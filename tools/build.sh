#!/bin/sh
# AUTOBUILD: 20261110-2330
# 驱动编译脚本: 优先内核全量 modules, 失败则退化为单模块 M=
set -u

KERNEL_TREE="${KERNEL_TREE:-$GITHUB_WORKSPACE/kernel_ares}"
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

echo "[*] KERNEL_TREE=$KERNEL_TREE"
echo "[*] CROSS_COMPILE=$CROSS_COMPILE"

if [ ! -d "$KERNEL_TREE" ]; then
  echo "[-] 内核树不存在: $KERNEL_TREE"; exit 1
fi
if [ ! -f "$KERNEL_TREE/Module.symvers" ]; then
  echo "[!] 无 Module.symvers, 降级为 prepare+scripts"
  make -C "$KERNEL_TREE" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" prepare scripts 2>&1 | tail -5 || true
fi

# 生成/更新 Kbuild
DRV="pubgm_self_drv"
cat > Kbuild <<KEOF
obj-m += ${DRV}.o
${DRV}-objs := main.o
KEOF

echo "[*] 方式1: 内核树 make M= ..."
if make -C "$KERNEL_TREE" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" M="$PWD" modules 2>&1 | tee /tmp/m1.log | tail -25; then
  echo "[+] 方式1 成功"
else
  echo "[!] 方式1 失败, 方式2: 手动 kbuild 单文件"
  make -C "$KERNEL_TREE" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" M="$PWD" ${DRV}.o 2>&1 | tail -25 || true
fi

# 产物命名
for f in *.ko; do
  [ -f "$f" ] || continue
  case "$f" in pubgm_self_drv.ko) ;; *) mv "$f" "pubgm_self_drv.ko" ;; esac
done

if [ -f pubgm_self_drv.ko ]; then
  echo "[+] $(ls -lh pubgm_self_drv.ko | awk '{print $5,$9}')"
  exit 0
else
  echo "[-] 未生成 .ko"; tail -40 /tmp/m1.log; exit 2
fi
