# x86 32-bit Assembly Reference Guide (claude cause learning material)

## Table of Contents
1. [Registers](#registers)
2. [Common Instructions](#common-instructions)
3. [Memory Access](#memory-access)
4. [Stack Operations](#stack-operations)
5. [Function Calls](#function-calls)
6. [Control Flow](#control-flow)
7. [I/O Operations](#io-operations)
8. [Special Instructions](#special-instructions)
9. [Inline Assembly in C](#inline-assembly-in-c)
10.[Common Patterns](#common-patterns)

---

## Registers

### **General Purpose Registers (32-bit)**

```asm
EAX, EBX, ECX, EDX      ; Main working registers
ESI, EDI                ; Source/Destination Index
EBP                     ; Base Pointer (used for stack frames)
ESP                     ; Stack Pointer (top of stack)
```

### **Special Purpose Registers**

```asm
EIP                     ; Instruction Pointer (where CPU is executing)
EFLAGS                  ; Flags register (carries condition information)
CS, DS, ES, SS          ; Segment registers (protected mode uses differently)
```

### **Register Breakdown**

When you use a 32-bit register, you're using the full 32 bits:

```
EAX (32-bit): [31-16 bits] [15-8 bits (AH)] [7-0 bits (AL)]
              
AX (16-bit):             [15-8 bits (AH)] [7-0 bits (AL)]

AH (8-bit):              [15-8 bits] ← Upper byte of AX
AL (8-bit):              [7-0 bits]  ← Lower byte of AX
```

**Example:**
```asm
mov eax, 0x12345678    ; eax = 0x12345678 (32-bit)
mov ax, 0xABCD         ; eax = 0x0000ABCD (lower 16 bits, upper cleared)
mov al, 0xFF           ; eax = 0x0000ABFF (lower 8 bits)
mov ah, 0x00           ; eax = 0x000000FF (upper 8 bits of AX)
```

---

## Common Instructions

### **Data Movement**

```asm
; MOV - Copy data
mov eax, 5              ; eax = 5
mov ebx, eax            ; ebx = eax (both now = 5)
mov ecx, [0xB8000]      ; ecx = value at address 0xB8000
mov [0xB8000], eax      ; Write eax to address 0xB8000

; LEA - Load Effective Address (useful for pointer arithmetic)
lea eax, [ebx + 4]      ; eax = (address of ebx) + 4

; XCHG - Exchange two values
xchg eax, ebx           ; Swap eax and ebx
```

### **Arithmetic**

```asm
; ADD - Addition
add eax, 5              ; eax = eax + 5
add eax, ebx            ; eax = eax + ebx

; SUB - Subtraction
sub eax, 3              ; eax = eax - 3
sub eax, ebx            ; eax = eax - ebx

; INC - Increment by 1
inc eax                 ; eax = eax + 1

; DEC - Decrement by 1
dec eax                 ; eax = eax - 1

; MUL - Unsigned multiply
mul ebx                 ; EDX:EAX = EAX * EBX (64-bit result)

; IMUL - Signed multiply
imul ebx                ; EDX:EAX = EAX * EBX

; DIV - Unsigned divide
div ebx                 ; EAX = EDX:EAX / EBX
                        ; EDX = remainder

; IDIV - Signed divide
idiv ebx                ; EAX = EDX:EAX / EBX (signed)
```

### **Logical Operations**

```asm
; AND - Bitwise AND
and eax, 0xFF           ; Keep only lower 8 bits of eax
and eax, ebx            ; eax = eax & ebx

; OR - Bitwise OR
or eax, 1               ; Set bit 0 of eax
or eax, ebx             ; eax = eax | ebx

; XOR - Bitwise XOR (good for clearing)
xor eax, eax            ; eax = 0 (fast way to clear register)
xor eax, ebx            ; eax = eax ^ ebx

; NOT - Bitwise NOT (flip all bits)
not eax                 ; eax = ~eax

; SHL - Shift Left (multiply by 2^n)
shl eax, 1              ; eax = eax * 2
shl eax, 3              ; eax = eax * 8

; SHR - Shift Right (divide by 2^n, unsigned)
shr eax, 1              ; eax = eax / 2
shr eax, 3              ; eax = eax / 8

; SAR - Shift Right Arithmetic (divide, signed)
sar eax, 1              ; eax = eax / 2 (preserves sign)
```

### **Comparison & Testing**

```asm
; CMP - Compare (sets flags, discards result)
cmp eax, 5              ; Compare eax with 5
                        ; Sets flags but doesn't change eax

; TEST - Test bit (AND but discard result)
test eax, eax           ; Test if eax is zero
test eax, 1             ; Test if bit 0 is set
```

### **Flag Manipulation**

```asm
; These set flags for conditional jumps

; Zero Flag (ZF) - set if result is zero
; Carry Flag (CF) - set if unsigned overflow
; Sign Flag (SF) - set if result is negative
; Overflow Flag (OF) - set if signed overflow
```

---

## Memory Access

### **Direct Addressing**

```asm
; Read from address
mov eax, [0xB8000]              ; eax = value at 0xB8000

; Write to address
mov [0xB8000], 'A'              ; Write 'A' to 0xB8000
mov dword [0x10000], 0x12345678 ; Write 32-bit value

; Size specifiers
mov byte [addr], al             ; Write 8-bit
mov word [addr], ax             ; Write 16-bit
mov dword [addr], eax           ; Write 32-bit
```

### **Register Indirect Addressing**

```asm
; Address is in a register
mov eax, [ebx]                  ; eax = value at address in ebx
mov [ecx], edx                  ; Write edx to address in ecx
mov [esi], al                   ; Write byte to address in esi
```

### **Indexed Addressing**

```asm
; Address = register + offset
mov eax, [ebx + 4]              ; eax = value at (ebx + 4)
mov [edi + 2], al               ; Write to (edi + 2)
mov ecx, [esi + 8]              ; ecx = value at (esi + 8)

; With scale (for arrays)
mov eax, [ebx + ecx*4]          ; eax = value at (ebx + ecx*4)
                                ; Good for arrays of 32-bit values
```

### **Pointer Iteration (Video Memory Example)**

```asm
; Write to video memory
mov edi, 0xB8000        ; Start at video memory
mov al, 'H'             ; Character to write
mov ah, 0x07            ; Color (white on black)

mov [edi], al           ; Write character
mov [edi+1], ah         ; Write color
add edi, 2              ; Move to next character position

mov [edi], 'e'
mov [edi+1], 0x07
add edi, 2
```

---

## Stack Operations

### **How Stack Works**

```
Stack grows DOWNWARD (high address → low address)

ESP (Stack Pointer) points to the TOP of the stack

Before: ESP = 0x1000, Stack empty
After push: ESP = 0x0FFC, value at 0x0FFC

Stack is LIFO (Last In First Out)
```

### **Stack Instructions**

```asm
; PUSH - Put value on stack
push eax                ; ESP -= 4; Memory[ESP] = eax
push ebx
push ecx

; POP - Take value from stack
pop ecx                 ; ecx = Memory[ESP]; ESP += 4
pop ebx
pop eax

; Note: Last pushed is first popped!
```

### **Stack Frame Pattern (Functions)**

```asm
my_function:
    push ebp            ; Save caller's base pointer
    mov ebp, esp        ; Create new base pointer
    sub esp, 16         ; Reserve 16 bytes for local variables
    
    ; Function body
    ; Access parameters: [ebp + 8], [ebp + 12], etc.
    ; Access locals: [ebp - 4], [ebp - 8], etc.
    
    mov eax, 42         ; Return value in eax
    
    add esp, 16         ; Clean up local variables
    pop ebp             ; Restore caller's base pointer
    ret                 ; Pop return address, jump back
```

---

## Function Calls

### **CALL and RET Instructions**

```asm
; CALL - Push return address and jump
call my_function        ; Pushes (current address + size of call instruction)
                        ; Jumps to my_function

; RET - Pop return address and jump back
ret                     ; Pops return address from stack, jumps back
```

### **Simple Function Example**

```asm
; Define function
add_numbers:
    ; eax = first number
    ; ebx = second number
    ; Result in eax
    add eax, ebx
    ret

; Call function
mov eax, 5
mov ebx, 3
call add_numbers        ; eax = 8 after return
```

### **Nested Function Calls**

```asm
function_a:
    call function_b     ; Call another function
    ; When function_b returns, execution continues here
    ret

function_b:
    ; Do something
    ret
```

---

## Control Flow

### **Conditional Jumps**

```asm
; After CMP or TEST, these jumps check flags

; Jump if Equal / Jump if Zero
je label                ; Jump if ZF is set
jz label                ; Same as JE

; Jump if Not Equal / Jump if Not Zero
jne label               ; Jump if ZF is clear
jnz label               ; Same as JNE

; Jump if Greater (unsigned)
ja label                ; Jump if above (unsigned >)
jae label               ; Jump if above or equal (unsigned >=)

; Jump if Less (unsigned)
jb label                ; Jump if below (unsigned <)
jbe label               ; Jump if below or equal (unsigned <=)

; Jump if Greater (signed)
jg label                ; Jump if greater (signed >)
jge label               ; Jump if greater or equal (signed >=)

; Jump if Less (signed)
jl label                ; Jump if less (signed <)
jle label               ; Jump if less or equal (signed <=)

; Unconditional Jump
jmp label               ; Always jump
```

### **Loop Construct**

```asm
; Loop using LOOP instruction (decrements ECX)
mov ecx, 10             ; Loop 10 times
loop_start:
    ; Loop body
    dec ecx
    jnz loop_start      ; Jump if not zero

; Or using LOOP (auto-decrements ECX)
mov ecx, 10
loop_start:
    ; Loop body
    loop loop_start      ; Decrements ECX, jumps if not zero
```

### **If-Then-Else Pattern**

```asm
cmp eax, 5
je equal_case
jg greater_case

; Less than case
mov ebx, 1
jmp end_if

greater_case:
mov ebx, 2
jmp end_if

equal_case:
mov ebx, 0

end_if:
; ebx now has result
```

---

## I/O Operations

### **Port I/O**

```asm
; OUT - Write to I/O port
outb port, al           ; Write byte to port
outw port, ax           ; Write word to port
outl port, eax          ; Write doubleword to port

; IN - Read from I/O port
inb port                ; Read byte from port (result in AL)
inw port                ; Read word from port (result in AX)
inl port                ; Read doubleword from port (result in EAX)
```

### **Example: A20 Line Enable**

```asm
; Enable A20 line for addressing >1MB
in al, 0x92             ; Read status from port 0x92
or al, 2                ; Set bit 1
out 0x92, al            ; Write back to port 0x92
```

### **Example: PIT Timer Programming**

```asm
; Program Programmable Interval Timer
outb 0x43, 0x34         ; Command register
outb 0x40, 0xFF         ; Counter low byte
outb 0x40, 0xFF         ; Counter high byte
```

---

## Special Instructions

### **CPU Control**

```asm
cli                     ; Clear Interrupt flag (disable interrupts)
sti                     ; Set Interrupt flag (enable interrupts)
hlt                     ; Halt CPU (stop executing)
nop                     ; No operation (1 byte, does nothing)

iret                    ; Interrupt Return (pop EIP, CS, EFLAGS)
ret                     ; Function Return (pop EIP)
```

### **Interrupt Related**

```asm
int n                   ; Software interrupt (0-255)
int 0x10                ; BIOS interrupt 0x10 (video services)
int 0x13                ; BIOS interrupt 0x13 (disk services)

iret                    ; Return from interrupt handler
```

### **GDT/IDT Loading**

```asm
lgdt [gdt_descriptor]   ; Load GDT (Global Descriptor Table)
lidt [idt_descriptor]   ; Load IDT (Interrupt Descriptor Table)
```

### **Control Registers**

```asm
; Read from CR0
mov eax, cr0            ; eax = CR0
or eax, 1               ; Set PE bit (Protected Mode Enable)
mov cr0, eax            ; CR0 = eax (enable protected mode)

; CR0 bits
; Bit 0: PE (Protection Enable) - enable protected mode
; Bit 16: WP (Write Protect)
; Bit 31: PG (Paging)
```

---

## Inline Assembly in C

### **GCC Inline Assembly Syntax**

```c
// Simple inline assembly
asm("mov eax, 5");

// With input/output
asm("mov %0, %%eax" : "=a"(result));

// Basic format
asm("instruction" : outputs : inputs : clobbers);
```

### **Practical Examples**

```c
// Get current value of ESP
uint32_t get_esp() {
    uint32_t esp;
    asm("mov %%esp, %0" : "=r"(esp));
    return esp;
}

// Set ESP
void set_esp(uint32_t new_esp) {
    asm("mov %0, %%esp" : : "r"(new_esp));
}

// Disable interrupts
#define cli() asm("cli")

// Enable interrupts
#define sti() asm("sti")

// Halt CPU
#define hlt() asm("hlt")

// Write to I/O port
#define outb(port, data) \
    asm("outb %0, %1" : : "a"(data), "Nd"(port))

// Read from I/O port
#define inb(port) ({ \
    uint8_t result; \
    asm("inb %1, %0" : "=a"(result) : "Nd"(port)); \
    result; })
```

---

## Common Patterns

### **Clearing a Register**

```asm
xor eax, eax            ; eax = 0 (faster than mov eax, 0)
```

### **Setting Bits**

```asm
or eax, 1               ; Set bit 0
or eax, 0x80            ; Set bit 7
```

### **Clearing Bits**

```asm
and eax, 0xFFFFFFFE     ; Clear bit 0
and eax, 0x7FFFFFFF     ; Clear bit 31
```

### **Testing Bits**

```asm
test eax, 1             ; Test bit 0
jnz bit_set             ; If set, jump

test eax, 0x80          ; Test bit 7
jz bit_clear            ; If clear, jump
```

### **Looping Through Array**

```asm
mov esi, array_start    ; Pointer to start of array
mov ecx, array_count    ; Number of elements

loop_start:
    mov eax, [esi]      ; Load current element
    ; Process eax
    add esi, 4          ; Move to next element (assuming 32-bit values)
    loop loop_start      ; Decrement ECX, jump if not zero
```

### **String Operations**

```asm
mov esi, string         ; Point to string
loop:
    lodsb               ; Load byte from [ESI] into AL, increment ESI
    or al, al           ; Check for null terminator
    jz done
    ; Process character in AL
    jmp loop
done:
```

### **Memory Copy**

```asm
mov esi, source         ; Source address
mov edi, destination    ; Destination address
mov ecx, byte_count     ; Number of bytes to copy

copy_loop:
    mov al, [esi]       ; Load byte from source
    mov [edi], al       ; Store to destination
    inc esi
    inc edi
    dec ecx
    jnz copy_loop
```

### **Dividing by Power of 2 (Optimization)**

```asm
; Instead of DIV (slow)
mov edx, 0
mov ecx, 4
div ecx                 ; eax = eax / 4

; Use shift (fast)
shr eax, 2              ; eax = eax >> 2 (same as / 4)
```

### **Multiplying by Power of 2 (Optimization)**

```asm
; Instead of MUL (slow)
mov ecx, 4
mul ecx                 ; eax = eax * 4

; Use shift (fast)
shl eax, 2              ; eax = eax << 2 (same as * 4)
```

---

## Summary of Useful Instructions for OS Dev

| Instruction | Purpose | Example |
|-------------|---------|---------|
| `mov` | Copy data | `mov eax, ebx` |
| `add` | Add | `add eax, 5` |
| `sub` | Subtract | `sub eax, 3` |
| `inc/dec` | Increment/Decrement | `inc eax` |
| `and/or/xor` | Bitwise operations | `and eax, 0xFF` |
| `shl/shr` | Shift (multiply/divide by 2^n) | `shl eax, 2` |
| `cmp` | Compare | `cmp eax, 5` |
| `je/jne/jz/jnz` | Conditional jumps | `je label` |
| `jmp` | Unconditional jump | `jmp label` |
| `call/ret` | Function calls | `call func` |
| `push/pop` | Stack operations | `push eax` |
| `lgdt/lidt` | Load tables | `lgdt [ptr]` |
| `cli/sti` | Interrupt control | `cli` |
| `hlt` | Halt CPU | `hlt` |
| `outb/inb` | I/O port operations | `outb 0x92, al` |

---

## Tips for Writing Assembly

1. **Comment everything** - Assembly is hard to read
2. **Use meaningful labels** - `loop_start`, `error_handler`, etc.
3. **Preserve registers** - Save/restore in function prologue/epilogue
4. **Mind the stack** - Keep track of stack pointer
5. **Test in stages** - Write small assembly blocks, test them
6. **Use NASM syntax** - Be consistent with syntax
7. **Align data** - Important for performance
8. **Check instruction sizes** - Some instructions are shorter than others

---

## References

- Intel x86 Instruction Set Reference
- OSDev.org Assembly Tutorials
- Your CPU documentation