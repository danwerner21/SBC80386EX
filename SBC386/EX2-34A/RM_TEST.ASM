;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; rm_test.asm -- real or V86 mode memory test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/
	bits	16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  rm_testSeg -- test any part of a real mode segment
;  rm_testSeb_bx -- same, but BX is the return address
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Enter with:
;	ES	segment selector to test
;	CX	count of WORDs to test, a multiple of 8 (Paragraph)
;	direction flag clear
;
;  Exit with:
;	AX	error count
;	BX is destroyed
;
;	All 16-bit registers preserved
;	High parts of 32-bit registers used as save areas
;	High half of some 32-bit registers are zeroed.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
rm_testSeg:
	pop	bx
rm_testSeg_bx:
	shl	ebx,16		; save return
	shl	edx,16
	shl	edi,16		; save DI value
	shl	esi,16		; save SI, zero error count
	shl	ebp,16

	mov	dx,cx		; copy CX
	shl	ecx,16		; save CX value
	shr	dx,1		; DX counts DWORDS
	mov	bp,di		; DI start of scan


	stc
	sbb	eax,eax		; EAX=0xFFFF_FFFF
	mov	bx,rm_ts1
	jmp	rm_testSeg_inner
rm_ts1:

	mov	eax,0x1234_FEDC	; pattern
	mov	bx,rm_ts2	;
	jmp	rm_testSeg_inner
rm_ts2:

	mov	eax,0xDCBA_5432	; pattern
	mov	bx,rm_ts3	;
	jmp	rm_testSeg_inner
rm_ts3:

	mov	eax,0x80402010	; pattern
	mov	bx,rm_ts4	;
	jmp	rm_testSeg_inner
rm_ts4:

	mov	eax,0x08040201	; pattern
	mov	bx,rm_ts5	;
	jmp	rm_testSeg_inner
rm_ts5:

	xor	eax,eax	 	; pattern
	mov	bx,rm_ts6	;
	jmp	rm_testSeg_inner
rm_ts6:


	shr	edx,16
	shr	edi,16		; restore DI value
	mov	ax,si		;  return Error Count

	shr	esi,16		; restore SI
	shr	ebp,16

	shr	ebx,16		; restore return
	jmp	bx	; RETURN


rm_testSeg_inner:
	mov	cx,dx	; DWORD count
	mov	di,bp	; start address

	align	2
	rep stosd

	mov	cx,dx	; DWORD count
	mov	di,bp	; start address
	align	2
rm_ts71:
	repe scasd	; test all of the values
	jne	rm_ts72
rm_ts7a: jmp	bx	; return

rm_ts72:
	inc	si	; count an error
	or	si,0x8000	; guarantee not zero
	jcxz	rm_ts7a	; if error occurred on last DWORD
	jmp	rm_ts71

