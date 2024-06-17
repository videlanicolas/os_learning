;========================================================================================================================
; Our bootloader will blindly execute the first instruction in our Kernel. The C compiler might arrange our code so that
; our 'main' function is not the very first instruction that is called, so we need to make sure we're actually executing
; 'main' and not any other function in our Kernel. To do this, we create this assembler file (so we know exactly what instructions
; are being executed) with the sole purpose of finding 'main' on our Kernel image and executing it.
;========================================================================================================================

[bits 32]
[extern main]	; This tells the linker that there is a symbol 'main' somewhere outside this file, and when it links it it should replace
		; this label with the correct address that the function 'main' was called.
global _start

_start:
	call main	; Jump to our Kernel code.

	jmp $		; If we return then just hang here (this should never happen in a real OS).
