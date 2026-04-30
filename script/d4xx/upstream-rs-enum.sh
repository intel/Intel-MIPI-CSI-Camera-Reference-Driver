#!/bin/bash

info=0
quiet=0
metadata_enabled=1
mux_param=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--info)
      info=1
      shift
    ;;
    -q|--quiet)
      quiet=1
      shift
    ;;
    -m|--mux)
      shift
      mux_param=$1
      shift
    ;;
    -n|--no-metadata)
      metadata_enabled=0
      shift
    ;;
    *)
      info=0
      quiet=0
      shift
    ;;
    esac
done

if [[ $info -eq 0 ]]; then
  if [ "$(id -u)" -ne 0 ]; then
          echo "Please run as root." >&2
          exit 1
  fi
fi

# Remove any existing rs-enum symlinks (capture nodes, subdevs, dfu) regardless
# of stream type (depth/color/ir/imu/...) or instance index.
for link in /dev/video-rs-*-* /dev/d4xx-dfu-*; do
    [ -L "$link" ] && rm -f "$link"
done


# ---- entity-name -> /dev/* node lookup ---------------------------------------
#
# Resolve subdev / video device nodes from media-ctl by entity name, so
# symlink targets stay correct regardless of how the kernel happens to number
# v4l-subdevX / videoX on this boot.

# Cached `media-ctl -p` dump for graph traversal.
MC_DUMP=$(media-ctl -p 2>/dev/null) || MC_DUMP=""

# Find the entity name (e.g. "D4XX depth 18-0010") whose name starts with the
# given prefix. Echoes the first match. Argument: prefix (e.g. "D4XX depth").
find_entity_name() {
    grep -oP "^- entity \d+: \K${1} [0-9a-f-]+(?= \()" <<<"$MC_DUMP" | head -1
}

# Resolve the /dev node (video* or v4l-subdev*) for an entity name.
entity_devnode() {
    media-ctl -e "$1" 2>/dev/null
}

# Resolve a node by entity-name prefix; echo "" if not found.
resolve() {
    local prefix=$1 name
    name=$(find_entity_name "$prefix") || return 0
    [ -z "$name" ] && return 0
    entity_devnode "$name"
}

# Print the block of media-ctl -p output describing the given entity name
# (between its `- entity N: <name> (...)` header and the next `- entity` line).
entity_block() {
    local name=$1
    awk -v n=": $name (" '
        /^- entity / {
            if (cap) exit
            cap = (index($0, n) > 0)
        }
        cap { print }
    ' <<<"$MC_DUMP"
}

# Within an entity block, follow the ENABLED outbound link from <src_pad>.
# Echoes "<dest_entity>|<dest_sink_pad>", or empty.
follow_link() {
    local entity=$1 src_pad=$2 cur="" line
    while IFS= read -r line; do
        if [[ $line =~ pad([0-9]+): ]]; then
            cur=${BASH_REMATCH[1]}
        fi
        if [[ $cur == "$src_pad" && $line == *'-> "'* && $line == *'[ENABLED'* ]]; then
            if [[ $line =~ \-\>\ \"([^\"]+)\":([0-9]+) ]]; then
                echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
                return 0
            fi
        fi
    done < <(entity_block "$entity")
}

# Within an entity block, find the ACTIVE route mapping (sink_pad/sink_stream)
# to (src_pad/src_stream). Echoes "<src_pad>|<src_stream>", or empty.
follow_route() {
    local entity=$1 sink_pad=$2 sink_stream=$3 in_r=0 line
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]+routes: ]]; then in_r=1; continue; fi
        if (( in_r )) && [[ $line =~ ^[[:space:]]+pad[0-9]+: ]]; then in_r=0; fi
        (( in_r )) || continue
        [[ $line == *'[ACTIVE]'* ]] || continue
        if [[ $line =~ ([0-9]+)/([0-9]+)\ -\>\ ([0-9]+)/([0-9]+)\ \[ACTIVE\] ]]; then
            if [[ ${BASH_REMATCH[1]} == "$sink_pad" && ${BASH_REMATCH[2]} == "$sink_stream" ]]; then
                echo "${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
                return 0
            fi
        fi
    done < <(entity_block "$entity")
}

# Echo /dev/video* node from an entity block, or empty if it's not a video node.
entity_video_devnode() {
    entity_block "$1" | grep -oP 'device node name \K/dev/video[0-9]+' | head -1
}

# Walk the graph from a source entity/pad/stream until reaching a /dev/videoN
# capture node. Echoes the resolved devnode, or empty if traversal stalls.
trace_to_video() {
    local entity=$1 src_pad=$2 stream=$3
    local i=0 link route dst_entity dst_pad dst_stream vnode

    while [ $i -lt 16 ]; do
        link=$(follow_link "$entity" "$src_pad")
        [ -z "$link" ] && return 0
        dst_entity=${link%|*}
        dst_pad=${link#*|}
        dst_stream=$stream

        vnode=$(entity_video_devnode "$dst_entity")
        if [ -n "$vnode" ]; then
            echo "$vnode"
            return 0
        fi

        # Multistream subdev: route sink pad/stream -> source pad/stream.
        route=$(follow_route "$dst_entity" "$dst_pad" "$dst_stream")
        [ -z "$route" ] && return 0
        entity=$dst_entity
        src_pad=${route%|*}
        stream=${route#*|}
        i=$((i + 1))
    done
    return 0
}

# ---- ACPI: bus-addr -> instance index -----------------------------------------
#
# Each D4XX camera lives under \_SB.PCxx.DES<N>.CH<MM>.SER<k>.CAM<k> in the
# ACPI namespace. We map (DES<N>, CH<MM>) -> instance index = N*4 + MM, so
# rs-enum symlinks get a stable per-camera suffix:
#     DES0.CH00 -> 0   DES0.CH01 -> 1   ...   DES0.CH03 -> 3
#     DES1.CH00 -> 4   DES1.CH01 -> 5   ...   DES1.CH03 -> 7
# All D4XX subdevs (DS5 mux / depth / rgb / ir / imu) share the same i2c
# bus-addr (e.g. "23-0010"), so we key the lookup by that bus-addr.

D4XX_CAM_HID=INTC10CD

declare -A BA_TO_IDX     # "23-0010" -> 0..7

for acpi_dir in /sys/bus/acpi/devices/${D4XX_CAM_HID}:*; do
    [ -d "$acpi_dir" ] || continue
    path=$(cat "$acpi_dir/path" 2>/dev/null) || continue
    # path tail looks like: ...DES<N>.CH<MM>.SER<k>.CAM<k>
    if [[ $path =~ \.DES([0-9]+)\.CH([0-9]+)\. ]]; then
        des_idx=${BASH_REMATCH[1]}
        ch_idx=$((10#${BASH_REMATCH[2]}))
    else
        continue
    fi
    idx=$((des_idx * 4 + ch_idx))

    # Pull the bus-addr from any v4l-subdev belonging to this ACPI device
    # (DS5 mux / D4XX depth / rgb / ir / imu all share the same bus-addr).
    ba=""
    for f in "$acpi_dir"/physical_node*/video4linux/v4l-subdev*/name; do
        [ -e "$f" ] || continue
        name=$(cat "$f")
        ba=$(grep -oP '[0-9]+-[0-9a-f]+' <<<"$name" | head -1)
        [ -n "$ba" ] && break
    done
    [ -z "$ba" ] && continue
    BA_TO_IDX[$ba]=$idx
done

# Extract bus-addr suffix ("D4XX depth 23-0010" -> "23-0010").
busaddr_of_entity() {
    grep -oP '[0-9]+-[0-9a-f]+$' <<<"$1"
}

# Discover all D4XX instances present in the media graph and emit per-instance
# symlinks indexed by their (DES, CH) ACPI position.
mapfile -t DEPTH_NAMES < <(grep -oP "^- entity \d+: \KD4XX depth [0-9a-f-]+(?= \()" <<<"$MC_DUMP")

if [ "${#DEPTH_NAMES[@]}" -eq 0 ]; then
    echo "ERROR: no D4XX depth entity found in media graph." >&2
    echo "       Is the d4xx driver loaded?" >&2
    exit 1
fi

for depth_name in "${DEPTH_NAMES[@]}"; do
    ba=$(busaddr_of_entity "$depth_name")
    idx=${BA_TO_IDX[$ba]:-}
    if [ -z "$idx" ]; then
        echo "WARN: no ACPI mapping for D4XX bus-addr $ba; skipping" >&2
        continue
    fi

    color_name="D4XX rgb $ba"
    ir_name="D4XX ir $ba"
    imu_name="D4XX imu $ba"

    grep -q "^- entity .*: ${color_name} (" <<<"$MC_DUMP" || color_name=""
    grep -q "^- entity .*: ${ir_name} ("    <<<"$MC_DUMP" || ir_name=""
    grep -q "^- entity .*: ${imu_name} ("   <<<"$MC_DUMP" || imu_name=""

    DEPTH_SD=$(entity_devnode "$depth_name")
    COLOR_SD=$( [ -n "$color_name" ] && entity_devnode "$color_name" )
    IR_SD=$(    [ -n "$ir_name" ]    && entity_devnode "$ir_name" )
    IMU_SD=$(   [ -n "$imu_name" ]   && entity_devnode "$imu_name" )

    DEPTH_VIDEO=$(trace_to_video "$depth_name" 0 0)
    COLOR_VIDEO=$( [ -n "$color_name" ] && trace_to_video "$color_name" 0 0 )
    IR_VIDEO=$(    [ -n "$ir_name" ]    && trace_to_video "$ir_name"    0 0 )
    IMU_VIDEO=$(   [ -n "$imu_name" ]   && trace_to_video "$imu_name"   0 0 )

    # Capture-node symlinks (only when the pipeline actually exposes them)
    [ -n "$DEPTH_VIDEO" ] && ln -s "$DEPTH_VIDEO" "/dev/video-rs-depth-${idx}"
    [ -n "$COLOR_VIDEO" ] && ln -s "$COLOR_VIDEO" "/dev/video-rs-color-${idx}"
    [ -n "$IR_VIDEO" ]    && ln -s "$IR_VIDEO"    "/dev/video-rs-ir-${idx}"
    [ -n "$IMU_VIDEO" ]   && ln -s "$IMU_VIDEO"   "/dev/video-rs-imu-${idx}"

    # Subdev symlinks (resolved by entity name, survive subdev renumbering)
    [ -n "$DEPTH_SD" ] && ln -s "$DEPTH_SD" "/dev/video-rs-depth-sd-${idx}"
    [ -n "$COLOR_SD" ] && ln -s "$COLOR_SD" "/dev/video-rs-color-sd-${idx}"
    [ -n "$IR_SD" ]    && ln -s "$IR_SD"    "/dev/video-rs-ir-sd-${idx}"
    [ -n "$IMU_SD" ]   && ln -s "$IMU_SD"   "/dev/video-rs-imu-sd-${idx}"

    [ -e "/dev/d4xx-dfu-${ba}" ] && ln -sf "/dev/d4xx-dfu-${ba}" "/dev/d4xx-dfu-${idx}"
done
