DefinitionBlock ("", "SSDT", 2, "", "IMG_PTL", 0x20250920)
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
            #define DES_CSI_LOCAL_PORT 6
            #define DES_CSI_REMOTE_PORT 0
            #define DES_I2C_BUS "\\_SB.PC00.I2C1"
            #define DESCH_DES_PATH "\\_SB.PC00.DES0"
            #define DESCH_DES_REF \_SB.PC00.DES0
            #include "_des_common_max96724.asl"

            // Channel 0
            #define DESCH_CH_VALUE 0
            #define DESCH_CH CH00
            #define DESCH_SER SER0
            #define DESCH_CAM CAM0
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH00"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH00.SER0"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH00.SER0
            #define DESCH_SER_GPIOREF ^^SER0
            #define DESCH_SER_PIPECONFIG 1
            #define CAM_LANES 2
            #include "_des_ch_common_d457.asl"

            // Clean up DES-level defines
            #undef CAM_LANES
        }
    }
}
