; Print a string of chars from the address at SI until 0x00 is found, then print a new line.
[bits 16]

println:
	pusha		; Save all general purpose registers to the stack.
	mov ah, 0x0e        ; BIOS teletype routine.
	mov bh, 0x00	; Display page number.

.loop:
	lodsb		; Load the value stored in DS:SI into AL, then increment SI.

	cmp al, 0x00	; Check if we're at the end of the string.
	je .done	; If we're at the end of the string then we're done.

	int 10h		; Call the BIOS to display the character stored in AL.

	jmp .loop	; Go back and get the next character.
.done:
	; Print a new line and carriage return.
	mov al, 0x0d
	int 10h
	mov al, 0x0a
	int 10h

	popa		; Restore all registers from the stack.
	ret		; Jump to where we were called.
