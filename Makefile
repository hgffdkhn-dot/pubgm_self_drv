obj-m += pubgm_self_drv.o
pubgm_self_drv-objs := main.o
M ?= $(PWD)
all:
	$(MAKE) -C $(KERNEL_TREE) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) M=$(M) modules
clean:
	$(MAKE) -C $(KERNEL_TREE) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) M=$(M) clean
