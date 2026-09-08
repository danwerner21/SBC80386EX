;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; stub.asm -- quiet the linker on all the undefineds
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
%include "seg_def.inc"
%include "i386EX.inc"

segment	_TEXT

global	int_nop			; filler

global	int_zero_divide		; 0
global	int_single_step		; 1
global	int_NMI_interrupt	; 2
global	int_breakpoint		; 3  trap on INT3
global	int_overflow		; 4
global	int_bounds_check	; 5
global	int_invalid_opcode	; 6
global	int_FPU_escape		; 7

;;global	int_irq0	; (timer 0)	int_double_fault
global	int_irq1	; (keyboard)	int_FPU_seg_overrun
global	int_irq2	; (IRQ cascade)	int_invalid_TSS
global	int_irq3	;		int_seg_not_present
global	int_irq4	; (COM1)	int_stack_fault
global	int_irq5	;		int_gen_prot_fault
global	int_irq6	; (FDC)		int_page_fault
global	int_irq7	;

global	clear_irq0	; (timer 0)	int_double_fault
global	clear_irq1	; (keyboard)	int_FPU_seg_overrun
global	clear_irq2	; (IRQ cascade)	int_invalid_TSS
global	clear_irq3	;		int_seg_not_present
global	clear_irq4	; (COM1)	int_stack_fault
global	clear_irq5	;		int_gen_prot_fault
global	clear_irq6	; (FDC)		int_page_fault
global	clear_irq7	;

; int_10h now lives in 10h_video.asm
;;global	int_11h		; (equip. config)  see "11h_12h.asm"
;;global	int_12h		; (conv. memory size)   ditto
;;global	int_13h		; (disk I/O)
;;global	int_14h		; (serial I/O)	see "14h_sio0.asm"
;;global	int_15h		; (cassette I/O + much more)
; int_16h and int_irq4 now live in 16h_kbd.asm
; int_17h now lives in 17h_prn.asm

; int_18h now lives in 19h_boot.asm
; int_19h now lives in 19h_boot.asm
;;global	int_1Ah		; (CMOS clock)
global	int_1Bh		; (ctrl-Break)
global	int_1Ch		; (timer tick)
global	int_1Dh		; (video parameter table)
global	int_1Eh		; (floppy disk params)
global	int_1Fh		; (font 80h..0FFh)
;
;  MSDOS reserved	20h .. 3Fh
;
global	int_msdos
;
global	int_40h		; Floppy disk driver
global	param_hd0	; fixed disk parameters
global	int_42h		; Video driver
global	param_VGA	; VGA/EGA character table
global	param_font	; PCjr chars 00h..7Fh
global	int_nop		; unused
global	param_hd1	; fixed disk parameters
; times 3  dw	int_nop		; IRET
global	int_4Ah		; BIOS alarm handler
; times 15h dw	int_nop		; IRET

; times 6  dw	int_nop		; User interrupts
global	int_EMM		; LIM EMS driver
; times 8  dw	int_nop		; User interrupts

global	int_irq8	; (1024hz clock)
global	int_irq9	; (irq2 redirect)
global	int_irq10
global	int_irq11
global	int_irq12
global	int_irq13
global	int_irq14	; (IDE interrupt)
global	int_irq15	; (Watchdog Timer)

global	clear_irq8	; (1024hz clock)
global	clear_irq9	; (irq2 redirect)
global	clear_irq10
global	clear_irq11
global	clear_irq12
global	clear_irq13
global	clear_irq14	; (IDE interrupt)
global	clear_irq15	; (Watchdog Timer)

;
;  Reserved locations INT 80h..0F0h for Basic
;  Locations 0F1h..0FFh not assigned

int_zero_divide:
int_single_step:
int_NMI_interrupt:
int_breakpoint:
int_overflow:
int_bounds_check:
int_invalid_opcode:
int_FPU_escape:

int_nop:	iret



; Non-specific EOI (End of Interrupt) command
;
NS_EOI	equ	0x20

int_irq0:
int_irq1:
int_irq2:
int_irq3:
int_irq5:
int_irq6:
int_irq7:

clear_irq0:
clear_irq1:
;;clear_irq2:	;cascade (see below)
clear_irq3:
clear_irq4:
clear_irq5:
clear_irq6:
clear_irq7:
	push	ax
	mov	al,NS_EOI
	out	OCW2M_AT,al
	pop	ax
	iret



;;int_11h:
;;int_12h:
;;int_13h:
;;int_14h:
;;int_15h:

int_1Ah:
int_1Bh:
int_1Ch		equ	int_nop	; streamlined return
int_1Dh:
int_1Eh:
int_1Fh:


%define INVALID_COMMAND		1
int_EMM:
int_msdos:
int_40h:	; floppy disk handler
	sti
	mov	ah,INVALID_COMMAND
	stc
	retf	2


param_hd0:
int_42h:
param_VGA:
param_font:
param_hd1:
int_4Ah:
	iret

int_irq8:
int_irq9:
int_irq10:
int_irq11:
int_irq12:
int_irq13:
int_irq14:
int_irq15:

clear_irq8:
clear_irq9:
clear_irq10:
clear_irq11:
clear_irq12:
clear_irq13:
clear_irq14:
clear_irq15:
	push	ax
	mov	al,NS_EOI
	out	OCW2S_AT,al
	jmp	$+3
clear_irq2:
	push	ax
; jmp $+3 comes here
	mov	al,0x62		; specific EOI to irq2 on Master
	out	OCW2M_AT,al
	pop	ax
	iret

;
;  Reserved locations INT 80h..0F0h for Basic
;  Locations 0F1h..0FFh not assigned


; do this to shut up WATCOM 1.9
	global	_small_code_
	global	VIDEO_putchar_
	global	@VIDEO_putchar
	global	@CVDU_putchar
_small_code_:
	nop
	ret
;/* this is just a stub for the moment */
VIDEO_putchar_:
@VIDEO_putchar:
@CVDU_putchar:
; POST and DOS now share one output path: this goes through INT 10h
; teletype rather than straight to INT 14h, so the BDA cursor stays in
; step with what has actually been printed.
%define VSHOW 0
%if VSHOW
	mov	dx,0x4ff
	out	dx,al
%endif
	push	bx		; cprintf keeps the character in BX across the
				;  putch(CR) that precedes putch(LF) -- the old
				;  form of this routine only touched AX and DX,
				;  and clobbering BX cost every line feed
	mov	ah,0x0E		; teletype
	xor	bx,bx		; page 0
	int	0x10
	pop	bx
%if VSHOW
	mov	al,ah
	mov	dx,0x4ff
	out	dx,al
%endif
	ret



	global	KBD_getchar_
	global	@KBD_getchar

KBD_getchar_:
@KBD_getchar:
; This MUST go through INT 16h, not INT 14h.
;
; The SIO0 receive interrupt now drains the UART into the ring buffer
; the moment a character arrives, so a polled INT 14h read here would
; wait forever for data that has already been taken.  Everything that
; reads the console -- getline, SETUP, the monitor -- comes through
; this one routine, so this is the only place it has to change.
	xor	ah,ah		; read a key, waiting for one
	int	0x16
	and	al,0x7F		; mask to 7 bits, as before
	xor	ah,ah		; the caller wants the character, not the
	ret			;  scan code INT 16h returns alongside it


	global	FDC_stop_motor
	global	FDC_stop_motor_
FDC_stop_motor_:
FDC_stop_motor:
; totally a dummy routine
	ret
