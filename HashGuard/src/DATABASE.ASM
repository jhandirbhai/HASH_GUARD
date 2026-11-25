; ============================================================
;  DATABASE.ASM  -  binary record database (HGDB.DAT)
;
;  Record layout (64 bytes, fixed size):
;     offset  0 : status   (1 = active, 0 = deleted/free slot)
;     offset  1 : name     (47 bytes, upper case, zero padded)
;     offset 48 : digest   (16 bytes, raw MD5)
;  Record n lives at file offset n * 64.
;  A deleted record's slot is re-used by the next registration.
; ============================================================

.DATA
dbFileName db 'HGDB.DAT',0
dbHandle   dw 0
dbFoundIdx dw 0FFFFh
dbFreeIdx  dw 0FFFFh
dbCount    dw 0
dbFound    db 0
recBuf     label byte
recStatus  db 0
recName    db 47 dup(0)
recDigest  db 16 dup(0)

.CODE

;------------------------------------------------------------
; DB_Open : open HGDB.DAT read/write, create it if missing
;   CF = 1 on error (errCode set)
;------------------------------------------------------------
DB_Open PROC NEAR
    push ax
    push cx
    push dx
    mov ax,3D02h
    mov dx,OFFSET dbFileName
    int 21h
    jnc dbo_ok
    mov errCode,ax
    cmp ax,2                    ; 2 = file not found -> create it
    jne dbo_fail
    mov ah,3Ch
    xor cx,cx
    mov dx,OFFSET dbFileName
    int 21h
    jc dbo_cfail
dbo_ok:
    mov dbHandle,ax
    clc
    jmp dbo_exit
dbo_cfail:
    mov errCode,ax
dbo_fail:
    stc
dbo_exit:
    pop dx
    pop cx
    pop ax
    ret
DB_Open ENDP

;------------------------------------------------------------
; DB_Close
;------------------------------------------------------------
DB_Close PROC NEAR
    push ax
    push bx
    mov bx,dbHandle
    mov ah,3Eh
    int 21h
    pop bx
    pop ax
    ret
DB_Close ENDP

;------------------------------------------------------------
; DB_SeekIdx : AX = record number, move file pointer to AX*64
;   CF = 1 on error
;------------------------------------------------------------
DB_SeekIdx PROC NEAR
    push ax
    push bx
    push cx
    push dx
    xor dx,dx
    mov cl,6                    ; 32-bit multiply by 64
sk_shift:
    shl ax,1
    rcl dx,1
    dec cl
    jnz sk_shift
    mov cx,dx                   ; CX:DX = offset
    mov dx,ax
    mov bx,dbHandle
    mov ax,4200h
    int 21h
    jnc sk_ok
    mov errCode,ax
    stc
    jmp sk_exit
sk_ok:
    clc
sk_exit:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DB_SeekIdx ENDP

;------------------------------------------------------------
; DB_Find : look up nameBuf in the database
;   Sets dbFound (1/0), dbFoundIdx, dbFreeIdx, dbCount.
;   When found, recBuf holds the record.   CF = 1 on error.
;------------------------------------------------------------
DB_Find PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov dbFound,0
    mov dbFoundIdx,0FFFFh
    mov dbFreeIdx,0FFFFh
    mov dbCount,0
    xor ax,ax
    call DB_SeekIdx
    jc dbf_fail
dbf_loop:
    mov bx,dbHandle
    mov ah,3Fh
    mov cx,64
    mov dx,OFFSET recBuf
    int 21h
    jc dbf_rderr
    cmp ax,0
    je dbf_end
    cmp ax,64
    jne dbf_corrupt
    cmp recStatus,1
    jne dbf_free
    mov si,OFFSET recName
    mov di,OFFSET nameBuf
    mov cx,47
    cld
    repe cmpsb
    jne dbf_next
    mov dbFound,1
    mov ax,dbCount
    mov dbFoundIdx,ax
    jmp dbf_ok
dbf_free:
    cmp dbFreeIdx,0FFFFh
    jne dbf_next
    mov ax,dbCount
    mov dbFreeIdx,ax
dbf_next:
    inc dbCount
    jmp dbf_loop
dbf_end:
dbf_ok:
    clc
    jmp dbf_exit
dbf_corrupt:
    mov errCode,1000            ; 1000 = database file damaged
    jmp dbf_fail
dbf_rderr:
    mov errCode,ax
dbf_fail:
    stc
dbf_exit:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DB_Find ENDP

;------------------------------------------------------------
; DB_Add : store nameBuf + md5Digest as a new record.
;   Call DB_Find first (it supplies dbFreeIdx / dbCount).
;   CF = 1 on error
;------------------------------------------------------------
DB_Add PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov recStatus,1
    mov si,OFFSET nameBuf
    mov di,OFFSET recName
    mov cx,47
    cld
    rep movsb
    mov si,OFFSET md5Digest
    mov di,OFFSET recDigest
    mov cx,16
    rep movsb
    mov ax,dbFreeIdx
    cmp ax,0FFFFh
    jne dba_seek
    mov ax,dbCount              ; no free slot -> append
dba_seek:
    call DB_SeekIdx
    jc dba_fail
    mov bx,dbHandle
    mov ah,40h
    mov cx,64
    mov dx,OFFSET recBuf
    int 21h
    jc dba_werr
    cmp ax,64
    jne dba_full
    clc
    jmp dba_exit
dba_full:
    mov errCode,1001            ; 1001 = disk full / short write
    jmp dba_fail
dba_werr:
    mov errCode,ax
dba_fail:
    stc
dba_exit:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DB_Add ENDP

;------------------------------------------------------------
; DB_Delete : mark record dbFoundIdx as deleted (status = 0)
;   Call DB_Find first.   CF = 1 on error
;------------------------------------------------------------
DB_Delete PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov recStatus,0
    mov ax,dbFoundIdx
    call DB_SeekIdx
    jc dbd_fail
    mov bx,dbHandle
    mov ah,40h
    mov cx,64
    mov dx,OFFSET recBuf
    int 21h
    jc dbd_werr
    cmp ax,64
    jne dbd_short
    clc
    jmp dbd_exit
dbd_short:
    mov errCode,1001
    jmp dbd_fail
dbd_werr:
    mov errCode,ax
dbd_fail:
    stc
dbd_exit:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DB_Delete ENDP

;------------------------------------------------------------
; DB_List : print every active record.
;   Returns AX = number of active records, CF = 1 on error
;------------------------------------------------------------
DB_List PROC NEAR
    push bx
    push cx
    push dx
    push si
    mov listCount,0
    xor ax,ax
    call DB_SeekIdx
    jc dbl_fail
dbl_loop:
    mov bx,dbHandle
    mov ah,3Fh
    mov cx,64
    mov dx,OFFSET recBuf
    int 21h
    jc dbl_rderr
    cmp ax,0
    je dbl_end
    cmp ax,64
    jne dbl_corrupt
    cmp recStatus,1
    jne dbl_loop
    inc listCount
    mov ax,listCount
    call UI_PrintDec
    mov dx,OFFSET msgDot
    call UI_PrintStr
    mov si,OFFSET recName
    call UI_PrintZ
    call UI_NewLine
    mov dx,OFFSET msgIndent
    call UI_PrintStr
    mov si,OFFSET recDigest
    call UI_PrintHex
    call UI_NewLine
    jmp dbl_loop
dbl_end:
    mov ax,listCount
    clc
    jmp dbl_exit
dbl_corrupt:
    mov errCode,1000
    jmp dbl_fail
dbl_rderr:
    mov errCode,ax
dbl_fail:
    stc
dbl_exit:
    pop si
    pop dx
    pop cx
    pop bx
    ret
DB_List ENDP
