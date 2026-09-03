/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SER-level defines expected by caller:
 *   DES_REF              - Reference to parent DES (e.g. \_SB.PC00.DESx), used in _DEP
 *   DES_PATH             - Path to parent DES (e.g. "\\_SB.PC00.DESx"), used in CSI2Bus
 *   DESCH_CH_PATH        - Path to DES channel (e.g. "\\_SB.PC00.DESx.CHxx"), used in I2cSerialBusV2
 *   DESCH_SER_PATH       - Path to SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in GpioIo
 *   DESCH_LINK_NUM       - DES channel number (e.g. 0 for CH00, 1 for CH01), used in CSI2Bus
 *   DESCH_SER_I2C        - SER I2C slave address (e.g. 0x40, 0x62), used in I2cSerialBusV2
 *   CAM_ALIAS            - Camera alias I2C address used in i2c-alias-pool in _DSD
 *   DESCH_SER_RESET_GPIO - (Optional) SER Reset GPIO pin number, used in GpioIo
 *   DESCH_SER_FSIN_GPIO  - (Optional) SER Extra GPIO pin number, used in GpioIo
 *   DESCH_SER_FSYNC_RX_ID - (Optional) GMSL GPIO ID the DES sends frame sync as, used in MFP node
 *   DESCH_SER_X/Y/Z/U_VC - (Optional) SER VC filter for Pipe X/Y/Z/U, specifically for MAX96717 driver
 */

#ifndef DESCH_SER_RESET_GPIO
#ifndef DESCH_SER_FSIN_GPIO

#define DESCH_SER_RESET_GPIO 0

#endif
#endif

#ifdef DESCH_SER_RESET_GPIO
#ifdef DESCH_SER_FSIN_GPIO

#if DESCH_SER_RESET_GPIO == DESCH_SER_FSIN_GPIO
#error "DESCH_SER_RESET_GPIO and DESCH_SER_FSIN_GPIO cannot be the same GPIO pin number"
#endif

#endif
#endif

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1138")         // MAX9295A
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    DES_REF               // Path to parent DES (e.g. "\\_SB.PC00.DESx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * SERx Local Port -> DESx Remote Port
     * SERx PRT1 -> DESx PRT0/1/2/3
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        1,                      // LocalPort (MAX9295A only 1 PHY)
        DES_PATH,         // ResourceSource (Path to parent DES, e.g. "\\_SB.PC00.DESx")
        DESCH_LINK_NUM,         // ResourceSourceIndex (e.g. 0/1/2/3 for parent DES PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        DESCH_SER_I2C,          // SlaveAddress (e.g. 0x40, 0x62 based on Serializer Hardware)
        ControllerInitiated,    // SlaveMode
#ifdef I2C_SPEED
        I2C_SPEED,              // I2C ConnectionSpeed (e.g. 100000 for 100kHz)
#else
        400000,                 // I2C ConnectionSpeed (400000 for 400kHz)
#endif
        AddressingMode7Bit,     // AddressingMode
        DESCH_CH_PATH,          // ResourceSource (e.g. "\\_SB.PC00.DESx.CHxx") based on which Link
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionNone,      // IoRestriction
        DESCH_SER_PATH,         // ResourceSourceIndex (Path to SER GPIO controller, e.g. "\\_SB.PC00.DESx.CHxx.SERx" based on which Link)
        0)                      // ResourceUsage (Must be 0)
    {
#ifdef DESCH_SER_RESET_GPIO
        DESCH_SER_RESET_GPIO,   // Pin 0 (e.g. MFP0 on MAX9295)
#endif
#ifdef DESCH_SER_FSIN_GPIO
        DESCH_SER_FSIN_GPIO,   // Extra pin (e.g. MFP7 on MAX9295)
#endif
    }
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Address called out in the pool is used as Camera Alias Address.
         */
        Package () { "i2c-alias-pool",  Package() { CAM_ALIAS } },
        /*
         * External GMSL frame sync control, consumed by max96717.c.
         * Disabled by default; define EXTERNAL_FRAME_SYNC (1) by the
         * caller to override.
         */
#ifdef EXTERNAL_FRAME_SYNC
        Package () { "gmsl-frame-sync-enable", EXTERNAL_FRAME_SYNC }, // Zero to disable, One to enable
#else
        Package () { "gmsl-frame-sync-enable", 0 }, // Disabled by default
#endif
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to CAMx (used by CAMx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to DESx PRTx (used by SERx CSI2Bus LocalPort)

        /* Below are for MAX96717 driver usage. Refer to max96717.c for implementation details */
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        Package () { "Pipe-U", "PIPU" }, // Pipe U
#ifdef EXTERNAL_FRAME_SYNC
#ifdef DESCH_SER_FSYNC_RX_ID
#ifdef DESCH_SER_FSIN_GPIO
        Package () { "fsync", "MFP" }, // fsync pin configuration
#endif
#endif
#endif
    }
})

#ifdef EXTERNAL_FRAME_SYNC
#ifdef DESCH_SER_FSYNC_RX_ID
#ifdef DESCH_SER_FSIN_GPIO
Name (MFP, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        #ifdef DESCH_SER_FSYNC_RX_ID
        Package () { "maxim,rx-id", DESCH_SER_FSYNC_RX_ID }, // GMSL GPIO ID sent by the DES
        #endif
        #ifdef DESCH_SER_FSIN_GPIO
        Package () { "gmsl-frame-sync-gpio-pin", DESCH_SER_FSIN_GPIO },
        #endif
    },
})
#endif
#endif
#endif

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
    #if CAM_LANES == 4
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // 4 data lanes
    #elif CAM_LANES == 2
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },       // 2 data lanes
    #else
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } }, // Default to 4 data lanes if not defined
    #endif
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PIPX, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        #ifdef DESCH_SER_X_VC
        Package () { "vc-id", DESCH_SER_X_VC },     // VC filter for pipe X
        #else
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
        #endif
    },
})

Name (PIPY, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        #ifdef DESCH_SER_Y_VC
        Package () { "vc-id", DESCH_SER_Y_VC },     // VC filter for pipe Y
        #else
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
        #endif
    },
})

Name (PIPZ, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        #ifdef DESCH_SER_Z_VC
        Package () { "vc-id", DESCH_SER_Z_VC },     // VC filter for pipe Z
        #else
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
        #endif
    },
})

Name (PIPU, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        #ifdef DESCH_SER_U_VC
        Package () { "vc-id", DESCH_SER_U_VC },     // VC filter for pipe U
        #else
        Package () { "vc-id", Package () { 0 } },   // Default to VC 0 if not defined
        #endif
    },
})
