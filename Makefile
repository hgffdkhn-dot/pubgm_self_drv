# Makefile for pubgm_self_drv kernel module
#
# 由 tools/build.sh 调用，通过 make -C $(KERNEL_TREE) M=$(PWD) 进入
# 不要直接在此 Makefile 里执行，统一走 build.sh

include Makefile.inc

all:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) clean

.PHONY: all clean
