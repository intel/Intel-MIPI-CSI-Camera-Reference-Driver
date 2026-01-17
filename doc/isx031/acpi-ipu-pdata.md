## Description

This document outlines the configuration parameters for up to GMSL 2 ISX031 Sensors Modules (from D3, Leopard imaging, Sensing), including validated settings and their compatibility across supported platforms.

## For ISX031 Sensor PDATA ACPI : GMSL2 max9296 DPHY on Advantech AFE-R360 (MTL) or ASR-A360 (ARL)

```
System Agent (SA) Configuration -> IPU Device (B0:D5:F0)                        [Enabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> CVF Support     [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 1 [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 2 [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 3 [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 4 [Disabled]

System Agent (SA) Configuration -> MIPI Camera Configuration -> Camera 1        [Enabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Link options
Sensor Model                    [User Custom]
Video HID                       INTC031M
Lanes Clock division            [4 4 2 2]
GPIO control                    [No Control Logic]
Camera position                 [Back]
Flash Support                   [Disabled]
Privacy LED                     [Driver default]
Rotation                        [0]
PPR Value                       4
PPR Unit	                    2
Camera module name              isx031
MIPI port                       0
LaneUsed                        [x2]
MCLK                            19200000
EEPROM Type                     [ROM_NONE]
VCM Type                        [VCM_NONE]
Number of I2C                   3
I2C Channel                     [I2C1]
Device                          0
I2C Address                     48
Device Type                     [IO expander]
Device                          1
I2C Address                     42
Device Type                     [IO expander]
Device                          2
I2C Address                     12
Device Type                     [Sensor]
Flash Driver Selection          [Disabled]

System Agent (SA) Configuration -> MIPI Camera Configuration -> Camera 2        [Enabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Link options
Sensor Model                    [User Custom]
Video HID                       INTC031M
Lanes Clock division            [4 4 2 2]
GPIO control                    [No Control Logic]
Camera position                 [Back]
Flash Support                   [Disabled]
Privacy LED                     [Driver default]
Rotation                        [0]
PPR Value                       4
PPR Unit	                    2
Camera module name              isx031
MIPI port                       4
LaneUsed                        [x2]
MCLK                            19200000
EEPROM Type                     [ROM_NONE]
VCM Type                        [VCM_NONE]
Number of I2C                   3
I2C Channel                     [I2C2]
Device                          0
I2C Address                     48
Device Type                     [IO expander]
Device                          1
I2C Address                     42
Device Type                     [IO expander]
Device                          2
I2C Address                     12
Device Type                     [Sensor]
Flash Driver Selection          [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Camera 3    [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Camera 4    [Disabled]
```