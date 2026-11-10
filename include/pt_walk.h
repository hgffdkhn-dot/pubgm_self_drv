#pragma once

#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/sched/task.h>

/*
 * ARM64 四级页表遍历: PGD -> PUD -> PMD -> PTE
 * 目标: 给定 task 的 mm 与虚拟地址 va, 返回物理页帧基址.
 * 特点: 纯查询, 不置 Accessed/Dirty 位, 不触发缺页, 不调 get_user_pages.
 */
static inline phys_addr_t pt_walk_va2pa(struct mm_struct *mm, unsigned long va)
{
    pgd_t *pgd;
    pud_t *pud;
    pmd_t *pmd;
    pte_t *pte;

    if (!mm || !mm->pgd)
        return 0;

    pgd = pgd_offset(mm, va);
    if (pgd_none(*pgd) || pgd_bad(*pgd))
        return 0;

    pud = pud_offset(pgd, va);
    if (pud_none(*pud) || pud_bad(*pud))
        return 0;

    pmd = pmd_offset(pud, va);
    if (pmd_none(*pmd) || pmd_bad(*pmd))
        return 0;

    pte = pte_offset_kernel(pmd, va);
    if (!pte || pte_none(*pte))
        return 0;

    /* 返回该页的物理基址 (不含页内偏移) */
    return (pte_pfn(*pte) << PAGE_SHIFT);
}
