%include "pm.inc"

; Page directory base addresses for 4 tasks
PageDirBase0		equ	200000h	; Page directory start address: 2M
PageTblBase0		equ	201000h	; Page table start address: 2M + 4K
PageDirBase1		equ	210000h
PageTblBase1		equ	211000h
PageDirBase2		equ	220000h
PageTblBase2		equ	221000h
PageDirBase3		equ	230000h
PageTblBase3		equ	231000h

org 0100h
jmp StartUp

[SECTION .gdt]
;                                      Base,       Limit     , Attribute
LABEL_GDT:		Descriptor	       0,                 0, 0
LABEL_DESC_NORMAL:	Descriptor	       0,            0ffffh, DA_DRW
LABEL_DESC_FLAT_C:	Descriptor             0,           0fffffh, DA_CR | DA_32 | DA_LIMIT_4K
LABEL_DESC_FLAT_RW:	Descriptor             0,           0fffffh, DA_DRW | DA_LIMIT_4K
LABEL_DESC_CODE32:	Descriptor	       0,  SegCode32Len - 1, DA_CR | DA_32
LABEL_DESC_CODE16:	Descriptor	       0,            0ffffh, DA_C
LABEL_DESC_DATA:	Descriptor	       0,	DataLen - 1, DA_DRW
LABEL_DESC_STACK:	Descriptor	       0,        TopOfStack, DA_DRWA | DA_32
LABEL_DESC_VIDEO:	Descriptor	 0B8000h,            0ffffh, DA_DRW + DA_DPL3
; TSS
LABEL_DESC_TSS0: 	Descriptor 			0,          TSS0Len-1, DA_386TSS
LABEL_DESC_TSS1: 	Descriptor 			0,          TSS1Len-1, DA_386TSS
LABEL_DESC_TSS2: 	Descriptor 			0,          TSS2Len-1, DA_386TSS
LABEL_DESC_TSS3: 	Descriptor 			0,          TSS3Len-1, DA_386TSS

; LDT Descriptors for tasks
LABEL_TASK0_DESC_LDT:    Descriptor         0,   TASK0LDTLen - 1, DA_LDT
LABEL_TASK1_DESC_LDT:    Descriptor         0,   TASK1LDTLen - 1, DA_LDT
LABEL_TASK2_DESC_LDT:    Descriptor         0,   TASK2LDTLen - 1, DA_LDT
LABEL_TASK3_DESC_LDT:    Descriptor         0,   TASK3LDTLen - 1, DA_LDT

GdtLen		equ	$ - LABEL_GDT
GdtPtr		dw	GdtLen - 1
dd	0		; GDT base address

; GDT Selectors
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorFlatC		equ	LABEL_DESC_FLAT_C	- LABEL_GDT
SelectorFlatRW		equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; TSS Selectors
SelectorTSS0        equ LABEL_DESC_TSS0     		- LABEL_GDT
SelectorTSS1        equ LABEL_DESC_TSS1     		- LABEL_GDT
SelectorTSS2        equ LABEL_DESC_TSS2     		- LABEL_GDT
SelectorTSS3        equ LABEL_DESC_TSS3     		- LABEL_GDT
SelectorLDT0        equ LABEL_TASK0_DESC_LDT   	- LABEL_GDT
SelectorLDT1        equ LABEL_TASK1_DESC_LDT    - LABEL_GDT
SelectorLDT2        equ LABEL_TASK2_DESC_LDT    - LABEL_GDT
SelectorLDT3        equ LABEL_TASK3_DESC_LDT 	- LABEL_GDT

; LDT and Task Definitions
; ---------------------------------------------------------------------------------------------
DefineTask 0, "VERY", 15, 0Bh
DefineTask 1, "LOVE", 15, 0Ch
DefineTask 2, "HUST", 15, 0Dh
DefineTask 3, "MRSU", 15, 0Eh

[SECTION .idt]
ALIGN	32
[BITS	32]
LABEL_IDT:
; Gate	Selector, Offset, DCount, Attribute
%rep 32
Gate	SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.020h:			Gate	SelectorCode32,    ClockHandler,      0, DA_386IGate
%rep 95
Gate	SelectorCode32, SpuriousHandler,      0, DA_386IGate
%endrep
.080h:			Gate	SelectorCode32,  UserIntHandler,      0, DA_386IGate

IdtLen		equ	$ - LABEL_IDT
IdtPtr		dw	IdtLen - 1
dd	0				; IDT Base Address

[SECTION .data1]	 ; Data segment
ALIGN	32
[BITS	32]
LABEL_DATA:
; Symbols used in real mode
_szPMMessage:			db	"Shenyu Dai - U202212021 - Level4", 0Ah, 0Ah, 0
_szMemChkTitle:			db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize			db	"RAM size:", 0
_szReturn			db	0Ah, 0
_szReadyMessage:			db	"Multitasking Output:", 0
; Variables
_wSPValueInRealMode		dw	0
_dwMCRNumber:			dd	0	; Memory Check Result
_dwDispPos:			dd	(80 * 0 + 0) * 2	; Screen position
_dwMemSize:			dd	0
_ARDStruct:			; Address Range Descriptor Structure
_dwBaseAddrLow:		dd	0
_dwBaseAddrHigh:	dd	0
_dwLengthLow:		dd	0
_dwLengthHigh:		dd	0
_dwType:		dd	0
_PageTableNumber:		dd	0
_SavedIDTR:			dd	0	; Save IDTR
dd	0
_SavedIMREG:			db	0	; Interrupt Mask Register value
_MemChkBuf:	times	256	db	0

%define ticks  20
_RunningTask:			dd	0
_TaskPriority:			dd	16*ticks, 10*ticks, 8*ticks, 6*ticks
_LeftTicks:			dd	0, 0, 0, 0

; Symbols used in protected mode
szPMMessage		equ	_szPMMessage	- $$
szMemChkTitle		equ	_szMemChkTitle	- $$
szRAMSize		equ	_szRAMSize	- $$
szReturn		equ	_szReturn	- $$
szReadyMessage  equ _szReadyMessage - $$
dwDispPos		equ	_dwDispPos	- $$
dwMemSize		equ	_dwMemSize	- $$
dwMCRNumber		equ	_dwMCRNumber	- $$
ARDStruct		equ	_ARDStruct	- $$
dwBaseAddrLow	equ	_dwBaseAddrLow	- $$
dwBaseAddrHigh	equ	_dwBaseAddrHigh	- $$
dwLengthLow	equ	_dwLengthLow	- $$
dwLengthHigh	equ	_dwLengthHigh	- $$
dwType		equ	_dwType		- $$
MemChkBuf		equ	_MemChkBuf	- $$
SavedIDTR		equ	_SavedIDTR	- $$
SavedIMREG		equ	_SavedIMREG	- $$
PageTableNumber		equ	_PageTableNumber- $$
; Task related variables
RunningTask     equ _RunningTask - $$
TaskPriority    equ _TaskPriority - $$
LeftTicks       equ _LeftTicks - $$
DataLen			equ	$ - LABEL_DATA

[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
times 512 db 0

TopOfStack	equ	$ - LABEL_STACK - 1

[SECTION .s16]
[BITS	16]
StartUp:
; Preparation
mov	ax, cs
mov	ds, ax
mov	es, ax
mov	ss, ax
mov	sp, 0100h
mov	[LABEL_GO_BACK_TO_REAL+3], ax
mov	[_wSPValueInRealMode], sp
; Get memory size
mov	ebx, 0
mov	di, _MemChkBuf
.loop:
mov	eax, 0E820h
mov	ecx, 20
mov	edx, 0534D4150h
int	15h
jc	LABEL_MEM_CHK_FAIL
add	di, 20
inc	dword [_dwMCRNumber]
cmp	ebx, 0
jne	.loop
jmp	LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
mov	dword [_dwMCRNumber], 0
LABEL_MEM_CHK_OK:

; Initialize global descriptors
InitDescBase LABEL_SEG_CODE16,LABEL_DESC_CODE16
InitDescBase LABEL_SEG_CODE32,LABEL_DESC_CODE32
InitDescBase LABEL_DATA, LABEL_DESC_DATA
InitDescBase LABEL_STACK, LABEL_DESC_STACK
; Initialize task descriptors
InitTaskDescBase 0
InitTaskDescBase 1
InitTaskDescBase 2
InitTaskDescBase 3
; Prepare to load GDTR
mov	eax, ds
shl	eax, 4
add	eax, LABEL_GDT		; eax <- gdt base address
mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt base address
; Prepare to load IDTR
mov	eax, ds
shl	eax, 4
add	eax, LABEL_IDT		; eax <- idt base address
mov	dword [IdtPtr + 2], eax	; [IdtPtr + 2] <- idt base address
; Save IDTR
sidt	[_SavedIDTR]
; Save interrupt mask register (IMREG) value
in	al, 21h
mov	[_SavedIMREG], al
; Load GDTR
lgdt	[GdtPtr]
; Disable interrupt
cli
; Load IDTR
lidt	[IdtPtr]
; Open address line A20
in	al, 92h
or	al, 00000010b
out	92h, al
; Prepare to switch to protected mode
mov	eax, cr0
or	eax, 1
mov	cr0, eax
; Enter protected mode
jmp	dword SelectorCode32:0

LABEL_REAL_ENTRY:		; Jump back to real mode from protected mode
mov	ax, cs
mov	ds, ax
mov	es, ax
mov	ss, ax
mov	sp, [_wSPValueInRealMode]

lidt	[_SavedIDTR]	; Restore the original value of IDTR

mov	al, [_SavedIMREG]	; Restore the original value of interrupt mask register (IMREG)
out	21h, al

in	al, 92h
and	al, 11111101b	; Close A20 address line
out	92h, al

sti			; Enable interrupt

mov	ax, 4c00h
int	21h		; Return to DOS

[SECTION .s32]
[BITS	32]
LABEL_SEG_CODE32:
mov	ax, SelectorData
mov	ds, ax			; Data segment selector
mov	es, ax
mov	ax, SelectorVideo
mov	gs, ax			; Video segment selector
mov	ax, SelectorStack
mov	ss, ax			; Stack segment selector
mov	esp, TopOfStack

; Initialize 8253A
call	Init8253A
call	Init8259A
; Display a string
push	szPMMessage
call	DispStr
add	esp, 4
push	szMemChkTitle
call	DispStr
add	esp, 4
call	DispMemSize		; Display memory information
; Calculate the number of page tables
xor	edx, edx
mov	eax, [dwMemSize]
mov	ebx, 400000h	; 400000h = 4M = 4096 * 1024, the memory size corresponding to a page table
div	ebx
mov	ecx, eax	; At this time, ecx is the number of page tables, that is, the number of PDEs
test	edx, edx
jz	.no_remainder
inc	ecx		; If the remainder is not 0, you need to add a page table
.no_remainder:
mov	[PageTableNumber], ecx	; Temporarily store the number of page tables
call	LABEL_INIT_PAGE_TABLE0
call	LABEL_INIT_PAGE_TABLE1
call	LABEL_INIT_PAGE_TABLE2
call	LABEL_INIT_PAGE_TABLE3
; Initialize ticks
mov 	ecx, 0
.initTicks:
mov     eax, dword [TaskPriority + ecx*4]
mov     dword [LeftTicks + ecx*4], eax
inc   	ecx
cmp    	ecx, 4
jne     .initTicks
mov 	ecx, 0
sti							; Enable interrupts
mov		eax, PageDirBase0	; Load CR3
mov		cr3, eax
mov		ax, SelectorTSS0	; Load TSS
ltr		ax
mov		eax, cr0
or		eax, 80000000h		; Enable paging
mov		cr0, eax
jmp		short .1
.1:
nop
; Prompt initialization is complete
.ready:
mov 	ecx, 0
mov		ah, 0Fh
.outputLoop:
mov		al, [szReadyMessage + ecx]
mov 	[gs:((80 * 14 + ecx) * 2)], ax
inc		ecx
cmp		al, 0
jnz		.outputLoop
SwitchTask 0
call	SetRealmode8259A	; Restore 8259A to return to real mode smoothly, not executed
jmp		SelectorCode16:0	; Return to real mode, not executed

; int handler ------------------------------------------------------------------
_ClockHandler:
ClockHandler	equ	_ClockHandler - $$
push	ds
pushad

mov		eax, SelectorData
mov		ds, ax

mov		al, 0x20
out		0x20, al

; Determine if LeftTick is 0. If it is not 0, it means that no task is running and no task switching is required.
mov     edx, dword [RunningTask]
mov     ecx, dword [LeftTicks+edx*4]
test    ecx, ecx
jnz     .subTicks	; Jump directly to subTicks, no task switching is required
; Determine whether all tasks have been executed. If all tasks have been executed, reassign values
mov     eax, dword [LeftTicks]
mov     ebx, edx
or      eax, dword [LeftTicks + 4]
or      eax, dword [LeftTicks + 8]
or      eax, dword [LeftTicks + 12]
jz      .allFinished	; Jump to allFinished and reassign values
.goToNext:  ; Select the next task
mov     eax, 0
mov     esi, 0
mov		ecx, 0
.getMaxLoop:  ; Get the task with the largest Ticks
cmp     dword [LeftTicks+eax*4], ecx
jle     .notMax
mov     ecx, dword [TaskPriority+eax*4]
mov     ebx, eax
mov     esi, 1
.notMax:
add     eax, 1
cmp     eax, 4
jnz     .getMaxLoop    ; Loop to get the task with the largest Ticks
mov     eax, esi
test    al, al
jz      .subTicks
mov     dword [RunningTask], ebx    ; RunningTask = ebx
mov     edx, ebx
; switch to task edx
cmp    	edx, 0
je     	.switchToTask0
cmp    	edx, 1
je     	.switchToTask1
cmp    	edx, 2
je     	.switchToTask2
cmp    	edx, 3
je     	.switchToTask3
jmp    	.exit
.switchToTask0:
SwitchTask 0
.switchToTask1:
SwitchTask 1
.switchToTask2:
SwitchTask 2
.switchToTask3:
SwitchTask 3
.subTicks:
sub     dword [LeftTicks+edx*4], 1
jmp	 .exit

; If all are finished, reassign values
.allFinished:  ; Local function
mov		ecx, 0
.setLoop:
mov     eax, dword [TaskPriority + ecx*4]
mov     dword [LeftTicks + ecx*4], eax
inc   	ecx
cmp    	ecx, 4
jne     .setLoop
mov 	ecx, 0
jmp     .goToNext

.exit:
popad
pop		ds
iretd

_UserIntHandler:
UserIntHandler	equ	_UserIntHandler - $$
mov	ah, 0Ch				; 0000: Black background 1100: Red text
mov	al, 'I'
mov	[gs:((80 * 0 + 70) * 2)], ax	; Screen position
iretd

_SpuriousHandler:
SpuriousHandler	equ	_SpuriousHandler - $$
mov	ah, 0Ch				; 0000: Black background 1100: Red text
mov	al, '!'
mov	[gs:((80 * 0 + 75) * 2)], ax	; Screen position
iretd

InitPageTable 0
InitPageTable 1
InitPageTable 2
InitPageTable 3

%include	"lib.inc"	; Library functions
SegCode32Len	equ	$ - LABEL_SEG_CODE32

[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
; Jump back to real mode:
mov		ax, SelectorNormal
mov		ds, ax
mov		es, ax
mov		fs, ax
mov		gs, ax
mov		ss, ax

mov		eax, cr0
and		eax, 7ffffffeh		; Switch to real mode and turn off paging
mov		cr0, eax

LABEL_GO_BACK_TO_REAL:
jmp		0:LABEL_REAL_ENTRY

Code16Len	equ	$ - LABEL_SEG_CODE16