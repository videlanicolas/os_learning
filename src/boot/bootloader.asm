;==================================;
; Bootloader for x86 architecture. ;
;==================================;

[bits 16]

[org 0x7c00]			; BIOS loads us at this address, so shift all addresses by this amount.

KERNEL_OFFSET equ 0x1000	; Offset to load the Kernel.

	; Prepare the stack.
	mov bp, 0x9000		; Set the base of our stack to a far away value.
	mov sp, bp		; Match the start and base of our stack.

	cli			; Disable all hardware interrupts while we boot, the Kernel should re-enable them.

	; Print a nice message for the user telling the OS is booting up.
	mov si, START_BOOT_MSG
	call println

	mov bx, KERNEL_OFFSET	; BX marks the destination for our read sectors.
	mov dh, 15		; Read 15 sectors.
	call disk_load		; Call our routine to load sectors to memory.
	cmp ah, 0		; AH will indicate if there was an error.
	jne .boot_fail

	; Make sure A20 is enabled.
	mov ax, 2401h
	int 15h
	jb .boot_fail		; If CF is set then this operation failed.
	cmp ah, 0		; If AH is different than 0 then the BIOS failed to enable A20.
	jne .boot_fail

	; Load the GDT.
	lgdt [gdt_desc]

	; Set protection mode.
	mov eax, cr0
	or eax, 1		; We need to set bit 0 (Protection Enable, the thing that switches to protected mode).
	mov cr0, eax

	jmp 08h:protected_mode_start
	
.boot_fail:
	mov bx, FAIL_BOOT_MSG
	call println

	; If we reached this point we failed to boot. This is here to prevent executing the bytes below
        ; as part of the main routine.
	jmp $

%include "./src/boot/disk_load.asm"
%include "./src/boot/println.asm"
%include "./src/boot/gdt.asm"

[bits 32]

protected_mode_start:
	mov ax, 10h		; NULL is at 0x00, CS is at 0x08, 8 bytes more and we get the data segment at 0x10.
	mov ds, ax		; Mark the Data segment at 10h.
	mov ss, ax		; Mark the Stack segment also at 10h.
	mov es, ax		; Extra segment equal to data segment.
	mov esp, 090000h	; ESP is the stack pointer in 32 bit world. Set it to a far away value (+1 MiB). 

	mov ebx, [KERN_BOOT_MSG]; Tell the user that we're booting the Kernel.
	call println_pm

	; Call our Kernel entry point.
	call KERNEL_OFFSET

	jmp $			; Hang here and don't execute the bytes below.

%include "./src/boot/println_pm.asm"

; Data
START_BOOT_MSG: db "Booting OS", 0
FAIL_BOOT_MSG: db "Bootloader error", 0
KERN_BOOT_MSG: db "Booting kernel", 0

; Spacing and signature
times 510 - ($ - $$) db 0	; This line basically adds 0x00 bytes to fill up until 510 bytes.
dw 0xaa55			; Magic number for BIOS to detect that this sector is a bootloader.
