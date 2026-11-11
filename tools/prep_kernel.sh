#!/bin/sh
# 将 .config 转为 ares_defconfig (仅过滤有效行)
set -u
SRC=""
for f in .config config kernel_config config.txt; do
  [ -f "$f" ] && SRC="$f" && break
done
[ -z "$SRC" ] && { echo "[-] 无配置文件"; exit 1; }
echo "[+] 来源: $SRC"
# defconfig 只保留 = 赋值行, 去掉注释与空行
grep -E '^[A-Za-z0-9_]+=|^# [A-Za-z0-9_]+ is not set' "$SRC" \
  | grep -v '^#' \
  > ares_defconfig
echo "[+] ares_defconfig: $(wc -l < ares_defconfig) 行"
head -3 ares_defconfig
