# Development log

This document holds all the progress and research I make while coding this OS.

## Getting started

Right after pressing the power button the Processor Control Register clears the protection bit (CR0 bit 0 for x86), forcing the CPU into 16 bit Real Mode. The next thing that happens is that the CPU will fetch the first instruction for the Reset Vector address, which for x86 is 0xfffffff0. Now you might notice that this is a 32 bit address, which would not be addressable in Real Mode 16 bit. I'm going to quote the [Intel's Software Developer's](https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.pdf) manual here (section 9.1.4):

```
The address FFFFFFF0H is beyond the 1-MByte addressable range of the processor while in real-address mode. The
processor is initialized to this starting address as follows. The CS register has two parts: the visible segment
selector part and the hidden base address part. In real-address mode, the base address is normally formed by
shifting the 16-bit segment selector value 4 bits to the left to produce a 20-bit base address. However, during a
hardware reset, the segment selector in the CS register is loaded with F000H and the base address is loaded with
FFFF0000H. The starting address is thus formed by adding the base address to the value in the EIP register (that
is, FFFF0000 + FFF0H = FFFFFFF0H).
```

### POST

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

### EFI and UEFI

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

### Bootloaders

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

* You can load Code (memory that can be executed as instructions) or Data (memory that is _read only_ and can't be executed) segments.
* You can set "privilege levels" (0 for highest and 3 for lowest).
* Set the portion in memory that each segment occupies.

Once all of these is done we can switch to Protected Mode by simply setting the 0 bit in `CR0`. We also need to clear the pipeline by performing a "far" jump, I explain this in [another repo](https://github.com/videlanicolas/playing-with-bootloaders/blob/main/src/switch_to_pm/bootloader.asm) if you're curious.

Now in Protected mode we need to find the Kernel's main entry point and jump to it, essentially passing over execution to the Kernel. 

## Hello Kernel!

TODO: Explain how we made it to print something to the screen after the Bootloader.

## First functions.

So now we have a simple Bootloader that loads our Kernel to memory, and the Kernel just prints a "!" character by writing directly to video memory. We now need to go further, but we can't make it further if we can't even print strings, get user input, scroll the screen if we reach the end, clear the screen, etc. These basic functions will be the basic IO for the Kernel.

### Clear the screen

Our first function should be to clear the screen, so we get rid of all the messaging from the BIOS and bootloader out of the way. To do this we need to get the start of the VGA address for Text mode (`0xB8000`) and mark each Word (16 bits) with the 0x00 character and 0x00 attribute. We can do that in a simple function:

```c
void clear() {
	char *video_mem_p = (char*) 0xb8000
	for (int i=0; i<2000; i++) {
		*video_mem_p++ = 0;
		*video_mem_p++ = 0;
	}
}

```

### Where `printf`?

Our Kernel can print characters straight to video memory, but it's difficult to do so. We need to modify address `0xb8000` with the char we want, then move two bytes up (because `0xB8001` is used for the attribute of that byte) and add the second char at `0xB8002`. This is explained in more details at the `Hello Kernel!` section. It's better to declare a function in C in our kernel that we can use to print strings.

How does Linux solves this? It has a function called [printk](https://www.kernel.org/doc/html/next/core-api/printk-basics.html#message-logging-with-printk) which basically does that, it prints a string to console. It has more features with it, like log levels, a semaphore to make it thread-safe and string formatting syntax. We'll provide none of it (at least for now) since we're just playing and we want to get strings printed out easily.

The function should take the string we want to print as parameter, but also should take the address in memory we want to print this character. The caller of this function should not have to worry about where in memory it needs to write the byte, this function should take that into account and only accept a string. Given we're in VGA text mode we know the screen size is 80x25 characters long, so we can implement some logic to save the state of a "cursor" and print a new line everytime its called.

```c
void kprint(char *message) {
	// Get the video memory address we want. This should be 0xb8000 plus the cursor lines we added before.

	// Loop over message, byte by byte, and copy it to video memory.
	loop until *message == 0 {
		*video_mem_p++ = *message++;
		// White character on black background.
		*video_mem_p++ = 0x0f;
		// Update X and Y accordingly.
	}
	// Add a cursor line, mimicking a new line.
}
``` 
