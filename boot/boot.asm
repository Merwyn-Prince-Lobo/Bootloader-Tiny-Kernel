;protected mode

[org 0x7c00]
[bits 16]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov si, msg_real
    call print_string_rm

    call enable_a20
    cli                     
                            
    lgdt [gdt_descriptor]   

    mov eax, cr0
    or eax, 1               ; set  Protection Enable
    mov cr0, eax

    jmp CODE_SEG:protected_mode_start
print_string_rm:
    pusha
.loop:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0e
    int 0x10
    jmp .loop
.done:
    popa
    ret

enable_a20:
    in al, 0x92
    or al, 2        ; bit 1 = enable A20
    out 0x92, al
    ret

msg_real db "Booting...", 0

gdt_start:

gdt_null:                  ; [0] required null descriptor
    dd 0x0
    dd 0x0

gdt_code:                  ; [1] code segment
    dw 0xffff               ; limit (bits 0-15)
    dw 0x0                  ; base  (bits 0-15)
    db 0x0                  ; base  (bits 16-23)
    db 10011010b            ; access: present, ring0, code, executable, readable
    db 11001111b            ; flags(4-bit) + limit(bits 16-19): 4K gran, 32-bit
    db 0x0                  ; base (bits 24-31)

gdt_data:                  ; [2] data segment (stack uses this too)
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b            ; access: present, ring0, data, writable
    db 11001111b
    db 0x0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; size of GDT, minus 1 (as CPU expects)
    dd gdt_start                  ; linear address of GDT

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

[bits 32]
protected_mode_start:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000   ; fresh 32-bit stack
    mov edi, 0xb8000
    mov ecx, 80*25       ; 80x25 chars
    mov ax, 0x0f20        ; white-on-black space
.clear:
    mov [edi], ax
    add edi, 2
    loop .clear

    ; no BIOS interrupts  protected mode -> write video memory directly
    mov esi, msg_pm
    mov edi, 0xb8000
    mov ah, 0x0f        ; white on black
.print_pm:
    mov al, [esi]
    cmp al, 0
    je .hang
    mov [edi], al
    mov [edi + 1], ah
    add esi, 1
    add edi, 2
    jmp .print_pm
.hang:
    jmp $

msg_pm db "Protected mode active!", 0

times 510-($-$$) db 0
dw 0xaa55