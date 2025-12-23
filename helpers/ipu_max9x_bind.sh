#!/bin/bash
#
# Dependency: v4l-utils
v4l2_util=$(which v4l2-ctl)
media_util=$(which media-ctl)
if [ -z ${v4l2_util} ]; then
	echo "v4l2-ctl not found, install with: sudo apt install v4l-utils"
	exit 1
fi
while [[ $# -gt 0 ]]; do
	case $1 in
		-q|--quiet)
			quiet=1
			shift
		;;
		-m|--mux)
			shift
			if [ ${#1} -eq 3 ]; then
			    mux_param=$1
			fi
			shift
		;;
		-s|--sensor)
			sensor=$2
			shift
		;;
		-h|--help)
			echo "-q -m -h" 
		;;
		-f)
			fmt="$2"
			shift
			;;
		*)
			quiet=0
			shift
		;;
		esac
done

sensor="${sensor:-isx031}"
if [ ${sensor} = "isx031" ]; then
	fmt="${fmt:-[fmt:UYVY8_1X16/1920x1536]}"
	# fmt="${fmt:-[fmt:UYVY8_1X16/1600x1280]}"
	# fmt="${fmt:-[fmt:UYVY8_1X16/1024x768]}"
elif [ ${sensor} = "imx390" ]; then
	fmt="${fmt:-[fmt:SGRBG12_1X12/1920x1200]}"
	# fmt="${fmt:-[fmt:SRGGB12_1X12/1936x1096]}"
	# fmt="${fmt:-[fmt:SRGGB12_1X12/1280x720]}"
	# fmt="${fmt:-[fmt:SRGGB12_1X12/1024x768]}"
elif [ ${sensor} = "ar0234" ]; then
	fmt="${fmt:-[fmt:SGRBG10_1X10/1280x960]}"
fi

declare entities=()
while IFS= read -r line; do 
	entities+=("$line")
done < <(media-ctl -p | grep entity | sed -e 's/.*: //;s/ (.*$//')

find_entity() {
	local name=$1
	for e in "${entities[@]}"; do
		if [[ "${e}" = *"${name}"* ]]; then
			echo -n "${e}"
			return
		fi
	done
	echo "$1 not found" >&2
	exit 1
}

des_node() {
	local mux=$1
	case ${mux} in
		a|b|c|d) echo -n "max9x a";;
		A|B|C|D) echo -n "max9x c";;
	esac
}
des_src_pad() {
	local mux=$1
	echo -n "\"$(des_node ${mux})\":0"
}
des_sink_pad() {
	local mux=$1
	echo -n "\"$(des_node ${mux})\":$(( ( 4 + ${mux_to_index[${mux}]} ) % 2 ))"
}

ser_node() {
	local mux=$1
	case ${mux} in
		a) find_entity "max9x a-0";;
		b) find_entity "max9x b-0";;
		c) find_entity "max9x c-0";;
		d) find_entity "max9x d-0";;
		A) find_entity "max9x a-2";;
		B) find_entity "max9x b-2";;
		C) find_entity "max9x c-2";;
		D) find_entity "max9x d-2";;
	esac
}
ser_src_pad() {
	local mux=$1
	echo -n "\"$(ser_node ${mux})\":2"
}
ser_sink_pad() {
	local mux=$1
	echo -n "\"$(ser_node ${mux})\":0"
}

sen_node() {
	local mux=$1
	case ${mux} in
		a) find_entity "i2c-${sensor} a-0";;
		b) find_entity "i2c-${sensor} b-0";;
		c) find_entity "i2c-${sensor} c-0";;
		d) find_entity "i2c-${sensor} d-0";;
		A) find_entity "i2c-${sensor} a-2";;
		B) find_entity "i2c-${sensor} b-2";;
		C) find_entity "i2c-${sensor} c-2";;
		D) find_entity "i2c-${sensor} d-2";;
	esac
}
sen_src_pad() {
	local mux=$1
	echo -n "\"$(sen_node ${mux})\":0"
}

# mapping for ISX031/IMX390/AR0234 mux entity to IPU7 CSI-2 entity matching.
declare -A media_mux_capture_link=( [a]=0 [A]=0 [b]=16 [B]=16 [c]=32)

# mapping for ISX031/IMX390/AR0234 mux entity to IPU7 CSI-2 entity matching.
declare -A media_mux_csi2_link=( [A]=0 [a]=0 [b]=1 [c]=2 [d]=3 [E]=4 [F]=5 [G]=0 [g]=0 [h]=1 [i]=2 [j]=3 [K]=4 [L]=5)

declare -A media_mux_capture_pad=(
	[A]=0
	[a]=0
	[B]=1
	[b]=1
	[C]=2
	[c]=2
	[D]=3
	[d]=3
)


# all available DS5 muxes, each one represent physically connected camera.
# muxes prefix a, b, c, d referes to max96724 aggregated link cameras
# muxes suffix 0, 1, 2 is referes to csi2 mipi port mapping
mux_list=${mux_param:-'a-0 b-0 c-0 a-1 b-1 c-1 a-2 b-2 c-2'}

# Find media device.
# For case with usb camera plugged in during the boot,
# usb media controller will occupy index 0
mdev=$(${v4l2_util} --list-devices | grep -A1 ipu6 | grep media)
[[ -z "${mdev}" ]] && exit 0

out() {
	echo -n "${@}    " >&2
	"${@}"
	echo "        RET=$?" >&2
}

media_ctl_cmd="${media_util} -d ${mdev}"
# media-ctl -r # <- this can be used to clean-up all bindings from media controller
# cache media-ctl output
dot=$($media_ctl_cmd --print-dot)

# all available IMX390/ISX031/AR0234 muxes, each one represent physically connected camera.
# muxes prefix a, b, c, d referes to max96724 aggregated link cameras
# muxes suffix 0, 1, 2 is referes to csi2 mipi port mapping

for mux in $mux_list; do
	e="$(sen_node ${mux})" 
	if [ -z "${e}" ]; then
		continue;
	fi

	[[ $quiet -eq 0 ]] && echo "Bind MAX9X mux ${mux} .. " >&2


	csi2="$((${camera:2:1}))"
	mux=${camera:0:1}

	# mapping for DS5 mux entity to IPU7 ISYS entity matching.
	isys_cap="$((${media_mux_capture_link[${mux}]}))"

	# for DS5 aggregated mux (above a) - use ISYS capture pads with offset 6
	# this offset used as capture sensor set - dept,rgb,ir,imu = 4
	cap_pad=0
	if [ "${mux}" \= "b" ]; then
	    cap_pad=6
	else
	    if  [ "${mux}" \= "c" ]; then
		metadata_enabled=0
		cap_pad=1
	    else
		if  [ "${mux}" \= "d" ]; then
		    metadata_enabled=0
		    cap_pad=7
		fi
	    fi
	fi
	isys_cap=$((${isys_cap}+${cap_pad}))

	# out $media_ctl_cmd -l "${des_node_src[${mux}]} -> \"Intel IPU6 ${csi2}\":0[1]"
	# out $media_ctl_cmd -l "$(des_src_pad ${mux}) -> \"Intel IPU7 ISYS ${csi2}\":0[1]"
	out $media_ctl_cmd -l "\"Intel IPU7 ${csi2}\":$((${cap_pad}+1)) -> \"Intel IPU7 ISYS ${isys_cap} $((${cap_pad}+0))\":0[5]"

	out $media_ctl_cmd -V "$(sen_src_pad ${mux}) ${fmt}"
	out $media_ctl_cmd -V "$(ser_sink_pad ${mux}) ${fmt}"
	out $media_ctl_cmd -V "$(ser_src_pad ${mux}) ${fmt}"
	out $media_ctl_cmd -V "$(des_sink_pad ${mux}) ${fmt}"
	out $media_ctl_cmd -V "$(des_src_pad ${mux}) ${fmt}"

	out $media_ctl_cmd -V "\"Intel IPU7 ${csi2}\":0 ${fmt}"
	out $media_ctl_cmd -V "\"Intel IPU7 ${csi2} $((${cap_pad}+0))\":0 ${fmt}"
	out $media_ctl_cmd -V "\"Intel IPU7 ${isys_cap} $((${cap_pad}+0))\":0 ${fmt}"

	cap_dev=$($media_ctl_cmd -e "Intel IPU7 ISYS ${isys_cap} $((${cap_pad}+0))")
	out ln -snf ${cap_dev} /dev/video-${sensor}-${mux}

done
