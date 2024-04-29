os: bootloader kernel
	rm bin/os.img || true
	cat bin/bootloader.img bin/kernel.img > bin/os.img

bootloader: init
	nasm src/boot/bootloader.asm -f bin -o bin/bootloader.img

kernel: init
	# Make the entry point, which sole purpose is to find main and execute it.
	# Make it with ELF (Executable & Linkable File) rather than raw binary, since this will be
	# used by the C linker.
	nasm src/kernel/kernel_entry.asm -f elf32 -o bin/kernel_entry.o
	# Compile the Kernel.
	# We need to compile with -ffreestanding because the standard library might not exist,
	# and startup may not necessarily be at 'main'. This is typical when compiling Kernels.
	gcc -fno-pie -m32 -ffreestanding -c src/kernel/kernel.c -o bin/kernel.o
	# Link the Kernel.
	# We mark 0x1000 as the offset for all instructions, this will be the offset we'll use in the
	# bootloader when loading the Kernel in memory.
	# Also link the kernel_entry code with our Kernel main code, this goes first.
	ld -o bin/kernel.img -m elf_i386 -Ttext 0x1000 bin/kernel_entry.o bin/kernel.o --oformat binary

init:
	mkdir bin || true

clean:
	rm -rf bin/*
