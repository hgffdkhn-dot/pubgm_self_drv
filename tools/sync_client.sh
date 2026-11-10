#!/bin/bash
# tools/sync_client.sh —— 把内核侧 randomize 出的 cmd 码同步到用户态 client.h
# 内核与用户态必须共用同一套 _IOWR 宏, 否则 ioctl 对不上会返回 ENOTTY.
# 先跑 randomize.sh, 再跑本脚本, 最后编译驱动 + 用户态.

set -u

SCRIPT_DIR=$(dirname "$0")
DRV_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
KH="$DRV_DIR/build/drv_ioctl.h"
CH="$DRV_DIR/user/client.h"

if [ ! -s "$KH" ]; then
    echo "[-] 没找到 $KH, 先跑: ./tools/randomize.sh" >&2
    exit 1
fi

# 从 build/drv_ioctl.h 抽 _IOWR 第二个参数 (cmd 偏移)
# 格式: #define DRV_OP_XXX _IOWR('Z', 0xNN, struct drv_req)
get() {
    key="$1"
    grep "define  *${key}" "$KH" | head -1 | sed -E 's/.*_IOWR\([^,]*, *([^,]*),.*/\1/' | tr -d ' '
}

AUTH=$(get  "DRV_OP_AUTH")
READ=$(get  "DRV_OP_READ")
WRITE=$(get "DRV_OP_WRITE")
MOD=$(get   "DRV_OP_MODBASE")

for v in "$AUTH" "$READ" "$WRITE" "$MOD"; do
    if ! echo "$v" | grep -qiE '^(0x)?[0-9a-f]+$'; then
        echo "[-] 无法从 $KH 解析 cmd 码 (AUTH=$AUTH READ=$READ WRITE=$WRITE MOD=$MOD)" >&2
        exit 1
    fi
done

# 用 python 安全改写 client.h (行号定位, 避免宏名正则误匹配)
python3 - "$CH" "$AUTH" "$READ" "$WRITE" "$MOD" <<'PY'
import sys, re
path, auth, read, write, mod = sys.argv[1:6]
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

mapping = {
    "DRV_OP_AUTH":    auth,
    "DRV_OP_READ":    read,
    "DRV_OP_WRITE":   write,
    "DRV_OP_MODBASE": mod,
}
out = []
for ln in lines:
    m = re.match(
        r'^(\s*#\s*define\s+)(DRV_OP_[A-Z]+)'
        r'(\s+_IOWR\(\s*DRV_MAGIC\s*,\s*)([^,]*)(,\s*struct\s+drv_req\s*\)\s*)$',
        ln)
    if m and m.group(2) in mapping:
        ln = "".join([
            m.group(1), m.group(2), m.group(3),
            mapping[m.group(2)], m.group(5)
        ])
    out.append(ln)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)

print("OK:%s:%s:%s:%s" % (auth, read, write, mod))
PY
