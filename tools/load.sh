#!/bin/sh
# 加载驱动 (仅在已 root 的 Android 上运行)
set -u
SRC_KO="${1:-pubgm_self_drv.ko}"
[ -f "$SRC_KO" ] || { echo "[-] $SRC_KO 不存在"; exit 1; }
HIDDEN="/data/local/tmp/.$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
cp "$SRC_KO" "$HIDDEN" 2>/dev/null || cp "$SRC_KO" "/data/local/tmp/${HIDDEN##*/}"
chmod 600 "$HIDDEN" 2>/dev/null || true
echo "[*] 已拷贝到 $HIDDEN"
if command -v insmod >/dev/null 2>&1; then
  insmod "$HIDDEN" 2>&1 && echo "[+] insmod 成功" || echo "[!] insmod 失败, 可能需要 root"
else
  echo "[!] 无 insmod, 尝试 modprobe"
  modprobe "$(basename "$HIDDEN" .ko)" 2>&1 || true
fi
