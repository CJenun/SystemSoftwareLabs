#include <slub.h>

#include <assert.h>
#include <list.h>
#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <stdio.h>
#include <string.h>

/* *
 * Simplified SLUB allocator.
 *
 * Design summary
 * --------------
 * Every cache owns slabs of exactly one page.  The first bytes of a slab page
 * hold a struct slub_slab; the rest of the page is an array of equal-sized
 * objects.  Because a slab is exactly one page and page-aligned, the metadata
 * of an object can be found in O(1):
 *
 *     slab = (struct slub_slab *)((uintptr_t)obj & ~(PGSIZE - 1));
 *
 * Free objects are linked through the first machine word of the object itself,
 * so no external free bitmap or array is needed.  A cache keeps:
 *
 *   - one active slab for the allocation fast path;
 *   - a list of partial slabs (some objects in use, at least one free).
 *
 * A full slab needs no list: when one of its objects is freed it is linked into
 * the partial list directly.  A non-active slab that becomes empty is returned
 * to layer 1 immediately.  The active slab is kept (even when empty) for fast
 * reuse until slub_shrink() is called.
 *
 * Two page flag bits are borrowed from struct Page to tell slub_free() what a
 * pointer belongs to.  They are runtime-only flags; the pmm managers only use
 * PG_reserved and PG_property, and both clear flags when a page is freed.
 * */

#define SLUB_NR_CACHES 16

#define PG_slub_slab   8
#define PG_slub_direct 9

#define PageSlubSlab(page)   (((page)->flags >> PG_slub_slab) & 1)
#define PageSlubDirect(page) (((page)->flags >> PG_slub_direct) & 1)

#define SLUB_SLAB_MAGIC 0x534C55424C414231UL /* "SLUBLAB1" */

struct slub_cache;

/* Metadata stored at the beginning of every one-page slab. */
struct slub_slab {
    uint64_t magic;
    struct slub_cache *cache;
    struct Page *page;          /* page descriptor of this slab */
    void *freelist;             /* free objects, linked through object[0] */
    list_entry_t link;          /* partial-slab list linkage */
    unsigned int inuse;         /* number of allocated objects */
    unsigned int total;         /* total number of objects in this slab */
    unsigned int npages;        /* always 1 in this simplified version */
    unsigned int on_partial;    /* is this slab currently on cache->partial? */
};

/* One cache per size class. */
struct slub_cache {
    const char *name;
    size_t object_size;
    size_t object_offset;       /* first object in a slab page */
    size_t objects_per_slab;
    struct slub_slab *active;   /* fast-path slab, may be full or empty */
    list_entry_t partial;       /* slabs with at least one free object */
    size_t nr_partial;
    size_t nr_slabs;
    size_t nr_objects;          /* objects living in all slabs */
    size_t nr_inuse;            /* currently allocated objects */
    size_t nr_alloc;            /* total allocations served */
    size_t nr_free;             /* total frees served */
};

#define le2slab(le, member) to_struct((le), struct slub_slab, member)

/* Size classes; all are multiples of SLUB_MIN_OBJECT_SIZE. */
static const size_t slub_sizes[SLUB_NR_CACHES] = {
    8,    16,   24,   32,   48,   64,   96,   128,
    192,  256,  384,  512,  768,  1024, 1536, 2048,
};

static const char *const slub_names[SLUB_NR_CACHES] = {
    "slub-8",    "slub-16",   "slub-24",   "slub-32",
    "slub-48",   "slub-64",   "slub-96",   "slub-128",
    "slub-192",  "slub-256",  "slub-384",  "slub-512",
    "slub-768",  "slub-1024", "slub-1536", "slub-2048",
};

static struct slub_cache slub_caches[SLUB_NR_CACHES];

/* size -> cache index, for size in [0, SLUB_MAX_CACHE_SIZE]. */
static uint8_t slub_size_index[SLUB_MAX_CACHE_SIZE + 1];

static int slub_ready;

/* ------------------------------------------------------------------ */
/* Layer 1: page-granularity allocation                               */
/* ------------------------------------------------------------------ */

static void *
slub_pages_alloc(size_t npages, struct Page **page_out) {
    struct Page *page;

    if (npages == 0) {
        return NULL;
    }
    page = alloc_pages(npages);
    if (page == NULL) {
        return NULL;
    }
    if (page_out != NULL) {
        *page_out = page;
    }
    /* The kernel maps all physical memory at va_pa_offset. */
    return (void *)(page2pa(page) + va_pa_offset);
}

void *
slub_page_alloc(size_t npages) {
    return slub_pages_alloc(npages, NULL);
}

void
slub_page_free(void *ptr, size_t npages) {
    struct Page *page;

    if (ptr == NULL || npages == 0) {
        return;
    }
    page = pa2page(PADDR(ptr));
    free_pages(page, npages);
}

/* ------------------------------------------------------------------ */
/* Slab management                                                    */
/* ------------------------------------------------------------------ */

/* Create a new one-page slab and build its free-object chain. */
static struct slub_slab *
slub_new_slab(struct slub_cache *cache) {
    struct Page *page = NULL;
    struct slub_slab *slab;
    char *first;
    void *mem;
    size_t i;

    mem = slub_pages_alloc(1, &page);
    if (mem == NULL) {
        return NULL;
    }

    slab = (struct slub_slab *)mem;
    slab->magic = SLUB_SLAB_MAGIC;
    slab->cache = cache;
    slab->page = page;
    slab->freelist = NULL;
    list_init(&slab->link);
    slab->inuse = 0;
    slab->total = (unsigned int)cache->objects_per_slab;
    slab->npages = 1;
    slab->on_partial = 0;

    /* Mark the page so slub_free() can recognize slab objects. */
    page->flags |= (1UL << PG_slub_slab);

    /*
     * Build the freelist in reverse order, so object[0] is the first one
     * handed out by the fast path.
     */
    first = (char *)mem + cache->object_offset;
    for (i = cache->objects_per_slab; i > 0; i--) {
        void *obj = first + (i - 1) * cache->object_size;
        *(void **)obj = slab->freelist;
        slab->freelist = obj;
    }

    cache->nr_slabs++;
    cache->nr_objects += cache->objects_per_slab;
    return slab;
}

/* Return a slab (which must be empty and off every list) to layer 1. */
static void
slub_destroy_slab(struct slub_cache *cache, struct slub_slab *slab) {
    struct Page *page = slab->page;

    assert(slab->inuse == 0);

    cache->nr_slabs--;
    cache->nr_objects -= slab->total;

    slab->magic = 0;
    page->flags &= ~(1UL << PG_slub_slab);
    slub_page_free((void *)slab, slab->npages);
}

/* Get a slab with free objects: first from the partial list, else create one. */
static struct slub_slab *
slub_acquire_slab(struct slub_cache *cache) {
    if (!list_empty(&cache->partial)) {
        list_entry_t *le = list_next(&cache->partial);
        struct slub_slab *slab = le2slab(le, link);

        list_del_init(&slab->link);
        slab->on_partial = 0;
        cache->nr_partial--;
        return slab;
    }
    return slub_new_slab(cache);
}

/* ------------------------------------------------------------------ */
/* Layer 2: object allocation                                         */
/* ------------------------------------------------------------------ */

/* Fast path: one pop from the active slab's in-object freelist. */
static void *
slub_alloc_object(struct slub_cache *cache) {
    struct slub_slab *slab = cache->active;
    void *obj;

    if (slab == NULL || slab->freelist == NULL) {
        slab = slub_acquire_slab(cache);
        if (slab == NULL) {
            return NULL;
        }
        cache->active = slab;
    }

    obj = slab->freelist;
    slab->freelist = *(void **)obj;
    slab->inuse++;
    cache->nr_inuse++;
    cache->nr_alloc++;
    return obj;
}

static void
slub_free_object(void *ptr) {
    struct slub_slab *slab;
    struct slub_cache *cache;
    uintptr_t offset;

    slab = (struct slub_slab *)((uintptr_t)ptr & ~(uintptr_t)(PGSIZE - 1));
    if (slab->magic != SLUB_SLAB_MAGIC) {
        panic("slub_free: %p is not a slab object", ptr);
    }

    cache = slab->cache;
    if (cache < slub_caches || cache >= slub_caches + SLUB_NR_CACHES) {
        panic("slub_free: corrupted slab metadata for %p", ptr);
    }

    /* The pointer must be the start of a valid object in this slab. */
    offset = (uintptr_t)ptr - (uintptr_t)slab;
    if (offset < cache->object_offset ||
        offset >= cache->object_offset +
                      (uintptr_t)slab->total * cache->object_size ||
        (offset - cache->object_offset) % cache->object_size != 0) {
        panic("slub_free: %p does not address an object of %s", ptr,
              cache->name);
    }

    /* Push onto the slab's in-object freelist. */
    *(void **)ptr = slab->freelist;
    slab->freelist = ptr;
    slab->inuse--;
    cache->nr_inuse--;
    cache->nr_free++;

    if (slab == cache->active) {
        /* Fast path: the active slab simply becomes non-full again. */
        return;
    }

    if (slab->inuse == 0) {
        /* Empty non-active slab: give the page back immediately. */
        if (slab->on_partial) {
            list_del_init(&slab->link);
            slab->on_partial = 0;
            cache->nr_partial--;
        }
        slub_destroy_slab(cache, slab);
    } else if (!slab->on_partial) {
        /*
         * The slab was full (full slabs are not kept on any list), or it is
         * already partially free.  Either way it now belongs on the partial
         * list because it has at least one free object.
         */
        list_add(&cache->partial, &slab->link);
        slab->on_partial = 1;
        cache->nr_partial++;
    }
}

/* Requests above SLUB_MAX_CACHE_SIZE go straight to layer 1. */
static void *
slub_alloc_large(size_t size) {
    size_t npages = (size + PGSIZE - 1) / PGSIZE;
    struct Page *page = NULL;
    void *mem;

    mem = slub_pages_alloc(npages, &page);
    if (mem == NULL) {
        return NULL;
    }

    page->flags |= (1UL << PG_slub_direct);
    page->property = (unsigned int)npages; /* only inspected by slub_free() */
    return mem;
}

void
slub_init(void) {
    size_t i;
    size_t class_index;

    if (slub_ready) {
        return;
    }

    for (i = 0; i < SLUB_NR_CACHES; i++) {
        struct slub_cache *cache = &slub_caches[i];

        cache->name = slub_names[i];
        cache->object_size = slub_sizes[i];
        cache->object_offset = ROUNDUP(sizeof(struct slub_slab),
                                       SLUB_MIN_OBJECT_SIZE);
        cache->objects_per_slab =
            (PGSIZE - cache->object_offset) / cache->object_size;
        assert(cache->objects_per_slab > 0);

        cache->active = NULL;
        list_init(&cache->partial);
        cache->nr_partial = 0;
        cache->nr_slabs = 0;
        cache->nr_objects = 0;
        cache->nr_inuse = 0;
        cache->nr_alloc = 0;
        cache->nr_free = 0;
    }

    /* Build the O(1) size-to-cache lookup table. */
    class_index = 0;
    slub_size_index[0] = 0;
    for (i = 1; i <= SLUB_MAX_CACHE_SIZE; i++) {
        while (i > slub_sizes[class_index]) {
            class_index++;
        }
        slub_size_index[i] = (uint8_t)class_index;
    }

    slub_ready = 1;
}

void *
slub_alloc(size_t size) {
    if (!slub_ready) {
        slub_init();
    }
    if (size == 0) {
        return NULL;
    }
    if (size <= SLUB_MAX_CACHE_SIZE) {
        return slub_alloc_object(&slub_caches[slub_size_index[size]]);
    }
    return slub_alloc_large(size);
}

void *
slub_zalloc(size_t size) {
    void *ptr = slub_alloc(size);

    if (ptr != NULL) {
        memset(ptr, 0, size);
    }
    return ptr;
}

void
slub_free(void *ptr) {
    struct Page *page;

    if (ptr == NULL) {
        return;
    }

    page = pa2page(PADDR(ptr));
    if (PageSlubSlab(page)) {
        slub_free_object(ptr);
    } else if (PageSlubDirect(page)) {
        size_t npages = page->property;

        page->flags &= ~(1UL << PG_slub_direct);
        page->property = 0;
        free_pages(page, npages);
    } else {
        panic("slub_free: %p was not allocated by slub", ptr);
    }
}

/* ------------------------------------------------------------------ */
/* Reclaim and introspection                                          */
/* ------------------------------------------------------------------ */

void
slub_shrink(void) {
    size_t i;

    if (!slub_ready) {
        return;
    }

    for (i = 0; i < SLUB_NR_CACHES; i++) {
        struct slub_cache *cache = &slub_caches[i];
        list_entry_t *le;

        /* Drop the empty active slab kept for fast reuse. */
        if (cache->active != NULL && cache->active->inuse == 0) {
            struct slub_slab *slab = cache->active;

            cache->active = NULL;
            slub_destroy_slab(cache, slab);
        }

        /* Defensive: partial slabs should never be empty. */
        le = list_next(&cache->partial);
        while (le != &cache->partial) {
            list_entry_t *next = list_next(le);
            struct slub_slab *slab = le2slab(le, link);

            if (slab->inuse == 0) {
                list_del_init(&slab->link);
                slab->on_partial = 0;
                cache->nr_partial--;
                slub_destroy_slab(cache, slab);
            }
            le = next;
        }
    }
}

size_t
slub_cache_count(void) {
    return SLUB_NR_CACHES;
}

int
slub_get_cache_info(size_t index, struct slub_cache_info *info) {
    struct slub_cache *cache;

    if (!slub_ready || index >= SLUB_NR_CACHES || info == NULL) {
        return 0;
    }

    cache = &slub_caches[index];
    info->object_size = cache->object_size;
    info->objects_per_slab = cache->objects_per_slab;
    info->slabs = cache->nr_slabs;
    info->objects = cache->nr_objects;
    info->in_use = cache->nr_inuse;
    info->allocations = cache->nr_alloc;
    info->frees = cache->nr_free;
    return 1;
}

void
slub_dump(void) {
    size_t i;

    if (!slub_ready) {
        cprintf("SLUB: not initialized\n");
        return;
    }

    cprintf("SLUB: %lu caches, free pages = %lu\n",
            (unsigned long)SLUB_NR_CACHES,
            (unsigned long)nr_free_pages());
    cprintf("  cache       size  objs/slab  slabs  inuse  allocs  frees\n");
    for (i = 0; i < SLUB_NR_CACHES; i++) {
        struct slub_cache *cache = &slub_caches[i];

        cprintf("  %-10s %5lu %9lu %6lu %6lu %7lu %6lu\n",
                cache->name,
                (unsigned long)cache->object_size,
                (unsigned long)cache->objects_per_slab,
                (unsigned long)cache->nr_slabs,
                (unsigned long)cache->nr_inuse,
                (unsigned long)cache->nr_alloc,
                (unsigned long)cache->nr_free);
    }
}
