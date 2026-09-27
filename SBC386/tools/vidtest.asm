;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vidtest.asm -- where does BIOS video output land, relative to a screen
;                the program drew itself?
;
; A DOS .COM for the SBC-386EX with the VGA3 board.  Both Borland IDEs draw
; most of their screen by writing B800 directly and put some of it out
; through INT 10h, and on this board the two disagree: one row comes out as
; garbage.  This does the same two things on a screen whose every cell is
; known, then reports what is actually in memory afterwards.
;
;	nasm -f bin vidtest.asm -o VIDTEST.COM
;
; Run it with SETUP -> Console -> Video only, so that INT 10h goes to the
; board alone and this program's own report goes to the serial line alone.
; The report is written with INT 14h, which never touches the screen.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro	pushm 1-*
  %rep %0
    push %1
    %rotate 1
  %endrep
%endmacro
%macro	popm 1-*
  %rep %0
    %rotate -1
    pop %1
  %endrep
%endmacro

	org	100h

VSEG		equ	0B800h
ROWS		equ	25
COLS		equ	80

	mov	dx,m_banner
	call	puts

; --- 1: fill every cell ourselves, so anything else that writes shows ----
; Row n gets the letter 'A'+n in attribute 07, all 80 columns.
	mov	ax,VSEG
	mov	es,ax
	xor	di,di
	xor	bl,bl			; row
.row:
	mov	cx,COLS
	mov	al,bl
	add	al,'A'
	mov	ah,07h
.cell:
	stosw
	loop	.cell
	inc	bl
	cmp	bl,ROWS
	jb	.row

; --- 2: put the cursor somewhere definite and use BIOS teletype ----------
	mov	ah,2
	xor	bh,bh
	mov	dx,0500h + 10		; row 5, column 10
	int	10h
	mov	si,s_tty
	call	tty_str

; --- 3: the same, with fn 09, which is not supposed to move the cursor --
	mov	ah,2
	xor	bh,bh
	mov	dx,0700h + 10		; row 7, column 10
	int	10h
	mov	ax,0900h + '#'
	mov	bx,001Fh		; page 0, attribute 1F
	mov	cx,5
	int	10h

; --- 4: ask the BIOS where it thinks the cursor is ----------------------
	mov	ah,3
	xor	bh,bh
	int	10h
	push	dx
	mov	dx,m_cursor
	call	puts
	pop	dx
	mov	al,dh
	call	hex8
	mov	al,','
	call	putc
	mov	al,dl
	call	hex8
	call	crlf

; --- 5: report rows 4 to 8 as they actually are -------------------------
	mov	dx,m_rows
	call	puts
	mov	bl,4
.dump:
	mov	dx,m_row
	call	puts
	mov	al,bl
	call	hex8
	mov	al,' '
	call	putc
	call	row_out
	call	crlf
	inc	bl
	cmp	bl,9
	jb	.dump

	mov	dx,m_done
	call	puts
	mov	ax,4C00h
	int	21h


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; row_out -- the characters of row BL, as text, with a dot for anything
; that is not printable.  Attributes are reported only where they differ
; from 07, which keeps the line readable.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
row_out:
	pushm	ax,bx,cx,si
	mov	al,bl
	mov	ah,COLS*2
	mul	ah
	mov	si,ax			; SI = the row's first byte
	mov	ax,VSEG
	mov	es,ax
	mov	cx,COLS
.1:
	mov	al,[es:si]
	cmp	al,' '
	jb	.dot
	cmp	al,7Eh
	jbe	.ok
.dot:	mov	al,'.'
.ok:	call	putc
	add	si,2
	loop	.1
	popm	ax,bx,cx,si
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; tty_str -- CS:SI through INT 10h teletype, the way a program that wants
; the BIOS to place its output would do it
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
tty_str:
	pushm	ax,bx,si
.1:	mov	al,[cs:si]
	inc	si
	or	al,al
	jz	.9
	mov	ah,0Eh
	mov	bx,0007h
	int	10h
	jmp	short .1
.9:	popm	ax,bx,si
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Output to the serial port only -- INT 14h, never the screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
puts:					; DX -> '$'-terminated
	pushm	ax,bx,si
	mov	si,dx
.1:	mov	al,[si]
	cmp	al,'$'
	je	.9
	call	putc
	inc	si
	jmp	short .1
.9:	popm	ax,bx,si
	ret

putc:					; AL
	pushm	ax,dx
	mov	ah,1
	xor	dx,dx			; COM1
	int	14h
	popm	ax,dx
	ret

crlf:
	push	ax
	mov	al,13
	call	putc
	mov	al,10
	call	putc
	pop	ax
	ret

hex8:					; AL
	pushm	ax,cx
	mov	cl,4
	mov	ch,al
	shr	al,cl
	call	.digit
	mov	al,ch
	and	al,0Fh
	call	.digit
	popm	ax,cx
	ret
.digit:
	and	al,0Fh
	add	al,'0'
	cmp	al,'9'
	jbe	putc
	add	al,'A'-'9'-1
	jmp	putc


m_banner	db	13,10,'VIDTEST -- BIOS video output against a screen drawn by hand',13,10
		db	'Screen filled: row n is the letter A+n, all 80 columns.',13,10
		db	'Teletype "BIOS" at row 5 col 10; five # at row 7 col 10 via fn 09.',13,10,'$'
m_cursor	db	13,10,'INT 10h fn 03 says the cursor is at row,col $'
m_rows		db	13,10,'Rows 4 to 8 as they now stand:',13,10,'$'
m_row		db	'  row $'
m_done		db	13,10,'Row 5 should read AAAAAAAAAABIOSAAA..., row 7 JJJJJJJJJJ#####JJJ...',13,10
		db	'Anything else is where the BIOS and the program disagree.',13,10,'$'
s_tty		db	'BIOS',0
