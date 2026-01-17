# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2010 - 2025 Intel Corporation.

KERNEL_VERSION := $(shell echo $(KERNELRELEASE) | sed 's/[^0-9.]*\([0-9]\.[0-9]*\)\..*/\1.0/')

CC := ${CC} -I ${M}/$(KERNEL_VERSION)/include-overrides

obj-$(CONFIG_VIDEO_AR0234) += ar0234.o
obj-$(CONFIG_VIDEO_AR0820) += ar0820.o
obj-$(CONFIG_VIDEO_ISX031) += isx031.o

ccflags-y := -DDRIVER_VERSION_SUFFIX=\"${DRIVER_VERSION_SUFFIX}\"
