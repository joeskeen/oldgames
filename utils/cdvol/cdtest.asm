; cdtest.asm - exercise CDVOL.COM and record the resulting SB mixer values.
;
; Calls MSCDEX INT 2F/AX=1510 with a synthetic IOCTL-output request that
; sets the CD volume to 0x40 (left) / 0x80 (right), then reads the SB16
; mixer CD volume registers and writes them to A:\CDTEST.BIN as two bytes.
; With the linear->dB mapping in CDVOL.COM those volumes become mixer
; values 0xC8 / 0xE0.
;
; Build: nasm -f bin -o CDTEST.COM cdtest.asm

BITS 16
ORG 100h

start:
    mov ax, cs
    mov [hdr+10h], ax
    mov word [hdr+0Eh], buf
    mov byte [hdr+0], 1Ah
    mov byte [hdr+1], 0
    mov byte [hdr+2], 0Ch
    mov byte [buf+0], 03h
    mov byte [buf+1], 0
    mov byte [buf+2], 40h
    mov byte [buf+3], 1
    mov byte [buf+4], 80h

    mov ax, 1510h
    mov cx, 3
    push cs
    pop es
    mov bx, hdr
    int 2Fh

    mov dx, 224h
    mov al, 36h
    out dx, al
    inc dx
    in  al, dx
    mov [result+0], al

    mov dx, 224h
    mov al, 37h
    out dx, al
    inc dx
    in  al, dx
    mov [result+1], al

    mov ah, 3Ch
    xor cx, cx
    mov dx, fname
    int 21h
    jc  .done
    mov bx, ax
    mov ah, 40h
    mov cx, 2
    mov dx, result
    int 21h
    mov ah, 3Eh
    int 21h

.done:
    mov ax, 4C00h
    int 21h

hdr:    times 1Ah db 0
buf:    times 16  db 0
result: db 0, 0
fname:  db 'A:\CDTEST.BIN', 0
