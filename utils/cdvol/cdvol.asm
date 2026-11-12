; cdvol.asm - mirror the MSCDEX CD-audio volume to the Sound Blaster mixer.
;
; Some DOS games set the CD audio volume through MSCDEX (IOCTL 0x03,
; "control audio channel").  Under a real DOS boot, MSCDEX translates that
; into an ATAPI MODE SELECT page 0x0E.  DOSBox-X currently logs that page
; but does not apply it to its CD-audio mixer channel, so the game's volume
; slider has no effect.
;
; The Sound Blaster mixer's CD volume registers (SB16 0x36/0x37), however,
; *are* wired to the DOSBox-X CD-audio mixer channel.  This TSR hooks
; INT 2F/AX=1510 (MSCDEX device driver request) and, for IOCTL output
; subfunction 0x03, copies the requested volumes into the SB mixer.
;
; Build: nasm -f bin -o CDVOL.COM cdvol.asm

BITS 16
ORG 100h

start:
    jmp setup

old_int2f  dd 0
sb_mixer   dw 0224h                  ; SB mixer index/data ports (A220h + 4/5)
vol_l      db 0
vol_r      db 0
have_vol   db 0
old_int1c  dd 0

; ------------------------------------------------------------------ handler
int2f:
    cmp ax, 1510h
    je  .mscdex
    jmp far [cs:old_int2f]

.mscdex:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; ES:BX -> MSCDEX request header
    cmp byte [es:bx+2], 0Ch          ; 0Ch = IOCTL output (MSCDEX)
    jne .done

    ; IOCTL buffer is at header+0x0E (offset) : header+0x10 (segment)
    mov si, [es:bx+0Eh]
    mov ax, [es:bx+10h]
    mov ds, ax
    cmp byte [si], 03h               ; 03h = control audio channel
    jne .done

    mov al, [si+2]                   ; left volume (0-255)
    call vol_to_reg                  ; linear amplitude -> SB16 dB index
    mov [cs:vol_l], al
    mov ah, 36h                      ; SB16 CD volume left
    call write_mixer

    mov al, [si+4]                   ; right volume (0-255)
    call vol_to_reg
    mov [cs:vol_r], al
    mov ah, 37h                      ; SB16 CD volume right
    call write_mixer
    mov byte [cs:have_vol], 1

%ifdef CDVOL_SERIAL
    ; debug build: emit left/right volumes to COM1 so the host can verify
    push dx
    push ax
    mov dx, 3F8h
    mov al, [si+2]
    out dx, al
    mov al, [si+4]
    out dx, al
    mov al, 0FFh
    out dx, al
    pop ax
    pop dx
%endif

.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:old_int2f]

; AL = volume (0-255), AH = SB mixer register
write_mixer:
    push dx
    push ax
    mov dx, [cs:sb_mixer]
    mov al, ah
    out dx, al                       ; select register
    inc dx
    pop ax
    out dx, al                       ; write 8-bit volume (mixer keeps top 5 bits)
    pop dx
    ret

; Re-apply the last CD volume on every timer tick.  The guest's SB driver
; (or a track change) can reset the SB mixer after the MSCDEX volume call,
; which would otherwise leave the CD audio at the reset level.
int1c:
    cmp byte [cs:have_vol], 0
    je  .chain
    push ax
    push dx
    mov al, [cs:vol_l]
    mov ah, 36h
    call write_mixer
    mov al, [cs:vol_r]
    mov ah, 37h
    call write_mixer
    pop dx
    pop ax
.chain:
    jmp far [cs:old_int1c]

; Convert a linear 0-255 volume to the SB16 CD volume register value.
; The SB16 CD volume is a 5-bit, roughly 2 dB/step attenuator.  Mapping
; the game's linear amplitude directly to the 5-bit index makes mid-range
; settings far too quiet (e.g. 53% -> -30 dB); this table maps linear
; amplitude to the nearest dB index instead (53% -> about -6 dB).
; In: AL = volume. Out: AL = register value (index << 3).
vol_to_reg:
    push bx
    xor ah, ah
    mov bx, vol_to_cda
    add bx, ax
    mov al, [cs:bx]
    shl al, 3
    pop bx
    ret

; 256-entry linear volume -> SB16 CD volume index (0..31) table.
vol_to_cda:
    db 0x00,0x07,0x0a,0x0c,0x0d,0x0e,0x0f,0x0f,0x10,0x10,0x11,0x11,0x12,0x12,0x12,0x13
    db 0x13,0x13,0x13,0x14,0x14,0x14,0x14,0x15,0x15,0x15,0x15,0x15,0x15,0x16,0x16,0x16
    db 0x16,0x16,0x16,0x16,0x16,0x17,0x17,0x17,0x17,0x17,0x17,0x17,0x17,0x17,0x18,0x18
    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x19,0x19,0x19,0x19,0x19,0x19
    db 0x19,0x19,0x19,0x19,0x19,0x19,0x19,0x19,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a
    db 0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1a,0x1b,0x1b,0x1b,0x1b,0x1b
    db 0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b,0x1b
    db 0x1b,0x1b,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c
    db 0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c,0x1c
    db 0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d
    db 0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d,0x1d
    db 0x1d,0x1d,0x1d,0x1d,0x1d,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e
    db 0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e
    db 0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e,0x1e
    db 0x1e,0x1e,0x1e,0x1e,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f
    db 0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f,0x1f

resident_end:

; -------------------------------------------------------------------- setup
setup:
    ; Find the Sound Blaster base in the BLASTER environment variable.
    mov ax, [ds:2Ch]
    test ax, ax
    jz  .hook
    mov ds, ax
    push cs
    pop es
    xor si, si
.scan:
    cmp byte [si], 0
    je  .hook
    mov di, blaster
    mov cx, 8
    push si
    repe cmpsb
    pop si
    je  .found
.skip:
    lodsb
    test al, al
    jnz .skip
    jmp .scan
.found:
    add si, 8                        ; skip "BLASTER="
    ; DS:SI points just after "BLASTER="
.find_a:
    lodsb
    test al, al
    jz  .hook
    cmp al, 'A'
    je  .parse_a
    cmp al, 'a'
    jne .find_a
.parse_a:
    xor bx, bx
    mov cx, 3
.hex:
    lodsb
    cmp al, '0'
    jb  .hex_done
    cmp al, '9'
    jbe .digit
    or  al, 20h
    cmp al, 'a'
    jb  .hex_done
    cmp al, 'f'
    ja  .hex_done
    sub al, 'a'-10
    jmp .add
.digit:
    sub al, '0'
.add:
    shl bx, 4
    or  bl, al
    loop .hex
.hex_done:
    add bx, 4                        ; mixer index port = base + 4
    mov [cs:sb_mixer], bx

.hook:
    push cs
    pop ds
    mov ax, 352Fh
    int 21h
    mov [old_int2f], bx
    mov [old_int2f+2], es

    mov ax, 252Fh
    mov dx, int2f
    int 21h

    mov ax, 351Ch
    int 21h
    mov [old_int1c], bx
    mov [old_int1c+2], es

    mov ax, 251Ch
    mov dx, int1c
    int 21h

    mov dx, (resident_end - start + 15) / 16 + 16
    mov ax, 3100h
    int 21h

blaster: db 'BLASTER='
