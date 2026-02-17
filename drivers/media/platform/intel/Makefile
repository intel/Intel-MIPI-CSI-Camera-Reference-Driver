# SPDX-License-Identifier: GPL-2.0

# Copyright (c) 2010 - 2025 Intel Corporation.

ccflags-y += -I$(src)/../../../../ipu7-drivers/drivers/media/pci/intel/ipu7

obj-$(CONFIG_INTEL_IPU_ACPI)         += ipu-acpi.o \
					ipu-acpi-pdata.o \
					ipu-acpi-common.o

ifeq ($(CONFIG_VIDEO_D4XX), m)
	ccflags-y += -DCONFIG_VIDEO_D4XX
endif

ifeq ($(CONFIG_VIDEO_MAX9X), m)
	ccflags-y += -DCONFIG_VIDEO_MAX9X
endif
