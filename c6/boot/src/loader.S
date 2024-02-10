%include "boot.inc"
SECTION LOADER vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP	equ	LOADER_BASE_ADDR

jmp loader_start 
; 构建 gdt，gdt 本质上是一段内存区域，每 8 个字节一个表项，即段描述符
; dd 指令定义双字，一个字 = 两个字节，所有 dd 就是定义 4 个字节
; 规定 第 0 个表项没有用，所以全部定义为 0

; 程序编译后的地址从上往下是越来越高的，所以上面 dd 命令定义的是段描述符的低 4 字节，
; 下面 dd 命令定义的是段描述符的高 4 字节。
GDT_BASE:
    dd 0x00000000
    dd 0x00000000

CODE_DESC:
    dd 0x0000ffff ; 段描述符的低 4 字节
    dd DESC_CODE_HIGH4 ; 段描述符的高 4 字节

DATA_STACK_DESC:
    dd 0x0000ffff ; 段描述符的低 4 字节
    dd DESC_DATA_HIGH4 ; 段描述符的高 4 字节

VIDEO_DESC:
	dd	0x80000007	;limit=(0xbffff - 0xb8000)/4k = 7
	dd	DESC_VIDEO_HIGH4;此时dpl为0

GDT_SIZE	equ	$ - GDT_BASE	;获取 GDT 大小
GDT_LIMIT	equ	GDT_SIZE - 1	;获取 段界限

times	60	dq	0	;预留60个空位，为以后填入中断描述符表和任务状态段TSS描述符留空间
				;times 60 表示后面的内容循环60次，是nasm提供的伪指令

SELECTOR_CODE 	equ	(0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA 	equ	(0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO 	equ	(0x0003 << 3) + TI_GDT + RPL0

;以下是 gdt 指针，前2字节是gdt界限，后4字节是gdt起始地址
gdt_ptr	dw	GDT_LIMIT
	dd	GDT_BASE

loadermsg db '2 loader in real.'

;---------------------------------------------------------
;INT 0x10	功能号:0x13	功能描述符:打印字符串
;---------------------------------------------------------
;输入:
;AH 子功能号=13H
;BH = 页码
;BL = 属性（若AL=00H或01H）
;CX = 字符串长度
;(DH,DL)=坐标(行，列)
;ES:BP=字符串地址
;AL=显示输出方式
;0——字符串中只含显示字符，其显示属性在BL中。显示后，光标位置不变
;1——字符串中只含显示字符，其显示属性在BL中。显示后，光标位置改变
;2——字符串中只含显示字符和显示属性。显示后，光标位置不变。
;3——字符串中只含显示字符和显示属性。显示后，光标位置改变。
;无返回值


loader_start:
	;显示字符串，表示当前在实模式
	mov sp, LOADER_BASE_ADDR
	mov bp, loadermsg	;ES:BP 字符串地址
	mov cx, 17		;字符串长度
	mov ax, 0x1301		;AH=13h，AL=01h
	mov bx, 0x001f		;页号为0（BH=0h），蓝底粉红字（BL=1fh）
	mov dx, 0x1800		;
	int 0x10		;int 10 BIOS中断

;----启用 保护模式----
	;1.打开A20地址线
	in al, 0x92
	or al, 00000010B
	out 0x92, al

	;2.加载GDT
	lgdt [gdt_ptr]

	;3.将CR0的PE位置1
	mov eax, cr0
	or eax, 0x00000001
	mov cr0, eax

	jmp dword SELECTOR_CODE:p_mode_start	;刷新流水线
						;流水线是CPU 的工作方式，会把当前指令和后面的几个指令同时放在流水线中重叠执行，由于之前的代码是16位，接下来的代码变成32位了，指令按照16位进行译码会出错，通过刷新流水线可以解决这个问题

[bits 32]
p_mode_start:
	;初始化为32位的段寄存器
	mov ax, SELECTOR_DATA
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov esp, LOADER_STACK_TOP

	;显示“P”到屏幕上
	mov ax, SELECTOR_VIDEO
	mov gs, ax
	mov byte [gs:160],'P'

;----加载 kernel----
	mov eax, KERNEL_START_SECTOR	;kernel.bin所在的扇区号
	mov ebx, KERNEL_BIN_BASE_ADDR	;从硬盘读出后写入的地址
	mov ecx, 200			;读入的扇区数
	
	call rd_disk_m_32		;从硬盘读取文件到内存，上面eax，ebx，ecx是参数

;----启用 分页机制----

	;创建页目录和页表并初始化页内存位图
	call setup_page

;-------- 创建页目录和页表 --------
setup_page:

;把页目录所占空间清0, 一个页目录表有 1024 个页目录项，每个页目录占 4B，所以一个页目录表就占 4096B
	mov ecx, 4096
	xor esi, esi
.clear_page_dir:
	mov byte [PAGE_DIR_TABLE_POS + esi], 0
	inc esi
	loop .clear_page_dir

; 开始创建页目录项，这个页目录表起始地址是在 0x100000,这个地址是任选的，只要可用就行
    mov eax, PAGE_DIR_TABLE_POS
    这里让页表和页目录表紧挨着，因为页目录表本身大小是 4K，所以第一个

























;----读取文件到内存----
;参数
;eax ：扇区号
;ebx ：待读入的地址
;ecx ：读入的扇区数

rd_disk_m_32:
        mov esi ,eax    ;备份eax
        mov di ,cx      ;备份cx

;读写硬盘
;1---设置要读取的扇区数
        mov dx ,0x1f2   ;设置端口号，dx用来存储端口号的
        mov al ,cl
        out dx ,al      ;读取的扇区数

        mov eax ,esi    ;恢复eax


;2---将LBA地址存入0x1f3～0x1f6
        ;LBA 7～0位写入端口0x1f3
        mov dx ,0x1f3
        out dx ,al

        ;LBA 15~8位写入端口0x1f4
        mov cl ,8
        shr eax ,cl     ;逻辑右移8位,将eax的最低8位移掉，让最低8位al的值变成接下来8位
        mov dx ,0x1f4
        out dx ,al

        ;LBA 24～16位写入端口0x1f5
        shr eax ,cl
        mov dx ,0x1f5
        out dx ,al

        shr eax ,cl
        and al ,0x0f    ;设置lba 24～27位
        or al ,0xe0     ;设置7～4位是1110表示LBA模式
        mov dx ,0x1f6
        out dx ,al

;3---向0x1f7端口写入读命令0x20
        mov dx ,0x1f7
        mov al ,0x20
        out dx ,al

;4---检测硬盘状态
.not_ready:
        ;同写入命令端口，读取时标示硬盘状态，写入时是命令
        nop
        in al ,dx
        and al ,0x88    ;第三位为1表示已经准备好了，第7位为1表示硬盘忙
        cmp al ,0x08
        jnz .not_ready

;5---0x1f0端口读取数据
        mov ax ,di      ;要读取的扇区数
        mov dx ,256     ;一个扇区512字节，一次读取2字节，需要读取256次
        mul dx          ;结果放在ax里
        mov cx ,ax      ;要读取的次数

        mov dx ,0x1f0
.go_on_read:
        in ax, dx
        mov [ebx], ax    ;bx是要读取到的内存地址
        add ebx, 0x02
        loop .go_on_read        ;循环cx次
        ret
