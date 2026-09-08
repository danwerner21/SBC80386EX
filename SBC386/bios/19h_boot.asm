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
; INT 18h is where the PC/AT went when nothing would boot.  It is still
; a stub here, so if it returns there is nothing further to try.
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


msg_booting:
	db	ASCII_CR,ASCII_LF,"Booting from drive 80h ...",ASCII_CR,ASCII_LF,0
msg_noread:
	db	ASCII_CR,ASCII_LF,"INT 19h: cannot read the boot sector",ASCII_CR,ASCII_LF,0
msg_nosig:
	db	ASCII_CR,ASCII_LF,"INT 19h: no AA55h signature -- not bootable",ASCII_CR,ASCII_LF,0
