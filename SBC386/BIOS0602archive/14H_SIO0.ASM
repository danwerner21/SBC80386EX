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
;  N.B.  only the PC/XT calls are included at this time
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "bda.inc"
%include "macro.inc"

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
	pushm	BX,CX,DX,DS	; AX is usually a return value
	get_bda	DS		;get DS = segment pointer to BDA
	mov	cx,[equip_flag]	; equipment flag in BDA
	shr	cx,9		;number of RS-232 ports
	and	cx,7		; **
	mov	bx,dx		; COM1==0, COM2==1, ...
	cmp	bx,cx		; 4 COM ports at most
	jae	bad_error

; the index in BX is below the number in CX
	add	bx,bx
	mov	dx,[serial_dev + BX]
	or	dx,dx
	jz	bad_error
	mov	cx,dx		; CX = base
	add	dx,LSR0-TBR0	; DX = Line Status Register
;
; we have the I/O base device code in DX
;
	or	ah,ah		; test for 0
	jz	init_sio
	dec	ah
	jz	write		; function 1
	dec	ah
	jz	read		; function 2
	dec	ah
	jz	status		; function 3
;
; the PS/2 functions are not implemented
;
bad_error:
	mov	ax,0x8E0F	; AH.7 = timeout
return_AX:
	popm	BX,CX,DX,DS	; restore the registers
	iret



SHIFT	equ	0		; set to 2 for 7.3728 mhz on 4UART
OSC	equ	1843200<<SHIFT
CLK	equ	OSC/16

	global	sio_divisors
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
;	CX	port base I/O address
;	DX	LSR I/O address
;
;    Exit with:
;	AH	line status
;	AL	modem status
;
;	CX	port I/O base address
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
;	CX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	character read
;	CX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read:
	call	get_status
	test	ah,LSR_RBF	;anything in the buffer
	jz	read

	xchg	cx,dx		;RBR to DX
	in	al,dx		;get the character
	xchg	cx,dx		;LSR to DX
	mov	bl,al		; save char read in
	call	get_status
	and	ah,BIT4+BIT3+BIT2+BIT1	; mask pertinent bits
	jz	.3
	or	ah,BIT7		;signal error
.3:
	mov	al,bl		;return char in AL, LSR in AH
	jmp	return_AX


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; write
;
;    Enter with:
;	AL	character to write
;	CX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	unchanged char
;	CX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

write:
	mov	bl,al		;save output character
.1:
	call	get_status	;line status to AH
	test	ah,LSR_TBE	;buffer empty?
	jz	.1

	xchg	cx,dx		;DX = base (TBR)
	mov	al,bl		; AL = character
	out	dx,al		; put it out
	xchg	cx,dx		;DX = LSR again
	call	get_status
	mov	al,bl		;restore char in AL
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
;	CX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	modem status
;	CX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_sio:
	mov	ah,al		;save init bits in AH
	dec	dx
	dec	dx		; LSR-2 is LCR
	mov	al,80h		; set Latch enable
	out	dx,al		;enable divisor latch
	mov	bl,ah		;data rate bits to BX.765
	shr	bx,4		;  to bits 321
	and	bx,0x0E		;mask bits
   cs	mov	bx,[sio_divisors + bx]
   	mov	al,bl		; low divisor
	xchg	cx,dx		; DLL to DX
	out	dx,al
	inc	dx		; DLH to DX (also IER)
	mov	al,bh		;high divisor
	out	dx,al
	xchg	cx,dx		;LCR to DX, IER to CX
	mov	al,00011111b	;mask for status bits
	and	al,ah		;mask bits, clear DLAB
	out	dx,al
	inc	dx
	inc	dx	 	;LCR+2 = LSR
	xchg	cx,dx		; IER to DX
	xor	ax,ax
	out	dx,al		;turn off all interrupts
	dec	dx		;base to DX
	xchg	cx,dx		;base to CX, LSR to DX
;  return status in AH,AL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; status
;
;    Enter with:
;	CX	base port address
;	DX	LSR port address
;
;    Exit with:
;	AH	port (line) status
;	AL	modem status
;	CX,DX	unchanged
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

status:
	call	get_status
	jmp	return_AX




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
