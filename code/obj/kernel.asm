
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	65c50513          	addi	a0,a0,1628 # ffffffffc02016a8 <etext+0x6>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	66650513          	addi	a0,a0,1638 # ffffffffc02016c8 <etext+0x26>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	63458593          	addi	a1,a1,1588 # ffffffffc02016a2 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	67250513          	addi	a0,a0,1650 # ffffffffc02016e8 <etext+0x46>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	67e50513          	addi	a0,a0,1662 # ffffffffc0201708 <etext+0x66>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	fe258593          	addi	a1,a1,-30 # ffffffffc0206078 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	68a50513          	addi	a0,a0,1674 # ffffffffc0201728 <etext+0x86>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00006597          	auipc	a1,0x6
ffffffffc02000ae:	3cd58593          	addi	a1,a1,973 # ffffffffc0206477 <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	67c50513          	addi	a0,a0,1660 # ffffffffc0201748 <etext+0xa6>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00006517          	auipc	a0,0x6
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0206018 <free_area>
ffffffffc02000e0:	00006617          	auipc	a2,0x6
ffffffffc02000e4:	f9860613          	addi	a2,a2,-104 # ffffffffc0206078 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	5a0010ef          	jal	ra,ffffffffc0201690 <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	67c50513          	addi	a0,a0,1660 # ffffffffc0201778 <etext+0xd6>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	687000ef          	jal	ra,ffffffffc0200f92 <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	13a010ef          	jal	ra,ffffffffc020127a <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	104010ef          	jal	ra,ffffffffc020127a <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00006317          	auipc	t1,0x6
ffffffffc02001c6:	e6e30313          	addi	t1,t1,-402 # ffffffffc0206030 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	5a650513          	addi	a0,a0,1446 # ffffffffc0201798 <etext+0xf6>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	56850513          	addi	a0,a0,1384 # ffffffffc0201770 <etext+0xce>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	3e00106f          	j	ffffffffc02015fc <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	59650513          	addi	a0,a0,1430 # ffffffffc02017b8 <etext+0x116>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00006597          	auipc	a1,0x6
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	57850513          	addi	a0,a0,1400 # ffffffffc02017c8 <etext+0x126>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00006417          	auipc	s0,0x6
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0206008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	57250513          	addi	a0,a0,1394 # ffffffffc02017d8 <etext+0x136>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	57a50513          	addi	a0,a0,1402 # ffffffffc02017f0 <etext+0x14e>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9e75>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	51090913          	addi	s2,s2,1296 # ffffffffc0201840 <etext+0x19e>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	4fa48493          	addi	s1,s1,1274 # ffffffffc0201838 <etext+0x196>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	52650513          	addi	a0,a0,1318 # ffffffffc02018b8 <etext+0x216>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	55250513          	addi	a0,a0,1362 # ffffffffc02018f0 <etext+0x24e>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	43250513          	addi	a0,a0,1074 # ffffffffc0201810 <etext+0x16e>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	22a010ef          	jal	ra,ffffffffc0201616 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	270010ef          	jal	ra,ffffffffc020166a <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	1bc010ef          	jal	ra,ffffffffc020164c <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	3a450513          	addi	a0,a0,932 # ffffffffc0201848 <etext+0x1a6>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	2f650513          	addi	a0,a0,758 # ffffffffc0201868 <etext+0x1c6>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	2fc50513          	addi	a0,a0,764 # ffffffffc0201880 <etext+0x1de>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	30a50513          	addi	a0,a0,778 # ffffffffc02018a0 <etext+0x1fe>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	34e50513          	addi	a0,a0,846 # ffffffffc02018f0 <etext+0x24e>
        memory_base = mem_base;
ffffffffc02005aa:	00006797          	auipc	a5,0x6
ffffffffc02005ae:	a887b723          	sd	s0,-1394(a5) # ffffffffc0206038 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00006797          	auipc	a5,0x6
ffffffffc02005b6:	a967b723          	sd	s6,-1394(a5) # ffffffffc0206040 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00006517          	auipc	a0,0x6
ffffffffc02005c0:	a7c53503          	ld	a0,-1412(a0) # ffffffffc0206038 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00006517          	auipc	a0,0x6
ffffffffc02005ca:	a7a53503          	ld	a0,-1414(a0) # ffffffffc0206040 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005d0:	00006797          	auipc	a5,0x6
ffffffffc02005d4:	a4878793          	addi	a5,a5,-1464 # ffffffffc0206018 <free_area>
ffffffffc02005d8:	e79c                	sd	a5,8(a5)
ffffffffc02005da:	e39c                	sd	a5,0(a5)
static void best_fit_check(void);

static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005dc:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005e0:	8082                	ret

ffffffffc02005e2 <best_fit_insert_block>:
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc02005e2:	00006697          	auipc	a3,0x6
ffffffffc02005e6:	a3668693          	addi	a3,a3,-1482 # ffffffffc0206018 <free_area>
ffffffffc02005ea:	669c                	ld	a5,8(a3)

// Insert a free block by address and coalesce without changing nr_free.
static void
best_fit_insert_block(struct Page *base) {
    list_entry_t *le = list_next(&free_list);
    while (le != &free_list && le2page(le, page_link) < base) {
ffffffffc02005ec:	00d78b63          	beq	a5,a3,ffffffffc0200602 <best_fit_insert_block+0x20>
ffffffffc02005f0:	fe878713          	addi	a4,a5,-24
ffffffffc02005f4:	00a77763          	bgeu	a4,a0,ffffffffc0200602 <best_fit_insert_block+0x20>
ffffffffc02005f8:	679c                	ld	a5,8(a5)
ffffffffc02005fa:	fe878713          	addi	a4,a5,-24
ffffffffc02005fe:	fed79be3          	bne	a5,a3,ffffffffc02005f4 <best_fit_insert_block+0x12>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200602:	6398                	ld	a4,0(a5)
        le = list_next(le);
    }
    list_add_before(le, &(base->page_link));
ffffffffc0200604:	01850593          	addi	a1,a0,24
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
ffffffffc0200608:	e38c                	sd	a1,0(a5)
ffffffffc020060a:	e70c                	sd	a1,8(a4)
    elm->next = next;
ffffffffc020060c:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020060e:	ed18                	sd	a4,24(a0)

    le = list_prev(&(base->page_link));
    if (le != &free_list) {
ffffffffc0200610:	02d70163          	beq	a4,a3,ffffffffc0200632 <best_fit_insert_block+0x50>
        struct Page *prev = le2page(le, page_link);
        if (prev + prev->property == base) {
ffffffffc0200614:	ff872303          	lw	t1,-8(a4)
        struct Page *prev = le2page(le, page_link);
ffffffffc0200618:	fe870893          	addi	a7,a4,-24
        if (prev + prev->property == base) {
ffffffffc020061c:	02031813          	slli	a6,t1,0x20
ffffffffc0200620:	02085813          	srli	a6,a6,0x20
ffffffffc0200624:	00281613          	slli	a2,a6,0x2
ffffffffc0200628:	9642                	add	a2,a2,a6
ffffffffc020062a:	060e                	slli	a2,a2,0x3
ffffffffc020062c:	9646                	add	a2,a2,a7
ffffffffc020062e:	04c50763          	beq	a0,a2,ffffffffc020067c <best_fit_insert_block+0x9a>
            base = prev;
        }
    }

    le = list_next(&(base->page_link));
    if (le != &free_list) {
ffffffffc0200632:	00d78f63          	beq	a5,a3,ffffffffc0200650 <best_fit_insert_block+0x6e>
        struct Page *next = le2page(le, page_link);
        if (base + base->property == next) {
ffffffffc0200636:	490c                	lw	a1,16(a0)
        struct Page *next = le2page(le, page_link);
ffffffffc0200638:	fe878693          	addi	a3,a5,-24
        if (base + base->property == next) {
ffffffffc020063c:	02059613          	slli	a2,a1,0x20
ffffffffc0200640:	9201                	srli	a2,a2,0x20
ffffffffc0200642:	00261713          	slli	a4,a2,0x2
ffffffffc0200646:	9732                	add	a4,a4,a2
ffffffffc0200648:	070e                	slli	a4,a4,0x3
ffffffffc020064a:	972a                	add	a4,a4,a0
ffffffffc020064c:	00d70363          	beq	a4,a3,ffffffffc0200652 <best_fit_insert_block+0x70>
            ClearPageProperty(next);
            next->property = 0;
            list_del_init(&(next->page_link));
        }
    }
}
ffffffffc0200650:	8082                	ret
            base->property += next->property;
ffffffffc0200652:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(next);
ffffffffc0200656:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc020065a:	0007b803          	ld	a6,0(a5)
ffffffffc020065e:	6790                	ld	a2,8(a5)
            base->property += next->property;
ffffffffc0200660:	9db5                	addw	a1,a1,a3
ffffffffc0200662:	c90c                	sw	a1,16(a0)
            ClearPageProperty(next);
ffffffffc0200664:	9b75                	andi	a4,a4,-3
ffffffffc0200666:	fee7b823          	sd	a4,-16(a5)
            next->property = 0;
ffffffffc020066a:	fe07ac23          	sw	zero,-8(a5)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc020066e:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc0200672:	01063023          	sd	a6,0(a2) # ff0000 <kern_entry-0xffffffffbf210000>
    elm->prev = elm->next = elm;
ffffffffc0200676:	e79c                	sd	a5,8(a5)
ffffffffc0200678:	e39c                	sd	a5,0(a5)
}
ffffffffc020067a:	8082                	ret
            prev->property += base->property;
ffffffffc020067c:	01052803          	lw	a6,16(a0)
            ClearPageProperty(base);
ffffffffc0200680:	6510                	ld	a2,8(a0)
            prev->property += base->property;
ffffffffc0200682:	0068033b          	addw	t1,a6,t1
ffffffffc0200686:	fe672c23          	sw	t1,-8(a4)
            ClearPageProperty(base);
ffffffffc020068a:	9a75                	andi	a2,a2,-3
ffffffffc020068c:	e510                	sd	a2,8(a0)
            base->property = 0;
ffffffffc020068e:	00052823          	sw	zero,16(a0)
    prev->next = next;
ffffffffc0200692:	e71c                	sd	a5,8(a4)
    next->prev = prev;
ffffffffc0200694:	e398                	sd	a4,0(a5)
    elm->prev = elm->next = elm;
ffffffffc0200696:	f10c                	sd	a1,32(a0)
    return listelm->next;
ffffffffc0200698:	671c                	ld	a5,8(a4)
    elm->prev = elm->next = elm;
ffffffffc020069a:	ed0c                	sd	a1,24(a0)
            base = prev;
ffffffffc020069c:	8546                	mv	a0,a7
ffffffffc020069e:	bf51                	j	ffffffffc0200632 <best_fit_insert_block+0x50>

ffffffffc02006a0 <best_fit_nr_free_pages>:
}

static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02006a0:	00006517          	auipc	a0,0x6
ffffffffc02006a4:	98856503          	lwu	a0,-1656(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc02006a8:	8082                	ret

ffffffffc02006aa <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc02006aa:	c94d                	beqz	a0,ffffffffc020075c <best_fit_alloc_pages+0xb2>
    if (n > nr_free || list_empty(&free_list)) {
ffffffffc02006ac:	00006597          	auipc	a1,0x6
ffffffffc02006b0:	96c58593          	addi	a1,a1,-1684 # ffffffffc0206018 <free_area>
ffffffffc02006b4:	0105a883          	lw	a7,16(a1)
ffffffffc02006b8:	86aa                	mv	a3,a0
ffffffffc02006ba:	02089793          	slli	a5,a7,0x20
ffffffffc02006be:	9381                	srli	a5,a5,0x20
ffffffffc02006c0:	08a7ec63          	bltu	a5,a0,ffffffffc0200758 <best_fit_alloc_pages+0xae>
    return list->next == list;
ffffffffc02006c4:	659c                	ld	a5,8(a1)
        return NULL;
ffffffffc02006c6:	4501                	li	a0,0
    if (n > nr_free || list_empty(&free_list)) {
ffffffffc02006c8:	08b78763          	beq	a5,a1,ffffffffc0200756 <best_fit_alloc_pages+0xac>
        if (p->property >= n &&
ffffffffc02006cc:	ff87a703          	lw	a4,-8(a5)
        struct Page *p = le2page(le, page_link);
ffffffffc02006d0:	fe878813          	addi	a6,a5,-24
        if (p->property >= n &&
ffffffffc02006d4:	02071613          	slli	a2,a4,0x20
ffffffffc02006d8:	9201                	srli	a2,a2,0x20
ffffffffc02006da:	00d66763          	bltu	a2,a3,ffffffffc02006e8 <best_fit_alloc_pages+0x3e>
ffffffffc02006de:	c501                	beqz	a0,ffffffffc02006e6 <best_fit_alloc_pages+0x3c>
            (page == NULL || p->property < page->property)) {
ffffffffc02006e0:	4910                	lw	a2,16(a0)
ffffffffc02006e2:	00c77363          	bgeu	a4,a2,ffffffffc02006e8 <best_fit_alloc_pages+0x3e>
            page = p;
ffffffffc02006e6:	8542                	mv	a0,a6
    return listelm->next;
ffffffffc02006e8:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006ea:	feb791e3          	bne	a5,a1,ffffffffc02006cc <best_fit_alloc_pages+0x22>
    if (page == NULL) {
ffffffffc02006ee:	c525                	beqz	a0,ffffffffc0200756 <best_fit_alloc_pages+0xac>
    __list_del(listelm->prev, listelm->next);
ffffffffc02006f0:	02053803          	ld	a6,32(a0)
    return listelm->prev;
ffffffffc02006f4:	6d18                	ld	a4,24(a0)
    if (page->property > n) {
ffffffffc02006f6:	4910                	lw	a2,16(a0)
    list_del_init(&(page->page_link));
ffffffffc02006f8:	01850793          	addi	a5,a0,24
    prev->next = next;
ffffffffc02006fc:	01073423          	sd	a6,8(a4)
    next->prev = prev;
ffffffffc0200700:	00e83023          	sd	a4,0(a6)
    elm->prev = elm->next = elm;
ffffffffc0200704:	f11c                	sd	a5,32(a0)
ffffffffc0200706:	ed1c                	sd	a5,24(a0)
    if (page->property > n) {
ffffffffc0200708:	02061793          	slli	a5,a2,0x20
ffffffffc020070c:	9381                	srli	a5,a5,0x20
        rest->property = page->property - n;
ffffffffc020070e:	0006881b          	sext.w	a6,a3
    if (page->property > n) {
ffffffffc0200712:	02f6f863          	bgeu	a3,a5,ffffffffc0200742 <best_fit_alloc_pages+0x98>
        struct Page *rest = page + n;
ffffffffc0200716:	00269793          	slli	a5,a3,0x2
ffffffffc020071a:	97b6                	add	a5,a5,a3
ffffffffc020071c:	078e                	slli	a5,a5,0x3
ffffffffc020071e:	97aa                	add	a5,a5,a0
        SetPageProperty(rest);
ffffffffc0200720:	6794                	ld	a3,8(a5)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200722:	00873303          	ld	t1,8(a4)
        rest->property = page->property - n;
ffffffffc0200726:	4106063b          	subw	a2,a2,a6
        SetPageProperty(rest);
ffffffffc020072a:	0026e693          	ori	a3,a3,2
ffffffffc020072e:	e794                	sd	a3,8(a5)
        rest->property = page->property - n;
ffffffffc0200730:	cb90                	sw	a2,16(a5)
        list_add(prev, &(rest->page_link));
ffffffffc0200732:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc0200736:	00d33023          	sd	a3,0(t1)
ffffffffc020073a:	e714                	sd	a3,8(a4)
    elm->next = next;
ffffffffc020073c:	0267b023          	sd	t1,32(a5)
    elm->prev = prev;
ffffffffc0200740:	ef98                	sd	a4,24(a5)
    ClearPageProperty(page);
ffffffffc0200742:	651c                	ld	a5,8(a0)
    page->property = 0;
ffffffffc0200744:	00052823          	sw	zero,16(a0)
    nr_free -= n;
ffffffffc0200748:	410888bb          	subw	a7,a7,a6
    ClearPageProperty(page);
ffffffffc020074c:	9bf5                	andi	a5,a5,-3
ffffffffc020074e:	e51c                	sd	a5,8(a0)
    nr_free -= n;
ffffffffc0200750:	0115a823          	sw	a7,16(a1)
    return page;
ffffffffc0200754:	8082                	ret
}
ffffffffc0200756:	8082                	ret
        return NULL;
ffffffffc0200758:	4501                	li	a0,0
ffffffffc020075a:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc020075c:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc020075e:	00001697          	auipc	a3,0x1
ffffffffc0200762:	1aa68693          	addi	a3,a3,426 # ffffffffc0201908 <etext+0x266>
ffffffffc0200766:	00001617          	auipc	a2,0x1
ffffffffc020076a:	1aa60613          	addi	a2,a2,426 # ffffffffc0201910 <etext+0x26e>
ffffffffc020076e:	04700593          	li	a1,71
ffffffffc0200772:	00001517          	auipc	a0,0x1
ffffffffc0200776:	1b650513          	addi	a0,a0,438 # ffffffffc0201928 <etext+0x286>
best_fit_alloc_pages(size_t n) {
ffffffffc020077a:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020077c:	a47ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200780 <best_fit_check>:
    free_page(p1);
    free_page(p2);
}

static void
best_fit_check(void) {
ffffffffc0200780:	715d                	addi	sp,sp,-80
ffffffffc0200782:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc0200784:	00006417          	auipc	s0,0x6
ffffffffc0200788:	89440413          	addi	s0,s0,-1900 # ffffffffc0206018 <free_area>
ffffffffc020078c:	641c                	ld	a5,8(s0)
ffffffffc020078e:	e486                	sd	ra,72(sp)
ffffffffc0200790:	fc26                	sd	s1,56(sp)
ffffffffc0200792:	f84a                	sd	s2,48(sp)
ffffffffc0200794:	f44e                	sd	s3,40(sp)
ffffffffc0200796:	f052                	sd	s4,32(sp)
ffffffffc0200798:	ec56                	sd	s5,24(sp)
ffffffffc020079a:	e85a                	sd	s6,16(sp)
ffffffffc020079c:	e45e                	sd	s7,8(sp)
ffffffffc020079e:	e062                	sd	s8,0(sp)
    int score = 0, sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02007a0:	26878963          	beq	a5,s0,ffffffffc0200a12 <best_fit_check+0x292>
    int count = 0, total = 0;
ffffffffc02007a4:	4481                	li	s1,0
ffffffffc02007a6:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc02007a8:	ff07b703          	ld	a4,-16(a5)
ffffffffc02007ac:	8b09                	andi	a4,a4,2
ffffffffc02007ae:	26070663          	beqz	a4,ffffffffc0200a1a <best_fit_check+0x29a>
        count++, total += p->property;
ffffffffc02007b2:	ff87a703          	lw	a4,-8(a5)
ffffffffc02007b6:	679c                	ld	a5,8(a5)
ffffffffc02007b8:	2905                	addiw	s2,s2,1
ffffffffc02007ba:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02007bc:	fe8796e3          	bne	a5,s0,ffffffffc02007a8 <best_fit_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc02007c0:	89a6                	mv	s3,s1
ffffffffc02007c2:	7c4000ef          	jal	ra,ffffffffc0200f86 <nr_free_pages>
ffffffffc02007c6:	33351a63          	bne	a0,s3,ffffffffc0200afa <best_fit_check+0x37a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02007ca:	4505                	li	a0,1
ffffffffc02007cc:	7a2000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02007d0:	8a2a                	mv	s4,a0
ffffffffc02007d2:	36050463          	beqz	a0,ffffffffc0200b3a <best_fit_check+0x3ba>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02007d6:	4505                	li	a0,1
ffffffffc02007d8:	796000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02007dc:	89aa                	mv	s3,a0
ffffffffc02007de:	32050e63          	beqz	a0,ffffffffc0200b1a <best_fit_check+0x39a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02007e2:	4505                	li	a0,1
ffffffffc02007e4:	78a000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02007e8:	8aaa                	mv	s5,a0
ffffffffc02007ea:	2c050863          	beqz	a0,ffffffffc0200aba <best_fit_check+0x33a>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc02007ee:	253a0663          	beq	s4,s3,ffffffffc0200a3a <best_fit_check+0x2ba>
ffffffffc02007f2:	24aa0463          	beq	s4,a0,ffffffffc0200a3a <best_fit_check+0x2ba>
ffffffffc02007f6:	24a98263          	beq	s3,a0,ffffffffc0200a3a <best_fit_check+0x2ba>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc02007fa:	000a2783          	lw	a5,0(s4)
ffffffffc02007fe:	24079e63          	bnez	a5,ffffffffc0200a5a <best_fit_check+0x2da>
ffffffffc0200802:	0009a783          	lw	a5,0(s3)
ffffffffc0200806:	24079a63          	bnez	a5,ffffffffc0200a5a <best_fit_check+0x2da>
ffffffffc020080a:	411c                	lw	a5,0(a0)
ffffffffc020080c:	24079763          	bnez	a5,ffffffffc0200a5a <best_fit_check+0x2da>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200810:	00006797          	auipc	a5,0x6
ffffffffc0200814:	8407b783          	ld	a5,-1984(a5) # ffffffffc0206050 <pages>
ffffffffc0200818:	40fa0733          	sub	a4,s4,a5
ffffffffc020081c:	870d                	srai	a4,a4,0x3
ffffffffc020081e:	00002597          	auipc	a1,0x2
ffffffffc0200822:	9325b583          	ld	a1,-1742(a1) # ffffffffc0202150 <error_string+0x38>
ffffffffc0200826:	02b70733          	mul	a4,a4,a1
ffffffffc020082a:	00002617          	auipc	a2,0x2
ffffffffc020082e:	92e63603          	ld	a2,-1746(a2) # ffffffffc0202158 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200832:	00006697          	auipc	a3,0x6
ffffffffc0200836:	8166b683          	ld	a3,-2026(a3) # ffffffffc0206048 <npage>
ffffffffc020083a:	06b2                	slli	a3,a3,0xc
ffffffffc020083c:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc020083e:	0732                	slli	a4,a4,0xc
ffffffffc0200840:	22d77d63          	bgeu	a4,a3,ffffffffc0200a7a <best_fit_check+0x2fa>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200844:	40f98733          	sub	a4,s3,a5
ffffffffc0200848:	870d                	srai	a4,a4,0x3
ffffffffc020084a:	02b70733          	mul	a4,a4,a1
ffffffffc020084e:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200850:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200852:	3ed77463          	bgeu	a4,a3,ffffffffc0200c3a <best_fit_check+0x4ba>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200856:	40f507b3          	sub	a5,a0,a5
ffffffffc020085a:	878d                	srai	a5,a5,0x3
ffffffffc020085c:	02b787b3          	mul	a5,a5,a1
ffffffffc0200860:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200862:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200864:	3ad7fb63          	bgeu	a5,a3,ffffffffc0200c1a <best_fit_check+0x49a>
    assert(alloc_page() == NULL);
ffffffffc0200868:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020086a:	00043c03          	ld	s8,0(s0)
ffffffffc020086e:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc0200872:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc0200876:	e400                	sd	s0,8(s0)
ffffffffc0200878:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc020087a:	00005797          	auipc	a5,0x5
ffffffffc020087e:	7a07a723          	sw	zero,1966(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc0200882:	6ec000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc0200886:	36051a63          	bnez	a0,ffffffffc0200bfa <best_fit_check+0x47a>
    free_page(p0);
ffffffffc020088a:	4585                	li	a1,1
ffffffffc020088c:	8552                	mv	a0,s4
ffffffffc020088e:	6ec000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    free_page(p1);
ffffffffc0200892:	4585                	li	a1,1
ffffffffc0200894:	854e                	mv	a0,s3
ffffffffc0200896:	6e4000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    free_page(p2);
ffffffffc020089a:	4585                	li	a1,1
ffffffffc020089c:	8556                	mv	a0,s5
ffffffffc020089e:	6dc000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    assert(nr_free == 3);
ffffffffc02008a2:	4818                	lw	a4,16(s0)
ffffffffc02008a4:	478d                	li	a5,3
ffffffffc02008a6:	32f71a63          	bne	a4,a5,ffffffffc0200bda <best_fit_check+0x45a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02008aa:	4505                	li	a0,1
ffffffffc02008ac:	6c2000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02008b0:	89aa                	mv	s3,a0
ffffffffc02008b2:	30050463          	beqz	a0,ffffffffc0200bba <best_fit_check+0x43a>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02008b6:	4505                	li	a0,1
ffffffffc02008b8:	6b6000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02008bc:	8aaa                	mv	s5,a0
ffffffffc02008be:	2c050e63          	beqz	a0,ffffffffc0200b9a <best_fit_check+0x41a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02008c2:	4505                	li	a0,1
ffffffffc02008c4:	6aa000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02008c8:	8a2a                	mv	s4,a0
ffffffffc02008ca:	2a050863          	beqz	a0,ffffffffc0200b7a <best_fit_check+0x3fa>
    assert(alloc_page() == NULL);
ffffffffc02008ce:	4505                	li	a0,1
ffffffffc02008d0:	69e000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02008d4:	28051363          	bnez	a0,ffffffffc0200b5a <best_fit_check+0x3da>
    free_page(p0);
ffffffffc02008d8:	4585                	li	a1,1
ffffffffc02008da:	854e                	mv	a0,s3
ffffffffc02008dc:	69e000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    assert(!list_empty(&free_list));
ffffffffc02008e0:	641c                	ld	a5,8(s0)
ffffffffc02008e2:	1a878c63          	beq	a5,s0,ffffffffc0200a9a <best_fit_check+0x31a>
    assert((p = alloc_page()) == p0);
ffffffffc02008e6:	4505                	li	a0,1
ffffffffc02008e8:	686000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02008ec:	52a99763          	bne	s3,a0,ffffffffc0200e1a <best_fit_check+0x69a>
    assert(alloc_page() == NULL);
ffffffffc02008f0:	4505                	li	a0,1
ffffffffc02008f2:	67c000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02008f6:	50051263          	bnez	a0,ffffffffc0200dfa <best_fit_check+0x67a>
    assert(nr_free == 0);
ffffffffc02008fa:	481c                	lw	a5,16(s0)
ffffffffc02008fc:	4c079f63          	bnez	a5,ffffffffc0200dda <best_fit_check+0x65a>
    free_page(p);
ffffffffc0200900:	854e                	mv	a0,s3
ffffffffc0200902:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200904:	01843023          	sd	s8,0(s0)
ffffffffc0200908:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc020090c:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200910:	66a000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    free_page(p1);
ffffffffc0200914:	4585                	li	a1,1
ffffffffc0200916:	8556                	mv	a0,s5
ffffffffc0200918:	662000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    free_page(p2);
ffffffffc020091c:	4585                	li	a1,1
ffffffffc020091e:	8552                	mv	a0,s4
ffffffffc0200920:	65a000ef          	jal	ra,ffffffffc0200f7a <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200924:	4515                	li	a0,5
ffffffffc0200926:	648000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc020092a:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc020092c:	48050763          	beqz	a0,ffffffffc0200dba <best_fit_check+0x63a>
    assert(!PageProperty(p0));
ffffffffc0200930:	651c                	ld	a5,8(a0)
ffffffffc0200932:	8b89                	andi	a5,a5,2
ffffffffc0200934:	46079363          	bnez	a5,ffffffffc0200d9a <best_fit_check+0x61a>
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200938:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020093a:	00043b03          	ld	s6,0(s0)
ffffffffc020093e:	00843a83          	ld	s5,8(s0)
ffffffffc0200942:	e000                	sd	s0,0(s0)
ffffffffc0200944:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200946:	628000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc020094a:	42051863          	bnez	a0,ffffffffc0200d7a <best_fit_check+0x5fa>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc020094e:	4589                	li	a1,2
ffffffffc0200950:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc0200954:	01042b83          	lw	s7,16(s0)
    free_pages(p0 + 4, 1);
ffffffffc0200958:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc020095c:	00005797          	auipc	a5,0x5
ffffffffc0200960:	6c07a623          	sw	zero,1740(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0200964:	616000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0200968:	8562                	mv	a0,s8
ffffffffc020096a:	4585                	li	a1,1
ffffffffc020096c:	60e000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200970:	4511                	li	a0,4
ffffffffc0200972:	5fc000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc0200976:	3e051263          	bnez	a0,ffffffffc0200d5a <best_fit_check+0x5da>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc020097a:	0309b783          	ld	a5,48(s3)
ffffffffc020097e:	8b89                	andi	a5,a5,2
ffffffffc0200980:	3a078d63          	beqz	a5,ffffffffc0200d3a <best_fit_check+0x5ba>
ffffffffc0200984:	0389a703          	lw	a4,56(s3)
ffffffffc0200988:	4789                	li	a5,2
ffffffffc020098a:	3af71863          	bne	a4,a5,ffffffffc0200d3a <best_fit_check+0x5ba>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc020098e:	4505                	li	a0,1
ffffffffc0200990:	5de000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc0200994:	8a2a                	mv	s4,a0
ffffffffc0200996:	38050263          	beqz	a0,ffffffffc0200d1a <best_fit_check+0x59a>
    assert(alloc_pages(2) != NULL);
ffffffffc020099a:	4509                	li	a0,2
ffffffffc020099c:	5d2000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02009a0:	34050d63          	beqz	a0,ffffffffc0200cfa <best_fit_check+0x57a>
    assert(p0 + 4 == p1);
ffffffffc02009a4:	334c1b63          	bne	s8,s4,ffffffffc0200cda <best_fit_check+0x55a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc02009a8:	854e                	mv	a0,s3
ffffffffc02009aa:	4595                	li	a1,5
ffffffffc02009ac:	5ce000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02009b0:	4515                	li	a0,5
ffffffffc02009b2:	5bc000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02009b6:	89aa                	mv	s3,a0
ffffffffc02009b8:	30050163          	beqz	a0,ffffffffc0200cba <best_fit_check+0x53a>
    assert(alloc_page() == NULL);
ffffffffc02009bc:	4505                	li	a0,1
ffffffffc02009be:	5b0000ef          	jal	ra,ffffffffc0200f6e <alloc_pages>
ffffffffc02009c2:	2c051c63          	bnez	a0,ffffffffc0200c9a <best_fit_check+0x51a>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc02009c6:	481c                	lw	a5,16(s0)
ffffffffc02009c8:	2a079963          	bnez	a5,ffffffffc0200c7a <best_fit_check+0x4fa>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc02009cc:	4595                	li	a1,5
ffffffffc02009ce:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc02009d0:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc02009d4:	01643023          	sd	s6,0(s0)
ffffffffc02009d8:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc02009dc:	59e000ef          	jal	ra,ffffffffc0200f7a <free_pages>
    return listelm->next;
ffffffffc02009e0:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02009e2:	00878963          	beq	a5,s0,ffffffffc02009f4 <best_fit_check+0x274>
        struct Page *p = le2page(le, page_link);
        count--, total -= p->property;
ffffffffc02009e6:	ff87a703          	lw	a4,-8(a5)
ffffffffc02009ea:	679c                	ld	a5,8(a5)
ffffffffc02009ec:	397d                	addiw	s2,s2,-1
ffffffffc02009ee:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02009f0:	fe879be3          	bne	a5,s0,ffffffffc02009e6 <best_fit_check+0x266>
    }
    assert(count == 0);
ffffffffc02009f4:	26091363          	bnez	s2,ffffffffc0200c5a <best_fit_check+0x4da>
    assert(total == 0);
ffffffffc02009f8:	e0ed                	bnez	s1,ffffffffc0200ada <best_fit_check+0x35a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
}
ffffffffc02009fa:	60a6                	ld	ra,72(sp)
ffffffffc02009fc:	6406                	ld	s0,64(sp)
ffffffffc02009fe:	74e2                	ld	s1,56(sp)
ffffffffc0200a00:	7942                	ld	s2,48(sp)
ffffffffc0200a02:	79a2                	ld	s3,40(sp)
ffffffffc0200a04:	7a02                	ld	s4,32(sp)
ffffffffc0200a06:	6ae2                	ld	s5,24(sp)
ffffffffc0200a08:	6b42                	ld	s6,16(sp)
ffffffffc0200a0a:	6ba2                	ld	s7,8(sp)
ffffffffc0200a0c:	6c02                	ld	s8,0(sp)
ffffffffc0200a0e:	6161                	addi	sp,sp,80
ffffffffc0200a10:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200a12:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200a14:	4481                	li	s1,0
ffffffffc0200a16:	4901                	li	s2,0
ffffffffc0200a18:	b36d                	j	ffffffffc02007c2 <best_fit_check+0x42>
        assert(PageProperty(p));
ffffffffc0200a1a:	00001697          	auipc	a3,0x1
ffffffffc0200a1e:	f2668693          	addi	a3,a3,-218 # ffffffffc0201940 <etext+0x29e>
ffffffffc0200a22:	00001617          	auipc	a2,0x1
ffffffffc0200a26:	eee60613          	addi	a2,a2,-274 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200a2a:	0c100593          	li	a1,193
ffffffffc0200a2e:	00001517          	auipc	a0,0x1
ffffffffc0200a32:	efa50513          	addi	a0,a0,-262 # ffffffffc0201928 <etext+0x286>
ffffffffc0200a36:	f8cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200a3a:	00001697          	auipc	a3,0x1
ffffffffc0200a3e:	f9668693          	addi	a3,a3,-106 # ffffffffc02019d0 <etext+0x32e>
ffffffffc0200a42:	00001617          	auipc	a2,0x1
ffffffffc0200a46:	ece60613          	addi	a2,a2,-306 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200a4a:	08f00593          	li	a1,143
ffffffffc0200a4e:	00001517          	auipc	a0,0x1
ffffffffc0200a52:	eda50513          	addi	a0,a0,-294 # ffffffffc0201928 <etext+0x286>
ffffffffc0200a56:	f6cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200a5a:	00001697          	auipc	a3,0x1
ffffffffc0200a5e:	f9e68693          	addi	a3,a3,-98 # ffffffffc02019f8 <etext+0x356>
ffffffffc0200a62:	00001617          	auipc	a2,0x1
ffffffffc0200a66:	eae60613          	addi	a2,a2,-338 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200a6a:	09000593          	li	a1,144
ffffffffc0200a6e:	00001517          	auipc	a0,0x1
ffffffffc0200a72:	eba50513          	addi	a0,a0,-326 # ffffffffc0201928 <etext+0x286>
ffffffffc0200a76:	f4cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200a7a:	00001697          	auipc	a3,0x1
ffffffffc0200a7e:	fbe68693          	addi	a3,a3,-66 # ffffffffc0201a38 <etext+0x396>
ffffffffc0200a82:	00001617          	auipc	a2,0x1
ffffffffc0200a86:	e8e60613          	addi	a2,a2,-370 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200a8a:	09200593          	li	a1,146
ffffffffc0200a8e:	00001517          	auipc	a0,0x1
ffffffffc0200a92:	e9a50513          	addi	a0,a0,-358 # ffffffffc0201928 <etext+0x286>
ffffffffc0200a96:	f2cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0200a9a:	00001697          	auipc	a3,0x1
ffffffffc0200a9e:	02668693          	addi	a3,a3,38 # ffffffffc0201ac0 <etext+0x41e>
ffffffffc0200aa2:	00001617          	auipc	a2,0x1
ffffffffc0200aa6:	e6e60613          	addi	a2,a2,-402 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200aaa:	0ab00593          	li	a1,171
ffffffffc0200aae:	00001517          	auipc	a0,0x1
ffffffffc0200ab2:	e7a50513          	addi	a0,a0,-390 # ffffffffc0201928 <etext+0x286>
ffffffffc0200ab6:	f0cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200aba:	00001697          	auipc	a3,0x1
ffffffffc0200abe:	ef668693          	addi	a3,a3,-266 # ffffffffc02019b0 <etext+0x30e>
ffffffffc0200ac2:	00001617          	auipc	a2,0x1
ffffffffc0200ac6:	e4e60613          	addi	a2,a2,-434 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200aca:	08d00593          	li	a1,141
ffffffffc0200ace:	00001517          	auipc	a0,0x1
ffffffffc0200ad2:	e5a50513          	addi	a0,a0,-422 # ffffffffc0201928 <etext+0x286>
ffffffffc0200ad6:	eecff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == 0);
ffffffffc0200ada:	00001697          	auipc	a3,0x1
ffffffffc0200ade:	11668693          	addi	a3,a3,278 # ffffffffc0201bf0 <etext+0x54e>
ffffffffc0200ae2:	00001617          	auipc	a2,0x1
ffffffffc0200ae6:	e2e60613          	addi	a2,a2,-466 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200aea:	10300593          	li	a1,259
ffffffffc0200aee:	00001517          	auipc	a0,0x1
ffffffffc0200af2:	e3a50513          	addi	a0,a0,-454 # ffffffffc0201928 <etext+0x286>
ffffffffc0200af6:	eccff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200afa:	00001697          	auipc	a3,0x1
ffffffffc0200afe:	e5668693          	addi	a3,a3,-426 # ffffffffc0201950 <etext+0x2ae>
ffffffffc0200b02:	00001617          	auipc	a2,0x1
ffffffffc0200b06:	e0e60613          	addi	a2,a2,-498 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200b0a:	0c400593          	li	a1,196
ffffffffc0200b0e:	00001517          	auipc	a0,0x1
ffffffffc0200b12:	e1a50513          	addi	a0,a0,-486 # ffffffffc0201928 <etext+0x286>
ffffffffc0200b16:	eacff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200b1a:	00001697          	auipc	a3,0x1
ffffffffc0200b1e:	e7668693          	addi	a3,a3,-394 # ffffffffc0201990 <etext+0x2ee>
ffffffffc0200b22:	00001617          	auipc	a2,0x1
ffffffffc0200b26:	dee60613          	addi	a2,a2,-530 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200b2a:	08c00593          	li	a1,140
ffffffffc0200b2e:	00001517          	auipc	a0,0x1
ffffffffc0200b32:	dfa50513          	addi	a0,a0,-518 # ffffffffc0201928 <etext+0x286>
ffffffffc0200b36:	e8cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200b3a:	00001697          	auipc	a3,0x1
ffffffffc0200b3e:	e3668693          	addi	a3,a3,-458 # ffffffffc0201970 <etext+0x2ce>
ffffffffc0200b42:	00001617          	auipc	a2,0x1
ffffffffc0200b46:	dce60613          	addi	a2,a2,-562 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200b4a:	08b00593          	li	a1,139
ffffffffc0200b4e:	00001517          	auipc	a0,0x1
ffffffffc0200b52:	dda50513          	addi	a0,a0,-550 # ffffffffc0201928 <etext+0x286>
ffffffffc0200b56:	e6cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200b5a:	00001697          	auipc	a3,0x1
ffffffffc0200b5e:	f3e68693          	addi	a3,a3,-194 # ffffffffc0201a98 <etext+0x3f6>
ffffffffc0200b62:	00001617          	auipc	a2,0x1
ffffffffc0200b66:	dae60613          	addi	a2,a2,-594 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200b6a:	0a800593          	li	a1,168
ffffffffc0200b6e:	00001517          	auipc	a0,0x1
ffffffffc0200b72:	dba50513          	addi	a0,a0,-582 # ffffffffc0201928 <etext+0x286>
ffffffffc0200b76:	e4cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200b7a:	00001697          	auipc	a3,0x1
ffffffffc0200b7e:	e3668693          	addi	a3,a3,-458 # ffffffffc02019b0 <etext+0x30e>
ffffffffc0200b82:	00001617          	auipc	a2,0x1
ffffffffc0200b86:	d8e60613          	addi	a2,a2,-626 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200b8a:	0a600593          	li	a1,166
ffffffffc0200b8e:	00001517          	auipc	a0,0x1
ffffffffc0200b92:	d9a50513          	addi	a0,a0,-614 # ffffffffc0201928 <etext+0x286>
ffffffffc0200b96:	e2cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200b9a:	00001697          	auipc	a3,0x1
ffffffffc0200b9e:	df668693          	addi	a3,a3,-522 # ffffffffc0201990 <etext+0x2ee>
ffffffffc0200ba2:	00001617          	auipc	a2,0x1
ffffffffc0200ba6:	d6e60613          	addi	a2,a2,-658 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200baa:	0a500593          	li	a1,165
ffffffffc0200bae:	00001517          	auipc	a0,0x1
ffffffffc0200bb2:	d7a50513          	addi	a0,a0,-646 # ffffffffc0201928 <etext+0x286>
ffffffffc0200bb6:	e0cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200bba:	00001697          	auipc	a3,0x1
ffffffffc0200bbe:	db668693          	addi	a3,a3,-586 # ffffffffc0201970 <etext+0x2ce>
ffffffffc0200bc2:	00001617          	auipc	a2,0x1
ffffffffc0200bc6:	d4e60613          	addi	a2,a2,-690 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200bca:	0a400593          	li	a1,164
ffffffffc0200bce:	00001517          	auipc	a0,0x1
ffffffffc0200bd2:	d5a50513          	addi	a0,a0,-678 # ffffffffc0201928 <etext+0x286>
ffffffffc0200bd6:	decff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 3);
ffffffffc0200bda:	00001697          	auipc	a3,0x1
ffffffffc0200bde:	ed668693          	addi	a3,a3,-298 # ffffffffc0201ab0 <etext+0x40e>
ffffffffc0200be2:	00001617          	auipc	a2,0x1
ffffffffc0200be6:	d2e60613          	addi	a2,a2,-722 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200bea:	0a200593          	li	a1,162
ffffffffc0200bee:	00001517          	auipc	a0,0x1
ffffffffc0200bf2:	d3a50513          	addi	a0,a0,-710 # ffffffffc0201928 <etext+0x286>
ffffffffc0200bf6:	dccff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200bfa:	00001697          	auipc	a3,0x1
ffffffffc0200bfe:	e9e68693          	addi	a3,a3,-354 # ffffffffc0201a98 <etext+0x3f6>
ffffffffc0200c02:	00001617          	auipc	a2,0x1
ffffffffc0200c06:	d0e60613          	addi	a2,a2,-754 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200c0a:	09d00593          	li	a1,157
ffffffffc0200c0e:	00001517          	auipc	a0,0x1
ffffffffc0200c12:	d1a50513          	addi	a0,a0,-742 # ffffffffc0201928 <etext+0x286>
ffffffffc0200c16:	dacff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200c1a:	00001697          	auipc	a3,0x1
ffffffffc0200c1e:	e5e68693          	addi	a3,a3,-418 # ffffffffc0201a78 <etext+0x3d6>
ffffffffc0200c22:	00001617          	auipc	a2,0x1
ffffffffc0200c26:	cee60613          	addi	a2,a2,-786 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200c2a:	09400593          	li	a1,148
ffffffffc0200c2e:	00001517          	auipc	a0,0x1
ffffffffc0200c32:	cfa50513          	addi	a0,a0,-774 # ffffffffc0201928 <etext+0x286>
ffffffffc0200c36:	d8cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200c3a:	00001697          	auipc	a3,0x1
ffffffffc0200c3e:	e1e68693          	addi	a3,a3,-482 # ffffffffc0201a58 <etext+0x3b6>
ffffffffc0200c42:	00001617          	auipc	a2,0x1
ffffffffc0200c46:	cce60613          	addi	a2,a2,-818 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200c4a:	09300593          	li	a1,147
ffffffffc0200c4e:	00001517          	auipc	a0,0x1
ffffffffc0200c52:	cda50513          	addi	a0,a0,-806 # ffffffffc0201928 <etext+0x286>
ffffffffc0200c56:	d6cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(count == 0);
ffffffffc0200c5a:	00001697          	auipc	a3,0x1
ffffffffc0200c5e:	f8668693          	addi	a3,a3,-122 # ffffffffc0201be0 <etext+0x53e>
ffffffffc0200c62:	00001617          	auipc	a2,0x1
ffffffffc0200c66:	cae60613          	addi	a2,a2,-850 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200c6a:	10200593          	li	a1,258
ffffffffc0200c6e:	00001517          	auipc	a0,0x1
ffffffffc0200c72:	cba50513          	addi	a0,a0,-838 # ffffffffc0201928 <etext+0x286>
ffffffffc0200c76:	d4cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200c7a:	00001697          	auipc	a3,0x1
ffffffffc0200c7e:	e7e68693          	addi	a3,a3,-386 # ffffffffc0201af8 <etext+0x456>
ffffffffc0200c82:	00001617          	auipc	a2,0x1
ffffffffc0200c86:	c8e60613          	addi	a2,a2,-882 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200c8a:	0f700593          	li	a1,247
ffffffffc0200c8e:	00001517          	auipc	a0,0x1
ffffffffc0200c92:	c9a50513          	addi	a0,a0,-870 # ffffffffc0201928 <etext+0x286>
ffffffffc0200c96:	d2cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200c9a:	00001697          	auipc	a3,0x1
ffffffffc0200c9e:	dfe68693          	addi	a3,a3,-514 # ffffffffc0201a98 <etext+0x3f6>
ffffffffc0200ca2:	00001617          	auipc	a2,0x1
ffffffffc0200ca6:	c6e60613          	addi	a2,a2,-914 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200caa:	0f100593          	li	a1,241
ffffffffc0200cae:	00001517          	auipc	a0,0x1
ffffffffc0200cb2:	c7a50513          	addi	a0,a0,-902 # ffffffffc0201928 <etext+0x286>
ffffffffc0200cb6:	d0cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200cba:	00001697          	auipc	a3,0x1
ffffffffc0200cbe:	f0668693          	addi	a3,a3,-250 # ffffffffc0201bc0 <etext+0x51e>
ffffffffc0200cc2:	00001617          	auipc	a2,0x1
ffffffffc0200cc6:	c4e60613          	addi	a2,a2,-946 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200cca:	0f000593          	li	a1,240
ffffffffc0200cce:	00001517          	auipc	a0,0x1
ffffffffc0200cd2:	c5a50513          	addi	a0,a0,-934 # ffffffffc0201928 <etext+0x286>
ffffffffc0200cd6:	cecff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 + 4 == p1);
ffffffffc0200cda:	00001697          	auipc	a3,0x1
ffffffffc0200cde:	ed668693          	addi	a3,a3,-298 # ffffffffc0201bb0 <etext+0x50e>
ffffffffc0200ce2:	00001617          	auipc	a2,0x1
ffffffffc0200ce6:	c2e60613          	addi	a2,a2,-978 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200cea:	0e800593          	li	a1,232
ffffffffc0200cee:	00001517          	auipc	a0,0x1
ffffffffc0200cf2:	c3a50513          	addi	a0,a0,-966 # ffffffffc0201928 <etext+0x286>
ffffffffc0200cf6:	cccff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(2) != NULL);
ffffffffc0200cfa:	00001697          	auipc	a3,0x1
ffffffffc0200cfe:	e9e68693          	addi	a3,a3,-354 # ffffffffc0201b98 <etext+0x4f6>
ffffffffc0200d02:	00001617          	auipc	a2,0x1
ffffffffc0200d06:	c0e60613          	addi	a2,a2,-1010 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200d0a:	0e700593          	li	a1,231
ffffffffc0200d0e:	00001517          	auipc	a0,0x1
ffffffffc0200d12:	c1a50513          	addi	a0,a0,-998 # ffffffffc0201928 <etext+0x286>
ffffffffc0200d16:	cacff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200d1a:	00001697          	auipc	a3,0x1
ffffffffc0200d1e:	e5e68693          	addi	a3,a3,-418 # ffffffffc0201b78 <etext+0x4d6>
ffffffffc0200d22:	00001617          	auipc	a2,0x1
ffffffffc0200d26:	bee60613          	addi	a2,a2,-1042 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200d2a:	0e600593          	li	a1,230
ffffffffc0200d2e:	00001517          	auipc	a0,0x1
ffffffffc0200d32:	bfa50513          	addi	a0,a0,-1030 # ffffffffc0201928 <etext+0x286>
ffffffffc0200d36:	c8cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200d3a:	00001697          	auipc	a3,0x1
ffffffffc0200d3e:	e0e68693          	addi	a3,a3,-498 # ffffffffc0201b48 <etext+0x4a6>
ffffffffc0200d42:	00001617          	auipc	a2,0x1
ffffffffc0200d46:	bce60613          	addi	a2,a2,-1074 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200d4a:	0e400593          	li	a1,228
ffffffffc0200d4e:	00001517          	auipc	a0,0x1
ffffffffc0200d52:	bda50513          	addi	a0,a0,-1062 # ffffffffc0201928 <etext+0x286>
ffffffffc0200d56:	c6cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200d5a:	00001697          	auipc	a3,0x1
ffffffffc0200d5e:	dd668693          	addi	a3,a3,-554 # ffffffffc0201b30 <etext+0x48e>
ffffffffc0200d62:	00001617          	auipc	a2,0x1
ffffffffc0200d66:	bae60613          	addi	a2,a2,-1106 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200d6a:	0e300593          	li	a1,227
ffffffffc0200d6e:	00001517          	auipc	a0,0x1
ffffffffc0200d72:	bba50513          	addi	a0,a0,-1094 # ffffffffc0201928 <etext+0x286>
ffffffffc0200d76:	c4cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d7a:	00001697          	auipc	a3,0x1
ffffffffc0200d7e:	d1e68693          	addi	a3,a3,-738 # ffffffffc0201a98 <etext+0x3f6>
ffffffffc0200d82:	00001617          	auipc	a2,0x1
ffffffffc0200d86:	b8e60613          	addi	a2,a2,-1138 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200d8a:	0d700593          	li	a1,215
ffffffffc0200d8e:	00001517          	auipc	a0,0x1
ffffffffc0200d92:	b9a50513          	addi	a0,a0,-1126 # ffffffffc0201928 <etext+0x286>
ffffffffc0200d96:	c2cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200d9a:	00001697          	auipc	a3,0x1
ffffffffc0200d9e:	d7e68693          	addi	a3,a3,-642 # ffffffffc0201b18 <etext+0x476>
ffffffffc0200da2:	00001617          	auipc	a2,0x1
ffffffffc0200da6:	b6e60613          	addi	a2,a2,-1170 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200daa:	0ce00593          	li	a1,206
ffffffffc0200dae:	00001517          	auipc	a0,0x1
ffffffffc0200db2:	b7a50513          	addi	a0,a0,-1158 # ffffffffc0201928 <etext+0x286>
ffffffffc0200db6:	c0cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != NULL);
ffffffffc0200dba:	00001697          	auipc	a3,0x1
ffffffffc0200dbe:	d4e68693          	addi	a3,a3,-690 # ffffffffc0201b08 <etext+0x466>
ffffffffc0200dc2:	00001617          	auipc	a2,0x1
ffffffffc0200dc6:	b4e60613          	addi	a2,a2,-1202 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200dca:	0cd00593          	li	a1,205
ffffffffc0200dce:	00001517          	auipc	a0,0x1
ffffffffc0200dd2:	b5a50513          	addi	a0,a0,-1190 # ffffffffc0201928 <etext+0x286>
ffffffffc0200dd6:	becff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200dda:	00001697          	auipc	a3,0x1
ffffffffc0200dde:	d1e68693          	addi	a3,a3,-738 # ffffffffc0201af8 <etext+0x456>
ffffffffc0200de2:	00001617          	auipc	a2,0x1
ffffffffc0200de6:	b2e60613          	addi	a2,a2,-1234 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200dea:	0b100593          	li	a1,177
ffffffffc0200dee:	00001517          	auipc	a0,0x1
ffffffffc0200df2:	b3a50513          	addi	a0,a0,-1222 # ffffffffc0201928 <etext+0x286>
ffffffffc0200df6:	bccff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200dfa:	00001697          	auipc	a3,0x1
ffffffffc0200dfe:	c9e68693          	addi	a3,a3,-866 # ffffffffc0201a98 <etext+0x3f6>
ffffffffc0200e02:	00001617          	auipc	a2,0x1
ffffffffc0200e06:	b0e60613          	addi	a2,a2,-1266 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200e0a:	0af00593          	li	a1,175
ffffffffc0200e0e:	00001517          	auipc	a0,0x1
ffffffffc0200e12:	b1a50513          	addi	a0,a0,-1254 # ffffffffc0201928 <etext+0x286>
ffffffffc0200e16:	bacff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200e1a:	00001697          	auipc	a3,0x1
ffffffffc0200e1e:	cbe68693          	addi	a3,a3,-834 # ffffffffc0201ad8 <etext+0x436>
ffffffffc0200e22:	00001617          	auipc	a2,0x1
ffffffffc0200e26:	aee60613          	addi	a2,a2,-1298 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200e2a:	0ae00593          	li	a1,174
ffffffffc0200e2e:	00001517          	auipc	a0,0x1
ffffffffc0200e32:	afa50513          	addi	a0,a0,-1286 # ffffffffc0201928 <etext+0x286>
ffffffffc0200e36:	b8cff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200e3a <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc0200e3a:	1141                	addi	sp,sp,-16
ffffffffc0200e3c:	e406                	sd	ra,8(sp)
ffffffffc0200e3e:	e022                	sd	s0,0(sp)
    assert(n > 0);
ffffffffc0200e40:	c9b5                	beqz	a1,ffffffffc0200eb4 <best_fit_free_pages+0x7a>
    for (; p != base + n; p ++) {
ffffffffc0200e42:	00259693          	slli	a3,a1,0x2
ffffffffc0200e46:	96ae                	add	a3,a3,a1
ffffffffc0200e48:	068e                	slli	a3,a3,0x3
ffffffffc0200e4a:	96aa                	add	a3,a3,a0
ffffffffc0200e4c:	87aa                	mv	a5,a0
ffffffffc0200e4e:	00a68f63          	beq	a3,a0,ffffffffc0200e6c <best_fit_free_pages+0x32>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e52:	6798                	ld	a4,8(a5)
ffffffffc0200e54:	8b0d                	andi	a4,a4,3
ffffffffc0200e56:	ef1d                	bnez	a4,ffffffffc0200e94 <best_fit_free_pages+0x5a>
        p->flags = p->property = 0;
ffffffffc0200e58:	0007a823          	sw	zero,16(a5)
ffffffffc0200e5c:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200e60:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200e64:	02878793          	addi	a5,a5,40
ffffffffc0200e68:	fef695e3          	bne	a3,a5,ffffffffc0200e52 <best_fit_free_pages+0x18>
    SetPageProperty(base);
ffffffffc0200e6c:	651c                	ld	a5,8(a0)
    base->property = n;
ffffffffc0200e6e:	0005841b          	sext.w	s0,a1
ffffffffc0200e72:	c900                	sw	s0,16(a0)
    SetPageProperty(base);
ffffffffc0200e74:	0027e793          	ori	a5,a5,2
ffffffffc0200e78:	e51c                	sd	a5,8(a0)
    best_fit_insert_block(base);
ffffffffc0200e7a:	f68ff0ef          	jal	ra,ffffffffc02005e2 <best_fit_insert_block>
    nr_free += n;
ffffffffc0200e7e:	00005797          	auipc	a5,0x5
ffffffffc0200e82:	19a78793          	addi	a5,a5,410 # ffffffffc0206018 <free_area>
ffffffffc0200e86:	4b8c                	lw	a1,16(a5)
}
ffffffffc0200e88:	60a2                	ld	ra,8(sp)
    nr_free += n;
ffffffffc0200e8a:	9da1                	addw	a1,a1,s0
}
ffffffffc0200e8c:	6402                	ld	s0,0(sp)
    nr_free += n;
ffffffffc0200e8e:	cb8c                	sw	a1,16(a5)
}
ffffffffc0200e90:	0141                	addi	sp,sp,16
ffffffffc0200e92:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e94:	00001697          	auipc	a3,0x1
ffffffffc0200e98:	d6c68693          	addi	a3,a3,-660 # ffffffffc0201c00 <etext+0x55e>
ffffffffc0200e9c:	00001617          	auipc	a2,0x1
ffffffffc0200ea0:	a7460613          	addi	a2,a2,-1420 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200ea4:	06d00593          	li	a1,109
ffffffffc0200ea8:	00001517          	auipc	a0,0x1
ffffffffc0200eac:	a8050513          	addi	a0,a0,-1408 # ffffffffc0201928 <etext+0x286>
ffffffffc0200eb0:	b12ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200eb4:	00001697          	auipc	a3,0x1
ffffffffc0200eb8:	a5468693          	addi	a3,a3,-1452 # ffffffffc0201908 <etext+0x266>
ffffffffc0200ebc:	00001617          	auipc	a2,0x1
ffffffffc0200ec0:	a5460613          	addi	a2,a2,-1452 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200ec4:	06a00593          	li	a1,106
ffffffffc0200ec8:	00001517          	auipc	a0,0x1
ffffffffc0200ecc:	a6050513          	addi	a0,a0,-1440 # ffffffffc0201928 <etext+0x286>
ffffffffc0200ed0:	af2ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200ed4 <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc0200ed4:	1141                	addi	sp,sp,-16
ffffffffc0200ed6:	e406                	sd	ra,8(sp)
ffffffffc0200ed8:	e022                	sd	s0,0(sp)
    assert(n > 0);
ffffffffc0200eda:	c9b5                	beqz	a1,ffffffffc0200f4e <best_fit_init_memmap+0x7a>
    for (; p != base + n; p ++) {
ffffffffc0200edc:	00259693          	slli	a3,a1,0x2
ffffffffc0200ee0:	96ae                	add	a3,a3,a1
ffffffffc0200ee2:	068e                	slli	a3,a3,0x3
ffffffffc0200ee4:	96aa                	add	a3,a3,a0
ffffffffc0200ee6:	87aa                	mv	a5,a0
ffffffffc0200ee8:	00a68f63          	beq	a3,a0,ffffffffc0200f06 <best_fit_init_memmap+0x32>
        assert(PageReserved(p));
ffffffffc0200eec:	6798                	ld	a4,8(a5)
ffffffffc0200eee:	8b05                	andi	a4,a4,1
ffffffffc0200ef0:	cf1d                	beqz	a4,ffffffffc0200f2e <best_fit_init_memmap+0x5a>
        p->flags = p->property = 0;
ffffffffc0200ef2:	0007a823          	sw	zero,16(a5)
ffffffffc0200ef6:	0007b423          	sd	zero,8(a5)
ffffffffc0200efa:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200efe:	02878793          	addi	a5,a5,40
ffffffffc0200f02:	fef695e3          	bne	a3,a5,ffffffffc0200eec <best_fit_init_memmap+0x18>
    SetPageProperty(base);
ffffffffc0200f06:	651c                	ld	a5,8(a0)
    base->property = n;
ffffffffc0200f08:	0005841b          	sext.w	s0,a1
ffffffffc0200f0c:	c900                	sw	s0,16(a0)
    SetPageProperty(base);
ffffffffc0200f0e:	0027e793          	ori	a5,a5,2
ffffffffc0200f12:	e51c                	sd	a5,8(a0)
    best_fit_insert_block(base);
ffffffffc0200f14:	eceff0ef          	jal	ra,ffffffffc02005e2 <best_fit_insert_block>
    nr_free += n;
ffffffffc0200f18:	00005797          	auipc	a5,0x5
ffffffffc0200f1c:	10078793          	addi	a5,a5,256 # ffffffffc0206018 <free_area>
ffffffffc0200f20:	4b8c                	lw	a1,16(a5)
}
ffffffffc0200f22:	60a2                	ld	ra,8(sp)
    nr_free += n;
ffffffffc0200f24:	9da1                	addw	a1,a1,s0
}
ffffffffc0200f26:	6402                	ld	s0,0(sp)
    nr_free += n;
ffffffffc0200f28:	cb8c                	sw	a1,16(a5)
}
ffffffffc0200f2a:	0141                	addi	sp,sp,16
ffffffffc0200f2c:	8082                	ret
        assert(PageReserved(p));
ffffffffc0200f2e:	00001697          	auipc	a3,0x1
ffffffffc0200f32:	cfa68693          	addi	a3,a3,-774 # ffffffffc0201c28 <etext+0x586>
ffffffffc0200f36:	00001617          	auipc	a2,0x1
ffffffffc0200f3a:	9da60613          	addi	a2,a2,-1574 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200f3e:	03b00593          	li	a1,59
ffffffffc0200f42:	00001517          	auipc	a0,0x1
ffffffffc0200f46:	9e650513          	addi	a0,a0,-1562 # ffffffffc0201928 <etext+0x286>
ffffffffc0200f4a:	a78ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200f4e:	00001697          	auipc	a3,0x1
ffffffffc0200f52:	9ba68693          	addi	a3,a3,-1606 # ffffffffc0201908 <etext+0x266>
ffffffffc0200f56:	00001617          	auipc	a2,0x1
ffffffffc0200f5a:	9ba60613          	addi	a2,a2,-1606 # ffffffffc0201910 <etext+0x26e>
ffffffffc0200f5e:	03800593          	li	a1,56
ffffffffc0200f62:	00001517          	auipc	a0,0x1
ffffffffc0200f66:	9c650513          	addi	a0,a0,-1594 # ffffffffc0201928 <etext+0x286>
ffffffffc0200f6a:	a58ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200f6e <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200f6e:	00005797          	auipc	a5,0x5
ffffffffc0200f72:	0ea7b783          	ld	a5,234(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc0200f76:	6f9c                	ld	a5,24(a5)
ffffffffc0200f78:	8782                	jr	a5

ffffffffc0200f7a <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200f7a:	00005797          	auipc	a5,0x5
ffffffffc0200f7e:	0de7b783          	ld	a5,222(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc0200f82:	739c                	ld	a5,32(a5)
ffffffffc0200f84:	8782                	jr	a5

ffffffffc0200f86 <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc0200f86:	00005797          	auipc	a5,0x5
ffffffffc0200f8a:	0d27b783          	ld	a5,210(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc0200f8e:	779c                	ld	a5,40(a5)
ffffffffc0200f90:	8782                	jr	a5

ffffffffc0200f92 <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200f92:	00001797          	auipc	a5,0x1
ffffffffc0200f96:	cbe78793          	addi	a5,a5,-834 # ffffffffc0201c50 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200f9a:	638c                	ld	a1,0(a5)
    cprintf("Managed range: [0x%016lx, 0x%016lx), npage = %lu, free pages = %lu\n",
            mem_base, mem_end, npage, n);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0200f9c:	7139                	addi	sp,sp,-64
ffffffffc0200f9e:	f04a                	sd	s2,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200fa0:	00001517          	auipc	a0,0x1
ffffffffc0200fa4:	ce850513          	addi	a0,a0,-792 # ffffffffc0201c88 <best_fit_pmm_manager+0x38>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200fa8:	00005917          	auipc	s2,0x5
ffffffffc0200fac:	0b090913          	addi	s2,s2,176 # ffffffffc0206058 <pmm_manager>
void pmm_init(void) {
ffffffffc0200fb0:	fc06                	sd	ra,56(sp)
ffffffffc0200fb2:	f426                	sd	s1,40(sp)
ffffffffc0200fb4:	f822                	sd	s0,48(sp)
ffffffffc0200fb6:	ec4e                	sd	s3,24(sp)
ffffffffc0200fb8:	e852                	sd	s4,16(sp)
ffffffffc0200fba:	e456                	sd	s5,8(sp)
ffffffffc0200fbc:	e05a                	sd	s6,0(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200fbe:	00f93023          	sd	a5,0(s2)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200fc2:	98aff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc0200fc6:	00093783          	ld	a5,0(s2)
ffffffffc0200fca:	679c                	ld	a5,8(a5)
ffffffffc0200fcc:	9782                	jalr	a5
    uint64_t mem_base = get_memory_base();
ffffffffc0200fce:	deeff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0200fd2:	84aa                	mv	s1,a0
    uint64_t mem_size = get_memory_size();
ffffffffc0200fd4:	df2ff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_size == 0 || mem_base < DRAM_BASE) {
ffffffffc0200fd8:	1a050263          	beqz	a0,ffffffffc020117c <pmm_init+0x1ea>
ffffffffc0200fdc:	800007b7          	lui	a5,0x80000
ffffffffc0200fe0:	fff7c793          	not	a5,a5
ffffffffc0200fe4:	1897fc63          	bgeu	a5,s1,ffffffffc020117c <pmm_init+0x1ea>
    uint64_t mem_end = mem_base + mem_size;
ffffffffc0200fe8:	00a48433          	add	s0,s1,a0
ffffffffc0200fec:	8aaa                	mv	s5,a0
    if (mem_end < mem_base) {
ffffffffc0200fee:	1e946863          	bltu	s0,s1,ffffffffc02011de <pmm_init+0x24c>
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc0200ff2:	47c5                	li	a5,17
ffffffffc0200ff4:	07ee                	slli	a5,a5,0x1b
ffffffffc0200ff6:	1487e763          	bltu	a5,s0,ffffffffc0201144 <pmm_init+0x1b2>
ffffffffc0200ffa:	787d                	lui	a6,0xfffff
ffffffffc0200ffc:	01047433          	and	s0,s0,a6
    if (mem_end <= mem_base) {
ffffffffc0201000:	1c84f363          	bgeu	s1,s0,ffffffffc02011c6 <pmm_init+0x234>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc0201004:	00006697          	auipc	a3,0x6
ffffffffc0201008:	07368693          	addi	a3,a3,115 # ffffffffc0207077 <end+0xfff>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc020100c:	57f5                	li	a5,-3
ffffffffc020100e:	07fa                	slli	a5,a5,0x1e
ffffffffc0201010:	0106f6b3          	and	a3,a3,a6
ffffffffc0201014:	00005997          	auipc	s3,0x5
ffffffffc0201018:	05c98993          	addi	s3,s3,92 # ffffffffc0206070 <va_pa_offset>
    npage = PPN(mem_end);
ffffffffc020101c:	00c45893          	srli	a7,s0,0xc
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201020:	00f9b023          	sd	a5,0(s3)
    npage = PPN(mem_end);
ffffffffc0201024:	00005a17          	auipc	s4,0x5
ffffffffc0201028:	024a0a13          	addi	s4,s4,36 # ffffffffc0206048 <npage>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020102c:	00005797          	auipc	a5,0x5
ffffffffc0201030:	02d7b223          	sd	a3,36(a5) # ffffffffc0206050 <pages>
    size_t nr_pages = npage - nbase;
ffffffffc0201034:	fff80637          	lui	a2,0xfff80
    npage = PPN(mem_end);
ffffffffc0201038:	011a3023          	sd	a7,0(s4)
    uintptr_t pages_pa = PADDR((uintptr_t)pages);
ffffffffc020103c:	c02007b7          	lui	a5,0xc0200
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc0201040:	8536                	mv	a0,a3
    size_t nr_pages = npage - nbase;
ffffffffc0201042:	9646                	add	a2,a2,a7
    uintptr_t pages_pa = PADDR((uintptr_t)pages);
ffffffffc0201044:	16f6e563          	bltu	a3,a5,ffffffffc02011ae <pmm_init+0x21c>
    uintptr_t pages_end = pages_pa + nr_pages * sizeof(struct Page);
ffffffffc0201048:	00261793          	slli	a5,a2,0x2
    uintptr_t pages_pa = PADDR((uintptr_t)pages);
ffffffffc020104c:	470d                	li	a4,3
    uintptr_t pages_end = pages_pa + nr_pages * sizeof(struct Page);
ffffffffc020104e:	97b2                	add	a5,a5,a2
    uintptr_t pages_pa = PADDR((uintptr_t)pages);
ffffffffc0201050:	077a                	slli	a4,a4,0x1e
ffffffffc0201052:	9736                	add	a4,a4,a3
    uintptr_t pages_end = pages_pa + nr_pages * sizeof(struct Page);
ffffffffc0201054:	078e                	slli	a5,a5,0x3
ffffffffc0201056:	97ba                	add	a5,a5,a4
    if (pages_pa < mem_base || pages_end > mem_end) {
ffffffffc0201058:	10976663          	bltu	a4,s1,ffffffffc0201164 <pmm_init+0x1d2>
ffffffffc020105c:	10f46463          	bltu	s0,a5,ffffffffc0201164 <pmm_init+0x1d2>
    uintptr_t freemem = ROUNDUP(pages_end, PGSIZE);
ffffffffc0201060:	6705                	lui	a4,0x1
ffffffffc0201062:	177d                	addi	a4,a4,-1
ffffffffc0201064:	97ba                	add	a5,a5,a4
ffffffffc0201066:	0107f833          	and	a6,a5,a6
    for (size_t i = 0; i < nr_pages; i++) {
ffffffffc020106a:	ce79                	beqz	a2,ffffffffc0201148 <pmm_init+0x1b6>
ffffffffc020106c:	00289713          	slli	a4,a7,0x2
ffffffffc0201070:	9746                	add	a4,a4,a7
ffffffffc0201072:	fec007b7          	lui	a5,0xfec00
ffffffffc0201076:	070e                	slli	a4,a4,0x3
ffffffffc0201078:	97b6                	add	a5,a5,a3
ffffffffc020107a:	973e                	add	a4,a4,a5
        SetPageReserved(pages + i);
ffffffffc020107c:	669c                	ld	a5,8(a3)
ffffffffc020107e:	0006a023          	sw	zero,0(a3)
    for (size_t i = 0; i < nr_pages; i++) {
ffffffffc0201082:	02868693          	addi	a3,a3,40
        SetPageReserved(pages + i);
ffffffffc0201086:	0017e793          	ori	a5,a5,1
ffffffffc020108a:	fef6b023          	sd	a5,-32(a3)
    for (size_t i = 0; i < nr_pages; i++) {
ffffffffc020108e:	fed717e3          	bne	a4,a3,ffffffffc020107c <pmm_init+0xea>
    if (freemem >= mem_end) {
ffffffffc0201092:	0a887d63          	bgeu	a6,s0,ffffffffc020114c <pmm_init+0x1ba>
    size_t n = (mem_end - freemem) / PGSIZE;
ffffffffc0201096:	41040b33          	sub	s6,s0,a6
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc020109a:	00c85813          	srli	a6,a6,0xc
ffffffffc020109e:	00cb5b13          	srli	s6,s6,0xc
ffffffffc02010a2:	15187a63          	bgeu	a6,a7,ffffffffc02011f6 <pmm_init+0x264>
    pmm_manager->init_memmap(base, n);
ffffffffc02010a6:	00093703          	ld	a4,0(s2)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc02010aa:	fff807b7          	lui	a5,0xfff80
ffffffffc02010ae:	983e                	add	a6,a6,a5
ffffffffc02010b0:	00281793          	slli	a5,a6,0x2
ffffffffc02010b4:	983e                	add	a6,a6,a5
ffffffffc02010b6:	6b1c                	ld	a5,16(a4)
ffffffffc02010b8:	080e                	slli	a6,a6,0x3
ffffffffc02010ba:	9542                	add	a0,a0,a6
ffffffffc02010bc:	85da                	mv	a1,s6
ffffffffc02010be:	9782                	jalr	a5
    cprintf("Physical memory: base = 0x%016lx, size = 0x%016lx (%lu MB)\n",
ffffffffc02010c0:	014ad693          	srli	a3,s5,0x14
ffffffffc02010c4:	8656                	mv	a2,s5
ffffffffc02010c6:	85a6                	mv	a1,s1
ffffffffc02010c8:	00001517          	auipc	a0,0x1
ffffffffc02010cc:	d5850513          	addi	a0,a0,-680 # ffffffffc0201e20 <best_fit_pmm_manager+0x1d0>
ffffffffc02010d0:	87cff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Managed range: [0x%016lx, 0x%016lx), npage = %lu, free pages = %lu\n",
ffffffffc02010d4:	000a3683          	ld	a3,0(s4)
ffffffffc02010d8:	85a6                	mv	a1,s1
ffffffffc02010da:	875a                	mv	a4,s6
ffffffffc02010dc:	8622                	mv	a2,s0
ffffffffc02010de:	00001517          	auipc	a0,0x1
ffffffffc02010e2:	d8250513          	addi	a0,a0,-638 # ffffffffc0201e60 <best_fit_pmm_manager+0x210>
ffffffffc02010e6:	866ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc02010ea:	00093783          	ld	a5,0(s2)
ffffffffc02010ee:	7b9c                	ld	a5,48(a5)
ffffffffc02010f0:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02010f2:	00001517          	auipc	a0,0x1
ffffffffc02010f6:	db650513          	addi	a0,a0,-586 # ffffffffc0201ea8 <best_fit_pmm_manager+0x258>
ffffffffc02010fa:	852ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02010fe:	00004597          	auipc	a1,0x4
ffffffffc0201102:	f0258593          	addi	a1,a1,-254 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc0201106:	00005797          	auipc	a5,0x5
ffffffffc020110a:	f6b7b123          	sd	a1,-158(a5) # ffffffffc0206068 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc020110e:	c02007b7          	lui	a5,0xc0200
ffffffffc0201112:	08f5e163          	bltu	a1,a5,ffffffffc0201194 <pmm_init+0x202>
ffffffffc0201116:	0009b603          	ld	a2,0(s3)
}
ffffffffc020111a:	7442                	ld	s0,48(sp)
ffffffffc020111c:	70e2                	ld	ra,56(sp)
ffffffffc020111e:	74a2                	ld	s1,40(sp)
ffffffffc0201120:	7902                	ld	s2,32(sp)
ffffffffc0201122:	69e2                	ld	s3,24(sp)
ffffffffc0201124:	6a42                	ld	s4,16(sp)
ffffffffc0201126:	6aa2                	ld	s5,8(sp)
ffffffffc0201128:	6b02                	ld	s6,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc020112a:	40c58633          	sub	a2,a1,a2
ffffffffc020112e:	00005797          	auipc	a5,0x5
ffffffffc0201132:	f2c7b923          	sd	a2,-206(a5) # ffffffffc0206060 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201136:	00001517          	auipc	a0,0x1
ffffffffc020113a:	d9250513          	addi	a0,a0,-622 # ffffffffc0201ec8 <best_fit_pmm_manager+0x278>
}
ffffffffc020113e:	6121                	addi	sp,sp,64
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201140:	80cff06f          	j	ffffffffc020014c <cprintf>
    mem_end = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc0201144:	843e                	mv	s0,a5
ffffffffc0201146:	bd55                	j	ffffffffc0200ffa <pmm_init+0x68>
    if (freemem >= mem_end) {
ffffffffc0201148:	0a886763          	bltu	a6,s0,ffffffffc02011f6 <pmm_init+0x264>
        panic("page_init: no free physical memory after kernel and Page array");
ffffffffc020114c:	00001617          	auipc	a2,0x1
ffffffffc0201150:	c6460613          	addi	a2,a2,-924 # ffffffffc0201db0 <best_fit_pmm_manager+0x160>
ffffffffc0201154:	08900593          	li	a1,137
ffffffffc0201158:	00001517          	auipc	a0,0x1
ffffffffc020115c:	b8050513          	addi	a0,a0,-1152 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc0201160:	862ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("page_init: Page array does not fit in physical memory");
ffffffffc0201164:	00001617          	auipc	a2,0x1
ffffffffc0201168:	c1460613          	addi	a2,a2,-1004 # ffffffffc0201d78 <best_fit_pmm_manager+0x128>
ffffffffc020116c:	07800593          	li	a1,120
ffffffffc0201170:	00001517          	auipc	a0,0x1
ffffffffc0201174:	b6850513          	addi	a0,a0,-1176 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc0201178:	84aff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("page_init: invalid physical memory range from DTB");
ffffffffc020117c:	00001617          	auipc	a2,0x1
ffffffffc0201180:	b2460613          	addi	a2,a2,-1244 # ffffffffc0201ca0 <best_fit_pmm_manager+0x50>
ffffffffc0201184:	05400593          	li	a1,84
ffffffffc0201188:	00001517          	auipc	a0,0x1
ffffffffc020118c:	b5050513          	addi	a0,a0,-1200 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc0201190:	832ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201194:	86ae                	mv	a3,a1
ffffffffc0201196:	00001617          	auipc	a2,0x1
ffffffffc020119a:	bba60613          	addi	a2,a2,-1094 # ffffffffc0201d50 <best_fit_pmm_manager+0x100>
ffffffffc020119e:	0aa00593          	li	a1,170
ffffffffc02011a2:	00001517          	auipc	a0,0x1
ffffffffc02011a6:	b3650513          	addi	a0,a0,-1226 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc02011aa:	818ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t pages_pa = PADDR((uintptr_t)pages);
ffffffffc02011ae:	00001617          	auipc	a2,0x1
ffffffffc02011b2:	ba260613          	addi	a2,a2,-1118 # ffffffffc0201d50 <best_fit_pmm_manager+0x100>
ffffffffc02011b6:	07500593          	li	a1,117
ffffffffc02011ba:	00001517          	auipc	a0,0x1
ffffffffc02011be:	b1e50513          	addi	a0,a0,-1250 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc02011c2:	800ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("page_init: no manageable physical memory from DTB");
ffffffffc02011c6:	00001617          	auipc	a2,0x1
ffffffffc02011ca:	b5260613          	addi	a2,a2,-1198 # ffffffffc0201d18 <best_fit_pmm_manager+0xc8>
ffffffffc02011ce:	06500593          	li	a1,101
ffffffffc02011d2:	00001517          	auipc	a0,0x1
ffffffffc02011d6:	b0650513          	addi	a0,a0,-1274 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc02011da:	fe9fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("page_init: physical memory range overflows");
ffffffffc02011de:	00001617          	auipc	a2,0x1
ffffffffc02011e2:	b0a60613          	addi	a2,a2,-1270 # ffffffffc0201ce8 <best_fit_pmm_manager+0x98>
ffffffffc02011e6:	05a00593          	li	a1,90
ffffffffc02011ea:	00001517          	auipc	a0,0x1
ffffffffc02011ee:	aee50513          	addi	a0,a0,-1298 # ffffffffc0201cd8 <best_fit_pmm_manager+0x88>
ffffffffc02011f2:	fd1fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc02011f6:	00001617          	auipc	a2,0x1
ffffffffc02011fa:	bfa60613          	addi	a2,a2,-1030 # ffffffffc0201df0 <best_fit_pmm_manager+0x1a0>
ffffffffc02011fe:	06a00593          	li	a1,106
ffffffffc0201202:	00001517          	auipc	a0,0x1
ffffffffc0201206:	c0e50513          	addi	a0,a0,-1010 # ffffffffc0201e10 <best_fit_pmm_manager+0x1c0>
ffffffffc020120a:	fb9fe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020120e <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc020120e:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201212:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201214:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201218:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc020121a:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020121e:	f022                	sd	s0,32(sp)
ffffffffc0201220:	ec26                	sd	s1,24(sp)
ffffffffc0201222:	e84a                	sd	s2,16(sp)
ffffffffc0201224:	f406                	sd	ra,40(sp)
ffffffffc0201226:	e44e                	sd	s3,8(sp)
ffffffffc0201228:	84aa                	mv	s1,a0
ffffffffc020122a:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc020122c:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0201230:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0201232:	03067e63          	bgeu	a2,a6,ffffffffc020126e <printnum+0x60>
ffffffffc0201236:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0201238:	00805763          	blez	s0,ffffffffc0201246 <printnum+0x38>
ffffffffc020123c:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc020123e:	85ca                	mv	a1,s2
ffffffffc0201240:	854e                	mv	a0,s3
ffffffffc0201242:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201244:	fc65                	bnez	s0,ffffffffc020123c <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201246:	1a02                	slli	s4,s4,0x20
ffffffffc0201248:	00001797          	auipc	a5,0x1
ffffffffc020124c:	cc078793          	addi	a5,a5,-832 # ffffffffc0201f08 <best_fit_pmm_manager+0x2b8>
ffffffffc0201250:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201254:	9a3e                	add	s4,s4,a5
}
ffffffffc0201256:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201258:	000a4503          	lbu	a0,0(s4)
}
ffffffffc020125c:	70a2                	ld	ra,40(sp)
ffffffffc020125e:	69a2                	ld	s3,8(sp)
ffffffffc0201260:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201262:	85ca                	mv	a1,s2
ffffffffc0201264:	87a6                	mv	a5,s1
}
ffffffffc0201266:	6942                	ld	s2,16(sp)
ffffffffc0201268:	64e2                	ld	s1,24(sp)
ffffffffc020126a:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020126c:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc020126e:	03065633          	divu	a2,a2,a6
ffffffffc0201272:	8722                	mv	a4,s0
ffffffffc0201274:	f9bff0ef          	jal	ra,ffffffffc020120e <printnum>
ffffffffc0201278:	b7f9                	j	ffffffffc0201246 <printnum+0x38>

ffffffffc020127a <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc020127a:	7119                	addi	sp,sp,-128
ffffffffc020127c:	f4a6                	sd	s1,104(sp)
ffffffffc020127e:	f0ca                	sd	s2,96(sp)
ffffffffc0201280:	ecce                	sd	s3,88(sp)
ffffffffc0201282:	e8d2                	sd	s4,80(sp)
ffffffffc0201284:	e4d6                	sd	s5,72(sp)
ffffffffc0201286:	e0da                	sd	s6,64(sp)
ffffffffc0201288:	fc5e                	sd	s7,56(sp)
ffffffffc020128a:	f06a                	sd	s10,32(sp)
ffffffffc020128c:	fc86                	sd	ra,120(sp)
ffffffffc020128e:	f8a2                	sd	s0,112(sp)
ffffffffc0201290:	f862                	sd	s8,48(sp)
ffffffffc0201292:	f466                	sd	s9,40(sp)
ffffffffc0201294:	ec6e                	sd	s11,24(sp)
ffffffffc0201296:	892a                	mv	s2,a0
ffffffffc0201298:	84ae                	mv	s1,a1
ffffffffc020129a:	8d32                	mv	s10,a2
ffffffffc020129c:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020129e:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc02012a2:	5b7d                	li	s6,-1
ffffffffc02012a4:	00001a97          	auipc	s5,0x1
ffffffffc02012a8:	c98a8a93          	addi	s5,s5,-872 # ffffffffc0201f3c <best_fit_pmm_manager+0x2ec>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02012ac:	00001b97          	auipc	s7,0x1
ffffffffc02012b0:	e6cb8b93          	addi	s7,s7,-404 # ffffffffc0202118 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012b4:	000d4503          	lbu	a0,0(s10)
ffffffffc02012b8:	001d0413          	addi	s0,s10,1
ffffffffc02012bc:	01350a63          	beq	a0,s3,ffffffffc02012d0 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc02012c0:	c121                	beqz	a0,ffffffffc0201300 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc02012c2:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012c4:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc02012c6:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012c8:	fff44503          	lbu	a0,-1(s0)
ffffffffc02012cc:	ff351ae3          	bne	a0,s3,ffffffffc02012c0 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012d0:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc02012d4:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc02012d8:	4c81                	li	s9,0
ffffffffc02012da:	4881                	li	a7,0
        width = precision = -1;
ffffffffc02012dc:	5c7d                	li	s8,-1
ffffffffc02012de:	5dfd                	li	s11,-1
ffffffffc02012e0:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc02012e4:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012e6:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02012ea:	0ff5f593          	zext.b	a1,a1
ffffffffc02012ee:	00140d13          	addi	s10,s0,1
ffffffffc02012f2:	04b56263          	bltu	a0,a1,ffffffffc0201336 <vprintfmt+0xbc>
ffffffffc02012f6:	058a                	slli	a1,a1,0x2
ffffffffc02012f8:	95d6                	add	a1,a1,s5
ffffffffc02012fa:	4194                	lw	a3,0(a1)
ffffffffc02012fc:	96d6                	add	a3,a3,s5
ffffffffc02012fe:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0201300:	70e6                	ld	ra,120(sp)
ffffffffc0201302:	7446                	ld	s0,112(sp)
ffffffffc0201304:	74a6                	ld	s1,104(sp)
ffffffffc0201306:	7906                	ld	s2,96(sp)
ffffffffc0201308:	69e6                	ld	s3,88(sp)
ffffffffc020130a:	6a46                	ld	s4,80(sp)
ffffffffc020130c:	6aa6                	ld	s5,72(sp)
ffffffffc020130e:	6b06                	ld	s6,64(sp)
ffffffffc0201310:	7be2                	ld	s7,56(sp)
ffffffffc0201312:	7c42                	ld	s8,48(sp)
ffffffffc0201314:	7ca2                	ld	s9,40(sp)
ffffffffc0201316:	7d02                	ld	s10,32(sp)
ffffffffc0201318:	6de2                	ld	s11,24(sp)
ffffffffc020131a:	6109                	addi	sp,sp,128
ffffffffc020131c:	8082                	ret
            padc = '0';
ffffffffc020131e:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0201320:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201324:	846a                	mv	s0,s10
ffffffffc0201326:	00140d13          	addi	s10,s0,1
ffffffffc020132a:	fdd6059b          	addiw	a1,a2,-35
ffffffffc020132e:	0ff5f593          	zext.b	a1,a1
ffffffffc0201332:	fcb572e3          	bgeu	a0,a1,ffffffffc02012f6 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201336:	85a6                	mv	a1,s1
ffffffffc0201338:	02500513          	li	a0,37
ffffffffc020133c:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc020133e:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201342:	8d22                	mv	s10,s0
ffffffffc0201344:	f73788e3          	beq	a5,s3,ffffffffc02012b4 <vprintfmt+0x3a>
ffffffffc0201348:	ffed4783          	lbu	a5,-2(s10)
ffffffffc020134c:	1d7d                	addi	s10,s10,-1
ffffffffc020134e:	ff379de3          	bne	a5,s3,ffffffffc0201348 <vprintfmt+0xce>
ffffffffc0201352:	b78d                	j	ffffffffc02012b4 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201354:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0201358:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020135c:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc020135e:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201362:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201366:	02d86463          	bltu	a6,a3,ffffffffc020138e <vprintfmt+0x114>
                ch = *fmt;
ffffffffc020136a:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc020136e:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201372:	0186873b          	addw	a4,a3,s8
ffffffffc0201376:	0017171b          	slliw	a4,a4,0x1
ffffffffc020137a:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc020137c:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201380:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201382:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201386:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020138a:	fed870e3          	bgeu	a6,a3,ffffffffc020136a <vprintfmt+0xf0>
            if (width < 0)
ffffffffc020138e:	f40ddce3          	bgez	s11,ffffffffc02012e6 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201392:	8de2                	mv	s11,s8
ffffffffc0201394:	5c7d                	li	s8,-1
ffffffffc0201396:	bf81                	j	ffffffffc02012e6 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201398:	fffdc693          	not	a3,s11
ffffffffc020139c:	96fd                	srai	a3,a3,0x3f
ffffffffc020139e:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013a2:	00144603          	lbu	a2,1(s0)
ffffffffc02013a6:	2d81                	sext.w	s11,s11
ffffffffc02013a8:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02013aa:	bf35                	j	ffffffffc02012e6 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc02013ac:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013b0:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc02013b4:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013b6:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc02013b8:	bfd9                	j	ffffffffc020138e <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc02013ba:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02013bc:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013c0:	01174463          	blt	a4,a7,ffffffffc02013c8 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc02013c4:	1a088e63          	beqz	a7,ffffffffc0201580 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc02013c8:	000a3603          	ld	a2,0(s4)
ffffffffc02013cc:	46c1                	li	a3,16
ffffffffc02013ce:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc02013d0:	2781                	sext.w	a5,a5
ffffffffc02013d2:	876e                	mv	a4,s11
ffffffffc02013d4:	85a6                	mv	a1,s1
ffffffffc02013d6:	854a                	mv	a0,s2
ffffffffc02013d8:	e37ff0ef          	jal	ra,ffffffffc020120e <printnum>
            break;
ffffffffc02013dc:	bde1                	j	ffffffffc02012b4 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc02013de:	000a2503          	lw	a0,0(s4)
ffffffffc02013e2:	85a6                	mv	a1,s1
ffffffffc02013e4:	0a21                	addi	s4,s4,8
ffffffffc02013e6:	9902                	jalr	s2
            break;
ffffffffc02013e8:	b5f1                	j	ffffffffc02012b4 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02013ea:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02013ec:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013f0:	01174463          	blt	a4,a7,ffffffffc02013f8 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc02013f4:	18088163          	beqz	a7,ffffffffc0201576 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc02013f8:	000a3603          	ld	a2,0(s4)
ffffffffc02013fc:	46a9                	li	a3,10
ffffffffc02013fe:	8a2e                	mv	s4,a1
ffffffffc0201400:	bfc1                	j	ffffffffc02013d0 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201402:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201406:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201408:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020140a:	bdf1                	j	ffffffffc02012e6 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc020140c:	85a6                	mv	a1,s1
ffffffffc020140e:	02500513          	li	a0,37
ffffffffc0201412:	9902                	jalr	s2
            break;
ffffffffc0201414:	b545                	j	ffffffffc02012b4 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201416:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc020141a:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020141c:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020141e:	b5e1                	j	ffffffffc02012e6 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0201420:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201422:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201426:	01174463          	blt	a4,a7,ffffffffc020142e <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc020142a:	14088163          	beqz	a7,ffffffffc020156c <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc020142e:	000a3603          	ld	a2,0(s4)
ffffffffc0201432:	46a1                	li	a3,8
ffffffffc0201434:	8a2e                	mv	s4,a1
ffffffffc0201436:	bf69                	j	ffffffffc02013d0 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0201438:	03000513          	li	a0,48
ffffffffc020143c:	85a6                	mv	a1,s1
ffffffffc020143e:	e03e                	sd	a5,0(sp)
ffffffffc0201440:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201442:	85a6                	mv	a1,s1
ffffffffc0201444:	07800513          	li	a0,120
ffffffffc0201448:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc020144a:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc020144c:	6782                	ld	a5,0(sp)
ffffffffc020144e:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201450:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201454:	bfb5                	j	ffffffffc02013d0 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201456:	000a3403          	ld	s0,0(s4)
ffffffffc020145a:	008a0713          	addi	a4,s4,8
ffffffffc020145e:	e03a                	sd	a4,0(sp)
ffffffffc0201460:	14040263          	beqz	s0,ffffffffc02015a4 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201464:	0fb05763          	blez	s11,ffffffffc0201552 <vprintfmt+0x2d8>
ffffffffc0201468:	02d00693          	li	a3,45
ffffffffc020146c:	0cd79163          	bne	a5,a3,ffffffffc020152e <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201470:	00044783          	lbu	a5,0(s0)
ffffffffc0201474:	0007851b          	sext.w	a0,a5
ffffffffc0201478:	cf85                	beqz	a5,ffffffffc02014b0 <vprintfmt+0x236>
ffffffffc020147a:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020147e:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201482:	000c4563          	bltz	s8,ffffffffc020148c <vprintfmt+0x212>
ffffffffc0201486:	3c7d                	addiw	s8,s8,-1
ffffffffc0201488:	036c0263          	beq	s8,s6,ffffffffc02014ac <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc020148c:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020148e:	0e0c8e63          	beqz	s9,ffffffffc020158a <vprintfmt+0x310>
ffffffffc0201492:	3781                	addiw	a5,a5,-32
ffffffffc0201494:	0ef47b63          	bgeu	s0,a5,ffffffffc020158a <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201498:	03f00513          	li	a0,63
ffffffffc020149c:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020149e:	000a4783          	lbu	a5,0(s4)
ffffffffc02014a2:	3dfd                	addiw	s11,s11,-1
ffffffffc02014a4:	0a05                	addi	s4,s4,1
ffffffffc02014a6:	0007851b          	sext.w	a0,a5
ffffffffc02014aa:	ffe1                	bnez	a5,ffffffffc0201482 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc02014ac:	01b05963          	blez	s11,ffffffffc02014be <vprintfmt+0x244>
ffffffffc02014b0:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc02014b2:	85a6                	mv	a1,s1
ffffffffc02014b4:	02000513          	li	a0,32
ffffffffc02014b8:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc02014ba:	fe0d9be3          	bnez	s11,ffffffffc02014b0 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02014be:	6a02                	ld	s4,0(sp)
ffffffffc02014c0:	bbd5                	j	ffffffffc02012b4 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02014c2:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02014c4:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc02014c8:	01174463          	blt	a4,a7,ffffffffc02014d0 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc02014cc:	08088d63          	beqz	a7,ffffffffc0201566 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc02014d0:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc02014d4:	0a044d63          	bltz	s0,ffffffffc020158e <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc02014d8:	8622                	mv	a2,s0
ffffffffc02014da:	8a66                	mv	s4,s9
ffffffffc02014dc:	46a9                	li	a3,10
ffffffffc02014de:	bdcd                	j	ffffffffc02013d0 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc02014e0:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02014e4:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc02014e6:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc02014e8:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc02014ec:	8fb5                	xor	a5,a5,a3
ffffffffc02014ee:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02014f2:	02d74163          	blt	a4,a3,ffffffffc0201514 <vprintfmt+0x29a>
ffffffffc02014f6:	00369793          	slli	a5,a3,0x3
ffffffffc02014fa:	97de                	add	a5,a5,s7
ffffffffc02014fc:	639c                	ld	a5,0(a5)
ffffffffc02014fe:	cb99                	beqz	a5,ffffffffc0201514 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201500:	86be                	mv	a3,a5
ffffffffc0201502:	00001617          	auipc	a2,0x1
ffffffffc0201506:	a3660613          	addi	a2,a2,-1482 # ffffffffc0201f38 <best_fit_pmm_manager+0x2e8>
ffffffffc020150a:	85a6                	mv	a1,s1
ffffffffc020150c:	854a                	mv	a0,s2
ffffffffc020150e:	0ce000ef          	jal	ra,ffffffffc02015dc <printfmt>
ffffffffc0201512:	b34d                	j	ffffffffc02012b4 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201514:	00001617          	auipc	a2,0x1
ffffffffc0201518:	a1460613          	addi	a2,a2,-1516 # ffffffffc0201f28 <best_fit_pmm_manager+0x2d8>
ffffffffc020151c:	85a6                	mv	a1,s1
ffffffffc020151e:	854a                	mv	a0,s2
ffffffffc0201520:	0bc000ef          	jal	ra,ffffffffc02015dc <printfmt>
ffffffffc0201524:	bb41                	j	ffffffffc02012b4 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201526:	00001417          	auipc	s0,0x1
ffffffffc020152a:	9fa40413          	addi	s0,s0,-1542 # ffffffffc0201f20 <best_fit_pmm_manager+0x2d0>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020152e:	85e2                	mv	a1,s8
ffffffffc0201530:	8522                	mv	a0,s0
ffffffffc0201532:	e43e                	sd	a5,8(sp)
ffffffffc0201534:	0fc000ef          	jal	ra,ffffffffc0201630 <strnlen>
ffffffffc0201538:	40ad8dbb          	subw	s11,s11,a0
ffffffffc020153c:	01b05b63          	blez	s11,ffffffffc0201552 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201540:	67a2                	ld	a5,8(sp)
ffffffffc0201542:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201546:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0201548:	85a6                	mv	a1,s1
ffffffffc020154a:	8552                	mv	a0,s4
ffffffffc020154c:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020154e:	fe0d9ce3          	bnez	s11,ffffffffc0201546 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201552:	00044783          	lbu	a5,0(s0)
ffffffffc0201556:	00140a13          	addi	s4,s0,1
ffffffffc020155a:	0007851b          	sext.w	a0,a5
ffffffffc020155e:	d3a5                	beqz	a5,ffffffffc02014be <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201560:	05e00413          	li	s0,94
ffffffffc0201564:	bf39                	j	ffffffffc0201482 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201566:	000a2403          	lw	s0,0(s4)
ffffffffc020156a:	b7ad                	j	ffffffffc02014d4 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc020156c:	000a6603          	lwu	a2,0(s4)
ffffffffc0201570:	46a1                	li	a3,8
ffffffffc0201572:	8a2e                	mv	s4,a1
ffffffffc0201574:	bdb1                	j	ffffffffc02013d0 <vprintfmt+0x156>
ffffffffc0201576:	000a6603          	lwu	a2,0(s4)
ffffffffc020157a:	46a9                	li	a3,10
ffffffffc020157c:	8a2e                	mv	s4,a1
ffffffffc020157e:	bd89                	j	ffffffffc02013d0 <vprintfmt+0x156>
ffffffffc0201580:	000a6603          	lwu	a2,0(s4)
ffffffffc0201584:	46c1                	li	a3,16
ffffffffc0201586:	8a2e                	mv	s4,a1
ffffffffc0201588:	b5a1                	j	ffffffffc02013d0 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc020158a:	9902                	jalr	s2
ffffffffc020158c:	bf09                	j	ffffffffc020149e <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc020158e:	85a6                	mv	a1,s1
ffffffffc0201590:	02d00513          	li	a0,45
ffffffffc0201594:	e03e                	sd	a5,0(sp)
ffffffffc0201596:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201598:	6782                	ld	a5,0(sp)
ffffffffc020159a:	8a66                	mv	s4,s9
ffffffffc020159c:	40800633          	neg	a2,s0
ffffffffc02015a0:	46a9                	li	a3,10
ffffffffc02015a2:	b53d                	j	ffffffffc02013d0 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc02015a4:	03b05163          	blez	s11,ffffffffc02015c6 <vprintfmt+0x34c>
ffffffffc02015a8:	02d00693          	li	a3,45
ffffffffc02015ac:	f6d79de3          	bne	a5,a3,ffffffffc0201526 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc02015b0:	00001417          	auipc	s0,0x1
ffffffffc02015b4:	97040413          	addi	s0,s0,-1680 # ffffffffc0201f20 <best_fit_pmm_manager+0x2d0>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02015b8:	02800793          	li	a5,40
ffffffffc02015bc:	02800513          	li	a0,40
ffffffffc02015c0:	00140a13          	addi	s4,s0,1
ffffffffc02015c4:	bd6d                	j	ffffffffc020147e <vprintfmt+0x204>
ffffffffc02015c6:	00001a17          	auipc	s4,0x1
ffffffffc02015ca:	95ba0a13          	addi	s4,s4,-1701 # ffffffffc0201f21 <best_fit_pmm_manager+0x2d1>
ffffffffc02015ce:	02800513          	li	a0,40
ffffffffc02015d2:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02015d6:	05e00413          	li	s0,94
ffffffffc02015da:	b565                	j	ffffffffc0201482 <vprintfmt+0x208>

ffffffffc02015dc <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015dc:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc02015de:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015e2:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02015e4:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015e6:	ec06                	sd	ra,24(sp)
ffffffffc02015e8:	f83a                	sd	a4,48(sp)
ffffffffc02015ea:	fc3e                	sd	a5,56(sp)
ffffffffc02015ec:	e0c2                	sd	a6,64(sp)
ffffffffc02015ee:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc02015f0:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02015f2:	c89ff0ef          	jal	ra,ffffffffc020127a <vprintfmt>
}
ffffffffc02015f6:	60e2                	ld	ra,24(sp)
ffffffffc02015f8:	6161                	addi	sp,sp,80
ffffffffc02015fa:	8082                	ret

ffffffffc02015fc <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02015fc:	4781                	li	a5,0
ffffffffc02015fe:	00005717          	auipc	a4,0x5
ffffffffc0201602:	a1273703          	ld	a4,-1518(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201606:	88ba                	mv	a7,a4
ffffffffc0201608:	852a                	mv	a0,a0
ffffffffc020160a:	85be                	mv	a1,a5
ffffffffc020160c:	863e                	mv	a2,a5
ffffffffc020160e:	00000073          	ecall
ffffffffc0201612:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201614:	8082                	ret

ffffffffc0201616 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201616:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc020161a:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc020161c:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc020161e:	cb81                	beqz	a5,ffffffffc020162e <strlen+0x18>
        cnt ++;
ffffffffc0201620:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201622:	00a707b3          	add	a5,a4,a0
ffffffffc0201626:	0007c783          	lbu	a5,0(a5)
ffffffffc020162a:	fbfd                	bnez	a5,ffffffffc0201620 <strlen+0xa>
ffffffffc020162c:	8082                	ret
    }
    return cnt;
}
ffffffffc020162e:	8082                	ret

ffffffffc0201630 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201630:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201632:	e589                	bnez	a1,ffffffffc020163c <strnlen+0xc>
ffffffffc0201634:	a811                	j	ffffffffc0201648 <strnlen+0x18>
        cnt ++;
ffffffffc0201636:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201638:	00f58863          	beq	a1,a5,ffffffffc0201648 <strnlen+0x18>
ffffffffc020163c:	00f50733          	add	a4,a0,a5
ffffffffc0201640:	00074703          	lbu	a4,0(a4)
ffffffffc0201644:	fb6d                	bnez	a4,ffffffffc0201636 <strnlen+0x6>
ffffffffc0201646:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201648:	852e                	mv	a0,a1
ffffffffc020164a:	8082                	ret

ffffffffc020164c <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020164c:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201650:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201654:	cb89                	beqz	a5,ffffffffc0201666 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201656:	0505                	addi	a0,a0,1
ffffffffc0201658:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020165a:	fee789e3          	beq	a5,a4,ffffffffc020164c <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020165e:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201662:	9d19                	subw	a0,a0,a4
ffffffffc0201664:	8082                	ret
ffffffffc0201666:	4501                	li	a0,0
ffffffffc0201668:	bfed                	j	ffffffffc0201662 <strcmp+0x16>

ffffffffc020166a <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020166a:	c20d                	beqz	a2,ffffffffc020168c <strncmp+0x22>
ffffffffc020166c:	962e                	add	a2,a2,a1
ffffffffc020166e:	a031                	j	ffffffffc020167a <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201670:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201672:	00e79a63          	bne	a5,a4,ffffffffc0201686 <strncmp+0x1c>
ffffffffc0201676:	00b60b63          	beq	a2,a1,ffffffffc020168c <strncmp+0x22>
ffffffffc020167a:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc020167e:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201680:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201684:	f7f5                	bnez	a5,ffffffffc0201670 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201686:	40e7853b          	subw	a0,a5,a4
}
ffffffffc020168a:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020168c:	4501                	li	a0,0
ffffffffc020168e:	8082                	ret

ffffffffc0201690 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201690:	ca01                	beqz	a2,ffffffffc02016a0 <memset+0x10>
ffffffffc0201692:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201694:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201696:	0785                	addi	a5,a5,1
ffffffffc0201698:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc020169c:	fec79de3          	bne	a5,a2,ffffffffc0201696 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc02016a0:	8082                	ret
