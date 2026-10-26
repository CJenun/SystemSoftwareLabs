# 简化 SLUB 分配器实现说明

本次没有修改任何原有文件，只新增了以下三个文件：

| 文件 | 作用 |
| --- | --- |
| `kern/mm/slub.h` | 对外接口、大小类常量 |
| `kern/mm/slub.c` | 两层 SLUB 主体实现 |
| `kern/mm/slub_test.c` | 启动时自检（不修改原测试文件） |

Makefile 会自动收集 `kern/mm/` 下的所有 `.c` 文件，因此**不需要修改 Makefile**。

---

## 1. 总体架构

```
                    slub_alloc(size) / slub_free(ptr)
                    ┌──────────────────────────────┐
   第二层：对象层   │ 16 个大小类 cache             │
   (任意大小)       │ active slab + partial 链表    │
                    │ 空闲对象用对象首字组成 freelist│
                    └──────────────┬───────────────┘
                                   │ 需要新 slab / 释放空 slab
                    ┌──────────────▼───────────────┐
   第一层：页层     │ slub_page_alloc / _free      │
   (页大小)         │ 调用 uCore 的 alloc_pages()  │
                    │    / free_pages()            │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │ pmm_manager                  │
                    │ best_fit（默认）或 buddy     │
                    └──────────────────────────────┘
```

### 第一层：页粒度分配

接口：

```c
void *slub_page_alloc(size_t npages);
void slub_page_free(void *ptr, size_t npages);
```

- 直接复用 lab2 已有的 `alloc_pages()` / `free_pages()`，因此 best_fit 和
  buddy 两种物理页管理器都能工作。
- 返回的是内核虚拟地址（`page2pa(page) + va_pa_offset`）。
- 这一层只负责“申请/归还 n 个连续物理页”，不关心页内对象怎么切分。

### 第二层：任意大小对象分配

接口：

```c
void *slub_alloc(size_t size);
void *slub_zalloc(size_t size);
void slub_free(void *ptr);
```

处理规则：

- `size == 0`：返回 `NULL`。
- `0 < size <= 2048`：从对应大小类的 cache 分配。
- `size > 2048`：直接走第一层，按页数取整分配（`npages = ceil(size/4096)`）。

大小类：

```
8, 16, 24, 32, 48, 64, 96, 128,
192, 256, 384, 512, 768, 1024, 1536, 2048
```

`slub_init()` 会建立 `size -> cache` 的数组，因此选择 cache 是 O(1)。

---

## 2. 页内布局

每个 slab 正好是一页。页首放元数据，后面是等长对象：

```
 一页 4 KiB
+------------------------+------------+------------+------------+-----+
| struct slub_slab (64B) | object 0   | object 1   | object 2   | ... |
+------------------------+------------+------------+------------+-----+
                         ^
                         object_offset = 64，按 8 字节对齐
```

因为 slab 是页对齐的，从对象指针反查 slab 元数据只需要：

```c
slab = (struct slub_slab *)((uintptr_t)obj & ~(PGSIZE - 1));
```

这就是本实现能做到 O(1) 释放的关键：不需要额外的全局映射表。

### slab 元数据

```c
struct slub_slab {
    uint64_t magic;             // 合法性检查
    struct slub_cache *cache;   // 所属 cache
    struct Page *page;          // 页描述符
    void *freelist;             // 页内空闲对象链表
    list_entry_t link;          // partial 链表节点
    unsigned int inuse;         // 已分配对象数
    unsigned int total;         // 对象总数
    unsigned int npages;        // 本简化版恒为 1
    unsigned int on_partial;    // 是否在 partial 链表上
};
```

### 空闲对象链表

空闲对象的前 8 个字节直接存放“下一个空闲对象”的指针：

```
slab->freelist ──► object[3] ──► object[7] ──► object[1] ──► NULL
                   (前 8 字节)   (前 8 字节)   (前 8 字节)
```

因此不需要外部位图或额外数组，分配/释放只改一个指针，时间复杂度 O(1)。

---

## 3. 每个 cache 的组织

```c
struct slub_cache {
    const char *name;
    size_t object_size;
    size_t object_offset;
    size_t objects_per_slab;
    struct slub_slab *active;   // 快速路径当前使用的 slab
    list_entry_t partial;       // 有空洞、可继续分配的 slab
    ...
    size_t nr_slabs, nr_objects, nr_inuse, nr_alloc, nr_free;
};
```

链表策略：

- **active**：当前正在分配对象的 slab，分配时直接从它的 freelist 弹出一个对象。
- **partial**：active 用完后，从这里取下一个有空洞的 slab。
- **full**：不需要链表。slab 满了以后自然从分配路径消失；其中某个对象被释放时，
  通过对象指针 O(1) 找到 slab 元数据，再把它挂回 partial。
- 非 active 的 slab 变空时立刻把整页还给第一层。
- active slab 即使变空也保留一页用于快速复用，`slub_shrink()` 可以统一收回。

---

## 4. 分配 / 释放路径

### `slub_alloc(size)`

1. `size == 0` 返回 `NULL`。
2. `size <= 2048`：
   - 用 `slub_size_index[size]` 找到 cache（O(1)）。
   - 取 `active` slab：
     - 如果 `active == NULL` 或 freelist 为空，则先从 partial 链表取一个 slab；
       没有 partial 就调用 `slub_new_slab()` 向第一层申请一页并切分。
     - 从 freelist 弹出第一个对象。
3. `size > 2048`：按页数调用 `slub_page_alloc()`。
   - 在第一页的 `struct Page.flags` 中设置 `PG_slub_direct` 标记；
   - 把页数保存在 `page->property` 中，供 `slub_free()` 使用。

### `slub_free(ptr)`

1. 由 `ptr` 得到 `struct Page`。
2. 如果带有 `PG_slub_slab` 标记：它是 slab 对象。
   - 对象指针向下取整得到 slab 元数据；
   - 校验 magic、cache 范围和对象对齐；
   - 把对象压回该 slab 的 freelist；
   - 如果该 slab 不是 active 且已经变空，立即归还整页；
   - 如果该 slab 不是 active、仍有对象在使用，挂到 partial。
3. 如果带有 `PG_slub_direct` 标记：它是大块分配。
   - 从 `page->property` 取出页数，调用第一层归还。
4. 两者都不是：`panic`，说明不是本分配器返回的指针。

两个标记位使用 `struct Page.flags` 的第 8、9 位，只在本分配器内部使用；
pmm 管理器只使用 `PG_reserved` / `PG_property`，释放时会把 flags 清零，不会冲突。

---

## 5. 复杂度

| 操作 | 复杂度 |
| --- | --- |
| `slub_alloc` 快路径 | O(1) |
| `slub_free` | O(1) |
| 新建一个 slab | O(objects_per_slab) |
| `slub_shrink` | O(cache 数 + 空 slab 数) |
| 大小到 cache 的映射 | O(1) |

---

## 6. 需要你确认的原文件修改清单

目前**没有修改任何原文件**。如果要在内核启动时真正运行它，只需要在
`kern/init/init.c` 中加两处（推荐放在这里，避免影响 `pmm.c` 里的评分注入）：

```diff
 #include <pmm.h>
+#include <slub.h>
 #include <stdio.h>
```

```diff
     pmm_init();  // init physical memory management
+
+    slub_init();
+    slub_self_test();   // 仅用于演示和自检；正式使用时可以删掉这一行
```

说明：

1. **Makefile 不需要改**：`kern/mm/*.c` 会被自动编译。
2. 如果只想启用分配器、不打印自检信息，只保留 `slub_init();` 即可；
   之后的代码可以直接调用 `slub_alloc()` / `slub_free()`。
3. 备用方案是在 `kern/mm/pmm.c` 的 `pmm_init()` 末尾调用，但评分脚本
   `tools/inject.py` 也会在 `pmm_init()` 末尾注入测试，因此更推荐改
   `kern/init/init.c`。

请确认是否允许我修改 `kern/init/init.c`。在你确认之前，原文件保持原样。

---

## 7. 验证情况（在临时副本中进行，未改动原目录）

我把整个工程复制到 `/tmp/slub_verify`，在临时副本的 `init.c` 中加入上述调用后：

- 默认 best_fit：编译通过，QEMU 运行输出：

```
[SLUB Test] layer 1 (page allocator): PASS
[SLUB Test] layer 2 (size classes): PASS
[SLUB Test] multi-slab reuse: PASS
[SLUB Test] large allocations: PASS
[SLUB Test] PASS
```

- `make clean && make DEFS=-DUSE_BUDDY_PMM`（buddy 页管理器）：同样全部 PASS。

自检覆盖：

- 第一层 1 页 / 3 页连续页分配、页对齐、内容读写、页数账目；
- 16 个大小类各分配 4 个对象，检查 8 字节对齐、互不重叠、内容不串；
- 600 个 32 字节对象（跨多个 slab），释放一半后用另一个 cache 再分配，
  检查原对象和新对象内容；
- 2049 B 到 64 KiB 的大块分配、页对齐、内容读写；
- `size == 0` 和超出全部空闲页的请求返回 `NULL`，且不泄漏页；
- 每次测试结束后 `slub_shrink()`，确认 `nr_free_pages()` 完全恢复。

---

## 8. 简化之处与限制

为了突出 SLUB 的主体思想，本实现有意简化了以下内容：

1. **单 CPU**：没有 per-CPU cache、没有加锁。真实 SLUB 每个 CPU 有独立的
   active slab 和 freelist，以减少竞争。
2. **slab 固定一页**：真实 SLUB 会根据对象大小选择 order（1、2、4 页等），
   以降低页内碎片和管理开销。这里统一用一页，便于从对象指针直接反查页首。
3. **没有 full 链表**：full slab 不需要参与分配，释放对象时通过页首元数据
   O(1) 找回，所以不维护 full 链表。
4. **没有 slab 合并 / 回收策略**：只有 `slub_shrink()` 手动回收空 slab。
5. **大块分配不缓存**：`size > 2048` 直接按页分配，没有 kmalloc-large 缓存。
6. **`slub_free` 只接受分配时返回的原始指针**，不支持释放块内部指针；
   也暂未实现 `realloc` 和双重释放检测。
7. `struct Page.flags` 借用了第 8、9 位作为运行时标记；这两位的含义仅在本
   分配器内部有效，页归还给 pmm 后会由 pmm 清零。
