## Description

This document outlines the configuration parameters for Sensor ISX031, including validated settings and their compatibility across supported platforms.

## For Sensor Type: MIPI CSI-2

1. Verify if line below in ipu_supported_sensors[]** in `drivers.camera.scaling.sensor/drivers/media/pci/intel/ipu-bridge.c`
   ```c
   IPU_SENSOR_CONFIG("INTC113C", 1, 300000000)
   ```

2. **Sensor ISP Physical Address Configuration:**
   
   The sensor I2C address is defined in `ipu6-drivers/include/media/i2c/isx031.h`:
   ```c
   #define ISX031_I2C_ADDRESS 0x1a
   ```
   
   | Vendor | Physical Address |
   |--------|------------------|
   | All    | 0x1a             |

## For Sensor Type: GMSL

### I2C Address Configuration

1. **MAX9295 Serializer Physical Address:**
   
   The serializer address is configured in `ipu6-drivers/drivers/media/platform/intel/ipu-acpi-pdata.c`:
   ```c
	serdes_sdinfo[i].ser_phys_addr = 0x40;
   ```

   | Vendor             | Physical Address |
   |--------------------|------------------|
   | D3 Embedded        | 0x40             |
   | Leopard Imaging    | 0x62             |
   | Sensing            | 0x40             |

2. **Sensor ISP Physical Address:**
   
   The sensor I2C address is defined in `ipu6-drivers/include/media/i2c/isx031.h`:
   ```c
   #define ISX031_I2C_ADDRESS 0x1a
   ```
   
   | Vendor             | Physical Address |
   |--------------------|------------------|
   | D3 Embedded        | 0x1a             |
   | Leopard Imaging    | 0x1a             |
   | Sensing            | 0x1a             |

### Patches required for ipu6-drivers Dkms build

#### For Leopard Imaging (LI) ISX031 sensors:

1. Navigate to the ipu6-drivers directory:
   ```bash
   cd ipu6-drivers
   ```

2. Apply the following patches from this repository:
   ```bash
   git am drivers.camera.scaling.sensor/patch/v6.12/0042-modify-physical-address-of-serializer.patch
   ```
   
   > **Note:** After applying, the serializer address is set to `0x62` for LI sensors. Sensors using the default `0x40` will not work unless reverted.

3. Build and install the DKMS modules:
   - Refer to the main [README.md](../../README.md) for complete DKMS build and installation instructions.

#### For Sensing ISX031 sensors:

1. Navigate to the ipu6-drivers directory:
   ```bash
   cd ipu6-drivers
   ```

2. Apply the following patches from this repository:
   ```bash
   git am drivers.camera.scaling.sensor/patch/v6.12/0041-media-i2c-max9x-Add-FSIN-GPIO-support-for-sensor-syn.patch
   ```
   
   > **Note:** This patch enables FSIN GPIO support
   
3. Build and install the DKMS modules:
   - Refer to the main [README.md](../../README.md) for complete DKMS build and installation instructions.

> **Important:** These patches were tested based on the validated system configuration listed below.   

## Validated with:
   - Kernel version 6.12: [linux-intel-lts](https://github.com/intel/linux-intel-lts/tree/lts-v6.12.48-linux-250924T142248Z)
   - IPU6 drivers: [ipu6-drivers](https://github.com/intel/ipu6-drivers/tree/iotg_ipu6) (commit `71e2e426`)