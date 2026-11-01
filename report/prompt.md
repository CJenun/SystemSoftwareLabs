**Trap上下文恢复与入口：**

[PROMPT]
**任务**：修改kern/trap/trapentry.S，补全RESTORE_ALL宏和__alltraps入口。
中断或异常发生时，硬件跳到stvec指向的__alltraps；SAVE_ALL已经在栈上
压好36个槽的trapframe。你要做的是：把sp作为参数传给trap()，等trap()
返回后，从trapframe恢复sstatus、sepc和全部通用寄存器，最后用sret回到
被中断的指令。

**操作要求**：只在 //lab3 function1 YOUR CODE标记处写代码。不要改
SAVE_ALL、__trapret和sret的位置，不要改trap()的签名，也不要动C代码。
需要的话可以加汇编注释。
**输出要求**：直接修改项目里的实际文件，不要只展示代码。寄存器和槽位
偏移以骨架为准，不要照搬其他版本的uCore。
[RELY]
// 栈与访存（libs/riscv.h）
#define REGBYTES        8
#define STORE           sd
#define LOAD            ld
// SAVE_ALL建立的trapframe，sp指向槽0
// 0:x0   1:ra   2:原sp   3:gp   4:tp
// 5~7:t0~t2   8~9:s0~s1   10~17:a0~a7
// 18~27:s2~s11   28~31:t3~t6
// 32:sstatus   33:sepc   34:badvaddr   35:scause

// 相关CSR与返回指令
csrw sstatus, s1
csrw sepc, s2
sret

// 被调用的C函数（kern/trap/trap.c）
void trap(struct trapframe *tf);
// trapframe布局（kern/trap/trap.h）
struct trapframe {
    struct pushregs gpr;   // x0~x31，共32个槽
    uintptr_t status;      // 槽32
    uintptr_t epc;         // 槽33
    uintptr_t badvaddr;    // 槽34
    uintptr_t cause;       // 槽35
};

[GUARANTEE]
必须实现或修改：
```asm
.macro RESTORE_ALL
    ...
.endm

__alltraps:
    ...
```
允许：
- 在RESTORE_ALL里用s1/s2当临时寄存器；
- 在__alltraps里用a0传参；
- 添加必要的汇编注释。

不允许：
- 修改SAVE_ALL、trap()、__trapret和sret；
- 新增全局变量或C函数；
- 改变trapframe的布局。
[SPECIFICATION]
**Pre-Condition**:
- 硬件已经跳到__alltraps，SAVE_ALL执行完毕；
- sp指向trapframe槽0，槽0~35都已填好；
- sscratch已被SAVE_ALL清零；
- trap()已经声明，__trapret紧跟__alltraps。

**Post-Condition**:
- sstatus和sepc分别从槽32、槽33恢复；
- x1、x3~x31全部从对应槽恢复，x0保持为0；
- sp最后从槽2恢复为进入trap前的值；
- 执行sret后，CPU回到sepc指向的指令，通用寄存器和中断前一致。

**Case 1**：普通时钟中断
- trap()返回时没有改epc；
- 恢复后sret回到被打断的那条指令继续执行。

**Case 2**：断点或非法指令异常
- C的exception_handler()已经把tf->epc推进到下一条指令；
- RESTORE_ALL按修改后的epc恢复sepc，sret后不再重复触发同一异常。

**Case 3**：恢复过程中再次来中断
- sp在恢复GPR时仍指向当前trapframe；
- 新trap的frame压在当前frame下方，不会覆盖正在恢复的内容；
- 嵌套返回后继续恢复，最终寄存器值仍然正确。

**Requirements**:
- sp必须最后恢复，否则后面的LOAD会用错基址；
- 不恢复x0，它是硬连线的0；
- sstatus和sepc先读进s1/s2，写完CSR后，s1/s2还要从槽9、18恢复；
- 不恢复sscratch，保持SAVE_ALL清零后的状态；
- 36×8=288字节是16的倍数，不要额外调整sp破坏ABI对齐；
- __alltraps里用`mv a0, sp`，不要用`addi a0, sp, ...`偏移；
- 异常处理推进sepc时必须按实际指令长度（c.ebreak是2字节），这是C部分的接口约定。


**中断处理功能：**

[PROMPT]

任务：
结合Lab3实验指导书及当前框架，在kern/trap/trap.c中实现完整的中断处理函数interrupt_handler()。

操作要求：
1.先阅读相关代码，理解Trap分发方式、时钟接口及测试中的调用方式，再进行实现。
2.在“//lab3 function2 YOUR CODE”对应区域添加interrupt_handler()
3.只实现中断处理部分。保留其他成员已经编写的代码及归属注释，不实现、覆盖或修改exception_handler()。
4.除必要的头文件、宏定义及本函数内部状态外，不修改其他内容，不修改已有函数、测试文件或构建脚本。
5.仅编写代码，不运行编译、QEMU、GDB或测试命令。

输出要求：
直接修改工作区中的目标文件。完成后简要说明修改位置。若发现其他成员的功能或Lab2前置代码尚未完成，只说明依赖情况，不越界补写，不添加空函数，不声称已经通过测试。


[RELY]

请阅读并依据以下文件实现，不自行假设不存在的接口：

1.kern/trap/trap.c、kern/trap/trap.h
   - struct trapframe保存当前Trap的上下文。
   - tf->cause保存Trap原因。
   - trap_dispatch()将中断交给interrupt_handler()。
   - 已有print_ticks()输出“100 ticks”，必须复用，不能修改。
   - 已有print_trapframe(tf)用于输出完整Trap frame。
   - TICK_NUM已定义为100。

2.kern/driver/clock.h、kern/driver/clock.c
   - extern volatile size_t ticks;
   - void clock_set_next_event(void);
   - clock_init()初始化ticks，并设置第一个时钟事件。
   - 时钟接口每次只安排一个事件，因此处理中断时需要安排下一次事件。

3.libs/riscv.h
   - 使用现有IRQ_*宏识别中断原因，不重复定义这些宏。
   - 框架定义了U、S、H、M对应的软件中断、定时器中断、外部中断，以及IRQ_COP、IRQ_HOST。
   - 当前项目为RV64，tf->cause最高位表示中断标志，其余位表示原因编号。

4.libs/sbi.h
   - void sbi_shutdown(void);
   - 需要调用该接口时，正确引入对应头文件，不手写替代声明或关机实现。

5.tools/test_lab3.c、tools/grade.sh
   - 测试不仅通过真实Trap调用本函数，也会直接构造Trap frame调用。
   - 软件中断测试使用带最高位中断标志的IRQ_S_SOFT。
   - 未知中断测试直接使用tf->cause=15，不带最高位中断标志。
   - 时钟测试需要达到ticks=200，并返回被打断的执行流后输出测试结果。
   - 这些文件仅供阅读，不得修改。

当前框架没有定义SHUTDOWN_AFTER。本任务将其默认值设为10，含义是累计输出10次统计信息后关机。若尚未定义，请采用条件宏定义补充默认值；若工作区已有定义，则保留已有定义，避免重复定义。


[GUARANTEE]

需要实现的函数：

void interrupt_handler(struct trapframe *tf);

该函数必须具有外部链接属性，不能定义为static，因为测试会从其他源文件调用它。

允许为本函数补充必要的头文件、SHUTDOWN_AFTER默认定义，以及用于记录统计输出次数的内部状态；不要求增加其他函数。

已有print_ticks()、print_trapframe()、trap_dispatch()、trap()等函数的实现及签名必须保持不变。


[SPECIFICATION]

Function:
void interrupt_handler(struct trapframe *tf);

Pre-Condition:
1.tf指向有效的struct trapframe。
2.正常时钟中断发生前，clock_init()已完成初始化。
3.本函数也可能被测试直接调用，因此不能要求tf->cause的最高位必须为1。
4.TICK_NUM和SHUTDOWN_AFTER为正整数。

Post-Condition:

一、中断原因识别
1.从tf->cause提取原因编号，正确排除最高位中断标志的影响。
2.同时支持带中断标志的原因值和测试直接提供的不带标志的原因编号。
3.不得为识别原因而修改tf->cause本身。

二、Supervisor时钟中断
当原因编号为IRQ_S_TIMER时：
1.调用clock_set_next_event()安排下一次时钟事件。
2.每处理一次该中断，ticks恰好增加一次，不能在函数内重新初始化ticks。
3.更新后的ticks达到TICK_NUM的整数倍时，调用print_ticks()一次。
4.累计输出统计信息达到SHUTDOWN_AFTER次时，调用sbi_shutdown()。
5.统计输出次数必须能够跨多次中断正确累计，不能在每次调用时重置。
6.默认配置下，ticks=100和ticks=200时应分别正常输出统计信息并返回；第10次统计输出时调用关机接口。
7.不得通过测试宏跳过关机功能或伪造测试成功信息。

三、其他已定义的中断
1.识别libs/riscv.h中其余已定义的中断原因，输出能区分其类型的提示。
2.IRQ_S_SOFT必须输出一行：
   Supervisor software interrupt
3.这些分支只完成实验要求的分类及提示，不扩展设备驱动功能。
4.不得修改ticks，也不得将它们当作Supervisor时钟中断处理。

四、未知中断
1.输出包含十进制原因编号的提示，格式为：
   Unknown interrupt: cause <原因编号>
2.随后调用print_trapframe(tf)，输出完整现场。
3.例如tf->cause=15时，必须输出：
   Unknown interrupt: cause 15
4.不得因此直接panic、关机或进入死循环，应正常返回。

五、上下文保持
1.本函数不得修改Trap frame中的任何字段，包括epc、status、cause和通用寄存器保存值。
2.中断处理不采用异常处理中“跳过触发指令”的方式，不得给tf->epc增加偏移。
3.上下文恢复及sret由已有汇编返回流程负责，本函数不自行恢复寄存器或开启中断。
4.除规定的关机路径外，处理完成后正常返回，使统一Trap返回流程能够继续执行。

Case（用于说明验收行为，不要求执行测试）:
1.收到带最高位标志的IRQ_S_SOFT：
   输出 Supervisor software interrupt，ticks 和 Trap frame保持不变。

2.直接传入tf->cause=15：
   输出 Unknown interrupt: cause 15，并调用print_trapframe(tf)，随后返回。

3.收到IRQ_S_TIMER，ticks原值为99：
   安排下一次事件，ticks变为100，输出一次统计信息。

4.默认配置下，累计时钟中断达到200次：
   已输出两次统计信息，尚未关机，可以返回原执行流。

5.默认配置下，累计输出第10次统计信息：
   调用sbi_shutdown()。

Requirements:
代码应使用框架已有接口，遵守当前项目的C语言编译约束，输出字符串使用真正的换行符。即使其他成员的功能尚未完成，也不得扩大本任务的修改范围。


**异常处理功能：**

[PROMPT]
**任务**：修改文件 kern\trap\trap.c，实现void exception_handler(struct trapframe *tf);(kern\trap\trap.c) 函数。exception_handler() 负责处理实验要求的异常，其中非法指令异常和断点异常需要输出规定格式的信息，并根据对应指令的长度正确更新 tf->epc，使 Trap 返回以后不会重复执行已经触发异常的指令；其他未要求具体处理的异常则使用已有的 print_trapframe(tf) 作为兜底处理。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。完成函数的实现或修改，包括但不限于：函数主体、辅助函数、内部使用的静态变量等。注意函数接口不要改变。修改内容在程序中用中文注释标注出来。如果有需要补充的其他内容先列出清单，等我确认后再执行。

**输出要求**：直接进行文件操作。保留文件中的现有代码。实现或修改的代码应插入或更新到相应的位置。不可改动其他部分，如有需要改动的部分先列出清单，等我确认后再执行。

[RELY]
整个功能模块可以借助的接口函数、结构体、数据结构为：这个模块主要依赖 struct trapframe、trap_dispatch()、interrupt_handler()、exception_handler()、print_trapframe()、clock_set_next_event()、ticks、TICK_NUM、SHUTDOWN_AFTER、IRQ_S_TIMER、CAUSE_ILLEGAL_INSTRUCTION、CAUSE_BREAKPOINT 以及 libs/sbi.h 中提供的关机相关接口。其中 tf->cause 用于判断当前 Trap 类型，tf->epc 用于记录和调整 Trap 返回后的执行位置，ticks 用于记录时钟中断次数。具体接口和宏均以实验框架中已有定义为准。

[GUARANTEE]
必须实现的函数：
实现void exception_handler(struct trapframe *tf)；

你可以根据需要添加：
- 辅助函数（建议设为static）
- 内部使用的宏定义
- 模块内部的静态变量

[SPECIFICATION]
## exception_handler

**Pre-Condition**:
- 由 trap_dispatch() 在异常（tf->cause 最高位为 0）时调用，tf 指向已保存完整现场的 trapframe。

**Post-Condition**:
- 异常已按类型处理；除 tf->epc 外，trapframe 的其他内容保持不变。
- 对已处理的异常，tf->epc 指向触发指令之后的下一条指令，trap 返回后不会重复执行原指令。
- 对未特殊处理的异常，已通过 print_trapframe() 输出现场。

  **Case 1**: 非法指令异常
  - 输出以 "Illegal instruction at" 开头、包含 tf->epc 的信息；根据该指令的实际长度（2 或 4 字节）推进 tf->epc，然后返回。

  **Case 2**: 断点异常
  - 输出以 "Breakpoint at" 开头、包含 tf->epc 的信息；同样按指令实际长度推进 tf->epc，然后返回。

  **Case 3**: 其他异常
  - 调用 print_trapframe(tf) 打印完整现场作为兜底，不修改 tf->epc。

**Requirements**:
- 不改变函数接口；除 tf->epc 外不修改 trapframe。
- 指令长度由 tf->epc 处指令编码的低两位判断：不为 0b11 时为 2 字节压缩指令，否则为 4 字节指令。
