    mov ax,0xb800
    mov es ,ax ;附加段基地址   
    mov cx,2000
    xor di,di	 ;偏移地址
    jmp near clear
clear:
    mov byte [es:di],0x20	;设置文本模式内容
    inc di
    mov byte [es:di],0x00  ;设置文本属性
    inc di
    loop clear	;循环

times 510-($-$$) db 0 ;填充0
    db 0x55,0xaa