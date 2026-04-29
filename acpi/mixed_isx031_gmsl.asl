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

            // Channel 0 (D3 ISX031)
            #define DESCH_CH_VALUE 0
            #define DESCH_CH CH00
            #define DESCH_SER SER0
            #define DESCH_CAM CAM0
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH00"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH00.SER0"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH00.SER0
            #define DESCH_SER_GPIOREF ^^SER0
            #include "_des_ch_common_isx031.asl"

            // Channel 1 (D3 ISX031)
            #define DESCH_CH_VALUE 1
            #define DESCH_CH CH01
            #define DESCH_SER SER1
            #define DESCH_CAM CAM1
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH01"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH01.SER1"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH01.SER1
            #define DESCH_SER_GPIOREF ^^SER1
            #include "_des_ch_common_isx031.asl"

            // Channel 2 (LI ISX031)
            #define DESCH_CH_VALUE 2
            #define DESCH_CH CH02
            #define DESCH_SER SER2
            #define DESCH_CAM CAM2
            #define DESCH_SER_I2C 0x62
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH02"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH02.SER2"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH02.SER2
            #define DESCH_SER_GPIOREF ^^SER2
            #include "_des_ch_common_isx031.asl"

            // Channel 3 (SENSING ISX031)
            #define DESCH_CH_VALUE 3
            #define DESCH_CH CH03
            #define DESCH_SER SER3
            #define DESCH_CAM CAM3
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES0.CH03"
            #define DESCH_SER_PATH "\\_SB.PC00.DES0.CH03.SER3"
            #define DESCH_SER_REF \_SB.PC00.DES0.CH03.SER3
            #define DESCH_SER_GPIOREF ^^SER3
            #define DESCH_EXTRA_GPIO_PIN 7
            #define DESCH_CAM_FSIN_GPIO 1
            #include "_des_ch_common_isx031.asl"

            // Clean up DES0-level defines
            #undef DES_PHY_TYPE
            #undef DES_I2C_ADDR
            #undef DES_CSI_LOCAL_PORT
            #undef DES_CSI_REMOTE_PORT
            #undef DES_I2C_BUS
            #undef DESCH_SER_I2C
            #undef DESCH_DES_PATH
            #undef DESCH_DES_REF
        }

        Device (DES1)
        {
            // DES-level defines for DES1
            #define DES_PHY_TYPE 0
            #define DES_I2C_ADDR 0x0027
            #define DES_CSI_LOCAL_PORT 4
            #define DES_CSI_REMOTE_PORT 2
            #define DES_I2C_BUS "\\_SB.PC00.I2C2"
            #define DESCH_DES_PATH "\\_SB.PC00.DES1"
            #define DESCH_DES_REF \_SB.PC00.DES1
            #include "_des_common_max96724.asl"

            // Channel 0 (D3 ISX031)
            #define DESCH_CH_VALUE 0
            #define DESCH_CH CH00
            #define DESCH_SER SER0
            #define DESCH_CAM CAM0
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH00"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH00.SER0"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH00.SER0
            #define DESCH_SER_GPIOREF ^^SER0
            #include "_des_ch_common_isx031.asl"

            // Channel 1 (D3 ISX031)
            #define DESCH_CH_VALUE 1
            #define DESCH_CH CH01
            #define DESCH_SER SER1
            #define DESCH_CAM CAM1
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH01"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH01.SER1"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH01.SER1
            #define DESCH_SER_GPIOREF ^^SER1
            #include "_des_ch_common_isx031.asl"

            // Channel 2 (LI ISX031)
            #define DESCH_CH_VALUE 2
            #define DESCH_CH CH02
            #define DESCH_SER SER2
            #define DESCH_CAM CAM2
            #define DESCH_SER_I2C 0x62
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH02"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH02.SER2"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH02.SER2
            #define DESCH_SER_GPIOREF ^^SER2
            #include "_des_ch_common_isx031.asl"

            // Channel 3 (SENSING ISX031)
            #define DESCH_CH_VALUE 3
            #define DESCH_CH CH03
            #define DESCH_SER SER3
            #define DESCH_CAM CAM3
            #define DESCH_SER_I2C 0x40
            #define DESCH_CH_PATH "\\_SB.PC00.DES1.CH03"
            #define DESCH_SER_PATH "\\_SB.PC00.DES1.CH03.SER3"
            #define DESCH_SER_REF \_SB.PC00.DES1.CH03.SER3
            #define DESCH_SER_GPIOREF ^^SER3
            #define DESCH_EXTRA_GPIO_PIN 7
            #define DESCH_CAM_FSIN_GPIO 1
            #include "_des_ch_common_isx031.asl"

            // Clean up DES0-level defines
            #undef DES_PHY_TYPE
            #undef DES_I2C_ADDR
            #undef DES_CSI_LOCAL_PORT
            #undef DES_CSI_REMOTE_PORT
            #undef DES_I2C_BUS
            #undef DESCH_SER_I2C
            #undef DESCH_DES_PATH
            #undef DESCH_DES_REF
        }
    }
}
