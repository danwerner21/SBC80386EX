;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 16h_kbd.asm -- INT 16h keyboard services, fed by two interrupts:
;                the SIO0 receive (IRQ4) for the serial console, and
;                the 8242 on the VGA3 board (IRQ1) for a PS/2 keyboard.
;                Both feed the one ring buffer at 40:1E; INT 16h does
;                not know or care which a key came from.
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
; Receive is interrupt-driven, and that is not an optimisation.  INT 14h
; is polled; if INT 16h polled as well, every key struck while DOS was
; producing output would be lost, because nothing would be looking at
; the UART during the write.  The ISR fills the ring buffer the PC BIOS
; has always kept at 40:1E, and INT 16h only ever reads from that.
;
; SIO0 receive lands on IRQ4 -- measured with IRQFIND in the monitor,
; and the same line a PC/AT gives COM1.  With ICW2M = 08h that is
; INT 0Ch, which is where int_irq4 sits.
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "macro.inc"
%include "stack.inc"
%define XXX
%include "bda.inc"
%undef XXX

	global	int_16h
	global	int_irq4
	global	int_irq1
	global	kbd_init_
	global	vt_tick

	extern	reboot_			; 19h_boot.asm -- restarts the board

segment	_TEXT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The console reset sequence -- this machine's Ctrl-Alt-Del
;
; A serial console has no Ctrl and no Alt to press: it delivers characters,
; not key events, which is why kbd_flag never holds anything.  Nothing
; requires the sequence to be that particular one, though, so the trigger is
; a character unlikely to arrive by accident, three times in a row.
;
; 1Eh is Ctrl-^.  It was picked over the more obvious Ctrl-] (1Dh) because
; that is the telnet escape and would be eaten by the terminal program
; before it ever reached the board, and over Ctrl-\ (1Ch) because that is
; SIGQUIT to a Unix terminal.  Nothing in common use binds Ctrl-^.
;
; The count lives in alt_input, which on a PC accumulates Alt+numpad digits
; and here has nothing to do: the serial console has no Alt and no numpad.
; The PS/2 keyboard, which has both, has a real Ctrl-Alt-Del in kbd_scan1
; and does not use this field.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESET_KEY	equ	0x1E		; Ctrl-^
RESET_COUNT	equ	3		; how many in a row
ASCII_BEL	equ 	0X08
VT_TIMEOUT	equ	2		; ticks: 55 to 110 ms for the rest of a sequence

NS_EOI		equ	0x20		; non-specific end of interrupt
KBD_START	equ	0x1E		; kbd_buffer, at 40:1E as on a PC
KBD_END		equ	0x3E		; one past its last word


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_init -- set the ring buffer up and turn the receive interrupt on
;
;	void kbd_init(void);
;
; Called from POST.  Until this runs the buffer pointers are zero, which
; would make the buffer look like a 16-word ring based at 40:0000 -- on
; top of the serial device table.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbd_init_:
	pushm	ax,dx,ds

	get_bda	DS
	mov	word [buffer_start],KBD_START
	mov	word [buffer_end],KBD_END
	mov	word [buffer_head],KBD_START
	mov	word [buffer_tail],KBD_START
	mov	byte [kbd_flag],0
	mov	byte [kbd_flag1],0
	mov	byte [alt_input],0	; the console reset sequence counter
	mov	byte [vt_state],0	; no escape sequence part-read
	mov	byte [kbd_flag2],0
	mov	byte [kbd_flag3],0	; no scan code prefix outstanding

	mov	dx,IER0			; receive data available
	mov	al,0x01
	out	dx,al

	popm	ax,dx,ds

	mov	ax,4			; IRQ4 -- SIO0 receive
	extern	unmask_interrupt_
	call	unmask_interrupt_

	call	kbc_init		; and the PS/2 keyboard, if the board is in
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int_irq4 -- the SIO0 receive interrupt
;
; Drains the UART into the ring buffer.  The loop matters: at 9600 baud
; with interrupts occasionally masked elsewhere, more than one character
; can be waiting by the time this runs, and leaving one behind would
; leave the interrupt asserted with nothing to clear it.
;
; A full buffer drops the character and beeps, which is what a PC does.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_irq4:
	pushm	ax,bx,cx,dx,si,di,ds

	get_bda	DS
	cld
.1:
	mov	dx,LSR0
	in	al,dx
	test	al,0x01			; anything in the receiver?
	jz	.9

	mov	dx,RBR0
	in	al,dx
	and	al,0x7F			; the console is 7-bit clean

; Watch for the reset sequence before the character goes anywhere.  The
; matching characters are eaten rather than delivered: this is an escape
; out of the running system, not data, and a partial sequence reaching DOS
; would be worse than losing it.
	cmp	al,RESET_KEY
	je	.rkey
	mov	byte [alt_input],0	; anything else breaks the run
	jmp	short .stuff
.rkey:
	inc	byte [alt_input]
	cmp	byte [alt_input],RESET_COUNT
	jb	.1			; not there yet; eat it and carry on
	jmp	reboot_			; does not return
.stuff:
	call	vt_in			; an escape sequence, or a character?
	jc	.1			; consumed; nothing to deliver yet
	call	kbd_stuff
	jmp	.1
.9:
	mov	al,NS_EOI
	out	OCW2M_AT,al

	popm	ax,bx,cx,dx,si,di,ds
	iret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vt_in -- one received character through the VT100 escape translator
;
;	Enter with AL, DS the BDA.
;	Exit with CF set if the character was part of a sequence and there
;	is nothing to deliver; CF clear if AL should be stuffed as itself.
;	A recognised sequence is stuffed here, as a scan code with no ASCII,
;	and returns CF set.
;
; A terminal sends the keys a PC has as scan codes -- arrows, Home, the
; function keys -- as escape sequences, two to five characters, arriving
; one interrupt apart.  So this is a state machine across interrupts,
; with the state in the BDA:
;
;	1  ESC seen.  " [ " goes to 2, " O " to 3, anything else means the
;	   ESC was a keystroke of its own and both are delivered.
;	2  CSI.  Digits accumulate; a letter or " ~ " ends it.
;	3  SS3.  One letter ends it -- what a VT100 sends for F1 to F4 and,
;	   in application mode, for the arrows.
;
; THE LONE ESCAPE is the hard case and the reason for vt_timer.  A user
; pressing Escape sends exactly the character that opens every sequence,
; and nothing distinguishes them but what does or does not follow.  So a
; lone ESC is held, and vt_tick -- called from the timer -- delivers it
; when nothing has followed for two ticks.  Without that, Escape in an
; editor would not arrive until the next keystroke, which vi would find
; unusable.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vt_in:
	cmp	byte [vt_state],0
	jne	.in_seq
	cmp	al,ASCII_ESC
	jne	.pass
	mov	byte [vt_state],1
	mov	byte [vt_timer],VT_TIMEOUT
	stc
	ret
.pass:
	clc
	ret

.in_seq:
	cmp	byte [vt_state],2
	je	.csi
	ja	.ss3

; state 1: ESC, and now the character that says what it was
	cmp	al,'['
	je	.to_csi
	cmp	al,'O'
	je	.to_ss3
	mov	byte [vt_state],0	; a keystroke of its own: ESC, then this
	push	ax
	mov	al,ASCII_ESC
	call	kbd_stuff
	pop	ax
	clc
	ret
.to_csi:
	mov	byte [vt_state],2
	mov	byte [vt_digit],0
	mov	byte [vt_timer],VT_TIMEOUT
	stc
	ret
.to_ss3:
	mov	byte [vt_state],3
	mov	byte [vt_timer],VT_TIMEOUT
	stc
	ret

; state 2: ESC [ .  Digits accumulate; ~ or a letter ends it.
.csi:
	cmp	al,'0'
	jb	.csi_end
	cmp	al,'9'
	ja	.csi_end
	pushm	ax,bx
	mov	bl,al
	mov	al,[vt_digit]
	mov	ah,10
	mul	ah
	sub	bl,'0'
	add	al,bl
	mov	[vt_digit],al
	popm	ax,bx
	mov	byte [vt_timer],VT_TIMEOUT
	stc
	ret
.csi_end:
	cmp	al,'~'
	je	.tilde
	mov	bx,vt_csi		; a letter: A..D, H, F
	jmp	short .letter
.tilde:
	push	ax
	mov	al,[vt_digit]
	mov	bx,vt_tilde
	call	vt_lookup
	pop	ax
	jmp	short .finish

; state 3: ESC O .  One letter and it is over.
.ss3:
	mov	bx,vt_ss3
.letter:
	push	ax
	call	vt_lookup
	pop	ax
.finish:
	mov	byte [vt_state],0
	stc
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vt_lookup -- AL against the pairs at CS:BX; stuff the scan code if it
; is there.  A sequence this BIOS does not know is dropped, which is
; better than delivering a letter the user did not type.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vt_lookup:
	pushm	ax,bx
.1:
   cs	cmp	byte [bx],0
	je	.9			; end of table: unknown, dropped
   cs	cmp	al,[bx]
	je	.hit
	add	bx,2
	jmp	short .1
.hit:
   cs	mov	ah,[bx+1]		; the scan code
	xor	al,al			; no ASCII, as a PC gives these keys
	call	kbd_stuff_ax
.9:
	popm	ax,bx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vt_tick -- called from the timer, 18.2 times a second
;
; Delivers a lone Escape once nothing has followed it, and abandons a
; sequence that stopped halfway.  DS is the BDA; everything preserved.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vt_tick:
	cmp	byte [vt_state],0
	je	.9
	dec	byte [vt_timer]
	jnz	.9
	pushm	ax,bx,cx,dx
	cmp	byte [vt_state],1
	jne	.drop			; a truncated sequence: let it go
	mov	al,ASCII_ESC		; a keystroke after all
	call	kbd_stuff
.drop:
	mov	byte [vt_state],0
	popm	ax,bx,cx,dx
.9:
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; What a terminal sends, and the scan code a PC program expects back.
; Pairs, zero-terminated.  The scan codes are the ones INT 16h returns
; with a zero ASCII byte, which is how every DOS program recognises a
; key that has no character.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	align	2
vt_csi:					; after ESC [
	db	'A',0x48			; up
	db	'B',0x50			; down
	db	'C',0x4D			; right
	db	'D',0x4B			; left
	db	'H',0x47			; home
	db	'F',0x4F			; end
	db	0

vt_ss3:					; after ESC O -- application mode, and F1..F4
	db	'A',0x48,'B',0x50,'C',0x4D,'D',0x4B
	db	'H',0x47,'F',0x4F
	db	'P',0x3B,'Q',0x3C,'R',0x3D,'S',0x3E
	db	0

vt_tilde:				; the number in ESC [ n ~
	db	1,0x47,  2,0x52,  3,0x53,  4,0x4F	; home ins del end
	db	5,0x49,  6,0x51				; page up, page down
	db	11,0x3B, 12,0x3C, 13,0x3D, 14,0x3E, 15,0x3F	; F1..F5
	db	17,0x40, 18,0x41, 19,0x42, 20,0x43, 21,0x44	; F6..F10
	db	23,0x85, 24,0x86			; F11, F12
	db	0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_stuff -- put the character in AL into the ring buffer
;
;  DS is the BDA.  AX, BX, CX are destroyed.
;
; The stored word is the PC convention: scan code in the high byte,
; ASCII in the low.  DOS reads the ASCII; a few programs check the scan
; code, which is why it is synthesised rather than left zero.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbd_stuff:
	pushm	ax,bx,cx,dx

; DEL from a terminal means backspace to DOS
	cmp	al,0x7F
	jne	.1
	mov	al,ASCII_BS
.1:
	movzx	bx,al
   cs	mov	ah,[bx+kbd_scan]	; synthesise the scan code
	mov	cx,ax			; CX is the word to store
kbd_stuff_word:				; entered from kbd_stuff_ax with CX made

	mov	bx,[buffer_tail]
	mov	ax,bx
	add	ax,2
	cmp	ax,KBD_END
	jb	.2
	mov	ax,KBD_START		; wrapped
.2:
	cmp	ax,[buffer_head]
	je	.full			; tail would meet head: no room

	mov	[bx],cx			; DS is 0040, BX is the offset
	mov	[buffer_tail],ax
	jmp	.9
.full:
	mov	al,ASCII_BEL		; the buffer is full -- complain
	mov	ah,1
	xor	dx,dx
	int	0x14
.9:
	popm	ax,bx,cx,dx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 16h -- keyboard services
;
;    Function		Usage
;    ========		=====
;	00	read a key, waiting for one
;	01	report whether a key is waiting, without taking it
;	02	read the shift flags
;	10h	as 00, extended
;	11h	as 01, extended
;	12h	as 02, extended
;
; 10h/11h/12h are the 101-key forms.  On a serial console they have
; nothing extra to report, so they share the code.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_16h:
	sti
	pushm	all,ds,es
	mov	bp,sp
	cld
	get_bda	DS

	mov	al,ah
	and	al,0x0F			; 10h/11h/12h behave as 00/01/02
	cmp	al,2
	ja	k_bad

	or	al,al
	jz	k_read
	dec	al
	jz	k_peek

; function 02 -- shift flags
	mov	al,[kbd_flag]
	mov	[bp+offset_ax],al
	jmp	k_done

k_bad:
	mov	word [bp+offset_ax],0
k_done:
	popm	all,ds,es
	iret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function 00 -- read a key, waiting until there is one
;
; HLT rather than a spin: the tick and the receive interrupt both wake
; it, and it keeps the bus quiet while DOS is idle at the prompt.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
k_read:
	sti
.1:
	mov	bx,[buffer_head]
	cmp	bx,[buffer_tail]
	jne	.2
	hlt				; nothing yet; wait for an interrupt
	jmp	.1
.2:
	mov	ax,[bx]			; the waiting key

	add	bx,2
	cmp	bx,KBD_END
	jb	.3
	mov	bx,KBD_START
.3:
	mov	[buffer_head],bx

	mov	[bp+offset_ax],ax
	jmp	k_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function 01 -- is a key waiting?
;
;  ZF set means the buffer is empty.  The key is left where it is.
;
; The Zero flag has to reach the caller, so this returns with RETF 2 --
; discarding the stacked flags -- rather than IRET, which would put them
; back and lose the answer.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
k_peek:
	mov	bx,[buffer_head]
	cmp	bx,[buffer_tail]
	je	.empty

	mov	ax,[bx]
	mov	[bp+offset_ax],ax

	popm	all,ds,es
	or	sp,sp			; SP is never zero, so ZF clear:
	retf	2			;  a key is waiting
.empty:
	popm	all,ds,es
	cmp	sp,sp			; ZF set: nothing waiting
	retf	2


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_scan -- ASCII to the scan code of the key that would produce it
;
; A serial console delivers characters, not key events, so the scan code
; has to be invented.  Most software reads only the ASCII byte, but
; enough of it looks at the scan code -- for Enter, Backspace and Escape
; especially -- that returning zero causes trouble.
;
; The value is the set-1 make code of the key bearing that character;
; shifted symbols carry the code of the unshifted key, which is what a
; real keyboard would have reported.
;
; 00h..1Fh are the control codes: Ctrl+letter carries the letter's code,
; with Backspace, Tab, Enter and Escape given their own keys.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	align	2
kbd_scan:
;	  ^@   ^A   ^B   ^C   ^D   ^E   ^F   ^G
	db 0x03,0x1E,0x30,0x2E,0x20,0x12,0x21,0x22
;	  BS   TAB  ^J   ^K   ^L   CR   ^N   ^O
	db 0x0E,0x0F,0x24,0x25,0x26,0x1C,0x31,0x18
;	  ^P   ^Q   ^R   ^S   ^T   ^U   ^V   ^W
	db 0x19,0x10,0x13,0x1F,0x14,0x16,0x2F,0x11
;	  ^X   ^Y   ^Z   ESC  ^\   ^]   ^^   ^_
	db 0x2D,0x15,0x2C,0x01,0x2B,0x1B,0x07,0x0C
;	  SP   !    "    #    $    %    &    '
	db 0x39,0x02,0x28,0x04,0x05,0x06,0x08,0x28
;	  (    )    *    +    ,    -    .    /
	db 0x0A,0x0B,0x09,0x0D,0x33,0x0C,0x34,0x35
;	  0    1    2    3    4    5    6    7
	db 0x0B,0x02,0x03,0x04,0x05,0x06,0x07,0x08
;	  8    9    :    ;    <    =    >    ?
	db 0x09,0x0A,0x27,0x27,0x33,0x0D,0x34,0x35
;	  @    A    B    C    D    E    F    G
	db 0x03,0x1E,0x30,0x2E,0x20,0x12,0x21,0x22
;	  H    I    J    K    L    M    N    O
	db 0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18
;	  P    Q    R    S    T    U    V    W
	db 0x19,0x10,0x13,0x1F,0x14,0x16,0x2F,0x11
;	  X    Y    Z    [    \    ]    ^    _
	db 0x2D,0x15,0x2C,0x1A,0x2B,0x1B,0x07,0x0C
;	  `    a    b    c    d    e    f    g
	db 0x29,0x1E,0x30,0x2E,0x20,0x12,0x21,0x22
;	  h    i    j    k    l    m    n    o
	db 0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18
;	  p    q    r    s    t    u    v    w
	db 0x19,0x10,0x13,0x1F,0x14,0x16,0x2F,0x11
;	  x    y    z    {    |    }    ~    DEL
	db 0x2D,0x15,0x2C,0x1A,0x2B,0x1B,0x29,0x53
len_kbd_scan	equ	$ - kbd_scan


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The PS/2 keyboard on the ECB VGA3 board
;
; The board carries an Intel 8242 -- an 8042 with the PC/AT keyboard
; firmware in it -- at the first two ports of its I/O block, which P3 on
; the board puts at 4E0h.  That makes this the port 60h/64h protocol at a
; different address and nothing else: translation is on, so scan codes
; arrive in set 1 exactly as INT 09h on a PC receives them.
;
; The interrupt goes out on the bus line K4 selects; both positions reach
; the 386EX INT0 pin, which is master IR1, which with ICW2 = 08h is INT 09h.
; K1 puts the video interrupt on INT5 (slave IR1, INT 71h) so the two never
; share a line; nothing enables it.
;
; Established with V3KBD in the monitor before a line of this was written.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KBC_DATA	equ	0x4E0		; 8242 data, read and write
KBC_STAT	equ	0x4E1		; status on read, command on write

KBC_OBF		equ	0x01		; a byte is waiting at KBC_DATA
KBC_IBF		equ	0x02		; the last byte written is not yet taken

KBC_SELFTEST	equ	0xAA		; resets the controller; replies 55
KBC_WRCMD	equ	0x60		; write the command byte
KBC_ENABLE	equ	0xAE		; keyboard interface on
KB_RESET	equ	0xFF		; to the keyboard; replies FA, then AA
KB_SETLED	equ	0xED		; then a lamp mask; each replies FA
KBC_CMDBYTE	equ	0x41		; IRQ on, set-2-to-1 translation on,
				; interface enabled, no system flag

; kbd_flag, 40:17, PC layout
KF_RSHIFT	equ	0x01
KF_LSHIFT	equ	0x02
KF_CTRL		equ	0x04
KF_ALT		equ	0x08
KF_SCROLL	equ	0x10
KF_NUM		equ	0x20
KF_CAPS		equ	0x40
KF_INS		equ	0x80

; kbd_flag3, 40:96, PC layout: the prefix state between interrupts
KF3_E1		equ	0x01		; last code was E1 (Pause)
KF3_E0		equ	0x02		; last code was E0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbc_init -- bring the controller up, if it is there
;
; Called from kbd_init.  The board may be absent, in which case the port
; floats and reads FF; that case leaves quietly and IR1 stays masked.  The
; timer is not running yet when this is called, so waits are counted, not
; timed: 64K reads of a port at seven wait states is some 30 ms, which is
; more than an 8042 ever needs and short enough not to notice at POST.
;
; The sequence is the PC/AT one, in full, because a shorter one did not
; work: drain, write the command byte and enable left the keyboard silent
; until the monitor's V3KBD -- self-test, enable, keyboard reset -- was
; run by hand.  The self-test resets the controller; the keyboard reset
; resets the keyboard.  Its replies, FA then AA, take up to half a second
; and are not waited for: IR1 is unmasked before they arrive and the ISR
; takes them as the break codes of 7A and 2A, which mean nothing.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbc_init:
	pushm	ax,cx,dx

	mov	dx,KBC_STAT
	in	al,dx
	cmp	al,0xFF
	je	.9			; nothing there

; Whatever the controller has been holding since power-up goes.
	mov	cx,16
.drain:
	in	al,dx
	test	al,KBC_OBF
	jz	.drained
	mov	dx,KBC_DATA
	in	al,dx
	mov	dx,KBC_STAT
	loop	.drain
.drained:
	mov	al,KBC_SELFTEST		; reset the controller ...
	call	kbc_put_cmd
	call	kbc_take		; ... and take its 55, or give up
	mov	al,KBC_WRCMD
	call	kbc_put_cmd
	mov	al,KBC_CMDBYTE
	call	kbc_put_data
	mov	al,KBC_ENABLE
	call	kbc_put_cmd
	mov	al,KB_RESET		; and reset the keyboard; see above
	call	kbc_put_data

	popm	ax,cx,dx
	mov	ax,1			; IRQ1 -- the keyboard
	call	unmask_interrupt_
	ret
.9:
	popm	ax,cx,dx
	ret

; Wait, bounded, for the controller to offer a byte, and take it.  The
; value is not wanted; the point is that the controller has finished
; what it was asked before it is asked the next thing.
kbc_take:
	pushm	ax,cx,dx
	mov	dx,KBC_STAT
	xor	cx,cx
.w:	in	al,dx
	test	al,KBC_OBF
	loopz	.w
	jz	.9			; gave up
	mov	dx,KBC_DATA
	in	al,dx
.9:	popm	ax,cx,dx
	ret

; Write AL to the controller (command) or to the keyboard (data), once
; the input buffer is free.  Gives up rather than hangs.
kbc_put_cmd:
	push	dx
	mov	dx,KBC_STAT
	jmp	short kbc_put
kbc_put_data:
	push	dx
	mov	dx,KBC_DATA
kbc_put:
	pushm	ax,cx
	mov	cx,0			; 64K tries
.wait:
	push	dx
	mov	dx,KBC_STAT
	in	al,dx
	pop	dx
	test	al,KBC_IBF
	loopnz	.wait
	popm	ax,cx
	out	dx,al
	pop	dx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; int_irq1 -- INT 09h, a scan code from the 8242
;
; One byte per interrupt: the 8042 holds the keyboard off until the byte
; is read, then lets the next one through, which raises the line again.
; The line is edge-triggered, so the byte is taken before EOI and nothing
; is left to re-arm.
;
; An interrupt with no byte waiting is spurious and is simply
; acknowledged.  The VGA3's retrace interrupt is not used (vga3.asm
; reads the CRTC's blanking bit instead), so K1 belongs on 2-3, off
; this line.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_irq1:
	pushm	ax,bx,cx,dx,ds

	mov	dx,KBC_STAT
	in	al,dx
	test	al,KBC_OBF
	jz	.eoi			; no byte: spurious, acknowledge only
	mov	dx,KBC_DATA
	in	al,dx

	get_bda	DS
	call	kbd_scan1
.eoi:
	mov	al,NS_EOI
	out	OCW2M_AT,al

	popm	ax,bx,cx,dx,ds
	iret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_leds -- make the lamps agree with kbd_flag
;
; DS is the BDA.  Everything preserved.  Called after every make code:
; the comparison below is the whole cost unless a lock key has actually
; changed, so it does not matter that most keys are not lock keys.
;
; kbd_flag2 holds what the lamps were last set to, in the keyboard's own
; bit order -- scroll, num, caps -- which is kbd_flag's lock bits shifted
; down four.  That the two layouts line up is a convenience of the PC
; definitions, not a coincidence worth relying on elsewhere.
;
; ED, then the mask; the keyboard acknowledges each with FA.  Both
; acknowledgements are taken here rather than left for the interrupt,
; which would read them as break codes of 7A -- harmless in themselves,
; but the next real key would then arrive one interrupt behind.
;
; This runs inside INT 09h with interrupts off and blocks for two
; keyboard frames, about 2 ms.  That is well under a timer tick, and it
; is only paid when a lock key is struck.  If the keyboard stops
; answering mid-sequence the bounded waits in kbc_take end it.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbd_leds:
	pushm	ax,cx,dx
	mov	al,[kbd_flag]
	shr	al,4
	and	al,7			; scroll, num, caps
	cmp	al,[kbd_flag2]
	je	.9			; the lamps already say this
	mov	[kbd_flag2],al
	push	ax
	mov	al,KB_SETLED
	call	kbc_put_data
	call	kbc_take		; the FA
	pop	ax
	call	kbc_put_data		; the mask
	call	kbc_take		; and its FA
.9:
	popm	ax,cx,dx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_scan1 -- one set-1 scan code in AL, DS the BDA
;
; Shift-state keys change kbd_flag and produce nothing.  Everything else
; is looked up by the shift state in force and stored as the PC word,
; scan in AH and ASCII in AL, through kbd_stuff_ax.
;
; Prefixes: E0 marks the keys that were added to the 101-key board --
; the cursor cluster, the right Ctrl and Alt, keypad Enter and /.  It is
; remembered in kbd_flag3 across the interrupt boundary and consumed by
; the next code.  E1 opens the six-byte Pause sequence, which is thrown
; away in its entirety.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbd_scan1:
	cmp	al,0xE0
	je	.pfx_e0
	cmp	al,0xE1
	je	.pfx_e1
	test	byte [kbd_flag3],KF3_E1
	jnz	.in_pause

	mov	bl,[kbd_flag3]		; BL bit 1: this code had an E0
	and	byte [kbd_flag3],~KF3_E0

	test	al,0x80
	jnz	.release
	call	.shifter		; a shift-state key?
	jc	.done			;   yes, and it has been handled

	cmp	al,0x53			; Del
	jne	.lookup
	mov	ah,[kbd_flag]
	and	ah,KF_CTRL+KF_ALT
	cmp	ah,KF_CTRL+KF_ALT
	jne	.lookup
	jmp	reboot_			; Ctrl-Alt-Del: does not return

.lookup:
	call	kbd_lookup		; AX = the word, or CF if nothing
	jc	.done
	call	kbd_stuff_ax
.done:
	call	kbd_leds		; cheap unless a lock key just changed
	ret

.pfx_e0:
	or	byte [kbd_flag3],KF3_E0
	ret
.pfx_e1:
	or	byte [kbd_flag3],KF3_E1
	ret
.in_pause:
	cmp	al,0xC5			; the sequence ends with the break of 45
	jne	.done
	and	byte [kbd_flag3],~(KF3_E1+KF3_E0)
	ret

.release:
	and	al,0x7F
	cmp	al,0x1D
	je	.rel_ctrl
	cmp	al,0x38
	je	.rel_alt
	test	bl,KF3_E0		; E0 AA, E0 B6: the fake shifts (below)
	jnz	.done
	cmp	al,0x2A
	je	.rel_ls
	cmp	al,0x36
	je	.rel_rs
	ret				; the release of an ordinary key
.rel_ls:
	and	byte [kbd_flag],~KF_LSHIFT
	ret
.rel_rs:
	and	byte [kbd_flag],~KF_RSHIFT
	ret
.rel_ctrl:
	and	byte [kbd_flag],~KF_CTRL
	ret
.rel_alt:
	and	byte [kbd_flag],~KF_ALT
	ret

; The make of a shift-state key.  CF set if AL was one.  Caps, Num and
; Scroll toggle on make.  The LEDs are not yet driven: that wants a small
; state machine for the keyboard's acknowledgements, and belongs with the
; first thing that needs it.
;
; E0 2A and E0 36 are not shifts.  With Num Lock on, the keyboard brackets
; every cursor-cluster key in them so that a host which knows nothing of
; E0 still gets a cursor key rather than a digit.  This host does know,
; so they are swallowed, or they would flip the keypad the wrong way.
.shifter:
	cmp	al,0x2A
	je	.set_ls
	cmp	al,0x36
	je	.set_rs
	cmp	al,0x1D
	je	.set_ctrl
	cmp	al,0x38
	je	.set_alt
	cmp	al,0x3A
	je	.tog_caps
	cmp	al,0x45
	je	.tog_num
	cmp	al,0x46
	je	.tog_scroll
	clc
	ret
.set_ls:	test	bl,KF3_E0
		jnz	.fake
		or	byte [kbd_flag],KF_LSHIFT
		stc
		ret
.set_rs:	test	bl,KF3_E0
		jnz	.fake
		or	byte [kbd_flag],KF_RSHIFT
		stc
		ret
.fake:		stc			; eaten, nothing changes
		ret
.set_ctrl:	or	byte [kbd_flag],KF_CTRL
		stc
		ret
.set_alt:	or	byte [kbd_flag],KF_ALT
		stc
		ret
.tog_caps:	xor	byte [kbd_flag],KF_CAPS
		stc
		ret
.tog_num:	test	bl,KF3_E0		; E0 45 is not Num Lock
		jnz	.not_shifter
		xor	byte [kbd_flag],KF_NUM
		stc
		ret
.tog_scroll:	xor	byte [kbd_flag],KF_SCROLL
		stc
		ret
.not_shifter:	clc
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_lookup -- scan code AL, E0 flag in BL bit 1, shift state in kbd_flag
;
; Returns the PC key word in AX, or CF set for a code with no meaning.
; Three regions of the set-1 space, each with its own rule:
;
;    01..39   the typewriter keys, four tables' worth
;    3B..44   F1..F10, plus 57 and 58 for F11 and F12: no ASCII, and the
;             scan code moves by a fixed amount per shift state
;    47..53   the keypad: digits when Num Lock says so and no E0 says
;             otherwise, cursor keys with no ASCII when not
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbd_lookup:
	mov	ah,al			; AH: the scan code, kept for the word
	mov	dh,bl			; DH: the E0 flag; BL becomes an index
	mov	cl,[kbd_flag]

	cmp	al,0x39
	jbe	.typewriter
	cmp	al,0x3B
	jb	.none
	cmp	al,0x44
	jbe	.fkey
	cmp	al,0x47
	jb	.none
	cmp	al,0x53
	jbe	.keypad
	cmp	al,0x57
	je	.fkey
	cmp	al,0x58
	je	.fkey
.none:
	stc
	ret

; --- the typewriter keys ---------------------------------------------
.typewriter:
	movzx	bx,al
	dec	bx			; tables begin at scan code 01
	test	cl,KF_ALT
	jnz	.alt
	test	cl,KF_CTRL
	jnz	.ctrl
	test	cl,KF_LSHIFT+KF_RSHIFT
	jnz	.shifted
   cs	mov	al,[bx+kt_normal]
	jmp	short .caps
.shifted:
   cs	mov	al,[bx+kt_shift]
.caps:
	test	cl,KF_CAPS
	jz	.tw_done
; Caps Lock inverts shift for letters and nothing else
	cmp	al,'a'
	jb	.caps_upper
	cmp	al,'z'
	ja	.tw_done
	sub	al,'a'-'A'
	jmp	short .tw_done
.caps_upper:
	cmp	al,'A'
	jb	.tw_done
	cmp	al,'Z'
	ja	.tw_done
	add	al,'a'-'A'
.tw_done:
	clc
	ret
.ctrl:
   cs	mov	al,[bx+kt_ctrl]
	cmp	al,0xFF			; FF marks a key with no Ctrl meaning
	je	.none
	clc
	ret
.alt:
	xor	al,al			; Alt+key: no ASCII, the scan code says which
	clc
	ret

; --- the function keys -----------------------------------------------
.fkey:
	cmp	al,0x57
	jb	.f10
	sub	al,0x57-0x0A		; F11, F12 follow F10 in the numbering
.f10:
	sub	al,0x3B			; 0..11
	test	cl,KF_ALT
	jnz	.f_alt
	test	cl,KF_CTRL
	jnz	.f_ctrl
	test	cl,KF_LSHIFT+KF_RSHIFT
	jnz	.f_shift
	add	al,0x3B			; F1..F10 are 3B..44, F11 and F12 85, 86
	cmp	al,0x45
	jb	.f_out
	add	al,0x85-0x45
	jmp	short .f_out
.f_shift:
	add	al,0x54			; 54..5D, then 87, 88
	cmp	al,0x5E
	jb	.f_out
	add	al,0x87-0x5E
	jmp	short .f_out
.f_ctrl:
	add	al,0x5E			; 5E..67, then 89, 8A
	cmp	al,0x68
	jb	.f_out
	add	al,0x89-0x68
	jmp	short .f_out
.f_alt:
	add	al,0x68			; 68..71, then 8B, 8C
	cmp	al,0x72
	jb	.f_out
	add	al,0x8B-0x72
.f_out:
	mov	ah,al
	xor	al,al
	clc
	ret

; --- the keypad ---------------------------------------------------------
.keypad:
	movzx	bx,al
	sub	bx,0x47
	test	cl,KF_ALT
	jnz	.alt
	test	cl,KF_CTRL
	jnz	.kp_ctrl

; Num Lock, an E0 (the cursor cluster), or Shift: each one flips it
	test	cl,KF_NUM
	setnz	dl
	test	dh,KF3_E0
	jz	.kp1
	xor	dl,1
.kp1:
	test	cl,KF_LSHIFT+KF_RSHIFT
	jz	.kp2
	xor	dl,1
.kp2:
   cs	mov	al,[bx+kt_keypad]	; the digit, or '-' '+' regardless
	cmp	al,'-'
	je	.kp_out
	cmp	al,'+'
	je	.kp_out
	test	dl,1
	jnz	.kp_out			; digits wanted
	xor	al,al			; a cursor key: no ASCII
.kp_out:
	clc
	ret
.kp_ctrl:
   cs	mov	al,[bx+kt_kp_ctrl]
	cmp	al,0xFF
	je	.none
	mov	ah,al			; Ctrl-cursor: the scan code is the meaning
	xor	al,al
	clc
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbd_stuff_ax -- AX is the complete word: scan in AH, ASCII in AL
;
; The tail of kbd_stuff, entered when the caller already knows the scan
; code and does not want one synthesised from the ASCII.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbd_stuff_ax:
	pushm	ax,bx,cx,dx
	mov	cx,ax
	jmp	kbd_stuff_word


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Set-1 scan code to ASCII, scan codes 01 to 39.  US layout.
;
; No line here may END with a backslash -- not even a comment.  NASM
; takes that as a continuation and swallows the next line whole, which
; is how the a..\ row once vanished and shifted every key after it by
; fourteen places.  The listing shows it as a line number that skips.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	align	2
kt_normal:
;	  Esc  1    2    3    4    5    6    7    8    9    0    -    =    BS   Tab
	db 0x1B,'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0x08,0x09
;	  q    w    e    r    t    y    u    i    o    p    [    ]    Ent  Ctl
	db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0x0D,0x00
;	  a    s    d    f    g    h    j    k    l    ;    '    `    LSh  backslash
	db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 0x27,'`', 0x00,'\'
;	  z    x    c    v    b    n    m    ,    .    /    RSh  *    Alt  Sp
	db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0x00,'*', 0x00,' '

kt_shift:
	db 0x1B,'!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0x08,0x00
	db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0x0D,0x00
	db 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0x00,'|'
	db 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0x00,'*', 0x00,' '

; FF: no Ctrl meaning.  Ctrl-BS is DEL, Ctrl-Enter is LF, Ctrl-[ ESC,
; Ctrl-\ FS, Ctrl-] GS, Ctrl-- US, Ctrl-6 RS, as on a PC.
kt_ctrl:
	db 0x1B,0xFF,0xFF,0xFF,0xFF,0xFF,0x1E,0xFF,0xFF,0xFF,0xFF,0x1F,0xFF,0x7F,0xFF
	db 0x11,0x17,0x05,0x12,0x14,0x19,0x15,0x09,0x0F,0x10,0x1B,0x1D,0x0A,0xFF
	db 0x01,0x13,0x04,0x06,0x07,0x08,0x0A,0x0B,0x0C,0xFF,0xFF,0xFF,0xFF,0x1C
	db 0x1A,0x18,0x03,0x16,0x02,0x0E,0x0D,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,' '

; The keypad, scan codes 47 to 53, as digits
kt_keypad:
;	  7    8    9    -    4    5    6    +    1    2    3    0    .
	db '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '0', '.'

; The keypad with Ctrl: the extended scan codes a PC returns, FF for none
kt_kp_ctrl:
;	  Home Up   PgUp -    Left 5    Rght +    End  Down PgDn Ins  Del
	db 0x77,0xFF,0x84,0xFF,0x73,0xFF,0x74,0xFF,0x75,0xFF,0x76,0xFF,0xFF
