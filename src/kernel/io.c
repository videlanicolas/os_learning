#include <stdint.h>
#include "io.h"

#define COM1			0x3f8

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

uint8_t tx_buffer_empty() {
    // Check the 6th bit in the Line Register, this is set if the tx buffer is empty,
    // meaning we can transmit data through the port.
    return inb(COM1 + 5) & 0x20;
}

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