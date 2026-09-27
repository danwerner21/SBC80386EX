;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; kbdiag.asm -- why does the PS/2 keyboard go quiet under DOS?
;
; A DOS .COM for the SBC-386EX with the VGA3 board.  Output through
; INT 21h only, so it needs nothing of the screen.
;
;	nasm -f bin kbdiag.asm -o KBDIAG.COM
;
; It prints the state that decides whether INT 09h can run -- the 8259
; mask, the 8242 status, the INT 09h vector, the BDA keyboard fields --
; then counts keystrokes reaching INT 16h for ten seconds three times:
; as found, after unmasking IRQ1, and after draining the 8242.  Whichever
; count comes alive names the fault.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	org	100h

KBC_DATA	equ	4E0h
KBC_STAT	equ	4E1h
TICKS		equ	182		; ten seconds of the 18.2hz count
BIOS_IRQ1	equ	37F1h		; int_irq1 in start.map, this build

start:
	mov	dx,m_banner
	call	puts

	mov	dx,m_imr
	call	puts
	in	al,21h
	call	hex8
	call	crlf

	mov	dx,m_stat
	call	puts
	mov	dx,KBC_STAT
	in	al,dx
	call	hex8
	call	crlf

	mov	dx,m_vec
	call	puts
	xor	ax,ax
	mov	es,ax
	mov	ax,[es:9*4+2]
	call	hex16
	mov	al,':'
	call	putc
	mov	ax,[es:9*4]
	call	hex16
	call	crlf

	mov	dx,m_vec0c
	call	puts
	mov	ax,[es:0Ch*4+2]
	call	hex16
	mov	al,':'
	call	putc
	mov	ax,[es:0Ch*4]
	call	hex16
	call	crlf

	mov	dx,m_code
	call	puts
	les	di,[es:9*4]		; ES:DI -> the INT 09h handler
	mov	cx,16
.code:	mov	al,[es:di]
	call	hex8
	mov	al,' '
	call	putc
	inc	di
	loop	.code
	call	crlf

	mov	ax,40h
	mov	es,ax
	mov	dx,m_flag
	call	puts
	mov	al,[es:17h]
	call	hex8
	mov	dx,m_flag3
	call	puts
	mov	al,[es:96h]
	call	hex8
	mov	dx,m_head
	call	puts
	mov	ax,[es:1Ah]
	call	hex16
	mov	al,'/'
	call	putc
	mov	ax,[es:1Ch]
	call	hex16
	call	crlf

; --- 1: as found -------------------------------------------------------
	mov	dx,m_t1
	call	puts
	call	count_keys

; --- 2: unmask IRQ1 --------------------------------------------------------
	mov	dx,m_t2
	call	puts
	in	al,21h
	and	al,0FDh
	out	21h,al
	call	count_keys

; --- 3: drain the 8242 -----------------------------------------------------
	mov	dx,m_t3
	call	puts
	mov	cx,16
.drain:
	mov	dx,KBC_STAT
	in	al,dx
	test	al,1
	jz	.drained
	mov	dx,KBC_DATA
	in	al,dx
	call	hex8			; show what was stuck
	mov	al,' '
	call	putc
	loop	.drain
.drained:
	call	crlf
	call	count_keys

; --- 4: is the 8242 producing bytes at all?  Poll it, bypassing IRQs ----
	mov	dx,m_t4
	call	puts
	mov	ax,40h
	mov	es,ax
	xor	bx,bx
	mov	si,[es:6Ch]
.poll:	mov	dx,KBC_STAT
	in	al,dx
	test	al,1
	jz	.pidle
	mov	dx,KBC_DATA
	in	al,dx
	call	hex8
	mov	al,' '
	call	putc
	inc	bx
.pidle:	mov	ax,[es:6Ch]
	sub	ax,si
	cmp	ax,TICKS
	jb	.poll
	call	crlf
	mov	dx,m_count
	call	puts
	mov	ax,bx
	call	hex16
	call	crlf

; --- 5: bypass DOS -- INT 09h straight to the BIOS handler ------------------
; BIOS_IRQ1 is int_irq1 from start.map; change it if the BIOS is rebuilt.
	mov	dx,m_t5
	call	puts
	xor	ax,ax
	mov	es,ax
	cli
	push	word [es:9*4+2]
	push	word [es:9*4]
	mov	word [es:9*4],BIOS_IRQ1
	mov	word [es:9*4+2],0F000h
	sti
	call	count_keys
	xor	ax,ax
	mov	es,ax
	cli
	pop	word [es:9*4]
	pop	word [es:9*4+2]
	sti

; --- 6: the controller itself, the V3KBD rungs -----------------------------
	mov	dx,m_t6
	call	puts
	mov	dx,m_cmdb
	call	puts
	mov	al,20h			; read the command byte
	call	kbc_cmd
	call	kbc_get
	jc	.nocmd
	call	hex8
	jmp	short .c1
.nocmd:	mov	dx,m_none
	call	puts
.c1:	call	crlf
	mov	dx,m_self
	call	puts
	mov	al,0AAh			; self-test, expect 55
	call	kbc_cmd
	call	kbc_get
	jc	.noself
	call	hex8
	jmp	short .c2
.noself:	mov	dx,m_none
	call	puts
.c2:	call	crlf
	mov	al,60h			; command byte := 41
	call	kbc_cmd
	mov	al,41h
	call	kbc_data
	mov	al,0AEh			; interface on
	call	kbc_cmd
	mov	dx,m_reset
	call	puts
	mov	al,0FFh			; keyboard reset, expect FA AA
	call	kbc_data
	mov	cx,3
.rr:	call	kbc_get
	jc	.rdone
	call	hex8
	mov	al,' '
	call	putc
	loop	.rr
.rdone:	call	crlf
	mov	dx,m_t6b
	call	puts
	call	count_keys

	mov	ax,4C00h
	int	21h


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 8242 access, bounded by the tick
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kbc_cmd:				; AL to the command port
	push	dx
	mov	dx,KBC_STAT
	jmp	short kbc_put
kbc_data:				; AL to the data port
	push	dx
	mov	dx,KBC_DATA
kbc_put:
	push	ax
	push	cx
	xor	cx,cx
.w:	push	dx
	mov	dx,KBC_STAT
	in	al,dx
	pop	dx
	test	al,2
	loopnz	.w
	pop	cx
	pop	ax
	out	dx,al
	pop	dx
	ret

kbc_get:				; AL = a byte from the controller, CF if none in ~1 s
	push	cx
	push	dx
	push	es
	mov	ax,40h
	mov	es,ax
	mov	cx,[es:6Ch]
.g:	mov	dx,KBC_STAT
	in	al,dx
	test	al,1
	jnz	.got
	mov	ax,[es:6Ch]
	sub	ax,cx
	cmp	ax,18
	jb	.g
	stc
	jmp	short .x
.got:	mov	dx,KBC_DATA
	in	al,dx
	clc
.x:	pop	es
	pop	dx
	pop	cx
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; count_keys -- for ten seconds, take every key INT 16h offers, print
; its word, and count them.  Keys from the serial console count too, so
; leave that alone during the test.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
count_keys:
	push	es
	mov	ax,40h
	mov	es,ax
	xor	bx,bx			; count
	mov	byte [bp_irr],0
	mov	byte [bp_isr],0
	mov	si,[es:6Ch]		; tick at start
.loop:
	mov	al,0Ah			; OCW3: read IRR
	out	20h,al
	in	al,20h
	or	byte [bp_irr],al
	mov	al,0Bh			; OCW3: read ISR
	out	20h,al
	in	al,20h
	or	byte [bp_isr],al
	mov	ah,1
	int	16h
	jz	.idle
	mov	ah,0
	int	16h
	call	hex16
	mov	al,' '
	call	putc
	inc	bx
.idle:
	mov	ax,[es:6Ch]
	sub	ax,si
	cmp	ax,TICKS
	jb	.loop
	call	crlf
	mov	dx,m_count
	call	puts
	mov	ax,bx
	call	hex16
	mov	dx,m_irr
	call	puts
	mov	al,[bp_irr]
	call	hex8
	mov	dx,m_isr
	call	puts
	mov	al,[bp_isr]
	call	hex8
	call	crlf
	pop	es
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; output, all through DOS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
puts:					; DX -> '$'-terminated
	push	ax
	mov	ah,9
	int	21h
	pop	ax
	ret

putc:					; AL
	push	ax
	push	dx
	mov	dl,al
	mov	ah,2
	int	21h
	pop	dx
	pop	ax
	ret

crlf:
	push	ax
	mov	al,13
	call	putc
	mov	al,10
	call	putc
	pop	ax
	ret

hex16:					; AX
	push	ax
	mov	al,ah
	call	hex8
	pop	ax
hex8:					; AL
	push	ax
	push	cx
	mov	cl,4
	mov	ch,al
	shr	al,cl
	call	.digit
	mov	al,ch
	and	al,0Fh
	call	.digit
	pop	cx
	pop	ax
	ret
.digit:
	add	al,'0'
	cmp	al,'9'
	jbe	putc
	add	al,'A'-'9'-1
	jmp	putc


m_banner	db	'KBDIAG -- PS/2 keyboard under DOS',13,10,'$'
m_imr		db	'8259 master mask (bit 1 = IRQ1 masked): $'
m_stat		db	'8242 status (bit 0 = byte waiting):     $'
m_vec		db	'INT 09h vector:                         $'
m_flag		db	'kbd_flag 40:17 $'
m_flag3		db	'  40:96 $'
m_head		db	'  buffer head/tail $'
m_t1		db	13,10,'1. As found.  Type on the PS/2 keyboard for ten seconds:',13,10,'$'
m_t2		db	13,10,'2. IRQ1 unmasked.  Type again:',13,10,'$'
m_t3		db	13,10,'3. 8242 drained (bytes shown).  Type again:',13,10,'$'
m_count		db	'   keys seen: $'
m_t6		db	13,10,'6. The controller under DOS:',13,10,'$'
m_cmdb		db	'   command byte (bit4=1 interface OFF, bit0 IRQ, bit6 translate): $'
m_self		db	'   self-test (55 = an 8042):  $'
m_reset		db	'   interface enabled; keyboard reset says (want FA AA): $'
m_t6b		db	'   Type again:',13,10,'$'
m_none		db	'no reply$'
m_t4		db	13,10,'4. Polling the 8242 directly, no interrupts.  Type again:',13,10,'$'
m_t5		db	13,10,'5. INT 09h vectored straight to the BIOS.  Type again:',13,10,'$'
m_irr		db	'   IRR bits seen: $'
m_isr		db	'   ISR bits seen: $'
m_vec0c		db	'INT 0Ch vector (IRQ4, works):           $'
m_code		db	'first bytes of the INT 09h handler:     $'
bp_irr		db	0
bp_isr		db	0
