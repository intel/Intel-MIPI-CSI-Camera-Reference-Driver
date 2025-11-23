# Imaging ACPI Configuration SSDT User Guide
## Overview
This directory contains information of imaging specific ACPI SSDT ASL sources compilation and loading

## How to compile ACPI ASL source
1. Install acpica tools version 20250807 https://github.com/acpica/acpica/releases/tag/20250807
```sh
 wget https://github.com/user-attachments/files/21674610/acpica-unix-20250807.tar.gz
 tar zxf ./acpica-unix-20250807.tar.gz
 cd acpica-unix-20250807/
 make
 sudo make install
 ```

2. Compile ASL source into AML file in acpi/sensor.asl
```sh
iasl acpi/d3_isx031_gmsl.asl
```

## How to load imaging SSDT at boot time
1. Create initramfs containing AML file
```sh
mkdir -p kernel/firmware/acpi/
find kernel | cpio -H newc --create > img_ssdt.img
```

2. Copy initfamfs to /boot directory
```sh
sudo cp img_ssdt.img /boot
```

3. Add following line to /etc/default/grub for  GRUB to load SSDT initramf
```
GRUB_EARLY_INITRD_LINUX_CUSTOM="img_ssdt.img"
```
4. Rebuild GRUB configuration
```sh
sudo update-grub
```

5. Reboot system and inspect loading of SSDT in kernel dmesg
```sh
dmesg | grep SSDT
```
You should see 
```
[    0.009303] ACPI: SSDT ACPI table found in initrd [kernel/firmware/acpi/isx031.aml][0x143d]
...
[    0.009609] ACPI: Table Upgrade: install [SSDT-      - IMG_PTL]
[    0.009611] ACPI: SSDT 0x00000000678E6000 00143D (v02        IMG_PTL  20250920 INTL 20250404)
```
