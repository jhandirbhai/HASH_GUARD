; ============================================================
;  HASHGUARD  -  PDF File Integrity Verification System
;  Pure 8086 assembly (MASM), MD5 implemented from scratch.
;
;  MAIN.ASM : shared data, menu loop and the six menu actions.
;  The other modules are pulled in with INCLUDE so that MASM
;  produces ONE object file (no inter-module symbol problems):
;       UI.ASM       screen output
;       FILEIO.ASM   file-name input, file hashing
;       MD5.ASM      MD5 engine
;       DATABASE.ASM HGDB.DAT record storage
; ============================================================

.MODEL SMALL
.STACK 400h

.DATA
;---- shared variables ----
errCode    dw 0
fileHandle dw 0
listCount  dw 0
inBuf      db 46               ; DOS 0Ah buffer: max length
inLen      db 0                ; actual length typed
inText     db 48 dup(0)
nameBuf    db 47 dup(0)        ; normalised file name (ASCIIZ)
fileBuf    db 512 dup(0)       ; file read buffer

;---- text ----
msgMenu    db 0Dh,0Ah
           db '========================================',0Dh,0Ah
           db '              HASHGUARD',0Dh,0Ah
           db '       PDF INTEGRITY VERIFICATION',0Dh,0Ah
           db 0Dh,0Ah
           db '   1. Generate PDF Hash',0Dh,0Ah
           db '   2. Register PDF Document',0Dh,0Ah
           db '   3. View Registered Documents',0Dh,0Ah
           db '   4. Verify PDF Integrity',0Dh,0Ah
           db '   5. Delete Registered Document',0Dh,0Ah
           db '   6. Exit',0Dh,0Ah
           db 0Dh,0Ah
           db '========================================',0Dh,0Ah
           db 'Enter Your Choice: $'
msgPress   db 0Dh,0Ah,'Press any key to return to the menu...$'
msgAskFile db 'Enter PDF file name (e.g. ..\TEST_FILES\SAMPLE.PDF): $'
msgBadName db '[ERROR] Invalid file name (empty or illegal characters).',0Dh,0Ah,'$'
msgBadMenu db 0Dh,0Ah,'[ERROR] Invalid selection. Please enter 1 to 6.',0Dh,0Ah,'$'
msgMd5Is   db 'MD5 hash : $'
msgErrNoFile db '[ERROR] File not found.',0Dh,0Ah,'$'
msgErrNoPath db '[ERROR] Path not found.',0Dh,0Ah,'$'
msgErrAccess db '[ERROR] Access denied.',0Dh,0Ah,'$'
msgErrHandles db '[ERROR] Too many open files.',0Dh,0Ah,'$'
msgErrOther db '[ERROR] DOS file error.',0Dh,0Ah,'$'
msgDbErr   db '[ERROR] Database error (cannot open, read or write HGDB.DAT).',0Dh,0Ah,'$'
msgDbBad   db '[ERROR] Database file is damaged (size is not a multiple of 64).',0Dh,0Ah,'$'
msgDot     db '. $'
msgIndent  db '    MD5: $'
msgRegOk   db '[OK] Document registered successfully.',0Dh,0Ah,'$'
msgRegDup  db '[INFO] This document is already registered. Delete it first to re-register.',0Dh,0Ah,'$'
msgNotReg  db '[INFO] This document is NOT REGISTERED in the database.',0Dh,0Ah,'$'
msgMatch   db 0Dh,0Ah,'*** HASH MATCHED - document is unchanged. ***',0Dh,0Ah,'$'
msgMismatch db 0Dh,0Ah,'*** HASH MISMATCHED - document has been MODIFIED! ***',0Dh,0Ah,'$'
msgStored  db 'Stored hash  : $'
msgCurrent db 'Current hash : $'
msgListHdr db 0Dh,0Ah,'Registered documents',0Dh,0Ah
           db '----------------------------------------',0Dh,0Ah,'$'
msgListNone db 'No documents are registered yet.',0Dh,0Ah,'$'
msgListCnt db '----------------------------------------',0Dh,0Ah
           db 'Total registered documents: $'
msgDelOk   db '[OK] Registration deleted. (The PDF file itself was not touched.)',0Dh,0Ah,'$'
msgBye     db 0Dh,0Ah,'HashGuard closed. Goodbye.',0Dh,0Ah,'$'

INCLUDE UI.ASM
INCLUDE FILEIO.ASM
INCLUDE MD5.ASM
INCLUDE DATABASE.ASM

.CODE
START:
    mov ax,@data
    mov ds,ax
    mov es,ax
    cld

menu_loop:
    call UI_ClearScreen
    mov dx,OFFSET msgMenu
    call UI_PrintStr
    mov ah,1                    ; read one key with echo
    int 21h
    mov bl,al
    call UI_NewLine
    cmp bl,'1'
    jne mn_2
    jmp do_generate
mn_2:
    cmp bl,'2'
    jne mn_3
    jmp do_register
mn_3:
    cmp bl,'3'
    jne mn_4
    jmp do_view
mn_4:
    cmp bl,'4'
    jne mn_5
    jmp do_verify
mn_5:
    cmp bl,'5'
    jne mn_6
    jmp do_delete
mn_6:
    cmp bl,'6'
    jne mn_bad
    jmp do_exit
mn_bad:
    mov dx,OFFSET msgBadMenu
    call UI_PrintStr
    jmp act_end

;------------------------------------------------------------
; 1. Generate PDF hash
;------------------------------------------------------------
do_generate:
    mov dx,OFFSET msgAskFile
    call UI_PrintStr
    call FIO_GetName
    jnc dg_hash
    mov dx,OFFSET msgBadName
    call UI_PrintStr
    jmp act_end
dg_hash:
    call FIO_HashFile
    jnc dg_show
    call UI_ShowDosError
    jmp act_end
dg_show:
    mov dx,OFFSET msgMd5Is
    call UI_PrintStr
    mov si,OFFSET md5Digest
    call UI_PrintHex
    call UI_NewLine
    jmp act_end

;------------------------------------------------------------
; 2. Register PDF document
;------------------------------------------------------------
do_register:
    mov dx,OFFSET msgAskFile
    call UI_PrintStr
    call FIO_GetName
    jnc rg_hash
    mov dx,OFFSET msgBadName
    call UI_PrintStr
    jmp act_end
rg_hash:
    call FIO_HashFile
    jnc rg_open
    call UI_ShowDosError
    jmp act_end
rg_open:
    call DB_Open
    jnc rg_find
    jmp db_error
rg_find:
    call DB_Find
    jnc rg_chk
    call DB_Close
    jmp db_error
rg_chk:
    cmp dbFound,1
    jne rg_add
    call DB_Close
    mov dx,OFFSET msgRegDup
    call UI_PrintStr
    jmp act_end
rg_add:
    call DB_Add
    jnc rg_ok
    call DB_Close
    jmp db_error
rg_ok:
    call DB_Close
    mov dx,OFFSET msgRegOk
    call UI_PrintStr
    mov dx,OFFSET msgMd5Is
    call UI_PrintStr
    mov si,OFFSET md5Digest
    call UI_PrintHex
    call UI_NewLine
    jmp act_end

;------------------------------------------------------------
; 3. View registered documents
;------------------------------------------------------------
do_view:
    call DB_Open
    jnc vw_list
    jmp db_error
vw_list:
    mov dx,OFFSET msgListHdr
    call UI_PrintStr
    call DB_List
    jnc vw_done
    call DB_Close
    jmp db_error
vw_done:
    call DB_Close
    or ax,ax
    jnz vw_count
    mov dx,OFFSET msgListNone
    call UI_PrintStr
    jmp act_end
vw_count:
    push ax
    mov dx,OFFSET msgListCnt
    call UI_PrintStr
    pop ax
    call UI_PrintDec
    call UI_NewLine
    jmp act_end

;------------------------------------------------------------
; 4. Verify PDF integrity
;------------------------------------------------------------
do_verify:
    mov dx,OFFSET msgAskFile
    call UI_PrintStr
    call FIO_GetName
    jnc vf_open
    mov dx,OFFSET msgBadName
    call UI_PrintStr
    jmp act_end
vf_open:
    call DB_Open
    jnc vf_find
    jmp db_error
vf_find:
    call DB_Find
    pushf                       ; keep CF across DB_Close
    call DB_Close
    popf
    jnc vf_chk
    jmp db_error
vf_chk:
    cmp dbFound,1
    je vf_hash
    mov dx,OFFSET msgNotReg
    call UI_PrintStr
    jmp act_end
vf_hash:
    call FIO_HashFile
    jnc vf_cmp
    call UI_ShowDosError
    jmp act_end
vf_cmp:
    mov si,OFFSET recDigest
    mov di,OFFSET md5Digest
    mov cx,16
    cld
    repe cmpsb
    jne vf_bad
    mov dx,OFFSET msgMatch
    call UI_PrintStr
    jmp act_end
vf_bad:
    mov dx,OFFSET msgMismatch
    call UI_PrintStr
    mov dx,OFFSET msgStored
    call UI_PrintStr
    mov si,OFFSET recDigest
    call UI_PrintHex
    call UI_NewLine
    mov dx,OFFSET msgCurrent
    call UI_PrintStr
    mov si,OFFSET md5Digest
    call UI_PrintHex
    call UI_NewLine
    jmp act_end

;------------------------------------------------------------
; 5. Delete registered document
;------------------------------------------------------------
do_delete:
    mov dx,OFFSET msgAskFile
    call UI_PrintStr
    call FIO_GetName
    jnc dl_open
    mov dx,OFFSET msgBadName
    call UI_PrintStr
    jmp act_end
dl_open:
    call DB_Open
    jnc dl_find
    jmp db_error
dl_find:
    call DB_Find
    jnc dl_chk
    call DB_Close
    jmp db_error
dl_chk:
    cmp dbFound,1
    je dl_del
    call DB_Close
    mov dx,OFFSET msgNotReg
    call UI_PrintStr
    jmp act_end
dl_del:
    call DB_Delete
    pushf
    call DB_Close
    popf
    jnc dl_ok
    jmp db_error
dl_ok:
    mov dx,OFFSET msgDelOk
    call UI_PrintStr
    jmp act_end

;------------------------------------------------------------
; common tails
;------------------------------------------------------------
db_error:
    cmp errCode,1000
    jne db_err_gen
    mov dx,OFFSET msgDbBad
    call UI_PrintStr
    jmp act_end
db_err_gen:
    mov dx,OFFSET msgDbErr
    call UI_PrintStr
act_end:
    call UI_PressKey
    jmp menu_loop

;------------------------------------------------------------
; 6. Exit
;------------------------------------------------------------
do_exit:
    mov dx,OFFSET msgBye
    call UI_PrintStr
    mov ax,4C00h
    int 21h

END START
