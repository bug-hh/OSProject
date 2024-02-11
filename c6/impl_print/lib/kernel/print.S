TI_GDT	equ	0
RPL0	equ	0

SELECTOR_VIDEO	equ	(0x0003 << 3) + TI_GDT + RPL0

[bits 32]
section .text 

; 在汇编语言中，用 global 修饰的函数，可以被外部调用
global put_char
put_char:
  pushad	;备份32位寄存器环境
	
	;保险起见，每次打印都给 gs 寄存器赋值
	mov ax, SELECTOR_VIDEO
	mov gs, ax
  
  ; 获取光标位置
  ; 先获取光标位置的高 8 位
  mov dx, 0x3d4  ; 0x3d4 表示当前寄存器类型是【地址寄存器】
  mov al, 0x0e   ; 
  out dx, al     ; 往这个寄存器里写入数字 e，表示要获取当前光标的高 8 位
  mov dx, 0x3d5  ; 0x3d5 表示当前寄存器类型是【数据寄存器】
  in al, dx      ; 将 当前光标的高 8 位 存到 al 里
  mov ah, al    
  
  ; 先获取光标位置的低 8 位
  mov dx, 0x3d4  ; 0x3d4 表示当前寄存器类型是【地址寄存器】
  mov al, 0x0f   ; 
  out dx, al     ; 往这个寄存器里写入数字 f，表示要获取当前光标的低 8 位
  mov dx, 0x3d5  ; 0x3d5 表示当前寄存器类型是【数据寄存器】
  in al, dx      ; 将 当前光标的高 8 位 存到 al 里
  
  ; 现在 ax 里已经存了当前光标位置
  ; 将光标位置存入 bx
  mov bx, ax
  
  ;在栈中获取待打印字符
	mov ecx, [esp + 36]	;pushad 压入 4*8=32 字节，主调函数返回地址 4 字节，所以 +36
  
  ;判断是不是控制字符
	cmp cl, 0x0d		;CR 是 0x0d 回车符
	jz .is_carriage_return
	cmp cl, 0x0a		;LF 是 0x0a 换行符
	jz .is_line_feed
	cmp cl, 0x8		;BS 是 0x08 退格符
	jz .is_backspace
	
	jmp .put_other
  
.is_backspace:
  dec bx 
  shl bx, 1
  mov byte [gs:bx], 0x20
  inc bx 
  mov byte [gs:bx], 0x07
  shr bx, 1
  jmp .set_cursor
  
; 输入字符处理
.put_other:
	shl bx, 1
	
	mov [gs:bx], cl		;cl里存放的是待打印的 ascii 码
	inc bx
	mov byte [gs:bx], 0x07	;字符属性
	shr bx, 1
	inc bx

	cmp bx, 2000
	jl .set_cursor		;若光标值小于2000，则没有写满，则设置新的光标值，反之则换行
  
; 换行/回车处理
.is_line_feed:
.is_carriage_return:	
; \r \n 都按 \n处理，光标切换到下一行的行首
; 这里的处理是：将光标移动到当前行首
	xor dx, dx		;dx是被除数的高 16 位
	mov ax, bx		;ax是被除数的低 16 位
	mov si, 80		
	div si			;光标位置除 80 的余数便是取整
	sub bx, dx		;dx里存放的是余数

.is_carriage_return_end:
; 将光标移动到下一行的同位置
	add bx, 80
	cmp bx, 2000

.is_line_feed_end:
	jl .set_cursor

; 滚屏处理
.roll_screen:
	;先将1-24行搬运到0-23行里
  cld
  mov ecx, 960		;2000-80=1920，1920*2=3840 个字节要搬运，一次搬运4字节，搬运 3840/4=960 次
	mov esi, 0xc00b80a0	;第1行行首
	mov edi, 0xc00b8000	;第0行行首, b8000 文本模式的显示适配器的内存地址
	rep movsd
  
  mov ebx, 3840
  mov ecx, 80
  
.cls:
	mov word [gs:ebx], 0x0720	;0x0720是黑底白字的空格
	add ebx, 2
	loop .cls
	mov bx, 1920			;将光标重置到24行行首
  
.set_cursor:
  mov dx, 0x3d4
  mov al, 0xe
  mov dx, al  ; 设置坐标高八位
  
  mov dx, 0x3d5
  mov al, bh 
  out dx, al 
  
  mov dx, 0x3d4
  mov al, 0xf 
  mov dx, al  ; 设置坐标低八位
  
  mov dx, 0x3d5
  mov al, bl 
  out dx, al 
  
.put_char_done:
	popad
	ret


  