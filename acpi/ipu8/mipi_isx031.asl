/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SSDT overlay: Direct MIPI CSI-2 ISX031 camera configuration on NVL platform.
 *
 * This overlay describes a native MIPI-connected ISX031 sensor (no GMSL SERDES).
 * Adjust the CAM_* defines below to match your hardware wiring.
 *
 * CAM-level defines (set per CAMx, see _mipi_cam_common_isx031.asl):
 *   CAM_I2C_BUS       - Camera I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   CAM_I2C_ADDR      - Camera I2C slave address (e.g. 0x001A for ISX031)
 *   CAM_TO_MIPI_PORT  - Connected IPU0 MIPI port (e.g. 0/1/2)
 *   CAM_LANES         - Number of MIPI data lanes (e.g. 2, 4)
 *   CAM_GPIO_CTLR     - GPIO controller path (e.g. "\\_SB.GPI1")
 *   CAM_RESET_PIN     - GPIO pin number for RESET (community-relative)
 *   CAM_IPU_PATH      - IPU path string (e.g. "\\_SB.PC00.IPU0")
 *   CAM_IPU_REF       - IPU namespace reference (e.g. \_SB.PC00.IPU0)
 *   CAM_GPIO_REF      - Device self-reference for reset-gpios (e.g. ^CAM0)
 *
 * Default configuration (from BIOS table, COM1 groups C_E_V):
 *   CAM0: I2C1, MIPI port 0, 4 lanes, GPP_E_1 (pin 27)
 *   CAM1: I2C0, MIPI port 2, 2 lanes, GPP_E_10 (pin 36)
 */

DefinitionBlock ("", "SSDT", 2, "", "IMG_IPU", 0x20260807)
{
    External (_SB.PC00, DeviceObj)
    External (_SB.PC00.IPU0, DeviceObj)
    External (_SB.GPI1, DeviceObj)          // GPIO controller COM1 for RESET

    Include ("_ipu.asl")

    Scope (\_SB.PC00)
    {
        Device (CAM0)
        {
            #define CAM_I2C_BUS "\\_SB.PC00.I2C1"
            #define CAM_I2C_ADDR 0x001A
            #define CAM_TO_MIPI_PORT 0
            #define CAM_LANES 4
            #define CAM_GPIO_CTLR "\\_SB.GPI1"
            #define CAM_RESET_PIN 27        // GPP_E_1 (COM1 pin 27)
            #define CAM_IPU_PATH "\\_SB.PC00.IPU0"
            #define CAM_IPU_REF \_SB.PC00.IPU0
            #define CAM_GPIO_REF ^CAM0
            #include "_mipi_cam_common_isx031.asl"
            #undef CAM_I2C_BUS
            #undef CAM_I2C_ADDR
            #undef CAM_TO_MIPI_PORT
            #undef CAM_LANES
            #undef CAM_GPIO_CTLR
            #undef CAM_RESET_PIN
            #undef CAM_IPU_PATH
            #undef CAM_IPU_REF
            #undef CAM_GPIO_REF
        }

        Device (CAM1)
        {
            #define CAM_I2C_BUS "\\_SB.PC00.I2C0"
            #define CAM_I2C_ADDR 0x001A
            #define CAM_TO_MIPI_PORT 2
            #define CAM_LANES 2
            #define CAM_GPIO_CTLR "\\_SB.GPI1"
            #define CAM_RESET_PIN 36        // GPP_E_10 (COM1 pin 36)
            #define CAM_IPU_PATH "\\_SB.PC00.IPU0"
            #define CAM_IPU_REF \_SB.PC00.IPU0
            #define CAM_GPIO_REF ^CAM1
            #include "_mipi_cam_common_isx031.asl"
            #undef CAM_I2C_BUS
            #undef CAM_I2C_ADDR
            #undef CAM_TO_MIPI_PORT
            #undef CAM_LANES
            #undef CAM_GPIO_CTLR
            #undef CAM_RESET_PIN
            #undef CAM_IPU_PATH
            #undef CAM_IPU_REF
            #undef CAM_GPIO_REF
        }
    }
}
