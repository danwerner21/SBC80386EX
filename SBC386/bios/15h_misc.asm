;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 15h_misc.asm -- handle many miscellaneous BIOS calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2018 John R. Coffman.  All rights reserved.
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
; SBC-386 board revisions:
;       SBC386-0   prototype / concept testing
;	SBC-386EX 2.0	production / January 2018
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "bda.inc"
%include "macro.inc"

	global	int_15h

segment	_TEXT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h was originally the Cassette I/O interface, but many, many
; additional functions were added, making this one of the most general
; BIOS function call.
;
;    Function		Usage
;    ========		=====
;	00	turn on cassette motor	[PC]
;	01	turn off cassette motor	[PC]
;	02	read cassette		[PC]
;	03	write cassette		[PC]
;
;	0Fh	format ESDI drive periodic interrupt [PS/2]
;	21h/00	read POST error log	[PS/2]
;	21h/01	write POST error log	[PS/2]
;
;	4Fh	keyboard intercept	[PS/2]
;
;	80h	device open		[AT][PS/2]
;	81h	device close		[AT][PS/2]
;	82h	process termination	[AT][PS/2]
;	83h	event wait		[AT][PS/2]
;	84h	read joystick		[AT][PS/2]
;	85h	SysReq key		[AT][PS/2]
;	86h	delay			[AT][PS/2]
;	87h	move Extended memory block [AT][PS/2]
;	88h	get Extended memory size [AT][PS/2]
;	89h	enter protected mode 	[AT][PS/2]
;
;	90h	device wait 		[AT][PS/2]
;	91h	device post 		[AT][PS/2]
;
;	0C0h	get system environment	[AT][PS/2]
;	0C1h	get address of Extended BIOS Data Area (EBDA) [PS/2]
;
;	0C2h/00	enable/disable pointing device [PS/2]
;	0C2h/01	reset pointing device 	[PS/2]
;	0C2h/02	set sample rate 	[PS/2]
;	0C2h/03	set resolution 		[PS/2]
;	0C2h/04	get pointing device type [PS/2]
;	0C2h/05	initialize pointing device interface [PS/2]
;	0C2h/06	set scaling OR get status [PS/2]
;	0C2h/07	set pointing device handler address [PS/2]
;
;	0C3h	set watchdog timeout	[PS/2]
;	0C4h	programmable option select [PS/2]
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int_15h:			; INT 0x15 enters here
; interrupts are disabled at this point
	cmp	ah,0x4F		;check for Keyboard Intercept
	jne	.1
; the keyboard code will set the Carry to make a simple IRET
; the simplest dummy code
	iret		; NULL return



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; other calls will be decoded with interrupts enabled
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.1:	sti
	cmp	ah,04h		; cassette calls are all below 4
	jae	.2
; it is a cassette call
.86:	mov	ah,0x86		; function not supported
	stc
	retf	2		;return with Carry set & error code


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; decode the 0x8? series
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.2:	sub	ah,0x80		;
	jz	device_open	; function 0x80
	cmp	ah,0x0A
	jae	.3
; 0x87 series
	dec	ah
	jz	device_close	; function 0x81
	dec	ah
	jz	process_term	; function 0x82
	dec	ah
	jz	event_wait	; function 0x83
	dec	ah
	jz	read_joystick	; function 0x84
read_joystick	equ	.86
	dec	ah
	jz	sys_req_key	; function 0x85
sys_req_key	equ	.86
	dec	ah
	jz	delay		; function 0x86
	dec	ah
	jz	mov_ext_mem	; function 0x87
	dec	ah
	jz	get_ext_mem_siz	; function 0x88
	jmp	enter_protected	; function 0x89



.3:	cmp	ah,0x10		;
	jz	device_wait	; function 0x90
	cmp	ah,0x11
	jz	device_post

; check the 0xC0++ series

	sub	ah,0x40		; 0xC0 subtracted now
	jz	get_sys_env
	cmp	ah,5		; all calls below 5
	jae	.86		; function not supported

; the 0xC0 series
	dec	ah
	jz	get_EBDA	; function 0xC1
	dec	ah
	jz	point_dev
point_dev	equ	.86	; function 0xC2
	dec	ah
	jz	watchdog	; function 0xC3
watchdog	equ	.86
	jmp	prog_opt	; function 0xC4
prog_opt	equ	.86





device_open:		; function 0x80
device_close:		; function 0x81
process_term:		; function 0x82
event_wait:		; function 0x83
;delay:			; function 0x86
mov_ext_mem:		; function 0x87
get_ext_mem_siz:	; function 0x88
enter_protected:	; function 0x89

device_wait:		; function 0x90
device_post:		; function 0x91
get_sys_env:		; function 0xC0
get_EBDA:		; function 0xC1
	jmp	int_15h.86	;for now




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h
; Function 86	Delay
;
;    Enter with:
;	AH	86h originally, now 0x00 due to decode
;	CX:DX	delay time in microseconds
;
;    Exit with:
;	Carry 	clear, if wait was performed
;		set. if wait was not performed
;
;    Notes:
;	The PC/AT BIOS uses the 1024hz CMOS interrupt to provide wait
;	time resolution to within 976usec.  The routine here uses
;	the 1mhz timer 1 counter to provide finer resolution for short
;	waits.  Longer waits use the 18.2hz clock, with a resolution
;	of 54.9ms.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  interrupts are enabled by the time we get to here
;
delay:
	cmp	cx,4		;about 250,000 usec
	jb	int_15h.86	;for now
; the very short delays are not handled at the moment !!!!!!

; Low resolution delays below:
;
; calculate the tick count (approximate)

	pushm	ax,bx,cx,dx,ds

; microsecond count is in CX:DX
;
; if clock ticks have been converted to 65536/hr, then
;  usec * 64 / 1875 / 1875 gives the clock tick count (18.2hz)

	mov	ax,cx		; AX:DX
	mov	bx,dx		; AX:BX
	xor	dx,dx		; 0:AX:BX
	mov	cx,6		; set for * 64 (by shifting)
.1:	shl	bx,1
	rcl	ax,1
	rcl	dx,1
	loop	.1		; DX:AX:BX is 6-byte usec * 64

	mov	cx,1875
; do the first long division
	div	cx		; (DX=rem, AX=quo)
	xchg	ax,bx
	div	cx		; BX:AX is first quotient

	xor	dx,dx
	xchg	ax,bx		; DX:AX:BX
	div	cx
	xchg	ax,bx
	div	cx		; BX:AX is final tick count
%if 0
	pushm	ax,bx
	mov	dx,bx
	extern	dout
	call	dout
	popm	ax,bx
%endif
	get_bda	DS

loc	equ	printer_timeout+3	;PRT4

do_delay:
; only very short delays are handled at this time !!!!!!
	or	bh,bl
	or	bh,ah
	jz	.1
	mov	al,255
.1:
	mov	byte [loc],al

.2:
	hlt			; HALT here doubles the delay unless
				;  HSREADY is set in PWRCON
	cmp	byte [loc],0
	jne	.2

.9:
	popm	ax,bx,cx,dx,ds
	clc
	retf	2
