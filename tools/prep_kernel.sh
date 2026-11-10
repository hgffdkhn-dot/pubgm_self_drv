#!/bin/sh
# tools/prep_kernel.sh
# 首次准备内核树:
#   1. 拉小米 ares-r-oss 内核源码
#   2. 合并手机导出的真实 .config（优先）或 ares_defconfig
#   3. 全量编译一次，生成完整的 Module.symvers + 头文件
# 之后 build.sh 只需增量编译驱动，几秒到几分钟搞定
#
# .config 放置位置（三选一，脚本自动找）:
#   A) 项目根目录（推荐）:
#      <drvier>/../.config           即 pubgm_self_drv/../.config
#      <drvier>/../kernel_config    导出文件名随便叫，含 config 字样即可
#   B) 内核树内: $KERNEL_TREE/.config
#   C) 环境变量: CONFIG_FILE=/path/to/config
#
# 手机导出真实配置（强烈推荐，保证与运行内核 100% 匹配）:
#   adb shell "zcat /proc/config.gz" > .config
#   cp .config <项目根目录>/
#
# 用法:
#   ./tools/prep_kernel.sh                     # 默认分支 ares-r-oss
#   KERNEL_BRANCH=ares-r-oss ./tools/prep_kernel.sh
#   KERNEL_TREE=/path ./tools/prep_kernel.sh
#   CONFIG_FILE=/path/to/config ./tools/prep_kernel.sh

set -e

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KERNEL_TREE="${KERNEL_TREE:-$DRV_DIR/../kernel_ares}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/MiCode/Xiaomi_Kernel_OpenSource}"
KERNEL_BRANCH="${KERNEL_BRANCH:-ares-r-oss}"

# ---- 自动寻找 .config ----
# 查找顺序: CONFIG_FILE > 项目根目录/.config > 项目根目录/kernel_config > 内核树/.config
find_config() {
    if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        echo "$CONFIG_FILE"; return
    fi
    # 项目根目录: 驱动目录的同级目录
    PROJECT_ROOT="$DRV_DIR/.."
    if [ -f "$PROJECT_ROOT/.config" ]; then
        echo "$PROJECT_ROOT/.config"; return
    fi
    # 项目根目录下任意文件名含 config 的普通文件（不含 .git 等）
    for f in "$PROJECT_ROOT"/*; do
        [ -f "$f" ] || continue
        case "$(basename "$f")" in
            .config|config|*config*.txt|kernel_config|kconfig) echo "$f"; return ;;
        esac
    done
    if [ -f "$KERNEL_TREE/.config" ]; then
        echo "$KERNEL_TREE/.config"; return
    fi
    echo ""
}

if [ -d "$KERNEL_TREE" ]; then
    echo "[*] 内核树已存在: $KERNEL_TREE，跳过 clone"
else
    echo "[*] 克隆 $KERNEL_REPO 分支 $KERNEL_BRANCH ..."
    git clone --depth 1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_TREE" \
        || git clone --depth 1 -b "$KERNEL_BRANCH" \
            https://github.com/AbzRaider/kernel_xiaomi_ares "$KERNEL_TREE"
fi

# 工具链
if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    if [ -n "$CI" ]; then
        apt-get update -qq
        apt-get install -y -qq \
            gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
            bc bison flex libelf-dev libssl-dev libncurses-dev \
            cpio kmod
    else
        echo "[-] 需要 aarch64-linux-gnu-gcc，请先安装交叉工具链"
        exit 127
    fi
fi

cd "$KERNEL_TREE"

# ---- 处理 .config ----
FOUND_CFG=$(find_config || true)
if [ -n "$FOUND_CFG" ]; then
    echo "[*] 找到手机导出的配置: $FOUND_CFG"
    # 校验: 必须有 CONFIG_ARM64=y 和版本号大致匹配
    if grep -qi "^CONFIG_ARM64=y" "$FOUND_CFG" 2>/dev/null; then
        echo "[+] 架构校验通过: CONFIG_ARM64=y"
    else
        echo "[!] 警告: 该 .config 似乎不是 arm64 内核配置，继续但可能不匹配"
    fi
    # 检查 LOCALVERSION / 版本匹配提示
    if grep -qi "4.14" "$FOUND_CFG" 2>/dev/null; then
        echo "[+] 版本匹配: 4.14.x"
    else
        echo "[!] 提示: 确认该 .config 来自 4.14.186 内核"
    fi
    cp "$FOUND_CFG" "$KERNEL_TREE/.config"
    echo "[*] 应用 olddefconfig ..."
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
else
    echo "[!] 未找到手机导出的 .config"
    echo "    期望位置之一:"
    echo "      $DRV_DIR/../.config"
    echo "      $KERNEL_TREE/.config"
    echo "    或设置 CONFIG_FILE=/path/to/config"
    echo "    回退使用默认 ares_defconfig（不保证与运行内核 100% 匹配）"
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ares_defconfig
fi

# 全量编译，生成 Module.symvers
echo "[*] 全量编译内核（生成 Module.symvers，可能 30-90 分钟）..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" Image modules

if [ -f "$KERNEL_TREE/Module.symvers" ]; then
    echo "[+] Module.symvers 已生成: $(wc -l < "$KERNEL_TREE/Module.symvers") 条符号"
else
    echo "[-] 警告: 未生成 Module.symvers，驱动模块可能编译失败"
    exit 2
fi

echo "[+] 内核树准备完成: $KERNEL_TREE"
echo "    后续执行: ./tools/pack_kernel.sh  上传 Release，然后 build.sh 增量编译"
