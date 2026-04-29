// SPDX-License-Identifier: GPL-2.0
// Copyright (c) 2025 Intel Corporation.
//
// Common template for ISX031 deserializer ATR channel device.
// Uses IASL C-preprocessor macros to eliminate per-channel file duplication.
//
// DES-level defines (set once before all channels, caller undefs after):
//   DESCH_SER_I2C     - Serializer I2C address (e.g., 0x40)
//   DESCH_DES_PATH    - DES ACPI path string (e.g., "\\_SB.PC00.DES0")
//   DESCH_DES_REF     - DES ACPI namespace reference (e.g., \_SB.PC00.DES0)
//
// Channel-level defines (set per channel, auto-cleaned by this template):
//   DESCH_CH_VALUE    - Channel number (0, 1, 2, 3) - used for _ADR, reg, and SER remote port
//   DESCH_CH          - Channel device name (e.g., CH00)
//   DESCH_SER         - Serializer device name (e.g., SER0)
//   DESCH_CAM         - Camera device name (e.g., CAM0)
//   DESCH_CH_PATH     - Channel ACPI path string (e.g., "\\_SB.PC00.DES0.CH00")
//   DESCH_SER_PATH    - Serializer ACPI path string (e.g., "\\_SB.PC00.DES0.CH00.SER0")
//   DESCH_SER_REF     - Serializer ACPI namespace reference (e.g., \_SB.PC00.DES0.CH00.SER0)
//   DESCH_SER_GPIOREF - GPIO reference for CAM reset (e.g., ^^SER0)
//
// Optional defines:
//   DESCH_EXTRA_GPIO_PIN  - Additional GPIO pin number (e.g., 7 for fsin)
//   DESCH_CAM_FSIN_GPIO   - If defined, adds fsin-gpios property to CAM _DSD

Device (DESCH_CH)
{
    Name (_ADR, DESCH_CH_VALUE)
    Name (_DSD, Package ()
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package ()
        {
            Package () { "reg", DESCH_CH_VALUE },
        }
    })

    Device (DESCH_SER)
    {
        #define SER_X_VC Package () { 0 }
        #define SER_Y_VC Package () { 1 }
        #define SER_Z_VC Package () { 2 }
        #define SER_U_VC Package () { 3 }
        #include "_ser_common_max9295.asl"

        Device (DESCH_CAM)
        {
            #include "_cam_common_d457.asl"
        }
    }
}

// Clean up channel-level defines for safe reuse
#undef DESCH_CH_VALUE
#undef DESCH_CH
#undef DESCH_SER
#undef DESCH_CAM
#undef DESCH_SER_I2C
#undef DESCH_CH_PATH
#undef DESCH_SER_I2C
#undef DESCH_SER_PATH
#undef DESCH_SER_REF
#undef DESCH_SER_GPIOREF
#ifdef DESCH_EXTRA_GPIO_PIN
#undef DESCH_EXTRA_GPIO_PIN
#endif
#ifdef DESCH_CAM_FSIN_GPIO
#undef DESCH_CAM_FSIN_GPIO
#endif
#undef SER_X_VC
#undef SER_Y_VC
#undef SER_Z_VC
#undef SER_U_VC
