## Description

This document provides details of the configuration settings for the D457 GMSL sensor.

## Compile ACPI ASL file based on use case

>**Note:** for 1x D457 3D sensor use case
    ../../script/gen_ssdt.sh ../../acpi/d4xx_gmsl.asl

## Configure pipeline

>**Note:** for Depth and RGB streams only

    ../../script/acpi/mc-mixed.sh

>**Note:** for all streams

    ../../script/acpi/mc-mixed.sh des=0,link=0,stream=depth,rgb,ir,imu

## Create symlinks for video devices

>**Note:** This step is only necessary to stream with RealSense SDK. If you are using v4l2src or v4l2-ctl, you can skip this step and use the video device directly.

    sudo ../../script/d4xx/upstream-rs-enum.sh

## How to Verify Stream

### Verify stream using v4l2src

#### Sample Userspace Command for v4l2src

> **Note:** Get device and RGB stream from output of mc-mixed.sh

    gst-launch-1.0 v4l2src device=/dev/video4 ! 'video/x-raw,format=YUY2,width=640,height=480,framerate=30/1,pixel-aspect-ratio=1/1' ! glimagesink

If already created symlinks for video devices, you may also use the symlinked video device for streaming. For example:

    gst-launch-1.0 v4l2src device=/dev/video-rs-color-0 ! 'video/x-raw,format=YUY2,width=640,height=480,framerate=30/1,pixel-aspect-ratio=1/1' ! glimagesink

### Verify stream using v4l2-ctl

>**Note:** v4l2-ctl does not have output on monitor, only printout in terminal.

Modify video device according to output of mc-mixed.sh

    v4l2-ctl -d /dev/video0 --stream-mmap 

### Verify stream using RealSense SDK

Clone librealsense repo

    git clone https://github.com/realsenseai/librealsense.git
    cd librealsense
    git fetch origin pull/15007/head:pr-15007
    git checkout pr-15007
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
    make -j2
    cd build/Release

Verify stream using rs-depth

>**Note:** rs-depth will show output in terminal

    ./rs-depth

Verify stream using rs-color

>**Note:** rs-color will show output in terminal

    ./rs-color

Verify stream using rs-multicam

>**Note:** rs-multicam will show output in graphical interface

    ./rs-multicam

Verify stream using realsense-viewer

>**Note:** realsense-viewer will show output in a graphical interface and require user to manually select the streams on the GUI.

    ./realsense-viewer
