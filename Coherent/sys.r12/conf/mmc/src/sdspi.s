/ sdspi.s -- the SSIO bursts of the SBC-386EX microSD driver, sbcsd.c.
/
/	int sdburst (struct sdio *);	send and keep n words
/	int sdxact (struct sdio *);	a read: the window, then a ring
/
/ These are SBC386/sdcard/sdcore.inc's genstart, spi_burst, xact_burst
/ and ssio_stop, which SDTEST 13 and SD.SYS proved on the board; the
/ notes there and in sdtest.asm say why each is as it is.  In short:
/
/   - the card's clock is STXCLK and SRXCLK tied: transmitter master
/     (SSIOCON2 = 2, set by sbcsd.c), receiver slave, never both master
/   - each burst restarts the baud-rate generator and waits sd_phd reads
/     of SSIOCTR before starting: free running, its phase at the start
/     decides whether the card hears the burst right
/   - each word in means the shifter has just taken the one waiting, so
/     the next goes in at once and the word in is read while it shifts
/   - in sdxact, after the window, the transmitter is left to repeat its
/     last word, FFFF -- an underflow, and what the card wants -- and the
/     words in go into a ring until sd_xdata after the first not FFFF
/   - every wait is bounded; interrupts are off for the burst
/
/ Words are moved first byte first: the SSIO sends its most significant
/ bit first, so each word is byte-swapped on the way out and the way in.
/ No string instructions: they would go through ES.  And EBP holds the
/ parameter block, so every reference through it says %ds: -- through
/ EBP the default is SS, and the kernel's stack segment is not its data
/ segment (the first try faulted on the first such store: "stack fault").

		.unixorder

		.text
		.globl	sdburst
		.globl	sdxact
		.globl	sdalign

/ struct sdio, as sbcsd.c declares it
SD_TX		=	0		/ words to send
SD_RX		=	4		/ words received
SD_N		=	8		/ sdburst: words; sdxact: the window's
SD_RING		=	12		/ sdxact: the ring
SD_RINGW	=	16		/  its words
SD_XDATA	=	20		/  words kept after the first not FFFF
SD_CAPMAX	=	24		/  FFFF words to wait at most
SD_BAUD		=	28		/ SSIOBAUD, enable bit and BV
SD_PHD		=	32		/ the start delay
SD_RTOT		=	36		/ out: words into the ring
SD_RWP		=	40		/ out: where the next would have gone
SD_ERR		=	44		/ out: TUE and ROE

SSIOTBUF	=	0xF480
SSIORBUF	=	0xF482
SSIOBAUD	=	0xF484
SSIOCON1	=	0xF486
SSIOCTR		=	0xF48A
TUEROE		=	0x88
ROE		=	0x08
RHBF		=	0x04
TENREN		=	0x11

ARG		=	20		/ after four pushes

/ ---- sdburst ---------------------------------------------------------------
/ Send SD_N words (at least 2) from SD_TX, keep the SD_N received at
/ SD_RX.  The last word goes out once more as the burst ends, so it
/ should be FFFF.  SD_ERR: an underflow before the last word went in, or
/ an overflow at all.  0, or -1 if the SSIO stopped.

sdburst:	push	%ebp
		push	%ebx
		push	%esi
		push	%edi
		movl	ARG(%esp), %ebp
		movl	$0, %ds:SD_ERR(%ebp)
		movl	%ds:SD_TX(%ebp), %esi
		movl	%ds:SD_RX(%ebp), %edi
		pushfl
		cli
		movw	(%esi), %ax		/ word 0 waits in the buffer ...
		addl	$2, %esi
		xchg	%al, %ah
		movl	$SSIOTBUF, %edx
		outw	(%dx)
		call	genstart		/ ... to the shifter at enable,
		movw	(%esi), %ax		/  and word 1 takes its place
		addl	$2, %esi
		xchg	%al, %ah
		movl	$SSIOTBUF, %edx
		outw	(%dx)
		movl	%ds:SD_N(%ebp), %ecx
		pushl	%ecx			/ (%esp) = words still to receive
		subl	$2, %ecx		/ ECX = words still to send

sbloop:		movl	$SSIOCON1, %edx		/ until a word is in
		movl	$65536, %ebx
sbw1:		inb	(%dx)
		testb	$RHBF, %al
		jnz	sbw2
		decl	%ebx
		jnz	sbw1
		jmp	sbfail
sbw2:		orl	%ecx, %ecx		/ the next out, if any
		jz	sbin
		movw	(%esi), %ax
		addl	$2, %esi
		xchg	%al, %ah
		movl	$SSIOTBUF, %edx
		outw	(%dx)
		decl	%ecx
		jnz	sbin
		movl	$SSIOCON1, %edx		/ the last is in: an underflow
		inb	(%dx)			/  before now was a real one
		andb	$TUEROE, %al
		movzxb	%al, %eax
		orl	%eax, %ds:SD_ERR(%ebp)
sbin:		movl	$SSIORBUF, %edx		/ the word in
		inw	(%dx)
		xchg	%al, %ah
		movw	%ax, (%edi)
		addl	$2, %edi
		decl	(%esp)
		jnz	sbloop
		addl	$4, %esp
		call	ssio_stop
		popfl
		subl	%eax, %eax
		jmp	sbret
sbfail:		addl	$4, %esp
		call	ssio_stop
		popfl
		movl	$-1, %eax
sbret:		pop	%edi
		pop	%esi
		pop	%ebx
		pop	%ebp
		ret

/ ---- sdxact -----------------------------------------------------------------
/ A read in one burst: SD_N words from SD_TX (the preamble, frame and
/ window), keeping all SD_N received at SD_RX; then, the transmitter left
/ alone, every word into the ring at SD_RING (SD_RINGW words, wrapping)
/ until SD_XDATA words after the first that is not FFFF.  SD_RTOT and
/ SD_RWP say what the ring holds.  0; -1 if the SSIO stopped; -2 if
/ nothing but FFFF came for SD_CAPMAX words.

sdxact:		push	%ebp
		push	%ebx
		push	%esi
		push	%edi
		movl	ARG(%esp), %ebp
		movl	$0, %ds:SD_ERR(%ebp)
		movl	%ds:SD_TX(%ebp), %esi
		movl	%ds:SD_RX(%ebp), %edi
		pushfl
		cli
		movw	(%esi), %ax
		addl	$2, %esi
		xchg	%al, %ah
		movl	$SSIOTBUF, %edx
		outw	(%dx)
		call	genstart
		movw	(%esi), %ax
		addl	$2, %esi
		xchg	%al, %ah
		movl	$SSIOTBUF, %edx
		outw	(%dx)
		movl	%ds:SD_N(%ebp), %ecx
		pushl	%ecx			/ 4(%esp) = window words to receive
		subl	$2, %ecx
		pushl	%ecx			/ (%esp) = words still to send

xwloop:		movl	$SSIOCON1, %edx
		movl	$65536, %ebx
xww1:		inb	(%dx)
		testb	$RHBF, %al
		jnz	xww2
		decl	%ebx
		jnz	xww1
		jmp	xfail8
xww2:		movl	$0xFFFF, %eax
		cmpl	$0, (%esp)
		je	xww3
		movw	(%esi), %ax
		addl	$2, %esi
		xchg	%al, %ah
		decl	(%esp)
xww3:		movl	$SSIOTBUF, %edx
		outw	(%dx)
		movl	$SSIORBUF, %edx
		inw	(%dx)
		xchg	%al, %ah
		movw	%ax, (%edi)
		addl	$2, %edi
		decl	4(%esp)
		jnz	xwloop
		addl	$8, %esp

		/ The rest: read only, into the ring.
		movl	%ds:SD_RINGW(%ebp), %eax	/ 4(%esp) = the ring's end
		shll	$1, %eax
		addl	%ds:SD_RING(%ebp), %eax
		pushl	%eax
		pushl	$0			/ (%esp) = ESI to stop at, once known
		movl	%ds:SD_RING(%ebp), %edi
		subl	%esi, %esi		/ ESI = words into the ring
		movl	%ds:SD_CAPMAX(%ebp), %ecx
xrloop:		movl	$SSIOCON1, %edx
		movl	$65536, %ebx
xrw1:		inb	(%dx)
		testb	$RHBF, %al
		jnz	xrw2
		decl	%ebx
		jnz	xrw1
		jmp	xfail8
xrw2:		movl	$SSIORBUF, %edx
		inw	(%dx)
		xchg	%al, %ah
		movw	%ax, (%edi)
		addl	$2, %edi
		cmpl	4(%esp), %edi
		jb	xr1
		movl	%ds:SD_RING(%ebp), %edi
xr1:		incl	%esi
		cmpl	$0, (%esp)
		jne	xr2
		cmpw	$0xFFFF, %ax
		je	xr3
		movl	%esi, %edx		/ the first that is not FFFF
		addl	%ds:SD_XDATA(%ebp), %edx
		movl	%edx, (%esp)
xr2:		cmpl	(%esp), %esi
		jb	xrloop
		addl	$8, %esp
		call	ssio_stop
		movl	%esi, %ds:SD_RTOT(%ebp)
		movl	%edi, %ds:SD_RWP(%ebp)
		popfl
		subl	%eax, %eax
		jmp	xret
xr3:		decl	%ecx
		jnz	xrloop
		addl	$8, %esp		/ nothing came
		call	ssio_stop
		popfl
		movl	$-2, %eax
		jmp	xret
xfail8:		addl	$8, %esp
		call	ssio_stop
		popfl
		movl	$-1, %eax
xret:		pop	%edi
		pop	%esi
		pop	%ebx
		pop	%ebp
		ret

/ ---- sdalign --------------------------------------------------------------
/ int sdalign (struct sdal *): AL_N bytes of AL_SRC from bit AL_BIT on, to
/ AL_DST, put together a byte at a time, and their CRC16-CCITT (from 0,
/ by AL_TAB, crctab) returned.  The card's bytes come at an offset and
/ this is where they are set straight: in C, a byte at a time through a
/ function, it took most of a sector's time.  On a byte boundary it is a
/ plain copy that reads nothing past the last byte, so it is safe on a
/ buffer that ends a page; off one, it reads one byte ahead.
/ EBP is only a counter here: nothing is addressed through it.

AL_SRC		=	0
AL_BIT		=	4
AL_DST		=	8
AL_N		=	12
AL_TAB		=	16

sdalign:	push	%ebp
		push	%ebx
		push	%esi
		push	%edi
		movl	ARG(%esp), %eax
		movl	AL_SRC(%eax), %esi
		movl	AL_BIT(%eax), %ecx
		movl	%ecx, %edx
		shrl	$3, %edx
		addl	%edx, %esi
		andl	$7, %ecx
		movl	AL_DST(%eax), %edi
		movl	AL_N(%eax), %ebp
		movl	AL_TAB(%eax), %ebx
		subl	%edx, %edx		/ DX = the CRC
		orl	%ebp, %ebp
		jz	aldone
		orl	%ecx, %ecx
		jz	alcopy
alloop:		movb	(%esi), %ah		/ two bytes, shifted: AH is one
		movb	1(%esi), %al
		incl	%esi
		shlw	%cl, %ax
		movb	%ah, (%edi)
		incl	%edi
		xorb	%dh, %ah		/ CRC = CRC<<8 ^ tab[CRC>>8 ^ byte]
		movzxb	%ah, %eax
		shll	$8, %edx
		shll	$1, %eax
		addl	%ebx, %eax
		xorw	(%eax), %dx
		decl	%ebp
		jnz	alloop
		jmp	aldone
alcopy:		movb	(%esi), %ah		/ on a byte boundary
		incl	%esi
		movb	%ah, (%edi)
		incl	%edi
		xorb	%dh, %ah
		movzxb	%ah, %eax
		shll	$8, %edx
		shll	$1, %eax
		addl	%ebx, %eax
		xorw	(%eax), %dx
		decl	%ebp
		jnz	alcopy
aldone:		movl	%edx, %eax
		andl	$0xFFFF, %eax
		pop	%edi
		pop	%esi
		pop	%ebx
		pop	%ebp
		ret

/ ---- genstart, ssio_stop ---------------------------------------------------
/ genstart: the generator from reset, SD_PHD reads of SSIOCTR, then the
/ transmitter and receiver on.  The first word must be in SSIOTBUF.
/ Clobbers EAX, ECX, EDX.

genstart:	movl	$SSIOBAUD, %edx
		subl	%eax, %eax		/ stopped: count cleared
		outb	(%dx)
		movl	%ds:SD_BAUD(%ebp), %eax	/ and from the top
		outb	(%dx)
		movl	%ds:SD_PHD(%ebp), %ecx
		orl	%ecx, %ecx
		jz	gsgo
		movl	$SSIOCTR, %edx
gsd:		inb	(%dx)
		loop	gsd
gsgo:		movl	$SSIOCON1, %edx
		movb	$TENREN, %al
		outb	(%dx)
		ret

/ ssio_stop: the word shifting finishes, any word waiting is never sent;
/ that last word read and dropped.  The overflow flag first, into SD_ERR
/ -- not the underflow flag, which a burst ending on a repeated FFFF sets
/ on purpose.  Clobbers EAX, ECX, EDX.

ssio_stop:	movl	$SSIOCON1, %edx
		inb	(%dx)
		andb	$ROE, %al
		movzxb	%al, %eax
		orl	%eax, %ds:SD_ERR(%ebp)
		subl	%eax, %eax
		outb	(%dx)
		movl	$65536, %ecx
ssw:		inb	(%dx)
		testb	$RHBF, %al
		jnz	ssr
		loop	ssw
ssr:		movl	$SSIORBUF, %edx
		inw	(%dx)
		ret
