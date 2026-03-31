## Description

This document outlines the configuration parameters for Sensor AR0830, including validated settings and their compatibility across supported platforms.

This sensor might come with in-built ISP module, please verify with your respective vendor.

   | Vendor             | Sensor           | ISP              |
   |---                 |---               |---               |
   | Sensing            | AR0830           | AP1302           |

## Driver DKMS Build

Build and install the DKMS modules according to [README.md](../../README.md)

## Sensor Kernel Configuration Verification

#### For Sensor Type: MIPI CSI-2

1. Verify the line below in ipu_supported_sensors[] in `../../drivers/media/pci/intel/ipu-bridge.c`
   ```c
   IPU_SENSOR_CONFIG("LIAR0830", 1, 600000000)
   ```

2. Sensor ISP Physical Address Configuration:

   | Vendor             | Physical Address |
   |--------------------|------------------|
   | Leopard Imaging    | 0x3C             |
