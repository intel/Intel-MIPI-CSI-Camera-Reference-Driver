/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 *
 * SSDT overlay: Direct MIPI CSI-2 OV13B10 camera configuration on ARL platform.
 *
 * This overlay describes a native MIPI-connected OV13B10 sensor (no GMSL SERDES).
 * Adjust the CAM_* defines below to match your hardware wiring.
 *
 * CAM-level defines (set per CAMx, see _mipi_cam_common_ov13b10.asl):
 *   CAM_I2C_BUS       - Camera I2C bus path (e.g. "\\_SB.PC00.I2C1")
 *   CAM_I2C_ADDR      - Camera I2C slave address (0x0010 for OV13B10)
 *   CAM_TO_MIPI_PORT  - Connected IPU0 MIPI port (e.g. 0/1/2/3/4/5)
 *   CAM_LANES         - Number of MIPI data lanes (e.g. 2, 4)
 *   CAM_RESET_GPIO_CTLR - GPIO controller path for RESET (e.g. "\\_SB.GPI0")
 *   CAM_POWER_GPIO_CTLR - GPIO controller path for POWER_EN (e.g. "\\_SB.GPI0")
 *   CAM_RESET_PIN     - GPIO pin number for RESET (GPIO controller offset)
 *   CAM_POWER_PIN     - GPIO pin number for POWER_EN (GPIO controller offset)
 *   CAM_RESET_GPIORSC - GPIO resource index used by reset-gpios:
 *                       0 = RESET GpioIo resource, 1 = POWER_EN GpioIo resource
 *   CAM_RESET_ACTIVE_LOW - RESET GPIO polarity (1: active low, 0: active high)
 *   CAM_IPU_PATH      - IPU path string (e.g. "\\_SB.PC00.IPU0")
 *   CAM_IPU_REF       - IPU namespace reference (e.g. \_SB.PC00.IPU0)
 *   CAM_GPIO_REF      - Device self-reference for reset-gpios (e.g. ^CAM0)
 *
 * Default configuration (from BIOS table for OV13B10 on IPU6EPMTL):
 *   CAM0: I2C1, MIPI port 0, 4 lanes,
 *         RESET COM0 D_E_F_V pad 23 (GPP_D_23, GPI0 pin 407),
 *         POWER_EN COM0 C pad 8 (GPP_C_8, GPI0 pin 72)
 *   CAM1: I2C0, MIPI port 4, 4 lanes,
 *         RESET COM0 D_E_F_V pad 22 (GPP_D_22, GPI0 pin 406),
 *         POWER_EN COM0 C pad 9 (GPP_C_9, GPI0 pin 73)
 *
 * On ARL (INTC105E) all pads are exposed by a single GPIO controller
 * \_SB.GPI0; pin number = 32 * group index + pad (see gpio-ranges in
 * /sys/kernel/debug/pinctrl/INTC105E:00).
 */

DefinitionBlock ("", "SSDT", 2, "", "IMG_IPU", 0x20261027)
{
    External (_SB.PC00, DeviceObj)
    External (_SB.PC00.IPU0, DeviceObj)
    External (_SB.GPI0, DeviceObj)          // GPIO controller for RESET and POWER_EN

    Include ("_ipu.asl")

    Scope (\_SB.PC00)
    {
        Device (CAM0)
        {
            #define CAM_I2C_BUS "\\_SB.PC00.I2C1"
            #define CAM_I2C_ADDR 0x0010
            #define CAM_TO_MIPI_PORT 0
            #define CAM_LANES 4
            #define CAM_RESET_GPIO_CTLR "\\_SB.GPI0"
            #define CAM_POWER_GPIO_CTLR "\\_SB.GPI0"
            #define CAM_RESET_PIN 407       // GPP_D_23 (COM0 D_E_F_V pad 23)
            #define CAM_POWER_PIN 72        // GPP_C_8 (COM0 C pad 8, Power_En)
            // Use POWER_EN GPIO resource for probe-time toggling.
            #define CAM_RESET_GPIORSC 1
            // Logical low maps to physical high (enable rail).
            #define CAM_RESET_ACTIVE_LOW 1
            #define CAM_IPU_PATH "\\_SB.PC00.IPU0"
            #define CAM_IPU_REF \_SB.PC00.IPU0
            #define CAM_GPIO_REF ^CAM0
            #include "_mipi_cam_common_ov13b10.asl"
            #undef CAM_I2C_BUS
            #undef CAM_I2C_ADDR
            #undef CAM_TO_MIPI_PORT
            #undef CAM_LANES
            #undef CAM_RESET_GPIO_CTLR
            #undef CAM_POWER_GPIO_CTLR
            #undef CAM_RESET_PIN
            #undef CAM_POWER_PIN
            #undef CAM_RESET_GPIORSC
            #undef CAM_RESET_ACTIVE_LOW
            #undef CAM_IPU_PATH
            #undef CAM_IPU_REF
            #undef CAM_GPIO_REF
        }

        Device (CAM1)
        {
            #define CAM_I2C_BUS "\\_SB.PC00.I2C0"
            #define CAM_I2C_ADDR 0x0010
            #define CAM_TO_MIPI_PORT 4
            #define CAM_LANES 4
            #define CAM_RESET_GPIO_CTLR "\\_SB.GPI0"
            #define CAM_POWER_GPIO_CTLR "\\_SB.GPI0"
            #define CAM_RESET_PIN 406       // GPP_D_22 (COM0 D_E_F_V pad 22)
            #define CAM_POWER_PIN 73        // GPP_C_9 (COM0 C pad 9, Power_En)
            // Use POWER_EN GPIO resource for probe-time toggling.
            #define CAM_RESET_GPIORSC 1
            // Logical low maps to physical high (enable rail).
            #define CAM_RESET_ACTIVE_LOW 1
            #define CAM_IPU_PATH "\\_SB.PC00.IPU0"
            #define CAM_IPU_REF \_SB.PC00.IPU0
            #define CAM_GPIO_REF ^CAM1
            #include "_mipi_cam_common_ov13b10.asl"
            #undef CAM_I2C_BUS
            #undef CAM_I2C_ADDR
            #undef CAM_TO_MIPI_PORT
            #undef CAM_LANES
            #undef CAM_RESET_GPIO_CTLR
            #undef CAM_POWER_GPIO_CTLR
            #undef CAM_RESET_PIN
            #undef CAM_POWER_PIN
            #undef CAM_RESET_GPIORSC
            #undef CAM_RESET_ACTIVE_LOW
            #undef CAM_IPU_PATH
            #undef CAM_IPU_REF
            #undef CAM_GPIO_REF
        }
    }
}
