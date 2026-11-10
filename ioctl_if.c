#include "drv.h"

static u32 g_token;            /* 握手令牌, 0 表示未认证 */
static struct drv_req g_last_req;

static int do_read(struct drv_req *r)
{
    struct task_struct *task;
    void *buf;
    int ret;

    if (r->size == 0 || r->size > 0x100000)
        return -EINVAL;

    task = find_get_task_by_vpid(r->pid);
    if (!task)
        return -ESRCH;

    buf = kzalloc(r->size, GFP_KERNEL);
    if (!buf) {
        put_task_struct(task);
        return -ENOMEM;
    }

    ret = mem_read_task(task, r->src, buf, r->size);
    if (ret == 0) {
        if (copy_to_user((void __user *)r->dst, buf, r->size))
            ret = -EFAULT;
    }

    kfree(buf);
    put_task_struct(task);
    return ret;
}

long drv_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    struct drv_req r;
    int ret = 0;

    if (copy_from_user(&r, (void __user *)arg, sizeof(r)))
        return -EFAULT;

    /* AUTH 握手: 拿到即生效, 用 XOR 扰乱 token, 0 视为未初始化 */
    if (cmd == DRV_OP_AUTH) {
        g_token = r.token ^ 0x5A5A5A5A;
        if (g_token == 0)
            g_token = 0x5A5A5A5A;
        return 0;
    }

    /* 其余命令必须握手 */
    if (g_token == 0 || r.token != g_token)
        return -EPERM;

    switch (cmd) {
    case DRV_OP_READ:
        ret = do_read(&r);
        break;
    case DRV_OP_WRITE:
        /* 预留: 写内存, 需先在页表项置可写位, 慎用 */
        ret = -ENOSYS;
        break;
    case DRV_OP_MODBASE:
        ret = -ENOSYS;
        break;
    default:
        ret = -EINVAL;
    }

    g_last_req = r;
    return ret;
}
