# Makefile.inc —— 被 Makefile / Kbuild 共同包含
# 让编译优先使用 tools/randomize.sh 产出的 build/drv_ioctl.h
# （用户态 client.h 的 cmd 码必须与内核一致，见 sync_client.sh）

MODULE_NAME ?= pubgm_self_drv

obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-objs := drv_main.o mem_core.o ioctl_if.o hide.o

# 把 build/ 目录放到头文件搜索路径最前面
# randomize.sh 产出 build/drv_ioctl.h, drv.h 通过 #ifndef DRV_IOCTL_RANDOMIZED 兜底
ccflags-y += -I$(src)/build -I$(src)/include
