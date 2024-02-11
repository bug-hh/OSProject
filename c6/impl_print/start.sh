#!/bin/bash
if [ ! -d "boot/bin" ]; then
  mkdir -p boot/bin
fi

if [ ! -d "kernel/obj" ]; then
  mkdir -p kernel/obj
fi

if [ ! -d "kernel/bin" ]; then
  mkdir -p kernel/bin
fi

nasm -I ./boot/src/include/ -o ./boot/bin/mbr.binary boot/src/mbr.S
nasm -I ./boot/src/include/ -o ./boot/bin/loader.binary boot/src/loader.S

dd if=./boot/bin/mbr.binary of=../../hd60M.img bs=512 count=1 seek=0 conv=notrunc
dd if=./boot/bin/loader.binary of=../../hd60M.img bs=512 count=3 seek=2 conv=notrunc

# use 32 bit
nasm -f elf -o lib/kernel/print.o lib/kernel/print.S

gcc -m32 -c -o kernel/obj/main.o kernel/src/main.c

ld -m elf_i386 -Ttext 0xc0001500 -e main -o kernel/bin/kernel.binary kernel/obj/main.o lib/kernel/print.o

dd if=kernel/bin/kernel.binary of=../../hd60M.img bs=512 count=200 seek=9 conv=notrunc

bochs -f ../../bochsrc.disk
