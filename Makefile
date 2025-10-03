# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2025 Intel Corporation.

KERNELRELEASE ?= $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KERNELRELEASE)/build
KERNEL_SUBVERSION := $(shell echo $(KERNELRELEASE) | cut -d- -f1 | sed -r 's/([0-9]+\.[0-9]+).*/\1.0/g')
BUILD_EXCLUSIVE_KERNEL="^(6\.(1[278])\.)"

MODSRC := $(shell pwd)

subdir-ccflags-y += -DDRIVER_VERSION_SUFFIX=\"${DRIVER_VERSION_SUFFIX}\"
# Extract kernel version components - strip suffix like "-intel"
KERNEL_VERSION := $(shell echo $(KERNELRELEASE) | cut -d. -f1)
KERNEL_PATCHLEVEL := $(shell echo $(KERNELRELEASE) | cut -d. -f2 | cut -d- -f1)

# Check if kernel version is 6.17 or above
KERNEL_EQ_6_17 := $(shell ([ $(KERNEL_VERSION) -eq 6 ] && [ $(KERNEL_PATCHLEVEL) -eq 17 ]) && echo 1 || echo 0)

# Check if kernel version is 6.12 or above
KERNEL_EQ_6_12 := $(shell ([ $(KERNEL_VERSION) -eq 6 ] && [ $(KERNEL_PATCHLEVEL) -eq 12 ]) && echo 1 || echo 0)

export EXTERNAL_BUILD = 1
export CONFIG_IPU_BRIDGE=m
export CONFIG_VIDEO_AR0820=m
export CONFIG_VIDEO_AR0234=m
export CONFIG_VIDEO_ISX031=m
export CONFIG_VIDEO_MAX9X=m
export CONFIG_VIDEO_LT6911UXE=m
export CONFIG_VIDEO_LT6911UXC=m
export CONFIG_VIDEO_LT6911GXD=m
export CONFIG_VIDEO_INTEL_IPU6=m
export CONFIG_VIDEO_INTEL_IPU6_ISYS_RESET=y
export CONFIG_INTEL_IPU_ACPI=m
export CONFIG_VIDEO_D4XX_MAX9295 = m
export CONFIG_VIDEO_D4XX_MAX9296 = m
export CONFIG_VIDEO_D4XX_MAX96724 = m
export CONFIG_VIDEO_D4XX = m

# Define config macros for conditional compilation in ipu-acpi.c
# IS_ENABLED() checks for CONFIG_XXX or CONFIG_XXX_MODULE
subdir-ccflags-$(CONFIG_VIDEO_MAX9X) += -DCONFIG_VIDEO_MAX9X
subdir-ccflags-$(CONFIG_VIDEO_ISX031) += -DCONFIG_VIDEO_ISX031
subdir-ccflags-$(CONFIG_VIDEO_D4XX) += -DCONFIG_VIDEO_D4XX
subdir-ccflags-$(CONFIG_VIDEO_AR0820) += -DCONFIG_VIDEO_AR0820
subdir-ccflags-$(CONFIG_VIDEO_AR0234) += -DCONFIG_VIDEO_AR0234 -DCONFIG_V4L2_CCI_I2C
subdir-ccflags-$(CONFIG_IPU_BRIDGE) += -DCONFIG_IPU_BRIDGE
subdir-ccflags-$(CONFIG_INTEL_IPU_ACPI) += -DCONFIG_INTEL_IPU_ACPI
subdir-ccflags-$(CONFIG_VIDEO_LT6911UXE) += -DCONFIG_VIDEO_LT6911UXE
subdir-ccflags-$(CONFIG_VIDEO_LT6911UXC) += -DCONFIG_VIDEO_LT6911UXC
subdir-ccflags-$(CONFIG_VIDEO_LT6911GXD) += -DCONFIG_VIDEO_LT6911GXD
subdir-ccflags-$(CONFIG_VIDEO_INTEL_IPU6) += -DCONFIG_VIDEO_INTEL_IPU6
subdir-ccflags-$(CONFIG_VIDEO_INTEL_IPU6_ISYS_RESET) += -DCONFIG_VIDEO_INTEL_IPU6_ISYS_RESET

# Path to v4l2-core module symbols
KBUILD_EXTRA_SYMBOLS += $(M)/$(KERNEL_SUBVERSION)/drivers/media/v4l2-core/Module.symvers

# Override LINUXINCLUDE to put our include path first
LINUXINCLUDE := -I$(src)/include $(LINUXINCLUDE)

ccflags-y := -I$(src)/include
ifeq ($(KERNEL_EQ_6_17),1)
# IPU7 driver configs
export CONFIG_VIDEO_INTEL_IPU7=m

subdir-ccflags-y += -DCONFIG_VIDEO_INTEL_IPU7

# Build IPU7 drivers from submodule
obj-m += ipu7-drivers/drivers/media/pci/intel/ipu7/
else ifeq ($(KERNEL_EQ_6_12),1)
# IPU6 driver configs
export CONFIG_VIDEO_INTEL_IPU6=m
export CONFIG_VIDEO_INTEL_IPU6_ISYS_RESET=y

subdir-ccflags-y += -DCONFIG_VIDEO_INTEL_IPU6

# Build IPU6 drivers from submodule
obj-m += ipu6-drivers/drivers/media/pci/intel/ipu6/
endif

obj-m += drivers/media/pci/intel/
obj-y += drivers/media/platform/intel/
obj-m += drivers/media/i2c/

subdir-ccflags-y += $(subdir-ccflags-m)
subdir-ccflags-y +=  -iquote $(src)/include/ -I$(src)/include/ -I$(src)/ipu6-drivers/include

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) modules

modules_install:
	$(MAKE) INSTALL_MOD_DIR=updates -C $(KERNEL_SRC) M=$(MODSRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) clean
