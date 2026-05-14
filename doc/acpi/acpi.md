## User Guide for ACPI SSDT ASL Compilation and Loading for Imaging Sensors

## Description
This document contains information of imaging specific ACPI SSDT ASL sources compilation and loading. It also contains information of how to construct media-ctl pipeline for imaging sensors described in ACPI SSDT, and how to verify the streaming of sensors.

## Create ASL file for imaging SSDT
Create ASL source file based on current hardware setup using reference ASL source file in ../acpi. Below are the good reference for different use cases:

| Use case | Reference ASL source file |
| --- | --- |
| 1x 2D sensor | max96724_li_isx031_gmsl.asl, max96724_sensing_isx031_gmsl.asl |
| 1x 3D sensor | max96724_rs_d457_gmsl.asl |
| 2x 2D sensor | max9296_d3_isx031_gmsl.asl |
| 4x 2D sensor on single DES | max96724_d3_isx031_gmsl.asl |
| 4x 2D sensor on single DES (mixed model) | max96724_mixed_isx031_gmsl.asl |
| 1x 2D sensor + 1x 3D sensor on single DES | max96724_mixed_isx031_d457_gmsl.asl |

## How to compile ACPI ASL source on Canonical Ubuntu 24.04
Pre-requisite:
    sudo apt-get install flex bison

Install acpica tools version 20260408 https://github.com/acpica/acpica/releases/tag/20260408

    wget https://github.com/acpica/acpica/releases/download/20260408/acpica-unix-20260408.tar.gz
    tar zxf ./acpica-unix-20260408.tar.gz
    cd acpica-unix-20260408/
    make
    sudo make install

Compile ASL source into AML file in acpi/sensor.asl

    iasl acpi/{sensor}.asl

## How to load imaging SSDT at boot time
Run helper script to generate initramfs image from ASL source file.

    ../../script/gen_ssdt.sh ../../acpi/{sensor}.asl

Add following line to /etc/default/grub for GRUB to load SSDT initramfs

    GRUB_EARLY_INITRD_LINUX_CUSTOM="img_ssdt.img"

Rebuild GRUB configuration

    sudo update-grub

Reboot system and inspect loading of SSDT in kernel dmesg

    dmesg | grep SSDT

You should see log similar to below:

    [    0.009303] ACPI: SSDT ACPI table found in initrd [kernel/firmware/acpi/isx031.aml][0x143d]
    ...
    [    0.009609] ACPI: Table Upgrade: install [SSDT-      - IMG_IPU]
    [    0.009611] ACPI: SSDT 0x00000000678E6000 00143D (v02        IMG_IPU  20260513 INTL 20250404)


## How to Verify Stream

### Construct media-ctl pipeline 

Run ../../script/acpi/mc-setup.sh to auto construct media-ctl pipeline.

> **Note:** Auto construct media-ctl pipeline for all links (regardless of 2D or 3D sensors) on all deserializers. 3D sensors default to depth and rgb streams, while 2D sensors default to yuv stream. Any unknown sensors will be skipped.

    ../../script/acpi/mc-setup.sh

> **Note:** If want to configure only DES0 single link, with 2D YUV sensor

    ../../script/acpi/mc-setup.sh des=0,link=0,stream=yuv

> **Note:** If want to configure only DES0 Link 0 with 2D YUV sensor, and Link 1 with 3D sensors

    ../../script/acpi/mc-setup.sh des=0,link=0,stream=yuv des=0,link=1,stream=depth,rgb

> **Note:** If want to configure only DES1 single link, with 3D depth and rgb sensors

    ../../script/acpi/mc-setup.sh des=1,link=1,stream=depth,rgb

### Verify stream using v4l2src

#### Sample Userspace Command for v4l2src

> **Note:** example for 2D sensor (isx031) stream or 3D sensor (d4xx) RGB stream

    gst-launch-1.0 v4l2src device=/dev/video0 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! glimagesink

### Verify stream using icamerasrc

> **Note:** Only work for 2D camera stream for now.

> **Note:** Have dependency on [ipu7-camera-hal PR](https://github.com/intel/ipu7-camera-hal/pull/44)

#### Camera Configuration File Setup for IPU75XA

Replace target system with recommended [ipu75xa](../../config/acpi/ipu75xa) setting

> **Note:** Add config below only if using x1 GMSL sensor.

    sudo cp -r ../../config/acpi/ipu75xa /etc/camera

#### Environment Setup

Export environment variables below

    unset XDG_RUNTIME_DIR
    export DISPLAY=:0; xhost +
    export GST_PLUGIN_PATH=/usr/lib/gstreamer-1.0
    export LIBVA_DRIVER_NAME=iHD
    export GST_GL_API=gles2
    export GST_GL_PLATFORM=egl
    export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig
    export LD_LIBRARY_PATH=/usr/local/lib/pkgconfig:/usr/local/lib:/usr/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu
    export logSink=terminal
    rm -rf ~/.cache/gstreamer-1.0

#### Sample Userspace Command for icamerasrc

    gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=acpi-1 printfps=true io-mode=mmap ! 'video/x-raw,format=UYVY,width=1920,height=1536' ! glimagesink sync=false

    gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false

