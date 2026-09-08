## Description
This document contains information of imaging specific ACPI SSDT ASL sources compilation and loading.

## Table of Contents

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#acpi-configuration-for-camera-imaging">ACPI Configuration for Camera Imaging</a></li>
    <li><a href="#legacy-bios-method">Legacy BIOS Method</a></li>
    <li><a href="#ssdt-asl-method">SSDT ASL Method</a></li>
    <li><a href="#advantage-of-ssdt-asl-method">Advantage of SSDT ASL Method</a></li>
    <li><a href="#requirement-to-use-ssdt-asl-method">Requirement to use SSDT ASL method</a></li>
    <li><a href="#what-are-acpi-asl-source-files">What are ACPI ASL Source Files?</a></li>
    <li><a href="#reference-asl-source-files">Reference ASL Source Files</a></li>
    <li><a href="#asl-source-files-for-different-use-cases">ASL Source Files for Different Use Cases</a></li>
    <li><a href="#kernel-dependencies-for-ssdt-asl-method">Kernel Dependencies for SSDT ASL Method</a></li>
    <li><a href="#compile-and-load">Compile and Load ACPI ASL Source Files</a></li>
  </ol>
</details>
<!-- END TABLE OF CONTENTS -->

## ACPI Configuration for Camera Imaging

The ACPI namespace is a hierarchical representation of platform devices and resources exposed by the BIOS firmware, enabling the operating system to discover, configure, and manage hardware.

Both [Legacy BIOS method](#legacy-bios-method) and [SSDT ASL method](#ssdt-asl-method) create ACPI devices for camera imaging. There can be conflicts if both methods are used simultaneously, so it is recommended to use only one method at a time.

### Legacy BIOS method

Using Legacy BIOS method, the camera imaging configuration is done through BIOS settings. BIOS has pre-defined fields and methods to store the configuration done on the BIOS menu page, which primarily caters to MIPI Direct camera setups.

For the MIPI Direct case, the `ipu-bridge` driver will read the BIOS settings and create an FWnode for each camera ACPI device. The sensor is then probed through the ACPI framework and registered into the V4L2 subdev framework.

For the GMSL case, the `ipu-acpi` driver will read the BIOS settings and create a static I2C platform data structure. The `ipu-driver` will then use the I2C platform data to probe `max9x` GMSL drivers and then sensor drivers through the I2C framework. The SerDes and sensors are then registered into the V4L2 subdev framework.

Limitations:
This method primarily caters to MIPI Direct camera setups ONLY
To properly describe GMSL setup, existing fields are not sufficient and some fields need to be repurposed.
The mechanism for creating the I2C platform data structure is fixed in `ipu-acpi`, it can **ONLY** populate multiple **SAME sensors** on a single deserializer.

### SSDT ASL method

Using SSDT ASL method, the camera imaging configuration is done through ACPI ASL source files. The ASL source files describe the hardware configuration of the system. They are compiled into SSDT binary, packaged into an early initramfs image, and loaded by the kernel during boot as an ACPI table **override**.

ASL files already have macros that describe the FWnode and I2C information for each camera device. The kernel `drivers/acpi/mipi-disco-img.c` will handle the FWnode creation. Sensor drivers and/or GMSL drivers will be probed through the ACPI framework and registered into the V4L2 subdev framework.

<h3> IMPORTANT: DISABLE all camera related BIOS settings when using SSDT ASL method </h3>

### Advantage of SSDT ASL method

- Offers flexibility: ASL source files are configurable according to the current hardware setup.
- Advanced configuration: Supports mix-and-match configurations of different GMSL sensors on a single deserializer.
- Modularity: Users do not need to recompile the `ipu-acpi` driver to add new sensors. Removes the dependency on BIOS.

### Requirement to use SSDT ASL method
- To compile ASL source files, you need to install `acpica` tools version 20260408 or later. Refer to [Compile and Load](#compile-and-load) section for details.
- GMSL setup enabled through this method requires **CONFIG_I2C_ATR** turned on in base kernel. If you are using Intel BKC, you might want to rebuild the kernel overlay with this config enabled.

## What are ACPI ASL Source Files?

ASL (ACPI Source Language) source files are used to describe the hardware configuration of the system to the operating system. In the context of imaging, these ASL source files define the configuration of camera sensors, (deserializers, serializers for GMSL setups), and their connections to the system's MIPI CSI ports.

The ASL source files are compiled into AML (ACPI Machine Language) binary tables, which are then loaded by the operating system during boot. These tables provide the necessary information for the OS to correctly initialize and manage the imaging hardware.

<h3> IMPORTANT: ASL source file must match or be subset of actual hardware setup.
Any mismatch between the ASL source files and the actual hardware can lead to failures in device registration and streaming. </h3>

The ASL source files are specific to the hardware configuration of the system. The common description of the hardware includes:
- PHY type
- MIPI Port
- Lane configuration
- I2C information (using I2cSerialBusV2)
- GPIO resource allocation (using GpioIo)
- FWnode linkage (using CSI2Bus)

For GMSL setups, the description includes the number of sensors, and extended I2C information and FWnode between deserializers and each serializer-sensor module.

## Reference ASL Source Files

The ASL source files in [acpi/](../../acpi/) are provided as a starting point for creating your own ASL source files based on your specific hardware setup.

<h3> You should use these reference files to understand the structure and required defines, and then create your own ASL source files that accurately reflect your hardware configuration. </h3>

<details>
<summary> Hierarchy </summary>

The hierarchy of the ASL Source Files for MIPI setup looks like this:

    Parent MIPI.asl (e.g. mipi_isx031.asl)
    ├── _ipu.asl
    └── _mipi_cam_common_*.asl

The hierarchy of the ASL Source Files for GMSL setup looks like this:

    Parent GMSL.asl (e.g. max96724_*.asl)
    ├── _ipu.asl
    └── _des_common_*.asl
            ├── _des_ch_common_*.asl
            │       ├── _ser_common_*.asl
            │       └── _cam_common_*.asl
            └── _des_ch_common_*.asl
                    ├── _ser_common_*.asl
                    └── _cam_common_*.asl

</details>

<details>
<summary> Common ASL </summary>

These Common ASL source files should be shared and reused across different use cases and IPU generations. They are **NOT** meant to be compiled into AML file directly and are included by parent ASL source files. They contain common definitions and methods that can be used by multiple ASL source files, reducing redundancy and improving maintainability.

> **Note:** If there is a need to modify common ASL, make sure the changes are generic to be reused for different use cases.

Future enhancements will further reduce redundancy and improve maintainability.

| Common ASL | Description |
| --- | --- |
| _cam_common_ar0234.asl      | Common ASL for AR0234 2D camera sensor |
| _cam_common_d457.asl        | Common ASL for D457 3D GMSL camera sensor |
| _cam_common_isx031.asl      | Common ASL for ISX031 2D GMSL camera sensor |
| _des_ch_common_ar0234.asl   | Common ASL for single GMSL Link / Channel with AR0234 2D GMSL camera sensor |
| _des_ch_common_isx031.asl   | Common ASL for single GMSL Link / Channel with ISX031 2D GMSL camera sensor |
| _des_ch_common_d457.asl     | Common ASL for single GMSL Link / Channel with D457 3D camera sensor |
| _des_common_max96724.asl    | Common ASL for MAX96724 deserializer |
| _des_common_max9296.asl     | Common ASL for MAX9296 deserializer |
| _ipu.asl                    | Common ASL for IPU |
| _mipi_cam_common_isx031.asl | Common ASL for ISX031 2D MIPI camera sensor |
| _ser_common_max9295.asl     | Common ASL for MAX9295 serializer    |

</details>

<details>
<summary> ASL defines </summary>

This section is purely informative to describe the ASL defines used in the reference ASL source files. The defines are expected to be defined in the caller ASL source file, and will be used by the common ASL source files. The defines are grouped into 4 categories: Deserializer specific, Channel specific, Serializer specific, and Sensor specific.

<details>
<summary>Deserializer Specific Defines</summary>

### Deserializer Specific Defines

Deserializer-specific defines are used to describe the connection to the board and SOC. These defines are expected to be defined in the caller ASL source file for each deserializer and will be used by the common ASL source files. The table below describes the required defines for a deserializer and the correlation to the legacy BIOS setting, if applicable.

| Deserializer Define | Description | Value | Correlate to legacy BIOS setting |
| --- | --- | --- | --- |
| DES_PHY_TYPE            | PHY connection to Board | 0 for CPHY, 1 for DPHY | PhyConfiguration |
| DES_I2C_ADDR            | I2C address of the deserializer | 0x0027 for MAX96724, 0x0048 for MAX9296 | I2C Device 0 |
| DES_LANES               | Number of lanes used by the deserializer | 2 or 4 depending on use case | Ppr Value |
| DES_INTERNAL_PHY        | Internal PHY + 4 | 4/5/6/7 for PHY0/1/2/3 | Rotation (Rotation/90 + 4) |
| DES_TO_MIPI_PORT        | Connected to MIPI port of SOC | 0/1/2/3/4/5 based on SOC and Hardware design | MIPI Port |
| DES_I2C_BUS             | I2C bus number for deserializer | "\\_SB.PC00.I2Cx" | I2C Channel |
| DES_PATH                | ACPI Path for Deserializer | "\\_SB.PC00.DESx" | - |
| DES_REF                 | ACPI Reference for Deserializer | \_SB.PC00.DESx | - |
| DES_PIPE_STR_AUTOSELECT | (Optional) Setting for MAX96724 to configure pipe, useful for 3D camera | 0 to disable fixed pipe, 1 to enable fixed pipe (default) | - |

</details>

<details>
<summary>Channel Specific Defines</summary>

### Channel Specific Defines

Channel-specific defines are common for all links, with an incrementing index. For example, if there are four deserializer links, the ASL source file should have four sets of channel-specific defines with link numbers from 0 to 3. These defines are expected to be defined in the caller ASL source file for each link and will be used by the common ASL source files. The table below describes the required defines for each channel.

| Channel Define | Description | Value |
| --- | --- | --- |
| DESCH_LINK_NUM    | Link number for current channel | 0/1/2/3 |
| DESCH_CH          | Channel Device for current link | CH00/CH01/CH02/CH03 |
| DESCH_SER         | Serializer Device for current link | SER0/SER1/SER2/SER3 |
| DESCH_CAM         | Camera Device for current link | CAM0/CAM1/CAM2/CAM3 |
| DESCH_CH_PATH     | ACPI Path for Channel Device | "\\_SB.PC00.DESx.CH0x" |
| DESCH_SER_PATH    | ACPI Path for Serializer Device | "\\_SB.PC00.DESx.SER0/1/2/3" |
| DESCH_SER_REF     | ACPI Reference for Serializer Device | \_SB.PC00.DESx.SER0/1/2/3 |
| DESCH_SER_GPIOREF | ACPI Reference for Serializer GPIO | ^^SER0/1/2/3 |
| CAM_ALIAS         | Sensor Alias address | 0x54/0x55/0x56/0x57 depends on hardware design. |

</details>

<details>
<summary>Serializer Specific Defines</summary>

### Serializer Specific Defines

Serializer-specific defines in ASL are used to specify the serializer configuration. These defines are expected to be defined in the channel-specific ASL source file for each link with a serializer and will be used by the common serializer ASL source file. The table below describes the required defines for a serializer and the correlation to the legacy setup, if applicable.

| Serializer Define | Description | Value | Correlate to legacy setup |
| --- | --- | --- | --- |
| DESCH_SER_I2C            | I2C address of the serializer | 0x40 or 0x62 based on MAX9295 design | ser_physical_addr in ipu-acpi.c |
| DESCH_SER_EXTRA_GPIO_PIN | (Optional) Extra MFP pin to be configured in Serializer | 1-11 for for mfp1-11 in max9295 | ser_gpio.chip_hwnum in ipu-acpi.c |
| DESCH_SER_X_VC           | (Optional) Setting for max9295 serializer to configure VC filter for Pipe X | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe X | - |
| DESCH_SER_Y_VC           | (Optional) Setting for max9295 serializer to configure VC filter for Pipe Y | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe Y | - |
| DESCH_SER_Z_VC           | (Optional) Setting for max9295 serializer to configure VC filter for Pipe Z | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe Z | - |
| DESCH_SER_U_VC           | (Optional) Setting for max9295 serializer to configure VC filter for Pipe U | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe U | - |

</details>

<details>
<summary>Sensor Specific Defines</summary>

### Sensor Specific Defines

| Sensor Define | Description | Value | Correlate to legacy setup |
| --- | --- | --- | --- |
| CAM_LANES           | Number of lanes used by the camera sensor | 2 or 4 depending on use case | LaneUsed in BIOS |
| EXTERNAL_FRAME_SYNC | (Optional) Use of FSIN GPIO. Requires an external pulse supplied to deserializer MFP pin | 1 if needed (DESCH_SER_EXTRA_GPIO_PIN and DES_FSIN_GPIO_PIN should also be defined in this case),  0 (default) | - |

#### Sample values for different sensor models

| Sensor Model  | DESCH_SER_I2C | DESCH_SER_EXTRA_GPIO_PIN | EXTERNAL_FRAME_SYNC | CAM_LANES | DESCH_SER_X/Y/Z/U_VC |
| --- | --- | --- | --- | --- | --- |
| D3 ISX031     | 0x40 | - | - | 4 | - |
| LI ISX031     | 0x62 | - | - | 4 | - |
| Sensing ISX031| 0x40 | 7 | 1 | 4 | - |
| RS D457       | 0x40 | - | - | 2 | Package () { 0 } for VC0 on Pipe X <br> Package () { 1 } for VC1 on Pipe Y <br> Package () { 2 } for VC2 on Pipe Z <br> Package () { 3 } for VC3 on Pipe U |
| D3 AR0234     | 0x40 | - | - | 2 | - |

</details>

</details>

## ASL Source Files for Different Use Cases

The reference ASL source files are located in [../../acpi/](../../acpi/) and are grouped according to the platform. The files only have minor differences such as PHY type and MIPI port.

Make sure the below ASL source files are at least a **subset** of your current hardware setup.

> Example 1: If you connected sensors on all 4 links with max96724, the ASL source file can have any 1/2/3/4 channels.

> Example 2: If you only connected on 1 link with max96724, the ASL source file can have only 1 channel, and must be that specific channel.

> **WARNING**: \
> If ASL specified more than actual Hardware connection, or there is probe failure in any one of the links, the whole v4l2 subdev registration will fail, and subsequent streaming will not be able to work.

<details>
<summary> IPU6EPMTL </summary>

- [ISX031 MIPI YUV](../../acpi/ipu6/mipi_isx031.asl)
- [AR0234 GMSL RAW on MAX9296](../../acpi/ipu6/max9296_d3_ar0234.asl)
- [ISX031 GMSL YUV on MAX9296](../../acpi/ipu6/max9296_d3_isx031.asl)
- [ISX031 GMSL YUV on MAX96724 DPHY](../../acpi/ipu6/max96724_dphy_d3_isx031.asl)
- [D457 GMSL 3D on MAX9296](../../acpi/ipu6/max9296_rs_d457.asl)
- [LI ISX031 GMSL on MAX9296](../../acpi/ipu6/max9296_li_isx031.asl)
- [Sensing ISX031 GMSL on MAX9296](../../acpi/ipu6/max9296_sensing_isx031.asl)
- [2D+2D, 2D+3D GMSL mix-and-match on MAX9296](../../acpi/ipu6/max9296_mixed.asl)

<p align="right">(<a href="#compile-and-load">Go to Compile and Load</a>)</p>

</details>

<details>
<summary> IPU75XA </summary>

- [ISX031 MIPI YUV](../../acpi/ipu7/mipi_isx031.asl)
- [AR0234 GMSL RAW on MAX96724](../../acpi/ipu7/max96724_d3_ar0234.asl)
- [ISX031 GMSL YUV on MAX96724](../../acpi/ipu7/max96724_d3_isx031.asl)
- [ISX031 GMSL YUV on MAX96724 DPHY](../../acpi/ipu7/max96724_dphy_d3_isx031.asl)
- [D457 GMSL 3D on MAX96724](../../acpi/ipu7/max96724_rs_d457.asl)
- [LI ISX031 GMSL on MAX96724](../../acpi/ipu7/max96724_li_isx031.asl)
- [Sensing ISX031 GMSL on MAX96724](../../acpi/ipu7/max96724_sensing_isx031.asl)
- [2D YUV + 2D YUV, 2D YUV + 3D YUV GMSL mix-and-match on MAX96724](../../acpi/ipu7/max96724_mixed.asl)
- [2D RAW + 2D YUV, 2D YUV + 2D RAW GMSL mix-and-match on MAX96724](../../acpi/ipu7/max96724_mixed_d3_ar0234_isx031.asl)
- [FrameSync on MAX96724](../../acpi/ipu7/max96724_sensing_isx031_fs.asl)

<p align="right">(<a href="#compile-and-load">Go to Compile and Load</a>)</p>

</details>

<details>
<summary> IPU8 </summary>

- [ISX031 MIPI YUV](../../acpi/ipu8/mipi_isx031.asl)
- [AR0234 GMSL RAW on MAX96724](../../acpi/ipu8/max96724_d3_ar0234.asl)
- [ISX031 GMSL YUV on MAX96724](../../acpi/ipu8/max96724_d3_isx031.asl)
- [ISX031 GMSL YUV on MAX96724 DPHY](../../acpi/ipu8/max96724_dphy_d3_isx031.asl)
- [D457 GMSL 3D on MAX96724](../../acpi/ipu8/max96724_rs_d457.asl)
- [LI ISX031 GMSL on MAX96724](../../acpi/ipu8/max96724_li_isx031.asl)
- [Sensing ISX031 GMSL on MAX96724](../../acpi/ipu8/max96724_sensing_isx031.asl)
- [2D YUV + 2D YUV, 2D YUV + 3D YUV GMSL mix-and-match on MAX96724](../../acpi/ipu8/max96724_mixed.asl)
- [2D RAW + 2D YUV, 2D YUV + 2D RAW GMSL mix-and-match on MAX96724](../../acpi/ipu8/max96724_mixed_d3_ar0234_isx031.asl)

<p align="right">(<a href="#compile-and-load">Go to Compile and Load</a>)</p>

</details>

<p align="right">(<a href="#compile-and-load">Go to Compile and Load</a>)</p>

## Kernel Dependencies for SSDT ASL method

For GMSL setups using SSDT ASL method, the base kernel needs the following kernel configs to be enabled. If they are not enabled, rebuild your kernel with below kernel configs.

    CONFIG_COMPILE_TEST=y
    CONFIG_I2C_ATR=m

>**Note:** `CONFIG_COMPILE_TEST` is a dependency config for `CONFIG_I2C_ATR`.

To rebuild [Intel Linux-Kernel-Overlay](https://github.com/intel/linux-kernel-overlay.git), follow the instructions in [Intel BKC using Getting Started Guide (GSG)](../../README.md#intel-bkc-using-getting-started-guide-gsg).
Before running `build.sh`, add above configs to `kernel-config/features/ipu.cfg`.

If you are rebuilding kernel from other source, make sure to add the configs into `.config` and run `make olddefconfig` before building the kernel.

After installing the kernel and reboot, verify `i2c_atr` module is present and used by `max_serdes`.

If `CONFIG_I2C_ATR=m`, verify the `i2c_atr` module is loaded:

    lsmod | grep i2c_atr

You should see output similar to below:

    i2c_atr                24576  1 max_serdes

If `CONFIG_I2C_ATR=y`, there will be no `lsmod` output for `i2c_atr`.

## Compile and Load

This section contains steps to compile your ASL source files into AML binary tables, and load them into the kernel during boot. The steps are as follows:

### Prerequisite on Canonical Ubuntu 24.04 or 26.04:

    sudo apt-get install flex bison

Install acpica tools version [20260408](https://github.com/acpica/acpica/releases/tag/20260408)

    wget https://github.com/acpica/acpica/releases/download/20260408/acpica-unix-20260408.tar.gz
    tar zxf ./acpica-unix-20260408.tar.gz
    cd acpica-unix-20260408/
    make
    sudo make install

### Compile ASL source file

Run helper script to generate initramfs image from ASL source file and copy to /boot

    ../../script/acpi/gen_ssdt.sh ../../acpi/{create-your-own.asl}

### Load SSDT initramfs

Add the following line to /etc/default/grub for GRUB to load the SSDT initramfs. Update and reboot. Make sure all camera-related BIOS settings are disabled.

    echo 'GRUB_EARLY_INITRD_LINUX_CUSTOM="img_ssdt.img"' | sudo tee -a /etc/default/grub
    sudo update-grub
    sudo reboot

#### Unload SSDT initramfs

To revert to the legacy setup using BIOS and ipu-acpi, remove the line below from /etc/default/grub, run update-grub, and reboot.

    sudo sed -i '/GRUB_EARLY_INITRD_LINUX_CUSTOM/d' /etc/default/grub
    sudo update-grub
    sudo reboot

### SSDT Verification

Inspect loading of SSDT in kernel dmesg

    dmesg | grep SSDT

You should see log similar to below:

    [    0.009303] ACPI: SSDT ACPI table found in initrd [kernel/firmware/acpi/isx031.aml][0x143d]
    ...
    [    0.009609] ACPI: Table Upgrade: install [SSDT-      - IMG_IPU]
    [    0.009611] ACPI: SSDT 0x00000000678E6000 00143D (v02        IMG_IPU  20260513 INTL 20250404)


[Proceed to userspace-gmsl.md](userspace-gmsl.md) for media-ctl pipeline construction and sensor streaming verification.

<p align="right">(<a href="#description">back to top</a>)</p>
