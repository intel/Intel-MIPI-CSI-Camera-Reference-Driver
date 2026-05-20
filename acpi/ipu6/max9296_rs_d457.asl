/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SSDT overlay: RealSense D457 GMSL camera configuration with two MAX9296A
 * deserializers on IPU6EPMTL platform.
 *   DES0 (DPHY, MIPI port 0) carries:
 *     - Link 0: RS D457 (MAX9295A SER @ 0x40)
 *     - Link 1: RS D457 (MAX9295A SER @ 0x40)
 *   DES1 (DPHY, MIPI port 4) carries:
 *     - Link 0: RS D457 (MAX9295A SER @ 0x40)
 *     - Link 1: RS D457 (MAX9295A SER @ 0x40)
 *
 * DES-level defines (set per DESx, undef'd at the end of each Device):
 *   DES_PHY_TYPE       - DES PHY type (0 for CPHY, 1 for DPHY)
 *   DES_I2C_ADDR       - DES I2C slave address (e.g. 0x0048 for MAX9296A)
 *   DES_INTERNAL_PHY   - DES internal PHY index (MAX9296A: 1 or 2)
 *   DES_TO_MIPI_PORT   - DES connected to IPU0 MIPI port (e.g. 0/1/2/3)
 *   DES_I2C_BUS        - DES I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   DES_PATH           - DES ACPI path string (e.g. "\\_SB.PC00.DES0")
 *   DES_REF            - DES ACPI namespace reference (e.g. \_SB.PC00.DES0)
 *
 * Channel-level defines (set per CHxx, undef'd by _des_ch_common_d457.asl):
 *   DESCH_LINK_NUM     - Channel/link number (0..1 for MAX9296A)
 *   DESCH_CH           - Channel device name (e.g. CH00)
 *   DESCH_SER          - Serializer device name (e.g. SER0)
 *   DESCH_CAM          - Camera device name (e.g. CAM0)
 *   DESCH_SER_I2C      - SER I2C slave address (e.g. 0x40 for MAX9295A)
 *   DESCH_CH_PATH      - CHxx ACPI path string
 *   DESCH_SER_PATH     - SERx ACPI path string
 *   DESCH_SER_REF      - SERx ACPI namespace reference
 *   DESCH_SER_GPIOREF  - SERx GPIO controller reference (e.g. ^^SER0)
 *   CAM_ALIAS          - Camera alias I2C address in i2c-alias-pool of the SER
 *   CAM_LANES          - Number of MIPI data lanes for the camera (e.g. 2, 4)
 *   DESCH_SER_X_VC     - D457: X-stream virtual channel mapping
 *   DESCH_SER_Y_VC     - D457: Y-stream virtual channel mapping
 *   DESCH_SER_Z_VC     - D457: Z-stream virtual channel mapping
 *   DESCH_SER_U_VC     - D457: U-stream virtual channel mapping
 */

DefinitionBlock ("", "SSDT", 2, "", "IMG_IPU", 0x20260513)
{
    External (_SB.PC00, DeviceObj)

    Include ("_ipu.asl")

    Scope (\_SB.PC00)
    {
        Device (DES0)
        {
            // DES-level defines for DES0
            #define DES_PHY_TYPE 1
            #define DES_I2C_ADDR 0x0048
            #define DES_LANES 4
            #define DES_INTERNAL_PHY 2
            #define DES_TO_MIPI_PORT 0
            #define DES_I2C_BUS "\\_SB.PC00.I2C1"
            #define DES_PATH "\\_SB.PC00.DES0"
            #define DES_REF \_SB.PC00.DES0
            #include "_des_common_max9296.asl"

            // Channel 0 (RS D457)
            #define DESCH_LINK_NUM 0
            #define DESCH_CH CH00
            #define DESCH_SER SER0
            #define DESCH_CAM CAM0
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH00"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH00.SER0"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH00.SER0
            #define DESCH_SER_GPIOREF ^^SER0
            #define CAM_ALIAS 0x54
            #define CAM_LANES 2
            #define DESCH_SER_X_VC Package () { 0 }
            #define DESCH_SER_Y_VC Package () { 1 }
            #define DESCH_SER_Z_VC Package () { 2 }
            #define DESCH_SER_U_VC Package () { 3 }
            #include "_des_ch_common_d457.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
            #undef CAM_ALIAS
            #undef CAM_LANES
            #undef DESCH_SER_X_VC
            #undef DESCH_SER_Y_VC
            #undef DESCH_SER_Z_VC
            #undef DESCH_SER_U_VC
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_CAM_FSIN_GPIO
            #undef DESCH_CAM_FSIN_GPIO
#endif

            // Channel 1 (RS D457)
            #define DESCH_LINK_NUM 1
            #define DESCH_CH CH01
            #define DESCH_SER SER1
            #define DESCH_CAM CAM1
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH01"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH01.SER1"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH01.SER1
            #define DESCH_SER_GPIOREF ^^SER1
            #define CAM_ALIAS 0x55
            #define CAM_LANES 2
            #define DESCH_SER_X_VC Package () { 0 }
            #define DESCH_SER_Y_VC Package () { 1 }
            #define DESCH_SER_Z_VC Package () { 2 }
            #define DESCH_SER_U_VC Package () { 3 }
            #include "_des_ch_common_d457.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
            #undef CAM_ALIAS
            #undef CAM_LANES
            #undef DESCH_SER_X_VC
            #undef DESCH_SER_Y_VC
            #undef DESCH_SER_Z_VC
            #undef DESCH_SER_U_VC
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_CAM_FSIN_GPIO
            #undef DESCH_CAM_FSIN_GPIO
#endif

            // Clean up DES0-level defines
            #undef DES_PHY_TYPE
            #undef DES_I2C_ADDR
            #undef DES_LANES
            #undef DES_INTERNAL_PHY
            #undef DES_TO_MIPI_PORT
            #undef DES_I2C_BUS
            #undef DES_PATH
            #undef DES_REF
        }

        Device (DES1)
        {
            // DES-level defines for DES1
            #define DES_PHY_TYPE 1
            #define DES_I2C_ADDR 0x0048
            #define DES_LANES 4
            #define DES_INTERNAL_PHY 2
            #define DES_TO_MIPI_PORT 4
            #define DES_I2C_BUS "\\_SB.PC00.I2C0"
            #define DES_PATH "\\_SB.PC00.DES1"
            #define DES_REF \_SB.PC00.DES1
            #include "_des_common_max9296.asl"

            // Channel 0 (RS D457)
            #define DESCH_LINK_NUM 0
            #define DESCH_CH CH00
            #define DESCH_SER SER0
            #define DESCH_CAM CAM0
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH00"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH00.SER0"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH00.SER0
            #define DESCH_SER_GPIOREF ^^SER0
            #define CAM_ALIAS 0x54
            #define CAM_LANES 2
            #define DESCH_SER_X_VC Package () { 0 }
            #define DESCH_SER_Y_VC Package () { 1 }
            #define DESCH_SER_Z_VC Package () { 2 }
            #define DESCH_SER_U_VC Package () { 3 }
            #include "_des_ch_common_d457.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
            #undef CAM_ALIAS
            #undef CAM_LANES
            #undef DESCH_SER_X_VC
            #undef DESCH_SER_Y_VC
            #undef DESCH_SER_Z_VC
            #undef DESCH_SER_U_VC
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_CAM_FSIN_GPIO
            #undef DESCH_CAM_FSIN_GPIO
#endif

            // Channel 1 (RS D457)
            #define DESCH_LINK_NUM 1
            #define DESCH_CH CH01
            #define DESCH_SER SER1
            #define DESCH_CAM CAM1
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH01"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH01.SER1"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH01.SER1
            #define DESCH_SER_GPIOREF ^^SER1
            #define CAM_ALIAS 0x55
            #define CAM_LANES 2
            #define DESCH_SER_X_VC Package () { 0 }
            #define DESCH_SER_Y_VC Package () { 1 }
            #define DESCH_SER_Z_VC Package () { 2 }
            #define DESCH_SER_U_VC Package () { 3 }
            #include "_des_ch_common_d457.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
            #undef CAM_ALIAS
            #undef CAM_LANES
            #undef DESCH_SER_X_VC
            #undef DESCH_SER_Y_VC
            #undef DESCH_SER_Z_VC
            #undef DESCH_SER_U_VC
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_CAM_FSIN_GPIO
            #undef DESCH_CAM_FSIN_GPIO
#endif

            // Clean up DES1-level defines
            #undef DES_PHY_TYPE
            #undef DES_I2C_ADDR
            #undef DES_LANES
            #undef DES_INTERNAL_PHY
            #undef DES_TO_MIPI_PORT
            #undef DES_I2C_BUS
            #undef DES_PATH
            #undef DES_REF
        }
    }
}
