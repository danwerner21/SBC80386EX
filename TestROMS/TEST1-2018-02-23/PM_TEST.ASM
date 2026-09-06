;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; pm_test.asm -- protected mode memory testing
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
	bits	32


%define	PATT 41			; 41, 37, 33
bitcount	equ	41		; 33, and 37 are former values

	align	4
pattern:
;;;;  1001_1000_1110_0101_1100_1000_1101_1100 000000000		41
;TPAT1	equ	0x98E5C8DC; carry=0
; pattern 0 is the same as the former 33, 37, and 41 bit patterns
 	dq	0_0000_0000__1001_1000_1110_0101_1100_1000_1101_1100b
	dq	-1



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  __pm_test41  --  test DWORD memory with rotating 41-bit pattern
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Enter with:
;	EDX:EAX	pattern (Carry & extension in EDX)
;	ECX 	memory DWORD count to test
;	EDI	memory address to start test
;
;  Exit with:
;	ESI	total error count
;
;	Other registers preserved
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
__pm_test41:
	pushm	ecx,edi, eax,edx, ebx

	xor	esi,esi		;zero the error count
	mov	bh,bitcount	; count all 41 bits of the pattern

__pm_test1:
	push	eax
	mov	al,bh
	call	__jleds
	call	__lites
	pop	eax

	mov	ecx,[esp]	;restore count at top of pass
	mov	edi,[esp+4]	;restore address likewise

	pushm	edx,eax		;save pattern
%if (PATT==33) | (PATT==41)
	shr	dh,1		; set carry
%endif

	align 2
__pm_test2:
	stosd			; store the pattern
%if PATT==37
	shl	dl,4		; shift out high bit (of 5)
	rcl	eax,1		; rotate the pattern
	rcr	dl,1		; shift in bit
	sar	dl,3		; propagate bit from EAX
	rol	dl,1		; put in bit 0 of dl
%elif PATT==33
	rcl	eax,1		; rotate the pattern
%elif PATT==41
	rcl	eax,1		; rotate the pattern
	rcl	dl,1		; bit into Carry
%endif
	loop	__pm_test2

; now do the readback
	popm	edx,eax		;restore original pattern

	mov	ecx,[esp]  	; get range to read back
	mov	edi,[esp+4]	;  **

	align 2
__pm_test3:
	scasd			; compare DWORD and increment EDI
				; SCAS affects the carry
	jne	__pm_terror
__pm_test3ok:
	jcxz	__pm_display	; with address override (CX, not ECX)
__pm_xdisplay:
%if PATT==37
	shl	dl,4		; shift out high bit (of 5)
	rcl	eax,1		; rotate the pattern
	rcr	dl,1		; shift in bit
	sar	dl,3		; propagate bit from EAX
	rol	dl,1		; put in bit 0 of DL
%elif PATT==33
;;	shr	dh,1		; set carry (3 clocks)
	add	dh,dh		; set carry (2 clocks)
	rcl	eax,1		; rotate the pattern
;;	rcl	dh,1		; save the carry (3 clocks)
  	sbb	dh,dh		; save the carry (2 clocks)
%elif PATT==41
	shr	dh,1		; set the carry
	rcl	eax,1		; rotate the pattern
	rcl	edx,1		; ** and save carry in DH bit 0
%endif
	loop	__pm_test3

;  all done withe this pass
	jmp	__pm_test4

	align 2
__pm_terror:
	inc	esi
	call	__pm_errWrite	;show error output line
	jmp	__pm_test3ok
__pm_display:
	pushm	eax,edx
	mov	eax,ecx
	shr	eax,16
	call	__lites
	popm	eax,edx
	jmp	__pm_xdisplay

__pm_test4:
	dec	bh		; count all the patterns
; start the loop over with an updated test pattern
	jnz	__pm_test1

	mov	ebx,eax
	popm	ecx,edi, eax,edx
	cmp	ebx,eax		;compare final to initial pattern
	je	__pm_test6
	inc	esi		;count an error if .ne.
__pm_test6:
	popm	ebx

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  __pm_errWrite -- output an error line
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Enter with:
;	EAX	expected pattern that did not match
;	EDI	points 1 dword beyond the error
;
;  Exit with:
;	All registers preserved
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
__pm_errWrite:
	pushm	ebx		;register save

	mov	ebx,eax		;save EAX (correct pattern)
	call	__crlf
	lea	eax,[edi-4]	;address where error occurred
	call	__eout
	mov	al,':'
	call	__putc		;  ADDR:
	call	__space
	mov	eax,ebx		; correct pattern
	call	__eout
	call	__space
	mov	al,'-'
	call	__putc
	mov	al,'>'
	call	__putc
	call	__space
	mov	eax,[edi-4]	;erroneous readback
	call	__eout
	mov	eax,ebx		;restore pattern

	popm	ebx		;register restore
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  __pm_sizeMem -- size Memory in Megabytes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Enter with:
;	nothing
;
;  Exit with:
;	EAX	size of 
;
;	Other registers preserved
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
__pm_sizeMem:
	pushm	edi		;just one save

	xor	eax,eax		; DO  I=0 TO 63
__pm_size1:
	mov	edi,eax
	shl	edi,20		; address Megabytes (2**20)
	mov	[edi],eax	; store the number 0..63
	inc	al
	cmp	al,64		; 64mb limit
	jb	__pm_size1

	sub	eax,[0]		; get memory size in megabytes

	popm	edi
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  __pm_test1bit -- test all the bit paths into memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Enter with:
;	ECX	BYTE count to test
;	EDI	address to test
;
;  Exit with:
;	ESI	error count
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
__pm_test1bit:
	pushm	ecx,edi, eax

	xor	esi,esi		;zero the error count
	mov	al,0xFE

.1:
	mov	ecx,[esp]
	mov	edi,[esp+4]	; reset the scan parameters
	rep stosb		; store all

	mov	ecx,[esp]
	mov	edi,[esp+4]	; reset the scan parameters

	call	__jleds
%if 1
	mov	ah,al
	rol	ah,4
	test	ah,al
	jz	.20
	and	al,ah
	jmp	.22
.20	or	al,ah
.22:	call	__lites		;preserves AX
	mov	al,ah
	ror	al,4
%endif

.2:	repe scasb
	je	.4
	inc	esi
	jecxz	.4	; just in case error was on last byte
	jmp	.2

.4:	rol	al,1		; shift the pattern
	cmp	al,0xFE
	je	.5
	cmp	al,0x01
	jne	.1

;pattern is 0x7F, done with all passes
	popm	ecx,edi, eax
	ret

;pattern is 0xFE, done with first passes
.5:
	mov	al,0x01
	jmp	.1		; go do the second loop



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;END pm_test.asm -- protected mode memory testing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
