#!/bin/sh
# tools/build.sh
# 编译 pubgm_self_drv.ko（假定内核树已 prepare 好）
#
# 用法:
#   ./tools/build.sh                 # 默认 ../kernel_ares
#   KERNEL_TREE=/path/to/kernel ./tools/build.sh
#   ./tools/build.sh prepare         # 首次: 预编译内核树 + 生成 Module.symvers

set -u

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KERNEL_TREE="${KERNEL_TREE:-$DRV_DIR/../kernel_ares}"

# ---- 步骤 1: 随机化 ioctl cmd（产出 build/drv_ioctl.h）----
echo "[*] 步骤 1/5: 随机化 ioctl cmd ..."
if sh "$SCRIPT_DIR/randomize.sh"; then
    echo "[+] randomize ok"
else
    echo "[-] randomize 失败，详见上方错误" >&2
    exit 1
fi

# ---- 步骤 2: 同步用户态 client.h ----
echo "[*] 步骤 2/5: 同步用户态 client.h ..."
if [ -x "$SCRIPT_DIR/sync_client.sh" ]; then
    if sh "$SCRIPT_DIR/sync_client.sh"; then
        echo "[+] client.h 同步 ok"
    else
        echo "[!] client.h 同步失败，用户态 ioctl 可能与内核不一致" >&2
    fi
else
    echo "[!] 未找到 sync_client.sh，跳过用户态同步"
fi

# ---- 步骤 3: 工具链自检 ----
echo "[*] 步骤 3/5: 检查工具链 ..."
ensure_toolchain() {
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        echo "[+] aarch64-linux-gnu-gcc: $(aarch64-linux-gnu-gcc --version | head -1)"
        return 0
    fi
    echo "[*] 安装交叉编译工具链 ..."
    if [ -n "${CI+x}" ]; then
        apt-get update -qq
        apt-get install -y -qq \
            gcc-aarch64-linux-gnu \
            binutils-aarch64-linux-gnu \
            bc bison flex \
            libelf-dev libssl-dev libncurses-dev \
            python3 \
            || { echo "[-] 工具链安装失败" >&2; exit 127; }
    else
        echo "[-] 未找到 aarch64-linux-gnu-gcc，请先安装:" >&2
        echo "    sudo apt install gcc-aarch64-linux-gnu bc bison flex libelf-dev libssl-dev" >&2
        exit 127
    fi
}
ensure_toolchain

# ---- 步骤 4: 内核树自检 ----
echo "[*] 步骤 4/5: 检查内核树 ..."
ensure_kernel_tree() {
    if [ -d "$KERNEL_TREE" ] && [ -f "$KERNEL_TREE/Makefile" ]; then
        echo "[+] 内核树: $KERNEL_TREE"
        return 0
    fi
    echo "[-] 内核树不存在: $KERNEL_TREE" >&2
    echo "    先执行: ./tools/prep_kernel.sh" >&2
    exit 1
}
ensure_kernel_tree

# 诊断: 列出内核树关键产物
echo "    --- 内核树诊断 ---"
ls -la "$KERNEL_TREE" 2>/dev/null | head -20
echo "    Module.symvers: $([ -f "$KERNEL_TREE/Module.symvers" ] && echo "存在 ($(wc -l < "$KERNEL_TREE/Module.symvers") 条)" || echo "缺失!")"
echo "    include/linux:  $([ -d "$KERNEL_TREE/include/linux" ] && echo "存在" || echo "缺失!")"
find "$KERNEL_TREE" -maxdepth 2 -name "Module.symvers" 2>/dev/null | while read f; do
    echo "    发现: $f"
done

case "$1" in
    prepare|prep)
        exec "$SCRIPT_DIR/prep_kernel.sh"
        ;;
esac

# ---- 步骤 5: 编译 ----
MODULE_NAME=pubgm_self_drv
export MODULE_NAME

echo "[*] 步骤 5/5: 编译 $MODULE_NAME.ko ..."

# modules_prepare（幂等）
echo "[*] make modules_prepare ..."
make -C "$KERNEL_TREE" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)" \
    modules_prepare >/dev/null 2>&1 \
    || echo "[!] modules_prepare 有警告，继续尝试编译"

# 编译驱动模块
echo "[*] make M=$DRV_DIR ..."
make -C "$KERNEL_TREE" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    M="$DRV_DIR" \
    MODULE_NAME="$MODULE_NAME" \
    -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)" 2>&1

if [ -f "$DRV_DIR/$MODULE_NAME.ko" ]; then
    echo ""
    echo "[+] 成功: $DRV_DIR/$MODULE_NAME.ko"
    ls -lh "$DRV_DIR/$MODULE_NAME.ko"
    file "$DRV_DIR/$MODULE_NAME.ko"
    # 校验架构必须为 aarch64
    if file "$DRV_DIR/$MODULE_NAME.ko" | grep -qi "aarch64\|ARM aarch64"; then
        echo "[+] 架构校验通过: aarch64"
    else
        echo "[-] 警告: 架构可能不对，请检查 CROSS_COMPILE"
    fi
    exit 0
else
    echo ""
    echo "[-] 未产出 .ko，请查看上方编译报错" >&2
    exit 2
fi
