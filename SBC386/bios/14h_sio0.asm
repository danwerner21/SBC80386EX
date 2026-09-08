;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 14h_sio0.asm -- Int 14 serial I/O on SIO0
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
;
;  N.B.:  "serial.inc" is NOT automatically generated from "serial.h"
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "bda.inc"
%include "macro.inc"
%include "stack.inc"
%include "serial.inc"

%define USE_CTS 0

	global	int_14h
segment _TEXT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int_14h	-- called with INT 0x14 with function code in AH
;
;    Enter with:
;	AH	function code 0, 1, 2, 3
;	DX	port number 0=COM1, .. 3=COM4
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int_14h:
	sti			; re-enable interrupts
	pushm	ALL,DS ;ES	; AX is usually a return value
	mov	bp,sp		; establish stack addressing
	get_bda	DS		;get DS = segment pointer to BDA
%if 0
	mov	cx,[equip_flag]	; equipment flag in BDA
	shr	cx,9		;number of RS-232 ports
	and	cx,7		; **
	mov	bx,dx		; COM1==0, COM2==1, ...
	cmp	bx,cx		; 4 COM ports at most
	jae	bad_error
%else
	cmp	dx,4		; 4 is the max
	jae	bad_error
	mov	bx,dx		;index to BX
%endif

; the index in BX is below the number in CX
	add	bx,bx
	mov	bx,[serial_dev + bx]
	or	bx,bx
	jz	bad_error
	lea	dx,[LSR0-TBR0 + bx]	; LSR address to DX
;
; we have the I/O base device code in BX
;
	or	ah,ah
	jz	init_sio	; function 0
	dec	ah
	jz	write		; function 1
	dec	ah
	jz	read		; function 2
	dec	ah
	jz	status		; function 3
	dec	ah
	jz	ext_init_sio	; function 4  PS/2

;
; the other PS/2 functions are not implemented
;
bad_error:
	mov	ax,0x8E0F	; AH.7 = timeout
return_AX:
	mov	[bp+offset_ax],ax
	popm	ALL,DS ;ES	; restore the registers
	iret



SHIFT	equ	2		; set to 2 for 7.3728 mhz on 4UART
OSC	equ	1843200<<SHIFT
CLK	equ	OSC/16

	global	_sio_divisors
_sio_divisors:
sio_divisors:
	dw	CLK/110		;0
	dw	CLK/150
	dw	CLK/300
	dw	CLK/600
	dw	CLK/1200	;5
	dw	CLK/2400
	dw	CLK/4800
	dw	CLK/9600	;7
; for the extended initialization call (PS/2)
	dw	CLK/19200	;8
	dw	CLK/38400
	dw	CLK/56000	; actually 57600
	dw	CLK/115200	;11
%if SHIFT
	dw	CLK/230400	;12
	dw	CLK/460800	;13
%endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get_status
;
;    Enter with:
;	BX	port base I/O address
;	DX	LSR I/O address
;
;    Exit with:
;	AH	line status
;	AL	modem status
;
;	BX	port I/O base address
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
get_status:
	in	al,dx		; get line status
	and	al,7Fh		; clear undefined bit
	mov	ah,al		; will return in AH
	inc	dx		; MSR0 in DX
	in	al,dx		; line status to AL
	dec	dx
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; read
;
;    Enter with:
;	BX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	character read
;	BX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read:
	call	get_status
	test	ah,LSR_RBF	;anything in the buffer
	jz	read

	xchg	bx,dx		;RBR to DX
	in	al,dx		;get the character
	xchg	bx,dx		;LSR to DX
	mov	cl,al		; save char read in
	call	get_status
	and	ah,BIT4+BIT3+BIT2+BIT1	; mask pertinent bits
	jz	.3
	or	ah,BIT7		;signal error
.3:
	mov	al,cl		;return char in AL, LSR in AH
	jmp	return_AX


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; write
;
;    Enter with:
;	AL	character to write
;	BX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	unchanged char
;	BX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

write:
	mov	cl,al		;save output character
.1:
	call	get_status	;line status to AH
%if USE_CTS
	; modem status is in AL
	test	al,MSR_CTS		; test CTS_bit
	jz	.1
%endif
	test	ah,LSR_TBE	;buffer empty?
	jz	.1
	xchg	bx,dx		;DX = base (TBR)
	mov	al,cl		; AL = character
	out	dx,al		; put it out
	xchg	bx,dx		;DX = LSR again
	call	get_status
	mov	al,cl		;restore char in AL
	jmp	return_AX




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; init_sio
;
;    Enter with:
;	AL	initialization parameters
;			bits 7 6 5	data rate
;			bits 4 3	parity x0=none, 01=odd, 11=even
;			bit  2		stop bits 0->1, 1->2 stop bits
;			bits 1 0	word length 10->7 11->8 bits
;	BX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	modem status
;	BX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_sio:
; Leave the console line settings alone.
;
; DOS initialises its AUX device during SYSINIT, and on this board AUX
; is COM1 -- which is the console.  Honouring that call reprograms the
; divisor latch out from under the terminal, and every byte after it
; arrives at the wrong rate.  The console speed belongs to SETUP, not to
; an application, so the request is acknowledged with a normal status
; and the hardware is not touched.
;
; DX no longer holds the port number here -- it was replaced with the
; LSR address above -- so the console is recognised by its device code.
;
; Function 4, the extended init, is deliberately NOT guarded: that is
; the one install_serial_console() uses at POST to set the console up in
; the first place.
	cmp	bx,[serial_dev]
	je	status		; the console: report status, change nothing

	mov	si,ax		; index to SI
	and	si,0x00E0	; mask to 3 bits
	shr	si,4		; form WORD index
	and	ax,00011111b	;mask for status bits
	mov	cl,SHIFT	;
; AL is LCR to-be
; SI is baud rate index
; CL is baud rate shift for 1.84mhz clock (2), 7.37mhz clk (0)
do_init:
	mov	ah,al		; save LCR value in AH
	dec	dx
	or	al,80h		; set DLAB
	dec	dx		; DX = LCR address
	out	dx,al		; set DLAB & LCR
	push	DX
	mov	dx,bx		; DX is DLL address
   cs	mov	di,[sio_divisors + si]
   	shr	di,cl
	mov	cx,di
	mov	al,cl
   	out	dx,al		; set low byte
	inc	dx   		; address DLH
	mov	al,ch
	out	dx,al		; set high byte
	pop	DX		; get LCR
	mov	al,ah		; set to clear DLAB
	out	dx,al		; clear DLAB, set LCR bits
	inc	dx		; DX = MCR
	mov	al,0x03		; set RTS & DTR
	out	dx,al		; **
	inc	dx		; DX = LSR
; just fall into the Status return
;;	call	get_status
;;	jmp	return_AX


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; status
;
;    Enter with:
;	BX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	modem status
;	BX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

status:
	call	get_status
	jmp	return_AX

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ext_init_sio		PS/2 extended init
;
;    Enter in the stack:
;	AL	break flag 0 or 1
;
;    SBC-386EX extension:
;	AL.765 are protocol bits
;
;	BH	parity
;			0 none
;			1 odd
;			2 even
;			3 stick parity odd
;			4 stick parity even
;	BL	stop bits
;			0 one stop bit
;			1 two stop bits (1.5 if CH==0)
;	CH	word length
;			0  5-bits
;			1  6-bits
;			2  7-bits
;			3  8-bits
;	CL	bit rate
;			0..8  (see table, 110 to 19200
;		386EX extension:
;			9..11 (38400,57600,115200)
;	DX	port number
;
;    Exit with:
;	AH	port (line) status
;	AL	modem status
;	BX,CX,DX	unchanged
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ext_init_sio:
	mov	cx,[bp + offset_cx]
; CL is the baud rate index
	mov	si,cx		; index to SI
	and	si,0x000F
	add	si,si		; SI is WORD index

	mov	ah,al		; save protocol bits in AH

	and	al,1		; mask to 1 bit
	shl	al,6		; break bit to bit 6
	and	ch,3		; mask word length
	or	al,ch		; break|nbits
; BX is the parity & stop bits
	mov	cx,[bp + offset_bx]
	and	cl,1		; mask stop bits
	shl	cl,2
	or	al,cl		; break|stop|nbits
	mov	cl,ch
	and	cx,7
	mov	di,cx
   cs	or	al,[par_tab + di] ; break|parity|stop|nbits
	mov	cl,2
	test	ah,CLK_737	; test 7.37 clock flag
	jz	do_init
	xor	cl,cl
	jmp	do_init
; SI is word index to bit rate
; AL is LCR value
; CL is shift (2)
; BX is base port
; DX is LSR (will be decremented to LCR)


par_tab:
	db	0	;none
	db	1<<3	;odd
	db	3<<3	;even
	db	5<<3	;stick one
	db	7<<3	;stick zero
	db	0
	db	0
	db	0





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; install_SIO0_		install the system board SIO0 (internal) 386EX port
;
;    Enter with:
;	AX	device code to install
;	direction flag clear
;
;    Exit with:
;	AX	0 if successful
;		non-Zero if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	global	install_SIO0_
segment _TEXT			; this routine is C-callable

install_SIO0_:
	pushm	DX,CX,SI,DS
	mov	dx,ax		; use device code in DX
	get_bda	DS		; get BIOS Data Area segment pointer
	lea	SI,[serial_dev]
	mov	cx,4
.1:
	lodsw			; get a device code
   	cmp	ax,dx		; is it already there
	je	.8
	or	ax,ax		; is the slot empty
	jz	.3		; empty if 0, install here
	loop	.1
	jmp	.8		; no empty slot

; empty slot found SI is already incremented
.3:	mov	[si-2],dx	;set device code
	add	byte [equip_flag+1], 1<<(9-8)	; increment at bit 9
	jmp	.9		; AX is already zero

.8:	mov	ax,0x8E		;
.9:	popm	DX,CX,SI,DS
	ret
