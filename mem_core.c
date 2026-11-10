#include "drv.h"

/*
 * 读目标进程内存: 手动页表遍历 + memremap, 不触发缺页.
 * 返回 0 成功, 负数失败.
 */
int mem_read_task(struct task_struct *task, unsigned long va, void *buf, size_t len)
{
    struct mm_struct *mm;
    phys_addr_t pa;
    void *map;
    size_t page_off, chunk;
    unsigned long cur = va;
    size_t done = 0;

    if (!task || !buf || len == 0)
        return -EINVAL;

    mm = get_task_mm(task);
    if (!mm)
        return -ESRCH;

    while (done < len) {
        pa = pt_walk_va2pa(mm, cur);
        if (!pa) {
            mmput(mm);
            return -EFAULT;   /* 页不在物理内存 */
        }

        page_off = cur & (PAGE_SIZE - 1);
        chunk = min((size_t)(PAGE_SIZE - page_off), len - done);

        map = memremap(pa, PAGE_SIZE, MEMREMAP_WB);
        if (!map) {
            mmput(mm);
            return -ENOMEM;
        }

        memcpy(buf + done, (char *)map + page_off, chunk);
        memunmap(map);

        cur += chunk;
        done += chunk;
    }

    mmput(mm);
    return 0;
}
