// SPDX-License-Identifier: GPL-2.0
// Copyright (c) 2022-2025 Intel Corporation.

#include <linux/acpi.h>
#include <linux/delay.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/pm_runtime.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/version.h>
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)
#include <asm/unaligned.h>
#else
#include <linux/unaligned.h>
#endif
#include <media/v4l2-ctrls.h>
#include <media/v4l2-device.h>
#include <media/v4l2-fwnode.h>
#include "media/i2c/ar0820.h"
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 10, 0)
#include <media/mipi-csi2.h>
#endif
#define to_ar0820(_sd)                  container_of(_sd, struct ar0820, sd)


struct ar0820_reg {
        enum {
                AR0820_REG_LEN_DELAY = 0,
                AR0820_REG_LEN_08BIT = 1,
                AR0820_REG_LEN_16BIT = 2,
        } mode;
        u16 address;
        u16 val;
};

struct ar0820_reg_list {
        u32 num_of_regs;
        const struct ar0820_reg *regs;
};

struct ar0820_mode {
        /* Frame width in pixels */
        u32 width;

        /* Frame height in pixels */
        u32 height;

        /* MEDIA_BUS_FMT */
        u32 code;

        /* MODE_FPS*/
        u32 fps;

        /* Sensor register settings for this resolution */
        const struct ar0820_reg_list reg_list;
};

struct ar0820 {
        struct v4l2_subdev sd;
        struct media_pad pad;

        /* Current mode */
        const struct ar0820_mode *cur_mode;
        /* Previous mode */
        const struct ar0820_mode *pre_mode;

        /* To serialize asynchronus callbacks */
        struct mutex mutex;

        /* i2c client */
        struct i2c_client *client;

        struct ar0820_platform_data *platform_data;
        struct gpio_desc *reset_gpio;
	struct gpio_desc *fsin_gpio;

        /* Streaming on/off */
        bool streaming;
};

static const struct ar0820_reg ar0820_3840_2160_30fps_reg[] = {
	/* TODO: Waiting for Sensing register list */
	{0,0,0},
	{0,0,0},
	{0,0,0},
};

static const struct ar0820_reg_list ar0820_3840_2160_30fps_reg_list = {
	.num_of_regs = ARRAY_SIZE(ar0820_3840_2160_30fps_reg),
	.regs = ar0820_3840_2160_30fps_reg,
};

static const struct ar0820_mode supported_modes[] = {
	{
		.width = 3840,
		.height = 2160,
		.code = MEDIA_BUS_FMT_UYVY8_1X16,
		.fps = 30,
		.reg_list = ar0820_3840_2160_30fps_reg_list,
	},
};

static int ar0820_identify_module(struct ar0820 *ar0820)
{
        
        struct i2c_client *client = ar0820->client;

	dev_dbg(&client->dev, "%s: Enter", __func__);

        return 0;
}

static void ar0820_update_pad_format(const struct ar0820_mode *mode,
                                     struct v4l2_mbus_framefmt *fmt)
{
        fmt->width = mode->width;
        fmt->height = mode->height;
        fmt->code = mode->code;
        fmt->field = V4L2_FIELD_NONE;
}

static int ar0820_start_streaming(struct ar0820 *ar0820)
{
        struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);

        return 0;
}

static int ar0820_stop_streaming(struct ar0820 *ar0820)
{
        struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);

	return 0;	
}

static int ar0820_set_stream(struct v4l2_subdev *subdev, int enable)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
        struct i2c_client *client = ar0820->client;
	int ret = 0;

        dev_dbg(&client->dev, "%s: Enter", __func__);
	
        if (ar0820->streaming == enable)
                return 0;

        mutex_lock(&ar0820->mutex);
	if (enable) {
		ret = pm_runtime_get_sync(&client->dev);
		if (ret < 0) {
			pm_runtime_put_noidle(&client->dev);
			mutex_unlock(&ar0820->mutex);
			return ret;
		}

		ret = ar0820_start_streaming(ar0820);
		if (ret) {
			enable = 0;
			ret = ar0820_stop_streaming(ar0820);
			pm_runtime_put(&client->dev);
		}
	} else {
		ret = ar0820_stop_streaming(ar0820);
		pm_runtime_put(&client->dev);
	}
	
        ar0820->streaming = enable;

        mutex_unlock(&ar0820->mutex);

        return ret;
}

static int ar0820_enable_streams(struct v4l2_subdev *subdev,
        struct v4l2_subdev_state *state,
        u32 pad, u64 streams_mask)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
        struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);

        return ar0820_set_stream(subdev, true);
}

static int ar0820_disable_streams(struct v4l2_subdev *subdev,
         struct v4l2_subdev_state *state,
         u32 pad, u64 streams_mask)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
        struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);
	
        return ar0820_set_stream(subdev, false);
}

static int __maybe_unused ar0820_suspend(struct device *dev)
{
	return 0;
}

static int __maybe_unused ar0820_resume(struct device *dev)
{
	return 0;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 10, 0)
static unsigned int ar0820_mbus_code_to_mipi(u32 code)
{
        switch (code) {
        case MEDIA_BUS_FMT_RGB565_1X16:
                return MIPI_CSI2_DT_RGB565;
        case MEDIA_BUS_FMT_RGB888_1X24:
                return MIPI_CSI2_DT_RGB888;
        case MEDIA_BUS_FMT_UYVY8_1X16:
        case MEDIA_BUS_FMT_YUYV8_1X16:
                return MIPI_CSI2_DT_YUV422_8B;
        case MEDIA_BUS_FMT_SBGGR16_1X16:
        case MEDIA_BUS_FMT_SGBRG16_1X16:
        case MEDIA_BUS_FMT_SGRBG16_1X16:
        case MEDIA_BUS_FMT_SRGGB16_1X16:
                return MIPI_CSI2_DT_RAW16;
        case MEDIA_BUS_FMT_SBGGR12_1X12:
        case MEDIA_BUS_FMT_SGBRG12_1X12:
        case MEDIA_BUS_FMT_SGRBG12_1X12:
        case MEDIA_BUS_FMT_SRGGB12_1X12:
                return MIPI_CSI2_DT_RAW12;
        case MEDIA_BUS_FMT_SBGGR10_1X10:
        case MEDIA_BUS_FMT_SGBRG10_1X10:
        case MEDIA_BUS_FMT_SGRBG10_1X10:
        case MEDIA_BUS_FMT_SRGGB10_1X10:
                return MIPI_CSI2_DT_RAW10;
        case MEDIA_BUS_FMT_SBGGR8_1X8:
        case MEDIA_BUS_FMT_SGBRG8_1X8:
        case MEDIA_BUS_FMT_SGRBG8_1X8:
        case MEDIA_BUS_FMT_SRGGB8_1X8:
                return MIPI_CSI2_DT_RAW8;
        default:
                /* return unavailable MIPI data type - 0x3f */
                WARN_ON(1);
                return 0x3f;
        }
}
#endif

static int ar0820_get_frame_desc(struct v4l2_subdev *subdev,
        unsigned int pad, struct v4l2_mbus_frame_desc *desc)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
	unsigned int i;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 10, 0)
        desc->type = V4L2_MBUS_FRAME_DESC_TYPE_CSI2;
#endif
        desc->num_entries = V4L2_FRAME_DESC_ENTRY_MAX;

        for (i = 0; i < desc->num_entries; i++) {
                desc->entry[i].flags = 0;
                desc->entry[i].pixelcode = MEDIA_BUS_FMT_FIXED;
                desc->entry[i].length = 0;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 10, 0)
                desc->entry[i].stream = i;
                desc->entry[i].bus.csi2.vc = i;
                desc->entry[i].bus.csi2.dt = ar0820_mbus_code_to_mipi(ar0820->cur_mode->code);
#endif
        }

	return 0;
}

static int ar0820_set_format(struct v4l2_subdev *subdev,
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 14, 0)
                             struct v4l2_subdev_pad_config *cfg,
#else
                             struct v4l2_subdev_state *sd_state,
#endif
                             struct v4l2_subdev_format *fmt)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
	const struct ar0820_mode *mode;
	int i;
	struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);

        for (i = 0; i < ARRAY_SIZE(supported_modes); i++)
                if (supported_modes[i].code == fmt->format.code &&
                    supported_modes[i].width == fmt->format.width &&
                    supported_modes[i].height == fmt->format.height) {
                        mode = &supported_modes[i];
                        break;
                }

        if (i >= ARRAY_SIZE(supported_modes))
                mode = &supported_modes[0];

        mutex_lock(&ar0820->mutex);

        ar0820_update_pad_format(mode, &fmt->format);
        if (fmt->which == V4L2_SUBDEV_FORMAT_TRY) {
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 14, 0)
                *v4l2_subdev_get_try_format(sd, cfg, fmt->pad) = fmt->format;
#elif LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)
                *v4l2_subdev_get_try_format(sd, sd_state, fmt->pad) = fmt->format;
#else
                *v4l2_subdev_state_get_format(sd_state, fmt->pad) = fmt->format;
#endif
        } else {
                ar0820->cur_mode = mode;
        }

        mutex_unlock(&ar0820->mutex);
	
	return 0;
}

static int ar0820_get_format(struct v4l2_subdev *subdev,
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 14, 0)
                             struct v4l2_subdev_pad_config *cfg,
#else
                             struct v4l2_subdev_state *sd_state,
#endif
                             struct v4l2_subdev_format *fmt)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
        struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);

        mutex_lock(&ar0820->mutex);
        if (fmt->which == V4L2_SUBDEV_FORMAT_TRY)
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 14, 0)
                fmt->format = *v4l2_subdev_get_try_format(&ar0820->sd, cfg,
                                                          fmt->pad);
#elif LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)
                fmt->format = *v4l2_subdev_get_try_format(&ar0820->sd, sd_state,
                                                          fmt->pad);
#else
                fmt->format = *v4l2_subdev_state_get_format(sd_state,
                                                          fmt->pad);
#endif
        else
                ar0820_update_pad_format(ar0820->cur_mode, &fmt->format);

        mutex_unlock(&ar0820->mutex);
	
	return 0;
}

static int ar0820_open(struct v4l2_subdev *subdev, struct v4l2_subdev_fh *fh)
{
        struct ar0820 *ar0820 = to_ar0820(subdev);
        struct i2c_client *client = ar0820->client;

        dev_dbg(&client->dev, "%s: Enter", __func__);

        mutex_lock(&ar0820->mutex);
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 14, 0)
        ar0820_update_pad_format(&supported_modes[0],
                                 v4l2_subdev_get_try_format(sd, fh->pad, 0));
#elif LINUX_VERSION_CODE < KERNEL_VERSION(6, 8, 0)
        ar0820_update_pad_format(&supported_modes[0],
                                 v4l2_subdev_get_try_format(sd, fh->state, 0));
#else
        ar0820_update_pad_format(&supported_modes[0],
                                 v4l2_subdev_state_get_format(fh->state, 0));
#endif
        mutex_unlock(&ar0820->mutex);	
	
	return 0;
}

static const struct v4l2_subdev_video_ops ar0820_video_ops = {
        .s_stream = ar0820_set_stream,
};

static const struct v4l2_subdev_pad_ops ar0820_pad_ops = {
        .set_fmt = ar0820_set_format,
        .get_fmt = ar0820_get_format,
        .get_frame_desc = ar0820_get_frame_desc,
        .enable_streams = ar0820_enable_streams,
        .disable_streams = ar0820_disable_streams,
};

static const struct v4l2_subdev_ops ar0820_subdev_ops = {
        .video = &ar0820_video_ops,
        .pad = &ar0820_pad_ops,
};

static const struct media_entity_operations ar0820_subdev_entity_ops = {
        .link_validate = v4l2_subdev_link_validate,
};

static const struct v4l2_subdev_internal_ops ar0820_internal_ops = {
        .open = ar0820_open,
};

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 0)
static int ar0820_remove(struct i2c_client *client)
#else
static void ar0820_remove(struct i2c_client *client)
#endif
{
        dev_dbg(&client->dev, "%s: Enter", __func__);

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 1, 0)
	return 0;
#endif
}

static int ar0820_probe(struct i2c_client *client)
{
        struct v4l2_subdev *sd;
        struct ar0820 *ar0820;
        int ret;

        dev_dbg(&client->dev, "%s: Enter", __func__);
	
	ar0820 = devm_kzalloc(&client->dev, sizeof(*ar0820), GFP_KERNEL);
	if(!ar0820)
		return -ENOMEM;

        ar0820->client = client;
        ar0820->platform_data = client->dev.platform_data;
        if (ar0820->platform_data == NULL)
                dev_warn(&client->dev, "no platform data provided\n");

        ar0820->reset_gpio = devm_gpiod_get_optional(&client->dev, "reset",
                                                     GPIOD_OUT_LOW);

        if (IS_ERR(ar0820->reset_gpio))
                return -EPROBE_DEFER;
        else if (ar0820->reset_gpio == NULL)
                dev_warn(&client->dev, "Reset GPIO not found");
        else {
                dev_dbg(&client->dev, "Found reset GPIO");
        }

        ar0820->fsin_gpio = devm_gpiod_get_optional(&client->dev, "fsin",
                                		    GPIOD_OUT_LOW);

        if (IS_ERR(ar0820->fsin_gpio))
                return -EPROBE_DEFER;
        else if (ar0820->fsin_gpio == NULL)
                dev_warn(&client->dev, "FSIN GPIO not found");
        else {
                dev_dbg(&client->dev, "Found FSIN GPIO");
        }
	
        /* initialize subdevice */
        sd = &ar0820->sd;
        v4l2_i2c_subdev_init(sd, client, &ar0820_subdev_ops);
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 10, 0)
        sd->flags |= V4L2_SUBDEV_FL_HAS_DEVNODE | V4L2_SUBDEV_FL_HAS_EVENTS;
#else
        sd->flags |= V4L2_SUBDEV_FL_HAS_DEVNODE;
#endif
        sd->internal_ops = &ar0820_internal_ops;
        sd->entity.ops = &ar0820_subdev_entity_ops;
        sd->entity.function = MEDIA_ENT_F_CAM_SENSOR;

        /* initialize subdev media pad */
        ar0820->pad.flags = MEDIA_PAD_FL_SOURCE;
        ret = media_entity_pads_init(&sd->entity, 1, &ar0820->pad);
        if (ret < 0) {
                dev_err(&client->dev,
                        "%s : media entity init Failed %d\n", __func__, ret);
                return ret;
        }

        ret = ar0820_identify_module(ar0820);
        if (ret) {
                dev_err(&client->dev, "failed to find sensor: %d", ret);
                return ret;
        }

        if (ar0820->platform_data && ar0820->platform_data->suffix)
                snprintf(ar0820->sd.name, sizeof(ar0820->sd.name), "ar0820 %c",
                         ar0820->platform_data->suffix);

        mutex_init(&ar0820->mutex);

        ar0820->pre_mode = &supported_modes[0];
        ar0820->cur_mode = ar0820->pre_mode;
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 13, 0)
        ret = v4l2_async_register_subdev_sensor_common(&ar0820->sd);
#else
        ret = v4l2_async_register_subdev_sensor(&ar0820->sd);
#endif
        if (ret < 0) {
                dev_err(&client->dev, "failed to register V4L2 subdev: %d",
                        ret);
                goto probe_error_media_entity_cleanup;
        }

        /*
         * Device is already turned on by i2c-core with ACPI domain PM.
         * Enable runtime PM and turn off the device.
         */
        pm_runtime_set_active(&client->dev);
        pm_runtime_enable(&client->dev);
        pm_runtime_idle(&client->dev);

        dev_dbg(&client->dev, "%s: Leave ", __func__);
	
        return 0;

probe_error_media_entity_cleanup:
        media_entity_cleanup(&ar0820->sd.entity);
        mutex_destroy(&ar0820->mutex);
		
	return ret;
}	

static const struct dev_pm_ops ar0820_pm_ops = {
        SET_SYSTEM_SLEEP_PM_OPS(ar0820_suspend, ar0820_resume)
};

static const struct i2c_device_id ar0820_id_table[] = {
        { "ar0820", 0 },
        { /* sentinel */ },
};
MODULE_DEVICE_TABLE(i2c, ar0820_id_table);

static struct i2c_driver ar0820_i2c_driver = {
        .driver = {
                .name = "ar0820",
                .pm = &ar0820_pm_ops,
        },
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 6, 0)
        .probe_new = ar0820_probe,
#else
        .probe = ar0820_probe,
#endif
        .remove = ar0820_remove,
        .id_table = ar0820_id_table,
};

module_i2c_driver(ar0820_i2c_driver);

MODULE_AUTHOR("Tay Boon Wooi <boonx.wooi.tay@intel.com>");
MODULE_DESCRIPTION("ar0820 sensor driver");
MODULE_LICENSE("GPL v2");

