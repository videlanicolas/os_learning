// Kernel main code.

#include "io.h"

#define TXT_VIDEO_MEM 	0xb8000

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

void printhex(char *hex) {

}

void printVGA(uint8_t x, uint8_t y, char *msg) {
	char *c = (char*) (TXT_VIDEO_MEM + (x * 2) + 80 * 2 * y);
	while(*msg != 0) {
		*c = *msg;
		c += 2;
		msg++;
	}
}

// Clear the screen, essentially deletes all video memory in VGA text mode.
void clear() {
	// VGA text mode is 80x25 characters, that's 2k characters, or 4k Words if we add the attributes.
	char *video_mem_p = (char*) TXT_VIDEO_MEM;
	for (int i=0; i<2000; i++) {
		// Write the ASCII 0 byte, the NULL char.
		*video_mem_p++ = 0;
		// Attribute 0, black colour.
		*video_mem_p++ = 0;
	}
}

// Halt the OS, clear the screen and print an error message.
void panic(char *msg){
	char *video_mem_p = (char *) TXT_VIDEO_MEM;	
	for (int i=0; i<2000; i++) {
		// Write the ASCII 0 byte, the NULL char.
		*video_mem_p++ = 0;
		// Light red on 
		*video_mem_p++ = 0x1f;
	}

	printVGA(40, 12, msg);
}

void main() {
	// Clear the screen of all the BIOS and bootloader output.
	clear();

	// Initialize the serial console.
	if (init_com1()) {
		// Failed to initialize COM1.
		panic("COM1 error.");
	}

	write_serial("Kernel booted!");
}
