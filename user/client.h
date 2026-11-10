#pragma once

#include <stdint.h>

#define DRV_MAGIC 'Z'
#define DRV_OP_AUTH    _IOWR(DRV_MAGIC, 0x28, struct drv_req)
#define DRV_OP_READ    _IOWR(DRV_MAGIC, 0x76, struct drv_req)
#define DRV_OP_WRITE   _IOWR(DRV_MAGIC, 0xB6, struct drv_req)
#define DRV_OP_MODBASE _IOWR(DRV_MAGIC, 0xF6, struct drv_req)

struct drv_req {
    int    pid;
    uint64_t src;
    uint64_t dst;
    uint64_t size;
    uint32_t token;
    char   name[32];
};

#ifdef __cplusplus
extern "C" {
#endif

int       drv_connect(const char *node);
void      drv_close(void);
uintptr_t read_qword(int pid, uintptr_t addr);
uintptr_t get_module_base(const char *name);

#ifdef __cplusplus
}
#endif
