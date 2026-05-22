## User Guide for ACPI SSDT ASL Compilation and Loading for Imaging Sensors

## Description
This document contains information of imaging specific ACPI SSDT ASL sources compilation and loading. It also contains information of how to construct media-ctl pipeline for imaging sensors described in ACPI SSDT, and how to verify the streaming of sensors.

## Create ACPI ASL Source Files

ASL source file needs to be created based on current hardware setup using reference ASL source file in ../acpi/{ipu}.
Below sections describe the common ASL source files for different use cases and IPU generations, and the required defines in ASL source file for deserializer, serializer and camera sensor.

### Common ASL to be shared across different use cases and IPU generations
These ASL source files should be able to be reused for different use cases. 

> **Note:** If there is a need to be modify common ASL, make sure the changes are generic enough to be reused for different use cases.

> **Note:** These ASL source files are **NOT** meant to be compiled into AML file directly. They should be included by use case specific ASL source files.

| ASL source file | Description | Usage |
| --- | --- | --- |
| _des_common_max96724.asl  | Common ASL for MAX96724 deserializer | Included by caller ASL source file for each MAX96724 deserializer |
| _des_ch_common_isx031.asl | Common ASL for single Deserializer Channel / Link with ISX031 2D camera sensor | Included by caller ASL source file for each link with ISX031 sensor |
| _des_ch_common_d457.asl   | Common ASL for single Deserializer Channel / Link with D457 3D camera sensor | Included by caller ASL source file for each link with D457 sensor |
| _ser_common_max9295.asl   | Common ASL for MAX9295 serializer    | Included by _des_ch_common_*.asl |
| _cam_common_isx031.asl    | Common ASL for ISX031 2D camera sensor | Included by _des_ch_common_isx031.asl |
| _cam_common_d457.asl      | Common ASL for D457 3D camera sensor | Included by _des_ch_common_d457.asl |

### ASL source file for different use cases

The reference ASL source files are located in ../acpi/{ipu}. Make sure below ASL source files is at least **subset** of your current hardware setup.
If you connect 4x 2D sensor with max96724, the ASL source file can have 1/2/3/4 channels.
If you only connect 1x 2D sensor with max96724, the ASL source file can only have 1 channel.

> **WARNING**: If ASL specified more than actual Hardware connection, or there is probe failure in any one of the links, the whole v4l2 subdev registration will fail, and subsequent streaming will not be able to work.

> There are acpi/ipu6 , acpi/ipu7 , acpi/ipu8 folders. The files are mostly similar across different IPU generations, but with minor difference such as CPHY/DPHY for deserializer, or IPU MIPI port. Make sure to pick the right reference ASL source file based on your IPU generation.

| Use case | Reference ASL source file |
| --- | --- |
| 1x 2D sensor | max96724_li_isx031.asl, max96724_sensing_isx031.asl |
| Nx 2D sensor  | max96724_d3_isx031.asl, max96724_dphy_d3_isx031.asl, max9296_d3_isx031.asl |
| Nx 3D sensor | max96724_rs_d457.asl, max9296_rs_d457.asl |
| Nx 2D sensors and 3D sensor | max96724_mixed.asl, max9296_mixed.asl |

### Deserializer Specific Defines in ASL

Deserializer specific defines are used to describe the Connection to Board and SOC. These defines are expected to be defined in the caller ASL source file for each deserializer, and will be used by the common ASL source files. Below table describes the required defines for deserializer, and the correlation to legacy BIOS setting if applicable.

| Deserializer Define | Description | Value | Correlate to legacy BIOS setting |
| --- | --- | --- | --- |
| DES_PHY_TYPE      | PHY connection to Board | 0 for CPHY, 1 for DPHY | PhyConfiguration |
| DES_I2C_ADDR      | I2C address of the deserializer | 0x0027 for MAX96724, 0x0048 for MAX9296 | I2C Device 0 |
| DES_LANES         | Number of lanes used by the deserializer | 2 or 4 depending on use case | Ppr Value |
| DES_INTERNAL_PHY  | Internal PHY + 4 | 4/5/6/7 for PHY0/1/2/3 | Rotation (Rotation/90 + 4) |
| DES_TO_MIPI_PORT  | Connected to MIPI port of SOC | 0/1/2/3/4/5 based on SOC and Hardware design | MIPI Port |
| DES_I2C_BUS       | I2C bus number for deserializer | "\\_SB.PC00.I2Cx" | I2C Channel |
| DES_PATH          | ACPI Path for Deserializer | "\\_SB.PC00.DESx" | - |
| DES_REF           | ACPI Reference for Deserializer | \_SB.PC00.DESx | - |
| DES_PIPE_STR_AUTOSELECT | (Optional) Setting for MAX96724 to configure pipe, useful for 3D camera | 0 to disable fixed pipe, 1 to enable fixed pipe (default) | - |

### Channel Specific Defines in ASL

Channel specific defines are common for all links, with index increment. For example, if there are 4 deserializer links, the ASL source file should have 4 sets of channel specific defines with link number from 0 to 3. These defines are expected to be defined in the caller ASL source file for each link, and will be used by the common ASL source files. Below table describes the required defines for each channel.

| Channel Define | Description | Value |
| --- | --- | --- |
| DESCH_LINK_NUM | Link number for current channel | 0/1/2/3 |
| DESCH_CH | Channel Device for current link | CH00/CH01/CH02/CH03 |
| DESCH_SER | Serializer Device for current link | SER0/SER1/SER2/SER3 |
| DESCH_CAM | Camera Device for current link | CAM0/CAM1/CAM2/CAM3 |
| DESCH_CH_PATH | ACPI Path for Channel Device | "\\_SB.PC00.DESx.CH0x" |
| DESCH_SER_PATH | ACPI Path for Serializer Device | "\\_SB.PC00.DESx.SER0/1/2/3" |
| DESCH_SER_REF | ACPI Reference for Serializer Device | \_SB.PC00.DESx.SER0/1/2/3 |
| DESCH_SER_GPIOREF | ACPI Reference for Serializer GPIO | ^^SER0/1/2/3 |
| CAM_ALIAS | Sensor Alias address | 0x54/0x55/0x56/0x57 depends on hardware design. |

### Serializer Specific Defines in ASL

Serializer Specific Defines in ASL is used to specify the configuration for serializer. These defines are expected to be defined in the channel specific ASL source file for each link with serializer, and will be used by the common serializer ASL source file. Below table describes the required defines for serializer, and the correlation to legacy setup if applicable.

| Serializer Define | Description | Value | Correlate to legacy setup |
| --- | --- | --- | --- |
| DESCH_SER_I2C | I2C address of the serializer | 0x40 or 0x62 based on MAX9295 design | ser_physical_addr in ipu-acpi.c |
| DESCH_SER_EXTRA_GPIO_PIN | (Optional) Extra MFP pin to be configured in Serializer | 1-11 for for mfp1-11 in max9295 | ser_gpio.chip_hwnum in ipu-acpi.c |
| DESCH_SER_X_VC | (Optional) Setting for max9295 serializer to configure VC filter for Pipe X | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe X | - |
| DESCH_SER_Y_VC | (Optional) Setting for max9295 serializer to configure VC filter for Pipe Y | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe Y | - |
| DESCH_SER_Z_VC | (Optional) Setting for max9295 serializer to configure VC filter for Pipe Z | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe Z | - |
| DESCH_SER_U_VC | (Optional) Setting for max9295 serializer to configure VC filter for Pipe U | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe U | - |

### Sensor Specific Defines in ASL

| Sensor Define | Description | Value | Correlate to legacy setup |
| --- | --- | --- | --- |
| CAM_LANES | Number of lanes used by the camera sensor | 2 or 4 depending on use case | LaneUsed in BIOS |
| DESCH_CAM_FSIN_GPIO | (Optional) Use of FSIN GPIO | 1 if needed (DESCH_SER_EXTRA_GPIO_PIN should also be defined in this case),  0 (default) | - |

#### Sample values for different models of sensors

| Sensor Model  | DESCH_SER_I2C | DESCH__SER_EXTRA_GPIO_PIN | DESCH_CAM_FSIN_GPIO | CAM_LANES | DESCH_SER_X/Y/Z/U_VC |
| --- | --- | --- | --- | --- | --- |
| D3 ISX031     | 0x40 | - | - | 4 | - |
| LI ISX031     | 0x62 | - | - | 4 | - |
| Sensing ISX031| 0x40 | 7 | 1 | 4 | - |
| RS D457       | 0x40 | - | - | 2 | Package () { 0/1/2/3 } for VC0/1/2/3 on Pipe X/Y/Z/U |


### Compile and Load ACPI ASL source on Canonical Ubuntu 24.04 or 26.04
Pre-requisite:
    sudo apt-get install flex bison

Install acpica tools version 20260408 https://github.com/acpica/acpica/releases/tag/20260408

    wget https://github.com/acpica/acpica/releases/download/20260408/acpica-unix-20260408.tar.gz
    tar zxf ./acpica-unix-20260408.tar.gz
    cd acpica-unix-20260408/
    make
    sudo make install

Run helper script to generate initramfs image from ASL source file and copy to /boot

    ../../script/gen_ssdt.sh ../../acpi/{ipu}/sensor.asl

Add following line to /etc/default/grub for GRUB to load SSDT initramfs. Update and reboot. Make sure all camera related BIOS setting are disabled.

    echo 'GRUB_EARLY_INITRD_LINUX_CUSTOM="img_ssdt.img"' | sudo tee -a /etc/default/grub
    sudo update-grub
    sudo reboot

>To revert back to Legacy setup using BIOS and ipu-acpi, remove below line from in /etc/default/grub, update-grub and reboot.

    sed -i '/GRUB_EARLY_INITRD_LINUX_CUSTOM/d' /etc/default/grub
    sudo update-grub
    sudo reboot

Inspect loading of SSDT in kernel dmesg

    dmesg | grep SSDT

You should see log similar to below:

    [    0.009303] ACPI: SSDT ACPI table found in initrd [kernel/firmware/acpi/isx031.aml][0x143d]
    ...
    [    0.009609] ACPI: Table Upgrade: install [SSDT-      - IMG_IPU]
    [    0.009611] ACPI: SSDT 0x00000000678E6000 00143D (v02        IMG_IPU  20260513 INTL 20250404)
