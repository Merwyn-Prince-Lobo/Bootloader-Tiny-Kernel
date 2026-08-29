# C Basics for Kernel Development(claude cause this is just learning material)

## Table of Contents
1. [Data Types](#data-types)
2. [Pointers](#pointers)
3. [Arrays](#arrays)
4. [Structs](#structs)
5. [Functions](#functions)
6. [Control Flow](#control-flow)
7. [Memory Access](#memory-access)
8. [Macros](#macros)
9. [Header Files](#header-files)
10. [OS Dev Specific Patterns](#os-dev-specific-patterns)

---

## Data Types

### **Integer Types**

```c
#include <stdint.h>

// Unsigned integers (0 to max value)
uint8_t   x;            // 8-bit (0 to 255)
uint16_t  x;            // 16-bit (0 to 65,535)
uint32_t  x;            // 32-bit (0 to 4,294,967,295)
uint64_t  x;            // 64-bit

// Signed integers (negative to positive)
int8_t    x;            // 8-bit (-128 to 127)
int16_t   x;            // 16-bit (-32,768 to 32,767)
int32_t   x;            // 32-bit (-2B to 2B)
int64_t   x;            // 64-bit

// Legacy C (avoid in kernel code)
char      x;            // Usually 8-bit
short     x;            // Usually 16-bit
int       x;            // Usually 32-bit
long      x;            // Machine-dependent (risky!)
```

### **Floating Point (Usually Not Used in Kernel)**

```c
float   x;              // 32-bit float
double  x;              // 64-bit float
```

### **Other Types**

```c
void    *ptr;           // Generic pointer (any address)
char    str[256];       // Character array (string)
```

### **Type Sizes (For Reference)**

```c
sizeof(uint8_t)   // 1 byte
sizeof(uint16_t)  // 2 bytes
sizeof(uint32_t)  // 4 bytes
sizeof(uint64_t)  // 8 bytes
```

---

## Pointers

### **What is a Pointer?**

A pointer is a **variable that stores a memory address**.

```
Normal variable:    int x = 42;        // x is 42
Pointer variable:   int *p = &x;       // p is the ADDRESS of x
```

### **Declaration and Initialization**

```c
// Declare a pointer
int *ptr;               // Pointer to int (uninitialized, dangerous!)
int *ptr = NULL;        // Pointer to int (initialized to NULL)

uint32_t *addr;         // Pointer to 32-bit value
unsigned char *mem;     // Pointer to byte

// Get address of variable
int x = 42;
int *p = &x;            // p now points to x

// Dereference (access value through pointer)
int value = *p;         // value = 42 (dereference p)
*p = 100;               // Change x to 100 through pointer
```

### **Pointer Arithmetic**

```c
uint32_t *ptr = (uint32_t *)0x10000;

ptr++;                  // Move forward by sizeof(uint32_t) = 4 bytes
                        // ptr now points to 0x10004

ptr += 2;               // Move forward by 2 * 4 = 8 bytes
                        // ptr now points to 0x1000C

ptr--;                  // Move back by 4 bytes
                        // ptr now points to 0x10008

uint32_t *ptr2 = ptr + 10;  // ptr2 = ptr + (10 * 4 bytes)
```

**Important:** Pointer arithmetic depends on type!

```c
uint8_t *p1 = 0x1000;
p1++;                   // p1 now = 0x1001 (increments by 1)

uint32_t *p4 = 0x1000;
p4++;                   // p4 now = 0x1004 (increments by 4)

uint16_t *p2 = 0x1000;
p2++;                   // p2 now = 0x1002 (increments by 2)
```

### **Pointer to Pointer**

```c
int x = 42;
int *p = &x;            // p points to x
int **pp = &p;          // pp points to p

int value = **pp;       // value = 42 (dereference twice)
```

### **NULL Pointer**

```c
#define NULL ((void*)0)

int *ptr = NULL;        // Null pointer (points nowhere)

if(ptr != NULL) {
    // Safe to dereference
    int x = *ptr;
}
```

---

## Arrays

### **Array Declaration**

```c
int arr[10];            // Array of 10 integers
uint8_t buffer[256];    // Array of 256 bytes
char string[32];        // Array of 32 characters (string buffer)

// Initialize
int arr[5] = {1, 2, 3, 4, 5};
int arr[5] = {0};       // Initialize all to zero

// 2D array
int matrix[3][4];       // 3 rows, 4 columns
```

### **Array Indexing**

```c
int arr[5] = {10, 20, 30, 40, 50};

int x = arr[0];         // x = 10 (first element)
int y = arr[4];         // y = 50 (last element)

arr[2] = 100;           // Set third element to 100
```

### **Array and Pointers are Equivalent**

```c
int arr[5] = {10, 20, 30, 40, 50};
int *ptr = arr;         // ptr points to first element

arr[0]   == *ptr;       // Both access same element
arr[1]   == *(ptr + 1); // Both access second element
arr[i]   == *(ptr + i); // General form
```

### **Iterating Through Array**

```c
int arr[10];

// Using index
for(int i = 0; i < 10; i++) {
    arr[i] = i * 2;
}

// Using pointer
int *ptr = arr;
for(int i = 0; i < 10; i++) {
    *ptr = i * 2;
    ptr++;
}
```

### **Passing Arrays to Functions**

```c
// Arrays decay to pointers in function parameters
void process_array(int *arr, int size) {
    for(int i = 0; i < size; i++) {
        arr[i] = arr[i] * 2;
    }
}

// Call
int myarr[10];
process_array(myarr, 10);

// Equivalent:
process_array(&myarr[0], 10);
```

---

## Structs

### **Structure Definition**

```c
// Define a structure
struct task {
    uint32_t esp;           // Stack pointer
    uint32_t ebp;           // Base pointer
    char name[32];          // Task name
    uint32_t state;         // Task state (0=ready, 1=running, etc.)
    uint32_t priority;      // Priority (0-255)
};

// Now struct task is a type you can use
```

### **Creating and Using Structs**

```c
// Create a variable of type "struct task"
struct task my_task;

// Access members with dot notation
my_task.esp = 0x90000;
my_task.ebp = 0x90000;
my_task.state = 1;

// Copy entire struct
struct task task2 = my_task;
task2.priority = 10;
```

### **Struct Pointers**

```c
struct task *ptr = &my_task;

// Access members through pointer with -> operator
ptr->esp = 0x90000;     // Same as my_task.esp = 0x90000
ptr->state = 1;         // Same as my_task.state = 1

// Equivalent: (*ptr).esp = 0x90000
```

### **Typedef for Convenience**

```c
// Instead of always typing "struct task"
typedef struct {
    uint32_t esp;
    uint32_t ebp;
    char name[32];
    uint32_t state;
} task_t;

// Now can use just "task_t"
task_t my_task;
task_t *ptr = &my_task;

ptr->esp = 0x90000;
```

### **Array of Structs**

```c
struct task tasks[10];      // Array of 10 tasks

tasks[0].esp = 0x90000;
tasks[1].esp = 0x90000;
tasks[5].state = 1;

// Pointer to array
struct task *ptr = tasks;
ptr[0].esp = 0x90000;       // Same as tasks[0].esp
(ptr + 1)->esp = 0x90000;   // Same as tasks[1].esp
```

### **Nested Structs**

```c
struct registers {
    uint32_t eax;
    uint32_t ebx;
    uint32_t ecx;
};

struct task {
    struct registers regs;
    uint32_t stack_pointer;
};

// Usage
struct task t;
t.regs.eax = 42;
```

---

## Functions

### **Function Declaration and Definition**

```c
// Declaration (tells compiler function exists)
void greet(const char *name);
int add(int a, int b);

// Definition (actual implementation)
void greet(const char *name) {
    screen_print("Hello, ");
    screen_print(name);
    screen_print("!\n");
}

int add(int a, int b) {
    return a + b;
}

// Calling function
greet("World");
int result = add(5, 3);     // result = 8
```

### **Function Parameters**

```c
// Pass by value (function gets a copy)
void increment(int x) {
    x++;                    // Only local copy is changed
}

int a = 5;
increment(a);               // a is still 5

// Pass by pointer (function can modify original)
void increment_ptr(int *x) {
    (*x)++;                 // Original is changed
}

int a = 5;
increment_ptr(&a);          // a is now 6

// Pass array (arrays always pass as pointers)
void clear_array(uint8_t *arr, int size) {
    for(int i = 0; i < size; i++) {
        arr[i] = 0;         // Modifies original array
    }
}
```

### **Return Values**

```c
// Return by value
int get_value() {
    return 42;
}

// Return via pointer
int* get_pointer() {
    static int x = 42;      // Must be static (live beyond function)
    return &x;
}

// Return struct
struct task create_task() {
    struct task t;
    t.esp = 0x90000;
    return t;               // Copy is returned
}

// Return pointer to struct (more efficient)
struct task* create_task_ptr() {
    static struct task t;
    t.esp = 0x90000;
    return &t;
}
```

### **Function Pointers**

```c
// Declare function pointer
void (*func_ptr)(int);      // Pointer to function taking int, returning void

// Point to a function
void my_function(int x) {
    // Do something
}

func_ptr = my_function;     // func_ptr now points to my_function

// Call through pointer
func_ptr(42);               // Same as my_function(42)

// Array of function pointers (useful for interrupt handlers)
void (*handlers[256])(void);

handlers[0] = divide_by_zero_handler;
handlers[1] = debug_handler;

handlers[0]();              // Call divide_by_zero_handler
```

---

## Control Flow

### **If-Else**

```c
if(x == 5) {
    // x is exactly 5
} else if(x > 5) {
    // x is greater than 5
} else if(x < 5) {
    // x is less than 5
} else {
    // This never runs (redundant)
}

// Comparison operators
x == y      // Equal
x != y      // Not equal
x > y       // Greater
x >= y      // Greater or equal
x < y       // Less
x <= y      // Less or equal

// Logical operators
x > 0 && x < 10     // AND (both true)
x == 0 || y == 0    // OR (at least one true)
!done               // NOT (invert boolean)
```

### **Switch Statement**

```c
switch(state) {
    case 0:
        screen_print("Ready\n");
        break;
    case 1:
        screen_print("Running\n");
        break;
    case 2:
        screen_print("Blocked\n");
        break;
    default:
        screen_print("Unknown\n");
}
```

### **For Loop**

```c
// Iterate from 0 to 9
for(int i = 0; i < 10; i++) {
    // i = 0, 1, 2, ..., 9
}

// Backwards
for(int i = 9; i >= 0; i--) {
    // i = 9, 8, 7, ..., 0
}

// Loop through array
int arr[5] = {1, 2, 3, 4, 5};
for(int i = 0; i < 5; i++) {
    printf("%d\n", arr[i]);
}

// Infinite loop (watch out!)
for(;;) {
    // Never exits unless break
}
```

### **While Loop**

```c
int i = 0;
while(i < 10) {
    i++;
}

// Infinite loop
while(1) {
    // Never exits unless break
}

// Pointer iteration
char *str = "Hello";
while(*str != '\0') {
    // Process character in *str
    str++;
}
```

### **Do-While Loop**

```c
int i = 0;
do {
    i++;
} while(i < 10);

// Executes body at least once
```

### **Break and Continue**

```c
for(int i = 0; i < 10; i++) {
    if(i == 5) {
        break;              // Exit loop immediately
    }
    if(i == 3) {
        continue;           // Skip to next iteration
    }
    // Process i
}
```

---

## Memory Access

### **Direct Memory Access (Key for OS)**

```c
// Cast address to pointer
unsigned char *video = (unsigned char *)0xB8000;

// Write byte
video[0] = 'A';             // Write 'A' at 0xB8000
video[1] = 0x07;            // Write color at 0xB8001

// Read byte
char ch = video[0];         // Read from 0xB8000

// Write multiple
video[0] = 'H';
video[2] = 'e';
video[4] = 'l';
video[6] = 'l';
video[8] = 'o';

// Write 32-bit value
uint32_t *addr = (uint32_t *)0x10000;
*addr = 0x12345678;         // Write 32-bit value
```

### **Iterating Through Memory**

```c
// Clear memory (set to zero)
unsigned char *mem = (unsigned char *)0x90000;
for(int i = 0; i < 4096; i++) {
    mem[i] = 0;
}

// Or with pointer
for(int i = 0; i < 4096; i++) {
    *mem = 0;
    mem++;
}

// Copy memory
unsigned char *src = (unsigned char *)0x10000;
unsigned char *dst = (unsigned char *)0x20000;

for(int i = 0; i < 1024; i++) {
    dst[i] = src[i];
}
```

### **Filling Memory**

```c
// Set all bytes to a value
unsigned char *memory = (unsigned char *)0xB8000;
int size = 4000;

for(int i = 0; i < size; i++) {
    memory[i] = 0;          // Clear to 0
}

// Using memset (if available)
// memset((void *)0xB8000, 0, 4000);
```

---

## Macros

### **Define Constants**

```c
#define MAX_TASKS 10
#define STACK_SIZE 4096
#define VIDEO_MEMORY 0xB8000

// Usage
uint32_t stack[STACK_SIZE];
struct task tasks[MAX_TASKS];
unsigned char *video = (unsigned char *)VIDEO_MEMORY;
```

### **Define Macros (Like Functions)**

```c
// Simple macro
#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25

// Macro with parameter
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

// Macro with multiple statements
#define DISABLE_INTERRUPTS() \
    do { \
        asm("cli"); \
    } while(0)

#define ENABLE_INTERRUPTS() \
    do { \
        asm("sti"); \
    } while(0)

// Usage
DISABLE_INTERRUPTS();
// Critical code here
ENABLE_INTERRUPTS();
```

### **Conditional Compilation**

```c
#ifdef DEBUG
    screen_print("Debug mode\n");
#endif

#if KERNEL_VERSION > 1
    // New features
#else
    // Old features
#endif
```

### **Common Macros for OS Dev**

```c
#define NULL ((void*)0)
#define TRUE 1
#define FALSE 0

#define UNUSED(x) (void)(x)     // Suppress unused warnings

#define PACKED __attribute__((packed))  // No padding in struct

typedef struct {
    uint32_t esp;
    uint32_t ebp;
} __attribute__((packed)) registers_t;
```

---

## Header Files

### **Creating a Header File (kernel.h)**

```c
#ifndef KERNEL_H
#define KERNEL_H

#include <stdint.h>
#include <stddef.h>

// Function declarations
void kernel_main();
void screen_init();
void screen_print(const char *str);

// Type definitions
typedef struct {
    uint32_t esp;
    uint32_t ebp;
} registers_t;

// Constants
#define MAX_TASKS 10
#define STACK_SIZE 4096

#endif  // KERNEL_H
```

### **Using a Header File (kernel.c)**

```c
#include "kernel.h"
#include <stdint.h>

#define VIDEO_MEMORY 0xB8000

void screen_init() {
    unsigned char *video = (unsigned char *)VIDEO_MEMORY;
    for(int i = 0; i < 80 * 25 * 2; i += 2) {
        video[i] = ' ';
        video[i+1] = 0x07;
    }
}

void screen_print(const char *str) {
    unsigned char *video = (unsigned char *)VIDEO_MEMORY;
    
    for(int i = 0; str[i] != '\0'; i++) {
        video[i * 2] = str[i];
        video[i * 2 + 1] = 0x07;
    }
}

void kernel_main() {
    screen_init();
    screen_print("Hello from kernel!");
}
```

### **Include Guards**

```c
#ifndef HEADER_H
#define HEADER_H

// Header content here

#endif  // HEADER_H
```

Prevents including same header twice.

---

## OS Dev Specific Patterns

### **Video Memory Output**

```c
#define VIDEO_MEMORY 0xB8000
#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25

typedef struct {
    int x;
    int y;
} cursor_t;

static cursor_t cursor = {0, 0};

void put_char(char c, uint8_t color) {
    unsigned char *video = (unsigned char *)VIDEO_MEMORY;
    int pos = (cursor.y * SCREEN_WIDTH + cursor.x) * 2;
    
    video[pos] = c;
    video[pos + 1] = color;
    
    cursor.x++;
    if(cursor.x >= SCREEN_WIDTH) {
        cursor.x = 0;
        cursor.y++;
    }
}

void print_string(const char *str) {
    for(int i = 0; str[i] != '\0'; i++) {
        put_char(str[i], 0x07);    // 0x07 = white on black
    }
}
```

### **Task Management Structure**

```c
typedef struct {
    uint32_t esp;
    uint32_t ebp;
    uint32_t state;
    char name[32];
    void (*func)(void);
    uint32_t stack[256];        // 1 KB stack per task
} task_t;

// Create task queue
#define MAX_TASKS 10
static task_t task_queue[MAX_TASKS];
static int task_count = 0;

void create_task(void (*func)(void), const char *name) {
    if(task_count >= MAX_TASKS) return;
    
    task_t *t = &task_queue[task_count];
    t->func = func;
    t->state = 0;           // Ready
    t->esp = (uint32_t)&t->stack[255];  // Top of stack
    
    for(int i = 0; i < 32 && name[i]; i++) {
        t->name[i] = name[i];
    }
    
    task_count++;
}
```

### **Interrupt Handler Pattern**

```c
typedef struct {
    uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax;
    uint32_t int_no, err_code;
    uint32_t eip, cs, eflags, useresp, ss;
} __attribute__((packed)) registers_t;

void interrupt_handler(registers_t regs) {
    if(regs.int_no == 0) {
        screen_print("Divide by zero!\n");
    } else if(regs.int_no == 14) {
        screen_print("Page fault!\n");
    }
}
```

### **Bit Manipulation Helpers**

```c
// Set bit
#define SET_BIT(byte, bit) ((byte) |= (1 << (bit)))

// Clear bit
#define CLEAR_BIT(byte, bit) ((byte) &= ~(1 << (bit)))

// Toggle bit
#define TOGGLE_BIT(byte, bit) ((byte) ^= (1 << (bit)))

// Test bit
#define TEST_BIT(byte, bit) (((byte) >> (bit)) & 1)

// Usage
uint8_t flags = 0;
SET_BIT(flags, 0);          // Set bit 0
if(TEST_BIT(flags, 0)) {    // Check bit 0
    // Do something
}
CLEAR_BIT(flags, 0);        // Clear bit 0
```

### **Safe Memory Copy**

```c
void memcpy_safe(void *dst, const void *src, int size) {
    unsigned char *d = (unsigned char *)dst;
    unsigned char *s = (unsigned char *)src;
    
    for(int i = 0; i < size; i++) {
        d[i] = s[i];
    }
}

// Usage
uint32_t dest[256];
uint32_t source[256] = {1, 2, 3, ...};
memcpy_safe(dest, source, sizeof(source));
```

---

## Compiler Flags for OS Dev

```bash
# -m32: Compile for 32-bit (even on 64-bit system)
gcc -m32 -c kernel.c

# -ffreestanding: Don't assume standard C environment
gcc -m32 -ffreestanding -c kernel.c

# -fno-pie: Disable Position Independent Executable
gcc -m32 -ffreestanding -fno-pie -c kernel.c

# -Wall -Wextra: Show all warnings
gcc -m32 -ffreestanding -fno-pie -Wall -Wextra -c kernel.c

# Typical compilation
gcc -m32 -c -ffreestanding -fno-pie -Wall kernel.c -o kernel.o
```

---

## Common Gotchas

### **1. Pointer Arithmetic Type Matters**

```c
uint8_t *p8 = (uint8_t *)0x1000;
p8++;           // p8 = 0x1001 (increments by 1)

uint32_t *p32 = (uint32_t *)0x1000;
p32++;          // p32 = 0x1004 (increments by 4)
```

### **2. String Termination**

```c
char str[5] = "Hi";     // str = 'H', 'i', '\0', ?, ?
char str[5] = {'H', 'i', '\0', 0, 0};  // Explicit
```

### **3. Array Decay to Pointer**

```c
int arr[10];
int *p = arr;           // p points to arr[0]

// These are equivalent:
arr[5]          == p[5]  == *(arr + 5)  == *(p + 5)
```

### **4. Function Parameter Arrays**

```c
void func(int arr[10]) {
    // arr is actually a pointer!
    // sizeof(arr) is sizeof(pointer), not 40!
}
```

### **5. Forgetting NULL Checks**

```c
int *ptr = NULL;
*ptr = 5;               // CRASH! (segmentation fault)

if(ptr != NULL) {
    *ptr = 5;           // Safe
}
```

---

## Summary Table

| Concept | Example | Notes |
|---------|---------|-------|
| **Variable** | `int x = 42;` | Store value |
| **Pointer** | `int *p = &x;` | Store address |
| **Dereference** | `*p` | Access value at address |
| **Array** | `int arr[10];` | Collection of same type |
| **String** | `char *str = "Hello";` | Char array ending in \0 |
| **Struct** | `struct task { ... };` | Collection of different types |
| **Function** | `void func() { ... }` | Reusable code block |
| **Macro** | `#define MAX 10` | Compile-time substitution |

---

## Quick Reference: Common Patterns

```c
// Clear memory
for(int i = 0; i < size; i++) buffer[i] = 0;

// Copy memory
for(int i = 0; i < size; i++) dst[i] = src[i];

// Iterate string
for(int i = 0; str[i] != '\0'; i++) { ... }

// Iterate pointer
for(int *p = start; p < end; p++) { ... }

// Find in array
for(int i = 0; i < size; i++) {
    if(arr[i] == target) return i;
}
return -1;

// Filter array
for(int i = 0; i < size; i++) {
    if(predicate(arr[i])) process(arr[i]);
}
```

---

## References

- C11 Standard
- Linux Kernel Source Code
- OS Development Tutorials
- Your C compiler documentation (gcc/clang)