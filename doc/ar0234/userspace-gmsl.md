## Description

This document details the configuration settings for the AR0234 GMSL sensor, providing essential information for system integration. The table below presents the key parameters and their respective values used during system setup and validation.

## Table of Contents

- [Hardware Connection](#hardware-connection)
  - [MAX9296 AIC (REV B) Connection](#max9296-aic-rev-b-connection)
  - [MAX96724 AIC (C-PHY) (REV A) Connection](#max96724-aic-c-phy-rev-a-connection)
  - [MAX96724 AIC (C-PHY) (REV B) Connection](#max96724-aic-c-phy-rev-b-connection)
  - [MAX96724 AIC (D-PHY) (REV B) Connection](#max96724-aic-d-phy-rev-b-connection)
  - [MAX96724 AIC (C-PHY to D-PHY Adapter) (REV B) Connection](#max96724-aic-c-phy-to-d-phy-adapter-rev-b-connection)
- [ACPI Setup - BIOS Configuration](#acpi-setup---bios-configuration)
  - [Sensor ACPI HID](#sensor-acpi-hid)
  - [BIOS Settings for IPU6EPMTL](#bios-settings-for-ipu6epmtl)
- [ACPI Setup - ASL Configuration](#acpi-setup---asl-configuration)
  - [ASL Configuration for IPU6EPMTL](#asl-configuration-for-ipu6epmtl)
  - [ASL Configuration for IPU75XA](#asl-configuration-for-ipu75xa)
  - [ASL Configuration for IPU8](#asl-configuration-for-ipu8)
- [Libcamhal Configuration File Setup (BIOS Configured Systems)](#libcamhal-configuration-file-setup-bios-configured-systems)
  - [Libcamhal Config for IPU6EPMTL](#libcamhal-config-for-ipu6epmtl)
- [Libcamhal Configuration File Setup (ASL Configured Systems)](#libcamhal-configuration-file-setup-asl-configured-systems)
  - [Libcamhal Config for IPU6EPMTL](#libcamhal-config-for-ipu6epmtl-1)
  - [Libcamhal Config for IPU75XA](#libcamhal-config-for-ipu75xa)
  - [Libcamhal Config for IPU8](#libcamhal-config-for-ipu8)
- [Libcamhal Tuning File Setup](#libcamhal-tuning-file-setup)
  - [Libcamhal Tuning for IPU6EPMTL](#libcamhal-tuning-for-ipu6epmtl)
  - [Libcamhal Tuning for IPU75XA](#libcamhal-tuning-for-ipu75xa)
  - [Libcamhal Tuning for IPU8](#libcamhal-tuning-for-ipu8)
- [Auto Media-Ctl Routing Setup (ASL Configured Systems)](#auto-media-ctl-routing-setup-asl-configured-systems)
- [Sensor Verification](#sensor-verification)
- [Stream Verification](#stream-verification)
  - [Environment Setup](#environment-setup)
  - [Stream with GStreamer icamerasrc](#stream-with-gstreamer-icamerasrc)
    - [Device Name Selection](#device-name-selection)
    - [Frame Buffer Memory Type (IO Mode) Selection](#frame-buffer-memory-type-io-mode-selection)
    - [Sensor Resolution Selection](#sensor-resolution-selection)
    - [Sensor Format Selection](#sensor-format-selection)
    - [Multi-Stream Selection](#multi-stream-selection)
      - [Multiprocessing Multi-Stream](#multiprocessing-multi-stream)
      - [Multithreading Multi-Stream](#multithreading-multi-stream)
- [Streaming Result](#streaming-result)
  - [Highest Bandwidth Configuration](#highest-bandwidth-configuration)

## Hardware Connection

This section describes the physical AIC (Add-In Card) hardware setup, including link port layout and jumper configurations for MIPI PHY selection.

### MAX9296 AIC (REV B) Connection

> **Note:** Samtec cables and an external power supply are required to connect the MAX9296 AIC to the baseboard.

![link-port](../images/max9296-fabb-dphy.png)

### MAX96724 AIC (C-PHY) (REV A) Connection

> **Note:** The MAX96724 AIC (REV A) supports only C-PHY connections, selectable via the J14 jumper highlighted in the image below.

![link-port](../images/max96724-faba-cphy.png)

### MAX96724 AIC (C-PHY) (REV B) Connection

> **Note:** The MAX96724 AIC (REV B) supports both C-PHY and D-PHY connections, selectable via the J14 jumper.

The image below shows the C-PHY setup.

![link-port](../images/max96724-fabb-cphy.png)

### MAX96724 AIC (D-PHY) (REV B) Connection

> **Note:** Ensure the J14 jumper pins are oriented toward the D-PHY connector, as shown in the image below.

The image below shows the D-PHY setup.

![link-port](../images/max96724-fabb-dphy.png)

### MAX96724 AIC (C-PHY to D-PHY Adapter) (REV B) Connection

The image below shows the C-PHY to D-PHY adapter setup.

![link-port](../images/max96724-fabb-cphy-dphy.png)

The following sections show the BIOS settings for each platform. Configure the BIOS for the platform in use.

>**Note:** If you want to configure ACPI using ASL, please refer to the [ASL configuration](#acpi-setup---asl-configuration) section below.

---
## ACPI Setup - BIOS Configuration

Using the BIOS configuration exercises the [ipu-acpi](../../drivers/media/platform/intel/) and [max9x](../../drivers/media/i2c/max9x/) drivers.

### Sensor ACPI HID

Use the sensor ACPI HID in the **Custom HID** field.

| Vendor          | Sensor ACPI HID |
|-----------------|:---------------:|
| D3 Embedded     | INTC0234        |

### BIOS Settings for IPU6EPMTL

<details>
<summary>MAX9296 DPHY + 2x AR0234</summary>
<p align="left">(<a href="#max9296-aic-rev-b-connection">Back to Hardware Setup</a>)</p>

> **Note:** No control logic or external clock is required.

>**BIOS Camera Option 1 Path:**\
 `Intel Advanced Menu`->`System Agent (SA) Configuration`->`MIPI Camera Configuration` -> `Camera Option 1` -> **Enabled**

|                            | Camera1 Link options |
|---                         |---                   |
| Sensor Model               | User Custom          |
| Custom HID                 | INTC0234             |
| Lanes Clock division       | 4 4 2 2              |
| CRD Version                | CRD-D                |
| GPIO control               | No Control Logic     |
| Camera position            | Front                |
| Flash Support              | Driver default       |
| Privacy LED                | Driver default       |
| Rotation                   | 90                   |
| PPR Value                  | 2                    |
| PPR Unit                   | 2                    |
| Camera module name         |                      |
| MIPI port                  | 0                    |
| LaneUsed                   | x2                   |
| MCLK                       | 19200000             |
| EEPROM Type                | ROM_NONE             |
| VCM Type                   | VCM_NONE             |
| Number of I2C Components   | 3                    |
| I2C Channel                | I2C1                 |
| Device 0                   |                      |
| I2C Address                | 48                   |
| Device Type                | Sensor               |
| Device 1                   |                      |
| I2C Address                | 44                   |
| Device Type                | Sensor               |
| Device 2                   |                      |
| I2C Address                | 50                   |
| Device Type                | Sensor               |
| Customize Device ID List   |                      |
| Customize Device ID Number | 17                   |
| Customize Device ID Number | 18                   |
| Customize Device ID Number | 19                   |
| Flash Driver Selection     | Disabled             |

</details>

---
## ACPI Setup - ASL Configuration

<h3>IMPORTANT: Turn off the BIOS setting to use the ASL method.</h3>

>**BIOS Camera Option 1 Path:**\
 `Intel Advanced Menu`->`System Agent (SA) Configuration`->`MIPI Camera Configuration` -> `Camera Option 1` -> **Disabled**

>**BIOS Camera Option 2 Path:**\
 `Intel Advanced Menu`->`System Agent (SA) Configuration`->`MIPI Camera Configuration` -> `Camera Option 2` -> **Disabled**

Using the ASL configuration exercises the [maxim-serdes](../../drivers/media/i2c/maxim-serdes/) drivers.

To compile ASL and load an SSDT overlay image, refer to [acpi/kernelspace.md](../acpi/kernelspace.md#compile-and-load).

### ASL Configuration for IPU6EPMTL

<details>
<summary> MAX9296 DPHY + 2x D3 AR0234 GMSL sensors use case </summary>
<p align="left">(<a href="#max9296-aic-rev-b-connection">Back to Hardware Setup</a>)</p>

>**ASL:** [max9296_d3_ar0234.asl](../../acpi/ipu6/max9296_d3_ar0234.asl)

</details>

### ASL Configuration for IPU75XA

<details>
<summary> MAX96724 CPHY + 8x D3 AR0234 GMSL sensors use case </summary>
<p align="left">(<a href="#max96724-aic-c-phy-rev-b-connection">Back to Hardware Setup</a>)</p>

>**ASL:** [max96724_d3_ar0234.asl](../../acpi/ipu7/max96724_d3_ar0234.asl)

</details>

### ASL Configuration for IPU8

<details>
<summary> MAX96724 CPHY + 8x D3 AR0234 GMSL sensors use case </summary>
<p align="left">(<a href="#max96724-aic-c-phy-rev-b-connection">Back to Hardware Setup</a>)</p>

>**ASL:** [max96724_d3_ar0234.asl](../../acpi/ipu8/max96724_d3_ar0234.asl)

</details>

---
## Libcamhal Configuration File Setup (BIOS Configured Systems)

#### Libcamhal Config for IPU6EPMTL

<details>
<summary>2x GMSL sensors use case </summary>

Please use recommended config from [ipu6epmtl](../../config/ar0234/ipu6epmtl).

    sudo cp -r ../../config/ar0234/ipu6epmtl /etc/camera
    sudo sed -i '/availableSensors/c\        <availableSensors value="ar0234"/>' /etc/camera/ipu6epmtl/libcamhal_profile.xml

</details>

---
## Libcamhal Configuration File Setup (ASL Configured Systems)

#### Libcamhal Config for IPU6EPMTL

<details>
<summary>2x GMSL sensors use case </summary>

Please use config from [ipu6epmtl](../../config/ar0234/ipu6epmtl).

    sudo cp -r ../../config/ar0234/ipu6epmtl /etc/camera

</details>

#### Libcamhal Config for IPU75XA

<details>
<summary>8x GMSL sensors use case </summary>

Please use recommended config from [ipu75xa](../../config/ar0234/ipu75xa).

    sudo cp -r ../../config/ar0234/ipu75xa /etc/camera

</details>

#### Libcamhal Config for IPU8

<details>
<summary>8x GMSL sensors use case </summary>

Please use recommended config from [ipu8](../../config/ar0234/ipu8).

    sudo cp -r ../../config/ar0234/ipu8 /etc/camera

</details>

---
## Libcamhal Tuning File Setup

RAW sensor required respective tuning configuration files below for streaming:

1. Arithmetic Image Quality Binary (AIQB)
2. Graph Setting Configuration (GCSS)

#### Libcamhal Tuning for IPU6EPMTL

1. Download [AR0234_TGL_10bits.aiqb](https://github.com/intel/ipu6-camera-hal/blob/iotg_ipu6/config/linux/ipu6epmtl/AR0234_TGL_10bits.aiqb)
2. Download [graph_settings_ar0234.xml](https://github.com/intel/ipu6-camera-hal/blob/iotg_ipu6/config/linux/ipu6epmtl/gcss/graph_settings_ar0234.xml)
3. Copy the files into target system:

    ```
    sudo cp AR0234_TGL_10bits.aiqb /etc/camera/ipu6epmtl
    sudo cp graph_settings_ar0234.xml /etc/camera/ipu6epmtl/gcss
    ```

#### Libcamhal Tuning for IPU75XA

The tuning files are available in [ipu75xa](../../config/ar0234/ipu75xa). In the future, this will be hosted at [here](https://github.com/intel/ipu7-camera-hal/tree/main/config/linux/ipu75xa).

#### Libcamhal Tuning for IPU8

The tuning files are available in [ipu8](../../config/ar0234/ipu8). In the future, this will be hosted at [here](https://github.com/intel/ipu7-camera-hal/tree/main/config/linux/ipu8).

---
## Auto Media-Ctl Routing Setup (ASL Configured Systems)

Please refer to [How to use mc-setup.sh](../acpi/userspace-gmsl.md#how-to-use-mc-setupsh)

---
## Sensor Verification

After completing the setup, verify that the sensor is probed and registered with the V4L2 framework:

    media-ctl -p

When using the BIOS configuration, the output for a single camera should look like the example below.

![media-ctl output](img-entity-ar0234-gmsl.png)

---
## Stream Verification

Follow the sections below to verify streaming:

- [Environment Setup](#environment-setup)
- [Stream with GStreamer icamerasrc](#stream-with-gstreamer-icamerasrc)

For more details on verification setup guide, please refer to [construct-pipeline](../acpi/userspace-gmsl.md#construct-pipeline) & [stream-verification](../acpi/userspace-gmsl.md#stream-verification).

### Environment Setup

Export the environment variables below:

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

For IPU6 only, configure the `isys_freq` value:

    sudo bash -c 'echo "options intel-ipu6 isys_freq_override=475" >> /etc/modprobe.d/ipu.conf'

### Stream with GStreamer icamerasrc

> **Note:** PSYS library requires superuser access, please login as root to run the sample commands given below.

#### Device Name Selection

| AIC Link | Supported Device-name | Command Pipeline |
|---|---|---|
| A | ar0234_acpi-1 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| B | ar0234_acpi-2 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-2 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| C | ar0234_acpi-3 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-3 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| D | ar0234_acpi-4 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-4 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| E | ar0234_acpi-5 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-5 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| F | ar0234_acpi-6 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-6 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| G | ar0234_acpi-7 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-7 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| H | ar0234_acpi-8 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-8 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |

> **Attention:** If the target is set up using "ACPI Setup - BIOS Configuration", replace the 'device-name' prefix in the sample commands above from 'ar0234_acpi-' to 'ar0234-'. For example, 'ar0234_acpi-1' becomes 'ar0234-1'.

> **Note:** Link ports E, F, G, and H apply only to the MAX96724 AIC.

> **Note**: Refer to icamerasrc device-name property for more sensor details.

#### Frame Buffer Memory Type (IO Mode) Selection

| IO Mode | Command Pipeline |
|---|---|
| USERPTR | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=userptr ! 'video/x-raw,format=NV12,width=1280,height=960' ! glimagesink sync=false |
| DMA MODE | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |

> **Note**: Refer to icamerasrc io-mode property for more sensor details.

#### Sensor Resolution Selection

| Resolution | Command Pipeline |
|---|---|
| 1280x960 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |

#### Sensor Format Selection

| Format | Command Pipeline |
|---|---|
| NV12 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |

#### Multi-Stream Selection

Multi-stream support can be configured using either of the following approaches:

- [Multiprocessing Multi-Stream](#multiprocessing-multi-stream)
- [Multithreading Multi-Stream](#multithreading-multi-stream)

##### Multiprocessing Multi-Stream

To stream N sensors concurrently, launch N terminal windows.
In each terminal, run the command below with the corresponding sensor number.

| Number of Streams | Command Pipeline |
|---|---|
| xN | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-N printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |

##### Multithreading Multi-Stream

Open a terminal window and run the command below, replacing the sensor number as needed.

| Number of Streams | Command Pipeline |
|---|---|
| x1 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| x2 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=2 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false icamerasrc num-buffers=-1 num-vc=2 scene-mode=normal device-name=ar0234_acpi-2 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |
| x4 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=4 scene-mode=normal device-name=ar0234_acpi-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false icamerasrc num-buffers=-1 num-vc=4 scene-mode=normal device-name=ar0234_acpi-2 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false icamerasrc num-buffers=-1 num-vc=4 scene-mode=normal device-name=ar0234_acpi-3 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false icamerasrc num-buffers=-1 num-vc=4 scene-mode=normal device-name=ar0234_acpi-4 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1280,height=960' ! glimagesink sync=false |

> **Note**: Known VC limitation (max vc=5) for multi-stream. \
For example, to enable 8 streams, user can launch 2 terminals, with each terminal running x4 streams.

---
## Streaming Result

> **Note:** Please ensure your system supports the specified number of streams before testing.

| Number of Streams | IO Mode  | FPS Result |ipu6ep|ipu6epmtl|ipu75xa|ipu8|
|:----------------:|:--------:|:----------:|:----:|:-------:|:-----:|:--:|
| x1               | USERPTR  | 30         |❌|✅|✅|✅|
| x2               | USERPTR  | 30         |❌|✅|✅|✅|
| x4               | USERPTR  | 30         |❌|❌|✅|✅|
| x8               | USERPTR  | 30         |❌|❌|✅|❌|
| x1               | DMA MODE | 30         |❌|✅|✅|✅|
| x2               | DMA MODE | 30         |❌|✅|✅|✅|
| x4               | DMA MODE | 30         |❌|❌|✅|✅|
| x8               | DMA MODE | 30         |❌|❌|✅|❌|

### Highest Bandwidth Configuration

The highest-bandwidth configurations tested are listed below.

  1. CPHY 2-lane per MIPI Port
     - 8x 1280x960 @ 30fps (default)

---
[↑ Back to Top](#description)
