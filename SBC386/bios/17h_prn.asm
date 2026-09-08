;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 17h_prn.asm -- INT 17h, the parallel printer interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2026 Dan Werner.  All rights reserved.
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
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386EX.inc"
%include "macro.inc"

	global	int_17h

segment	_TEXT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 17h -- printer
;
;    Function		Usage
;    ========		=====
;	00	print the character in AL on printer DX
;	01	initialise printer DX
;	02	read the status of printer DX
;
;  All three return the printer status in AH.
;
; This board has no parallel port.  What matters is that the answer is a
; well-formed status rather than the invalid-command return: DOS probes
; LPT at startup, and a carry with AH=01 there reads as "function not
; supported", which is a different thing from "no printer" and does not
; always end the probe.
;
; The status returned is TIMEOUT (bit 0) with SELECTED (bit 4) clear --
; the unambiguous "nothing answered" that a retry loop terminates on.
; bda.parallel_dev[] stays zero, so DOS should not get this far anyway.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PRN_TIMEOUT	equ	0x01		; bit 0: operation timed out

int_17h:
	sti
	cmp	ah,2
	ja	.bad

	mov	ah,PRN_TIMEOUT		; no printer ever answers
	clc
	retf	2			; an INT handler returns FAR, and the
					;  caller's flags must be discarded

.bad:
	mov	ah,PRN_TIMEOUT
	stc
	retf	2
