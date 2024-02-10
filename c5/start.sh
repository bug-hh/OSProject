#!/bin/bash
nasm -I ./boot/src/include/ -o ./boot/bin/mbr.bin boot/src/mbr.S
nasm -I ./boot/src/include/ -o ./boot/bin/loader.bin boot/src/loader.S

dd if=./boot/bin/mbr.bin of=../hd60M.img bs=512 count=1 seek=0 conv=notrunc
dd if=./boot/bin/loader.bin of=../hd60M.img bs=512 count=3 seek=2 conv=notrunc

# use 32 bit
# nasm -f elf -o lib/kernel/print.o lib/kernel/print.S

# gcc -m32 -I lib/kernel -c -o kernel/main.o kernel/main.c

# ld -m elf_i386 -Ttext 0xc0001500 -e main -o ./kernel.bin kernel/main.o lib/kernel/print.o 


# dd if=./kernel.bin of=./hd60M.img bs=512 count=200 seek=9 conv=notrunc

bochs -f ../bochsrc.disk