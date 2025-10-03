# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2025 Intel Corporation.

KERNELRELEASE ?= $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KERNELRELEASE)/build
KERNEL_VERSION := $(shell echo $(KERNELRELEASE) | cut -d- -f1 | sed -r 's/([0-9]+\.[0-9]+).*/\1.0/g')
BUILD_EXCLUSIVE_KERNEL="^(6\.(1[278])\.)"

MODSRC := $(shell pwd)

subdir-ccflags-y += -DDRIVER_VERSION_SUFFIX=\"${DRIVER_VERSION_SUFFIX}\"

# Define config macros for conditional compilation in ipu6-acpi.c
# IS_ENABLED() checks for CONFIG_XXX or CONFIG_XXX_MODULE
subdir-ccflags-y += -DCONFIG_VIDEO_MAX9X_MODULE=1
subdir-ccflags-y += -DCONFIG_VIDEO_D4XX_MODULE=1
subdir-ccflags-y += -DCONFIG_VIDEO_ISX031_MODULE=1
subdir-ccflags-y += -DCONFIG_VIDEO_AR0820_MODULE=1
subdir-ccflags-y += -DCONFIG_VIDEO_AR0234_MODULE=1
subdir-ccflags-y += -DCONFIG_IPU_BRIDGE_MODULE=1

export EXTERNAL_BUILD = 1
export CONFIG_IPU_BRIDGE=m
export CONFIG_VIDEO_AR0820=m
export CONFIG_VIDEO_AR0234=m
export CONFIG_VIDEO_ISX031=m
export CONFIG_VIDEO_MAX9X=m
export CONFIG_VIDEO_D4XX_MAX9295 = m
export CONFIG_VIDEO_D4XX_MAX9296 = m
export CONFIG_VIDEO_D4XX_MAX96724 = m
export CONFIG_VIDEO_D4XX = m

# Path to v4l2-core module symbols
KBUILD_EXTRA_SYMBOLS = $(M)/$(KERNEL_VERSION)/drivers/media/v4l2-core/Module.symvers

obj-m += drivers/media/pci/intel/
obj-m += drivers/media/i2c/

export CONFIG_INTEL_IPU_ACPI = m
obj-y += drivers/media/platform/intel/

subdir-ccflags-$(CONFIG_INTEL_IPU_ACPI) += \
        -DCONFIG_INTEL_IPU_ACPI
subdir-ccflags-$(CONFIG_VIDEO_AR0234) += \
        -DCONFIG_V4L2_CCI_I2C

subdir-ccflags-y += $(subdir-ccflags-m)

subdir-ccflags-y +=  -iquote $(src)/include/ -I$(src)/include/ 

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) modules

modules_install:
	$(MAKE) INSTALL_MOD_DIR=updates -C $(KERNEL_SRC) M=$(MODSRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) clean
