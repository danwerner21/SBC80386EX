;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; some useful macros:
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%define NREPEAT 0

%if NREPEAT

%macro	rep	1
%%loop:	%1
	dec	cx
	jnz	%%loop
%endm

%macro	repne	1
%%loop:	%1
	je	%%e
	dec	cx
	jnz	%%loop
	cmp	cx,1
	jmp	%%done
%%e:	dec	cx
	cmp	cx,cx
%%done:
%endm

%macro	repe	1
%%loop:	%1
	jne	%%ne
	dec	cx
	jnz	%%loop
	jmp	%%done
%%ne:	dec	cx
	jcxz	%%cxz
	jmp	%%done
%%cxz:	cmp	cx,1
%%done:
%endm

%macro	REP	1
%%loop:	%1
	dec	ecx
	jnz	%%loop
%endm

%macro	REPNE	1
%%loop:	%1
	je	%%e
	dec	ecx
	jnz	%%loop
	cmp	cl,1
	jmp	%%done
%%e:	dec	ecx
	cmp	cl,cl
%%done:
%endm

%macro	REPE	1
%%loop:	%1
	jne	%%ne
	dec	ecx
	jnz	%%loop
	jmp	%%done
%%ne:	dec	ecx
	jecxz	%%cxz
	jmp	%%done
%%cxz:	cmp	cl,1
%%done:
%endm

%endif


;
; format of the BYTE initialization table:  address, byte
;
%imacro  binit 2
        dw      %1
        db      %2
%endmacro
; end with DW -1

;
; format of the WORD initialization table:  address, word
;
%imacro  winit 2
        dw      %1
        dw      %2
%endmacro
; end with DW -1


; get the BIOS Data Area segment pointer to a [segment] register
%imacro get_bda	1.nolist
	push	0x0040
	pop	%1
	cnop
%endm


; get the Location 0 (Interrupt Descriptor Table) pointer to a register
%imacro	get_loc0 1.nolist
	push	0x0000
	pop	%1
	cnop
%endm



%imacro setloc  1.nolist
 times   (%1-($-$$)) db 0FFh
%endm

%imacro db_lo   1
 db (%1)&255
%endm

%imacro cnop    0.nolist
%ifdef SOFT_DEBUG
%if SOFT_DEBUG
        nop
%endif
%endif
%endm

%imacro popm 1-*.nolist
%rep %0
%ifidni %1,ALL
 popa
%elifidni %1,F
 popf
%else
 pop %1
%ifidni %1,DS
 cnop
%elifidni %1,ES
 cnop
%elifidni %1,FS
 cnop
%elifidni %1,GS
 cnop
%endif
%endif
%rotate 1
%endrep
%endm

%imacro pushm 1-*.nolist
%rep %0
%rotate -1
%ifidni %1,ALL
 pusha
%elifidni %1,F
 pushf
%else
 push %1
%endif
%endrep
%endm

%imacro descr_linear_data 2-3.nolist	; address, size [, E]  E!=0 means expand down
%assign __size__ (%2-1)	| 0xFF
%if (__size__ <= 0xFFFF)
%assign __gran__ 0
%else
%assign __gran__ 0xC0			; G B 0 0
%endif
%assign __expand__ 0
%if %0==3
%if %3
%assign __expand__ 4
%endif
%endif
dd (((%1)&0xFFFF)<<16)|(__size__&0xFFFF)
dd (((%1)>>24)&0xFF)|((__gran__|(__size__>>16)&0x0F)<<16)|((0x93|__expand__)<<8)|(((%1)>>16)&0xFF)
%endm

%imacro descr_linear_code 2-3.nolist	; address, size [,C]  C!=0 means conforming
%assign __size__ (%2-1)	| 0xFF
%if (__size__ <= 0xFFFF)
%assign __gran__ 0
%else
%assign __gran__ 0xC0			; G D 0 0
%endif
%assign __conform__ 0
%if %0==3
%if %3
%assign __conform__ 4
%endif
%endif
dd (((%1)&0xFFFF)<<16)|(__size__&0xFFFF)
dd (((%1)>>24)&0xFF)|((__gran__|(__size__>>16)&0x0F)<<16)|((0x9B|__conform__)<<8)|(((%1)>>16)&0xFF)
%endm

;/* End of macro.inc */
