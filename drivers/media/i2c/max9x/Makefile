KERNEL_VERSION := $(shell echo $(KERNELRELEASE) | sed 's/[^0-9.]*\([0-9]\.[0-9]*\)\..*/\1.0/')

ccflags-y += -I$(src)/../../../../ipu7-drivers/drivers/media/pci/intel/ipu7
ccflags-y += -I$(src)/../../../../$(KERNEL_VERSION)/include-overrides

obj-m 		+= max9x.o
max9x-y += serdes.o max9296.o max96724.o max9295.o max96717.o
