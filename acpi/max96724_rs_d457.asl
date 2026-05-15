/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SSDT overlay: D457 (D4xx) GMSL camera configuration on PTL platform.
 *   One MAX96724 deserializer (DES0) with CPHY connection to PTL platform,
 *   carrying D457 cameras over GMSL links, fronted by MAX9295A serializers. 
 *   Each D457 exposes four virtual channels (X/Y/Z/U) for its image streams.
 *
 * DES-level defines (set per DESx, undef'd at the end of each Device):
 *   DES_PHY_TYPE             - DES PHY type (0 for CPHY, 1 for DPHY)
 *   DES_I2C_ADDR             - DES I2C slave address (e.g. 0x0027 for MAX96724)
 *   DES_INTERNAL_PHY         - DES internal PHY (PHY0 = 4, PHY1 = 5, PHY2 = 6, PHY3 = 7)
 *   DES_TO_MIPI_PORT         - DES connected to IPU0 MIPI port (e.g. 0/1/2/3)
 *   DES_I2C_BUS              - DES I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   DES_PATH                 - DES ACPI path string (e.g. "\\_SB.PC00.DES0")
 *   DES_REF                  - DES ACPI namespace reference (e.g. \_SB.PC00.DES0)
 *   DES_PIPE_STR_AUTOSELECT  - DES pipe stream autoselect (0/1)
 *
 * Channel-level defines (set per CHxx, undef'd by _des_ch_common_d457.asl):
 *   DESCH_LINK_NUM           - Channel/link number (0..3) - used for _ADR, reg, SER remote port
 *   DESCH_CH                 - Channel device name (e.g. CH00)
 *   DESCH_SER                - Serializer device name (e.g. SER0)
 *   DESCH_CAM                - Camera device name (e.g. CAM0)
 *   DESCH_SER_I2C            - SER I2C slave address (e.g. 0x40 for MAX9295A)
 *   DESCH_CH_PATH            - CHxx ACPI path string (e.g. "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH           - SERx ACPI path string (e.g. "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF            - SERx ACPI namespace reference (e.g. \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_GPIOREF        - SERx GPIO controller reference (e.g. ^^SER0)
 *   CAM_ALIAS                - Camera alias I2C address used in i2c-alias-pool of the SER
 *   CAM_LANES                - Number of MIPI data lanes for the camera (e.g. 2, 4)
 *   DESCH_SER_X_VC           - D457 X-stream virtual channel mapping (Package of VC indices)
 *   DESCH_SER_Y_VC           - D457 Y-stream virtual channel mapping
 *   DESCH_SER_Z_VC           - D457 Z-stream virtual channel mapping
 *   DESCH_SER_U_VC           - D457 U-stream virtual channel mapping
 *   DESCH_SER_EXTRA_GPIO_PIN - Optional: extra SER GPIO pin number
 *   DESCH_CAM_FSIN_GPIO      - Optional: camera FSIN GPIO index on the SER
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
            #define DES_PHY_TYPE 0
            #define DES_I2C_ADDR 0x0027
            #define DES_INTERNAL_PHY 6
            #define DES_TO_MIPI_PORT 0
            #define DES_I2C_BUS "\\_SB.PC00.I2C1"
            #define DES_PATH "\\_SB.PC00.DES0"
            #define DES_REF \_SB.PC00.DES0
            #define DES_PIPE_STR_AUTOSELECT 0
            #include "_des_common_max96724.asl"

            // Channel 0
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
        }
    }
}
