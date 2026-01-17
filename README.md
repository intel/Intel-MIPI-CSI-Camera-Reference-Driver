# Intel MIPI-GMSL Camera Reference (Linux v4l2 drivers)

This repository contains Linux debian reference drivers and configurations for Intel Image Processing Units (IPUs) MIPI-GMSL CSI cameras, supporting multiple Camera sensor modules and serdes ODM/OEM implementations (e.g. Advantech,... )

## Supported Sensors

| Sensor Name     |Sensor Type  |Serializer Type |Deserializer Type | Vendor          | Kernel Version     | IPU Version         |
|-----------------|-------------|----------------|------------------|-----------------|--------------------|---------------------|
| AR0233          | GMSL        | max9295        | max9296/max96724 | Sensing         | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |
| AR0820          | GMSL        | max9295        | max9296/max96724 | Sensing         | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |
| ISX031          | GMSL        | max9295        | max9296/max96724 | D3 Embedded     | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |
| ISX031          | GMSL        | max9295        | max9296/max96724 | Sensing         | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |
| ISX031          | GMSL        | max9295        | max9296/max96724 | Leopard Imaging | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |
| ISX031          | MIPI-direct | none           | none             | D3 Embedded     | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |
| AR0234          | MIPI-direct | none           | none             | D3 Embedded     | K6.12/K6.17/K6.18  | IPU6EPMTL/IPU7PTL   |

> **Note:** IPU6EPMTL represents Intel Core Ultra Series 1 and 2 (aka. MTL and ARL) platforms, IPU7PTL represents Intel Core Ultra Series 3 (aka. PTL) platforms.

## Directory Structure

- `drivers/`: Host Linux kernel drivers for supported sensors
- `config/`: Host Middleware Configuration files, BIOS setting and sample commands for supported sensors
- `doc/`: Documentation on Kernel Driver dependency on ipu6-drivers repository
- `patch/`: Host Dependent Kernel patches to enable specific sensors
- `include/`: Header files for driver compilation
- `patches/`: DKMS Dependent out-of-tree patchset for V4L2-core, IPU6 and IPU7 ISYS amd PSYS kernel modules build
- `helpers/`: Various helpers IPU6/IPU7 ISYS, serdes and sensor scripts for binding GMSL v4l2 subdevices, udev rules, modprobe.d .conf, ... 

## Getting Started with Debian Linux MIPI-GMSL2 Reference Camera

1. Clone this repository and checkout to your desired release tag :

```bash
export $HOME=$(pwd)
cd $HOME
git clone --recurse-submodules https://github.com/intel/Intel-MIPI-CSI-Camera-Reference-Driver.git intel-mipi-gmsl-drivers
cd intel-mipi-gmsl-drivers
git checkout <commit-id>
```

2. install debian helper dependencies and build Canonical/Ubuntu 24.04 or GNU/Debian 13 compatible package :

```bash
sudo apt install equivs devscripts linux-headers-$(uname -r)
mk-build-deps -i --host-arch amd64 --build-arch amd64 -t "apt-get -y -q -o Debug::pkgProblemResolver=yes --no-install-recommends --allow-downgrades" debian/control
dpkg-buildpackage
ls ../intel-mipi-gmsl*
```

> **Note:** this step should produce multiple debian files, especially `../intel-mipi-gmsl-dkms_20260112-0eci1_amd64.deb` , `../intel-mipi-gmsl-drivers_20260112-0eci1.tar.gz`, `../intel-mipi-gmsl-drivers_20260112-0eci1_amd64.buildinfo`, `../intel-mipi-gmsl-drivers_20260112-0eci1_amd64.changes`, `../intel-mipi-gmsl-drivers_20260112-0eci1.dsc`. 

3. Install & Build everything at once e.g. Intel IPU6/IPU7 PSYS and ISYS, GMSL2 Serdes and Camera Sensor : 

```bash
sudo apt install ../intel-mipi-gmsl-dkms_20260112-0eci1_amd64.deb
```

4. Check dkms modules versioning, modprobe.d configuration before loading the IPU ISYS kernel modules :

```bash
modinfo intel-ipu6-isys
modprobe --show-depends intel-ipu6-isys
modprobe intel-ipu6-isys
```

> **Note:** all modules version should match the package version as well as dependencies with `ipu-acpi` kernel modules.

5. Leverage helper scripts to bind v4l2 media pipeline for each individual sensors modules (Refer to `doc/\<sensor\>/acpi-ipu-pdata.md` to configure ACPI Camera PDATA from BIOS/UEFI menu). For example below the v4l2 media pipeline binding from any ISX031 GMSL sub-devices to IPU ISYS video capture devices: 

```bash
/usr/share/camera/ipu_max9x_bind.sh -s isx031
```
> **Note:**  ipu6 and ipu7 MIPI CSI2, as well as max9x Serializer and Deserializer, requires `v4l-utils (>=1.30)` to  set v4l2 subdevice streams and routes.
The easiest way consist of downloading the latest Canonical Ubuntu `v4l-utils` package or rebuild once and install locally `v4l2-ctl 1.32.0` as followed :

```bash
cd $HOME
git clone https://git.launchpad.net/ubuntu/+source/v4l-utils
mk-build-deps -i --host-arch amd64 --build-arch amd64 -t "apt-get -y -q -o Debug::pkgProblemResolver=yes --no-install-recommends --allow-downgrades" debian/control
echo 1.0 > debian/source/format
dpkg-buildpackage
apt install ../v4l-utils_1.32.0-2ubuntu1_amd64.deb ../libv4l-0t64_1.32.0-2ubuntu1_amd64.deb ../libv4l2rds0t64_1.32.0-2ubuntu1_amd64.deb  ../libv4lconvert0t64_1.32.0-2ubuntu1_amd64.deb
v4l2-ctl --version
```
6. Final sanity-check if the v4l2 camera video streaming functional.

```bash
v4l2-ctl -d /dev/video-isx031-a-0 --set-fmt-video=width=1920,height=1536,pixelformat=UYVY && v4l2-ctl -d /dev/video-isx031-a-0 --stream-mmap
```

## Getting Started with Linux "BKC-image" Reference Camera

1. Install Intel BKC image:
   - Go to rdc.intel.com
        - Download IPU Master Collateral (Document #817101)
   - In Document #817101
        - Go to **Linux Getting Started Guide (GSG) Documentation** section
        - Search for your platform under **Platform** column
        - Click on **Getting Started Guide** link under **BSP** column
   - Download Platform Getting Started Guide (GSG) based on your platform (e.g., MTL, ARL)
   - In Platform GSG
        - Go to **Getting Started with Ubuntu\* with Kernel Overlay** section
        - Follow steps to install Intel Kernel Overlay and Userspace packages

2. Clone this repository and checkout to your desired release tag
```bash
export $HOME=$(pwd)
cd $HOME
git clone https://github.com/intel/Intel-MIPI-CSI-Camera-Reference-Driver.git
cd Intel-MIPI-CSI-Camera-Reference-Driver
git checkout <release-tag>
```

3. Clone ipu repositories and checkout to below commits
```bash
cd $HOME
git clone -b iotg_ipu6 https://github.com/intel/ipu6-camera-bins.git
cd ipu6-camera-bins
git checkout 0b102acf2d95f86ec85f0299e0dc779af5fdfb81

cd $HOME
git clone -b iotg_ipu6 https://github.com/intel/ipu6-camera-hal.git
cd ipu6-camera-hal
git checkout a647a0a0c660c1e43b00ae9e06c0a74428120f3a

cd $HOME
git clone -b icmaerasrc_slim_api https://github.com/intel/icamerasrc.git
cd icamerasrc
git checkout 4fb31db76b618aae72184c59314b839dedb42689

cd $HOME
git clone -b iotg_ipu6 https://github.com/intel/ipu6-drivers.git
cd ipu6-drivers
git checkout 71e2e426f3e16f8bc42bf2f88a21fa95eeca5923
```

4. Deploy and build IPU userspace components
```bash
# ipu6-camera-bins: Deploy files using below steps:
# Runtime Files
mkdir -p /lib/firmware/intel/ipu
sudo cp -r $HOME/ipu6-camera-bins/lib/lib* /usr/lib/
sudo cp -r $HOME/ipu6-camera-bins/lib/firmware/intel/ipu/*.bin /lib/firmware/intel/ipu

# Development files
mkdir -p /usr/include /usr/lib/pkgconfig
sudo cp -r $HOME/ipu6-camera-bins/include/* /usr/include/
sudo cp -r $HOME/ipu6-camera-bins/lib/pkgconfig/* /usr/lib/pkgconfig/

for lib in $HOME/ipu6-camera-bins/lib/lib*.so.*; do \
  lib=${lib##*/}; \
  sudo ln -s $lib /usr/lib/${lib%.*}; \
done

# ipu6-camera-hal and icamerasrc: Build using below steps:
# Make sure ipu6-camera-hal & icamerasrc are both in same directory, i.e. $HOME.
cd $HOME
cp $HOME/ipu6-camera-hal/build.sh .
# To build IPU6EPMTL with DMA (recommended)
./build.sh -d --board ipu_mtl

# To build IPU6EPMTL without DMA
./build.sh --board ipu_mtl

# Install built libraries to Target
sudo cp -r $HOME/out/<target>/install/etc/* /etc/
sudo cp -r $HOME/out/<target>/install/usr/include/* /usr/include/
sudo cp -r $HOME/out/<target>/install/usr/lib/* /usr/lib/
```

5. (optional) Setup media-ctl to Version 1.30 for debugging
```bash
# Install dependencies
sudo apt-get install debhelper doxygen gcc git graphviz libasound2-dev libjpeg-dev libqt5opengl5-dev libudev-dev libx11-dev meson pkg-config qtbase5-dev udev libsdl2-dev libbpf-dev llvm clang libjson-c-dev

# Build and install v4l-utils 1.30
git clone https://github.com/gjasny/v4l-utils.git -b stable-1.30
cd v4l-utils
meson build/
sudo ninja -C build/ install
```

6. (If needed) Refer to `doc/\<sensor\>/kernelspace.md`, if there are dependency patches to enable the sensor, apply the patch to **ipu6-drivers**.
```bash
cd $HOME/ipu6-drivers
git am $HOME/Intel-MIPI-CSI-Camera-Reference-Driver/.../XXX.patch
```

7. Dkms build ipu6-drivers
```bash
cd $HOME/ipu6-drivers
sudo dkms add .
sudo dkms build -m ipu6-drivers -v 0.0.0
sudo dkms install -m ipu6-drivers -v 0.0.0
```

8. Dkms build this repository
```bash
cd $HOME/Intel-MIPI-CSI-Camera-Reference-Driver
sudo dkms add .
sudo dkms build -m ipu-camera-sensor -v 0.1
sudo dkms install -m ipu-camera-sensor -v 0.1
```

9. Power off Board. Connect Sensor Hardware. Power On Board and Sensor.

10. Boot into BIOS menu. Configure BIOS option according to config/\<sensor\>/userspace-\<interface\>.md, 
    - Follow Section **BIOS Configuration Table**
        - **\<IPU VERSION\> Camera Option** and/or 
        - **\<IPU VERSION\> Control Logic**

    For example, for ISX031 GMSL on K6.12 IPU6EPMTL platform:
    - Follow `config/isx031/userspace-gmsl.md`
        - Follow **BIOS Configuration Table** >> **IPU6EPMTL Camera Option**

11. Boot into OS. Check if sensor is enumerated correctly in media-ctl
    - If sensor is not listed, re-check hardware connection and BIOS configuration
    - If issue persists, refer to Intel IPU Team for support.
```bash
media-ctl -p | grep -ie <sensor>
```

12. Setup XML file according to config/\<sensor\>/userspace-\<interface\>.md,
    - Follow Section **Camera XML File Setup**
        - **\<IPU VERSION\> Configuration**

    For example, for ISX031 GMSL on K6.12 IPU6EPMTL platform:
    - Follow `config/isx031/userspace-gmsl.md`
        - Follow **Camera XML File Setup** >> **IPU6EPMTL Configuration** section

13. Export below environment variables or add to shell profile (e.g., `~/.bashrc` )
```bash
export DISPLAY=:0; xhost +
export GST_PLUGIN_PATH=/usr/lib/gstreamer-1.0
export LIBVA_DRIVER_NAME=iHD
export GST_GL_API=gles2
export GST_GL_PLATFORM=egl
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig
export LD_LIBRARY_PATH=/usr/local/lib/pkgconfig:/usr/local/lib:/usr/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu
export logSink=terminal
rm -rf ~/.cache/gstreamer-1.0
```

14. Run Gstreamer command according to config/\<sensor\>/userspace-\<interface\>.md,
    - Follow Section **Sample Userspace Command**
        - Copy and run command based on your use case. 

    For example, for 1x ISX031 GMSL on K6.12 IPU6EPMTL platform:
    - Follow `config/isx031/userspace-gmsl.md`
        - Follow **Sample Userspace Command** >> **Number of Stream (Single Stream / Multi Stream) Selection** >> command for x1 stream

15. Enjoy your camera stream!

## Documentation

Detailed documentation for each sensor can be found in the `doc/` directory, organized by sensor model.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## Security

For security concerns, please see [SECURITY.md](SECURITY.md).

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md).
