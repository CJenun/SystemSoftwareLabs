#include <pmm.h>
#include <buddy_pmm.h>
#include <memlayout.h>
#include <mmu.h>
#include <stdio.h>

/* *
 * Runtime self-test for the buddy system PMM.
 *
 * This file lives in kern/mm, so the Makefile compiles it automatically.
 * To run it, add these two lines at the end of pmm_init() in kern/mm/pmm.c:
 *
 *     extern void test_buddy(void);
 *     test_buddy();
 *
 * The test skips itself when another manager (e.g. best_fit) is active, so it
 * is safe to call unconditionally.
 *
 * It verifies:
 *   - allocation sizes/alignment and page accounting;
 *   - splitting a large block and merging the pieces back;
 *   - a mixed allocation workload with no overlapping blocks;
 *   - that reserved pages never enter the allocator;
 *   - the manager's internal consistency check after the workload.
 * 
检查项	内容
超大请求	申请比全部空闲页还多时必须返回 NULL
基本分配	1/3/5 页请求的地址对齐、块互不重叠、空闲页精确记账
拆分/合并	分配 16 页后按 1+1+2+4+8 分片释放，确认完全合并并能再次分配
混合负载	64 个 1～32 页的块循环分配，逐块检查对齐、无重叠、页数账目；两轮释放后恢复初始空闲页数
保留页	pages[0]（OpenSBI 区）保持 PageReserved 且不在空闲链表中
内部自检	负载结束后再调用一次 pmm_manager->check()
 * */

#define BUDDY_TEST_MAX_BLOCKS 64

static struct Page *held_page[BUDDY_TEST_MAX_BLOCKS];
static size_t held_n[BUDDY_TEST_MAX_BLOCKS];
static size_t held_block_pages[BUDDY_TEST_MAX_BLOCKS];

/* Number of pages a request of n pages really occupies. */
static size_t
buddy_test_block_pages(size_t n) {
    size_t pages = 1;
    while (pages < n) {
        pages <<= 1;
    }
    return pages;
}

static bool
buddy_test_overlap(struct Page *a, size_t an, struct Page *b, size_t bn) {
    return a < b + bn && b < a + an;
}

void
test_buddy(void) {
    if (pmm_manager != &buddy_pmm_manager) {
        cprintf("[Buddy Test] SKIP (memory management: %s)\n",
                pmm_manager->name);
        return;
    }

    size_t free0 = nr_free_pages();
    cprintf("[Buddy Test] start, free pages = %lu\n", (unsigned long)free0);

    /* An impossible request must fail cleanly. */
    assert(alloc_pages(free0 + 1) == NULL);

    /* Basic allocation, alignment and accounting. */
    struct Page *a = alloc_pages(1);
    struct Page *b = alloc_pages(3);   /* occupies 4 pages */
    struct Page *c = alloc_pages(5);   /* occupies 8 pages */
    assert(a != NULL && b != NULL && c != NULL);
    assert(!PageProperty(a) && !PageProperty(b) && !PageProperty(c));
    assert((((size_t)(b - pages)) & 3) == 0);
    assert((((size_t)(c - pages)) & 7) == 0);
    assert(!buddy_test_overlap(a, 1, b, 4));
    assert(!buddy_test_overlap(a, 1, c, 8));
    assert(!buddy_test_overlap(b, 4, c, 8));
    assert(nr_free_pages() == free0 - 13);

    free_pages(b, 3);
    free_pages(a, 1);
    free_pages(c, 5);
    assert(nr_free_pages() == free0);
    cprintf("[Buddy Test] basic: PASS\n");

    /* Split a 16-page block, return it piece by piece, then reuse it. */
    struct Page *p = alloc_pages(16);
    assert(p != NULL);
    assert((((size_t)(p - pages)) & 15) == 0);
    assert(nr_free_pages() == free0 - 16);

    free_pages(p, 1);
    assert(nr_free_pages() == free0 - 15);
    free_pages(p + 1, 1);
    assert(nr_free_pages() == free0 - 14);
    free_pages(p + 2, 2);
    assert(nr_free_pages() == free0 - 12);
    free_pages(p + 4, 4);
    assert(nr_free_pages() == free0 - 8);
    free_pages(p + 8, 8);
    assert(nr_free_pages() == free0);

    p = alloc_pages(16);
    assert(p != NULL);
    free_pages(p, 16);
    assert(nr_free_pages() == free0);
    cprintf("[Buddy Test] split/merge: PASS\n");

    /* Mixed workload: blocks must never overlap, accounting must stay exact. */
    static const size_t sizes[] = {1, 2, 3, 4, 5, 8, 16, 32};
    size_t nheld = 0;
    size_t expected = free0;

    for (size_t i = 0; i < BUDDY_TEST_MAX_BLOCKS; i++) {
        size_t n = sizes[i % (sizeof(sizes) / sizeof(sizes[0]))];
        size_t block_pages = buddy_test_block_pages(n);
        struct Page *q = alloc_pages(n);
        assert(q != NULL);
        assert(!PageProperty(q));
        assert((((size_t)(q - pages)) & (block_pages - 1)) == 0);

        for (size_t j = 0; j < nheld; j++) {
            assert(!buddy_test_overlap(q, block_pages,
                                       held_page[j], held_block_pages[j]));
        }

        held_page[nheld] = q;
        held_n[nheld] = n;
        held_block_pages[nheld] = block_pages;
        nheld++;

        expected -= block_pages;
        assert(nr_free_pages() == expected);
    }

    /* Release in two passes so an odd/even split is exercised too. */
    for (size_t i = 0; i < nheld; i += 2) {
        free_pages(held_page[i], held_n[i]);
        expected += held_block_pages[i];
        assert(nr_free_pages() == expected);
    }
    for (size_t i = 1; i < nheld; i += 2) {
        free_pages(held_page[i], held_n[i]);
        expected += held_block_pages[i];
        assert(nr_free_pages() == expected);
    }
    assert(nr_free_pages() == free0);
    cprintf("[Buddy Test] stress: PASS\n");

    /* Reserved pages (OpenSBI/kernel/Page array) must stay out of the lists. */
    assert(PageReserved(&pages[0]));
    assert(!PageProperty(&pages[0]));
    cprintf("[Buddy Test] reserved: PASS\n");

    /* Run the module's own consistency check after the workload. */
    pmm_manager->check();
    cprintf("[Buddy Test] PASS\n");
}
