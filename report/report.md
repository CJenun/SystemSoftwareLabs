# lab2

# 实验报告

## 实验基本信息

|项目|内容|
|---|---|
|**实验名称**|Lab 2: 物理内存和页表|
|**小组成员**|2511098\-陈俊锡、2510942\-华星源、2513599\-胡健飞|
|**完成日期**|2026\-10\-23|

### 小组分工

练习如何分工？

|成员|负责的练习/模块|
|---|---|
|2511098\-陈俊锡|物理内存分配功能模块任务一；物理内存分配功能模块任务二；分支任务\-gdb调试页表查询过程|
|2510942\-华星源|物理内存分配功能模块任务三；Challenge：任意大小的内存单元 slub 分配算法|
|2513599\-胡健飞|物理内存初始化功能模块；Challenge：硬件的可用物理内存范围的获取方法|

实验报告如何分工？

|成员|负责的实验报告部分|
|---|---|
|2511098\-陈俊锡|实验基本信息；实验目的；实验环境；实验整体逻辑分析；物理内存分配功能模块任务一、任务二；分支任务\-gdb调试页表查询过程；实验总结与收获|
|2510942\-华星源|物理内存分配功能模块任务三；Challenge：任意大小的内存单元 slub 分配算法|
|2513599\-胡健飞|物理内存初始化功能模块；Challenge：硬件的可用物理内存范围的获取方法|

---

## 一、实验目的

本实验的主要目的是：

1. 理解页表的建立和使用方法，掌握大页和TLB的作用

2. 理解物理内存的管理方法，学习内存初始化过程

3. 理解页面分配算法，认识不同分配算法的特点

4. 掌握提示词的写法，增强与大模型的协作能力

---

## 二、实验环境

你们使用的 AI 工具

|成员|AI 编程工具|底层模型|备注|
|---|---|---|---|
|2511098\-陈俊锡|Codex（VS Code插件）|GPT\-6\.1\-sol|无|
|2513599\-胡健飞|Claude Code（VS Code插件）|DeepSeek\-V4\-Pro<br>|无|
|2510942\-华星源|Claude Code（Vs Code插件）|Deepseek\-V4\-Pro|无|

**说明：**

- **AI 编程工具**：指具体使用的终端工具、编辑器插件、桌面应用或浏览器界面

- **底层模型**：指该工具使用的大语言模型及版本

---

## 三、实验整体逻辑分析

### 2\.1 本章节的逻辑主线

本章围绕物理内存管理与页表地址映射展开，整个实验要解决的核心问题是：内核启动后，如何知道系统中有哪些物理内存，其中哪些区域可以使用，以及怎样按需分配这些内存。

### 2\.2 功能的逐步实现

1. 首先完成**物理内存初始化**。从设备树获取内存范围，建立Page描述符，再将可用页面注册到物理内存管理器。因为需要先知道可以分配的页面，这样后续的内存分配才可以进行。

2. 接着分析**First\-Fit连续物理内存分配算法**。需要先读取框架的数据结构和接口，之后才可以实现其他分配算法。

3. 然后实现**Best\-Fit分配算法**。在First\-Fit的基础上，将分配策略改为寻找满足请求的最小空闲块。这样可以比较两种算法的区别，加深对页的理解。

4. 随后实现**Buddy System分配算法**。按照大小为二的幂的块分配内存，进行块的拆分与合并。这可以理解另一种内存分配方式，为后续SLUB对象分配提供基础知识。

5. 随后实现**SLUB内存对象分配**。由分配器提供页，在页内管理不同大小的对象。通过已有的页面分配功能，可以进一步理解从页管理到对象管理的知识。

6. 最后进行**整体运行验证**。检查运行结果，并利用GDB跟踪页表查询过程和QEMU中的TLB。将这一环节放在最后，有助于结合前面对物理页和地址的认识，理解分页机制，验证结果是否符合预期。

---

## 四、实验内容与实现

### 功能模块：物理内存探测与页描述符初始化

**负责人****：2513599 胡健飞**

#### 模块功能描述

**需要实现/修改的函数：**

```C
static void page_init(void);
/* interfaces this module calls */
uint64_t get_memory_base(void);
uint64_t get_memory_size(void);
static void init_memmap(struct Page *base, size_t n);
static inline struct Page *pa2page(uintptr_t pa);
#define PADDR(kva)     
#define ROUNDUP(a, n)   
#define SetPageReserved(page)   
```

**功能说明：**

• 在系统中的作用：page\_init\(\)是pmm\_init\(\)的第二步，负责把设备树探测到的物理内存转换成内核可管理的数据结构，即一个覆盖全部物理页的struct Page描述符数组，以及交给当前pmm\_manager的初始空闲页区间。

- 上游：kern/driver/dtb\.c的dtb\_init\(\) 解析DTB，保存memory\_base / memory\_size，本模块通过 get\_memory\_base\(\)/get\_memory\_size\(\) 读取；

- 下游：init\_memmap\(\)把空闲区交给pmm\_manager，alloc\_pages\(\) / free\_pages\(\) 之后都依赖这里建立好的描述符；

- 启动代码：entry\.S 建立 Sv39 启动页表并把内核映射到KERNBASE，本模块设置的va\_pa\_offset= PHYSICAL\_MEMORY\_OFFSET是 PADDR\(\)正确工作的前提。

- 测试：官方 tools/test\_lab2\.c的test\_page\_init\(\)在 pmm\_init\(\)末尾检查va\_pa\_offset、npage、pages对齐、内核尾页和描述符页的Reserved状态以及空闲页数量。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````text
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
````

#### 实现迭代过程

本模块的实现经历了1次迭代，过程如下：

---

##### 第一次迭代

**遇到的问题：**

- 问题：**QEMU运行时内核panic。**

- 错误信息：kernel panic at kern/mm/default\_pmm\.c:22: assertion failed: PageReserved\(p\)

- 原因分析：第二版在调用init\_memmap\(\)之前先把空闲页的Reserved位清掉了；但default\_init\_memmap\(\)的入口断言要求传入的页仍处于Reserved状态，函数内部会自己清flags并设置PG\_property。

- **问题解决策略：**

- 针对问题1：在提示词中补充“先阅读default\_pmm\.c中default\_init\_memmap\(\)的前置条件和断言”，写出“不要提前ClearPageReserved，只把连续空闲区间交给init\_memmap\(\)”。删除page\_init中的清除循环后重新编译运行，panic消失。

**最终结果：**

经过1次迭代，该模块最终：

- ✅ 编译通过

- ✅ 所有相关测试通过

- ✅ 功能符合预期

---

### Challenge：物理内存范围获取方法

**负责人****：2513599 胡健飞**

本实验中OS能提前知道可用物理内存范围，是因为OpenSBI在跳转前把DTB的物理地址放在a1寄存器，entry\.S保存到boot\_dtb，dtb\_init\(\)解析/memory节点得到memory\_base和memory\_size。如果OS无法提前获得这条信息，可以从三类途径获取：

1. 由固件和引导协议提供内存描述

• x86：BIOS int 0x15, EAX=E820返回E820内存图；UEFI使用GetMemoryMap\(\)；Multiboot也直接提供memory map。

• RISC\-V：标准机制就是DTB，SBI本身不提供内存布局。

• 虚拟机：QEMU可以通过fw\_cfg提供etc/e820、etc/ram\_size等条目。

2. 主动探测

• 从体系结构约定的DRAM起点开始，按页或按块写入特征值再读回，能原样读回则认为是RAM。

• 用二分法确定上界，越界访问会触发异常或总线错误，据此收缩可用范围。

• 前提是异常处理已经建立，探测必须避开已知MMIO区域，写操作可能有副作用，因此应优先只读探测或选择可安全读写的地址。

3. 平台约定与配置

• SoC内存控制器寄存器、bootloader命令行、虚拟机配置都可以直接给出内存起始地址和大小。

• 本实验的QEMU virt机器DRAM固定从0x80000000开始、默认128MB，可作为判断探测结果是否合理的依据。

---

### 功能模块：物理内存分配功能\-任务一、任务二

**负责人：** 2511098\-陈俊锡

#### First\-Fit分配器如何初始化空闲页、分配连续物理页、回收页面并合并相邻空闲块？

初始化空闲页：

分配器通过default\_init函数和default\_init\_memmap函数来实现空闲页的初始化。deault\_init函数首先通过调用list\_init\(\&free\_list\)创建一个空链表，并将用来记录空闲页数总数的nr\_free设为零；之后default\_init\_memmap函数接收一段连续可分配页面首页的Page地址和这段页面的数量，它首先遍历从选页Page地址base开始的n个Page，检查页原先牌保留状态，再将记录页面状态的falgs和表示连续页数量的propert置为零，调用set\_page\_ref函数将引用记数清零；然后将首页的property赋值为n，用来记录这一组页的数量，并将首页标记为空闲块的起点；接下来将页总数nr\_free在原有基础上加n；最后把首页的Page中的page\_link插入free\_list以将整个块接入管理，并保持链表按地址从低到高排列。

分配连续物理页：

分配器通过default\_alloc\_pages函数来实现分配连续物理页。它首先通过assert函数检查申数页数必须大于零，否则申请失败；然后将n与空闲页总数nr\_free比较，若总数不足也会分配失败；随后遍历整个链表，一但发现有空闲块的页数大于或等于需要分配的页数就会将该块首页的Page保存，并停止查找；最后通过if \(page \!= NULL\)判断是否找到了符合条件的块，如果找到了，则会进行分配：先将该空闲块从链表中移除，如果该块页数大于申请页数则需要进行拆分，将拆分出来的块的首页的property设为剩余的页数，组成新的块插入原块在链表中的位置，并将nr\_free减去分配出的页数；如果该块页数等于所需页数则不需要拆分，最后通过ClearPageProperty\(page\)清除已分配块首页的property标志，返回首页的page，如果分配失败则会返回NULL。

回收页面并合并相邻空页块：

分配器通过default\_free\_pages函数来实现回收页面并合并相邻空闲块。它首先遍历这些页面的Page，确认它们不是保留页，没有空闲页首页的Property标识，确认完成后将Page中的所有状态标志清零，通过set\_page\_ref\(p, 0\)将引用记数置零；接下来将首页的property设为这组页面的数量，并设置Property标志，将nr\_free加上n以增加空闲页总数；接下来它会将这一组页面按顺序插入链表，并保持空闲块按地址从低到高排列；随后检查前一个空闲块的下一页是否为本次释放块的首页，如果满足条件，它会将两块的页数相加赋给前一个块首页的property，将当前块首页的Property和链表节点清除，再让base指向合并后的首页；最后检查当前块结束后的下一页是不是后一个空闲块的首页，如果符合条件，会将两块的页数相加赋给当前块首页的property，清除后一块首页的Property标志，将后一页节的链表节点移除。

#### 原有的first fit算法是否有进一步的改进空间？

当前的first fit算法第次分配都从空闲链表头开始查找，最坏情况下需要遍历所有空闲块，时间复杂度为O\(n\)，我们可以把链表改为搜索树，树中的每个节点存放一个空闲块的起始地址，以每个空闲块的起始地址作为排序依据：让每个节点左侧子树中的块的地址都比它低，右侧子树中的块的地址都比它高，以保证检索顺序仍然是从低往高检索；另外对于每个非叶子节点都记录其子树最大空闲块大小，这样如果需要分配的页数大于该节点的子树最大空闲块大小，就无需检查其中的节点。通过建立搜索树能将查找最坏情况下的时间复杂度降到O\(logn\)，可以减少查找开销，提高搜索的效率。

#### 模块功能描述

**需要实现/修改的函数：**

```C
需要实现的函数
static void best_fit_init(void);
static void best_fit_init_memmap(struct Page *base, size_t n);
static struct Page *best_fit_alloc_pages(size_t n);
static void best_fit_free_pages(struct Page *base, size_t n);
static size_t best_fit_nr_free_pages(void);
需要修改的函数
static void init_pmm_manager(void);
```

**功能说明：**

Best\-Fit模块负责管理可用物理页面，为内核提供连续物理页的分配和回收功能。分配时，从满足请求的空闲块中选择最小的一块，以减少本次分配后剩余的空间。

模块需要完成空闲页面登记、页面分配和页面释放。分配时，若选中块大小恰好满足请求，则整块分配；若选中块大小大于请求分配的大小，则将其拆分并保留剩余部分；如果没有足够大的连续空闲块则返回NULL。释放时，会更新空闲页总数，同时检查该块是否与前后空闲块在物理地址上连续，如果连续则将其合并为一个块。

物理内存初始化模块通过init\_memmap\(\)将可用页交给本模块管理。本模块将管理函数注册到best\_fit\_pmm\_manager中，内核可以通过alloc\_pages\(\)、free\_pages\(\)和nr\_free\_pages\(\)来调用。内核初始化物理内存后调用best\_fit\_check\(\)检查Best\-Fit是否正常工作。

**Best\-Fit算法改进空间：**

当找到大小恰好等于请求页数的空闲块时，可以立即结束查找，不再进行后继查找，因为不可能再找到更合适的块，可以提高查找效率。另外，我们可以使用按空闲块大小构建的平衡搜索树，通过对搜索树进行遍历来寻找最合适的块，可以减少消耗的时间，提高搜索效率。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````text
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
````

#### 实现迭代过程

本模块的实现经历了1次迭代，过程如下：

---

##### 第一次迭代

**最终结果：**

经过1次迭代，该模块最终：

- ✅ 编译通过

- ✅ 所有相关测试通过

- ✅ 功能符合预期

---

### 功能模块：物理内存分配功能\-任务三

**负责人：****2510942\-华星源**

#### 模块功能描述

**需要实现/修改的函数：**

```C
static void buddy_init(void)；
static void buddy_insert(struct Page *block, unsigned int order)；
static void buddy_free_range(struct Page *base, size_t n)；
static void buddy_init_memmap(struct Page *base, size_t n)；
static struct Page *buddy_alloc_pages(size_t n)；
static void buddy_free_pages(struct Page *base, size_t n)；
static size_t buddy_nr_free_pages(void)；
static void buddy_check(void)；
```

**功能说明：**

## 1\. 在系统中的作用

它是 ucore 物理内存管理的具体实现之一，实现 `struct pmm_manager` 的 6 个回调，接管 `page_init()` 交出的全部空闲物理页。上层只通过 `alloc_pages/free_pages/nr_free_pages` 访问它，因此可与 `default_pmm`、`best_fit_pmm` 互换。核心职责是把物理页按 2 的幂（1～2^15 页）分块、按阶维护空闲链表，并保证分配不重叠、释放可回收、页数账目准确。

## 2\. 需要处理的主要场景

- **初始化**：接收的区间起点和长度不一定是 2 的幂，需要拆成若干对齐的 2 次幂块挂入对应阶链表；校验并清除 `PageReserved`。

- **分配**：请求页数向上取整到块大小；从最小可用阶找块，不足时逐级二分，把多余半块放回低阶；内存不足或碎片导致无合适块时返回 `NULL`。

- **释放**：整块归还并与同阶伙伴块反复合并；对非对齐的异常请求退化为按对齐块拆分归还。

- **记账与自检**：维护全局空闲页数，保证等于各阶链表块大小之和；提供 `check()` 校验链表结构、对齐、范围，并做可恢复的分配/释放测试。

- **安全边界**：绝不分配 OpenSBI、内核镜像、`Page` 描述符数组等保留页；不越出 `pages` 数组范围。

## 3\. 与其他模块的交互

- **`pmm.c`**：调用 `init()`、`init_memmap()`、`check()`，并通过函数指针转发 `alloc/free/nr_free`；用 `USE_BUDDY_PMM` 宏在本模块与 `best_fit_pmm` 之间选择。

- **`page_init()`**** / ****`dtb`**：`page_init()` 解析 DTB、建立 `pages` 数组并把空闲区交给 `init_memmap()`；`init()` 执行时 `pages` 尚未建立，因此不能访问它。

- **`memlayout.h`**** / ****`list.h`**：复用 `struct Page` 的 `property` 存阶号、`PG_property` 标记块首页，用 `page_link` 挂入空闲链表。

- **调用方**：后续内核功能通过 `alloc_pages/free_pages` 使用物理页，不感知 Buddy 内部结构。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````text
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
````

#### 实现迭代过程

本模块的实现经历了 1 次迭代，过程如下：

---

**最终结果：**

经过 1 次迭代，该模块最终：

- ✅ 编译通过

- ✅ 所有相关测试通过

- ✅ 功能符合预期

### Challenge：任意大小的内存单元 slub 分配算法

**负责人：** 2510942\-华星源

#### 模块功能描述

**需要实现/修改的函数：**

```C++
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

//内部辅助函数
static void *slub_pages_alloc(size_t npages, struct Page **page_out);

static struct slub_slab *slub_new_slab(struct slub_cache *cache);
static void              slub_destroy_slab(struct slub_cache *cache,
                                           struct slub_slab *slab);
static struct slub_slab *slub_acquire_slab(struct slub_cache *cache);

static void *slub_alloc_object(struct slub_cache *cache);
static void  slub_free_object(void *ptr);

static void *slub_alloc_large(size_t size);
```

**功能说明：**

## 模块功能简述

### 1\. 在整个系统中的作用

`slub` 是运行在物理页管理器（PMM）之上的内核对象分配器，位于“物理页分配”和“内核上层代码”之间。PMM 只能按页（4 KiB）分配内存，若直接用页分配来满足几十字节的小对象需求，会造成严重内部碎片。`slub` 通过两层架构解决这个问题：

- **第一层（页层）**：向 `pmm_manager` 申请/归还连续物理页；

- **第二层（对象层）**：把一页切分成多个等长对象，用 O\(1\) 的空闲链表管理小对象，并以“大小类 \+ slab”的方式复用内存。

因此，它让内核可以像 `malloc/free` 一样按任意大小申请内存，同时尽量保持较高的空间利用率和分配效率。

### 2\. 需要处理的主要场景

- **小对象频繁分配/释放**：8～2048 字节按 16 个大小类处理，相同大小的对象直接从 slab 的 freelist 弹出或压回，快路径为 O\(1\)。

- **同一大小类的高频复用**：每个 cache 保留 active slab 和 partial 链表，优先复用有空闲对象的 slab。

- **跨 slab 分配**：当前 slab 用满时，从 partial 链表取下一个 slab；没有可用 slab 时再向页层申请新页。

- **大块分配**：超过 2048 字节的请求直接按页分配，避免为偶尔的大请求维护复杂的 cache。

- **内存回收**：非 active 的空 slab 立即归还页层；`slub_shrink()` 统一回收各 cache 保留的空 active slab。

- **异常与边界情况**：`size == 0`、物理内存不足、非法释放指针、重复初始化等。

- **统计与自检**：提供 `slub_get_cache_info()`、`slub_dump()` 和启动期 `slub_self_test()`，用于观察 cache 状态并验证分配/释放/页账目是否正确。

### 3\. 与其他模块的交互关系

- **与 PMM 模块**：通过 `alloc_pages()`、`free_pages()`、`nr_free_pages()` 交互；兼容默认的 `best_fit_pmm_manager` 和可选的 `buddy_pmm_manager`，不修改 PMM 源码。

- **与 ****`struct Page`**：把页描述符的 `flags` 中未被 PMM 使用的位临时用作 SLUB 页标记，用 `property` 临时记录大块分配的页数；页归还前清理这些信息。

- **与 ****`list.h`**：使用双向链表维护每个 cache 的 partial slab 集合。

- **与启动流程**：在 `pmm_init()` 之后调用 `slub_init()`；`kern/init/init.c` 中已预留注释形式的接入点，取消注释后可在启动时运行自检。

- **与上层内核代码**：上层只需包含 `slub.h`，调用 `slub_alloc()` / `slub_zalloc()` / `slub_free()`，不需要关心 slab、freelist 或页层细节。

- **与测试/评分模块**：新增文件由 Makefile 自动编译；启动自检位于独立的 `slub_test.c`，不修改原有的 `test_lab2.c` 或评分注入逻辑。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````text
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
````

#### 实现迭代过程

本模块的实现经历了 1 次迭代，过程如下：

---

**最终结果：**

经过 1 次迭代，该模块最终：

- ✅ 编译通过

- ✅ 所有相关测试通过

- ✅ 功能符合预期

---

## 五、测试与验证

**测试截图：**

执行make qemu后，运行状态如下，可以看到内核正常启动，且成功切换到Best\-Fit，输出check\_alloc\_page\(\) succeeded\!表示通过内核中的注册检查，结果符合预期。

![屏幕截图 2026\-10\-24 184348\.png](images/屏幕截图%202026-10-24%20184348.png)

### 分支任务：GDB 调试页表查询过程

**负责人：** 2511098\-陈俊锡

在终端一中执行cd lab2; make debug来启动QEMU，并通过\-S使CPU暂停。终端二执行pgrep \-af qemu\-system\-riscv64获取进程号和启动命令

![屏幕截图 2026\-10\-24 211531\.png](images/屏幕截图%202026-10-24%20211531.png)

接下来在终端二sudo gdb \-p 14039连接QEMU，出现\(gdb\)后输入

```Plain Text
set pagination off
handle SIGPIPE nostop noprint
```

第一条指令用来关闭输出分页；第二条指令避免调试被SIGPIPE信号打断。然后输入break riscv\_cpu\_tlb\_fill if address \>= 0xffffffffc0200000 \&\& access\_type == MMU\_DATA\_STORE使内核向高地址内存写入数据，并在需要QEMU填充TLB时，让QEMU暂停。riscv\_cpu\_tlb\_fill\(\)是处理 TLB 填充的函数，后面会从这里进入页表查询。接下来然后检查断点：info breakpoints

![屏幕截图 2026\-10\-24 212114\.png](images/屏幕截图%202026-10-24%20212114.png)

可见断点设置正确，Enb已经启用。

先在终端二输入continue以恢复QEMU程序，同时保证CPU仍暂停，等待调试；在终端三执行cd lab2;make gdb来启动RISCV GDB，连接QEMU中的CPU，连接后在终端三输入

```Plain Text
set pagination off
x/i $pc
```

这会显示CPU接下来要执行的指令；然后在终端三输入

```Plain Text
tbreak *kern_init
continue
```

tbreak设置一个临时断点，之后CPU会执行启动代码和OpenSBI，并在kern\_init\(\)的第一条指令前暂停，执行后终端一中结果如下

![屏幕截图 2026\-10\-24 212746\.png](images/屏幕截图%202026-10-24%20212746.png)

可见运行被顺利暂停，之后输入x/12i $pc来显示接下来的12条命令。

![屏幕截图 2026\-10\-24 213116\.png](images/屏幕截图%202026-10-24%20213116.png)

我们从输出中选择这条指令

```Plain Text
0xffffffffc02000ee: sd ra,8(sp)
```

它用来把ra中的返回地址写入sp\+8指向的内存，保存到栈中。

接下来在终端三中输入

```Plain Text
tbreak *0xffffffffc02000ee
continue
```

停下后输入

```Plain Text
x/i $pc
info registers sp ra
p/x $sp + 8
```

用来确认当前指令、要写入的数据和写入的虚拟地址

![屏幕截图 2026\-10\-24 213403\.png](images/屏幕截图%202026-10-24%20213403.png)

由图可见，写入的数据：ra中的0x80000a02，目标虚拟地址：0xffffffffc0204ff8，写入大小：8字节

接下来执行si，让QEMU进行处理，执行后终端二中出现：

![image\.png](images/image%201.png)

成功命中之前设置的断点，接下来在终端二中输入

```Plain Text
p/x address  //将地址显示为十六进制
bt           //显示调用栈
```

调用栈如下：

![image\.png](images/image%204.png)

![image\.png](images/image%203.png)

接下来在终端二中输入

```Plain Text
set $va = address
tbreak get_physical_address
continue
```

保存本次虚拟地址并让程序停在地址转换函数的入口，停下后输入：

```Plain Text
p/x addr
p/x env->satp
p env->priv
```

用来确认要转换的地址，以及CPU采用什么分页模式，接下来输入

```Plain Text
until 187
list 183,200
p vm
p/x base
```

让程序执行到选择分页模式的switch语句附近，接下来会进入Sv39分支

levels = 3：最多查询三级页表。

ptidxbits = 9：每级使用 9 位索引，可选择 512 项。

ptesize = 8：每个页表项占 8 字节。

输入next，程序会在191行停止，再输入一次next，执行完该行的赋值，之后执行p levels;p ptidxbits;p ptesize。通过until 237;list 231,242;p ptshift检查地址是否合法并计算ptshift = \(levels \- 1\) \* ptidxbits。接下来输入

```Plain Text
next
next
next
next
p i
p/x idx
```

先用next进入循环，第二次执行idx的计算。当前正准备执行pte\_addr = base \+ idx \* ptesize;在输入next后再输入p/x pte\_addr找到页表项的位置，当前的PMP检查用于判断是否允许访问页表项所在的物理内存。检查通过后，QEMU会执行target\_ulong pte = ldq\_phys\(cs\-\>as, pte\_addr\);从客户机物理地址pte\_addr读取 8 字节，保存到pte。接下来在终端二中输入list 244,260;next直到target\_ulong ppn = pte \>\> PTE\_PPN\_SHIFT; 再输入p/x pte，得到$15 = 0x200000cf，页表项包含物理页号和状态标志现两部分，这一页号的R W X不全是零，因此它是一个叶子项，是映射的1GiB大页，接下来再输入next直到if \(\!\(pte \& PTE\_V\)\) \{，再查看p/x ppn，得到0x80000，说明物理页号已经成功提取。

之后的if \(\!\(pte \& PTE\_V\)\)检查页表项是否无效。本次V=1，不会进入失败分支，else if \(\!\(pte \& \(PTE\_R \| PTE\_W \| PTE\_X\)\)\)检查是否指向下一级页表，本次R W X都为1，所以也不会进入此分支，不会继续查下一级页表。在终端二先通过list 256,294，通过next直到if \(updated\_pte \!= pte\) \{，再查看p/x updated\_pte；p/x pte，两个值都是0x200000cf，继续next直到执行完\*physical =后输入

```Plain Text
p/x *physical
p/x (addr & 0xfff)
p/x (*physical | (addr & 0xfff))
```

![image\.png](images/image%202.png)

说明虚拟地址是0xffffffffc0204ff8，物理地址是0x80204ff8，地址转换符合预期。

之后执行

```Plain Text
finish               //执行完当前的地址转换函数并返回
tbreak tlb_set_page
continue             //运行到TLB登记函数
info args            //查看准备登记的映射
```

**为什么判断TLB未命中？**

在终端二中执行

```Plain Text
bt
frame 3
list 1513,1528
p/x addr
p/x tlb_addr
p/x (addr & 0xfffffffffffff000)
```

分别查看当时从 TLB 项中取出的地址标记和本次访问的虚拟页基址。得到：

```C
(gdb) bt
#0  tlb_set_page (cpu=0x643ab39670e0, vaddr=18446744072637923328, paddr=2149597184, 
    prot=7, mmu_idx=1, size=4096) at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cputlb.c:847
#1  0x0000643aa6f4a393 in riscv_cpu_tlb_fill (cs=0x643ab39670e0, 
    address=18446744072637927416, size=8, access_type=MMU_DATA_STORE, mmu_idx=1, 
    probe=false, retaddr=136125196796229)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/target/riscv/cpu_helper.c:472
#2  0x0000643aa6e8f6b8 in tlb_fill (cpu=0x643ab39670e0, addr=18446744072637927416, 
    size=8, access_type=MMU_DATA_STORE, mmu_idx=1, retaddr=136125196796229)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cputlb.c:878
#3  0x0000643aa6e95bdd in store_helper (env=0x643ab396faf0, addr=18446744072637927416, 
    val=2147486210, oi=49, retaddr=136125196796229, size=8, big_endian=false)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cputlb.c:1522
#4  helper_le_stq_mmu (env=0x643ab396faf0, addr=18446744072637927416, val=2147486210, 
    oi=49, retaddr=136125196796229)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cputlb.c:1672
#5  0x00007bce1e000145 in code_gen_buffer ()
#6  0x0000643aa6eb42b0 in cpu_tb_exec (cpu=0x643ab39670e0, 
    itb=0x7bce1e000040 <code_gen_buffer+19>)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cpu-exec.c:173
#7  0x0000643aa6eb50e7 in cpu_loop_exec_tb (cpu=0x643ab39670e0, 
    tb=0x7bce1e000040 <code_gen_buffer+19>, last_tb=0x7bce1dffe958, 
    tb_exit=0x7bce1dffe950) at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cpu-exec.c:621
#8  0x0000643aa6eb5410 in cpu_exec (cpu=0x643ab39670e0)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cpu-exec.c:732
#9  0x0000643aa6e678f4 in tcg_cpu_exec (cpu=0x643ab39670e0)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/cpus.c:1435
#10 0x0000643aa6e681ab in qemu_tcg_cpu_thread_fn (arg=0x643ab39670e0)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/cpus.c:1743
#11 0x0000643aa72f74f4 in qemu_thread_start (args=0x643ab397d6b0)
    at util/qemu-thread-posix.c:502
#12 0x00007bce24ca3dfa in start_thread (arg=<optimized out>)
    at ./nptl/pthread_create.c:454
#13 0x00007bce24d375cc in __GI___clone3 ()
    at ../sysdeps/unix/sysv/linux/x86_64/clone3.S:78
(gdb) frame 3
#3  0x0000643aa6e95bdd in store_helper (env=0x643ab396faf0, addr=18446744072637927416, 
    val=2147486210, oi=49, retaddr=136125196796229, size=8, big_endian=false)
    at /mnt/d/WSL/RISCV/qemu-4.1.1/accel/tcg/cputlb.c:1522
1522                tlb_fill(env_cpu(env), addr, size, MMU_DATA_STORE,
(gdb) list 1513,1528
1513        if (addr & ((1 << a_bits) - 1)) {
1514            cpu_unaligned_access(env_cpu(env), addr, MMU_DATA_STORE,
1515                                 mmu_idx, retaddr);
1516        }
1517
1518        /* If the TLB entry is for a different page, reload and try again.  */
1519        if (!tlb_hit(tlb_addr, addr)) {
1520            if (!victim_tlb_hit(env, mmu_idx, index, tlb_off,
1521                addr & TARGET_PAGE_MASK)) {
1522                tlb_fill(env_cpu(env), addr, size, MMU_DATA_STORE,
1523                         mmu_idx, retaddr);
1524                index = tlb_index(env, mmu_idx, addr);
1525                entry = tlb_entry(env, mmu_idx, addr);
1526            }
1527            tlb_addr = tlb_addr_write(entry) & ~TLB_INVALID_MASK;
1528        }
(gdb) p/x addr
$28 = 0xffffffffc0204ff8
(gdb) p/x tlb_addr
$29 = 0xffffffffffffffff
(gdb) p/x (addr & 0xfffffffffffff000)
$30 = 0xffffffffc0204000
(gdb) 
```

结果说明TLB 中的地址标记为0xffffffffffffffff本次访问的虚拟页是0xffffffffc0204000两者不匹配，因此第 1519 行的条件成立：

```Plain Text
if (!tlb_hit(tlb_addr, addr))
```

随后又没有命中victim TLB，所以执行到了第 1522 行tlb\_fill\(\)。

**分页开启前的对比：**

在终端二执行以下代码

```Plain Text
set pagination off
handle SIGPIPE nostop noprint
break riscv_cpu_tlb_fill if address == 0x1000 && access_type == MMU_INST_FETCH
continue
```

这里暂停原来的写访问断点，改为观察内核物理入口 0x80200000 的取指。再在终端三中输入continue

再在终端二中执行

```Plain Text
bt 5
tbreak get_physical_address
continue
p/x addr
p/x env->satp
p env->priv
until 172
next
p/x addr
p/x *physical
finish
tbreak tlb_set_page
continue
info args
```

观察到

![image\.png](images/image.png)

与之前的结果进行对比可知QEMU 的软件TLB不完全等同于真实CPU的分页TLB，真实CPU的分页TLB主要缓存虚拟地址到物理地址的转换QEMU还需要把客户机的内存访问落实到宿主机内存，因此，即使客户机当前不进行分页转换，也会使用软件TLB加速访问。

**调试过程中的细节及收获：**

两个 GDB 的执行状态存在联系。我们在 RISC\-V GDB 中单步执行内核的存储指令后，本机 GDB 命中了 QEMU 中的断点，此时 RISC\-V GDB 会等待。通过这一现象，我们理解了 ucore 的执行依赖 QEMU：当模拟器被暂停时，其中的虚拟 CPU 也无法继续执行。

调试器显示的源码行不代表该语句已经执行。计算页表索引时，我们提前打印了尚未赋值的 idx，得到了异常数值。执行完赋值语句后，结果才变为正确的 0x1ff。另外，退出 store\_helper\(\) 后，其局部变量无法再通过当前上下文直接查看。这使我们认识到，分析变量值必须结合程序的执行位置。

没有进行分页转换，也可能使用 QEMU 的软件 TLB。启动初期，CPU 处于 M 模式，satp=0，地址转换函数直接得到 `0x1000→0x1000`，随后仍调用了 tlb\_set\_page\(\)。这说明 QEMU 的软件 TLB 还承担了加速模拟内存访问的作用，不能将它完全等同于真实 CPU 的分页 TLB。

**大模型解决的问题和交互过程：**

区分两种 GDB。开始调试时，执行 sudo gdb 提示找不到命令，但实验一中曾正常使用过 GDB。我向 AI 提供报错，并说明此前的使用情况。经过分析，明确了实验一通过 make gdb 调用的是 RISC\-V GDB，而本次还需要本机 GDB 调试 QEMU。随后成功使用本机 GDB 附加到了 QEMU 进程。

理解实际地址转换过程。刚开始时，我能够执行命令，但不清楚每一步的目的。因此，我要求 AI 先解释操作含义，再根据每轮输出给出下一步。我们选取 sd ra,8\(sp\)，确定目标虚拟地址为 0xffffffffc0204ff8，随后跟踪页表查询，读出页表项 0x200000cf，最终确认完整物理地址为 0x80204ff8。这种方式帮助我们把调试命令对应到具体的地址转换过程。

修正分页前的对比方法。第一次尝试对比时，预期断点没有命中。我们向 AI 提供线程信息，发现当时虽然处于 M 模式，但 satp 仍保存 Sv39 配置，不能直接作为预期的启动状态记录。随后改为重新启动 QEMU，捕获 0x1000 的第一次取指，实际确认 satp=0，并观察到地址被直接使用。这个过程使我们认识到，AI 给出的调试方案也需要根据实际输出调整，不能把预期状态当作观察结果。

---

## 六、实验总结与收获

### 对操作系统的理解

1. 本实验中重要的知识点，以及与对应的 OS 原理中的知识点，并简要说明二者的含义、关系和差异

（1）物理内存初始化。本实验从设备树获取内存范围，使用Page描述符记录页面状态，再注册可分配页面。这对应OS原理中的内存资源管理。OS内存管理覆盖内存使用的整个过程，本实验仅涵盖初始化过程，为后续页面动态分配提供基础。

（2）页面分配算法，它负责根据请求选择合适的空闲页面。本实验包含First\-Fit、Best\-Fit、Buddy System等算法，通过它们来讲解不同分配策略的区别。这对应OS原理中的连续内存分配。本实验验证算法的基本行为，学习其基本逻辑，OS中还需要处理并发请求等复杂情况。

（3）页表映射，页表映射用于建立虚拟地址到物理地址的转换。本实验通过Sv39页表来讲解页表映射，并通过QEMU调试来观察具体过程。这对应OS原理中的分页机制。区别在于本实验主要研究现有映射，尚未实现OS中的完整的按需分页及缺页处理流程。

（4）对象分配，它用来处理不足一页的内存请求。本实验的SLUB利用底层页面，在页面内部划分并复用对象槽位。这对应OS内核中的细粒度内存分配，体现了分层管理思想。本实验简化了SLUB的实现，仅需实现其基本结构，而在OS中还要考虑分配效率、空间利用率等问题

2. OS原理中很重要、但在本实验中没有对应上的知识点

（1）进程调度。进程调度决定哪个任务获得处理器，用来处理多任务并行情况。本实验主要研究内存管理，没有实现多任务调度机制。

（2）按需分页。它根据应用需求进行页面映射，并在缺页时补充页面。本实验没有实现完整的缺页处理流程。

（3）同步互斥。用于保护共享资源，避免并发操作破坏数据。本实验不涉及多任务环境下的资源保护机制。

### AI 协作开发的经验

通过本次实验，我们认识到明确的任务描述是与AI有效协作的基础。在实现内存分配算法时，需要提供已有的数据结构和函数接口，并说明实验要求，讲解空闲页的选择规则。将任务拆分后逐步完成，更便于发现问题，也有助于提高效率。代码能够编译并不代表实现正确，对于Best\-Fit、Buddy System和SLUB，我们还需要验证内存是否按预期情况进行分配。AI可以帮助我们完成代码编写，但仍需要我们完成具体功能的验证，确保代码准确无误。在排查错误时，需要提供具体的报错信息并和AI明确说明修复要求，每次修改后及时验证可以缩小问题范围，避免多处改动后难以定位原因。

这次协作让我们认识到，虽然AI能够提高开发效率，但验证实验结果仍是我们的责任，只有真正掌握内存分配的知识，才能指导AI进行开发，将大模型的辅助转化为自身能力的提升。

---

