## Description

This document outlines the configuration parameters for Sensor AR0820, including validated settings and their compatibility across supported platforms.

This sensor might come with in-built ISP module, please verify with your respective vendor.

   | Vendor             | Sensor           | ISP              |
   |---                 |---               |---               |
   | Sensing            | AR0820           | GW5300           |

## Driver DKMS Build

Build and install the DKMS modules according to [README.md](../../README.md)

## Sensor Kernel Configuration Verification

#### For Sensor Type: GMSL

1. MAX9295 Serializer Physical Address Configuration:
   
   The serializer address is configured in `ipu6-drivers/drivers/media/platform/intel/ipu-acpi-pdata.c`:
   ```c
	serdes_sdinfo[i].ser_phys_addr = 0x40;
   ```

   | Vendor             | Physical Address |
   |---                 |---               |
   | Sensing            | 0x40             |

2. Sensor ISP Physical Address Configuration:
   
   The sensor I2C address is defined in `<current_repo>/include/media/i2c/ar0820.h`:
   ```c
   #define AR0820_I2C_ADDRESS 0x6D  // Sensing ISP I2C Address is 0xDA >> 1
   ```

   | Vendor             | Physical Address |
   |---                 |---               |
   | Sensing            | 0x6D             |
