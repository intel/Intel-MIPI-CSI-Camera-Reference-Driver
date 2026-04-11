## Description

This document outlines the configuration parameters for Sensor IMX415, including validated settings and their compatibility across supported platforms.

## Driver DKMS Build

Build and install the DKMS modules according to [README.md](../../README.md)

## Sensor Kernel Configuration Verification

#### For Sensor Type: MIPI CSI-2

1. Verify the line below in ipu_supported_sensors[] in `../../drivers/media/pci/intel/ipu-bridge.c`
   ```c
   IPU_SENSOR_CONFIG("LIIMX415", 1, 445500000)
   ```

2. Sensor ISP Physical Address Configuration:

   The sensor I2C address is defined in `../../include/media/i2c/imx415.h`:
   ```c
   #define IMX415_I2C_ADDRESS 0x1A
   ```

   | Vendor             | Physical Address |
   |--------------------|------------------|
   | Leopard Imaging    | 0x1A             |

