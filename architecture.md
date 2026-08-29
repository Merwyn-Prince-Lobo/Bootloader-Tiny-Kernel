# Bootloader + Tiny Kernel Architecture

## Table of Contents
1. [System Overview](#system-overview)
2. [Memory Layout](#memory-layout)
3. [Boot Process](#boot-process)
4. [Component Breakdown](#component-breakdown)
5. [Real vs Protected Mode](#real-vs-protected-mode)
6. [Task Management](#task-management)
7. [Context Switching](#context-switching)
8. [Interrupt Handling](#interrupt-handling)
9. [Scheduler Design](#scheduler-design)
10. [File Structure](#file-structure)
11. [Implementation Roadmap](#implementation-roadmap)

---

## System Overview

```
┌─────────────────────────────────────┐
│      Tiny Kernel (32-bit)           │
│  ├─ Interrupt System (IDT)          │
│  ├─ Task Manager                    │
│  ├─ Scheduler (Round-Robin)         │
│  ├─ Console I/O                     │
│  └─ Timer Handler                   │
└─────────────────────────────────────┘
          ↑
          │ (loaded by)
          │
┌─────────────────────────────────────┐
│  Bootloader (512 bytes, 16-bit)     │
│  ├─ Real Mode Setup                 │
│  ├─ Disk Read (load kernel)         │
│  ├─ A20 Line Enable                 │
│  ├─ GDT Setup                       │
│  └─ Protected Mode Switch           │
└─────────────────────────────────────┘
          ↑
          │ (loaded by)
          │
┌─────────────────────────────────────┐
│         BIOS Firmware               │
│      (emulated by QEMU)             │
└─────────────────────────────────────┘
```

**Key Insight:** Bootloader is just 512 bytes. It prepares the CPU and loads your actual kernel.

---

## Memory Layout

All addresses are in hexadecimal. This is your playground in QEMU.

```
4GB ┌─────────────────────────────────────────┐
    │  (Available for expansion)              │
    │                                         │
0x10000 ┌─────────────────────────────────────┐
    │  KERNEL CODE & DATA                     │
    │  ├─ kernel.c compiled code              │
    │  ├─ Interrupt Descriptor Table (IDT)    │
    │  ├─ Task structures                     │
    │  ├─ Global variables                    │
    │  └─ Kernel heap (future)                │
    │                                         │
0x90000 ┌─────────────────────────────────────┐
    │  KERNEL STACK                           │
    │  (grows downward)                       │
    │                                         │
0xA0000 ├─────────────────────────────────────┤
    │  (Reserved for hardware)                │
    │                                         │
0xB8000 ├─────────────────────────────────────┤
    │  VIDEO MEMORY (80x25 text mode)        │
    │  ├─ Each char = 2 bytes                │
    │  │   Byte 1: ASCII char                │
    │  │   Byte 2: Color attribute           │
    │  └─ Total: 80*25*2 = 4000 bytes        │
    │                                         │
0xC0000 ├─────────────────────────────────────┤
    │  (ROM, not used)                        │
    │                                         │
0x7C00  ├─────────────────────────────────────┤
    │  BOOTLOADER (512 bytes)                 │
    │  └─ BIOS loads here                     │
    │                                         │
0x7E00  ├─────────────────────────────────────┤
    │  (Free space during boot)               │
    │  └─ Kernel will be loaded here          │
    │     (sectors 2+ from disk)              │
    │                                         │
0x400   ├─────────────────────────────────────┤
    │  BIOS Data Area (256 bytes)             │
    │  └─ Don't touch                         │
    │                                         │
0x0     ├─────────────────────────────────────┤
    │  INTERRUPT VECTOR TABLE (Real Mode)    │
    │  └─ Points to interrupt handlers        │
0x0     └─────────────────────────────────────┘
```

### Key Addresses

| Address | Purpose | Size |
|---------|---------|------|
| 0x0 - 0x400 | IVT (Real Mode) | 1 KB |
| 0x400 - 0x500 | BIOS Data | 256 B |
| 0x7C00 - 0x7E00 | Bootloader | 512 B |
| 0x7E00 - 0x10000 | Kernel in transit | ~34 KB |
| 0x10000+ | Kernel (final) | ~50 KB+ |
| 0xB8000 - 0xBFFFF | Video Memory | 32 KB |
| 0x90000+ | Kernel Stack | ~64 KB |

---

## Boot Process

### Stage 1: BIOS Boot

```
1. Power on
   └─ CPU executes BIOS firmware code
   
2. BIOS Initialization
   ├─ Check hardware
   ├─ Set up IVT (Interrupt Vector Table)
   └─ Initialize devices
   
3. BIOS Disk Read
   ├─ Read sector 0 from disk
   ├─ Load 512 bytes into RAM at 0x7C00
   ├─ Check for boot signature (0xAA55 at byte 510-511)
   └─ If found: BOOT is valid
   
4. BIOS Jump
   └─ Set CS:IP = 0x0000:0x7C00
   └─ Execute bootloader code
```

### Stage 2: Bootloader (Real Mode)

**File:** `boot.asm`

```
Bootloader Tasks (in order):

1. REAL MODE SETUP
   ├─ Initialize segments (CS, DS, ES, SS)
   ├─ Initialize stack pointer (ESP)
   └─ Status: "Booting..." printed to screen
   
2. ENABLE A20 LINE
   ├─ Why: Access memory >1MB in protected mode
   ├─ How: Write to port 0x92
   └─ Status: A20 gate is now open
   
3. LOAD GDT (Global Descriptor Table)
   ├─ Create minimal GDT:
   │  ├─ Segment 0: Null descriptor
   │  ├─ Segment 1: Code segment (0x08)
   │  └─ Segment 2: Data segment (0x10)
   ├─ Load GDT with lgdt instruction
   └─ Status: GDT ready for protected mode
   
4. LOAD KERNEL FROM DISK
   ├─ Use BIOS int 0x13 (disk read)
   ├─ Read sectors 2-X into 0x10000
   ├─ (Sector 0 = bootloader, Sector 1 = unused)
   └─ Status: Kernel image in RAM
   
5. SWITCH TO PROTECTED MODE
   ├─ Set PE bit (bit 0) in CR0 register
   ├─ Far jump to protected mode code (0x08:protected_start)
   └─ Status: CPU now in 32-bit protected mode
   
6. JUMP TO KERNEL
   ├─ Long jump to kernel entry point (0x10000)
   └─ Kernel code takes over
```

**Key Assembly Concepts:**
- `lgdt [gdt_descriptor]` - Load GDT address
- `mov eax, cr0; or eax, 1; mov cr0, eax` - Enable protected mode
- `jmp 0x08:label` - Far jump (segment:offset)
- `int 0x13` - BIOS disk interrupt
- `outb port, value` - Write to I/O port

### Stage 3: Kernel (Protected Mode)

**Files:** `kernel_entry.asm`, `kernel.c`

```
Kernel Startup Tasks:

1. KERNEL ENTRY (Assembly)
   ├─ Called from bootloader
   ├─ Set up stack pointer
   └─ Call kernel_main (C function)
   
2. CONSOLE INITIALIZATION
   ├─ Clear video memory (0xB8000)
   ├─ Initialize cursor position
   └─ Status: Screen ready for text output
   
3. INTERRUPT SETUP
   ├─ Create IDT (Interrupt Descriptor Table)
   ├─ Set up exception handlers
   │  └─ Divide by zero, page fault, etc.
   ├─ Set up interrupt handlers
   │  └─ Timer interrupt (IRQ 0)
   └─ Load IDT with lidt instruction
   
4. PIT (TIMER) SETUP
   ├─ Program Programmable Interval Timer
   ├─ Set to fire every 50ms (adjustable)
   ├─ Enable IRQ 0 (unmask in PIC)
   └─ Status: Timer running, interrupts every 50ms
   
5. TASK SYSTEM INITIALIZATION
   ├─ Create task queue
   ├─ Initialize task TCB (Task Control Block)
   ├─ Create idle task
   └─ Status: Ready to add user tasks
   
6. CREATE TEST TASKS
   ├─ Task 1: Print "T1"
   ├─ Task 2: Print "T2"
   ├─ Task 3: Print "T3"
   └─ Status: Tasks ready but not running yet
   
7. START SCHEDULER
   ├─ Enable interrupts (sti instruction)
   ├─ Run first task
   ├─ Timer interrupt fires every 50ms
   ├─ Scheduler context-switches to next task
   └─ Loop forever (scheduler never returns)
```

---

## Component Breakdown

### 1. Bootloader (`boot.asm`)

**Responsibilities:**
- Load from 0x7C00 (BIOS entry point)
- Print to screen (real mode)
- Read kernel from disk
- Switch CPU mode (real → protected)
- Jump to kernel

**Size:** Exactly 512 bytes (BIOS requirement)

**Key Functions:**
```asm
print_string       - Print message to screen
enable_a20         - Open A20 line for >1MB access
load_kernel        - Read kernel from disk via BIOS
switch_to_protected_mode  - Set PE bit, far jump
```

**Data Structures:**
```asm
GDT (Global Descriptor Table):
  [0] Null descriptor (reserved)
  [1] Code segment: base=0, limit=4GB, readable
  [2] Data segment: base=0, limit=4GB, writable
```

---

### 2. Kernel Entry (`kernel_entry.asm`)

**Responsibilities:**
- Called by bootloader (protected mode)
- Set up C runtime (stack, etc.)
- Call kernel_main function

**Functions:**
```asm
start          - Entry point, set up, call kernel_main
```

---

### 3. Console Output (`screen.c/h`)

**Responsibilities:**
- Manage text output to screen
- Write to video memory (0xB8000)
- Handle newlines and cursor movement

**Data Structures:**
```c
struct {
    int cursor_x;      // 0-79
    int cursor_y;      // 0-24
}
```

**Key Functions:**
```c
screen_init()          - Clear screen, init cursor
screen_clear()         - Blank all text
screen_print(str)      - Print string (with newline support)
screen_print_int(num)  - Print integer
screen_print_hex(num)  - Print hex value
```

**Implementation Notes:**
- Video memory at 0xB8000
- 80 characters wide, 25 lines tall
- Each char = 2 bytes: [char][color_attr]
- Color: 0x07 = white on black

---

### 4. Interrupt System (`interrupt.c/h`)

**Responsibilities:**
- Build Interrupt Descriptor Table (IDT)
- Register interrupt handlers
- Load IDT into CPU
- Handle exceptions and interrupts

**Data Structures:**
```c
struct idt_entry {
    uint16_t base_lo;      // Lower 16 bits of handler address
    uint16_t sel;          // Code segment selector (0x08)
    uint8_t always0;       // Reserved
    uint8_t flags;         // Type, DPL, etc.
    uint16_t base_hi;      // Upper 16 bits of handler address
};

struct idtr {
    uint16_t limit;        // Size of IDT - 1
    uint32_t base;         // IDT base address
} __attribute__((packed));
```

**Key Functions:**
```c
interrupt_init()              - Create and load IDT
set_idt_gate(n, base, sel)   - Register interrupt handler
default_handler()             - Catch-all handler
timer_interrupt_handler()     - Called every 50ms
```

**Interrupt Numbers:**
- 0x00-0x1F: CPU exceptions (divide by zero, page fault, etc.)
- 0x20: Timer (IRQ 0) ← Most important
- 0x21: Keyboard (IRQ 1)

---

### 5. Task Management (`task.c/h`)

**Responsibilities:**
- Create and manage tasks
- Store task state (registers, stack)
- Queue tasks for scheduler

**Data Structures:**
```c
struct task {
    uint32_t esp;           // Stack pointer (CRITICAL for context switch)
    uint32_t ebp;           // Base pointer
    uint32_t stack[256];    // Task's stack space (1 KB per task)
    
    char name[32];          // Task name (for debugging)
    uint32_t state;         // RUNNING, READY, BLOCKED, etc.
    uint32_t priority;      // 0-255 (higher = more important)
    
    uint32_t (*func)();     // Task function pointer
};

#define TASK_RUNNING  0
#define TASK_READY    1
#define TASK_BLOCKED  2
#define TASK_DEAD     3
```

**Key Functions:**
```c
task_init()                    - Initialize task system
create_task(func, name)        - Create new task
get_current_task()             - Return current task
set_current_task(task)         - Switch to task
```

**Important Notes:**
- Each task needs its own stack
- Stack grows downward (high to low addresses)
- ESP must be saved/restored for context switching

---

### 6. Scheduler (`scheduler.c/h`)

**Responsibilities:**
- Maintain queue of ready tasks
- Pick next task to run (round-robin)
- Be called by timer interrupt
- Context switch to next task

**Algorithm: Round-Robin**
```
Timer fires (every 50ms)
  ↓
scheduler_run() called
  ↓
Save current task's ESP
  ↓
Get next task from queue (circular)
  ↓
Restore next task's ESP
  ↓
Return to task (via context switch)
  ↓
Task runs for 50ms
  ↓
Timer fires again...
```

**Data Structures:**
```c
struct {
    task_t *queue[MAX_TASKS];      // Array of tasks
    int current_index;              // Current task in queue
    int count;                       // Number of tasks
} scheduler;
```

**Key Functions:**
```c
scheduler_init()            - Create empty queue
scheduler_add_task(task)    - Add task to queue
scheduler_remove_task(task) - Remove task from queue
scheduler_run()             - Pick next task and switch
scheduler_start()           - Begin scheduling (never returns)
```

---

### 7. Timer (`timer.c/h`)

**Responsibilities:**
- Program PIT (Programmable Interval Timer)
- Handle timer interrupts
- Call scheduler every tick

**Key I/O Ports (x86 PIT):**
```
Port 0x43: Command register
Port 0x40: Counter 0 (timer)

To set timer to ~55ms:
  outb(0x43, 0x34)    // Command: binary, mode 2, counter 0
  outb(0x40, 0xFF)    // Load count (low byte)
  outb(0x40, 0xFF)    // Load count (high byte)
```

**Key Functions:**
```c
timer_init()           - Program PIT
timer_handler()        - Called every tick, calls scheduler
get_tick()            - Return elapsed ticks (for timing)
```

---

## Real vs Protected Mode

### Real Mode (Bootloader)

```
Address Calculation: Physical Address = Segment * 16 + Offset

Example:
  CS = 0x7C00  (Code Segment)
  IP = 0x0000  (Instruction Pointer)
  Physical = 0x7C00 * 16 + 0x0000 = 0x7C000

Addressable Memory: 0 - 0xFFFFF (1 MB)

Segment Registers: CS, DS, ES, SS
```

**Bootloader runs entirely in real mode.**

### Protected Mode (Kernel)

```
Address Calculation: Linear Address (direct)

Example:
  Address 0x10000 = 0x10000 (much simpler!)

Addressable Memory: 0 - 0xFFFFFFFF (4 GB)

Memory Protection: Privilege rings (0=kernel, 3=user)

Requires:
  - GDT (Global Descriptor Table)
  - IDT (Interrupt Descriptor Table)
  - CR0 PE bit enabled
```

**Kernel runs entirely in protected mode.**

---

## Task Management

### Task Lifecycle

```
                    create_task()
                         ↓
                    ┌─────────┐
                    │  READY  │ ← Waiting to run
                    └─────────┘
                         ↑
                         │ scheduler picks
                         ↓
                    ┌─────────┐
                    │ RUNNING │ ← Currently executing
                    └─────────┘
                         ↓ (timer interrupt)
                         │ (context switch)
                    ┌─────────┐
                    │  READY  │ ← Back in queue
                    └─────────┘
                    
                    repeat...
                    
                    When done:
                         ↓
                    ┌─────────┐
                    │  DEAD   │ ← Task finished
                    └─────────┘
```

### Task Control Block (TCB)

Every task has a structure that holds:

```c
struct task {
    // CPU state (saved during context switch)
    uint32_t esp;      // MOST IMPORTANT: stack pointer
    uint32_t ebp;
    
    // Task metadata
    char name[32];
    uint32_t state;    // RUNNING, READY, etc.
    
    // Task resources
    uint32_t stack[256];   // Private stack (1 KB)
    uint32_t (*func)();    // Entry point
}
```

---

## Context Switching

### What Is It?

Save current task's CPU state → Load next task's CPU state → Resume execution.

### How It Works

```
Timer Interrupt Fires (CPU interrupt 0x20)
    ↓
CPU saves minimal state: IP, CS, flags
    ↓
CPU jumps to timer_interrupt_handler() (in IDT)
    ↓
Handler calls scheduler_run()
    ↓
CRITICAL PART:
  1. Save current task's ESP (and other registers)
  2. Get next task from queue
  3. Load next task's ESP (and other registers)
    ↓
Handler returns (iret instruction)
    ↓
CPU restores IP, CS, flags from stack
    ↓
Next task resumes execution (looks like time passed)
```

### Implementation (Pseudocode)

```c
// In timer interrupt handler
void timer_handler() {
    // Save current task
    current_task->esp = get_esp();  // Must be in assembly!
    current_task->ebp = get_ebp();
    
    // Get next task
    next_task = scheduler_get_next();
    
    // Restore next task
    set_esp(next_task->esp);
    set_ebp(next_task->ebp);
    
    // Return from interrupt
    // CPU will execute next_task's code
}
```

**Assembly Part** (Must be inline assembly):
```asm
get_esp:
  mov eax, esp
  ret

set_esp:
  mov esp, [esp + 4]  ; New ESP passed as parameter
  ret
```

---

## Interrupt Handling

### Interrupt Flow

```
1. EVENT OCCURS (timer, keyboard, exception, etc.)
   
2. CPU (hardware) does:
   ├─ Save current state (CS, IP, flags) on stack
   ├─ Look up IDT entry for interrupt number
   ├─ Get handler address from IDT
   └─ Jump to handler
   
3. HANDLER CODE RUNS (your code)
   ├─ Determine cause of interrupt
   ├─ Do work (e.g., context switch)
   ├─ Return using iret
   
4. CPU (hardware) does:
   ├─ Pop state from stack (CS, IP, flags)
   └─ Resume execution at previous location
```

### IDT Setup

```
IDT is array of 256 entries (one per interrupt):

Entry Format (8 bytes):
  Bytes 0-1:   Handler address (bits 0-15)
  Bytes 2-3:   Code segment selector (0x08 for kernel)
  Byte 4:      Reserved (always 0)
  Byte 5:      Flags (Type, DPL, P bit)
  Bytes 6-7:   Handler address (bits 16-31)

Loading IDT:
  idtr.limit = sizeof(idt) - 1    // 256*8 = 2048 bytes
  idtr.base = (uint32_t)&idt
  lidt [idtr]                      // Load into CPU
```

---

## Scheduler Design

### Round-Robin Algorithm

Each task gets equal CPU time (time slice).

```
Time ─────────────────────────────────────→

Task 1  ▓▓▓▓  ░░░░░░░░░░░  ▓▓▓▓
Task 2       ▓▓▓▓  ░░░░░░░░  ▓▓▓▓
Task 3            ▓▓▓▓  ░░░░  ▓▓▓▓

▓ = Running
░ = Waiting
Time slice = ~50ms (one timer tick)

Process:
  1. Task 1 runs for 50ms
  2. Timer interrupt fires
  3. Context switch → Task 2
  4. Task 2 runs for 50ms
  5. Timer interrupt fires
  6. Context switch → Task 3
  7. Task 3 runs for 50ms
  8. Timer interrupt fires
  9. Context switch → Task 1 (restart)
  10. Repeat...
```

### Scheduler Queue

```c
Maintained as circular array:

scheduler.queue[0] ─┐
scheduler.queue[1]  │
scheduler.queue[2]  │
scheduler.queue[3]  └─→ Loop back to [0]
  ...
scheduler.current_index ─→ Points to currently running task

Next task: queue[(current_index + 1) % count]
```

### Scheduling Algorithm

```c
void scheduler_run() {
    // Move to next task
    current_index = (current_index + 1) % task_count;
    
    // Get the task
    next_task = queue[current_index];
    
    // Context switch (ESP/EBP/etc.)
    perform_context_switch(current_task, next_task);
    
    // Update current
    current_task = next_task;
}
```

---

## File Structure

### Directory Layout

```
project/
├── ARCHITECTURE.md          ← You are here
├── Makefile                 ← Build rules
├── os.img                   ← Built OS image (output)
│
├── boot/
│   ├── boot.asm            ← Bootloader (512 bytes)
│   ├── boot_protected.asm  ← Protected mode entry
│   └── linker.ld           ← Linker script (controls layout)
│
├── kernel/
│   ├── kernel_entry.asm    ← Kernel entry point (calls C)
│   ├── kernel.c            ← kernel_main() and globals
│   ├── kernel.h
│   │
│   ├── screen.c/h          ← Console output
│   ├── screen.o            ← (compiled)
│   │
│   ├── interrupt.c/h       ← IDT setup and handlers
│   ├── interrupt.o
│   │
│   ├── task.c/h            ← Task management
│   ├── task.o
│   │
│   ├── scheduler.c/h       ← Scheduler (round-robin)
│   ├── scheduler.o
│   │
│   ├── timer.c/h           ← PIT timer
│   └── timer.o
│
├── utils/
│   ├── common.c/h          ← Helper functions
│   └── common.o
│
└── test/
    ├── test_tasks.c        ← Test task code
    └── test_output.txt     ← Expected output

Build Process:
  boot.asm ──nasm──→ boot.o
  boot_protected.asm ──nasm──→ boot_protected.o
  
  kernel/*.c ──gcc──→ *.o files
  
  All *.o ──ld──→ os.img (final binary)
                  ↓
            Run in QEMU
```

---

## Implementation Roadmap

### Phase 1: Bootloader Only (Week 1)

**Goal:** Print "Booting..." to screen

**Deliverable:**
- `boot.asm` (500 lines)
- Test in QEMU
- See text output

**Key Skills:**
- x86 16-bit assembly
- Video memory access
- BIOS interrupts

**Milestone:**
```
$ qemu-system-i386 -drive file=os.img,format=raw

[QEMU window]
Booting...
```

---

### Phase 2: Protected Mode Switch (Week 1-2)

**Goal:** Successfully switch to 32-bit mode without crashing

**Deliverable:**
- `boot.asm` (updated)
- `boot_protected.asm` (100 lines)
- GDT setup
- Mode switch
- Print from 32-bit code

**Key Skills:**
- GDT structure
- CR0 register manipulation
- Far jumps
- 32-bit addressing

**Milestone:**
```
$ qemu-system-i386 -drive file=os.img,format=raw

[QEMU window]
Booting...
In protected mode!
```

---

### Phase 3: Bootloader Loads Kernel (Week 2)

**Goal:** Bootloader reads kernel from disk and jumps to it

**Deliverable:**
- `boot.asm` (disk read support)
- `kernel_entry.asm` (stub)
- `kernel.c` (simple main)
- Linker script
- Build system (Makefile)

**Key Skills:**
- Disk I/O via BIOS int 0x13
- Linking separate modules
- Memory layout planning

**Milestone:**
```
$ qemu-system-i386 -drive file=os.img,format=raw

[QEMU window]
Booting...
In protected mode!
Hello from kernel!
```

---

### Phase 4: Console Output System (Week 2)

**Goal:** Build screen printing library

**Deliverable:**
- `screen.c/h`
- Supports printing strings, ints, hex
- Newline handling
- Cursor management

**Key Skills:**
- Video memory layout (0xB8000)
- String handling in C
- Printf-like formatting

**Test:**
```c
screen_print("Value: ");
screen_print_int(42);
screen_print("\n");
```

---

### Phase 5: Interrupt System (Week 3)

**Goal:** Set up IDT and handle basic interrupts

**Deliverable:**
- `interrupt.c/h`
- IDT creation
- Default exception handlers
- Load IDT (lidt instruction)

**Key Skills:**
- IDT structure
- Interrupt numbers
- CPU exceptions
- Inline assembly for lidt/sti/cli

**Test:**
```
1. Intentionally divide by zero
2. Exception handler prints "Division by zero!"
3. System continues (ideally)
```

---

### Phase 6: Timer and Task Creation (Week 3-4)

**Goal:** Get timer firing, create test tasks

**Deliverable:**
- `timer.c/h` (PIT programming)
- `task.c/h` (task structure)
- Timer interrupt handler
- Create 2-3 test tasks

**Key Skills:**
- PIT I/O port programming
- Interrupt rate calculation
- Task structure design
- Stack setup for tasks

**Test:**
```
$ qemu-system-i386 -drive file=os.img,format=raw

[QEMU window]
Booting...
In protected mode!
Hello from kernel!
Interrupts initialized
Tasks created
Timer started
Tick! Tick! Tick!
```

---

### Phase 7: Context Switching (Week 4)

**Goal:** Save/restore task state during interrupts

**Deliverable:**
- `scheduler.c/h` (round-robin queue)
- Context switch assembly code
- Task switching logic

**Key Skills:**
- Assembly register save/restore
- ESP manipulation
- Interrupt return path (iret)
- Inline assembly (asm keyword in C)

**Test:**
```
1. Create 2 tasks
2. Each prints its name in loop
3. See output: T1 T2 T1 T2 T1 T2...
4. Tasks switch every timer tick
```

---

### Phase 8: Full Scheduler (Week 4-5)

**Goal:** Run multiple tasks concurrently

**Deliverable:**
- `scheduler.c/h` (complete)
- 3-5 test tasks
- Proper round-robin

**Key Skills:**
- Task queue management
- Index arithmetic
- Circular buffers

**Test:**
```
$ qemu-system-i386 -drive file=os.img,format=raw

[QEMU window]
T1 T2 T3 T1 T2 T3 T1 T2 T3 T1 T2 T3 ...
```

---

### Phase 9: Polish & Testing (Week 5-6)

**Goal:** Clean up code, add features

**Optional additions:**
- Task priority (for future)
- Better task states (BLOCKED, etc.)
- Yield() function (task gives up CPU)
- Show current task on screen
- Timing statistics
- Error handling

**Deliverable:**
- Clean codebase
- Good documentation
- README.md
- GitHub repo

---

## Summary Table

| Phase | Duration | Goal | Output |
|-------|----------|------|--------|
| 1 | 3 days | Boot + print | "Booting..." on screen |
| 2 | 4 days | Protected mode | Switch to 32-bit |
| 3 | 3 days | Load kernel | Bootloader → kernel |
| 4 | 2 days | Console I/O | Printf-like printing |
| 5 | 3 days | Interrupts | IDT setup, exceptions |
| 6 | 4 days | Timer & tasks | Timer fires, tasks created |
| 7 | 5 days | Context switch | Save/restore registers |
| 8 | 4 days | Scheduler | Tasks run concurrently |
| 9 | 5 days | Polish | Clean repo, documentation |
| **TOTAL** | **~33 days** | **Full OS** | **Runnable kernel** |

---

## Key Assembly Instructions You'll Use

```asm
mov eax, ebx          ; Move (copy)
push eax              ; Push to stack
pop eax               ; Pop from stack
call label            ; Call function (pushes return address)
ret                   ; Return from function (pops IP)
jmp label             ; Unconditional jump
jne label             ; Jump if not equal
or/and eax, ebx       ; Bitwise operations
lgdt [gdt_ptr]        ; Load GDT
lidt [idt_ptr]        ; Load IDT
cli                   ; Clear interrupts (disable)
sti                   ; Set interrupts (enable)
iret                  ; Interrupt return
outb port, al         ; Write byte to I/O port
inb port              ; Read byte from I/O port
times N db 0          ; Repeat N zero bytes
hlt                   ; Halt CPU
nop                   ; No operation
```

---

## Key C Macros You'll Write

```c
#define TRUE 1
#define FALSE 0

#define NULL ((void*)0)

#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25
#define VIDEO_MEMORY 0xB8000

#define MAX_TASKS 10

#define TASK_RUNNING 0
#define TASK_READY 1
#define TASK_BLOCKED 2

// Inline assembly
#define cli() asm("cli")
#define sti() asm("sti")
#define hlt() asm("hlt")

// I/O
#define outb(port, data) asm("outb %0, %1" : : "a"(data), "Nd"(port))
#define inb(port) asm("inb %0" : "=a"(result) : "Nd"(port)); return result
```

---

## Common Pitfalls

1. **Bootloader Size**
   - Must be exactly 512 bytes
   - Don't exceed with too much code
   - Use `times N db 0` to pad

2. **Stack Overflow**
   - Stack grows downward (high → low)
   - Each task needs ~1KB stack
   - Don't overlap with other data

3. **Segment/Offset Confusion**
   - Real mode: multiply segment by 16
   - Protected mode: just use linear address
   - Different rules, easy to mix up

4. **Context Switch Race Conditions**
   - Interrupts can fire while context switching
   - Disable interrupts during critical sections
   - Use cli/sti carefully

5. **Memory Layout**
   - Kernel at 0x10000 (from linker script)
   - Bootloader at 0x7C00 (BIOS loads here)
   - Stacks must not overlap
   - Video memory read-only

6. **PIT Timer Frequency**
   - Default ~18.2 Hz (55ms per tick)
   - Can reprogram for different rates
   - Too fast = lots of context switches
   - Too slow = unresponsive

---

## Debugging Tips

1. **Print early, print often**
   ```c
   screen_print("Checkpoint 1\n");
   // ... code ...
   screen_print("Checkpoint 2\n");
   ```

2. **Use QEMU with GDB**
   ```bash
   qemu-system-i386 -kernel os.img -S -gdb tcp::1234
   # In another terminal:
   gdb
   (gdb) target remote :1234
   (gdb) break kernel_main
   (gdb) continue
   ```

3. **Check compilation**
   ```bash
   nasm -f elf32 boot.asm -o boot.o
   # Look for error messages
   
   gcc -c kernel.c -o kernel.o
   # Look for warnings too (gcc -Wall -Wextra)
   ```

4. **Verify binary layout**
   ```bash
   objdump -h os.img
   # Check that sections are where you expect
   
   hexdump -C os.img | head
   # Look for bootloader code
   ```

5. **QEMU debugging output**
   ```bash
   qemu-system-i386 os.img -d int,cpu_reset
   # Shows interrupts and CPU state changes
   ```

---

## Resume Talking Points

After completing this project, you can discuss:

- "Explain the bootloader to kernel transition"
  - Real mode limitations
  - Protected mode setup
  - GDT and IDT structures

- "How does context switching work?"
  - Interrupt handlers
  - Register saving
  - Stack pointer swapping

- "What's the scheduler doing?"
  - Round-robin algorithm
  - Task queue management
  - Time slicing

- "Why these design choices?"
  - Why x86 32-bit
  - Why round-robin (simple, fair)
  - Why this task structure

- "What would you improve?"
  - Priority scheduling
  - Memory protection
  - Virtual memory / paging
  - Synchronization primitives (mutex, semaphore)

---

## Conclusion

This architecture gives you a minimal but complete OS:
- Bootloader that loads kernel
- Kernel that manages CPU time
- Interrupt system for preemption
- Scheduler that runs multiple tasks
- ~1500 lines of code total

It's small enough to understand completely, but large enough to hit real OS concepts.

**Ready to start coding? Pick Phase 1!**
