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

# Locate the (single) deserializer present on the system. If multiple are
# present, the first one wins; export DES_HID=<hid> to override.
find_deserializer() {
    local want=${DES_HID:-}
    local hid
    for hid in "${!DES_PREFIX[@]}"; do
        [ -n "$want" ] && [ "$want" != "$hid" ] && continue
        local d
        for d in /sys/bus/acpi/devices/${hid}:*; do
            [ -d "$d" ] || continue
            echo "$d"
            return 0
        done
    done
    return 1
}

declare -a CH_PATH SER_PATH CAM_PATH
declare -a SER_BA  CAM_BA
declare -a CAM_HID CAM_MODEL CAM_PREFIX
declare -a SER_HID_ARR SER_PFX
DES_BA=""; DES_PREFIX_NAME=""; DES_PATH=""

discover() {
    local des_dir des_hid
    des_dir=$(find_deserializer) || {
        echo "ERROR: no known deserializer ACPI device present" >&2
        return 1
    }
    des_hid=$(acpi_hid "$des_dir")
    DES_PREFIX_NAME=${DES_PREFIX[$des_hid]}
    DES_PATH=$(cat "$des_dir/path")
    DES_BA=$(acpi_busaddr "$des_dir" "$DES_PREFIX_NAME") || {
        echo "ERROR: deserializer ${des_hid} has no v4l-subdev (driver loaded?)" >&2
        return 1
    }

    local i=0 ch ser_path ser_dir ser_hid cam_path cam_dir cam_hid
    while IFS= read -r ch; do
        [ -z "$ch" ] && continue
        # serializer = single child of CHxx
        ser_path=$(acpi_children_of "$ch" | head -1)
        [ -z "$ser_path" ] && continue
        read -r _ ser_dir < <(acpi_find_by_path "$ser_path") || continue
        ser_hid=$(acpi_hid "$ser_dir")
        [ -n "${SER_PREFIX[$ser_hid]:-}" ] || {
            echo "WARN: unknown serializer HID $ser_hid at $ser_path; skipping" >&2
            continue
        }
        # camera = single child of SERx
        cam_path=$(acpi_children_of "$ser_path" | head -1)
        [ -z "$cam_path" ] && continue
        read -r _ cam_dir < <(acpi_find_by_path "$cam_path") || continue
        cam_hid=$(acpi_hid "$cam_dir")
        [ -n "${SENSOR_MODEL[$cam_hid]:-}" ] || {
            echo "WARN: unknown camera HID $cam_hid at $cam_path; skipping" >&2
            continue
        }

        CH_PATH[$i]=$ch
        SER_PATH[$i]=$ser_path
        CAM_PATH[$i]=$cam_path
        SER_HID_ARR[$i]=$ser_hid
        SER_PFX[$i]=${SER_PREFIX[$ser_hid]}
        SER_BA[$i]=$(acpi_busaddr "$ser_dir" "${SER_PFX[$i]}") || {
            echo "ERROR: serializer at $ser_path has no v4l-subdev" >&2
            return 1
        }
        CAM_PREFIX[$i]=${SENSOR_PREFIX[$cam_hid]}
        CAM_BA[$i]=$(acpi_busaddr "$cam_dir" "${CAM_PREFIX[$i]}") || {
            echo "ERROR: camera at $cam_path has no v4l-subdev" >&2
            return 1
        }
        CAM_HID[$i]=$cam_hid
        CAM_MODEL[$i]=${SENSOR_MODEL[$cam_hid]}
        i=$((i + 1))
    done < <(acpi_children_of "$DES_PATH")

    [ "$i" -gt 0 ] || { echo "ERROR: no cameras discovered under $DES_PATH" >&2; return 1; }
    return 0
}

# -------- pretty print --------------------------------------------------------

print_topology() {
    echo "Discovered topology:"
    printf "  DES   %-34s %s %s\n" "$DES_PATH" "${DES_PREFIX_NAME}" "$DES_BA"
    local i
    for i in "${!CAM_PATH[@]}"; do
        printf "  CAM%d  %-34s %s %s  (model=%s, hid=%s)\n" \
            "$i" "${CAM_PATH[$i]}" "${CAM_PREFIX[$i]}" "${CAM_BA[$i]}" \
            "${CAM_MODEL[$i]}" "${CAM_HID[$i]}"
        printf "  SER%d  %-34s %s %s\n" \
            "$i" "${SER_PATH[$i]}" "${SER_PFX[$i]}" "${SER_BA[$i]}"
    done
}

# -------- per-sensor media-ctl programming -----------------------------------
#
# CLI (mc-d4xx-style):
#     mc-mixed.sh                                       # default per-model streams
#     mc-mixed.sh link=N,stream=<csv> [link=M,stream=<csv> ...]
#
# Stream tokens by sensor model:
#     d4xx:   depth | rgb | ir | imu
#     isx031: yuv
#
# When no link/stream is specified, the default is:
#     d4xx   -> depth,rgb
#     isx031 -> yuv
# applied to every link discovered under the deserializer.
#
# Node layout: node = STREAM_NODE[s] * 4 + link_idx  (/dev/video<node>).

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

# -------- main ----------------------------------------------------------------

discover || exit 1
print_topology

# ---- argument parsing ------------------------------------------------------

declare -a CFG_LINKS=()
declare -a CFG_STREAMS=()

if [ "$#" -eq 0 ]; then
    # Default: program every discovered link with its model's default streams.
    for i in "${!CAM_MODEL[@]}"; do
        CFG_LINKS+=("$i")
        CFG_STREAMS+=("${MODEL_DEFAULT_STREAMS[${CAM_MODEL[$i]}]}")
    done
else
    for arg in "$@"; do
        link=""; streams=""
        IFS=',' read -ra parts <<<"$arg"
        for kv in "${parts[@]}"; do
            case "$kv" in
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
        [ -n "${CAM_MODEL[$link]:-}" ] || die "no camera discovered on link $link"
        for s in $streams; do
            stream_valid_for_model "$s" "${CAM_MODEL[$link]}" \
                || die "stream '$s' invalid for ${CAM_MODEL[$link]} on link $link"
        done
        CFG_LINKS+=("$link")
        CFG_STREAMS+=("$streams")
    done
    declare -A seen_link=()
    for l in "${CFG_LINKS[@]}"; do
        [ -z "${seen_link[$l]:-}" ] || die "link $l specified more than once"
        seen_link[$l]=1
    done
fi

# Deserializer CSI2-source pad: max96724 -> 6, max9296a -> 4.
case "$DES_PREFIX_NAME" in
    max96724) DES_SRC_PAD=6 ;;
    max9296a) DES_SRC_PAD=4 ;;
    *) die "unknown deserializer prefix '$DES_PREFIX_NAME'" ;;
esac

echo "Setting Up:"
for k in "${!CFG_LINKS[@]}"; do
    l=${CFG_LINKS[$k]}
    echo -e "  LINK${l}\t Sensor model\t ${CAM_MODEL[$l]}\n\t Cam Entity\t ${CAM_PREFIX[$l]} ${CAM_BA[$l]}\n\t Ser Entity\t ${SER_PFX[$l]} ${SER_BA[$l]}"
    for s in ${CFG_STREAMS[$k]}; do
        node=$(( STREAM_NODE[$s] * 4 + l ))
        echo -e "\t Stream\t\t [${s}] available at: /dev/video${node}"
    done
done

# ---- programming -----------------------------------------------------------

des_routes=""
csi2_routes=""

# --- pass 1: routes only (the kernel resets per-stream pad formats whenever
#             routes are (re)programmed, so all -R must precede any -V).
for k in "${!CFG_LINKS[@]}"; do
    l=${CFG_LINKS[$k]}
    model=${CAM_MODEL[$l]}
    cam=${CAM_BA[$l]}
    ser=${SER_BA[$l]}
    sel_streams=(${CFG_STREAMS[$k]})
    n=${#sel_streams[@]}

    case "$model" in
        d4xx)
            # DS5 mux: active selected streams + inactive [0] for the rest.
            declare -A is_selected=()
            for s in "${sel_streams[@]}"; do is_selected[$s]=1; done

            mux_route_parts=()
            for idx in "${!sel_streams[@]}"; do
                s=${sel_streams[$idx]}
                mux_route_parts+=("${STREAM_MUXPAD[$s]}/0->0/${idx}[1]")
            done
            inactive_idx=$n
            for s in depth rgb ir imu; do
                [ -n "${is_selected[$s]:-}" ] && continue
                mux_route_parts+=("${STREAM_MUXPAD[$s]}/0->0/${inactive_idx}[0]")
                inactive_idx=$((inactive_idx + 1))
            done
            mux_routes=$(IFS=,; echo "${mux_route_parts[*]}")

            media-ctl -l "\"DS5 mux ${cam}\":0 -> \"${SER_PFX[$l]} ${ser}\":0[1]"
            media-ctl -R "\"DS5 mux ${cam}\" [${mux_routes}]"

            ser_route_parts=()
            for idx in $(seq 0 $((n - 1))); do
                ser_route_parts+=("0/${idx}->1/${idx}[1]")
            done
            ser_routes=$(IFS=,; echo "${ser_route_parts[*]}")
            media-ctl -R "\"${SER_PFX[$l]} ${ser}\" [${ser_routes}]"

            unset is_selected
            ;;
        isx031)
            # isx031 -> max96717 link is IMMUTABLE; just program ser passthrough.
            ser_route_parts=()
            for idx in $(seq 0 $((n - 1))); do
                ser_route_parts+=("0/${idx}->1/${idx}[1]")
            done
            ser_routes=$(IFS=,; echo "${ser_route_parts[*]}")
            media-ctl -R "\"${SER_PFX[$l]} ${ser}\" [${ser_routes}]"
            ;;
    esac

    for idx in "${!sel_streams[@]}"; do
        s=${sel_streams[$idx]}
        node=$(( STREAM_NODE[$s] * 4 + l ))
        des_routes+="${des_routes:+,}${l}/${idx}->${DES_SRC_PAD}/${node}[1]"
        csi2_routes+="${csi2_routes:+,}0/${node}->$((node + 1))/0[1]"
    done
done

media-ctl -R "\"${DES_PREFIX_NAME} ${DES_BA}\" [${des_routes}]"
media-ctl -R "\"Intel IPU7 CSI2 0\" [${csi2_routes}]"

for k in "${!CFG_LINKS[@]}"; do
    l=${CFG_LINKS[$k]}
    for s in ${CFG_STREAMS[$k]}; do
        node=$(( STREAM_NODE[$s] * 4 + l ))
        media-ctl -l "\"Intel IPU7 CSI2 0\":$((node + 1)) -> \"Intel IPU7 ISYS Capture ${node}\":0[1]"
    done
done

# --- pass 2: format propagation.
for k in "${!CFG_LINKS[@]}"; do
    l=${CFG_LINKS[$k]}
    model=${CAM_MODEL[$l]}
    cam=${CAM_BA[$l]}
    ser=${SER_BA[$l]}
    sel_streams=(${CFG_STREAMS[$k]})

    for idx in "${!sel_streams[@]}"; do
        s=${sel_streams[$idx]}
        node=$(( STREAM_NODE[$s] * 4 + l ))
        fmt=$(stream_fmt "$s")
        size=$(stream_size "$s")

        case "$model" in
            d4xx)
                media-ctl -V "\"D4XX ${s} ${cam}\":0 [fmt:${fmt}/${size} field:none]"
                ;;
            isx031)
                media-ctl -V "\"isx031 ${cam}\":0/${idx} [fmt:${fmt}/${size} field:none]"
                ;;
        esac
        media-ctl -V "\"${SER_PFX[$l]} ${ser}\":0/${idx} [fmt:${fmt}/${size} field:none]"
        media-ctl -V "\"${SER_PFX[$l]} ${ser}\":1/${idx} [fmt:${fmt}/${size} field:none]"
        media-ctl -V "\"${DES_PREFIX_NAME} ${DES_BA}\":${l}/${idx} [fmt:${fmt}/${size} field:none]"
        media-ctl -V "\"${DES_PREFIX_NAME} ${DES_BA}\":${DES_SRC_PAD}/${node} [fmt:${fmt}/${size} field:none]"
        media-ctl -V "\"Intel IPU7 CSI2 0\":0/${node} [fmt:${fmt}/${size} field:none]"
        media-ctl -V "\"Intel IPU7 CSI2 0\":$((node + 1))/0 [fmt:${fmt}/${size} field:none]"
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
    l=${CFG_LINKS[$k]}
    for s in ${CFG_STREAMS[$k]}; do
        node=$(( STREAM_NODE[$s] * 4 + l ))
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
