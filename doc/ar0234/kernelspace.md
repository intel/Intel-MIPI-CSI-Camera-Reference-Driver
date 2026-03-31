## Description

This document outlines the configuration parameters for Sensor AR0234, including validated settings and their compatibility across supported platforms.

## Driver DKMS Build

Build and install the DKMS modules according to [README.md](../../README.md)

## Sensor Kernel Configuration Verification

#### For Sensor Type: MIPI CSI-2

1. Verify the line below in ipu_supported_sensors[] in `../../drivers/media/pci/intel/ipu-bridge.c`
   ```c
   IPU_SENSOR_CONFIG("INTC10C0", 1, 360000000)
   ```

2. Sensor ISP Physical Address Configuration:

   The sensor I2C address is defined in `../../include/media/i2c/ar0234.h`:
   ```c
   #define AR0234_I2C_ADDRESS 0x10
   ```

   | Vendor             | Physical Address |
   |--------------------|------------------|
   | D3 Embedded        | 0x10             |

#### For Sensor Type: GMSL

1. MAX9295 Serializer Physical Address Configuration:

   The serializer address is configured in `../../drivers/media/platform/intel/ipu-acpi-pdata.c`:
   ```c
	serdes_sdinfo[i].ser_phys_addr = 0x40;
   ```

   | Vendor             | Physical Address |
   |---                 |---               |
   | D3 Embedded        | 0x40             |

2. Sensor ISP Physical Address Configuration:

   The sensor I2C address is defined in `../../include/media/i2c/ar0234.h`:
   ```c
   #define AR0234_I2C_ADDRESS 0x10
   ```

   | Vendor             | Physical Address |
   |---                 |---               |
   | D3 Embedded        | 0x10             |
