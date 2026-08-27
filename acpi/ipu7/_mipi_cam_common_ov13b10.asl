/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * Description: Common template for a direct MIPI CSI-2 OV13B10 camera device.
 *              This include provides the body of a CAMx device for native MIPI.
 *
 * CAM-level defines expected by caller:
 *   CAM_I2C_BUS       - Camera I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   CAM_I2C_ADDR      - Camera I2C slave address (e.g. 0x0010)
 *   CAM_TO_MIPI_PORT  - Connected IPU MIPI port index (e.g. 0, 1, 2)
 *   CAM_LANES         - Number of MIPI data lanes (e.g. 2, 4)
 *   CAM_RESET_GPIO_CTLR - GPIO controller path for RESET (e.g. "\\_SB.GPI1")
 *   CAM_POWER_GPIO_CTLR - GPIO controller path for POWER_EN (e.g. "\\_SB.GPI0")
 *   CAM_RESET_PIN     - GPIO pin number for RESET
 *   CAM_POWER_PIN     - GPIO pin number for POWER_EN
 *   CAM_RESET_GPIORSC - GPIO resource index used by reset-gpios:
 *                       0 = first GpioIo (_CRS RESET), 1 = second GpioIo (_CRS POWER_EN)
 *   CAM_RESET_ACTIVE_LOW - RESET GPIO polarity (1: active low, 0: active high)
 *   CAM_IPU_PATH      - IPU path string (e.g. "\\_SB.PC00.IPU0")
 *   CAM_IPU_REF       - IPU namespace reference (e.g. \_SB.PC00.IPU0)
 *   CAM_GPIO_REF      - Device self-reference for reset-gpios (e.g. ^CAM0)
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("OVTI13B1")         // OV13B10
}

Name (_DEP, Package (0x01)       // _DEP: Dependencies
{
    CAM_IPU_REF
})

Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> IPU Remote Port
     * CAMx PRT0 -> IPU PRTx (selected by CAM_TO_MIPI_PORT)
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (sensor local port)
        CAM_IPU_PATH,           // ResourceSource (Path to IPU)
        CAM_TO_MIPI_PORT,       // ResourceSourceIndex (IPU PRTx)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        CAM_I2C_ADDR,           // SlaveAddress
        ControllerInitiated,    // SlaveMode
        400000,                 // I2C ConnectionSpeed
        AddressingMode7Bit,     // AddressingMode
        CAM_I2C_BUS,            // ResourceSource
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData

    /* GPIO for sensor RESET (directly from SoC GPIO controller) */
    GpioIo (
        Exclusive,              // Shared (Not shared)
        PullNone,               // PinConfig (No need for pulls)
        0,                      // DebounceTimeout
        0,                      // DriveStrength
        IoRestrictionOutputOnly,// IoRestriction (Only used as output)
        CAM_RESET_GPIO_CTLR,    // ResourceSource (GPIO controller)
        0)                      // ResourceSourceIndex (Must be 0)
    {
        CAM_RESET_PIN           // Pin number
    }

    /* GPIO for sensor POWER_EN (optional rail control) */
    GpioIo (
        Exclusive,
        PullNone,
        0,
        0,
        IoRestrictionOutputOnly,
        CAM_POWER_GPIO_CTLR,
        0)
    {
        CAM_POWER_PIN           // Pin number
    }
})

Name (_DSD, Package ()           // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 19200000 }, // 19.2 MHz
        /*
         * reset-gpios: used by ov13b10.c driver via
         * devm_gpiod_get_optional(dev, "reset", ...)
         * Format: { <gpio_ref>, <resource_index>, <pin_index>, <active_low> }
         * resource_index maps to _CRS GpioIo order: 0=RESET, 1=POWER_EN.
         */
        Package () { "reset-gpios", Package () { CAM_GPIO_REF, CAM_RESET_GPIORSC, 0, CAM_RESET_ACTIVE_LOW } },
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here is local camera port used by mipi-disco-img.c. */
        Package () { "mipi-img-port-0", "PRT0" },
    },
})

Name (PRT0, Package ()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lane", 0 },
#if CAM_LANES == 4
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } },
#elif CAM_LANES == 2
        Package () { "mipi-img-data-lanes", Package () { 1, 2 } },
#else
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } },
#endif
        Package () { "mipi-img-link-frequencies", Package () { 560000000 } },
    },
})
