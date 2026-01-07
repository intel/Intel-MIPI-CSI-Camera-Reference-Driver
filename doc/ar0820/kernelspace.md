## Description

This document outlines the configuration parameters for Sensor AR0820, including validated settings and their compatibility across supported platforms. The table below summarizes the configurations that have been tested and verified, providing a reference for platform-specific implementation and integration.

## Patches required for ipu6-drivers Dkms build

1. Navigate to the ipu6-drivers directory:
   ```bash
   cd ipu6-drivers
   ```

2. Apply the following patches from this repository:
   ```bash
   git am drivers.camera.scaling.sensor/patch/v6.12/0040-media-platform-intel-Add-AR0820-sensor-support-to-IPU.patch
   git am drivers.camera.scaling.sensor/patch/v6.12/0041-media-i2c-max9x-Add-FSIN-GPIO-support-for-sensor-syn.patch
   ```

3. Build and install the DKMS modules:
   - Refer to the main [README.md](../../README.md) for complete DKMS build and installation instructions.
   
   > **Important:** These patches were tested based on the validated system configuration listed below.

#### For Sensor Type: GMSL

1. MAX9295 Serializer Physical Address Configuration:
   
   The serializer address is configured in `ipu6-drivers/drivers/media/platform/intel/ipu-acpi-pdata.c`:
   ```c
	serdes_sdinfo[i].ser_phys_addr = 0x40;
   ```

   | Vendor | Physical Address |
   |--------|------ |
   | Sensing | 0x40 |

2. Sensor ISP Physical Address Configuration:
   
   The sensor I2C address is defined in `ipu6-drivers/include/media/i2c/ar0820.h`:
   ```c
   #define AR0820_I2C_ADDRESS 0x6D  // Sensing ISP I2C Address is 0xDA >> 1
   ```

   | Sensor | Physical Address |
   |--------|------------------|
   | AR0820 | 0x6D |
   | AR0233 | 0x6D |
   
   > **Note:** The AR0820 driver supports both AR0820 and AR0233 sensors, both using the same I2C address.

## Validated with:
   - Kernel version 6.12: [linux-intel-lts](https://github.com/intel/linux-intel-lts/tree/lts-v6.12.48-linux-250924T142248Z)
   - IPU6 drivers: [ipu6-drivers](https://github.com/intel/ipu6-drivers/tree/iotg_ipu6) (commit `71e2e426`)
