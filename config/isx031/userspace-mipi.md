## Description

This document details the configuration settings for the ISX031 MIPI CSI-2 sensor, providing essential information for system integration. The table below presents the key parameters and their respective values used during system setup and validation.

## BIOS Configuration Table

**Note:** No External Clock required.

#### IPU6EP Control Logic

| | Control Logic 1 | Control Logic 2 |
|----------|----------|----------|
| Control Logic Type | Discrete | Discrete |
| CRD Version | CRD-D | CRD-D |
| Input Clock | 19.2MHz | 19.2MHz |
| PCH Clock | IMGCLKOUT_0 | IMGCLKOUT_1 |
| Number of GPIOs | 1 | 1 |
| GPIO 0 | | |
| Group Pad Number | 5 | 15 |
| Group Number | F | E |
| Function | RESET | RESET |
| Active Value | 1 | 1 |
| Initial Value | 0 | 0 |

#### IPU6EP Camera Link Options

| | Camera1 Link Options | Camera2 Link Options |
|----------|----------|----------|
| Sensor Model | User Custom | User Custom |
| Custom HID | INTC113C | INTC113C |
| Lanes Clock division | 4 4 2 2 | 4 4 2 2 |
| CRD Version | CRD-D | CRD-D |
| GPIO control | Control Logic 1 | Control Logic 2 |
| Camera position | Front | Back |
| Flash Support | Disabled | Disabled |
| Privacy LED | Driver default | Driver default |
| Rotation | 0 | 0 |
| PPR Value | 0 | 0 |
| PPR Unit | 0 | 0 |
| Camera module name | _ | _ |
| MIPI port | 1 | 2 |
| LaneUsed | x4 | x4 |
| PortSpeed | 2 | 2 |
| MCLK | 19200000 | 19200000 |
| EEPROM Type | ROM_NONE | ROM_NONE |
| VCM Type | VCM_NONE | VCM_NONE |
| Number of I2C Components | 1 | 1 |
| I2C Channel | I2C1 | I2C5 |
| Device 0 | | |
| I2C Address | 1A | 1A |
| Device Type | Sensor | Sensor |
| Flash Driver Selection | Disabled | Disabled |

#### IPU6EPMTL Control Logic

| | Control Logic 1 | Control Logic 2 |
|----------|----------|----------|
| Control Logic Type | Discrete | Discrete |
| CRD Version | CRD-D | CRD-D |
| Input Clock | 19.2MHz | 19.2MHz |
| PCH Clock | IMGCLKOUT_0 | IMGCLKOUT_1 |
| Number of GPIOs | 1 | 1 |
| GPIO 0 | | |
| Group Pad Number | 23 | 0 |
| Group Number | D_E_F_V | A_B_H_S |
| Com Number | COM0 | COM3 |
| Function | RESET | RESET |
| Active Value | 1 | 1 |
| Initial Value | 0 | 0 |

#### IPU6EPMTL Camera Link Options

| | Camera1 Link Options | Camera2 Link Options |
|----------|----------|----------|
| Sensor Model | User Custom | User Custom |
| Custom HID | INTC113C | INTC113C |
| Lanes Clock division | 4 4 2 2 | 4 4 2 2 |
| CRD Version | CRD-D | CRD-D |
| GPIO control | Control Logic 1 | Control Logic 2 |
| Camera position | Front | Back |
| Flash Support | Disabled | Disabled |
| Privacy LED | Driver default | Driver default |
| Rotation | 0 | 0 |
| Voltage Rail | | 3 voltage rail |
| PPR Value | 0 | 0 |
| PPR Unit | 0 | 0 |
| Camera module name | _ | _ |
| MIPI port | 0 | 4 |
| LaneUsed | x4 | x4 |
| MCLK | 19200000 | 19200000 |
| EEPROM Type | ROM_NONE | ROM_NONE |
| VCM Type | VCM_NONE | VCM_NONE |
| Number of I2C Components | 1 | 1 |
| I2C Channel | I2C1 | I2C0 |
| Device 0 | | |
| I2C Address | 1A | 1A |
| Device Type | Sensor | Sensor |
| Customize Device ID List | | |
| Customize Device ID Number | 17 | 17 |
| Customize Device ID Number | 18 | 18 |
| Customize Device ID Number | 19 | 19 |
| Flash Driver Selection | Disabled | Disabled |

## Camera XML/JSON File Setup

#### IPU6EP Configuration

1. Import the files below to `/etc/camera/ipu6ep/sensor`
   - isx031-1-mipi.xml
   - isx031-2-mipi.xml

2. Append the new sensors in `/etc/camera/ipu6ep/libcamhal_profile.xml`
   ```xml
   <availableSensors value="...,isx031-1-mipi-1,isx031-2-mipi-2"/>
   ```

#### IPU6EPMTL Configuration

1. Import the files below to `/etc/camera/ipu6epmtl/sensor`
   - isx031-1-mipi.xml
   - isx031-2-mipi.xml

2. Append the new sensors into `/etc/camera/ipu6epmtl/libcamhal_profile.xml`
   ```xml
   <availableSensors value="...,isx031-1-mipi-0,isx031-2-mipi-4"/>
   ```

## Sample Userspace Command

#### Sensor Device Selection

| MIPI Port | Command Pipeline |
|----------|----------|
| CRD1 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=**isx031-1** printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1080' ! glimagesink sync=false |
| CRD2 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=**isx031-2** printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1080' ! glimagesink sync=false |

**Note**: Refer to icamerasrc device-name property for more sensor details.

#### Frame Buffer Memory Type (IO Mode) Selection

| IO Mode | Command Pipeline |
|----------|----------|
| MMAP | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=**mmap** ! '**video/x-raw,format=UYVY**,width=1920,height=1080' ! glimagesink sync=false |
| DMA MODE | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=**dma_mode** ! '**video/x-raw(memory:DMABuf),drm-format=UYVY**,width=1920,height=1080' ! glimagesink sync=false |

**Note**: Refer to icamerasrc io-mode property for more sensor details.

#### Sensor Resolution Selection
| Resolution | Command Pipeline |
|----------|----------|
| 1920x1080 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,**width=1920,height=1080**' ! glimagesink sync=false |

#### Sensor Format Selection
| Format | Command Pipeline |
|----------|----------|
| UYVY | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),**drm-format=UYVY**,width=1920,height=1080' ! glimagesink sync=false |

#### Number of Stream (Single Stream / Multi Stream) Selection

| Number of Stream | Command Pipeline |
|----------|----------|
| x1 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=**isx031-1** printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1080' ! glimagesink sync=false |
| x2 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=**isx031-1** printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1080' ! glimagesink sync=false icamerasrc num-buffers=-1 scene-mode=normal device-name=**isx031-2** printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1080' ! glimagesink sync=false |

#### FPS Result

| Number of Stream | IO Mode | FPS Result |
|----------|----------|----------|
| x1 | MMAP | 30 |
| x2 | MMAP | 30 |
| x1 | DMA MODE | 30 |
| x2 | DMA MODE | 30 |
