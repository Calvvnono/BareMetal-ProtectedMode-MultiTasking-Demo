; ==========================================
; pmtest2.asm
; 编译方法：nasm pmtest2.asm -o pmtest2.com
; ==========================================

; 这段代码的主要功能是从实模式切换到保护模式，并在保护模式下执行一些操作后再切换回实模式。以下是代码的详细功能总结：
; 1. **初始化段描述符**：
;     - 初始化16位代码段描述符、32位代码段描述符、数据段描述符和堆栈段描述符。通过计算段基址并将其写入描述符表，确保在保护模式下正确访问内存。
; 2. **准备加载全局描述符表寄存器（GDTR）**：
;     - 计算GDT的基址并将其存入`GdtPtr`，为加载GDTR作准备。
; 3. **加载GDTR**：
;     - 使用`lgdt`指令加载GDTR，将GDT的基址和界限加载到GDTR中。
; 4. **关闭中断**：
;     - 使用`cli`指令关闭中断，确保在切换模式时不会被中断打断。
; 5. **打开地址线A20**：
;     - 通过操作端口`92h`打开地址线A20，以便访问1MB以上的内存。

; 6. **切换到保护模式**：
;     - 设置CR0寄存器的PE位（保护模式启用位），将处理器切换到保护模式。
;     - 使用远跳转指令`jmp dword SelectorCode32:0`，将32位代码段选择子加载到CS寄存器，并跳转到保护模式下的代码段。
; 7. **保护模式下的操作**：
;     - 在保护模式下执行一些操作（如显示字符等），具体操作在代码中未完全展示。
; 8. **切换回实模式**：
;     - 在保护模式下执行完操作后，通过设置段寄存器和CR0寄存器，切换回实模式。
;     - 使用远跳转指令`jmp 0:LABEL_REAL_ENTRY`，跳转到实模式下的代码段。
; 9. **实模式下的操作**：
;     - 在实模式下继续执行一些操作（如设置段寄存器等），具体操作在代码中未完全展示。
; 总结：这段代码实现了从实模式到保护模式的切换，并在保护模式下执行一些操作后再切换回实模式。通过初始化段描述符、加载GDTR、关闭中断、打开地址线A20、设置CR0寄存器等步骤，确保在切换过程中正确设置和访问内存。

%include	"pm.inc"	; 常量, 宏, 以及一些说明

org	0100h
	jmp	LABEL_BEGIN	; 跳转到程序开始位置

[SECTION .gdt]
; GDT
;                                         段基址,       段界限     , 属性
LABEL_GDT:		Descriptor	       0,                 0, 0     		; 空描述符
LABEL_DESC_NORMAL:	Descriptor	       0,            0ffffh, DA_DRW		; Normal 描述符
LABEL_DESC_CODE32:	Descriptor	       0,  SegCode32Len - 1, DA_C + DA_32	; 非一致代码段, 32
LABEL_DESC_CODE16:	Descriptor	       0,            0ffffh, DA_C		; 非一致代码段, 16
LABEL_DESC_DATA:	Descriptor	       0,	DataLen - 1, DA_DRW		; Data
LABEL_DESC_STACK:	Descriptor	       0,        TopOfStack, DA_DRWA + DA_32	; Stack, 32 位
LABEL_DESC_TEST:	Descriptor	0500000h,            0ffffh, DA_DRW
LABEL_DESC_VIDEO:	Descriptor	 0B8000h,            0ffffh, DA_DRW		; 显存首地址
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorTest		equ	LABEL_DESC_TEST		- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
SPValueInRealMode	dw	0
; 字符串
PMMessage:		db	"In Protect Mode now. ^-^", 0	; 进入保护模式后显示此字符串
OffsetPMMessage		equ	PMMessage - $$
StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
OffsetStrTest		equ	StrTest - $$
DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]


; 全局堆栈段
[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
	times 512 db 0

TopOfStack	equ	$ - LABEL_STACK - 1

; END of [SECTION .gs]


[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax	; 设置数据段寄存器
	mov	es, ax	; 设置附加段寄存器
	mov	ss, ax	; 设置堆栈段寄存器
	mov	sp, 0100h	; 设置堆栈指针

	; 保存返回实模式的段寄存器和堆栈指针
	mov	[LABEL_GO_BACK_TO_REAL+3], ax
	mov	[SPValueInRealMode], sp

	; 初始化 16 位代码段描述符，这里的代码段描述符是为了跳回实模式而设置的
	mov	ax, cs
	movzx eax, ax 							; eax = 0x0000xxxx
	shl	eax, 4 								; 段选择子左移4位，得到段基址
	add	eax, LABEL_SEG_CODE16 				; 加上段内偏移，得到完整的段基址
	mov	word [LABEL_DESC_CODE16 + 2], ax 	; 将段基址的低16位存入描述符
	shr	eax, 16 							; 将段基址右移16位，得到高位部分
	mov	byte [LABEL_DESC_CODE16 + 4], al 	; 将段基址的中间8位存入描述符
	mov	byte [LABEL_DESC_CODE16 + 7], ah 	; 将段基址的高8位存入描述符

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
	mov	ax, cs
	mov	ds, ax	; 设置数据段寄存器
	mov	es, ax	; 设置附加段寄存器
	mov	ss, ax	; 设置堆栈段寄存器

	mov	sp, [SPValueInRealMode]

	in	al, 92h		; ┓
	and	al, 11111101b	; ┣ 关闭 A20 地址线
	out	92h, al		; ┛

	sti			; 开中断

	mov	ax, 4c00h	; ┓
	int	21h		; ┛回到 DOS
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	ax, SelectorTest
	mov	es, ax			; 测试段选择子
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子

	mov	ax, SelectorStack
	mov	ss, ax			; 堆栈段选择子

	mov	esp, TopOfStack

	; 下面显示一个字符串
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetPMMessage	; 源数据偏移
	mov	edi, (80 * 10 + 0) * 2	; 目的数据偏移。屏幕第 10 行, 第 0 列。
	cld
.1:
	lodsb
	test	al, al
	jz	.2
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1
.2:	; 显示完毕

	call	DispReturn

	call	TestRead
	call	TestWrite
	call	TestRead

	; 到此停止
	jmp	SelectorCode16:0

; ------------------------------------------------------------------------
TestRead:
	xor	esi, esi
	mov	ecx, 8
.loop
	mov	al, [es:esi]
	call	DispAL
	inc	esi
	loop	.loop

	call	DispReturn

	ret
; TestRead 结束-----------------------------------------------------------


; ------------------------------------------------------------------------
TestWrite:
	push	esi
	push	edi
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetStrTest	; 源数据偏移
	cld
.1:
	lodsb
	test	al, al
	jz	.2
	mov	[es:edi], al
	inc	edi
	jmp	.1
.2:

	pop	edi
	pop	esi

	ret
; TestWrite 结束----------------------------------------------------------


; ------------------------------------------------------------------------
; 显示 AL 中的数字
; 默认地:
;	数字已经存在 AL 中
;	edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;	ax, edi
; ------------------------------------------------------------------------
DispAL:
	push	ecx
	push	edx

	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	dl, al
	shr	al, 4
	mov	ecx, 2
.begin:
	and	al, 01111b
	cmp	al, 9
	ja	.1
	add	al, '0'
	jmp	.2
.1:
	sub	al, 0Ah
	add	al, 'A'
.2:
	mov	[gs:edi], ax
	add	edi, 2

	mov	al, dl
	loop	.begin
	add	edi, 2

	pop	edx
	pop	ecx

	ret
; DispAL 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
DispReturn:
	push	eax
	push	ebx
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	ebx
	pop	eax

	ret
; DispReturn 结束---------------------------------------------------------

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]


; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN	32
[BITS	16]
; LABEL_SEG_CODE16 是一个标签，表示 16 位代码段的起始地址。
; 在初始化段描述符时，通过 add eax, LABEL_SEG_CODE16 将这个地址(段内偏移)加到段基址中，以便正确设置段描述符
LABEL_SEG_CODE16:
	; 跳回实模式:
	mov	ax, SelectorNormal
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and	al, 11111110b
	mov	cr0, eax

LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值

Code16Len	equ	$ - LABEL_SEG_CODE16

; END of [SECTION .s16code]
