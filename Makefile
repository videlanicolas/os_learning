
SRCS?=$(wildcard src/kernel/*.c)
HEADERS = $(wildcard src/kernel/*.h)
OBJS?=$(SRCS:.c=.o)

BOOTLOADER_SRC?=src/boot/bootloader.asm

CFLAGS?=-fno-pie -m32 -ffreestanding
LDFLAGS?=-m elf_i386 -Ttext 0x1000 --oformat binary

BOOTLOADER?=bin/bootloader.img
KERNEL?=bin/kernel.img
OS?=bin/os.img

SERIAL_LOG?=serial.log

QEMU?=/usr/bin/qemu-system-i386
NASM?=nasm
GCC?=gcc
LD?=ld

run: $(OS) | $(QEMU)
	$(QEMU) -drive file=$<,format=raw,if=floppy -serial file:$(SERIAL_LOG)

run_courses: $(OS) | $(QEMU)
	$(QEMU) -display curses -drive file=$<,format=raw,if=floppy -serial file:$(SERIAL_LOG)

$(OS): $(BOOTLOADER) $(KERNEL)
	cat $^ > $@

$(BOOTLOADER): | $(BOOTLOADER_SRC) bin
	$(NASM) $(BOOTLOADER_SRC) -f bin -o $@

$(KERNEL): src/kernel/kernel_entry.o ${OBJS} | bin
# Link the Kernel.
# We mark 0x1000 as the offset for all instructions, this will be the offset we'll use in the
# bootloader when loading the Kernel in memory.
# Also link the kernel_entry code with our Kernel main code, this goes first.
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.c ${HEADERS} | bin
# Compile the Kernel.
# We need to compile with -ffreestanding because the standard library might not exist,
# and startup may not necessarily be at 'main'. This is typical when compiling Kernels.
	$(GCC) $(CFLAGS) -c $< -o $@

src/kernel/kernel_entry.o: | src/kernel/kernel_entry.asm bin
# Make the entry point, which sole purpose is to find main and execute it.
# Make it with ELF (Executable & Linkable File) rather than raw binary, since this will be
# used by the C linker.
	$(NASM) src/kernel/kernel_entry.asm -f elf32 -o $@

bin:
	mkdir -p bin

clean:
	rm -rf bin src/kernel/*.o src/boot/*.o *.o
