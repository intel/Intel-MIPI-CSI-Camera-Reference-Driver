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
        <li><a href="#"bios-configuration>BIOS Configuration</a></li>
        <li><a href="#sensor-xml-configuration-file-setup">Sensor XML Configuration File Setup</a></li>
        <li><a href="#setup-verification">Setup Verification</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#security">Security</a></li>
    <li><a href="#code-of-conduct">Code of Conduct</a></li>
  </ol>
</details>

## Supported Sensors

| Sensor          |Sensor Type | Vendor          | IPU Version                |
|-----------------|------------|-----------------|----------------------------|
| AR0233+GW5300   | GMSL       | Sensing         | IPU6EPMTL, IPU75XA         |
| AR0234          | GMSL       | D3 Embedded     | IPU6EPMTL                  |
| AR0234          | MIPI CSI-2 | D3 Embedded     | IPU6EPMTL                  |
| AR0820+GW5300   | GMSL       | Sensing         | IPU6EPMTL, IPU75XA         |
| AR0830+AP1302   | MIPI CSI-2 | Leopard Imaging | IPU6EPMTL, IPU75XA         |
| ISX031          | GMSL       | D3 Embedded     | IPU6EP, IPU6EPMTL, IPU75XA |
| ISX031          | GMSL       | Leopard Imaging | IPU6EP, IPU6EPMTL, IPU75XA |
| ISX031          | GMSL       | Sensing         | IPU6EP, IPU6EPMTL, IPU75XA |
| ISX031          | MIPI CSI-2 | D3 Embedded     | IPU6EP, IPU6EPMTL, IPU75XA |

> **Note:** \
IPU6EP represents ADL, TWL, ASL and RPL platforms; \
IPU6EPMTL represents MTL and ARL platforms; \
IPU75XA represents PTL platforms.

## Supported Ubuntu and Kernel Version

| IPU Version        | Ubuntu Version  | Kernel Version  |
|--------------------|-----------------|-----------------|
| IPU6EP / IPU6EPMTL | 24.04.4         | 6.12 Intel BKC  |
|                    | 24.04.4         | 6.17 Canonical  |
| IPU75XA            | 24.04.4         | 6.17 Intel BKC  |
|                    | 24.04.4         | 6.17 Canonical  |

## Directory Structure

| Directory | Description |
|-----------|-------------|
| [drivers/](drivers) | Host Linux kernel drivers for supported sensors |
| [config/](config)   | Host middleware configuration files |
| [doc/](doc)         | Documentation guide for kernelspace and userspace configuration |
| [include/](include) | Header files for driver compilation |

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
| IPU6        | 0b102acf2d95f86ec85f0299e0dc779af5fdfb81 | a647a0a0c660c1e43b00ae9e06c0a74428120f3a | 4fb31db76b618aae72184c59314b839dedb42689 |
| IPU7        | 2ef0857570b2dde3c2072fdacf22fdfff1a89bf2 | 3b9388ecdb682b6e7e9f57a4192b4612bfb43410 | 4fb31db76b618aae72184c59314b839dedb42689 |

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

<p align="right">(<a href="#readme-top">back to top</a>)</p>
