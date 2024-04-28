; Global Descriptor Table definition.
; We only want two segments: code and data.

; https://wiki.osdev.org/GDT has a good description of all fields.
gdt_start:
	; NULL segment.
	dq 0				; Assembler has 'dq' (define quad word) which defines 8 bytes.
	
	; Code segment.
	dw 0xffff			; Limit of the segment, take all the available space.
	dw 0				; Base address is the linear address where this segment begins, 0 for the beginning.
	db 0				; Part of the base address above.
	
	; Access byte, this marks the semgment as code segment, as well as other things.
	db 10011010b

	; Flags and remaining bits of segment limit.
	db 11001111b

	db 0				; Remaining byte of base address.

	; Data segment.
	dw 0xffff			; Limit of the segment, take all the available space.
	dw 0				; Base address.
	db 0				; More base address.

	; Access byte, similar to the code segment except we mark it as read-only.
	db 10010010b

	; Same as Code segment.
	db 11001111b

	db 0				; Remaining byte of base address.
gdt_end:

gdt_desc:
	dw gdt_end - gdt_start - 1	; Size of GDT, minus 1 because the maximum value is 65535 and the GDT can be up to 65536.
	dd gdt_start			; Address of the start of GDT.
