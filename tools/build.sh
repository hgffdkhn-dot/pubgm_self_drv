#!/bin/sh
# tools/build.sh
# 编译 pubgm_self_drv.ko（假定内核树已 prepare 好）
# 用法:
#   ./tools/build.sh                 # 用默认 ../kernel_ares
#   KERNEL_TREE=/path/to/kernel ./tools/build.sh
#   ./tools/build.sh prepare         # 首次: 预编译内核树 + 生成 Module.symvers

set -e

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KERNEL_TREE="${KERNEL_TREE:-$DRV_DIR/../kernel_ares}"

# 工具链自检: 缺啥装啥（CI 里跑 apt-get，本地跳过）
ensure_toolchain() {
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        return 0
    fi
    echo "[*] 安装交叉编译工具链 ..."
    if [ -n "$CI" ]; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq \
            gcc-aarch64-linux-gnu \
            binutils-aarch64-linux-gnu \
            bc bison flex \
            libelf-dev libssl-dev libncurses-dev \
            python3
    else
        echo "[!] 未找到 aarch64-linux-gnu-gcc，请先安装:"
        echo "    sudo apt install gcc-aarch64-linux-gnu bc bison flex libelf-dev libssl-dev"
        exit 127
    fi
}

ensure_kernel_tree() {
    if [ -d "$KERNEL_TREE" ] && [ -f "$KERNEL_TREE/Makefile" ]; then
        return 0
    fi
    echo "[!] 内核树不存在: $KERNEL_TREE"
    echo "    先执行: ./tools/prep_kernel.sh"
    exit 1
}

ensure_toolchain

case "$1" in
    prepare|prep)
        # 委托给 prep_kernel.sh
        exec "$SCRIPT_DIR/prep_kernel.sh"
        ;;
esac

ensure_kernel_tree

echo "[*] 内核树: $KERNEL_TREE"
echo "[*] 驱动目录: $DRV_DIR"

# 显式锁定模块名，避免错拼成 pgubn_self_drv
MODULE_NAME=pubgm_self_drv
export MODULE_NAME

# 进入内核树做 modules_prepare（幂等，可重复跑）
echo "[*] make modules_prepare ..."
make -C "$KERNEL_TREE" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    -j"$(nproc)" \
    modules_prepare >/dev/null

# 编译驱动模块
echo "[*] 编译 $MODULE_NAME.ko ..."
make -C "$KERNEL_TREE" \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    M="$DRV_DIR" \
    MODULE_NAME="$MODULE_NAME" \
    -j"$(nproc)"

if [ -f "$DRV_DIR/$MODULE_NAME.ko" ]; then
    echo "[+] 成功: $DRV_DIR/$MODULE_NAME.ko"
    ls -lh "$DRV_DIR/$MODULE_NAME.ko"
    # 校验架构
    file "$DRV_DIR/$MODULE_NAME.ko"
else
    echo "[-] 未产出 .ko，检查上面的报错"
    exit 2
fi
