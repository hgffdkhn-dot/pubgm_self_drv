/*
 * test_client.c — 自检: 连接驱动读一个地址
 * 用法: ./test_client /dev/.随机节点 <pid> <addr>
 */
#include <stdio.h>
#include <stdint.h>
#include "client.h"

int main(int argc, char **argv)
{
    const char *node;
    int pid;
    uintptr_t addr, v;

    if (argc < 4) {
        fprintf(stderr, "usage: %s <node> <pid> <addr>\n", argv[0]);
        return 1;
    }
    node = argv[1];
    pid  = atoi(argv[2]);
    addr = (uintptr_t)strtoull(argv[3], NULL, 0);

    if (drv_connect(node) < 0) {
        fprintf(stderr, "connect %s failed\n", node);
        return 1;
    }

    v = read_qword(pid, addr);
    printf("read @%p = 0x%lx\n", (void*)addr, (unsigned long)v);

    drv_close();
    return 0;
}
