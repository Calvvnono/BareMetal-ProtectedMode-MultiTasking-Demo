; DispAL: Display digits from AL
DispAL:
	push	ecx
	push	edx
	push	edi
	mov	edi, [dwDispPos]
	mov	ah, 0Fh
	mov	dl, al
	shr	al, 4
	mov	ecx, 2
.begin:
	and	al, 01111b
	cmp	al, 9
	ja	.convertA
	add	al, '0'
	jmp	.after
.convertA:
	sub	al, 0Ah
	add	al, 'A'
.after:
	mov	[gs:edi], ax
	add	edi, 2
	mov	al, dl
	loop	.begin
	mov	[dwDispPos], edi
	pop	edi
	pop	edx
	pop	ecx
	ret

; DispInt: Display integer
DispInt:
	mov	eax, [esp + 4]
	shr	eax, 24
	call	DispAL
	mov	eax, [esp + 4]
	shr	eax, 16
	call	DispAL
	mov	eax, [esp + 4]
	shr	eax, 8
	call	DispAL
	mov	eax, [esp + 4]
	call	DispAL
	mov	ah, 07h
	mov	al, 'h'
	push	edi
	mov	edi, [dwDispPos]
	mov	[gs:edi], ax
	add	edi, 4
	mov	[dwDispPos], edi
	pop	edi
	ret

; DispStr: Display string
DispStr:
	push	ebp
	mov	ebp, esp
	push	ebx
	push	esi
	push	edi
	mov	esi, [ebp + 8]
	mov	edi, [dwDispPos]
	mov	ah, 0Fh
.1:
	lodsb
	test	al, al
	jz	.2
	cmp	al, 0Ah
	jnz	.3
	push	eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.1
.3:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1
.2:
	mov	[dwDispPos], edi
	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret

; DispReturn: Newline
DispReturn:
	push	szReturn
	call	DispStr
	add	esp, 4
	ret

; MemCpy: Memory copy
MemCpy:
	push	ebp
	mov	ebp, esp
	push	esi
	push	edi
	push	ecx
	mov	edi, [ebp + 8]
	mov	esi, [ebp + 12]
	mov	ecx, [ebp + 16]
.1:
	cmp	ecx, 0
	jz	.2
	mov	al, [ds:esi]
	inc	esi
	mov	byte [es:edi], al
	inc	edi
	dec	ecx
	jmp	.1
.2:
	mov	eax, [ebp + 8]
	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp
	ret

; DispMemSize: Display memory size info
DispMemSize:
	push	esi
	push	edi
	push	ecx
	mov	esi, MemChkBuf
	mov	ecx, [dwMCRNumber]
.loop:
	mov	edx, 5
	mov	edi, ARDStruct
.1:
	push	dword [esi]
	call	DispInt
	pop	eax
	stosd
	add	esi, 4
	dec	edx
	cmp	edx, 0
	jnz	.1
	call	DispReturn
	cmp	dword [dwType], 1
	jne	.2
	mov	eax, [dwBaseAddrLow]
	add	eax, [dwLengthLow]
	cmp	eax, [dwMemSize]
	jb	.2
	mov	[dwMemSize], eax
.2:
	loop	.loop
	call	DispReturn
	push	szRAMSize
	call	DispStr
	add	esp, 4
	push	dword [dwMemSize]
	call	DispInt
	add	esp, 4
	pop	ecx
	pop	edi
	pop	esi
	ret

; Init8259A: Initialize 8259A
Init8259A:
	mov	al, 011h
	out	020h, al
	call	io_delay
	out	0A0h, al
	call	io_delay
	mov	al, 020h
	out	021h, al
	call	io_delay
	mov	al, 028h
	out	0A1h, al
	call	io_delay
	mov	al, 004h
	out	021h, al
	call	io_delay
	mov	al, 002h
	out	0A1h, al
	call	io_delay
	mov	al, 001h
	out	021h, al
	call	io_delay
	out	0A1h, al
	call	io_delay
	mov	al, 11111110b
	out	021h, al
	call	io_delay
	mov	al, 11111111b
	out	0A1h, al
	call	io_delay
	ret

; SetRealmode8259A: Set real mode 8259A
SetRealmode8259A:
	mov	ax, SelectorData
	mov	fs, ax
	mov	al, 017h
	out	020h, al
	call	io_delay
	mov	al, 008h
	out	021h, al
	call	io_delay
	mov	al, 001h
	out	021h, al
	call	io_delay
	mov	al, [fs:SavedIMREG]
	out	021h, al
	call	io_delay
	ret

; Init8253A: Initialize 8253A
Init8253A:
	mov	al, 00110110b
	out	043h, al
	call	io_delay
	mov	ax, 59659
	out	040h, al
	call	io_delay
	mov	al, ah
	out	040h, al
	call	io_delay
	ret

; io_delay: I/O delay
io_delay:
	nop
	nop
	nop
	nop
	ret
