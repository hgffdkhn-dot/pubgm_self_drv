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

# ---- 步骤 3: 工具链自检 (Actions 镜像预装, 无需 apt) ----
echo "[*] 步骤 3/5: 检查工具链 ..."
ensure_toolchain() {
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        echo "[+] aarch64-linux-gnu-gcc: $(aarch64-linux-gnu-gcc --version | head -1)"
        return 0
    fi
    # AUTOBUILD:20261110-203732 不再引用 apt, 仅检测
    echo "[-] 未找到 aarch64-linux-gnu-gcc" >&2
    echo "[-] Actions ubuntu-latest 应预装; 本地请自行确保 PATH 中存在该命令" >&2
    exit 127
}
ensure_toolchain

# ---- 步骤 4: 内核树自检（缺失则现场 clone + 编译兜底）----
echo "[*] 步骤 4/5: 检查内核树 ..."
ensure_kernel_tree() {
    if [ -d "$KERNEL_TREE" ] && [ -f "$KERNEL_TREE/Makefile" ]; then
        echo "[+] 内核树: $KERNEL_TREE"
        return 0
    fi
    echo "[!] 内核树不存在: $KERNEL_TREE" >&2
    echo "[*] 现场 clone ares-r-oss 并编译内核树 ..." >&2

    # 寻找 .config（项目根目录优先）
    CFG=""
    for f in "$DRV_DIR/.config" "$DRV_DIR/config" "$DRV_DIR/kernel_config" "$DRV_DIR/config.txt"; do
        if [ -f "$f" ]; then CFG="$f"; break; fi
    done

    # clone（官方源 + 备用源兜底）
    rm -rf "$KERNEL_TREE"
    mkdir -p "$KERNEL_TREE"
    CLONED=0
    for REPO in \
        "https://github.com/MiCode/Xiaomi_Kernel_OpenSource" \
        "https://github.com/AbzRaider/kernel_xiaomi_ares"; do
        if git clone --depth 1 -b ares-r-oss "$REPO" "$KERNEL_TREE" 2>/dev/null; then
            echo "[+] clone 成功: $REPO" >&2
            CLONED=1
            break
        fi
        echo "[!] $REPO 失败，尝试备用源 ..." >&2
    done
    if [ "$CLONED" -ne 1 ]; then
        echo "[-] 内核源码 clone 失败（网络/分支问题）" >&2
        return 1
    fi

    # 应用 config
    if [ -n "$CFG" ]; then
        echo "[+] 使用 $CFG" >&2
        cp "$CFG" "$KERNEL_TREE/.config"
        (cd "$KERNEL_TREE" && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig 2>&1 | tail -3)
    else
        echo "[*] 无 .config，使用默认 ares_defconfig" >&2
        (cd "$KERNEL_TREE" && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ares_defconfig 2>&1 | tail -3)
    fi

    # 全量编译（产出 Module.symvers）
    echo "[*] 全量编译内核（耐心等待，约 60-120 分钟）..." >&2
    (cd "$KERNEL_TREE" && \
     make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)" \
          Image modules 2>&1 | tail -5)

    if [ -f "$KERNEL_TREE/Module.symvers" ]; then
        echo "[+] 内核树就绪，Module.symvers: $(wc -l < "$KERNEL_TREE/Module.symvers") 条" >&2
        return 0
    fi
    echo "[-] 编译完成但 Module.symvers 缺失" >&2
    return 1
}
ensure_kernel_tree || { echo "[-] 内核树准备失败"; exit 2; }

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
