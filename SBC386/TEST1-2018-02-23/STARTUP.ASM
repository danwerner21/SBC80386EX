;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; startup.asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2017,2018 John R. Coffman.  All rights reserved.
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
%define SOFT_DEBUG 1		; for 'cnop' macro
%define wFPU	1
%define HALF_MEM 1		; 1 = exclude DRAM that overlaps the ROM
				; 0 = DRAM & ROM overlap
%define SHADOW_MODE 1		; shadow ROM in DRAM
%define	PATT 41			; 41, 37, 33

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

        org     ROM	; at 0x000F0000 at the moment
origin:

NL      equ     ASCII_NL
NUL     equ     ASCII_NUL

notice:
        db      NL,NL,NL
        db      "RetroBrew Computers : SBC-386EX 2.0 Project",NL
        db      "Intel 80386EX test code 1 of ", __DATE__, " ", __TIME__, NL
        db      "Copyright (C) 2017,2018 John R Coffman.  All rights reserved.",NL
        db      "This program may be used/copied/modified for hobbyist use only.",NL,NL
	db	"Released under the GNU General Puplic License, Version 3 of 29 June 2007,",NL
	db	"See the file COPYING in the top level source directory, or 'http://www.gnu.org'.",NL
nl2:    db      NL,NL
        db      NUL

cr0str:
        db      "CR0 = ", NUL
ucsad:	db	"    UCSAD = ", NUL
ucsmsk:	db	"  UCSMSK = ", NUL

%if wFPU
no_fpu: 
        db      "No "
w_fpu:  db      "Math co-processor is present.", NL, NUL
w_fpu2:	db	" >fninit failure<", ASCII_CR, NUL

fpu_ini:
	db	"Math co-processor initialization:    Fstsw = ", NUL
fpu_comp:
	db	"   INT(pi+1) = ", NUL
%endif

blanks:
	db	"        ",NUL
msg_card:
	db	"No "
	db	"Micro SD card is present in the socket.  (If the card is not present,",NL
	db	"the activity LED should be ON when you continue.)",NL,NUL


msgfreq:
	db	NL,"CPU clock = ",NUL
mhz:	db	" mhz",NL,NUL

nv1:
	db	"NVRAM individual writes; individual reads:",NL,NUL
nv2:
	db	"NVRAM burst read:",NL,NUL
nv3:
	db	NL,"NVRAM burst write; individual reads:",NL,NUL
jrc_sw:
	db	"(JRC) $4FF switch setting = ",NUL
msg_vga3:
	db	"VGA3 indirect r/w (XIO) ",NUL
msg_fail:
	db	"failed.",NL,NUL
msg_succ:
	db	"succeeded.",NL,NUL
msg_vga3_2:
	db	"VGA3 direct memory readback (XMEM) ",NUL
msg_vga3_3:
	db	"VGA3 direct memory r/w (XMEM) ",NUL
msg_vga3_4:
	db	"VGA3 indirect readback (XIO) ",NUL
msg_dram1:
	db	NL,"Priming the DRAM ...",NL, NUL
msg_dram2:
	db	NL,"Testing the DRAM -- errors will be printed on-screen",NL
	db	"Shadow BIOS will be enabled.  The ROM and SRAM chips will be disabled.",NL
	db	"Hit any key to skip test, <ESC> to terminate ...", NL, NUL
msg_prot:
	db	NL,"Leaving Real Mode, entering Protected Mode.", NL
	db	"There are "
%if PATT==33
	db	"33"
%elif PATT==37
	db	"37"
%elif PATT==41
	db	"41"
%else
	db	"XX"
%endif
	db	" major countdown sequences in the Extended Memory test.",NL
	db	"  Be patient.         (64Mb @ 33mhz = 27min.)",NL,NUL

msg_real:
	db	"Left Protected Mode, returned to Real Mode.", NL, NUL
msg_size:
	db	"Mb memory installed.      ",NUL
msg_640K_1bit:
	db	NL,"Test 640K individual data bit paths:  ",NUL
msg_errors:
	db	" error(s) encountered.",NL,NUL
msg_63M_1bit:
	db	"Test same in Memory>1Meg (very  l..o..n..g  test):  ",NUL
msg_rot41:
	db	"Test 41-bit rotating pattern (27 min.):  ",NUL
msg_hi_err:
	db	"h error(s) in Extended Memory.",NL,NUL

msg99:
	db	"Done.",NL,NUL

btab1:
        binit   PORT92_AT,0x02  ; enable the A20 line

;    LITES[3:0], DSRST, DSCLK, RTS0#, DSDAT
        binit   P1LTC, 0x6F	; LITES (weak)1100 --> 1001 (inverted outputs)
	binit	P1DIR, 0x00+DSDAT	; LITES (7..4) are DRIVEN now, DSDAT is input
        binit   P1CFG, BIT1     ; RTS0# is connected to SIO0

; for the WATCHDOG timer bus monitor READY function
;;;;	binit	PWRCON, BIT3	; WDTRDY bit enable

;    CTS0, TXD0, RXD0, CS4, CS3, CS2, CS1, CS0
        binit   P2LTC,0xFF      ; set all high
        binit   P2DIR,0xA0      ; CTS0# & RXD0 are inputs
        binit   P2CFG,0xFF      ; all are alternate function:

;    COMCLK, SD-CS#, IR7, IR6, IR5, IR1, SD-CD#, PEREQ(sense)	
	binit   P3LTC,0xFF      ; set all high
        binit   P3DIR,0xFF	; all are O.C. or inputs
        binit   P3CFG,BIT7+ ZBIT6 +BIT5+BIT4+BIT3+BIT2 +ZBIT1+ZBIT0
; move to SDcard codes, later
;
SDLTC	equ	P3LTC		;Latch (output) port for SDcard bits
SDPIN	equ	P3PIN		;Pin (input) value for port
SDnCS	equ	BIT6		;'not' Chip Select
SDnCD	equ	BIT1		;'not' Card Detect


        binit   PINCFG, BIT6+ZBIT5+ZBIT4+ZBIT3+ZBIT2+ZBIT1+ZBIT0

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
COMCLK	equ	1843200		; standard 1.8432mhz oscillator
BAUD	equ	9600		; default SIO0 bit rate
DIVISOR	equ	COMCLK/16/BAUD	; SIO0 divisor to achieve BAUD rate
CLKIN0	equ	COMCLK/2	; Timer0 input count rate
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
        binit   DLL0, DIVISOR & 0xFF	   ; 9600 bps
        binit   DLH0, (DIVISOR>>8) & 0xFF  ; **
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

; set up UCS for 64K ROM
	winit	UCSADH, 0x000F
	winit	UCSADL, ZBIT9+BIT8 + 3;w.s.  BS8, MEM
	winit	UCSMSKH, 0x0000
	winit	UCSMSKL, 0xFC01	; 0x000F_0000..0x000F_FFFF; mask SMM, csEN

; Enable SRAM select for SBC386-0 on CS4#
SRAM_AD	equ	0x000A8000	; set at address 0xA800:0000
SRAM_MS equ	0x00007FFF	; 15 bits
REFRESH_AD equ	0x00020000	; refresh select address
TEST_AD	equ	0x00010000	; do tests here
XFER_AD equ	0x00020000


	winit	CS4ADH, (SRAM_AD>>16)&0xFFFF	;high address
	winit	CS4ADL, (SRAM_AD&0xF800)| ZBIT9+BIT8 + 0;w.s.  8-bit, MEM, ~RDY
	winit	CS4MSKH, (SRAM_MS>>16)&0xFFFF|0xFC00 ;set for 32k only
	winit	CS4MSKL, (SRAM_MS&0xF800)|0x401	;32Kb, mask SMM, enable

; set up CS0# for the external I/O at 0400..04FF
	winit	CS0ADH, (0x400 >> 6) & 0xFFFF
	winit	CS0ADL, (0x400 <<10) & 0xFFFF | ZBIT9+ZBIT8 + ZBIT7+ 7;w.s.
	winit	CS0MSKH, ~(0x00FF00 >> 6) & 0xFFFF
	winit	CS0MSKL, ~(0x00FF00 <<10) & 0xF800 | BIT10+BIT0
;
; set up CS3# for the external Memory select at $000B_xxxx
	winit	CS3ADH, 0x000B
	winit	CS3ADL, 0x0000 | ZBIT9+BIT8+ZBIT7 + 5;w.s.
	winit	CS3MSKH, 0x0000
	winit	CS3MSKL, 0xF800 | BIT10+BIT0

;
; set up CS2# for the DRAM address range
	winit	CS2ADH, 0x0000		; address == 00000000
	winit	CS2ADL, 0x0000 | BIT9+BIT8+ZBIT7 + 2;w.s.
%if HALF_MEM
	winit	CS2MSKH, 0x03F7		; 8000:xxxx .. F000:xxxx off limits
%else
	winit	CS2MSKH, 0x03FF		; DRAM and ROM overlap
%endif
	winit	CS2MSKL, 0xF800 | BIT10 + BIT0  ; enable the chip select

%if 1
;
; set up the Refresh unit
	winit	RFSBAD, (REFRESH_AD>>14) & 0xFFFF  ; Base Address
	winit	RFSADD, (REFRESH_AD & 0x3FFF) | 1  ; low 14 address bits
	winit	RFSCIR, 16000/64 | 0xFC00	   ; for a 16mhz clk (clk2=32mhz)
	winit	RFSCON, BIT15		; enable/disable the refresh
%endif

; set up the WATCHDOG timer to monitor the bus
;  try to trap FPU hangs
;
;;;;	winit	WDTSTATUS, BIT1		; set BUSMON
; PWRCON must also be set to enable this function (a byte init)

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


	align	2
;       global  start
start:
        cli
        in	al,REMAPCFGH	; reset the state machine (state A)
        mov     ax,0x8000
        out     REMAPCFGH,al	; move to (state B)
        xchg    ah,al
        out     REMAPCFGL,al	; move to (state C)
        out     REMAPCFG,ax	; move to (state D), sets ESE bit
; Expanded I/O is now available -- ESE bit is set
        cld                     ; do this as insurance (direction=forward)

; Do the word port initialization
;
        mov     si,wtab1        ; get table address to SI
        mov     cx,return2      ; set return address
        jmp     initw_          ; simulate call
return2:

; Do the byte port initialization
;
        mov     si,btab1        ; get table address to SI
        mov     cx,return1      ; set return address
        jmp     initb_          ; simulate call
return1:

	mov	dx,0x4FF	;diagnostic board (JRC)
	mov	al,0x5A		;different from final display (0xA5)
	out	dx,al		;out to ECB

%if 0
; read switches to turn DRAM refresh on or off
	mov	dx,0x4FF	; switch register
	in	al,dx
	and	ax,1		; mask low bit
	mov	dx,RFSCON	; refresh control
	ror	ax,1		; move bit 0 to bit 15
	out	dx,ax		; enable/disable Refresh
%endif



; Set up addressing to test the SRAM
;
	mov	bx,SRAM_AD >> 4  ; set segment regs
        mov     ds,bx           ; DS=0000
        cnop
        mov     es,bx           ; ES=0000
        cnop

; Test all bits of the data path into memory
	
	xor	bx,bx		; test DS:[BX] data bits
	mov	ax,0x0180	; pattern
mem0:
	mov	[bx],al		; store a bit
	mov	[bx+80],ah	; and another
	cmp	al,[bx]		; test the first
	jne	patherr
	cmp	ah,[bx+80]	; test the second
	jne	patherr
	shr	al,1		;
	shl	ah,1		; shift the bit patterns
	jnc	mem0		; stop after 8th shift

; data path into SRAM is good

TPAT1	equ	0x98E5C8DC; carry=0
;;;;  1001_1000_1110_0101_1100_1000_1101_1100 0			33
;;;;  1001_1000_1110_0101_1100_1000_1101_1100 00000		37
;;;;  1001_1000_1110_0101_1100_1000_1101_1100 000000000		41

	mov	cx,(SRAM_MS+1)>>2
	xor	di,di		; ES = seg register
	mov	eax,TPAT1	; special bit pattern
	clc
	align	2  ; make kill test???
mem1:
	stosd			; store EAX <== ES:[di]
	rcr	eax,1		; rotate the 33-bit pattern
	loop	mem1

	mov	cx,(SRAM_MS+1)>>2
	xor	si,si		; DS = seg register
	mov	ebx,TPAT1	; special bit pattern
	clc
	align 2
mem2:
	lodsd			; retrieve value to EAX
	sbb	dh,dh		; save carry in DH
	cmp	eax,ebx		; compare values
	jne	patherr		; error if not the same
	rcr	dh,1		; restore the carry
	rcr	ebx,1		; rotate the 33-bit pattern
	loop	mem2

; Newly added SRAM test
	mov	cx, 32768/2	; WORDS
	mov	di, 0		; at 0000
	mov	bx, mem3
	jmp	rm_testSeg_bx
mem3:
	or	ax,ax
	jnz	patherr


; may now set up a stack
	mov	bx,ds		; use SS=DS=ES
        mov     ss,bx           ; set the stack pointer
        mov     sp,0x4000       ; may now use Stack & memory


	mov     al,1            ; show in the lights
        call    lites

        push    cs
        pop     ds


; Display the copyright notice without further ado ...

	mov	si,notice
        call    putstr          ; put out comment

        mov     si,cr0str       ; string
        call    putstr
        mov     eax,cr0         ; look at CR0
        call    eout


	mov     al,2            ; show in the lights
        call    lites

;  Continue with success ('0010') in the LITES


%if 1
	mov	si,ucsad
	call	putstr
	mov	dx,UCSADH
	in	ax,dx
	call	wout
	mov	dx,UCSADL
	in	ax,dx
	call	wout

	mov	si,ucsmsk
	call	putstr

	mov	dx,UCSMSKH
	in	ax,dx
	call	wout
	mov	dx,UCSMSKL
	in	ax,dx
	call	wout
	call	crlf

%endif

	call	crlf
	mov	si,msg_card
	call	getSD_CD
	push	ax			;save card state
	jz	no_SDcard
	add	si,3
no_SDcard:
	call	putstr

	call	pause

	pop	ax			;retrieve card state
	xor	al,1			;only light if not present
	call	ioSD_CS

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

%if 0
	push	bx
	mov	ax,bx
	call	wout		; raw count in hex
	pop	bx
%endif
%if 1
;
; set up the refresh counter correctly
%if 0
	xor	ax,ax
	mov	dx,RFSCON	; REFRESH control
	out	dx,ax		; stop refresh
%endif
	mov	ax,bx		; count in khz
	shr	ax,6		; divide by 64khz
	mov	dx,RFSCIR	; Refresh Count
	out	dx,ax
%if 0
	mov	ax,BIT15	; enable refresh
	mov	dx,RFSCON	; REFRESH control
	out	dx,ax
%endif
%endif

; put out CPU frequency message

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

; try to do output to the ECB bus
;
	mov	dx,0x4FF	;diagnostic board (JRC)
	mov	al,0xA5
	out	dx,al

	mov	si,jrc_sw	;tell the world what we're doing
	call	putstr

	in	al,dx		;input byte from diag. bd. switches (JRC)
	call	bout
        mov     al,NL
        call    outc

;
; VGA3 test of XIO
;
	mov	si,msg_vga3
	call	putstr

	mov	dx,dev_VGA3+4	;Configuration register
	mov	al,0x80		;set for $B800:0000
	out	dx,al
;
	mov	ax,0xB800	;segment register value
	mov	es,ax		;set ES
	mov	bx,0000		;set BX

	xor	dx,dx		;set indirect mode (DH), error count (DL)

	mov	cx,8		;8 writes
	push	bx
	mov	al,1		; start bit
v1:
%if 0
	push	ax
	call	bout
	pop	ax
%endif
	call	vga3wr		;write AL
	inc	bx
	rol	al,1
	loop	v1		; do 8 writes
	pop	bx		; start over

	mov	cx,8
 	mov	ah,1
	push	bx
v2:
	call	vga3rd		;indirect read
	inc	bx
%if 0
	push	ax
	call	bout
	pop	ax
%endif
	cmp	al,ah
	je	v3
	inc	dl
v3:	rol	ah,1		;rotate pattern
	loop	v2
	pop	bx

	mov	si,msg_succ	;
	or	dl,dl
	jz	v4
	mov	si,msg_fail
v4:	call	putstr

	mov	si,msg_vga3_2
	call	putstr

	mov	cx,8
 	mov	ah,1
	mov	dx,0x0100	;direct memory read
	push	bx
v5:
	call	vga3rd		;direct read
	inc	bx
%if 0
	push	ax
	call	bout
	pop	ax
%endif
	cmp	al,ah
	je	v6
	inc	dl
v6:	rol	ah,1		;rotate pattern
	loop	v5
	pop	bx

	mov	si,msg_succ	;
	or	dl,dl
	jz	v7
	mov	si,msg_fail
v7:	call	putstr



;-----------
	mov	si,msg_vga3_3
	call	putstr

	mov	dx,0x0100	;set direct mode (DH), error count (DL)

	mov	cx,8		;8 writes
	push	bx
	mov	al,0xFE		; start bit 0 off
v11:
%if 0
	push	ax
	call	bout
	pop	ax
%endif
	call	vga3wr		;write AL
	inc	bx
	rol	al,1
	loop	v11		; do 8 writes
	pop	bx		; start over

	mov	cx,8
 	mov	ah,0xFE
	push	bx
v12:
	call	vga3rd		;indirect read
	inc	bx
%if 0
	push	ax
	call	bout
	pop	ax
%endif
	cmp	al,ah
	je	v13
	inc	dl
v13:	rol	ah,1		;rotate pattern
	loop	v12
	pop	bx

	mov	si,msg_succ	;
	or	dl,dl
	jz	v14
	mov	si,msg_fail
v14:	call	putstr

	mov	si,msg_vga3_4
	call	putstr

	mov	cx,8
 	mov	ah,0xFE
	mov	dx,0x0000	;indirect memory read
	push	bx
v15:
	call	vga3rd		;direct read
	inc	bx
%if 0
	push	ax
	call	bout
	pop	ax
%endif
	cmp	al,ah
	je	v16
	inc	dl
v16:	rol	ah,1		;rotate pattern
	loop	v15
	pop	bx

	mov	si,msg_succ	;
	or	dl,dl
	jz	v17
	mov	si,msg_fail
v17:	call	putstr


	call	crlf
	call	pause		; pause before FPU stuff

	xor	ax,ax		; estinguish SD_CS light
	call	ioSD_CS

%if wFPU
; check presence of FPU
	mov     di,no_fpu	; first assume FPU not present

	mov     dx,P3PIN        ; get P3 port status
        in      al,dx           ; P3.0 is co-processor presence detect
        mov     bx,ax           ; save state in BL
; save FPU bit in BL

	smsw	ax		; control bits to AX

        and     bl,BIT0         ; 1=no FPU, 0=with FPU
        jnz     noFPU

        add     di,(w_fpu-no_fpu) ; change comment to FPU present
; Display the FPU notice
        or      al,CR0_MP       ; set MP bit
        and     al,~(CR0_EM | CR0_TS)	; clear EM & TS bits
	jmp	fpu2
noFPU:
        and     al,~(CR0_MP | CR0_TS)	; clear MP & TS bits
;	or      al,CR0_EM       ; set EM bit (future with Emulator)
fpu2:
        lmsw    ax              ;

	call	crlf		;
	mov	si,di 		; FPU info
	call	putstr

	or	bl,bl		; Test for FPU
	jnz	FPUmsg		; jump if not present

	mov	si,w_fpu2	; tentative failure message
	call	putstr

%if 0
	fnstsw	ax
	jmp	$+2
	fninit
%else
	fnstsw	ax
	jmp	$+2
	jmp	$+2
	fninit
	jmp	$+2
	jmp	$+2
	finit
%endif
;
FPUmsg:

; initialization may be taking place
;
	or      bl,bl           ; test FPU not present
        jnz     fpu5

; put out message during init
	mov	si,fpu_ini
	call	putstr

   es   mov     word [0x600],-1
   es   fstcw	word [0x600]
   es   mov     ax,[0x600]
        call    wout

	mov	si,fpu_comp
	call	putstr

        fldpi
        fld1
        fadd
   es   fistp   dword [0x600]
   es   mov     eax,[0x600]
        call    eout
	call	crlf

; above was skipped if no FPU

fpu5:
;;	nop
%endif


;
; prime the DRAM
;

	mov	si,msg_dram2
	call	putstr

;;;	nop
;;;continue:
	mov	ax,TEST_AD>>4	; segment $1000
	mov	ds,ax
	mov	es,ax
	xor	si,si		; DS:SI = $1000:0000
	mov	cx,32768	; 64K bytes (will load Words)

	rep lodsw

	or	cx,si
	jnz	patherr

	mov	ax,1
	call	lites


%if SHADOW_MODE
	mov	ax,0xF000	; source segment
	mov	ds,ax
	cnop
	mov	ax,XFER_AD>>4	; destination segment
	mov	es,ax
	cnop
	mov	cx,65535	; 64K-1 bytes
	xor	si,si
	xor	di,di
	rep movsb		; move (almost) all of ROM
	movsb			; plus one more
	jmp	(XFER_AD>>4):shadow1
shadow1:
	mov	al,1
	mov	dx,0x4FF
	out	dx,al

	mov	ax,7
	call	lites

	mov	al,2
	mov	dx,0x4FF
	out	dx,al

; disable the ROM
	mov	dx,UCSMSKL	; low mask has enable bit
	in	ax,dx
	and	al,~BIT0	; clear the enable bit
	out	dx,ax		; disable the ROM

	mov	al,3
	mov	dx,0x4FF
	out	dx,al

%if 1
; disable the SRAM
	mov	dx,CS4MSKL	;
	in	ax,dx
	and	al,~BIT0
	out	dx,ax		; disable the SRAM
%endif
%if 1
	mov	dx,CS2MSKH	; high bits of DRAM mask
	mov	ax,0x03FF	; turn on all bits
	out	dx,ax		;  **
%endif
%if 1
; move the ROM code to DRAM
	mov	ax,es
	mov	dx,ds
	mov	ds,ax
	cnop
	mov	es,dx		; exchage source & dest
	cnop
	mov	cx,65535	; 32K words, 64K bytes
	xor	si,si
	xor	di,di

	mov	al,4
	mov	dx,0x4FF
	out	dx,al
%if 1
	rep movsb		; move all the code
%else
shad7:
	lodsb
	stosb
	loop	shad7
%endif
	movsb			; plus one more
%endif
	mov	al,5
	mov	dx,0x4FF
	out	dx,al

%if 0
	jmp	$+2
	jmp	0xF000:shadow2
shadow2:
%endif
	mov	ax,0xB
	call	lites

%endif
; end SHADOW_MODE

continue:
	mov	ax,1
	call	lites

	mov	ax,TEST_AD>>4	; segment $1000
	mov	ds,ax
	mov	es,ax
	xor	si,si
	xor	di,di
	xor	ax,ax		; AX = 0
%if 0
	;;;align	2
	;;;nop

	stosb			; store the first
	mov	cx,65535		; 64K bytes
	rep stosb
%else

%if 1
	;;;align	2
	mov	cx,32768	; 64K bytes (will store Words)
%if 1
	rep stosw
%else
	rep stosb
	;;;align	2
	mov	cx,32768
	rep stosb
%endif
%else
	;;;align	2
	mov	cx,32768	; 64K bytes (will store Words)
dr_stor0:
    es	mov	[di],ax		; store a word
;;	mov	[di],ax		; store a word
    	inc	di
	inc	di
	loop	dr_stor0
%endif
%endif
	or	cx,di
	jnz	patherr

	mov	ax,2
	call	lites


	mov	cx,32768	; 64K bytes (will load Words)
	xor	bx,bx		; error flag
	xor	di,di

	;;;align	2		;
rescan:
	xor	ax,ax
;;;	jmp	$+2
	
	repe scasw

	je	good3

	lea	ax,[di-2]
	call	wout
	mov	al,':'
	call	putc
	call	space
    es	mov	ax,[di-2]
    	call	wout
	call	crlf
	mov	bx,1
; error flagged, test for keyboard hit
	call	testc
	jz	bad2	; jump if no char waiting
	call	getc	; get the waiting character
	cmp	al,ASCII_ESC
	jne	good4	; not ESC, exit scasw loop
	jmp	stop_testing	; ESC stop all testing
bad2:
	cmp	di,0
	jne	rescan

good3:
	mov	ax,3
	call	lites

	or	bx,bx
	je	good31
	call	crlf
good31:

	or	cx,di
	jnz	dramstop

good4:
	mov	ax,4
	call	lites

;
; now the vicious test pattern
;
	mov	cx,1<<(16-2)	; 64K segment of dwords
	xor	di,di		; ES = seg register
	mov	eax,TPAT1	; special bit pattern
	clc
	;;;align	2
	nop
;;;
;;; unaligned loop makes previous test work @ 33mhz
;;;
dmem1:
	stosd			; store EAX <== ES:[di]
	rcr	eax,5		; rotate the 33-bit pattern
	loop	dmem1

	mov	cx,1<<(16-2)	; 64K segment of dwords
	xor	si,si		; DS = seg register
	xor	di,di
	mov	ebx,TPAT1	; special bit pattern
	clc
dmem2:
	lodsd			; retrieve value to EAX
	sbb	dh,dh		; save carry in DH
	cmp	eax,ebx		; compare values
	je	dmem3		; skip print if no error
; the error print
	pushm	eax,ebx,dx
	mov	ax,si		; address
	call	wout
	mov	al,':'
	call	putc
	call	space
	mov	eax,ebx
	call	eout
	call	space
	mov	al,'-'
	call	putc
	mov	al,'>'
	call	putc
	call	space
	pop	eax
	push	eax
	call	eout
	call	crlf
	popm	eax,ebx,dx
	inc	di		; signal an error
; test for ESC, or just terminate acid test
	call	testc
	jz	dmem3		; no kbd hit, just continue test
	call	getc
	cmp	al,ASCII_ESC
	jne	dmem31
	jmp	stop_testing

dmem3:
	rcr	dh,1		; restore the carry
	rcr	ebx,5		; rotate the 33-bit pattern
	loop    dmem2

dmem31:
	or	di,di
	je	dmem4
	call	crlf
dmem4:

	mov	ax,5
	call	lites


	call	testc		; Test for key hit
	jz	continue

	
	call	getc		; clear the character input

stop_testing:

; former "Done."
;   Now, enter Protected Mode
;
	push	cs
	pop	ds
	mov	si,msg_prot		; Prot. Mode message
	call	putstr



%if 1
; move GDT into place
;
	mov	ax,(PM_GDT>>4) & 0xFF00
	mov	es,ax
	cnop
	mov	di,(PM_GDT) & 0x0FFF
	push	di			; for later pointer
	push	cs
	pop	ds
	cnop
	mov	si,gdt0

	mov	cx,len_gdt
	rep movsb

	pop	di			; saved above
    cs	lgdt 	[gdt0+descrP]
%else
;
; Use ROM segment GDT
;
	jmp	load_ROM_gdt

	align	2
gdt00:	dw	len_gdt
	dd	gdt0+0xF0000
	dw	0
load_ROM_gdt:

    cs	lgdt	[gdt00]

%endif
;
; set the PE bit to switch into Protected Mode
;
	mov	eax,cr0			; 
	or	al,1			; set PE bit
	mov	cr0,eax
; now in protected mode, but no segment registers are set
	jmp	$+2			; flush the pre-fetch queue
	align	2
	jmp	descr_BIOS32:pm_continue


	bits	32
pm_continue:
	mov	dx,0x4FF
	mov	al,0x6F
	out	dx,al
	cnop

	mov	dx,P1LTC
	out	dx,al
	cnop


	mov	ax,descr_DS
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	esp,SRAM_AD + 0x8000

	mov	al,0x0C		; 1100 in LED lites
	call	__lites		; destroys EDX no longer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; size memory here
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	call	__pm_sizeMem	;get memory size to EAX

      	push	eax		; save memory size
	mov	ebx,eax		; save size in EBX, too

	call	__jleds

	call	__decout	; print size in decimal

	mov	esi,msg_size + (ROM_SEG<<4)
	call	__putstr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; clear out 640K + extended memory (1meg .. 64meg limit)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	xor	edi,edi
	mov	ecx, 640*1024/4	; 640k of MSDOS memory (in Dwords)

	xor	eax,eax
	rep stosd
; now wipe the memory above 1 meg.
	mov	edi,1<<20	; address high memory
	mov	ecx,ebx
	dec	ecx		; subtract first megabyte
	shl	ecx,20-2	; count Dwords
	rep stosd		; Zero it out

	mov	al,0x0A
	call	__lites

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; test memory bit paths
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	esi,msg_640K_1bit + (ROM_SEG<<4)
	call	__putstr

	xor	edi,edi		; start at 0
	mov	ecx,0x000A_0000	; 640K
	call	__pm_test1bit

	mov	al,0x0B
	call	__lites

	mov	eax,esi
	call	__decout
	mov	esi,msg_errors + (ROM_SEG<<4)
	call	__putstr
	
	mov	esi,msg_63M_1bit + (ROM_SEG<<4)
	call	__putstr

	mov	edi,0x0010_0000	; start of extended memory
	mov	ecx,ebx		; count of megabytes
	dec	ecx		; ExtMem = AllMem-1meg
	shl	ecx,20		; Mbyte -> Byte
	call	__pm_test1bit

	mov	al,0x0C
	call	__lites

	mov	eax,esi
	call	__decout
	mov	esi,msg_errors + (ROM_SEG<<4)
	call	__putstr
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; test all of high memory
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	esi,msg_rot41 + (ROM_SEG<<4)
	call	__putstr

	dec	bl		; count one less megabyte

%if 1
	mov	ecx,ebx		; megabyte count to ECX
	shl	ecx,20-2	; DWORD count in ECX
	mov	edi,0x0010_0000	; start of Extended Memory
	mov	eax,TPAT1	; 32-bit pattern
	xor	edx,edx		; extend to 41 bits with zeroes

	call	__pm_test41
%else
	mov	bh,PATT		; count all 33/37/41 bits of the pattern
	xor	esi,esi		; Zero the error count, clear the Carry
	mov	eax,TPAT1	; DH[4:0] + EAX is the 37-bit pattern
	xor	dx,dx		; 41st,37th,33rd bits are in DH & Carry
pm_test1:
	push	eax
	mov	al,bh
	call	__jleds
	call	__lites
	pop	eax

	mov	edi,0x00100000	; address first meg of extended memory
	movzx	ecx,bl		; count of megabytes
	shl	ecx,20-2	; count of Dwords

	push	eax		; save pattern 
	push	dx		; save 37rd bit
%if (PATT==33) | (PATT==41)
	shr	dh,1		; set carry
%endif

	align 2
pm_test2:
	stosd			; store the pattern
%if PATT==37
	shl	dl,4		; shift out high bit (of 5)
	rcl	eax,1		; rotate the pattern
	rcr	dl,1		; shift in bit
	sar	dl,3		; propagate bit from EAX
	rol	dl,1		; put in bit 0 of dl
%elif PATT==33
	rcl	eax,1		; rotate the pattern
%elif PATT==41
	rcl	eax,1		; rotate the pattern
	rcl	dl,1		; bit into Carry
%endif
	loop	pm_test2

; now do the readback
	mov	edi,0x00100000
	movzx	ecx,bl		; count of megabytes
	shl	ecx,20-2	; count of Dwords

	pop	dx		; restore bit 37 of the pattern
	pop	eax		; restore original pattern

	align 2
pm_test3:
	scasd			; compare DWORD and increment EDI
				; SCAS affects the carry
	jne	pm_terror
pm_test3ok:
	jcxz	pm_display	; with address override (CX, not ECX)
pm_xdisplay:
%if PATT==37
	shl	dl,4		; shift out high bit (of 5)
	rcl	eax,1		; rotate the pattern
	rcr	dl,1		; shift in bit
	sar	dl,3		; propagate bit from EAX
	rol	dl,1		; put in bit 0 of DL
%elif PATT==33
;;	shr	dh,1		; set carry (3 clocks)
	add	dh,dh		; set carry (2 clocks)
	rcl	eax,1		; rotate the pattern
;;	rcl	dh,1		; save the carry (3 clocks)
  	sbb	dh,dh		; save the carry (2 clocks)
%elif PATT==41
	shr	dh,1		; set the carry
	rcl	eax,1		; rotate the pattern
	rcl	edx,1		; ** and save carry in DH bit 0
%endif
	loop	pm_test3
	jmp	pm_test4

	align 2
pm_terror:
	inc	esi
; error printout
%if 1
	pushm	eax,edx
	call	__crlf
	lea	eax,[edi-4]	; location of error
	call	__eout
	mov	al,':'		;colon
	call	__putc
	call	__space
	mov	eax,[esp]	; original value
	call	__eout
	call	__space
	mov	al,'-'
	call	__putc
	mov	al,'>'
	call	__putc
	call	__space
	mov	eax,[edi-4]	; actual read
	call	__eout
	popm	eax,edx

%endif

	jmp	pm_test3ok
pm_display:
	pushm	eax,edx
	mov	eax,ecx
	shr	eax,16
	call	__lites
	popm	eax,edx
	jmp	pm_xdisplay

pm_test4:
	dec	bh		; count all the patterns
; start the loop over with an updated test pattern
	jnz	pm_test1
%endif

	pushm	eax,esi

	or	esi,esi		;test error count
	jz	pm_test6	;no spacing if zero
	call	__crlf		;if there is error printout
pm_test6:
	mov	eax,esi		; error count printout
	call	__decout

	mov	esi,msg_hi_err+1+(ROM_SEG<<4)
	call	__putstr

	popm	ecx,esi,edi	; patt to ECX(was EAX),
				; err count to ESI
				; size to EDI (push EAX was way up there)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; now return to Real Mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
return_to_real:
	mov	ax,descr_RMdata		; 64K segment at 0x00000000
	mov	gs,ax
	mov	fs,ax
	mov	es,ax
	mov	ds,ax
	mov	ss,ax
	jmp	$+2	; clear prefetch queue
	jmp	descr_RMcode:real_return
real_return:
	bits	16

	mov	eax,cr0		;
	and	al,0xFE		; turn off PE bit
	mov	cr0,eax
	jmp	$+2
	jmp	0xF000:really_return
really_return:
	mov	ax,(SRAM_AD>>4)&0xFFFF
	mov	ss,ax
	mov	sp,SRAM_MS+1

	xor	ax,ax
	mov	ds,ax
	mov	es,ax
	mov	fs,ax
	mov	gs,ax

	mov	ax,3
	call	lites

	mov	ebx,esi		; save the error count
	cmp	ecx,TPAT1	; see if the 37 passes returned to 
				; the original test pattern
	je	.4
	inc	ebx

.4:	push	cs
	pop	ds
	call	crlf
	mov	si,msg_real
	call	putstr

; All done, put out message
;
	push	cs
	pop	ds
	mov	si,msg99	;"Done." message
	call	putstr

	mov	ax,6
	call	lites

	jmp	stop


;  Halt with success ('0110') in the LITES

patherr:
stop:
        hlt
        jmp     $-1
dramstop:
	jmp	$

; lites -- enter with new "lites" value in AL
;       uses AX & DX
;
lites:		; Real mode entry
        mov     dx,P1LTC        ; get parallel port address
	not	al		; complement bits
	mov	ah,al
	shl	ah,4		; bits to position, zero low 4 bits
	in	al,dx
	and	al,0x0F		; save low bits
	or	al,ah		; set complemented bits
	out	dx,al		; and output
	ret

;
;  codes to handle the SDcard interface for now
;
getSD_CD:		; CARD DETECT (ret 1=present, 0=absent)
	push	dx
	mov	dx,SDPIN	;I/O port (input)
	in	al,dx
	test	al,SDnCD	;0=detect, 1=none
	mov	ax,0		;does not touch the flags
	jnz	.1
	inc	ax
.1:	pop	dx
	or	ax,ax		;return presence in carry
	ret

ioSD_CS:		; CHIP SELECT (1=enable, 0=disable)
	push	dx
	mov	dx,SDLTC
	mov	ah,al	; save option (1/0)
	in	al,dx
	or	ah,ah	; test turn on or off
	jz	.off
.on:	and	al,~SDnCS
	jmp	.out
.off:	or	al,SDnCS
.out:	out	dx,al
	pop	dx
	ret

;
; output an ASCII_SP to the console
;
space:
	mov	al,ASCII_SP
	jmp	putc
;
; output a CR/LF to the console
;
;;crlf:
;
; outc -- write an ASCII 'cooked' character
;       Convert NL to CR,NL
;
outc:
        cmp     al,ASCII_NL     ; test for NL
        jne     putc            ; if not, just put out the character
crlf:
        mov     al,ASCII_CR     ; get a CR
        call    putc            ; write it out
        mov     al,ASCII_NL     ; restore NL
;
; putc -- put out a character in AL to the SIO0 port
;
putc:
	push	dx		; register save
	push	ax		; PUSH EAX
putc1:
        mov     dx,LSR0         ; Line Status Register

        in      al,dx
        test    al,LSR_TBE      ; Transmit Buffer Empty
        jz      putc1

        pop     ax
        mov     dx,TBR0         ; Transmit buffer register
        out     dx,al           ; send the character

        pop     dx              ; register restore
        ret


; test for character waiting for input
;	returns 1 in AL if char waiting
;	returns 0 in AL if no char is waiting
;
testc:
	push	dx
	mov	dx,LSR0		; Line Status Register
	in	al,dx
	and	al,LSR_RBF	; Receive buffer full
	pop	dx
	ret


getc:
	push	dx
getc1:
	mov	dx,LSR0		; Line Status Register
	in	al,dx
	test	al,LSR_RBF	; Receive buffer full
	jz	getc1

	mov	dx,RBR0		; Receive Buffer
	in	al,dx		; get the character
	pop	dx
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


dev_VGA3	equ	0x4E0	;
;
; VGA3 reads & writes
;
; Enter with address in ES:BX
; Value in AL, option in DH
;   DH == 0	; use indirect r/w using address registers
;   DH == 1	; use direct memory write
;
vga3wr:
	or	dh,dh		;test write option
	jz	vwrind
   ES	mov	[bx],al		;direct write
   	ret
vwrind:
	push	dx
	mov	dx,dev_VGA3 + 5
	xchg	al,bh		;high address part
	out	dx,al		;write to address reg.
	inc	dx
	xchg	al,bl		;low address part
	out	dx,al		;write low address
	inc	dx
	xchg	al,bh		;restore value to write
	out	dx,al		;write to memory
	xchg	bl,bh		;restore BX
	pop	dx
	ret

vga3rd:
	or	dh,dh
	jz	vrdind
   ES	mov	al,[bx]		;direct read
   	ret
vrdind:
	push	dx
	mov	dx,dev_VGA3 + 5	;high address register
	mov	al,bh
	out	dx,al		;high part of address
	inc	dx
	mov	al,bl		;low part of address
	out	dx,al		; **
	inc	dx
	in	al,dx		;get data byte
	pop	dx
	ret

msg_pause:
	db	NL,"Press any key to continue ...", NUL
pause:
	pushm	ax,si,ds
	push	cs
	pop	ds		; Set up DS:SI
	cnop			; Conditional NOP
	mov	si,msg_pause
	call	putstr
	call	getc
	call	crlf
	popm	ax,si,ds
	ret

%include "ds1302.asm"
%include "pm_sio.asm"
%include "pm_test.asm"

	align	16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Linear Protected Mode code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%assign	PM_BASE  0x000F0000+ROM
%if 1
	descr_linear_data	0,0x0400_0000	; 64meg at 00000000
	descr_linear_data	0,0xFFFF, 1	; 64k 80286 data seg (exp down)
	descr_linear_code	0,0x03FF_FFFF	; 64meg at 00000000
%endif
;
; The GDT prototype will be copied to the lowest address in SRAM
;
PM_GDT	equ	SRAM_AD			; protected mode address
;RM_GDT	equ	(SRAM_AD>>4):0000	; real mode segment offset
	
;
; now the Global Descriptor Table prototype
;
	align	16
gdt0:	dq	0		; null descriptor
descr08	equ	$-gdt0
	dw	len_gdt-1
	dd	PM_GDT
	dw	0		; filler
descrP	equ	descr08


descr10	equ	$-gdt0
	dq	0		; LDT filler


descr18	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_DS	equ	descr18


descr20	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_ES	equ	descr20


descr28	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_SS	equ	descr28


descr30	equ	$-gdt0
	descr_linear_code	0, 0x03FF_FFFF	; 64meg DRAM
descr_CS	equ	descr30


descr38	equ	$-gdt0
	descr_linear_code	0xF0000, 0xFFFF ; 64K code (286)
descr_BIOS	equ	descr38


descr40	equ	$-gdt0
	descr_linear_data	0x400, 0x300	; BIOS data area
descr_BDA equ	descr40


descr48	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_FS	equ	descr48


descr50	equ	$-gdt0
	descr_linear_data	0, 0x03FF_FFFF	; 64meg DRAM
descr_GS	equ	descr50


descr58	equ	$-gdt0
	descr_linear_data	0, 0xFFFF	; 64K return Data segment
descr_RMdata	equ	descr58


descr60	equ	$-gdt0
	descr_linear_code	0x000F0000, 0xFFFF	; 64K return Code segment
descr_RMcode	equ	descr60


descr68	equ	$-gdt0
	descr_linear_code	0xF0000, 0x1FFFF ; 128K code
descr_BIOS32	equ	descr68


len_gdt		equ	$-gdt0

%include "rm_test.asm"


        setloc (0x10000-ROM-16)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Real Mode statup jump
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	bits	16
        align   16
bootstrap:
        jmp     0xF000:start	; 5 byte real-mode far call
	
;;;	times	11  db 0xFF	; fill out the ROM
	db	__DATE__,NUL
