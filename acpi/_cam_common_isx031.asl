Method (_STA, 0, NotSerialized)  // _STA: Status
{
    Return (0x0F)
}

Method (_HID, 0, NotSerialized)  // _HID: Hardware ID
{
    Return ("INTC113C") // ISX031
}

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    CSI2Bus(DeviceInitiated, 1, 0, DESCH_SER_PATH, 0,,,) // Type 1 for DPHY; CAM port 0 -> SER port <DESCH_SER_PATH>

    I2cSerialBusV2 (0x001A, ControllerInitiated, 0x00061A80, // actual address
            AddressingMode7Bit, DESCH_SER_PATH,
            0x00, ResourceConsumer,, Exclusive)
})

Name (_DEP, Package (0x01)  // _DEP: Dependencies
{
    DESCH_SER_REF
})

Name (_DSD, Package ()  // _DSD: Device-Specific Data
{

    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), /* Device Properties for _DSD */,
    Package ()
    {
        Package () { "mipi-img-clock-frequency", 96000000 }, // 9.6 MHz
        Package () { "reset-gpios", Package () { DESCH_SER_GPIOREF, 0, 0, 1 } },
#ifdef DESCH_CAM_FSIN_GPIO
        Package () { "fsin-gpios", Package () { DESCH_SER_GPIOREF, 0, 1, 1 } },
#endif
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), /* Hierarchical Data Extension */,
    Package ()
    {
        Package () { "mipi-img-port-0", "PRT0" }, // to ser
    },
})

Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        Package () { "mipi-img-link-frequencies", Package() { 600000000 } }, // 600 MHz
    },
})