;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 15h_misc.asm -- handle many miscellaneous BIOS calls
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

	global	int_15h

segment	_TEXT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h was originally the Cassette I/O interface, but many, many
; additional functions were added, making this one of the most general
; BIOS function call.
;
;    Function		Usage
;    ========		=====
;	00	turn on cassette motor	[PC]
;	01	turn off cassette motor	[PC]
;	02	read cassette		[PC]
;	03	write cassette		[PC]
;
;	0Fh	format ESDI drive periodic interrupt [PS/2]
;	21h/00	read POST error log	[PS/2]
;	21h/01	write POST error log	[PS/2]
;
;	4Fh	keyboard intercept	[PS/2]
;
;	80h	device open		[AT][PS/2]
;	81h	device close		[AT][PS/2]
;	82h	process termination	[AT][PS/2]
;	83h	event wait		[AT][PS/2]
;	84h	read joystick		[AT][PS/2]
;	85h	SysReq key		[AT][PS/2]
;	86h	delay			[AT][PS/2]
;	87h	move Extended memory block [AT][PS/2]
;	88h	get Extended memory size [AT][PS/2]
;	89h	enter protected mode 	[AT][PS/2]
;
;	90h	device wait 		[AT][PS/2]
;	91h	device post 		[AT][PS/2]
;
;	0C0h	get system environment	[AT][PS/2]
;	0C1h	get address of Extended BIOS Data Area (EBDA) [PS/2]
;
;	0C2h/00	enable/disable pointing device [PS/2]
;	0C2h/01	reset pointing device 	[PS/2]
;	0C2h/02	set sample rate 	[PS/2]
;	0C2h/03	set resolution 		[PS/2]
;	0C2h/04	get pointing device type [PS/2]
;	0C2h/05	initialize pointing device interface [PS/2]
;	0C2h/06	set scaling OR get status [PS/2]
;	0C2h/07	set pointing device handler address [PS/2]
;
;	0C3h	set watchdog timeout	[PS/2]
;	0C4h	programmable option select [PS/2]
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int_15h:			; INT 0x15 enters here
; interrupts are disabled at this point
	cmp	ah,0x4F		;check for Keyboard Intercept
	jne	.1
; the keyboard code will set the Carry to make a simple IRET
; the simplest dummy code
	iret		; NULL return



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; other calls will be decoded with interrupts enabled
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.1:	sti
	cmp	ah,04h		; cassette calls are all below 4
	jae	.2
; it is a cassette call
.86:	mov	ah,0x86		; function not supported
	stc
	retf	2		;return with Carry set & error code


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; decode the 0x8? series
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.2:	sub	ah,0x80		;
	jz	device_open	; function 0x80
	cmp	ah,0x0A
	jae	.3
; 0x87 series
	dec	ah
	jz	device_close	; function 0x81
	dec	ah
	jz	process_term	; function 0x82
	dec	ah
	jz	event_wait	; function 0x83
	dec	ah
	jz	read_joystick	; function 0x84
read_joystick	equ	.86
	dec	ah
	jz	sys_req_key	; function 0x85
sys_req_key	equ	.86
	dec	ah
	jz	delay		; function 0x86
	dec	ah
	jz	mov_ext_mem	; function 0x87
	dec	ah
	jz	get_ext_mem_siz	; function 0x88
	jmp	enter_protected	; function 0x89



.3:	cmp	ah,0x10		;
	jz	device_wait	; function 0x90
	cmp	ah,0x11
	jz	device_post

; check the 0xC0++ series

	sub	ah,0x40		; 0xC0 subtracted now
	jz	get_sys_env
	cmp	ah,5		; all calls below 5
	jae	.86		; function not supported

; the 0xC0 series
	dec	ah
	jz	get_EBDA	; function 0xC1
	dec	ah
	jz	point_dev
point_dev	equ	.86	; function 0xC2
	dec	ah
	jz	watchdog	; function 0xC3
watchdog	equ	.86
	jmp	prog_opt	; function 0xC4
prog_opt	equ	.86





device_open:		; function 0x80
device_close:		; function 0x81
process_term:		; function 0x82
event_wait:		; function 0x83
;delay:			; function 0x86	-- below
;mov_ext_mem:		; function 0x87	-- below
;get_ext_mem_siz:	; function 0x88	-- below
enter_protected:	; function 0x89

device_wait:		; function 0x90
device_post:		; function 0x91
;get_sys_env:		; function 0xC0	-- below
get_EBDA:		; function 0xC1
	jmp	int_15h.86	;for now




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h
; Function 86	Delay
;
;    Enter with:
;	AH	86h originally, now 0x00 due to decode
;	CX:DX	delay time in microseconds
;
;    Exit with:
;	Carry 	clear, if wait was performed
;		set. if wait was not performed
;
;    Notes:
;	The PC/AT BIOS uses the 1024hz CMOS interrupt to provide wait
;	time resolution to within 976usec.  The routine here uses
;	the 1mhz timer 1 counter to provide finer resolution for short
;	waits.  Longer waits use the 18.2hz clock, with a resolution
;	of 54.9ms.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  interrupts are enabled by the time we get to here
;
delay:
	cmp	cx,4		;about 250,000 usec
	jb	short_delay	;below that, the 1mhz counter

; Low resolution delays below:
;
; calculate the tick count (approximate)

	pushm	ax,bx,cx,dx,ds

; microsecond count is in CX:DX
;
; if clock ticks have been converted to 65536/hr, then
;  usec * 64 / 1875 / 1875 gives the clock tick count (18.2hz)

	mov	ax,cx		; AX:DX
	mov	bx,dx		; AX:BX
	xor	dx,dx		; 0:AX:BX
	mov	cx,6		; set for * 64 (by shifting)
.1:	shl	bx,1
	rcl	ax,1
	rcl	dx,1
	loop	.1		; DX:AX:BX is 6-byte usec * 64

	mov	cx,1875
; do the first long division
	div	cx		; (DX=rem, AX=quo)
	xchg	ax,bx
	div	cx		; BX:AX is first quotient

	xor	dx,dx
	xchg	ax,bx		; DX:AX:BX
	div	cx
	xchg	ax,bx
	div	cx		; BX:AX is final tick count
%if 0
	pushm	ax,bx
	mov	dx,bx
	extern	dout
	call	dout
	popm	ax,bx
%endif
	get_bda	DS

loc	equ	printer_timeout+3	;PRT4

do_delay:
; only very short delays are handled at this time !!!!!!
	or	bh,bl
	or	bh,ah
	jz	.1
	mov	al,255
.1:
	mov	byte [loc],al

.2:
	hlt			; HALT here doubles the delay unless
				;  HSREADY is set in PWRCON
	cmp	byte [loc],0
	jne	.2

.9:
	popm	ax,bx,cx,dx,ds
	clc
	retf	2


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The 1mhz counter -- Timer 1
;
; CLKPRS is calibrated at POST from the measured CPU clock so that PSCLK
; comes out at 1.000mhz (start.asm), and counters 1 and 2 are driven from
; PSCLK.  Counter 1 is programmed MODE0 with a count of 65536, so once its
; gate is open it is simply a free-running 16-bit DOWN counter ticking once
; per microsecond and wrapping every 65.536ms.
;
; POST opens counter 0's gate only -- start_timer0_ in 1Ah_time.asm writes
; TIMER_STOP+BIT1 -- so the gate has to be opened here before the counter
; can be read.  Nothing unmasks a timer interrupt (OCW1M masks everything
; and only IRQ0 and IRQ4 are ever unmasked), so letting counter 1 run costs
; nothing and it is left running.
;
; The port numbers and the gate bits are spelled out here rather than taken
; from timer.inc: that file emits a binit record of its own at file scope,
; so including it would plant three stray bytes in _TEXT.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
T1_LATCH	equ	0x40	; counter 1, counter-latch command
T1_GATES	equ	0x4B	; timer.inc TIMER_RUN: gates for counters 0 and 1


;-----------------------------------------------------------------------------
; t1_read -- the current value of the 1mhz counter
;
;    Exit with:
;	AX	counter 1, counting down
;	every other register and the flags preserved
;
; The latch command and the two reads that follow it are one indivisible
; operation: an interrupt that latched again between them would leave the
; two halves coming from different samples.
;-----------------------------------------------------------------------------
t1_read:
	push	dx
	pushf
	cli

	mov	al,T1_LATCH
	mov	dx,TMRCON
	out	dx,al
	mov	dx,TMR1
	in	al,dx		; count low
	mov	ah,al
	in	al,dx		; count high
	xchg	al,ah		; AX = the latched count

	popf
	pop	dx
	ret


;-----------------------------------------------------------------------------
; short_delay -- INT 15h function 86h, for waits below 250ms
;
;    Enter with:
;	CX:DX	the delay in microseconds (CX <= 3, so 262143 at most)
;
;    Exit with:
;	Carry	clear
;	all registers preserved
;
; The counter is sampled, not programmed: each pass subtracts however many
; microseconds have gone by since the previous sample, and the 16-bit
; subtraction rides through the counter's wrap the same way the 18.2hz
; deadlines in diskide.asm ride through theirs.  A pass of this loop is a
; few microseconds, far short of the 65.536ms wrap, so no wrap is missed.
;
; Interrupts stay enabled.  A tick or a received character taken during the
; wait is real elapsed time, and is counted as such.
;
; The 18.2hz tick is watched as well, and not for timekeeping: if counter 1
; never moves -- a gate that did not open, a PSCLK that is not running --
; the subtraction above would never reach zero and DOS would hang inside
; INT 15h.  The tick is driven from counter 0 by a different gate bit and a
; different clock, so it is independent evidence that time is passing.  Six
; ticks is 439ms, comfortably past the 262ms this path is ever asked for, even
; allowing a whole tick of slop in the sample taken on the way in.
;-----------------------------------------------------------------------------
T1_BAILOUT	equ	8		; 18.2hz ticks: ~439ms

short_delay:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	push	es

	movzx	esi,cx		; ESI = the requested microseconds
	shl	esi,16
	mov	si,dx

	mov	al,T1_GATES	; open counter 1's gate.  Counter 0's gate bit
	mov	dx,TMRCFG	;  is set in the same write, so the 18.2hz tick
	out	dx,al		;  is not disturbed

	get_bda	ES
    es	mov	cx,[timer_count_low]	; CX = the tick we started on

	call	t1_read
	mov	di,ax		; DI = the previous sample
.1:
	call	t1_read
	mov	bx,di
	sub	bx,ax		; counting down, so previous - current
	mov	di,ax
	movzx	ebx,bx
	sub	esi,ebx		; microseconds still to wait
	jbe	.9

    es	mov	dx,[timer_count_low]
	sub	dx,cx			; ticks gone by, riding the wrap
	cmp	dx,T1_BAILOUT
	jb	.1			; counter 1 is dead -- stop waiting
.9:
	pop	es
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	clc
	retf	2


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h
; Function 87h	Move a block of Extended memory
;
;    Enter with:
;	AH	87h originally, now 0x00 due to decode
;	CX	the number of WORDS to move, 8000h (64Kb) at most
;	ES:SI	a six-entry Global Descriptor Table:
;		  00h	null
;		  08h	the GDT itself	-- filled in here
;		  10h	source		-- the caller's
;		  18h	destination	-- the caller's
;		  20h	BIOS code	-- filled in here
;		  28h	stack		-- filled in here
;
;    Exit with:
;	AH	00 on success, 02 if the request cannot be honoured
;	Carry	clear on success, set on failure
;
;    Notes:
;	The caller supplies the table because this BIOS has nowhere to build
;	one: _DATA and _BSS are empty by design and ROM cannot be written.
;	The three entries the interface reserves for the BIOS are written
;	into the caller's table, which is in RAM.
;
;	The move runs in 16-bit protected mode.  The caller's source and
;	destination descriptors are 286-style, with a 16-bit limit, so a
;	plain REP MOVSW from offset zero reaches every byte either one can
;	describe and the 32-bit machinery in sizer.asm is not needed.  A
;	caller that asks for more words than its own descriptors cover will
;	fault, with no IDT to catch it -- the same exposure the PC/AT BIOS
;	has always had here.
;
;	There is no A20 gate to open on this board.  PORT92_AT bit 1 is set
;	at POST and nothing masks address line 20 in any case.
;
;	Interrupts are off across the switch: there is no protected mode
;	IDT, so an interrupt taken in protected mode would fault with
;	nothing to catch it.  A full 64Kb move is short enough that the
;	18.2hz tick is not lost.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GDT_SRC		equ	0x10
GDT_DST		equ	0x18
GDT_CODE	equ	0x20
GDT_STACK	equ	0x28
GDT_LEN		equ	6*8		; six descriptors

mov_ext_mem:
	cmp	cx,0x8000	; 64Kb is the most one call can move
	ja	.bad
	or	cx,cx
	jz	.done		; nothing to move

	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	push	ds
	push	es
	pushf
	cli

; the linear address of the caller's table
	mov	ax,es
	movzx	eax,ax
	shl	eax,4
	movzx	ebx,si
	add	eax,ebx		; EAX = the GDT's linear base

; Descriptor 08h is the table itself.  In 16-bit operand size LGDT takes a
; 16-bit limit and a 24-bit base -- exactly the first six bytes of a
; 286-style descriptor -- so the entry serves as the LGDT operand where it
; sits.  Storing the base as a dword also puts zero in the access byte,
; which leaves a null descriptor behind rather than a bogus one.
	mov	word [es:si+8],GDT_LEN-1
	mov	[es:si+10],eax

; Descriptor 20h is this code: base F0000, limit 64K, 16-bit exec/read.
	mov	word [es:si+GDT_CODE],0xFFFF	; limit 15:0
	mov	word [es:si+GDT_CODE+2],0	; base 15:0
	mov	byte [es:si+GDT_CODE+4],0x0F	; base 23:16
	mov	byte [es:si+GDT_CODE+5],0x9B	; present, ring 0, exec/read
	mov	word [es:si+GDT_CODE+6],0	; limit 19:16, byte granular,
						;  16-bit, base 31:24

; Descriptor 28h covers the caller's stack with a 64K limit.  It is never
; loaded into SS -- nothing touches the stack between the two writes to
; CR0 -- but DS and ES are given it on the way out, so that no segment
; leaves protected mode with a cached limit larger than real mode allows.
	mov	ax,ss
	movzx	eax,ax
	shl	eax,4
	mov	word [es:si+GDT_STACK],0xFFFF
	mov	[es:si+GDT_STACK+2],eax
	mov	byte [es:si+GDT_STACK+5],0x93	; present, ring 0, read/write
	mov	word [es:si+GDT_STACK+6],0

	lgdt	[es:si+8]

	mov	ebx,cr0		; CR0 is held in EBX because the prefetch
	or	bl,1		;  flush below eats EAX
	mul	eax		; time waster for the prefetch queue
	mov	cr0,ebx		; enter protected mode
	jmp	GDT_CODE:.pm

.pm:
	mov	ax,GDT_SRC	; the caller's source
	mov	ds,ax
	mov	ax,GDT_DST	; the caller's destination
	mov	es,ax
	xor	si,si
	xor	di,di
	cld
	rep	movsw		; CX words, DS:SI -> ES:DI

	mov	ax,GDT_STACK	; 64K limits before leaving
	mov	ds,ax
	mov	es,ax

	mov	eax,cr0
	and	al,0xFE		; clear PE
	mov	cr0,eax
	jmp	0xF000:.rm
.rm:
	popf
	pop	es
	pop	ds
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
.done:
	xor	ah,ah		; no error
	clc
	retf	2

.bad:
	mov	ah,2		; "exception error" -- the nearest thing this
	stc			;  interface has to say about a bad request
	retf	2


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h
; Function 88h	Get the Extended memory size
;
;    Exit with:
;	AX	kilobytes of memory above the first megabyte
;	Carry	clear
;
;    Notes:
;	start.asm sizes memory with ext_mem_size, subtracts the first
;	megabyte and stores the remainder in kilobytes, which is exactly
;	what this call reports.  HIMEM.SYS will not load without it.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
get_ext_mem_siz:
	push	ds
	get_bda	DS
	mov	ax,[extended_memory]
	pop	ds
	clc
	retf	2


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 15h
; Function C0h	Get the system configuration table
;
;    Exit with:
;	ES:BX	-> the table below
;	AH	00
;	Carry	clear
;
;    Notes:
;	Model FCh is the PC/AT, which is what this BIOS presents: a
;	cascaded pair of interrupt controllers, a real-time clock, and
;	INT 13h with the AT fixed-disk geometry calls.  The submodel and
;	the revision are this board's own.
;
;	Feature byte 1 is the only one of the five with anything to say:
;	  bit 6	 a second interrupt controller is present -- the 386EX ICU
;		 is a cascaded pair, master at 20h and slave at A0h
;	  bit 5	 a real-time clock is present -- the DS1302, reached
;		 through INT 1Ah functions 02h..05h
;	Bit 4 stays clear: the keyboard path in 16h_kbd.asm does not call
;	INT 15h function 4Fh.  Bit 2 stays clear: no EBDA is allocated and
;	function C1h still reports unsupported.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	align	2
sys_config:
	dw	sys_config_end - sys_config - 2	; count of the bytes following
	db	0xFC		; model:    PC/AT
	db	0x01		; submodel: SBC-386EX 2.0
	db	0x00		; BIOS revision
	db	BIT6+BIT5	; feature byte 1
	db	0		; feature byte 2
	db	0		; feature byte 3
	db	0		; feature byte 4
	db	0		; feature byte 5
sys_config_end:

get_sys_env:
	push	cs		; the table sits in ROM alongside this code
	pop	es
	mov	bx,sys_config
	xor	ah,ah
	clc
	retf	2
