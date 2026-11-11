#!/usr/bin/env bash
# AUTOBUILD: 20261110-2240
set -u
SRC_KO="${1:-pubgm_self_drv.ko}"
[ -f "$SRC_KO" ] || { echo "[-] $SRC_KO 不存在"; exit 1; }
HIDDEN="/data/local/tmp/.$(head -c 8 /dev/urandom | xxd -p)"
cp "$SRC_KO" "$HIDDEN" 2>/dev/null && chmod 600 "$HIDDEN" 2>/dev/null || true
echo "[*] 已放置: $HIDDEN"
echo "[*] 请手动执行: insmod $HIDDEN"
