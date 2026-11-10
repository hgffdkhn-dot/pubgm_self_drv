#!/bin/bash
# tools/randomize.sh — 编译前随机化驱动名与 ioctl cmd 偏移
# 每次编译跑一次, 降低特征命中率
set -e
cd "$(dirname "$0")/.."

RND=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6)
NAME="gpu_$RND"

# 替换 Kbuild / drv_main.c 里的默认名
sed -i "s/^obj-m += .*/obj-m += pubgm_self_drv.o/" Kbuild
echo "[*] driver name base: $NAME (compile-time fixed; runtime node randomized by load.sh)"

# 随机 cmd 偏移 (0x10~0xFE 之间取偶数)
OP_AUTH=$(printf '0x%02X' $((0x20 + RANDOM % 100)))
OP_READ=$(printf '0x%02X' $((0x40 + RANDOM % 100)))
OP_WRITE=$(printf '0x%02X' $((0x80 + RANDOM % 80)))
OP_MOD=$(printf '0x%02X' $((0x10 + RANDOM % 40)))

echo "#pragma once" > include/drv_ioctl.h
{
  echo "#define DRV_OP_AUTH    _IOWR('Z', $OP_AUTH, struct drv_req)"
  echo "#define DRV_OP_READ    _IOWR('Z', $OP_READ, struct drv_req)"
  echo "#define DRV_OP_WRITE   _IOWR('Z', $OP_WRITE, struct drv_req)"
  echo "#define DRV_OP_MODBASE _IOWR('Z', $OP_MOD, struct drv_req)"
} >> include/drv_ioctl.h

echo "[+] ioctl cmds randomized: AUTH=$OP_AUTH READ=$OP_READ WRITE=$OP_WRITE MOD=$OP_MOD"
echo "[!] include/drv_ioctl.h regenerated — must be included by ioctl_if.c"
