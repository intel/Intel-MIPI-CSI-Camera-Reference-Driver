#!/bin/bash
#
# Discover the GMSL camera topology purely from ACPI/sysfs and program
# the media graph with media-ctl. Supports a *mixed* set of sensors behind
# a single deserializer (e.g. CAM0=D4XX on CH00, CAM1=ISX031 on CH01).
#
# ACPI namespace layout assumed (from SSDT):
#     \_SB.PCxx.DESn                             -- deserializer
#       \_SB.PCxx.DESn.CHmm                      -- channel (no HID)
#         \_SB.PCxx.DESn.CHmm.SERk                -- serializer
#           \_SB.PCxx.DESn.CHmm.SERk.CAMk          -- camera (sensor)
#
# Every ACPI device exposes:
#   /sys/bus/acpi/devices/<HID>:<UID>/path        -- ACPI namespace path
#   /sys/bus/acpi/devices/<HID>:<UID>/physical_node*/video4linux/v4l-subdev*/name
#                                                 -- "<entity_prefix> <bus>-<addr>"
#
# Known sensor / SerDes HIDs:
#   INTC10CD = D4XX camera   (entity prefixes: "DS5 mux", "D4XX depth/rgb/ir/imu")
#   INTC113C = ISX031 camera (entity prefix:   "isx031")
#   INTC1138 = MAX9295 / MAX96717 serializer    (entity prefix: "max96717")
#   INTC1137 = MAX9296A deserializer            (entity prefix: "max9296a")
#   INTC1139 = MAX96724 deserializer            (entity prefix: "max96724")

# -------- sensor-model table ---------------------------------------------------
#  HID       MODEL     CAM_PREFIX (used to read v4l-subdev bus-addr)
declare -A SENSOR_MODEL=(
    [INTC10CD]=d4xx
    [INTC113C]=isx031
)
declare -A SENSOR_PREFIX=(
    [INTC10CD]="DS5 mux"
    [INTC113C]="isx031"
)

# Serializer / deserializer HID -> v4l entity prefix
declare -A SER_PREFIX=(
    [INTC1138]="max96717"
)
declare -A DES_PREFIX=(
    [INTC1137]="max9296a"
    [INTC1139]="max96724"
)

# -------- low-level helpers ---------------------------------------------------

# Read "bus-addr" (e.g. 18-0010) from any v4l-subdev whose name starts with
# the given prefix, under any physical_node* of an ACPI sysfs dir.
acpi_busaddr() {
    local acpi_dir=$1 prefix=$2
    local f
    for f in "$acpi_dir"/physical_node*/video4linux/v4l-subdev*/name; do
        [ -e "$f" ] || continue
        local name; name=$(cat "$f")
        local ba; ba=$(printf '%s\n' "$name" | grep -oP "^${prefix} \K[0-9]+-[0-9a-f]+" | head -1)
        [ -n "$ba" ] && { echo "$ba"; return 0; }
    done
    return 1
}

# Find the ACPI sysfs dir whose `path` file matches a given namespace path.
# Echo "<HID>:<UID> <sysfs_dir>" or return 1.
acpi_find_by_path() {
    local target=$1
    local d p
    for d in /sys/bus/acpi/devices/*; do
        p=$(cat "$d/path" 2>/dev/null) || continue
        if [ "$p" = "$target" ]; then
            echo "$(basename "$d") $d"
            return 0
        fi
    done
    return 1
}

# List immediate ACPI children of a namespace path: print "<child_path>"
# sorted by the trailing component (so CH00 < CH01).
acpi_children_of() {
    local parent=$1
    local d p
    for d in /sys/bus/acpi/devices/*; do
        p=$(cat "$d/path" 2>/dev/null) || continue
        case "$p" in
            "$parent".*) ;;
            *) continue ;;
        esac
        # only direct children (one extra dot-segment)
        local rest=${p#"$parent".}
        case "$rest" in *.*) continue ;; esac
        echo "$p"
    done | sort -u
}

# HID/UID of an ACPI sysfs dir
acpi_hid() { cat "$1/hid" 2>/dev/null; }

# -------- topology discovery --------------------------------------------------

# Maximum number of links (CHxx) we consider per deserializer, keyed by the
# deserializer's v4l entity prefix. Override per model via env, e.g.
# MAX_LINKS_max9296a=2.
declare -A MAX_LINKS_BY_PREFIX=(
    [max96724]=${MAX_LINKS_max96724:-4}
    [max9296a]=${MAX_LINKS_max9296a:-2}
)
# Per-DES MAX_LINKS (indexed by DES index 'd'), populated during discovery.
declare -a DES_MAX_LINKS=()

# Locate every deserializer present on the system. Echoes one sysfs dir per
# line. Honours DES_HID=<hid> (filter to a specific HID) and DES_BUSADDR=
# (filter to a specific bus-addr e.g. "1-0027").
find_all_deserializers() {
    local want_hid=${DES_HID:-}
    local want_ba=${DES_BUSADDR:-}
    local hid d ba prefix
    for hid in "${!DES_PREFIX[@]}"; do
        [ -n "$want_hid" ] && [ "$want_hid" != "$hid" ] && continue
        prefix=${DES_PREFIX[$hid]}
        for d in /sys/bus/acpi/devices/${hid}:*; do
            [ -d "$d" ] || continue
            if [ -n "$want_ba" ]; then
                ba=$(acpi_busaddr "$d" "$prefix") || continue
                [ "$ba" = "$want_ba" ] || continue
            fi
            echo "$d"
        done
    done
}

# Per-DES arrays (indexed by deserializer index 'd', 0..N-1):
declare -a DES_PATH=() DES_BA=() DES_PREFIX_NAME=() DES_SRC_PAD=()
declare -a IPU_CSI2_ENTITY=() IPU_BASE=() CAPTURE_BASE=()
NUM_DES=0

# Per-link associative arrays keyed by "d_l" (deserializer index, link index):
declare -A CH_PATH=() SER_PATH=() CAM_PATH=()
declare -A SER_BA=()  CAM_BA=()
declare -A CAM_HID=() CAM_MODEL=() CAM_PREFIX=()
declare -A SER_HID_ARR=() SER_PFX=()
# LINKS_OF[d] holds a space-separated list of valid link indices on DES d.
declare -A LINKS_OF=()

discover_one_des() {
    local d=$1 des_dir=$2
    local des_hid des_path des_ba des_prefix
    des_hid=$(acpi_hid "$des_dir")
    des_prefix=${DES_PREFIX[$des_hid]}
    des_path=$(cat "$des_dir/path")
    des_ba=$(acpi_busaddr "$des_dir" "$des_prefix") || {
        echo "WARN: deserializer ${des_hid} at ${des_path} has no v4l-subdev (driver loaded?); skipping" >&2
        return 1
    }

    DES_PATH[$d]=$des_path
    DES_BA[$d]=$des_ba
    DES_PREFIX_NAME[$d]=$des_prefix
    # DES_SRC_PAD[$d] is filled in later by detect_csi2_entities() based on the
    # live media topology (which reflects the DES_CSI_LOCAL_PORT value the
    # SSDT/_CRS published in the CSI2Bus resource).
    DES_MAX_LINKS[$d]=${MAX_LINKS_BY_PREFIX[$des_prefix]:-4}

    local i ch ser_path ser_dir ser_hid cam_path cam_dir cam_hid ch_name key
    local found=0
    local links=""
    while IFS= read -r ch; do
        [ -z "$ch" ] && continue

        ch_name=${ch##*.}
        if [[ $ch_name =~ ^CH([0-9]+)$ ]]; then
            i=$((10#${BASH_REMATCH[1]}))
        else
            echo "WARN: DES${d}: cannot parse channel index from '$ch'; skipping" >&2
            continue
        fi
        if (( i >= DES_MAX_LINKS[d] )); then
            echo "WARN: DES${d}: link ${i} (${ch}) exceeds max supported links (${DES_MAX_LINKS[$d]}) for ${des_prefix}; skipping" >&2
            continue
        fi
        key="${d}_${i}"

        ser_path=$(acpi_children_of "$ch" | head -1)
        [ -z "$ser_path" ] && {
            echo "WARN: DES${d} link ${i} (${ch}) has no serializer child; skipping" >&2
            continue
        }
        read -r _ ser_dir < <(acpi_find_by_path "$ser_path") || {
            echo "WARN: DES${d} link ${i}: serializer ACPI dev for '$ser_path' not present in sysfs; skipping" >&2
            continue
        }
        ser_hid=$(acpi_hid "$ser_dir")
        [ -n "${SER_PREFIX[$ser_hid]:-}" ] || {
            echo "WARN: DES${d} link ${i}: unsupported serializer HID '$ser_hid' at $ser_path; skipping" >&2
            continue
        }

        cam_path=$(acpi_children_of "$ser_path" | head -1)
        [ -z "$cam_path" ] && {
            echo "WARN: DES${d} link ${i}: serializer at $ser_path has no camera child; skipping" >&2
            continue
        }
        read -r _ cam_dir < <(acpi_find_by_path "$cam_path") || {
            echo "WARN: DES${d} link ${i}: camera ACPI dev for '$cam_path' not present in sysfs; skipping" >&2
            continue
        }
        cam_hid=$(acpi_hid "$cam_dir")
        if [ -z "${SENSOR_MODEL[$cam_hid]:-}" ]; then
            local cam_name=""
            cam_name=$(cat "$cam_dir"/physical_node*/video4linux/v4l-subdev*/name 2>/dev/null | head -1)
            echo "WARN: DES${d} link ${i}: unsupported camera HID '$cam_hid' at $cam_path${cam_name:+ (subdev: $cam_name)}; skipping" >&2
            echo "      add an entry to SENSOR_MODEL[${cam_hid}] / SENSOR_PREFIX[${cam_hid}] to enable it" >&2
            continue
        fi

        CH_PATH[$key]=$ch
        SER_PATH[$key]=$ser_path
        CAM_PATH[$key]=$cam_path
        SER_HID_ARR[$key]=$ser_hid
        SER_PFX[$key]=${SER_PREFIX[$ser_hid]}
        SER_BA[$key]=$(acpi_busaddr "$ser_dir" "${SER_PFX[$key]}") || {
            echo "WARN: DES${d} link ${i}: serializer at $ser_path has no v4l-subdev (driver loaded?); skipping" >&2
            unset 'CH_PATH[$key]' 'SER_PATH[$key]' 'CAM_PATH[$key]' \
                  'SER_HID_ARR[$key]' 'SER_PFX[$key]' 'SER_BA[$key]'
            continue
        }
        CAM_PREFIX[$key]=${SENSOR_PREFIX[$cam_hid]}
        CAM_BA[$key]=$(acpi_busaddr "$cam_dir" "${CAM_PREFIX[$key]}") || {
            echo "WARN: DES${d} link ${i}: camera at $cam_path has no v4l-subdev (driver loaded?); skipping" >&2
            unset 'CH_PATH[$key]' 'SER_PATH[$key]' 'CAM_PATH[$key]' \
                  'SER_HID_ARR[$key]' 'SER_PFX[$key]' 'SER_BA[$key]' \
                  'CAM_PREFIX[$key]'
            continue
        }
        CAM_HID[$key]=$cam_hid
        CAM_MODEL[$key]=${SENSOR_MODEL[$cam_hid]}
        links+="${links:+ }${i}"
        found=$((found + 1))
    done < <(acpi_children_of "$des_path")

    LINKS_OF[$d]=$links
    [ "$found" -gt 0 ] || {
        echo "WARN: DES${d} (${des_path}): no supported cameras discovered; skipping" >&2
        unset 'DES_PATH[$d]' 'DES_BA[$d]' 'DES_PREFIX_NAME[$d]' 'DES_SRC_PAD[$d]'
        unset 'LINKS_OF[$d]'
        return 1
    }
    return 0
}

discover() {
    local des_dirs=()
    mapfile -t des_dirs < <(find_all_deserializers)
    [ "${#des_dirs[@]}" -gt 0 ] || {
        echo "ERROR: no known deserializer ACPI device present" >&2
        return 1
    }
    local d=0 dir
    for dir in "${des_dirs[@]}"; do
        if discover_one_des "$d" "$dir"; then
            d=$((d + 1))
        fi
    done
    NUM_DES=$d
    [ "$NUM_DES" -gt 0 ] || { echo "ERROR: no usable deserializer found" >&2; return 1; }
    return 0
}

# For each DES, locate the "Intel IPUx CSI2 N" entity wired to its source
# pad, the DES source pad number itself (which mirrors DES_CSI_LOCAL_PORT in
# the SSDT CSI2Bus resource), and the absolute capture-node base (lowest
# "ISYS Capture <N>" index linked to that CSI2). The DES->CSI2 link is
# IMMUTABLE so the live media topology is the source of truth.
detect_csi2_entities() {
    local topo
    topo=$(media-ctl -p 2>/dev/null) || {
        echo "ERROR: failed to read media topology via 'media-ctl -p'" >&2
        return 1
    }
    local d des_entity csi2 src_pad base line
    for ((d = 0; d < NUM_DES; d++)); do
        des_entity="${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}"
        # Extract "<src_pad> <csi2_entity>" from the entity block.
        line=$(awk -v des="$des_entity" '
            /^- entity / { in_des=0 }
            index($0, "- entity") && index($0, ": " des " (") { in_des=1; next }
            in_des && match($0, /pad[0-9]+:/) {
                p = substr($0, RSTART+3, RLENGTH-4)
                cur_pad = p + 0
            }
            in_des && match($0, /-> "Intel IPU[0-9]+ CSI2 [0-9]+"/) {
                s = substr($0, RSTART+4, RLENGTH-5)
                gsub(/"/, "", s)
                print cur_pad, s
                exit
            }' <<<"$topo")
        if [ -z "$line" ]; then
            echo "ERROR: DES${d}: could not find an 'Intel IPUx CSI2 N' link from '$des_entity'" >&2
            return 1
        fi
        src_pad=${line%% *}
        csi2=${line#* }
        DES_SRC_PAD[$d]=$src_pad
        IPU_CSI2_ENTITY[$d]=$csi2
        IPU_BASE[$d]=${csi2% CSI2 *}

        # Capture base = lowest "ISYS Capture N" entity that links from this CSI2.
        base=$(awk -v csi="$csi2" '
            /^- entity / {
                cap_num = ""
                if (match($0, /Intel IPU[0-9]+ ISYS Capture [0-9]+/)) {
                    s = substr($0, RSTART, RLENGTH)
                    sub(/.*Capture /, "", s)
                    cap_num = s + 0
                }
            }
            cap_num != "" && index($0, "<- \"" csi "\":") {
                if (min == "" || cap_num < min) min = cap_num
            }
            END { if (min != "") print min }' <<<"$topo")
        if [ -z "$base" ]; then
            echo "ERROR: DES${d}: could not find any 'ISYS Capture' entity linked from '$csi2'" >&2
            return 1
        fi
        CAPTURE_BASE[$d]=$base
    done
    return 0
}

# -------- pretty print --------------------------------------------------------

print_topology() {
    echo "Discovered topology:"
    local d l key
    for ((d = 0; d < NUM_DES; d++)); do
        printf "  DES%d  %-34s %s %s -> %s (capture base /dev/video%s)\n" \
            "$d" "${DES_PATH[$d]}" "${DES_PREFIX_NAME[$d]}" "${DES_BA[$d]}" \
            "${IPU_CSI2_ENTITY[$d]}" "${CAPTURE_BASE[$d]}"
        for l in ${LINKS_OF[$d]}; do
            key="${d}_${l}"
            printf "    CAM%d  %-34s %s %s  (model=%s, hid=%s)\n" \
                "$l" "${CAM_PATH[$key]}" "${CAM_PREFIX[$key]}" "${CAM_BA[$key]}" \
                "${CAM_MODEL[$key]}" "${CAM_HID[$key]}"
            printf "    SER%d  %-34s %s %s\n" \
                "$l" "${SER_PATH[$key]}" "${SER_PFX[$key]}" "${SER_BA[$key]}"
        done
    done
}


# -------- per-sensor media-ctl programming -----------------------------------
#
# CLI:
#     mc-mixed.sh                                      # default per-model streams, all DES
#     mc-mixed.sh [des=D,]link=N,stream=<csv> ...
#
# When des= is omitted, des=0 is assumed (matches the legacy single-DES CLI).
#
# Stream tokens by sensor model:
#     d4xx:   depth | rgb | ir | imu
#     isx031: yuv
#
# Default streams when no link is specified:
#     d4xx   -> depth,rgb
#     isx031 -> yuv
# applied to every link discovered under every deserializer.
#
# Capture-node layout (per DES) -- STREAM-MAJOR:
#     csi2_pad = STREAM_NODE[s] * DES_MAX_LINKS[d] + l
#     node     = CAPTURE_BASE[d] + csi2_pad
# Nodes are grouped by stream type across links: e.g. for a 4-link max96724
# with d4xx, depth lands on nodes base+0..3, rgb on base+4..7, etc. For
# 1-stream sensors like isx031, 4 links land on base+0..3 directly. The
# CSI2 RX cap is IPU7_NR_OF_CSI2_SRC_PADS (16 with the D4XX patch applied;
# 8 otherwise); the resulting pad must stay within that.
#
# v4l2 source_stream tag at the deserializer source pad / CSI2 sink pad is
# allocated separately as a compact per-DES sequential id (0..3), because
# max96724 / max_des bound the per-pipe stream-id field at 2 bits
# (MAX_SERDES_STREAMS_NUM=4). The csi2_pad above is only used as the CSI2
# *source* pad index (i.e. capture-node selector).

# =============================================================================
# Per-sensor stream defaults
# =============================================================================
# To support a new sensor or tweak an existing one, edit the block below.
# Each sensor model has its own WIDTH/HEIGHT/FMT knobs; stream_fmt() and
# stream_size() dispatch on the stream token to pick the right value.
# All variables honour environment-variable overrides (`VAR=...` on the CLI).

# ---- D4XX (Intel RealSense) -------------------------------------------------
# Streams: depth | rgb | ir | imu
D4XX_WIDTH=${D4XX_WIDTH:-640}
D4XX_HEIGHT=${D4XX_HEIGHT:-480}
D4XX_DEPTH_FMT=${D4XX_DEPTH_FMT:-UYVY8_1X16}
D4XX_RGB_FMT=${D4XX_RGB_FMT:-YUYV8_1X16}
D4XX_IR_FMT=${D4XX_IR_FMT:-VYUY8_1X16}
D4XX_IMU_FMT=${D4XX_IMU_FMT:-Y8_1X8}
D4XX_IMU_SIZE=${D4XX_IMU_SIZE:-38x1}

# ---- ISX031 (YUV) ------------------------------------------------------
# Streams: yuv
ISX031_FMT=${ISX031_FMT:-UYVY8_1X16}
ISX031_SIZE=${ISX031_SIZE:-1920x1536}

# Stream metadata.  d4xx: depth/rgb/ir/imu.  isx031: yuv (treated as row 0).
declare -A STREAM_NODE=(   [depth]=0 [rgb]=1 [ir]=2 [imu]=3 [yuv]=0 )
declare -A STREAM_MUXPAD=( [depth]=1 [rgb]=2 [ir]=3 [imu]=4 )

declare -A MODEL_DEFAULT_STREAMS=(
    [d4xx]="depth rgb"
    [isx031]="yuv"
)

stream_fmt() {
    case "$1" in
        depth) echo "${D4XX_DEPTH_FMT}" ;;
        rgb)   echo "${D4XX_RGB_FMT}"   ;;
        ir)    echo "${D4XX_IR_FMT}"    ;;
        imu)   echo "${D4XX_IMU_FMT}"   ;;
        yuv)   echo "${ISX031_FMT}"     ;;
    esac
}
stream_size() {
    case "$1" in
        depth|rgb|ir) echo "${D4XX_WIDTH}x${D4XX_HEIGHT}" ;;
        imu)          echo "${D4XX_IMU_SIZE}"             ;;
        yuv)          echo "${ISX031_SIZE}"               ;;
    esac
}
stream_valid_for_model() {
    case "$2" in
        d4xx)   [[ $1 == depth || $1 == rgb || $1 == ir || $1 == imu ]] ;;
        isx031) [[ $1 == yuv ]] ;;
        *)      return 1 ;;
    esac
}

die() { echo "ERROR: $*" >&2; exit 1; }

# Require media-ctl >= 1.30 (older releases lack the streams/routing API used here).
check_media_ctl_version() {
    local required_major=1 required_minor=30
    command -v media-ctl >/dev/null 2>&1 || die "media-ctl not found in PATH"

    local ver
    ver=$(media-ctl --version 2>/dev/null | awk '/^media-ctl[[:space:]]+[0-9]+\./ {print $2; exit}')
    [[ -n $ver ]] || die "unable to determine media-ctl version (\`media-ctl --version\`)"

    local major minor
    major=${ver%%.*}
    minor=${ver#*.}; minor=${minor%%.*}; minor=${minor%%-*}
    [[ $major =~ ^[0-9]+$ && $minor =~ ^[0-9]+$ ]] \
        || die "unable to parse media-ctl version: '$ver'"

    if (( major < required_major )) || \
       (( major == required_major && minor < required_minor )); then
        die "media-ctl ${ver} is too old; ${required_major}.${required_minor} or newer is required"
    fi
}

# -------- main ----------------------------------------------------------------

check_media_ctl_version
discover || exit 1
detect_csi2_entities || exit 1
print_topology

# ---- argument parsing ------------------------------------------------------

# Each CFG entry is identified by (des_idx, link_idx) and carries a streams list.
declare -a CFG_DES=()
declare -a CFG_LINKS=()
declare -a CFG_STREAMS=()

if [ "$#" -eq 0 ]; then
    # Default: program every discovered link with its model's default streams.
    for ((d = 0; d < NUM_DES; d++)); do
        for l in ${LINKS_OF[$d]}; do
            key="${d}_${l}"
            CFG_DES+=("$d")
            CFG_LINKS+=("$l")
            CFG_STREAMS+=("${MODEL_DEFAULT_STREAMS[${CAM_MODEL[$key]}]}")
        done
    done
else
    for arg in "$@"; do
        des=""; link=""; streams=""
        IFS=',' read -ra parts <<<"$arg"
        for kv in "${parts[@]}"; do
            case "$kv" in
                des=*)    des=${kv#des=} ;;
                link=*)   link=${kv#link=} ;;
                stream=*) streams+="${streams:+ }${kv#stream=}" ;;
                depth|rgb|ir|imu|yuv)
                    streams+="${streams:+ }$kv"
                    ;;
                *) die "unrecognised token '$kv' in '$arg'" ;;
            esac
        done
        [ -n "$link" ]    || die "missing link= in '$arg'"
        [ -n "$streams" ] || die "missing stream= in '$arg'"
        [[ $link =~ ^[0-9]+$ ]] || die "link must be numeric (got '$link')"
        # Default des=0 when only one DES is present and des= was omitted.
        if [ -z "$des" ]; then
            if [ "$NUM_DES" -gt 1 ]; then
                die "des= required when multiple deserializers are present (in '$arg')"
            fi
            des=0
        fi
        [[ $des =~ ^[0-9]+$ ]] || die "des must be numeric (got '$des')"
        (( des < NUM_DES )) || die "des=$des out of range (have ${NUM_DES} DES)"
        key="${des}_${link}"
        [ -n "${CAM_MODEL[$key]:-}" ] || die "no camera discovered on DES${des} link ${link}"
        for s in $streams; do
            stream_valid_for_model "$s" "${CAM_MODEL[$key]}" \
                || die "stream '$s' invalid for ${CAM_MODEL[$key]} on DES${des} link ${link}"
        done
        CFG_DES+=("$des")
        CFG_LINKS+=("$link")
        CFG_STREAMS+=("$streams")
    done
    # Reject duplicate (des,link) entries.
    declare -A seen=()
    for k in "${!CFG_LINKS[@]}"; do
        sk="${CFG_DES[$k]}_${CFG_LINKS[$k]}"
        [ -z "${seen[$sk]:-}" ] || die "DES${CFG_DES[$k]} link ${CFG_LINKS[$k]} specified more than once"
        seen[$sk]=1
    done
fi

echo "Setting Up:"

# IPU7 CSI2 RX source-pad cap (16 with the D4XX patch, 8 otherwise).
IPU_CSI2_SRC_PADS=${IPU_CSI2_SRC_PADS:-16}

# Compute csi2_pad per (cfg_index, stream) using a stream-major formula:
# all 'depth' across links first, then all 'rgb', etc. For 1-stream sensors
# (isx031) this collapses to csi2_pad == link, so 4 links land on the first
# four capture nodes.
declare -A CSI2_PAD=()
# Compact v4l2 source_stream id assigned to each (cfg_index, stream) at the
# deserializer source pad and at the CSI2 sink pad. The kernel-side max96724
# / max_des state machine bounds the per-pipe stream-id field at 2 bits
# (MAX_SERDES_STREAMS_NUM=4), so any v4l2 source_stream tag >=4 trips an
# EINVAL on set_fmt. We therefore allocate per-DES sequential ids 0..3
# independent of the (larger) csi2_pad values used downstream.
declare -A DES_STREAM=()
declare -A DES_STREAM_NEXT=()
for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    for s in ${CFG_STREAMS[$k]}; do
        pad=$(( STREAM_NODE[$s] * DES_MAX_LINKS[d] + l ))
        if (( pad >= IPU_CSI2_SRC_PADS )); then
            die "DES${d} link ${l} stream ${s}: csi2_pad ${pad} exceeds IPU7 cap (${IPU_CSI2_SRC_PADS}); rebuild with the D4XX patch (raises cap to 16) or reduce active links/streams"
        fi
        CSI2_PAD["${k}_${s}"]=$pad

        ds=${DES_STREAM_NEXT[$d]:-0}
        if (( ds >= 4 )); then
            die "DES${d}: too many streams routed through deserializer source pad (max96724 supports 4 unique source_streams)"
        fi
        DES_STREAM["${k}_${s}"]=$ds
        DES_STREAM_NEXT[$d]=$(( ds + 1 ))
    done
done

# Reset all media links and per-stream pad state so we don't inherit formats
# or enabled-link flags from a prior run with a different layout.
media-ctl -r 2>/dev/null || true

for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    echo -e "  DES${d} LINK${l}\t Sensor model\t ${CAM_MODEL[$key]}\n\t\t Cam Entity\t ${CAM_PREFIX[$key]} ${CAM_BA[$key]}\n\t\t Ser Entity\t ${SER_PFX[$key]} ${SER_BA[$key]}"
    for s in ${CFG_STREAMS[$k]}; do
        csi2_pad=${CSI2_PAD["${k}_${s}"]}
        node=$(( CAPTURE_BASE[d] + csi2_pad ))
        echo -e "\t\t Stream\t\t [${s}] available at: /dev/video${node} (csi2 src stream ${csi2_pad})"
    done
done

# ---- programming -----------------------------------------------------------

# Per-DES route accumulators (the kernel resets per-stream pad formats whenever
# routes are (re)programmed, so all -R must precede any -V).
declare -A DES_ROUTES=()
declare -A CSI2_ROUTES=()

# --- pass 1: per-link source-side routes (mux/serializer), and accumulate
#             per-DES deserializer/CSI2 routes.
for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    model=${CAM_MODEL[$key]}
    cam=${CAM_BA[$key]}
    ser=${SER_BA[$key]}
    ser_pfx=${SER_PFX[$key]}
    sel_streams=(${CFG_STREAMS[$k]})
    n=${#sel_streams[@]}

    # Stream IDs along the mux->serializer->deserializer chain are fixed
    # per sensor sub-stream (see STREAM_NODE): depth=0, rgb=1, ir=2, imu=3,
    # yuv=0. The d4xx driver in particular asserts that the route's
    # source_stream on the mux matches the sensor's hard-coded vc_id, so
    # we must use STREAM_NODE[$s] -- not a sequential 0..n-1 index -- as
    # the stream identifier everywhere downstream of the sensor.

    case "$model" in
        d4xx)
            declare -A is_selected=()
            for s in "${sel_streams[@]}"; do is_selected[$s]=1; done

            mux_route_parts=()
            for s in depth rgb ir imu; do
                sid=${STREAM_NODE[$s]}
                if [ -n "${is_selected[$s]:-}" ]; then
                    mux_route_parts+=("${STREAM_MUXPAD[$s]}/0->0/${sid}[1]")
                else
                    mux_route_parts+=("${STREAM_MUXPAD[$s]}/0->0/${sid}[0]")
                fi
            done
            mux_routes=$(IFS=,; echo "${mux_route_parts[*]}")

            media-ctl -l "\"DS5 mux ${cam}\":0 -> \"${ser_pfx} ${ser}\":0[1]"
            media-ctl -R "\"DS5 mux ${cam}\" [${mux_routes}]"

            ser_route_parts=()
            for s in "${sel_streams[@]}"; do
                sid=${STREAM_NODE[$s]}
                ser_route_parts+=("0/${sid}->1/${sid}[1]")
            done
            ser_routes=$(IFS=,; echo "${ser_route_parts[*]}")
            media-ctl -R "\"${ser_pfx} ${ser}\" [${ser_routes}]"

            unset is_selected
            ;;
        isx031)
            ser_route_parts=()
            for s in "${sel_streams[@]}"; do
                sid=${STREAM_NODE[$s]}
                ser_route_parts+=("0/${sid}->1/${sid}[1]")
            done
            ser_routes=$(IFS=,; echo "${ser_route_parts[*]}")
            media-ctl -R "\"${ser_pfx} ${ser}\" [${ser_routes}]"
            ;;
    esac

    vcs=${MODEL_VCS_PER_LINK[$model]:-1}
    for s in "${sel_streams[@]}"; do
        sid=${STREAM_NODE[$s]}
        csi2_pad=${CSI2_PAD["${k}_${s}"]}
        des_stream=${DES_STREAM["${k}_${s}"]}
        DES_ROUTES[$d]+="${DES_ROUTES[$d]:+,}${l}/${sid}->${DES_SRC_PAD[$d]}/${des_stream}[1]"
        CSI2_ROUTES[$d]+="${CSI2_ROUTES[$d]:+,}0/${des_stream}->$((csi2_pad + 1))/0[1]"
    done
done

# Apply per-DES route tables.
for ((d = 0; d < NUM_DES; d++)); do
    [ -n "${DES_ROUTES[$d]:-}" ] || continue
    media-ctl -R "\"${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}\" [${DES_ROUTES[$d]}]"
    media-ctl -R "\"${IPU_CSI2_ENTITY[$d]}\" [${CSI2_ROUTES[$d]}]"
done

# CSI2 source pad -> ISYS Capture entity link (must exist before formats flow).
for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    for s in ${CFG_STREAMS[$k]}; do
        csi2_pad=${CSI2_PAD["${k}_${s}"]}
        node=$(( CAPTURE_BASE[d] + csi2_pad ))
        media-ctl -l "\"${IPU_CSI2_ENTITY[$d]}\":$((csi2_pad + 1)) -> \"${IPU_BASE[$d]} ISYS Capture ${node}\":0[1]"
    done
done

# --- pass 2: format propagation (all routes are now in place).

# Wrapper around `media-ctl -V` that prints the exact failing arg on error so
# format-propagation issues are easy to pin down.
mc_v() {
    if ! media-ctl -V "$1"; then
        echo "  ^^ failed: media-ctl -V $1" >&2
    fi
}

for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    model=${CAM_MODEL[$key]}
    cam=${CAM_BA[$key]}
    ser=${SER_BA[$key]}
    ser_pfx=${SER_PFX[$key]}
    sel_streams=(${CFG_STREAMS[$k]})

    for s in "${sel_streams[@]}"; do
        sid=${STREAM_NODE[$s]}
        csi2_pad=${CSI2_PAD["${k}_${s}"]}
        des_stream=${DES_STREAM["${k}_${s}"]}
        fmt=$(stream_fmt "$s")
        size=$(stream_size "$s")

        case "$model" in
            d4xx)
                mc_v "\"D4XX ${s} ${cam}\":0 [fmt:${fmt}/${size} field:none]"
                ;;
            isx031)
                mc_v "\"isx031 ${cam}\":0/${sid} [fmt:${fmt}/${size} field:none]"
                ;;
        esac
        mc_v "\"${ser_pfx} ${ser}\":0/${sid} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${ser_pfx} ${ser}\":1/${sid} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}\":${l}/${sid} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}\":${DES_SRC_PAD[$d]}/${des_stream} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${IPU_CSI2_ENTITY[$d]}\":0/${des_stream} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${IPU_CSI2_ENTITY[$d]}\":$((csi2_pad + 1))/0 [fmt:${fmt}/${size} field:none]"
    done
done

# ---- v4l2-ctl: capture-node format -----------------------------------------

mbus_to_pixfmt() {
    case "$1" in
        UYVY8_1X16) echo UYVY ;;
        YUYV8_1X16) echo YUYV ;;
        VYUY8_1X16) echo "Y8I " ;;  # IR -> interleaved 8-bit greyscale
        Y8_1X8)     echo GREY ;;
        *)          echo ""   ;;
    esac
}

for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    for s in ${CFG_STREAMS[$k]}; do
        node=$(( CAPTURE_BASE[d] + CSI2_PAD["${k}_${s}"] ))
        pixfmt=$(mbus_to_pixfmt "$(stream_fmt "$s")")
        [ -z "$pixfmt" ] && continue
        size=$(stream_size "$s")
        w=${size%x*}
        h=${size#*x}
        v4l2-ctl -d "/dev/video${node}" \
            --set-fmt-video="width=${w},height=${h},pixelformat=${pixfmt}" \
            >/dev/null
    done
done
