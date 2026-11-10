#!/bin/sh
# tools/diag.sh —— 内核树 / 驱动状态诊断
# CI 失败时跑这个，快速定位是内核树问题还是驱动代码问题.

set -u

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KERNEL_TREE="${KERNEL_TREE:-$DRV_DIR/../kernel_ares}"

echo "=== 诊断 pubgm_self_drv 构建环境 ==="
echo "驱动目录:   $DRV_DIR"
echo "内核树:     $KERNEL_TREE"
echo "当前目录:   $(pwd)"
echo "uname:      $(uname -a)"
echo "nproc:      $(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"
echo ""

echo "--- 工具链 ---"
for t in gcc aarch64-linux-gnu-gcc make python3; do
    if command -v $t >/dev/null 2>&1; then
        echo "[+] $t: $($t --version 2>/dev/null | head -1)"
    else
        echo "[-] $t: 未安装"
    fi
done
echo ""

echo "--- 内核树 ---"
if [ -d "$KERNEL_TREE" ]; then
    echo "[+] 目录存在"
    echo "    Makefile:       $([ -f "$KERNEL_TREE/Makefile" ] && echo "存在" || echo "缺失!")"
    echo "    .config:        $([ -f "$KERNEL_TREE/.config" ] && echo "存在 ($(wc -l < "$KERNEL_TREE/.config") 行)" || echo "缺失")"
    echo "    Module.symvers: $([ -f "$KERNEL_TREE/Module.symvers" ] && echo "存在 ($(wc -l < "$KERNEL_TREE/Module.symvers") 条)" || echo "缺失!")"
    echo "    include/linux:  $([ -d "$KERNEL_TREE/include/linux" ] && echo "存在" || echo "缺失!")"
    echo "    scripts/:       $([ -d "$KERNEL_TREE/scripts" ] && echo "存在" || echo "缺失")"
    echo "    arch/arm64:     $([ -d "$KERNEL_TREE/arch/arm64" ] && echo "存在" || echo "缺失")"
    if [ -f "$KERNEL_TREE/include/generated/autoconf.h" ]; then
        echo "    autoconf.h:    存在 ($(wc -l < "$KERNEL_TREE/include/generated/autoconf.h") 行)"
    else
        echo "    autoconf.h:    缺失 (modules_prepare 未跑)"
    fi
else
    echo "[-] 内核树不存在"
fi
echo ""

echo "--- 驱动产物 ---"
for f in pubgm_self_drv.ko build/drv_ioctl.h user/client.o user/test_client; do
    if [ -f "$DRV_DIR/$f" ]; then
        echo "[+] $f: $(ls -lh "$DRV_DIR/$f" | awk '{print $5}')"
    else
        echo "[ ] $f: 未生成"
    fi
done
echo ""

echo "--- 建议 ---"
if [ ! -f "$KERNEL_TREE/Module.symvers" ]; then
    echo "* Module.symvers 缺失: 先跑 ./tools/prep_kernel.sh 全量编译内核"
fi
if [ ! -f "$KERNEL_TREE/include/generated/autoconf.h" ]; then
    echo "* autoconf.h 缺失: 跑 make modules_prepare"
fi
if [ ! -f "$DRV_DIR/build/drv_ioctl.h" ]; then
    echo "* build/drv_ioctl.h 缺失: 先跑 ./tools/randomize.sh"
fi
