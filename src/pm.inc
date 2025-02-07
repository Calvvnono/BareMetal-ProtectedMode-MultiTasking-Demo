DA_32       EQU 4000h
DA_LIMIT_4K EQU 8000h

DA_DPL0 EQU 00h
DA_DPL1 EQU 20h
DA_DPL2 EQU 40h
DA_DPL3 EQU 60h

DA_DR    EQU 90h
DA_DRW   EQU 92h
DA_DRWA  EQU 93h
DA_C     EQU 98h
DA_CR    EQU 9Ah
DA_CCO   EQU 9Ch
DA_CCOR  EQU 9Eh

DA_LDT      EQU 82h
DA_TaskGate EQU 85h
DA_386TSS   EQU 89h
DA_386CGate EQU 8Ch
DA_386IGate EQU 8Eh
DA_386TGate EQU 8Fh

SA_RPL0 EQU 0
SA_RPL1 EQU 1
SA_RPL2 EQU 2
SA_RPL3 EQU 3

SA_TIG EQU 0
SA_TIL EQU 4

PG_P   EQU 1
PG_RWR EQU 0
PG_RWW EQU 2
PG_USS EQU 0
PG_USU EQU 4

%macro Descriptor 3
	dw %2 & 0FFFFh
	dw %1 & 0FFFFh
	db (%1 >> 16) & 0FFh
	dw ((%2 >> 8) & 0F00h) | (%3 & 0F0FFh)
	db (%1 >> 24) & 0FFh
%endmacro

%macro Gate 4
	dw (%2 & 0FFFFh)
	dw %1
	dw (%3 & 1Fh) | ((%4 << 8) & 0FF00h)
	dw ((%2 >> 16) & 0FFFFh)
%endmacro

%macro InitDescBase 2
	xor eax, eax
	mov ax, cs
	shl eax, 4
	add eax, %1
	mov word [%2 + 2], ax
	shr eax, 16
	mov byte [%2 + 4], al
	mov byte [%2 + 7], ah
%endmacro

%macro InitTaskDescBase 1
	InitDescBase LABEL_TASK%1_LDT, LABEL_TASK%1_DESC_LDT
	InitDescBase LABEL_TASK%1_CODE, LABEL_TASK%1_DESC_CODE
	InitDescBase LABEL_TASK%1_DATA, LABEL_TASK%1_DESC_DATA 
	InitDescBase LABEL_TASK%1_STACK0, LABEL_TASK%1_DESC_STACK0 
	InitDescBase LABEL_TASK%1_STACK3, LABEL_TASK%1_DESC_STACK3
	InitDescBase LABEL_TSS%1, LABEL_DESC_TSS%1 
%endmacro

%macro DefineLDT 1
[SECTION .ldt%1]
ALIGN 32
LABEL_TASK%1_LDT:
LABEL_TASK%1_DESC_DATA: Descriptor 0, Task%1DataLen - 1, DA_DRWA + DA_DPL3
LABEL_TASK%1_DESC_CODE: Descriptor 0, Task%1CodeLen - 1, DA_C + DA_32 + DA_DPL3
LABEL_TASK%1_DESC_STACK0: Descriptor 0, TopOfTask%1Stack0, DA_DRWA + DA_32
LABEL_TASK%1_DESC_STACK3: Descriptor 0, TopOfTask%1Stack3, DA_DRWA + DA_32 + DA_DPL3
TASK%1LDTLen equ $ - LABEL_TASK%1_LDT
SelectorTask%1Data equ LABEL_TASK%1_DESC_DATA - LABEL_TASK%1_LDT + SA_TIL + SA_RPL3
SelectorTask%1Code equ LABEL_TASK%1_DESC_CODE - LABEL_TASK%1_LDT + SA_TIL + SA_RPL3
SelectorTask%1Stack0 equ LABEL_TASK%1_DESC_STACK0 - LABEL_TASK%1_LDT + SA_TIL
SelectorTask%1Stack3 equ LABEL_TASK%1_DESC_STACK3 - LABEL_TASK%1_LDT + SA_TIL + SA_RPL3
%endmacro

%macro DefineTaskData 2
[SECTION .task%1data]
ALIGN 32
[BITS 32]
LABEL_TASK%1_DATA:
	_szTask%1Message: db %2, 0
	szTask%1Message equ _szTask%1Message - $$
Task%1DataLen equ $ - LABEL_TASK%1_DATA
%endmacro

%macro DefineTaskCode 3
[SECTION .task%1code]
ALIGN 32
[BITS 32]
LABEL_TASK%1_CODE:
	xor ecx, ecx
	mov ah, %3
.outputLoop:
	mov al, [szTask%1Message + ecx]
	mov [gs:((80 * %2 + ecx) * 2)], ax
	inc ecx
	cmp al, 0
	jne .outputLoop
	jmp LABEL_TASK%1_CODE
Task%1CodeLen equ $ - LABEL_TASK%1_CODE
%endmacro

%macro DefineTaskStack0 1
[SECTION .task%1stack0]
ALIGN 32
[BITS 32]
LABEL_TASK%1_STACK0:
	times 512 db 0
TopOfTask%1Stack0 equ $ - LABEL_TASK%1_STACK0 - 1
%endmacro

%macro DefineTaskStack3 1
[SECTION .task%1stack3]
ALIGN 32
[BITS 32]
LABEL_TASK%1_STACK3:
	times 512 db 0
TopOfTask%1Stack3 equ $ - LABEL_TASK%1_STACK3 - 1
%endmacro

%macro DefineTaskTSS 1
[SECTION .tss%1]
ALIGN 32
[BITS 32]
LABEL_TSS%1:
	DD 0
	DD TopOfStack
	DD SelectorStack
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DD 0
	DW 0
	DW $ - LABEL_TSS%1 + 2
	DB 0ffh
TSS%1Len equ $ - LABEL_TSS%1
%endmacro

%macro DefineTask 4
	DefineLDT %1
	DefineTaskCode %1, %3, %4
	DefineTaskData %1, %2
	DefineTaskStack0 %1
	DefineTaskStack3 %1
	DefineTaskTSS %1
%endmacro

%macro InitPageTable 1
LABEL_INIT_PAGE_TABLE%1:
	mov ax, SelectorFlatRW
	mov es, ax
	mov edi, PageDirBase%1
	xor eax, eax
	mov eax, PageTblBase%1 | PG_P | PG_USU | PG_RWW
	mov ecx, [PageTableNumber]
.1:
	stosd
	add eax, 4096
	loop .1
	mov eax, [PageTableNumber]
	mov ebx, 1024
	mul ebx
	mov ecx, eax
	mov edi, PageTblBase%1
	xor eax, eax
	mov eax, PG_P | PG_USU | PG_RWW
.2:
	stosd
	add eax, 4096
	loop .2
	ret
%endmacro

%macro SwitchTask 1
	mov ax, SelectorLDT%1
	lldt ax
	mov eax, PageDirBase%1
	mov cr3, eax
	mov eax, SelectorTask%1Data
	mov ds, eax
	push SelectorTask%1Stack3
	push TopOfTask%1Stack3
	pushfd
	pop eax
	or eax, 0x200
	push eax
	push SelectorTask%1Code
	push 0
	iretd
%endmacro