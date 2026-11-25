; ============================================================
;  MD5.ASM  -  HashGuard MD5 engine (pure 8086, MASM syntax)
;
;  A 32-bit MD5 word is stored as two 16-bit words in memory
;  (low word first = little-endian) and handled in DX:AX
;  (DX = high word, AX = low word).
;
;  Public routines (all NEAR, DS = ES = data segment):
;     MD5_Init    - reset the state
;     MD5_Update  - DS:SI = data, CX = byte count (0..65535)
;     MD5_Final   - pad, finish, result in md5Digest (16 bytes)
; ============================================================

.DATA
md5State label word
stA     dw 2 dup(0)
stB     dw 2 dup(0)
stC     dw 2 dup(0)
stD     dw 2 dup(0)
md5Save label word
svA     dw 2 dup(0)
svB     dw 2 dup(0)
svC     dw 2 dup(0)
svD     dw 2 dup(0)
md5LenLo dw 0
md5LenHi dw 0
bitsLo  dw 2 dup(0)
bitsHi  dw 2 dup(0)
blkLen  dw 0
stepI   dw 0
gIdx    dw 0
blk     db 64 dup(0)
md5Digest db 16 dup(0)

;---- K[i] = floor(abs(sin(i+1)) * 2^32), 64 constants ----
md5K label dword
    dd 0D76AA478h, 0E8C7B756h, 242070DBh, 0C1BDCEEEh
    dd 0F57C0FAFh, 4787C62Ah, 0A8304613h, 0FD469501h
    dd 698098D8h, 8B44F7AFh, 0FFFF5BB1h, 895CD7BEh
    dd 6B901122h, 0FD987193h, 0A679438Eh, 49B40821h
    dd 0F61E2562h, 0C040B340h, 265E5A51h, 0E9B6C7AAh
    dd 0D62F105Dh, 02441453h, 0D8A1E681h, 0E7D3FBC8h
    dd 21E1CDE6h, 0C33707D6h, 0F4D50D87h, 455A14EDh
    dd 0A9E3E905h, 0FCEFA3F8h, 676F02D9h, 8D2A4C8Ah
    dd 0FFFA3942h, 8771F681h, 6D9D6122h, 0FDE5380Ch
    dd 0A4BEEA44h, 4BDECFA9h, 0F6BB4B60h, 0BEBFBC70h
    dd 289B7EC6h, 0EAA127FAh, 0D4EF3085h, 04881D05h
    dd 0D9D4D039h, 0E6DB99E5h, 1FA27CF8h, 0C4AC5665h
    dd 0F4292244h, 432AFF97h, 0AB9423A7h, 0FC93A039h
    dd 655B59C3h, 8F0CCC92h, 0FFEFF47Dh, 85845DD1h
    dd 6FA87E4Fh, 0FE2CE6E0h, 0A3014314h, 4E0811A1h
    dd 0F7537E82h, 0BD3AF235h, 2AD7D2BBh, 0EB86D391h
;---- per-step left-rotate amounts ----
md5S label byte
    db 7,12,17,22,7,12,17,22
    db 7,12,17,22,7,12,17,22
    db 5,9,14,20,5,9,14,20
    db 5,9,14,20,5,9,14,20
    db 4,11,16,23,4,11,16,23
    db 4,11,16,23,4,11,16,23
    db 6,10,15,21,6,10,15,21
    db 6,10,15,21,6,10,15,21

.CODE

;------------------------------------------------------------
; MD5_Init : A=67452301h B=EFCDAB89h C=98BADCFEh D=10325476h
;------------------------------------------------------------
MD5_Init PROC NEAR
    mov stA,2301h
    mov stA+2,6745h
    mov stB,0AB89h
    mov stB+2,0EFCDh
    mov stC,0DCFEh
    mov stC+2,98BAh
    mov stD,5476h
    mov stD+2,1032h
    mov md5LenLo,0
    mov md5LenHi,0
    mov blkLen,0
    ret
MD5_Init ENDP

;------------------------------------------------------------
; MD5_Update : DS:SI = bytes, CX = count
;------------------------------------------------------------
MD5_Update PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    add md5LenLo,cx
    adc md5LenHi,0
upd_loop:
    jcxz upd_done
    mov bx,blkLen
    mov al,[si]
    inc si
    mov blk[bx],al
    inc bx
    mov blkLen,bx
    cmp bx,64
    jne upd_next
    push cx
    push si
    call MD5_Transform
    pop si
    pop cx
    mov blkLen,0
upd_next:
    dec cx
    jmp upd_loop
upd_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
MD5_Update ENDP

;------------------------------------------------------------
; MD5_Final : append 80h, zero padding, 64-bit bit length
;------------------------------------------------------------
MD5_Final PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; bit length = byte length * 8 (64-bit result in bitsLo:bitsHi)
    mov ax,md5LenLo
    mov dx,md5LenHi
    xor bx,bx
    mov cx,3
fin_sh:
    shl ax,1
    rcl dx,1
    rcl bx,1
    loop fin_sh
    mov bitsLo,ax
    mov bitsLo+2,dx
    mov bitsHi,bx
    mov bitsHi+2,0
    ; padding
    mov bx,blkLen
    mov blk[bx],80h
    inc bx
    cmp bx,56
    jbe fin_pad56
fin_z1:
    cmp bx,64
    jae fin_t1
    mov blk[bx],0
    inc bx
    jmp fin_z1
fin_t1:
    call MD5_Transform
    xor bx,bx
fin_pad56:
    cmp bx,56
    jae fin_len
    mov blk[bx],0
    inc bx
    jmp fin_pad56
fin_len:
    mov ax,bitsLo
    mov word ptr blk+56,ax
    mov ax,bitsLo+2
    mov word ptr blk+58,ax
    mov ax,bitsHi
    mov word ptr blk+60,ax
    mov ax,bitsHi+2
    mov word ptr blk+62,ax
    call MD5_Transform
    mov blkLen,0
    ; copy A,B,C,D (already little-endian) to the digest
    mov si,OFFSET md5State
    mov di,OFFSET md5Digest
    mov cx,16
    cld
    rep movsb
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
MD5_Final ENDP

;------------------------------------------------------------
; MD5_Transform : process the 64-byte block in blk
;   for i = 0..63
;     f = round function(B,C,D), g = message word index
;     t = f + A + K[i] + M[g]
;     A = D; D = C; C = B; B = B + rotl(t, S[i])
;------------------------------------------------------------
MD5_Transform PROC NEAR
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; save the chaining state
    mov si,OFFSET md5State
    mov di,OFFSET md5Save
    mov cx,8
    cld
    rep movsw
    mov stepI,0
tr_loop:
    mov bx,stepI
    cmp bx,16
    jb tr_r0
    cmp bx,32
    jb tr_r1
    cmp bx,48
    jb tr_r2
    jmp tr_r3

tr_r0:                          ; F = (B and C) or (not B and D), g = i
    mov ax,stB
    mov cx,ax
    and ax,stC
    not cx
    and cx,stD
    or ax,cx
    mov dx,stB+2
    mov cx,dx
    and dx,stC+2
    not cx
    and cx,stD+2
    or dx,cx
    mov gIdx,bx
    jmp tr_havef

tr_r1:                          ; G = (D and B) or (not D and C), g = (5i+1) mod 16
    mov ax,stD
    mov cx,ax
    and ax,stB
    not cx
    and cx,stC
    or ax,cx
    mov dx,stD+2
    mov cx,dx
    and dx,stB+2
    not cx
    and cx,stC+2
    or dx,cx
    mov si,bx
    shl si,1
    shl si,1
    add si,bx
    inc si
    and si,15
    mov gIdx,si
    jmp tr_havef

tr_r2:                          ; H = B xor C xor D, g = (3i+5) mod 16
    mov ax,stB
    xor ax,stC
    xor ax,stD
    mov dx,stB+2
    xor dx,stC+2
    xor dx,stD+2
    mov si,bx
    shl si,1
    add si,bx
    add si,5
    and si,15
    mov gIdx,si
    jmp tr_havef

tr_r3:                          ; I = C xor (B or not D), g = 7i mod 16
    mov ax,stD
    not ax
    or ax,stB
    xor ax,stC
    mov dx,stD+2
    not dx
    or dx,stB+2
    xor dx,stC+2
    mov si,bx
    shl si,1
    shl si,1
    shl si,1
    sub si,bx
    and si,15
    mov gIdx,si

tr_havef:                       ; DX:AX = f
    add ax,stA
    adc dx,stA+2
    mov si,bx                   ; + K[i]  (4 bytes per entry)
    shl si,1
    shl si,1
    add ax,word ptr md5K[si]
    adc dx,word ptr md5K[si+2]
    mov si,gIdx                 ; + M[g]  (4 bytes per word)
    shl si,1
    shl si,1
    add ax,word ptr blk[si]
    adc dx,word ptr blk[si+2]
    mov si,bx                   ; rotate left by S[i]
    mov cl,md5S[si]
tr_rot:
    shl ax,1
    rcl dx,1
    adc ax,0
    dec cl
    jnz tr_rot
    add ax,stB                  ; + B
    adc dx,stB+2
    mov cx,stD                  ; A = D
    mov stA,cx
    mov cx,stD+2
    mov stA+2,cx
    mov cx,stC                  ; D = C
    mov stD,cx
    mov cx,stC+2
    mov stD+2,cx
    mov cx,stB                  ; C = B
    mov stC,cx
    mov cx,stB+2
    mov stC+2,cx
    mov stB,ax                  ; B = new value
    mov stB+2,dx
    inc stepI
    cmp stepI,64
    jae tr_done
    jmp tr_loop
tr_done:
    mov ax,svA                  ; add saved state
    add stA,ax
    mov ax,svA+2
    adc stA+2,ax
    mov ax,svB
    add stB,ax
    mov ax,svB+2
    adc stB+2,ax
    mov ax,svC
    add stC,ax
    mov ax,svC+2
    adc stC+2,ax
    mov ax,svD
    add stD,ax
    mov ax,svD+2
    adc stD+2,ax
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
MD5_Transform ENDP
