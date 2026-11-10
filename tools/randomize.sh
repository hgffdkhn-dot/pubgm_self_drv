#!/bin/bash
# tools/randomize.sh —— 编译前随机化 ioctl cmd 偏移
# 每次编译跑一次, 降低特征命中率.
# CI 安全: 不 sed -i 原地改工作区, 全部产出写到 build/ 目录.
# 用 printf 避免 $(()) 中大数溢出 / 数组语法问题.

set -u

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
BUILD_DIR="$DRV_DIR/build"
mkdir -p "$BUILD_DIR"

# 随机 8 位 hex 作为本次编译标识
RND=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
DRV_NAME="gpu_${RND}"

# 随机 cmd 偏移: 落在 [0x10, 0xFE] 的偶数上
op_rand() {
    lo=$1
    hi=$2
    v=$(od -An -N2 -tu2 /dev/urandom | tr -d ' \n')
    v=$(( v % (hi - lo + 1) + lo ))
    printf '0x%02X' $(( v & ~1 ))
}

OP_AUTH=$(op_rand 0x20 0x40)
OP_READ=$(op_rand 0x42 0x80)
OP_WRITE=$(op_rand 0x82 0xC0)
OP_MOD=$(op_rand 0xC2 0xFE)

OUT="$BUILD_DIR/drv_ioctl.h"
printf '%s\n' \
    '/* 由 tools/randomize.sh 生成 —— 每次编译随机化. 勿手改. */' \
    '#pragma once' \
    '#define DRV_IOCTL_RANDOMIZED' \
    "#define DRV_OP_AUTH    _IOWR('Z', ${OP_AUTH}, struct drv_req)" \
    "#define DRV_OP_READ    _IOWR('Z', ${OP_READ}, struct drv_req)" \
    "#define DRV_OP_WRITE   _IOWR('Z', ${OP_WRITE}, struct drv_req)" \
    "#define DRV_OP_MODBASE _IOWR('Z', ${OP_MOD}, struct drv_req)" \
    > "$OUT"

echo "[+] randomize: name_hint=$DRV_NAME"
echo "[+] randomize: AUTH=$OP_AUTH READ=$OP_READ WRITE=$OP_WRITE MODBASE=$OP_MOD"
echo "[+] output: $OUT"

if [ ! -s "$OUT" ]; then
    echo "[-] FATAL: 无法写入 $OUT" >&2
    exit 1
fi
