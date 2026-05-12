/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * CAM-level defines expected by caller:
 *   DESCH_SER_REF      - Path to parent SER (e.g. \_SB.PC00.DESx.CHxx.SERx), used in _DEP
 *   DESCH_SER_PATH     - Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx"), used in CSI2Bus and GpioIo
 *   DESCH_SER_GPIOREF  - GPIO controller path for SER (e.g. ^^SERx), used in gpio resources (e.g. reset-gpios)
 *   CAM_LANES    - Number of MIPI data lanes for the camera
 */
Method (_STA, 0, NotSerialized) // _STA: Status
{
    Return (0x0F)               // bit 0: device is present, bit 1: device is enabled, bit 2: device is shown in UI, bit 3: device is functional
}

Method (_HID, 0, NotSerialized) // _HID: Hardware ID
{
    Return ("INTC10CD")         // D4XX
}

Name (_DEP, Package (0x01)      // _DEP: Dependencies
{
    DESCH_SER_REF               // Path to parent SER (e.g. "\\_SB.PC00.DESx.CHxx.SERx")
})

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    /*
     * mipi-disco-img.c will use the information in CSI2Bus to create fwnode.
     * CAMx Local Port -> SERx Remote Port
     * CAMx PRT0 -> SERx PRT0
     */
    CSI2Bus(
        DeviceInitiated,        // SlaveMode
        1,                      // PhyType (1 for DPHY)
        0,                      // LocalPort (D4XX only 1 PHY)
        DESCH_SER_PATH,         // ResourceSource (Path to parent SERx, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0,                      // ResourceSourceIndex (e.g. 0 for SERx PRT0)
        ,                       // ResourceUsage
        ,                       // DescriptorName
        )                       // VendorData

    I2cSerialBusV2 (
        0x0010,                 // SlaveAddress (0x10 based on D4XX hardware)
        ControllerInitiated,    // SlaveMode
        0x00061A80,             // ConnectionSpeed
        AddressingMode7Bit,     // AddressingMode
        DESCH_SER_PATH,         // ResourceSource (Path to parent SER, e.g. "\\_SB.PC00.DESx.CHxx.SERx")
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                       // DescriptorName
        Exclusive,              // Shared
        )                       // VendorData
})

Name (_DSD, Package ()          // _DSD: Device-Specific Data
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties for _DSD
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 96 MHz

        /*
         * Sensor specific GPIOs, reset-gpios will be used by d4xx.c
         * when devm_gpiod_get_optional is being called with "reset" consumer.
         * For details, please refer to ACPI GPIO binding documentation
         * https://www.kernel.org/doc/html/latest/firmware-guide/acpi/gpio-properties.html
         *
         * DESCH_SER_GPIOREF is the GPIO controller from parent SERx
         * 0 is the GPIO pin group in parent SERx
         * 0 is the index of pin in the GPIO pin group in parent SERx
         * 1 is active low for reset
         *
         */
        Package () { "reset-gpios", Package () { DESCH_SER_GPIOREF, 0, 0, 1 } },
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
    Package ()
    {
        /* mipi-img-port here are NOT actual MIPI ports, but is used by mipi-disco-img.c to create fwnode. */
        Package () { "mipi-img-port-0", "PRT0" }, // Connected to SERx PRTx (used by CAMx CSI2Bus LocalPort)
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        #if CAM_LANES == 4
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        #elif CAM_LANES == 2
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
        #else
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
        #endif
    },
})
