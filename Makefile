obj-m += pubgm_self_drv.o
all:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) modules
clean:
	$(MAKE) -C $(KERNEL_TREE) M=$(PWD) clean
ccflags-y := -D__KERNEL__ -Wall -O2
