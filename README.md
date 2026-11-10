# pubgm_self_drv — 自研内核驱动

红米K40游戏增强版 (ares) / 内核 4.14.186 专用。自研，不依赖市面泛滥驱动。

## 核心设计

- **手动页表遍历 + `memremap` 读物理内存**：不触发缺页、不置 Accessed/Dirty 位、不调 `get_user_pages` / `process_vm_readv`
- **加载即摘链表 + 删文件 + 随机设备节点名**：`lsmod`、`/proc/modules` 不可见
- **ioctl 命令码编译期随机化**：每次 `build.sh` 自动换，内核侧与用户态侧通过 `sync_client.sh` 保持一致
- **不 printk 生产环境**：`drv_init` 不输出任何日志

## 目录结构

```
pubgm_self_drv/
├── drv_main.c          # 模块入口 init/exit
├── mem_core.c          # 页表遍历读内存核心
├── ioctl_if.c          # ioctl 分发 + AUTH 握手
├── hide.c              # 模块隐藏 (摘链表)
├── Makefile / Kbuild   # 均 include Makefile.inc
├── Makefile.inc        # 公共: 源文件列表 + ccflags -Ibuild -Iinclude
├── include/
│   ├── drv.h           # 共用头 (cmd 宏在 build/drv_ioctl.h 存在时被跳过)
│   └── pt_walk.h       # ARM64 四级页表遍历
├── build/              # ★ randomize.sh 产出的 drv_ioctl.h 在此, 编译时优先包含
├── user/
│   ├── client.c        # 用户态读写接口 (仅 ioctl, 不碰 process_vm_readv)
│   ├── client.h        # cmd 码必须与内核侧 build/drv_ioctl.h 一致
│   └── test_client.c   # 自检程序
├── tools/
│   ├── build.sh        # 主编译 (randomize → sync → toolchain 检查 → 编译)
│   ├── prep_kernel.sh  # 全量编译内核, 生成 Module.symvers
│   ├── pack_kernel.sh  # 打包内核树上传 Release
│   ├── randomize.sh    # 随机 ioctl cmd, 写 build/drv_ioctl.h
│   ├── sync_client.sh  # 把随机 cmd 同步到 user/client.h
│   ├── load.sh         # 手机端: 随机名 insmod + 删文件 + 随机节点
│   └── diag.sh         # 环境诊断 (CI 失败时跑)
└── .github/workflows/
    ├── build.yml           # 增量编译出 .ko
    └── config-bootstrap.yml # 首次: 注入 .config 全量编译内核
```

## 最关键的：`.config` 放哪

手机导出：
```bash
adb shell "zcat /proc/config.gz" > .config
```

**正确位置是项目根目录**（与 `pubgm_self_drv/` 同级）：
```
你的仓库/
├── pubgm_self_drv/
├── .config          ← 放这里
└── README.md
```

`prep_kernel.sh` 自动查找顺序：
1. `$CONFIG_FILE` 环境变量
2. 项目根目录 `/.config`
3. 项目根目录任意含 `config` 的文件名（`kernel_config`、`config.txt` 等）
4. 内核树内 `.config`

脚本校验 `CONFIG_ARM64=y` 与版本 `4.14`。

## 编译流程（两条路，选一条）

### 路线 A：全自动（推荐，没电脑也能跑）

1. 把 `.config` 放到项目根目录，`git add .config && git commit && git push`
2. 到 GitHub Actions 页面手动触发 **`config-bootstrap`**
   - 它会：clone `ares-r-oss` → 注入 `.config` → `olddefconfig` → 全量编译（60-120 分钟）→ 打包上传 Release `kernel-prep` → 自动把下载链接写回 `build.yml`
3. 之后再 push 代码，`build-ko` 自动下载内核树 + 增量编译出 `pubgm_self_drv.ko`

### 路线 B：本地准备内核树

```bash
./tools/prep_kernel.sh      # 全量编译, 产出 kernel_ares/Module.symvers
./tools/pack_kernel.sh      # 打包成 kernel_ares_prepared.tar.zst
# 上传到 GitHub Release (tag: kernel-prep)
# 把下载链接填到 .github/workflows/build.yml 顶部 KERNEL_PREP_URL
```

## 本地编译驱动（有 Linux 环境时）

```bash
./tools/randomize.sh        # 产出 build/drv_ioctl.h
./tools/sync_client.sh      # 同步 user/client.h
./tools/build.sh            # 编译出 pubgm_self_drv.ko
```

诊断（编译失败时）：
```bash
KERNEL_TREE=/path/to/kernel_ares ./tools/diag.sh
```

## 加载（手机端，需要 root）

```bash
adb push pubgm_self_drv.ko /data/local/tmp/
adb shell
su
sh /data/local/tmp/load.sh
# 输出: [+] loaded, node=/dev/.xxxxx  (major=NNN)
# 把这个节点路径填进你的 drv_connect()
```

`load.sh` 会：随机化 ko 文件名 → `insmod` → 删除原文件 → 从 `/proc/devices` 取 major → `mknod` 随机名节点。

## 用户态对接

```c
#include "user/client.h"

int main() {
    drv_connect("/dev/.随机节点");   // load.sh 输出的那个路径
    uintptr_t val = read_qword(pid, addr);
    drv_close();
    return 0;
}
```

## 反检测 Checklist

- [ ] 不出现 `process_vm_readv` / `get_user_pages` 调用
- [ ] 不读 `/proc/pid/mem`
- [ ] 驱动名随机、节点名随机、cmd 码每次编译变
- [ ] `lsmod` 看不到（摘链表）
- [ ] `/proc/kallsyms` 无驱动符号（完整隐藏需改内核镜像）
- [ ] 生产环境不 `printk`
- [ ] 读取间隔抖动，不在游戏主线程上下文
- [ ] **小号先测 24 小时，再上朋友的号**

## 参考

- 小米内核开源: https://github.com/MiCode/Xiaomi_Kernel_OpenSource
- ares 分支: `ares-r-oss`
- 内核 4.14.186 / ARM64
