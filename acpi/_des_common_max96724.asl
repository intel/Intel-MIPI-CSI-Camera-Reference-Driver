// DES-level defines expected by caller:
//   DES_I2C_ADDR    - DES I2C slave address (e.g., 0x0027)
//   DES_CSI_LOCAL_PORT    - DES local port in CSI2Bus (e.g., 6)
//   DES_CSI_REMOTE_PORT    - IPU remote port in CSI2Bus (e.g., 0)
//   DES_I2C_BUS     - I2C bus path string (e.g., "\\_SB.PC00.I2C1")

Name (_UID, Zero)  // _UID: Unique ID
Method (_HID, 0, NotSerialized)  // _HID: Hardware ID
{
    Return ("INTC1139")
}
Method (_CID, 0, NotSerialized)  // _CID: Compatible ID
{
    Return ("INTC1139")
}
Method (_STA, 0, NotSerialized)  // _STA: Status
{
    Return (0x0F)
}

Name (_DEP, Package ()  // _DEP: Dependencies
{
    \_SB.PC00.IPU0
})

Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    CSI2Bus(DeviceInitiated, DES_PHY_TYPE, DES_CSI_LOCAL_PORT, "\\_SB.PC00.IPU0", DES_CSI_REMOTE_PORT,,,) 
            // <DES_PHY_TYPE> 0 for CPHY, 1 for DPHY
            // DES port <DES_CSI_LOCAL_PORT> -> IPU port <DES_CSI_REMOTE_PORT>
    I2cSerialBusV2 (
        DES_I2C_ADDR,           // SlaveAddress
        ControllerInitiated,    // SlaveMode
        0x00061A80,             // ConnectionSpeed
        AddressingMode7Bit,     // AddressingMode
        DES_I2C_BUS,            // ResourceSource
        0x00,                   // ResourceSourceIndex
        ResourceConsumer,       // ResourceUsage
        ,                      // DescriptorName
        Exclusive,              // ShareType
        )
})

Name (_DSD, Package ()
{
    ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), /* Device Properties for _DSD */,
    Package ()
    {
        Package () { "i2c-alias-pool",  Package () { 0x44, 0x45, 0x46, 0x47 } },
    },
    ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), /* Hierarchical Data Extension */,
    Package ()
    {
        Package () { "mipi-img-port-0", "PRT0" },
        Package () { "mipi-img-port-1", "PRT1" },
        Package () { "mipi-img-port-2", "PRT2" },
        Package () { "mipi-img-port-3", "PRT3" },
        Package () { "mipi-img-port-6", "PRT6" },
    }
})
Name (PRT0, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4} },
    },
})

Name (PRT1, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },

})

Name (PRT2, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } },
    },
})

Name (PRT3, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
    },

})
Name (PRT6, Package()
{
    ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
    Package ()
    {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
        Package () { "mipi-img-link-frequencies", Package() { 1000000000 } }, // 1 GHz
    },
})
