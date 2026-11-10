#!/bin/sh
# tools/pack_kernel.sh
# 把预编译好的内核树打包，上传到 Release 供 CI 下载
# CI 只需下载解压后增量编译驱动，避免每次全量编译超时
#
# 用法:
#   ./tools/pack_kernel.sh                      # 默认压缩 ../kernel_ares
#   KERNEL_TREE=/path ./tools/pack_kernel.sh
#
# 产物: kernel_ares_prepared.tar.zst（zstd 压缩，约 200-500MB）
# 上传到 GitHub Release "kernel-prep" 后，build.yml 会自动下载

set -e

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KERNEL_TREE="${KERNEL_TREE:-$DRV_DIR/../kernel_ares}"

if [ ! -d "$KERNEL_TREE" ]; then
    echo "[-] 内核树不存在: $KERNEL_TREE，先跑 prep_kernel.sh"
    exit 1
fi

if [ ! -f "$KERNEL_TREE/Module.symvers" ]; then
    echo "[-] Module.symvers 缺失，内核树未 prepare，先跑 prep_kernel.sh"
    exit 1
fi

# 只保留编译模块必需的子集，减小体积
KEEP="Makefile .config Module.symvers include scripts arch drivers/mm"
CLEANUP_DIRS=".git"

echo "[*] 清理 .git 以减小体积 ..."
rm -rf "$KERNEL_TREE/.git"

OUT="kernel_ares_prepared.tar.zst"
echo "[*] 打包 $KERNEL_TREE -> $OUT ..."
tar -cf - -C "$(dirname "$KERNEL_TREE")" "$(basename "$KERNEL_TREE")" \
    | zstd -19 -T0 -o "$OUT"

SIZE=$(du -h "$OUT" | cut -f1)
echo "[+] 打包完成: $OUT ($SIZE)"
echo ""
echo "下一步:"
echo "  1. 去 GitHub 创建一个名为 'kernel-prep' 的 Release"
echo "  2. 把 $OUT 上传为该 Release 的资产"
echo "  3. 把上传得到的浏览器下载链接填进 .github/workflows/build.yml 的 KERNEL_PREP_URL"
