/* 
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for each ISX031 GMSL camera under each deserializer link,
 *              where each link is represented as an ATR channel device.
 *
 * DES-level defines expected by caller:
 *   DES_PATH          - DESx ACPI path string (e.g., "\\_SB.PC00.DES0")
 *   DES_REF           - DESx ACPI namespace reference (e.g., \_SB.PC00.DES0)
 *
 * Channel-level defines expected by caller:
 *   DESCH_CH          - Channel device name (e.g., CH00)
 *   DESCH_SER         - Serializer device name (e.g., SER0)
 *   DESCH_CAM         - Camera device name (e.g., CAM0)
 *   DESCH_CH_PATH     - CHxx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
 *   DESCH_SER_PATH    - SERx ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
 *   DESCH_SER_REF     - SERx ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
 *   DESCH_SER_I2C     - SERx I2C address (e.g., 0x40)
 *   DESCH_LINK_NUM    - Channel/link number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
 *   DESCH_SER_GPIOREF - SERx GPIO controller reference (e.g., ^^SER0, ^^SER1, etc.)
 *   CAM_LANES   - CAMx Number of MIPI data lanes for the camera (e.g., 2, 4)
 * Optional defines:
 *   DESCH_SER_EXTRA_GPIO_PIN - SERx Additional GPIO pin number (e.g., 7 for MFP7 in MAX9295A)
 *   DESCH_SER_X/Y/Z/U_VC - SERx VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 *   DESCH_CAM_FSIN_GPIO  - CAMx Add fsin-gpio resource if defined
 */

Device (DESCH_CH) // New CHxx Device under parent DESx device for each DES channel/link
{
    /*
     * Channel is the naming convention used by i2c-mux or i2c-atr in ACPI namespace 
     * In GMSL context, it can directly be translated as Link 0/1/2/3 of the Deserializer
     */

    Name (_ADR, DESCH_LINK_NUM) // _ADR: Address for the channel (e.g. 0 for Link 0, 1 for Link 1)

    Name (_DSD, Package ()      // _DSD: Device Specific Data
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package ()
        {
            Package () { "reg", DESCH_LINK_NUM },       // used by i2c-atr driver. Represents the channel / link number
        }
    })

    Device (DESCH_SER)      // SERx device under parent DESx.CHxx
    {
        #include "_ser_common_max9295.asl"

        Device (DESCH_CAM)  // CAMx device under parent DESx.CHxx.SERx
        {
            #include "_cam_common_isx031.asl"
        }
    }
}
