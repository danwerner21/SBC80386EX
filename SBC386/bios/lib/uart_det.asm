;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; uart_det.asm -- detect UART type
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
;	SBC-386EX 2.0	production / January 2017
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "../seg_def.inc"
%include "../macro.inc"

%define SAVE 0

segment	_TEXT
;
;	word uart_detect(word device_code);
;
;  Returns:
;	0	None
;	1	8250
;	2	16450/8250A
;	3	16550
;	4	16550A
;	5	16550C
;	6	16650
;	7	16750
;	8	16850	can't distinguish from 16650 yet
;
	global	uart_det_	; Watcom calling convention
uart_det_:
	pushm	bx,cx,dx,si,di

	mov	dx,ax		; base device code to DX
	inc	dx		; IER
	xor	ax,ax		; AH=0 (no uart), AL=0
	out	dx,al		; IER=0
	mov	ch,dl		; CH=IER
	inc	dx
	inc	dx		; DX=LCR
	mov	al,0x80
	out	dx,al		; LCR=80h, set DLAB
	mov	cl,dl		; CL=LCR
	mov	dl,ch		; DX=IER/DLH
	mov	al,0x5A
	mov	bh,al		; save 0x5A constant
	out	dx,al
	dec	dx
	not	al		; AL = 0xA5
	out	dx,al
	inc	dx
	in	al,dx		; readback
	cmp	al,bh
	je	.1
	or	al,al
	jne	.99		; no uart detected
	dec	dx
	in	al,dx
	inc	dx
	or	al,al
	jne	.99
	or	ah,0x40		; Divisor reads as 0x0000

.1:
	mov	dl,cl		; DX=LCR
	xor	al,al		; AL=0
	out	dx,al		; turn off DLAT access
	mov	dl,ch		; DX=IER
	in	al,dx		; get IER/DLH
	cmp	al,bh		; is it still 0x5A
	je	.99		; no UART if it is still 0x5A

	inc	ah		; AH=1, at least 8250
; Test for the scratch register presence
	add	dx,6		; DX=SCR
	mov	al,bh		; AL=0x5A
	out	dx,al		; SCR=0x5A
	in	al,dx		; read SCR
	cmp	al,bh		; is SCR there?
	jne	.99		; UART without SCR is 8250 vanilla

	inc	ah		; AH=2, it is 8250A or 16450
	xchg	dl,cl		; DX=LCR  CL=SCR
	mov	al,0xBF		; special value to enable FIFOs
	out	dx,al		; **
	xchg	dl,cl		; DX=SCR  CL=LCR
	in	al,dx		; read back SCR
	cmp	al,bh		; is SCR still 0x5A
	jne	.6

	mov	dl,cl		; DX=LCR  CL=LCR
	mov	al,0x80		; set DLAB bit once more
	out	dx,al		;  **
	dec	dx		; DX=FCR/IIR
	mov	al,0xE7
	out	dx,al		; set FCR/IIR
	in	al,dx		; read it back
	mov	bh,al		; save FCR in BH
	inc	dx		; DX=LCR
	xor	al,al
	out	dx,al		; reset DLAB bit

	test	bh,1<<6		; test bit 6
	jz	.99		; it is 16450
	inc	ah		; AH=3 at least a 16550
	test	bh,1<<7		; test bit 7
	jz	.99		; it is 16550
	test	bh,1<<5		; bit 5, 64-byte FIFO
	jnz	.7		; set, it is a 16750

	inc	ah		; AH=4      16550A or  16550C
	inc	dx		; DX=MCR
	mov	al,0x20
	out	dx,al		; set AFE bit
	in	al,dx
	test	al,0x20		; still set
	jz	.99		; it is a 16550A
	inc	ah		; AH=5	   16550C
	jmp	.99

.7:	; it is 16750
	mov	ah,3		; will return 7

.6:	; it is 16650 or 16850
	add	ah,4		; AH was 2 if label .6 is branched to
.99:
	mov	al,ah
	cbw			; always positive

	popm	bx,cx,dx,si,di
	ret			; return UART level in AX
