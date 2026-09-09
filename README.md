# About This Project

This repository contains reference drivers and configurations for Intel MIPI CSI cameras, supporting various sensor modules and Image Processing Units (IPUs).

<!-- TABLE OF CONTENTS -->
<details open>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#supported-sensors">Supported Sensors</a></li>
    <li><a href="#supported-ubuntu-and-kernel-version">Supported Ubuntu and Kernel Version</a></li>
    <li><a href="#directory-structure">Directory Structure</a></li>
    <li><a href="#setup-procedure">Setup Procedure</a>
      <ul>
      <li><a href="#software-setup---ubuntu-and-kernel">Software Setup - Ubuntu and Kernel</a></li>
        <li><a href="#software-setup---userspace">Software Setup - Userspace</a></li>
        <li><a href="#software-setup---kernel-driver-dkms-build">Software Setup - Kernel Driver DKMS Build</a></li>
        <li><a href="#hardware-setup">Hardware Setup</a></li>
        <li><a href="#acpi-setup---bios-configuration">ACPI Setup - BIOS</a></li>
        <li><a href="#acpi-setup---asl-configuration">ACPI Setup - ASL</a></li>
        <li><a href="#setup-verification">Setup Verification</a></li>
        <li><a href="#stream-verification">Stream Verification</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#security">Security</a></li>
    <li><a href="#code-of-conduct">Code of Conduct</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>


## Supported Sensors

| GMSL Sensor                                 | User Guide                                  | Vendor          | IPU6EP | IPU6EPMTL | IPU75XA | IPU8 |
|---------------------------------------------|---------------------------------------------|-----------------|:------:|:---------:|:-------:|:----:|
| [AR0233+GW5300](doc/ar0233/kernelspace.md)  | [User Guide](doc/ar0233/userspace-gmsl.md)  | Sensing         |❌ |✅B|✅B|❌ |
| [AR0234](doc/ar0234/kernelspace.md)         | [User Guide](doc/ar0234/userspace-gmsl.md)  | D3 Embedded     |❌ |✅ |✅A|✅A|
| [AR0820+GW5300](doc/ar0820/kernelspace.md)  | [User Guide](doc/ar0820/userspace-gmsl.md)  | Sensing         |❌ |✅B|✅B|❌ |
| D457                                        | [User Guide](doc/d4xx/userspace-gmsl.md)    | RealSense       |❌ |✅ |✅ |✅ |
| [ISX031](doc/isx031/kernelspace.md)         | [User Guide](doc/isx031/userspace-gmsl.md)  | D3 Embedded     |✅B|✅ |✅ |✅ |
| [ISX031](doc/isx031/kernelspace.md)         | [User Guide](doc/isx031/userspace-gmsl.md)  | Leopard Imaging |✅B|✅ |✅ |✅ |
| [ISX031](doc/isx031/kernelspace.md)         | [User Guide](doc/isx031/userspace-gmsl.md)  | Sensing         |✅B|✅ |✅ |✅ |


| MIPI Sensor                                 | User Guide                                  | Vendor          | IPU6EP | IPU6EPMTL | IPU75XA | IPU8 |
|---------------------------------------------|---------------------------------------------|-----------------|:------:|:---------:|:-------:|:----:|
| [AR0234](doc/ar0234/kernelspace.md)         | [User Guide](doc/ar0234/userspace-mipi.md)  | D3 Embedded     |❌ |✅B|✅B|✅B|
| [AR0830+AP1302](doc/ar0830/kernelspace.md)  | [User Guide](doc/ar0830/userspace-mipi.md)  | Leopard Imaging |❌ |✅B|✅B|❌ |
| IMX415                                      | [User Guide](doc/imx415/userspace-mipi.md)  | Leopard Imaging |❌ |✅B|❌ |❌ |
| [IMX586](doc/imx586/kernelspace.md)         | [User Guide](doc/imx586/userspace-mipi.md)  | Leopard Imaging |❌ |✅B|❌ |❌ |
| [ISX031](doc/isx031/kernelspace.md)         | [User Guide](doc/isx031/userspace-mipi.md)  | D3 Embedded     |✅B|✅ |✅ |✅ |
| [ISX031](doc/isx031/kernelspace.md)         | [User Guide](doc/isx031/userspace-mipi.md)  | Sensing         |✅B|✅B|✅B|❌ |
| OV13B10                                     | [User Guide](doc/ov13b10/userspace-mipi.md) | Leopard Imaging |❌ |❌ |✅ |✅ |

> **Note:** \
> Items marked with ✅ are enabled by BIOS and ASL method. \
> Items marked with ✅B are enabled by BIOS method ONLY. \
> Items marked with ✅A are enabled by ASL method ONLY. \
> Items marked with ❌ are not enabled by BIOS or ASL method.

> **Note:** \
> IPU6EP represents TWL platforms. \
> IPU6EPMTL represents MTL and ARL platforms. \
> IPU75XA represents PTL platforms. \
> IPU8 represents NVL platforms.

---
## Supported Ubuntu and Kernel Version

| IPU Version | Ubuntu Version  | Intel Kernel Overlay | Canonical Kernel | BIOS support | ASL support |
|:-----------:|-----------------|:--------------------:|:----------------:|:------------:|:-----------:|
| IPU6EP      | 24.04.4         | 6.12                 |                  |✅|❌|
|             | 24.04.4         | 6.18 (BKC)           | 6.17             |✅|❌|
|             | 26.04           | 6.18                 | 7.0              |✅|❌|
| IPU6EPMTL   | 24.04.4         | 6.12                 |                  |✅|❌|
|             | 24.04.4         | 6.18 (BKC)           | 6.17             |✅|✅*|
|             | 26.04           | 6.18                 | 7.0              |✅|✅*|
| IPU75XA     | 24.04.4         | 6.17                 |                  |✅|❌|
|             | 24.04.4         | 6.18 (BKC)           | 6.17             |✅|✅*|
|             | 26.04           | 6.18                 | 7.0              |✅|✅*|
| IPU8        | 24.04.4         | 7.0                  |                  |✅|✅|
|             | 26.04           | 7.0                  |                  |✅|✅|

> **Note:** \
> ✅* indicates that ASL support is **NOT AVAILABLE** for 6.18 (BKC) **by default**. Please rebuild the 6.18 Kernel Overlay with ASL support enabled. For more details, please refer to [doc/acpi/kernelspace.md](doc/acpi/kernelspace.md).\
> To use Intel BKC, please refer [here](#intel-bkc-using-getting-started-guide-gsg) for more details.

---
## Directory Structure
| Directory           | Description |
|---------------------|-------------|
| [acpi/](acpi)       | Host ASL source files for different configurations |
| [config/](config)   | Host middleware configuration files |
| [drivers/](drivers) | Host Linux kernel drivers for supported sensors |
| [doc/](doc)         | Host Documentation guide for kernelspace and userspace configuration |
| [include/](include) | Host Header files for driver compilation |
| [script/](script)   | Host Utility scripts |

---
## Setup Procedure

1. Find your desired target platform and desired Ubuntu/Kernel from the table [above](#supported-ubuntu-and-kernel-version).

2. Setup your target platform. Follow section [below](#software-setup---ubuntu-and-kernel).
   > To use **Intel BKC**, Follow section [below](#intel-bkc-using-getting-started-guide-gsg).

3. DKMS build your kernel drivers. Follow section [below](#software-setup---kernel-driver-dkms-build).

4. Install required software dependencies on your target platform. Follow section [below](#software-setup---userspace).

5. Setup your Hardware. Follow section [below](#hardware-setup).

6. Configure ACPI to match with Hardware setup.

   > For **BIOS Configuration** method, go to [BIOS Configuration](#acpi-setup---bios-configuration).

   > For **ACPI ASL Configuration** method, go to [ACPI ASL Configuration](#acpi-setup---asl-configuration).

7. Boot and verify the setup using `media-ctl`. Go to [Setup Verification](#setup-verification).

8. Enjoy your camera stream! Go to [Stream Verification](#stream-verification).

---
<details open>
<summary>Expand to show detailed setup steps</summary>

---
### Software Setup - Ubuntu and Kernel

#### Intel BKC using Getting Started Guide (GSG)
<details>
<summary> Show details </summary>

> **Note:** GSG requires granted access to Intel® RDC portal. Please contact your Intel representative for access.

> **Skip this section** if you do not have access. Use default Canonical Kernel version that comes with the Ubuntu Image instead.

1. Download **Getting Started Guide** from table below and setup according to your target **Platform**.
2. Under section **Getting Started with Ubuntu with Kernel Overlay**, follow **ALL** instructions to avoid missing dependencies.
3. Under section **Auto Script Installation**, download `Ubuntu Kernel Overlay Auto Installer Script` from platform-respective Software Packages.
4. Run installer script to install Intel Kernel Overlay and Intel BKC on your target platform.

> **Reminder:** All collaterals below can be downloaded in [rdc.intel.com](https://www.intel.com/content/www/us/en/resources-documentation/developer.html) with proper granted access.

| Platform | Getting Started Guide | Software Package |
|:---:|:---:|:---:|
| ARL | [828853](https://www.intel.com/content/www/us/en/secure/content-details/828853/ubuntu-with-kernel-overlay-on-intel-core-ultra-200u-and-200h-series-processors-code-named-arrow-lake-u-h-for-edge-platforms-get-started-guide.html?DocID=828853) | [831484](https://www.intel.com/content/www/us/en/secure/design/confidential/software-kits/kit-details.html?kitId=831484) |
| MTL | [779460](https://www.intel.com/content/www/us/en/secure/content-details/779460/ubuntu-with-kernel-overlay-on-intel-core-mobile-processors-code-named-meteor-lake-u-h-for-edge-platforms-get-started-guide.html?DocID=779460) | [790840](https://www.intel.com/content/www/us/en/secure/content-details/790840/meteor-lake-ps-ubuntu-with-kernel-overlay-software-packages.html?DocID=790840) |
| TWL | [793827](https://www.intel.com/content/www/us/en/secure/content-details/793827/ubuntu-with-kernel-overlay-intel-atom-x7000re-x7000c-x7000fe-processor-series-intel-processor-n150-n250-intel-core-3-processor-n355-for-edge-applications-get-started-guide-amston-lake-mr5-amston-lake-fusa-pv-twin-lake-mr2.html?DocID=793827) | [803960](https://www.intel.com/content/www/us/en/secure/design/confidential/software-kits/kit-details.html?kitId=803960) |
| PTL | [858119](https://edc.intel.com/content/www/us/en/secure/design/confidential/products-and-solutions/processors-and-chipsets/panther-lake-h/with-linux-os-get-started-guide-for-edge-compute-applications/) | [860689](https://www.intel.com/content/www/us/en/secure/design/confidential/software-kits/kit-details.html?kitId=860689) |

Reference: [Intel® IPU6 Enabling Partners Technical Collaterals Advisory](https://www.intel.com/content/www/us/en/secure/content-details/817101/intel-ipu6-enabling-partners-technical-collaterals-advisory.html?DocID=817101)

<p align="right">(<a href="#setup-procedure">Back to Setup Procedure</a>)</p>

</details>

#### Canonical Kernel

Canonical Kernel version comes with the Ubuntu Image by default. Make sure the kernel version is supported [here](#supported-ubuntu-and-kernel-version).

<p align="right">(<a href="#setup-procedure">Back to Setup Procedure</a>)</p>

---
### Software Setup - Userspace

Build and install these software dependencies in your target system:

#### Utility Tools

<details>
<summary> Show details </summary>

> v4l-utils with version >= 1.30 is **mandatory** for GMSL setup. \
> acpica with version >= 20260408 is **mandatory** for ACPI ASL setup.

| Tool | Repository | Tag     | Steps to setup |
|------|------------|---------| -----|
| v4l-utils | [v4l-utils](https://github.com/gjasny/v4l-utils) | stable-1.30 | Build from repo |
| acpica | [acpica](https://github.com/open-acpica/acpica.git) | 20260408    | Refer [here](doc/acpi/kernelspace.md#compile-and-load) |

</details>

#### Intel IPU Camera Software Stack

<details>
<summary>Show details </summary>

- ipu-camera-bins (E.g. [IPU6EP, IPU6EPMTL](https://github.com/intel/ipu6-camera-bins/tree/iotg_ipu6) / [IPU75XA, IPU8](https://github.com/intel/ipu7-camera-bins))
- ipu-camera-hal (E.g. [IPU6EP, IPU6EPMTL](https://github.com/intel/ipu6-camera-hal/tree/iotg_ipu6) / [IPU75XA, IPU8](https://github.com/intel/ipu7-camera-hal))
- [icamerasrc](https://github.com/intel/icamerasrc/tree/icamerasrc_slim_api)

| IPU Version       | ipu-camera-bins                          | ipu-camera-hal                           | icamerasrc                               |
|-------------------|------------------------------------------|------------------------------------------|------------------------------------------|
| IPU6EP, IPU6EPMTL | d9421fef539f24fc80c27002d5da753e193b0670 | 5aa9a3bd3d5582667915d93b0128a02953adbbbc | 7517af78f49a18dde6de86042055aa14ebe6d184 |
| IPU75XA           | adf55525ab9d370828723b1ff8bee76ed7a492e8 | a17d17718e8df9e74940fac32beda016836ef43b | 7517af78f49a18dde6de86042055aa14ebe6d184 |
| IPU8              | adf55525ab9d370828723b1ff8bee76ed7a492e8 | a17d17718e8df9e74940fac32beda016836ef43b | 7517af78f49a18dde6de86042055aa14ebe6d184 |

</details>

#### Media Driver

> **Note:** \
> Build from source only if you are using **Canonical Kernel with PTL**. \
> Skip this step if you are using **Intel BKC**.

> **RECOMMENDED** if you want to have **DMABuf** support.

<details>
<summary>Show List</summary>

| Component    | Repository | Tag     | Build Step |
|--------------|------------|---------|------------|
| libva        | [libva](https://github.com/intel/libva) | 2.23.0 | Follow build steps in repo |
| gmmlib       | [gmmlib](https://github.com/intel/gmmlib) | intel-gmmlib-22.10.0 | Follow build steps in repo |
| media-driver | [media-driver](https://github.com/intel/media-driver) | intel-media-26.1.5 | Follow build steps in repo |

</details>
<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

---
### Software Setup - Kernel Driver DKMS Build

**Initialize** and update current repository recursively to ensure all dependencies are correctly fetched.

    git checkout main
    git submodule update --init --recursive

**Build and install** modules using DKMS

    sudo dkms remove ipu-camera-sensor/0.1
    sudo rm -rf /usr/src/ipu-camera-sensor-0.1/

    sudo dkms add .
    sudo dkms build -m ipu-camera-sensor -v 0.1
    sudo dkms install -m ipu-camera-sensor -v 0.1 --force

<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

---
### Hardware Setup

1. Reference Hardware setup can be found in [doc/{sensor}](doc/) and respective `userspace.md` files.
   - Hardware Connection for [Common GMSL setup](doc/isx031/userspace-gmsl.md#hardware-connection)

<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

---
### ACPI Setup - BIOS Configuration

1. Power cycle target system with sensors connected.
2. Import sensor profile into BIOS, under section `BIOS Configuration Table` in respective userspace.md.
   - E.g. ISX031 GMSL using [userspace-gmsl.md](doc/isx031/userspace-gmsl.md#acpi-setup---bios-configuration)
   - E.g. AR0234 MIPI using [userspace-mipi.md](doc/ar0234/userspace-mipi.md#acpi-setup---bios-configuration)

<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

---
### ACPI Setup - ASL Configuration

ASL Configuration is added since release/26Q2.1.

1. Turn off all Camera related BIOS setting.
2. Create own ASL source file using reference ASL source file in `../../acpi/{ipu}`. Follow section [here](doc/acpi/kernelspace.md#reference-asl-source-files).
3. Compile and load ASL source into GRUB. Follow section [here](doc/acpi/kernelspace.md#compile-and-load)

<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

---
### Setup Verification

> **Note:** Minimum media-ctl version required = ([1.30](https://github.com/gjasny/v4l-utils/tree/stable-1.30))

1. Verify sensor setup using `media-ctl -p`.

<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

---
### Stream Verification

1. Reference stream verification for different sensor setup can be found in [doc/{sensor}](doc/) and respective userspace.md files.
   - E.g. ISX031 GMSL using [userspace-gmsl.md](doc/isx031/userspace-gmsl.md#stream-verification)
   - E.g. AR0234 MIPI using [userspace-mipi.md](doc/ar0234/userspace-mipi.md#stream-verification)

<p align="right">(<a href="#setup-procedure">back to Setup Procedure</a>)</p>

</details>

---
## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## Security

For security concerns, please see [SECURITY.md](SECURITY.md).

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Files in config/ and script/ are licensed under the Apache License 2.0. See [LICENSE-APACHE](LICENSE-APACHE) for details.

Files in acpi/, drivers/ and include/ are licensed under the GPL-2.0 License. See [LICENSE-GPL](LICENSE-GPL) for details.

 <p align="right">(<a href="#about-this-project">back to top</a>)</p>
