/* 由 tools/randomize.sh 生成 —— 每次编译随机化. 勿手改. */
#pragma once
#define DRV_IOCTL_RANDOMIZED
#define DRV_OP_AUTH    _IOWR('Z', 0x3C, struct drv_req)
#define DRV_OP_READ    _IOWR('Z', 0x4E, struct drv_req)
#define DRV_OP_WRITE   _IOWR('Z', 0xAC, struct drv_req)
#define DRV_OP_MODBASE _IOWR('Z', 0xEE, struct drv_req)
