# pubgm_self_drv — 自研内核驱动

红米K40游戏增强版 (ares) / 内核 4.14.186 专用。

特点：
- 自研，不依赖市面泛滥驱动
- 手动页表遍历读取物理内存，不触发缺页/Accessed 位
- 模块加载即摘链表 + 删文件 + 随机设备节点名
- ioctl 命令码编译期随机化

## 目录结构

```
pubgm_self_drv/
├── drv_main.c        # 模块入口，init/exit
├── mem_core.c        # 页表遍历读内存核心
├── ioctl_if.c        # 用户态通信接口
├── hide.c            # 模块隐藏
├── include/
│   ├── drv.h
│   ├── pt_walk.h
│   └── drv_ioctl.h   # 由 tools/randomize.sh 生成
├── user/
│   ├── client.c      # 用户态读写接口
│   ├── client.h
│   └── test_client.c
├── tools/
│   ├── build.sh      # 主编译脚本（CI 友好）
│   ├── prep_kernel.sh
│   ├── pack_kernel.sh
│   ├── load.sh       # 随机名加载 + 删文件
│   └── randomize.sh  # 随机化 ioctl cmd
├── Kbuild
├── Makefile
└── README.md
```

## 最重要的一步：把手机的 .config 放进项目根目录

没有它，驱动模块会加载失败（内核版本/配置不匹配）。

```bash
# 手机上执行（需要 root 或 /proc/config.gz 可读）
adb shell "zcat /proc/config.gz" > .config

# 把这个 .config 文件放到项目根目录，即 pubgm_self_drv/ 的同级目录
#   pubgm_self_drv/
#   .config          <-- 就放这里
#   README.md
```

`prep_kernel.sh` 会自动找 `.config`，查找顺序：
1. `$CONFIG_FILE` 环境变量
2. 项目根目录 `/.config`
3. 项目根目录任意文件名含 `config` 的文件（如 `kernel_config`、`config.txt`）
4. 内核树内 `.config`

脚本会校验 `CONFIG_ARM64=y` 与 `4.14` 版本号。

## 编译（两条路线，选一条）

### 路线 A：全自动（推荐，没电脑也能跑）

1. 把 `.config` 放进项目根目录，`git push`
2. 到 Actions 页面手动触发 **`config-bootstrap`** 工作流
3. 它会：clone 内核 -> 注入你的 `.config` -> 全量编译 -> 打包上传 Release -> **自动把下载链接写回 `build.yml`**
4. 之后再 push 代码，`build-ko` 工作流自动下载内核树 + 增量编译出 `pubgm_self_drv.ko`

### 路线 B：本地准备内核树

```bash
./tools/prep_kernel.sh
# 产出: kernel_ares/Module.symvers

./tools/pack_kernel.sh
# 产出: kernel_ares_prepared.tar.zst
# 上传到 GitHub Release (tag: kernel-prep)
# 把下载链接填到 .github/workflows/build.yml 顶部 KERNEL_PREP_URL
```

### 触发增量编译

```bash
git add . && git commit -m "update" && git push
```

## 加载（手机端）

```bash
adb push pubgm_self_drv.ko /data/local/tmp/
adb shell
su
sh /data/local/tmp/load.sh
```

`load.sh` 会：
1. 随机化 ko 文件名
2. `insmod`
3. 加载完删除原文件
4. 建一个随机名 `/dev` 节点

## 用户态对接

```cpp
#include "user/client.h"

int main() {
    drv_connect("/dev/<随机节点>");
    uintptr_t val = read_qword(pid, addr);
    return 0;
}
```

## 反检测 Checklist

- [ ] 不出现 `process_vm_readv` 调用
- [ ] 不读 `/proc/pid/mem` 用户态
- [ ] 驱动名随机、节点名随机、cmd 码每次编译变
- [ ] `lsmod` 看不到（摘链表）
- [ ] `/proc/kallsyms` 无驱动符号
- [ ] 不写内核日志（别 printk 生产环境）
- [ ] 读取间隔抖动，不在游戏主线程上下文
- [ ] 小号先测 24 小时，再上主力号

## 参考

- 小米内核开源: https://github.com/MiCode/Xiaomi_Kernel_OpenSource
- ares (红米K40游戏增强版) 分支: `ares-r-oss`
- 4.14.186 内核，ARM64
