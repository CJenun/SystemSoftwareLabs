***物理内存探测与页描述符初始化:***

[PROMPT]
**任务**：修改文件kern/mm/pmm.c，实现page_init()。该函数负责：在链接符号
end之后建立覆盖全部物理内存的Page描述符数组；把OpenSBI、内核镜像和
描述符数组本身占用的页标记为Reserved；把剩余完整页交给当前pmm_manager。

**操作要求**：你必须在项目中修改实际文件，而不是只展示代码。保留文件中已有
的代码，只在 //lab2 function1 YOUR CODE标记处补全page_init()；如需辅助
函数，请设为static，不要改动其他函数的逻辑。

**输出要求**：直接进行文件操作。所有宏、结构体和函数以工程真实代码为准，
使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的信息；不要修改测试
代码，不要引入无关功能。

[RELY]
// 宏定义（kern/mm/mmu.h、libs/defs.h、libs/riscv.h、kern/mm/memlayout.h）
#define PGSIZE                  4096
#define PGSHIFT                 12
#define PPN(la)                 (((uintptr_t)(la)) >> PGSHIFT)
#define ROUNDUP(a, n) ({                                        \
    size_t __n = (size_t)(n);                                   \
    (typeof(a))(ROUNDDOWN((size_t)(a) + __n - 1, __n)); })
#define DRAM_BASE               0x80000000
#define PHYSICAL_MEMORY_OFFSET  0xFFFFFFFF40000000
#define KERNBASE                0xFFFFFFFFC0200000
#define SetPageReserved(page)   ((page)->flags |= (1UL << PG_reserved))
#define ClearPageReserved(page) ((page)->flags &= ~(1UL << PG_reserved))
#define PageReserved(page)      (((page)->flags >> PG_reserved) & 1)
#define PADDR(kva) ({                                           \
    uintptr_t __m_kva = (uintptr_t)(kva);                       \
    if (__m_kva < KERNBASE)                                     \
        panic("PADDR called with invalid kva %08lx", __m_kva);  \
    __m_kva - va_pa_offset; })

// 数据结构（kern/mm/memlayout.h），PG_reserved = 0，PG_property = 1
struct Page {
    int ref;                  // 引用计数
    uint64_t flags;           // 状态位
    unsigned int property;    // 空闲块页数，First-Fit使用
    list_entry_t page_link;   // 空闲链表节点
};

// 可用函数
uint64_t get_memory_base(void);                  // DTB物理内存起始地址
uint64_t get_memory_size(void);                  // DTB物理内存大小
static void init_memmap(struct Page *base, size_t n);  // 注册空闲区
static inline struct Page *pa2page(uintptr_t pa);      // 物理地址转Page
static inline void set_page_ref(struct Page *page, int val);
void panic(const char *fmt, ...);

// 全局变量
extern struct Page *pages;          // Page描述符数组
extern size_t npage;                // 物理页总数
extern const size_t nbase;          // DRAM_BASE / PGSIZE
extern uint64_t va_pa_offset;       // 内核虚拟地址与物理地址的偏移
extern const struct pmm_manager *pmm_manager;
extern char end[];                  // 内核镜像末尾（虚拟地址）

[GUARANTEE]
必须实现或修改的主要接口：
```c
static void page_init(void);
```

你可以根据需要添加：
- 辅助函数（建议设为static）
- 模块内部使用的宏定义
- 模块内部的静态变量

[SPECIFICATION]
## page_init

**Pre-Condition**:
- dtb_init() 已执行，get_memory_base()/get_memory_size() 返回
  有效的物理内存范围，且memory_size > 0。
- init_pmm_manager() 已执行，pmm_manager已指向具体的分配器。
- 链接符号end指向内核镜像末尾的虚拟地址；pages、npage、
  va_pa_offset尚未建立。
- 物理内存足以容纳覆盖全部内存的Page描述符数组。

**Post-Condition**:
- va_pa_offset等于PHYSICAL_MEMORY_OFFSET。
- pages指向end之后第一个页对齐的地址，描述符数组覆盖
  [DRAM_BASE, mem_base + mem_size) 对应的全部物理页。
- npage等于内存上界mem_base + mem_size对应的页号；nbase等于
  DRAM_BASE / PGSIZE。
- OpenSBI、内核镜像和描述符数组自身占用的页处于Reserved状态，
  引用计数为0。
- 描述符数组之后、内存上界之前的完整页已全部交给pmm_manager，
  nr_free_pages() 大于0；不足一页的尾部被丢弃。
- 空闲区与内核、描述符数组没有重叠。

**Case 1**:
- 触发条件：memory_size == 0，DTB没有给出有效内存。
- 行为：调用panic() 终止初始化；不建立描述符数组，不调用
  init_memmap()。

**Case 2**:
- 触发条件：内存范围有效，且描述符数组末尾之后仍有完整页
  （freemem < mem_end）。
- 行为：按Post-Condition建立描述符，保留已用页，把
  [freemem, mem_end) 内的完整页交给init_memmap()。

**Case 3**:
- 触发条件：内存范围有效，但描述符数组末尾已经到达或越过内存上界
  （freemem >= mem_end）。
- 行为：调用panic()；不得用0或其他非法页数调用init_memmap()。

**Requirements**:
- 不得提前清除空闲页的Reserved位：default_init_memmap() 会断言
  入参页仍为Reserved，并由它负责清除。
- 只登记完整页，尾部不足PGSIZE的部分不能进入空闲区。
- 不修改tools/test_lab2.c等测试代码，不新增全局变量；新增辅助
  函数必须为static。
- 严格区分虚拟地址（如end）、物理地址（如freemem、mem_end）和
  物理页号（如npage）。
- 函数名以骨架代码为准：是init_memmap，不是旧版指导书里的
  init_memmapp。


  ***物理内存分配功能-任务二:***

  [PROMPT]

任务：
参考 `kern/mm/default_pmm.c` 中的完整First-Fit实现，在 `kern/mm/best_fit_pmm.c` 标有 `lab2` 和 `YOUR CODE` 的位置，实现完整的Best-Fit连续物理内存管理模块。

根据 `kern/mm/pmm.h` 中 `struct pmm_manager` 的成员职责，设计模块内部状态，实现相关管理函数，定义 `best_fit_pmm_manager` 完成注册。同时修改 `kern/mm/pmm.c` 中的 `init_pmm_manager()`，将当前物理内存管理器切换为 `best_fit_pmm_manager`。

操作要求：

1. 必须修改项目中的实际文件，不要仅输出代码片段。
2. 保留已有代码，在标记位置补充模块实现，并完成必要的管理器切换。
3. 不得修改 `basic_check()` 和 `best_fit_check()`，不得绕过测试中的断言。
4. 不修改First-Fit实现、公共数据结构及公共接口，不引入其他实验任务的功能。
5. 保留实验标记。新增辅助函数和内部状态应限制在本模块中。
6. 算法的时空复杂度不做要求，以功能正确、兼容现有测试为目标。

输出要求：
使用以下 `[RELY]`、`[GUARANTEE]`、`[SPECIFICATION]` 提供的信息，以工程真实代码为准完成修改。完成后简要说明修改内容。仅编写代码，不执行编译、启动 QEMU 或运行测试的命令，验证由我们手动完成。

[RELY]

首先阅读以下文件：

- `kern/mm/default_pmm.c`
- `kern/mm/best_fit_pmm.c`
- `kern/mm/best_fit_pmm.h`
- `kern/mm/pmm.h`
- `kern/mm/memlayout.h`
- `kern/mm/pmm.c`
- `libs/list.h`

工程中的相关数据结构为：

```c
struct Page {
    int ref;
    uint64_t flags;
    unsigned int property;
    list_entry_t page_link;
};

typedef struct {
    list_entry_t free_list;
    unsigned int nr_free;
} free_area_t;
```

相关状态含义：

- `ref`：页面引用计数。
- `flags`：页面状态标志。
- `property`：在空闲块首页记录该块包含的连续页面数量。
- `page_link`：将空闲块首页连接到空闲链表。
- `nr_free`：空闲页面总数，不是空闲块数量。

可以使用工程现有的链表操作，以及 `PageReserved`、`PageProperty`、`SetPageProperty`、`ClearPageProperty`、`set_page_ref`、`le2page` 等接口，具体定义以源码为准。

必须兼容以下测试约定：

1. 测试直接访问并修改 `free_list` 和 `nr_free`，因此必须提供这两个名称对应的可读写状态。可以参考 First-Fit，使用静态 `free_area_t` 配合宏定义。
2. 测试会保存、清空并恢复空闲链表和页面计数。模块不能依赖无法随这些操作正确恢复的额外管理状态。
3. 测试存在空闲链表已清空、但 `nr_free` 尚未清零的时刻。此时分配必须返回 `NULL`。
4. 测试要求分配得到的页面引用计数为 0，且分配块首页不具有 `Property` 标志。
5. 测试可能一次释放此前分别分配、但在物理地址上连续的多个页面，不能强制一次释放必须对应一次分配。

物理内存初始化属于前置任务。本次不修改或补写 `page_init()`；如果发现该前置功能尚未完成，只需在修改说明中指出。

[GUARANTEE]

在 `best_fit_pmm.c` 中实现：

```c
static void best_fit_init(void);

static void best_fit_init_memmap(struct Page *base, size_t n);

static struct Page *best_fit_alloc_pages(size_t n);

static void best_fit_free_pages(struct Page *base, size_t n);

static size_t best_fit_nr_free_pages(void);
```

定义与头文件声明一致的注册结构：

```c
const struct pmm_manager best_fit_pmm_manager;
```

该结构必须设置以下成员：

- `name`：设为 `"best_fit_pmm_manager"`。
- `init`：对应模块初始化函数。
- `init_memmap`：对应空闲区登记函数。
- `alloc_pages`：对应 Best-Fit 分配函数。
- `free_pages`：对应页面释放函数。
- `nr_free_pages`：对应空闲页计数查询函数。
- `check`：使用现有 `best_fit_check()`。

允许为现有测试函数补充必要的前向声明，但不得修改其定义和函数体。

修改 `pmm.c` 中的：

```c
static void init_pmm_manager(void);
```

使其选择Best-Fit管理器，保留原有名称输出及初始化调用。

允许新增 `static` 辅助函数、内部宏和静态变量，不改变公共接口。

[SPECIFICATION]

1. best_fit_init()

Pre-Condition：
在登记可用物理页面之前调用。

Post-Condition：
空闲链表初始化为空，空闲页面总数为 0，管理器能够接收后续空闲区登记。

2. best_fit_init_memmap(base, n)

Pre-Condition：
`n > 0`。`base` 指向一段连续可用物理内存首页的 `Page` 描述符，该范围包含 `n` 个页面，尚未登记为空闲区域，并符合框架的初始保留状态约定。

Post-Condition：
清理这些页面的管理状态，将引用计数设为0，解除其保留状态。使用空闲块首页记录连续页面数量，并设置有效的 `Property` 标志。将该区域纳入空闲链表，保持按起始地址递增排列，`nr_free` 增加 `n`，不得重复登记页面。

3. best_fit_alloc_pages(n)

Pre-Condition：
`n > 0`，管理器已初始化。

Post-Condition：
成功时，返回所分配连续物理页的首页描述符指针，实际分配恰好 `n` 页，`nr_free` 减少 `n`。分配块首页不再具有 `Property` 标志，页面引用计数保持为0。剩余空闲块的大小、标志及链表关系保持有效。

Case 1：
存在满足请求的空闲块时，选择其中页数最少的块，而不是遇到第一个足够大的块就停止。多个候选块大小相同时，选择起始地址最低的块。

Case 2：
选中块大小恰好为 `n` 时，整块分配，该块不再出现在空闲链表中。

Case 3：
选中块大小大于 `n` 时，从块的起始位置分配前 `n` 页，将剩余页面作为有效空闲块保留。

Case 4：
空闲链表为空、空闲页总数不足，或不存在足够大的连续空闲块时，返回 `NULL`，不得改变已有空闲块及空闲页计数。

4. best_fit_free_pages(base, n)

Pre-Condition：
`n > 0`。待释放的页面范围有效且连续，页面均已分配，不属于保留页，也不与现有空闲区域重叠。

Post-Condition：
清理待释放页面的状态，将引用计数设为0，使这些页面重新纳入空闲管理，`nr_free` 增加 `n`。空闲链表保持按起始地址递增排列，并合并物理地址连续的相邻空闲块。

Case 1：
与前后空闲块均不连续时，作为独立空闲块保留。

Case 2：
仅与前一个空闲块连续时，合并至前一个块，合并后的首页为前一个块的首页。

Case 3：
仅与后一个空闲块连续时，将后一个块合并进本次释放块。

Case 4：
与前后两个空闲块均连续时，合并为一个完整空闲块。

Requirements：
合并后仅保留一个有效的空闲块首页节点，正确维护其 `property` 和 `Property` 标志。合并不改变空闲页总数，不能重复增加 `nr_free`。无需清零物理页面中的数据。

5. best_fit_nr_free_pages()

Pre-Condition：
管理器已初始化。

Post-Condition：
返回当前空闲页面总数，不修改内部状态。正常管理状态下，返回值应等于空闲链表中所有空闲块的页数之和。

6. best_fit_pmm_manager

Requirements：
注册结构具有外部链接，与 `best_fit_pmm.h` 中的声明一致。所有函数指针类型正确，`check` 指向未经修改的 `best_fit_check()`。妥善处理声明顺序，避免引用尚未声明的函数。

7. init_pmm_manager()

Pre-Condition：
Best-Fit注册结构已定义，并可通过现有头文件访问。

Post-Condition：
`pmm_manager` 指向 `best_fit_pmm_manager`，原有管理器名称输出及初始化调用保持有效。后续通过公共页面管理接口进行的分配、释放和检查均使用Best-Fit模块。

***物理内存分配功能-任务三:***

[PROMPT]
任务：新建 kern/mm/buddy_pmm.c、kern/mm/buddy_pmm.h，并修改 kern/mm/pmm.c，实现 Buddy 物理内存分配模块。Buddy System算法把系统中的可用存储空间划分为存储块(Block)来进行管理, 每个存储块的大小必须是2的n次幂(Pow(2, n)), 即1, 2, 4, 8, 16, 32, 64, 128...。最后在 pmm.c 中用 USE_BUDDY_PMM 宏选择（默认仍用 best_fit）。

操作要求：直接修改实际文件，保留原有代码；不要改 default_pmm.c、best_fit_pmm.c、page_init()、Makefile、tools/。kern/mm 下的新文件会被自动编译。pmm.c 改动处用 [BUDDY] 注释标注。

输出要求：直接进行文件操作。头文件用 __KERN_MM_BUDDY_PMM_H__ 保护；回调与辅助函数设为 static；pmm.c 的 include 加在 <best_fit_pmm.h> 后，选择逻辑写进 init_pmm_manager()。

[RELY]

- `struct Page`：`ref`（引用计数）、`flags`（状态位）、`property`（记录空闲块的档位）、`page_link`（链表结点）。
- 状态位宏：`PG_reserved`（保留页，不可分配）、`PG_property`（该页是空闲块的第一页）；宏 `SetPageReserved`/`ClearPageReserved`/`PageReserved`/`SetPageProperty`/`ClearPageProperty`/`PageProperty`。
- 链表函数：`list_init`、`list_add`、`list_del`、`list_del_init`、`list_empty`、`list_next`、`list_prev`、`le2page`。
- 全局变量：`pages`（页描述符数组）、`npage`（内存末端页号）、`nbase`（起始页号，2^19 的倍数）；可用 `page2pa`、`pa2page`、`set_page_ref`、`page_ref`。
- QEMU 下可管理页数为 `npage - nbase = 32768 = 2^15`。
- 管理器接口：
  ```c
  struct pmm_manager {
      const char *name;
      void (*init)(void);
      void (*init_memmap)(struct Page *base, size_t n);
      struct Page *(*alloc_pages)(size_t n);
      void (*free_pages)(struct Page *base, size_t n);
      size_t (*nr_free_pages)(void);
      void (*check)(void);
  };
调用顺序：init → page_init → init_memmap(base, n)（这 n 页都带 PG_reserved）→ check。
错误处理可用 assert / panic。

[GUARANTEE]

必须实现：

extern const struct pmm_manager buddy_pmm_manager;
static void buddy_init(void);
static void buddy_init_memmap(struct Page *base, size_t n);
static struct Page *buddy_alloc_pages(size_t n);
static void buddy_free_pages(struct Page *base, size_t n);
static size_t buddy_nr_free_pages(void);
static void buddy_check(void);
允许新增（必须是 static）：

static unsigned int buddy_order_of(size_t n);
static size_t buddy_total_pages(void);
static void buddy_insert(struct Page *block, unsigned int order);
static void buddy_free_range(struct Page *base, size_t n);
宏 BUDDY_MAX_ORDER（值为 15）、BUDDY_NR_ORDERS（值为 16）
静态变量：空闲链表数组、全局空闲页计数
pmm.c 只加两处：包含 buddy_pmm.h；在 init_pmm_manager() 中按宏选择管理器，默认仍为 best_fit_pmm_manager。


[SPECIFICATION]

基本规则
一个空闲块由连续 2^order 页组成，首页按 2^order 页对齐，并设置 PG_property、property = order；块内其余页标志清零。
buddy_nr_free 记录所有空闲页总数，每档链表里块的大小之和应与之相等。
所有块都必须在 pages 数组范围内，不能动 PageReserved 的页。
buddy_init
清空 16 条链表和 buddy_nr_free；不访问 pages/npage。

buddy_order_of / buddy_total_pages
buddy_order_of(n) 返回能容纳 n 页的最小等级，n 太大时返回 BUDDY_MAX_ORDER + 1。buddy_total_pages() 返回 npage - nbase。只用移位运算。

buddy_insert(block, order)
先把 buddy_nr_free 增加 2^order 页。然后检查相邻伙伴块：位置为 index ^ (1 << order)，若存在、在范围内、PG_property 已置且等级相同，就从链表摘下并合并，低地址作为合并后的首页，等级加一，继续向上合并。最后把首页放入对应链表。

buddy_free_range(base, n)
把任意连续区间拆成若干"起点对齐、大小不超过剩余页数"的 2 的幂块；每块清零后调用 buddy_insert；所有块合计正好 n 页。

buddy_init_memmap
检查 n > 0，对每页确认是 PageReserved，清零 flags/property/ref，再调用 buddy_free_range。不要重复累加 buddy_nr_free。

buddy_alloc_pages
n > 0；算出所需等级，等级超限或总空闲页不够则返回 NULL；从该等级向上找第一个非空链表，取首页；若块比需要的大，就不断对半拆开，把上半部分放回低一档链表；最后清零首页并让 buddy_nr_free 减少 2^order。返回地址按块大小对齐，页数可能多于请求的 n。

buddy_free_pages
n > 0；算出等级，确认地址在范围内且都不是 PageReserved；清零请求的 n 页。若起点按块大小对齐且整块不越界，就整块调用 buddy_insert（按 2^order 页归还）；否则调用 buddy_free_range 只归还 n 页。这样分配多少、释放多少能对上。

buddy_nr_free_pages
返回 buddy_nr_free。

buddy_check
先遍历 16 条链表，检查首页标志、等级、对齐和范围，并确认总页数等于 buddy_nr_free。空闲页不少于 16 时做可恢复的分配/释放测试：

分配 16 页，确认非空、对齐，空闲页减 16；
按 1、1、2、4、8 页依次释放，确认空闲页恢复；
分配 3 页（实际占 4 页），释放后再次恢复；
申请比全部空闲页还多的内存，必须返回 NULL；
再检查一遍链表。 只用 assert，结束时状态不变。


***Challenge：任意大小的内存单元 slub 分配算法***

[PROMPT]
**任务**：修改文件 `kern/mm/slub.h`、`kern/mm/slub.c`、`kern/mm/slub_test.c`、`kern/init/init.c`，在 uCore lab2（RISC-V、Sv39）中实现一个简化 `slub` 内存分配模块。模块必须采用两层架构：

- **第一层（页层）**：提供以页为单位的连续物理页分配与释放，封装现有的 `pmm_manager`，不重新实现页分配算法。
- **第二层（对象层）**：在第一层之上提供任意大小对象分配。使用 16 个大小类（8、16、24、32、48、64、96、128、192、256、384、512、768、1024、1536、2048 字节）；每个 slab 固定为一页；页首存放 slab 元数据，剩余空间切分为等长对象；空闲对象的前 8 字节直接串成 freelist；每个 cache 维护一个 active slab 和一个 partial slab 链表，full slab 不进入链表；大于 2048 字节的请求直接走页层并按页数记录。分配/释放快路径必须为 O(1)。
- 提供启动期自检，覆盖页层、所有大小类、跨 slab 复用、大块分配、错误请求和页账目恢复。
- 在 `kern/init/init.c` 中加入接入代码，但**必须全部保持注释状态**，默认启动行为不变。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。完成模块的完整实现，包括但不限于：头文件接口、函数主体、辅助函数、模块内部静态变量、自检代码和 `init.c` 中的注释接入。保留文件中现有代码；新增代码应插入到正确位置。不要修改 `kern/mm/pmm.c`、`kern/mm/best_fit_pmm.c`、`kern/mm/buddy_pmm.c`、`tools/` 下的评分文件和 `Makefile`。代码必须能在现有编译选项（`-std=gnu99 -Wall -Werror -fno-builtin -nostdinc` 等）下编译通过，不得引入警告。不得使用标准 C 库或动态内存，只能使用项目提供的 `libs/` 与 `kern/` 接口。

**输出要求**：直接进行文件操作。保留现有代码，将新接口放入 `kern/mm/slub.h`，实现放入 `kern/mm/slub.c`，自检放入 `kern/mm/slub_test.c`，并在 `kern/init/init.c` 中添加注释形式的接入点。公开接口不得使用 `static`；内部辅助函数应使用 `static`，只在本模块内部使用，不得改变公开接口。代码中应有简短注释说明两层架构、slab 布局以及对象/页标记的含义。

[RELY]

**基础类型与宏**
- `PGSIZE = 4096`，`PGSHIFT = 12`；`ROUNDUP` / `ROUNDDOWN` 定义于 `libs/defs.h`。
- `size_t` 为 64 位无符号整数；`bool` 是 `int` 的 typedef，项目未定义 `true` / `false`，如需布尔返回值请使用 `0` / `1`。
- `list_entry_t`、`list_init`、`list_add`、`list_add_before`、`list_del_init`、`list_empty`、`list_next`、`list_prev` 定义于 `libs/list.h`。`list_add(listelm, elm)` 表示把 `elm` 插到 `listelm` 之后；没有 `list_first`，首元素用 `list_next(&head)` 获取。
- `to_struct(ptr, type, member)` 和 `offsetof` 可用于由链表节点反推外层结构体；`le2page(le, page_link)` 是现成的 Page 版本。

**页描述符与地址转换**
```c
struct Page {
    int ref;
    uint64_t flags;
    unsigned int property;
    list_entry_t page_link;
};
```
- 已使用标志位：`PG_reserved = 0`、`PG_property = 1`，对应 `SetPageReserved` / `ClearPageReserved` / `PageReserved` / `SetPageProperty` / `ClearPageProperty` / `PageProperty`。
- `flags` 的其余位当前未被 PMM 使用，可临时借用，但页归还 PMM 前必须清理。
- 分配成功返回的页，其 `PG_property` 位必须保持 0；`property` 字段可以在对象层内部临时使用，但不能设置 `PG_property` 位，否则 PMM 释放时会触发断言。
- 全局变量：`struct Page *pages`、`size_t npage`、`const size_t nbase`、`uint64_t va_pa_offset`。
- `page2pa(struct Page *)` 返回物理地址；`pa2page(uintptr_t)` 返回页描述符；`PADDR(kva)` 把内核虚地址转为物理地址（要求地址不低于 `KERNBASE`）。
- 内核将所有物理内存映射到 `va_pa_offset` 偏移处，因此“页的内核虚拟地址”可由 `page2pa(page) + va_pa_offset` 得到。

**可调用的页分配接口**
```c
struct Page *alloc_pages(size_t n);
void free_pages(struct Page *base, size_t n);
size_t nr_free_pages(void);
```
- `alloc_pages(n)` 返回 `n` 个连续物理页的起始页描述符，失败返回 `NULL`。
- 调用 `free_pages(base, n)` 时必须使用与 `alloc_pages` 相同的 `n`；best_fit 释放恰好 `n` 页，buddy 会按 `n` 对应的 2 的幂阶数处理。
- 默认 PMM 为 `best_fit_pmm_manager`，也可通过 `DEFS=-DUSE_BUDDY_PMM` 切换为 `buddy_pmm_manager`；本模块必须对两者都正确工作，且不得修改 PMM 源码。
- 页分配器只在 `pmm_init()` 完成后可用；`pmm_init()` 会建立 `pages`、`npage`、`va_pa_offset` 并初始化空闲页。

**其他可用设施**
- `cprintf`、`panic`、`assert`、`memset` 可直接使用。
- `Makefile` 会自动收集 `kern/mm/*.c` 并把 `kern/mm` 加入 include path，因此新增 `.c` / `.h` 不需要修改 `Makefile`。

[GUARANTEE]

必须在 `kern/mm/slub.h` 中声明、并在 `kern/mm/slub.c` 中实现以下接口，签名必须完全一致：

```c
#define SLUB_MIN_OBJECT_SIZE 8
#define SLUB_MAX_CACHE_SIZE  2048

struct slub_cache_info {
    size_t object_size;
    size_t objects_per_slab;
    size_t slabs;
    size_t objects;
    size_t in_use;
    size_t allocations;
    size_t frees;
};

void  slub_init(void);
void *slub_alloc(size_t size);
void *slub_zalloc(size_t size);
void  slub_free(void *ptr);

void *slub_page_alloc(size_t npages);
void  slub_page_free(void *ptr, size_t npages);

void  slub_shrink(void);

size_t slub_cache_count(void);
int    slub_get_cache_info(size_t index, struct slub_cache_info *info);
void   slub_dump(void);

int    slub_self_test(void);
```

必须在 `kern/mm/slub_test.c` 中实现 `slub_self_test(void)`。该文件会由 Makefile 自动编译；即使未被调用，也不能引入链接错误或编译警告。

必须在 `kern/init/init.c` 中出现以下接入代码，且**全部处于注释状态**：

```c
// #include <slub.h>
```

```c
    pmm_init();  // init physical memory management

    // SLUB demo/self-test: uncomment the include and these calls to enable.
    // slub_init();
    // slub_self_test();
```

允许新增辅助函数，但它们必须是 `static`，只在本模块内部使用，不得改变公开接口。建议的职责划分如下（名称可调整，但职责必须覆盖）：

```c
static void *slub_pages_alloc(size_t npages, struct Page **page_out);
static struct slub_slab *slub_new_slab(struct slub_cache *cache);
static void slub_destroy_slab(struct slub_cache *cache, struct slub_slab *slab);
static struct slub_slab *slub_acquire_slab(struct slub_cache *cache);
static void *slub_alloc_object(struct slub_cache *cache);
static void slub_free_object(void *ptr);
static void *slub_alloc_large(size_t size);
```

允许新增模块内部宏定义和静态变量，例如 slab 魔数、页标记位、cache 数组、大小类表、`size -> cache` 索引表、模块初始化标志等。不得新增会污染全局命名空间的非 `static` 符号。

[SPECIFICATION]

## slub_init
Pre-Condition：可在 `pmm_init()` 之后调用；调用前模块可以尚未初始化；允许重复调用。
Post-Condition：16 个大小类 cache 全部完成初始化；每个 cache 的对象大小、每 slab 对象数、active 指针、partial 链表头和统计字段有效；`size -> cache` 的 O(1) 查找表建立完毕；模块标记为 ready。初始化过程不得申请物理页，slab 必须按需创建。若模块已经 ready，则保持现有 cache、slab 和统计数据不变。
Case 1：首次调用。初始化所有 cache、大小类表和索引表，置 ready。
Case 2：重复调用。直接返回，不得重复初始化、不得丢失已有 slab 或统计信息。
Requirements：页首元数据大小必须向上按 `SLUB_MIN_OBJECT_SIZE` 对齐；必须保证每个大小类的 `objects_per_slab >= 1`；初始化不依赖任何已分配对象。

## slub_page_alloc
Pre-Condition：PMM 已初始化；`npages > 0`。
Post-Condition：成功时返回页对齐的内核虚拟地址，对应 `npages` 个连续物理页，且这些页已从 PMM 空闲链表中移除；失败返回 `NULL`，PMM 状态不变。返回的页不应带任何对象层标记。
Case 1：`npages == 0` 或 `alloc_pages` 返回 `NULL`。返回 `NULL`。
Case 2：分配成功。返回 `page2pa(page) + va_pa_offset` 形式的页对齐地址。
Requirements：必须通过当前 `pmm_manager` 的 `alloc_pages` 分配；不得直接操作 `pages` 数组或另建页管理器；调用方必须使用相同的 `npages` 调用 `slub_page_free` 释放。

## slub_page_free
Pre-Condition：`ptr` 是 `slub_page_alloc` 返回的页起始地址；`npages` 与申请时一致。
Post-Condition：对应连续页归还 PMM，页描述符恢复为 PMM 可接受的状态。
Case 1：`ptr == NULL` 或 `npages == 0`。防御性直接返回。
Case 2：参数有效。把 `ptr` 转成物理地址并找到起始页描述符，调用 `free_pages(page, npages)`。
Requirements：只接受页起始指针，不接受块内部指针；释放页数必须与申请时一致；不负责清理对象层标记，调用者应在归还前完成。

## slub_alloc
Pre-Condition：单 CPU、无并发；`size` 可为 0；模块未初始化时应能隐式完成初始化。
Post-Condition：成功时返回至少 `size` 字节、按 8 字节对齐、与所有存活分配互不重叠的对象；失败返回 `NULL`。cache 的 active/partial 状态、统计计数和页账目与结果一致。
Case 1：`size == 0`。返回 `NULL`。
Case 2：`1 <= size <= SLUB_MAX_CACHE_SIZE`。通过 O(1) 索引选择大小类；若 active slab 存在且 freelist 非空，直接弹出第一个空闲对象（快路径）；否则从 partial 链表取一个 slab；若 partial 为空，则创建新的一页 slab；如果页层分配失败，返回 `NULL`，且不得破坏已有 cache 状态。
Case 3：`size > SLUB_MAX_CACHE_SIZE`。按 `ceil(size / PGSIZE)` 计算页数，直接调用页层分配；成功后在页描述符中记录“大块分配”标记和页数，保证后续 `slub_free` 能识别并归还；失败返回 `NULL`。
Case 4：空闲内存不足。返回 `NULL`，不改变 freelist、slab 计数和页账目。
Requirements：快路径 O(1)；返回对象不要求清零；不得移动或复制已分配对象；不得修改现有 PMM 管理器；大块分配必须能由统一的 `slub_free` 释放。

## slub_zalloc
Pre-Condition：同 `slub_alloc`。
Post-Condition：成功时返回至少 `size` 字节全为 0 的对象；失败返回 `NULL`。
Case 1：`size == 0`。返回 `NULL`。
Case 2：`slub_alloc` 成功。将请求的 `size` 字节清零后返回。
Case 3：`slub_alloc` 失败。返回 `NULL`，不写内存。
Requirements：只保证请求的 `size` 字节为 0，类内填充字节不要求清零。

## slub_free
Pre-Condition：`ptr` 为 `NULL`、`slub_alloc` 返回的对象指针，或大块分配返回的页起始指针；不得重复释放；不得是块内部指针。
Post-Condition：对象回到所属 slab 的 freelist，或大块页归还页层；slab 的 active/partial/full 状态与 cache 统计一致；页账目正确。
Case 1：`ptr == NULL`。直接返回。
Case 2：`ptr` 是 slab 对象。校验页标记、slab 魔数、所属 cache 范围和对象对齐；把对象压入所属 slab 的 freelist；如果该 slab 是 active，则保持 active 并直接返回；如果该 slab 不是 active 且 `inuse` 变为 0，必要时从 partial 链表移除并把整页归还页层；如果该 slab 不是 active 但仍在使用，确保它位于 partial 链表上。
Case 3：`ptr` 是大块分配。从页描述符中取出分配时记录的页数，清除大块标记，归还页层。
Case 4：指针不属于本分配器或元数据损坏。调用 `panic`，不得继续破坏内存。
Requirements：正常释放路径 O(1)；释放后不得再读取已归还页的元数据；不要求实现双重释放检测；只接受分配时返回的精确指针。

## slub_shrink
Pre-Condition：模块已初始化；cache 中可能存在空 active slab 或空 partial slab。
Post-Condition：所有空 slab 归还页层；仍含有已分配对象的 slab 不受影响；cache 的 slab 计数和对象计数更新正确。
Case 1：active slab 存在且 `inuse == 0`。回收该 slab，并把 active 置空。
Case 2：partial 链表中存在 `inuse == 0` 的 slab（防御性情况）。从链表移除并回收。
Case 3：slab 仍有对象在使用。保留不动。
Requirements：幂等；不得回收非空 slab；自检结束时可用它把所有空闲页恢复到基线。

## slub_cache_count
Pre-Condition：无。
Post-Condition：返回大小类数量 16。
Requirements：返回值必须与 `slub_get_cache_info` 接受的合法索引范围一致。

## slub_get_cache_info
Pre-Condition：`info` 非空；`index` 位于 `[0, slub_cache_count())`；模块已初始化。
Post-Condition：把指定 cache 的快照写入 `info` 并返回 1。`objects` 表示该 cache 所有 slab 提供的对象槽总数，`in_use` 表示当前已分配对象数，`allocations` / `frees` 为累计计数。
Case 1：参数有效且模块已初始化。填充结构体并返回 1。
Case 2：`info == NULL`、索引越界或模块未初始化。返回 0，不修改内存。
Requirements：只读快照，不得影响分配器状态。

## slub_dump
Pre-Condition：建议模块已初始化。
Post-Condition：使用 `cprintf` 输出 16 个 cache 的名称、对象大小、每 slab 对象数、slab 数、正在使用对象数、累计分配次数、累计释放次数，以及当前空闲页数。不改变任何状态。
Case 1：模块未初始化。输出简短提示后返回。
Case 2：模块已初始化。输出统计表。
Requirements：仅用于调试，不得调用分配器或改变页账目；格式必须能被现有 `cprintf` 正确解析。

## slub_self_test
Pre-Condition：`pmm_init()` 与 `slub_init()` 已完成；处于启动阶段，没有并发分配；只使用公开 API 和 `nr_free_pages()`。
Post-Condition：全部检查通过时返回 1，并在第一个失败项处返回 0；所有测试对象都已释放，空 slab 已经过 `slub_shrink()` 回收，`nr_free_pages()` 恢复到测试开始前的基线；输出明确的 PASS/FAIL 信息。
Case 1：页层测试。分别申请 1 页和 3 页，检查返回非空、页对齐、互不重叠、内容可读写、释放后页账目恢复。
Case 2：大小类测试。对 1 到 2048 字节之间的代表性大小（至少覆盖每个大小类的边界）各分配 4 个对象，检查非空、8 字节对齐、互不重叠、内容正确；释放后调用 shrink 并检查页账目恢复。
Case 3：跨 slab 复用测试。分配 600 个 32 字节对象以强制使用多个一页 slab，验证内容；释放一半；再从另一个大小类分配 300 个对象；验证新旧对象内容均未损坏；释放全部对象。
Case 4：大块分配测试。覆盖 2049、4096、4097、8192、12288、10000、65536 字节等大小，检查返回非空、页对齐、内容可读写、释放后页账目恢复。
Case 5：错误请求测试。`slub_alloc(0)` 必须返回 `NULL`；申请页数超过当前全部空闲页时必须返回 `NULL`，且不得泄漏页。
Case 6：最终账目测试。调用 `slub_shrink()` 后 `nr_free_pages()` 必须等于基线。
Requirements：必须同时适用于 `best_fit_pmm_manager` 和 `buddy_pmm_manager`；失败时只打印失败信息并返回 0，不得使用 `assert` 导致内核 panic；成功时至少输出以下阶段信息：
`[SLUB Test] layer 1 (page allocator): PASS`、
`[SLUB Test] layer 2 (size classes): PASS`、
`[SLUB Test] multi-slab reuse: PASS`、
`[SLUB Test] large allocations: PASS`、
`[SLUB Test] PASS`。
不得留下未释放的对象或空 slab。

## kern/init/init.c 的接入修改
Pre-Condition：保留原有 `kern_init` 启动流程。
Post-Condition：文件中出现 `// #include <slub.h>`，并在 `pmm_init()` 之后出现注释形式的 `// slub_init();` 和 `// slub_self_test();`。默认编译和启动行为与修改前一致。
Case 1：保持注释。内核正常启动，不输出 SLUB 自检信息。
Case 2：取消注释。`slub_init()` 被调用，随后运行 `slub_self_test()`。
Requirements：不得修改 `kern_init` 的其他逻辑；不得在注释外新增 SLUB 调用；不得修改 `pmm.c` 或评分脚本。
