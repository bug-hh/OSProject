#!/bin/bash
nasm -I ./boot/src/include/ -o ./boot/bin/mbr.binary boot/src/mbr.S
nasm -I ./boot/src/include/ -o ./boot/bin/loader.binary boot/src/loader.S

dd if=./boot/bin/mbr.binary of=../../hd60M.img bs=512 count=1 seek=0 conv=notrunc
dd if=./boot/bin/loader.binary of=../../hd60M.img bs=512 count=3 seek=2 conv=notrunc

# use 32 bit
# nasm -f elf -o lib/kernel/print.o lib/kernel/print.S

# gcc -m32 -I lib/kernel -c -o kernel/main.o kernel/main.c

# ld -m elf_i386 -Ttext 0xc0001500 -e main -o ./kernel.binary kernel/main.o lib/kernel/print.o 


# dd if=./kernel.binary of=./hd60M.img bs=512 count=200 seek=9 conv=notrunc

bochs -f ../../bochsrc.disk
