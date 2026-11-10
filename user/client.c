/*
 * user/client.c — 用户态对接库
 * 接口风格对齐 qx-对接.h, 内部只走 ioctl, 不调 process_vm_readv.
 */

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/ioctl.h>
#include <stdint.h>

#include "client.h"

static int g_fd = -1;
static uint32_t g_token;

int drv_connect(const char *node)
{
    struct drv_req r;
    g_fd = open(node, O_RDWR);
    if (g_fd < 0)
        return -1;

    g_token = (uint32_t)rand() ^ 0x5A5A5A5A;
    memset(&r, 0, sizeof(r));
    r.token = g_token;
    if (ioctl(g_fd, DRV_OP_AUTH, &r) < 0) {
        close(g_fd);
        g_fd = -1;
        return -2;
    }
    return 0;
}

void drv_close(void)
{
    if (g_fd >= 0) {
        close(g_fd);
        g_fd = -1;
    }
}

static int do_read(uintptr_t addr, void *buf, size_t size)
{
    struct drv_req r;
    memset(&r, 0, sizeof(r));
    r.src  = addr;
    r.dst  = (uintptr_t)buf;
    r.size = size;
    r.token = g_token;
    return ioctl(g_fd, DRV_OP_READ, &r);
}

uintptr_t read_qword(int pid, uintptr_t addr)
{
    uintptr_t v = 0;
    /* 忽略 pid: 驱动按打开时关联, 或自行扩展为 per-pid */
    (void)pid;
    do_read(addr, &v, sizeof(v));
    return v;
}

uintptr_t get_module_base(const char *name)
{
    /* 用户态读 /proc/pid/maps 解析, 驱动不参与, 避免内核暴露读取逻辑 */
    char path[64];
    FILE *fp;
    char line[512];
    uintptr_t base = 0;
    int pid;

    pid = getpid();   /* 需改为目标 pid, 由调用者传 */
    snprintf(path, sizeof(path), "/proc/%d/maps", pid);
    fp = fopen(path, "r");
    if (!fp) return 0;

    while (fgets(line, sizeof(line), fp)) {
        if (strstr(line, name)) {
            sscanf(line, "%lx", &base);
            break;
        }
    }
    fclose(fp);
    return base;
}
