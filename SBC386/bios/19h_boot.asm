;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 19h_boot.asm -- INT 19h, the bootstrap loader
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2026 Dan Werner.  All rights reserved.
; Provided for hobbyist use on the RetroBrew SBC-386EX board.
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program in the file COPYING in the topmost source
; directory.  If not, see <http://www.gnu.org/licenses/>.
;
;
; Modelled on BOOT_STRAP_1 in ATBIOS/ATBIOS/test6.asm, keeping the fixed
; disk path (H5..H8 there) and dropping the diskette path, which this
; board has no hardware for.
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386EX.inc"
%include "macro.inc"
; ASCII_CR and ASCII_LF come from i386EX.inc -- "ascii.h" is a C
; header and NASM cannot read it

	global	int_18h
	global	int_19h

segment	_TEXT

BOOT_SEG	equ	0x0000		; the boot sector is loaded and entered
BOOT_OFF	equ	0x7C00		;  at 0000:7C00, by long convention
BOOT_DRIVE	equ	0x80		; first fixed disk
BOOT_RETRIES	equ	4		; as the PC/AT did


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 19h -- Bootstrap Loader
;
; Read cylinder 0, head 0, sector 1 of drive 80h into 0000:7C00, check
; that it ends in AA55h, and enter it.
;
; This call does not return.  It replaces the stack it was entered on,
; because the boot sector is entitled to assume nothing about whatever
; POST was using -- and on this board POST's stack lives up in the SRAM
; at A800:xxxx, which is no use to anything that follows.
;
;  Hands control over with:
;	CS:IP	0000:7C00
;	DL	80h, the drive it was read from
;	DS,ES	0000
;	SS:SP	0000:7C00, growing down away from the sector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_19h:
	cli
	xor	ax,ax
	mov	ss,ax			; the stack the boot sector expects:
	cnop
	mov	sp,BOOT_OFF		;  0000:7C00, growing downward
	mov	ds,ax
	cnop
	mov	es,ax
	cnop
	sti
	cld

; Clear the boot location first.  A read that fails part way through, or
; a drive that returns short, must not be able to leave anything
; executable sitting there from an earlier attempt.
	mov	di,BOOT_OFF
	mov	cx,256			; 256 words == one sector
	rep	stosw			; AX is still zero

	mov	cx,BOOT_RETRIES
.retry:
	push	cx

; Reset first.  On this BIOS that also puts the drives back into 8-bit
; PIO after the soft reset -- see fn00 in 13h_disk.asm.
	mov	ah,0
	mov	dl,BOOT_DRIVE
	int	0x13
	jc	.again

	mov	ax,0x0201		; read, one sector
	mov	cx,0x0001		; cylinder 0, sector 1
	mov	dh,0			; head 0
	mov	dl,BOOT_DRIVE
	xor	bx,bx
	mov	es,bx			; ES:BX = 0000:7C00
	cnop
	mov	bx,BOOT_OFF
	int	0x13
	jnc	.loaded

.again:
	pop	cx
	loop	.retry
	mov	si,msg_noread
	jmp	short .give_up

.loaded:
	pop	cx

; The last two bytes of a bootable sector are AA55h.  Without this test
; a blank or data-only disk would be executed as code.
	cmp	word [BOOT_OFF+510],0xAA55
	je	.enter

	mov	si,msg_nosig

.give_up:
	call	boot_msg
; INT 18h is where the PC/AT went when nothing would boot.  Here it
; prints and drops into the debug monitor, and retries the boot when the
; monitor is left -- so this call does not normally come back.
	int	0x18
.hang:
	hlt
	jmp	.hang

.enter:
	mov	si,msg_booting
	call	boot_msg

	mov	dl,BOOT_DRIVE		; the sector is told where it came from
	xor	ax,ax
	mov	ds,ax
	cnop
	mov	es,ax
	cnop
	jmp	BOOT_SEG:BOOT_OFF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; boot_msg -- write the ASCIIZ string at CS:SI to the serial console
;
; The CS override matters: by the time this runs DS has been set to zero
; for the boot sector, while the strings are still up in the ROM.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
boot_msg:
	pushm	ax,bx,cx,dx,si
.1:
   cs	lodsb
	or	al,al
	jz	.9
	mov	ah,1			; write character
	xor	dx,dx			; COM1
	int	0x14
	jmp	.1
.9:
	popm	ax,bx,cx,dx,si
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 18h -- no bootable device
;
; On a PC/AT this went to ROM BASIC.  There is none here, and halting
; leaves a failed boot silent and costs a power cycle to get back to
; SETUP.  Drop into the debug monitor instead: at this point the machine
; itself is healthy -- it is the disk that would not boot -- so
; everything the monitor needs is already working.
;
; Reached from INT 19h when the boot sector cannot be read or carries no
; signature, and from a boot sector in its own right: the MBR on a
; partitioned card issues INT 18h when it finds no active partition.
;
; Leaving the monitor retries the boot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	extern	debugmon_

int_18h:
	cli
	xor	ax,ax
	mov	ss,ax			; a stack of our own: whatever called
	cnop				;  us may have moved SS:SP somewhere
	mov	sp,BOOT_OFF		;  unhelpful, and a boot sector that
	sti				;  failed is not to be trusted with it
	cld

	mov	si,msg_nodisk
	call	boot_msg

	mov	ax,DGROUP		; the C code addresses through DGROUP
	mov	ds,ax
	cnop
	mov	es,ax
	cnop

	call	debugmon_

; The operator has left the monitor.  Try the disk again -- a card may
; have been changed, or SETUP used, in the meantime.
	mov	si,msg_retry
	call	boot_msg
	int	0x19

; INT 19h does not return.  If its vector were wrong we would arrive
; here rather than running off into memory.
.hang:
	hlt
	jmp	.hang

msg_booting:
	db	ASCII_CR,ASCII_LF,"Booting from drive 80h ...",ASCII_CR,ASCII_LF,0
msg_noread:
	db	ASCII_CR,ASCII_LF,"INT 19h: cannot read the boot sector",ASCII_CR,ASCII_LF,0
msg_nosig:
	db	ASCII_CR,ASCII_LF,"INT 19h: no AA55h signature -- not bootable",ASCII_CR,ASCII_LF,0
msg_nodisk:
	db	ASCII_CR,ASCII_LF
	db	"INT 18h: no bootable device.",ASCII_CR,ASCII_LF
	db	"Dropping into the debug monitor -- EXIT retries the boot."
	db	ASCII_CR,ASCII_LF,0
msg_retry:
	db	ASCII_CR,ASCII_LF,"Retrying the boot ...",ASCII_CR,ASCII_LF,0
