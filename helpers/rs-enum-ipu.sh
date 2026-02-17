#!/bin/bash
# Create symbolic links for video nodes and for metadata nodes - /dev/video-rs-[<sensor>|<sensor>-md]-[camera-index]
# This script intended for mipi devices on IPU7.
# After running this script in enumeration mode, it will create links as follow for example:
# Example of the output:
#
# Pantherlake:
#$ ./rs-enum.sh 
#Bus	Camera	Sensor	Node Type	Video Node	RS Link
# ipu7	0	depth	Streaming	/dev/video4 	/dev/video-rs-depth-a-0
# ipu7	0	depth	Metadata	/dev/video5	/dev/video-rs-depth-md-a-0
# ipu7	0	ir	Streaming	/dev/video8	/dev/video-rs-ir-a-0
# ipu7	0	imu	Streaming	/dev/video9	/dev/video-rs-imu-a-0
# ipu7	0	color	Streaming	/dev/video6	/dev/video-rs-color-a-0
# ipu7	0	color	Metadata	/dev/video7	/dev/video-rs-color-md-a-0
# i2c 	0	d4xx   	Firmware 	/dev/d4xx-dfu-a	/dev/d4xx-dfu-a-0
# ipu7	2	depth	Streaming	/dev/video36	/dev/video-rs-depth-a-2
# ipu7	2	depth	Metadata	/dev/video37  	/dev/video-rs-depth-md-a-2
# ipu7	2	ir	Streaming	/dev/video40	/dev/video-rs-ir-a-2
# ipu7	2	imu	Streaming	/dev/video41	/dev/video-rs-imu-a-2
# ipu7	2	color 	Streaming	/dev/video38	/dev/video-rs-color-a-2
# ipu7	2	color 	Metadata	/dev/video39	/dev/video-rs-color-md-a-2
# i2c 	2	d4xx   	Firmware 	/dev/d4xx-dfu-c	/dev/d4xx-dfu-a-2

# Dependency: v4l-utils
v4l2_util=$(which v4l2-ctl)
media_util=$(which media-ctl)
if [ -z ${v4l2_util} ]; then
  echo "v4l2-ctl not found, install with: sudo apt install v4l-utils"
  exit 1
fi
metadata_enabled=1
#
# parse command line parameters
# for '-i' parameter, print links only
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
      if [ ${#1} -eq 3 ]; then
	 mux_param=$1
      fi
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
#set -x
if [[ $info -eq 0 ]]; then
  if [ "$(id -u)" -ne 0 ]; then
          echo "Please run as root." >&2
          exit 1
  fi
fi


# all available DS5 muxes, each one represent physically connected camera.
# muxes prefix a, b, c, d referes to max96724 aggregated link cameras
# muxes suffix 0, 1, 2, 3, 4, 5 is referes to csi2 mipi port mapping

mux_list=${mux_param:-'a-0 b-0 c-0 d-0 a-1 b-1 c-1 d-1 a-2 b-2 c-2 d-2 a-3 b-3 c-3 d-3 a-4 b-4 c-4 d-4 a-5 b-5 c-5 d-5'}

# mapping for DS5 mux entity to IPU6/IPU7 CSI-2 entity matching.
declare -A camera_idx=( [a]=0 [b]=1 [c]=2 [d]=3 )
declare -A mipi_csi2_idx=( [a]=0 [b]=0 [c]=0)
declare -A d4xx_vc_named=([depth]=1 [rgb]=3 [ir]=5 [imu]=6)
declare -A camera_names=( [depth]=depth [rgb]=color [ir]=ir [imu]=imu )

camera_vid=("depth" "depth-md" "color" "color-md" "ir" "ir-md" "imu")

#IPU6 or IPU7 ISYS
mdev=$(${v4l2_util} --list-devices | grep -A100 ipu | grep media)
cap_prefix=$(${v4l2_util} --list-devices | grep ipu | grep PCI | sed 's/^\(ipu[6|7]\).*/\1/' | tr '[:lower:]' '[:upper:]')

if [ -n "${mdev}" ]; then
[[ $quiet -eq 0 ]] && printf "Bus\tCamera\tSensor\tNode Type\tVideo Node\tRS Link\n"
# cache media-ctl output
dot=$(${media_util} -d ${mdev} --print-dot | grep -v dashed)
# for all d457 muxes a-0, b-0, c-0, a-1, b-1, c-1, a-2, b-2, c-2, 
for camera in $mux_list; do
  create_dfu_dev=0
  update_mux_link_freq=0
  csi2="$((${camera:2:1}))"
  mux=${camera:0:1}
  suffix="$((${camera_idx[${mux}]}+(4*${csi2})))"
  vpad=0
  [[ "${mux}" == "b" ]]  && vpad=$((${vpad}+6))
  [[ "${mux}" == "c" ]]  && vpad=$((${vpad}+1))
  [[ "${mux}" == "d" ]]  && vpad=$((${vpad}+7))

  for sens in "${!d4xx_vc_named[@]}"; do
    # get sensor binding from media controller
    d4xx_sens=$(echo "${dot}" | grep "D4XX $sens $camera" | awk '{print $1}')

    [[ -z $d4xx_sens ]] && continue; # echo "SENS $sens NOT FOUND" && continue

    if [ "${mux}" \= "c" ]; then
	# remap IR amd IMU suffix c to CSI2 input 13 and 14 
	[[ ${camera_names["${sens}"]} == 'depth' ]] && vpad=1
	[[ ${camera_names["${sens}"]} == 'color' ]] && vpad=1
	[[ ${camera_names["${sens}"]} == 'ir' ]] && vpad=$((${vpad}+7))
	[[ ${camera_names["${sens}"]} == 'imu' ]] && vpad=$((${vpad}+7))
	#echo "${camera_names["${sens}"]}:${d4xx_vc_named[${sens}]} -> $((${d4xx_vc_named[${sens}]}+${vpad}))"
    fi

    if [ "${mux}" \= "d" ]; then
	# remap IR amd IMU suffix d to CSI2 input 15 and 16  
	[[ ${camera_names["${sens}"]} == 'depth' ]] && vpad=7
	[[ ${camera_names["${sens}"]} == 'color' ]] && vpad=7
	[[ ${camera_names["${sens}"]} == 'ir' ]] && vpad=$((${vpad}+3))
	[[ ${camera_names["${sens}"]} == 'imu' ]] && vpad=$((${vpad}+3))
	#echo "${camera_names["${sens}"]}:${d4xx_vc_named[${sens}]} -> $((${d4xx_vc_named[${sens}]}+${vpad}))"
    fi

    d4xx_sens_mux=$(echo "${dot}" | grep $d4xx_sens:port0 | awk '{print $3}' | awk -F':' '{print $1}')
    csi2=$(echo "${dot}" | grep $d4xx_sens_mux:port0 | awk '{print $3}' | awk -F':' '{print $1}')
    vid_nd=$(echo "${dot}" | grep -w "$csi2:port$((${d4xx_vc_named[${sens}]}+${vpad}))" | awk '{print $3}' | awk -F':' '{print $1}')
    [[ -z $vid_nd ]] && continue; # echo "SENS $sens NOT FOUND" && continue

    vid=$(echo "${dot}" | grep "${vid_nd}" | grep video | tr '\\n' '\n' | grep video | awk -F'"' '{print $1}')
    [[ -z $vid ]] && continue;
    dev_ln="/dev/video-rs-${camera_names["${sens}"]}-${suffix}"
    dev_name=$(${v4l2_util} -d $vid -D | grep "Card type" | awk -F':' '{print $2}')

    mux_nd=$(echo "${dot}" | grep -w "$d4xx_sens_mux:port1" | awk '{print $3}' | awk -F':' '{print $1}')
    dev_mux=$(echo "${dot}" | grep "${mux_nd}" | grep subdev | tr '\\n' '\n' | grep subdev | awk -F'"' '{print $1}' | awk -F'|' '{print $1}')

    [[ $quiet -eq 0 ]] && printf '%s\t%s\t%s\tStreaming\t%s\t%s\n' "$dev_name" ${camera} ${camera_names["${sens}"]} $vid $dev_ln

    # create link only in case we choose not only to show it
    if [[ $info -eq 0 ]]; then
      [[ -e $dev_ln ]] && unlink $dev_ln
      ln -s $vid $dev_ln
      # enable ipu7 link enumeration feature
      ${v4l2_util} -d $dev_ln -c enumerate_graph_link=1
      [[ -e $dev_ln && ${camera_names["${sens}"]} == 'depth' ]] && ${v4l2_util} -d $dev_ln --set-fmt-video=width=640,height=480,pixelformat='Z16 '
      [[ -e $dev_ln && ${camera_names["${sens}"]} == 'color' ]] && ${v4l2_util} -d $dev_ln  --set-fmt-video=width=640,height=480,pixelformat='YUYV'
      [[ -e $dev_ln && ${camera_names["${sens}"]} == 'ir' ]] && ${v4l2_util} -d $dev_ln --set-fmt-video=width=640,height=480,pixelformat='Y8I '
      # For fimware version starting from: 5.16,
      # IMU will have 32bit axis values.
      # 5.16.x.y = firmware version: 0x0510
      # state->fw_version < 0x510
      #[[ -e $dev_ln && ${camera_names["${sens}"]} == 'imu' ]] && ${v4l2_util} -d $dev_ln --set-fmt-video=width=32,height=1,pixelformat='GREY'
      # state->fw_version >= 0x510
      [[ -e $dev_ln && ${camera_names["${sens}"]} == 'imu' ]] && ${v4l2_util} -d $dev_ln --set-fmt-video=width=38,height=1,pixelformat='GREY'
    fi

    update_mux_link_freq=1 # will update link freq for camera
    create_dfu_dev=1 # will create DFU device link for camera

    # metadata link
    if [ "$metadata_enabled" -eq 0 ]; then
        continue;
    fi
    # skip IR metadata node for now.
    [[ ${camera_names["${sens}"]} == 'ir' ]] && continue
    # skip IMU metadata node.
    [[ ${camera_names["${sens}"]} == 'imu' ]] && continue
    # skip metadata node for c and d
    [[ "${mux}" == "c" ]]  && continue
    [[ "${mux}" == "d" ]]  && continue

    vid_num=$(echo $vid | grep -o '[0-9]\+')
    dev_md_ln="/dev/video-rs-${camera_names["${sens}"]}-md-${suffix}"
    dev_name=$(${v4l2_util} -d "/dev/video$(($vid_num+1))" -D | grep Model | awk -F':' '{print $2}')

    [[ $quiet -eq 0 ]] && printf '%s\t%s\t%s\tMetadata\t/dev/video%s\t%s\n' "$dev_name" ${camera} ${camera_names["${sens}"]} $(($vid_num+1)) $dev_md_ln
    # create link only in case we choose not only to show it
    if [[ $info -eq 0 ]]; then
      [[ -e $dev_md_ln ]] && unlink $dev_md_ln
      ln -s "/dev/video$(($vid_num+1))" $dev_md_ln
      ${v4l2_util} -d $dev_md_ln -c enumerate_graph_link=3
    fi

  done

  # update link_freq for D457 camera
  if [[ ${update_mux_link_freq} -eq 1 ]]; then
    ${v4l2_util} -d $dev_mux  --set-ctrl v4l2_cid_link_freq=6
  fi

  # DFU device link for camera
  if [[ ${create_dfu_dev} -eq 1 ]]; then
    dev_dfu_name="/dev/d4xx-dfu-${camera}"
    dev_dfu_ln="/dev/d4xx-dfu-${suffix}"
    if [[ $info -eq 0 ]]; then
	[[ -L "$dev_dfu_ln" ]] && unlink $dev_dfu_ln
	ln -s $dev_dfu_name $dev_dfu_ln
    fi
    [[ $quiet -eq 0 ]] && printf '%s\t%s\t%s\tFirmware \t%s\t%s\n' " i2c " ${camera} "d4xx   " $dev_dfu_name $dev_dfu_ln
  fi

done
fi
# end of file

