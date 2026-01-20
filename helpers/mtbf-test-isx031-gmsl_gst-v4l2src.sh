#!/bin/bash
# Dependency: gstreamer1.0-plugins-base
gst_util=$(which gst-launch-1.0)
if [ -z ${gst_util} ]; then
	echo "Gstreamer1.0 not found, install with: sudo apt install gstreamer1.0-tools gstreamer1.0-plugins-base"
	exit 1
fi
i2c_util=$(which i2ctransfer)
if [ -z ${i2c_util} ]; then
	echo "i2ctransfer not found, install with: sudo apt install i2c-tools"
	exit 1
fi

# Flag to indicate shutdown requested
shutdown_requested=false

###### to be MODIFIED if max9x AIC GMSL deserializer board is mapped differently
desA_addr=27
desA_i2c=0
desA_csi=0
desA_tuple="a|d"
#--------
desB_addr=27
desB_i2c=1
desB_csi=2
desB_tuple="a|d"
######

nox=false
watch=false
while [[ $# -gt 0 ]]; do
	case $1 in
		-l|--loop)
			shift
			loop=$1
			shift
		;;
		-t|--testcase)
			shift
			testcase=$1
			shift
		;;
		-d|--duration)
			shift
			duration=$1
			shift
		;;
		-n|--nox)
			nox=true
			shift
		;;
		-w|--watch)
			watch=true
			shift
		;;
		-h|--help)
			echo "-t,--testcase <2by2|4by4|6by6|8by8> -d,--duration <ex: 1=10s, 6=1min, 18=3min, 180=30min, 360=1h, ...> -l,--loop <number of testcase iteration, before exit> -n,-nox -w,-watch <max9x a|b|c|d-$desA_csi|$desB_csi gmsl-link status display every 10sec>"
			echo "Examples:"
			echo "  ./mtbf-test-isx031-gmsl_gst-v4l2src.sh -t 2by2 -d 1 -l 1 -n   #isx031 a|d-$desA_csi and a|d-$desB_csi GMSL links back-to-back 10s test, 1-loop : gst-launch-1.0 v4l2src ...! fakesink..."
			echo "  ./mtbf-test-isx031-gmsl_gst-v4l2src.sh -t 4by4 -d 6 -l 10     #isx031 a|b|c|d-$desA_csi and a|b|c|d-$desB_csi GMSL links back-to-back 1min test, 10-loops : gst-launch-1.0 v4l2src ...! xvimagesink..."
			echo "  ./mtbf-test-isx031-gmsl_gst-v4l2src.sh -t 6by6 -d 180 -l 5 -n #isx031 a|b|c|d-$desA_csi|$desB_csi and b|c-$desB_csi|$desA_csi GMSL links back-to-back 30min test, 5-loops : gst-launch-1.0 v4l2src ...! fakesink..."
			echo "  ./mtbf-test-isx031-gmsl_gst-v4l2src.sh -t 8by8 -d 360 -l 1 -n -w # isx031 a|b|c|d-$desA_csi|$desB_csi GMSL links back-to-back 1h test, 1-loops and watch max9x link-status : gst-launch-1.0 v4l2src ...! fakesink..."
			exit 1
			;;
		*)
			shift
		;;
	esac
done

handle_sigterm() {
    echo "Shutdown signal received"
    pkill gst-launch-1.0
    shutdown_requested=true
}

# Handle multiple signals with the same handler
trap handle_sigterm SIGTERM SIGINT SIGHUP

RED='\033[0;31m'
GREEN='\033[0;32m'
GREY='\033[0;37m'
NC='\033[0m' # No Color

# Helper function to check specific bits
# Usage: check_bit <hex_value> <bit_number>
check_bit() {
    local val=$((16#${1#0x}))
    local bit=$2
    local label=$3
    if [ $(( (val >> bit) & 1 )) -eq 1 ]; then
        echo "1 ($label)"
    else
        echo "0 ($label)"
    fi
}
# Usage: check_cng <hex_value> <bit_shifting> <bit_mask> 
check_cnt() {
    local val=$((16#${1#0x}))
    local bit=$2
    local mask=$((16#${3#0x}))
    echo "$(( (val >> bit) & mask ))"
}

reg_max9x_id () {
    local BUS=$1
    local DEV=$2

    # GMSL a|b|c|d Link/Lock Status
    ADDR=0x000D
    # Split 16-bit address for w2 transfer (e.g., 0x0005 -> 0x0 0x5)
    HIGH_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) >> 8 )))
    LOW_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) & 0xFF )))
        
    VAL=$(i2ctransfer -y -f $BUS w2@0x$DEV $HIGH_BYTE $LOW_BYTE r1)
    echo $VAL
    #return $VAL
}


reg_max9x_lnklock () {
    local BUS=$1
    local DEV=$2
    
    # GMSL a|b|c|d Link/Lock Status
    echo "max9x i2c-$BUS@0x$DEV LINK_LOCK Status:"
    for REG in "0x001A:5/LNKA_LOCKED" "0x000A:3/LNKB_LOCKED" "0x000B:3/LNKC_LOCKED" "0x000C:3/LNKD_LOCKED"; do
        ADDR=${REG%:*}
        ARGS=${REG#*:}
        BIT=${ARGS%/*}
        LBL=${ARGS#*/}
        # Split 16-bit address for w2 transfer (e.g., 0x0005 -> 0x0 0x5)
        HIGH_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) >> 8 )))
        LOW_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) & 0xFF )))
        
        VAL=$(i2ctransfer -y -f $BUS w2@0x$DEV $HIGH_BYTE $LOW_BYTE r1)
        RESULT=$(check_bit $VAL $BIT $LBL)
        echo "      Reg $ADDR bit$BIT: $VAL -> status: $RESULT"
    done
}

reg_max9x_vidlock () {
    local BUS=$1
    local DEV=$2

    # GMSL a|b|c|d video Lock Status
    echo "max9x i2c-$BUS@0x$DEV VID_LOCK Status:"
    # Mapping: RegAddr:Bit
    DEEP_REGS=("0x0108:6/VIDA_LOCKED" "0x011A:6/VIDB_LOCKED" "0x012C:6/VIDC_LOCKED" "0x013E:6/VIDD_LOCKED")
    
    for ENTRY in "${DEEP_REGS[@]}"; do
        ADDR=${ENTRY%:*}
        ARGS=${ENTRY#*:}
        BIT=${ARGS%/*}
        LBL=${ARGS#*/}
        HIGH_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) >> 8 )))
        LOW_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) & 0xFF )))
        
        VAL=$(i2ctransfer -y -f $BUS w2@0x$DEV $HIGH_BYTE $LOW_BYTE r1)
        RESULT=$(check_bit $VAL $BIT $LBL)
        echo "      Reg $ADDR bit$BIT: $VAL -> status: $RESULT"
    done
}

reg_max9x_deserr () {
    local BUS=$1
    local DEV=$2
    local DNAME=$3

    # GMSL a|b|c|d video Lock Status
    echo "$DNAME i2c-$BUS@0x$DEV ERR_CNT Status:"
    # Mapping: RegAddr:Bit
    for REG in "0x01dc:5/VPRBS_FAIL" "0x01fc:5/VPRBS_FAIL"; do
        ADDR=${REG%:*}
        ARGS=${REG#*:}
        BIT=${ARGS%/*}
        LBL=${ARGS#*/}
        # Split 16-bit address for w2 transfer (e.g., 0x0005 -> 0x0 0x5)
        HIGH_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) >> 8 )))
        LOW_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) & 0xFF )))
        
        VAL=$(i2ctransfer -y -f $BUS w2@0x$DEV $HIGH_BYTE $LOW_BYTE r1)
        RESULT=$(check_bit $VAL $BIT $LBL)
        echo "      Reg $ADDR bit$BIT: $VAL -> status: $RESULT"
    done

    if [[ $DNAME == "max9296" ]]; then
	DEEP_REGS=("0x0022:0-FF/DEC_ERR_A" "0x0023:0-FF/DEC_ERR_B" "0x0025:0-FF/PKT_CNT")
    else
	DEEP_REGS=("0x0035:0-FF/DEC_ERR_A" "0x0036:0-FF/DEC_ERR_B" "0x0037:0-FF/DEC_ERR_C" "0x0038:0-FF/DEC_ERR_D" \
					   "0x0039:0-FF/IDL_ERR_A" "0x003A:0-FF/IDL_ERR_B" "0x003B:0-FF/IDL_ERR_C" "0x003C:0-FF/IDL_ERR_D" \
					   "0x08D0:0-F/TX0_PKT_CNT" "0x08D2:0-F/PHY0_PKT_CNT" \
					   "0x08D1:0-F/TX2_PKT_CNT" "0x08D3:0-F/PHY2_PKT_CNT")
    fi
    for ENTRY in "${DEEP_REGS[@]}"; do
        ADDR=${ENTRY%:*}
        ARGS=${ENTRY#*:}
        ARG1=${ARGS%/*}
        LBL=${ARGS#*/}
        ARG2=${ARG1%/*}
        BIT=${ARG2%-*}
        MSK=${ARG2#*-*}
	#echo $BIT
	#echo $MASK
        HIGH_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) >> 8 )))
        LOW_BYTE=$(printf "0x%x" $(( (16#${ADDR#0x}) & 0xFF )))
        
        VAL=$(i2ctransfer -y -f $BUS w2@0x$DEV $HIGH_BYTE $LOW_BYTE r1)
        RESULT=$(check_cnt $VAL $BIT $MSK)
        echo "      Reg $ADDR [$LBL] mask0x$MSK: $VAL -> count: $RESULT"
    done
}

# Wait with timeout (Bash 4.3+)
wait_with_timeout() {
    local pid=$1
    local timeout=$2
    local dname=$3
    local bus=$4
    local addr=$5
    local count=0
    local wcount=0
    local ret=0

    echo "$(reg_max9x_deserr $bus $addr ${dname})" 1>&2 # clear max9x error status 


    while kill -0 "$pid" 2>/dev/null; do

	#echo $count
	
	err_cnt=$(dmesg | grep -i "error group 3 code 18" | wc -l)
	if [[ $(($err_cnt - $err_initial)) -ge 1 ]]; then
	    err_tailmsg=$(dmesg -T | grep -i "error group 3 code 18" | tail -n 1)
	    echo "Oops: $err_tailmsg"
	    echo "Error waiting for PID $pid [HW_ERR_BAD_FRAME_DIM cnt=$(($err_cnt - $err_initial))]"
	    reg_max9x_deserr $bus $addr ${dname}  #Check Deserializer status
	    return 0
	fi

        if [[ $count -ge $timeout ]]; then
            echo "Timeout waiting for PID $pid"
            return 1
        fi

        sleep 1
        count=$((count + 1))
	if [[ "$watch" == "true" ]]; then
            wcount=$((wcount + 1))
	    if [[ $wcount -gt 10 ]]; then
		reg_max9x_deserr $bus $addr ${dname}  #Check Deserializer status
		wcount=0
	    fi
	fi
    done

    wait "$pid"
    ret=$?
    #echo $ret
    if [[ $ret -ne 0 ]]; then 
	return $((-1))
    else
	return 1
    fi
}

test_v4l2src_1920x1536_2by2() {
    local i=$1
    local csi=$2
    local fcnt=$3
    local tout=$4
    local dname=$5
    local bus=$6
    local addr=$7
    local tuple=${8:-'a|d'}
    local pid=0
    local ret=0
    local out="videoconvert ! xvimagesink"    

    [[ "$nox" == "true" ]] && out="fakesink sync=false enable-last-sample=false"

    echo "Starting ... $dname GMSL $tuple-$csi links $testcase test-run $i with PID: $pid"

    gst-launch-1.0 \
	v4l2src device=/dev/video-isx031-${tuple%|*}-$csi num-buffers=$fcnt ! \
	'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_0 \
	v4l2src device=/dev/video-isx031-${tuple#*|}-$csi num-buffers=$fcnt ! \
	'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_1 \
	compositor name=comp \
	sink_0::xpos=0    sink_0::ypos=0    sink_0::width=1920 sink_0::height=1536 sink_0::zorder=1 \
	sink_1::xpos=1920 sink_1::ypos=0    sink_1::width=1920 sink_1::height=1536 sink_1::zorder=2 \
 	! ${out} &

    # Get the PID of the last background process
    pid=$!
    
    if [[ "$watch" == "true" ]]; then
	reg_max9x_vidlock $bus $addr #Check Deserializer status
    fi

    wait_with_timeout $pid $(($tout+1)) $dname $bus $addr
    ret=$?

    # kill any background process
    kill $pid 2>/dev/null

    return $ret
}

test_v4l2src_1920x1536_4by4() {
    local i=$1
    local csi=$2
    local fcnt=$3
    local tout=$4
    local dname=$5
    local bus=$6
    local addr=$7
    local tuple=${8:-'a|d'}
    local dmux=${9:-'a-0'}
    local pid=0
    local ret=0
    local out="videoconvert ! xvimagesink"

    [[ "$nox" == "true" ]] && out="fakesink sync=false enable-last-sample=false"

    echo "Starting... $dname GMSL a|b|c|d-$csi links $testcase test-run $i with PID: $pid"

    gst-launch-1.0 \
	v4l2src device=/dev/video-isx031-a-$csi num-buffers=$fcnt ! \
	'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_0 \
	v4l2src device=/dev/video-isx031-b-$csi num-buffers=$fcnt ! \
	'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_1 \
	v4l2src device=/dev/video-isx031-c-$csi num-buffers=$fcnt ! \
	'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_2 \
	v4l2src device=/dev/video-isx031-d-$csi num-buffers=$fcnt ! \
	'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_3 \
	compositor name=comp \
	sink_0::xpos=0    sink_0::ypos=0    sink_0::width=1920 sink_0::height=1536 sink_0::zorder=1 \
	sink_1::xpos=1920 sink_1::ypos=0    sink_1::width=1920 sink_1::height=1536 sink_1::zorder=2 \
	sink_2::xpos=0    sink_2::ypos=1536 sink_2::width=1920 sink_2::height=1536 sink_2::zorder=3 \
	sink_3::xpos=1920 sink_3::ypos=1536 sink_3::width=1920 sink_3::height=1536 sink_3::zorder=4 \
	! ${out} &

    # Get the PID of the last background process
    pid=$!
    
    if [[ "$watch" == "true" ]]; then
	reg_max9x_vidlock $bus $addr #Check Deserializer status
    fi

    wait_with_timeout $pid $(($tout+1)) $dname $bus $addr
    ret=$?

    # kill any background process
    kill $pid 2>/dev/null

    return $ret
}

test_v4l2src_1920x1536_6by6() {
    local i=$1
    local csi=$2
    local fcnt=$3
    local tout=$4
    local dname=$5
    local bus=$6
    local addr=$7
    local tuple=${8:-'b|c'}
    local pid=0
    local ret=0
    local out="videoconvert ! xvimagesink"

    [[ "$nox" == "true" ]] && out="fakesink sync=false enable-last-sample=false"

    if [[ $csi -eq $desA_csi ]]; then
	echo "Starting... $dname GMSL a|b|c|d-$desA_csi and $tuple-$desB_csi links $testcase test-run $i with PID: $pid"
	gst-launch-1.0 \
        v4l2src device=/dev/video-isx031-a-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_0 \
        v4l2src device=/dev/video-isx031-b-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_1 \
        v4l2src device=/dev/video-isx031-c-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_2 \
        v4l2src device=/dev/video-isx031-d-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_3 \
        v4l2src device=/dev/video-isx031-${tuple%|*}-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_4 \
        v4l2src device=/dev/video-isx031-${tuple#*|}-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_5 \
        compositor name=comp \
        sink_0::xpos=0    sink_0::ypos=0    sink_0::width=1920 sink_0::height=1536 sink_0::zorder=1 \
        sink_1::xpos=1920 sink_1::ypos=0    sink_1::width=1920 sink_1::height=1536 sink_1::zorder=2 \
        sink_2::xpos=3840 sink_2::ypos=0    sink_2::width=1920 sink_2::height=1536 sink_2::zorder=3 \
        sink_3::xpos=5760 sink_3::ypos=0    sink_3::width=1920 sink_3::height=1536 sink_3::zorder=4 \
        sink_4::xpos=0    sink_4::ypos=1536 sink_4::width=1920 sink_4::height=1536 sink_4::zorder=5 \
        sink_5::xpos=1920 sink_5::ypos=1536 sink_5::width=1920 sink_5::height=1536 sink_5::zorder=6 \
	! ${out} &
    else
	echo "Starting... $dname GMSL a|b|c|d-$desB_csi and $tuple-$desA_csi links $testcase test-run $i with PID: $pid"
	gst-launch-1.0 \
        v4l2src device=/dev/video-isx031-a-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_0 \
        v4l2src device=/dev/video-isx031-b-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_1 \
        v4l2src device=/dev/video-isx031-c-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_2 \
        v4l2src device=/dev/video-isx031-d-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_3 \
        v4l2src device=/dev/video-isx031-${tuple%|*}-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_4 \
        v4l2src device=/dev/video-isx031-${tuple#*|}-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_5 \
        compositor name=comp \
        sink_0::xpos=0    sink_0::ypos=0    sink_0::width=1920 sink_0::height=1536 sink_0::zorder=1 \
        sink_1::xpos=1920 sink_1::ypos=0    sink_1::width=1920 sink_1::height=1536 sink_1::zorder=2 \
        sink_2::xpos=3840 sink_2::ypos=0    sink_2::width=1920 sink_2::height=1536 sink_2::zorder=3 \
        sink_3::xpos=5760 sink_3::ypos=0    sink_3::width=1920 sink_3::height=1536 sink_3::zorder=4 \
        sink_4::xpos=0    sink_4::ypos=1536 sink_4::width=1920 sink_4::height=1536 sink_4::zorder=5 \
        sink_5::xpos=1920 sink_5::ypos=1536 sink_5::width=1920 sink_5::height=1536 sink_5::zorder=6 \
	! ${out} &
    fi

    # Get the PID of the last background process
    pid=$!

    if [[ "$watch" == "true" ]]; then
	reg_max9x_vidlock $desA_i2c $desA_addr #Check Deserializer status
	reg_max9x_vidlock $desB_i2c $desB_addr #Check Deserializer status
    fi
    
    wait_with_timeout $pid $(($tout+1)) $dname $bus $addr
    ret=$?

    # kill any background process
    kill $pid 2>/dev/null

    return $ret
}

test_v4l2src_1920x1536_8by8() {
    local i=$1
    local csi=$2
    local fcnt=$3
    local tout=$4
    local dname=$5
    local bus=$6
    local addr=$7
    local tuple=${8:-'b|c'}
    local pid=0
    local ret=0
    local out="videoconvert ! xvimagesink"

    [[ "$nox" == "true" ]] && out="fakesink sync=false enable-last-sample=false"

    gst-launch-1.0 \
        v4l2src device=/dev/video-isx031-a-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_0 \
        v4l2src device=/dev/video-isx031-b-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_1 \
        v4l2src device=/dev/video-isx031-c-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_2 \
        v4l2src device=/dev/video-isx031-d-$desA_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_3 \
        v4l2src device=/dev/video-isx031-a-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_4 \
        v4l2src device=/dev/video-isx031-b-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_5 \
        v4l2src device=/dev/video-isx031-c-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_6 \
        v4l2src device=/dev/video-isx031-d-$desB_csi num-buffers=$fcnt ! \
        'video/x-raw,width=1920,height=1536,format=UYVY,pixel-aspect-ratio=1/1,framerate=30/1' ! comp.sink_7 \
        compositor name=comp \
        sink_0::xpos=0    sink_0::ypos=0    sink_0::width=1920 sink_0::height=1536 sink_0::zorder=1 \
        sink_1::xpos=1920 sink_1::ypos=0    sink_1::width=1920 sink_1::height=1536 sink_1::zorder=2 \
        sink_2::xpos=3840 sink_2::ypos=0    sink_2::width=1920 sink_2::height=1536 sink_2::zorder=3 \
        sink_3::xpos=5760 sink_3::ypos=0    sink_3::width=1920 sink_3::height=1536 sink_3::zorder=4 \
        sink_4::xpos=0    sink_4::ypos=1536 sink_4::width=1920 sink_4::height=1536 sink_4::zorder=5 \
        sink_5::xpos=1920 sink_5::ypos=1536 sink_5::width=1920 sink_5::height=1536 sink_5::zorder=6 \
        sink_6::xpos=3840 sink_6::ypos=1536 sink_6::width=1920 sink_6::height=1536 sink_6::zorder=7 \
        sink_7::xpos=5760 sink_7::ypos=1536 sink_7::width=1920 sink_7::height=1536 sink_7::zorder=8 \
	! ${out} &

    # Get the PID of the last background process
    pid=$!
    
    echo "Started GMSL a|b|c|d-0 and a|b|c|d-2 links $testcase test-run $i with PID: $pid"
    if [[ "$watch" == "true" ]]; then
	reg_max9x_vidlock $desA_i2c $desA_addr #Check Deserializer status
	reg_max9x_vidlock $desB_i2c $desB_addr #Check Deserializer status
    fi

    wait_with_timeout $pid $(($tout+1)) $dname $bus $addr
    ret=$?

    # kill any background process
    kill $pid 2>/dev/null

    return $ret
}

# Main loop checks shutdown flag
i=0
pass=0
fail=0
ign=0
pass1=0
fail1=0
ign1=0
err_baseline=$(dmesg | grep -i "error group 3 code 18" | wc -l)
err_count=$err_baseline

##################################
framecnt=330 #10s of frames
testvar1=${duration:-1} #default 1=10s
testvar2=${loop:-10} # default one loop
testvar3=${mux:-'a-0'} # watch a-0 deserilizer
testcase=${testcase:-'4by4'}
##################################
timeout=$(($testvar1*10))
framecnt=$(($framecnt*$testvar1))


echo "${NC}########################################"

#Check A/B Deserializers DEV_ID
val=$(reg_max9x_id $desA_i2c $desA_addr)
case ${val} in
    0x94)
	desA_name="max9296"
	;;
    0xa2|0xa3|0xa4)
	desA_name="max96724"
	;;
    *)
	echo "NO max9x Deserializer Found at i2c-$desA_i2c@0x$desA_addr!"
	exit 0
	;;
esac
echo " Found $desA_name GMSL Deserializer at i2c-$desA_i2c@0x$desA_addr!"

case "$(reg_max9x_id $desB_i2c $desB_addr)" in
    0x94)
	desB_name="max9296"
	;;
    0xa2|0xa3|0xa4)
	desB_name="max96724"
	;;
    *)
	echo "NO max9x Deserializer Found at i2c-$desB_i2c@0x$desB_addr!"
	exit 0
	;;
esac
echo " Found $desB_name GMSL Deserializer at i2c-$desB_i2c@0x$desA_addr!"

[[ $duration -eq 0 ]] && exit 0

#echo "$timeout = $framecnt"

[[ "$testcase" != "2by2" && "$testcase" != "4by4" && "$testcase" != "6by6"  && "$testcase" != "8by8" ]] && exit 0

#echo "${testvar3%-*}"
#echo "${testvar3#*-}"

[[ "${testvar3%-*}" != "a" && "${testvar3%-*}" != "b" && "${testvar3%-*}" != "c"  && "${testvar3%-*}" != "d" ]] && exit 0
[[ ${testvar3#*-} -gt 5 ]] && exit 0

echo "GMSL $desA_name A/B back-to-back $testcase #ofFrames=$framecnt [timeout=${timeout} sec streaming 1920x1536@30fps] #ofIteration=$testvar2"
reg_max9x_lnklock $desA_i2c $desA_addr #Check A Deserializer link status
reg_max9x_lnklock $desB_i2c $desB_addr #Check B Deserializer link status

while [[ "$shutdown_requested" == "false" ]]; do

    # back-to-back Testcases, ignore after 5 attempt for the rest of the test-runner
    if [[ $ign -lt 5 ]]; then

	echo -e "\n========================================"

	# Change 2by2 or 6by6 permutation
	[[ "${testcase}" == "2by2" && $desA_name == "max9296" ]] && desA_tuple="a|b"
	[[ "${testcase}" == "6by6" ]] && desA_tuple="b|c"

	is_ignored=false
	err_initial=$(dmesg | grep -i "error group 3 code 18" | wc -l)
	test_v4l2src_1920x1536_${testcase} $i $desA_csi $framecnt $(($timeout+2)) $desA_name $desA_i2c $desA_addr $desA_tuple
	ret=$?
	#echo $ret
	if [[ $ret -eq 0 ]]; then
	    reg_max9x_lnklock $desA_i2c $desA_addr #Check A Deserializer link status
	    echo "completed $testcase testrun $i unsuccessfully"
	    fail=$((fail+1))
	else
	    if [[ $ret -eq 255 ]]; then
		echo "ignored $testcase testrun $i"
		ign=$((ign+1))
		is_ignored=true
	    else
		echo "completed $testcase testrun $i successfully"
		pass=$((pass+1))
	    fi
	fi

	if [[ "$is_ignored" == "false" ]]; then
	    sleep 5 
	    echo "########################################"
	fi

	i=$((i+1))

    fi

    [[ $i -ge $testvar2 ]] && shutdown_requested=true

    # in any testcase if camera are not connected to the respective ports,
    # exit after 5 attempt
    [[ $ign -ge 5  && $ign1 -ge 5 ]] && exit 0

    # in 8by8 testcase if camera are not connected to the respective ports,
    # exit after 5 attempt
    [[ "${testcase}" == "8by8" && $ign -gt 5 ]] && exit 0

    # ignore after 5 attempt or in 8by8 testcase 
    [[ "${testcase}" == "8by8" || $ign1 -gt 5 ]] && continue

    # Change 2by2 or 6by6 permutation
    [[ "${testcase}" == "2by2" && $desB_name == "max9296" ]] && desB_tuple="a|b"
    [[ "${testcase}" == "6by6" ]] && desB_tuple="b|c"

    echo -e "$\n========================================"
    is_ignored=false
    err_initial=$(dmesg | grep -i "error group 3 code 18" | wc -l)
    test_v4l2src_1920x1536_${testcase} $i $desB_csi $framecnt $(($timeout+2)) $desB_name $desB_i2c $desB_addr $desB_tuple
    ret=$?
    #echo $ret
    if [[ $ret -eq 0 ]]; then
	reg_max9x_lnklock $desB_i2c $desB_addr #Check B Deserializer link status
	echo "completed $testcase testrun $i unsuccessfully"
	fail1=$((fail1+1))
    else
	if [[ $ret -eq 255 ]]; then
	    echo "ignored $testcase testrun $i"
	    ign1=$((ign1+1))
	    is_ignored=true
	else
	    echo "completed $testcase testrun $i successfully"
	    pass1=$((pass1+1))
	fi
    fi

    if [[ "$is_ignored" == "false" ]]; then
	sleep 5 
	echo "########################################"
    fi

    i=$((i+1))
    
done

err_count=$(dmesg | grep -i "error group 3 code 18" | wc -l)
echo "---------------------------------"
echo "GMSL isx031 camera links $testcase Back-to-Back v4l2src Stress-Test"
echo "Testvars: #ofFrames=$framecnt [1920x1536@30fps streaming for ~$timeout sec.] #ofIteration=$testvar2"
[[ "${testcase}" == "2by2" ]] && echo "GMSL $desA_name a|d-$desA_csi testruns=$(($pass+$fail+$ign)) (pass/fail/ignore=$pass/$fail/$ign)"
[[ "${testcase}" == "2by2" ]] && echo "GMSL $desB_name a|d-$desB_csi testruns=$(($pass1+$fail1+$ign1)) (pass/fail/ignore=$pass1/$fail1/$ign1)"
[[ "${testcase}" == "4by4" ]] && echo "GMSL $desA_name a|b|c|d-desA_csi testruns=$(($pass+$fail+$ign)) (pass/fail/ignore=$pass/$fail/$ign)"
[[ "${testcase}" == "4by4" ]] && echo "GMSL $desB_name a|b|c|d-$desB_csi testruns=$(($pass1+$fail1+$ign1)) (pass/fail/ignore=$pass1/$fail1/$ign1)"
[[ "${testcase}" == "6by6" ]] && echo "GMSL $desA_name a|b|c|d-desA_csi and $desB_name b|c-$desB_csi testruns=$(($pass+$fail+$ign)) (pass/fail/ignore=$pass/$fail/$ign)"
[[ "${testcase}" == "6by6" ]] && echo "GMSL $desB_name a|b|c|d-$desB_csi and $desA_name b|c-desA_csi testruns=$(($pass1+$fail1+$ign1)) (pass/fail/ignore=$pass1/$fail1/$ign1)"
[[ "${testcase}" == "8by8" ]] && echo "GMSL $desA_name a|b|c|d-$desA_csi and $desB_name a|b|c|d-$desB_csi testruns=$(($pass+$fail+$ign)) (pass/fail/ignore=$pass/$fail/$ign)"
echo "[HW_ERR_BAD_FRAME_DIM cnt=$(($err_count - $err_baseline)))]"
echo "exiting..."
