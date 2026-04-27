// SPDX-License-Identifier: GPL-2.0
// Copyright (c) 2019 - 2024 Intel Corporation.

#include <linux/acpi.h>
#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/pm_runtime.h>
#include <media/v4l2-cci.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-event.h>
#include <media/v4l2-device.h>
#include <media/v4l2-fwnode.h>

/* Chip ID */
#define IMX586_REG_CHIP_ID		CCI_REG16(0x0016)
#define IMX586_CHIP_ID			0x0586

#define IMX586_REG_MODE_SELECT		CCI_REG8(0x0100)
#define IMX586_REG_VTS			CCI_REG16(0x0340)
#define IMX586_REG_EXPOSURE		CCI_REG16(0x0202)
#define IMX586_REG_ANALOG_GAIN		CCI_REG16(0x0204)
#define IMX586_REG_GLOBAL_GAIN		CCI_REG16(0x020E)
#define IMX586_REG_ORIENTATION		CCI_REG8(0x0101)
#define IMX586_REG_TEST_PATTERN		CCI_REG16_LE(0x0600)

#define IMX586_EXPOSURE_MIN		0
#define IMX586_EXPOSURE_MAX_MARGIN	80
#define IMX586_EXPOSURE_STEP		1

#define IMX586_ANALOG_GAIN_MIN		0
#define IMX586_ANALOG_GAIN_MAX		0x7f
#define IMX586_ANALOG_GAIN_STEP		1
#define IMX586_ANALOG_GAIN_DEFAULT	0xe

#define IMX586_GLOBAL_GAIN_MIN		0
#define IMX586_GLOBAL_GAIN_MAX		0x7ff
#define IMX586_GLOBAL_GAIN_STEP		1
#define IMX586_GLOBAL_GAIN_DEFAULT	0x80

#define IMX586_COMMON_WIDTH		4000
#define IMX586_COMMON_HEIGHT		3000
#define IMX586_PIXEL_ARRAY_LEFT		0
#define IMX586_PIXEL_ARRAY_TOP		0
#define IMX586_ORIENTATION_HFLIP	BIT(14)
#define IMX586_ORIENTATION_VFLIP	BIT(15)

#define IMX586_VTS_DEFAULT		3688
#define IMX586_VTS_MAX			0xffff
#define IMX586_HTS_DEFAULT		7808
#define IMX586_PPL_DEFAULT		7808

#define IMX586_MODE_STANDBY		0x00
#define IMX586_MODE_STREAMING		0x01

#define IMX586_PIXEL_RATE		448000000ULL
#define IMX586_XCLK_FREQ		24000000ULL

#define IMX586_TEST_PATTERN_DISABLE	0
#define IMX586_TEST_PATTERN_SOLID_COLOR	1
#define IMX586_TEST_PATTERN_COLOR_BARS	2
#define IMX586_TEST_PATTERN_GREY_COLOR	3
#define IMX586_TEST_PATTERN_WALKING	256

#define IMX586_PM_MAX_RETRY		10
#define IMX586_REG_SLEEP_200MS		200
static DEFINE_MUTEX(imx586_mutex);

#define to_imx586(_sd)	container_of(_sd, struct imx586, sd)

struct imx586_reg_list {
	u32 num_of_regs;
	const struct cci_reg_sequence *regs;
};

struct imx586_mode {
	u32 width;
	u32 height;
	u32 hts;
	u32 vts_def;
	u32 code;
	/* Sensor register settings for this mode */
	const struct imx586_reg_list reg_list;
};

static const struct cci_reg_sequence mode_4000x3000_10bit_4lane[] = {
	{ CCI_REG8(0x0136),0x18},
	{ CCI_REG8(0x0137),0x00},
	{ CCI_REG8(0x3C7E),0x01},
	{ CCI_REG8(0x3C7F),0x0A},
	{ CCI_REG8(0x0111),0x02},
	{ CCI_REG8(0x380C),0x00},
	{ CCI_REG8(0x3C00),0x10},
	{ CCI_REG8(0x3C01),0x10},
	{ CCI_REG8(0x3C02),0x10},
	{ CCI_REG8(0x3C03),0x10},
	{ CCI_REG8(0x3C04),0x10},
	{ CCI_REG8(0x3C05),0x01},
	{ CCI_REG8(0x3C06),0x00},
	{ CCI_REG8(0x3C07),0x00},
	{ CCI_REG8(0x3C08),0x03},
	{ CCI_REG8(0x3C09),0xFF},
	{ CCI_REG8(0x3C0A),0x01},
	{ CCI_REG8(0x3C0B),0x00},
	{ CCI_REG8(0x3C0C),0x00},
	{ CCI_REG8(0x3C0D),0x03},
	{ CCI_REG8(0x3C0E),0xFF},
	{ CCI_REG8(0x3C0F),0x20},
	{ CCI_REG8(0x3F88),0x00},
	{ CCI_REG8(0x3F8E),0x00},
	{ CCI_REG8(0x5282),0x01},
	{ CCI_REG8(0x9004),0x14},
	{ CCI_REG8(0x9200),0xF4},
	{ CCI_REG8(0x9201),0xA7},
	{ CCI_REG8(0x9202),0xF4},
	{ CCI_REG8(0x9203),0xAA},
	{ CCI_REG8(0x9204),0xF4},
	{ CCI_REG8(0x9205),0xAD},
	{ CCI_REG8(0x9206),0xF4},
	{ CCI_REG8(0x9207),0xB0},
	{ CCI_REG8(0x9208),0xF4},
	{ CCI_REG8(0x9209),0xB3},
	{ CCI_REG8(0x920A),0xB7},
	{ CCI_REG8(0x920B),0x34},
	{ CCI_REG8(0x920C),0xB7},
	{ CCI_REG8(0x920D),0x36},
	{ CCI_REG8(0x920E),0xB7},
	{ CCI_REG8(0x920F),0x37},
	{ CCI_REG8(0x9210),0xB7},
	{ CCI_REG8(0x9211),0x38},
	{ CCI_REG8(0x9212),0xB7},
	{ CCI_REG8(0x9213),0x39},
	{ CCI_REG8(0x9214),0xB7},
	{ CCI_REG8(0x9215),0x3A},
	{ CCI_REG8(0x9216),0xB7},
	{ CCI_REG8(0x9217),0x3C},
	{ CCI_REG8(0x9218),0xB7},
	{ CCI_REG8(0x9219),0x3D},
	{ CCI_REG8(0x921A),0xB7},
	{ CCI_REG8(0x921B),0x3E},
	{ CCI_REG8(0x921C),0xB7},
	{ CCI_REG8(0x921D),0x3F},
	{ CCI_REG8(0x921E),0x77},
	{ CCI_REG8(0x921F),0x77},
	{ CCI_REG8(0x9222),0xC4},
	{ CCI_REG8(0x9223),0x4B},
	{ CCI_REG8(0x9224),0xC4},
	{ CCI_REG8(0x9225),0x4C},
	{ CCI_REG8(0x9226),0xC4},
	{ CCI_REG8(0x9227),0x4D},
	{ CCI_REG8(0x9810),0x14},
	{ CCI_REG8(0x9814),0x14},
	{ CCI_REG8(0x99B2),0x20},
	{ CCI_REG8(0x99B3),0x0F},
	{ CCI_REG8(0x99B4),0x0F},
	{ CCI_REG8(0x99B5),0x0F},
	{ CCI_REG8(0x99B6),0x0F},
	{ CCI_REG8(0x99E4),0x0F},
	{ CCI_REG8(0x99E5),0x0F},
	{ CCI_REG8(0x99E6),0x0F},
	{ CCI_REG8(0x99E7),0x0F},
	{ CCI_REG8(0x99E8),0x0F},
	{ CCI_REG8(0x99E9),0x0F},
	{ CCI_REG8(0x99EA),0x0F},
	{ CCI_REG8(0x99EB),0x0F},
	{ CCI_REG8(0x99EC),0x0F},
	{ CCI_REG8(0x99ED),0x0F},
	{ CCI_REG8(0xA569),0x06},
	{ CCI_REG8(0xA56A),0x13},
	{ CCI_REG8(0xA56B),0x13},
	{ CCI_REG8(0xA679),0x20},
	{ CCI_REG8(0xA830),0x68},
	{ CCI_REG8(0xA831),0x56},
	{ CCI_REG8(0xA832),0x2B},
	{ CCI_REG8(0xA833),0x55},
	{ CCI_REG8(0xA834),0x55},
	{ CCI_REG8(0xA835),0x16},
	{ CCI_REG8(0xA837),0x51},
	{ CCI_REG8(0xA838),0x34},
	{ CCI_REG8(0xA854),0x4F},
	{ CCI_REG8(0xA855),0x48},
	{ CCI_REG8(0xA856),0x45},
	{ CCI_REG8(0xA857),0x02},
	{ CCI_REG8(0xA85A),0x23},
	{ CCI_REG8(0xA85B),0x16},
	{ CCI_REG8(0xA85C),0x12},
	{ CCI_REG8(0xA85D),0x02},
	{ CCI_REG8(0xAC72),0x01},
	{ CCI_REG8(0xAC73),0x26},
	{ CCI_REG8(0xAC74),0x01},
	{ CCI_REG8(0xAC75),0x26},
	{ CCI_REG8(0xAC76),0x00},
	{ CCI_REG8(0xAC77),0xC4},
	{ CCI_REG8(0xB051),0x02},
	{ CCI_REG8(0xC020),0x01},
	{ CCI_REG8(0xC61D),0x00},
	{ CCI_REG8(0xC625),0x00},
	{ CCI_REG8(0xC638),0x03},
	{ CCI_REG8(0xC63B),0x01},
	{ CCI_REG8(0xE286),0x31},
	{ CCI_REG8(0xE2A6),0x32},
	{ CCI_REG8(0xE2C6),0x33},
	{ CCI_REG8(0xEA4B),0x00},
	{ CCI_REG8(0xEA4C),0x00},
	{ CCI_REG8(0xEA4D),0x00},
	{ CCI_REG8(0xEA4E),0x00},
	{ CCI_REG8(0xF000),0x00},
	{ CCI_REG8(0xF001),0x10},
	{ CCI_REG8(0xF00C),0x00},
	{ CCI_REG8(0xF00D),0x40},
	{ CCI_REG8(0xF030),0x00},
	{ CCI_REG8(0xF031),0x10},
	{ CCI_REG8(0xF03C),0x00},
	{ CCI_REG8(0xF03D),0x40},
	{ CCI_REG8(0xF44B),0x80},
	{ CCI_REG8(0xF44C),0x10},
	{ CCI_REG8(0xF44D),0x06},
	{ CCI_REG8(0xF44E),0x80},
	{ CCI_REG8(0xF44F),0x10},
	{ CCI_REG8(0xF450),0x06},
	{ CCI_REG8(0xF451),0x80},
	{ CCI_REG8(0xF452),0x10},
	{ CCI_REG8(0xF453),0x06},
	{ CCI_REG8(0xF454),0x80},
	{ CCI_REG8(0xF455),0x10},
	{ CCI_REG8(0xF456),0x06},
	{ CCI_REG8(0xF457),0x80},
	{ CCI_REG8(0xF458),0x10},
	{ CCI_REG8(0xF459),0x06},
	{ CCI_REG8(0xF478),0x20},
	{ CCI_REG8(0xF479),0x80},
	{ CCI_REG8(0xF47A),0x80},
	{ CCI_REG8(0xF47B),0x20},
	{ CCI_REG8(0xF47C),0x80},
	{ CCI_REG8(0xF47D),0x80},
	{ CCI_REG8(0xF47E),0x20},
	{ CCI_REG8(0xF47F),0x80},
	{ CCI_REG8(0xF480),0x80},
	{ CCI_REG8(0xF481),0x20},
	{ CCI_REG8(0xF482),0x60},
	{ CCI_REG8(0xF483),0x80},
	{ CCI_REG8(0xF484),0x20},
	{ CCI_REG8(0xF485),0x60},
	{ CCI_REG8(0xF486),0x80},
	{ CCI_REG8(0x9852),0x00},
	{ CCI_REG8(0x9954),0x0F},
	{ CCI_REG8(0xA7AD),0x01},
	{ CCI_REG8(0xA7CB),0x01},
	{ CCI_REG8(0xAE09),0xFF},
	{ CCI_REG8(0xAE0A),0xFF},
	{ CCI_REG8(0xAE12),0x58},
	{ CCI_REG8(0xAE13),0x58},
	{ CCI_REG8(0xAE15),0x10},
	{ CCI_REG8(0xAE16),0x10},
	{ CCI_REG8(0xAF05),0x48},
	{ CCI_REG8(0xB07C),0x02},
	{ CCI_REG8(0x0112),0x0A},
	{ CCI_REG8(0x0113),0x0A},
	{ CCI_REG8(0x0114),0x03},
	{ CCI_REG8(0x0342),0x1E},
	{ CCI_REG8(0x0343),0x80},
	{ CCI_REG8(0x0340),0x12},
	{ CCI_REG8(0x0341),0x2A},
	{ CCI_REG8(0x0344),0x00},
	{ CCI_REG8(0x0345),0x00},
	{ CCI_REG8(0x0346),0x00},
	{ CCI_REG8(0x0347),0x00},
	{ CCI_REG8(0x0348),0x1F},
	{ CCI_REG8(0x0349),0x3F},
	{ CCI_REG8(0x034A),0x17},
	{ CCI_REG8(0x034B),0x6F},
	{ CCI_REG8(0x0220),0x62},
	{ CCI_REG8(0x0222),0x01},
	{ CCI_REG8(0x0900),0x01},
	{ CCI_REG8(0x0901),0x22},
	{ CCI_REG8(0x0902),0x08},
	{ CCI_REG8(0x3140),0x00},
	{ CCI_REG8(0x3246),0x81},
	{ CCI_REG8(0x3247),0x81},
	{ CCI_REG8(0x3F15),0x00},
	{ CCI_REG8(0x0401),0x00},
	{ CCI_REG8(0x0404),0x00},
	{ CCI_REG8(0x0405),0x10},
	{ CCI_REG8(0x0408),0x00},
	{ CCI_REG8(0x0409),0x00},
	{ CCI_REG8(0x040A),0x00},
	{ CCI_REG8(0x040B),0x00},
	{ CCI_REG8(0x040C),0x0F},
	{ CCI_REG8(0x040D),0xA0},
	{ CCI_REG8(0x040E),0x0B},
	{ CCI_REG8(0x040F),0xB8},
	{ CCI_REG8(0x034C),0x0F},
	{ CCI_REG8(0x034D),0xA0},
	{ CCI_REG8(0x034E),0x0B},
	{ CCI_REG8(0x034F),0xB8},
	{ CCI_REG8(0x0301),0x05},
	{ CCI_REG8(0x0303),0x02},
	{ CCI_REG8(0x0305),0x04},
	{ CCI_REG8(0x0306),0x00},
	{ CCI_REG8(0x0307),0xE3},
	{ CCI_REG8(0x030B),0x01},
	{ CCI_REG8(0x030D),0x04},
	{ CCI_REG8(0x030E),0x00},
	{ CCI_REG8(0x030F),0xFA},
	{ CCI_REG8(0x0310),0x01},
	{ CCI_REG8(0x3620),0x00},
	{ CCI_REG8(0x3621),0x00},
	{ CCI_REG8(0x3C11),0x06},
	{ CCI_REG8(0x3C12),0x06},
	{ CCI_REG8(0x3C13),0x2D},
	{ CCI_REG8(0x3F0C),0x00},
	{ CCI_REG8(0x3F14),0x00},
	{ CCI_REG8(0x3F80),0x00},
	{ CCI_REG8(0x3F81),0xFA},
	{ CCI_REG8(0x3F8C),0x00},
	{ CCI_REG8(0x3F8D),0x00},
	{ CCI_REG8(0x3FF8),0x00},
	{ CCI_REG8(0x3FF9),0x00},
	{ CCI_REG8(0x3FFE),0x03},
	{ CCI_REG8(0x3FFF),0x98},
	{ CCI_REG8(0x0202),0x11},
	{ CCI_REG8(0x0203),0xFA},
	{ CCI_REG8(0x0224),0x01},
	{ CCI_REG8(0x0225),0xF4},
	{ CCI_REG8(0x3FE0),0x01},
	{ CCI_REG8(0x3FE1),0xF4},
	{ CCI_REG8(0x0204),0x00},
	{ CCI_REG8(0x0205),0x70},
	{ CCI_REG8(0x0216),0x00},
	{ CCI_REG8(0x0217),0x70},
	{ CCI_REG8(0x0218),0x01},
	{ CCI_REG8(0x0219),0x00},
	{ CCI_REG8(0x020E),0x01},
	{ CCI_REG8(0x020F),0x00},
	{ CCI_REG8(0x0210),0x01},
	{ CCI_REG8(0x0211),0x00},
	{ CCI_REG8(0x0212),0x01},
	{ CCI_REG8(0x0213),0x00},
	{ CCI_REG8(0x0214),0x01},
	{ CCI_REG8(0x0215),0x00},
	{ CCI_REG8(0x3FE2),0x00},
	{ CCI_REG8(0x3FE3),0x70},
	{ CCI_REG8(0x3FE4),0x01},
	{ CCI_REG8(0x3FE5),0x00},
};

static const char * const imx586_test_pattern_menu[] = {
	"Disabled",
	"Color Bars",
	"Solid Color",
	"Grey Color Bars",
	"Walking 1s",
};

static const int imx586_test_pattern_val[] = {
	IMX586_TEST_PATTERN_DISABLE,
	IMX586_TEST_PATTERN_COLOR_BARS,
	IMX586_TEST_PATTERN_SOLID_COLOR,
	IMX586_TEST_PATTERN_GREY_COLOR,
	IMX586_TEST_PATTERN_WALKING,
};

static const s64 link_freq_menu_items[] = {
	1000000000ULL,
};

static const struct imx586_mode supported_modes[] = {
	{
		.width = IMX586_COMMON_WIDTH,
		.height = IMX586_COMMON_HEIGHT,
		.hts = IMX586_HTS_DEFAULT,
		.vts_def = IMX586_VTS_DEFAULT,
		.code = MEDIA_BUS_FMT_SGRBG10_1X10,
		.reg_list = {
			.num_of_regs = ARRAY_SIZE(mode_4000x3000_10bit_4lane),
			.regs = mode_4000x3000_10bit_4lane,
		},
	},
};

struct imx586 {
	struct v4l2_subdev sd;
	struct media_pad pad;
	struct v4l2_ctrl_handler ctrl_handler;

	/* V4L2 Controls */
	struct v4l2_ctrl *link_freq;
	struct v4l2_ctrl *exposure;
	struct v4l2_ctrl *hblank;
	struct v4l2_ctrl *vblank;
	struct v4l2_ctrl *vflip;
	struct v4l2_ctrl *hflip;
	struct regmap *regmap;
	unsigned long link_freq_bitmap;
	const struct imx586_mode *cur_mode;

	struct gpio_desc *reset_gpio;
	bool streaming;
};

static int imx586_set_ctrl(struct v4l2_ctrl *ctrl)
{
	struct imx586 *imx586 =
		container_of(ctrl->handler, struct imx586, ctrl_handler);
	struct i2c_client *client = v4l2_get_subdevdata(&imx586->sd);
	s64 exposure_max, exposure_def;
	struct v4l2_subdev_state *state;
	const struct v4l2_mbus_framefmt *format;
	int ret = 0;

	state = v4l2_subdev_get_locked_active_state(&imx586->sd);
	format = v4l2_subdev_state_get_format(state, 0);

	/* Propagate change of current control to all related controls */
	if (ctrl->id == V4L2_CID_VBLANK) {
		/* Update max exposure while meeting expected vblanking */
		exposure_max = format->height + ctrl->val -
			       IMX586_EXPOSURE_MAX_MARGIN;
		exposure_def = format->height - IMX586_EXPOSURE_MAX_MARGIN;
		__v4l2_ctrl_modify_range(imx586->exposure,
					imx586->exposure->minimum,
					exposure_max, imx586->exposure->step,
					exposure_def);
	}

	/* V4L2 controls values will be applied only when power is already up */
	if (!pm_runtime_get_if_in_use(&client->dev))
		return 0;

	switch (ctrl->id) {
	case V4L2_CID_ANALOGUE_GAIN:
		ret = cci_write(imx586->regmap, IMX586_REG_ANALOG_GAIN,
				ctrl->val, NULL);
		break;

	case V4L2_CID_DIGITAL_GAIN:
		ret = cci_write(imx586->regmap, IMX586_REG_GLOBAL_GAIN,
				ctrl->val, NULL);
		break;

	case V4L2_CID_EXPOSURE:
		ret = cci_write(imx586->regmap, IMX586_REG_EXPOSURE,
				ctrl->val, NULL);
		break;

	case V4L2_CID_VBLANK:
		ret = cci_write(imx586->regmap, IMX586_REG_VTS,
				imx586->cur_mode->height + ctrl->val, NULL);
		ret = cci_write(imx586->regmap, IMX586_REG_VTS,
				0xe68, NULL);
		break;

	case V4L2_CID_HFLIP:
	case V4L2_CID_VFLIP:;
		u64 reg;

		ret = cci_read(imx586->regmap, IMX586_REG_ORIENTATION,
				&reg, NULL);
		if (ret)
			break;

		reg &= ~(IMX586_ORIENTATION_HFLIP |
			 IMX586_ORIENTATION_VFLIP);
		if (imx586->hflip->val)
			reg |= IMX586_ORIENTATION_HFLIP;
		if (imx586->vflip->val)
			reg |= IMX586_ORIENTATION_VFLIP;

		ret = cci_write(imx586->regmap, IMX586_REG_ORIENTATION,
				reg, NULL);
		break;

	case V4L2_CID_TEST_PATTERN:
		ret = cci_write(imx586->regmap, IMX586_REG_TEST_PATTERN,
				imx586_test_pattern_val[ctrl->val], NULL);
		break;

	default:
		ret = -EINVAL;
		break;
	}

	pm_runtime_put(&client->dev);

	return ret;
}

static const struct v4l2_ctrl_ops imx586_ctrl_ops = {
	.s_ctrl = imx586_set_ctrl,
};

static int imx586_init_controls(struct imx586 *imx586)
{
	struct i2c_client *client = v4l2_get_subdevdata(&imx586->sd);
	struct v4l2_fwnode_device_properties props;
	struct v4l2_ctrl_handler *ctrl_hdlr;
	s64 exposure_max, vblank_max, vblank_def, hblank;
	u32 link_freq_size;
	int ret;

	ctrl_hdlr = &imx586->ctrl_handler;
	ret = v4l2_ctrl_handler_init(ctrl_hdlr, 10);
	if (ret)
		return ret;

	link_freq_size = ARRAY_SIZE(link_freq_menu_items) - 1;
	imx586->link_freq = v4l2_ctrl_new_int_menu(ctrl_hdlr,
						   &imx586_ctrl_ops,
						   V4L2_CID_LINK_FREQ,
						   link_freq_size, 0,
						   link_freq_menu_items);
	if (imx586->link_freq)
		imx586->link_freq->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops, V4L2_CID_ANALOGUE_GAIN,
			  IMX586_ANALOG_GAIN_MIN, IMX586_ANALOG_GAIN_MAX,
			  IMX586_ANALOG_GAIN_STEP, IMX586_ANALOG_GAIN_DEFAULT);
	v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops, V4L2_CID_DIGITAL_GAIN,
			  IMX586_GLOBAL_GAIN_MIN, IMX586_GLOBAL_GAIN_MAX,
			  IMX586_GLOBAL_GAIN_STEP, IMX586_GLOBAL_GAIN_DEFAULT);

	exposure_max = imx586->cur_mode->vts_def - IMX586_EXPOSURE_MAX_MARGIN;
	imx586->exposure = v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops,
					     V4L2_CID_EXPOSURE,
					     IMX586_EXPOSURE_MIN, exposure_max,
					     IMX586_EXPOSURE_STEP,
					     exposure_max);

	v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops, V4L2_CID_PIXEL_RATE,
			  IMX586_PIXEL_RATE, IMX586_PIXEL_RATE, 1,
			  IMX586_PIXEL_RATE);

	vblank_max = IMX586_VTS_MAX - imx586->cur_mode->height;
	vblank_def = imx586->cur_mode->vts_def - imx586->cur_mode->height;
	imx586->vblank = v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops,
					   V4L2_CID_VBLANK, 0, vblank_max, 1,
					   vblank_def);
	hblank = IMX586_PPL_DEFAULT - imx586->cur_mode->width;
	imx586->hblank = v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops,
					   V4L2_CID_HBLANK, hblank, hblank, 1,
					   hblank);
	if (imx586->hblank)
		imx586->hblank->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	imx586->hflip = v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops,
					  V4L2_CID_HFLIP, 0, 1, 1, 0);
	imx586->vflip = v4l2_ctrl_new_std(ctrl_hdlr, &imx586_ctrl_ops,
					  V4L2_CID_VFLIP, 0, 1, 1, 0);

	v4l2_ctrl_new_std_menu_items(ctrl_hdlr, &imx586_ctrl_ops,
				     V4L2_CID_TEST_PATTERN,
				     ARRAY_SIZE(imx586_test_pattern_menu) - 1,
				     0, 0, imx586_test_pattern_menu);

	if (ctrl_hdlr->error)
		return ctrl_hdlr->error;

	ret = v4l2_fwnode_device_parse(&client->dev, &props);
	if (ret)
		return ret;

	ret = v4l2_ctrl_new_fwnode_properties(ctrl_hdlr, &imx586_ctrl_ops,
					      &props);
	if (ret)
		return ret;

	imx586->sd.ctrl_handler = ctrl_hdlr;

	return 0;
}

static void imx586_update_pad_format(const struct imx586_mode *mode,
				     struct v4l2_mbus_framefmt *fmt)
{
	fmt->width = mode->width;
	fmt->height = mode->height;
	fmt->code = mode->code;
	fmt->field = V4L2_FIELD_NONE;
}

static int imx586_start_streaming(struct imx586 *imx586)
{
	struct i2c_client *client = v4l2_get_subdevdata(&imx586->sd);
	const struct imx586_reg_list *reg_list;
	int ret;

	ret = pm_runtime_resume_and_get(&client->dev);
	if (ret < 0)
		return ret;

	usleep_range(1000, 1500);

	reg_list = &imx586->cur_mode->reg_list;
	ret = cci_multi_reg_write(imx586->regmap, reg_list->regs,
				  reg_list->num_of_regs, NULL);
	if (ret) {
		dev_err(&client->dev, "failed to set mode");
		goto err_rpm_put;
	}

	ret = __v4l2_ctrl_handler_setup(imx586->sd.ctrl_handler);
	if (ret)
		goto err_rpm_put;

	ret = cci_write(imx586->regmap, IMX586_REG_MODE_SELECT,
			IMX586_MODE_STREAMING, NULL);
	if (ret) {
		dev_err(&client->dev, "failed to start stream");
		goto err_rpm_put;
	}

	imx586->streaming = true;
	return 0;

err_rpm_put:
	pm_runtime_put(&client->dev);
	return ret;
}

static int imx586_stop_streaming(struct imx586 *imx586)
{
	int ret;
	struct i2c_client *client = v4l2_get_subdevdata(&imx586->sd);

	ret = cci_write(imx586->regmap, IMX586_REG_MODE_SELECT,
			IMX586_MODE_STANDBY, NULL);
	if (ret < 0)
		dev_err(&client->dev, "failed to stop stream");

	imx586->streaming = false;

	return ret;
}

static int imx586_set_stream(struct v4l2_subdev *sd, int enable)
{
	struct imx586 *imx586 = to_imx586(sd);
	struct i2c_client *client = v4l2_get_subdevdata(sd);
	struct v4l2_subdev_state *state;
	int ret = 0;

	mutex_lock(&imx586_mutex);

	state = v4l2_subdev_lock_and_get_active_state(sd);

	if (imx586->streaming == enable)
		goto unlock;

	if (enable) {
		ret = pm_runtime_resume_and_get(&client->dev);
		if (ret < 0)
			goto unlock;

		ret = imx586_start_streaming(imx586);
		if (ret) {
			ret = imx586_stop_streaming(imx586);
			if (ret)
				goto unlock;
			pm_runtime_put(&client->dev);
		}
	}
	else {
		ret = imx586_stop_streaming(imx586);
		if (ret)
			goto unlock;
		pm_runtime_put(&client->dev);
	}

	/* vflip and hflip cannot change during streaming */
	__v4l2_ctrl_grab(imx586->vflip, enable);
	__v4l2_ctrl_grab(imx586->hflip, enable);
	v4l2_subdev_unlock_state(state);

unlock:
	mutex_unlock(&imx586_mutex);
	return ret;
}

static int imx586_set_format(struct v4l2_subdev *sd,
			     struct v4l2_subdev_state *sd_state,
			     struct v4l2_subdev_format *fmt)
{
	struct imx586 *imx586 = to_imx586(sd);
	struct i2c_client *client = v4l2_get_subdevdata(&imx586->sd);
	struct v4l2_rect *crop;
	const struct imx586_mode *mode;
	s64 hblank;
	int ret;

	mode = v4l2_find_nearest_size(supported_modes,
				      ARRAY_SIZE(supported_modes),
				      width, height,
				      fmt->format.width,
				      fmt->format.height);

	crop = v4l2_subdev_state_get_crop(sd_state, fmt->pad);
	crop->width = mode->width;
	crop->height = mode->height;

	imx586_update_pad_format(mode, &fmt->format);
	*v4l2_subdev_state_get_format(sd_state, fmt->pad) = fmt->format;

	if (fmt->which == V4L2_SUBDEV_FORMAT_TRY)
		return 0;

	imx586->cur_mode = mode;

	hblank = IMX586_PPL_DEFAULT - mode->width;
	ret = __v4l2_ctrl_modify_range(imx586->hblank, hblank, hblank,
				       1, hblank);
	if (ret) {
		dev_err(&client->dev, "HB ctrl range update failed");
		return ret;
	}

	/* Update limits and set FPS to default */
	ret = __v4l2_ctrl_modify_range(imx586->vblank, 0,
				       IMX586_VTS_MAX - mode->height, 1,
				       mode->vts_def - mode->height);
	if (ret) {
		dev_err(&client->dev, "VB ctrl range update failed");
		return ret;
	}

	ret = __v4l2_ctrl_s_ctrl(imx586->vblank, mode->vts_def - mode->height);
	if (ret) {
		dev_err(&client->dev, "VB ctrl set failed");
		return ret;
	}

	return 0;
}

static int imx586_enum_mbus_code(struct v4l2_subdev *sd,
				 struct v4l2_subdev_state *sd_state,
				 struct v4l2_subdev_mbus_code_enum *code)
{
	if (code->index > 0)
		return -EINVAL;

	code->code = MEDIA_BUS_FMT_SGRBG10_1X10;

	return 0;
}

static int imx586_enum_frame_size(struct v4l2_subdev *sd,
				  struct v4l2_subdev_state *sd_state,
				  struct v4l2_subdev_frame_size_enum *fse)
{
	if (fse->index >= ARRAY_SIZE(supported_modes))
		return -EINVAL;

	if (fse->code != MEDIA_BUS_FMT_SGRBG10_1X10)
		return -EINVAL;

	fse->min_width = supported_modes[fse->index].width;
	fse->max_width = fse->min_width;
	fse->min_height = supported_modes[fse->index].height;
	fse->max_height = fse->min_height;

	return 0;
}

static int imx586_get_selection(struct v4l2_subdev *sd,
				struct v4l2_subdev_state *state,
				struct v4l2_subdev_selection *sel)
{
	switch (sel->target) {
	case V4L2_SEL_TGT_CROP:
	case V4L2_SEL_TGT_CROP_DEFAULT:
	case V4L2_SEL_TGT_CROP_BOUNDS:
		sel->r.top = IMX586_PIXEL_ARRAY_TOP;
		sel->r.left = IMX586_PIXEL_ARRAY_LEFT;
		sel->r.width = IMX586_COMMON_WIDTH;
		sel->r.height = IMX586_COMMON_HEIGHT;
		break;

	default:
		return -EINVAL;
	}

	return 0;
}

static int imx586_init_state(struct v4l2_subdev *sd,
			     struct v4l2_subdev_state *sd_state)
{
	struct v4l2_subdev_format fmt = {
		.which = V4L2_SUBDEV_FORMAT_TRY,
		.pad = 0,
		.format = {
			.code = MEDIA_BUS_FMT_SGRBG10_1X10,
			.width = IMX586_COMMON_WIDTH,
			.height = IMX586_COMMON_HEIGHT,
		},
	};

	imx586_set_format(sd, sd_state, &fmt);

	return 0;
}

static const struct v4l2_subdev_video_ops imx586_video_ops = {
	.s_stream = imx586_set_stream,
};

static const struct v4l2_subdev_pad_ops imx586_pad_ops = {
	.set_fmt = imx586_set_format,
	.get_fmt = v4l2_subdev_get_fmt,
	.enum_mbus_code = imx586_enum_mbus_code,
	.enum_frame_size = imx586_enum_frame_size,
	.get_selection = imx586_get_selection,
};

static const struct v4l2_subdev_core_ops imx586_core_ops = {
	.subscribe_event = v4l2_ctrl_subdev_subscribe_event,
	.unsubscribe_event = v4l2_event_subdev_unsubscribe,
};

static const struct v4l2_subdev_ops imx586_subdev_ops = {
	.core = &imx586_core_ops,
	.video = &imx586_video_ops,
	.pad = &imx586_pad_ops,
};

static const struct media_entity_operations imx586_subdev_entity_ops = {
	.link_validate = v4l2_subdev_link_validate,
};

static const struct v4l2_subdev_internal_ops imx586_internal_ops = {
	.init_state = imx586_init_state,
};

static int imx586_parse_fwnode(struct imx586 *imx586, struct device *dev)
{
	struct fwnode_handle *endpoint;
	struct v4l2_fwnode_endpoint bus_cfg = {
		.bus_type = V4L2_MBUS_CSI2_DPHY,
	};
	int ret;

	endpoint =
		fwnode_graph_get_endpoint_by_id(dev_fwnode(dev), 0, 0,
						FWNODE_GRAPH_ENDPOINT_NEXT);
	if (!endpoint) {
		dev_err(dev, "endpoint node not found");
		return -EPROBE_DEFER;
	}

	ret = v4l2_fwnode_endpoint_alloc_parse(endpoint, &bus_cfg);
	if (ret) {
		dev_err(dev, "parsing endpoint node failed");
		goto out_err;
	}

	dev_dbg(dev, "lane = %d\n", bus_cfg.bus.mipi_csi2.num_data_lanes);
	/* Check the number of MIPI CSI2 data lanes */
	if (bus_cfg.bus.mipi_csi2.num_data_lanes != 4) {
		dev_err(dev, "only 4 data lanes are currently supported");
		goto out_err;
	}

	ret = v4l2_link_freq_to_bitmap(dev, bus_cfg.link_frequencies,
				       bus_cfg.nr_of_link_frequencies,
				       link_freq_menu_items,
				       ARRAY_SIZE(link_freq_menu_items),
				       &imx586->link_freq_bitmap);
	if (ret)
		goto out_err;

out_err:
	v4l2_fwnode_endpoint_free(&bus_cfg);
	fwnode_handle_put(endpoint);
	return ret;
}

static int imx586_identify_module(struct imx586 *imx586)
{
	struct i2c_client *client = v4l2_get_subdevdata(&imx586->sd);
	int ret;
	u64 val;

	ret = cci_read(imx586->regmap, IMX586_REG_CHIP_ID, &val, NULL);
	if (ret)
		return ret;

	if (val != IMX586_CHIP_ID) {
		dev_err(&client->dev, "chip id mismatch: %x!=%llx",
			IMX586_CHIP_ID, val);
		return -ENXIO;
	}

	return 0;
}

static void imx586_remove(struct i2c_client *client)
{
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct imx586 *imx586 = to_imx586(sd);

	v4l2_async_unregister_subdev(&imx586->sd);
	v4l2_subdev_cleanup(sd);
	media_entity_cleanup(&imx586->sd.entity);
	v4l2_ctrl_handler_free(&imx586->ctrl_handler);
	pm_runtime_disable(&client->dev);
	pm_runtime_set_suspended(&client->dev);
}
static int imx586_reset(struct gpio_desc *reset_gpio)
{
	if (!IS_ERR_OR_NULL(reset_gpio)) {
		gpiod_direction_output(reset_gpio, 0);

		gpiod_set_value_cansleep(reset_gpio, 1);
		msleep(10);

		gpiod_set_value_cansleep(reset_gpio, 0);
		msleep(10);

		return 0;
	}

	return -EINVAL;
}
static int imx586_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct imx586 *imx586;
	struct clk *xclk;
	u32 xclk_freq;
	int ret;

	imx586 = devm_kzalloc(&client->dev, sizeof(*imx586), GFP_KERNEL);
	if (!imx586)
		return -ENOMEM;

	ret = imx586_parse_fwnode(imx586, dev);
	if (ret)
		return ret;

	imx586->regmap = devm_cci_regmap_init_i2c(client, 16);
	if (IS_ERR(imx586->regmap))
		return dev_err_probe(dev, PTR_ERR(imx586->regmap),
				     "failed to init CCI");

	v4l2_i2c_subdev_init(&imx586->sd, client, &imx586_subdev_ops);

	imx586->reset_gpio = devm_gpiod_get_optional(&client->dev, "reset",
							GPIOD_ASIS);
	if (IS_ERR(imx586->reset_gpio))
		return -EPROBE_DEFER;
	else if (imx586->reset_gpio == NULL)
		dev_warn(&client->dev, "Reset GPIO not found");
	else {
		dev_dbg(&client->dev, "Found reset GPIO");
		imx586_reset(imx586->reset_gpio);
	}

	xclk = devm_clk_get_optional(dev, NULL);
	if (IS_ERR(xclk)) {
		if (PTR_ERR(xclk) != -EPROBE_DEFER)
			dev_err(dev, "failed to get xclk %ld", PTR_ERR(xclk));
		return PTR_ERR(xclk);
	}

	xclk_freq = clk_get_rate(xclk);
	if (xclk_freq != IMX586_XCLK_FREQ) {
		dev_err(dev, "xclk frequency not supported: %d Hz", xclk_freq);
		return -EINVAL;
	}

	ret = clk_prepare_enable(xclk);
	if (ret < 0) {
		dev_err(dev, "failed to enable imaging clock: %d", ret);
		return ret;
	}
	usleep_range(10000, 15000);

	/* Check module identity */
	ret = imx586_identify_module(imx586);
	if (ret) {
		dev_err(dev, "failed to find sensor: %d", ret);
		return ret;
	}

	imx586->cur_mode = &supported_modes[0];
	ret = imx586_init_controls(imx586);
	if (ret) {
		dev_err(&client->dev, "failed to init controls: %d", ret);
		goto probe_error_v4l2_ctrl_handler_free;
	}

	imx586->sd.internal_ops = &imx586_internal_ops;
	imx586->sd.flags |= V4L2_SUBDEV_FL_HAS_DEVNODE |
			    V4L2_SUBDEV_FL_HAS_EVENTS;
	imx586->sd.entity.ops = &imx586_subdev_entity_ops;
	imx586->sd.entity.function = MEDIA_ENT_F_CAM_SENSOR;

	imx586->pad.flags = MEDIA_PAD_FL_SOURCE;
	ret = media_entity_pads_init(&imx586->sd.entity, 1, &imx586->pad);
	if (ret) {
		dev_err(&client->dev, "failed to init entity pads: %d", ret);
		goto probe_error_v4l2_ctrl_handler_free;
	}

	imx586->sd.state_lock = imx586->ctrl_handler.lock;
	ret = v4l2_subdev_init_finalize(&imx586->sd);
	if (ret < 0) {
		dev_err(dev, "v4l2 subdev init error: %d", ret);
		goto probe_error_media_entity_cleanup;
	}

	/*
	 * Device is already turned on by i2c-core with ACPI domain PM.
	 * Enable runtime PM and turn off the device.
	 */
	pm_runtime_set_active(&client->dev);
	pm_runtime_enable(&client->dev);
	pm_runtime_idle(&client->dev);

	ret = v4l2_async_register_subdev_sensor(&imx586->sd);
	if (ret < 0) {
		dev_err(&client->dev, "failed to register V4L2 subdev: %d",
			ret);
		goto probe_error_rpm;
	}

	return 0;
probe_error_rpm:
	pm_runtime_disable(&client->dev);
	v4l2_subdev_cleanup(&imx586->sd);

probe_error_media_entity_cleanup:
	media_entity_cleanup(&imx586->sd.entity);

probe_error_v4l2_ctrl_handler_free:
	v4l2_ctrl_handler_free(imx586->sd.ctrl_handler);

	return ret;
}

static int __maybe_unused imx586_suspend(struct device *dev)
{
	struct i2c_client *client = to_i2c_client(dev);
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct imx586 *imx586 = to_imx586(sd);

	mutex_lock(&imx586_mutex);

	// TODO: Add logic to support suspend during streaming later

	if (imx586->streaming)
		imx586_stop_streaming(imx586);

	mutex_unlock(&imx586_mutex);

	if (imx586->reset_gpio)
		gpiod_set_value_cansleep(imx586->reset_gpio, 1);

	return 0;
}

static int __maybe_unused imx586_resume(struct device *dev)
{
	struct i2c_client *client = to_i2c_client(dev);
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct imx586 *imx586 = to_imx586(sd);
	int ret;
	int count;

	mutex_lock(&imx586_mutex);

	if (imx586->reset_gpio) {
		for (count = 0; count < IMX586_PM_MAX_RETRY; count++) {
			gpiod_set_value_cansleep(imx586->reset_gpio, 0);
			msleep(IMX586_REG_SLEEP_200MS);

			ret = gpiod_get_value_cansleep(imx586->reset_gpio);
			if (ret == 0)
				break;
		}

		if (ret != 0) {
			dev_err(&client->dev, "failed to power on sensor in pm resume");
			mutex_unlock(&imx586_mutex);
			return -ETIMEDOUT;
		}
	}

	// TODO: Add logic to support resume streaming after back from suspend later

	if (imx586->streaming) {
		ret = imx586_start_streaming(imx586);
		if (ret) {
			imx586_stop_streaming(imx586);
			goto unlock;
		}
	}

unlock:
	mutex_unlock(&imx586_mutex);
	return 0;
}

static const struct dev_pm_ops imx586_pm_ops = {
	SET_SYSTEM_SLEEP_PM_OPS(imx586_suspend, imx586_resume)
};

static const struct acpi_device_id imx586_acpi_ids[] = {
	{ "IMXSN586" },
	{}
};
MODULE_DEVICE_TABLE(acpi, imx586_acpi_ids);

static struct i2c_driver imx586_i2c_driver = {
	.driver = {
		.name = "imx586",
		.acpi_match_table = ACPI_PTR(imx586_acpi_ids),
		.pm = &imx586_pm_ops,
	},
	.probe = imx586_probe,
	.remove = imx586_remove,
};

module_i2c_driver(imx586_i2c_driver);

MODULE_DESCRIPTION("ON Semiconductor imx586 sensor driver");
MODULE_AUTHOR("Dongcheng Yan <dongcheng.yan@intel.com>");
MODULE_AUTHOR("Hao Yao <hao.yao@intel.com>");
MODULE_LICENSE("GPL");
