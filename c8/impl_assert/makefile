BUILD_DIR = ./build  
BOOT_DIR = ./boot
ENTRY_POINT = 0xC0001500
AS = nasm
CC = gcc 
LD = ld 
MBR_LIB = -I $(BOOT_DIR)/src/include
LIB = -I lib/ -I lib/kernel -I kernel/src -I device/src
ASFLAGS = -f elf
CFLAGS = -m32 -Wall $(LIB) -c -fno-builtin -W -Wstrict-prototypes \
	       -Wmissing-prototypes
LDFLAGS = -m elf_i386 -Ttext $(ENTRY_POINT) -e main
OBJS = $(BUILD_DIR)/main.o $(BUILD_DIR)/init.o $(BUILD_DIR)/interrupt.o \
      $(BUILD_DIR)/timer.o $(BUILD_DIR)/kernel.o $(BUILD_DIR)/print.o \
      $(BUILD_DIR)/debug.o



##############     c代码编译     ###############
$(BUILD_DIR)/main.o: kernel/main.c lib/kernel/print.h \
        lib/stdint.h kernel/init.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/init.o: kernel/init.c kernel/init.h lib/kernel/print.h \
        lib/stdint.h kernel/interrupt.h device/timer.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/interrupt.o: kernel/interrupt.c kernel/interrupt.h \
        lib/stdint.h kernel/global.h lib/kernel/io.h lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/timer.o: device/timer.c device/timer.h lib/stdint.h\
         lib/kernel/io.h lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/debug.o: kernel/debug.c kernel/debug.h \
        lib/kernel/print.h lib/stdint.h kernel/interrupt.h
	$(CC) $(CFLAGS) $< -o $@
	
	
##############    汇编代码编译    ###############
$(BUILD_DIR)/kernel.o: kernel/kernel.S
	$(AS) $(ASFLAGS) $< -o $@
$(BUILD_DIR)/print.o: lib/kernel/print.S
	$(AS) $(ASFLAGS) $< -o $@

	
##############    链接所有目标文件    #############
$(BUILD_DIR)/kernel.binary: $(OBJS)
	$(LD) $(LDFLAGS) $^ -O $@
	
############## 生成 MBR #########################
$(BUILD_DIR)/mbr.binary: boot/src/mbr.S 
	$(AS) $(MBR_LIB) $< -o $@
$(BUILD_DIR)/loader.binary: boot/src/loader.S 
	$(AS) $(MBR_LIB) $< -o $@
	
.PHONY : mk_dir hd clean all

mk_dir:
	if [[ ! -d $(BUILD_DIR) ]];then mkdir $(BUILD_DIR);fi

hd:
	dd if=$(BUILD_DIR)/mbr.binary \
           of=/Users/bughh/KaliProject/OSProject/hd60M.img \
           bs=512 count=1 seek=0 conv=notrunc
	dd if=$(BUILD_DIR)/loader.binary \
					 of=/Users/bughh/KaliProject/OSProject/hd60M.img \
					 bs=512 count=3 seek=2 conv=notrunc
	dd if=$(BUILD_DIR)/kernel.binary \
           of=/Users/bughh/KaliProject/OSProject/hd60M.img \
           bs=512 count=200 seek=9 conv=notrunc

clean:
	cd $(BUILD_DIR) && rm -f ./*

build: $(BUILD_DIR)/kernel.binary

start:
	bochs -f /Users/bughh/KaliProject/OSProject/bochsrc.disk

all: mk_dir build hd start 