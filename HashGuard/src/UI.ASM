; ============================================================
;  UI.ASM  -  HashGuard screen routines (8086, MASM)
;  All strings are '$' terminated (DOS function 09h).
; ============================================================

.CODE

;---- DX = offset of '$' string ----
UI_PrintStr PROC NEAR
    push ax
    mov ah,9
    int 21h
    pop ax
    ret
UI_PrintStr ENDP

;---- CR/LF ----
UI_NewLine PROC NEAR
    push ax
    push dx
    mov dl,13
    mov ah,2
    int 21h
    mov dl,10
    mov ah,2
    int 21h
    pop dx
    pop ax
    ret
UI_NewLine ENDP

;---- clear screen (set text mode 3) ----
UI_ClearScreen PROC NEAR
    push ax
    mov ax,0003h
    int 10h
    pop ax
    ret
UI_ClearScreen ENDP

;---- wait for a key ----
UI_PressKey PROC NEAR
    push ax
    push dx
    mov dx,OFFSET msgPress
    mov ah,9
    int 21h
    mov ah,8
    int 21h
    pop dx
    pop ax
    ret
UI_PressKey ENDP

;---- SI = ASCIIZ string, print it ----
UI_PrintZ PROC NEAR
    push ax
    push dx
    push si
pz_loop:
    lodsb
    or al,al
    jz pz_done
    mov dl,al
    mov ah,2
    int 21h
    jmp pz_loop
pz_done:
    pop si
    pop dx
    pop ax
    ret
UI_PrintZ ENDP

;---- AL = byte, print as two hex digits ----
UI_PrintHexByte PROC NEAR
    push ax
    push cx
    push dx
    mov dh,al
    mov cl,4
    shr al,cl
    call UI_HexNibble
    mov al,dh
    and al,0Fh
    call UI_HexNibble
    pop dx
    pop cx
    pop ax
    ret
UI_PrintHexByte ENDP

;---- AL = 0..15, print one hex digit (lower case) ----
UI_HexNibble PROC NEAR
    push ax
    push dx
    cmp al,9
    jbe hn_digit
    add al,39
hn_digit:
    add al,'0'
    mov dl,al
    mov ah,2
    int 21h
    pop dx
    pop ax
    ret
UI_HexNibble ENDP

;---- SI = 16 bytes, print 32 hex characters ----
UI_PrintHex PROC NEAR
    push ax
    push cx
    push si
    mov cx,16
ph_loop:
    lodsb
    call UI_PrintHexByte
    loop ph_loop
    pop si
    pop cx
    pop ax
    ret
UI_PrintHex ENDP

;---- AX = unsigned number, print in decimal ----
UI_PrintDec PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov bx,10
    xor cx,cx
pd_div:
    xor dx,dx
    div bx
    push dx
    inc cx
    or ax,ax
    jnz pd_div
pd_out:
    pop dx
    add dl,'0'
    mov ah,2
    int 21h
    loop pd_out
    pop dx
    pop cx
    pop bx
    pop ax
    ret
UI_PrintDec ENDP

;---- print message for the DOS error code in errCode ----
UI_ShowDosError PROC NEAR
    push ax
    push dx
    mov ax,errCode
    mov dx,OFFSET msgErrOther
    cmp ax,2
    jne se_c3
    mov dx,OFFSET msgErrNoFile
    jmp se_print
se_c3:
    cmp ax,3
    jne se_c5
    mov dx,OFFSET msgErrNoPath
    jmp se_print
se_c5:
    cmp ax,5
    jne se_c4
    mov dx,OFFSET msgErrAccess
    jmp se_print
se_c4:
    cmp ax,4
    jne se_print
    mov dx,OFFSET msgErrHandles
se_print:
    call UI_PrintStr
    pop dx
    pop ax
    ret
UI_ShowDosError ENDP
