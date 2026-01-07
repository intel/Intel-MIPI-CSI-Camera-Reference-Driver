# Description

This document provides configuration details for **ar0234** sensor. The table below outlines key parameters and their corresponding values used in the system setup. 

## BIOS Configuration Table

**Note:** No External Clock required.

#### IPU6EPMTL Control Logic

| | Control Logic 1 | 
|----------|----------|
| Control Logic Type | Discrete |
| Number of GPIOs | 1 |
| Group Pad Number | 23 |
| Group Number | D_E_F_V |
| Com Number | COM0 |
| Function | RESET |
| Active Value | 1 |
| Initial Value | 1 |

#### IPU6EPMTL Camera Link  Option

|                            | Camera1 Link options |
|---                         |---                   |
| Sensor Model               | User Custom          |
| Custom HID                 | INTC10C0             |
| Lanes Clock division       | 4 4 2 2              |
| CRD Version                | CRD-D                |
| GPIO control               | Control Logic 1      |
| Camera position            | Back                 |
| Flash Support              | Enabled              |
| Privacy LED                | Driver default       |
| Rotation                   | 0                    |
| PPR Value                  | 1                    |
| PPR Unit                   | A                    |
| Camera module name         | YHCE                 |
| MIPI port                  | 0                    |
| LaneUsed                   | x2                   |
| MCLK                       | 19200000             |
| EEPROM Type                | ROM_NONE             |
| VCM Type                   | VCM_NONE             |
| Number of I2C Components   | 1                    |
| I2C Channel                | I2C1                 |
| Device 0                   |                      |
| I2C Address                | 10                   |
| Device Type                | Sensor               |
| Customize Device ID List   |                      |
| Customize Device ID Number | 17                   |
| Customize Device ID Number | 18                   |
| Customize Device ID Number | 19                   |
| Flash Driver Selection     | Disabled             |

## Camera XML File Setup

####  IPU6EPMTL Configuration

1. Import the files from ipu6/ below to `/etc/camera/ipu6epmtl/sensor`
   - ar0234-1.xml

2. Append the new sensors into `/etc/camera/ipu6epmtl/libcamhal_profile.xml`
   ```xml
   <availableSensors value="...,ar0234-1-0"/>
   ```

3. AR0234 is a raw sensor, therefore it has dependencies on these files below. They can be installed and deployed from https://github.com/intel/ipu6-camera-hal.
   - /etc/camera/ipu6epmtl/AR0234_TGL_10bits.aiqb
   - /etc/camera/ipu6epmtl/gcss/graph_settings_ar0234.xml

#### Sensor Device Selection

| MIPI Port | Device Name |
|----------|----------|
| CRD1 | ar0234-1 |

## Sample UserSpace Command

1. PSYS library requires superuser to access, therefore please login as root to run the sample command sample given below.

2. Please also make sure the following commands are run or included in /root/.bashrc:
   ```bash
   export DISPLAY=:0; xhost +
   export GST_PLUGIN_PATH=/usr/lib/gstreamer-1.0
   export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
   export LIBVA_DRIVER_NAME=iHD
   export GST_GL_API=gles2
   export GST_GL_PLATFORM=egl
   ```

| Number of Stream | Command Pipeline |
|----------|----------|
| x1 | gst-launch-1.0 icamerasrc num-buffers=-1 printfps=true device-name=ar0234-1 io-mode=4 ! 'video/x-raw(memory:DMABuf), drm-format=NV12, width=1280, height=960' ! glimagesink sync=false |

#### FPS Result

| Number of Stream | IO Mode | FPS Result |
|----------|----------|----------|
| x1 | DMA MODE | 30 |
