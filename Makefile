# Makefile for pubgm_self_drv kernel module
#
# 由 tools/build.sh 调用，通过 make -C $(KERNEL_TREE) M=$(PWD) 进入
# 不要直接在此 Makefile 里执行，统一走 build.sh

MODULE_NAME ?= pubgm_self_drv

# 源文件
obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-objs := drv_main.o mem_core.o ioctl_if.o hide.o

# 默认目标（供 build.sh 触发）
all:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) clean

.PHONY: all clean
