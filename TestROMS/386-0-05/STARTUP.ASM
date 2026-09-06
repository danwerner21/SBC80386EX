;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; startup.asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2017 John R. Coffman.  All rights reserved.
; Provided for hobbyist use on the RetroBrew SBC-386 board.
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
;       [TBA 1.0     production board]
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/


; startup.asm
;
%include "i386EX.inc"
%include "macro.inc"

%imacro  binit 2
        dw      %1
        db      %2
%endmacro

%imacro  winit 2
        dw      %1
        dw      %2
%endmacro

        cpu     386
        bits    16

        org     ROM
origin:

NL      equ     ASCII_NL
NUL     equ     ASCII_NUL

notice:
        db      NL,NL,NL
        db      "RetroBrew Computers : SBC-386 Project",NL
        db      "Intel 80386EX test code 0 of ", __DATE__, " ", __TIME__, NL
        db      "Copyright (C) 2017  John R Coffman.  All rights reserved.",NL
        db      "This program may be used/copied/modified for hobbyist use only.",NL
nl3:    db      NL,NL
        db      NUL

cr0str:
        db      "CR0 = ", NUL

no_fpu: 
        db      "No "
w_fpu:  db      "Math co-processor is present.", NL, NUL

blanks:
	db	"        ",NUL

msgfreq:
	db	NL,"CPU clock = ",NUL
mhz:	db	" mhz",NL,NUL

nv1:
	db	"NVRAM individual writes; individual reads:",NL,NUL
nv2:
	db	"NVRAM burst read:",NL,NUL
nv3:
	db	NL,"NVRAM burst write; individual reads:",NL,NUL
msg99:
	db	NL,"Done.",NL,NUL

btab1:
        binit   PORT92_AT,0x02  ; enable the A20 line

        binit   P1LTC,0x6F      ; LITES (weak)1100 --> 1001 (inverted outputs)
        binit   P1DIR,0xFF-BIT1      ; LITES are O.C., 3,2,0 are inputs
                                ; Next round, RTC_DQ will move to P1.0
        binit   P1CFG, BIT1     ; only RTS0# is connected

        binit   P2LTC,0xFF      ; set all high
        binit   P2DIR,0xA0      ; CTS0# & RXD0 are inputs
        binit   P2CFG,0xFF      ; all are alternate function:
                        ; CTS0, TXD0, RXD0, CS4, CS3, CS2, CS1, CS0

        binit   P3LTC,0xFF-BIT6      ; set all high except
        binit   P3DIR,BIT7+ZBIT6+BIT5+BIT4+BIT3+BIT2+ZBIT1+BIT0
        binit   P3CFG,0xFF -BIT6-BIT1-BIT0  ; 6, 1, 0 are RTC; all to move on next revision

        binit   PINCFG, ZBIT5

TIMER_STOP	equ	BIT6+BIT0 + ZBIT1 + ZBIT3 + ZBIT5 ; stop 0, 1, 2
TIMER_RUN	equ	TIMER_STOP + BIT1 + BIT3	; run counters 0, 1

        binit   TMRCFG, ZBIT7+TIMER_STOP ; bit6: s/w control of GATEn, bit7=0 enables all clocks
		;Timers enabled, 1&2 use PSCLK, 0 uses TMRCLK0 (COMCLK/2)
CTR0 equ ZBIT7+ZBIT6	;select counter 0
CTR1 equ ZBIT7+ BIT6	;select counter 1
CTR2 equ  BIT7+ZBIT6	;select counter 2
CWR01 equ BIT5+BIT4	;Write Count low, then high
MODE0 equ 0
MODE1 equ BIT1
; counter 0 runs at 1.8432mhz / 2  =  921600  (just under 1mhz)
; @20hz, the divisor is 46080 yielding a 50ms time slot
COMCLK	equ	1843200
CLKIN0	equ	COMCLK/2
MS50	equ	CLKIN0 / 20
MS50HI	equ	MS50/256
MS50LO	equ	MS50 & 0xFF

	binit	TMRCON, CTR0 + CWR01 + MODE0 + ZBIT0	;binary
	binit	TMR0, MS50LO	;low byte
	binit	TMR0, MS50HI	;high byte = 46080
	binit	TMRCON, CTR1 + CWR01 + MODE0 + ZBIT0	;binary
	binit	TMR1, 0
	binit	TMR1, 0		; 65536
	binit	TMRCON, CTR2 + CWR01 + MODE0 + ZBIT0	;binary
	binit	TMR2, 0
	binit	TMR2, 0		; 65536

;
; Initialize the Serial output channel 0  (SIO0)
;
        binit   SIOCFG, BIT7+ZBIT6 + BIT2+ZBIT1+ZBIT0
        binit   LCR0, 0x80      ; enable divisor latch
        binit   DLL0, 12        ; 9600 bps
        binit   DLH0, 0         ; **
        binit   LCR0, 3         ; 8-bit, no parity, 1 stop bit
        binit   IER0, 0         ; disable interrupts
        binit   MCR0, 3         ; set RTS & DTR

;;moved down        binit   TBR0, '*'       ;Test output one character

;
; ICU initialization (must be last):
;
	binit   INTCFG, BIT6+ZBIT5+BIT4+BIT3+BIT2+BIT1+ZBIT0

	binit	ICW1S,	BIT4+ ZBIT3 +BIT0	;bit3 0=edge
	binit	ICW2S,	0x70			;INT 70h-77h vectors
	binit	ICW3S,	2			;slave is #2
	binit	ICW4S,	ZBIT4+ZBIT1+BIT0	;no SFNM, no AEOI on slave
	binit	OCW1S,	BIT0			;mask IR8 (INT4=TIMRCLK0)
	binit	OCW3S,	BIT6+ZBIT5+ ZBIT4+BIT3 +BIT1+BIT0 ;disable SMM,

	binit	ICW1M,	BIT4+ ZBIT3 +BIT0	;bit3: 0=edge, 1=level
	binit	ICW2M,	0x08			;INT 8..F vectors
	binit	ICW3M,	BIT2			;slave on IR2 is used
	binit	ICW4M,	ZBIT4+ZBIT1+BIT0	;bit4: SFNM off; bit1: AEOI off
	binit	OCW1M,	BIT3			;mask IR3
	binit	OCW3M,	BIT6+ZBIT5+ ZBIT4+BIT3 +BIT1+BIT0 ;disable SMM,
						; enable read of ISreg


; enable read of ISreg
;  serial character output:
	binit   TBR0, '*'       ;Test output one character

        dw      -1


;
; WORD port initialization table
;
wtab1:
	winit	CLKPRS, 50-2	;PSCLK divider (PSCLK = (CLK2/2) / (denom+2)
			    	;initially divide by 50

	dw	-1		;EOF marker


; enter with SI pointing at the table of BYTES to init.
;
initb:
        pop     cx
initb_:
   cs   lodsw                   ; get destination port
        mov     dx,ax
        inc     ax              ; test for EOF
        jnz     $+4
        jmp     cx              ; EOF, return

   cs   lodsb                   ; get port value
        out     dx,al           ; output port value
        jmp     initb_


; enter with SI pointing at the table of WORDS to init.
;
initw:
        pop     cx
initw_:
   cs   lodsw                   ; get destination port
        mov     dx,ax
        inc     ax              ; test for EOF
        jnz     $+4
        jmp     cx              ; EOF, return

   cs   lodsw                   ; get port value
        out     dx,ax           ; output to word port
        jmp     initw_


;       global  start
start:
        cli
        mov     ax,0x8000
        out     REMAPCFGH,al
        xchg    ah,al
        out     REMAPCFGL,al
        out     REMAPCFG,ax
; Expanded I/O is now available -- ESE bit is set
        cld                     ; do this as insurance (direction=forward)

; Modify the ROM select on the UCS# pin
;
        mov     dx,UCSMSKH      ; high mask
        in      ax,dx           ; read the Reset value
        and     ax,0xFFF0       ; XXXF.XXXX (64K ROM0 should select)
        out     dx,ax           ;
        mov     dx,UCSADL       ; address low
        in      ax,dx           ; read the Reset value
        and     ax,0xFDE2       ; 8-bit, 2 wait states only
        out     dx,ax           ;

; Do the byte port initialization
;
        mov     si,btab1        ; get table address to SI
        mov     cx,return1      ; set return address
        jmp     initb_          ; simulate call
return1:

; Do the word port initialization
;
        mov     si,wtab1        ; get table address to SI
        mov     cx,return2      ; set return address
        jmp     initw_          ; simulate call
return2:



; Enable SRAM select for SBC386-0 on CS4#
;
        mov     dx,CS4ADH       ; high address
        mov     ax,0x0000       ;
        out     dx,ax
        mov     dx,CS4ADL       ; low address
        mov     ax,0x0301       ; 16-bit, Mem, ~Rdy, 1 wait state
        out     dx,ax           ;
        mov     dx,CS4MSKH      ; high mask
        mov     ax,0xFC0F       ; set for 1mb only
        out     dx,ax           ;
        mov     dx,CS4MSKL      ; low mask
        mov     ax,0xFC01       ; 1mb, mask SMM, enable
        out     dx,ax           ;

; Test all bits of the data path into memory
;
        xor     bx,bx           ; will write to location 0
        mov     ds,bx           ; DS=0000
        nop
        mov     es,bx           ; ES=0000
        nop

        mov     cx,32768
mem0:
        mov     ax,1            ; test bit 0
mem1:
        mov     [bx],ax         ; store it
        nop
        nop
        nop
        cmp     ax,[bx]         ; compare to what was written
        jne     patherr
%if 0
        cmp     ah,[bx+1]       ; byte compare
        jne     patherr
        cmp     al,[bx]         ; byte compare
        jne     patherr
%endif
        shl     ax,1            ; test next bit
        jnc     mem1
; the One's test passed

        mov     ax,0xFFFE       ; test zero bit
mem2:
        mov     [bx],ax         ; store it
        nop
        nop
        cmp     ax,[bx]         ; check readback
        jne     patherr
%if 0
        cmp     ah,[bx+1]       ; byte compare
        jne     patherr
        cmp     al,[bx]         ; byte compare
        jne     patherr
%endif
        rol     ax,1
        jnc     mem2
; the Zero bit test passed

        lea     bx,[bx+2]
        loop    mem0

; The BX has incremented by 2*32k, so it is now 0000

        mov     ss,bx           ; set the stack pointer
        mov     sp,0x4000       ; may now use Stack & memory

        push    0xF000
        push    good
        retf                    ; far return to zero bits in hidden CS base

good:
; check presence of FPU
        mov     dx,P1PIN        ; get P1 port status
        in      al,dx           ; P1.3 is co-processor presence detect
        mov     bx,ax           ; save state in BL
; save FPU bit in BL

	mov     al,1            ; show in the lights
        call    lites


        push    cs
        pop     ds

	mov     di,no_fpu

        smsw    ax              ;
        and     bl,BIT3         ; 1=no FPU, 0=with FPU
        jnz     noFPU           ;
; FPU is present
        or      al,CR0_MP       ; set MP bit
        and     al,~CR0_EM      ; clear EM bit
        add     di,(w_fpu-no_fpu) ; change comment
        lmsw    ax              ;
	jmp	$+2
	jmp	$+2

; The following instruction may hang:   Why?
	fninit		; Start FPU initialization
; Note that 'finit' will ALWAYS hand.

        jmp     fpu2

noFPU:
        and     al,~CR0_MP      ; clear MP bit
;	or      al,CR0_EM       ; set EM bit (future with Emulator)
        lmsw    ax              ;
fpu2:


; Display the copyright notice without further ado ...

	mov	si,notice
        call    putstr          ; put out comment

; Display the FPU notice

	mov	si,di 		; FPU info
	call	putstr

        mov     si,cr0str       ; string
        call    putstr
        mov     eax,cr0         ; look at CR0
        call    eout

        mov     si,nl3
        call    putstr

        or      bl,bl           ; test FPU not present
        jnz     fpu5

   es   mov     word [0x600],-1
   es   fnstcw  word [0x600]
   es   mov     ax,[0x600]
        call    wout
        mov     al,NL
        call    outc

        fldpi
        fld1
        fadd
   es   fistp   dword [0x600]
   es   mov     eax,[0x600]
        call    eout
        mov     si,nl3
        call    putstr

; above was skipped if no FPU

fpu5:
        mov     al,2            ; show in the lights
        call    lites

;  Continue with success ('0010') in the LITES


; set values in the NVRAM
	mov	si,nv1		;indiv. wr, indiv. rd
	call	putstr

        xor     cx,cx
wr_nvram1:
        mov     al,cl           ; address
        call    nv_write        ; write address at address
        jc      patherr
        inc     cl
        cmp     cl,31
        jb      wr_nvram1

; now read back the values

        xor     cx,cx
rd_nvram1:
        mov     al,cl           ; get address
        call    nv_read         ; read NVRAM
        jc      patherr

        inc     cl
        call    bout
        mov     al,ASCII_SP
        call    outc
        cmp     cl,31
        jb      rd_nvram1

        mov     al,NL
        call    outc

; now try the burst read

	mov	si,nv2
	call	putstr

        mov     bx,0x600                ; store at 0000:0600
        mov     si,bx

        mov     al,31
        call    nv_read
        jc      patherr

        mov     cx,31
rd_nvram2:
   es   lodsb
        call    bout

        mov     al,ASCII_SP
        call    outc
        loop    rd_nvram2

        mov     al,NL
        call    outc

	mov	si,nv3
	call	putstr

	mov	di,bx
	mov	cx,31
	mov	al,0xFF
wr_nvram3:
   es	stosb			; store byte
   	dec	al
	loop	wr_nvram3

; now the burst write
	mov	al,31
	call	nv_write


        xor     cx,cx
rd_nvram4:
        mov     al,cl           ; get address
        call    nv_read         ; read NVRAM
        jc      patherr

        inc     cl
        call    bout
        mov     al,ASCII_SP
        call    outc
        cmp     cl,31
        jb      rd_nvram4

        mov     al,NL
        call    outc

	mov     al,4
        call    lites

; Try to determine the CPU frequency

	mov	dx,TMRCFG	; Timer control
	mov	al,TIMER_RUN	;start counters 0 & 1
	out	dx,al		; **

	mov	dx,OCW3M
	mov	al,BIT6+ZBIT5+ ZBIT4+BIT3 +BIT1+ZBIT0  ;IRreg
	out	dx,al
wait00:
	jmp	$+2
	jmp	$+2
	jmp	$+2
	in	al,dx		;has an interrupt been generated
	test	al,BIT0		; from Timer 0
	jz	wait00		;Out0 is still low

	mov	dx,TMRCFG
	mov	al,TIMER_STOP	; turn off all the gates
	out	dx,al

	mov	dx,TMR1		; read what is left in timer 1
	in	al,dx		;low byte
	mov	bl,al
	in	al,dx		;high byte
	mov	bh,al
	not	bx		; -count-1

	lea	ax,[bx+500]	; round to nearest integer
	mov	cx,1000
	xor	dx,dx
	div	cx		;integer frequency
	dec	ax
	dec	ax		; divisor is 2 less
	mov	dx,CLKPRS	; pre-scale clock
	out	dx,ax		; PSCLK is now 1.000 mhz (1 usec clock)

;;;	call	bout

	mov	si,msgfreq
	call	putstr

;;;	mov	ax,bx		;
;;;	call	wout

	lea	ax,[bx+5]	; round to 2 decimal places
	xor	dx,dx
	div	cx

	push	dx		;save the remainder
	mov	cx,10
	div	cl
	shl	al,4
	or	al,ah		; form BCD byte
	call	bout
	mov	al,'.'
	call	putc

	pop	ax		;remainder
	xor	dx,dx
	div	cx		;down to 2 digits
	div	cl
	shl	al,4
	or	al,ah
	call	bout

	mov	si,mhz
	call	putstr

	mov	al,8
	call	lites

	mov	si,msg99	;"Done." message
	call	putstr

;  Halt with success ('1000') in the LITES


patherr:
stop:
        hlt
        jmp     $-1

; lites -- enter with new "lites" value in AL
;       uses AX & DX
;
lites:
        not     ax              ; complement bits
        ror     ax,4            ; rotate lites to hi bits of AH
        mov     dx,P1LTC        ; get parallel port address
        in      al,dx           ; get port value
        xor     ah,al           ; xor to AH
        and     ah,0xF0         ; mask bits
        xor     al,ah           ; store in al
        out     dx,al           ; and output
        ret

;
; outc -- write an ASCII 'cooked' character
;       Convert NL to CR,NL
;
outc:
        cmp     al,ASCII_NL     ; test for NL
        jne     putc            ; if not, just put out the character
        mov     al,ASCII_CR     ; get a CR
        call    putc            ; write it out
        mov     al,ASCII_NL     ; restore NL
;
; putc -- put out a character in AL to the SIO0 port
;
putc:
        push    dx              ; register saves
        push    ax
putc1:
        mov     dx,LSR0         ; Line Status Register
        in      al,dx
        test    al,LSR_TBE      ; Transmit Buffer Empty
        jz      putc1

        pop     ax
        mov     dx,TBR0         ; Transmit buffer register
        out     dx,al           ; send the character

        pop     dx              ; register restores
        ret


; putstr -- put out ASCII string terminated by NUL
;       DS:SI points at the string
;
putstr:
        xor     ax,ax           ; set NUL terminator in AH
;
; gputstr -- general put out an ASCII string
;       DS:SI points at the string
;       AH is the terminator character, usually NUL
;
gputstr:
        lodsb                   ; get next character
        cmp     ah,al           ; is it the terminator
        je      ps9
        call    outc
        jmp     gputstr
ps9:    ret




; Hexadecimal output:
; extdword(EAX)
; dword(DX:AX) word(AX) byte(AL) nibble(AL[3..0])   output
;
eout:   ror     eax,16          ; put out high word first
        call    wout
        shr     eax,16          ; put out the low word
        jmp     wout
dout:   xchg    ax,dx           ; put out DX first
        call    wout
        mov     ax,dx
wout:   xchg    ah,al           ; put out AH first
        call    bout
        mov     al,ah           ; put out former AL
bout:   push    ax              ; save AL
        shr     al,4            ; position High nibble
        call    nout            ; write high nibble
        pop     ax
nout:   and     al,0x0F         ; mask low nibble
        daa                     ; divide by 10, AH=quotient, AL=remainder
        add     al,0xF0         ; propagate quotient into the Carry flag
        adc     al,0x40         ; form HEX digit
        jmp     putc            ; 'putc' does the return



%include "ds1302.asm"


        setloc (0x10000-ROM-16)

        align   16

bootstrap:
        jmp     start

