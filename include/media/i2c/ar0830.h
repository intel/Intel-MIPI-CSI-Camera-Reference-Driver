/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * include/media/i2c/ar0830.h
 *
 * Copyright (C) 2025 Intel Corporation
 *
 */

#ifndef AR0830_H
#define AR0830_H

#define AR0830_ANALOG_GAIN_MIN		0
#define AR0830_ANALOG_GAIN_MAX		0x16
#define AR0830_ANALOG_GAIN_STEP		1
#define AR0830_ANALOG_GAIN_DEFAULT	0xe

#define AR0830_GLOBAL_GAIN_MIN		1
#define AR0830_GLOBAL_GAIN_MAX		0x162
#define AR0830_GLOBAL_GAIN_STEP		1
#define AR0830_GLOBAL_GAIN_DEFAULT	0x80

#define AR0830_COMMON_WIDTH			3840
#define AR0830_COMMON_HEIGHT		2160

#define AR0830_PIXEL_RATE			600000000ULL

#define BOOTDATA "NewBootdata.txt"
#define MAX_FIRMWARE_SIZE 			(1024*1024)
#define FIRMWARE_BLOCK_SIZE 		256
#define MAX_REGISTERS_PER_BLOCK 	50
#define FIRMWARE_REG_START_ADDR		0x8000
#define FIRMWARE_REG_END_ADDR		0x9fff
#define BOOTSTAGE_COMPLETE			0xFFFF
#define BOOTSTAGE_CHECKSUM			0xFFFF
#define STALL 1

#define AR0830_REG_ADDR(n)				((n) & 0x0000ffff)
#define AR0830_REG_PAGE(n)				((n) & 0x00ff0000)
#define AR0830_REG_SIZE(n)				((n) >> 24)
#define AR0830_REG_PAGE_MASK			0x00ff0000
#define AR0830_REG_16BIT(n)				((2 << 24) | (n))
#define AR0830_REG_32BIT(n)				((4 << 24) | (n))

#define AR0830_ATOMIC					AR0830_REG_16BIT(0x1184)
#define ATOMIC_RECORD					BIT(0)
#define ATOMIC_FINISH					BIT(1)
#define ATOMIC_MODE						BIT(2)
#define ATOMIC_UPDATE_FORMAT			BIT(3)
#define ATOMIC_UPDATE					BIT(4)
#define ATOMIC_UPDATE_ALL				(ATOMIC_UPDATE | ATOMIC_UPDATE_FORMAT | ATOMIC_MODE | ATOMIC_FINISH | ATOMIC_RECORD)

#define SYS_START										0x601A
#define AR0830_SYS_START								AR0830_REG_16BIT(SYS_START)
#define AR0830_SYS_START_STALL_STATUS					BIT(9)
#define AR0830_SYS_START_STALL_EN						BIT(8)
#define AR0830_SYS_START_STALL_MODE_FRAME				(0U << 6)
#define AR0830_SYS_START_STALL_MODE_DISABLED			(1U << 6)
#define AR0830_SYS_START_STALL_MODE_STANDBY				(2U << 6)
#define AR0830_SYS_START_STALL_MODE_STANDBY_SENSOR_OFF	(3U << 6)
#define AR0830_REG_ADV_START			0xe000
#define AR0830_ADV_START				AR0830_REG_32BIT(AR0830_REG_ADV_START)
#define AR0830_REG_ADV_ADDR_1			AR0830_REG_32BIT(0xe004)
#define AR0830_ADVANCED_BASE			AR0830_REG_32BIT(0xf038)
#define AR0830_SIPS_SLEW_CTRL			AR0830_REG_16BIT(0xf058)
#define AR0830_PREVIEW_WIDTH			AR0830_REG_16BIT(0x2000)
#define AR0830_PREVIEW_HEIGHT			AR0830_REG_16BIT(0x2002)
#define AR0830_PREVIEW_HINF_CTRL		AR0830_REG_16BIT(0x2030)
#define AR0830_PREVIEW_MAX_FPS			AR0830_REG_16BIT(0x2020)
#define AR0830_BOOTDATA_STAGE			AR0830_REG_16BIT(0x6002)
#define AR0830_SYSTEM_FREQ_IN			AR0830_REG_32BIT(0x6024)
#define AR0830_HINF_MIPI_FREQ_TGT		AR0830_REG_32BIT(0x6034)
#define AR0830_BOOTDATA_CHECKSUM		AR0830_REG_16BIT(0x6134)
#define AR0830_FW_REF		AR0830_REG_16BIT(0x004E)
#define PREVIEW_MAX_FPS(fps)			(fps << 8)
#define TO_S15_16(x)					((s32)((x) << 16))
#ifdef DEBUG
#define AR0830_CON_BUF_SIZE				512
#define AR0830_CON_BUF(n)				AR0830_REG_16BIT(0x0a2c + (n))
#define AR0830_WARNING(n)				AR0830_REG_16BIT(0x6004 + (n) * 2)
#define AR0830_ERROR					AR0830_REG_16BIT(0x0006)
#define AR0830_ERR_FILE					AR0830_REG_32BIT(0x0008)
#define AR0830_ERR_LINE					AR0830_REG_16BIT(0x000c)
#define AR0830_SIPM_ERR_0				AR0830_REG_16BIT(0x0014)
#define AR0830_SIPM_ERR_1				AR0830_REG_16BIT(0x0016)
#define AR0830_FRAME_CNT				AR0830_REG_16BIT(0x0002)
#define AR0830_ADV_CAPTURE_A_FV_CNT		AR0830_REG_32BIT(0x00490040)
#endif
#define OFFSET_BASE 			6
#define OFFSET_STEP 			5

#define REG_VALUE_4			4
#define REG_VALUE_2			2
#define REG_VALUE_1			1

#define to_ar0830(_sd)	container_of(_sd, struct ar0830, sd)

static const struct regmap_config ar0830_regmap_config = {
	.reg_bits = 16,
	.val_bits = 16,
	.reg_stride = 2,
	.reg_format_endian = REGMAP_ENDIAN_BIG,
	.val_format_endian = REGMAP_ENDIAN_BIG,
	.cache_type = REGCACHE_NONE,
};

static const struct regmap_config ar0830_regmap32_config = {
	.reg_bits = 16,
	.val_bits = 32,
	.reg_stride = 4,
	.reg_format_endian = REGMAP_ENDIAN_BIG,
	.val_format_endian = REGMAP_ENDIAN_BIG,
	.cache_type = REGCACHE_NONE,
};

struct ar0830_mode {
	u32 width;
	u32 height;
	u32 code;

};

static const s64 link_freq_menu_items[] = {
	600000000ULL, /* 600M */
};

static const struct ar0830_mode supported_modes[] = {
	{
		.width = AR0830_COMMON_WIDTH,
		.height = AR0830_COMMON_HEIGHT,
		.code = MEDIA_BUS_FMT_UYVY8_1X16,
	},
};

struct ar0830 {
	struct v4l2_subdev sd;
	struct media_pad pad;
	struct v4l2_ctrl_handler ctrl_handler;
	struct device *dev;
	/* V4L2 Controls */
	struct v4l2_ctrl *link_freq;

	struct regmap *regmap;
	struct regmap *regmap32;
	u32 reg_page;
	unsigned long link_freq_bitmap;
	const struct ar0830_mode *cur_mode;
	struct gpio_desc *reset_gpio;

	u8 num_data_lanes;
	/* firmware */
	const struct firmware *firmware;
};

static int ar0830_board_setup(struct ar0830 *ar0830);
static int ar0830_read(struct ar0830 *ar0830, u32 reg, u32 *val);
static int __ar0830_read(struct ar0830 *ar0830, u32 reg, u32 *val);
static int __ar0830_poll_param(struct ar0830 *ar0830, u32 reg,
		struct regmap **regmap, u16 *addr);

#ifdef DEBUG
static int ar0830_log_status(struct v4l2_subdev *sd);

static const char * const ar0830_warnings[] = {
	"HINF_BANDWIDTH",
	"FLICKER_DETECTION",
	"FACED_NE",
	"SMILED_NE",
	"HINF_OVERRUN",
	NULL,
	"FRAME_TOO_SMALL",
	"MISSING_PHASES",
	"SPOOF_UNDERRUN",
	"JPEG_NOLAST",
	"NO_IN_FREQ_SPEC",
	"SINF0",
	"SINF1",
	"CAPTURE0",
	"CAPTURE1",
	"ISR_UNHANDLED",
	"INTERLEAVE_SPOOF",
	"INTERLEAVE_BUF",
	"COORD_OUT_OF_RANGE",
	"ICP_CLOCKING",
	"SENSOR_CLOCKING",
	"SENSOR_NO_IHDR",
	"DIVIDE_BY_ZERO",
	"INT0_UNDERRUN",
	"INT1_UNDERRUN",
	"SCRATCHPAD_TOO_BIG",
	"OTP_RECORD_READ",
	"NO_LSC_IN_OTP",
	"GPIO_INT_LOST",
	"NO_PDAF_DATA",
	"FAR_PDAF_ACCESS_SKIP",
	"PDAF_ERROR",
	"ATM_TVI_BOUNDS",
	"SIPM_0_RTY",
	"SIPM_1_TRY",
	"SIPM_0_NO_ACK",
	"SIPM_1_NO_ACK",
	"SMILE_DIS",
	"DVS_DIS",
	"TEST_DIS",
	"SENSOR_LV2LV",
	"SENSOR_FV2FV",
	"FRAME_LOST",
};
#endif /* DEBUG */

#endif /* AR0830_H */
