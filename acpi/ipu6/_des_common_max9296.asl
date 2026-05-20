/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * DES-level defines expected by caller:
 *   DES_PHY_TYPE           - DES PHY type (0 for CPHY, 1 for DPHY), used in CSI2Bus
 *   DES_INTERNAL_PHY       - DES internal PHY (e.g. PHY0 = 2, PHY1 = 3), used as DES Local port in CSI2Bus.
 *   DES_LANES              - Number of MIPI data lanes (e.g. 2, 4), used in PRT2/3 connected to IPU
 *   DES_TO_MIPI_PORT       - DES connected to MIPI Port (e.g. 0/1/2/3) of IPU0 Device, used as IPU remote port in CSI2Bus
 *   DES_I2C_ADDR           - DES I2C slave address (e.g. 0x0048 for MAX9296A), used in I2cSerialBusV2
 *   DES_I2C_BUS            - DES I2C bus path string (e.g. "\\_SB.PC00.I2C1"), used in I2cSerialBusV2
 */

Name (_UID, Zero)               // _UID: Unique ID

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC1137")         // MAX9296A
}

Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Name (_DEP, Package ()          // _DEP: Dependencies
{
    \_SB.PC00.IPU0              // Path to parent IPU0 (e.g. "\\_SB.PC00.IPU0")
})

Name (_CRS, ResourceTemplate () // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * DESx Local Port -> IPU0 Remote Port
     * DESx PRT2/3 -> IPU0 PRT0/1/2/3
     */

    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        DES_PHY_TYPE,           // PhyType (e.g. 0 for CPHY, 1 for DPHY)
        DES_INTERNAL_PHY,       // LocalPort (e.g. 2/3 for DES internal PHY0/1)
        "\\_SB.PC00.IPU0",      // ResourceSource
        DES_TO_MIPI_PORT,       // ResourceSourceIndex (e.g. 0/1/2/3 for parent IPU0 PRT0/1/2/3)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        DES_I2C_ADDR,           // SlaveAddress (e.g. 0x0048 based on Deserializer Hardware)
        ControllerInitiated,    // SlaveMode
        0x00061A80,             // ConnectionSpeed
        AddressingMode7Bit,     // AddressingMode
        DES_I2C_BUS,            // ResourceSource (e.g. "\\_SB.PC00.I2C1") based on Board design
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        /*
         * I2C alias pool used by i2c-atr driver.
         * Addresses called out in the pool is used for Serializer for each link.
         */
        Package () { "i2c-alias-pool",  Package () { 0x44, 0x45 } },
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to Link 0 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-1", "PRT1" }, // Connected to Link 1 of DESx (used by SERx CSI2Bus ResourceSourceIndex)
        Package () { "mipi-img-port-2", "PRT2" }, // Internal PHY0, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
        Package () { "mipi-img-port-3", "PRT3" }, // Internal PHY1, Connected to IPU0 PRTx (used by DESx CSI2Bus LocalPort)
    }
})
Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4} },
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },
})

Name (PRT2, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        #if DES_LANES == 2
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
        #else
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } },
        #endif
        Package () { "mipi-img-link-frequencies", Package() { 1000000000 } }, // 1 GHz to be used by Intel IPU driver as link frequency
    },
})

Name (PRT3, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        #if DES_LANES == 2
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
        #else
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        #endif
    },
})
