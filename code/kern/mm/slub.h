#ifndef __KERN_MM_SLUB_H__
#define __KERN_MM_SLUB_H__

#include <defs.h>

/* *
 * A simplified SLUB allocator for uCore lab2.
 *
 * Two layers:
 *
 *   layer 1 (page layer)
 *       slub_page_alloc(n) / slub_page_free(ptr, n)
 *       Allocate/free n physically contiguous pages through the active
 *       pmm_manager.  A returned pointer is a kernel virtual address.
 *
 *   layer 2 (object layer)
 *       slub_alloc(size) / slub_free(ptr) / slub_zalloc(size)
 *       Serve arbitrary sizes.  Sizes up to SLUB_MAX_CACHE_SIZE come from
 *       per-size caches; each cache carves page-sized slabs into fixed-size
 *       objects and keeps the free objects on an in-object free list.
 *       Larger requests are served directly by layer 1.
 *
 * The allocation/free fast path is O(1) (pop/push the head of a free list).
 * The slow path (current slab exhausted) fetches a partial slab or creates a
 * new slab with layer 1.
 * */

#define SLUB_MIN_OBJECT_SIZE 8
#define SLUB_MAX_CACHE_SIZE  2048

/* Snapshot of one cache, filled by slub_get_cache_info(). */
struct slub_cache_info {
    size_t object_size;
    size_t objects_per_slab;
    size_t slabs;
    size_t objects;
    size_t in_use;
    size_t allocations;
    size_t frees;
};

/* Initialize all caches.  It is safe to call this more than once. */
void slub_init(void);

/* Layer 2: arbitrary-size object allocation. */
void *slub_alloc(size_t size);
void *slub_zalloc(size_t size);
void slub_free(void *ptr);

/* Layer 1: page-granularity allocation (n contiguous pages). */
void *slub_page_alloc(size_t npages);
void slub_page_free(void *ptr, size_t npages);

/* Release the empty slabs each cache keeps for fast reuse. */
void slub_shrink(void);

/* Introspection. */
size_t slub_cache_count(void);
int slub_get_cache_info(size_t index, struct slub_cache_info *info);
void slub_dump(void);

/* Boot-time self test.  Returns 1 on success, 0 on failure. */
int slub_self_test(void);

#endif /* !__KERN_MM_SLUB_H__ */
