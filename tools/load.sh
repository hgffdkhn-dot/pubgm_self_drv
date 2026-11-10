#!/system/bin/sh
# tools/load.sh — 手机端加载驱动 (随机名 + 加载即删 + 随机节点)
# 用法: adb shell "su -c 'bash /data/local/tmp/load.sh'"

set -e

SRC_KO=${1:-/data/local/tmp/pubgm_self_drv.ko}
TMP_DIR=/data/local/tmp

if [ ! -f "$SRC_KO" ]; then
    echo "[-] ko not found: $SRC_KO"
    exit 1
fi

# 1) 随机名隐藏文件
RND=$(cat /dev/urandom | tr -dc 'a-z' | head -c 6)
HIDDEN=$TMP_DIR/.$RND.ko
cp "$SRC_KO" "$HIDDEN"
chmod 644 "$HIDDEN"

# 2) insmod
insmod "$HIDDEN"

# 3) 加载完立刻删源文件
rm -f "$HIDDEN" "$SRC_KO"

# 4) 建随机名设备节点
MAJOR=$(grep -E "gpu_aux" /proc/devices | awk '{print $1}')
if [ -z "$MAJOR" ]; then
    echo "[-] driver major not found in /proc/devices"
    exit 1
fi

NODE_RND=$(cat /dev/urandom | tr -dc 'a-z' | head -c 5)
NODE=/dev/.$NODE_RND
mknod "$NODE" c "$MAJOR" 0
chmod 666 "$NODE"

echo "[+] loaded, node=$NODE  (major=$MAJOR)"
echo "[!] use this node path in drv_connect()"
