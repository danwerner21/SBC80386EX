;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; alloc.asm -- handle EBDA, UMB allocations
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ebda_alloc	Allocate bytes from the EBDA
;
;   void *ebda_alloc(word nbytes);
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	ebda_alloc, ebda_alloc_
ebda_alloc:
ebda_alloc_:
; check first to see if data area is set up
	pushm	DS
	get_bda	DS

%define nbytes AX
	mov	dx,[ebda_seg_ptr]
	or	dx,dx			; test for uninitialized
	jnz	.2
	mov	dx,[memory_size]	; get size in Kbytes (640)
	cmp	dx,512
  	jle	.1
	inc	dx			; allocate 1K above 640K
.1:
	shl	dx,6			; convert to paragraphs
.2:
; allocate only in units of paragraphs (16-bytes)
	add	ax,15			; round up to nearest PARA
	shr	ax,4			; divide by 16
	sub	dx,ax			; allocate it
	mov	[ebda_seg_ptr],dx
	mov	ax,dx
	shr	ax,6			; convert to Kbyte count
	mov	[memory_size],ax	; save it
	xor	ax,ax

	popm	DS
	ret
