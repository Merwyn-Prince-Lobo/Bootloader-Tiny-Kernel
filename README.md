# Please feel hesitant to contribute this is a personal learning project
##           thank u 

















note:  how to run or work on ts
```
git clone https://github.com/Merwyn-Prince-Lobo/Bootloader-Tiny-Kernel
cd Bootloader-Tiny-Kernel

sudo apt update
sudo apt install nasm gcc make gdb binutils qemu-system-x86 qemu-utils

#pls verify 
nasm --version
gcc --version
ld --version
make --version
qemu-system-i386 --version
gdb --version

```

to build and check the build 
```
# Build the OS
make

# Check if os.img was created
ls -l os.img

# Should show something like: -rw-r--r-- 1 user user 65536 Aug 29 12:34 os.img i think 
```