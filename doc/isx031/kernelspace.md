## Description

This document outlines the configuration parameters for Sensor ISX031, including validated settings and their compatibility across supported platforms.

## Driver DKMS Build

Build and install the DKMS modules according to [README.md](../../README.md)

## Sensor Kernel Configuration Verification

#### For Sensor Type: MIPI CSI-2

1. Verify the line below in ipu_supported_sensors[] in `../../drivers/media/pci/intel/ipu-bridge.c`
   ```c
   IPU_SENSOR_CONFIG("INTC113C", 1, 300000000)
   ```

2. Sensor ISP Physical Address Configuration:
   
   The sensor I2C address is defined in `../../include/media/i2c/isx031.h`:
   ```c
   #define ISX031_I2C_ADDRESS 0x1a
   ```
   
   | Vendor             | Physical Address |
   |--------------------|------------------|
   | D3 Embedded        | 0x1a             |

#### For Sensor Type: GMSL

1. MAX9295 Serializer Physical Address:
   
   The serializer address is configured in `../../drivers/media/platform/intel/ipu-acpi.c`:
   ```c
	serdes_sdinfo[i].ser_phys_addr = 0x40;
   ```

   | Vendor             | Physical Address |
   |--------------------|------------------|
   | D3 Embedded        | 0x40             |
   | Leopard Imaging    | 0x62             |
   | Sensing            | 0x40             |

2. Sensor ISP Physical Address:
   
   The sensor I2C address is defined in `../../include/media/i2c/isx031.h`:
   ```c
   #define ISX031_I2C_ADDRESS 0x1a
   ```
   
   | Vendor             | Physical Address |
   |--------------------|------------------|
   | D3 Embedded        | 0x1a             |
   | Leopard Imaging    | 0x1a             |
   | Sensing            | 0x1a             |
