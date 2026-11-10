#!/system/bin/sh
# tools/load.sh —— 手机端加载驱动 (随机名 + 加载即删 + 随机节点)
# 用法: su -c "sh /data/local/tmp/load.sh [/path/to/pubgm_self_drv.ko]"

set -u

SRC_KO=${1:-/data/local/tmp/pubgm_self_drv.ko}
TMP_DIR=/data/local/tmp

if [ ! -f "$SRC_KO" ]; then
    echo "[-] ko not found: $SRC_KO"
    echo "    把 pubgm_self_drv.ko 推到 /data/local/tmp/ 后重试"
    exit 1
fi

# 1) 随机名隐藏文件
RND=$(cat /dev/urandom | tr -dc 'a-z' | head -c 6)
HIDDEN=$TMP_DIR/.$RND.ko
cp "$SRC_KO" "$HIDDEN"
chmod 644 "$HIDDEN"

# 2) insmod
insmod "$HIDDEN"
if [ $? -ne 0 ]; then
    echo "[-] insmod 失败，检查: dmesg | tail"
    rm -f "$HIDDEN"
    exit 1
fi

# 3) 加载完立刻删源文件
rm -f "$HIDDEN" "$SRC_KO"

# 4) 建随机名设备节点
#    驱动注册名是 "gpu_aux" (DRV_NAME_DEFAULT), 从 /proc/devices 取 major
MAJOR=$(grep -E "gpu_aux" /proc/devices | awk '{print $1}')
if [ -z "$MAJOR" ]; then
    # 兜底: 扫描所有字符设备, 找最新注册的
    echo "[!] /proc/devices 中未找到 gpu_aux, 尝试扫描 ..."
    MAJOR=$(dmesg 2>/dev/null | grep -oiE "gpu_aux.*major[ =][0-9]+" | tail -1 | grep -oE "[0-9]+" | head -1)
fi
if [ -z "$MAJOR" ]; then
    echo "[-] 无法获取驱动 major 号, 节点未创建"
    echo "    手动: cat /proc/devices | grep gpu_aux"
    exit 1
fi

NODE_RND=$(cat /dev/urandom | tr -dc 'a-z' | head -c 5)
NODE=/dev/.$NODE_RND
mknod "$NODE" c "$MAJOR" 0
chmod 666 "$NODE"

echo "[+] loaded, node=$NODE  (major=$MAJOR)"
echo "[!] 把 $NODE 填进你的 drv_connect() 调用"
