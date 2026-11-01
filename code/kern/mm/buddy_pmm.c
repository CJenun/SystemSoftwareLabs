#include <buddy_pmm.h>
#include <list.h>
#include <pmm.h>

/* lab2 function3 2510942
*/

/* *
 * Buddy System physical page allocator.
 *
 * Every free block is a run of 2^order physically contiguous pages whose first
 * page is aligned to 2^order pages.  For each order there is one free list;
 * the block header page carries PG_property and stores its order in
 * "property".  All other pages of a block have no flags set.
 *
 * Allocation: the smallest power-of-two block not smaller than the request is
 * taken from the lowest non-empty order.  Larger blocks are split in halves;
 * the unused half of every split is put back on the corresponding free list.
 *
 * Free: the smallest power-of-two block covering the request is returned.  A
 * misaligned request (which never comes from alloc_pages) is decomposed into
 * maximal aligned power-of-two pieces instead.  After insertion the block is
 * repeatedly merged with its buddy while the buddy is free and of the same
 * order.
 *
 * Because page2ppn() adds nbase and nbase is a multiple of 2^BUDDY_MAX_ORDER,
 * alignment in the Page array is exactly physical alignment for every order
 * we support.
 * */

/* 128 MiB of RAM -> 2^15 pages, so 2^15 is the largest block we need. */
#define BUDDY_MAX_ORDER 15
#define BUDDY_NR_ORDERS (BUDDY_MAX_ORDER + 1)

static free_area_t buddy_free_area[BUDDY_NR_ORDERS];
static size_t buddy_nr_free;

#define buddy_list(order) (buddy_free_area[(order)].free_list)

/* Number of pages described by the Page array (indexed by page - pages). */
static inline size_t buddy_total_pages(void) { return npage - nbase; }

/* Smallest order with 2^order >= n; returns BUDDY_MAX_ORDER + 1 if too big. */
static unsigned int buddy_order_of(size_t n) {
    unsigned int order = 0;
    while (order <= BUDDY_MAX_ORDER && (1UL << order) < n) {
        order++;
    }
    return order;
}

static void buddy_init(void) {
    for (unsigned int order = 0; order < BUDDY_NR_ORDERS; order++) {
        list_init(&buddy_list(order));
        buddy_free_area[order].nr_free = 0;
    }
    buddy_nr_free = 0;
}

/* *
 * Insert one free block and merge it upwards with free buddies.
 * The block must be clean (no PG_property on any of its pages) and aligned.
 * */
static void buddy_insert(struct Page *block, unsigned int order) {
    size_t total = buddy_total_pages();
    size_t index = (size_t)(block - pages);

    assert(order <= BUDDY_MAX_ORDER);
    assert((index & ((1UL << order) - 1)) == 0);
    assert(index + (1UL << order) <= total);

    buddy_nr_free += (1UL << order);

    while (order < BUDDY_MAX_ORDER) {
        size_t buddy_index = index ^ (1UL << order);
        struct Page *buddy;

        if (buddy_index + (1UL << order) > total) {
            break;
        }
        buddy = pages + buddy_index;
        if (!PageProperty(buddy) || buddy->property != order) {
            break;
        }

        /* The buddy is a free block of the same order: take it off its list. */
        list_del(&buddy->page_link);
        ClearPageProperty(buddy);
        buddy->property = 0;

        /* The lower address is the header of the merged block. */
        if (buddy_index < index) {
            block = buddy;
            index = buddy_index;
        }
        order++;
    }

    block->property = order;
    SetPageProperty(block);
    list_add(&buddy_list(order), &block->page_link);
}

/* *
 * Free an arbitrary contiguous range by splitting it into maximal aligned
 * power-of-two blocks.  Used by init_memmap and by misaligned free requests.
 * */
static void buddy_free_range(struct Page *base, size_t n) {
    size_t index = (size_t)(base - pages);

    assert(n > 0);
    while (n > 0) {
        unsigned int order = 0;
        struct Page *p;

        while (order < BUDDY_MAX_ORDER) {
            size_t size = 1UL << (order + 1);
            if (size > n || (index & (size - 1)) != 0) {
                break;
            }
            order++;
        }

        for (p = base; p != base + (1UL << order); p++) {
            p->flags = 0;
            p->property = 0;
            set_page_ref(p, 0);
        }
        buddy_insert(base, order);

        base += (1UL << order);
        index += (1UL << order);
        n -= (1UL << order);
    }
}

static void buddy_init_memmap(struct Page *base, size_t n) {
    struct Page *p;

    assert(n > 0);
    for (p = base; p != base + n; p++) {
        assert(PageReserved(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }
    buddy_free_range(base, n);
}

static struct Page *buddy_alloc_pages(size_t n) {
    unsigned int order, current;
    struct Page *block;

    assert(n > 0);
    order = buddy_order_of(n);
    if (order > BUDDY_MAX_ORDER || buddy_nr_free < (1UL << order)) {
        return NULL;
    }

    /* Find the smallest non-empty order able to serve the request. */
    for (current = order; current <= BUDDY_MAX_ORDER; current++) {
        if (!list_empty(&buddy_list(current))) {
            break;
        }
    }
    if (current > BUDDY_MAX_ORDER) {
        return NULL;
    }

    block = le2page(list_next(&buddy_list(current)), page_link);
    list_del(&block->page_link);
    ClearPageProperty(block);
    block->property = 0;

    /* Split down to the requested order; return the upper half each time. */
    while (current > order) {
        struct Page *buddy;

        current--;
        buddy = block + (1UL << current);
        buddy->flags = 0;
        buddy->property = current;
        SetPageProperty(buddy);
        list_add(&buddy_list(current), &buddy->page_link);
    }

    block->flags = 0;
    block->property = 0;
    set_page_ref(block, 0);
    buddy_nr_free -= (1UL << order);
    return block;
}

static void buddy_free_pages(struct Page *base, size_t n) {
    unsigned int order;
    size_t total = buddy_total_pages();
    size_t index = (size_t)(base - pages);
    struct Page *p;

    assert(n > 0);
    order = buddy_order_of(n);
    assert(order <= BUDDY_MAX_ORDER);
    assert(index < total && index + n <= total);

    for (p = base; p != base + n; p++) {
        assert(!PageReserved(p));
        p->flags = 0;
        p->property = 0;
        set_page_ref(p, 0);
    }

    if ((index & ((1UL << order) - 1)) == 0 &&
        index + (1UL << order) <= total) {
        /* Normal case: the request is a whole aligned block. */
        buddy_insert(base, order);
    } else {
        /* Defensive path: free exactly the requested pages. */
        buddy_free_range(base, n);
    }
}

static size_t buddy_nr_free_pages(void) { return buddy_nr_free; }

/* Verify the shape of every free list and the global page accounting. */
static void buddy_check(void) {
    size_t total = 0;

    for (unsigned int order = 0; order < BUDDY_NR_ORDERS; order++) {
        list_entry_t *le = &buddy_list(order);
        while ((le = list_next(le)) != &buddy_list(order)) {
            struct Page *p = le2page(le, page_link);
            size_t index = (size_t)(p - pages);

            assert(PageProperty(p));
            assert(p->property == order);
            assert(p >= pages && index + (1UL << order) <= buddy_total_pages());
            assert((index & ((1UL << order) - 1)) == 0);
            total += (1UL << order);
        }
    }
    assert(total == buddy_nr_free);

    /* Exercise allocation, splitting, merging and page accounting. */
    size_t free_before = buddy_nr_free;
    if (free_before >= 16) {
        struct Page *p = buddy_alloc_pages(16);

        assert(p != NULL);
        assert(!PageProperty(p));
        assert((((size_t)(p - pages)) & 15) == 0);
        assert(buddy_nr_free == free_before - 16);

        /* Free the block in pieces; the pieces must coalesce again. */
        buddy_free_pages(p, 1);
        buddy_free_pages(p + 1, 1);
        buddy_free_pages(p + 2, 2);
        buddy_free_pages(p + 4, 4);
        buddy_free_pages(p + 8, 8);
        assert(buddy_nr_free == free_before);

        /* A non-power-of-two request is rounded up to 4 pages. */
        p = buddy_alloc_pages(3);
        assert(p != NULL);
        assert(buddy_nr_free == free_before - 4);
        buddy_free_pages(p, 3);
        assert(buddy_nr_free == free_before);

        /* A request larger than all free memory must fail. */
        assert(buddy_alloc_pages(free_before + 1) == NULL);

        /* The free lists must still be consistent after all of the above. */
        total = 0;
        for (unsigned int order = 0; order < BUDDY_NR_ORDERS; order++) {
            list_entry_t *le = &buddy_list(order);
            while ((le = list_next(le)) != &buddy_list(order)) {
                struct Page *q = le2page(le, page_link);
                assert(PageProperty(q) && q->property == order);
                total += (1UL << order);
            }
        }
        assert(total == buddy_nr_free);
    }
}

const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};
