;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sd.asm -- SD.SYS, a DOS block device driver for the SBC-386EX's on-board
;		microSD socket.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.  See SBC386/bios/COPYING.
;
;	nasm -O9 -f bin -o SD.SYS sd.asm		(sdcore.inc beside it)
;	CONFIG.SYS:  DEVICE=SD.SYS
;
; One drive letter: the card's first FAT12 or FAT16 partition (MBR types
; 01, 04, 06, 0E), or, on a card with no partition table, the whole card
; as one volume.  Sectors are numbered in 32 bits (header attribute bit
; 1), as a partition over 32 MB needs; DOS 4 or later, so.
;
; At load the card is brought up (sdcore.inc's sd_start: the fastest
; clock that reads sector 0 correctly) and the volume found.  With no
; card, or nothing it can use, the driver says so and does not stay.
;
; Each sector is read or written by sdcore.inc in one burst, with CRC16
; checked on reads and the card's data response and status on writes,
; and tried three times.  Write-with-verify reads each sector back and
; compares.  Media check watches card detect: a card taken out (and put
; back) is reported as changed, and brought up again before the BPB is
; rebuilt.
;
; The driver runs on its own stack: DOS lends a block driver very little,
; and the SSIO bursts run with interrupts off for up to a revolution of
; the card's internal wait, so nothing else is borrowed either.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	cpu	386
	bits	16
	org	0

; ---- Device header ----------------------------------------------------------
header:	dd	-1			; one driver in this file
	dw	0002h			; block device; 32-bit sector numbers
	dw	strategy
	dw	interrupt
	db	1			; units (DOS fills it in from INIT)
	times 7 db 0

; request header offsets
RQ_UNIT		equ	1
RQ_CMD		equ	2
RQ_STATUS	equ	3
RQ_MEDIA	equ	13		; also INIT's unit count out
RQ_ADDR		equ	14		; transfer address; INIT's break address;
					;  MEDIA CHECK's answer (byte)
RQ_COUNT	equ	18		; sectors; BUILD BPB's BPB pointer; INIT's
					;  BPB array pointer
RQ_START	equ	20		; start sector, FFFFh: see RQ_START32
RQ_DRIVE	equ	22		; INIT: the drive number DOS gave us
RQ_START32	equ	26

ST_DONE		equ	0100h
ST_ERROR	equ	8000h
E_UNKNOWN	equ	03h		; error codes, low byte of the status
E_NOTREADY	equ	02h
E_SECTOR	equ	08h
E_WRITE		equ	0Ah
E_READ		equ	0Bh

reqptr	dd	0

strategy:
	mov	[cs:reqptr],bx
	mov	[cs:reqptr+2],es
	retf

; ---- The interrupt routine: everything, on our own stack -----------------
interrupt:
	pushf
	pushad
	push	ds
	push	es
	mov	[cs:oldsp],sp
	mov	[cs:oldss],ss
	mov	ax,cs
	cli
	mov	ss,ax
	mov	sp,stacktop
	sti				; (DOS's flags are restored on the way out)
	push	cs
	pop	ds
	push	cs
	pop	es
	cld
	les	bx,[reqptr]
	mov	al,[es:bx+RQ_CMD]
	push	cs
	pop	es
	mov	word [status],ST_DONE
	cmp	al,0
	je	.init
	cmp	al,1
	je	.media
	cmp	al,2
	je	.bpb
	cmp	al,4
	je	.read
	cmp	al,8
	je	.write
	cmp	al,9
	je	.writev
	mov	word [status],ST_DONE|ST_ERROR|E_UNKNOWN
	jmp	.out
.init:	call	do_init
	jmp	.out
.media:	call	do_media
	jmp	.out
.bpb:	call	do_bpb
	jmp	.out
.read:	call	do_read
	jmp	.out
.write:	mov	byte [verify],0
	call	do_write
	jmp	.out
.writev:
	mov	byte [verify],1
	call	do_write
.out:	les	bx,[reqptr]
	mov	ax,[status]
	mov	[es:bx+RQ_STATUS],ax
	cli
	mov	ss,[cs:oldss]
	mov	sp,[cs:oldsp]
	pop	es
	pop	ds
	popad
	popf
	retf

; ---- MEDIA CHECK -----------------------------------------------------------
; Not changed, unless the card is out or has been: then changed, and the
; card brought up again (if it is back) for the BUILD BPB that follows.
do_media:
	les	bx,[reqptr]
	mov	byte [es:bx+RQ_ADDR],1	; not changed
	push	cs
	pop	es
	call	sd_card
	jnz	.in
	mov	byte [gone],1
	jmp	.changed
.in:	cmp	byte [gone],0
	je	.x
	call	restart			; back: bring it up
	jc	.changed		;  (BUILD BPB will say not ready)
	mov	byte [gone],0
.changed:
	les	bx,[reqptr]
	mov	byte [es:bx+RQ_ADDR],0FFh
	push	cs
	pop	es
.x:	ret

; ---- BUILD BPB ----------------------------------------------------------------
do_bpb:
	cmp	byte [gone],0
	jne	.nr
	les	bx,[reqptr]
	mov	word [es:bx+RQ_COUNT],bpb
	mov	[es:bx+RQ_COUNT+2],cs
	push	cs
	pop	es
	ret
.nr:	mov	word [status],ST_DONE|ST_ERROR|E_NOTREADY
	ret

; ---- INPUT, OUTPUT, OUTPUT WITH VERIFY -------------------------------------
; getio -- the request's transfer address, count and start sector into
; xfer, count and lba; the count it asks for checked against the volume.
; CF, with [status] set, if the card is out or the range runs off the end.
getio:
	les	bx,[reqptr]
	mov	ax,[es:bx+RQ_ADDR]
	mov	dx,[es:bx+RQ_ADDR+2]
	mov	cx,[es:bx+RQ_COUNT]
	movzx	esi,word [es:bx+RQ_START]
	cmp	si,0FFFFh
	jne	.s16
	mov	esi,[es:bx+RQ_START32]
.s16:	mov	word [es:bx+RQ_COUNT],0	; none done yet
	push	cs
	pop	es
	mov	bp,ax			; normalised: offset under 16, so the
	shr	bp,4			;  512s added per sector cannot wrap
	add	dx,bp
	and	ax,0Fh
	mov	[xfer],ax
	mov	[xfer+2],dx
	mov	[count],cx
	mov	[lba],esi
	call	sd_card
	jz	.nr
	cmp	byte [gone],0
	jne	.nr
	movzx	ecx,cx
	add	ecx,esi
	jc	.range
	cmp	ecx,[vsize]
	ja	.range
	clc
	ret
.nr:	mov	byte [gone],1
	mov	word [status],ST_DONE|ST_ERROR|E_NOTREADY
	stc
	ret
.range:	mov	word [status],ST_DONE|ST_ERROR|E_SECTOR
	stc
	ret

; next -- one sector done: the count in the request up, the transfer
; address on 512 bytes (kept normalised), the sector on one.
next:
	les	bx,[reqptr]
	inc	word [es:bx+RQ_COUNT]
	push	cs
	pop	es
	mov	ax,[xfer]
	add	ax,512
	mov	dx,ax
	shr	dx,4
	add	[xfer+2],dx
	and	ax,0Fh
	mov	[xfer],ax
	inc	dword [lba]
	dec	word [count]
	ret

do_read:
	call	getio
	jc	.x
.s:	cmp	word [count],0
	je	.x
	call	rd_try
	jc	.err
	push	es			; to the caller's buffer
	les	di,[xfer]
	mov	si,secbuf
	mov	cx,256
	rep	movsw
	pop	es
	call	next
	jmp	.s
.err:	mov	word [status],ST_DONE|ST_ERROR|E_READ
.x:	ret

do_write:
	call	getio
	jc	.x
.s:	cmp	word [count],0
	je	.x
	push	ds			; from the caller's buffer
	lds	si,[xfer]
	mov	di,secbuf
	mov	cx,256
	rep	movsw
	pop	ds
	call	wr_try
	jc	.err
	cmp	byte [verify],0
	je	.n
	call	rd_try			; read it back and compare
	jc	.err
	push	es
	les	di,[xfer]
	mov	si,secbuf
	mov	cx,256
	repe	cmpsw
	pop	es
	jne	.err
.n:	call	next
	jmp	.s
.err:	mov	word [status],ST_DONE|ST_ERROR|E_WRITE
.x:	ret

; rd_try, wr_try -- sector [lba] of the volume, three tries.  CF if all
; three failed.
rd_try:
	mov	byte [rtries],3
.t:	mov	ebx,[lba]
	add	ebx,[poff]
	call	sd_read
	jnc	.x
	dec	byte [rtries]
	jnz	.t
	stc
.x:	ret

wr_try:
	mov	byte [rtries],3
.t:	mov	ebx,[lba]
	add	ebx,[poff]
	call	wr_sector
	jnc	.x
	dec	byte [rtries]
	jnz	.t
	stc
.x:	ret

; ---- Finding the volume -----------------------------------------------------
; restart -- the card from nothing, and its volume: CF if either fails,
; [fail] saying which (a message, for INIT).
restart:
	mov	word [fail],m_nocard
	call	sd_card
	jz	.no
	mov	word [fail],m_nostart
	call	sd_start
	jc	.no
	call	findvol
	ret
.no:	stc
	ret

; findvol -- poff, vsize and bpb from the card: the first FAT12/16
; partition in the MBR, or, if sector 0 is itself a boot sector, the
; whole card.  CF, [fail] set, if neither.
findvol:
	mov	word [fail],m_noread
	mov	dword [poff],0
	mov	dword [lba],0
	call	rd_try
	jc	.no
	mov	word [fail],m_nomedia
	cmp	word [secbuf+510],0AA55h
	jne	.no
	mov	si,secbuf+1BEh		; the partition table
	mov	cx,4
.p:	mov	al,[si+4]
	cmp	al,01h			; FAT12
	je	.got
	cmp	al,04h			; FAT16 < 32 MB
	je	.got
	cmp	al,06h			; FAT16
	je	.got
	cmp	al,0Eh			; FAT16, LBA
	je	.got
	add	si,16
	loop	.p
	call	isboot			; none: is sector 0 a boot sector?
	jnc	.bs
	mov	word [fail],m_nopart
	jmp	.no
.got:	mov	eax,[si+8]
	mov	[poff],eax
	mov	dword [lba],0		; its boot sector
	call	rd_try
	jc	.no
	mov	word [fail],m_noboot
	cmp	word [secbuf+510],0AA55h
	jne	.no
	call	isboot
	jc	.no
.bs:	mov	si,secbuf+0Bh		; the BPB
	mov	di,bpb
	mov	cx,BPBLEN
	rep	movsb
	movzx	eax,word [bpb+8]	; total sectors: 16 bits, or 32 if 0
	or	ax,ax
	jnz	.t
	mov	eax,[bpb+21]
.t:	mov	[vsize],eax
	clc
	ret
.no:	stc
	ret

; isboot -- CF clear if secbuf looks like a FAT boot sector: a jump, 512
; bytes a sector, a power of two sectors a cluster, one or two FATs.
isboot:
	mov	al,[secbuf]
	cmp	al,0EBh
	je	.j
	cmp	al,0E9h
	jne	.no
.j:	cmp	word [secbuf+0Bh],512
	jne	.no
	mov	al,[secbuf+0Dh]
	or	al,al
	jz	.no
	mov	ah,al
	dec	ah
	test	al,ah			; a power of two
	jnz	.no
	mov	al,[secbuf+10h]
	cmp	al,1
	jb	.no
	cmp	al,2
	ja	.no
	clc
	ret
.no:	stc
	ret

; ---- The SD core ------------------------------------------------------------
%include "sdcore.inc"

; ---- The driver's data ------------------------------------------------------
BPBLEN		equ	25		; DOS 3.31 BPB: bytes 0Bh-23h
bpb	times BPBLEN db 0
bpbarr	dw	bpb			; INIT's BPB array: one unit
poff	dd	0			; the volume's first sector on the card
vsize	dd	0			; its sectors
lba	dd	0			; the volume's sector being moved
xfer	dd	0			; the caller's buffer, normalised
count	dw	0			; sectors still to move
status	dw	0
verify	db	0
gone	db	0			; the card is out, or has been
rtries	db	0
fail	dw	0			; restart's reason, a message
oldss	dw	0
oldsp	dw	0
	align	2
	times 512 db 0
stacktop:

; Everything above stays; INIT and its messages go.
resident_end:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INIT: once, at boot.  DOS allows INT 21h output here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
do_init:
	call	crcinit
	mov	dx,m_banner
	call	iputs
	call	restart
	jc	.no
	les	bx,[reqptr]		; one unit, its BPB, and where we end
	mov	byte [es:bx+RQ_MEDIA],1
	mov	word [es:bx+RQ_ADDR],resident_end
	mov	[es:bx+RQ_ADDR+2],cs
	mov	word [es:bx+RQ_COUNT],bpbarr
	mov	[es:bx+RQ_COUNT+2],cs
	mov	al,[es:bx+RQ_DRIVE]	; DOS 4+: the drive number we got
	push	cs
	pop	es
	add	al,'A'
	mov	[m_drv],al
	mov	dx,m_ok1
	call	iputs
	mov	eax,[vsize]		; MB
	shr	eax,11
	call	idec
	mov	dx,m_ok2
	call	iputs
	call	sd_mhz			; the clock, x.xx MHz
	xor	dx,dx
	mov	cx,100
	div	cx
	push	dx
	movzx	eax,ax
	call	idec
	mov	dl,'.'
	mov	ah,2
	int	21h
	pop	ax
	cmp	ax,10
	jae	.two
	push	ax
	mov	dl,'0'
	mov	ah,2
	int	21h
	pop	ax
.two:	movzx	eax,ax
	call	idec
	mov	dx,m_ok3
	call	iputs
	ret
.no:	mov	dx,[fail]		; say why, and do not stay
	call	iputs
	les	bx,[reqptr]
	mov	byte [es:bx+RQ_MEDIA],0
	mov	word [es:bx+RQ_ADDR],0
	mov	[es:bx+RQ_ADDR+2],cs
	push	cs
	pop	es
	mov	word [status],ST_DONE|ST_ERROR|E_NOTREADY
	ret

iputs:	push	ax			; DX -> '$'-terminated
	mov	ah,9
	int	21h
	pop	ax
	ret

idec:	push	eax			; EAX, unsigned decimal
	push	ecx
	push	edx
	mov	ecx,10
	push	word 0FFFFh
.div:	xor	edx,edx
	div	ecx
	push	dx
	or	eax,eax
	jnz	.div
.out:	pop	dx
	cmp	dx,0FFFFh
	je	.end
	add	dl,'0'
	mov	ah,2
	int	21h
	jmp	.out
.end:	pop	edx
	pop	ecx
	pop	eax
	ret

m_banner db	"SD.SYS -- SBC-386EX microSD",13,10,"$"
m_ok1	db	"  drive "
m_drv	db	"?: $"
m_ok2	db	" MB, $"
m_ok3	db	" MHz",13,10,"$"
m_nocard db	"  no card in the socket: not installed",13,10,"$"
m_nostart db	"  the card did not answer: not installed",13,10,"$"
m_noread db	"  sector 0 would not read: not installed",13,10,"$"
m_nomedia db	"  sector 0 is neither an MBR nor a boot sector: not installed",13,10,"$"
m_nopart db	"  no FAT12/16 partition on the card: not installed",13,10,"$"
m_noboot db	"  the partition has no FAT boot sector: not installed",13,10,"$"
