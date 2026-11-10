# Kbuild - kernel build file
# 与 Makefile 保持一致，部分内核版本只认 Kbuild

MODULE_NAME ?= pubgm_self_drv

obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-objs := drv_main.o mem_core.o ioctl_if.o hide.o
