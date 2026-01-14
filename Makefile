# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2025 Intel Corporation.

KERNELRELEASE ?= $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KERNELRELEASE)/build
KERNEL_VERSION := $(shell echo $(KERNELRELEASE) cut -d- -f1 | sed -r 's/([0-9]+\.[0-9]+).*/\1.0/g')
BUILD_EXCLUSIVE_KERNEL="^(6\.(1[278])\.)"

MODSRC := $(shell pwd)

subdir-ccflags-y += -DDRIVER_VERSION_SUFFIX=\"${DRIVER_VERSION_SUFFIX}\"

export EXTERNAL_BUILD = 1
export CONFIG_IPU_BRIDGE=m
export CONFIG_VIDEO_AR0820=m
export CONFIG_VIDEO_AR0234=m
export CONFIG_VIDEO_ISX031=m
export CONFIG_VIDEO_MAX9X=m
export CONFIG_VIDEO_LT6911UXE=m
export CONFIG_VIDEO_LT6911UXC=m
export CONFIG_VIDEO_LT6911GXD=m

# Define config macros for conditional compilation in ipu-acpi.c
# IS_ENABLED() checks for CONFIG_XXX or CONFIG_XXX_MODULE
subdir-ccflags-$(CONFIG_VIDEO_MAX9X) += -DCONFIG_VIDEO_MAX9X
subdir-ccflags-$(CONFIG_VIDEO_ISX031) += -DCONFIG_VIDEO_ISX031
subdir-ccflags-$(CONFIG_VIDEO_AR0820) += -DCONFIG_VIDEO_AR0820
subdir-ccflags-$(CONFIG_VIDEO_AR0234) += -DCONFIG_VIDEO_AR0234
subdir-ccflags-$(CONFIG_IPU_BRIDGE) += -DCONFIG_IPU_BRIDGE
subdir-ccflags-$(CONFIG_INTEL_IPU_ACPI) += -DCONFIG_INTEL_IPU_ACPI
subdir-ccflags-$(CONFIG_VIDEO_LT6911UXE) += -DCONFIG_VIDEO_LT6911UXE
subdir-ccflags-$(CONFIG_VIDEO_LT6911UXC) += -DCONFIG_VIDEO_LT6911UXC
subdir-ccflags-$(CONFIG_VIDEO_LT6911GXD) += -DCONFIG_VIDEO_LT6911GXD
# Override LINUXINCLUDE to put our include path first
LINUXINCLUDE := -I$(src)/include $(LINUXINCLUDE)

ccflags-y := -I$(src)/include

obj-m += drivers/media/pci/intel/
obj-m += drivers/media/i2c/

export CONFIG_INTEL_IPU_ACPI = m
obj-y += drivers/media/platform/intel/

subdir-ccflags-y += $(subdir-ccflags-m)

subdir-ccflags-y +=  -iquote $(src)/include/ -I$(src)/include/ 

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) modules

modules_install:
	$(MAKE) INSTALL_MOD_DIR=updates -C $(KERNEL_SRC) M=$(MODSRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) clean
