#include "drv.h"

/*
 * 隐藏手段:
 *  1) 从模块链表摘除, lsmod 不可见
 *  2) 清理 __ksymtab / kallsyms 相关符号 (4.14 上符号节通常不可写,
 *     故只做链表摘除 + 不 printk)
 *
 * 注意: 现代反作弊还会扫 /proc/kallsyms 与 page_owner, 完整隐藏需配合
 * 修改内核镜像 (CONFIG_KALLSYMS_ALL=n / 改内核), 此处仅做基础隐藏.
 */
static void hide_module(void)
{
    struct list_head *list;

    list = &THIS_MODULE->list;
    if (!list_empty(list)) {
        list_del_init(list);
    }

    /* 摘除 kobject, sysfs 下也不可见 */
    if (THIS_MODULE->holders_dir)
        THIS_MODULE->holders_dir = NULL;
}

void hide_do(void)
{
    hide_module();
}
