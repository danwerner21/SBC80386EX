;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vga3.asm -- the ECB VGA3 board: 80x25 text on an HD6445, memory mapped
;             at B8000, written wherever the beam is not
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
; THE BOARD
;
; Eight I/O ports at 4E0h (P3 jumpered E0h): an 8242 keyboard controller
; at +0/+1, the HD6445 CRTC at +2/+3, the CFG register at +4, and at
; +5..+7 a pair of address registers and a data port that reach the 32K
; of video RAM a byte at a time.  CFG bit 7 also puts that 32K on the
; ECB memory bus, at B0000 (clear) or B8000 (set).  The SBC's CS3 maps
; B0000..BFFFF to the bus with DRAM suppressed there, 8-bit, five wait
; states, READY generated internally -- so the RAM is simply memory at
; B800:0000, one bus cycle a byte, and a program that writes the screen
; directly, as DOS programs do, is writing the board.
;
; THE RAM IS NOT ARBITRATED.  A CPU access while the CRTC is fetching
; corrupts that fetch and the screen sparkles -- by either path; both
; were measured.  The CPU's own read or write is not harmed: V3RDCHK
; read the live screen 32,000 times without an error.  Confining writes
; to vertical blanking was tried and is far too slow: blanking is 11%
; of the frame, and a scroll took four frames.
;
; THE DESIGN: WRITE DURING BLANKING
;
; Bit 1 of HD6445 register 31, read through the data port, is vertical
; blanking -- the SBC-188 BIOS scrolled on it.  Every write to the board
; waits for it, then goes.  Blanking is 1553 usec of the 14271 usec frame
; (measured with V3BEAM), which is about thirteen row copies, so a
; whole-screen scroll takes two frames, near 28 ms.  Single characters
; wait at most one frame and usually far less.
;
; Two cleverer schemes were built and both failed, which is why this one
; is deliberately dull.  Queueing the work for a retrace interrupt was
; four frames a scroll and unusably slow.  Computing the beam position
; from a blanking edge and the 1 mhz counter -- write to any row the beam
; is not on -- was fast but flickered, and went on flickering after the
; counter-wrap bug in it was fixed, for a reason never established.  The
; CRTC status bit needs no model of the hardware to be right.
;
; The board's retrace interrupt is not used either: the status bit is
; exact and free of interrupt latency, and it leaves INT0 to the
; keyboard.  K1 may sit in either position.  Should R31 never change --
; no CRTC clock, say -- writes go ahead blind rather than hang.
;
; Layout of the 32K: screen at 0000, 4000 bytes, character then
; attribute; font in the last 4K page, which CFG selects.  The CRTC
; start address stays at 0 so that B800:0000 is the top-left cell.
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "macro.inc"
%define XXX
%include "bda.inc"
%undef XXX

	global	vga3_init_		; C: int vga3_init(void), 1 if present
	global	vga3_putc		; AL at the cursor, character only
	global	vga3_cells		; AL,BL at the cursor CX times; DL=1 attr too
	global	vga3_getcell		; -> AX, the cell under the cursor
	global	vga3_cursor		; AH row, AL column -> the CRTC
	global	vga3_shape		; CX as INT 10h fn 01
	global	vga3_scroll_up		; as INT 10h fn 06
	global	vga3_scroll_dn		; as INT 10h fn 07
	global	vga3_clear		; the screen to spaces, cursor home

segment	_TEXT

V3_PORT		equ	0x4E0		; P3 jumpered to E0h
V3_CRTC_A	equ	V3_PORT+2	; HD6445 address register
V3_CRTC_D	equ	V3_PORT+3	; HD6445 data register
V3_CFG		equ	V3_PORT+4	; write only
V3_ADR_HI	equ	V3_PORT+5	; write only
V3_ADR_LO	equ	V3_PORT+6	; write only
V3_DATA		equ	V3_PORT+7

V3_SEG		equ	0xB800		; the 32K, memory mapped
V3_FONT		equ	0x7000		; page 7, as CFG below says
V3_COLS		equ	80
V3_ROWS		equ	25
V3_CELLS	equ	V3_COLS*V3_ROWS
V3_BLANK	equ	0x0720		; attribute 07, a space

; CFG: bit 7 memory window at B8000 (clear: B0000); 6:4 font page 7;
; bit 3 one font; bit 2 video on; bit 0 nine-dot characters.
V3_CFG_QUIET	equ	0xF0		; mapped, video off
V3_CFG_ON	equ	0xF4

R31		equ	31		; HD6445: bit 1 = vertical blanking
ROW_BLANKING	equ	25		; "row" the beam is on during blanking


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 80x25, nine-dot characters, 28.322mhz dots: VGA's 720x400 text timing.
;   80 shown + 2 + 12 + 6 = 100 char clocks = 900 dots = 31.469khz
;   400 lines + 12 + 2 + 35 = 449 lines = 70.08hz
;
; These are the parameters the SBC-188 BIOS (John Coffman, 2012) drove
; this same board with.  Vsync belongs on line 412, which is not a row
; boundary; the HD6445 can do it anyway -- R7 puts it at row 25, line
; 400, and R27, enabled by bit 3 of R30, moves it 12 lines on.  So the
; frame is VGA's 449 lines exactly, not the 453 a plain 6845 forced.
; R2 is the arithmetic 82: the 68 that once "centred" the picture was
; correcting for a monitor that had taken the signal for 640x350, which
; is a sync-polarity matter for the jumpers, not for this table.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	align	2
v3_mode:
	db	0,  99,   1,  80,   2,  82,   3,  0x2C
	db	4,  27,   5,  1,    6,  25,   7,  25
	db	8,  0,    9,  15,   10, 0x6D, 11, 14	; cursor lines 13-14, blink 1/32
	db	12, 0,    13, 0,    14, 0,    15, 0
	db	30, 0,    31, 0,    32, 0		; control 1..3 known
	db	27, 12,   30, 0x08			; vsync 12 lines after row 25
v3_mode_len	equ	$ - v3_mode


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The register path: the CRTC, and the RAM for the presence test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; g_crtc -- AH to CRTC register AL.  AL is destroyed.
g_crtc:
	push	dx
	mov	dx,V3_CRTC_A
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
	pop	dx
	ret

; g_rd / g_wr -- AL from / to RAM byte BX through the address registers
g_seek:
	pushm	ax,dx
	mov	dx,V3_ADR_HI
	mov	al,bh
	out	dx,al
	inc	dx
	mov	al,bl
	out	dx,al
	popm	ax,dx
	ret
g_rd:
	call	g_seek
	push	dx
	mov	dx,V3_DATA
	in	al,dx
	pop	dx
	ret
g_wr:
	call	g_seek
	push	dx
	mov	dx,V3_DATA
	out	dx,al
	pop	dx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Addressing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; g_cell -- BX = byte offset of the cell at row AH, column AL.  Needs
; no segment; everything else preserved.
g_cell:
	pushm	ax,dx
	mov	dl,al
	mov	al,ah
	mov	ah,V3_COLS
	mul	ah
	xor	dh,dh
	add	ax,dx
	add	ax,ax
	mov	bx,ax
	popm	ax,dx
	ret

; g_bda_cursor -- AH = row, AL = column of the active page's cursor.
; DS is the BDA.
g_bda_cursor:
	push	bx
	mov	bl,[vid_active_page]
	and	bl,7
	xor	bh,bh
	add	bx,bx
	mov	ax,[bx+vid_cursor]
	pop	bx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The beam.  DS is the BDA.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; beam_avoid -- wait for vertical blanking, then return.  The arguments
; the callers pass -- the rows they are about to touch -- are ignored:
; during blanking every row is safe.  They are kept because the callers
; read better for having said what they touch, and because a scheme that
; uses them may yet be made to work.
;
; Bounded at 64K reads, about two frames.  If the bit never sets there is
; no CRTC clock and nothing to synchronise with, so the write proceeds.
; Everything preserved.
beam_avoid:
	pushm	ax,cx,dx
	mov	dx,V3_CRTC_A
	mov	al,R31
	out	dx,al
	inc	dx			; DX = the data port, R31 selected
	xor	cx,cx
.w:	in	al,dx
	test	al,2
	loopz	.w
	popm	ax,cx,dx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The primitives INT 10h uses.  DS is the BDA.  Registers preserved
; except where a result is returned.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; vga3_putc -- the character AL into the cell under the cursor; the
; attribute there is left alone, as teletype on a PC leaves it.
vga3_putc:
	pushm	ax,bx,dx,es
	mov	dl,al
	call	g_bda_cursor		; AH row, AL column
	mov	al,ah
	call	beam_avoid		; AH..AL = the row
	call	g_bda_cursor
	call	g_cell
	mov	ax,V3_SEG
	mov	es,ax
	mov	[es:bx],dl
	popm	ax,bx,dx,es
	ret

; vga3_cells -- AL, CX times, from the cursor on; with attribute BL when
; DL is 1 (fn 09), character only when 0 (fn 0A).  Clipped to the
; screen.  Written a row at a time, each row once the beam is off it.
vga3_cells:
	pushm	ax,bx,cx,dx,si,di,es
	mov	dh,bl			; DH attribute, DL type
	mov	bl,al			; BL character
	call	g_bda_cursor
	mov	si,ax			; SI = row:column
	call	g_cell
	mov	di,bx			; DI = byte offset
	mov	ax,V3_CELLS*2
	sub	ax,di
	shr	ax,1			; cells to the end of the screen
	cmp	cx,ax
	jbe	.1
	mov	cx,ax
.1:	jcxz	.9
	mov	ax,V3_SEG
	mov	es,ax
.row:
	mov	ax,si			; AH row, AL column
	mov	bh,al			; BH = column
	mov	al,ah
	call	beam_avoid		; this row
	mov	al,V3_COLS
	sub	al,bh
	xor	ah,ah			; AX = cells left in this row
	cmp	ax,cx
	jbe	.2
	mov	ax,cx
.2:	sub	cx,ax
	xchg	ax,cx			; CX = cells now, AX = cells after
	push	ax
	mov	al,bl			; character
	mov	ah,dh			; attribute
	test	dl,1
	jnz	.both
.char:	stosb
	inc	di
	loop	.char
	jmp	short .3
.both:	rep	stosw
.3:	pop	cx
	jcxz	.9
	mov	ax,si			; column 0 of the next row
	inc	ah
	xor	al,al
	mov	si,ax
	jmp	short .row
.9:
	popm	ax,bx,cx,dx,si,di,es
	ret

; vga3_getcell -- AX = attribute:character under the cursor.  A read
; disturbs the fetch as a write does, so it too waits for the beam.
vga3_getcell:
	pushm	bx,es
	call	g_bda_cursor
	mov	al,ah
	call	beam_avoid
	call	g_bda_cursor
	call	g_cell
	mov	ax,V3_SEG
	mov	es,ax
	mov	ax,[es:bx]
	popm	bx,es
	ret

; vga3_cursor -- the hardware cursor to row AH, column AL.  A CRTC
; register, not RAM: no contention, so immediate.
vga3_cursor:
	pushm	ax,bx
	call	g_cell
	shr	bx,1			; cell number
	mov	al,14
	mov	ah,bh
	call	g_crtc
	mov	al,15
	mov	ah,bl
	call	g_crtc
	popm	ax,bx
	ret

; vga3_shape -- as INT 10h fn 01: CH start line, bit 5 no cursor; CL end.
; R10 bits 6:5 are the 6845's blink control: 01 not displayed, 10 blink.
vga3_shape:
	pushm	ax
	mov	ah,ch
	and	ah,0x1F
	or	ah,0x40
	test	ch,0x20
	jz	.1
	mov	ah,0x20
.1:	mov	al,10
	call	g_crtc
	mov	ah,cl
	and	ah,0x1F
	mov	al,11
	call	g_crtc
	popm	ax
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Scrolling, as INT 10h fn 06 and 07 have it
;
;   CH,CL  top-left row, column      DH,DL  bottom-right row, column
;   AL     lines to scroll, zero meaning blank the whole window
;   BH     attribute for the lines that are blanked
;
; Rows are moved one at a time, each once the beam is clear of both its
; source and its destination, then the vacated rows are blanked.  Up
; works from the top down -- the order the beam draws in, so the copy
; runs behind it -- and down from the bottom up, so that a row is always
; read before it is overwritten.
;
; Registers through the loops: CX and DX the window, BH the attribute,
; BL the row counter, DI the lines (low) and the window height (high).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vga3_scroll_up:
	pushm	si
	xor	si,si
	jmp	short g_scroll
vga3_scroll_dn:
	pushm	si
	mov	si,1

g_scroll:				; SI 0 up, 1 down
	pushm	ax,bx,cx,dx,di,es
	cld
	cmp	dh,V3_ROWS-1
	jbe	.1
	mov	dh,V3_ROWS-1
.1:	cmp	dl,V3_COLS-1
	jbe	.2
	mov	dl,V3_COLS-1
.2:	cmp	ch,dh
	ja	.done			; an empty window
	cmp	cl,dl
	ja	.done
	mov	ah,dh
	sub	ah,ch
	inc	ah			; AH = rows in the window
	or	al,al
	jz	.all
	cmp	al,ah
	jb	.some
.all:	mov	al,ah			; blank it all
.some:
	mov	di,ax			; DI: lines in the low byte, rows in the high
	mov	ax,V3_SEG
	mov	es,ax
	xor	bl,bl			; k = 0

.move:
	mov	ax,di
	sub	ah,al			; AH = rows to move
	cmp	bl,ah
	jae	.blank
	or	si,si
	jnz	.mv_dn
	mov	ax,di			; up: destination = top + k,
	mov	ah,ch
	add	ah,bl
	add	al,ah			;     source = destination + lines
	jmp	short .mv
.mv_dn:
	mov	ax,di			; down: destination = bottom - k,
	mov	ah,dh
	sub	ah,bl
	neg	al
	add	al,ah			;       source = destination - lines
.mv:
	call	row_copy		; AH destination row, AL source row
	inc	bl
	jmp	short .move

.blank:
	xor	bl,bl			; j = 0
.bl:
	mov	ax,di
	cmp	bl,al			; j < lines?
	jae	.done
	or	si,si
	jnz	.bl_dn
	mov	ah,dh			; up: bottom - lines + 1 + j
	sub	ah,al
	inc	ah
	add	ah,bl
	jmp	short .bl_go
.bl_dn:
	mov	ah,ch			; down: top + j
	add	ah,bl
.bl_go:
	mov	al,bh			; the attribute
	call	row_blank		; AH row, AL attribute
	inc	bl
	jmp	short .bl

.done:
	popm	ax,bx,cx,dx,di,es
	popm	si
	ret

; row_copy -- source row AL to destination row AH, columns CL..DL, on
; the board (ES), once the beam is clear of both.  Everything preserved.
row_copy:
	pushm	ax,bx,cx,dx,si,di,ds
	mov	bx,ax
	cmp	bh,bl
	jbe	.r1
	xchg	bh,bl			; BH the lower row, BL the higher
.r1:	push	ax
	mov	ax,bx
	call	beam_avoid		; AH..AL
	pop	ax
	mov	dh,al			; the source row
	mov	al,cl
	call	g_cell
	mov	di,bx			; destination
	mov	ah,dh
	call	g_cell
	mov	si,bx			; source
	sub	dl,cl
	inc	dl
	movzx	cx,dl			; cells
	push	es
	pop	ds			; DS = ES = the board
	rep	movsw
	popm	ax,bx,cx,dx,si,di,ds
	ret

; row_blank -- row AH, columns CL..DL, to spaces in attribute AL, on the
; board (ES), once the beam is off it.  Everything preserved.
row_blank:
	pushm	ax,bx,cx,dx,di
	mov	dh,al			; the attribute
	mov	al,ah
	call	beam_avoid		; this row
	mov	al,cl
	call	g_cell
	mov	di,bx
	sub	dl,cl
	inc	dl
	movzx	cx,dl
	mov	ah,dh
	mov	al,' '
	rep	stosw
	popm	ax,bx,cx,dx,di
	ret

; vga3_clear -- the whole screen blanked, cursor home
vga3_clear:
	pushm	ax,bx,cx,dx
	xor	cx,cx
	mov	dx,((V3_ROWS-1)<<8)|(V3_COLS-1)
	xor	al,al
	mov	bh,V3_BLANK>>8
	call	vga3_scroll_up
	xor	ax,ax
	call	vga3_cursor
	popm	ax,bx,cx,dx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vga3_init -- is the board there, and if so bring it up
;
;	int vga3_init(void);		returns 1 if it is
;
; Called from POST before the first INT 10h, and from the monitor after
; VGA3 has been over the memory.  Two patterns at an off-screen address
; decide presence: a floating bus reads FF and agrees with neither.
; Then the CRTC; the memory window with video off; the font and a clear
; screen written straight in, which is allowed to sparkle because
; nothing is being shown yet; and video on.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vga3_init_:
	pushm	bx,cx,dx,si,di,ds,es
	cld
	get_bda	DS

	mov	bx,0x1000
	mov	al,0x55
	call	g_wr
	call	g_rd
	cmp	al,0x55
	jne	.absent
	mov	al,0xAA
	call	g_wr
	call	g_rd
	cmp	al,0xAA
	jne	.absent

	mov	cx,40			; every register zero first, the extended
	xor	bx,bx			;  ones included, so the table starts from
.zap:	mov	al,bl			;  a known state.  g_crtc eats AL, hence BL
	xor	ah,ah
	call	g_crtc
	inc	bl
	loop	.zap

	mov	si,v3_mode
	mov	cx,v3_mode_len/2
.crtc:
   cs	mov	ax,[si]			; AL register, AH value
	call	g_crtc
	add	si,2
	loop	.crtc

	mov	dx,V3_CFG
	mov	al,V3_CFG_QUIET
	out	dx,al

	mov	ax,V3_SEG
	mov	es,ax
	mov	di,V3_FONT
	mov	si,v3_font
	mov	cx,v3_font_len
	push	ds
	push	cs
	pop	ds
	rep	movsb			; the font
	pop	ds
	xor	di,di
	mov	ax,V3_BLANK
	mov	cx,V3_CELLS
	rep	stosw			; the screen

	mov	dx,V3_CFG
	mov	al,V3_CFG_ON
	out	dx,al

	or	byte [console],CON_VIDEO
	mov	ax,1
	jmp	short .9
.absent:
	xor	ax,ax
.9:
	popm	bx,cx,dx,si,di,ds,es
	ret


%include "font3270.inc"
