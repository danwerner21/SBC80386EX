;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; icu.asm -- routines for the ICU's (master & slave)
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


	global	mask_interrrupt, mask_interrupt_
	global	unmask_interrupt, unmask_interrupt_

segment	_TEXT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; mask_interrupt
;
;    Enter with:
;	AX	interrupt to mask off (0..15)
;
;    Exit with;
;		specified interrupt is masked off
;
; N.B. routine may be called from C-code
;
;	void mask_interrupt(int);
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
mask_interrupt_:
mask_interrupt:
	pushm	cx,dx

	xchg	ax,cx		; CX is interrupt number
	mov	ax,1
	and	cx,15		; insurance
	shl	ax,cl
	mov	dx,OCW1S_AT	; set for slave
	or	al,al
	jz	.2		; non-zero means master
	mov	dx,OCW1M_AT
	mov	ah,al
.2:			; enable bit is in AH
	in	al,dx		; read current mask
	or	al,ah		; set bit
	out	dx,al		; set mask

	popm	cx,dx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unmask_interrupt
;
;    Enter with:
;	AX	interrupt to unmask (0..15)
;
;    Exit with;
;		specified interrupt is turned on
;
; N.B. routine may be called from C-code
;
;	void unmask_interrupt(int);
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
unmask_interrupt_:
unmask_interrupt:
	pushm	cx,dx

	xchg	ax,cx		; CX is interrupt number
	mov	ax,1
	and	cx,15		; insurance
	shl	ax,cl
	mov	dx,OCW1S_AT	; set for slave
	or	al,al
	jz	.2		; non-zero means master
	mov	dx,OCW1M_AT
	mov	ah,al
.2:			; enable bit is in AH
	not	ah		; disable mask in AH
	in	al,dx		; read current mask
	and	al,ah		; clear bit
	out	dx,al		; set new mask

	popm	cx,dx
	ret
