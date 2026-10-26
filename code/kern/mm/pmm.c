#include <default_pmm.h>
#include <best_fit_pmm.h>
#include <buddy_pmm.h>
#include <defs.h>
#include <error.h>
#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <sbi.h>
#include <stdio.h>
#include <string.h>
#include <riscv.h>
#include <dtb.h>

// virtual address of physical page array
struct Page *pages;
// amount of physical memory (in pages)
size_t npage = 0;
// the kernel image is mapped at VA=KERNBASE and PA=info.base
uint64_t va_pa_offset;
// memory starts at 0x80000000 in RISC-V
// DRAM_BASE defined in riscv.h as 0x80000000
const size_t nbase = DRAM_BASE / PGSIZE;

// virtual address of boot-time page directory
uintptr_t *satp_virtual = NULL;
// physical address of boot-time page directory
uintptr_t satp_physical;

// physical memory management
const struct pmm_manager *pmm_manager;


static void check_alloc_page(void);

// init_pmm_manager - initialize a pmm_manager instance
static void init_pmm_manager(void) {
    // [BUDDY] begin: compile-time selection of the physical memory manager
    //   make                                    -> best_fit_pmm_manager (default)
    //   make clean && make DEFS=-DUSE_BUDDY_PMM -> buddy_pmm_manager
    // NOTE: "make clean" is required when switching DEFS, because make does
    //       not treat CFLAGS/DEFS changes as a reason to rebuild objects.
#ifdef USE_BUDDY_PMM
    pmm_manager = &buddy_pmm_manager;
#else
    pmm_manager = &best_fit_pmm_manager;
#endif
    // [BUDDY] end
    cprintf("memory management: %s\n", pmm_manager->name);
    pmm_manager->init();
}

// init_memmap - call pmm->init_memmap to build Page struct for free memory
static void init_memmap(struct Page *base, size_t n) {
    pmm_manager->init_memmap(base, n);
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
}

//lab2 function1 2513599

/*
 * page_init - build the Page descriptor array and hand the usable physical
 * memory to the current pmm_manager.
 *
 * Memory layout after this function:
 *   [DRAM_BASE, KERNEL_BEGIN_PADDR)      OpenSBI, reserved
 *   [KERNEL_BEGIN_PADDR, end)            kernel image, reserved
 *   [end, pages + nr_pages)              Page descriptors, reserved
 *   [freemem, mem_end)                   free pages, given to init_memmap()
 */
static void page_init(void) {
    extern char end[];

    uint64_t mem_base = get_memory_base();
    uint64_t mem_size = get_memory_size();

    // the DTB must report a non-empty range inside the DRAM
    if (mem_size == 0 || mem_base < DRAM_BASE) {
        panic("page_init: invalid physical memory range from DTB");
    }

    // guard against overflow when computing the end of the range
    uint64_t mem_end = mem_base + mem_size;
    if (mem_end < mem_base) {
        panic("page_init: physical memory range overflows");
    }

    // the kernel maps and manages physical memory only below this bound
    if (mem_end > PHYSICAL_MEMORY_END) {
        mem_end = PHYSICAL_MEMORY_END;
    }

    // only complete pages can be managed; drop the tail shorter than one page
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
    if (mem_end <= mem_base) {
        panic("page_init: no manageable physical memory from DTB");
    }

    // the kernel is linked at KERNBASE, i.e. PHYSICAL_MEMORY_OFFSET above its
    // physical address; PADDR() below depends on this value
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;

    // Page descriptors live right after the kernel image (virtual address end),
    // rounded up so that the array itself starts on a page boundary
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);

    // one descriptor per physical page in [DRAM_BASE, mem_end)
    npage = PPN(mem_end);
    size_t nr_pages = npage - nbase;

    // make sure the descriptor array fits before writing anything into it
    uintptr_t pages_pa = PADDR((uintptr_t)pages);
    uintptr_t pages_end = pages_pa + nr_pages * sizeof(struct Page);
    if (pages_pa < mem_base || pages_end > mem_end) {
        panic("page_init: Page array does not fit in physical memory");
    }

    // reserve every descriptor first: pages must not be allocated before the
    // whole layout is known. This also covers OpenSBI, the kernel image and the
    // descriptor array itself.
    for (size_t i = 0; i < nr_pages; i++) {
        set_page_ref(pages + i, 0);
        SetPageReserved(pages + i);
    }

    // first page that can be handed over: right after the descriptor array,
    // aligned up and converted to a physical address
    uintptr_t freemem = ROUNDUP(pages_end, PGSIZE);

    // no complete free page left, the allocator must not be initialized
    if (freemem >= mem_end) {
        panic("page_init: no free physical memory after kernel and Page array");
    }

    // hand all complete pages in [freemem, mem_end) to the manager; the tail
    // shorter than one page is not included. init_memmap() asserts that the
    // pages are still reserved and clears their flags itself.
    size_t n = (mem_end - freemem) / PGSIZE;
    init_memmap(pa2page(freemem), n);

    cprintf("Physical memory: base = 0x%016lx, size = 0x%016lx (%lu MB)\n",
            mem_base, mem_size, mem_size / (1024 * 1024));
    cprintf("Managed range: [0x%016lx, 0x%016lx), npage = %lu, free pages = %lu\n",
            mem_base, mem_end, npage, n);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
    // We need to alloc/free the physical memory (granularity is 4KB or other size).
    // So a framework of physical memory manager (struct pmm_manager)is defined in pmm.h
    // First we should init a physical memory manager(pmm) based on the framework.
    // Then pmm can alloc/free the physical memory.
    // Now the first_fit/best_fit/worst_fit/buddy_system pmm are available.
    init_pmm_manager();

    // detect physical memory space, reserve already used memory,
    // then use pmm->init_memmap to create free page list
    page_init();

    // use pmm->check to verify the correctness of the alloc/free function in a pmm
    check_alloc_page();

    extern char boot_page_table_sv39[];
    satp_virtual = (pte_t*)boot_page_table_sv39;
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
    cprintf("check_alloc_page() succeeded!\n");
}
