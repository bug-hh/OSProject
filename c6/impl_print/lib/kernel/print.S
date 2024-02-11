TI_GDT	equ	0
RPL0	equ	0

SELECTOR_VIDEO	equ	(0x0003 << 3) + TI_GDT + RPL0

[bits 32]
section .text 
put_int_buff dq 0

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
  out dx, al  ; 设置坐标高八位
  
  mov dx, 0x3d5
  mov al, bh 
  out dx, al 
  
  mov dx, 0x3d4
  mov al, 0xf 
  out dx, al  ; 设置坐标低八位
  
  mov dx, 0x3d5
  mov al, bl 
  out dx, al 
  
.put_char_done:
	popad
	ret

global put_str
put_str:
  push ebx 
  push ecx 
  xor ecx, ecx 
  ; 这里 12 是指前面两个 push 命令以及 put_str 的返回地址（4个字节）
  ; 因为压栈后，esp 是减小的
  mov ebx, [esp + 12]
.goon:
  mov cl, [ebx]
  cmp cl, 0   ; 遇到字符串尾，直接结束
  jz .str_over
  push ecx  ; 给 put_char 传递参数
  call put_char
  add esp, 4
  inc ebx
  jmp .goon
  

.str_over:
  pop ecx 
  pop ebx
  ret

global put_int
put_int:
  pushad 
  mov edi, 7
  mov ebp, esp 
  ; 36 = pushad 的 8 个寄存器 + put_int 的返回地址
  ; 获取 put_int 入参
  mov eax, [esp+36] 
  mov edx, eax 
.base16_4:
  ; 获取 1 位十六进制数
  and edx, 0x0000000F
  cmp edx, 9
  ; 如果超过 9，那就要打印 A-F
  jg .A2F
  add dl, '0'
  jmp .store
.A2F:
  sub dl, 'A'
  add dl, 'A'
.store:
  mov [put_int_buff+edi], dl 
  ; 取下一个 16 进制数
  shr eax, 4
  mov edx, eax 
  dec edi 
  cmp edi, 0
  jge .base16_4
  
  ; 程序执行到这里，put_int_buff 里已经装好了转换成 16 进制的数
  ; 现在要做的是去掉前面多余的 0，比如 000123 变成 123
  ; 现在 edi == -1, 把它变成 0
  xor edi, edi 
.skip_zero:
  cmp edi, 8
  jz .full_zero
  mov cl, [put_int_buff + edi]
  cmp cl, '0'
  inc edi 
  jz .skip_zero
  ; 代码执行到这里，表示原来 edi 所指的位置不为 0，但是现在 edi 又加 1 了，所以要减回去
  dec edi 
  jmp .print_one_char
.full_zero:
  mov edi, 7
.print_one_char:
  xor ecx, ecx ; 把 ecx 清空
  mov cl, [put_int_buff + edi]
  push ecx 
  call put_char
  add esp, 4
  inc edi
  cmp edi, 8
  jl .print_one_char
  popad 
  ret 
  
  
  
  