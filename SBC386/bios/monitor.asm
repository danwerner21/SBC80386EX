;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; monitor.asm -- assembly support for the debug monitor
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

segment	_TEXT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; go_call -- FAR CALL an arbitrary Real Mode address, for the GO command
;
;	void __cdecl go_call(word seg, word off, T_REGS *regs);
;
; The register values in *regs are loaded before the call and written
; back from whatever the callee left behind, so GO can both set up a
; call and report what came out of it.
;
; A far CALL is used rather than a far JMP, so the target comes back to
; the monitor with a RETF.  A target that returns with IRET, or that
; leaves the stack unbalanced, will not find its way home.
;
; The callee is trusted for SS:SP and nothing else.  BP is re-formed
; from SP after the call because the callee is free to trash it.
;
;    Enter with (__cdecl -- arguments on the stack, caller cleans up):
;	[bp+4]	target segment
;	[bp+6]	target offset
;	[bp+8]	regs offset
;	[bp+10]	regs segment
;
;    T_REGS layout, in words:
;	+0 AX	+2 BX	+4 CX	+6 DX
;	+8 SI	+10 DI	+12 DS	+14 ES	+16 FLAGS
;
;    Exit with:
;	*regs updated, all of the monitor's own registers preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	_go_call
_go_call:
	push	bp
	mov	bp,sp
	pushm	ax,bx,cx,dx,si,di,ds,es		; SP is now BP-16

	sub	sp,4				; SP is now BP-20
	mov	ax,[bp+6]			; stage the far target where
	mov	[bp-20],ax			;  CALL FAR can reach it with
	mov	ax,[bp+4]			;  a BP-relative address
	mov	[bp-18],ax

; Load the entry values.  DS and ES travel through the stack because
; T_REGS is addressed through ES:DI right up to the last moment.
	les	di,[bp+8]			; ES:DI -> T_REGS
	push	word [es:di+14]			; ES for the callee
	push	word [es:di+12]			; DS for the callee
	mov	ax,[es:di+0]
	mov	bx,[es:di+2]
	mov	cx,[es:di+4]
	mov	dx,[es:di+6]
	mov	si,[es:di+8]
	mov	di,[es:di+10]			; DI last: it held the pointer
	pop	ds
	pop	es				; SP is back to BP-20

	call	far [bp-20]			; *** into the unknown ***

; Capture what came back.  PUSHF is first because nothing between the
; call and it may disturb the flags.
	pushf
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es

; Re-form BP.  A RETF with a balanced stack leaves SP at BP-20, and the
; nine words just pushed put it at BP-38.
	mov	bp,sp
	add	bp,38

	les	di,[bp+8]			; ES:DI -> T_REGS again
	pop	word [es:di+14]			; ES	(pushed last)
	pop	word [es:di+12]			; DS
	pop	word [es:di+10]			; DI
	pop	word [es:di+8]			; SI
	pop	word [es:di+6]			; DX
	pop	word [es:di+4]			; CX
	pop	word [es:di+2]			; BX
	pop	word [es:di+0]			; AX
	pop	word [es:di+16]			; FLAGS

	add	sp,4				; drop the staged far target
	popm	ax,bx,cx,dx,si,di,ds,es
	pop	bp
	ret			; __cdecl -- caller pops the arguments
