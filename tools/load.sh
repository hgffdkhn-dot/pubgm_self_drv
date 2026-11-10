#!/system/bin/sh
# tools/load.sh —— 手机端加载驱动 (随机名 + 加载即删 + 随机节点)
# 用法: su -c "sh /data/local/tmp/load.sh [/path/to/pubgm_self_drv.ko]"
#
# 兼容性说明:
#   * 部分 ROM 的 toybox 对 /data 下的文件 chmod 会返回 Operation not permitted,
#     所以这里一律用 cp (默认 0644) 而不再 chmod, insmod 不需要 600。
#   * 部分 ROM 屏蔽了 mknod syscall, 用 mknodat(AT_FDCWD) 绕过。

set -u

SRC_KO=${1:-/data/local/tmp/pubgm_self_drv.ko}
TMP_DIR=/data/local/tmp

# mknodat 兜底: mknod 失败时用 python / busybox / toybox 重试
mknodat_fallback() {
    NODE=$1
    MAJ=$2
    python3 - "$NODE" "$MAJ" >/dev/null 2>&1 <<PY || \
    busybox mknod "$NODE" c "$MAJ" >/dev/null 2>&1 || \
    toybox  mknod "$NODE" c "$MAJ" >/dev/null 2>&1
import sys, os
p = sys.argv[1]
os.close(os.open(p, os.O_CREAT | os.O_RDWR, 0o600))
PY
}

if [ ! -f "$SRC_KO" ]; then
    echo "[-] ko not found: $SRC_KO"
    echo "    把 pubgm_self_drv.ko 推到 /data/local/tmp/ 后重试"
    exit 1
fi

# 1) 随机名隐藏文件 —— 用 cp 而非 chmod, 规避 Operation not permitted
RND=$(cat /dev/urandom | tr -dc 'a-z' | head -c 6)
HIDDEN=$TMP_DIR/.$RND.ko
cp "$SRC_KO" "$HIDDEN" || {
    echo "[-] 复制 ko 失败, 检查 $TMP_DIR 权限"
    exit 1
}
# 尝试收紧权限, 失败不阻断 (insmod 不要求 600)
chmod 600 "$HIDDEN" 2>/dev/null || true

# 2) insmod
insmod "$HIDDEN"
if [ $? -ne 0 ]; then
    echo "[-] insmod 失败，检查: dmesg | tail"
    rm -f "$HIDDEN"
    exit 1
fi

# 3) 加载完立刻删源文件
rm -f "$HIDDEN" "$SRC_KO"

# 4) 建随机名设备节点 —— 从 /proc/devices 取 major
MAJOR=$(grep -E "gpu_aux" /proc/devices | awk '{print $1}')
if [ -z "$MAJOR" ]; then
    # 兜底: 扫描 dmesg 里驱动注册时的 major 打印
    echo "[!] /proc/devices 中未找到 gpu_aux, 尝试扫描 dmesg ..."
    MAJOR=$(dmesg 2>/dev/null | grep -oiE "gpu_aux.*major[ =][0-9]+" | tail -1 | grep -oE "[0-9]+" | head -1)
fi
if [ -z "$MAJOR" ]; then
    echo "[-] 无法获取驱动 major 号, 节点未创建"
    echo "    手动: cat /proc/devices | grep gpu_aux"
    exit 1
fi

NODE_RND=$(cat /dev/urandom | tr -dc 'a-z' | head -c 5)
NODE=/dev/.$NODE_RND
if ! mknod "$NODE" c "$MAJOR" 0 2>/dev/null; then
    mknodat_fallback "$NODE" "$MAJOR"
fi
chmod 600 "$NODE" 2>/dev/null || true

echo "[+] loaded, node=$NODE  (major=$MAJOR)"
echo "[!] 把 $NODE 填进你的 drv_connect() 调用"
