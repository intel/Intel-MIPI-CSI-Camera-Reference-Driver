// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (c) 2017-2024, INTEL CORPORATION.  All rights reserved.
 *
 * max96724.c - max96724 GMSL Deserializer driver
 */

#include <linux/i2c.h>
#include <linux/gpio.h>
#include <linux/kernel.h>
#include <linux/media.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/of_gpio.h>
#include <linux/version.h>
// #include <media/camera_common.h>
#include <linux/regmap.h>
#include <media/i2c/d4xx-max96724.h>
#include <linux/bitops.h>


/* MAX96724 register specifics */
#define MAX96724_FLD_OFS(n, bits_per_field, count) (((n) % (count)) * (bits_per_field))
#define MAX96724_OFFSET_GENMASK(offset, h, l) GENMASK(offset + h, offset + l)
#define MAX96724_FIELD_PREP(_mask, _val)				\
	({								\
		((typeof(_mask))(_val) << __bf_shf(_mask)) & (_mask);	\
	})


#define MAX96724_REG3_ADDR 0x0003  /* I2C Remote Control Channel Enable */
#define MAX96724_REG5_ADDR 0x0005
#define MAX96724_REG6_ADDR 0x0006
#define MAX96724_REG10_ADDR 0x0010 /* PHY A/B RX/TX rate control */
#define MAX96724_REG11_ADDR 0x0011 /* PHY C/D RX/TX rate control */
#define MAX96724_PWR1_ADDR 0x0013  /* RESET_ALL */
#define MAX96724_REG14_ADDR 0x0014
#define MAX96724_REG15_ADDR 0x0015
#define MAX96724_REG16_ADDR 0x0016
#define MAX96724_REG17_ADDR 0x0017 /* Internal regulator control */
#define MAX96724_REG18_ADDR 0x0018 /* RESET_ONESHOT control */
#define MAX96724_REG19_ADDR 0x0019 /* Internal regulator control */

#define MAX96724_REG_POC_CTRL1	MAX96724_REG14_ADDR
#define MAX96724_REG_POC_CTRL2	MAX96724_REG15_ADDR
#define MAX96724_REG_POC_CTRL3	MAX96724_REG16_ADDR

#define MAX96724_REG17_CTRL_EN_FIELD BIT(2)
#define MAX96724_REG19_CTRL_EN_FIELD BIT(4)

#define MAX96724_LINK_CTRL_ADDR 0x0006
#define MAX96724_LINK_CTRL_GMSL_FIELD(link) BIT(link) << 4
#define MAX96724_LINK_CTRL_EN_FIELD(link) BIT(link)

#define MAX96724_RESET_CTRL_ADDR MAX96724_REG18_ADDR
#define MAX96724_RESET_CTRL_FIELD(link) BIT(link)
#define MAX96724_RESET_LINK_FIELD(link) BIT(link) << 4

#define MAX967XX_DEV_ID_ADDR 0x000D
#define MAX96712_DEV_REV_ID 0xA0
#define MAX96724_DEV_REV_ID 0xA2

#define MAX967XX_DEV_REV_ADDR 0x004C
#define MAX967XX_DEV_REV_FIELD GENMASK(3, 0)

/* Note that CSIs and pipes overlap:
 * 0x901 through 0x90A and 0x933 through 0x934 are CSIs, repeated every 0x40 up to 4 times
 * 0x90B through 0x932 are pipes, repeated every 0x40 up to 4 times
 */
#define MAX96724_MIPI_TX0 0x0900
#define MAX96724_MIPI_TX(pipe) (MAX96724_MIPI_TX0 + ((pipe) * 0x40))

#define MAX96724_MIPI_TX_DESKEW_INIT(csi) (MAX96724_MIPI_TX(csi) + 0x03)
#define MAX96724_MIPI_TX_LANE_CNT(csi) (MAX96724_MIPI_TX(csi) + 0x0A)
#define MAX96724_MIPI_TX_ALT_MEM(csi) (MAX96724_MIPI_TX(csi) + 0x33)

#define MAX96724_MAP_EN_L(pipe) (MAX96724_MIPI_TX(pipe) + 0x0B)
#define MAX96724_MAP_EN_H(pipe) (MAX96724_MIPI_TX(pipe) + 0x0C)
#define MAX96724_MAP_SRCDST_EN_FIELD(map) BIT(map)

#define MAX96724_MAP_SRC_L(pipe, map) (MAX96724_MIPI_TX(pipe) + 0x0D + ((map) * 2))
#define MAX96724_MAP_DST_L(pipe, map) (MAX96724_MIPI_TX(pipe) + 0x0D + ((map) * 2) + 1)

#define MAX96724_MAP_PHY_DEST(pipe, map) (MAX96724_MIPI_TX(pipe) + 0x2D + ((map) / 4))
#define MAX96724_MAP_DPHY_DEST_FIELD(map) GENMASK(1, 0) << MAX96724_FLD_OFS(map, 2, 4)

#define MAX96724_MIPI_TX_EXT0 0x0800
#define MAX96724_MIPI_TX_EXT(pipe) (MAX96724_MIPI_TX_EXT0 + ((pipe) * 0x10))
#define MAX96724_MAP_SRCDST_H(pipe, map) (MAX96724_MIPI_TX_EXT(pipe) + (map))

/* Video Pipe MIPI Lanes deskew init */
#define MAX96724_DESKEW_INIT0_ADDR MAX96724_MIPI_TX_DESKEW_INIT(0)
#define MAX96724_DESKEW_INIT1_ADDR MAX96724_MIPI_TX_DESKEW_INIT(1)
#define MAX96724_DESKEW_INIT2_ADDR MAX96724_MIPI_TX_DESKEW_INIT(2)
#define MAX96724_DESKEW_INIT3_ADDR MAX96724_MIPI_TX_DESKEW_INIT(3)
#define MAX96724_MIPI_TX_DESKEW_INIT_AUTO_FIELD BIT(7)
#define MAX96724_MIPI_TX_DESKEW_WIDTH_FIELD GENMASK(2, 0)

/* Video Pipe MIPI Lanes Controls */
#define MAX96724_LANE_CTRL0_ADDR MAX96724_MIPI_TX_LANE_CNT(0)
#define MAX96724_LANE_CTRL1_ADDR MAX96724_MIPI_TX_LANE_CNT(1)
#define MAX96724_LANE_CTRL2_ADDR MAX96724_MIPI_TX_LANE_CNT(2)
#define MAX96724_LANE_CTRL3_ADDR MAX96724_MIPI_TX_LANE_CNT(3)
#define MAX96724_MIPI_TX_LANE_CNT_FIELD GENMASK(7, 6)
#define MAX96724_MIPI_TX_CPHY_EN_FIELD BIT(5)
#define MAX96724_MIPI_TX_VCX_EN_FIELD BIT(4)
#define MAX96724_MIPI_TX_WAKEUP_CYC_FIELD GENMASK(2, 0)

#define MAX96724_LANE_CTRL_MAP(num_lanes) \
	(((num_lanes) << 6) & MAX96724_MIPI_TX_LANE_CNT_FIELD)

#define MAX96724_CSI_DPHY 0x0
#define MAX96724_CSI_CPHY 0x1
#define MAX96724_CSI_MODE_1X4 0x0
#define MAX96724_CSI_MODE_4X2 0x1
#define MAX96724_CSI_MODE_2X4 0x4

/* Video Pipe MIPI Mapping Enable */
#define MAX96724_PIPE_X_MIPI_EN MAX96724_MAP_EN_L(0)
#define MAX96724_MAP_EN_FIELD GENMASK(7, 0)

/* Video Pipe X Cross Mapping  baseline */
#define MAX96724_PIPE_X_EN_ADDR MAX96724_MAP_EN_L(0)
#define MAX96724_PIPE_X_SRC_0_MAP_ADDR MAX96724_MAP_SRC_L(0,0)
#define MAX96724_PIPE_X_DST_0_MAP_ADDR MAX96724_MAP_DST_L(0,0)
#define MAX96724_PIPE_X_SRCDST_VC_EXT_0_MAP_ADDR MAX96724_MAP_SRCDST_H(0,0)
#define MAX96724_PIPE_X_PHY_DEST_0_MAP_ADDR MAX96724_MAP_PHY_DEST(0,0)
#define MAX96724_PIPE_X_SRC_1_MAP_ADDR MAX96724_MAP_SRC_L(0,1)
#define MAX96724_PIPE_X_DST_1_MAP_ADDR MAX96724_MAP_DST_L(0,1)
#define MAX96724_PIPE_X_SRCDST_VC_EXT_1_MAP_ADDR MAX96724_MAP_SRCDST_H(0,1)
#define MAX96724_PIPE_X_PHY_DEST_1_MAP_ADDR MAX96724_MAP_PHY_DEST(0,1)
#define MAX96724_PIPE_X_SRC_2_MAP_ADDR MAX96724_MAP_SRC_L(0,2)
#define MAX96724_PIPE_X_DST_2_MAP_ADDR MAX96724_MAP_DST_L(0,2)
#define MAX96724_PIPE_X_PHY_DEST_2_MAP_ADDR MAX96724_MAP_PHY_DEST(0,2)
#define MAX96724_PIPE_X_SRCDST_VC_EXT_2_MAP_ADDR MAX96724_MAP_SRCDST_H(0,2)
#define MAX96724_PIPE_X_SRC_3_MAP_ADDR MAX96724_MAP_SRC_L(0,3)
#define MAX96724_PIPE_X_DST_3_MAP_ADDR MAX96724_MAP_DST_L(0,3)
#define MAX96724_PIPE_X_PHY_DEST_3_MAP_ADDR MAX96724_MAP_PHY_DEST(0,3)
#define MAX96724_PIPE_X_SRCDST_VC_EXT_3_MAP_ADDR MAX96724_MAP_SRCDST_H(0,3)
#define MAX96724_MAP_SRC_L_VC_FIELD GENMASK(7, 6)
#define MAX96724_MAP_SRC_L_DT_FIELD GENMASK(5, 0)
#define MAX96724_MAP_DST_L_VC_FIELD GENMASK(7, 6)
#define MAX96724_MAP_DST_L_DT_FIELD GENMASK(5, 0)

/* Video Pipe X to alternative memory Mapping */
#define MAX96724_PIPE_X_ALT_MEM_ADDR MAX96724_MIPI_TX_ALT_MEM(0)
#define MAX96724_MIPI_TX_ALT_MEM_FIELD GENMASK(4, 0)
#define MAX96724_MIPI_TX_ALT_MEM_8BPP BIT(1)
#define MAX96724_MIPI_TX_ALT_MEM_10BPP BIT(2)
#define MAX96724_MIPI_TX_ALT_MEM_12BPP BIT(0)
#define MAX96724_MIPI_TX_ALT_MEM_24BPP BIT(3)
#define MAX96724_MIPI_TX_ALT2_MEM_8BPP BIT(4)

/* Video Pipe X to PHY Mapping */
#define MAX96724_PIPE_X_SRCDST_0_MAP_ADDR MAX96724_MAP_SRCDST_H(0,0)
#define MAX96724_PIPE_X_SRCDST_1_MAP_ADDR MAX96724_MAP_SRCDST_H(0,1)
#define MAX96724_PIPE_X_SRCDST_2_MAP_ADDR MAX96724_MAP_SRCDST_H(0,2)
#define MAX96724_PIPE_X_SRCDST_3_MAP_ADDR MAX96724_MAP_SRCDST_H(0,3)
#define MAX96724_MAP_SRCDST_H_SRC_VC_FIELD GENMASK(7, 5)
#define MAX96724_MAP_SRCDST_H_DST_VC_FIELD GENMASK(4, 2)

#define MAX96724_VID_RX0_ADDR 0x0100
#define MAX96724_VID_RX0(pipe) (MAX96724_VID_RX0_ADDR + (0x12 * (pipe)))
#define MAX96724_VID_RX6_ADDR 0x0106
#define MAX96724_VID_RX6(pipe) (MAX96724_VID_RX6_ADDR + (0x12 * (pipe)))
#define MAX96724_VID_RX8_ADDR 0x0108
#define MAX96724_VID_STATUS_ADDR(pipe) (MAX96724_VID_RX8_ADDR + (0x12 * (pipe)))
#define MAX96724_VID_LOCK_BIT BIT(6)

#define MAX96724_PIPE_DE_STATUS_ADDR 0x11F0
#define MAX96724_PIPE_HS_STATUS_ADDR 0x11F1
#define MAX96724_PIPE_VS_STATUS_ADDR 0x11F2

#define MAX96724_PIPE_X_ST_SEL_ADDR 0x0050

/* Video Pipe Input Source Selection
 * This tells MAX96724 which PHY (Link) feeds which Video Pipe.
 * Without this, video data cannot flow from GMSL links to CSI-2 output.
 *
 * REG 0x00F0: Video Pipe 0/1 input selection
 *   Bit[7:6] = 01: Pipe 1 from GMSL B link
 *   Bit[5:4] = 10: Pipe 1 uses internal Pipe X
 *   Bit[3:2] = 00: Pipe 0 from GMSL A link
 *   Bit[1:0] = 10: Pipe 0 uses internal Pipe X
 *   Value: 0xF0
 *
 * REG 0x00F1: Video Pipe 2/3 input selection
 *   Bit[7:6] = 11: Pipe 3 from GMSL D link
 *   Bit[5:4] = 10: Pipe 3 uses internal Pipe X
 *   Bit[3:2] = 10: Pipe 2 from GMSL C link
 *   Bit[1:0] = 10: Pipe 2 uses internal Pipe X
 *   Value: 0xEA
 *
 * REG 0x00F4: Enable all Video Pipes
 *   Bit[3:0] = 1111: Enable Pipe 3/2/1/0
 *   Value: 0x0F
 */
#define MAX96724_VIDEO_PIPE_SEL_0_ADDR 0x00F0  /* Pipe 0/1 input: GMSL A/B */
#define MAX96724_VIDEO_PIPE_SEL_1_ADDR 0x00F1  /* Pipe 2/3 input: GMSL C/D */
#define MAX96724_VIDEO_PIPE_EN_ADDR    0x00F4  /* Enable Video Pipes */
#define MAX96724_VIDEO_PIPE_SEL(pipe) (MAX96724_VIDEO_PIPE_SEL_0_ADDR + ((pipe) / 2))
#define MAX96724_VIDEO_PIPE_SEL_LINK_FIELD(link) GENMASK(1, 0) << (MAX96724_FLD_OFS(link, 4, 2) + 2)
#define MAX96724_VIDEO_PIPE_SEL_INPUT_FIELD(link) GENMASK(1, 0) << (MAX96724_FLD_OFS(link, 4, 2) + 0)
#define MAX96724_VIDEO_PIPE_EN(pipe) (MAX96724_VIDEO_PIPE_EN_ADDR)
#define MAX96724_VIDEO_PIPE_EN_FIELD(pipe) BIT(pipe)
#define MAX96724_VIDEO_PIPE_STREAM_SEL_ALL_FIELD BIT(4)
#define MAX96724_VIDEO_PIPE_LEGACY_MODE 0U
#define MAX96724_VIDEO_PIPE_SRCMAP_MODE 1U

/* MIPI CSI-2 PHY Configuration */
#define MAX96724_PHY_RATE_CTRL_ADDR MAX96724_REG10_ADDR
#define MAX96724_PHY_RATE_CTRL(link) (MAX96724_PHY_RATE_CTRL_ADDR + ((link) / 2))
#define MAX96724_PHY_RATE_CTRL_TX_FIELD(link) GENMASK(1, 0) << (MAX96724_FLD_OFS(link, 4, 2) + 2)
#define MAX96724_PHY_RATE_CTRL_RX_FIELD(link) GENMASK(1, 0) << (MAX96724_FLD_OFS(link, 4, 2) + 0)
#define MAX96724_PHY_RATE_CTRL_TX_6GBPS 0x10
#define MAX96724_PHY_RATE_CTRL_TX_3GBPS 0x01

#define MAX96724_BACKTOP1_ADDR 0x0400
#define MAX96724_DPLL_STATUS_ADDR MAX96724_BACKTOP1_ADDR
#define MAX96724_DPLL_STATUS_FIELD(phy) BIT(phy) << 4

#define MAX96724_BACKTOP22_ADDR 0x0415
#define MAX96724_DPLL_FREQ(phy) (MAX96724_BACKTOP22_ADDR + ((phy) * 3))
#define MAX96724_PHY0_CLK_ADDR MAX96724_DPLL_FREQ(0)
#define MAX96724_PHY1_CLK_ADDR MAX96724_DPLL_FREQ(1)
#define MAX96724_PHY2_CLK_ADDR MAX96724_DPLL_FREQ(3)
#define MAX96724_PHY3_CLK_ADDR MAX96724_DPLL_FREQ(3)
#define MAX96724_DPLL_FREQ_FIELD GENMASK(4, 0)

#define MAX96724_BACKTOP12_ADDR 0x040B
#define MAX96724_CSI_OUT_EN_ADDR MAX96724_BACKTOP12_ADDR
#define MAX96724_CSI_OUT_EN_FIELD BIT(1)

#define MAX96724_DPLL_RESET(phy) (0x1C00 + ((phy) * 0x100))
#define MAX96724_DPLL_RESET_SOFT_RST_FIELD BIT(0)

#define MAX96724_MIPI_PHY0 0x08A0
#define MAX96724_MIPI_PHY0_MODE_FIELD GENMASK(4, 0)
#define MAX96724_MIPI_PHY0_CLK_SEL_EN_FIELD(csi) BIT((csi) / 2)
#define MAX96724_MIPI_PHY0_CLK_FORCE_EN_FIELD BIT(7)

#define MAX96724_MIPI_PHY2 0x08A2
#define MAX96724_MIPI_PHY_ENABLE MAX96724_MIPI_PHY2
#define MAX96724_PWDN_PHYS_ADDR MAX96724_MIPI_PHY_ENABLE
#define MAX96724_MIPI_PHY_ENABLE_FIELD(csi) BIT((csi) + 4)

#define MAX96724_MIPI_PHY3 0x08A3
#define MAX96724_MIPI_PHY_LANE_MAP(csi) (MAX96724_MIPI_PHY3 + (csi) / 2)
#define MAX96724_MIPI_PHY_LANE_MAP_FIELD(csi, lane) \
	(GENMASK(1, 0) << (MAX96724_FLD_OFS(csi, 4, 2) + MAX96724_FLD_OFS(lane, 2, 2)))

#define MAX96724_MIPI_PHY5 0x08A5
#define MAX96724_MIPI_PHY13 0x08AD
#define MAX96724_CPHY_PREAMBLE_ADDR MAX96724_MIPI_PHY13
#define MAX96724_CPHY_PREAMBLE_FIELD GENMASK(5, 0)

#define MAX96724_MIPI_PHY14 0x08AE
#define MAX96724_CPHY_PREP_ADDR MAX96724_MIPI_PHY14
#define MAX96724_CPHY_PREP_LENGTH_FIELD GENMASK(1, 0)
#define MAX96724_CPHY_POST_TIMING_FIELD GENMASK(6, 2)

/* GPIO Configuration Registers */

#define MAX96724_GPIO_REG(n) (0x0300 + (3 * n))
#define MAX96724_GPIO_RES_CFG BIT(7)
#define MAX96724_GPIO_TX_ENABLE BIT(1)
#define MAX96724_GPIO_OUTDRV_DISABLE BIT(0)
#define MAX96724_GPIO_PUSH_PULL BIT(5)
#define MAX96724_GPIO_A_REG(n) (MAX96724_GPIO_REG(n) + 1)
#define MAX96724_GPIO_B_REG(n) \
	((n <= 2) ? (0x0337 + 3 * n) : (n <= 7) ? (0x341 + 3 * (n - 3)) \
	: (0x351 + 3 * (n - 8)))
#define MAX96724_GPIO_C_REG(n) \
	((n == 0) ? (0x036D) : (n <= 5) ? (0x371 + 3 * (n - 1)) \
	: (0x381 + 3 * (n - 6)))
#define MAX96724_GPIO_D_REG(n) \
	((n <= 3) ? (0x03A4 + 3 * n) : (n <= 8) ? (0x3B1 + 3 * (n - 4)) \
	: (0x3C1 + 3 * (n - 9)))

/* According to MAX96724 spec:
 *   GPIO7_A (RES_CFG, TX_PRIO, TX_COMP_EN, GPIO_OUT, GPIO_IN, GPIO_RX_EN, GPIO_TX_EN, GPIO_OUT_DIS)
 *   GPIO7_B (PULL_UPDN_SEL[1:0], GPIO_TX_ID[4:0])
 *   GPIO7_C (OVR_RES_CFG, GPIO_RX_ID[4:0])
 * These are GPIO configuration registers, NOT CSI mode or lane mapping registers.
 */
#define MAX96724_GPIO5_A MAX96724_GPIO_A_REG(5)
#define MAX96724_GPIO5_B MAX96724_GPIO_B_REG(5)
#define MAX96724_GPIO5_C MAX96724_GPIO_C_REG(5)
#define MAX96724_GPIO6_A MAX96724_GPIO_A_REG(6)

#define MAX96724_GPIO7_C MAX96724_GPIO_C_REG(7)

#define MAX96712_GPIO7_C 0x0318
/* GPIO Configuration Registers */
#define MAX96712_GPIO15_A 0x0330  /* GPIO15_A: RES_CFG, TX_PRIO, TX_COMP_EN, GPIO_OUT, GPIO_IN, GPIO_RX_EN, GPIO_TX_EN, GPIO_OUT_DIS */
#define MAX96712_GPIO15_B 0x0331  /* GPIO15_B: PULL_UPDN_SEL[1:0], GPIO_TX_ID[4:0] */
#define MAX96712_GPIO15_C 0x0332  /* GPIO15_C: OVR_RES_CFG, GPIO_RX_ID[4:0] */
#define MAX96712_GPIO16_A 0x0333  /* GPIO16_A: RES_CFG, TX_PRIO, TX_COMP_EN, GPIO_OUT, GPIO_IN, GPIO_RX_EN, GPIO_TX_EN, GPIO_OUT_DIS */

#define MAX96724_CTRL1_ADDR MAX96724_REG18_ADDR

/* data defines */

#define MAX96724_ALLPHYS_NOSTDBY 0xF0
#define MAX96724_ST_ID_SEL_INVALID 0xF

#define MAX96724_CPHY_PREAMBLE_DEFAULT 0x1f
#define MAX96724_CPHY_PREP_DEFAULT 0x5d

// write 0x20 for 1500Mbps/lane on CSI2 controller & CPHY
#define MAX96724_CPHY_CLK_1500BPS 0x20
// write 0x2f for 1500Mbps/lane on CSI2 controller & DPHY
#define MAX96724_DPHY_CLK_1500BPS 0x2F

#define MAX96724_RESET_ALL 0x80

/* MAX96724 Quad GMSL Deserializer:
 * - 4 GMSL input links (Link A/B/C/D from serializers)
 * - 4 video pipelines (Pipe X/Y/Z/U)
 * - 2 CSI-2 output controllers (2x4-lane or 4x2-lane modes)
 */
#define MAX96724_MAX_SOURCES 4
#define MAX96724_NUM_CSI_LINKS 4
#define MAX96724_MAX_PIPES 4

#define MAX96724_DEFAULT_SER_ADDR_A 0x28
#define MAX96724_DEFAULT_SER_ADDR_B 0x2A
#define MAX96724_RESET_DELAY_MS 100

#define MAX96724_PIPE_X 0
#define MAX96724_PIPE_Y 1
#define MAX96724_PIPE_Z 2
#define MAX96724_PIPE_U 3
#define MAX96724_PIPE_INVALID 0xF

/* CSI Controller IDs (not register addresses) */
#define MAX96724_CSI_CTRL_ID_0 0
#define MAX96724_CSI_CTRL_ID_1 1
#define MAX96724_CSI_CTRL_ID_2 2
#define MAX96724_CSI_CTRL_ID_3 3

#define MAX96724_INVAL_ST_ID 0xFF

/* Use reset value as per spec, confirm with vendor */
#define MAX96724_RESET_ST_ID 0x00

#define MAX96724_LINK_STATUS(link) ((link) == 0 ? 0x1A : 0x0A + ((link) - 1))
#define MAX96724_LINK_LOCK_BIT BIT(3)

#define MAX96724_GMSL_MODE_REG 0x06
#define MAX96724_GMSL_MODE_PER_LINK_MASK 0x3
#define MAX96724_GMSL_MODE_AUTO 0x0
#define MAX96724_GMSL_MODE_GMSL2 0x1
#define MAX96724_GMSL_MODE_GMSL1 0x2
#define MAX96724_GMSL_MODE_RESERVED 0x3

#define MAX96724_VC_2_BITS 0U
#define MAX96724_VC_4_BITS 1U

// See: Errata for MAX96724/MAX96724F/MAX96724R (Rev. 1) document
//      https://www.analog.com/media/en/technical-documentation/data-sheets/max96724-f-r-rev1-b-0a-errata.pdf
static const struct reg_sequence max96724_errata_rev1[] = {
        // Errata #5 - GMSL2 Link requires register writes for robust 6 Gbps operation
        { 0x1449, 0x75, },
        { 0x1549, 0x75, },
        { 0x1649, 0x75, },
        { 0x1749, 0x75, },
};

enum max96724_rev {
	MAX96724_REV_F = 1,
	MAX96724_REV_R,
};

static const struct reg_sequence max96712_phy_tuning_revABC[] = {
        // PHY A
        { 0x1458, 0x28, },
        { 0x1459, 0x68, },
        { 0x143E, 0xB3, },
        { 0x143F, 0x72, },
        // PHY B
        { 0x1558, 0x28, },
        { 0x1559, 0x68, },
        { 0x153E, 0xB3, },
        { 0x153F, 0x72, },
        // PHY C
        { 0x1658, 0x28, },
        { 0x1659, 0x68, },
        { 0x163E, 0xB3, },
        { 0x163F, 0x72, },
        // PHY D
        { 0x1758, 0x28, },
        { 0x1759, 0x68, },
        { 0x173E, 0xB3, },
        { 0x173F, 0x72, },
};

static const struct reg_sequence max96712_phy_tuning_revE[] = {
        // Increase CMU regulator output voltage (bit 4)
        { 0x06C2, 0x10, },
        // Set VgaHiGain_Init_6G (bit 1) and VgaHiGain_Init_3G (bit 0)* for PHY A/B/C/D
        { 0x14D1, 0x03, },
        { 0x15D1, 0x03, },
        { 0x16D1, 0x03, },
        { 0x17D1, 0x03, },
};

enum max96712_rev {
        MAX96712_REV_A = 1,
        MAX96712_REV_B,
        MAX96712_REV_C,
        MAX96712_REV_D,
        MAX96712_REV_E,
};

/* Log all register writes */
#define  MAX96724_WRITE_REG(map, reg, val) \
({ \
        int __ret; \
        struct regmap *__map = (map); \
        unsigned int __reg = (reg); \
        unsigned int __val = (val); \
        dev_dbg(regmap_get_device(__map), "REG_WRITE: [0x%04X] = 0x%02X", __reg, __val); \
        __ret = regmap_write(__map, __reg, __val); \
        if (__ret) \
                dev_err(regmap_get_device(__map), "REG_WRITE FAILED: [0x%04X] = 0x%02X, ret=%d", __reg, __val, __ret); \
        __ret; \
})

/* Log register update_bits (read-modify-write) */
#define  MAX96724_UPDATE_BITS(map, reg, mask, val) \
({ \
        int __ret; \
        struct regmap *__map = (map); \
        unsigned int __reg = (reg); \
        unsigned int __mask = (mask); \
        unsigned int __val = (val); \
        unsigned int __old_val = 0; \
        unsigned int __new_val = 0; \
        regmap_read(__map, __reg, &__old_val); \
        __new_val = (__old_val & ~__mask) | (__val & __mask); \
        dev_dbg(regmap_get_device(__map), "REG_UPDATE_BITS: [0x%04X] mask=0x%02X, old=0x%02X, new=0x%02X (val=0x%02X)", \
                __reg, __mask, __old_val, __new_val, __val); \
        __ret = regmap_update_bits(__map, __reg, __mask, __val); \
        if (__ret) \
                dev_err(regmap_get_device(__map), "REG_UPDATE_BITS FAILED: [0x%04X] mask=0x%02X val=0x%02X, ret=%d", \
                        __reg, __mask, __val, __ret); \
        __ret; \
})

struct max96724_source_ctx {
	struct gmsl_link_ctx *g_ctx;
	bool st_enabled;
};

struct pipe_ctx {
	u32 id;
	u32 dt_type;
	u32 dst_csi_ctrl;
	u32 st_count;
	u32 st_id_sel;
};

struct max96724 {
	struct i2c_client *i2c_client;
	struct regmap *regmap;
	u32 num_src;
	u32 max_src;
	u32 num_src_found;
	u32 src_link;
	bool splitter_enabled;
	struct max96724_source_ctx sources[MAX96724_MAX_SOURCES];
	struct mutex lock;
	u32 sdev_ref;
	bool lane_setup;
	bool link_setup;
	struct pipe_ctx pipe[MAX96724_MAX_PIPES];
	u8 csi_mode;
	int reset_gpio;
	int pw_ref;
	struct regulator *vdd_cam_1v2;
	__u32 d4xx_hacks;
	u32 dev_id;
	u32 dst_link;
	u8 csi_phy;
	u8 dst_n_lanes;
};

static int max96724_read_reg(struct device *dev,
	u16 addr, unsigned int *val)
{
	struct max96724 *priv;
	int err;

	priv = dev_get_drvdata(dev);

	err = regmap_read(priv->regmap, addr, val);
	if (err)
		dev_err(dev,
		"%s:i2c read failed, 0x%x\n",
		__func__, addr);

	return err;
}

static int max96724_write_reg(struct device *dev,
	u16 addr, u8 val)
{
	struct max96724 *priv;
	int err;

	priv = dev_get_drvdata(dev);

	err = MAX96724_WRITE_REG(priv->regmap, addr, val);
	if (err)
		dev_err(dev,
		"%s:i2c write failed, 0x%x = %x\n",
		__func__, addr, val);

	/* delay before next i2c command as required for SERDES link */
	usleep_range(100, 110);

	return err;
}

static int max96724_get_sdev_idx(struct device *dev,
			struct device *s_dev, unsigned int *idx)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	unsigned int i;
	int err = 0;

	mutex_lock(&priv->lock);
	for (i = 0; i < priv->max_src; i++) {
		if (priv->sources[i].g_ctx->s_dev == s_dev)
			break;
	}
	if (i == priv->max_src) {
		dev_err(dev, "no sdev found\n");
		err = -EINVAL;
		goto ret;
	}

	if (idx)
		*idx = i;

ret:
	mutex_unlock(&priv->lock);
	return err;
}

static void max96724_pipes_reset(struct max96724 *priv)
{
	/*
	 * This is default pipes combination. add more mappings
	 * for other combinations and requirements.
	 */
	struct pipe_ctx pipe_defaults[] = {
		{MAX96724_PIPE_X, GMSL_CSI_DT_RAW_12,
			MAX96724_CSI_CTRL_ID_1, 0, MAX96724_INVAL_ST_ID},
		{MAX96724_PIPE_Y, GMSL_CSI_DT_RAW_12,
			MAX96724_CSI_CTRL_ID_1, 0, MAX96724_INVAL_ST_ID},
		{MAX96724_PIPE_Z, GMSL_CSI_DT_EMBED,
			MAX96724_CSI_CTRL_ID_1, 0, MAX96724_INVAL_ST_ID},
		{MAX96724_PIPE_U, GMSL_CSI_DT_EMBED,
			MAX96724_CSI_CTRL_ID_1, 0, MAX96724_INVAL_ST_ID}
	};

	/*
	 * Add DT props for num-streams and stream sequence, and based on that
	 * set the appropriate pipes defaults.
	 * For now default it supports "2 RAW12 and 2 EMBED" 1:1 mappings.
	 */
	memcpy(priv->pipe, pipe_defaults, sizeof(pipe_defaults));
}

static void max96724_reset_ctx(struct max96724 *priv)
{
	unsigned int i;

	priv->link_setup = false;
	priv->lane_setup = false;
	priv->num_src_found = 0;
	priv->src_link = 0;
	priv->dst_link = 0;
	priv->dst_n_lanes = 2;
	priv->splitter_enabled = false;
	max96724_pipes_reset(priv);
	for (i = 0; i < priv->num_src; i++)
		priv->sources[i].st_enabled = false;
}

int max96724_power_on(struct device *dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	int err = 0;

	mutex_lock(&priv->lock);
	if (priv->pw_ref == 0) {
		usleep_range(1, 2);
		if (priv->reset_gpio)
			gpio_set_value(priv->reset_gpio, 0);

		usleep_range(30, 50);

		if (priv->vdd_cam_1v2) {
			err = regulator_enable(priv->vdd_cam_1v2);
			if (unlikely(err))
				goto ret;
		}

		usleep_range(30, 50);

		/*exit reset mode: XCLR */
		if (priv->reset_gpio) {
			gpio_set_value(priv->reset_gpio, 0);
			usleep_range(30, 50);
			gpio_set_value(priv->reset_gpio, 1);
			usleep_range(30, 50);
		}

		/* delay to settle reset */
		msleep(20);
	}

	priv->pw_ref++;

ret:
	mutex_unlock(&priv->lock);

	return err;
}
EXPORT_SYMBOL(max96724_power_on);

void max96724_power_off(struct device *dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);

	mutex_lock(&priv->lock);
	priv->pw_ref--;

	if (priv->pw_ref < 0)
		priv->pw_ref = 0;

	if (priv->pw_ref == 0) {
		/* enter reset mode: XCLR */
		usleep_range(1, 2);
		if (priv->reset_gpio)
			gpio_set_value(priv->reset_gpio, 0);

		if (priv->vdd_cam_1v2)
			regulator_disable(priv->vdd_cam_1v2);
	}

	mutex_unlock(&priv->lock);
}
EXPORT_SYMBOL(max96724_power_off);

static const char *max96724_get_link_name(u32 link)
{
	switch (link) {
	case GMSL_SERDES_CSI_LINK_A:
		return "GMSL A";
	case GMSL_SERDES_CSI_LINK_B:
		return "GMSL B";
	case GMSL_SERDES_CSI_LINK_C:
		return "GMSL C";
	case GMSL_SERDES_CSI_LINK_D:
		return "GMSL D";
	default:
		return "GMSL UNKNOWN";
	}
}

static u8 max96724_link_to_port(u32 link)
{
	switch (link) {
	case GMSL_SERDES_CSI_LINK_B:
		return 1;
	case GMSL_SERDES_CSI_LINK_C:
		return 2;
	case GMSL_SERDES_CSI_LINK_D:
		return 3;
	case GMSL_SERDES_CSI_LINK_A:
	default:
		return 0;
	}
}


/* CRITICAL: max96724_check_status wait for sensor video to stabilize before enabling CSI output!
 *   1. Triggers all cameras via GPIO (MFP7/MFP8)
 *   2. sleep 0.3  ← 300ms delay to let sensors stabilize!
 *   3. i2ctransfer ... 0x04 0x0b 0x02  ← Enable CSI
 *   4. i2ctransfer ... 0x08 0xa0 0x84  ← Enable continuous clock
 *
 * Without this delay, deserializer tries to lock video before sensor
 * outputs stable video data, resulting in VIDEO_LOCK failure (0x0108=0x02)
 */
int max96724_check_status(struct device *dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	int err = 0;
	u8 src_port = max96724_link_to_port(priv->src_link);

	mutex_lock(&priv->lock);

	dev_info(dev, "%s: Wake-up %s CSI %u %s mode %s (num_lanes:x%u)\n",
		__func__,
		max96724_get_link_name(priv->src_link),
		priv->dst_link,
		priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
		priv->csi_mode == MAX96724_CSI_MODE_1X4 || MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2",
		priv->dst_n_lanes);

	/* Enable MIPI TX controller and enable PHY CLK cycle */
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_MIPI_TX_LANE_CNT(priv->dst_link),
		MAX96724_MIPI_TX_WAKEUP_CYC_FIELD,
		MAX96724_FIELD_PREP(MAX96724_MIPI_TX_WAKEUP_CYC_FIELD, 1U));
	if (err) {
		dev_err(dev, "%s: Failed to configure CSI %u %s wakeup cycles: %d\n",
			__func__,
			priv->dst_link,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			err);
	}

	// enable CSI out link after initialization complet
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_CSI_OUT_EN_ADDR,
		MAX96724_CSI_OUT_EN_FIELD,
		MAX96724_FIELD_PREP(MAX96724_CSI_OUT_EN_FIELD, 1U));
	if (err) {
		dev_err(dev, "%s: Failed to enable csi output link: %d\n",
			__func__,
			err);
	}

	/* Turn on MIPI PHY continuous clock mode (matches script line 520)
	 * Reference script does this AFTER CSI enable (0x040B = 0x02)
	 * This enables continuous clock on MIPI CSI-2 interface
	 * 0x84 = 0b10000100
	 *   Bit[7] = 1: Enable continuous clock mode
	 */
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_MIPI_PHY0,
		MAX96724_MIPI_PHY0_CLK_FORCE_EN_FIELD,
		MAX96724_FIELD_PREP(MAX96724_MIPI_PHY0_CLK_FORCE_EN_FIELD, 1U));
	if (err)
		dev_err(dev, "%s: Failed to enable %s %s continuous clock  : %d\n",
			__func__,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			priv->csi_mode == MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2",
			err);
	else
		dev_dbg(dev, "%s: %s CSI %u %s %s (num_lanes:x%u) continuous clock mode enabled\n",
			__func__,
			max96724_get_link_name(priv->src_link),
			priv->dst_link,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			priv->csi_mode == MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2",
			priv->dst_n_lanes);

	/* Re-Check GMSL link status after initial configuration */
	{
		unsigned int link_status = 0;
		max96724_read_reg(dev, MAX96724_LINK_STATUS(src_port), &link_status);
		dev_dbg(dev, "%s: %s Link status: 0x%02x (LOCK=%d, bit0-7: %s%s%s%s%s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), link_status, !!(link_status & MAX96724_LINK_LOCK_BIT),
			(link_status & 0x01) ? "VID_LOCK " : "",
			(link_status & 0x02) ? "CONFIG_DETECT " : "",
			(link_status & 0x04) ? "VIDEO_DETECT " : "",
			(link_status & 0x08) ? "LOCK " : "",
			(link_status & 0x10) ? "ERROR " : "",
			(link_status & 0x20) ? "bit5 " : "",
			(link_status & 0x40) ? "bit6 " : "",
			(link_status & 0x80) ? "LOCKED " : "");
		unsigned int pll_status = 0;
		max96724_read_reg(dev, MAX96724_DPLL_STATUS_ADDR, &pll_status);
		dev_dbg(dev, "%s: %s DPLL status: 0x%02x (bit0-7: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pll_status,
			(pll_status & MAX96724_DPLL_STATUS_FIELD(0)) ? "CSIPLL0_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(1)) ? "CSIPLL1_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(2)) ? "CSIPLL2_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(3)) ? "CSIPLL3_LOCK " : "");
		unsigned int vid_status = 0;
		max96724_read_reg(dev, MAX96724_VID_STATUS_ADDR(src_port), &vid_status);
		dev_dbg(dev, "%s: %s Video RX status: 0x%02x (LOCK=%d, bit4-6: %s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), vid_status, !!(link_status & MAX96724_VID_LOCK_BIT),
			(vid_status & 0x40) ? "VID_LOCK " : "",
			(vid_status & 0x20) ? "VID_PKT_DET " : "",
			(vid_status & 0x10) ? "VID_SEQ_ERR " : "");
		unsigned int pipe_de_status = 0, pipe_hs_status = 0, pipe_vs_status = 0;
		max96724_read_reg(dev, MAX96724_PIPE_DE_STATUS_ADDR, &pipe_de_status);
		dev_dbg(dev, "%s: %s Video Pipeline DE status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_de_status,
			(pipe_de_status & 0x01) ? "DE_DET_0 " : "",
			(pipe_de_status & 0x02) ? "DE_DET_1 " : "",
			(pipe_de_status & 0x04) ? "DE_DET_2 " : "",
			(pipe_de_status & 0x08) ? "DE_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_HS_STATUS_ADDR, &pipe_hs_status);
		dev_dbg(dev, "%s: %s Video Pipeline HS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_hs_status,
			(pipe_hs_status & 0x01) ? "HS_DET_0 " : "",
			(pipe_hs_status & 0x02) ? "HS_DET_1 " : "",
			(pipe_hs_status & 0x04) ? "HS_DET_2 " : "",
			(pipe_hs_status & 0x08) ? "HS_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_VS_STATUS_ADDR, &pipe_vs_status);
		dev_dbg(dev, "%s: %s Video Pipeline VS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_vs_status,
			(pipe_vs_status & 0x01) ? "VS_DET_0 " : "",
			(pipe_vs_status & 0x02) ? "VS_DET_1 " : "",
			(pipe_vs_status & 0x04) ? "VS_DET_2 " : "",
			(pipe_vs_status & 0x08) ? "VS_DET_3 " : "");
	}

	mutex_unlock(&priv->lock);

	return err;
}
EXPORT_SYMBOL(max96724_check_status);

int max96724_set_mfp(struct device *dev, int pin, int val)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	struct regmap *map = priv->regmap;
	int err;

	if (pin > 10)
		return -EINVAL;

	err = MAX96724_UPDATE_BITS(map, MAX96724_GPIO_REG(pin),
		(1<<4 | 1<<2 | 1<<0),
		((val ? 1<<4 : 0) | 0<<2 | 0<<0) );

	err |= MAX96724_UPDATE_BITS(map, MAX96724_GPIO_REG(pin),
		3<<6|1<<5,
		1<<6|1<<5);

	return err;

}
EXPORT_SYMBOL(max96724_set_mfp);

static int max967xx_phy_tuning(struct device *dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	struct regmap *map = priv->regmap;
	int ret;
	unsigned rev = 0;

	if (priv->dev_id == MAX96724_DEV_REV_ID) {

		ret = regmap_read(map, MAX967XX_DEV_REV_ADDR, &rev);
		ret |= regmap_multi_reg_write(map,
					     max96724_errata_rev1,
					     ARRAY_SIZE(max96724_errata_rev1));

		goto phy_tuning_out;
	}

	ret = regmap_read(map, MAX967XX_DEV_REV_ADDR, &rev);
	switch (FIELD_GET(MAX967XX_DEV_REV_FIELD, rev)) {
		case MAX96712_REV_A:
		case MAX96712_REV_B:
		case MAX96712_REV_C:
			ret |= regmap_multi_reg_write(map,
						     max96712_phy_tuning_revABC,
						     ARRAY_SIZE(max96712_phy_tuning_revABC));
			break;
		case MAX96712_REV_D:
			// No tuning necessary
			break;
		case MAX96712_REV_E:
			ret |= regmap_multi_reg_write(map,
						     max96712_phy_tuning_revE,
						     ARRAY_SIZE(max96712_phy_tuning_revE));
			break;
		default:
			dev_warn(dev, "Unknown chip revision");
			break;
	}

phy_tuning_out:
	dev_dbg(dev, "%s: applying %s (rev %u) CSI %u %s tunning\n",
		 __func__,
		 priv->dev_id == MAX96724_DEV_REV_ID ? "MAX96724" : "MAX96712",
		 rev,
		 priv->dst_link,
		 priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY");
	return ret;
}

static int max96724_write_link(struct device *dev, u32 link)
{
	int ret = -EINVAL;
	int err = 0;
	struct max96724 *priv = dev_get_drvdata(dev);
	int link_id;
	int port;

	port = max96724_link_to_port(link);
	if (port < 0) {
		dev_err(dev, "%s: invalid link 0x%x\n", __func__, link);
		return ret;
	}

	dev_dbg(dev, "%s: write %s link (id=0x%x, idx=%u)\n",
		__func__, max96724_get_link_name(link), port);

	/* Check GMSL link status - hardware auto-negotiation should have completed */
	{
		int i;
		unsigned int link_status = 0;
		for (i = 0; i < MAX96724_MAX_SOURCES; i++) {
			max96724_read_reg(dev, MAX96724_LINK_STATUS(i), &link_status);
			dev_dbg(dev, "%s: GMSL %c 6Gbps link status: 0x%02x (LOCK=%d, bit0-7: %s%s%s%s%s%s%s%s)\n",
				__func__, 'A' + i , link_status, !!(link_status & MAX96724_LINK_LOCK_BIT),
				(link_status & 0x01) ? "VID_LOCK " : "",
				(link_status & 0x02) ? "CONFIG_DETECT " : "",
				(link_status & 0x04) ? "VIDEO_DETECT " : "",
				(link_status & 0x08) ? "LOCK " : "",
				(link_status & 0x10) ? "ERROR " : "",
				(link_status & 0x20) ? "bit5 " : "",
				(link_status & 0x40) ? "bit6 " : "",
				(link_status & 0x80) ? "LOCKED " : "");
		}
	}
	ret = 0;

write_link_out:
	return ret;
}

int max96724_setup_link(struct device *dev, struct device *s_dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	int err = 0;
	unsigned int i = 0;

	dev_dbg(dev, "%s: ENTER\n", __func__);

	err = max96724_get_sdev_idx(dev, s_dev, &i);
	if (err) {
		dev_err(dev, "%s: Failed to get sdev_idx: %d\n", __func__, err);
		return err;
	}

	dev_info(dev, "%s: Source index=%d, link=%s\n", __func__, i,
		 max96724_get_link_name(priv->sources[i].g_ctx->serdes_csi_link));

	mutex_lock(&priv->lock);

	if (!priv->splitter_enabled) {
		err = max96724_write_link(dev,
				priv->sources[i].g_ctx->serdes_csi_link);
		if (err)
			goto ret;

		priv->link_setup = true;
	}

ret:
	mutex_unlock(&priv->lock);

	return err;
}
EXPORT_SYMBOL(max96724_setup_link);

int max96724_setup_control(struct device *dev, struct device *s_dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	int err = 0;
	unsigned int i = 0;

	u8 src_port;

	dev_dbg(dev, "%s: ENTER\n", __func__);

	err = max96724_get_sdev_idx(dev, s_dev, &i);
	if (err) {
		dev_err(dev, "%s: Failed to get sdev_idx: %d\n", __func__, err);
		return err;
	}

	mutex_lock(&priv->lock);

	if (!priv->link_setup) {
		dev_err(dev, "%s: invalid state\n", __func__);
		err = -EINVAL;
		goto error;
	}

	if (priv->sources[i].g_ctx->serdev_found) {
		priv->num_src_found++;
		priv->src_link = priv->sources[i].g_ctx->serdes_csi_link;
		priv->dst_link = priv->sources[i].g_ctx->dst_csi_port;
		src_port = max96724_link_to_port(priv->src_link);
		priv->dst_n_lanes = priv->sources[i].g_ctx->num_csi_lanes;

		/* Check GMSL link status - hardware auto-negotiation should have completed */
		{
			unsigned int link_status = 0;
			max96724_read_reg(dev, MAX96724_LINK_STATUS(src_port), &link_status);
			dev_dbg(dev, "%s: %s Link status: 0x%02x (LOCK=%d, bit0-7: %s%s%s%s%s%s%s%s)\n",
				__func__, max96724_get_link_name(priv->src_link), link_status, !!(link_status & MAX96724_LINK_LOCK_BIT),
				 (link_status & 0x01) ? "VID_LOCK " : "",
				 (link_status & 0x02) ? "CONFIG_DETECT " : "",
				 (link_status & 0x04) ? "VIDEO_DETECT " : "",
				 (link_status & 0x08) ? "LOCK " : "",
				 (link_status & 0x10) ? "ERROR " : "",
				 (link_status & 0x20) ? "bit5 " : "",
				 (link_status & 0x40) ? "bit6 " : "",
				 (link_status & 0x80) ? "LOCKED " : "");
		}
	}

	/* Enable splitter mode */
	if ((priv->max_src > 1U) &&
		(priv->num_src_found > 0U) &&
		(priv->splitter_enabled == false)) {

		//Fetch and output chip name
		unsigned int dev_id = 0;
		err = max96724_read_reg(dev, MAX967XX_DEV_ID_ADDR, &dev_id);
		if (err) {
			dev_warn(dev, "%s(): Failed to read Serdes chip ID", __func__);
			dev_id = MAX96724_DEV_REV_ID;  // fallback max96724
		}
		priv->dev_id = dev_id;

		dev_dbg(dev, "%s: set %s SerDes GMSL A & B & C & D quad-link)\n",
			__func__,
			priv->dev_id == MAX96724_DEV_REV_ID ? "MAX96724" : "MAX96712");

		priv->splitter_enabled = true;

		dev_dbg(dev, "%s: reset %s link done\n",
			__func__,
			max96724_get_link_name(priv->src_link));
	}

	//max96724_write_reg(dev,
	//		MAX96724_PWDN_PHYS_ADDR, MAX96724_ALLPHYS_NOSTDBY);

	priv->sdev_ref++;

	dev_dbg(dev, "%s:  checking serializer sources (count/ref=%d/%d -> src[%d]=%s)\n",
		 __func__,
		 priv->num_src_found,
		 priv->sdev_ref, i,
		 max96724_get_link_name(priv->sources[i].g_ctx->serdes_csi_link));

	/* Reset splitter mode if all devices are not found */
	if ((priv->sdev_ref == priv->max_src) &&
		(priv->splitter_enabled == true) &&
		(priv->num_src_found > 0U) &&
		(priv->num_src_found < priv->max_src)) {
		dev_info(dev, "%s: restore SerDes %s single-link\n",
			 __func__,
			 max96724_get_link_name(priv->src_link));

		/* Only restore link if it's valid (not UNKNOWN) */
		if (priv->src_link != GMSL_SERDES_CSI_LINK_UNKNOWN) {
			err = max96724_write_link(dev, priv->src_link);
			if (err) {
				dev_info(dev, "%s: fail to write source link\n",
					 __func__);
				goto error;
			}
		} else {
			dev_info(dev, "%s: skip restore (src_link is UNKNOWN)\n",
				 __func__);
		}
		priv->splitter_enabled = false;

	} else if (priv->num_src_found < priv->sdev_ref) {

		dev_info(dev, "%s: restore SerDes %s single-link\n",
			 __func__,
			 max96724_get_link_name(priv->src_link));

		/* Only restore link if it's valid (not UNKNOWN) */
		if (priv->src_link != GMSL_SERDES_CSI_LINK_UNKNOWN) {
			err = max96724_write_link(dev, priv->src_link);
			if (err) {
				dev_info(dev, "%s: fail to write source link\n",
					 __func__);
				goto error;
			}
		} else {
			dev_info(dev, "%s: skip restore (src_link is UNKNOWN)\n",
				 __func__);
		}
		priv->splitter_enabled = false;
	}

error:
	mutex_unlock(&priv->lock);
	dev_dbg(dev, "%s: EXIT (err=%d, sdev_ref=%d, num_src_found=%d)\n",
		 __func__, err, priv->sdev_ref, priv->num_src_found);
	return err;
}
EXPORT_SYMBOL(max96724_setup_control);

int max96724_reset_control(struct device *dev, struct device *s_dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);

	mutex_lock(&priv->lock);
	if (!priv->sdev_ref) {
		dev_info(dev, "%s: dev is already in reset state\n", __func__);
		goto ret;
	}

	priv->sdev_ref--;
	if (priv->sdev_ref == 0) {
		max96724_reset_ctx(priv);
		max96724_write_reg(dev, MAX96724_PWR1_ADDR, MAX96724_RESET_ALL);

		/* delay to settle reset */
		msleep(100);
	}

ret:
	mutex_unlock(&priv->lock);

	return 0;
}
EXPORT_SYMBOL(max96724_reset_control);

int max96724_sdev_register(struct device *dev, struct gmsl_link_ctx *g_ctx)
{
	struct max96724 *priv = NULL;
	unsigned int i;
	int err = 0;

	if (!dev || !g_ctx || !g_ctx->s_dev) {
		dev_err(dev, "%s: invalid input params\n", __func__);
		return -EINVAL;
	}

	priv = dev_get_drvdata(dev);

	mutex_lock(&priv->lock);

	if (priv->num_src > priv->max_src) {
		dev_err(dev,
			"%s: MAX96724 inputs size exhausted\n", __func__);
		err = -ENOMEM;
		goto error;
	}

	if (priv->d4xx_hacks) {
		bool csi_mode_ok = false;
		dev_dbg(dev,
			"%s: Checking Deserializer g_ctx->csi_mode=%s\n",
			__func__,
			(g_ctx->csi_mode == GMSL_CSI_4X2_MODE) == GMSL_CSI_4X2_MODE ? "4X2" : "2X4");

		switch (priv->csi_mode) {
		case MAX96724_CSI_MODE_1X4:
			csi_mode_ok = (g_ctx->csi_mode == GMSL_CSI_1X4_MODE);
			break;
		case MAX96724_CSI_MODE_2X4:
			csi_mode_ok = (g_ctx->csi_mode == GMSL_CSI_1X4_MODE) ||
				(g_ctx->csi_mode == GMSL_CSI_2X4_MODE);
			break;
		case MAX96724_CSI_MODE_4X2:
			csi_mode_ok = (g_ctx->csi_mode == GMSL_CSI_4X2_MODE);
			break;
		default:
			csi_mode_ok = false;
			break;
		}

		if (!csi_mode_ok) {
			dev_err(dev,
				"%s: csi mode not supported\n", __func__);
			err = -EINVAL;
			goto error;
		}
		dev_dbg(dev, "%s: d4xx specfic csi-mode set\n", __func__);
	}

	for (i = 0; i < priv->num_src; i++) {
		if (g_ctx->serdes_csi_link ==
			priv->sources[i].g_ctx->serdes_csi_link) {
			dev_err(dev,
				"%s: serdes csi link is in use\n", __func__);
			err = -EINVAL;
			goto error;
		}
		/*
		 * All sdevs should have same num-csi-lanes regardless of
		 * dst csi port selected.
		 * Later if there is any usecase which requires each port
		 * to be configured with different num-csi-lanes, then this
		 * check should be performed per port.
		 */
		if (g_ctx->num_csi_lanes !=
				priv->sources[i].g_ctx->num_csi_lanes) {
			dev_err(dev,
				"%s: csi num lanes mismatch\n", __func__);
			err = -EINVAL;
			goto error;
		}
	}

	priv->sources[priv->num_src].g_ctx = g_ctx;
	priv->sources[priv->num_src].st_enabled = false;

	priv->num_src++;

error:
	mutex_unlock(&priv->lock);
	return err;
}
EXPORT_SYMBOL(max96724_sdev_register);

int max96724_sdev_unregister(struct device *dev, struct device *s_dev)
{
	struct max96724 *priv = NULL;
	int err = 0;
	unsigned int i = 0;

	if (!dev || !s_dev) {
		dev_err(dev, "%s: invalid input params\n", __func__);
		return -EINVAL;
	}

	priv = dev_get_drvdata(dev);
	mutex_lock(&priv->lock);

	if (priv->num_src == 0) {
		dev_err(dev, "%s: no source found\n", __func__);
		err = -ENODATA;
		goto error;
	}

	for (i = 0; i < priv->num_src; i++) {
		if (s_dev == priv->sources[i].g_ctx->s_dev) {
			priv->sources[i].g_ctx = NULL;
			break;
		}
	}

	if (i == priv->num_src) {
		dev_err(dev,
			"%s: requested device not found\n", __func__);
		err = -EINVAL;
		goto error;
	}
	priv->num_src--;

error:
	mutex_unlock(&priv->lock);
	return err;
}
EXPORT_SYMBOL(max96724_sdev_unregister);

static int max96724_get_available_pipe(struct device *dev,
				u32 st_data_type, u32 dst_csi_port)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	int i;

	for (i = 0; i < MAX96724_MAX_PIPES; i++) {
		/*
		 * TODO: Enable a pipe for multi stream configuration having
		 * similar stream data type. For now use st_count as a flag
		 * for 1 to 1 mapping in pipe and stream data type, same can
		 * be extended as count for many to 1 mapping. Would also need
		 * few more checks such as input stream id select, dst port etc.
		 */
		if ((priv->pipe[i].dt_type == st_data_type) &&
			((dst_csi_port == GMSL_CSI_PORT_A) ?
				(priv->pipe[i].dst_csi_ctrl ==
					MAX96724_CSI_CTRL_ID_0) ||
				(priv->pipe[i].dst_csi_ctrl ==
					MAX96724_CSI_CTRL_ID_1) :
				(priv->pipe[i].dst_csi_ctrl ==
					MAX96724_CSI_CTRL_ID_2) ||
				(priv->pipe[i].dst_csi_ctrl ==
					MAX96724_CSI_CTRL_ID_3)) &&
			(!priv->pipe[i].st_count))
			break;
	}

	if (i == MAX96724_MAX_PIPES) {
		dev_err(dev, "%s: all pipes are busy\n", __func__);
		return -ENOMEM;
	}

	return i;
}

struct reg_pair {
	u16 addr;
	u8 val;
};

static int max96724_set_registers(struct device *dev, struct reg_pair *map,
				 u32 count)
{
	int err = 0;
	u32 j = 0;

	for (j = 0; j < count; j++) {
		err = max96724_write_reg(dev,
			map[j].addr, map[j].val);
		if (err != 0)
			break;
	}

	return err;
}

int max96724_get_available_pipe_id(struct device *dev, int vc_id)
{
	int i;
	int pipe_id = -ENOMEM;
	struct max96724 *priv = dev_get_drvdata(dev);

	mutex_lock(&priv->lock);
	for (i = 0; i < MAX96724_MAX_PIPES; i++) {
		if (i == vc_id && !priv->pipe[i].st_count) {
			priv->pipe[i].st_count++;
			pipe_id = i;
			break;
		}
	}
	mutex_unlock(&priv->lock);

	return pipe_id;
}
EXPORT_SYMBOL(max96724_get_available_pipe_id);

int max96724_release_pipe(struct device *dev, int pipe_id)
{
	struct max96724 *priv = dev_get_drvdata(dev);

	if (pipe_id < 0 || pipe_id >= MAX96724_MAX_PIPES)
		return -EINVAL;

	mutex_lock(&priv->lock);
	priv->pipe[pipe_id].st_count = 0;
	mutex_unlock(&priv->lock);

	return 0;
}
EXPORT_SYMBOL(max96724_release_pipe);

void max96724_reset_oneshot(struct device *dev)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	int err = 0;

	u8 src_port = max96724_link_to_port(priv->src_link);

	/* Re-Check GMSL link status after initial configuration */
	{
		unsigned int link_status = 0;
		max96724_read_reg(dev, MAX96724_LINK_STATUS(src_port), &link_status);
		dev_dbg(dev, "%s: %s Link status: 0x%02x (LOCK=%d, bit0-7: %s%s%s%s%s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), link_status, !!(link_status & MAX96724_LINK_LOCK_BIT),
			(link_status & 0x01) ? "VID_LOCK " : "",
			(link_status & 0x02) ? "CONFIG_DETECT " : "",
			(link_status & 0x04) ? "VIDEO_DETECT " : "",
			(link_status & 0x08) ? "LOCK " : "",
			(link_status & 0x10) ? "ERROR " : "",
			(link_status & 0x20) ? "bit5 " : "",
			(link_status & 0x40) ? "bit6 " : "",
			(link_status & 0x80) ? "LOCKED " : "");
		unsigned int pll_status = 0;
		max96724_read_reg(dev, MAX96724_DPLL_STATUS_ADDR, &pll_status);
		dev_dbg(dev, "%s: %s DPLL status: 0x%02x (bit0-7: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pll_status,
			(pll_status & MAX96724_DPLL_STATUS_FIELD(0)) ? "CSIPLL0_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(1)) ? "CSIPLL1_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(2)) ? "CSIPLL2_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(3)) ? "CSIPLL3_LOCK " : "");
		unsigned int vid_status = 0;
		max96724_read_reg(dev, MAX96724_VID_STATUS_ADDR(src_port), &vid_status);
		dev_dbg(dev, "%s: %s Video RX status: 0x%02x (LOCK=%d, bit4-6: %s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), vid_status, !!(link_status & MAX96724_VID_LOCK_BIT),
			(vid_status & 0x40) ? "VID_LOCK " : "",
			(vid_status & 0x20) ? "VID_PKT_DET " : "",
			(vid_status & 0x10) ? "VID_SEQ_ERR " : "");
		unsigned int pipe_de_status = 0, pipe_hs_status = 0, pipe_vs_status = 0;
		max96724_read_reg(dev, MAX96724_PIPE_DE_STATUS_ADDR, &pipe_de_status);
		dev_dbg(dev, "%s: %s Video Pipeline DE status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_de_status,
			(pipe_de_status & 0x01) ? "DE_DET_0 " : "",
			(pipe_de_status & 0x02) ? "DE_DET_1 " : "",
			(pipe_de_status & 0x04) ? "DE_DET_2 " : "",
			(pipe_de_status & 0x08) ? "DE_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_HS_STATUS_ADDR, &pipe_hs_status);
		dev_dbg(dev, "%s: %s Video Pipeline HS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_hs_status,
			(pipe_hs_status & 0x01) ? "HS_DET_0 " : "",
			(pipe_hs_status & 0x02) ? "HS_DET_1 " : "",
			(pipe_hs_status & 0x04) ? "HS_DET_2 " : "",
			(pipe_hs_status & 0x08) ? "HS_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_VS_STATUS_ADDR, &pipe_vs_status);
		dev_dbg(dev, "%s: %s Video Pipeline VS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_vs_status,
			(pipe_vs_status & 0x01) ? "VS_DET_0 " : "",
			(pipe_vs_status & 0x02) ? "VS_DET_1 " : "",
			(pipe_vs_status & 0x04) ? "VS_DET_2 " : "",
			(pipe_vs_status & 0x08) ? "VS_DET_3 " : "");
	}
	
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_RESET_CTRL_ADDR,
		MAX96724_RESET_CTRL_FIELD(src_port),
		MAX96724_FIELD_PREP(MAX96724_RESET_CTRL_FIELD(src_port), 1U));
	if (err)
		dev_err(dev, "%s: Failed to trigger %s link reset: %d\n",
			__func__,
			max96724_get_link_name(priv->src_link),
			err);

	/* delay to settle link */
	msleep(100);

	/* clear link and ctrl reset */
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_RESET_CTRL_ADDR,
		MAX96724_RESET_CTRL_FIELD(src_port),
		MAX96724_FIELD_PREP(MAX96724_RESET_CTRL_FIELD(src_port), 0U));
	if (err)
		dev_err(dev, "%s: Failed to clear %s link reset: %d\n",
			__func__,
			max96724_get_link_name(priv->src_link),
			err);

}
EXPORT_SYMBOL(max96724_reset_oneshot);

static int __max96724_set_pipe_d4xx(struct device *dev, int pipe_id, u8 data_type1,
				    u8 data_type2, u32 vc_id, u32 csi_id )
{
	int err = 0;
	struct max96724 *priv = dev_get_drvdata(dev);
	int i = 0;
	u8 en_mapping_num = 0x0F;
	u8 all_mapping_phy = 0x55;
	u8 dis_lim_heart = 0x0A;

	u8 link_id = max96724_link_to_port(priv->src_link);

	u8 vc_id_2b_lsb = ((u8) vc_id) & 0x3;
	u8 vc_id_2b_msb = (((u8) vc_id) >>  2) & 0x3;

	if (data_type2 == 0x0)
		en_mapping_num = 0x07;

	switch (csi_id) {
	case GMSL_CSI_PORT_A:
		all_mapping_phy = 0x00;
		break;
	case GMSL_CSI_PORT_B:
		all_mapping_phy = 0x55;
		break;
	case GMSL_CSI_PORT_C:
		all_mapping_phy = 0xAA;
		break;
	case GMSL_CSI_PORT_D:
		all_mapping_phy = 0xFF;
		break;
	default:
		dev_warn(dev, "%s: invalid deserializer csi port, default CSI 1!\n", __func__);
	};
	
	struct reg_pair map_pipe_select[] = {
		{MAX96724_REG5_ADDR, 0x80}, // Enable lock
		{MAX96724_REG6_ADDR, 0xFF}, // Enable all GMSL input sources
		{MAX96724_MIPI_PHY0,
			MAX96724_FIELD_PREP(MAX96724_MIPI_PHY0_CLK_FORCE_EN_FIELD, 0U) |
			MAX96724_FIELD_PREP(MAX96724_MIPI_PHY0_MODE_FIELD, priv->csi_mode)
		},
		{MAX96724_MIPI_PHY2, 0xF4},
		{MAX96724_MIPI_PHY3, 0x44},
		{MAX96724_MIPI_PHY5, 0x00},
	};

	struct reg_pair map_pipe_control[] = {
		// Enable 4 mappings for Pipe X
		{MAX96724_PIPE_X_EN_ADDR, 0x0F},
		// Map data_type1 on vc_id
		{MAX96724_PIPE_X_SRC_0_MAP_ADDR, 0x1E},
		{MAX96724_PIPE_X_DST_0_MAP_ADDR, 0x1E},
		// Map frame_start on vc_id
		{MAX96724_PIPE_X_SRC_1_MAP_ADDR, 0x00},
		{MAX96724_PIPE_X_DST_1_MAP_ADDR, 0x00},
		// Map frame end on vc_id
		{MAX96724_PIPE_X_SRC_2_MAP_ADDR, 0x01},
		{MAX96724_PIPE_X_DST_2_MAP_ADDR, 0x01},
		// Map data_type2 on vc_id
		{MAX96724_PIPE_X_SRC_3_MAP_ADDR, 0x12},
		{MAX96724_PIPE_X_DST_3_MAP_ADDR, 0x12},
		// Mappings to CSI 1 (master for port A)
		{MAX96724_PIPE_X_PHY_DEST_0_MAP_ADDR, all_mapping_phy},
		// SEQ_MISS_EN: Disabled / DIS_PKT_DET: Disabled
		{MAX96724_VID_RX0_ADDR, 0x33}, // pipe X
		// LIM_HEART : Disabled
		{MAX96724_VID_RX6_ADDR, dis_lim_heart},
		/* Extend each SRC/DST to CPHY 5-bits / DPHY 4-bits VCs
		{MAX96724_PIPE_X_SRCDST_VC_EXT_0_MAP_ADDR, 0x0},
		{MAX96724_PIPE_X_SRCDST_VC_EXT_1_MAP_ADDR, 0x0},
		{MAX96724_PIPE_X_SRCDST_VC_EXT_2_MAP_ADDR, 0x0},
		{MAX96724_PIPE_X_SRCDST_VC_EXT_3_MAP_ADDR, 0x0},
		*/
	};

	for (i = 0; i < 10; i++) {
		map_pipe_control[i].addr += 0x40 * pipe_id;
	}

	map_pipe_control[0].val = en_mapping_num;
	map_pipe_control[1].val = (vc_id_2b_lsb << 6) | data_type1;
	map_pipe_control[2].val = (vc_id_2b_lsb << 6) | data_type1;
	map_pipe_control[3].val = (vc_id_2b_lsb << 6) | 0x01;
	map_pipe_control[4].val = (vc_id_2b_lsb << 6) | 0x01;
	map_pipe_control[5].val = (vc_id_2b_lsb << 6) | 0x00;
	map_pipe_control[6].val = (vc_id_2b_lsb << 6) | 0x00;
	map_pipe_control[7].val = (vc_id_2b_lsb << 6) | data_type2;
	map_pipe_control[8].val = (vc_id_2b_lsb << 6) | data_type2;
	map_pipe_control[9].val = all_mapping_phy;

	map_pipe_control[10].addr += 0x12 * pipe_id;
	map_pipe_control[11].addr += 0x12 * pipe_id;

	map_pipe_control[10].val = 0x33;
	map_pipe_control[11].val = dis_lim_heart;

	/* Extend each SRC/DST to CPHY 5-bits / DPHY 4-bits VCs
	map_pipe_control[12].addr += 0x10 * pipe_id;
	map_pipe_control[13].addr += 0x10 * pipe_id;
	map_pipe_control[14].addr += 0x10 * pipe_id;
	map_pipe_control[15].addr += 0x10 * pipe_id;

	map_pipe_control[12].val = (vc_id_2b_msb << 3) | vc_id_2b_msb;
	map_pipe_control[13].val = (vc_id_2b_msb << 3) | vc_id_2b_msb;
	map_pipe_control[14].val = (vc_id_2b_msb << 3) | vc_id_2b_msb;
	map_pipe_control[15].val = (vc_id_2b_msb << 3) | vc_id_2b_msb;
	*/

	dev_info(dev, "%s: %s pipe %u set on vc_id=%u [reg: src/dst:0x%x, dstext:0x%x] \n",
		__func__,
		 max96724_get_link_name(priv->src_link),
		 pipe_id, vc_id,
		(vc_id_2b_lsb << 6),
		vc_id_2b_msb);


	// disable CSI out link during pipe re-configuration
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_CSI_OUT_EN_ADDR,
		MAX96724_CSI_OUT_EN_FIELD,
		MAX96724_FIELD_PREP(MAX96724_CSI_OUT_EN_FIELD, 0));
	if (err) {
		dev_err(dev, "%s: Failed to enable csi output link: %d\n",
			__func__,
			err);
	}

	/* Video Pipe Input Source Selection
	 * This tells MAX96724 which PHY (Link) feeds which Video Pipe.
	 * Without this, video data cannot flow from GMSL links to CSI-2 output.
	 *
	 * REG 0x00F0: Video Pipe 0/1 input selection
	 *   Bit[7:6] = <link_id>: Pipe 1 from GMSL A, B, C or D link
	 *   Bit[5:4] = 01: Pipe 1 uses internal Pipe Y
	 *   Bit[3:2] = <link_id>: Pipe 0 from GMSL A, B, C or D link
	 *   Bit[1:0] = 00: Pipe 0 uses internal Pipe X
	 *
	 * REG 0x00F1: Video Pipe 2/3 input selection
	 *   Bit[7:6] = <link_id>: Pipe 3 from GMSL A, B, C or D link
	 *   Bit[5:4] = 11: Pipe 3 uses internal Pipe Z
	 *   Bit[3:2] = <link_id>: Pipe 2 from GMSL A, B, C or D link
	 *   Bit[1:0] = 10: Pipe 2 uses internal Pipe U
	 *
	 * REG 0x00F4: Enable/disable Video Pipes
	 *   Bit[3:0] = <pipe_id>: Enable Pipe 3, 2, 1 or 0
	 */
	err |= MAX96724_UPDATE_BITS(priv->regmap, MAX96724_VIDEO_PIPE_EN_ADDR,
			MAX96724_VIDEO_PIPE_EN_FIELD(pipe_id),
			MAX96724_FIELD_PREP(MAX96724_VIDEO_PIPE_EN_FIELD(pipe_id), 0U));

	err |= max96724_set_registers(dev, map_pipe_select,
				     ARRAY_SIZE(map_pipe_select));

	err |= MAX96724_UPDATE_BITS(priv->regmap, MAX96724_VIDEO_PIPE_SEL(pipe_id),
			MAX96724_VIDEO_PIPE_SEL_LINK_FIELD(pipe_id)
			| MAX96724_VIDEO_PIPE_SEL_INPUT_FIELD(pipe_id),
			MAX96724_FIELD_PREP(MAX96724_VIDEO_PIPE_SEL_LINK_FIELD(pipe_id), link_id)
			| MAX96724_FIELD_PREP(MAX96724_VIDEO_PIPE_SEL_INPUT_FIELD(pipe_id), pipe_id));

	err |= MAX96724_UPDATE_BITS(priv->regmap, MAX96724_VIDEO_PIPE_EN_ADDR,
			MAX96724_VIDEO_PIPE_EN_FIELD(pipe_id),
			MAX96724_FIELD_PREP(MAX96724_VIDEO_PIPE_EN_FIELD(pipe_id), 1U));

	// 0x02: ALT_MEM_MAP8, 0x10: ALT2_MEM_MAP8
	err |= MAX96724_WRITE_REG(priv->regmap, MAX96724_MIPI_TX_ALT_MEM(csi_id), 0x2);

	err |= max96724_set_registers(dev, map_pipe_control,
				     ARRAY_SIZE(map_pipe_control));

	/* Configure per Pipe CSI and PHY type
		| MAX96724_MIPI_TX_VCX_EN_FIELD
		| MAX96724_FIELD_PREP(MAX96724_MIPI_TX_VCX_EN_FIELD, MAX96724_VC_2_BITS)
	*/
	err |= MAX96724_UPDATE_BITS(priv->regmap, MAX96724_MIPI_TX_LANE_CNT(i),
		MAX96724_MIPI_TX_CPHY_EN_FIELD
		| MAX96724_MIPI_TX_WAKEUP_CYC_FIELD
		| MAX96724_MIPI_TX_LANE_CNT_FIELD,
		MAX96724_FIELD_PREP(MAX96724_MIPI_TX_CPHY_EN_FIELD,
				    priv->csi_phy == MAX96724_CSI_CPHY ? 1U : 0U)
		| MAX96724_FIELD_PREP(MAX96724_MIPI_TX_WAKEUP_CYC_FIELD, 1U)
		| MAX96724_LANE_CTRL_MAP(priv->dst_n_lanes-1));
	if (err) {
		dev_err(dev, "%s: Failed to configure pipe control %u %s %u lanes: %d\n",
			__func__,
			csi_id,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			priv->dst_n_lanes,
			err);
	}

	err |= max967xx_phy_tuning(dev);
	if (err) {
		dev_err(dev, "%s: Failed to apply %s tunning : %d\n",
			__func__,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			err);
	}

	/* Configure auto-deskew for all pipes
	 * Script: 0x0903/0x0943/0x0983/0x09C3 = auto deskew enable
	 */
	err |= MAX96724_UPDATE_BITS(priv->regmap, MAX96724_MIPI_TX_DESKEW_INIT(csi_id),
			MAX96724_MIPI_TX_DESKEW_INIT_AUTO_FIELD,
			MAX96724_FIELD_PREP(MAX96724_MIPI_TX_DESKEW_INIT_AUTO_FIELD, 1U));
	if (err) {
		dev_err(dev, "%s: Failed to enable deskew CSI %u %s: %d\n",
			__func__,
			csi_id,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			err);
	}

	/* Configure lane mapping DPLL Frequency
	 * Script: DPHY_CLK_1500BPS 0x0415/0x0418/0x041B/0x041E = 0x2F
	 * Script: CPHY_CLK_1500BPS 0x0415/0x0418/0x041B/0x041E = 0x20
	*/
	err |= MAX96724_UPDATE_BITS(priv->regmap, MAX96724_DPLL_FREQ(csi_id),
		MAX96724_DPLL_FREQ_FIELD,
		MAX96724_FIELD_PREP(MAX96724_DPLL_FREQ_FIELD,
		priv->csi_phy == MAX96724_CSI_CPHY 	? MAX96724_CPHY_CLK_1500BPS
							: MAX96724_DPHY_CLK_1500BPS));
	if (err) {
		dev_err(dev, "%s: Failed to set CSI %u %s at 1500bps: %d\n",
			__func__,
			csi_id,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
			err);
	}

	/* Configure CPHY preamble
	*/
	if (priv->csi_phy == MAX96724_CSI_CPHY) {
		err |= MAX96724_WRITE_REG(priv->regmap, MAX96724_CPHY_PREAMBLE_ADDR,
			MAX96724_FIELD_PREP(MAX96724_CPHY_PREAMBLE_FIELD, MAX96724_CPHY_PREAMBLE_DEFAULT));
		if (err) {
			dev_err(dev, "%s: Failed to set CSI %u %s preamble : %d\n",
				__func__,
				csi_id,
				priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
				err);
		}

		err |= MAX96724_WRITE_REG(priv->regmap, MAX96724_CPHY_PREP_ADDR, MAX96724_CPHY_PREP_DEFAULT);
		if (err) {
			dev_err(dev, "%s: Failed to set CSI %u %s prep and post : %d\n",
				__func__,
				csi_id,
				priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
				err);
		}
		dev_dbg(dev, "%s: preparing %s preamble : 0x8AD/0x8AE applied\n",
			__func__,
			priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY");
	}

#ifndef CONFIG_VIDEO_D4XX_MAX96712
	/* Write 0x1d00 register sequence
	 * This register is written twice with different values - appears to be
	 * some kind of command sequence or state machine control
	 */
	err = max96724_write_reg(dev, 0x1d00, 0xf4);
	err |= max96724_write_reg(dev, 0x1d00, 0xf5);
	if (err) {
		dev_warn(dev, "%s: Failed to reset internal state machine : %d\n",
			__func__,
			err);
	}
#endif
        /* Reset all GMSL links after configuration (matches script line 508)
         * Reference script does this AFTER all serializer config and BEFORE CSI enable:
         *   1. Restore all links (0x0006 = 0xFF)
         *   2. Reset all links (0x0018 = 0x0F) ← This step!
         *   3. Enable CSI output (0x040B = 0x02)
         *   4. Configure MIPI PHY continuous clock (0x08A0 = 0x84)
         *
         * This reset ensures all link configurations take effect properly
         * and synchronizes the GMSL links before CSI streaming starts.
        */
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_RESET_CTRL_ADDR,
		MAX96724_RESET_LINK_FIELD(0)
		| MAX96724_RESET_LINK_FIELD(1)
		| MAX96724_RESET_LINK_FIELD(2)
		| MAX96724_RESET_LINK_FIELD(3),
		MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(0), 1U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(1), 1U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(2), 1U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(3), 1U));
	if (err)
		dev_err(dev, "%s: Failed to reset all links: %d\n",
			__func__, err);

	// delay to settle link
	msleep(100);

	// clear GMSL2 links Reset
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_RESET_CTRL_ADDR,
		MAX96724_RESET_LINK_FIELD(0)
		| MAX96724_RESET_LINK_FIELD(1)
		| MAX96724_RESET_LINK_FIELD(2)
		| MAX96724_RESET_LINK_FIELD(3),
		MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(0), 0U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(1), 0U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(2), 0U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(3), 0U));
	if (err)
		dev_err(dev, "%s: Failed to reset all links: %d\n",
			__func__, err);

        /* CRITICAL: DO NOT enable CSI_OUT_EN (0x040b) here!
         *
         * Reference script shows CSI should be enabled LAST, after:
         * 1. All MAX967xx configuration complete
         * 2. GMSL link is locked
         * 3. Sensor is streaming valid data
         *
         * IPU behavior is CORRECT:
         * - Firmware waits for initial capture BEFORE calling s_stream
         * - This ensures IPU is ready to receive data
         * - CSI should only output when sensor has valid data ready
         *
         * We enable CSI in s_stream AFTER sensor stream-on succeeds.
         */

	return err;
}

int max96724_init_settings(struct device *dev)
{
	int err = 0;
	int i;
	unsigned src_pipe = MAX96724_PIPE_X;
	unsigned phy_lane_map[MAX96724_NUM_CSI_LINKS];
	unsigned rev;

	struct max96724 *priv = dev_get_drvdata(dev);
        struct regmap *map = priv->regmap;
	u8 src_port = max96724_link_to_port(priv->src_link);

	dev_dbg(dev, "%s: Clearing  %s CSI %u %s mode %s (num_lanes:x%u)\n",
		__func__,
		max96724_get_link_name(priv->src_link),
		priv->dst_link,
		priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
		priv->csi_mode == MAX96724_CSI_MODE_1X4 || MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2",
		priv->dst_n_lanes);

	mutex_lock(&priv->lock);

#ifdef CONFIG_VIDEO_D4XX_MAX96712
	/* Enable internal regulators (0x17 and 0x19) - before reset
	*/
	err = MAX96724_WRITE_REG(priv->regmap, MAX96724_REG17_ADDR, 0x12);
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_REG19_ADDR,
		MAX96724_REG19_CTRL_EN_FIELD,
		MAX96724_FIELD_PREP(MAX96724_REG19_CTRL_EN_FIELD, 1U));

	/* Enable PoC (Power over Coax) for cameras
	*/
	dev_dbg(dev, "Enabling PoC (Power over Coax)...\n");
	err = MAX96724_WRITE_REG(priv->regmap, MAX96724_REG_POC_CTRL1, 0x80);
	err = MAX96724_WRITE_REG(priv->regmap, MAX96724_REG_POC_CTRL2, 0x80);
	err = MAX96724_WRITE_REG(priv->regmap, MAX96724_REG_POC_CTRL3, 0x01);

	msleep(100); // Wait for power to stabilize
#endif

	/* Reset GMSL2 links state
	*/
	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_RESET_CTRL_ADDR,
		MAX96724_RESET_LINK_FIELD(0)
		| MAX96724_RESET_LINK_FIELD(1)
		| MAX96724_RESET_LINK_FIELD(2)
		| MAX96724_RESET_LINK_FIELD(3),
		MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(0), 1U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(1), 1U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(2), 1U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(3), 1U));
	if (err) {
		dev_err(dev, "%s: Failed to reset link: %d\n",
			__func__,
			err);
		goto init_settings_out;
	}

	msleep(1);	// delay to settle link

	err = MAX96724_UPDATE_BITS(priv->regmap, MAX96724_RESET_CTRL_ADDR,
		MAX96724_RESET_LINK_FIELD(0)
		| MAX96724_RESET_LINK_FIELD(1)
		| MAX96724_RESET_LINK_FIELD(2)
		| MAX96724_RESET_LINK_FIELD(3),
		MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(0), 0U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(1), 0U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(2), 0U)
		| MAX96724_FIELD_PREP(MAX96724_RESET_LINK_FIELD(3), 0U));
	if (err) {
		dev_err(dev, "%s: Failed to reset link: %d\n",
			__func__,
			err);
		goto init_settings_out;
	}
	msleep(100);	// delay to settle link

	for (i = 0; i < MAX96724_MAX_PIPES; i++) {
		dev_dbg(dev, "%s enable GMSL link through pipe X source to Video pipe %d",
			max96724_get_link_name(priv->src_link),
			i);

		err |= __max96724_set_pipe_d4xx(dev, i, GMSL_CSI_DT_YUV422_8,
							GMSL_CSI_DT_EMBED, i, priv->dst_link);
	}
	if (err) {
		dev_err(dev, "%s: Failed to configure %s pipe X to Video pipes : %d\n",
			__func__,
			max96724_get_link_name(priv->src_link),
			err);
		goto init_settings_out;
	}

	//msleep(300);  // Wait after pipe configuration

	/* Configure MIPI D-PHY/C-PHY
	 * These registers configure the MIPI physical layer for CSI-2 output
	 */
	dev_info(dev, "%s: Configuring CSI %u %s mode %s: num_lanes x%u (%s)\n",
		 __func__,
		 priv->dst_link,
		 priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
		 priv->csi_mode == MAX96724_CSI_MODE_1X4 || MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2",
		 priv->dst_n_lanes,
		 priv->dev_id == MAX96724_DEV_REV_ID ? "MAX96724" : "MAX96712");

	/* Re-Check GMSL link status after initial configuration */
	{
		unsigned int link_status = 0;
		max96724_read_reg(dev, MAX96724_LINK_STATUS(src_port), &link_status);
		dev_dbg(dev, "%s: %s Link status: 0x%02x (LOCK=%d, bit0-7: %s%s%s%s%s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), link_status, !!(link_status & MAX96724_LINK_LOCK_BIT),
			(link_status & 0x01) ? "VID_LOCK " : "",
			(link_status & 0x02) ? "CONFIG_DETECT " : "",
			(link_status & 0x04) ? "VIDEO_DETECT " : "",
			(link_status & 0x08) ? "LOCK " : "",
			(link_status & 0x10) ? "ERROR " : "",
			(link_status & 0x20) ? "bit5 " : "",
			(link_status & 0x40) ? "bit6 " : "",
			(link_status & 0x80) ? "LOCKED " : "");
		unsigned int pll_status = 0;
		max96724_read_reg(dev, MAX96724_DPLL_STATUS_ADDR, &pll_status);
		dev_dbg(dev, "%s: %s DPLL status: 0x%02x (bit0-7: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pll_status,
			(pll_status & MAX96724_DPLL_STATUS_FIELD(0)) ? "CSIPLL0_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(1)) ? "CSIPLL1_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(2)) ? "CSIPLL2_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(3)) ? "CSIPLL3_LOCK " : "");
		unsigned int vid_status = 0;
		max96724_read_reg(dev, MAX96724_VID_STATUS_ADDR(src_port), &vid_status);
		dev_dbg(dev, "%s: %s Video RX status: 0x%02x (LOCK=%d, bit4-6: %s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), vid_status, !!(link_status & MAX96724_VID_LOCK_BIT),
			(vid_status & 0x40) ? "VID_LOCK " : "",
			(vid_status & 0x20) ? "VID_PKT_DET " : "",
			(vid_status & 0x10) ? "VID_SEQ_ERR " : "");
		unsigned int pipe_de_status = 0, pipe_hs_status = 0, pipe_vs_status = 0;
		max96724_read_reg(dev, MAX96724_PIPE_DE_STATUS_ADDR, &pipe_de_status);
		dev_dbg(dev, "%s: %s Video Pipeline DE status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_de_status,
			(pipe_de_status & 0x01) ? "DE_DET_0 " : "",
			(pipe_de_status & 0x02) ? "DE_DET_1 " : "",
			(pipe_de_status & 0x04) ? "DE_DET_2 " : "",
			(pipe_de_status & 0x08) ? "DE_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_HS_STATUS_ADDR, &pipe_hs_status);
		dev_dbg(dev, "%s: %s Video Pipeline HS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_hs_status,
			(pipe_hs_status & 0x01) ? "HS_DET_0 " : "",
			(pipe_hs_status & 0x02) ? "HS_DET_1 " : "",
			(pipe_hs_status & 0x04) ? "HS_DET_2 " : "",
			(pipe_hs_status & 0x08) ? "HS_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_VS_STATUS_ADDR, &pipe_vs_status);
		dev_dbg(dev, "%s: %s Video Pipeline VS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_vs_status,
			(pipe_vs_status & 0x01) ? "VS_DET_0 " : "",
			(pipe_vs_status & 0x02) ? "VS_DET_1 " : "",
			(pipe_vs_status & 0x04) ? "VS_DET_2 " : "",
			(pipe_vs_status & 0x08) ? "VS_DET_3 " : "");
	}

init_settings_out:
	mutex_unlock(&priv->lock);

	return err;
}
EXPORT_SYMBOL(max96724_init_settings);

int max96724_set_pipe(struct device *dev, int pipe_id,
		     u8 data_type1, u8 data_type2, u32 vc_id)
{
	struct max96724 *priv = dev_get_drvdata(dev);
	unsigned src_pipe = MAX96724_PIPE_X;
	unsigned rev;
        struct regmap *map = priv->regmap;
	int err = 0;
	u8 src_port = max96724_link_to_port(priv->src_link);

	if (pipe_id > (MAX96724_MAX_PIPES - 1)) {
		dev_info(dev, "%s, input pipe_id: %d exceed max96724 max pipes\n",
			 __func__, pipe_id);
		return -EINVAL;
	}

	dev_dbg(dev, "%s: disabling  %s pipe %u (vc_id %u) CSI %u %s mode %s (num_lanes:x%u)\n",
		__func__,
		max96724_get_link_name(priv->src_link),
		pipe_id, vc_id,
		priv->dst_link,
		priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
		priv->csi_mode == MAX96724_CSI_MODE_1X4 || MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2",
		priv->dst_n_lanes);

	mutex_lock(&priv->lock);

	dev_info(dev, "%s() : %s Re-configuring pipe_id %d, data_type1 %x, data_type2 %x, vc_id %u\n",
		__func__,
		max96724_get_link_name(priv->src_link),
		pipe_id, data_type1, data_type2, vc_id);


	err = __max96724_set_pipe_d4xx(dev, pipe_id, data_type1, data_type2, vc_id, priv->dst_link);

	/* Double-Check GMSL link status after stream start configuration */
	{
		unsigned int link_status = 0;
		max96724_read_reg(dev, MAX96724_LINK_STATUS(src_port), &link_status);
		dev_dbg(dev, "%s: %s Link status: 0x%02x (LOCK=%d, bit0-7: %s%s%s%s%s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), link_status, !!(link_status & MAX96724_LINK_LOCK_BIT),
			(link_status & 0x01) ? "VID_LOCK " : "",
			(link_status & 0x02) ? "CONFIG_DETECT " : "",
			(link_status & 0x04) ? "VIDEO_DETECT " : "",
			(link_status & 0x08) ? "LOCK " : "",
			(link_status & 0x10) ? "ERROR " : "",
			(link_status & 0x20) ? "bit5 " : "",
			(link_status & 0x40) ? "bit6 " : "",
			(link_status & 0x80) ? "LOCKED " : "");
		unsigned int pll_status = 0;
		max96724_read_reg(dev, MAX96724_DPLL_STATUS_ADDR, &pll_status);
		dev_dbg(dev, "%s: %s DPLL status: 0x%02x (bit0-7: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pll_status,
			(pll_status & MAX96724_DPLL_STATUS_FIELD(0)) ? "CSIPLL0_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(1)) ? "CSIPLL1_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(2)) ? "CSIPLL2_LOCK " : "",
			(pll_status & MAX96724_DPLL_STATUS_FIELD(3)) ? "CSIPLL3_LOCK " : "");
		unsigned int vid_status = 0;
		max96724_read_reg(dev, MAX96724_VID_STATUS_ADDR(src_port), &vid_status);
		dev_dbg(dev, "%s: %s Video RX status: 0x%02x (LOCK=%d, bit4-6: %s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), vid_status, !!(link_status & MAX96724_VID_LOCK_BIT),
			(vid_status & 0x40) ? "VID_LOCK " : "",
			(vid_status & 0x20) ? "VID_PKT_DET " : "",
			(vid_status & 0x10) ? "VID_SEQ_ERR " : "");
		unsigned int pipe_de_status = 0, pipe_hs_status = 0, pipe_vs_status = 0;
		max96724_read_reg(dev, MAX96724_PIPE_DE_STATUS_ADDR, &pipe_de_status);
		dev_dbg(dev, "%s: %s Video Pipeline DE status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_de_status,
			(pipe_de_status & 0x01) ? "DE_DET_0 " : "",
			(pipe_de_status & 0x02) ? "DE_DET_1 " : "",
			(pipe_de_status & 0x04) ? "DE_DET_2 " : "",
			(pipe_de_status & 0x08) ? "DE_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_HS_STATUS_ADDR, &pipe_hs_status);
		dev_dbg(dev, "%s: %s Video Pipeline HS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_hs_status,
			(pipe_hs_status & 0x01) ? "HS_DET_0 " : "",
			(pipe_hs_status & 0x02) ? "HS_DET_1 " : "",
			(pipe_hs_status & 0x04) ? "HS_DET_2 " : "",
			(pipe_hs_status & 0x08) ? "HS_DET_3 " : "");
		max96724_read_reg(dev, MAX96724_PIPE_VS_STATUS_ADDR, &pipe_vs_status);
		dev_dbg(dev, "%s: %s Video Pipeline VS status: 0x%02x (bit0-3: %s%s%s%s)\n",
			__func__, max96724_get_link_name(priv->src_link), pipe_vs_status,
			(pipe_vs_status & 0x01) ? "VS_DET_0 " : "",
			(pipe_vs_status & 0x02) ? "VS_DET_1 " : "",
			(pipe_vs_status & 0x04) ? "VS_DET_2 " : "",
			(pipe_vs_status & 0x08) ? "VS_DET_3 " : "");
	}

	dev_info(dev, "%s: Successfully enabled %s pipe %u (vc_id %u) CSI %u %s lanes %s map\n",
		__func__,
		 max96724_get_link_name(priv->src_link),
		 pipe_id, vc_id,
		 priv->dst_link,
		 priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
		 priv->csi_mode == MAX96724_CSI_MODE_2X4 ? "2X4" : "4X2");

 set_pipe_out:
	mutex_unlock(&priv->lock);

	return err;
}
EXPORT_SYMBOL(max96724_set_pipe);

static const struct of_device_id max96724_of_match[] = {
	{ .compatible = "maxim,d4xx-max96724", },
	{ },
};
MODULE_DEVICE_TABLE(of, max96724_of_match);

#ifdef CONFIG_OF
static int max96724_parse_dt(struct max96724 *priv,
				struct i2c_client *client)
{
	struct device_node *node = client->dev.of_node;
	int err = 0;
	const char *str_value;
	int value;
	const struct of_device_id *match;

	if (!node)
		return -EINVAL;

	match = of_match_device(max96724_of_match, &client->dev);
	if (!match) {
		dev_err(&client->dev, "Failed to find matching dt id\n");
		return -EFAULT;
	}

	err = of_property_read_string(node, "csi-mode", &str_value);
	if (err < 0) {
		dev_err(&client->dev, "csi-mode property not found\n");
		return err;
	}

	if (!strcmp(str_value, "2x4")) {
		priv->csi_mode = MAX96724_CSI_MODE_2X4;
	} else if (!strcmp(str_value, "4x2")) {
		priv->csi_mode = MAX96724_CSI_MODE_4X2;
	} else {
		dev_err(&client->dev, "invalid csi mode\n");
		return -EINVAL;
	}

	err = of_property_read_u32(node, "max-src", &value);
	if (err < 0) {
		dev_err(&client->dev, "No max-src info\n");
		return err;
	}
	priv->max_src = value;

	priv->reset_gpio = of_get_named_gpio(node, "reset-gpios", 0);
	if (priv->reset_gpio < 0) {
		dev_err(&client->dev, "reset-gpios not found %d\n", err);
		return err;
	}

	/* digital 1.2v */
	if (of_get_property(node, "vdd_cam_1v2-supply", NULL)) {
		priv->vdd_cam_1v2 = regulator_get(&client->dev, "vdd_cam_1v2");
		if (IS_ERR(priv->vdd_cam_1v2)) {
			dev_err(&client->dev,
				"vdd_cam_1v2 regulator get failed\n");
			err = PTR_ERR(priv->vdd_cam_1v2);
			priv->vdd_cam_1v2 = NULL;
			return err;
		}
	} else {
		priv->vdd_cam_1v2 = NULL;
	}

	return 0;
}

#else
static int max96724_parse_pdata(struct max96724 *priv,
				struct i2c_client *client)
{
	struct max96724_pdata *pdata = client->dev.platform_data;
	if (pdata) {
		dev_dbg(&client->dev, "%s: Parsing Deserializer PDATA (mode=%s) \n",
			__func__,
			pdata->csi_mode == GMSL_CSI_4X2_MODE ? "4X2" : "2X4");
		if (pdata->csi_mode == GMSL_CSI_2X4_MODE ||
		    pdata->csi_mode == GMSL_CSI_1X4_MODE)
			priv->csi_mode = MAX96724_CSI_MODE_2X4;
		else if (pdata->csi_mode == GMSL_CSI_4X2_MODE)
			priv->csi_mode = MAX96724_CSI_MODE_4X2;
		else {
			dev_err(&client->dev, "invalid csi mode\n");
			return -EINVAL;
		}
		if (pdata->csi_phy == GMSL_CSI_CPHY)
			priv->csi_phy = MAX96724_CSI_CPHY;
		else if (pdata->csi_phy == GMSL_CSI_DPHY)
			priv->csi_phy = MAX96724_CSI_DPHY;
		else {
			dev_err(&client->dev, "invalid csi phy\n");
			return -EINVAL;
		}

		priv->max_src = pdata->max_src;
		if (pdata->d4xx_hacks) {
			priv->d4xx_hacks = pdata->d4xx_hacks;
		} else {
			priv->d4xx_hacks = 0;
		}
	} else {
		priv->csi_mode = MAX96724_CSI_MODE_2X4;
		priv->csi_phy = MAX96724_CSI_CPHY;
		priv->max_src = 1;
		priv->reset_gpio = 0;
		priv->vdd_cam_1v2 = NULL;
		priv->d4xx_hacks = 0;
	}

	dev_info(&client->dev, "%s: %s Deserializer PDATA set CSI %s %s lane config (max_src=%u) \n",
		__func__,
		pdata->d4xx_hacks ? "d4xx" : "",
		priv->csi_phy == MAX96724_CSI_CPHY ? "CPHY" : "DPHY",
		priv->csi_mode == MAX96724_CSI_MODE_4X2 ? "4X2" : "2X4",
		priv->max_src);

	return 0;
}

#endif

static struct regmap_config max96724_regmap_config = {
	.reg_bits = 16,
	.val_bits = 8,
	.cache_type = REGCACHE_RBTREE,
};

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 0)
static int max96724_probe(struct i2c_client *client,
				const struct i2c_device_id *id)
#else
static int max96724_probe(struct i2c_client *client)
#endif
{
	struct max96724 *priv;
	int err = 0;

	dev_info(&client->dev, "[MAX96724]: probing GMSL Deserializer\n");

	/* Try to wake up MAX96724 by attempting to write to various control registers */
	{
		u8 wake_sequence[] = {MAX96724_CTRL1_ADDR, 0x00}; /* CTRL0 register, reset value */
		struct i2c_msg wake_msg = {
			.addr = client->addr,
			.flags = 0,
			.len = 2,
			.buf = wake_sequence
		};

		dev_info(&client->dev, "Attempting to wake up MAX96724...\n");
		i2c_transfer(client->adapter, &wake_msg, 1);
		msleep(50); /* Give device time to initialize */
	}

	priv = devm_kzalloc(&client->dev, sizeof(*priv), GFP_KERNEL);
	priv->i2c_client = client;
	priv->regmap = devm_regmap_init_i2c(priv->i2c_client,
				&max96724_regmap_config);
	if (IS_ERR(priv->regmap)) {
		dev_err(&client->dev,
			"regmap init failed: %ld\n", PTR_ERR(priv->regmap));
		return -ENODEV;
	}

#ifdef CONFIG_OF
	err = max96724_parse_dt(priv, client);
	if (err) {
		dev_err(&client->dev, "unable to parse dt\n");
		return -EFAULT;
	}
#else
	err = max96724_parse_pdata(priv, client);
	if (err) {
		dev_err(&client->dev, "unable to parse pdata\n");
		return -EFAULT;
	}
#endif

	max96724_pipes_reset(priv);

	dev_dbg(&client->dev, "[DEBUG] MAX96724_MAX_SOURCES defined as: %d, priv->max_src: %d\n",
		 MAX96724_MAX_SOURCES, priv->max_src);

	if (priv->max_src > MAX96724_MAX_SOURCES) {
		dev_err(&client->dev,
			"max sources more than currently supported\n");
		return -EINVAL;
	}

	mutex_init(&priv->lock);

	dev_set_drvdata(&client->dev, priv);

	/* Verify device communication by reading chip ID registers */
	{
		unsigned int reg_val;
		int ret;
		u8 buf[2];
		struct i2c_msg msgs[2];

		dev_info(&client->dev, "Testing I2C communication at address 0x%02x\n", client->addr);

		/* First try raw I2C read of device ID register */
		buf[0] = 0x0D; /* Device ID register */
		msgs[0].addr = client->addr;
		msgs[0].flags = 0;
		msgs[0].len = 1;
		msgs[0].buf = buf;

		msgs[1].addr = client->addr;
		msgs[1].flags = I2C_M_RD;
		msgs[1].len = 1;
		msgs[1].buf = &buf[1];

		ret = i2c_transfer(client->adapter, msgs, 2);
		if (ret == 2) {
			dev_info(&client->dev, "Raw I2C success! Device ID: 0x%02x\n", buf[1]);
		} else {
			dev_err(&client->dev, "Raw I2C failed: ret=%d\n", ret);

			/* Try alternative addresses */
			dev_info(&client->dev, "Trying alternative I2C addresses...\n");
			for (int alt_addr = 0x29; alt_addr <= 0x2C; alt_addr++) {
				msgs[0].addr = alt_addr;
				msgs[1].addr = alt_addr;
				ret = i2c_transfer(client->adapter, msgs, 2);
				if (ret == 2) {
					dev_info(&client->dev, "Found device at address 0x%02x! Device ID: 0x%02x\n", 
						alt_addr, buf[1]);
					break;
				}
			}
		}

		/* Now try regmap-based access */
		err = max96724_read_reg(&client->dev, 0x0D, &reg_val);
		if (err) {
			dev_err(&client->dev, "Regmap read device ID failed\n");
		} else {
			dev_info(&client->dev, "Regmap success! Device ID: 0x%02x\n", reg_val);
		}

		/* Read CTRL0 register to verify basic communication */
		err = max96724_read_reg(&client->dev, MAX96724_CTRL1_ADDR, &reg_val);
		if (err) {
			dev_err(&client->dev, "Failed to read CTRL1 register (0x%x)\n",
				MAX96724_CTRL1_ADDR);
		} else {
			dev_info(&client->dev, "MAX96724 CTRL1: 0x%02x\n", reg_val);
		}

		/* Check initial link status on all ports */
		max96724_read_reg(&client->dev, 0x001A, &reg_val);
		dev_info(&client->dev, "Initial Link A status (0x001A): 0x%02x (LOCK=%d)\n",
			 reg_val, (reg_val >> 3) & 1);
		max96724_read_reg(&client->dev, 0x000A, &reg_val);
		dev_info(&client->dev, "Initial Link B status (0x000A): 0x%02x (LOCK=%d)\n",
			 reg_val, (reg_val >> 3) & 1);
		max96724_read_reg(&client->dev, 0x000B, &reg_val);
		dev_info(&client->dev, "Initial Link C status (0x000B): 0x%02x (LOCK=%d)\n",
			 reg_val, (reg_val >> 3) & 1);
		max96724_read_reg(&client->dev, 0x000C, &reg_val);
		dev_info(&client->dev, "Initial Link D status (0x000C): 0x%02x (LOCK=%d)\n",
			 reg_val, (reg_val >> 3) & 1);

		/* Read REG 0x06 (GMSL configuration) - this tells us if GMSL1 or GMSL2 */
		max96724_read_reg(&client->dev, 0x06, &reg_val);
		dev_dbg(&client->dev, "REG 0x06 (GMSL config): 0x%02x (Bit0-3: LinkA-D mode)\n", reg_val);

	}

	/* dev communication gets validated when GMSL link setup is done */
	dev_info(&client->dev, "%s:  success\n", __func__);

	return 0;
}

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 0)
static int max96724_remove(struct i2c_client *client)
#else
static void max96724_remove(struct i2c_client *client)
#endif
{
	struct max96724 *priv;

	if (client != NULL) {
		priv = dev_get_drvdata(&client->dev);
		dev_info(&client->dev, "[MAX96724]: remove GMSL Deserializer\n");
		mutex_destroy(&priv->lock);
#ifdef CONFIG_OF
		i2c_unregister_device(client);
		client = NULL;
#endif
	}
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 0)
	return 0;
#endif
}

static const struct i2c_device_id max96724_id[] = {
	{ "d4xx-max96724", 0 },
	{ },
};

MODULE_DEVICE_TABLE(i2c, max96724_id);

static struct i2c_driver max96724_i2c_driver = {
	.driver = {
		.name = "d4xx-max96724",
		.owner = THIS_MODULE,
		.of_match_table = of_match_ptr(max96724_of_match),
	},
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 0)
	.probe = max96724_probe,
#elif LINUX_VERSION_CODE < KERNEL_VERSION(6, 6, 0)
	.probe_new = max96724_probe,
#else
	.probe = max96724_probe,
#endif
	.remove = max96724_remove,
	.id_table = max96724_id,
};

module_i2c_driver(max96724_i2c_driver);

MODULE_DESCRIPTION("Quad GMSL Deserializer driver max96724");
MODULE_AUTHOR("Florent Pirou <florent.pirou@intel.com>");
MODULE_LICENSE("GPL v2");
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)
MODULE_VERSION(DRIVER_VERSION_SUFFIX);
#endif
