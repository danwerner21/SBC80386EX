;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; crc.asm -- codes for calculating CRC7 & CRC16 checksums
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2013,2018 John R. Coffman.  All rights reserved.
; Provided for hobbyist use on the RetroBrew SBC-386EX board.
; Derived from codes that were ...
; Provided for hobbyist use on the N8VEM SBC-188 board.
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/
%include "seg_def.inc"
%include "macro.inc"

segment	CODE

%ifndef CRC16
%define CRC16 0		; don't include CRC16 calculations
%endif
%ifndef CRC7
%define CRC7 0
%endif


%if CRC7
%if CRC7==1
CRC7poly	equ	00100001b	; 8-bit polynomial
%else
CRC7poly	equ	00010010b
%endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; crc7	calculate a CRC7 polynomial
;    /* THIS CODE DIFFERS FROM THE crc7 USED WITH THE SDCARDs */
; calcCRC7  calculate CRC7 for the SDcard (no OR of last bit)
;
;  Enter with:
;	ES:BX	points at a string of bytes
;	CX	count of bytes in the string
;	direction flag clear
;
;  Return with:
;	ES:BX	point at next byte beyond end of string
;	CX = 0
;	AL = CRC7 polynomial byte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%if CRC7==2
	global	calcCRC7
calcCRC7:
%else
	global	crc7
crc7:
%endif
	push	dx
	xor	dl,dl		; start CRC7 at zero
.1:
   es	mov	al,[bx]		; get next byte
   	inc	bx
	mov	dh,8 			; 8 bits in AL
.11:	
	mov	ah,dl			; copy CRC to AH
	xor	ah,al			; Sign bit is 0 or 1
	shl	ax,1
	sbb	ah,ah			; AH is 0 or -1
	shl	dl,1			; shift polynomial

	and	ah,CRC7poly		; get bits to add into the CRC
; USE CRC7=1 FOR 8-BIT, CRC7=2 FOR 7-BIT (SDcards)

	xor	dl,ah			; update the polynomial
	dec	dh
	jnz	.11

	loop	.1

	mov	al,dl		; final CRC7 to AL
	pop	dx
	ret

%endif



%if CRC16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; crc16		add data to the input CRC16 calculation
;
;  Enter with:
;	ES:BX	data pointer
;	CX	count of bytes
;	AX	partial CRC16 sum
;
;  Return with:
;	ES:BX	updated data pointer
;	CX = 0
;	AX	updated CRC16 sum
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	crc16
crc16:
	pushm	si		; save SI

	mov	si,bx		; use ES:SI to address data
.2:
	mov	bl,ah		; form index into table
	xor	bh,bh		; zap BH
  es	xor	bl,[si]		; form table index
  	inc	si
  	mov	ah,al		; update CRC16
	xor	al,al
	shl	bx,1
  cs	xor	ax,[crc16tab + bx]
  	loop	.2

	mov	bx,si		; updated BX value
	popm	si
	ret


	align	2
%include "crc16tab.inc"

%endif

; end crc.asm

