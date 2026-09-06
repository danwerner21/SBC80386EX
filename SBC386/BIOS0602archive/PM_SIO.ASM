;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; pm_sio.asm -- protected mode serial I/O
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2018 John R. Coffman.  All rights reserved.
; Provided for hobbyist use on the RetroBrew SBC-386EX board.
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program in the file COPYING in the topmost source
; directory.  If not, see <http://www.gnu.org/licenses/>.
;
;
; SBC-386 board revisions:
;       SBC386-0   prototype / concept testing
;	SBC-386EX 2.0	production / January 2018
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/
	bits	32

__lites:		; Protected mode entry
	pushm	dx,ax
        mov     dx,P1LTC        ; get parallel port address
	not	al		; complement bits
	mov	ah,al
	shl	ah,4		; bits to position, zero low 4 bits
	in	al,dx
	and	al,0x0F		; save low bits
	or	al,ah		; set complemented bits
	out	dx,al		; and output
	popm	dx,ax
	ret

__jleds:
	push	edx
	mov	dx,0x4FF	; JRC specific 8 LED display
	out	dx,al
	pop	edx
	ret

;
; output an ASCII_SP to the console
;
__space:
	mov	al,ASCII_SP
	jmp	__putc
;
;
; outc -- write an ASCII 'cooked' character
;       Convert NL to CR,NL
;
__outc:
        cmp     al,ASCII_NL     ; test for NL
        jne     __putc          ; if not, just put out the character
__crlf:
        mov     al,ASCII_CR     ; get a CR
        call    __putc          ; write it out
        mov     al,ASCII_NL     ; restore NL
;
; putc -- put out a character in AL to the SIO0 port
;
__putc:
        push    edx              ; register saves
        push    eax
__putc1:
        mov     edx,LSR0         ; Line Status Register
        in      al,dx
        test    al,LSR_TBE      ; Transmit Buffer Empty
        jz      __putc1

        pop     eax
        mov     dx,TBR0         ; Transmit buffer register
        out     dx,al           ; send the character

        pop     edx              ; register restores
        ret


; test for character waiting for input
;	returns 1 in AL if char waiting
;	returns 0 in AL if no char is waiting
;
__testc:
	push	dx
	mov	dx,LSR0		; Line Status Register
	in	al,dx
	and	al,LSR_RBF	; Receive buffer full
	pop	dx
	ret


__getc:
	push	dx
__getc1:
	mov	dx,LSR0		; Line Status Register
	in	al,dx
	test	al,LSR_RBF	; Receive buffer full
	jz	__getc1

	mov	dx,RBR0		; Receive Buffer
	in	al,dx		; get the character
	pop	dx
	ret

; putstr -- put out ASCII string terminated by NUL
;       ESI points at the string
;
__putstr:
        xor     ah,ah           ; set NUL terminator in AH
;
; gputstr -- general put out an ASCII string
;       ESI points at the string
;       AH is the terminator character, usually NUL
;
__gputstr:
        lodsb                   ; get next character
        cmp     ah,al           ; is it the terminator
        je      __ps9
        call    __outc
        jmp     __gputstr
__ps9:  ret




; Hexadecimal output:
;    Caution:  output routines are destructive of (E)AX
;
; extdword(EAX)
;   word(AX) byte(AL) nibble(AL[3..0])   output
;
__eout: ror     eax,16          ; put out high word first
        call    __wout
        shr     eax,16          ; put out the low word
__wout: xchg    ah,al           ; put out AH first
        call    __bout
        mov     al,ah           ; put out former AL
__bout: push    ax              ; save AL
        shr     al,4            ; position High nibble
        call    __nout            ; write high nibble
        pop     ax
__nout: and     al,0x0F         ; mask low nibble
        daa                     ; divide by 10, AH=quotient, AL=remainder
        add     al,0xF0         ; propagate quotient into the Carry flag
        adc     al,0x40         ; form HEX digit
        jmp     __putc          ; '__putc' does the return

; Decimal output with zeroes suppressed
;  argument is unsigned and in EAX
;
__decout:
	pushm	eax,ecx,edx,ebx
	mov	ebx,10
	xor	ecx,ecx		; count pushes
.2:	xor	edx,edx		;
	div	ebx		; divide by 10
	or	eax,eax		; quotient of Zero indicates done
	jz	.4
	push	edx		; save the digit (remainder)
	inc	cl		; count digits pushed
	jmp	.2
; put out the saved digits
.4:	mov	eax,edx
	call	__nout

	jecxz	.9
	dec	cl
	pop	edx
	jmp	.4

.9:	popm	eax,ecx,edx,ebx
	ret
