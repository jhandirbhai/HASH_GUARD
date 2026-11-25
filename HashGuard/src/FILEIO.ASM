; ============================================================
;  FILEIO.ASM  -  keyboard file-name input and file hashing
;  Uses DOS INT 21h: 0Ah (buffered input), 3Dh open, 3Fh read,
;  3Eh close.
; ============================================================

.CODE

;------------------------------------------------------------
; FIO_GetName : read a file name from the keyboard.
;   Result : nameBuf = upper-case ASCIIZ name (zero padded to 47)
;   CF = 1 if empty or it contains an invalid character
;------------------------------------------------------------
FIO_GetName PROC NEAR
    push ax
    push cx
    push dx
    push si
    push di
    mov dx,OFFSET inBuf
    mov ah,0Ah
    int 21h
    call UI_NewLine
    mov di,OFFSET nameBuf       ; clear the name buffer
    mov cx,47
    xor al,al
    cld
    rep stosb
    mov cl,inLen
    xor ch,ch
    jcxz fn_bad                 ; empty entry
    mov si,OFFSET inText
    mov di,OFFSET nameBuf
fn_loop:
    lodsb
    cmp al,21h                  ; control chars and blank are invalid
    jb fn_bad
    cmp al,'*'
    je fn_bad
    cmp al,'?'
    je fn_bad
    cmp al,'<'
    je fn_bad
    cmp al,'>'
    je fn_bad
    cmp al,'|'
    je fn_bad
    cmp al,'"'
    je fn_bad
    cmp al,'a'                  ; to upper case
    jb fn_store
    cmp al,'z'
    ja fn_store
    sub al,20h
fn_store:
    stosb
    loop fn_loop
    clc
    jmp fn_exit
fn_bad:
    stc
fn_exit:
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret
FIO_GetName ENDP

;------------------------------------------------------------
; FIO_HashFile : MD5 of the file named in nameBuf
;   Result : md5Digest (16 bytes), CF = 0
;   Error  : CF = 1, errCode = DOS error code
;------------------------------------------------------------
FIO_HashFile PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    mov ax,3D00h                ; open for reading
    mov dx,OFFSET nameBuf
    int 21h
    jc hf_err
    mov fileHandle,ax
    call MD5_Init
hf_read:
    mov bx,fileHandle
    mov ah,3Fh
    mov cx,512
    mov dx,OFFSET fileBuf
    int 21h
    jc hf_rderr
    cmp ax,0
    je hf_done
    mov cx,ax
    mov si,OFFSET fileBuf
    call MD5_Update
    jmp hf_read
hf_done:
    mov bx,fileHandle
    mov ah,3Eh
    int 21h
    call MD5_Final
    clc
    jmp hf_exit
hf_rderr:
    mov errCode,ax
    mov bx,fileHandle
    mov ah,3Eh
    int 21h
    stc
    jmp hf_exit
hf_err:
    mov errCode,ax
    stc
hf_exit:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
FIO_HashFile ENDP
