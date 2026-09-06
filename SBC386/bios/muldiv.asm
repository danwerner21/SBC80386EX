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

segment	_TEXT

%if 0
	global	@remLS, @divLS, @mulLS
@remLS:
	div	bx   	;BX is divisor
	mov	ax,dx	;remainder to AX
	ret
@divLS:
	mov	cx,ax	;save low part of dividend
	mov	ax,dx	; high part of dividend to 00:AX
	xor	dx,dx
	div	bx	;BX is divisor
	xchg	ax,cx	; save high Quotient in CX
	div	bx	; divide hi-rem & low dividend
	mov	dx,cx	;DX:AX is quotient
	ret
@mulLS:
	mov	cx,ax	;save low part of multiplicand
	mov	ax,dx	;high part of multiplicand
	mul	bx	;DX:AX:?? is product
	xchg	cx,ax	;discard DX, product is CX:??
	mul	bx	; DX:AX formed from low word of multiplicand
	add	dx,cx	; DX:AX is the full product
	ret


%else




%if 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  C-callable:
;       dword __fastcall divLS(dword dividend, word divisor);
;
;       double word  divided by  word
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        global  divLS_
divLS_:
        ; DX:AX is dividend
        ; BX is divisor
        or      dx,dx
        jnz     .3
        div     bx
        xor     dx,dx
        ret

.3:     mov     cx,ax           ; save low dividend in CX
        mov     ax,dx
        xor     dx,dx           ; 0:DX div BX
        div     bx
        xchg    cx,ax           ; CX is high quotient
        div     bx
        mov     dx,cx
        ret

%if 0
;;;%ifndef HAS_FASTCALL
        global  _divLS
_divLS: push    bp
        mov     bp,sp
        mov     ax,ARG(1)
        mov     dx,ARG(2)
        mov     bx,ARG(3)
        call    @divLS
        leave
        ret

        global  _remLS
_remLS: push    bp
        mov     bp,sp
        mov     ax,ARG(1)
        mov     dx,ARG(2)
        mov     bx,ARG(3)
        call    @remLS
        leave
        ret
%endif
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  C-callable:
;       word __fastcall remLS(dword dividend, word divisor);
;
;       remainder of:
;       double word  divided by  word
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        global  remLS_
remLS_:
        ; DX:AX is dividend
        ; BX is divisor
        or      dx,dx
        jz      .5
        mov     cx,ax           ; save low dividend in CX
        mov     ax,dx
        xor     dx,dx           ; 0:DX div BX
        div     bx              ; discard quotient in AX
        mov     ax,cx           ; restore low dividend
.5:     div     bx
        mov     ax,dx           ; remainder to AX
        ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  C-callable:
;       dword __fastcall mulLS(dword factor1, word factor2);
;
;       double word  multiplied by  word
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	mulLS_
mulLS_:
	; DX:AX is factor1
	; BX is factor2
        or      dx,dx
        jnz     .1		; dx != 0
        mul     bx
        ret
.1:     mov     cx,ax           ; save low part of factor1 in CX
        mov     ax,dx
        mul     bx
        xchg    cx,ax           ; CX is a product of high part of factor1 and factor2
        mul	bx
        add     dx,cx
        ret
%endif




%endif
