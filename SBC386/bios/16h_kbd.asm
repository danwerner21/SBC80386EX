;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 16h_kbd.asm -- INT 16h keyboard services over the serial console,
;                fed by the SIO0 receive interrupt
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
%include "i386EX.inc"
%include "macro.inc"
%include "stack.inc"
%define XXX
%include "bda.inc"
%undef XXX

	global	int_16h
	global	int_irq4
	global	kbd_init_

segment	_TEXT
ASCII_BEL	equ 	0X08

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

	mov	dx,IER0			; receive data available
	mov	al,0x01
	out	dx,al

	popm	ax,dx,ds

	mov	ax,4			; IRQ4 -- SIO0 receive
	extern	unmask_interrupt_
	call	unmask_interrupt_
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

	call	kbd_stuff
	jmp	.1
.9:
	mov	al,NS_EOI
	out	OCW2M_AT,al

	popm	ax,bx,cx,dx,si,di,ds
	iret


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
