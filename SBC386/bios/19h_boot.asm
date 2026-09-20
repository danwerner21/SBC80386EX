;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 19h_boot.asm -- INT 19h, the bootstrap loader
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
;
; Modelled on BOOT_STRAP_1 in ATBIOS/ATBIOS/test6.asm.  The diskette path
; was dropped when this was first written, there being no floppy hardware
; on the board; it is back now that there is, and tried first.
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "macro.inc"
%include "bda.inc"		; floppy_tab, and serial_dev for reboot_
; ASCII_CR and ASCII_LF come from i386ex.inc -- "ascii.h" is a C
; header and NASM cannot read it

	global	int_18h
	global	int_19h

segment	_TEXT

BOOT_SEG	equ	0x0000		; the boot sector is loaded and entered
BOOT_OFF	equ	0x7C00		;  at 0000:7C00, by long convention
BOOT_DRIVE	equ	0x80		; first fixed disk
BOOT_FLOPPY	equ	0x00		; drive A
BOOT_RETRIES	equ	4		; as the PC/AT did
BOOT_FD_TRIES	equ	2		; fewer for the floppy: an empty drive
					;  is the ordinary case, and every
					;  attempt costs a motor spin-up


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 19h -- Bootstrap Loader
;
; Read cylinder 0, head 0, sector 1 into 0000:7C00, check that it ends in
; AA55h, and enter it.
;
; The floppy is tried first and the fixed disk second, which is the order a
; PC has always used and the reason anyone can repair a machine whose hard
; disk will not boot.  This one had no such route until the floppy driver
; worked: a bad CF meant reflashing the BIOS to get anywhere.
;
; The floppy is skipped entirely when SETUP says no drive is fitted, since
; there is no way to ask the hardware -- and an empty drive is the ordinary
; case anyway, so it gets two attempts rather than four.
;
; This call does not return.  It replaces the stack it was entered on,
; because the boot sector is entitled to assume nothing about whatever
; POST was using -- and on this board POST's stack lives up in the SRAM
; at A800:xxxx, which is no use to anything that follows.
;
;  Hands control over with:
;	CS:IP	0000:7C00
;	DL	the drive it was read from, 00h or 80h
;	DS,ES	0000
;	SS:SP	0000:7C00, growing down away from the sector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_19h:
	cli
	xor	ax,ax
	mov	ss,ax			; the stack the boot sector expects:
	cnop
	mov	sp,BOOT_OFF		;  0000:7C00, growing downward
	mov	ds,ax
	cnop
	mov	es,ax
	cnop
	sti
	cld

; The floppy first, but only if SETUP says one is there.
	push	ds
	get_bda	DS
	mov	al,[floppy_tab]
	pop	ds
	or	al,al
	jz	.fixed

	mov	si,msg_try_a
	call	boot_msg
	mov	dx,BOOT_FLOPPY
	mov	cx,BOOT_FD_TRIES
	call	boot_try
	jnc	.enter

.fixed:
	mov	si,msg_try_c
	call	boot_msg
	mov	dx,BOOT_DRIVE
	mov	cx,BOOT_RETRIES
	call	boot_try
	jnc	.enter

	mov	si,msg_noread
	call	boot_msg
; INT 18h is where the PC/AT went when nothing would boot.  Here it
; prints and drops into the debug monitor, and retries the boot when the
; monitor is left -- so this call does not normally come back.
	int	0x18
.hang:
	hlt
	jmp	.hang

.enter:
	push	si			; the drive it was found on -- printing
	mov	si,msg_booting		;  the message is about to overwrite SI
	call	boot_msg
	pop	dx			; DL = that drive, DH = 0
	xor	ax,ax
	mov	ds,ax
	cnop
	mov	es,ax
	cnop
	jmp	BOOT_SEG:BOOT_OFF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; boot_try -- load and check a boot sector from one drive
;
;    Enter with:
;	DX	the drive: 0000h for A, 0080h for the first fixed disk.
;		DH must be zero -- it is the head the sector is read from
;	CX	how many attempts to make
;
;    Exit with:
;	Carry clear, and 0000:7C00 holding a sector that ends in AA55h
;	SI	the drive, for handing to the sector in DL
;	Carry set if it could not be read, or carried no signature
;
; The landing area is cleared before each drive is tried.  A read that
; fails part way through, or a drive that returns short, must not be able
; to leave anything executable there from an earlier attempt -- and with
; two drives now tried in turn, "an earlier attempt" includes the other
; one.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
boot_try:
	pushm	ax,bx,cx,dx,di,es

	mov	si,dx			; the drive, kept across INT 13h

	xor	ax,ax
	mov	es,ax
	cnop
	mov	di,BOOT_OFF
	push	cx
	mov	cx,256			; 256 words == one sector
	rep	stosw			; AX is still zero
	pop	cx

.retry:
	push	cx

; Reset first.  On the fixed disk that also puts the drives back into
; 8-bit PIO after the soft reset -- see fn00 in 13h_disk.asm.
	mov	dx,si
	mov	ah,0
	int	0x13
	jc	.again

	mov	dx,si			; DH is zero: head 0
	mov	ax,0x0201		; read, one sector
	mov	cx,0x0001		; cylinder 0, sector 1
	xor	bx,bx
	mov	es,bx			; ES:BX = 0000:7C00
	cnop
	mov	bx,BOOT_OFF
	int	0x13
	jnc	.loaded

.again:
	pop	cx
	loop	.retry
	stc
	jmp	short .9

.loaded:
	pop	cx

; The last two bytes of a bootable sector are AA55h.  Without this test a
; blank or data-only disk would be executed as code.
	xor	ax,ax
	mov	es,ax
	cnop
    es	cmp	word [BOOT_OFF+510],0xAA55
	je	.ok
	stc
	jmp	short .9
.ok:
	clc
.9:
	popm	ax,bx,cx,dx,di,es
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; boot_msg -- write the ASCIIZ string at CS:SI to the serial console
;
; The CS override matters: by the time this runs DS has been set to zero
; for the boot sector, while the strings are still up in the ROM.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
boot_msg:
	pushm	ax,bx,cx,dx,si
.1:
   cs	lodsb
	or	al,al
	jz	.9
	mov	ah,1			; write character
	xor	dx,dx			; COM1
	int	0x14
	jmp	.1
.9:
	popm	ax,bx,cx,dx,si
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 18h -- no bootable device
;
; On a PC/AT this went to ROM BASIC.  There is none here, and halting
; leaves a failed boot silent and costs a power cycle to get back to
; SETUP.  Drop into the debug monitor instead: at this point the machine
; itself is healthy -- it is the disk that would not boot -- so
; everything the monitor needs is already working.
;
; Reached from INT 19h when the boot sector cannot be read or carries no
; signature, and from a boot sector in its own right: the MBR on a
; partitioned card issues INT 18h when it finds no active partition.
;
; Leaving the monitor retries the boot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	extern	debugmon_

int_18h:
	cli
	xor	ax,ax
	mov	ss,ax			; a stack of our own: whatever called
	cnop				;  us may have moved SS:SP somewhere
	mov	sp,BOOT_OFF		;  unhelpful, and a boot sector that
	sti				;  failed is not to be trusted with it
	cld

	mov	si,msg_nodisk
	call	boot_msg

	mov	ax,DGROUP		; the C code addresses through DGROUP
	mov	ds,ax
	cnop
	mov	es,ax
	cnop

	call	debugmon_

; The operator has left the monitor.  Try the disk again -- a card may
; have been changed, or SETUP used, in the meantime.
	mov	si,msg_retry
	call	boot_msg
	int	0x19

; INT 19h does not return.  If its vector were wrong we would arrive
; here rather than running off into memory.
.hang:
	hlt
	jmp	.hang

msg_try_a:
	db	ASCII_CR,ASCII_LF,"Trying drive A: ...",ASCII_CR,ASCII_LF,0
msg_try_c:
	db	"Trying drive C: ...",ASCII_CR,ASCII_LF,0
msg_booting:
	db	"Boot sector loaded, entering it ...",ASCII_CR,ASCII_LF,0
msg_noread:
	db	ASCII_CR,ASCII_LF,"INT 19h: cannot read the boot sector",ASCII_CR,ASCII_LF,0
msg_nosig:
	db	ASCII_CR,ASCII_LF,"INT 19h: no AA55h signature -- not bootable",ASCII_CR,ASCII_LF,0
msg_nodisk:
	db	ASCII_CR,ASCII_LF
	db	"INT 18h: no bootable device.",ASCII_CR,ASCII_LF
	db	"Dropping into the debug monitor -- EXIT retries the boot."
	db	ASCII_CR,ASCII_LF,0
msg_retry:
	db	ASCII_CR,ASCII_LF,"Retrying the boot ...",ASCII_CR,ASCII_LF,0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; reboot -- restart the board through the ROM's own reset entry
;
;	void reboot(void);
;
; Does not return.
;
; FFFF:0000 is where the processor begins after a reset and where
; 'bootstrap' in boot.asm sits: a five-byte far jump to F000:0000.  Going
; through it rather than straight to F000:0000 means a warm start takes
; exactly the path a cold one does, including anything that ever gets added
; to that stub.
;
; This is not a hardware reset -- the peripherals keep whatever state they
; are in -- but start.asm is written to survive being re-entered.  The
; expanded I/O unlock opens with a read of REMAPCFGH precisely to put that
; state machine back to a known state from wherever it was, and every port
; the BIOS depends on is written from wtab1/btab1 rather than assumed.  What
; it does not do is reset the IDE drive, so the first thing POST does to the
; card is the soft reset in hd_reset(), which is what that is for.
;
; SETUP is the caller: it used to print "Reboot required!" and then call
; exit(15), which lands in exit_ and powers the board down.  Telling someone
; a reboot is required and then making the machine unresponsive is the
; wrong pair of actions, and it is the reason this exists.
;
; The console is drained first.  The last line of output is still sitting
; in the UART when the chip selects are reprogrammed, and without the wait
; the user sees a truncated message and reads it as a crash.  The port comes
; from bda.serial_dev[0] rather than a constant, since the console may be
; the on-chip SIO0 at 3F8h or the MF/PIC at 448h.
;
; DX has to be loaded before the jump, and this is the whole reason the
; first version of this routine did not work.  The very first thing POST
; does is 'cmp dx,DEVICE_ID' -- DX carries the 386EX component identifier
; out of a hardware reset, and start.asm checks it before anything else.
; Arriving without it fails that test and lands in error_halt, which is a
; cli/hlt loop: the board simply stops, with no output to say why.  A
; software restart has to present the register state a reset would have.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	reboot_
reboot_:
	cli

	get_bda	DS

; Tell POST this is a warm start, so it can skip the memory march.  The
; test of segment 0 during POST zeroes the BDA, which is what puts this
; back to zero again -- the next start after this one is a cold one unless
; something asks otherwise.
	mov	word [reset_flag],WARM_BOOT

	mov	dx,[serial_dev]		; console base, 0 if none was installed
	or	dx,dx
	jz	.2

	add	dx,LSR0-TBR0		; the line status register
	mov	cx,0			; 65536 reads is far longer than a
					;  character takes at any rate we use
.1:
	in	al,dx
	test	al,LSR_TE		; transmitter completely empty?
	jnz	.2
	loop	.1
.2:
	mov	dx,DEVICE_ID		; what a hardware reset would have left
	jmp	0xFFFF:0x0000		; the reset entry, into boot.asm
