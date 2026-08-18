## Description

This document details the steps to validate ACPI-enumerated GMSL sensors, providing essential information for system integration.

For Kernel space ASL source file creation and compilation, please refer to [kernelspace.md](./kernelspace.md).

## Table of Contents

- [Introduction to ASL configured system](#introduction-to-asl-configured-system)
    - [new mc-setup script](#new-mc-setup-script)
    - [new libcamhal configuration files](#new-libcamhal-configuration-files)
- [How to use mc-setup.sh](#how-to-use-mc-setupsh)
    - [Construct pipeline](#construct-pipeline)
    - [Sample Commands](#sample-commands)
    - [Advanced - Per stream Configuration](#advanced---per-stream-configuration)
- [Stream verification](#stream-verification)
    - [Sanity Streaming Test using v4l2-ctl](#sanity-streaming-test-using-v4l2-ctl)
    - [GStreamer streaming using v4l2src](#gstreamer-streaming-using-v4l2src)
    - [GStreamer streaming using icamerasrc](#gstreamer-streaming-using-icamerasrc)

## Introduction to ASL configured system

### new mc-setup script
When using an ASL-configured system, the I2C bus enumerated by the GMSL drivers is dynamic and can differ on every boot. If the legacy method of creating a static media-ctl pipeline in the libcamhal configuration is used, the pipeline will not be valid on every boot and sensor streaming will fail. To address this issue, a new script called **mc-setup.sh** is introduced to dynamically construct the media-ctl pipeline based on the current ACPI enumeration. mc-setup.sh uses the ACPI path of each hardware component (deserializer, serializer, sensor) to construct the media-ctl pipeline.

> 2D sensors refer to sensors that only have single stream, such as ISX031 (YUV), AR0234 (RAW Bayer).

> 3D sensors refer to sensors that have multiple streams, such as D457 (Depth, RGB, IR, IMU).

<details>
<summary> Default Stream for 2D and 3D sensors </summary>

| Sensor | Default Stream |
| ---    | --- |
| AR0234 | Single |
| D457   | Depth+RGB |
| ISX031 | Single |

The script can be used for MIPI and GMSL sensors. There are default streams for each sensor type. For 2D sensors, the default stream is the only stream available; for 3D sensors, the default stream is Depth+RGB.

</details>

<details>
<summary> Supported Sensors </summary>

GMSL Deserializers: MAX9296A, MAX96724
GMSL Serializers: MAX9295A
GMSL 2D RAW sensors: AR0234
GMSL 2D YUV sensors: ISX031
GMSL 3D YUV sensors: D457

MIPI 2D YUV sensors: ISX031
MIPI 2D RAW sensors: OV13B10

</details>

<p align="right">(<a href="#how-to-use-mc-setupsh"> How to use mc-setup.sh</a>)</p>

### new libcamhal configuration files

> 2D YUV sensors (e.g. ISX031 GMSL) : acpi.xml or acpi.json

A new libcamhal configuration file called **acpi.xml or acpi.json** is created. It is designed to be sensor agnostic so it can be reused for different 2D YUV sensors, provided that mc-setup is maintained properly and extended when new hardware or configuration needs arise.

> 2D RAW sensors (e.g. AR0234 GMSL) : [ar0234.xml](../../config/ar0234/ipu6epmtl/sensors/ar0234.xml)

For 2D RAW sensor that requires 3A and PSYS support, it will require dedicated Graph Setting and Tuning Files, hence a dedicated libcamhal config file is needed instead of sharing acpi.xml or acpi.json with YUV sensors.

> 3D YUV sensors (e.g. D457 GMSL) : d4xx.xml or d4xx.json

A new libcamhal configuration file called **d4xx.xml or d4xx.json** is created. It is **NOT** sensor agnostic as 3D sensors might have different subdev and streams supported.

## How to use mc-setup.sh

Prerequisites:

1. ACPI ASL created correctly.
2. ACPI ASL loaded correctly.
3. Kernel driver probed successfully.

### Construct pipeline

Before elaborating, here are some definitions of 2D and 3D sensors and the kinds of configurations that mc-setup.sh can support.

2D sensors are sensors that only have single stream, such as ISX031 (YUV), AR0234 (RAW Bayer). \
3D sensors are sensors that have multiple streams, such as D457 (Depth, RGB, IR, IMU). \
Default streams for 3D sensors are **Depth+RGB** unless specified.

There are **limitations** of only having 4 internal pipes for deserializer, for both MAX9296 and MAX96724. Hence, **total streams cannot exceed 4 streams per deserializer**. This limitation will be observed when there are 3D sensors involved in one of the links.

Examples below will use MAX96724 as example.

**2D setup**

- DES{N}
    - Link 0 - 2D sensor (model A)
    - Link 1 - 2D sensor (model A)
    - Link 2 - 2D sensor (model A)
    - Link 3 - 2D sensor (model A)

**3D setup**

- DES{N}
    - Link 0 - 3D sensor (model A)
    - Link 1 - 3D sensor (model A)

**2D+2D setup (mix-and-match)**

- DES{N}
    - Link 0 - 2D sensor (model A)
    - Link 1 - 2D sensor (model B)
    - Link 2 - 2D sensor (model C)
    - Link 3 - 2D sensor (model D)

**2D+3D setup (mix-and-match)**

- DES{N}
    - Link 0 - 2D sensor (model A)
    - Link 1 - 2D sensor (model B)
    - Link 2 - 3D sensor (model C)

#### Sample Commands

<details>
<summary> All default streams </summary>

### Command

    ../../script/acpi/mc-setup.sh

### Output

>2D setup

    Configuration summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video0
    DES0 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video1
    DES0 LINK2      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video2
    DES0 LINK3      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video3

>3D setup

    Configuration summary:
    DES0 LINK0      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video0
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video4
    DES0 LINK1      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video1
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video5
    DES1 LINK0      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video16
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video20
    DES1 LINK1      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video17
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video21

>2D+2D setup

    Configuration summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video0
    DES0 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video1
    DES0 LINK2      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video2
    DES0 LINK3      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video3

>2D+3D setup

    Configuration summary:
    DES1 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video16
    DES1 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video17
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22

</details>

<details>
<summary> Selected Deserializer </summary>

### Command

> command 1: \
DES0, all links, default streams

    ../../script/acpi/mc-setup.sh des=0

> command 2: \
DES1, all links, default streams

    ../../script/acpi/mc-setup.sh des=1

### Output

> DES0 2D+2D, DES1 2D+3D setup

    # command 1
    Configuration summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video0
    DES0 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video1
    DES0 LINK2      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video2
    DES0 LINK3      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video3

    # command 2
    Configuration summary:
    DES1 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video16
    DES1 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video17
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22


</details>

<details>
<summary> Selected links (default stream)</summary>

### Command

> command 1: \
DES0, \
link 0

    ../../script/acpi/mc-setup.sh des=0,link=0

> command 2: \
DES0, \
link 1 \
link 2

    ../../script/acpi/mc-setup.sh des=0,link=1 des=0,link=2

> command 3: \
DES0, \
link 2 \
DES1, \
link 2

    ../../script/acpi/mc-setup.sh des=0,link=2 des=1,link=2

### Output

> DES0 2D+2D, \
DES1 2D+3D setup

    # command 1:
    Configuration Summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video0

    # command 2
    Configuration Summary:
    DES0 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video1
    DES0 LINK2      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video2

    # command 3
    Configuration Summary:
    DES0 LINK2      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video2
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22

</details>

<details>
<summary> Selected Stream from Selected Link - 3D ONLY </summary>

### Command

> command 1: \
DES1, \
link 2 (3D ONLY), \
\- Depth

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=depth

> command 2: \
DES1, \
link 2 (3D ONLY), \
\- Depth \
\- RGB

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=depth,rgb

> command 3: \
DES1, \
link 2 (3D ONLY), \
\- Depth \
\- RGB \
\- IR \
\- IMU

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=depth,rgb,ir,imu

> command 4: \
DES1, \
link 0 (2D), \
\- YUV \
link 2 (3D ONLY), \
\- Depth \
\- RGB \
\- IR

    ../../script/acpi/mc-setup.sh des=1,link=0 des=1,link=2,stream=depth,rgb,ir

### Output
> DES1 2D+3D setup

    # command 1:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18

    # command 2:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22

    # command 3:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20
                    Stream          [imu]    38x1       Y8_1X8        50.000 FPS -->  /dev/video16

    # command 4:
    Configuration summary:
    DES1 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video16
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20

</details>

### Advanced - Per stream Configuration

>**IMPORTANT**: \
Make sure you are familiar with how to select different links and/or streams from the previous section. This section only focus on how to configure the streams for selected link(s) and/or stream(s).

<details>
<summary> Change Resolution </summary>

>IMPORTANT: For supported resolution and format, please refer to ../{sensor}/userspace-{interface}.md for each sensor if applicable.

Commands in this section only change the resolution of the stream, if applicable.

### Command

> command 1: \
DES0, \
link 0 (2D) -> 1280x720

    ../../script/acpi/mc-setup.sh des=0,link=0,res=1280x720

> command 2: \
DES0, \
link 0 (2D) -> 1280x720 \
link 1 (2D) -> reuse current

    ../../script/acpi/mc-setup.sh des=0,link=0,res=1280x720 des=0,link=1

> command 3: \
DES1, \
link 2 (3D ONLY), \
\- Depth stream -> 1280x720 \
\- RGB stream -> reuse current \
\- IR stream -> 1280x720.

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=[depth,res=1280x720],[rgb],[ir,res=1280x720]

> command 4: \
DES1, \
link 1 (2D) -> 1920x1080 \
link 2 (3D ONLY), \
\- Depth stream -> 1280x720 \
\- RGB stream -> default \
\- IR stream -> 1280x720

    ../../script/acpi/mc-setup.sh \
    des=1,link=1,res=1920x1080 \
    des=1,link=2,stream=[depth,res=1280x720],[rgb],[ir,res=1280x720]

### Output

> DES0 2D+2D, \
DES1 2D+3D setup

    # command 1:
    Configuration summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video0

    # command 2:
    Configuration summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video0
    DES0 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1536  UYVY8_1X16    30.000 FPS -->  /dev/video1

    # command 3:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20

    # command 4:
    Configuration summary:
    DES1 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1080  UYVY8_1X16    60.000 FPS -->  /dev/video17
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20

</details>

<details>
<summary> Change Format </summary>

Commands in this section only change the format of the stream, if applicable.

### Command

> command 1: \
DES0, \
link 0 -> UYVY8_1X16

    ../../script/acpi/mc-setup.sh des=0,link=0,format=UYVY8_1X16

> command 2: \
DES1, \
link 1 (2D), -> reuse current \
link 2 (3D ONLY), \
\- Depth -> FIXED

    ../../script/acpi/mc-setup.sh des=1,link=1 \
    des=1,link=2,stream=depth,format=FIXED

> command 3: \
DES1, \
link 2 (3D ONLY), \
\- Depth stream -> UYVY8_1X16 \
\- RGB stream -> YUYV8_1X16 \
\- IR stream -> Y8_1X8 \
\- IMU stream -> Y8_1X8

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=[depth,format=UYVY8_1X16],[rgb,format=YUYV8_1X16],[ir,format=Y8_1X8],[imu,format=Y8_1X8]

### Output

> DES1 2D+3D setup

    # command 1:
    Configuration summary:
    DES0 LINK0      Sensor model    isx031
                    Stream          [single] 1280x720   UYVY8_1X16       n/a FPS -->  /dev/video0

    # command 2:
    Configuration summary:
    DES1 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1080  UYVY8_1X16    60.000 FPS -->  /dev/video17
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   FIXED         30.000 FPS -->  /dev/video18

    # command 3:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20
                    Stream          [imu]    38x1       Y8_1X8       400.000 FPS -->  /dev/video16

</details>

<details>
<summary> Change FPS </summary>

Commands in this section only change the FPS of the stream, if applicable.

### Command

> command 1: \
DES1, \
link 0 -> 60fps

    ../../script/acpi/mc-setup.sh des=1,link=0,fps=60

> command 2: \
DES1, \
link 1 (2D), -> reuse current \
link 2 (3D ONLY), \
\- Depth -> 5fps

    ../../script/acpi/mc-setup.sh des=1,link=1 \
    des=1,link=2,stream=depth,fps=5

> command 3: \
DES1, \
link 2 (3D ONLY), \
\- Depth stream -> 30fps \
\- RGB stream -> 5fps \
\- IR stream -> 30fps \
\- IMU stream -> 400fps

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=[depth,fps=30],[rgb,fps=5],[ir,fps=30],[imu,fps=400]

### Output

> 2D+3D setup

    # command 1:
    Configuration summary:
    DES1 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1080  UYVY8_1X16    60.000 FPS -->  /dev/video16

    # command 2:
    Configuration summary:
    DES1 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1080  UYVY8_1X16    60.000 FPS -->  /dev/video17
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16     5.000 FPS -->  /dev/video18

    # command 3:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16     5.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20
                    Stream          [imu]    38x1       Y8_1X8       400.000 FPS -->  /dev/video16

</details>

<details>
<summary> Mixed Combination to configure Resolution, Format and FPS </summary>

Commands in this section show mixed combinations for configuring resolution, format, and FPS.
The commands **combine the tokens** from the previous sections into the same command.

### Command

> command 1: \
DES1, \
link 0 -> 1920x1080 @ 60fps

    ../../script/acpi/mc-setup.sh des=1,link=0,res=1920x1080,fps=60

> command 2: \
DES1, \
link 1 (2D), -> UYVY8_1X16, 1920x1080 @ 60fps \
link 2 (3D ONLY), \
\- Depth -> FIXED, 1280x720 @ 5fps

    ../../script/acpi/mc-setup.sh des=1,link=1,format=UYVY8_1X16,res=1920x1080,fps=60 \
    des=1,link=2,stream=depth,format=FIXED,res=1280x720,fps=5

> command 3: \
DES1, \
link 2 (3D ONLY), \
\- Depth stream -> UYVY8_1X16, 1280x720 @ 30fps \
\- RGB stream -> YUYV8_1X16, 1280x800 @ 30fps \
\- IR stream -> Y8_1X8, 1280x720 @ 30fps \
\- IMU stream -> Y8_1X8, 38x1 @ 400fps

    ../../script/acpi/mc-setup.sh des=1,link=2,stream=[depth,format=UYVY8_1X16,res=1280x720,fps=30],[rgb,format=YUYV8_1X16,res=1280x800,fps=30],[ir,format=Y8_1X8,res=1280x720,fps=30],[imu,format=Y8_1X8,res=38x1,fps=400]

### Output

> DES1 2D+3D setup

    # command 1:
    Configuration summary:
    DES1 LINK0      Sensor model    isx031
                    Stream          [single] 1920x1080  UYVY8_1X16    60.000 FPS -->  /dev/video16

    # command 2:
    Configuration summary:
    DES1 LINK1      Sensor model    isx031
                    Stream          [single] 1920x1080  UYVY8_1X16    60.000 FPS -->  /dev/video17
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   FIXED          5.000 FPS -->  /dev/video18

    # command 3:
    Configuration summary:
    DES1 LINK2      Sensor model    d4xx
                    Stream          [depth]  1280x720   UYVY8_1X16    30.000 FPS -->  /dev/video18
                    Stream          [rgb]    1280x800   YUYV8_1X16    30.000 FPS -->  /dev/video22
                    Stream          [ir]     1280x720   Y8_1X8        30.000 FPS -->  /dev/video20
                    Stream          [imu]    38x1       Y8_1X8       400.000 FPS -->  /dev/video16

</details>

</details>

---
## Stream verification

### Sanity Streaming Test using v4l2-ctl

>**Pro:** \
v4l2-ctl can be used directly once mc-setup is completed; it is also more lightweight than v4l2src since it does not require GStreamer.

>**Con:** \
no preview window; it only shows streaming status in terminal.

#### Sample Command

    v4l2-ctl -d /dev/video{X} --stream-mmap --stream-count=150

#### Sample output

    v4l2-ctl -d /dev/video5 --stream-mmap --stream-count=150
    <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 29.99 fps
    <<<<<<<<<<<<<<<<<<<<<<<<<<<< 29.99 fps
    <<<<<<<<<<<<<<<<<<<<<<<<<<<< 29.99 fps
    <<<<<<<<<<<<<<<<<<<<<<<<<<<< 29.99 fps
    <<<<<<<<<<<<<<<<<<<<<<<<<<<< 29.99 fps
    <<<<<<<<<<<<<<<<<<<<<<<<<<<<

---
### GStreamer streaming using v4l2src

>**Pro:**\
v4l2src can directly be used once mc-setup is completed without any libcamhal configuration files setup.

>**Con:**\
v4l2src does not support DMABuf which might hit some performance issue.

#### Sample Command

    gst-launch-1.0 v4l2src device=/dev/video{X} ! 'video/x-raw,format={FORMAT},width={WIDTH},height={HEIGHT},framerate={FPS}/1,pixel-aspect-ratio=1/1' ! glimagesink

#### Sample Output

    Setting pipeline to PAUSED ...
    Pipeline is live and does not need PREROLL ...
    Got context from element 'sink': gst.gl.GLDisplay=context, gst.gl.GLDisplay=(GstGLDisplay)"\(GstGLDisplayX11\)\ gldisplayx11-0";
    Pipeline is PREROLLED ...
    Setting pipeline to PLAYING ...
    New clock: GstSystemClock
    Redistribute latency...
    Got EOS from element "pipeline0".
    Execution ended after 0:00:05.426540632
    Setting pipeline to NULL ...
    Freeing pipeline ...

---
### GStreamer streaming using icamerasrc

>**Pro:** \
icamerasrc supports DMABuf which offers better performance.

>**Con:** \
Have dependency on [ipu7-camera-hal PR64](https://github.com/intel/ipu7-camera-hal/pull/64)

Prerequisites:

**ipu7-camera-hal already cloned and compiled previously**

    cd ipu7-camera-hal
    git fetch origin pull/64/head:pr-64
    git checkout pr-64

    # Rebuild and Reinstall ipu7-camera-hal

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

#### Sample Command for 2D GMSL YUV sensor

Replace the device-name, format, width and height with the correct values for the sensor.

DMA Command

    gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=acpi-{X} printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format={FORMAT},width={WIDTH},height={HEIGHT}' ! glimagesink sync=false

MMAP Command

    gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=acpi-{X} printfps=true io-mode=mmap ! 'video/x-raw,format={FORMAT},width={WIDTH},height={HEIGHT}' ! glimagesink sync=false



<details>
<summary> device-name </summary>

|Link| device-name |
|:---:|:---: |
|0/A| acpi-1 |
|1/B| acpi-2 |
|2/C| acpi-3 |
|3/D| acpi-4 |
|4/E| acpi-5 |
|5/F| acpi-6 |
|6/G| acpi-7 |
|7/H| acpi-8 |

</details>

<details>
<summary> io-mode </summary>

|use case| io-mode | caps |
|:---:|:---: |---|
|DMA| dma_mode | 'video/x-raw(memory:DMABuf),drm-format={},width={},height={}' |
|MMAP| mmap | 'video/x-raw,format={},width={},height={}' |

</details>

<details>
<summary> num-vc </summary>

num-vc property is used to start the stream concurrently.
For multi-streaming case, it is possible to set num-vc=1 and start the stream one by one.

|use case| num-vc |
|:---:|:---: |
|1x stream | 1 |
|2x stream | 2 |
|3x stream | 3 |
|4x stream | 4 |
|5x stream | 5 |
|6x stream | 6 |
|7x stream | 7 |
|8x stream | 8 |

</details>

<details>
<summary> configuration </summary>

| Format | Resolution |
| :---: |:---: |
| UYVY8_1X16 | 1280x720, 1920x1080, 1920x1536 |

</details>

</details>

#### Sample Command for 2D GMSL RAW sensor

- (e.g.) AR0234 GMSL refer to [../ar0234/userspace-gmsl.md](../ar0234/userspace-gmsl.md#sensor-verification).


#### Sample Command for 3D GMSL YUV sensor

- (e.g.) D457 GMSL refer to [../d4xx/userspace-gmsl.md](../d4xx/userspace-gmsl.md#sensor-verification).


#### Sample Command for Mix-and-Match 2D+3D GMSL YUV sensor

<details>
<summary> link 0 (2D) + link 2 (3D, Depth+RGB streams) </summary>

    gst-launch-1.0 \
    icamerasrc num-buffers=-1 num-vc=3 scene-mode=normal device-name=acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format={FORMAT},width={WIDTH},height={HEIGHT}' ! glimagesink sync=false \
    icamerasrc num-buffers=-1 num-vc=3 scene-mode=normal device-name=d4xx-3-depth printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format={FORMAT},width={WIDTH},height={HEIGHT}' ! glimagesink sync=false \
    icamerasrc num-buffers=-1 num-vc=3 scene-mode=normal device-name=d4xx-3-rgb printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format={FORMAT},width={WIDTH},height={HEIGHT}' ! glimagesink sync=false

</details>

 <p align="right">(<a href="#description">back to top</a>)</p>
