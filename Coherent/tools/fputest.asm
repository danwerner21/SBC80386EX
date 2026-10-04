; fputest.asm -- exercise the 80387 under DOS, the way COHERENT's probe does.
;
;	nasm -f bin -o FPUTEST.COM fputest.asm
;
; Each line prints a result in hex with the value a working 387 gives.
; Steps 1-2 are what the SBC BIOS already checks (presence).  Steps 3-4
; are ordinary arithmetic.  Step 5 is the exact sequence in COHERENT's
; ndpSense() that faulted on the SBC: 1.0/0.0 with exceptions masked,
; then comparing +infinity with -infinity.  If the program stops partway,
; the last line printed says where.  The two db lines are the exact
; bytes of the kernel's fdivp and fld, whatever an assembler prefers.

	org	0x100

start:	mov	dx, s_hdr
	call	puts

	mov	word [w], 0xFFFF	; 1. FNINIT clears the status word
	fninit
	fnstsw	[w]
	mov	dx, s_1
	call	puts
	mov	ax, [w]
	call	hexw

	fnstcw	[w]			; 2. default control word
	mov	dx, s_2
	call	puts
	mov	ax, [w]
	call	hexw

	fild	word [two]		; 3. 2 + 3
	fiadd	word [three]
	fistp	word [w]
	fwait
	mov	dx, s_3
	call	puts
	mov	ax, [w]
	call	hexw

	fild	word [n355]		; 4. 355 / 113 * 10000 = 31416
	fidiv	word [n113]
	fimul	word [n10000]
	fistp	word [w]
	fwait
	mov	dx, s_4
	call	puts
	mov	ax, [w]
	call	hexw

	mov	dx, s_5a		; 5. COHERENT's probe
	call	puts
	fld1
	fldz
	db	0xDE, 0xF9		; fdivp st(1),st: +inf, divide-by-zero masked
	db	0xD9, 0xC0		; fld st(0)
	fchs				; -inf
	fcompp
	fstsw	[w]
	fwait
	mov	dx, s_5
	call	puts
	mov	ax, [w]
	call	hexw

	mov	dx, s_done
	call	puts
	mov	ax, 0x4C00
	int	0x21

puts:	mov	ah, 9			; print $-terminated string at DX
	int	0x21
	ret

hexw:	push	cx			; print AX as 4 hex digits, then CR LF
	push	dx
	mov	cx, 4
hexl:	rol	ax, 4
	push	ax
	and	al, 0x0F
	add	al, '0'
	cmp	al, '9'
	jbe	hexp
	add	al, 7
hexp:	mov	dl, al
	mov	ah, 2
	int	0x21
	pop	ax
	loop	hexl
	mov	dl, 0x0D
	mov	ah, 2
	int	0x21
	mov	dl, 0x0A
	int	0x21
	pop	dx
	pop	cx
	ret

w:	dw	0
two:	dw	2
three:	dw	3
n355:	dw	355
n113:	dw	113
n10000:	dw	10000

s_hdr:	db	'FPU test -- COHERENT ndpSense() sequence', 13, 10, '$'
s_1:	db	'1. status after FNINIT    (want 0000): $'
s_2:	db	'2. control word           (want 037F): $'
s_3:	db	'3. 2 + 3                  (want 0005): $'
s_4:	db	'4. 355/113 x 10000        (want 7AB8): $'
s_5a:	db	'5. 1/0, -inf, compare ... $'
s_5:	db	'status (want C3 clear, 4000 bit off): $'
s_done:	db	'done', 13, 10, '$'
