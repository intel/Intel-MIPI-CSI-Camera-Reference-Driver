# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2010 - 2025 Intel Corporation.

KERNEL_VERSION := $(shell echo $(KERNELRELEASE) | cut -d- -f1 | sed -r 's/([0-9]+\.[0-9]+).*/\1.0/g')

ccflags-y := -DDRIVER_VERSION_SUFFIX=\"${DRIVER_VERSION_SUFFIX}\"

ccflags-y += -I$(src)/../../../ipu7-drivers/drivers/media/pci/intel/ipu7
ccflags-y += -I$(src)/../../../$(KERNEL_VERSION)/include-overrides

obj-$(CONFIG_VIDEO_AR0234) += ar0234.o
obj-$(CONFIG_VIDEO_AR0820) += ar0820.o
obj-$(CONFIG_VIDEO_ISX031) += isx031.o

ifeq ($(CONFIG_VIDEO_D4XX), m)
	ccflags-y += -DCONFIG_VIDEO_D4XX_SERDES
endif

subdir-ccflags-y := -DDRIVER_VERSION_SUFFIX=\"${DRIVER_VERSION_SUFFIX}\"
obj-$(CONFIG_VIDEO_MAX9X) += max9x/
obj-$(CONFIG_VIDEO_D4XX_MAX9295) += d4xx-max9295.o
obj-$(CONFIG_VIDEO_D4XX_MAX9296) += d4xx-max9296.o
obj-$(CONFIG_VIDEO_D4XX) += d4xx.o
