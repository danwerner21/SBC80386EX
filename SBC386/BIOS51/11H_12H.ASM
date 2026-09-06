;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 11h_12h.asm -- handle the trivial BIOS calls
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

	global	int_11h
	global	int_12h
segment CODE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int_11h	Get Equipment Configuration word
;
;    Enter with:
;	nothing
;
;    Exit with:
;	AX	equipment configuration word; viz.,
;
;			bits 15 14	number of printers
;			bit  13		used on PC,XT,PCjr only
;			bit  12		1=game adapter present
;			bits 11 10 9	number of RS-232 ports
;			bit  8		reserved
;			bits 7 6	no. of floppy drives - 1, if bit0 set
;			bits 5 4	initial video mode
;						00 - reserved
;						01 - 40x25 color text
;						10 - 80x25 color text
;						11 - 80x25 monochrome
;			bit  3		no longer used (was on PC)
;			bit  2		has pointing device (PS/2)
;			bit  1		math coprocessor (FPU) installed
;			bit  0		has floppy disk(s) (see bits 7 6)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int_11h:
	sti
	push	DS	;save seg. reg.
	get_bda	DS
	mov	ax,[equip_flag]
	pop	DS
	cnop
	iret




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int_12h	Get Conventional Memory size in K-words
;
;    Enter with:
;	nothing
;
;    Exit with:
;	AX	number of 1K blocks below 1Mb (up to 640)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int_12h:
	sti
	push	DS	;save seg. reg.
	get_bda	DS
	mov	ax,[memory_size]
	pop	DS
	cnop
	iret


