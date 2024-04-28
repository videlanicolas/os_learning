; Print a string in 32 bit protected mode. 
[bits 32]

; Constants.
VIDEO_MEMORY equ 0xb8000	; This is where video memory starts.
WHITE_ON_BLACK equ 0x0f		; Foreground and background color for each character. https://wiki.osdev.org/Printing_To_Screen

; Print a string pointed by EBX
; We only get 80x25 characters in this mode.
println_pm:
	pusha			; Push all regsters to the stack, so we save their state.
	mov edx, VIDEO_MEMORY	; Make EDX point to the start of the video memory.
	mov ah, WHITE_ON_BLACK	; Always use this color for all printed bytes.

.loop:
	mov al, [ebx]           ; Get the byte to print into AL.
	cmp al, 0x00            ; If this is the null byte, we're done.
	je .done

	; So AL is a byte we must print, so move it to the correct poisiton in video memory
	mov [edx], ax           ; Move the byte and attributes to the current position in video memory.
	; Move over to the next position in video memory. Each char has 1 byte for the ASCII char and 
	; 1 byte for the attribute (i.e. color). So:
	;
	; 0xb800:0000 -> ASCII char
	; 0xb800:0001 -> Attribute
	add edx, 2
	inc ebx			; Move to the next byte to print.

	jmp .loop		; Loop back and repeat with the next byte.

.done:
	popa			; Restore all registers
	ret			; Jump back to where we were called.
