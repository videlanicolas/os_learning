.. toctree::
   :maxdepth: 3

===============
Development log
===============

This document holds all the progress and research I make while coding this OS.

Getting started
===============

Right after pressing the power button the Processor Control Register clears the protection bit (CR0 bit 0 for x86), forcing the CPU into 16 bit Real Mode. The next thing that happens is that the CPU will fetch the first instruction for the Reset Vector address, which for x86 is 0xfffffff0. Now you might notice that this is a 32 bit address, which would not be addressable in Real Mode 16 bit. I'm going to quote the [Intel's Software Developer's](https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.pdf) manual here (section 9.1.4):

`The address FFFFFFF0H is beyond the 1-MByte addressable range of the processor while in real-address mode. The
processor is initialized to this starting address as follows. The CS register has two parts: the visible segment
selector part and the hidden base address part. In real-address mode, the base address is normally formed by
shifting the 16-bit segment selector value 4 bits to the left to produce a 20-bit base address. However, during a
hardware reset, the segment selector in the CS register is loaded with F000H and the base address is loaded with
FFFF0000H. The starting address is thus formed by adding the base address to the value in the EIP register (that
is, FFFF0000 + FFF0H = FFFFFFF0H).`

----
POST
----

The first task of the BIOS is to perform a Power-On Self Test. This checks (amongst other things):

* CPU registers are working.
* Checks the integrity of the BIOS by calculating a checksum (this has nothing to do with Secure Boot and UEFI).
* Initialize system bus.
* Initialize RAM.

If something goes wrong here usually BIOS will let us know through LEDs and beeps (e.g. 3 beeps means "Memory error").

Once POST is done we get RAM initialized in a nice way, some interesting addresses:

* 0x0000 - 0x03ff: Interrupt Vector Table (IVT), a table containing the code to execute for each BIOS interrupt (e.g. INT 13h, INT 10h, etc...).
* 0x7c00 - 0x7dff: Bootloader (unloaded at this point).
* 0xa000 - 0xbfff: Video memory.

After this is done the BIOS will now scan through all the available mass storage devices and, following a configurable priority list, will read the first sector (512 bytes) looking for a sector that has the last 2 bytes equal to 0x55AA (a.k.a. the bootloader magic bytes). When found it loads that sector from disk to memory at address 0x7c00 and jumps (JMP) to that address, effectively handing execution over to the bootloader.

------------
EFI and UEFI
------------

16 bit Real Mode sounds so old these days, with 32 and 64 bit CPUs being the majority used by consumers. BIOSes came in different flavours and implementations, some would automatically enable the A20 line for you, some others would implement Video memory on different addresses, others might even load the bootloader on a different address altogether. Throughout time BIOSes converged into one way of doing things, but there was never a standard set for the industry on where would things be loaded, what services should be available on interrupts or which mode should the CPU be booted in (Real Mode or Protected Mode). Software developers would assume manufacturers will follow other BIOS implementations and assume things are placed where is generally assumed they are, but this would not be the case for all BIOSes.

During the mid 90s Intel started working on an initiative called "Intel Boot Initiative", which focused on making booting less complicated in order to get more efficient CPUs (and thus better hardware for servers they tried to sell with HP). They designed a standard all BIOS from Intel should follow, things like:

* Automatically enable A20.
* Automatically switch to 32 bit protected mode.
* Provide standard functions (such as "Disk operations" and "Video operations").

This quickly evolved into a forum called "Unified EFI forum" involving other companies such as AMD, ARM, Dell, HP, Apple, Lenovo and Microsoft. And thus the UEFI standard was born in 2005 (actually in 2004 first contributed by Intel under the EFI name).

We're not going to go deep into UEFI (at least not now), but just to point out the differences with legacy BIOSes, UEFI provides:

* Standard functions for all platforms.
* Only available for 32 or 64 bit CPUs.
* Secure boot functionality (i.e. verify the bootloader and OS).
* Backwards compatibility with legacy BIOS (through "classes").

-----------
Bootloaders
-----------

The user pressed on the power button, BIOS (or UEFI) was loaded and executed POST, it fetched the bootloader, loaded it at `0x7c00` and then jumped (JMP) to it. The task of the bootloader is to prepare the CPU for the OS, loading the Kernel of our OS and pass on execution to it. Because we have such a short amount of space to work with (512 bytes, 1 sector), simple bootloaders are usually coded in Assembler. This guarantees we're as efficient as possible while doing all the steps we need to take. More complex bootloaders like [GRUB](https://www.gnu.org/software/grub/) use higher languages like C. For this research I've opted to code my own bootloader, so I learn more.

Given we want to make a 32 bit OS (and booting from a legacy BIOS) we need to make sure we're at 32 bit [Protected Mode](https://wiki.osdev.org/Protected_mode), this means we need to:

1. Disable interrupts.
2. Load the Kernel to memory.
3. Enable A20 line.
4. Load the GDT.
5. Switch to Protected Mode.

The first step is required so that we don't get interrupted while booting, the Kernel should re-enable interrupts once it thinks it's appropiate.

The second step is to load the Kernel from disk to memory, by using the handy interrupt `13h` (Disk operations). We do this now because we can't use BIOS functions in Protected Mode.

The third step involves enabling the A20 line. What is the A20 line you say? I made a brief summary [here](https://github.com/videlanicolas/playing-with-bootloaders/blob/main/src/common/check_a20.asm), but you can also read a more detailed explanation of what this is in [OSDev Wiki](https://wiki.osdev.org/A20). In any case, there's a handy BIOS service (`INT 15h`, `ax = 2401h`) that enables it.

The fourth step involves loading the Global Descriptor Table (GDT). This is a feature of Intel's x86 processors which you can segment memory, so that it protects the access and execution to it depending where it's being accessed from. This is the "Protected Mode" feature we're after. You can read more about it [here](https://wiki.osdev.org/GDT), but the key points are:

* You can load Code (memory that can be executed as instructions) or Data (memory that is *read only* and can't be executed) segments.
* You can set "privilege levels" (0 for highest and 3 for lowest).
* Set the portion in memory that each segment occupies.

Once all of these is done we can switch to Protected Mode by simply setting the 0 bit in `CR0`. We also need to clear the pipeline by performing a "far" jump, I explain this in [another repo](https://github.com/videlanicolas/playing-with-bootloaders/blob/main/src/switch_to_pm/bootloader.asm) if you're curious.

Now in Protected mode we need to find the Kernel's main entry point and jump to it, essentially passing over execution to the Kernel. 

Hello Kernel!
=============

The Kernel's task is to provide an API to interface with the hardware, this will abstract the Operating System and its applications from the complexities of hardware. The Kernel is just the start of the OS, it's the foundation where everything else is built. The way it exposes its API is through System calls, these are interrupts in the CPU which trigger functionality inside the Kernel. Lets not get ahead of ourselves now with this and focus on just booting the simplets Kernel there is:

.. code-block:: c

	void main() {
		// We got booted!
		
		// Print '!' on the screen, we can access the video memory directly for this.
		*(0xb8000) = '!';
		
		// Hang here with an infinite loop.
		while (1);
	}

As you might have noted we're using C instead of Assembler, just imagine coding an Operating System entirely in Assembler. I mean you don't have to imagine, just take a look at [MenuetOS](https://www.menuetos.net/). Although we could take the hard path and keep using Assembler to build our Kernel, we opt to use a more human-readable higher language like C. This also brings the benefit of comparing our code with what Linux does.

We compile this to machine code and attach it right next to our bootloader, so when it loads the contiguous sectors from disk it loads this Kernel to memory. But now, where _exactly_ should the bootloader jump to? As in which address should we use in the `JMP` instruction? One could be tempted to say "well the Kernel will be loaded to memory right after the bootloader, so just jump to the next address after the bootloader". Although this might work for now we're never sure `main` will be the first bit of code in the compiled binary. The C compiler will make decisions on where to place code more efficiently, and we're not aware of those decisions when we compile the code. Because of this we need some way to tell the bootloader that we want to target the address of function `main`, whatever that is. This is solved by the magic of "linking".

-------------------
Compiler and linker
-------------------

This is explained in greater detail [here](https://www.cprogramming.com/compilingandlinking.html). The C programming language has a "compiler" and a "linker", the compiler converts source files (`*.c`) to object files (`*.o`) and the linked joins multiple object files into one executable file with machine code.

The compiler's job is to convert the text in the source file to machine code, i.e. functions must have its stack pointer defined (but not the size, the linker will do this afterwards) and proper `RET` with the correct register holding the return value, `if` branches should use `CPM` plus a conditional jump right after, loops should be translated to a subroutine where we jump back to the beggining unless a certain contidion is met, etc. The functions declared on other files are included with the `#include` directive, which includes the header files (`*.h`) which declares the function prototypes. If the source file makes a call to a function declared within the same source file then the compiler can easily figure out where should `CALL` point to, since it'll place the function subroutine at a given position in memory. But if the source file makes a call to a function defined in some other file then we don't know where will that function be in memory, so we don't know what address should be placed on `CALL`. This is the problem the linker solves.

Object files created by the compiler are not directly executable (unless we're compiling a freestanding single file with no include headers, but that's just a very niche edge case), it holds information about the function names and where are the functions called. The object file knows the code must be somewhere, so it places a placeholder saying "I need to call `functionX`, but `functionX` is not defined in this file". The linker receives a list of object files and checks which object calls external functions, then replaces the placeholder address with the real address value of the function. This effecitvely "links" objects to each other, and the result is a combinarion of all object files with proper addresses placed where they need to.

------------
Kernel entry
------------

So why do we care about compiler and linker? Because we can now have a separate assembler code statically at the beggining of our Kernel image with the solve purpose of finding `main` and jumping to it. It'll declare that the address of `main` will be defined by the linker when linking this file with the Kernel object file.

.. code-block::

	[bits 32]
	[extern main]   ; This tells the linker that this address should be resolved to a symbol called `main`.

	call main       ; We jump to `main` and wait until it returns, which should be never.

This file is canonically called "kernel entry`. It's in assembler because we want to tell the CPU exactly what are the steps to take in order to execute the `main` function in the Kernel. Now we can link both object files like so:

.. code-block:: bash

	$ ld -o kernel.img -Ttext 0x1000 kernel_entry.o kernel.o --oformat binary

The linker will keep the same order of the object files in the output, so in this case `kernel_entry.o` will be right in front of `kernel.o`. `--Ttext` behaves like `ORG` in assembler, it shifts all the addresses in the output binary to the given value, in this case we shift addresses to `0x1000`, so the bootloader knows exactly where to jump to land on the Kernel entry code.

-----------------------
From power-on to Kernel
-----------------------

The steps we take are:

1. Power on.
2. BIOS (UEFI) runs POST.
3. BIOS looks for a bootloader and jumps to it.
4. Bootloader loads the Kernel and switches to 32 bit protected mode.
5. Bootloader jumps to Kernel entry.
6. Kernel entry jumps to Kernel `main` function.
7. Kernel `main` function is executed.

At this point we can now switch our development to C (although we reserve the right to use assembler when necessary).

First functions
===============

So now we have a simple Bootloader that loads our Kernel to memory, and the Kernel just prints a "!" character by writing directly to video memory. We now need to go further, but we can't make it further if we can't even print strings, get user input, scroll the screen if we reach the end, clear the screen, etc. These basic functions will be the basic IO for the Kernel.

----------------
Clear the screen
----------------

Our first function should be to clear the screen, so we get rid of all the messaging from the BIOS and bootloader out of the way. To do this we need to get the start of the VGA address for Text mode (`0xB8000`) and mark each Word (16 bits) with the 0x00 character and 0x00 attribute. We can do that in a simple function:

.. code-block:: c

	void clear() {
		char *video_mem_p = (char*) 0xb8000
		for (int i=0; i<2000; i++) {
			*video_mem_p++ = 0;
			*video_mem_p++ = 0;
		}
	}

---------------
Where `printf`?
---------------

Our Kernel can print characters straight to video memory, but it's difficult to do so. We need to modify address `0xb8000` with the char we want, then move two bytes up (because `0xB8001` is used for the attribute of that byte) and add the second char at `0xB8002`. This is explained in more details at the `Hello Kernel!` section. It's better to declare a function in C in our kernel that we can use to print strings.

How does Linux solves this? It has a function called [printk](https://www.kernel.org/doc/html/next/core-api/printk-basics.html#message-logging-with-printk) which basically does that, it prints a string to console. It has more features with it, like log levels, a semaphore to make it thread-safe and string formatting syntax. We'll provide none of it (at least for now) since we're just playing and we want to get strings printed out easily.

The function should take the string we want to print as parameter, but also should take the address in memory we want to print this character. The caller of this function should not have to worry about where in memory it needs to write the byte, this function should take that into account and only accept a string. Given we're in VGA text mode we know the screen size is 80x25 characters long, so we can implement some logic to save the state of a "cursor" and print a new line everytime its called.

.. code-block:: c

	#define TXT_VIDEO_MEM 0xb8000

	char cursor_x = 0;
	char cursor_y = 0;

	// Print a message to the screen, while saving the position of a cursor.
	void printk(char *message) {
		char *video_mem_p = (char *) TXT_VIDEO_MEM;

		// We need to move the video memory up to the point where we should write our next line.
		// 80 x 2 = 160, the amount of bytes we need to move for each line.
		video_mem_p += 160*cursor_y;

		// Loop over the message until we find the NULL character.
		while (*message != 0) {
			// Write the character.
			*video_mem_p++ = *message++;
			// White character on a black background.
			*video_mem_p++ = 0x0F;

			// We printed one character, so add 1 to X.
			cursor_x++;
			// If we reached the end of the line, do a new line.
			if (cursor_x >= 80) {
				cursor_x = 0;
				cursor_y++;
				// If we reached the end of the screen, go to the top.
				// TODO: Implement scrolling.
				if (cursor_y >= 25) cursor_y = 0;
			}
		}
		// Update cursors.
		cursor_x = 0;
		cursor_y++;
		if (cursor_y >= 25) cursor_y = 0;
	}

We should also have a way to print numbers (decimal and hexadecimal) to the screen:

.. todo:: Show how to print numbers.

--------------
Serial console
--------------

While printing stuff to the screen is great, we only have so much space to print information. After filling the screen with logs we're going to have to clear the screen to keep printing stuff, which makes the old log lines disappear. To avoid this we should have the ability to print to the serial console.

Serial port communication is a legacy way to communicate between devices, this has been deprecated in favour of USB. Still, hardware today supports serial ports, and luckily for us they are way easier to implement than a USB driver. Serial ports have a baud rate, this represents the amout of symbols that can transmit within a second. A symbol can be anything, it can be a byte representation or 8 bits, it could also be 4 bits. Generally serial ports configure their symbol to be 8 bits + 1 stop bit, meaning they'll transmit 8 bits and then 1 bit to indicate the end of the transmitted byte. We're going to choose the highest baud rate available to us, 115200 symbols per second. This is fine for new shiny hardware, but old or slow hardware might not be able to talk to us at this speed. It's generally agreed that a speed of 9600 symbols per second should be fine for everyone to handle, so if we ever need to deploy this OS on slow hardware then it would be safer to use this speed instead.

Serial ports also have parity checks, this forces the receiver to add up all the 1s and check if the sum is ODD or EVEN (it can be either way, it's configurable). The receiver gets an extra bit that converts the sum to the correct parity, if at least 1 bit suffered from an error transmission then the receiver can take notice of this. This will not save the receiver from more than 1 bit changes. This party check was made during a time were hardware was generally unreliable, and one was not 100% sure bits will arrive intact at their destination. These days we have way more reliable hardware and we don't require parity checks anymore.

The protocol we're going to use here is the same as the one adopted worldwide: 8 bits, 1 stop bit, no parity checks, or 8N1 for short.

[Here](https://wiki.osdev.org/Serial_Ports) are the details of how to setup the serial port, but in a very crude summary:

* There are multiple serial ports available (COM1 through COM8), although COM1 and COM2 are unofficially standardized.
* COM1 (IO port `0x3F8`) defines registers depending on the offset of the IO port address.
	* Reads on `0x3F8` will return a byte transmitted to us, and writing to `0x3F8` will send a byte through the port.
	* `0x3F8` + 1 is the Interrupt Enable Register.
	* `0x3F8` + 2 is the FIFO control register.
	* And so on...

We first need to initialize the serial port and test it's working properly. To do this we set multiple registers on a precise order, by writing bytes out through the port. We also set the serial port in "loopback" mode to test if we receive a byte we transmit ourselves.

.. code-block:: c

	// Initializes COM1 port: https://wiki.osdev.org/Serial_Ports
	// We'll do 8N1, 115200 baud.
	uint8_t init_com1() {
		// Disable all interrupts while we initialize COM1.
		outb(COM1 + 1, 0x00);

		// Setting the baud rate to 115200, this means having a divisor of 1.
		// To do this we need to do the following:
		// Set the most significant bit of the Line Control Register. This is the DLAB bit, and allows access to the divisor registers.
		// Send the least significant byte of the divisor value to [PORT + 0].
		// Send the most significant byte of the divisor value to [PORT + 1].
		// Clear the most significant bit of the Line Control Register.

		outb(COM1 + 3, 0x80);		// Set bit 7, this is DLAB bit.
		outb(COM1, 0x01);			// Set the LSB of the divisor value. We just want 1.
		outb(COM1 + 1, 0x00);		// Set the MSB of the divisor value, this should be 0.
		outb(COM1 + 3, 0x00);		// Clear bit 7 to set the divisor.		

		// Set the parity, stop and data bits.
		// We're going to choose 8N1, the default everywhere:
		// * 8 bits of data.
		// * No parity.
		// * 1 stop bit.
		outb(COM1 + 3, 0x03);			// 8N1, no break bit, no DLAB.

		// FIFO register:
		// * Enable FIFO.
		// * Clear FIFO input/output buffers.
		// * Set interrupt at 8 bits, this means we're going to get interrupted when there's at least 1 byte at the receiving buffer.
		outb(COM1 + 2, 0xC7);

		// Modem Control Register.
		// Initialize the IRQ.
		outb(COM1 + 4, 0x0B);

		// Now enable loopback mode, to test the serial TX/RX lines are working.
		outb(COM1 + 4, 0x1E);

		outb(COM1, 0x55);               // Send 0x55 (alternating 1s and 0s).

		// Read the byte, it should be the same byte we sent.
		if (inb(COM1) != 0x55) {
			return 1;
		}
		
		// If we're here then we passed the test, disable loopback in COM1
		outb(COM1 + 4, 0x0F);

		return 0;
	}

Now we define two handy assembler-based functions to read a byte from the port and write a byte to the port.

.. code-block:: c

	// Handy function to output a byte through a port.
	static inline void outb(uint16_t port, uint8_t val)
	{
		__asm__ volatile ( "outb %b0, %w1" : : "a"(val), "Nd"(port) : "memory");
	}

	// Handy function to get a byte input from a port.
	static inline uint8_t inb(uint16_t port)
	{
		uint8_t ret;
		__asm__ volatile ( "inb %w1, %b0"
					: "=a"(ret)
					: "Nd"(port)
					: "memory");
		return ret;
	}

And we tie it all up with a `write_serial` function to print a line to the console (that is, ending with carriage return and new line).

.. code-block:: c

	void write_serial(char *message, uint16_t length) {
		for (int i = 0; i < length; i++) {
			// Wait until the tx buffer is empty.
			while (tx_buffer_empty() == 0);

			// Send the char out through the console.
			outb(COM1, message[i]);
		}

		// Print a new line.
		while (tx_buffer_empty() == 0);
		outb(COM1, 0x0d);
		while (tx_buffer_empty() == 0);
		outb(COM1, 0x0a);
	}

It would be nice if we can add some sort of timestamp to the console line, so we know at which time a given message was written to the serial port. But how do we get the time?

******************
Time in the Kernel
******************

