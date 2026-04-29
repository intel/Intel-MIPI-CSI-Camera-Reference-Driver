Method (_STA, 0, NotSerialized)  // _STA: Status
{
        Return (0x0F)
}

Method (_HID, 0, NotSerialized)  // _HID: Hardware ID
{
        Return ("INTC1138") // MAX9295
}

Name(_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
{
    CSI2Bus(DeviceInitiated, 1, 1, DESCH_DES_PATH, DESCH_CH_VALUE,,,) // Type 1 for DPHY; SER port 1 -> DES port <DESCH_CH_VALUE>
    I2cSerialBusV2 (DESCH_SER_I2C, ControllerInitiated, 0x00061A80, 
            AddressingMode7Bit, DESCH_CH_PATH,
            0x00, ResourceConsumer,, Exclusive)
    GpioIo (
        Exclusive,                  // Not shared
        PullNone,                   // No need for pulls
        0,                          // Debounce timeout
        0,                          // Drive strength
        IoRestrictionOutputOnly,    // Only used as output
        DESCH_SER_PATH,             // GPIO controller
        0)                          // Must be 0
    {
        0,                         // Pin 0
#ifdef DESCH_EXTRA_GPIO_PIN
        DESCH_EXTRA_GPIO_PIN,      // Extra pin
#endif
    }
})

Name (_DEP, Package (0x01)  // _DEP: Dependencies
{
    DESCH_DES_REF
})

Name (_DSD, Package ()  // _DSD: Device-Specific Data
{
        ToUUID ("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), /* Device Properties for _DSD */,
        Package ()
        {
        Package () { "i2c-alias-pool",  Package () { 0x54, 0x55 } }, // alias for cam0
        },
        ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), /* Hierarchical Data Extension */,
        Package ()
        {
        Package () { "mipi-img-port-0", "PRT0" }, // to sensor
        Package () { "mipi-img-port-1", "PRT1" }, // to des
        #ifdef SER_X_VC
        Package () { "Pipe-X", "PIPX" }, // Pipe X
        #endif
        #ifdef SER_Y_VC
        Package () { "Pipe-Y", "PIPY" }, // Pipe Y
        #endif
        #ifdef SER_Z_VC
        Package () { "Pipe-Z", "PIPZ" }, // Pipe Z
        #endif
        #ifdef SER_U_VC
        Package () { "Pipe-U", "PIPU" }, // Pipe U
        #endif
        }
})

Name (PRT0, Package()
{
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
        Package () { "mipi-img-clock-lanes", 0 },
        #if CAM_LANES == 4
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        #elif CAM_LANES == 2
        Package () { "mipi-img-data-lanes", Package() { 1, 2 } },
        #else
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        #endif
        },
})

Name (PRT1, Package()
{
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
        Package () { "mipi-img-clock-lanes", 0 },
        Package () { "mipi-img-data-lanes", Package() { 1, 2, 3, 4 } },
        Package () { "mipi-img-link-frequencies", Package() { 600000000 } }, // 600 MHz
        },
})
#ifdef SER_X_VC
Name (PIPX, Package()
{
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
        Package () { "vc-id", SER_X_VC }, // VC for pipe X
        },
})
#endif
#ifdef SER_Y_VC
Name (PIPY, Package()
{
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
        Package () { "vc-id", SER_Y_VC }, // VC for pipe Y
        },
})
#endif
#ifdef SER_Z_VC
Name (PIPZ, Package()
{
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
        Package () { "vc-id", SER_Z_VC }, // VC for pipe Z
        },
})
#endif
#ifdef SER_U_VC
Name (PIPU, Package()
{
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
        Package () { "vc-id", SER_U_VC }, // VC for pipe U
        },
})
#endif