#!/bin/bash
# tools/build.sh — 编译自研驱动 + 用户态库
# 需要: 对应内核源码树 + aarch64-linux-gnu-gcc
#
# 用法:
#   export KERNEL=/path/to/kernel_ares
#   bash tools/build.sh

set -e

KERNEL=${KERNEL:-/lib/modules/$(uname -r)/build}
CROSS=${CROSS:-aarch64-linux-gnu-}

cd "$(dirname "$0")/.."

echo "[*] kernel: $KERNEL"
echo "[*] cross:  $CROSS"

# 首次编译内核头文件 (如未完成)
if [ ! -f "$KERNEL/Module.symvers" ]; then
    echo "[*] preparing kernel..."
    make -C "$KERNEL" ARCH=arm64 CROSS_COMPILE=$CROSS modules_prepare -j$(nproc) || true
fi

# 随机化
bash tools/randomize.sh

# 编译驱动
echo "[*] building kernel module..."
make -C . KDIR="$KERNEL" CROSS="$CROSS" all

# 编译用户态
echo "[*] building userspace..."
make -C user CC=$CROSS-gcc all

echo "[+] done: pubgm_self_drv.ko  user/test_client  user/libclient.a"
