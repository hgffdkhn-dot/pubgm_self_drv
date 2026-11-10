#include "drv.h"

static int g_major;
static struct class *g_cls;
static struct device *g_dev;
static char g_drv_name[16];

static long drv_unlocked_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    return drv_ioctl(filp, cmd, arg);
}

static const struct file_operations drv_fops = {
    .owner = THIS_MODULE,
    .unlocked_ioctl = drv_unlocked_ioctl,
};

static int __init drv_init(void)
{
    g_major = register_chrdev(0, DRV_NAME_DEFAULT, &drv_fops);
    if (g_major < 0)
        return g_major;

    g_cls = class_create(THIS_MODULE, DRV_NAME_DEFAULT);
    if (IS_ERR(g_cls)) {
        unregister_chrdev(g_major, DRV_NAME_DEFAULT);
        return PTR_ERR(g_cls);
    }

    /* 设备节点由 load.sh 用 mknod 建, 这里不自动建, 避免留下固定名 */

    hide_do();

    /* 生产环境不 printk, 此处仅在调试期保留 */
    /* pr_info("%s: init ok, major=%d\n", DRV_NAME_DEFAULT, g_major); */
    return 0;
}

static void __exit drv_exit(void)
{
    if (g_dev)
        device_destroy(g_cls, MKDEV(g_major, 0));
    if (g_cls)
        class_destroy(g_cls);
    unregister_chrdev(g_major, DRV_NAME_DEFAULT);
}

module_init(drv_init);
module_exit(drv_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("dad");
MODULE_DESCRIPTION("self-made kernel driver for ares 4.14.186");
MODULE_VERSION("0.1");
