;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 10h_video.asm -- INT 10h, the video interface, on a serial terminal
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
; There is no display buffer.  Output goes to the serial console as
; ANSI/VT100, and the only state kept is the cursor and mode fields in
; the BDA -- deliberately, because real memory-mapped video is coming to
; this board later and a pretend buffer at B800:0000 would just have to
; be torn out again.
;
; The consequence, stated plainly: function 08h cannot report what is on
; the screen, and 09h/0Ah write to the terminal and put the cursor back
; rather than editing a buffer.  Everything DOS actually leans on --
; teletype, cursor, mode, scroll -- is honest.
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

	global	int_10h

segment	_TEXT

VID_COLS	equ	80		; the terminal we assume
VID_ROWS	equ	25
VID_MODE	equ	3		; 80x25 colour text
VID_ATTR	equ	0x07		; normal white on black
ASCII_BEL	equ	0x07


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 10h entry
;
; DS is pointed at the BIOS data area throughout, so the video fields
; are addressed directly.  Anything in the ROM needs a CS override --
; which is why the escape sequences below are built a character at a
; time instead of coming from strings.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_10h:
	sti
	pushm	all,ds,es
	mov	bp,sp
	cld

	get_bda	DS			; the BDA is all the state there is

	cmp	ah,len_v_tab
	jnb	v_done			; unsupported: return quietly, as a
					;  real BIOS does -- never an error

	mov	bl,ah
	xor	bh,bh
	add	bx,bx
   cs	jmp	word [bx+v_tab]

v_done:
	popm	all,ds,es
	iret


	align	2
v_tab:
	dw	v_fn00		; 00 set mode
	dw	v_fn01		; 01 set cursor shape
	dw	v_fn02		; 02 set cursor position
	dw	v_fn03		; 03 get cursor position
	dw	v_done		; 04 read light pen -- no
	dw	v_fn05		; 05 set active page
	dw	v_fn06		; 06 scroll up
	dw	v_fn07		; 07 scroll down
	dw	v_fn08		; 08 read character/attribute
	dw	v_fn09		; 09 write character and attribute
	dw	v_fn0A		; 0A write character
	dw	v_done		; 0B set palette -- nothing to set
	dw	v_done		; 0C write pixel -- text only
	dw	v_done		; 0D read pixel  -- text only
	dw	v_fn0E		; 0E teletype
	dw	v_fn0F		; 0F get mode
len_v_tab	equ	($-v_tab)/2


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vputc -- write AL to the serial console
;
; Everything preserved.  INT 14h is used rather than VIDEO_putchar
; because VIDEO_putchar is about to be pointed here, and that would be
; a loop.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vputc:
	pushm	ax,bx,cx,dx,si,di
	mov	ah,1			; write character
	xor	dx,dx			; COM1
	int	0x14
	popm	ax,bx,cx,dx,si,di
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vputdec2 -- write AL as exactly two decimal digits
;
; ANSI accepts leading zeros, so two digits always is both correct and
; much shorter than suppressing them.  Rows reach 25 and columns 80, so
; two is enough.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vputdec2:
	pushm	ax,bx
	xor	ah,ah
	mov	bl,10
	div	bl			; AL = tens, AH = units
	add	al,'0'
	call	vputc
	mov	al,ah
	add	al,'0'
	call	vputc
	popm	ax,bx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vcsi -- emit ESC [
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vcsi:
	pushm	ax
	mov	al,ASCII_ESC
	call	vputc
	mov	al,'['
	call	vputc
	popm	ax
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vcursor -- BX = the current page's cursor word, AH = row, AL = column
; vsetcur -- store AH/AL back as the current page's cursor
;
;  DS is the BDA.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vcursor:
	mov	bl,[vid_active_page]
	and	bl,7
	xor	bh,bh
	add	bx,bx
	mov	ax,[bx+vid_cursor]
	ret

vsetcur:
	pushm	bx
	mov	bl,[vid_active_page]
	and	bl,7
	xor	bh,bh
	add	bx,bx
	mov	[bx+vid_cursor],ax
	popm	bx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vgoto -- move the terminal cursor to the BDA cursor position
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vgoto:
	pushm	ax,bx,cx
	call	vcursor			; AH = row, AL = column
	mov	cx,ax
	call	vcsi
	mov	al,ch			; row
	inc	al			; ANSI counts from one
	call	vputdec2
	mov	al,';'
	call	vputc
	mov	al,cl			; column
	inc	al
	call	vputdec2
	mov	al,'H'
	call	vputc
	popm	ax,bx,cx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Cursor movement, tracked in the BDA.  The terminal does the real work
; -- it wraps and scrolls by itself -- so these only keep our idea of
; where the cursor is in step with what the terminal has done.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_advance:				; one column right, wrapping
	pushm	ax,bx,cx
	call	vcursor			; AH = row, AL = column
	inc	al
	cmp	al,VID_COLS
	jb	.9
	xor	al,al			; wrapped: column 0 of the next row
	inc	ah
	cmp	ah,VID_ROWS
	jb	.9
	mov	ah,VID_ROWS-1		; the terminal scrolled; stay on the
.9:					;  bottom row
	call	vsetcur
	popm	ax,bx,cx
	ret

v_col0:					; carriage return
	pushm	ax,bx
	call	vcursor
	xor	al,al
	call	vsetcur
	popm	ax,bx
	ret

v_nextrow:				; line feed
	pushm	ax,bx
	call	vcursor
	inc	ah
	cmp	ah,VID_ROWS
	jb	.9
	mov	ah,VID_ROWS-1
.9:
	call	vsetcur
	popm	ax,bx
	ret

v_backsp:				; backspace
	pushm	ax,bx
	call	vcursor
	or	al,al
	jz	.9			; already at the left margin
	dec	al
.9:
	call	vsetcur
	popm	ax,bx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 00 -- set video mode
;
;  AL = mode; bit 7 set means do not clear the screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn00:
	mov	al,[bp+offset_ax]
	mov	ah,al
	and	al,0x7F
	mov	[vid_mode],al

	mov	word [vid_columns],VID_COLS
	mov	byte [ega_rows],VID_ROWS-1
	mov	word [vid_buf_len],VID_COLS*VID_ROWS*2
	mov	word [vid_start],0
	mov	byte [vid_active_page],0
	mov	word [vid_addr_chip],0x03D4
	mov	byte [vid_palette],0

	pushm	bx,cx
	xor	bx,bx
	mov	cx,8
.1:	mov	word [bx+vid_cursor],0
	add	bx,2
	loop	.1
	popm	bx,cx

	test	ah,0x80			; caller asked us not to clear?
	jnz	v_done			; then leave the terminal alone entirely

	call	vcsi			; ESC [ 2 J -- erase the screen
	mov	al,'2'
	call	vputc
	mov	al,'J'
	call	vputc
	call	vgoto
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 01 -- set cursor shape.  Recorded and ignored: a terminal has one.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn01:
	mov	ax,[bp+offset_cx]
	mov	[vid_cursor_mode],ax
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 02 -- set cursor position.  DH = row, DL = column, BH = page.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn02:
	mov	bx,[bp+offset_bx]
	mov	al,bh
	and	al,7
	mov	[vid_active_page],al

	mov	ax,[bp+offset_dx]	; AH = row, AL = column
	cmp	ah,VID_ROWS
	jb	.1
	mov	ah,VID_ROWS-1
.1:	cmp	al,VID_COLS
	jb	.2
	mov	al,VID_COLS-1
.2:
	call	vsetcur
	call	vgoto
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 03 -- get cursor position.  BH = page.
;
;  Returns DH = row, DL = column, CX = cursor shape.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn03:
	mov	bx,[bp+offset_bx]
	mov	al,bh
	and	al,7
	mov	[vid_active_page],al

	call	vcursor			; AH = row, AL = column
	mov	[bp+offset_dx],ax
	mov	ax,[vid_cursor_mode]
	mov	[bp+offset_cx],ax
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 05 -- set the active display page
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn05:
	mov	al,[bp+offset_ax]
	and	al,7
	mov	[vid_active_page],al
	call	vgoto
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 0F -- get the current mode
;
;  Returns AL = mode, AH = column count, BH = active page.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn0F:
	mov	al,[vid_mode]
	mov	ah,[vid_columns]
	mov	[bp+offset_ax],ax
	mov	bx,[bp+offset_bx]
	mov	bh,[vid_active_page]
	mov	[bp+offset_bx],bx
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 0E -- teletype output.  AL = character.
;
; The one function DOS leans on hardest.  Printable characters go out
; and move the cursor; the four control codes that matter are passed
; through and tracked.  The terminal does its own wrapping and
; scrolling, so there is nothing to do but keep our idea of the cursor
; in step.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn0E:
	mov	al,[bp+offset_ax]

	cmp	al,ASCII_CR
	je	.cr
	cmp	al,ASCII_LF
	je	.lf
	cmp	al,ASCII_BS
	je	.bs
	cmp	al,ASCII_BEL
	je	.bell
	cmp	al,ASCII_SP
	jb	.bell			; any other control: emit, do not track

	call	vputc
	call	v_advance
	jmp	v_done
.cr:
	call	vputc
	call	v_col0
	jmp	v_done
.lf:
	call	vputc
	call	v_nextrow
	jmp	v_done
.bs:
	call	vputc
	call	v_backsp
	jmp	v_done
.bell:
	call	vputc
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 09 -- write character and attribute, CX times
; fn 0A -- write character, CX times
;
;  AL = character, BH = page, BL = attribute (09 only), CX = count
;
; The BIOS contract is that the cursor does NOT move.  On a terminal the
; characters move it anyway, so it is put back afterwards.  The
; attribute is discarded: there is nowhere to keep it, and emitting SGR
; for it would fight with whatever the application is doing.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn09:
v_fn0A:
	mov	cx,[bp+offset_cx]
	or	cx,cx
	jz	v_done			; a count of zero writes nothing

	mov	al,[bp+offset_ax]
.1:
	push	cx
	call	vputc
	pop	cx
	loop	.1

	call	vgoto			; the cursor did not officially move
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 08 -- read the character and attribute at the cursor
;
; There is no buffer to read, and no terminal answers this.  A space in
; the normal attribute is returned: it is what an unwritten cell holds,
; it is what the few callers that use this are usually testing for, and
; it is at least consistent.  This is the one function the no-buffer
; decision makes dishonest, and it is recorded here rather than left for
; someone to discover.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn08:
	mov	ax,(VID_ATTR<<8) | ASCII_SP
	mov	[bp+offset_ax],ax
	jmp	v_done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn 06 -- scroll a window up
; fn 07 -- scroll a window down
;
;  AL = lines to scroll, zero means blank the whole window
;  CH,CL = top-left row,column     DH,DL = bottom-right row,column
;  BH = attribute for the blanked lines
;
; A whole-screen scroll becomes a real terminal scroll.  Anything
; smaller is served by setting a scrolling region, scrolling inside it,
; and putting the region back -- which is what DOS's full-screen
; programs are asking for.  A window that is the whole screen and a
; count of zero is the common "clear the screen" call.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
v_fn06:
	mov	bl,'S'			; ESC [ n S -- scroll up
	jmp	short v_scroll
v_fn07:
	mov	bl,'T'			; ESC [ n T -- scroll down

v_scroll:
	mov	cx,[bp+offset_cx]	; CH = top row, CL = left column
	mov	dx,[bp+offset_dx]	; DH = bottom row, DL = right column
	mov	al,[bp+offset_ax]	; lines

; A count of zero, or a count covering the window, blanks it.
	or	al,al
	jz	.blank
	mov	ah,dh
	sub	ah,ch
	inc	ah			; window height
	cmp	al,ah
	jnb	.blank

; Set the scrolling region to the window, scroll, then release it.
	push	ax
	call	vcsi
	mov	al,ch
	inc	al
	call	vputdec2
	mov	al,';'
	call	vputc
	mov	al,dh
	inc	al
	call	vputdec2
	mov	al,'r'			; ESC [ top ; bottom r
	call	vputc

	call	vcsi
	pop	ax
	call	vputdec2
	mov	al,bl			; 'S' or 'T'
	call	vputc

	call	vcsi			; ESC [ r -- region back to full screen
	mov	al,'r'
	call	vputc
	call	vgoto
	jmp	v_done

.blank:
; Blank the window a row at a time: position, then erase to end of line.
; ESC [ 2 J would be wrong for anything but the full screen.
	mov	al,ch			; current row
.1:
	cmp	al,dh
	ja	.9
	push	ax
	call	vcsi
	inc	al
	call	vputdec2
	mov	al,';'
	call	vputc
	mov	al,cl			; left column
	inc	al
	call	vputdec2
	mov	al,'H'
	call	vputc
	call	vcsi
	mov	al,'K'			; erase to end of line
	call	vputc
	pop	ax
	inc	al
	jmp	.1
.9:
	call	vgoto
	jmp	v_done
