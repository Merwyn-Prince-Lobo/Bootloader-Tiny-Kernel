cat > Makefile << 'EOF'

all: os.img

os.img: boot/boot.bin kernel/kernel.bin
	cat boot/boot.bin kernel/kernel.bin > os.img

boot/boot.bin: boot/boot.asm
	nasm -f bin boot/boot.asm -o boot/boot.bin

kernel/kernel.bin: kernel/kernel_entry.o kernel/kernel.o
	ld -m elf_i386 kernel/kernel_entry.o kernel/kernel.o -o kernel/kernel.bin

kernel/kernel_entry.o: kernel/kernel_entry.asm
	nasm -f elf32 kernel/kernel_entry.asm -o kernel/kernel_entry.o

kernel/kernel.o: kernel/kernel.c kernel/kernel.h
	gcc -m32 -c -ffreestanding kernel/kernel.c -o kernel/kernel.o

run: os.img               #emulator
	qemu-system-i386 -drive file=os.img,format=raw


clean:
	rm -f boot/*.bin kernel/*.o kernel/*.bin os.img

.PHONY: all run clean
EOF