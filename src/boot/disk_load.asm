; Routine to load sectors of memory to disk.
; AL: Amount of sectors to read.
; BX: Address to store the sectors.
; DL: Boot drive.
; Returns AL equal to the amount of sectors read.
[bits 16]

disk_load:
	pusha		; Store the value of all registers.

	mov ah, 02h	; Read sector service.
	mov cx, 0002h	; Cylinder 0 (CH) and start reading from sector 2 (CL) (sector 1 is the bootloader).
	mov dh, 0	; Head 0.
	int 13h		; Call BIOS disk operations routine.

	; That's it, BIOS will put the error code in AH.
	popa
	ret
