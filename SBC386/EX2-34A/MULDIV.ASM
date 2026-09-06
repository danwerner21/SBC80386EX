; muldiv.asm
;
%include "seg_def.inc"
%if 0

#pragma aux remLS "@*" parm caller [dx ax] [bx] value [ax] modify [cx]
word remLS(dword dividend, word divisor);
#pragma aux divLS "@*" parm caller [dx ax] [bx] value [dx ax] modify [cx]
dword divLS(dword dividend, word divisor);
#pragma aux mulLS "@*" parm caller [dx ax] [bx] value [dx ax] modify [cx]
dword mulLS(dword factor1, word factor2);

%endif

segment	CODE

	global	@remLS, @divLS, @mulLS
@remLS:
	div	bx   	;BX is divisor
	mov	ax,dx	;remainder to AX
	ret
@divLS:
	div	bx	;BX is divisor
	xor	dx,dx	;return a long
	ret
@mulLS:
	mov	cx,ax	;save low part of multiplicand
	mov	ax,dx	;high part of multiplicand
	mul	bx	;DX:AX:?? is product
	xchg	cx,ax	;discard DX, product is CX:??
	mul	bx	; DX:AX formed from low word of multiplicand
	add	dx,cx	; DX:AX is the full product
	ret


; do this to shut up WATCOM 1.9
	global	_small_code_, @VIDEO_putchar
_small_code_:
@VIDEO_putchar:
	nop
	ret
