#include <linux/module.h>
#include <linux/kernel.h>
static int __init drv_init(void){ pr_info("pubgm_self_drv: init\n"); return 0; }
static void __exit drv_exit(void){ pr_info("pubgm_self_drv: exit\n"); }
module_init(drv_init); module_exit(drv_exit);
MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("pubgm self driver");
