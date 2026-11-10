# Makefile for pubgm_self_drv (Ares 4.14.186)
# 用法: make KDIR=/path/to/kernel_ares [CROSS=aarch64-linux-gnu-]

KDIR ?= /lib/modules/$(shell uname -r)/build
CROSS ?= aarch64-linux-gnu-
ARCH := arm64

obj-m := pubgm_self_drv.o
pubgm_self_drv-objs := drv_main.o mem_core.o ioctl_if.o hide.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) ARCH=$(ARCH) clean

# 快速随机化：编译前换名字和 cmd 偏移
randomize:
	@bash tools/randomize.sh

.PHONY: all clean randomize
