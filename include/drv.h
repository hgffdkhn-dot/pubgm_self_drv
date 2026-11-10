#pragma once

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>
#include <linux/sched.h>
#include <linux/sched/task.h>
#include <linux/pid.h>
#include <linux/mm.h>
#include <linux/ioctl.h>
#include <linux/slab.h>
#include <linux/random.h>

#include "pt_walk.h"

/* 随机化魔术与 cmd —— randomize.sh 会在此处替换成随机值 */
#define DRV_MAGIC        'Z'

#ifndef DRV_OP_AUTH
#define DRV_OP_AUTH      _IOWR(DRV_MAGIC, 0x3A, struct drv_req)
#endif
#ifndef DRV_OP_READ
#define DRV_OP_READ      _IOWR(DRV_MAGIC, 0x7C, struct drv_req)
#endif
#ifndef DRV_OP_WRITE
#define DRV_OP_WRITE     _IOWR(DRV_MAGIC, 0x91, struct drv_req)
#endif
#ifndef DRV_OP_MODBASE
#define DRV_OP_MODBASE   _IOWR(DRV_MAGIC, 0x52, struct drv_req)
#endif

#define DRV_NAME_DEFAULT "gpu_aux"

struct drv_req {
    __s32   pid;
    __u64   src;        /* 目标进程虚拟地址 */
    __u64   dst;        /* 用户态缓冲区 (输出) */
    __u64   size;
    __u32   token;
    char    name[32];   /* 模块名 (MODBASE 用) */
};

extern struct drv_req g_last_req;

/* ioctl 实现 */
long drv_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);

/* 内存读取核心 */
int  mem_read_task(struct task_struct *task, unsigned long va, void *buf, size_t len);
