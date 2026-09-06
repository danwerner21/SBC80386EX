;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sizer.asm -- size Extended Memory using protected mode
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
;%include "bda.inc"
%include "macro.inc"


segment CONST

PM_GDT	equ	0x000F_0000 + gdt0
	global	gdt0
;
; now the Global Descriptor Table prototype
;
	align	16
gdt0:	dq	0		; null descriptor
rom_gdt:
descr08	equ	$-gdt0
	dw	len_gdt-1
	dd	PM_GDT
	dw	0		; filler
descrP	equ	descr08


descr10	equ	$-gdt0
	dq	0		; LDT filler


descr18	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_DS	equ	descr18


descr20	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_ES	equ	descr20


descr28	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_SS	equ	descr28


descr30	equ	$-gdt0
	descr_linear_code	0, 0x03FF_FFFF	; 64meg DRAM
descr_CS	equ	descr30


descr38	equ	$-gdt0
	descr_linear_code	0xF0000, 0xFFFF ; 64K code (286)
descr_BIOS	equ	descr38


descr40	equ	$-gdt0
	descr_linear_data	0x400, 0x300	; BIOS data area
descr_BDA equ	descr40


descr48	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_FS	equ	descr48


descr50	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_GS	equ	descr50


descr58	equ	$-gdt0
	descr_linear_data	0, 0xFFFF	; 64K return Data segment
descr_RMdata	equ	descr58


descr60	equ	$-gdt0
	descr_linear_code	0x000F0000, 0xFFFF	; 64K return Code segment
descr_RMcode	equ	descr60


descr68	equ	$-gdt0
	descr_linear_code	0xF0000, 0x1FFFF ; 128K code
descr_BIOS32	equ	descr68


len_gdt		equ	$-gdt0



segment	_TEXT

	bits	16

	global	ext_mem_size
;
; enter protected mode to size Extended memory
;
ext_mem_size:
	lgdt	[rom_gdt]	; use ROM version of GDT
;
; set the PE bit to switch into Protected Mode
;
	mov	ebx,cr0			; get CR0 to set Prot Mode
	or	bl,1			; set PE bit
	mul	eax	;time waster for prefetch queue
	mov	cr0,ebx			; enter protected mode
; now in protected mode, but no segment registers are set
	jmp	descr_BIOS32:pm_continue

	bits	32
pm_continue:
	mov	dx,0x4FF
	mov	al,0xF0
	out	dx,al
;;;	hlt

	mov	ax,descr_DS		; set DS descriptor
	mov	ds,ax			; **

;	xor	ebx,ebx
;	xor	ebp,ebp
; stack value saves
;	mov	bx,ss
;	mov	esi,ebx			; save SS
;	mov	bp,sp			; save SP
;
;	shl	ebx,4			; account for
;	add	ebx,ebp			; new linear stack pointer
;
;	mov	ss,ax			; linear Stack
;	mov	esp,ebx			; set stack

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  __pm_sizeMem -- size Memory in Megabytes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	xor	eax,eax		; DO  I=0 TO 63
	mov	edx,[eax]	;save location [00000]
__pm_size1:
	mov	edi,eax
	shl	edi,20		; address Megabytes (2**20)
	mov	[edi],eax	; store the number 0..63
	inc	al
	cmp	al,64		; 64mb limit
	jb	__pm_size1

	sub	eax,[0]		; get memory size in megabytes
	mov	[0],edx		;restore location [00000]
	mov	edx,eax		; answer in EDX

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; now return to Real Mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
return_to_real:
	mov	ax,descr_RMdata		; 64K segment at 0x00000000
	mov	ds,ax
;;;	jmp	$+2	; clear prefetch queue
	jmp	descr_RMcode:real_return
real_return:
	bits	16

	mov	eax,cr0		;
	and	al,0xFE		; turn off PE bit
	mov	cr0,eax
	jmp	0xF000:really_return
;	jmp	far really_return
really_return:
	mov	ax,DGROUP
	mov	ds,ax
; the segment registers below were never touched in Protected Mode
;	mov	es,ax
;	mov	fs,ax
;	mov	gs,ax

; EDX is size in MB
	mov	ax,dx
	ret
