## Description

This document details the configuration settings for the IMX586 MIPI CSI-2 sensor, providing essential information for system integration. The table below presents the key parameters and their respective values used during system setup and validation.

## BIOS Configuration Table

> **Note:** External Clock required on IMGCLKOUT_2 and IMGCLKOUT_0.

#### IPU6EPMTL Control Logic

|                            | Control Logic 1      | Control Logic 2      |
|---                         |---                   | ---                  |
| Control Logic Type         | Discrete             | Discrete             |
| Input Clock                | 24MHz                | 24MHz                |
| PCH Clock Source           | <IMGCLKOUT_2>        | <IMGCLKOUT_0>        | 
| Number of GPIOs            | 1                    | 1                    |
| Group Pad Number           | 23                   | 0                    |
| Group Number               | D_E_F_V              | A_B_H_S              |
| Com Number                 | COM0                 | COM3                 |
| Function                   | RESET                | RESET                |
| Active Value               | 1                    | 1                    |
| Initial Value              | 1                    | 1                    |

#### IPU6EPMTL Camera Link  Option

|                            | Camera1 Link options | Camera2 Link options |
|---                         |---                   | ---                  |
| Sensor Model               | User Custom          | User Custom          |
| Custom HID                 | IMXSN586             | IMXSN586             |
| Lanes Clock division       | 4 4 2 2              | 4 4 2 2              |
| CRD Version                | CRD-D                | CRD-D                |
| GPIO control               | Control Logic 1      | Control Logic 2      |
| Camera position            | Front                | Back                 |
| Flash Support              | Disabled             | Disabled             |
| Privacy LED                | Driver default       | Driver default       |
| Rotation                   | 0                    | 0                    |
| PPR Value                  | 2                    | 2                    |
| PPR Unit                   | 2                    | 2                    |
| Camera module name         | _                    | _                    |
| MIPI port                  | 0                    | 4                    |
| LaneUsed                   | x4                   | x4                   |
| MCLK                       | 24000000             | 24000000             |
| EEPROM Type                | ROM_NONE             | ROM_NONE             |
| VCM Type                   | VCM_NONE             | VCM_NONE             |
| Number of I2C Components   | 1                    | 1                    |
| I2C Channel                | I2C1                 | I2C0                 |
| Device 0                   |                      |                      |
| I2C Address                | 1A                   | 1A                   |
| Device Type                | Sensor               | Sensor               |
| Customize Device ID List   |                      |                      |
| Customize Device ID Number | 17                   | 17                   |
| Customize Device ID Number | 18                   | 18                   |
| Customize Device ID Number | 19                   | 19                   |
| Flash Driver Selection     | Disabled             | Disabled             |

## Camera XML File Setup

####  IPU6EPMTL Configuration

Replace target system with recommended [ipu6epmtl](../../config/imx586/ipu6epmtl) setting

    sudo cp -r ../../config/imx586/ipu6epmtl /etc/camera

## Camera Tuning File Setup

#### IPU6EPMTL Configuration

Import [IMX586_GX48M9684_MTL.aiqb](https://github.com/intel/ipu6-camera-hal/blob/iotg_ipu6/config/linux/ipu6epmtl/IMX586_GX48M9684_MTL.aiqb) into target system `/etc/camera/ipu6epmtl`

## Sample Userspace Command

#### Sensor Device Selection

| MIPI Port | Command Pipeline |
|---|---|
| CRD1 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |
| CRD2 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-b printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |

> **Note**: Refer to icamerasrc device-name property for more sensor details.

#### Frame Buffer Memory Type (IO Mode) Selection

| IO Mode | Command Pipeline |
|---|---|
| USERPTR | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=userptr ! 'video/x-raw,format=NV12,width=3968,height=2976' ! glimagesink sync=false |
| DMA MODE | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |

> **Note**: Refer to icamerasrc io-mode property for more sensor details.

#### Sensor Resolution Selection

| Resolution | Command Pipeline |
|---|---|
| 3968x2976 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |
| 1920x1080 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=1920,height=1080' ! glimagesink sync=false |

#### Sensor Format Selection

| Format | Command Pipeline |
|---|---|
| NV12 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |

#### Number of Stream (Single Stream / Multi Stream) Selection

| Number of Stream | Command Pipeline |
|---|---|
| x1 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |
| x2 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-a printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false icamerasrc num-buffers=-1 scene-mode=auto device-name=imx586-b printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=NV12,width=3968,height=2976' ! glimagesink sync=false |

#### FPS Result

| Number of Stream | IO Mode  | FPS Result |
|---               |---       |---         |
| x1               | USERPTR  | 30         |
| x1               | DMA MODE | 30         |
| x2               | USERPTR  | 30         |
| x2               | DMA MODE | 30         |
