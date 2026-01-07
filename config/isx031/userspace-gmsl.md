## Description

This document details the configuration settings for the ISX031 GMSL sensor, providing essential information for system integration. The table below presents the key parameters and their respective values used during system setup and validation.

## BIOS Configuration Table

**Note:** No External Clock required.

#### IPU6EP Camera Option

| | Camera1 Link options | Camera2 Link options |
|----------|----------|----------|
| Sensor Model | User Custom | User Custom |
| Custom HID | INTC031M | INTC031M |
| Lanes Clock division | 4 4 2 2 | 4 4 2 2 |
| CRD Version | CRD-D | CRD-D |
| GPIO control | No Control Logic | No Control Logic |
| Camera position | Front | Back |
| Flash Support | Disabled | Disabled |
| Privacy LED | Driver default | Driver default |
| Rotation | 90 | 90 |
| PPR Value | 2 | 2 |
| PPR Unit | 2 | 2 |
| Camera module name | _ | _ |
| MIPI port | 1 | 2 |
| LaneUsed | x4 | x4 |
| MCLK | 19200000 | 19200000 |
| EEPROM Type | ROM_NONE | ROM_NONE |
| VCM Type | VCM_NONE | VCM_NONE |
| Number of I2C Components | 3 | 3 |
| I2C Channel | I2C1 | I2C0 |
| Device 0 | | |
| I2C Address | 48 | 48 |
| Device Type | Sensor | Sensor |
| Device 1 | | |
| I2C Address | 44 | 44 |
| Device Type | Sensor | Sensor |
| Device 2 | | |
| I2C Address | 50 | 50 |
| Device Type | Sensor | Sensor |
| Customize Device ID List | | |
| Customize Device ID Number | 17 | 17 |
| Customize Device ID Number | 18 | 18 |
| Customize Device ID Number | 19 | 19 |
| Flash Driver Selection | Disabled | Disabled |

#### IPU6EPMTL Camera Option

| | Camera1 Link options | Camera2 Link options |
|----------|----------|----------|
| Sensor Model | User Custom | User Custom |
| Custom HID | INTC031M | INTC031M |
| Lanes Clock division | 4 4 2 2 | 4 4 2 2 |
| CRD Version | CRD-D | CRD-D |
| GPIO control | No Control Logic | No Control Logic |
| Camera position | Front | Back |
| Flash Support | Disabled | Disabled |
| Privacy LED | Driver default | Driver default |
| Rotation | 90 | 90 |
| PPR Value | 2 | 2 |
| PPR Unit | 2 | 2 |
| Camera module name | _ | _ |
| MIPI port | 0 | 4 |
| LaneUsed | x4 | x4 |
| MCLK | 19200000 | 19200000 |
| EEPROM Type | ROM_NONE | ROM_NONE |
| VCM Type | VCM_NONE | VCM_NONE |
| Number of I2C Components | 3 | 3 |
| I2C Channel | I2C1 | I2C0 |
| Device 0 | | |
| I2C Address | 48 | 48 |
| Device Type | Sensor | Sensor |
| Device 1 | | |
| I2C Address | 44 | 44 |
| Device Type | Sensor | Sensor |
| Device 2 | | |
| I2C Address | 50 | 50 |
| Device Type | Sensor | Sensor |
| Customize Device ID List | | |
| Customize Device ID Number | 17 | 17 |
| Customize Device ID Number | 18 | 18 |
| Customize Device ID Number | 19 | 19 |
| Flash Driver Selection | Disabled | Disabled |

## Camera XML File Setup

#### IPU6EP Configuration

1. Import files below to `/etc/camera/ipu6ep/sensor`
   - isx031-1.xml
   - isx031-2.xml
   - isx031-3.xml
   - isx031-4.xml

2. Append new sensors in `/etc/camera/ipu6ep/libcamhal_profile.xml`
   ```xml
   <availableSensors value="...,isx031-1-1,isx031-2-1,isx031-3-2,isx031-4-2"/>
   ```

#### IPU6EPMTL Configuration

1. Import files below to `/etc/camera/ipu6epmtl/sensor`
   - isx031-1.xml
   - isx031-2.xml
   - isx031-3.xml
   - isx031-4.xml

2. Append new sensors into `/etc/camera/ipu6epmtl/libcamhal_profile.xml`
   ```xml
   <availableSensors value="...,isx031-1-0,isx031-2-0,isx031-3-4,isx031-4-4"/>
   ```

## Sample Userspace Command

#### Sensor Device Selection

| Sensor Number | Command Pipeline |
|----------|----------|
| 1 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=**isx031-1** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false |
| 2 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=**isx031-2** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false |
| 3 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=**isx031-3** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false | 
| 4 | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=**isx031-4** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false |

**Note**: Refer to icamerasrc device-name property for more sensor details.

#### Frame Buffer Memory Type (IO Mode) Selection

| IO Mode | Command Pipeline |
|----------|----------|
| MMAP | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=**1** ! '**video/x-raw,format=UYVY**,width=1920,height=1536' ! glimagesink sync=false |
| DMA MODE | gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=**4** ! '**video/x-raw(memory:DMABuf),drm-format=UYVY**,width=1920,height=1536' ! glimagesink sync=false |

**Note**: Refer to icamerasrc io-mode property for more sensor details.

#### Sensor Resolution Selection
| Resolution | Command Pipeline |
|----------|----------|
| 1920x1536 | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,**width=1920,height=1536**' ! glimagesink sync=false |

#### Sensor Format Selection
| Format | Command Pipeline |
|----------|----------|
| UYVY | gst-launch-1.0 icamerasrc num-buffers=-1 scene-mode=normal device-name=isx031-1 printfps=true io-mode=dma_mode ! 'video/x-raw(memory:DMABuf),**drm-format=UYVY**,width=1920,height=1536' ! glimagesink sync=false |

#### Number of Stream (Single Stream / Multi Stream) Selection

| Number of Stream | Command Pipeline |
|----------|----------|
| x1 | gst-launch-1.0 icamerasrc num-buffers=-1 **num-vc=1** scene-mode=normal device-name=**isx031-1** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false |
| x2 | gst-launch-1.0 icamerasrc num-buffers=-1 **num-vc=2** scene-mode=normal device-name=**isx031x2-1** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink icamerasrc num-buffers=-1 **num-vc=2** scene-mode=normal device-name=**isx031x2-2** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false |
| x4 | gst-launch-1.0 icamerasrc num-buffers=-1 **num-vc=4** scene-mode=normal device-name=**isx031x4-1** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink icamerasrc num-buffers=-1 **num-vc=4** scene-mode=normal device-name=**isx031x4-2** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink icamerasrc num-buffers=-1 **num-vc=4** scene-mode=normal device-name=**isx031x4-3** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink icamerasrc num-buffers=-1 **num-vc=4** scene-mode=normal device-name=**isx031x4-4** printfps=true io-mode=4 ! 'video/x-raw(memory:DMABuf),drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false |

#### FPS Result

| Number of Stream | IO Mode | FPS Result |
|----------|----------|----------|
| x1 | MMAP | 30 |
| x2 | MMAP | 30 |
| x4 | MMAP | 30 |
| x1 | DMA MODE | 30 |
| x2 | DMA MODE | 30 |
| x4 | DMA MODE | 30 |
