#!/bin/bash
#
# Copyright (C) 2026 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
#   OVTI13B1 = OV13B10 camera (entity prefix: "ov13b10")
#   INTC1138 = MAX9295 serializer               (entity prefix: "max96717")
#   INTC1141 = MAX96717 serializer              (entity prefix: "max96717")
#   INTC1137 = MAX9296A deserializer            (entity prefix: "max9296a")
#   INTC1139 = MAX96724 deserializer            (entity prefix: "max96724")

# =============================================================================
# Environment variable overrides (all optional)
# =============================================================================
# Discovery filters:
#   DES_HID=<hid>            Restrict discovery to one deserializer HID
#                            (e.g. INTC1137 or INTC1139). Default: unset (all).
#   DES_BUSADDR=<bus>-<addr> Restrict to one I2C bus-addr (e.g. 1-0027).
#                            Default: unset (all).
#
# Per-DES link count caps (override MAX_LINKS_BY_PREFIX):
#   MAX_LINKS_max96724       Default: 4
#   MAX_LINKS_max9296a       Default: 2
#
# IPU7 CSI2 RX source-pad cap:
#   IPU_CSI2_SRC_PADS        Default: 16 (use 8 without the D4XX IPU7 patch).
#
# Example:
#   DES_HID=INTC1139 ./mc-setup.sh \
#       link=0,stream=depth,res=1280x720,format=UYVY8_1X16 \
#       link=1,stream=depth
#
# =============================================================================
# USER CONFIGURATION
# =============================================================================
# Edit the tables below to add a new sensor MODEL, a new HID -> entity PREFIX
# mapping, or a new stream FORMAT. Everything further down is generic and
# dispatches off these tables.
#
# To add a new sensor model:
#   1. Add its ACPI HID -> model name in SENSOR_MODEL.
#   2. Add its ACPI HID -> v4l-subdev entity prefix in SENSOR_PREFIX.
#   3. For multi-stream models, list the stream tokens in MODEL_STREAMS and
#      select their defaults in MODEL_DEFAULT_STREAMS.
#   4. For each new stream token, set STREAM_NODE (and STREAM_MUXPAD if it
#      flows through a d4xx-style mux).
#   5. If your new media-bus code isn't covered, extend MBUS_TO_PIXFMT.
#   6. If the sensor needs custom media-ctl wiring beyond a plain serializer
#      pass-through (e.g. a mux subdev), extend the per-model case statements
#      in the programming passes further down -- the tables alone are enough
#      for simple "serializer-only" sensors.
# -----------------------------------------------------------------------------

# ---- ACPI HID -> v4l entity prefix / sensor model ---------------------------
declare -A SENSOR_MODEL=(
    [INTC10CD]=d4xx
    [INTC113C]=isx031
    [INTC10C0]=ar0234
    [OVTI13B1]=ov13b10
)
declare -A SENSOR_PREFIX=(
    [INTC10CD]="DS5 mux"
    [INTC113C]="isx031"
    [INTC10C0]="ar0234"
    [OVTI13B1]="ov13b10"
)

# ---- Direct MIPI sensor HIDs (no GMSL deserializer) ------------------------
declare -A MIPI_SENSOR_HID=(
    [INTC113C]=isx031
    [OVTI13B1]=ov13b10
)

# ---- Serializer / Deserializer HID -> v4l entity prefix ---------------------
declare -A SER_PREFIX=(
    [INTC1138]="max96717"
    [INTC1141]="max96717"
)
declare -A DES_PREFIX=(
    [INTC1137]="max9296a"
    [INTC1139]="max96724"
)

# Max number of CHxx links per deserializer, keyed by DES entity prefix.
# Override per model via env, e.g. MAX_LINKS_max9296a=2.
declare -A MAX_LINKS_BY_PREFIX=(
    [max96724]=${MAX_LINKS_max96724:-4}
    [max9296a]=${MAX_LINKS_max9296a:-2}
)

# ---- Per-model stream definitions -------------------------------------------
# MODEL_STREAMS: stream tokens selectable for multi-stream models.
# MODEL_DEFAULT_STREAMS: streams enabled for those models when no `stream=` is
# given on the CLI.
declare -A MODEL_STREAMS=(
    [d4xx]="depth rgb ir imu"
)
declare -A MODEL_DEFAULT_STREAMS=(
    [d4xx]="depth rgb"
)

fixed_stream_for_model() {
    case "$1" in
        isx031|ar0234|ov13b10) echo single ;;
        *) return 1 ;;
    esac
}

# STREAM_NODE: per-stream capture-node index (also used as the v4l2
# source_stream id on the mux/serializer chain -- d4xx in particular asserts
# this matches the sensor's hard-coded vc_id, so pick stable values).
declare -A STREAM_NODE=(
    [depth]=0
    [rgb]=1
    [ir]=2
    [imu]=3
    [single]=0
)

# Capture-node placement is independent of STREAM_NODE. Depth and IMU share
# bank 0..3; RGB and IR share bank 4..7. Rotating IR and IMU by two links gives
# this D4XX camera 1..4 mapping:
#   depth=0,1,2,3  rgb=4,5,6,7  ir=6,7,4,5  imu=2,3,0,1
CSI2_NODE_BANK_SIZE=4
declare -A STREAM_CAPTURE_BASE=(
    [depth]=0
    [rgb]=4
    [ir]=4
    [imu]=0
    [single]=0
)
declare -A STREAM_LINK_ROTATION=(
    [depth]=0
    [rgb]=0
    [ir]=2
    [imu]=2
    [single]=0
)

# STREAM_MUXPAD: sink pad on a d4xx-style mux subdev. Only needed for streams
# that flow through such a mux, usually a 3D sensor.
declare -A STREAM_MUXPAD=(
    [depth]=1
    [rgb]=2
    [ir]=3
    [imu]=4
)

# ---- Media-bus -> V4L2 pixelformat fourcc (used on capture nodes) -----------
declare -A MBUS_TO_PIXFMT=(
    [FIXED]="Z16 "
    [UYVY8_1X16]="UYVY"
    [YUYV8_1X16]="YUYV"
    [RGB888_1X24]="BGR3"
    [VYUY8_1X16]="Y8I "   # IR -> interleaved 8-bit greyscale
    [Y8_1X8]="GREY"
    [SGRBG10_1X10]="BA10"  # AR0234 RAW Bayer SGRBG 10-bit
)
mbus_to_pixfmt() { echo "${MBUS_TO_PIXFMT[$1]:-}"; }

declare -A STREAM_FORMAT_MAP=(
    [d4xx_depth_FIXED]=UYVY8_1X16
)

# =============================================================================
# end of USER CONFIGURATION
# =============================================================================

# -------- low-level helpers ---------------------------------------------------

# Find the lowest "ISYS Capture N" index linked from a given CSI2 entity.
# Reads media-ctl topology from stdin.
capture_base_of_csi2() {
    awk -v csi="$1" '
        /^- entity / {
            n = ""
            if (match($0, /Intel IPU[0-9]+ ISYS Capture [0-9]+/)) {
                s = substr($0, RSTART, RLENGTH)
                sub(/.*Capture /, "", s)
                n = s + 0
            }
        }
        n != "" && index($0, "<- \"" csi "\":") {
            if (m == "" || n < m) m = n
        }
        END { if (m != "") print m }
    '
}

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

# Wrappers around `media-ctl` that print the exact failing arg on error so
# link-setup, routing and format-propagation issues are easy to pin down.
# Each wrapper preserves the underlying `media-ctl` exit status so callers
# checking $? still see the failure.
mc_l() {
    local rc
    media-ctl -l "$1"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  ^^ failed: media-ctl -l $1" >&2
    fi
    return "$rc"
}

mc_R() {
    local rc
    media-ctl -R "$1"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  ^^ failed: media-ctl -R $1" >&2
    fi
    return "$rc"
}

mc_v() {
    local rc
    media-ctl -V "$1"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "  ^^ failed: media-ctl -V $1" >&2
    fi
    return "$rc"
}

# -------- topology discovery --------------------------------------------------

# Per-DES MAX_LINKS (indexed by DES index 'd'), populated during discovery
# from MAX_LINKS_BY_PREFIX (declared in the USER CONFIGURATION block).
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

# Per-DES arrays (indexed by ACPI DESn number; indices may be sparse):
declare -a DES_PATH=() DES_BA=() DES_PREFIX_NAME=() DES_SRC_PAD=()
declare -a IPU_CSI2_ENTITY=() IPU_BASE=() CAPTURE_BASE=()
NUM_DES=0

# Per-link associative arrays keyed by "d_l" (deserializer index, link index):
declare -A SER_PATH=() CAM_PATH=()
declare -A SER_BA=()  CAM_BA=()
declare -A CAM_HID=() CAM_MODEL=() CAM_PREFIX=()
declare -A SER_PFX=()
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
    # DES_SRC_PAD[$d] is filled in later by detect_gmsl_csi2() based on the
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

        SER_PATH[$key]=$ser_path
        CAM_PATH[$key]=$cam_path
        SER_PFX[$key]=${SER_PREFIX[$ser_hid]}
        SER_BA[$key]=$(acpi_busaddr "$ser_dir" "${SER_PFX[$key]}") || {
            echo "WARN: DES${d} link ${i}: serializer at $ser_path has no v4l-subdev (driver loaded?); skipping" >&2
            unset 'SER_PATH[$key]' 'CAM_PATH[$key]' \
                  'SER_PFX[$key]' 'SER_BA[$key]'
            continue
        }
        CAM_PREFIX[$key]=${SENSOR_PREFIX[$cam_hid]}
        CAM_BA[$key]=$(acpi_busaddr "$cam_dir" "${CAM_PREFIX[$key]}") || {
            echo "WARN: DES${d} link ${i}: camera at $cam_path has no v4l-subdev (driver loaded?); skipping" >&2
            unset 'SER_PATH[$key]' 'CAM_PATH[$key]' \
                  'SER_PFX[$key]' 'SER_BA[$key]' \
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

    # Every deserializer ACPI path, ignoring DES_HID=/DES_BUSADDR=.
    local all_hid all_dir all_path
    for all_hid in "${!DES_PREFIX[@]}"; do
        for all_dir in /sys/bus/acpi/devices/${all_hid}:*; do
            [ -d "$all_dir" ] || continue
            all_path=$(cat "$all_dir/path" 2>/dev/null) || continue
            [ -n "$all_path" ] && ALL_DES_PATHS+=("$all_path")
        done
    done

    if [ "${#des_dirs[@]}" -gt 0 ]; then
        local d=0 dir des_path
        for dir in "${des_dirs[@]}"; do
            des_path=$(cat "$dir/path")
            if [[ $des_path =~ \.DES([0-9]+)$ ]]; then
                d=$((10#${BASH_REMATCH[1]}))
            fi
            discover_one_des "$d" "$dir"
            d=$((d + 1))
        done
        NUM_DES=${#DES_PATH[@]}
    fi
    if [ "$NUM_DES" -eq 0 ] && [ "${#des_dirs[@]}" -gt 0 ]; then
        echo "WARN: ${#des_dirs[@]} deserializer ACPI device(s) found" \
             "but none are usable (driver loaded?)" >&2
    fi
    # Discover direct MIPI cameras (skips sensors already behind a DES).
    discover_mipi_cameras
    [ "$NUM_DES" -gt 0 ] || [ "$NUM_MIPI" -gt 0 ] || {
        echo "ERROR: no deserializer or direct MIPI camera found" >&2
        return 1
    }
    return 0
}

# ---- Direct MIPI camera support ---------------------------------------------
declare -a MIPI_BA=() MIPI_PREFIX=() MIPI_MODEL=() MIPI_CSI2=() MIPI_CAP=()
declare -a MIPI_PATH=()
declare -a ALL_DES_PATHS=()
NUM_MIPI=0
# The direct MIPI cameras form one more camera group after the deserializers.
# -1 means there are none. mipi=N selects a camera in this group.
MIPI_GROUP=-1

discover_mipi_cameras() {
    local hid model prefix d ba path leaf idx count=0
    for hid in "${!MIPI_SENSOR_HID[@]}"; do
        for d in /sys/bus/acpi/devices/${hid}:*; do
            [ -d "$d" ] || continue
            # Skip sensors behind a deserializer, including one whose ACPI
            # device exists but couldn't be discovered (driver not bound, no
            # usable child): otherwise it would be misclassified as direct
            # MIPI and its serializer/deserializer bypassed entirely.
            path=$(cat "$d/path" 2>/dev/null) || continue
            local skip=0 di
            for di in "${!ALL_DES_PATHS[@]}"; do
                case "$path" in "${ALL_DES_PATHS[$di]}."*) skip=1; break ;; esac
            done
            [ "$skip" -eq 1 ] && continue

            # See doc/acpi/userspace-mipi.md for how mipi=N is numbered.
            leaf=${path##*.}            # "\_SB_.PC00.CAM1" -> "CAM1"
            if [[ $leaf =~ ^CAM([0-9]+)$ ]]; then
                idx=$((10#${BASH_REMATCH[1]}))
            else
                echo "WARN: cannot parse camera index from '${path}';" \
                     "expected a CAMn device; skipping" >&2
                continue
            fi
            if [ -n "${MIPI_PATH[$idx]:-}" ]; then
                echo "WARN: mipi=${idx} is already ${MIPI_PATH[$idx]};" \
                     "skipping ${path}" >&2
                continue
            fi

            model=${MIPI_SENSOR_HID[$hid]}
            prefix=${SENSOR_PREFIX[$hid]}
            ba=$(acpi_busaddr "$d" "$prefix") || continue
            MIPI_PATH[$idx]=$path
            MIPI_BA[$idx]=$ba; MIPI_PREFIX[$idx]=$prefix; MIPI_MODEL[$idx]=$model
            count=$((count + 1))
        done
    done

    NUM_MIPI=$count
    [ "$NUM_MIPI" -eq 0 ] && return 0

    # Register them in the per-camera tables the deserializer path uses, so
    # everything downstream of discovery treats both kinds the same. The
    # indices are the SSDT ones, so they can have gaps.
    # DES indices can be sparse (ACPI DESn numbers), so pick an index above
    # the highest one rather than NUM_DES, which could collide with a DES.
    MIPI_GROUP=0
    local di
    for di in "${!DES_PATH[@]}"; do
        [ "$di" -lt "$MIPI_GROUP" ] || MIPI_GROUP=$((di + 1))
    done
    local i key links=""
    for i in "${!MIPI_PATH[@]}"; do
        key="${MIPI_GROUP}_${i}"
        CAM_PATH[$key]=${MIPI_PATH[$i]}
        CAM_BA[$key]=${MIPI_BA[$i]}
        CAM_PREFIX[$key]=${MIPI_PREFIX[$i]}
        CAM_MODEL[$key]=${MIPI_MODEL[$i]}
        links+="${links:+ }$i"
    done
    LINKS_OF[$MIPI_GROUP]=$links
    echo "Discovered $NUM_MIPI direct MIPI camera(s)"
}

detect_mipi_csi2() {
    [ "$NUM_MIPI" -eq 0 ] && return 0
    local topo i cam csi2
    topo=$(media-ctl -p 2>/dev/null) || return 1
    for i in "${!MIPI_PATH[@]}"; do
        cam="${MIPI_PREFIX[$i]} ${MIPI_BA[$i]}"
        csi2=$(awk -v c="$cam" '
            /- entity.*: / { f = index($0, ": " c " (") ? 1 : 0 }
            f && /-> "Intel IPU[0-9]+ CSI2 [0-9]+"/ {
                gsub(/.*-> "|":.*/, "")
                print
                exit
            }
        ' <<<"$topo")
        [ -z "$csi2" ] && { echo "ERROR: no CSI2 link for $cam" >&2; return 1; }
        MIPI_CSI2[$i]=$csi2
        MIPI_CAP[$i]=$(capture_base_of_csi2 "$csi2" <<<"$topo")
        if [ -z "${MIPI_CAP[$i]}" ]; then
            echo "ERROR: MIPI${i}: could not find any 'ISYS Capture' entity linked from '$csi2'" >&2
            return 1
        fi
    done
}

# Program the direct MIPI cameras picked out of CFG_* by the argument parsing
# above. There is nothing to route on this path, the sensor feeds the CSI2
# receiver directly, so only the pad formats, the rate and the capture link are
# set here. Everything else is shared with the deserializer path: the same
# arguments, the same format, size and rate validation, and the same
# capture-node format step further down.
setup_mipi_cameras() {
    local k i model cam csi2 node fmt size s sid fps actual_fps ipu
    for k in "${!CFG_LINKS[@]}"; do
        [ "${CFG_DES[$k]}" = "$MIPI_GROUP" ] || continue
        i=${CFG_LINKS[$k]}
        model=${MIPI_MODEL[$i]}
        cam=${MIPI_BA[$i]}
        csi2=${MIPI_CSI2[$i]}
        node=${MIPI_CAP[$i]}
        ipu=${csi2% CSI2 *}
        # The CSI2 -> capture link belongs to the camera, not any one
        # stream, so enable it once here rather than once per stream below.
        mc_l "\"${csi2}\":1 -> \"${ipu} ISYS Capture ${node}\":0[1]" || \
            die "cannot enable capture link on MIPI${i}"
        for s in ${CFG_STREAMS[$k]}; do
            sid=${STREAM_NODE[$s]}
            fmt=${CFG_STREAM_FMT["${k}_${s}"]}
            size=${CFG_STREAM_SIZE["${k}_${s}"]}

            # Address pad and stream explicitly, as the deserializer path
            # does. The sensor emits on stream sid and the CSI2 sink takes it
            # there; the CSI2 source pad carries stream 0, one pad per
            # capture node.
            mc_v "\"${MIPI_PREFIX[$i]} ${cam}\":0/${sid} [fmt:${fmt}/${size} field:none]" || \
                die "cannot set sensor pad format on MIPI${i}, stream ${s}"
            mc_v "\"${csi2}\":0/${sid} [fmt:${fmt}/${size} field:none]" || \
                die "cannot set CSI2 sink format on MIPI${i}, stream ${s}"
            mc_v "\"${csi2}\":1/0 [fmt:${fmt}/${size} field:none]" || \
                die "cannot set CSI2 source format on MIPI${i}, stream ${s}"

            # Set the rate after the format, not before. A sensor picks a
            # new mode on S_FMT, so a rate applied first is still limited by
            # the OLD mode: switching from 1280x720 (30fps max) and asking
            # for 1920x1536@60 would clamp to 30 if the rate went first.
            fps=${CFG_STREAM_FPS["${k}_${s}"]}
            if [ -n "${CFG_STREAM_FPS_APPLY["${k}_${s}"]:-}" ] &&
                [[ $fps =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                actual_fps=$(sensor_set_fps "$model" "$cam" "$s" "$sid" \
                    "$fps" "MIPI${i} stream ${s}") || \
                    die "cannot configure FPS on MIPI${i}, stream ${s}"
                CFG_STREAM_FPS["${k}_${s}"]=$actual_fps
            fi
        done
    done
}

# Name a camera for messages the way it is selected on the command line: a
# GMSL camera by its deserializer and link, a direct MIPI camera by its own
# number.
cam_label() {
    if [ "$1" = "$MIPI_GROUP" ]; then echo "MIPI$2"; else echo "DES$1 link $2"; fi
}

# For each DES, locate the "Intel IPUx CSI2 N" entity wired to its source
# pad, the DES source pad number itself (which mirrors DES_CSI_LOCAL_PORT in
# the SSDT CSI2Bus resource), and the absolute capture-node base (lowest
# "ISYS Capture <N>" index linked to that CSI2). The DES->CSI2 link is
# IMMUTABLE so the live media topology is the source of truth.
detect_gmsl_csi2() {
    local topo
    topo=$(media-ctl -p 2>/dev/null) || {
        echo "ERROR: failed to read media topology via 'media-ctl -p'" >&2
        return 1
    }
    local d des_entity csi2 src_pad base line
    for d in "${!DES_PATH[@]}"; do
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

        CAPTURE_BASE[$d]=$(capture_base_of_csi2 "$csi2" <<<"$topo")
        if [ -z "${CAPTURE_BASE[$d]}" ]; then
            echo "ERROR: DES${d}: could not find any 'ISYS Capture' entity linked from '$csi2'" >&2
            return 1
        fi
    done
    return 0
}

# -------- pretty print --------------------------------------------------------

print_topology() {
    echo "Discovered topology:"
    local d l key
    for d in "${!DES_PATH[@]}"; do
        printf "  DES%d  %-34s %s %s -> %s (capture base /dev/video%s)\n" \
            "$d" "${DES_PATH[$d]}" "${DES_PREFIX_NAME[$d]}" "${DES_BA[$d]}" \
            "${IPU_CSI2_ENTITY[$d]}" "${CAPTURE_BASE[$d]}"
        for l in ${LINKS_OF[$d]}; do
            key="${d}_${l}"
            printf "    SER%d  %-34s %s %s\n" \
                "$l" "${SER_PATH[$key]}" "${SER_PFX[$key]}" "${SER_BA[$key]}"
            printf "    CAM%d  %-34s %s %s  (model=%s, hid=%s)\n" \
                "$l" "${CAM_PATH[$key]}" "${CAM_PREFIX[$key]}" "${CAM_BA[$key]}" \
                "${CAM_MODEL[$key]}" "${CAM_HID[$key]}"
        done
    done
    [ "$NUM_MIPI" -eq 0 ] \
        || echo "  Direct MIPI cameras (select with mipi=N):"
    for i in "${!MIPI_PATH[@]}"; do
        printf "  MIPI%d  %s %s -> %s (capture /dev/video%s)\n" \
            "$i" "${MIPI_PREFIX[$i]}" "${MIPI_BA[$i]}" \
            "${MIPI_CSI2[$i]}" "${MIPI_CAP[$i]}"
    done
    echo ""
}

# -------- per-sensor media-ctl programming -----------------------------------
#
# CLI:
#     mc-setup.sh                                      # default per-model streams, all DES
#
# Sample syntax (Items in [] are optional.)
#     mc-setup.sh [des=D,]link=N[,stream=<csv>][,res=WxH][,format=MBUS_CODE][,fps=FPS]
#
# Sample Single Stream Use Case can omit stream.
#     mc-setup.sh des=D,link=N,res=WxH,format=MBUS_CODE,fps=FPS
#
# Sample Multi Stream Use Case
#     mc-setup.sh des=D,link=N,stream=[TOKEN,res=WxH,format=MBUS_CODE,fps=FPS],\
#                                      [TOKEN,res=WxH,format=MBUS_CODE,fps=FPS] ...
#
# TOKEN is only applicable for multi-stream sensors as specified in MODEL_STREAMS.
# Other 2D sensors do not need stream=<csv>, they default to `single`.
#
# D4xx defaults to depth,rgb when no stream is specified.
#
# When des= is omitted, des=0 is assumed (matches the legacy single-DES CLI).
#
# Sample MIPI Camera Use Case
#     mc-setup.sh mipi=N,res=WxH,format=MBUS_CODE,fps=FPS
#
# Sample MIPI x GMSL Use Case
#     mc-setup.sh des=0,link=0 mipi=1,res=1920x1536,fps=60
#
# Capture-node layout (per DES):
#     csi2_pad = STREAM_CAPTURE_BASE[s] +
#                 ((l + STREAM_LINK_ROTATION[s]) % CSI2_NODE_BANK_SIZE)
#     node     = CAPTURE_BASE[d] + csi2_pad
# This places each stream in its configured capture bank and rotates selected
# streams across links using the permutation documented above. Streams that
# resolve to the same node cannot be enabled together and are rejected. For
# 1-stream sensors like isx031, links land on base+0..3 directly. The CSI2 RX
# cap is IPU*_NR_OF_CSI2_SRC_PADS; set IPU_CSI2_SRC_PADS to match (commonly 8
# or 16).
#
# v4l2 source_stream tag at the deserializer source pad / CSI2 sink pad is
# allocated separately as a compact per-DES sequential id (0..3), because
# max96724 / max_des bound the per-pipe stream-id field at 2 bits
# (MAX_SERDES_STREAMS_NUM=4). The csi2_pad above is only used as the CSI2
# *source* pad index (i.e. capture-node selector).

# =============================================================================
# Per-sensor stream lookups
# =============================================================================

sensor_entity_pad() {
    local model=$1 cam=$2 stream=$3 sid=$4

    case "$model" in
        d4xx)   SENSOR_ENTITY="D4XX ${stream} ${cam}"; SENSOR_PAD=0; SENSOR_SID=0 ;;
        isx031) SENSOR_ENTITY="isx031 ${cam}"; SENSOR_PAD=0; SENSOR_SID=$sid ;;
        ar0234) SENSOR_ENTITY="ar0234 ${cam}"; SENSOR_PAD=0; SENSOR_SID=$sid ;;
        ov13b10) SENSOR_ENTITY="ov13b10 ${cam}"; SENSOR_PAD=0; SENSOR_SID=0 ;;
        *) return 1 ;;
    esac
}

# Query one sensor source pad and print "<mbus-code> <width>x<height>".
sensor_active_format() {
    local model=$1 cam=$2 stream=$3 sid=$4 output fmt size

    sensor_entity_pad "$model" "$cam" "$stream" "$sid" || return 1
    output=$(media-ctl --get-v4l2 \
        "\"${SENSOR_ENTITY}\":${SENSOR_PAD}/${SENSOR_SID}" 2>/dev/null) || return 1
    if [[ $output =~ fmt:([[:alnum:]_]+)/([0-9]+x[0-9]+) ]]; then
        fmt=${BASH_REMATCH[1]}
        size=${BASH_REMATCH[2]}
        echo "$fmt $size"
        return 0
    fi
    return 1
}

sensor_active_fps() {
    local model=$1 cam=$2 stream=$3 sid=$4 dev output

    sensor_entity_pad "$model" "$cam" "$stream" "$sid" || return 1
    dev=$(media-ctl -e "$SENSOR_ENTITY" 2>/dev/null) || return 1
    output=$(v4l2-ctl -d "$dev" --get-subdev-fps \
        pad="$SENSOR_PAD",stream="$SENSOR_SID" 2>/dev/null) || return 1
    if [[ $output =~ Frames[[:space:]]per[[:space:]]second:[[:space:]]([0-9.]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Print the requested format/size after checking the sensor's advertised
# format-resolution combinations. Retain the active format when unsupported;
# use the largest resolution advertised for a supported format.
sensor_validate_format_size() {
    local model=$1 cam=$2 stream=$3 sid=$4 requested_fmt=$5 requested_size=$6
    local active_fmt=$7 active_size=$8 context=$9 dev codes line code name
    local selected_fmt selected_size selected_code sizes supported
    local min_w min_h max_w max_h req_w req_h largest_w largest_h
    local area largest_area=0
    local range_re

    range_re='Size[[:space:]]Range:[[:space:]]([0-9]+)x([0-9]+)'
    range_re+='[[:space:]]-[[:space:]]([0-9]+)x([0-9]+)'

    selected_fmt=${requested_fmt:-$active_fmt}
    selected_size=${requested_size:-$active_size}
    sensor_entity_pad "$model" "$cam" "$stream" "$sid" || return 1
    dev=$(media-ctl -e "$SENSOR_ENTITY" 2>/dev/null) || {
        echo "$selected_fmt $selected_size"
        return 0
    }

    codes=$(v4l2-ctl -d "$dev" --list-subdev-mbus-codes \
        pad="$SENSOR_PAD",stream="$SENSOR_SID" 2>/dev/null) || {
        echo "$selected_fmt $selected_size"
        return 0
    }
    while IFS= read -r line; do
        if [[ $line =~ (0x[[:xdigit:]]+):[[:space:]]+MEDIA_BUS_FMT_([[:alnum:]_]+) ]]; then
            code=${BASH_REMATCH[1]}
            name=${BASH_REMATCH[2]^^}
            if [ "$name" = "${selected_fmt^^}" ]; then
                selected_code=$code
                selected_fmt=$name
            fi
        fi
    done <<<"$codes"

    if [ -z "$selected_code" ]; then
        [ -z "$requested_fmt" ] || printf \
            "WARN: %s: format '%s' is unsupported; retaining current active format '%s'\n" \
            "$context" "$requested_fmt" "$active_fmt" >&2
        selected_fmt=$active_fmt
        while IFS= read -r line; do
            if [[ $line =~ (0x[[:xdigit:]]+):[[:space:]]+MEDIA_BUS_FMT_([[:alnum:]_]+) ]]; then
                code=${BASH_REMATCH[1]}
                name=${BASH_REMATCH[2]^^}
                [ "$name" = "${active_fmt^^}" ] && selected_code=$code
            fi
        done <<<"$codes"
    fi

    if [ -n "$requested_size" ] && [ -n "$selected_code" ]; then
        sizes=$(v4l2-ctl -d "$dev" --list-subdev-framesizes \
            pad="$SENSOR_PAD",stream="$SENSOR_SID",code="$selected_code" 2>/dev/null) || sizes=""
        supported=0
        while IFS= read -r line; do
            if [[ $line =~ $range_re ]]; then
                min_w=${BASH_REMATCH[1]}; min_h=${BASH_REMATCH[2]}
                max_w=${BASH_REMATCH[3]}; max_h=${BASH_REMATCH[4]}
                area=$(( max_w * max_h ))
                if (( area > largest_area )); then
                    largest_area=$area
                    largest_w=$max_w
                    largest_h=$max_h
                fi
                req_w=${requested_size%x*}; req_h=${requested_size#*x}
                if (( req_w >= min_w && req_w <= max_w && req_h >= min_h && req_h <= max_h )); then
                    supported=1
                fi
            elif [[ $line =~ Size:[[:space:]]Discrete[[:space:]]([0-9]+)x([0-9]+) ]]; then
                max_w=${BASH_REMATCH[1]}; max_h=${BASH_REMATCH[2]}
                area=$(( max_w * max_h ))
                if (( area > largest_area )); then
                    largest_area=$area
                    largest_w=$max_w
                    largest_h=$max_h
                fi
                req_w=${requested_size%x*}; req_h=${requested_size#*x}
                if (( req_w == max_w && req_h == max_h )); then
                    supported=1
                fi
            fi
        done <<<"$sizes"
        if [ -n "$sizes" ] && (( ! supported )); then
            printf "WARN: %s: resolution '%s' is unsupported with format '%s'; " \
                "$context" "$requested_size" "$selected_fmt" >&2
            if (( largest_area > 0 )); then
                selected_size="${largest_w}x${largest_h}"
                printf "using largest supported resolution '%s'\n" "$selected_size" >&2
            else
                printf "retaining current active resolution '%s'\n" "$active_size" >&2
                selected_size=$active_size
            fi
        fi
    fi

    echo "$selected_fmt $selected_size"
}

sensor_validate_fps() {
    local model=$1 cam=$2 stream=$3 sid=$4 fmt=$5 size=$6
    local requested_fps=$7 active_fps=$8 context=$9 dev codes line code name
    local format_size_changed=${10}
    local interval_args intervals candidate selected_fps max_fps supported=0

    selected_fps=${requested_fps:-$active_fps}
    sensor_entity_pad "$model" "$cam" "$stream" "$sid" || return 1
    dev=$(media-ctl -e "$SENSOR_ENTITY" 2>/dev/null) || {
        echo "$selected_fps"
        return
    }
    codes=$(v4l2-ctl -d "$dev" --list-subdev-mbus-codes \
        pad="$SENSOR_PAD",stream="$SENSOR_SID" 2>/dev/null) || {
        echo "$selected_fps"
        return
    }
    while IFS= read -r line; do
        if [[ $line =~ (0x[[:xdigit:]]+):[[:space:]]+MEDIA_BUS_FMT_([[:alnum:]_]+) ]]; then
            name=${BASH_REMATCH[2]^^}
            [ "$name" = "${fmt^^}" ] && code=${BASH_REMATCH[1]}
        fi
    done <<<"$codes"
    [ -n "$code" ] || { echo "$selected_fps"; return; }

    interval_args="pad=${SENSOR_PAD},stream=${SENSOR_SID},code=${code}"
    interval_args+=",width=${size%x*},height=${size#*x}"
    intervals=$(v4l2-ctl -d "$dev" --list-subdev-frameintervals \
        "$interval_args" 2>/dev/null) || intervals=""
    [ -n "$intervals" ] || { echo "$selected_fps"; return; }
    while IFS= read -r line; do
        if [[ $line =~ \(([0-9.]+)[[:space:]]fps\) ]]; then
            candidate=${BASH_REMATCH[1]}
            if [ -z "$max_fps" ] || awk -v a="$candidate" -v b="$max_fps" \
                'BEGIN { exit !(a > b) }'; then
                max_fps=$candidate
            fi
            awk -v a="$candidate" -v b="$selected_fps" \
                'BEGIN { exit !((a - b < 0.0005) && (b - a < 0.0005)) }' && {
                selected_fps=$candidate
                supported=1
            }
        fi
    done <<<"$intervals"
    if (( format_size_changed )) && [ -z "$requested_fps" ] && [ -n "$max_fps" ]; then
        selected_fps=$max_fps
    elif (( ! supported )) && [ -n "$max_fps" ]; then
        # An unsupported rate always falls back to the mode's fastest one,
        # whether or not format/size changed; the active FPS is only a
        # starting point, not a safe fallback for a new request.
        [ -z "$requested_fps" ] || printf \
            "WARN: %s: FPS '%s' is unsupported with %s/%s; " \
            "$context" "$requested_fps" "$fmt" "$size" >&2
        [ -z "$requested_fps" ] || printf "using largest supported FPS '%s'\n" \
            "$max_fps" >&2
        selected_fps=$max_fps
    fi
    echo "$selected_fps"
}

sensor_set_fps() {
    local model=$1 cam=$2 stream=$3 sid=$4 fps=$5 context=$6 dev output

    sensor_entity_pad "$model" "$cam" "$stream" "$sid" || return 1
    dev=$(media-ctl -e "$SENSOR_ENTITY" 2>/dev/null) || return 1
    v4l2-ctl -d "$dev" --set-subdev-fps \
        pad="$SENSOR_PAD",stream="$SENSOR_SID",fps="$fps" >/dev/null \
        || { echo "WARN: ${context}: failed to set FPS '${fps}'" >&2; return 1; }
    output=$(v4l2-ctl -d "$dev" --get-subdev-fps \
        pad="$SENSOR_PAD",stream="$SENSOR_SID" 2>/dev/null) || return 1
    [[ $output =~ Frames[[:space:]]per[[:space:]]second:[[:space:]]([0-9.]+) ]] \
        || return 1
    echo "${BASH_REMATCH[1]}"
}

# Is stream token $1 selectable for model $2?
stream_valid_for_model() {
    local s=$1 streams=${MODEL_STREAMS[$2]:-} t
    [ -n "$streams" ] || return 1
    for t in $streams; do
        [ "$t" = "$s" ] && return 0
    done
    return 1
}

# Is $1 a known stream token (in any model)?
is_known_stream() { [ -n "${STREAM_NODE[$1]+x}" ]; }

die() { echo "ERROR: $*" >&2; exit 1; }

check_media_tools() {
    local missing=() tool
    for tool in media-ctl v4l2-ctl; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    [ "${#missing[@]}" -eq 0 ] && return 0

    echo "Missing required command(s): ${missing[*]}; installing v4l-utils..." >&2
    command -v apt-get >/dev/null 2>&1 \
        || die "apt-get not found; install v4l-utils manually"

    local apt=(apt-get)
    if (( EUID != 0 )); then
        command -v sudo >/dev/null 2>&1 \
            || die "root privileges are required to install v4l-utils"
        apt=(sudo apt-get)
    fi
    "${apt[@]}" install -y v4l-utils \
        || die "failed to install v4l-utils"

    for tool in media-ctl v4l2-ctl; do
        command -v "$tool" >/dev/null 2>&1 \
            || die "$tool is still unavailable after installing v4l-utils"
    done
}

# Require media-ctl >= 1.30 (older releases lack the streams/routing API used here).
check_media_ctl_version() {
    local required_major=1 required_minor=30

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

check_media_tools
check_media_ctl_version
discover || exit 1

[ "$NUM_DES"  -gt 0 ] && { detect_gmsl_csi2 || exit 1; }
[ "$NUM_MIPI" -gt 0 ] && { detect_mipi_csi2 || exit 1; }
print_topology

# ---- argument parsing ------------------------------------------------------
#
# Parse arguments for both GMSL and MIPI setups.

declare -a CFG_DES=()
declare -a CFG_LINKS=()
declare -a CFG_STREAMS=()
declare -a CFG_RES=()
declare -a CFG_FORMAT=()
declare -a CFG_FPS=()
declare -A CFG_STREAM_RES=()
declare -A CFG_STREAM_FORMAT=()
declare -A CFG_STREAM_FPS_REQUEST=()

# Camera groups: the usable deserializers (indices can be sparse) plus the
# direct MIPI one.
declare -a GROUP_IDS=("${!DES_PATH[@]}")
[ "$MIPI_GROUP" -ge 0 ] && GROUP_IDS+=("$MIPI_GROUP")

if [ "$#" -eq 0 ]; then
    # Default: program every discovered link with its default or fixed stream.
    for g in "${GROUP_IDS[@]}"; do
        for l in ${LINKS_OF[$g]}; do
            key="${g}_${l}"
            CFG_DES+=("$g")
            CFG_LINKS+=("$l")
            model=${CAM_MODEL[$key]}
            streams=${MODEL_DEFAULT_STREAMS[$model]:-}
            [ -n "$streams" ] || streams=$(fixed_stream_for_model "$model") \
                || die "no stream configuration for $model"
            CFG_STREAMS+=("$streams")
            CFG_RES+=("")
            CFG_FORMAT+=("")
            CFG_FPS+=("")
        done
    done
else
    for arg in "$@"; do
        des=""; link=""; streams=""; res=""; format=""; fps=""; mipi_sel=""
        declare -A arg_stream_res=()
        declare -A arg_stream_format=()
        declare -A arg_stream_fps=()

        # Parse bracketed per-stream settings before splitting the remaining
        # link-level options on commas.
        if [[ $arg == *",stream=["* ]]; then
            stream_specs=${arg#*,stream=}
            arg=${arg%%,stream=*}
            while [ -n "$stream_specs" ]; do
                stream_specs=${stream_specs#"${stream_specs%%[![:space:]]*}"}
                if [[ $stream_specs =~ ^\[([^][]+)\](,(.*))?$ ]]; then
                    stream_spec=${BASH_REMATCH[1]}
                    stream_specs=${BASH_REMATCH[3]}
                else
                    die "invalid bracketed stream specification in '$stream_specs'"
                fi

                IFS=',' read -ra stream_parts <<<"$stream_spec"
                for stream_part_idx in "${!stream_parts[@]}"; do
                    stream_part=${stream_parts[$stream_part_idx]}
                    stream_part=${stream_part#"${stream_part%%[![:space:]]*}"}
                    stream_parts[$stream_part_idx]=${stream_part%"${stream_part##*[![:space:]]}"}
                done
                s=${stream_parts[0]}
                is_known_stream "$s" || die "unknown stream '$s' in '$stream_spec'"
                [ -z "${arg_stream_res[$s]+x}" ] && \
                    [ -z "${arg_stream_format[$s]+x}" ] && \
                    [[ " $streams " != *" $s "* ]] \
                    || die "stream '$s' specified more than once"
                streams+="${streams:+ }$s"
                for stream_kv in "${stream_parts[@]:1}"; do
                    case "$stream_kv" in
                        res=*)
                            arg_stream_res[$s]=${stream_kv#res=}
                            [[ ${arg_stream_res[$s]} =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] \
                                || die "res must be a nonzero WIDTHxHEIGHT" \
                                       "(got '${arg_stream_res[$s]}')"
                            ;;
                        format=*)
                            arg_stream_format[$s]=${stream_kv#format=}
                            [[ ${arg_stream_format[$s]} =~ ^[[:alnum:]_]+$ ]] \
                                || die "format must be a media-bus code" \
                                    "(got '${arg_stream_format[$s]}')"
                            ;;
                        fps=*)
                            arg_stream_fps[$s]=${stream_kv#fps=}
                            [[ ${arg_stream_fps[$s]} =~ ^[0-9]+([.][0-9]+)?$ ]] \
                                || die "fps must be numeric (got '${arg_stream_fps[$s]}')"
                            ! [[ ${arg_stream_fps[$s]} =~ ^0+([.]0*)?$ ]] \
                                || die "fps must be greater than zero" \
                                       "(got '${arg_stream_fps[$s]}')"
                            ;;
                        *) die "unrecognized stream option '$stream_kv' in '$stream_spec'" ;;
                    esac
                done
            done
        fi

        IFS=',' read -ra parts <<<"$arg"
        for kv in "${parts[@]}"; do
            case "$kv" in
                des=*)
                    [ -z "$mipi_sel" ] \
                        || die "des= and mipi= cannot be combined in '$arg'"
                    des=${kv#des=}
                    ;;
                link=*)
                    [ -z "$mipi_sel" ] \
                        || die "link= does not apply to mipi= in '$arg'"
                    link=${kv#link=}
                    ;;
                mipi=*)
                    [ -z "$des" ] \
                        || die "des= and mipi= cannot be combined in '$arg'"
                    [ -z "$link" ] \
                        || die "link= does not apply to mipi= in '$arg'"
                    mipi_sel=${kv#mipi=}
                    [[ $mipi_sel =~ ^[0-9]+$ ]] \
                        || die "mipi must be numeric (got '$mipi_sel')"
                    mipi_sel=$((10#$mipi_sel))
                    # Reuse the same des/link pair GMSL uses internally, so
                    # every check and table below treats mipi=N as one more
                    # camera group.
                    des=$MIPI_GROUP
                    link=$mipi_sel
                    ;;
                stream=*) streams+="${streams:+ }${kv#stream=}" ;;
                res=*)    res=${kv#res=} ;;
                format=*) format=${kv#format=} ;;
                fps=*)    fps=${kv#fps=} ;;
                *)
                    if is_known_stream "$kv"; then
                        streams+="${streams:+ }$kv"
                    else
                        die "unrecognized token '$kv' in '$arg'"
                    fi
                    ;;
            esac
        done
        [ -n "$link" ]    || die "missing link= or mipi= in '$arg'"
        [[ $link =~ ^[0-9]+$ ]] || die "link must be numeric (got '$link')"
        [ -z "$res" ] || [[ $res =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] \
            || die "res must be a nonzero WIDTHxHEIGHT (got '$res')"
        [ -z "$format" ] || [[ $format =~ ^[[:alnum:]_]+$ ]] \
            || die "format must be a media-bus code (got '$format')"
        if [ -n "$fps" ]; then
            [[ $fps =~ ^[0-9]+([.][0-9]+)?$ ]] \
                || die "fps must be numeric (got '$fps')"
            ! [[ $fps =~ ^0+([.]0*)?$ ]] \
                || die "fps must be greater than zero (got '$fps')"
        fi
        # mipi= already named the camera. Otherwise this is a deserializer
        # camera: default to the sole usable DES when des= was omitted.
        if [ -z "$mipi_sel" ]; then
            if [ "$NUM_DES" -eq 0 ]; then
                die "no deserializer on this board; use mipi=N to select a" \
                    "direct MIPI camera (in '$arg')"
            fi
            if [ -z "$des" ]; then
                [ "$NUM_DES" -le 1 ] || die "des= required when multiple" \
                    "deserializers are present (in '$arg')"
                des=${!DES_PATH[@]}
            fi
            [[ $des =~ ^[0-9]+$ ]] || die "des must be numeric (got '$des')"
            [ -n "${DES_PATH[$des]:-}" ] || die \
                "des=$des not available (usable DES indices: ${!DES_PATH[*]})"
        fi
        clabel=$(cam_label "$des" "$link")
        key="${des}_${link}"
        [ -n "${CAM_MODEL[$key]:-}" ] \
            || die "no camera discovered at ${clabel}"
        model=${CAM_MODEL[$key]}
        if [ -n "${MODEL_STREAMS[$model]:-}" ]; then
            [ -n "$streams" ] || streams=${MODEL_DEFAULT_STREAMS[$model]}
            for s in $streams; do
                stream_valid_for_model "$s" "$model" \
                    || die "stream '$s' invalid for $model at ${clabel}"
            done
        else
            fixed_stream=$(fixed_stream_for_model "$model") \
                || die "no stream configuration for $model"
            if [ -n "$streams" ] && [ "$streams" != "$fixed_stream" ]; then
                echo "WARN: $model at ${clabel}: replacing requested" \
                    "stream '$streams' with fixed stream '$fixed_stream'" >&2
                # Move the bracketed values to the fixed name so a stream
                # named something else does not drop the res, format and fps
                # that came with it.
                for s in $streams; do
                    [ -z "${arg_stream_res[$s]+x}" ] \
                        || arg_stream_res[$fixed_stream]=${arg_stream_res[$s]}
                    [ -z "${arg_stream_format[$s]+x}" ] \
                        || arg_stream_format[$fixed_stream]=${arg_stream_format[$s]}
                    [ -z "${arg_stream_fps[$s]+x}" ] \
                        || arg_stream_fps[$fixed_stream]=${arg_stream_fps[$s]}
                done
            fi
            streams=$fixed_stream
        fi
        CFG_DES+=("$des")
        CFG_LINKS+=("$link")
        CFG_STREAMS+=("$streams")
        CFG_RES+=("$res")
        CFG_FORMAT+=("$format")
        CFG_FPS+=("$fps")
        k=$((${#CFG_LINKS[@]} - 1))
        for s in $streams; do
            CFG_STREAM_RES["${k}_${s}"]=${arg_stream_res[$s]:-}
            CFG_STREAM_FORMAT["${k}_${s}"]=${arg_stream_format[$s]:-}
            CFG_STREAM_FPS_REQUEST["${k}_${s}"]=${arg_stream_fps[$s]:-${CFG_FPS[$k]}}
        done
        unset arg_stream_res arg_stream_format arg_stream_fps
    done
    # Reject duplicate (group,link) entries.
    declare -A seen=()
    for k in "${!CFG_LINKS[@]}"; do
        sk="${CFG_DES[$k]}_${CFG_LINKS[$k]}"
        [ -z "${seen[$sk]:-}" ] \
            || die "$(cam_label "${CFG_DES[$k]}" "${CFG_LINKS[$k]}")" \
                   "specified more than once"
        seen[$sk]=1
    done
fi

# Resolve and validate each selected stream's format, size and FPS. An
# unsupported requested FPS always falls back to the largest FPS advertised
# for the mode. An omitted FPS keeps the active rate unless format/size
# changed, in which case it also uses the mode's largest FPS.
declare -A CFG_STREAM_FMT=()
declare -A CFG_STREAM_PIXFMT=()
declare -A CFG_STREAM_SIZE=()
declare -A CFG_STREAM_FPS=()
declare -A CFG_STREAM_FPS_APPLY=()
for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    clabel=$(cam_label "$d" "$l")
    model=${CAM_MODEL[$key]}
    cam=${CAM_BA[$key]}
    for s in ${CFG_STREAMS[$k]}; do
        sid=${STREAM_NODE[$s]}
        requested_fmt=${CFG_STREAM_FORMAT["${k}_${s}"]:-${CFG_FORMAT[$k]}}
        requested_size=${CFG_STREAM_RES["${k}_${s}"]:-${CFG_RES[$k]}}
        # Pick a rate whenever the format or size was asked for, not only when
        # fps= was given. The rate left over from the old mode is not always
        # the best the new one can do, and sensor_validate_fps() answers a
        # change with the mode's top rate.
        if [ -n "$requested_fmt" ] || [ -n "$requested_size" ] ||
            [ -n "${CFG_STREAM_FPS_REQUEST["${k}_${s}"]}" ]; then
            CFG_STREAM_FPS_APPLY["${k}_${s}"]=1
        fi
        detected=$(sensor_active_format "$model" "$cam" "$s" "$sid") || \
            die "cannot read active format from ${model} sensor on" \
                "${clabel}, stream ${s}"
        read -r detected_fmt detected_size <<<"$detected"
        validated=$(sensor_validate_format_size "$model" "$cam" "$s" "$sid" \
            "$requested_fmt" "$requested_size" "$detected_fmt" "$detected_size" \
            "${clabel} stream ${s}")
        read -r selected_fmt CFG_STREAM_SIZE["${k}_${s}"] <<<"$validated"
        CFG_STREAM_PIXFMT["${k}_${s}"]=$(mbus_to_pixfmt "$selected_fmt")
        format_key="${model}_${s}_${selected_fmt}"
        CFG_STREAM_FMT["${k}_${s}"]=${STREAM_FORMAT_MAP[$format_key]:-$selected_fmt}
        format_size_changed=0
        if [ "${CFG_STREAM_FMT["${k}_${s}"]}" != "$detected_fmt" ] || \
            [ "${CFG_STREAM_SIZE["${k}_${s}"]}" != "$detected_size" ]; then
            format_size_changed=1
        fi
        active_fps=$(sensor_active_fps "$model" "$cam" "$s" "$sid") || active_fps=""
        if [ -n "$active_fps" ]; then
            CFG_STREAM_FPS["${k}_${s}"]=$(sensor_validate_fps \
                "$model" "$cam" "$s" "$sid" \
                "${CFG_STREAM_FMT["${k}_${s}"]}" \
                "${CFG_STREAM_SIZE["${k}_${s}"]}" \
                "${CFG_STREAM_FPS_REQUEST["${k}_${s}"]}" "$active_fps" \
                "${clabel} stream ${s}" "$format_size_changed")
        else
            [ -z "${CFG_STREAM_FPS_REQUEST["${k}_${s}"]}" ] || \
                echo "WARN: ${clabel} stream ${s}: FPS control unavailable" >&2
            CFG_STREAM_FPS["${k}_${s}"]="n/a"
            CFG_STREAM_FPS_REQUEST["${k}_${s}"]=""
        fi
    done
done

# IPU7 CSI2 RX source-pad cap (16 with the D4XX patch, 8 otherwise).
IPU_CSI2_SRC_PADS=${IPU_CSI2_SRC_PADS:-16}

# Compute csi2_pad per (cfg_index, stream) using the configured capture bank
# and link rotation. For isx031 this collapses to csi2_pad == link.
declare -A CSI2_PAD=()
declare -A CSI2_PAD_OWNER=()
# Compact v4l2 source_stream id assigned to each (cfg_index, stream) at the
# deserializer source pad and at the CSI2 sink pad. The kernel-side max96724
# / max_des state machine bounds the per-pipe stream-id field at 2 bits
# (MAX_SERDES_STREAMS_NUM=4), so any v4l2 source_stream tag >=4 trips an
# EINVAL on set_fmt. We therefore allocate per-DES sequential ids 0..3
# independent of the (larger) csi2_pad values used downstream.
declare -A DES_STREAM=()
declare -A DES_STREAM_NEXT=()
for k in "${!CFG_LINKS[@]}"; do
    # A direct MIPI camera owns its CSI2 receiver, so it has no pad to place
    # and no source_stream to allocate. Its capture node comes from discovery.
    [ "${CFG_DES[$k]}" != "$MIPI_GROUP" ] || continue
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    for s in ${CFG_STREAMS[$k]}; do
        pad=$(( STREAM_CAPTURE_BASE[$s] +
            (l + STREAM_LINK_ROTATION[$s]) % CSI2_NODE_BANK_SIZE ))
        if (( pad >= IPU_CSI2_SRC_PADS )); then
            die "DES${d} link ${l} stream ${s}: csi2_pad ${pad} exceeds CSI2 src-pad cap "\
            "(${IPU_CSI2_SRC_PADS}); reduce active links/streams or rebuild the kernel with a "\
            "higher *_NR_OF_CSI2_SRC_PADS"
        fi
        pad_key="${d}_${pad}"
        if [ -n "${CSI2_PAD_OWNER[$pad_key]:-}" ]; then
            die "DES${d} link ${l} stream ${s}: capture node offset ${pad} conflicts with "\
            "${CSI2_PAD_OWNER[$pad_key]}"
        fi
        CSI2_PAD_OWNER[$pad_key]="link ${l} stream ${s}"
        CSI2_PAD["${k}_${s}"]=$pad

        ds=${DES_STREAM_NEXT[$d]:-0}
        if (( ds >= 4 )); then
            die "DES${d}: too many streams routed through deserializer source pad (maxim-serdes "\
            "supports 4 unique source_streams)"
        fi
        DES_STREAM["${k}_${s}"]=$ds
        DES_STREAM_NEXT[$d]=$(( ds + 1 ))
    done
done

# Reset all media links and per-stream pad state so we don't inherit formats
# or enabled-link flags from a prior run with a different layout. The sensor
# to CSI2 link of a direct MIPI camera is IMMUTABLE and survives this; its
# CSI2 to capture link does not, so restore it for every discovered camera
# here, including ones not named on the command line. A selected camera's
# own pass through setup_mipi_cameras() below just re-enables the same link.
media-ctl -r 2>/dev/null || true

for i in "${!MIPI_PATH[@]}"; do
    ipu=${MIPI_CSI2[$i]% CSI2 *}
    mc_l "\"${MIPI_CSI2[$i]}\":1 -> \"${ipu} ISYS Capture ${MIPI_CAP[$i]}\":0[1]" || \
        die "cannot restore capture link on MIPI${i}"
done

# Direct MIPI cameras have no routes or deserializer pass to wait on, so
# program them now: CFG_STREAM_FPS gets the sensor's actual accepted rate
# before the summary below prints it, instead of the pre-programming
# candidate from sensor_validate_fps.
setup_mipi_cameras

echo -e "\nConfiguration summary:"
for k in "${!CFG_LINKS[@]}"; do
    d=${CFG_DES[$k]}
    l=${CFG_LINKS[$k]}
    key="${d}_${l}"
    if [ "$d" = "$MIPI_GROUP" ]; then
        printf "  %-10s\t Sensor model\t %s\n" "MIPI${l}" "${CAM_MODEL[$key]}"
    else
        printf "  %-10s\t Sensor model\t %s\n" "DES${d} LINK${l}" "${CAM_MODEL[$key]}"
    fi
    for s in ${CFG_STREAMS[$k]}; do
        if [ "$d" = "$MIPI_GROUP" ]; then
            node=${MIPI_CAP[$l]}
        else
            node=$(( CAPTURE_BASE[d] + CSI2_PAD["${k}_${s}"] ))
        fi
        printf "                 Stream          %-8s %-10s %-12s %7s FPS -->  /dev/video%s\n" \
            "[${s}]" "${CFG_STREAM_SIZE["${k}_${s}"]}" \
            "${CFG_STREAM_FMT["${k}_${s}"]}" \
            "${CFG_STREAM_FPS["${k}_${s}"]}" "$node"
    done
done

# ---- programming -----------------------------------------------------------

# Per-DES route accumulators (the kernel resets per-stream pad formats whenever
# routes are (re)programmed, so all -R must precede any -V).
declare -A DES_ROUTES=()
declare -A CSI2_ROUTES=()

# --- pass 1: per-link source-side routes (mux/serializer), and accumulate
#             per-DES deserializer/CSI2 routes. Direct MIPI cameras have no
#             serializer or deserializer to route and are skipped here;
#             setup_mipi_cameras() programs them further down.
for k in "${!CFG_LINKS[@]}"; do
    [ "${CFG_DES[$k]}" != "$MIPI_GROUP" ] || continue
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
    # single=0. The d4xx driver in particular asserts that the route's
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

            mc_l "\"DS5 mux ${cam}\":0 -> \"${ser_pfx} ${ser}\":0[1]"
            mc_R "\"DS5 mux ${cam}\" [${mux_routes}]"

            ser_route_parts=()
            for s in "${sel_streams[@]}"; do
                sid=${STREAM_NODE[$s]}
                ser_route_parts+=("0/${sid}->1/${sid}[1]")
            done
            ser_routes=$(IFS=,; echo "${ser_route_parts[*]}")
            mc_R "\"${ser_pfx} ${ser}\" [${ser_routes}]"

            unset is_selected
            ;;
        isx031|ar0234)
            ser_route_parts=()
            for s in "${sel_streams[@]}"; do
                sid=${STREAM_NODE[$s]}
                ser_route_parts+=("0/${sid}->1/${sid}[1]")
            done
            ser_routes=$(IFS=,; echo "${ser_route_parts[*]}")
            mc_R "\"${ser_pfx} ${ser}\" [${ser_routes}]"
            ;;
    esac

    for s in "${sel_streams[@]}"; do
        sid=${STREAM_NODE[$s]}
        csi2_pad=${CSI2_PAD["${k}_${s}"]}
        des_stream=${DES_STREAM["${k}_${s}"]}
        DES_ROUTES[$d]+="${DES_ROUTES[$d]:+,}${l}/${sid}->${DES_SRC_PAD[$d]}/${des_stream}[1]"
        CSI2_ROUTES[$d]+="${CSI2_ROUTES[$d]:+,}0/${des_stream}->$((csi2_pad + 1))/0[1]"
    done
done

# Apply per-DES route tables.
for d in "${!DES_PATH[@]}"; do
    [ -n "${DES_ROUTES[$d]:-}" ] || continue
    mc_R "\"${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}\" [${DES_ROUTES[$d]}]"
    mc_R "\"${IPU_CSI2_ENTITY[$d]}\" [${CSI2_ROUTES[$d]}]"
done

# CSI2 source pad -> ISYS Capture entity link (must exist before formats flow).
for k in "${!CFG_LINKS[@]}"; do
    [ "${CFG_DES[$k]}" != "$MIPI_GROUP" ] || continue
    d=${CFG_DES[$k]}
    for s in ${CFG_STREAMS[$k]}; do
        csi2_pad=${CSI2_PAD["${k}_${s}"]}
        node=$(( CAPTURE_BASE[d] + csi2_pad ))
        mc_l "\"${IPU_CSI2_ENTITY[$d]}\":$((csi2_pad + 1)) -> \"${IPU_BASE[$d]} ISYS Capture ${node}\":0[1]"
    done
done

# --- pass 2: format propagation (all routes are now in place).

for k in "${!CFG_LINKS[@]}"; do
    [ "${CFG_DES[$k]}" != "$MIPI_GROUP" ] || continue
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
        fmt=${CFG_STREAM_FMT["${k}_${s}"]}
        size=${CFG_STREAM_SIZE["${k}_${s}"]}

        case "$model" in
            d4xx)
                mc_v "\"D4XX ${s} ${cam}\":0 [fmt:${fmt}/${size} field:none]"
                ;;
            isx031)
                mc_v "\"isx031 ${cam}\":0/${sid} [fmt:${fmt}/${size} field:none]"
                ;;
            ar0234)
                mc_v "\"ar0234 ${cam}\":0/${sid} [fmt:${fmt}/${size} field:none]"
                ;;
            ov13b10)
                mc_v "\"ov13b10 ${cam}\":0/${sid} [fmt:${fmt}/${size} field:none]"
                ;;
        esac
            fps=${CFG_STREAM_FPS["${k}_${s}"]}
            if [ -n "${CFG_STREAM_FPS_APPLY["${k}_${s}"]:-}" ] &&
                [[ $fps =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                actual_fps=$(sensor_set_fps "$model" "$cam" "$s" "$sid" \
                    "$fps" \
                    "DES${d} link ${l} stream ${s}") || \
                    die "cannot configure FPS on DES${d} link ${l}, stream ${s}"
                CFG_STREAM_FPS["${k}_${s}"]=$actual_fps
            fi
        mc_v "\"${ser_pfx} ${ser}\":0/${sid} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${ser_pfx} ${ser}\":1/${sid} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}\":${l}/${sid} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${DES_PREFIX_NAME[$d]} ${DES_BA[$d]}\":${DES_SRC_PAD[$d]}/${des_stream} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${IPU_CSI2_ENTITY[$d]}\":0/${des_stream} [fmt:${fmt}/${size} field:none]"
        mc_v "\"${IPU_CSI2_ENTITY[$d]}\":$((csi2_pad + 1))/0 [fmt:${fmt}/${size} field:none]"
    done
done

# ---- v4l2-ctl: capture-node format -----------------------------------------

for k in "${!CFG_LINKS[@]}"; do
    for s in ${CFG_STREAMS[$k]}; do
        if [ "${CFG_DES[$k]}" = "$MIPI_GROUP" ]; then
            node=${MIPI_CAP[${CFG_LINKS[$k]}]}
        else
            node=$(( CAPTURE_BASE[${CFG_DES[$k]}] + CSI2_PAD["${k}_${s}"] ))
        fi
        pixfmt=${CFG_STREAM_PIXFMT["${k}_${s}"]}
        [ -z "$pixfmt" ] && continue
        size=${CFG_STREAM_SIZE["${k}_${s}"]}
        w=${size%x*}
        h=${size#*x}
        v4l2-ctl -d "/dev/video${node}" \
            --set-fmt-video="width=${w},height=${h},pixelformat=${pixfmt}" \
            >/dev/null || die "cannot set /dev/video${node} to ${pixfmt} ${size}"
    done
done
