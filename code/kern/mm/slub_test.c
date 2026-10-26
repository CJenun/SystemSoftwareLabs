#include <slub.h>

#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <stdio.h>
#include <string.h>

/* *
 * Runtime self test for the simplified SLUB allocator.
 *
 * This file lives in kern/mm, so the Makefile compiles it automatically.
 * To run it, add the following after pmm_init() (see SLUB_README.md):
 *
 *     slub_init();
 *     slub_self_test();
 *
 * The test only uses the public SLUB API and nr_free_pages(), so it works
 * with either the best-fit or the buddy pmm_manager.
 * */

#define TEST_CHECK(cond, msg)                            \
    do {                                                 \
        if (!(cond)) {                                   \
            cprintf("[SLUB Test] FAIL: %s\n", (msg));    \
            return 0;                                    \
        }                                                \
    } while (0)

#define TEST_MAX_OBJECTS 256
#define TEST_MANY_OBJECTS 600

struct test_object {
    void *ptr;
    size_t size;
    unsigned char pattern;
};

static struct test_object test_objects[TEST_MAX_OBJECTS];
static size_t test_object_count;

static int
test_overlap(uintptr_t a, size_t alen, uintptr_t b, size_t blen) {
    return a < b + blen && b < a + alen;
}

/* Record an allocation, check alignment/overlap, and fill it with a pattern. */
static int
test_record(void *ptr, size_t size, unsigned char pattern) {
    size_t i;

    if (ptr == NULL || test_object_count >= TEST_MAX_OBJECTS) {
        return 0;
    }
    if (((uintptr_t)ptr & (SLUB_MIN_OBJECT_SIZE - 1)) != 0) {
        return 0;
    }
    for (i = 0; i < test_object_count; i++) {
        if (test_overlap((uintptr_t)ptr, size,
                         (uintptr_t)test_objects[i].ptr,
                         test_objects[i].size)) {
            return 0;
        }
    }

    memset(ptr, pattern, size);
    test_objects[test_object_count].ptr = ptr;
    test_objects[test_object_count].size = size;
    test_objects[test_object_count].pattern = pattern;
    test_object_count++;
    return 1;
}

static int
test_verify_all(void) {
    size_t i;
    size_t j;

    for (i = 0; i < test_object_count; i++) {
        unsigned char *p = (unsigned char *)test_objects[i].ptr;

        for (j = 0; j < test_objects[i].size; j++) {
            if (p[j] != test_objects[i].pattern) {
                return 0;
            }
        }
    }
    return 1;
}

static void
test_free_all(void) {
    while (test_object_count > 0) {
        test_object_count--;
        slub_free(test_objects[test_object_count].ptr);
    }
}

/* Layer 1: contiguous page allocation through the pmm_manager. */
static int
test_page_layer(void) {
    size_t before = nr_free_pages();
    void *one = slub_page_alloc(1);
    void *three = slub_page_alloc(3);
    unsigned char *a = (unsigned char *)one;
    unsigned char *b = (unsigned char *)three;

    TEST_CHECK(one != NULL && three != NULL, "page allocation returned NULL");
    TEST_CHECK(((uintptr_t)one % PGSIZE) == 0 &&
                   ((uintptr_t)three % PGSIZE) == 0,
               "page allocation is not page aligned");
    TEST_CHECK(!test_overlap((uintptr_t)one, PGSIZE,
                             (uintptr_t)three, 3 * PGSIZE),
               "page allocations overlap");

    memset(one, 0xA5, PGSIZE);
    memset(three, 0x5A, 3 * PGSIZE);
    TEST_CHECK(a[0] == 0xA5 && a[PGSIZE - 1] == 0xA5,
               "one-page buffer is not usable");
    TEST_CHECK(b[0] == 0x5A && b[3 * PGSIZE - 1] == 0x5A,
               "three-page buffer is not usable");

    slub_page_free(one, 1);
    slub_page_free(three, 3);
    TEST_CHECK(nr_free_pages() == before, "page accounting is wrong");
    return 1;
}

/* Every size class, four objects each, allocated and freed in mixed order. */
static int
test_size_classes(void) {
    static const size_t sizes[] = {
        1,    7,    8,    9,    15,   16,   17,   24,
        31,   32,   33,   48,   63,   64,   65,   96,
        127,  128,  129,  192,  255,  256,  257,  384,
        511,  512,  513,  768,  1023, 1024, 1025, 1536,
        1537, 2048,
    };
    const size_t nr_sizes = sizeof(sizes) / sizeof(sizes[0]);
    size_t i;
    size_t j;

    test_object_count = 0;

    for (i = 0; i < nr_sizes; i++) {
        for (j = 0; j < 4; j++) {
            void *ptr = slub_alloc(sizes[i]);
            unsigned char pattern = (unsigned char)(0x10 + i * 4 + j);

            TEST_CHECK(ptr != NULL, "size-class allocation returned NULL");
            TEST_CHECK(test_record(ptr, sizes[i], pattern),
                       "size-class object is misaligned or overlaps");
        }
    }

    TEST_CHECK(test_verify_all(), "size-class object contents were corrupted");

    /* Free in reverse allocation order to exercise the partial list. */
    while (test_object_count > 0) {
        test_object_count--;
        slub_free(test_objects[test_object_count].ptr);
    }
    return 1;
}

/* More objects than one slab holds, forcing several slabs and reuse. */
static int
test_many_objects(void) {
    void *objects[TEST_MANY_OBJECTS];
    size_t i;

    for (i = 0; i < TEST_MANY_OBJECTS; i++) {
        uint64_t *word;

        objects[i] = slub_alloc(32);
        TEST_CHECK(objects[i] != NULL, "multi-slab allocation returned NULL");
        word = (uint64_t *)objects[i];
        *word = 0x534C554200000000UL + i;
    }
    for (i = 0; i < TEST_MANY_OBJECTS; i++) {
        TEST_CHECK(*(uint64_t *)objects[i] == 0x534C554200000000UL + i,
                   "multi-slab object was corrupted");
    }

    /* Half of the objects go back to their partial slabs. */
    for (i = 0; i < TEST_MANY_OBJECTS; i += 2) {
        slub_free(objects[i]);
    }

    /* Allocate from another cache; the freed slots must be reusable later. */
    for (i = 0; i < TEST_MANY_OBJECTS; i += 2) {
        objects[i] = slub_alloc(64);
        TEST_CHECK(objects[i] != NULL,
                   "allocation after partial-free returned NULL");
        *(uint64_t *)objects[i] = 0x534C554300000000UL + i;
    }

    for (i = 0; i < TEST_MANY_OBJECTS; i++) {
        if (i % 2 == 0) {
            TEST_CHECK(*(uint64_t *)objects[i] ==
                           0x534C554300000000UL + i,
                       "reused object was corrupted");
        } else {
            TEST_CHECK(*(uint64_t *)objects[i] ==
                           0x534C554200000000UL + i,
                       "surviving object was corrupted");
        }
    }

    for (i = 0; i < TEST_MANY_OBJECTS; i++) {
        slub_free(objects[i]);
    }
    return 1;
}

/* Above SLUB_MAX_CACHE_SIZE the page layer serves the request directly. */
static int
test_large_objects(void) {
    static const size_t sizes[] = {
        SLUB_MAX_CACHE_SIZE + 1,
        PGSIZE,
        PGSIZE + 1,
        2 * PGSIZE,
        3 * PGSIZE,
        10000,
        16 * PGSIZE,
    };
    const size_t nr_sizes = sizeof(sizes) / sizeof(sizes[0]);
    size_t i;

    for (i = 0; i < nr_sizes; i++) {
        unsigned char *ptr = (unsigned char *)slub_alloc(sizes[i]);
        size_t j;

        TEST_CHECK(ptr != NULL, "large allocation returned NULL");
        TEST_CHECK(((uintptr_t)ptr % PGSIZE) == 0,
                   "large allocation is not page aligned");
        for (j = 0; j < sizes[i]; j++) {
            ptr[j] = (unsigned char)(0x80 + i);
        }
        for (j = 0; j < sizes[i]; j++) {
            TEST_CHECK(ptr[j] == (unsigned char)(0x80 + i),
                       "large allocation was corrupted");
        }
        slub_free(ptr);
    }
    return 1;
}

/* After all objects are freed and shrink is called, every page is back. */
static int
test_accounting(size_t baseline) {
    slub_shrink();
    return nr_free_pages() == baseline;
}

int
slub_self_test(void) {
    size_t baseline;

    slub_init();
    slub_shrink();
    baseline = nr_free_pages();
    cprintf("[SLUB Test] start, free pages = %lu\n",
            (unsigned long)baseline);

    TEST_CHECK(test_page_layer(), "layer 1: page alloc/free");
    cprintf("[SLUB Test] layer 1 (page allocator): PASS\n");

    TEST_CHECK(test_size_classes(), "layer 2: size classes");
    cprintf("[SLUB Test] cache state before shrink "
            "(one empty active slab per used cache):\n");
    slub_dump();
    TEST_CHECK(test_accounting(baseline), "size-class accounting");
    cprintf("[SLUB Test] layer 2 (size classes): PASS\n");

    TEST_CHECK(test_many_objects(), "multi-slab reuse");
    TEST_CHECK(test_accounting(baseline), "multi-slab accounting");
    cprintf("[SLUB Test] multi-slab reuse: PASS\n");

    TEST_CHECK(test_large_objects(), "large allocations");
    TEST_CHECK(test_accounting(baseline), "large-allocation accounting");
    cprintf("[SLUB Test] large allocations: PASS\n");

    TEST_CHECK(slub_alloc(0) == NULL, "zero-size allocation is not NULL");
    TEST_CHECK(slub_alloc((nr_free_pages() + 1) * PGSIZE) == NULL,
               "oversized allocation did not fail");
    TEST_CHECK(test_accounting(baseline), "failed-allocation accounting");

    cprintf("[SLUB Test] PASS\n");
    return 1;
}
