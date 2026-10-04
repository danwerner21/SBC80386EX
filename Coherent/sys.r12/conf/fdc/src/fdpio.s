/ fdpio.s -- the data phase of the SBC-386EX floppy driver, sbcfd.c.
/
/	int fdpioa (int msr, unsigned char *buf, int n, int phase);
/
/ phase is 0xE0 for a read, 0xA0 for a write.  Returns
/	0	all n bytes moved
/	1	the controller went to its result phase early
/	2	it stopped answering
/
/ The FDC9266 has no DMA on this board, and at 500 kbps a byte not taken
/ within 16 microseconds is an overrun (ST1 10).  A C loop through inb()
/ and outb() and busyWait() is too slow for that, so this follows the
/ BIOS's fdcpio.asm: the first byte -- up to a revolution away -- waited
/ for with interrupts as the caller left them, then the burst with them
/ off.  The kernel runs at IOPL 1, so cli is allowed.
/
/ MSR is matched under the mask E0:
/	E0	read data wants collecting
/	A0	write data wants feeding
/	C0	the result phase: the command has ended

		.unixorder

		.text
		.globl	fdpioa

msr		=	12			/ after two pushes
buf		=	16
cnt		=	20
phase		=	24

fdpioa:		push	%ebx
		push	%esi
		movl	msr(%esp), %edx
		movl	buf(%esp), %esi
		movl	cnt(%esp), %ecx
		movb	phase(%esp), %ah

		movl	$1000000, %ebx		/ more than a revolution
fpwait1:	inb	(%dx)
		andb	$0xE0, %al
		cmpb	%ah, %al
		je	fpburst
		cmpb	$0xC0, %al
		je	fpshort
		decl	%ebx
		jnz	fpwait1
		movl	$2, %eax
		jmp	fpret
fpshort:	movl	$1, %eax
		jmp	fpret

fpburst:	pushfl
		cli
fpnext:		incl	%edx			/ the data register
		cmpb	$0xA0, %ah
		je	fpwr
		inb	(%dx)
		movb	%al, (%esi)
		jmp	fpstep
fpwr:		movb	(%esi), %al
		outb	(%dx)
fpstep:		incl	%esi
		decl	%edx			/ back to MSR
		decl	%ecx
		jz	fpdone

		movl	$65536, %ebx		/ far longer than 16us
fpwait2:	inb	(%dx)
		andb	$0xE0, %al
		cmpb	%ah, %al
		je	fpnext
		cmpb	$0xC0, %al
		je	fpcut
		decl	%ebx
		jnz	fpwait2
		movl	$2, %ebx
		jmp	fpout
fpcut:		movl	$1, %ebx
		jmp	fpout
fpdone:		subl	%ebx, %ebx
fpout:		popfl
		movl	%ebx, %eax

fpret:		pop	%esi
		pop	%ebx
		ret
