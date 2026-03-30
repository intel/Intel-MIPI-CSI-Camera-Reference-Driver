# Intel MIPI CSI Camera Reference Driver

This repository contains reference drivers and configurations for Intel MIPI CSI cameras, supporting various sensor modules and Image Processing Units (IPUs).

## Directory Structure

- `6.xx.0/`: Kernel Dependent upstream/unpatched v4l2-core API codebase
- `drivers/`: Host Linux kernel drivers for supported sensors
- `helpers/`: v4l2 utils helpers script and udev to easily create gmsl camera media pipeline
- `config/`: Host Middleware Configuration files, BIOS setting and sample commands for supported sensors
- `doc/`: Documentation on Kernel Driver dependency on ipu6-drivers repository
- `patches/`: Host Dependent IPU v4l2 patches to enable specific sensors
- `include/`: Header files for driver compilation

## Getting Developper Started with Reference GMSL Camera

1. Clone this repository and checkout debian dev branch

```
export $HOME=$(pwd)
cd $HOME
git clone --recursive https://github.com/Pirouf/Intel-mipi-gmsl-modules.git -b 20260211/Q1.1.1a-d4xx-max9672x intel-mipi-gmsl-drivers-debian-20260211
```

2. Create origin debian source archive

```
tar czvf intel-mipi-gmsl-drivers_20260211.orig.tar.gz --exclude=".git" --exclude=".gitignore" --exclude=".gitmodules" --exclude="debian"  --exclude=".pc" intel-mipi-gmsl-drivers-debian-20260211
```

3. Install debian package dependencies (if done once already, you can skip it)

```
sudo apt install devscripts
cd $HOME/intel-mipi-gmsl-drivers-debian-20260211
mk-build-deps -i --host-arch amd64 --build-arch amd64 -t "apt-get -y -q -o Debug::pkgProblemResolver=yes --no-install-recommends --allow-downgrades" debian/control
rm *.buildinfo *.changes *.deb
dpkg-buildpackage
```

4. Stitch the `0001-media-ctl-add-pad-support-2-digits-stream-id.patch` fix/workaround for `media-ctl` 1-digit stream-id limitation onto Debian latest `v4l-utils` v1.32 stable

```
cd $HOME
git clone https://salsa.debian.org/debian/libv4l.git -b debian/1.32.0-2
cd $HOME/libv4l
mk-build-deps -i --host-arch amd64 --build-arch amd64 -t "apt-get -y -q -o Debug::pkgProblemResolver=yes --no-install-recommends --allow-downgrades" debian/control
rm *.buildinfo *.changes *.deb
export QUILT_PATCHES=debian/patches
export QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
quilt pop -af || true
quilt import -f -d n ${HOME}/intel-mipi-gmsl-drivers-debian-20260211/patches/libv4l/0001-media-ctl-add-pad-support-2-digits-stream-id.patch
quilt push -a
dpkg-buildpackage
```

5. Install local dkms and v4l-utils debian packages

```
cd $HOME
sudo apt install ./intel-mipi-gmsl-dkms_20260211-1_amd64.deb ./v4l-utils_1.32.0-2_amd64.deb ./libv4l*_1.32.0-2_amd64.deb
```
6. Select max929x or max967xx deserializer to compile certain linux v4l2 i2c sensors driver with.

7. Reboot in UEFI/BIOS menu, to enable Intel IPU in and configure Camera ACPI PDATA i2c and CSI2 controls under

```
systemctl reboot --firmware-setup

```

Select `Intel Advanced Menu -> System Agent (SA) Configuration  -> MIPI Camera Configuration  -> < Enable >`.
Configure each Camera ACPI device individually `Intel Advanced Menu -> System Agent (SA) Configuration -> MIPI Camera Configuration -> Link Options`.
Select `Intel Advanced Menu -> System Agent (SA) Configuration -> MIPI Camera Configuration -> Link Options -> User Custom`.

For example Realsense D457 on IPU7 (Intel Core Ultra 3 - Panther Lake) - one ACPI entry each D457 Cameras

| UEFI Custom Sensor (D457)                | Camera 1   | Camera 2  | Camera 3   | Camera 4   |
|------------------------------------------|------------|-----------|------------|------------|
| GMSL deserializer suffix                 | c          | c         | c          | c          |
| Custom HID                               | INTC10CD   | INTC10CD  | INTC10CD   | INTC10CD   |
| CSI bus-type                             | CPHY       | CPHY      | CPHY       | CPHY       |
| Rotation (d4xx deserializer input-link)  | 0          | 90        | 180        | 270        |
| PPR Value (deserializer # of lanes)      | 2          | 2         | 2          | 2          |
| PPR Unit (# of Cameras per-device)       | 1          | 1         | 1          | 1          |
| Camera module label                      | d4xx       | d4xx      | d4xx       | d4xx       |
| MIPI Port (Index)                        | 2          | 2         | 2          | 2          |
| LaneUsed (serializer # of lanes)         | x2         | x2        | x2         | x2         |
| Number of I2C                            | 3          | 3         | 3          | 3          |
| I2C Channel                              | I2C2       | I2C2      | I2C2       | I2C2       |
| Device0 I2C Address (sensor)             | 12         | 13        | 14         | 15         |
| Device1 I2C Address (serializer)         | 42         | 43        | 44         | 45         |
| Device2 I2C Address (deserializer)       | 27         | 27        | 27         | 27         |

Note: Using `INTC10CD` HID, the `Rotation` selection defines `d4xx-max96724` deserializer input-link mapping: GMSL A (`Rotation=0`) or GMSL B (`Rotation=90`) or GMSL C (`Rotation=180`) or D (`Rotation=270`)

For example  d3embedded ISX031 GMSL modules on IPU7 (Intel Core Ultra 3 - Panther Lake) - only one ACPI entry for all 4 ISX031 Cameras

| UEFI Custom Sensor (ISX031)              | Camera 1   |
|------------------------------------------|------------|
| GMSL deserializer suffix                 | c          |
| Custom HID                               | INTC031M   |
| CSI bus-type                             | CPHY       |
| Rotation (max9x deserializer out-link)   | 180        |
| PPR Value (deserializer # of lanes)      | 2          |
| PPR Unit (# of Cameras per-device)       | 4          |
| Camera module label                      | d4xx       |
| MIPI Port (Index)                        | 2          |
| LaneUsed (serializer # of lanes)         | x4         |
| Number of I2C                            | 3          |
| I2C Channel                              | I2C2       |
| Device0 I2C Address (deserilizer)        | 27         |
| Device1 I2C Address (serializer)         | 42         |
| Device2 I2C Address (sensor)             | 12         |

Note: Using `INTC031M` HID, the `Rotation` selection defines `d4xx-max96724` deserializer output-link mapping: CSI PHY A (`Rotation=0`) or CSI PHY C (`Rotation=180`)

8. User to need to double check and edit `modprobe.d` module config file if necessary to configure it for `max9296` or `max967xx` add-on board

For example of 4x Realsense D457 on IPU7 (Intel Core Ultra 3 - Panther Lake)

```
# modinfo d4xx
filename:       /lib/modules/6.17.0-1010-oem/updates/dkms/d4xx.ko.zst
version:        20260211-0eci1
license:        GPL v2
author:         Guennadi Liakhovetski <guennadi.liakhovetski@intel.com>,
                                Nael Masalha <nael.masalha@intel.com>,
                                Alexander Gantman <alexander.gantman@intel.com>,
                                Emil Jahshan <emil.jahshan@intel.com>,
                                Xin Zhang <xin.x.zhang@intel.com>,
                                Qingwu Zhang <qingwu.zhang@intel.com>,
                                Evgeni Raikhel <evgeni.raikhel@intel.com>,
                                Shikun Ding <shikun.ding@intel.com>,
                                Florent Pirou <florent.pirou@intel.com>,
                                Dmitry Perchanov <dmitry.perchanov@intel.com>
description:    RealSense D4XX Camera Driver
srcversion:     B6A9500EDADC591780A52F9
alias:          i2c:d4xx-awg
alias:          i2c:d4xx-asr
alias:          i2c:d4xx
alias:          of:N*T*Cintel,d4xxC*
alias:          of:N*T*Cintel,d4xx
depends:        d4xx-max9295,d4xx-max96724,v4l2-async,videodev,mc
name:           d4xx
retpoline:      Y
vermagic:       6.17.0-1010-oem SMP preempt mod_unload modversions
sig_id:         PKCS#7
signer:         eci-rvp-ptl-gmsl-4 Secure Boot Module Signature key
sig_key:        1F:18:1B:36:4E:5E:1C:D9:C7:D9:7D:AB:F2:A6:78:C8:A5:07:8F:A5
sig_hashalgo:   sha512
signature:      24:9D:08:A3:72:A4:97:CF:F1:B5:47:B3:A3:07:88:7F:0B:1B:66:FD:
                7F:A8:AD:02:A9:A8:BB:EC:B5:AE:AB:6E:A2:F2:5C:8A:E6:E2:68:97:
                BA:A2:CA:53:00:54:B6:44:4D:FF:CE:80:ED:4D:BE:16:2D:DF:C0:65:
                1B:DD:D0:24:E6:B6:1E:06:06:C3:A1:87:92:2F:E4:8E:AE:C7:88:12:
                C0:1B:6A:B6:A4:6B:5D:A9:A5:B3:57:61:38:1A:E1:05:FB:4A:E3:A3:
                8F:26:C3:EC:2C:3C:2F:04:EA:96:CE:3A:8D:D0:F5:8F:64:0F:5E:49:
                A3:03:5F:B6:40:E0:37:9C:E6:12:92:34:AE:53:6B:38:74:6E:8B:D9:
                EA:B4:AA:EE:50:21:41:84:4E:51:9E:0A:B7:5E:40:D3:82:A2:8E:92:
                2E:86:35:31:AE:64:AC:8C:4A:27:FF:F5:81:FB:D8:EC:7C:E2:87:11:
                D7:E9:23:FB:A2:BE:E2:75:CC:AC:58:2F:67:38:BE:61:C6:64:FF:5E:
                1A:EF:E3:35:F9:3D:96:CF:CC:71:08:F1:5A:BD:50:FD:A4:2F:C0:30:
                99:E2:85:11:BD:5F:D9:07:A9:BA:AE:6B:20:78:16:AE:F3:DE:97:5A:
                7A:4B:E4:EB:28:BF:94:BE:AE:E4:26:6A:18:54:84:AE
parm:           sensor_vc:VC set for sensors
                sensor_vc=0,1,2,3,2,3,0,1,1,0,3,2,3,2,1,0 (array of ushort)
parm:           serdes_bus:d4xx-max96724 deserializer i2c bus
                serdes_bus=0,0,1,1 (array of ushort)
parm:           des_addr:d4xx-max96724 deserializer i2c address
                des_addr=0x27,0x27,0x27,0x27 (array of ushort)
parm:           des_csi:d4xx-max96724 deserializer csi output
                des_csi=0,2,0,2 (array of ushort)

```

```
# uncomment d4xx driver boot options corresponding to your Intel platform
#
# MTL GMSL2 AIC max9296 device generally on i2c-2 and i2c-3 buses
#options d4xx des_addr=0x48,0x4a,0x48,0x4a serdes_bus=2,2,3,3
# ARL GMSL2 AIC max9296 device generally on i2c-0 and i2c-3  buses
#options d4xx des_addr=0x48,0x4a,0x48,0x4a serdes_bus=0,0,3,3
# ADL/RPL/ASL GMSL2 AIC max9296 device generally on i2c-4 bus
#options d4xx des_addr=0x48,0x4a,0x68,0x6c serdes_bus=4,4,4,4
# ARL GMSL2 AIC dual-max96712 device generally on i2c-0 bus
#options d4xx des_addr=0x6b,0x6b,0x29,0x29 serdes_bus=0,0,0,0

# PTL GMSL2 AIC dual-max96724 device generally on i2c-0 and i2c-1 buses
options d4xx des_addr=0x27,0x27,0x27,0x27 serdes_bus=0,0,1,1 des_csi=0,0,2,2
# !!WARNING!! Intel Servoss Mountain 1.0 (Fab A) dual-max96724 board cphy CRD connectivity is inverted
# max96724 csi 0 CPHY-2T DA0/DA1 maps to ipu7 isys csi 2
# max96724 csi 2 CPHY-2T DB0/DB1 maps to ipu7 isys csi 0
#options d4xx des_addr=0x27,0x27,0x27,0x27 serdes_bus=1,1,2,2 des_csi=2,2,0,0
#

#options d4xx dyndbg
#options d4xx-max9295 dyndbg
#options d4xx-max9296 dyndbg
#options d4xx-max96724 dyndbg

```

```
modprobe --show-depends d4xx
insmod /lib/modules/6.17.0-1010-oem/kernel/drivers/media/mc/mc.ko.zst
insmod /lib/modules/6.17.0-1010-oem/updates/dkms/videodev.ko.zst
insmod /lib/modules/6.17.0-1010-oem/kernel/drivers/media/v4l2-core/v4l2-async.ko.zst
insmod /lib/modules/6.17.0-1010-oem/updates/dkms/d4xx-max96724.ko.zst dyndbg
insmod /lib/modules/6.17.0-1010-oem/updates/dkms/d4xx-max9295.ko.zst
insmod /lib/modules/6.17.0-1010-oem/updates/dkms/d4xx.ko.zst des_addr=0x27,0x27,0x27,0x27 serdes_bus=0,0,1,1 des_csi=0,0,2,2

```

For example of 4x D3 ISX031

```
modinfo isx031
filename:       /lib/modules/6.17.0-1010-oem/updates/dkms/isx031.ko.zst
license:        GPL v2
author:         Wei Khang, Goh <wei.khang1.goh@intel.com>
author:         Jonathan Lui <jonathan.ming.jun.lui@intel.com>
author:         Hao Yao <hao.yao@intel.com>
description:    isx031 sensor driver
srcversion:     12A145D4C2F70B04B1E8D25
alias:          i2c:isx031
alias:          acpi*:INTC113C:*
depends:        videodev,mc,v4l2-fwnode,v4l2-async
name:           isx031
retpoline:      Y
vermagic:       6.17.0-1010-oem SMP preempt mod_unload modversions
sig_id:         PKCS#7
signer:         eci-rvp-ptl-gmsl-4 Secure Boot Module Signature key
sig_key:        1F:18:1B:36:4E:5E:1C:D9:C7:D9:7D:AB:F2:A6:78:C8:A5:07:8F:A5
sig_hashalgo:   sha512
signature:      57:81:3B:A6:5C:99:C4:26:46:7D:32:A0:5C:49:4D:8A:31:1B:EA:E1:
                51:A5:B6:CF:2A:8D:F7:AD:8E:F3:01:F2:D3:1E:8E:3F:32:69:FF:59:
                40:27:13:98:56:2F:72:AD:8E:F5:52:FC:91:CB:68:81:A2:9C:DE:23:
                08:9F:51:DB:4D:16:B6:FD:2F:E4:DC:EF:B3:76:59:3B:DF:4D:64:03:
                E1:20:9D:06:83:7F:94:3E:84:AA:47:57:F6:CA:58:24:89:72:42:9A:
                4B:9A:24:FF:BD:B5:17:78:D4:F3:B8:7F:18:0E:F8:33:62:D7:71:04:
                52:75:B8:B9:4D:2F:68:53:31:08:12:3E:D9:97:76:16:FA:1A:62:9C:
                00:ED:12:2E:B3:B7:4D:92:6A:DD:1D:74:20:4A:89:58:29:0A:C8:8A:
                01:89:32:15:55:3C:38:94:71:F7:40:98:80:5D:15:28:E0:2B:8E:0B:
                E7:DD:E7:38:E6:A8:47:61:8D:25:66:A3:2A:FB:4A:45:46:3A:5E:EE:
                9B:9E:73:16:69:8A:31:90:D2:71:D0:BA:A5:94:79:C5:E1:59:12:4C:
                C0:8E:F6:76:2C:A5:B8:91:5F:B4:DA:21:53:F5:AF:87:CA:8F:67:A4:
                68:79:FC:22:8C:B9:96:F2:19:94:8D:42:30:25:BF:2C
```

```
modprobe --show-depends isx031
insmod /lib/modules/6.17.0-1010-oem/kernel/drivers/media/mc/mc.ko.zst
insmod /lib/modules/6.17.0-1010-oem/updates/dkms/videodev.ko.zst
insmod /lib/modules/6.17.0-1010-oem/kernel/drivers/media/v4l2-core/v4l2-async.ko.zst
insmod /lib/modules/6.17.0-1010-oem/kernel/drivers/media/v4l2-core/v4l2-fwnode.ko.zst
insmod /lib/modules/6.17.0-1010-oem/updates/dkms/isx031.ko.zst
```

9. load IPU ISYS module and bind ALL sensors as v4l2 media pipeline graph.

```
modprobe intel-ipu7-isys
```

For example of 4x D457 on IPU7 (Intel Core Ultra 3 - Panther Lake) - 

```
/usr/share/camera/rs_ipu_d457_bind.sh -n -q && /usr/share/camera/rs-enum-ipu.sh -n
(count=1 on IPU7 CSI 2)...
(count=2 on IPU7 CSI 2)...
(count=3 on IPU7 CSI 2)...
(count=4 on IPU7 CSI 2)...
Bus     Camera  Sensor  Node Type       Video Node      RS Link
 ipu7   a-2     ir      Inactive        /dev/video37    /dev/video-rs-ir-8
 ipu7   a-2     depth   Stream(id=0)    /dev/video33    /dev/video-rs-depth-8
 ipu7   a-2     imu     Inactive        /dev/video38    /dev/video-rs-imu-8
 ipu7   a-2     color   Stream(id=2)    /dev/video35    /dev/video-rs-color-8
 i2c    a-2     d4xx    Firmware        /dev/d4xx-dfu-a-2       /dev/d4xx-dfu-8
 ipu7   b-2     ir      Inactive        /dev/video43    /dev/video-rs-ir-9
 ipu7   b-2     depth   Stream(id=6)    /dev/video39    /dev/video-rs-depth-9
 ipu7   b-2     imu     Inactive        /dev/video44    /dev/video-rs-imu-9
 ipu7   b-2     color   Stream(id=8)    /dev/video41    /dev/video-rs-color-9
 i2c    b-2     d4xx    Firmware        /dev/d4xx-dfu-b-2       /dev/d4xx-dfu-9
 ipu7   c-2     ir      Inactive        /dev/video45    /dev/video-rs-ir-10
 ipu7   c-2     depth   Stream(id=1)    /dev/video34    /dev/video-rs-depth-10
 ipu7   c-2     imu     Inactive        /dev/video46    /dev/video-rs-imu-10
 ipu7   c-2     color   Stream(id=3)    /dev/video36    /dev/video-rs-color-10
 i2c    c-2     d4xx    Firmware        /dev/d4xx-dfu-c-2       /dev/d4xx-dfu-10
 ipu7   d-2     ir      Inactive        /dev/video47    /dev/video-rs-ir-11
 ipu7   d-2     depth   Stream(id=7)    /dev/video40    /dev/video-rs-depth-11
 ipu7   d-2     imu     Inactive        /dev/video48    /dev/video-rs-imu-11
 ipu7   d-2     color   Stream(id=9)    /dev/video42    /dev/video-rs-color-11
 i2c    d-2     d4xx    Firmware        /dev/d4xx-dfu-d-2       /dev/d4xx-dfu-11
```
note: v4l2 limites to 8 streams/routes max per CSI ports has priortized depth+rgb

For example of selecting only 1-out-of-4 D457 on IPU7 (Intel Core Ultra 3 - Panther Lake)

```
# /usr/share/camera/rs_ipu_d457_bind.sh -n -m a-2 -q && /usr/share/camera/rs-enum-ipu.sh -n
(count=1 on IPU7 CSI 2)...
Bus     Camera  Sensor  Node Type       Video Node      RS Link
 ipu7   a-2     ir      Stream(id=4)    /dev/video37    /dev/video-rs-ir-8
 ipu7   a-2     depth   Stream(id=0)    /dev/video33    /dev/video-rs-depth-8
 ipu7   a-2     imu     Stream(id=5)    /dev/video38    /dev/video-rs-imu-8
 ipu7   a-2     color   Stream(id=2)    /dev/video35    /dev/video-rs-color-8
 i2c    a-2     d4xx    Firmware        /dev/d4xx-dfu-a-2       /dev/d4xx-dfu-8
```

For example of 4x D3embedded ISX031  on IPU7 (Intel Core Ultra 3 - Panther Lake)

```
./helpers/ipu_max9x_bind.sh -q -s isx031
Bind IPU7 to isx031 a-2 through max9x c  ..
Bind IPU7 to isx031 b-2 through max9x c  ..
Bind IPU7 to isx031 c-2 through max9x c  ..
Bind IPU7 to isx031 d-2 through max9x c  ..
```

10. Enjoy your GMSL cameras streaming on Intel IPU MIPI CSI2 ports!

For example 4x D457 on IPU7 (Intel Core Ultra 3 - Panther Lake) - 

```
rs-enumerate-devices -S
Device Name                   Serial Number       Firmware Version
Intel RealSense D457          241122303302        5.17.0.10
Intel RealSense D457          242422303692        5.17.0.10
Intel RealSense D457          242422304793        5.17.0.10
Intel RealSense D457          242422303456        5.17.0.10
Device info:
    Name                          :     Intel RealSense D457
    Serial Number                 :     241122303302
    Firmware Version              :     5.17.0.10
    Recommended Firmware Version  :     5.17.0.9
    Physical Port                 :     /dev/video-rs-depth-10
    Debug Op Code                 :     15
    Advanced Mode                 :     YES
    Product Id                    :     ABCD
    Camera Locked                 :     YES
    Product Line                  :     D400
    Asic Serial Number            :     321543110732
    Firmware Update Id            :     321543110732
    Dfu Device Path               :     /dev/d4xx-dfu-10
    Connection Type               :     GMSL

Device info:
    Name                          :     Intel RealSense D457
    Serial Number                 :     242422303692
    Firmware Version              :     5.17.0.10
    Recommended Firmware Version  :     5.17.0.9
    Physical Port                 :     /dev/video-rs-depth-11
    Debug Op Code                 :     15
    Advanced Mode                 :     YES
    Product Id                    :     ABCD
    Camera Locked                 :     YES
    Product Line                  :     D400
    Asic Serial Number            :     250343111497
    Firmware Update Id            :     250343111497
    Dfu Device Path               :     /dev/d4xx-dfu-11
    Connection Type               :     GMSL

Device info:
    Name                          :     Intel RealSense D457
    Serial Number                 :     242422304793
    Firmware Version              :     5.17.0.10
    Recommended Firmware Version  :     5.17.0.9
    Physical Port                 :     /dev/video-rs-depth-8
    Debug Op Code                 :     15
    Advanced Mode                 :     YES
    Product Id                    :     ABCD
    Camera Locked                 :     YES
    Product Line                  :     D400
    Asic Serial Number            :     252143110007
    Firmware Update Id            :     252143110007
    Dfu Device Path               :     /dev/d4xx-dfu-8
    Connection Type               :     GMSL

Device info:
    Name                          :     Intel RealSense D457
    Serial Number                 :     242422303456
    Firmware Version              :     5.17.0.10
    Recommended Firmware Version  :     5.17.0.9
    Physical Port                 :     /dev/video-rs-depth-9
    Debug Op Code                 :     15
    Advanced Mode                 :     YES
    Product Id                    :     ABCD
    Camera Locked                 :     YES
    Product Line                  :     D400
    Asic Serial Number            :     245543111541
    Firmware Update Id            :     245543111541
    Dfu Device Path               :     /dev/d4xx-dfu-9
    Connection Type               :     GMSL
```

or 

```
gst-launch-1.0 -e -v  \
v4l2src device=/dev/video-rs-color-8 ! 'video/x-raw, width=640, height=480, format=YUY2, pixel-aspect-ratio=1/1, framerate=30/1' !  comp.sink_0 \
v4l2src device=/dev/video-rs-color-9 ! 'video/x-raw, width=640, height=480, format=YUY2, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_1 \
v4l2src device=/dev/video-rs-color-10 ! 'video/x-raw, width=640, height=480, format=YUY2, pixel-aspect-ratio=1/1, framerate=30/1' !  comp.sink_2 \
v4l2src device=/dev/video-rs-color-11 ! 'video/x-raw, width=640, height=480, format=YUY2, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_3 \
compositor name=comp \
sink_0::xpos=0 sink_0::ypos=0 sink_0::width=640 sink_0::height=480 sink_0::zorder=1 \
sink_1::xpos=640 sink_1::ypos=0 sink_1::width=640 sink_1::height=480 sink_1::zorder=2 \
sink_2::xpos=0 sink_2::ypos=480 sink_0::width=640 sink_2::height=480 sink_2::zorder=3 \
sink_3::xpos=640 sink_3::ypos=480 sink_3::width=640 sink_3::height=480 sink_3::zorder=2 ! videoconvert ! fakesink
```

For example 4x D3embedded ISX031 GMSL modules on IPU7 (Intel Core Ultra 3 - Panther Lake)

```
gst-launch-1.0 -e -v \
v4l2src device=/dev/video-isx031-a-2 ! 'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' !  comp.sink_0 \
v4l2src device=/dev/video-isx031-b-2 ! 'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_1 \
v4l2src device=/dev/video-isx031-c-2 ! 'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_2 \
v4l2src device=/dev/video-isx031-d-2 ! 'video/x-raw, width=1920, height=1536, format=UYVY, pixel-aspect-ratio=1/1, framerate=30/1' ! comp.sink_3 \
compositor name=comp \
sink_0::xpos=0 sink_0::ypos=0 sink_0::width=1920 sink_0::height=1536 sink_0::zorder=1 \
sink_1::xpos=1920 sink_1::ypos=0 sink_1::width=1920 sink_1::height=1536 sink_1::zorder=2 \
sink_2::xpos=0 sink_2::ypos=1536 sink_2::width=1920 sink_2::height=1536 sink_2::zorder=3 \
sink_3::xpos=1920 sink_3::ypos=1536 sink_3::width=1920 sink_3::height=1536 sink_3::zorder=4 ! videoconvert ! fakesink

```

## Documentation

Detailed documentation for each sensor can be found in the [doc/](doc) directory, organized by sensor model.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## Security

For security concerns, please see [SECURITY.md](SECURITY.md).

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md).
