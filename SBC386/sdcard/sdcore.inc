;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sdcore.inc -- the SBC-386EX microSD socket: the SSIO, SPI-mode SD, and
;		reading and writing 512-byte sectors.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.  See SBC386/bios/COPYING.
;
; The routines below are SDTEST 13's (sdtest.asm), which proved them on
; the board, without its diagnostics.  sdtest.asm's comments say how each
; part was found; the short version, for anyone changing them:
;
;   - the card's clock is STXCLK and SRXCLK tied: transmitter master,
;     receiver slave, never both master
;   - CS# (P3.6) is open drain; P3DIR bit 6 must stay set, or 5V reaches
;     the card.  Nothing here writes P3DIR
;   - every burst restarts the baud-rate generator and waits [phd] before
;     starting (genstart): left free running, its phase at the start
;     decides whether the card hears the burst right
;   - twenty bytes of FF go before every command frame
;   - the receive offset is found from R1's first 0 bit, and every byte
;     after it reassembled at that offset
;   - a read -- command, R1, wait, token, data, CRC -- is one burst; so is
;     a write up to its data response
;   - waits are bounded; interrupts are off for each burst
;
; Uses DS = ES = the segment it lives in, and the direction flag clear.
;
; The caller provides nothing; it calls sd_start once, then sd_read and
; wr_sector with sector numbers of the card (not of a partition), secbuf
; holding the data.

SSIOTBUF	equ	0F480h		; write only
SSIORBUF	equ	0F482h		; read only
SSIOBAUD	equ	0F484h		; write only
SSIOCON1	equ	0F486h
SSIOCON2	equ	0F488h
SSIOCTR		equ	0F48Ah		; read only
P3PIN		equ	0F870h
P3LTC		equ	0F872h
P3DIR		equ	0F874h

TUE		equ	80h		; SSIOCON1: transmit underflow
THBE		equ	40h		;  transmit holding buffer empty
TEN		equ	10h		;  transmitter enable
ROE		equ	08h		;  receive overflow
RHBF		equ	04h		;  receive holding buffer full
REN		equ	01h		;  receiver enable
TXM		equ	02h		; SSIOCON2: transmitter master
BEN		equ	80h		; SSIOBAUD: generator enable
SDnCS		equ	40h		; P3.6
SDnCD		equ	02h		; P3.1, low with a card in

; SERCLK is CLK2/4, 10 MHz at 20 MHz; the clock is SERCLK / (2*BV + 2)
BV_SLOW		equ	12		; 385 kHz: initialisation wants < 400

TICKS		equ	6Ch		; BDA timer count, 18.2 a second
PRE		equ	20		; command burst: FFs before the frame
WINLEN		equ	PRE+24		;  then 8 bytes of frame, 16 of window

WHY_OK		equ	0		; [why] after a failure
WHY_R1		equ	1		;  no R1, or not 00
WHY_TOK		equ	2		;  no data token, or not FE
WHY_CRC		equ	3		;  the data's CRC16 is wrong
WHY_SSIO	equ	4		;  a word lost (overflow) or late (underflow)
WHY_SHORT	equ	5		;  the block not all kept
WHY_WRESP	equ	6		;  the write not accepted
WHY_BUSY	equ	7		;  still busy after half a second
WHY_STAT	equ	8		;  CMD13 reported an error

; ssio_init -- stopped, then arrangement [cfg] (TXM or RXM, never both),
; the generator running slow, the receive buffer emptied.
ssio_init:
	mov	dx,SSIOCON1
	xor	al,al			; both off; TUE and ROE cleared
	out	dx,al
	mov	dx,SSIOBAUD
	out	dx,al
	mov	dx,SSIOCON2
	mov	al,TXM			; RXM never: see the top
	out	dx,al
	mov	dx,SSIOBAUD
	mov	al,BEN|BV_SLOW
	mov	[baud],al
	out	dx,al
	mov	dx,SSIORBUF
	in	ax,dx			; clears RHBF
	ret

; wake -- CS high, 160 clocks (a card wants 74) into rawbuf.  CF if the
; SSIO never finished a word.
wake:
	call	cs_high
	xor	si,si
	mov	di,rawbuf
	mov	cx,10
	jmp	spi_xfer

; genstart -- start a burst at a known phase of the clock: the generator
; from reset, [phd] reads of SSIOCTR as a delay, then the transmitter and
; receiver.  The first word must already be in SSIOTBUF.
;
; Why.  The transmitter starts in step with the baud-rate generator, and
; how a burst begins depends on the generator's phase at that instant
; (Intel's figures 12-7 and 12-8).  Free running, that phase is set by
; the time since the last burst: about the same throughout a run, since
; the code repeats, but different from run to run.  v10 shows it: CMD0
; answered in some runs, not at all in others, and a different code path
; (the recovery) turned a good run bad.  Restarting the generator each
; burst makes the phase repeatable; v5 did that with no delay and got a
; bad phase every time.  So step 3 tries delays until CMD0 answers, and
; step 9 does the same at each speed.  All with interrupts off: the delay
; is counted in instructions and must not be stretched.
NPHD		equ	8		; delays tried: 0 to 7 reads
genstart:
	push	cx
	mov	dx,SSIOBAUD
	xor	al,al			; stopped: count cleared
	out	dx,al
	mov	al,[baud]
	out	dx,al			; and from the top
	movzx	cx,byte [phd]
	jcxz	.go
	mov	dx,SSIOCTR
.d:	in	al,dx
	loop	.d
.go:	mov	dx,SSIOCON1
	mov	al,TEN|REN
	out	dx,al
	pop	cx
	ret

; spi_xfer -- move CX words (at least one) through the SSIO, full duplex.
;   SI	the bytes to send, two a word, first byte first; 0 sends FFh
;   DI	where to put the bytes received, the same way; 0 discards them
; Returns AX = the last word received, first byte in AL; CF set if the
; SSIO stopped answering.  Advances SI and DI when they are not 0.
; Clobbers BX, CX, DX.
;
; The transmitter is double buffered: the next word goes into the holding
; buffer while the last one shifts, and the receiver hands over each word
; as it completes.  If the buffer were not refilled in time the
; transmitter would send the old word again and the receiver would lose
; one, so the burst runs with interrupts held off.  The last word is
; followed by a disable, which lets it finish and then stops the clock.
;
; The baud-rate generator runs whether or not the transmitter does, and
; the transmitter starts in step with it, so how a burst begins depends
; on the generator's phase at that moment (Intel's figures 12-7, 12-8).
; One way the card counts an edge the slave receiver does not, and every
; byte comes in a bit early.  Free running, a command burst always gets
; through and its R1 locates the offset (v3, v4); but the offset can
; differ from one burst to the next above 385 kHz (v4), so a data command
; goes in one burst with its data (xact_burst).  Restarting the
; generator for every burst to fix the phase stopped the card hearing
; commands at all (v5), so it runs free.
spi_xfer:
	pushf
	cli
	call	.txword
	mov	dx,SSIOTBUF
	out	dx,ax
	call	genstart
.loop:	dec	cx
	jz	.last
	mov	ah,THBE			; the last word is in the shifter
	call	.wait
	jc	.fail
	call	.txword
	mov	dx,SSIOTBUF
	out	dx,ax
	mov	ah,RHBF			; the last word has come in
	call	.wait
	jc	.fail
	call	.rxword
	jmp	.loop
.last:	mov	ah,THBE
	call	.wait
	jc	.fail
	in	al,dx			; DX = SSIOCON1
	and	al,TUE|ROE
	or	[ssio_err],al		; should never happen; reported if it does
	xor	al,al			; disable: the word in the shifter finishes
	out	dx,al
	mov	ah,RHBF
	call	.wait
	jc	.fail
	call	.rxword
	popf
	clc
	ret
.fail:	mov	dx,SSIOCON1
	xor	al,al
	out	dx,al
	popf
	stc
	ret

.txword:				; AX = the next word to send
	mov	ax,0FFFFh
	or	si,si
	jz	.tx1
	lodsw
	xchg	al,ah			; first byte goes out first: MSB
.tx1:	ret

.rxword:				; AX = the word received, stored
	mov	dx,SSIORBUF
	in	ax,dx
	xchg	al,ah
	or	di,di
	jz	.rx1
	stosw
.rx1:	ret

.wait:					; until SSIOCON1 has bit AH; CF if never
	mov	dx,SSIOCON1
	xor	bx,bx			; 65536 reads: milliseconds
.w1:	in	al,dx
	test	al,ah
	jnz	.w2
	dec	bx
	jnz	.w1
	stc
	ret
.w2:	clc
	ret

; rd_byte -- AL = the next raw byte from the SSIO.  A word brings two; the
; second is kept for the next call.  All else preserved.
rd_byte:
	cmp	byte [held],0
	je	.fresh
	mov	byte [held],0
	mov	al,[heldb]
	ret
.fresh:	push	bx
	push	cx
	push	dx
	push	si
	push	di
	xor	si,si
	xor	di,di
	mov	cx,1
	call	spi_xfer
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	jnc	.ok
	mov	ax,0FFFFh		; a dead SSIO reads as no answer
.ok:	mov	[heldb],ah
	mov	byte [held],1
	ret

; rd_block -- CX raw bytes to DI: a held byte first, then whole words in
; one burst, then a last single byte if CX was odd.  DI advances.
rd_block:
	jcxz	.done
	cmp	byte [held],0
	je	.even
	mov	al,[heldb]
	mov	byte [held],0
	stosb
	dec	cx
.even:	push	cx
	shr	cx,1
	jz	.odd
	push	si
	xor	si,si
	call	spi_xfer
	pop	si
.odd:	pop	cx
	test	cl,1
	jz	.done
	call	rd_byte
	stosb
.done:	ret

; rd_raw -- AL = the next raw byte of the transaction: what is left of
; the command burst's window first, then the SSIO.  All else preserved.
rd_raw:
	push	bx
	movzx	bx,byte [aidx]
	cmp	bl,WINLEN
	jae	.ssio
	mov	al,[win+bx]
	inc	byte [aidx]
	pop	bx
	ret
.ssio:	pop	bx
	jmp	rd_byte

; rd_rawblock -- CX raw bytes of the transaction to DI.  DI advances.
rd_rawblock:
.w:	jcxz	.done
	cmp	byte [aidx],WINLEN
	jae	.rest
	call	rd_raw
	stosb
	dec	cx
	jmp	.w
.rest:	jmp	rd_block
.done:	ret

; rd_abyte -- AL = the card's next byte.  All else preserved.
rd_abyte:
	push	cx
	call	rd_raw			; AL = raw byte j+1
	mov	ah,[la]
	mov	[la],al
	mov	cl,[sbits]
	shl	ah,cl
	neg	cl
	add	cl,8			; 8 - s; a shift of 8 empties AL
	shr	al,cl
	or	al,ah
	pop	cx
	ret

; rd_ablock -- CX of the card's bytes to DI: the raw bytes in one burst
; where they can be, then reassembled.  DI advances.
rd_ablock:
	jcxz	.done
	push	si
	push	di
	push	cx
	mov	di,rawbuf
	call	rd_rawblock
	pop	bx			; BX = count
	pop	di
	push	bx
	mov	si,rawbuf
	mov	cl,[sbits]
	mov	ch,8
	sub	ch,cl
.b:	lodsb				; raw byte j+1
	mov	dl,al
	mov	al,[la]
	mov	[la],dl
	shl	al,cl
	xchg	cl,ch
	shr	dl,cl
	xchg	cl,ch
	or	al,dl
	stosb
	dec	bx
	jnz	.b
	pop	cx
	pop	si
.done:	ret

; cs_low, cs_high -- select and deselect the card.  Open drain: the latch
; bit pulls the line low or lets the pull-up have it; P3DIR is not
; touched.  After deselecting, a word of clocks lets the card let go of
; DO.  The transaction's bytes go with the selection.
cs_low:
	mov	byte [held],0
	mov	byte [aidx],WINLEN
	mov	dx,P3LTC
	in	al,dx
	and	al,~SDnCS
	out	dx,al
	ret

cs_high:
	mov	dx,P3LTC
	in	al,dx
	or	al,SDnCS
	out	dx,al
	push	bx
	push	cx
	push	si
	push	di
	xor	si,si
	xor	di,di
	mov	cx,1
	call	spi_xfer
	pop	di
	pop	si
	pop	cx
	pop	bx
	mov	byte [held],0
	mov	byte [aidx],WINLEN
	ret

; sd_cmd -- send command AL with argument EBX and CRC byte AH (end bit
; included; only CMD0 and CMD8 are checked in SPI mode), and return its
; R1 in AL.  AL = FFh and CF set if no answer started in the window.  The
; card must be selected.  Leaves the transaction positioned after R1, at
; the offset found, for rd_abyte and rd_ablock.
;
; One burst of WINLEN bytes: FF, 40|cmd, the argument big end first, the
; CRC, FF, then sixteen more FFs to clock the answer in.  R1's bit 7 is
; always 0 and the card sends FFs until it answers, so the first 0 bit
; from byte 6 on (an answer can start in byte 7, and arrive a bit early)
; is the top bit of R1.
sd_cmd:
	push	ebx
	push	cx
	push	dx
	push	si
	push	di
	call	mkframe
	mov	si,cmdbuf		; preamble, frame, window
	mov	di,win
	mov	cx,WINLEN/2
	call	spi_burst		; the tight loop: right at any speed
	mov	byte [held],0
	jc	.none
	mov	bx,(PRE+6)*8		; bit number: R1 can start in frame byte 7
.find:	mov	si,bx
	shr	si,3
	mov	al,[win+si]
	mov	cl,bl
	and	cl,7
	shl	al,cl
	test	al,80h
	jz	.found
	inc	bx
	cmp	bx,(WINLEN-6)*8		; room for R1 and lookahead
	jb	.find
.none:	mov	byte [aidx],WINLEN
	mov	byte [sbits],0
	mov	al,0FFh
	stc
	jmp	.out
.found:	mov	al,bl
	and	al,7
	mov	[sbits],al
	shr	bx,3
	mov	al,[win+bx]
	mov	[la],al
	inc	bx
	mov	[aidx],bl
	call	rd_abyte		; R1
	clc
.out:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	ebx
	ret

; mkframe -- command AL, argument EBX, CRC byte AH into the frame: FF,
; 40|cmd, the argument big end first, the CRC, FF.  The FFs before it (the
; preamble) and after it (the window), are never written.  Clears the
; trace and the SSIO error flags.
;
; Why a preamble.  The transmitter starts in step with the free-running
; baud-rate generator; caught high, the clock pin goes from floating low
; straight to high, an edge the card counts -- and DI at that instant is
; still floating, held LOW by R7.  So the card can see a 0 before the
; burst's first bit, takes it for a command's start bit, and swallows the
; next 48 bits as a command of its own: CMD0 went unanswered in v3's first
; run, v5, v7 and v8, card reinserted or not, and was answered in the
; others -- a matter of phase.  Twenty bytes of FF first let any such
; phantom command end, be answered (illegal command) and finish before
; the real frame; the search for R1 starts after the frame, past the
; phantom's answer.
mkframe:
	push	ebx
	mov	byte [ssio_err],0
	mov	byte [frame],0FFh
	or	al,40h
	mov	[frame+1],al
	mov	[frame+6],ah
	mov	byte [frame+7],0FFh
	mov	[frame+5],bl
	mov	[frame+4],bh
	shr	ebx,16
	mov	[frame+3],bl
	mov	[frame+2],bh
	pop	ebx
	ret

; ---- A data command, in one burst --------------------------------------
;
; The command, R1, the wait, the token, the data and its CRC16 all go in
; one burst, so one offset serves the lot: the offset can differ from one
; burst to the next, and a fast card's token can arrive inside the
; command's own window (v6).
;
;   words 0 to WINLEN/2-1	the preamble, the frame and its window: the
;			transmitter refilled from cmdbuf, every word kept in
;			xbuf
;   then		the transmitter left alone -- it repeats its last word,
;			FFFF, an underflow, and exactly what the card wants --
;			and every word read into a ring of RINGW words, until
;			XDATA words after the first that is not FFFF
;
; The ring keeps the last RINGW words in order, so a token that came in
; the window followed by data starting with FFFF loses nothing (v11's
; "ea" at 1 MHz); a long wait for the token only overwrites FFs, whole
; words at a time, which leaves the alignment alone.  rd_xact unrolls the
; ring after the window, oldest first.

XDATA		equ	262		; > 1 + 257 words: token, 512+2 bytes
RINGW		equ	560		; > XDATA + 257: room for all-FF data

; xact_burst -- send cmdbuf, then FFs; keep the window in xbuf and the
; rest in the ring, as above.  [rtot] = words into the ring, [rwp] = where
; the next would have gone.  CF if the SSIO stopped, or nothing but FFFF
; came for CAPMAX words.  Interrupts off.
CAPMAX		equ	30000		; 0.5s at 1 MHz, 0.2s at 2.5
xact_burst:
	push	bp
	pushf
	cli
	mov	si,cmdbuf
	mov	di,xbuf
	lodsw				; word 0 waits in the buffer ...
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	call	genstart		; ... goes to the shifter at enable,
	lodsw				;  and word 1 takes its place
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	mov	bp,WINLEN/2
	; Each word that comes in means the shifter has just taken the word
	; waiting in the buffer: the next goes in at once, and the word in is
	; read while the following one shifts.
.w:	mov	dx,SSIOCON1
	xor	bx,bx			; 65536 polls: a word at any speed
.w1:	in	al,dx
	test	al,RHBF
	jnz	.w2
	dec	bx
	jnz	.w1
	jmp	.fail
.w2:	mov	ax,0FFFFh
	cmp	si,cmdbuf+WINLEN
	jae	.w3
	lodsw
	xchg	al,ah
.w3:	mov	dx,SSIOTBUF
	out	dx,ax
	mov	dx,SSIORBUF
	in	ax,dx
	xchg	al,ah			; first byte first
	stosw
	dec	bp
	jnz	.w
	; The rest: read only.
	mov	di,xring
	xor	bp,bp			; BP = words into the ring
	xor	bx,bx			; BX = BP to stop at, once known
	mov	cx,CAPMAX
.r:	mov	dx,SSIOCON1
	xor	si,si			; 65536 polls (SI is free once the frame
.r1:	in	al,dx			;  is out)
	test	al,RHBF
	jnz	.r2
	dec	si
	jnz	.r1
	jmp	.fail
.r2:	mov	dx,SSIORBUF
	in	ax,dx
	xchg	al,ah
	stosw
	cmp	di,xring+RINGW*2
	jb	.r3
	mov	di,xring
.r3:	inc	bp
	or	bx,bx
	jnz	.r4
	cmp	ax,0FFFFh
	je	.r5
	mov	bx,bp			; the first that is not FFFF
	add	bx,XDATA
.r4:	cmp	bp,bx
	jb	.r
	call	ssio_stop
	mov	[rtot],bp
	mov	[rwp],di
	popf
	clc
	pop	bp
	ret
.r5:	dec	cx
	jnz	.r
	call	ssio_stop		; nothing came
	popf
	stc
	pop	bp
	ret
.fail:	call	ssio_stop
	popf
	stc
	pop	bp
	ret

; ssio_stop -- end a burst: the word shifting finishes, any word waiting
; in the buffer is never sent; that last word read and dropped.  The
; overflow flag is added to [ssio_err] first -- not the underflow flag,
; which a burst ending on a repeated FFFF sets on purpose.
ssio_stop:
	mov	dx,SSIOCON1
	in	al,dx
	and	al,ROE
	or	[ssio_err],al
	xor	al,al
	out	dx,al
	push	cx
	xor	cx,cx
.s1:	in	al,dx
	test	al,RHBF
	jnz	.s2
	loop	.s1
.s2:	pop	cx
	mov	dx,SSIORBUF
	in	ax,dx
	ret

; spi_burst -- send CX words (at least 2) from SI, keeping the CX words
; received at DI; the last word goes out once more as the burst ends, so
; it should be FFFF.  CF if the SSIO stopped.  Interrupts off.
spi_burst:
	push	bp
	pushf
	cli
	mov	bp,cx			; BP = words still to receive
	lodsw
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	call	genstart
	lodsw
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	sub	cx,2			; CX = words still to send
.l:	mov	dx,SSIOCON1
	xor	bx,bx			; 65536 polls: a word at any speed.  (256
.l1:	in	al,dx			;  was too few at 385 kHz: on-chip I/O
	test	al,RHBF			;  is quick, and v12 lost every command)
	jnz	.l2
	dec	bx
	jnz	.l1
	call	ssio_stop
	popf
	stc
	pop	bp
	ret
.l2:	jcxz	.l3
	lodsw
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	dec	cx
	jnz	.l3
	mov	dx,SSIOCON1		; the last word is in: an underflow
	in	al,dx			;  before now was a real one
	and	al,TUE|ROE
	or	[ssio_err],al
.l3:	mov	dx,SSIORBUF
	in	ax,dx
	xchg	al,ah
	stosw
	dec	bp
	jnz	.l
	call	ssio_stop
	popf
	clc
	pop	bp
	ret

; xbits -- AL = the 8 bits of xbuf starting at bit BX.  All else kept.
xbits:
	push	cx
	push	si
	mov	si,bx
	shr	si,3
	mov	cl,bl
	and	cl,7
	mov	ah,[xbuf+si]
	mov	al,[xbuf+si+1]
	shl	ax,cl
	mov	al,ah
	pop	si
	pop	cx
	ret

; rd_xact -- data command AL, argument EBX: CX bytes of data, then its two
; CRC16 bytes, to DI.  AL = R1 (FFh if none).  CF on failure, [why] saying
; which.  Tried again, up to three times, if the block was not kept whole.
rd_xact:
	mov	[xcmd],al
	mov	[xarg],ebx
	mov	[xn],cx
	mov	[xdst],di
	mov	byte [xtries],3
.again:	mov	al,[xcmd]
	mov	ebx,[xarg]
	mov	ah,01h			; CRC: unchecked after CMD8
	call	mkframe
	call	cs_low
	call	xact_burst
	pushf
	call	cs_high
	popf
	jc	.timeout
	call	unroll
	call	find_r1			; BX = its first bit, AL = R1
	jc	.nor1
	or	al,al			; R1 must be 00
	jz	.tok
	mov	byte [why],WHY_R1
	stc
	ret
.tok:	mov	dx,[xlen]		; the token: the first byte after R1, at
	shl	dx,3			;  its offset, that is not FFh
	sub	dx,16
.t:	add	bx,8
	cmp	bx,dx
	jae	.notok
	call	xbits
	cmp	al,0FFh
	je	.t
	mov	[tokb],al
	cmp	al,0FEh
	jne	.badtok
	add	bx,8			; the data's first bit
	mov	ax,[xn]
	add	ax,2			; and its CRC: all of it kept?
	shl	ax,3
	add	ax,bx
	add	ax,8
	mov	dx,[xlen]
	shl	dx,3
	cmp	ax,dx
	ja	.retry
	mov	cx,[xn]
	add	cx,2
	mov	di,[xdst]
	call	xcopy
	xor	al,al			; R1
	test	byte [ssio_err],ROE	; a word lost.  (TUE is expected: the
	jnz	.ssio			;  transmitter repeats FFFF on purpose)
	clc
	ret
.retry:	dec	byte [xtries]
	jnz	.again
	mov	byte [why],WHY_SHORT
	xor	al,al
	stc
	ret
.ssio:	mov	byte [why],WHY_SSIO
	stc
	ret
.notok:	mov	byte [tokb],0FFh
.badtok:
	mov	byte [why],WHY_TOK
	xor	al,al
	stc
	ret
.nor1:	mov	al,0FFh
	mov	byte [why],WHY_R1
	stc
	ret
.timeout:
	mov	byte [why],WHY_TOK
	mov	byte [tokb],0FFh
	test	byte [ssio_err],ROE
	jz	.to1
	mov	byte [why],WHY_SSIO
.to1:	mov	al,0FFh
	stc
	ret

; unroll -- the ring after the window in xbuf, oldest word first; [xlen]
; = the bytes now in xbuf.
unroll:
	mov	di,xbuf+WINLEN
	mov	cx,[rtot]
	cmp	cx,RINGW
	jbe	.lin
	mov	si,[rwp]		; wrapped: rwp to the end, then the start
	mov	cx,xring+RINGW*2
	sub	cx,si
	shr	cx,1
	rep	movsw
	mov	si,xring
	mov	cx,[rwp]
	sub	cx,xring
	shr	cx,1
	rep	movsw
	mov	ax,RINGW
	jmp	.len
.lin:	mov	si,xring
	mov	ax,cx
	rep	movsw
.len:	shl	ax,1
	add	ax,WINLEN
	mov	[xlen],ax
	ret

; find_r1 -- in xbuf: BX = the first 0 bit from frame byte 6 on, AL = the
; 8 bits from there (R1), [sbits] = BX mod 8.  CF if there is none.
find_r1:
	mov	bx,(PRE+6)*8
.r:	call	xbits
	test	al,80h
	jz	.r1
	inc	bx
	cmp	bx,(WINLEN-6)*8
	jb	.r
	stc
	ret
.r1:	mov	ah,bl
	and	ah,7
	mov	[sbits],ah
	clc
	ret

; xcopy -- CX bytes of xbuf from bit BX to DI: a plain copy when BX is on a
; byte, else each byte put together from two.  DI advances.
xcopy:
	mov	si,bx
	shr	si,3
	add	si,xbuf
	mov	ax,bx
	and	al,7
	jnz	.shift
	rep	movsb
	ret
.shift:	mov	dx,cx
	mov	cl,al
.s1:	mov	ah,[si]
	mov	al,[si+1]
	shl	ax,cl
	mov	[di],ah
	inc	si
	inc	di
	dec	dx
	jnz	.s1
	ret

; wr_sector -- secbuf to sector EBX.  CF on failure, [why] saying which.
;
; One burst: the preamble, the CMD24 frame and its window (R1 arrives in
; it), FF FE -- the token, a byte at least after R1 -- the 512 bytes, their
; CRC16, and WRESP bytes of FF in which the card's data response comes.
; R1 locates the offset; the response is the first byte after the CRC, at
; it, that is not FF, and must say "accepted" (xxx0 0101).  Then the card
; holds DO low while it programs, polled in bursts of its own (busy is all
; 0s: the offset does not matter) until a word of FFFF.  Then CMD13, the
; card's status, must be 00 00.
WRESP		equ	8
WTXW		equ	(WINLEN+2+512+2+WRESP)/2
wr_sector:
	mov	byte [why],WHY_OK
	cmp	byte [ccs],0
	jne	.blk
	shl	ebx,9			; byte addressed
.blk:	mov	al,24
	mov	ah,01h
	call	mkframe
	mov	si,cmdbuf		; build the burst
	mov	di,wtx
	mov	cx,WINLEN/2
	rep	movsw
	mov	ax,0FEFFh		; FF, then the token FE
	stosw
	mov	si,secbuf
	mov	cx,256
	rep	movsw
	push	di
	mov	si,secbuf
	mov	cx,512
	call	crc16
	pop	di
	xchg	al,ah			; big end first
	stosw
	mov	ax,0FFFFh
	mov	cx,WRESP/2
	rep	stosw
	call	cs_low
	mov	si,wtx
	mov	di,xbuf
	mov	cx,WTXW
	call	spi_burst
	jc	.ssio
	test	byte [ssio_err],TUE|ROE	; every word out in time (spi_burst looks
	jnz	.ssio			;  until the last is in), none lost
	mov	word [xlen],WTXW*2
	call	find_r1
	jc	.nor1
	or	al,al
	jnz	.badr1
	; the card byte sent while the host sent byte t starts at bit 8t of
	; xbuf, less 8 when the offset is not 0 (it comes a bit early)
	mov	bx,(WINLEN+2+512+2)*8
	movzx	ax,byte [sbits]
	or	ax,ax
	jz	.r0
	sub	bx,8
	add	bx,ax
.r0:	mov	cx,WRESP-2		; (xbits reads a byte ahead)
.dr:	call	xbits
	cmp	al,0FFh
	jne	.resp
	add	bx,8
	loop	.dr
.resp:	mov	[wresp],al
	and	al,1Fh
	cmp	al,05h			; accepted
	jne	.badresp
	call	ticks			; busy
	mov	[t0],ax
.busy:	xor	si,si
	xor	di,di
	mov	cx,1
	call	spi_xfer
	cmp	ax,0FFFFh
	je	.done
	call	ticks
	sub	ax,[t0]
	cmp	ax,10			; half a second
	jb	.busy
	call	cs_high
	mov	byte [why],WHY_BUSY
	jmp	.say
.done:	call	ticks
	sub	ax,[t0]
	mov	[wbusy],ax
	call	cs_high
	call	cs_low			; CMD13: status, R2
	mov	al,13
	xor	ebx,ebx
	mov	ah,01h
	call	sd_cmd
	mov	[wstat],al
	call	rd_abyte
	mov	[wstat+1],al
	call	cs_high
	cmp	word [wstat],0
	jne	.badstat
	clc
	ret
.ssio:	call	cs_high
	mov	byte [why],WHY_SSIO
	jmp	.say
.nor1:	mov	al,0FFh
.badr1:	call	cs_high
	mov	[r1v],al
	mov	byte [why],WHY_R1
	jmp	.say
.badresp:
	call	cs_high
	mov	byte [why],WHY_WRESP
	jmp	.say
.badstat:
	mov	byte [why],WHY_STAT
.say:	stc
	ret

; crcinit -- crctab[b] = the CRC16 of b followed by eight 0 bits.
crcinit:
	mov	di,crctab
	xor	bx,bx
.n:	mov	ah,bl
	xor	al,al
	mov	cx,8
.b:	shl	ax,1
	jnc	.s
	xor	ax,1021h
.s:	loop	.b
	stosw
	inc	bx
	cmp	bx,256
	jb	.n
	ret

; crc16 -- CX bytes at SI: AX = their CRC16-CCITT, x^16 + x^12 + x^5 + 1,
; starting from 0, as an SD data block carries it.  A byte a table entry.
crc16:
	push	bx
	push	cx
	push	dx
	push	si
	xor	dx,dx
.byte:	lodsb
	xor	al,dh
	movzx	bx,al
	shl	bx,1
	mov	dh,dl
	xor	dl,dl
	xor	dx,[crctab+bx]
	loop	.byte
	mov	ax,dx
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret

; ticks -- AX = the low word of the BIOS tick count.
ticks:
	push	es
	push	bx
	xor	bx,bx
	mov	es,bx
	mov	ax,[es:400h+TICKS]
	pop	bx
	pop	es
	ret

; sd_read -- sector EBX of the card to secbuf (512 bytes and 2 of CRC16),
; CRC16 checked.  CF on failure, [why] saying which.
sd_read:
	mov	byte [why],WHY_OK
	cmp	byte [ccs],0
	jne	.blk
	shl	ebx,9			; byte addressed
.blk:	mov	al,17
	mov	di,secbuf
	mov	cx,512			; the data, then its CRC16, big end first
	call	rd_xact
	jc	.x
	mov	si,secbuf
	mov	cx,512
	call	crc16
	xchg	al,ah
	cmp	ax,[secbuf+512]
	je	.ok
	mov	byte [why],WHY_CRC
	stc
.x:	ret
.ok:	clc
	ret

; sd_card -- ZF clear if a card is in the socket.
sd_card:
	push	ax
	push	dx
	mov	dx,P3PIN
	in	al,dx
	not	al
	test	al,SDnCD
	pop	dx
	pop	ax
	ret

; sd_start -- bring the card up from nothing: CF if it would not come.
; Leaves [ccs] (block addressed), [baud] and [phd] for sd_read and
; wr_sector: the fastest of BVLIST at which some start delay reads sector
; 0 correctly, else 385 kHz.
;
; As SDTEST: the start delay is the first at which CMD0 answers 01 twice;
; CMD8 (an SD v2 card echoes 1AA; a v1 card calls it illegal); ACMD41
; until ready, two seconds at most, asking for high capacity if CMD8 was
; taken; CMD58 for CCS; CMD16 512 if the card is byte addressed.
sd_start:
	call	sd_card
	jz	.fail
	call	ssio_init
	call	wake
	mov	byte [phd],0
.ph:	mov	byte [tries],2
.ph1:	call	cs_low
	mov	al,0
	xor	ebx,ebx
	mov	ah,95h			; the CRC CMD0 needs
	call	sd_cmd
	mov	[r1v],al
	call	cs_high
	cmp	byte [r1v],01h
	jne	.phn
	dec	byte [tries]
	jnz	.ph1
	jmp	.phok
.phn:	inc	byte [phd]
	cmp	byte [phd],NPHD
	jb	.ph
	jmp	.fail
.phok:	mov	al,[phd]
	mov	[phd0],al
	call	wake

	mov	byte [hcs],0		; CMD8
	call	cs_low
	mov	al,8
	mov	ebx,1AAh
	mov	ah,87h
	call	sd_cmd
	cmp	al,01h
	jne	.v1
	mov	di,r7
	mov	cx,4
	call	rd_ablock
	call	cs_high
	cmp	word [r7+2],0AA01h	; bytes 01 AA
	jne	.fail
	mov	byte [hcs],1
	jmp	.a41
.v1:	mov	[r1v],al
	call	cs_high
	cmp	byte [r1v],0FFh		; no answer
	je	.fail
	test	byte [r1v],04h		; illegal command: SD v1
	jz	.fail

.a41:	call	ticks			; ACMD41
	mov	[t0],ax
.a1:	call	cs_low
	mov	al,55
	xor	ebx,ebx
	mov	ah,01h
	call	sd_cmd
	mov	[r1v],al
	call	cs_high
	cmp	byte [r1v],01h
	ja	.fail
	call	cs_low
	mov	al,41
	xor	ebx,ebx
	cmp	byte [hcs],0
	je	.a2
	mov	ebx,40000000h		; HCS
.a2:	mov	ah,01h
	call	sd_cmd
	mov	[r1v],al
	call	cs_high
	cmp	byte [r1v],00h
	je	.ocr
	cmp	byte [r1v],01h
	jne	.fail
	call	ticks
	sub	ax,[t0]
	cmp	ax,37
	jb	.a1
	jmp	.fail

.ocr:	call	cs_low			; CMD58
	mov	al,58
	xor	ebx,ebx
	mov	ah,01h
	call	sd_cmd
	cmp	al,00h
	je	.o1
	call	cs_high
	jmp	.fail
.o1:	mov	di,ocr
	mov	cx,4
	call	rd_ablock
	call	cs_high
	mov	byte [ccs],0
	test	byte [ocr],40h
	jz	.sdsc
	mov	byte [ccs],1
	jmp	.speed
.sdsc:	call	cs_low			; CMD16 512
	mov	al,16
	mov	ebx,512
	mov	ah,01h
	call	sd_cmd
	mov	[r1v],al
	call	cs_high
	cmp	byte [r1v],00h
	jne	.fail

.speed:	mov	byte [bvi],0		; the fastest that reads sector 0
.sp:	movzx	bx,byte [bvi]
	mov	al,[bvlist+bx]
	cmp	al,0FFh
	je	.slow
	or	al,BEN
	mov	[baud],al
	mov	byte [phd],0
.sp1:	xor	ebx,ebx
	call	sd_read
	jnc	.ok
	inc	byte [phd]
	cmp	byte [phd],NPHD
	jb	.sp1
	inc	byte [bvi]
	jmp	.sp
.slow:	mov	byte [baud],BEN|BV_SLOW
	mov	al,[phd0]
	mov	[phd],al
.ok:	clc
	ret
.fail:	stc
	ret

; sd_mhz -- AX = the clock in use, in tens of kHz, from [baud].
sd_mhz:
	push	cx
	push	dx
	mov	al,[baud]
	and	ax,7Fh
	shl	ax,1
	add	ax,2			; 2*BV + 2
	mov	cx,ax
	mov	ax,1000			; 10 MHz in tens of kHz
	xor	dx,dx
	div	cx
	pop	dx
	pop	cx
	ret

; ---- Data ----------------------------------------------------------------

bvlist	db	2, 3, 4, 0FFh		; 1.67, 1.25, 1 MHz; fastest first
bvi	db	0
baud	db	BEN|BV_SLOW		; SSIOBAUD for each burst
phd	db	0			; genstart's delay
phd0	db	0			; the one CMD0 liked, at 385 kHz
tries	db	0
held	db	0			; a raw byte is waiting in heldb
heldb	db	0
aidx	db	WINLEN			; next raw byte in win
sbits	db	0			; receive offset, 0-7
la	db	0			; raw byte j: see rd_abyte
hcs	db	0			; the card took CMD8
ccs	db	0			; block addressed
ssio_err db	0
why	db	0
tokb	db	0
r1v	db	0
wresp	db	0
wstat	dw	0
wbusy	dw	0
t0	dw	0
xtries	db	0
xcmd	db	0
xarg	dd	0
xn	dw	0
xdst	dw	0
xlen	dw	0
rtot	dw	0
rwp	dw	0
r7	times 4 db 0
rawbuf	times 32 db 0		; wake's clocks; rd_ablock's raw bytes
ocr	times 4 db 0
cmdbuf	times PRE db 0FFh		; the preamble
frame	times 8 db 0
	times WINLEN-PRE-8 db 0FFh	; the window's clocks
win	times WINLEN db 0
crctab	times 256 dw 0
secbuf	times 520 db 0
wtx	times WTXW*2 db 0FFh
xring	times RINGW*2 db 0FFh
xbuf	times WINLEN+2*RINGW+8 db 0FFh
