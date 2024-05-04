# Development log

This document holds all the progress and research I make while coding this OS.

## Getting started

TODO: Explain POST, BIOS.

## Bootloaders

TODO: Explain Bootloaders.

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
