# About This Project

This repository contains reference drivers and configurations for Intel MIPI CSI cameras, supporting various sensor modules and Image Processing Units (IPUs).

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#supported-sensors">Supported Sensors</a></li>
    <li><a href="#supported-ubuntu-and-kernel-version">Supported Ubuntu and Kernel Version</a></li>
    <li><a href="#directory-structure">Directory Structure</a></li>
    <li><a href="#getting-started-guide">Getting Started Guide</a></li>
    <li><a href="#software-dependencies">Software Dependencies</a></li>
    <li>
      <a href="#setup-procedure">Setup Procedure</a>
      <ul>
        <li><a href="#kernel-driver-dkms-build">Kernel Driver DKMS Build</a></li>
        <li><a href="#bios-configuration">BIOS Configuration</a></li>
        <li><a href="#camera-configuration-file-setup">Camera Configuration File Setup</a></li>
        <li><a href="#setup-verification">Setup Verification</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#security">Security</a></li>
    <li><a href="#code-of-conduct">Code of Conduct</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>

## Supported Sensors

| Sensor          | Sensor Type | Vendor          | IPU Version                      |
|-----------------|-------------|-----------------|----------------------------------|
| AR0233+GW5300   | GMSL        | Sensing         | IPU6EPMTL, IPU75XA               |
| AR0234          | GMSL        | D3 Embedded     | IPU6EPMTL                        |
| AR0234          | MIPI CSI-2  | D3 Embedded     | IPU6EPMTL                        |
| AR0820+GW5300   | GMSL        | Sensing         | IPU6EPMTL, IPU75XA               |
| AR0830+AP1302   | MIPI CSI-2  | Leopard Imaging | IPU6EPMTL, IPU75XA               |
| ISX031          | GMSL        | D3 Embedded     | IPU6EP, IPU6EPMTL, IPU75XA, IPU8 |
| ISX031          | GMSL        | Leopard Imaging | IPU6EP, IPU6EPMTL, IPU75XA, IPU8 |
| ISX031          | GMSL        | Sensing         | IPU6EP, IPU6EPMTL, IPU75XA       |
| ISX031          | MIPI CSI-2  | D3 Embedded     | IPU6EP, IPU6EPMTL, IPU75XA, IPU8 |
| ISX031          | MIPI CSI-2  | Sensing         | IPU6EP, IPU6EPMTL, IPU75XA       |
| IMX415          | MIPI CSI-2  | Leopard Imaging | IPU6EPMTL                        |
| IMX586          | MIPI CSI-2  | Leopard Imaging | IPU6EPMTL                        |
| OV13B10         | MIPI CSI-2  | Leopard Imaging | IPU8                             |

> **Note:** \
IPU6EP represents ADL, TWL, ASL and RPL platforms; \
IPU6EPMTL represents MTL and ARL platforms; \
IPU75XA represents PTL platforms; \
IPU8 represents NVL platforms.

## Supported Ubuntu and Kernel Version

| IPU Version        | Ubuntu Version  | Kernel Version  |
|--------------------|-----------------|-----------------|
| IPU6EP / IPU6EPMTL | 24.04.4         | 6.12 Intel BKC  |
|                    | 24.04.4         | 6.17 Canonical  |
|                    | 26.04           | 7.0 Canonical   |
| IPU75XA            | 24.04.4         | 6.17 Intel BKC  |
|                    | 24.04.4         | 6.17 Canonical  |
|                    | 26.04           | 7.0 Canonical   |
| IPU8               | 24.04.4         | 6.18 Intel BKC  |
|                    | 24.04.4         | 7.0 IOT Next    |

## Directory Structure
| Directory | Description |
|-----------|-------------|
| [drivers/](drivers) | Host Linux kernel drivers for supported sensors |
| [config/](config)   | Host middleware configuration files |
| [doc/](doc)         | Documentation guide for kernelspace and userspace configuration |
| [include/](include) | Header files for driver compilation |
| [acpi/](acpi)       | Host ASL source files for different configurations |

## Getting Started Guide

1. Download `Getting Started Guide` (table below), and setup according to your target `Platform`.
2. Inside the guide, follow all instructions under section `Getting Started with Ubuntu with Kernel Overlay`.
3. Under section `Auto Script Installation`, download and use `Ubuntu Kernel Overlay Auto Installar Script` from platform-respective Software Packages.

> **Note:** All collaterals belows can be downloaded in [rdc.intel.com](https://www.intel.com/content/www/us/en/resources-documentation/developer.html) with proper granted access.

| Platform | Getting Started Guide | Software Package |
|---|---|---|
| ARL | [828853](https://www.intel.com/content/www/us/en/secure/content-details/828853/ubuntu-with-kernel-overlay-on-intel-core-ultra-200u-and-200h-series-processors-code-named-arrow-lake-u-h-for-edge-platforms-get-started-guide.html?DocID=828853) | [831484](https://www.intel.com/content/www/us/en/secure/design/confidential/software-kits/kit-details.html?kitId=831484) |
| MTL | [779460](https://www.intel.com/content/www/us/en/secure/content-details/779460/ubuntu-with-kernel-overlay-on-intel-core-mobile-processors-code-named-meteor-lake-u-h-for-edge-platforms-get-started-guide.html?DocID=779460) | [790840](https://www.intel.com/content/www/us/en/secure/content-details/790840/meteor-lake-ps-ubuntu-with-kernel-overlay-software-packages.html?DocID=790840) |
| TWL | [793827](https://www.intel.com/content/www/us/en/secure/content-details/793827/ubuntu-with-kernel-overlay-intel-atom-x7000re-x7000c-x7000fe-processor-series-intel-processor-n150-n250-intel-core-3-processor-n355-for-edge-applications-get-started-guide-amston-lake-mr5-amston-lake-fusa-pv-twin-lake-mr2.html?DocID=793827) | [803960](https://www.intel.com/content/www/us/en/secure/design/confidential/software-kits/kit-details.html?kitId=803960) |
| PTL | [858119](https://edc.intel.com/content/www/us/en/secure/design/confidential/products-and-solutions/processors-and-chipsets/panther-lake-h/with-linux-os-get-started-guide-for-edge-compute-applications/) | [871556](https://www.intel.com/content/www/us/en/secure/design/confidential/software-kits/kit-details.html?kitId=860689) |

Reference: [Intel® IPU6 Enabling Partners Technical Collaterals Advisory](https://www.intel.com/content/www/us/en/secure/content-details/817101/intel-ipu6-enabling-partners-technical-collaterals-advisory.html?DocID=817101)

## Software Dependencies

Install these software dependencies in your target system:

- ipu-camera-bins (E.g. [ipu6-camera-bins](https://github.com/intel/ipu6-camera-bins/tree/iotg_ipu6) / [ipu7-camera-bins](https://github.com/intel/ipu7-camera-bins))
- ipu-camera-hal (E.g. [ipu6-camera-hal](https://github.com/intel/ipu6-camera-hal/tree/iotg_ipu6) / [ipu7-camera-hal](https://github.com/intel/ipu7-camera-hal))
- [icamerasrc](https://github.com/intel/icamerasrc/tree/icamerasrc_slim_api)

| IPU Version | ipu-camera-bins                          | ipu-camera-hal                           | icamerasrc                               |
|-------------|------------------------------------------|------------------------------------------|------------------------------------------|
| IPU6        | d9421fef539f24fc80c27002d5da753e193b0670 | f93eec544a5234bf0b610b3f76d64c8fa711c364 | 867c5b6ab7925c9b69b8374873a832266d97d7e5 |
| IPU7        | d235697c3bb41d56402d4805a7b82fdc938c077a | ea085c325e7a67a811a0baa5ce2d1b8f5641ea02 | 867c5b6ab7925c9b69b8374873a832266d97d7e5 |

## Setup Procedure

### Kernel Driver DKMS Build

Initialize and update current repository recursively to ensure all dependencies are correctly fetched.

    git checkout main
    git submodule update --init --recursive

Build and install modules using DKMS

    sudo dkms remove ipu-camera-sensor/0.1
    sudo rm -rf /usr/src/ipu-camera-sensor-0.1/

    sudo dkms add .
    sudo dkms build -m ipu-camera-sensor -v 0.1
    sudo dkms install -m ipu-camera-sensor -v 0.1 --force

### BIOS Configuration

1. Power cycle target system with sensors connected.
2. Import sensor profile into BIOS, under section `BIOS Configuration Table` in recommended userspace.md.
    - E.g. ISX031 GMSL using [userspace-gmsl.md](doc/isx031/userspace-gmsl.md)
    - E.g. AR0234 MIPI using [userspace-mipi.md](doc/ar0234/userspace-mipi.md)

### Camera Configuration File Setup

Setup camera configuration file under section `Camera Configuration File Setup` in recommended userspace.md.

### Setup Verification

Verify sensor setup using `media-ctl`.

> **Note:** Minimum version required = ([1.30](https://github.com/gjasny/v4l-utils/tree/stable-1.30))

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
