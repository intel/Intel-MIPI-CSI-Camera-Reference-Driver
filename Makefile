# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2025 Intel Corporation.

KERNELRELEASE ?= $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KERNELRELEASE)/build
MODSRC := $(shell pwd)

export EXTERNAL_BUILD = 1

export CONFIG_IPU_BRIDGE=m
export CONFIG_VIDEO_AR0820=m
export CONFIG_VIDEO_AR0234=m
export CONFIG_VIDEO_ISX031=m

obj-m += drivers/media/pci/intel/
obj-m += drivers/media/i2c/


subdir-ccflags-y +=  -iquote $(src)/include/ -I$(src)/include/ 

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) modules

modules_install:
	$(MAKE) INSTALL_MOD_DIR=updates -C $(KERNEL_SRC) M=$(MODSRC) modules_install

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(MODSRC) clean
