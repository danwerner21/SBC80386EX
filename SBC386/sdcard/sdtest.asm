;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sdtest.asm -- bring up the SBC-386EX's on-board microSD socket, one rung
;		at a time, under DOS.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.  See SBC386/bios/COPYING.
;
;	nasm -O9 -f bin -o SDTEST.COM sdtest.asm	(-O9 sizes the jumps)
;
; THE WIRING (Hardware/SBC-386EX-2.0-kicad, SDcard sheet)
;
;   card CLK  <- pins 98 STXCLK and 77 SRXCLK, tied; 2.7K/4.7K divider
;   card DI   <- pin 79 SSIOTX; 2.7K/4.7K divider
;   card DO   -> pin 78 SSIORX; 10K pull-up to the card's 3.3V
;   card CS#  <- pin 86 P3.6, OPEN DRAIN; 10K pull-up to 3.3V, LED D8
;   card CD#  -> pin 75 P3.1, low when a card is in; 10K pull-up to 5V
;
; CS# goes straight from a 5V pin to the card.  P3DIR bit 6 must stay set
; -- open drain, pulled up to 3.3V -- or the card sees 5V; this program
; refuses to run if it is clear and never changes it.
;
; THE SSIO (Intel386 EX User's Manual, 272485, chapter 12)
;
; Words of 16 bits, most significant bit first; no 8-bit mode.  One of
; the transmitter and receiver is master and drives the clock -- STXCLK
; and SRXCLK are tied, and are the card's clock -- and the other is slave,
; clocked from its pin.  NEVER BOTH MASTER: two outputs on one wire.
;
;   TXM	transmitter master, receiver slave (Intel's figure 12-2)
;   RXM	receiver master, transmitter slave (figure 12-3)
;
; THE FIRST RUN (v1, TXM) found the card answering CMD0 -- it took the
; command, so clock, DI and CS work -- but read FE 03 for FF 01: every
; bit one early.  Either the slave receiver samples just after the card
; changes DO, or the clock gains an edge as it floats low at the end of
; each burst (R8 pulls it down).  So this version does not assume an
; alignment, it finds it:
;
;   - a command goes out in one burst with sixteen bytes of response
;     window after it; R1 always has bit 7 clear, so the first 0 bit in
;     the window is where the card's bytes start, and its position mod 8
;     is the receive offset for the rest of the transaction;
;   - every byte after that is reassembled at that offset;
;   - CID, CSD and sectors are checked against their CRC7 and CRC16, so
;     an alignment that changes between bursts shows up as a CRC error
;     rather than as plausible data;
;   - step 3 runs CMD0 in both arrangements and prints what each saw.
;
; Clock: SERCLK (SIOCFG bit 2, set by the BIOS) is CLK2/4, 10 MHz with a
; 20 MHz part, and the generator gives SERCLK / (2*BV + 2):
BV_SLOW		equ	12		; 385 kHz: initialisation wants < 400
; and afterwards the fastest of BV 4..1 (1 to 2.5 MHz) that step 9 finds
; reading reliably: see bvtab.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	cpu	386
	bits	16
	org	100h

SSIOTBUF	equ	0F480h		; write only
SSIORBUF	equ	0F482h		; read only
SSIOBAUD	equ	0F484h		; write only
SSIOCON1	equ	0F486h
SSIOCON2	equ	0F488h
SSIOCTR		equ	0F48Ah		; read only
PINCFG		equ	0F826h
SIOCFG		equ	0F836h
P3PIN		equ	0F870h
P3LTC		equ	0F872h
P3DIR		equ	0F874h

; SSIOCON1
TUE		equ	80h		; transmit underflow
THBE		equ	40h		; transmit holding buffer empty
TEN		equ	10h		; transmitter enable
ROE		equ	08h		; receive overflow
RHBF		equ	04h		; receive holding buffer full
REN		equ	01h		; receiver enable
; SSIOCON2 -- exactly one of these
TXM		equ	02h		; TXMM: transmitter master
RXM		equ	01h		; RXMM: receiver master
; SSIOBAUD
BEN		equ	80h		; generator enable
; port 3
SDnCS		equ	40h		; P3.6
SDnCD		equ	02h		; P3.1

TICKS		equ	6Ch		; BDA timer count, 18.2 a second
PRE		equ	20		; command burst: FFs before the frame (below)
WINLEN		equ	PRE+24		;  then 8 bytes of frame, 16 of window
TRACEMAX	equ	16

%macro	say	1
	mov	dx,%1
	call	puts
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
start:
	cld

	say	m_banner

; ---- 1. The pins, as the BIOS left them ----------------------------------
	say	m_p3dir
	mov	dx,P3DIR
	in	al,dx
	call	hex8
	test	al,SDnCS
	jnz	.p3ok
	say	m_p3bad
	jmp	quit
.p3ok:	say	m_ok

	say	m_pincfg
	mov	dx,PINCFG
	in	al,dx
	call	hex8
	test	al,3			; PM1:0 clear: SRXCLK and SSIOTX
	jz	.pinok
	say	m_pinbad
	jmp	quit
.pinok:	say	m_ok

	say	m_siocfg
	mov	dx,SIOCFG
	in	al,dx
	call	hex8
	test	al,4			; SSBSRC: SERCLK
	jnz	.siook
	say	m_siowarn		; PSCLK: clocks are not as printed
	jmp	.card
.siook:	say	m_ok

.card:	say	m_cd
	mov	dx,P3PIN
	in	al,dx
	call	hex8
	test	al,SDnCD
	jz	.cdok
	say	m_nocard
	jmp	quit
.cdok:	say	m_ok

; ---- 2. The SSIO: wake-up clocks with CS high ----------------------------
	say	m_ssio
	mov	byte [cfg],TXM
	call	ssio_init
	mov	dx,SSIOCTR
	in	al,dx
	call	hex8
	test	al,80h			; BSTAT: generator running
	jnz	.genok
	say	m_genbad
	jmp	quit
.genok:	say	m_ok
	call	wake
	jnc	.wakeok
	say	m_noword
	jmp	quit
.wakeok:
	say	m_wake
	mov	si,rawbuf
	mov	cx,20
	call	hexbytes
	say	m_wakeexp

; ---- 3. CMD0 at each start delay: which phase does the card hear? -------
; Twice at each of NPHD delays (see genstart).  The first delay that
; answers 01 both times is used for the steps that follow, at 385 kHz.
	say	m_align
	mov	byte [cfg],TXM
	mov	byte [split],0
	call	ssio_init
	call	wake
	mov	byte [bestd],0FFh
	mov	byte [dcount],0
.ph:	mov	al,[dcount]
	mov	[phd],al
	say	m_phd
	mov	al,[dcount]
	add	al,'0'
	call	putc
	mov	al,':'
	call	putc
	mov	byte [swok],1
	mov	bp,2
.ph1:	call	cs_low
	mov	al,0
	xor	ebx,ebx
	mov	ah,95h
	call	sd_cmd
	mov	[r1v],al
	call	cs_high
	mov	al,' '
	call	putc
	mov	al,[r1v]
	call	hex8
	mov	al,'/'
	call	putc
	mov	al,[sbits]
	add	al,'0'
	call	putc
	cmp	byte [r1v],01h
	je	.ph2
	mov	byte [swok],0
.ph2:	dec	bp
	jnz	.ph1
	call	crlf
	cmp	byte [swok],0
	je	.ph3
	cmp	byte [bestd],0FFh
	jne	.ph3
	mov	al,[dcount]
	mov	[bestd],al
.ph3:	inc	byte [dcount]
	cmp	byte [dcount],NPHD
	jb	.ph
	cmp	byte [bestd],0FFh
	jne	.svok
	say	m_noalign
	jmp	quit
.svok:	mov	al,[bestd]
	mov	[phd],al
	say	m_phuse
	mov	al,[phd]
	add	al,'0'
	call	putc
	call	crlf
	call	wake

; ---- 4. CMD0: idle ------------------------------------------------------
	say	m_cmd0
	mov	bp,5
.c0:	call	cs_low
	mov	al,0
	xor	ebx,ebx
	mov	ah,95h			; the CRC CMD0 needs
	call	sd_cmd
	push	ax
	call	cs_high
	pop	ax
	cmp	al,01h
	je	.c0ok
	dec	bp
	jnz	.c0
	call	hex8
	say	m_bad
	call	trace
	jmp	quit
.c0ok:	call	hex8
	call	showofs
	say	m_ok

; ---- 5. CMD8: interface condition -- an SD v2 card echoes 1AA ------------
	say	m_cmd8
	mov	byte [hcs],0
	mov	bp,3
.c8try:	call	cs_low
	mov	al,8
	mov	ebx,1AAh
	mov	ah,87h
	call	sd_cmd
	cmp	al,0FFh			; no answer at all: show it, try again
	jne	.c8ans
	push	ax
	call	cs_high
	pop	ax
	call	hex8
	say	m_noans
	call	trace
	dec	bp
	jnz	.c8try
	say	m_bad
	jmp	quit
.c8ans:	call	hex8
	cmp	al,01h
	jne	.c8v1
	mov	di,r7
	mov	cx,4
	call	rd_ablock
	call	cs_high
	mov	al,' '
	call	putc
	mov	si,r7
	mov	cx,4
	call	hexbytes
	cmp	word [r7+2],0AA01h	; bytes 01 AA
	je	.c8ok
	say	m_bad
	call	trace
	jmp	quit
.c8ok:	mov	byte [hcs],1
	say	m_v2
	jmp	.acmd41
.c8v1:	push	ax
	call	cs_high
	pop	ax
	test	al,04h			; illegal command: an SD v1 card
	jnz	.c8old
	say	m_bad
	call	trace
	jmp	quit
.c8old:	say	m_v1

; ---- 6. ACMD41: start initialisation, wait until it finishes -------------
.acmd41:
	say	m_acmd41
	call	ticks
	mov	[t0],ax
.a41:	call	cs_low
	mov	al,55
	xor	ebx,ebx
	mov	ah,01h
	call	sd_cmd
	cmp	al,01h			; idle, or ready
	jbe	.a41b
	push	ax
	call	cs_high
	pop	ax
	call	hex8
	say	m_c55bad
	call	trace
	jmp	quit
.a41b:	push	ax
	call	cs_high
	pop	ax
	call	cs_low
	mov	al,41
	xor	ebx,ebx
	cmp	byte [hcs],0
	je	.a41c
	mov	ebx,40000000h		; HCS: we take high capacity
.a41c:	mov	ah,01h
	call	sd_cmd
	push	ax
	call	cs_high
	pop	ax
	cmp	al,00h
	je	.a41ok
	cmp	al,01h
	jne	.a41bad
	call	ticks
	sub	ax,[t0]
	cmp	ax,37			; two seconds
	jb	.a41
.a41bad:
	call	hex8
	say	m_a41bad
	call	trace
	jmp	quit
.a41ok:	call	ticks
	sub	ax,[t0]
	movzx	eax,ax
	call	dec32
	say	m_a41ok

; ---- 7. CMD58: OCR -- CCS says block or byte addressing -----------------
	say	m_cmd58
	call	cs_low
	mov	al,58
	xor	ebx,ebx
	mov	ah,01h
	call	sd_cmd
	call	hex8
	cmp	al,00h
	je	.c58a
	call	cs_high
	say	m_bad
	call	trace
	jmp	quit
.c58a:	mov	di,ocr
	mov	cx,4
	call	rd_ablock
	call	cs_high
	mov	al,' '
	call	putc
	mov	si,ocr
	mov	cx,4
	call	hexbytes
	mov	byte [ccs],0
	test	byte [ocr],40h
	jz	.sdsc
	mov	byte [ccs],1
	say	m_sdhc
	jmp	.cid
.sdsc:	say	m_sdsc
	call	cs_low			; byte addressed: 512-byte blocks
	mov	al,16
	mov	ebx,512
	mov	ah,01h
	call	sd_cmd
	push	ax
	call	cs_high
	pop	ax
	cmp	al,00h
	je	.cid
	say	m_c16bad
	call	hex8
	call	crlf
	jmp	quit

; ---- 8. CMD10, CMD9: who made it, how big -- the first data blocks -------
.cid:	say	m_cid
	mov	al,10
	mov	di,cid
	call	rd_reg
	jc	quit
	say	m_maker
	mov	al,[cid]
	call	hex8
	say	m_oem
	mov	si,cid+1
	mov	cx,2
	call	ascii
	say	m_name
	mov	si,cid+3
	mov	cx,5
	call	ascii
	call	crlf

	say	m_csd
	mov	al,9
	mov	di,csd
	call	rd_reg
	jc	quit
	call	capacity
	mov	[nsect],eax
	say	m_size
	mov	eax,[nsect]
	call	dec32
	say	m_sectors
	mov	eax,[nsect]
	shr	eax,11			; 2048 sectors a MB
	call	dec32
	say	m_mb

; ---- 9. Each speed, each start delay: sector 0 once ------------------------
; The phase that works depends on the clock, so at each speed every delay
; is tried.  Each entry: result, SSIO flags if they were set, /offset.
; The fastest speed with a delay that read sector 0 is used for step 10,
; at its first such delay; step 10's 256 reads say whether it holds.
	say	m_sweep
	mov	byte [quiet],1
	mov	byte [bestbv],0FFh
	xor	bx,bx
.sw:	push	bx
	mov	al,[bvtab+bx]
	mov	[curbv],al
	or	al,BEN
	mov	[baud],al
	say	m_swhead
	mov	si,bx
	shl	si,1
	mov	dx,[bvname+si]
	call	puts
	mov	byte [curd],0FFh
	mov	byte [dcount],0
.sd:	mov	al,[dcount]
	mov	[phd],al
	xor	ebx,ebx
	call	rd_sector
	movzx	si,byte [why]
	shl	si,1
	mov	dx,[whyname+si]
	call	puts
	cmp	byte [ssio_err],0
	je	.sd1
	mov	al,[ssio_err]
	call	hex8
.sd1:	mov	al,'/'
	call	putc
	mov	al,[sbits]
	add	al,'0'
	call	putc
	mov	al,' '
	call	putc
	cmp	byte [why],0
	jne	.sd2
	cmp	byte [curd],0FFh
	jne	.sd2
	mov	al,[dcount]
	mov	[curd],al
.sd2:	inc	byte [dcount]
	cmp	byte [dcount],NPHD
	jb	.sd
	call	crlf
	pop	bx
	cmp	byte [curd],0FFh
	je	.sw3
	mov	al,[bvtab+bx]		; slowest first: the last good is fastest
	mov	[bestbv],al
	mov	al,[curd]
	mov	[bestd],al
.sw3:	inc	bx
	cmp	bx,NBV
	jb	.sw
	mov	byte [quiet],0
	cmp	byte [bestbv],0FFh
	jne	.swok
	say	m_noswp
	jmp	quit
.swok:	mov	al,[bestbv]
	or	al,BEN
	mov	[baud],al
	mov	al,[bestd]
	mov	[phd],al
	say	m_swuse
	mov	al,[bestbv]
	add	al,'0'
	call	putc
	say	m_swuse2
	mov	al,[phd]
	add	al,'0'
	call	putc
	call	crlf

	say	m_sec0
	xor	ebx,ebx
	call	rd_sector
	jc	quit
	mov	ax,[secbuf+1FEh]
	call	hex16
	call	showofs
	cmp	ax,0AA55h
	je	.sigok
	say	m_nosig
	jmp	.speed
.sigok:	say	m_ok
	mov	si,secbuf+1BEh
	mov	bp,1
.part:	cmp	byte [si+4],0		; type 0: unused
	je	.pnext
	say	m_pent
	mov	ax,bp
	add	al,'0'
	call	putc
	say	m_pboot
	mov	al,[si]
	call	hex8
	say	m_ptype
	mov	al,[si+4]
	call	hex8
	say	m_pstart
	mov	eax,[si+8]
	call	dec32
	say	m_plen
	mov	eax,[si+12]
	call	dec32
	say	m_pmb
	mov	eax,[si+12]
	shr	eax,11
	call	dec32
	say	m_mb
.pnext:	add	si,16
	inc	bp
	cmp	bp,4
	jbe	.part

; ---- 10. How fast: 256 single-sector reads, each CRC checked --------------
.speed:	say	m_speed
	call	ticks
	mov	[t0],ax
	xor	ebx,ebx
.sp:	push	ebx
	call	rd_sector
	pop	ebx
	jc	quit
	inc	ebx
	cmp	ebx,256
	jb	.sp
	call	ticks
	sub	ax,[t0]
	jnz	.spt
	inc	ax
.spt:	mov	[t0],ax
	movzx	eax,ax
	call	dec32
	say	m_ticks
	mov	eax,128*182		; 128 KB, 18.2 ticks a second
	xor	edx,edx
	movzx	ecx,word [t0]
	imul	ecx,ecx,10
	div	ecx
	call	dec32
	say	m_kbs

	say	m_done
	call	ssio_off
	mov	ax,4C00h
	int	21h

quit:	say	m_stop
	call	ssio_off
	mov	ax,4C01h
	int	21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Step 3.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; survey -- CMD0 three times in arrangement [cfg], each line showing the
; raw window and where the answer started.  AL = 2 if all three gave R1
; 01 at offset 0, 1 if all gave 01 at one offset, 0 otherwise.
survey:
	call	ssio_init
	call	wake
	mov	byte [sv_ok],1
	mov	byte [sv_zero],1
	mov	byte [sv_ofs],0FFh
	mov	bp,3
.try:	say	m_svhead
	call	showcombo
	call	cs_low
	mov	al,0
	xor	ebx,ebx
	mov	ah,95h
	call	sd_cmd
	push	ax
	call	cs_high
	pop	ax
	push	ax
	say	m_svr1
	pop	ax
	call	hex8
	cmp	al,01h
	je	.t2
	mov	byte [sv_ok],0
.t2:	call	showofs
	mov	al,[sbits]
	cmp	al,0
	je	.t3
	mov	byte [sv_zero],0
.t3:	cmp	byte [sv_ofs],0FFh
	je	.t4
	cmp	al,[sv_ofs]
	je	.t5
	mov	byte [sv_ok],0		; the offset moved
.t4:	mov	[sv_ofs],al
.t5:	say	m_svwin
	mov	si,win+PRE		; from the frame on
	mov	cx,WINLEN-PRE
	call	hexbytes
	call	crlf
	dec	bp
	jnz	.try
	xor	al,al
	cmp	byte [sv_ok],0
	je	.out
	inc	al
	cmp	byte [sv_zero],0
	je	.out
	inc	al
.out:	ret

; recover -- bring back a card that an earlier run left mid-transfer: a
; card part way through sending a block ignores CMD0 until the block is
; out.  So, selected, clock out more than a block and its CRC; send CMD12,
; which ends a multiple-block read; then deselect.  v3, v5 and v7 each
; began after a run that had stopped part way, and each saw no answer to
; CMD0 until the card was taken out and put back.
recover:
	call	ssio_init
	call	wake
	call	cs_low
	mov	bp,60			; 60 x 10 words: 1200 bytes
.r1:	xor	si,si
	xor	di,di
	mov	cx,10
	call	spi_xfer
	dec	bp
	jnz	.r1
	mov	al,12			; CMD12: stop transmission
	xor	ebx,ebx
	mov	ah,01h
	call	sd_cmd
	xor	si,si			; its busy, if any, and some more
	xor	di,di
	mov	cx,32
	call	spi_xfer
	call	cs_high
	jmp	wake

; showcombo -- which arrangement and burst shape [cfg] and [split] are.
showcombo:
	push	dx
	mov	dx,m_txm
	cmp	byte [cfg],TXM
	je	.s1
	mov	dx,m_rxm
.s1:	call	puts
	mov	dx,m_long
	cmp	byte [split],0
	je	.s2
	mov	dx,m_split
.s2:	call	puts
	pop	dx
	ret

; showofs -- "  @ bit N" for the receive offset just found.
showofs:
	push	ax
	say	m_at
	movzx	eax,byte [sbits]
	call	dec32
	pop	ax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SSIO.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; ssio_init -- stopped, then arrangement [cfg] (TXM or RXM, never both),
; the generator running slow, the receive buffer emptied.
ssio_init:
	mov	dx,SSIOCON1
	xor	al,al			; both off; TUE and ROE cleared
	out	dx,al
	mov	dx,SSIOBAUD
	out	dx,al
	mov	dx,SSIOCON2
	mov	al,[cfg]
	and	al,TXM|RXM
	cmp	al,TXM|RXM		; both: refuse, use TXM
	jne	.one
	mov	al,TXM
.one:	out	dx,al
	mov	dx,SSIOBAUD
	mov	al,BEN|BV_SLOW
	mov	[baud],al
	out	dx,al
	mov	dx,SSIORBUF
	in	ax,dx			; clears RHBF
	ret

; ssio_off -- card deselected, SSIO stopped and back in its reset state.
ssio_off:
	mov	dx,P3LTC
	in	al,dx
	or	al,SDnCS
	out	dx,al
	mov	dx,SSIOCON1
	xor	al,al
	out	dx,al
	mov	dx,SSIOBAUD
	out	dx,al
	mov	dx,SSIOCON2
	out	dx,al
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Raw bytes, on top of words.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The card's bytes: raw bytes reassembled at the offset sd_cmd found.
;
; With offset s, the card's byte j is the low 8-s bits of raw byte j and
; the high s bits of raw byte j+1.  [la] holds raw byte j.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
	push	bx			; keep the first few for trace
	movzx	bx,byte [ntrace]
	cmp	bl,TRACEMAX
	jae	.n1
	mov	[tracebuf+bx],al
	inc	byte [ntrace]
.n1:	pop	bx
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Selection.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SD commands.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
	cmp	byte [split],0
	jne	.split
	mov	cx,WINLEN/2
	call	spi_xfer
	jmp	.sent
.split:	mov	cx,(PRE+8)/2		; preamble and frame alone
	call	spi_xfer
	jc	.sent
	mov	cx,(WINLEN-PRE-8)/2	; then the window, a word a burst
.sp1:	push	cx
	xor	si,si
	mov	cx,1
	call	spi_xfer		; DI advances
	pop	cx
	jc	.sent
	loop	.sp1
.sent:	mov	byte [held],0
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
	mov	byte [ntrace],0
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

; wait_token -- the card's bytes until one is not FFh, for up to half a
; second.  AL = that byte (FEh starts a data block).
wait_token:
	push	bx
	push	cx
	call	ticks
	mov	bx,ax
.w:	mov	cx,256
.w1:	call	rd_abyte
	cmp	al,0FFh
	jne	.got
	loop	.w1
	call	ticks
	sub	ax,bx
	cmp	ax,9
	jb	.w
	mov	al,0FFh
.got:	pop	cx
	pop	bx
	ret

; ---- A data command, in one burst --------------------------------------
;
; v6 read a data block in a burst of its own after the command's, and at
; 385 kHz this card's token arrived inside the command's window: the burst
; that went looking for it found the tail of the CID instead.  So now the
; command, R1, the wait, the token, the data and its CRC16 all go in one
; burst, and one offset serves the lot.  To keep the buffer bounded:
;
;   words 0-11	the frame and its window, always kept
;   then	FFFF words are dropped while waiting -- unless the window
;		already held more than R1, i.e. the token came early
;   then	from the first word that is not FFFF, XDATA words more are
;		kept: the token, the data, the CRC and slack
;
; Dropping whole FFFF words takes 16 bits at a time out of a run of FFs
; and leaves the alignment alone.  The one thing it could break is a token
; that began in the window without the window showing three words that
; are not FFFF: then FFFF data might be dropped.  The parse catches that
; (a token in the window, and words dropped) and the read is tried again.

XDATA		equ	262		; > 1 + 257 words: token, 512+2 bytes

; xact_burst -- send cmdbuf's frame and FFs, keep what comes back in xbuf
; as above.  [xlen] = bytes kept, [xskip] = words dropped.  CF if the SSIO
; stopped, or nothing but FF came for CAPMAX words.  Interrupts off.
CAPMAX		equ	30000		; 0.5s at 1 MHz, 0.2s at 2.5
xact_burst:
	push	bp
	pushf
	cli
	mov	word [xskip],0
	mov	byte [xnff],0
	mov	si,cmdbuf
	mov	di,xbuf
	xor	bp,bp			; BP = the index of the word received
	xor	bx,bx			; BX = the index to stop at, once known
	mov	cx,CAPMAX
	lodsw				; word 0 waits in the buffer ...
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	call	genstart		; ... goes to the shifter at enable,
	lodsw				;  and word 1 takes its place
	xchg	al,ah
	mov	dx,SSIOTBUF
	out	dx,ax
	; Each word that comes in means the shifter has just taken the word
	; waiting in the buffer, so the buffer is free: the next word goes in
	; at once, and the word in is read while the following one shifts --
	; a whole word time for both, and no call in the way.
.loop:	mov	dx,SSIOCON1
	xor	ah,ah			; 256 polls: more than a word at 385 kHz
.w:	in	al,dx
	test	al,RHBF
	jnz	.in
	dec	ah
	jnz	.w
	jmp	.fail
.in:	mov	ax,0FFFFh		; the next word out
	cmp	si,cmdbuf+WINLEN
	jae	.t1
	lodsw
	xchg	al,ah
.t1:	mov	dx,SSIOTBUF
	out	dx,ax
	mov	dx,SSIORBUF		; the word in
	in	ax,dx
	xchg	al,ah			; first byte first
	cmp	bp,WINLEN/2
	jae	.post
	stosw				; the window: always
	cmp	bp,PRE/2+3		; an answer can start in frame word 3
	jb	.next
	cmp	ax,0FFFFh
	je	.next
	inc	byte [xnff]
	jmp	.next
.post:	or	bx,bx
	jnz	.keep
	cmp	ax,0FFFFh
	jne	.start
	cmp	byte [xnff],3		; R1 takes one word or two: three is more
	jae	.start
	inc	word [xskip]		; still waiting: drop it
	dec	cx
	jnz	.next
	call	.stop			; nothing came
	popf
	stc
	pop	bp
	ret
.start:	mov	bx,bp
	add	bx,XDATA
.keep:	stosw
	cmp	bp,bx
	je	.done
.next:	inc	bp
	jmp	.loop
.done:	call	.stop
	mov	ax,di
	sub	ax,xbuf
	mov	[xlen],ax
	popf
	clc
	pop	bp
	ret
.fail:	mov	dx,SSIOCON1
	in	al,dx
	and	al,TUE|ROE
	or	[ssio_err],al
	xor	al,al
	out	dx,al
	popf
	stc
	pop	bp
	ret

.stop:					; one word shifting, one in the buffer:
	mov	dx,SSIOCON1		;  disable, the shifting one finishes,
	in	al,dx			;  the buffered one is never sent
	and	al,TUE|ROE
	or	[ssio_err],al
	xor	al,al
	out	dx,al
	xor	ah,ah
.s1:	in	al,dx
	test	al,RHBF
	jnz	.s2
	dec	ah
	jnz	.s1
.s2:	mov	dx,SSIORBUF
	in	ax,dx
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
; which.  Tried again, up to three times, when the token came too early,
; or too late in the burst, to be kept whole.
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
	mov	bx,(PRE+6)*8		; R1: the first 0 bit from frame byte 6
.r:	call	xbits
	test	al,80h
	jz	.r1
	inc	bx
	cmp	bx,(WINLEN-6)*8
	jb	.r
	mov	al,0FFh
	mov	byte [why],WHY_R1
	stc
	ret
.r1:	mov	ah,bl
	and	ah,7
	mov	[sbits],ah
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
	cmp	bx,WINLEN/2*16		; in the window, with words dropped?
	jae	.tok2
	cmp	word [xskip],0
	jne	.retry
.tok2:	add	bx,8			; the data's first bit
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
.copy:	call	xbits
	stosb
	add	bx,8
	loop	.copy
	xor	al,al			; R1
	cmp	byte [ssio_err],0
	jne	.ssio
	clc
	ret
.retry:	dec	byte [xtries]
	jnz	.again
	mov	byte [why],WHY_EARLY
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
.timeout:
	mov	byte [why],WHY_TOK
	mov	byte [tokb],0FFh
	cmp	byte [ssio_err],0
	je	.to1
	mov	byte [why],WHY_SSIO
.to1:	mov	al,0FFh
	stc
	ret

; why_say -- print what [why] says, with the R1 (AL), token or SSIO flags
; involved.
why_say:
	push	ax
	movzx	si,byte [why]
	shl	si,1
	mov	dx,[whyname+si]
	call	puts
	cmp	byte [why],WHY_R1
	jne	.w1
	say	m_r1is
	pop	ax
	push	ax
	call	hex8
.w1:	cmp	byte [why],WHY_TOK
	jne	.w2
	say	m_tokis
	mov	al,[tokb]
	call	hex8
.w2:	cmp	byte [why],WHY_SSIO
	jne	.w3
	say	m_terr
	mov	al,[ssio_err]
	call	hex8
.w3:	call	showofs
	call	crlf
	pop	ax
	ret

; rd_reg -- CMD9 or CMD10 (AL): sixteen bytes of CSD or CID to DI,
; printed, CRC7 checked.  CF and a message on failure.
rd_reg:
	mov	byte [why],WHY_OK
	push	di
	xor	ebx,ebx
	mov	cx,16			; its CRC16 follows, unchecked: the
	mov	di,regbuf		;  register has its own CRC7
	call	rd_xact
	pop	di
	jc	.bad
	push	di
	mov	si,regbuf
	mov	cx,16
	rep	movsb
	pop	si
	push	si
	mov	cx,16
	call	hexbytes
	call	showofs
	pop	si
	mov	cx,15
	call	crc7
	cmp	al,[si+15]
	jne	.badcrc
	say	m_crcok
	clc
	ret
.badcrc:
	push	ax
	say	m_crcbad
	pop	ax
	call	hex8
	call	crlf
	stc
	ret
.bad:	say	m_bad2
	call	why_say
	stc
	ret

; rd_sector -- sector EBX to secbuf, CRC16 checked.  CF on failure, with
; [why] saying which (WHY_*) and, unless [quiet], a message.
rd_sector:
	mov	byte [why],WHY_OK
	cmp	byte [ccs],0
	jne	.blk
	shl	ebx,9			; byte addressed
.blk:	mov	al,17
	mov	di,secbuf
	mov	cx,512			; the data, then its CRC16, big end first
	call	rd_xact
	jc	.bad
	mov	si,secbuf
	mov	cx,512
	call	crc16
	xchg	al,ah
	cmp	ax,[secbuf+512]
	jne	.badcrc
	clc
	ret
.badcrc:
	mov	byte [why],WHY_CRC
	cmp	byte [quiet],0
	jne	.q
	push	ax
	say	m_dcrcbad
	pop	ax
	xchg	al,ah
	call	hex16
	say	m_dcrcgot
	mov	ax,[secbuf+512]
	xchg	al,ah
	call	hex16
	call	showofs
	call	crlf
	stc
	ret
.bad:	cmp	byte [quiet],0
	jne	.q
	say	m_rdbad
	call	why_say
.q:	stc
	ret

; capacity -- EAX = the card's size in 512-byte sectors, from the CSD.
capacity:
	mov	al,[csd]
	shr	al,6
	cmp	al,1
	je	.v2
	; CSD 1.0: (C_SIZE+1) << (C_SIZE_MULT+2) blocks of 2^READ_BL_LEN
	movzx	eax,byte [csd+6]
	and	al,3
	shl	eax,8
	mov	al,[csd+7]
	shl	eax,2
	movzx	ecx,byte [csd+8]
	shr	cl,6
	or	eax,ecx
	inc	eax			; C_SIZE + 1
	mov	cl,[csd+9]
	and	cl,3
	shl	cl,1
	mov	ch,[csd+10]
	shr	ch,7
	or	cl,ch			; C_SIZE_MULT
	add	cl,2
	shl	eax,cl
	mov	cl,[csd+5]
	and	cl,0Fh			; READ_BL_LEN
	sub	cl,9
	shl	eax,cl			; in 512-byte sectors
	ret
.v2:	; CSD 2.0: (C_SIZE+1) * 512K
	movzx	eax,byte [csd+7]
	and	al,3Fh
	shl	eax,8
	mov	al,[csd+8]
	shl	eax,8
	mov	al,[csd+9]
	inc	eax
	shl	eax,10
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CRCs, as SD uses them.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; crc7 -- CX bytes at SI: AL = the CRC7 shifted left with the end bit, as
; it ends a CID or CSD.  x^7 + x^3 + 1.
crc7:
	push	cx
	push	dx
	push	si
	xor	dl,dl			; the CRC, in bits 6:0
.byte:	lodsb
	mov	dh,8
.bit:	mov	ah,dl
	shl	ah,1			; bit 7 = the CRC's top bit
	xor	ah,al			; ... with the data's
	shl	dl,1
	and	dl,7Fh
	test	ah,80h
	jz	.nx
	xor	dl,09h
.nx:	shl	al,1
	dec	dh
	jnz	.bit
	loop	.byte
	mov	al,dl
	shl	al,1
	or	al,1
	pop	si
	pop	dx
	pop	cx
	ret

; crc16 -- CX bytes at SI: AX = their CRC16-CCITT, x^16 + x^12 + x^5 + 1,
; starting from 0, as an SD data block carries it.
crc16:
	push	cx
	push	dx
	push	si
	xor	dx,dx
.byte:	lodsb
	xor	dh,al
	mov	ah,8
.bit:	shl	dx,1
	jnc	.nx
	xor	dx,1021h
.nx:	dec	ah
	jnz	.bit
	loop	.byte
	mov	ax,dx
	pop	si
	pop	dx
	pop	cx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Output.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

; trace -- what the last command sent and got back, raw, and the card's
; bytes after the offset was found.
trace:
	say	m_tsent
	mov	si,frame
	mov	cx,8
	call	hexbytes
	say	m_tpre
	mov	si,win
	mov	cx,PRE
	call	hexbytes
	say	m_tgot
	mov	si,win+PRE
	mov	cx,WINLEN-PRE
	call	hexbytes
	say	m_tthen
	mov	si,tracebuf
	movzx	cx,byte [ntrace]
	call	hexbytes
	call	showofs
	say	m_terr
	mov	al,[ssio_err]
	call	hex8
	call	crlf
	ret

puts:	push	ax			; DX -> '$'-terminated
	mov	ah,9
	int	21h
	pop	ax
	ret

putc:	push	ax			; AL
	push	dx
	mov	dl,al
	mov	ah,2
	int	21h
	pop	dx
	pop	ax
	ret

crlf:	push	dx
	say	m_crlf
	pop	dx
	ret

hex8:	push	ax			; AL, two digits
	push	ax
	shr	al,4
	call	.dig
	pop	ax
	call	.dig
	pop	ax
	ret
.dig:	and	al,0Fh
	add	al,'0'
	cmp	al,'9'
	jbe	.d1
	add	al,7
.d1:	jmp	putc

hex16:	xchg	al,ah			; AX, four digits
	call	hex8
	xchg	al,ah
	jmp	hex8

hexbytes:				; CX bytes at SI, spaced
	jcxz	.done
	push	ax
.b:	lodsb
	call	hex8
	mov	al,' '
	call	putc
	loop	.b
	pop	ax
.done:	ret

ascii:	lodsb				; CX printable bytes at SI
	cmp	al,20h
	jb	.dot
	cmp	al,7Eh
	jbe	.p
.dot:	mov	al,'.'
.p:	call	putc
	loop	ascii
	ret

dec32:	push	eax			; EAX, unsigned decimal
	push	ecx
	push	edx
	mov	ecx,10
	push	word 0FFFFh		; end marker
.div:	xor	edx,edx
	div	ecx
	push	dx
	or	eax,eax
	jnz	.div
.out:	pop	ax
	cmp	ax,0FFFFh
	je	.end
	add	al,'0'
	call	putc
	jmp	.out
.end:	pop	edx
	pop	ecx
	pop	eax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Messages.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

m_banner db	"SDTEST 11 -- SBC-386EX microSD bring-up",13,10,13,10,"$"
m_ok	db	"  ok",13,10,"$"
m_bad	db	"  FAILED",13,10,"$"
m_crlf	db	13,10,"$"
m_stop	db	13,10,"Stopped.",13,10,"$"
m_done	db	13,10,"All steps passed.",13,10,"$"
m_at	db	"  @ bit $"

m_p3dir	db	"1. P3DIR   (want bit 6 set, CS# open drain)     $"
m_p3bad	db	"  FAILED: CS# would be driven to 5V.  Not touching the card.",13,10,"$"
m_pincfg db	"   PINCFG  (want bits 1:0 clear, SSIO pins)     $"
m_pinbad db	"  FAILED: the pins are SIO1's RTS1#/DTR1#, not the SSIO's",13,10,"$"
m_siocfg db	"   SIOCFG  (want bit 2 set, SSIO from SERCLK)   $"
m_siowarn db	"  bit 2 clear: PSCLK clocks the SSIO, speeds differ",13,10,"$"
m_cd	db	"   P3PIN   (want bit 1 clear, a card is in)     $"
m_nocard db	"  FAILED: no card (P3.1 high)",13,10,"$"

m_ssio	db	"2. SSIOCTR (want bit 7 set, generator running)  $"
m_genbad db	"  FAILED: the baud-rate generator did not start",13,10,"$"
m_wake	db	"   160 clocks, CS# high; got: $"
m_noword db	"  FAILED: the SSIO never completed a word (RHBF stayed clear)",13,10,"$"
m_wakeexp db	13,10,"   (want all FF: DO floats, pulled up)",13,10,"$"

m_align	db	"3. CMD0 twice at each start delay D (want 01 both times)",13,10,"$"
m_phd	db	"   D=$"
m_phuse	db	"   using D=$"
m_svhead db	"   $"
m_txm	db	"TX master/RX slave$"
m_rxm	db	"RX master/TX slave$"
m_long	db	", one burst$"
m_split	db	", split    $"
m_svr1	db	"  R1 $"
m_svwin	db	13,10,"     from the frame: $"
m_noalign db	"  FAILED: no steady R1 01",13,10,"$"
m_using	db	"   using $"
m_flush	db	"   no answer: clocking out any transfer left over, CMD12, then again",13,10,"$"

m_cmd0	db	"4. CMD0    (want R1 01, idle)                   $"
m_cmd8	db	"5. CMD8    (want 01, then 00 00 01 AA)          $"
m_v2	db	"  ok, an SD v2 card",13,10,"$"
m_v1	db	"  illegal command: an SD v1 card",13,10,"$"
m_noans	db	"  no answer$"

m_acmd41 db	"6. ACMD41  (want R1 00, ready, within 2s)       $"
m_c55bad db	"  FAILED: CMD55 refused",13,10,"$"
m_a41bad db	"  FAILED: still not ready",13,10,"$"
m_a41ok	db	" ticks  ok",13,10,"$"

m_cmd58	db	"7. CMD58   (want 00, then the OCR)              $"
m_sdhc	db	"  ok, high capacity: block addressed",13,10,"$"
m_sdsc	db	"  ok, standard capacity: byte addressed",13,10,"$"
m_c16bad db	"  CMD16 (512-byte blocks) refused: $"

m_cid	db	"8. CID     $"
m_maker	db	"   maker $"
m_oem	db	"  OEM $"
m_name	db	"  product $"
m_csd	db	"   CSD     $"
m_crcok	db	"  CRC7 ok",13,10,"$"
m_crcbad db	"  CRC7 BAD, computed $"
m_size	db	"   size $"
m_sectors db	" sectors, $"
m_mb	db	" MB",13,10,"$"

m_sweep	db	"9. Sector 0 once at each speed and each D=0..7 (result/offset)",13,10,"$"
m_swuse	db	"   using BV=$"
m_swuse2 db	" D=$"
m_swhead db	"   $"
m_f4	db	"1 MHz     $"
m_f3	db	"1.25 MHz  $"
m_f2	db	"1.67 MHz  $"
m_f1	db	"2.5 MHz   $"
m_w0	db	"ok$"
m_w1	db	"R1$"
m_w2	db	"tok$"
m_w3	db	"CRC$"
m_w4	db	"SS$"
m_w5	db	"ea$"
m_noswp	db	"  FAILED: no speed read sector 0 three times",13,10,"$"
m_terr	db	"  SSIO TUE/ROE $"
m_sec0	db	"   at the fastest; signature (want AA55)       $"
m_nosig	db	"  no partition table signature",13,10,"$"
m_pent	db	"   partition $"
m_pboot	db	": boot $"
m_ptype	db	" type $"
m_pstart db	" start $"
m_plen	db	" sectors $"
m_pmb	db	" = $"

m_speed	db	"10. 256 single-sector reads, CRC16 checked: $"
m_ticks	db	" ticks, $"
m_kbs	db	" KB/s",13,10,"$"

m_token	db	"  no data token; got $"
m_rdbad	db	13,10,"   read FAILED: $"
m_bad2	db	"  FAILED: $"
m_r1is	db	", R1 $"
m_tokis	db	", got $"
m_dcrcbad db	13,10,"   data CRC16 BAD: computed $"
m_dcrcgot db	", block says $"
m_ovf	db	"  SSIO underflow/overflow during a read, SSIOCON1 bits: $"
m_tsent	db	13,10,"   frame sent:          $"
m_tpre	db	13,10,"   during the preamble: $"
m_tgot	db	13,10,"   from the frame on:   $"
m_tthen	db	13,10,"   card bytes:          $"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Data.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cfg	db	TXM			; SSIOCON2: TXM or RXM
split	db	0			; command and window as separate bursts
quiet	db	0			; rd_sector: no messages
why	db	0			; rd_sector: WHY_*
WHY_OK	equ	0
WHY_R1	equ	1
WHY_TOK	equ	2
WHY_CRC	equ	3
WHY_SSIO equ	4
WHY_EARLY equ	5
whyname	dw	m_w0, m_w1, m_w2, m_w3, m_w4, m_w5
NBV	equ	4
bvtab	db	4, 3, 2, 1		; slowest first
bvname	dw	m_f4, m_f3, m_f2, m_f1
curbv	db	0
phd	db	0			; genstart's delay
bestd	db	0
curd	db	0
dcount	db	0
r1v	db	0
baud	db	BEN|BV_SLOW		; SSIOBAUD for each burst
tokb	db	0			; the byte where a token should be
bestbv	db	0
swok	db	0
sv_ok	db	0
sv_zero	db	0
sv_ofs	db	0
held	db	0			; a raw byte is waiting in heldb
heldb	db	0
aidx	db	WINLEN			; next raw byte in win
sbits	db	0			; receive offset, 0-7
la	db	0			; raw byte j: see rd_abyte
hcs	db	0			; the card took CMD8: ask for high capacity
ccs	db	0			; block addressed
ssio_err db	0
ntrace	db	0
t0	dw	0
nsect	dd	0
cmdbuf	times PRE db 0FFh		; the preamble
frame	times 8 db 0
	times WINLEN-PRE-8 db 0FFh	; the window's clocks
win	times WINLEN db 0
tracebuf times TRACEMAX db 0
r7	times 4 db 0
ocr	times 4 db 0
cid	times 16 db 0
csd	times 16 db 0
secbuf	times 520 db 0
rawbuf	times 540 db 0
regbuf	times 20 db 0
xtries	db	0
xnff	db	0
xskip	dw	0
xlen	dw	0
xcmd	db	0
xarg	dd	0
xn	dw	0
xdst	dw	0
xbuf	times WINLEN+2*XDATA+8 db 0FFh
