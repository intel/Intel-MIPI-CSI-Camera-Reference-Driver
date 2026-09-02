/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SSDT overlay: 3x D3 ISX031 GMSL camera + 1x RS D457 configuration on Robinson Bay.
 *
 *   DES0 (MAX96724 2-trio CPHY, MIPI port 0)
 *     - Link 0: 4-lane D3 ISX031              (MAX9295A SER @ 0x40)
 *     - Link 1: 4-lane D3 ISX031              (MAX9295A SER @ 0x40)
 *     - Link 3: 4-lane D3 ISX031              (MAX9295A SER @ 0x40)
 *   DES1 (MAX96724 2-trio CPHY, MIPI port 2)
 *     - Link 2: 2-lane RealSense D457         (MAX9295A SER @ 0x40, D457 VC mapping)
 *
 * DES-level defines (set per DESx, undef'd at the end of each Device):
 *   DES_PHY_TYPE             - DES PHY type (0 for CPHY, 1 for DPHY)
 *   DES_I2C_ADDR             - DES I2C slave address (e.g. 0x0027 for MAX96724)
 *   DES_LANES                - Number of MIPI data lanes (e.g. 2, 4)
 *   DES_INTERNAL_PHY         - DES internal PHY (PHY0 = 4, PHY1 = 5, PHY2 = 6, PHY3 = 7)
 *   DES_TO_MIPI_PORT         - DES connected to IPU0 MIPI port (e.g. 0/1/2/3)
 *   DES_I2C_BUS              - DES I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   DES_PATH                 - DES ACPI path string (e.g. "\\_SB.PC00.DES0")
 *   DES_REF                  - DES ACPI namespace reference (e.g. \_SB.PC00.DES0)
 *   DES_PIPE_STR_AUTOSELECT  - (Optional) MAX96724 pipe-stream-autoselect override (0 disables, 1 enables)
 *   I2C_SPEED                - (Optional) I2C connection speed for I2cSerialBusV2 (defaults to 400000)
 *   DES_FSIN_GPIO_PIN        - (Optional) DES GPIO pin number, used in GpioIo (e.g. 7 for MFP7 on MAX96724,
 *                              used to receive the external GMSL frame sync trigger pulse)
 *
 * Channel-level defines (set per CHxx, undef'd by the caller after each channel include):
 *   DESCH_LINK_NUM           - Channel/link number (0..3) - used for _ADR, reg, SER remote port
 *   DESCH_CH                 - Channel device name (e.g. CH00)
 *   DESCH_SER                - Serializer device name (e.g. SER0)
 *   DESCH_CAM                - Camera device name (e.g. CAM0)
 *   DESCH_SER_I2C            - SER I2C slave address (e.g. 0x40 for MAX9295A)
 *   DESCH_CH_PATH            - CHxx ACPI path string (e.g. "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH           - SERx ACPI path string (e.g. "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF            - SERx ACPI namespace reference (e.g. \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_GPIOREF        - SERx GPIO controller reference (e.g. ^^SER0)
 *   DESCH_SER_EXTRA_GPIO_PIN - (Optional) Extra SER GPIO pin number (e.g. 7)
 *   DESCH_SER_FSYNC_RX_ID    - (Optional) SER FSYNC RX pin ID (e.g. 7)
 *   DESCH_SER_X/Y/Z/U_VC     - (Optional) VC mapping/filter for D457 streams (Package of VC indices)
 *   EXTERNAL_FRAME_SYNC      - Camera external frame sync FSIN GPIO enablement
 *   CAM_ALIAS                - Camera alias I2C address used in i2c-alias-pool of the SER
 *   CAM_LANES                - Number of MIPI data lanes for the camera (e.g. 2, 4)
 */

/*
 * IMPORTANT: The setup below is for Robinson Bay.
 *
 * Rotation 0   = Channel 0
 * Rotation 90  = Channel 1
 * Rotation 180 = Channel 2
 * Rotation 270 = Channel 3
 *
 *  ___ ___       ___ ___
 * |   |   |     |   |   |
 * |90 |180|     | 1 | 2 |
 * |___|___| --> |___|___|
 * |   |   |     |   |   |
 * |270| 0 |     | 3 | 0 |
 * |___|___|     |___|___|
 *
 *
 * Update the ASL accordingly based on your connection.
 * Make sure DESCH_CH, DESCH_SER, DESCH_CAM, DESCH_CH_PATH, DESCH_SER_PATH,
 * DESCH_SER_REF, DESCH_SER_GPIOREF are all updated if connection changed.
 *
 * 3x D3 ISX031 on MIPI-0 (90, 180, 270),   --> DES0, channel 1,2,3 : frame sync enabled
 * 1x RealSense on MIPI-2 (90)              --> DES1, channel 1     : frame sync disabled
 *
 */


DefinitionBlock ("", "SSDT", 2, "", "IMG_ROB", 0x20260827)
{
    External (_SB.PC00, DeviceObj)

    Include ("_ipu.asl")

    Scope (\_SB.PC00)
    {
        Device (DES0)
        {
            #define EXTERNAL_FRAME_SYNC 1

            // DES-level defines for DES0
            #define DES_PHY_TYPE 0
            #define DES_I2C_ADDR 0x0027
            #define DES_LANES 2
            #define DES_INTERNAL_PHY 4
            #define DES_TO_MIPI_PORT 0
            #define DES_I2C_BUS "\\_SB.PC00.I2C0"
            #define DES_PATH "\\_SB.PC00.DES0"
            #define DES_REF \_SB.PC00.DES0
            #define DES_FSIN_GPIO_PIN 7
            #include "_des_common_max96724.asl"

            // Channel 1/acpi 2 (D3 MFP8 fsync)
            #define DESCH_CH CH01
            #define DESCH_SER SER1
            #define DESCH_CAM CAM1
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH01"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH01.SER1"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH01.SER1
            #define DESCH_LINK_NUM 1
            #define DESCH_SER_I2C 0x40
            #define DESCH_SER_GPIOREF ^^SER1
            #define DESCH_SER_EXTRA_GPIO_PIN 8
            #define DESCH_SER_FSYNC_RX_ID 7
            #define CAM_ALIAS 0x55
            #define CAM_LANES 4
            #include "_des_ch_common_isx031.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_SER_FSYNC_RX_ID
            #undef DESCH_SER_FSYNC_RX_ID
#endif
            #undef CAM_ALIAS
            #undef CAM_LANES

            // Channel 2/acpi 3 (D3 MFP8 fsync)
            #define DESCH_CH CH02
            #define DESCH_SER SER2
            #define DESCH_CAM CAM2
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH02"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH02.SER2"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH02.SER2
            #define DESCH_LINK_NUM 2
            #define DESCH_SER_I2C 0x40
            #define DESCH_SER_GPIOREF ^^SER2
            #define DESCH_SER_EXTRA_GPIO_PIN 8
            #define DESCH_SER_FSYNC_RX_ID 7
            #define CAM_ALIAS 0x56
            #define CAM_LANES 4
            #include "_des_ch_common_isx031.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_SER_FSYNC_RX_ID
            #undef DESCH_SER_FSYNC_RX_ID
#endif
            #undef CAM_ALIAS
            #undef CAM_LANES

            // Channel 3/acpi 4 (D3 MFP8 fsync)
            #define DESCH_CH CH03
            #define DESCH_SER SER3
            #define DESCH_CAM CAM3
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH03"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH03.SER3"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH03.SER3
            #define DESCH_LINK_NUM 3
            #define DESCH_SER_I2C 0x40
            #define DESCH_SER_GPIOREF ^^SER3
            #define DESCH_SER_EXTRA_GPIO_PIN 8
            #define DESCH_SER_FSYNC_RX_ID 7
            #define CAM_ALIAS 0x57
            #define CAM_LANES 4
            #include "_des_ch_common_isx031.asl"
            #undef DESCH_CH
            #undef DESCH_SER
            #undef DESCH_CAM
            #undef DESCH_CH_PATH
            #undef DESCH_SER_PATH
            #undef DESCH_SER_REF
            #undef DESCH_LINK_NUM
            #undef DESCH_SER_I2C
            #undef DESCH_SER_GPIOREF
#ifdef DESCH_SER_EXTRA_GPIO_PIN
            #undef DESCH_SER_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_SER_FSYNC_RX_ID
            #undef DESCH_SER_FSYNC_RX_ID
#endif
            #undef CAM_ALIAS
            #undef CAM_LANES

            // Clean up DES-level defines
            #undef DES_PHY_TYPE
            #undef DES_I2C_ADDR
            #undef DES_LANES
            #undef DES_INTERNAL_PHY
            #undef DES_TO_MIPI_PORT
            #undef DES_I2C_BUS
            #undef DES_PATH
            #undef DES_REF
#ifdef DES_FSIN_GPIO_PIN
            #undef DES_FSIN_GPIO_PIN
#endif
#ifdef EXTERNAL_FRAME_SYNC
            #undef EXTERNAL_FRAME_SYNC
#endif
        }

        Device (DES1)
        {
//            #define EXTERNAL_FRAME_SYNC 1

            // DES-level defines for DES1
            #define DES_PHY_TYPE 0
            #define DES_I2C_ADDR 0x0027
            #define DES_LANES 2
            #define DES_INTERNAL_PHY 6
            #define DES_TO_MIPI_PORT 2
            #define DES_I2C_BUS "\\_SB.PC00.I2C1"
            #define DES_PATH "\\_SB.PC00.DES1"
            #define DES_REF \_SB.PC00.DES1
            #define DES_PIPE_STR_AUTOSELECT 0
            #define I2C_SPEED 100000
//            #define DES_FSIN_GPIO_PIN 7
            #include "_des_common_max96724.asl"

            // Channel 1 (D457 MFP0 fsync)
            #define DESCH_LINK_NUM 1
            #define DESCH_CH CH01
            #define DESCH_SER SER1
            #define DESCH_CAM CAM1
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH01"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH01.SER1"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH01.SER1
            #define DESCH_SER_GPIOREF ^^SER1
            #define DESCH_SER_X_VC Package () { 0 }
            #define DESCH_SER_Y_VC Package () { 1 }
            #define DESCH_SER_Z_VC Package () { 2 }
            #define DESCH_SER_U_VC Package () { 3 }
//            #define DESCH_SER_FSYNC_RX_ID 0
            #define CAM_ALIAS 0x55
            #define CAM_LANES 2
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
#ifdef DESCH_SER_FSYNC_RX_ID
            #undef DESCH_SER_FSYNC_RX_ID
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
            #undef DES_PIPE_STR_AUTOSELECT
#ifdef DES_FSIN_GPIO_PIN
            #undef DES_FSIN_GPIO_PIN
#endif
#ifdef EXTERNAL_FRAME_SYNC
            #undef EXTERNAL_FRAME_SYNC
#endif
            #undef I2C_SPEED
        }
    }
}
