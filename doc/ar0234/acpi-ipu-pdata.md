## Description

This document outlines the configuration parameters for Sensor AR0234, including validated settings and their compatibility across supported platforms.

## For Sensor PDATA ACPI : MIPI CSI-2

```
System Agent (SA) Configuration -> IPU Device (B0:D5:F0)                        [Enabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> CVF Support     [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 1 [Enabled]
Control Logic Type              [Discrete]
CRD Version                     [CRD-D]
Input Clock                     [19.2 MHz]
PCH Clock Source                [IMGCLKOUT_0]
Number of GPIO Pins             0

System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 2 [Enabled]
Control Logic Type              [Discrete]
CRD Version                     [CRD-D]
Input Clock                     [19.2 MHz]
PCH Clock Source                [IMGCLKOUT_1]
Number of GPIO Pins             0

System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 3 [Disabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Control Logic 4 [Disabled]

System Agent (SA) Configuration -> MIPI Camera Configuration -> Camera 1        [Enabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Link options
Sensor Model                    [User Custom]
Video HID                       INTC10C0
Lanes Clock division            [4 4 2 2]
GPIO control                    [Control Logic 1]
Camera position                 [Back]
Flash Support                   [Disabled]
Privacy LED                     [Driver default]
Rotation                        [0]
PPR Value                       10
PPR Unit	                    A
Camera module name              YHCE
MIPI port                       0
LaneUsed                        [x2]
MCLK                            19200000
EEPROM Type                     [ROM_NONE]
VCM Type                        [VCM_NONE]
Number of I2C                   1
I2C Channel                     [I2C0]
Device                          0
I2C Address                     10
Device Type                     [Sensor]
Flash Driver Selection          [Disabled]

System Agent (SA) Configuration -> MIPI Camera Configuration -> Camera 2    [Enabled]
System Agent (SA) Configuration -> MIPI Camera Configuration -> Link options
Sensor Model                    [User Custom]
Video HID                       INTC10C0
Lanes Clock division            [4 4 2 2]
GPIO control                    [Control Logic 2]
Camera position                 [Back]
Flash Support                   [Disabled]
Privacy LED                     [Driver default]
Rotation                        [0]
PPR Value                       10
PPR Unit	                    A
Camera module name              YHCE
MIPI port                       4
LaneUsed                        [x2]
MCLK	                        19200000
EEPROM Type                     [ROM_NONE]
VCM Type                        [VCM_NONE]
Number of I2C                   1
I2C Channel                     [I2C5]
Device                          0
I2C Address                     10
Device Type                     [Sensor]
Flash Driver Selection          [Disabled]
```