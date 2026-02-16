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

declare -A mux_to_index=([a]=0 [b]=1 [c]=2 [d]=3)

find_entity() {
	local name=$1
	for e in "${entities[@]}"; do
		if [[ "${e}" = *"${name}"* ]]; then
			echo -n "${e}"
			return
		fi
	done
	#echo "$1 not found" >&2
	exit 1
}

des_node() {
	local mux=$1
	case ${mux} in
		a-0|b-0|c-0|d-0) echo -n "max9x a";;
		a-1|b-1|c-1|d-1) echo -n "max9x b";;
		a-2|b-2|c-2|d-2) echo -n "max9x c";;
		a-3|b-3|c-3|d-3) echo -n "max9x d";;
		a-4|b-4|c-4|d-4) echo -n "max9x e";;
		a-5|b-5|c-5|d-5) echo -n "max9x f";;
	esac
}
des_src_pad() {
	local mux=$1
	echo -n "\"$(des_node ${mux})\":0"
}
des_sink_pad() {
	local mux=$1
	echo -n "\"$(des_node ${mux})\":$(( 4 + ${mux_to_index[${mux:0:1}]} ))"
}

ser_node() {
	local mux=$1
	find_entity "max9x ${mux}"
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
	find_entity "${sensor} ${mux}"
}
sen_src_pad() {
	local mux=$1
	echo -n "\"$(sen_node ${mux})\":0"
}

# mapping for ISX031/IMX390/AR0234 max9x entity to IPU7|IPU6 CSI-2 entity matching.
declare -A media_mux_capture_link=( [0]=0 [1]=16 [2]=32 [3]=48 [4]=64 [5]=80)

declare -A media_mux_capture_pad=(
	[a]=0
	[b]=1
	[c]=2
	[d]=3
)

# all available   ISX031/IMX390/AR0234 max9x entity, each one represent physically connected camera.
# muxes prefix a, b, c, d referes to max96724 or max9296 aggregated link cameras
# muxes suffix 0, 1, 2, 3, 4, 5 is referes to csi2 mipi port mapping
mux_list=${mux_param:-'a-0 b-0 c-0 d-0 a-1 b-1 c-1 d-1 a-2 b-2 c-2 d-2 a-3 b-3 c-3 d-3 a-4 b-4 c-4 d-4 a-5 b-5 c-5 d-5'}

# Find media device.
# For case with usb camera plugged in during the boot,
# usb media controller will occupy index 0
mdev=$(${v4l2_util} --list-devices | grep -A100 ipu | grep media)
[[ -z "${mdev}" ]] && exit 0

# Find IPU PCI device gen name
cap_prefix=$(${v4l2_util} --list-devices | grep ipu | grep PCI | sed 's/^\(ipu[6|7]\).*/\1/' | tr '[:lower:]' '[:upper:]')
[[ -z "${cap_prefix}" ]] && exit 0

out() {
	echo -n "${@}    " >&2
	"${@}"
	echo "        RET=$?" >&2
}

media_ctl_cmd="${media_util} -d ${mdev}"
media-ctl -r # <- this can be used to clean-up all bindings from media controller
# cache media-ctl output
dot=$($media_ctl_cmd --print-dot)

des_route=""
csi_route=""
des_suffix="a"
streamid=0
# loop over all available IMX390/ISX031/AR0234 max9x, each one represent physically connected camera.
for camera in $mux_list; do
	e="$(sen_node ${camera})" 
	if [ -z "${e}" ]; then
		continue;
	fi
	d="$(des_node ${camera})"
	if [ "${des_suffix}" != "${d:6:1}" ]; then
		des_suffix="${d:6:1}"
		streamid=0
	fi

	[[ $quiet -eq 0 ]] && echo "Bind $cap_prefix to ${sensor} ${camera} through max9x ${des_suffix}  .. " >&2

	csi2="$((${camera:2:1}))"
	mux=${camera:0:1}

	# mapping for MAX9x mux entity to IPU7|IPU6 ISYS matching entity.
	cap_pad="${media_mux_capture_pad[${mux}]}"
	isys_cap="$((${media_mux_capture_link[${csi2}]}+${cap_pad}))"

	out $media_ctl_cmd -l "$(des_src_pad ${camera}) -> \"Intel ${cap_prefix} CSI2 ${csi2}\":0[1]"
	out $media_ctl_cmd -l "\"Intel ${cap_prefix} CSI2 ${csi2}\":$((${cap_pad}+1)) -> \"Intel ${cap_prefix} ISYS Capture ${isys_cap}\":0[1]"

	# subdev entity '['pad-number '/' stream-number '->' pad-number '/' stream-number '[' route-flags ']' ']' ;
	if [ $streamid -eq 0 ]; then
		des_route="$((${cap_pad} + 4))/${streamid}->0/${streamid}[1]"
		csi_route="0/${streamid}->$((${cap_pad} + 1))/${streamid}[1]"
	else
		des_route=${des_route}",$((${cap_pad} + 4))/${streamid}->0/${streamid}[1]"
		csi_route=${csi_route}",0/${streamid}->$((${cap_pad} + 1))/${streamid}[1]"
	fi
	out $media_ctl_cmd -R "\"$(ser_node ${camera})\"[0/0->2/${streamid}[1]]"
	out $media_ctl_cmd -R "\"$(des_node ${camera})\"[${des_route}]"
	out $media_ctl_cmd -R "\"Intel ${cap_prefix} CSI2 ${csi2}\"[${csi_route}]"

	out $media_ctl_cmd -V "$(sen_src_pad ${camera}) ${fmt}"
	out $media_ctl_cmd -V "$(ser_sink_pad ${camera}) ${fmt}"
	out $media_ctl_cmd -V "$(ser_src_pad ${camera})/${streamid} ${fmt}"
	out $media_ctl_cmd -V "$(des_sink_pad ${camera})/${streamid} ${fmt}"
	out $media_ctl_cmd -V "$(des_src_pad ${camera})/${streamid} ${fmt}"

	out $media_ctl_cmd -V "\"Intel ${cap_prefix} CSI2 ${csi2}\":0/${streamid} ${fmt}"
	out $media_ctl_cmd -V "\"Intel ${cap_prefix} CSI2 ${csi2}\":$((${cap_pad}+1))/${streamid} ${fmt}"

	cap_dev=$($media_ctl_cmd -e "Intel ${cap_prefix} ISYS Capture ${isys_cap}")
	dev_ln="/dev/video-${sensor}-${camera}"
	out ln -snf ${cap_dev} ${dev_ln}

	# set default v4l2 fmt value
if [ ${sensor} = "isx031" ]; then
	out ${v4l2_util} -d ${dev_ln} --set-fmt-video=width=1920,height=1536,pixelformat=UYVY
elif [ ${sensor} = "imx390" ]; then
	out ${v4l2_util} -d ${dev_ln} --set-fmt-video=width=1920,height=1200,pixelformat=NV12
elif [ ${sensor} = "ar0234" ]; then
	out ${v4l2_util} -d ${dev_ln} --set-fmt-video=width=1280,height=960,pixelformat=NV12
fi
	# disable ipu link enumeration feature
	out ${v4l2_util} -d $dev_ln -c enumerate_graph_link=0

	# change group
	out chown root:video $cap_dev

	# WA: must repeat all the v4l2 set-fmt on Intel IPU7 CSI2 2 v4l2 subdev pad 0
	if [ $streamid -gt 0 ]; then
		for i in $(seq 0 $streamid); do out $media_ctl_cmd -V "\"Intel ${cap_prefix} CSI2 ${csi2}\":0/$((${i})) ${fmt}"; done
	fi
	streamid=$(($streamid + 1))
done
