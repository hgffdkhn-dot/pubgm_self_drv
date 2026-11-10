# pubgm_self_drv — 自研内核驱动（红米K40游戏增强版 ares / 4.14.186）

## ⚠️ 声明
本项目仅用于 **Android 内核安全研究 / 学习页表遍历与内核模块隐藏技术**。
请勿用于违反游戏用户协议、破坏公平性的用途。使用本项目产生的任何后果由使用者自行承担。

## 项目结构
```
pubgm_self_drv/
├── Makefile              # 内核模块编译入口
├── Kbuild                # 内核 build 配置
├── drv_main.c            # 模块入口 + 加载后擦痕迹
├── mem_core.c            # 页表遍历读目标进程内存
├── ioctl_if.c            # 用户态 ioctl 通信（随机 cmd 码 + 握手）
├── hide.c                # 隐藏：摘模块链表 / 擦符号
├── include/
│   ├── drv.h
│   └── pt_walk.h
├── user/
│   ├── Makefile
│   └── client.c          # 用户态库，对接 qx-对接.h 风格接口
└── tools/
    ├── build.sh          # 云编译 / 本地编译脚本
    ├── load.sh           # 随机名 insmod + 删文件 + 随机节点
    └── randomize.sh      # 编译前随机化驱动名 / cmd 码
```

## 一、编译（Ubuntu / GitHub Actions / Termux+proot）
依赖：aarch64-linux-gnu-gcc、make、bc、bison、flex、libssl-dev、对应内核源码树。

```bash
# 1. 拉取 ares 4.14.186 内核源码（小米开源）
git clone --depth 1 -b ares-r-4.14.186 https://github.com/MiCode/Xiaomi_Kernel_OpenSource.git kernel_ares
export KERNEL=/path/to/kernel_ares

# 2. 首次编译内核（生成 Module.symvers / 头文件）
cd $KERNEL
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ares_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_prepare -j$(nproc)

# 3. 编译本驱动
cd /path/to/pubgm_self_drv
make KDIR=$KERNEL        # 产出 pubgm_self.ko
```

> 随机化：每次编译前跑 `bash tools/randomize.sh`，会随机替换驱动名和 ioctl cmd 偏移。

## 二、加载（手机端，root）
```bash
adb push pubgm_self.ko /data/local/tmp/
adb shell
su
cd /data/local/tmp
bash /path/to/load.sh     # 随机名 insmod + 删 ko + 建随机 /dev 节点
```

`load.sh` 会：
1. 把 ko 复制成随机 6 位小写字母名（隐藏文件）
2. `insmod` 加载
3. 加载完立刻 `rm` 掉源文件
4. 在 `/dev/` 下建随机名字符设备节点
5. 驱动内部摘掉模块链表、擦符号

## 三、用户态对接
```cpp
#include "client.h"

int main() {
    drv_connect("/dev/.随机节点名");      // load.sh 会打印实际节点名
    uintptr_t base = get_module_base(pid, "libUE4.so");
    uintptr_t uworld = read_qword(pid, base + 0x1771CC38);  // GWorld
    // ... 接你已有的偏移体系
}
```

接口与 `qx-对接.h` 风格一致：`read_qword` / `write_qword` / `get_module_base`，
用户态只走 `ioctl`，**完全不调** `process_vm_readv` / 不读 `/proc/pid/mem`。

## 四、反检测要点（务必全过再上号）
- [ ] 驱动名 / 节点名 / ioctl cmd 全部随机化
- [ ] 模块从链表摘除，`lsmod` 不可见
- [ ] `/proc/kallsyms` 无本驱动符号
- [ ] 无 printk / 不写内核日志
- [ ] 用户态不出现 process_vm_readv
- [ ] 读取间隔抖动，不在游戏渲染线程上下文
- [ ] 先用小号测试 24h，稳定后再用主力号

## 五、验证加载是否成功
```bash
lsmod | grep -i 随机名     # 应为空
cat /proc/kallsyms | grep drv_init   # 应为空
./user/test_client         # 自带的读写测试程序
```
