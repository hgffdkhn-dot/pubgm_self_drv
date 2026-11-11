#!/usr/bin/env bash
# AUTOBUILD: 20261110-2240
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
log() { echo "$@"; }

ensure_toolchain() {
  log "[*] 工具链自检 ..."
  : "${CROSS_COMPILE:=aarch64-linux-gnu-}"
  if command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    log "[+] ${CROSS_COMPILE}gcc: $(${CROSS_COMPILE}gcc --version | head -1)"
  else
    log "[-] 缺少 ${CROSS_COMPILE}gcc (CI 不自动安装, 请在外层 workflow 准备)"
    exit 1
  fi
  for t in bc bison flex; do
    command -v "$t" >/dev/null 2>&1 || log "[!] 警告: $t 缺失, 内核编译可能失败"
  done
}

prepare_kernel() {
  local KS="${KERNEL_TREE:-$ROOT/kernel_ares}"
  log "[*] 检查内核树: $KS"
  if [ -d "$KS" ] && [ -f "$KS/Module.symvers" ]; then log "[+] 内核树就绪"; return 0; fi
  log "[-] 内核树缺失, 尝试现场 clone ..."
  rm -rf "$KS"
  git clone --depth 1 -b ares-r-oss https://github.com/MiCode/Xiaomi_Kernel_OpenSource "$KS" 2>&1 | tail -3 \
    || git clone --depth 1 -b ares-r-oss https://github.com/AbzRaider/kernel_xiaomi_ares "$KS" 2>&1 | tail -3 \
    || { log "[-] clone 失败"; exit 2; }
  local CFG=""
  for f in .config config kernel_config config.txt; do
    [ -f "$ROOT/$f" ] && CFG="$ROOT/$f" && break
  done
  [ -z "$CFG" ] && { log "[-] 无 .config 可用"; exit 2; }
  cp "$CFG" "$KS/.config"
  cd "$KS"
  make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" olddefconfig 2>&1 | tail -2
  make ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)" Image modules 2>&1 | tail -5
  cd "$ROOT"
  [ -f "$KS/Module.symvers" ] || { log "[-] 编译后 Module.symvers 仍缺失"; exit 2; }
}

build_ko() {
  log "[*] 编译驱动模块 ..."
  local KS="${KERNEL_TREE:-$ROOT/kernel_ares}"
  export KERNEL_TREE="$KS"
  make -C "$KS" M="$ROOT" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" modules 2>&1 | tee build.log | tail -20
  if [ -f pubgm_self_drv.ko ]; then
    log "[+] 产出: $(ls -lh pubgm_self_drv.ko | awk '{print $5}')"
  else
    log "[-] 未产出 .ko"; exit 2
  fi
}

main() {
  log "===== 步骤 1/3: 工具链自检 ====="; ensure_toolchain
  log "===== 步骤 2/3: 内核树准备 ====="; prepare_kernel
  log "===== 步骤 3/3: 编译 .ko ====="; build_ko
  log "===== 全部完成 ====="
}
main "$@"
