;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; start.asm
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
%ifndef CRC
%define CRC 0
%endif
%ifndef CRC_AT
%define CRC_AT 0xFFEE
%endif


%include "seg_def.inc"
%include "i386EX.inc"
%include "macro.inc"
%define XXX
%include "bda.inc"
%undef XXX

NL      equ     ASCII_NL
NUL     equ     ASCII_NUL

        cpu     386
        bits    16

	global	origin, notice, start

extern	int_zero_divide		; 0
extern	int_single_step		; 1
extern	int_NMI_interrupt	; 2
extern	int_breakpoint		; 3  trap on INT3
extern	int_overflow		; 4
extern	int_bounds_check	; 5
extern	int_invalid_opcode	; 6
extern	int_FPU_escape		; 7

extern	int_irq0	; (timer 0)	int_double_fault
extern	int_irq1	; (keyboard)	int_FPU_seg_overrun
extern	int_irq2	; (IRQ cascade)	int_invalid_TSS
extern	int_irq3	;		int_seg_not_present
extern	int_irq4	; (COM1)	int_stack_fault
extern	int_irq5	;		int_gen_prot_fault
extern	int_irq6	; (FDC)		int_page_fault
extern	int_irq7	;

extern	int_10h		; (video)	int_FPU_error
extern	int_11h		; (equip. config)
extern	int_12h		; (conv. memory size)
extern	int_13h		; (disk I/O)
extern	int_14h		; (serial I/O)
extern	int_15h		; (cassette I/O + much more)
extern	int_16h		; (keyboard)
extern	int_17h		; (parallel port)

extern	int_18h		; (ROM Basic)
extern	int_19h		; (Reboot)
extern	int_1Ah		; (CMOS clock)
extern	int_1Bh		; (ctrl-Break)
extern	int_1Ch		; (timer tick)
extern	int_1Dh		; (video parameter table)
extern	int_1Eh		; (floppy disk params)
extern	int_1Fh		; (font 80h..0FFh)

extern	int_msdos	; returns error code

extern	int_40h		; Floppy disk driver
extern	param_hd0	; fixed disk parameters
extern	int_42h		; Video driver
extern	param_VGA	; VGA/EGA character table
extern	param_font	; PCjr chars 00h..7Fh
extern	int_nop		; unused
extern	param_hd1	; fixed disk parameters
extern	int_4Ah		; BIOS alarm handler

extern	int_EMM		; LIM EMS driver

extern	int_irq8	; (1024hz clock)
extern	int_irq9	; (irq2 redirect)
extern	int_irq10
extern	int_irq11
extern	int_irq12
extern	int_irq13
extern	int_irq14	; (IDE interrupt)
extern	int_irq15	; (Watchdog Timer)





segment _TEXT

origin:
	cli
	jmp	start		;skip over boilerplate

; notice at the beginning of the ROM

db "Copyright (C) 2018  John R Coffman.  All rights reserved."
dd	0

segment CONST

	align	2
page0vectors:	; these are condensed
	dw	int_zero_divide		; 0
	dw	int_single_step		; 1
	dw	int_NMI_interrupt	; 2
	dw	int_breakpoint		; 3  trap on INT3
	dw	int_overflow		; 4
	dw	int_bounds_check	; 5
	dw	int_invalid_opcode	; 6
	dw	int_FPU_escape		; 7

	dw	int_irq0	; (timer 0)	int_double_fault
	dw	int_irq1	; (keyboard)	int_FPU_seg_overrun
	dw	int_irq2	; (IRQ cascade)	int_invalid_TSS
	dw	int_irq3	;		int_seg_not_present
	dw	int_irq4	; (COM1)	int_stack_fault
	dw	int_irq5	;		int_gen_prot_fault
	dw	int_irq6	; (FDC)		int_page_fault
	dw	int_irq7	;

	dw	int_10h		; (video)	int_FPU_error
	dw	int_11h		; (equip. config)
	dw	int_12h		; (conv. memory size)
	dw	int_13h		; (disk I/O)
	dw	int_14h		; (serial I/O)
	dw	int_15h		; (cassette I/O + much more)
	dw	int_16h		; (keyboard)
	dw	int_17h		; (parallel port)

	dw	int_18h		; (ROM Basic)
	dw	int_19h		; (Reboot)
	dw	int_1Ah		; (CMOS clock)
	dw	int_1Bh		; (ctrl-Break)
	dw	int_1Ch		; (timer tick)
	dw	int_1Dh		; (video parameter table)
	dw	int_1Eh		; (floppy disk params)
	dw	int_1Fh		; (font 80h..0FFh)
;
;  MSDOS reserved	20h .. 3Fh
;
  times 20h dw	int_msdos	; IRET w/ error
;
	dw	int_40h		; Floppy disk driver
	dw	param_hd0	; fixed disk parameters
	dw	int_42h		; Video driver
	dw	param_VGA	; VGA/EGA character table
	dw	param_font	; PCjr chars 00h..7Fh
	dw	int_nop		; unused
	dw	param_hd1	; fixed disk parameters
  times 3  dw	int_nop		; IRET
	dw	int_4Ah		; BIOS alarm handler
  times 15h dw	int_nop		; IRET

  times 7  dw	int_nop		; User interrupts
  	dw	int_EMM		; LIM EMS driver
  times 8  dw	int_nop		; User interrupts

  	dw	int_irq8	; (1024hz clock)
	dw	int_irq9	; (irq2 redirect)
	dw	int_irq10
	dw	int_irq11
	dw	int_irq12
	dw	int_irq13
	dw	int_irq14	; (IDE interrupt)
	dw	int_irq15	; (Watchdog Timer)

  times 8  dw int_nop

;
;  Reserved locations INT 80h..0F0h for Basic
;  Locations 0F1h..0FFh not assigned

n_page0vectors	equ	($-page0vectors)/2




	

;
; WORD port initialization table
;
wtab1:
	winit	CLKPRS, 50-2	;PSCLK divider (PSCLK = (CLK2/2) / (denom+2)
			    	;initially divide by 50

; set up UCS for 64K ROM
	winit	UCSADH, 0x000F
	winit	UCSADL, ZBIT9+BIT8 + 5;w.s.  BS8, MEM
	winit	UCSMSKH, 0x0000
	winit	UCSMSKL, 0xFC01	; 0x000F_0000..0x000F_FFFF; mask SMM, csEN

; Enable SRAM select for SBC386-0 on CS4#
SRAM_AD	equ	0x000A8000	; set at address 0xA800:0000
SRAM_MS equ	0x00007FFF	; 15 bits
REFRESH_AD equ	0x00020000	; refresh select address
TEST_AD	equ	0x00010000	; do tests here
XFER_AD equ	0x00020000


	winit	CS4ADH, (SRAM_AD>>16)&0xFFFF	;high address
	winit	CS4ADL, (SRAM_AD&0xF800)| ZBIT9+BIT8 + 1;w.s.  8-bit, MEM, ~RDY
	winit	CS4MSKH, (SRAM_MS>>16)&0xFFFF|0xFC00 ;set for 32k only
%if HALF_MEM
	winit	CS4MSKL, (SRAM_MS&0xF800)|0x401	;32Kb, mask SMM, enable
%else
	winit	CS4MSKL, (SRAM_MS&0xF800)|0x400	;32Kb, mask SMM, disable
%endif

; set up CS0# for the external I/O at 0400..04FF
	winit	CS0ADH, (0x400 >> 6) & 0xFFFF
	winit	CS0ADL, (0x400 <<10) & 0xFFFF | ZBIT9+ZBIT8 + ZBIT7+ 7;w.s.
	winit	CS0MSKH, ~(0x00FF00 >> 6) & 0xFFFF
	winit	CS0MSKL, ~(0x00FF00 <<10) & 0xF800 | BIT10+BIT0
;
; set up CS1# for the IDE I/O at 01F0..01FF	-- ZBIT0 disables it
	winit	CS1ADH, (0x1F0 >> 6) & 0xFFFF
	winit	CS1ADL, (0x1F0 <<10) & 0xFFFF | ZBIT9+ZBIT8 + ZBIT7+ 5;w.s.
	winit	CS1MSKH, ~(0x00FFF0 >> 6) & 0xFFFF
	winit	CS1MSKL, ~(0x00FFF0 <<10) & 0xF800 | BIT10+ BIT0
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




btab1:
        binit   PORT92_AT,0x02  ; enable the A20 line

;    LITES[3:0], DSRST, DSCLK, RTS0#, DSDAT
;;;	binit   P1LTC, 0x6F	; LITES (weak)1100 --> 1001 (inverted outputs)
	binit   P1LTC, 0x63	; LITES (weak)1100 --> 1001 (inverted outputs)
				; DSRST asserted, DSCLK low, RTS0# de-asserted, DSDAT o.c. high 
;;;	binit	P1DIR, 0x00+DSDAT	; LITES (7..4) are DRIVEN now, DSDAT is input
	binit	P1DIR, 0x00+BIT0 	; LITES (7..4) are DRIVEN now, DSDAT is input
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
;
; constants below have been moved to "timer.inc"
;
%if 0
TIMER_STOP	equ	BIT6+BIT0 + ZBIT1 + ZBIT3 + ZBIT5 ; stop 0, 1, 2
TIMER_RUN	equ	TIMER_STOP + BIT1 + BIT3	; run counters 0, 1

        binit   TMRCFG, ZBIT7+TIMER_STOP ; bit6: s/w control of GATEn, bit7=0 enables all clocks
		;Timers enabled, 1&2 use PSCLK, 0 uses TMRCLK0 (COMCLK/2)
CTR0 equ ZBIT7+ZBIT6	;select counter 0
CTR1 equ ZBIT7+ BIT6	;select counter 1
CTR2 equ  BIT7+ZBIT6	;select counter 2
CWR01 equ BIT5+BIT4	;Write Count low, then high
MODE0 equ ZBIT3+ZBIT2+ZBIT1
MODE1 equ ZBIT3+ZBIT2+ BIT1
MODE2 equ ZBIT3+ BIT2+ZBIT1
MODE3 equ ZBIT3+ BIT2+ BIT1
MODE4 equ  BIT3+ZBIT2+ZBIT1
MODE5 equ  BIT3+ZBIT2+ BIT1
; counter 0 runs at 1.8432mhz / 2  =  921600  (just under 1mhz)
; @20hz, the divisor is 46080 yielding a 50ms time slot
COMCLK	equ	1843200		; standard 1.8432mhz oscillator
BAUD	equ	9600		; default SIO0 bit rate
DIVISOR	equ	COMCLK/16/BAUD	; SIO0 divisor to achieve BAUD rate
CLKIN0	equ	COMCLK/2	; Timer0 input count rate
MS50	equ	CLKIN0 / 20	; 50ms clock
MS50HI	equ	MS50/256
MS50LO	equ	MS50 & 0xFF
MS18a	equ	50619		; 18.206602hz clock (54.92513ms)
				; 0x1800BA = 1573050 ticks/day
MS18b	equ	50625		; 18.204444hz clock (54.93164ms)
				; 0x180000 = 1572864 ticks/day
%else
%include "timer.inc"
%endif

	binit	TMRCON, CTR0 + CWR01 + MODE0 + ZBIT0	;binary
	binit	TMR0, MS50LO	;low byte
	binit	TMR0, MS50HI	;high byte = 46080
	binit	TMRCON, CTR1 + CWR01 + MODE0 + ZBIT0	;binary
	binit	TMR1, 0
	binit	TMR1, 0		; 65536
	binit	TMRCON, CTR2 + CWR01 + MODE0 + ZBIT0	;binary
	binit	TMR2, 0
	binit	TMR2, 0		; 65536

;		  0
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

	binit	ICW1M,	BIT4+ ZBIT3 +BIT0	;bit3: 0=edge
	binit	ICW2M,	0x08			;INT 8..F vectors
	binit	ICW3M,	BIT2			;slave on IR2 is used
	binit	ICW4M,	ZBIT4+ZBIT1+BIT0	;bit4: SFNM off; bit1: AEOI off
	binit	OCW1M,	0xFF			;mask all interrupts
	binit	OCW3M,	BIT6+ZBIT5+ ZBIT4+BIT3+BIT1+BIT0 ;disable SpMskM,
						; enable read of ISreg

	binit	ICW1S,	BIT4+ ZBIT3 +BIT0	;bit3 0=edge
	binit	ICW2S,	0x70			;INT 70h-77h vectors
	binit	ICW3S,	2			;slave is #2
	binit	ICW4S,	ZBIT4+ZBIT1+BIT0	;no SFNM, no AEOI on slave
	binit	OCW1S,	0xFF			;mask all interrupts
	binit	OCW3S,	BIT6+ZBIT5+ ZBIT4+BIT3 +BIT1+BIT0 ;disable SpMskM,



; enable read of ISreg
;  serial character output:
	binit   TBR0, '*'       ;Test output one character

        dw      -1

	global	_bda_ptr
	global	bda_ptr
_bda_ptr:
bda_ptr:	dw	0, BDA_segment

; initial contents of NVRAM on ice-cold start
;
NVRAM00:
	dw	00_0000_00111_00_0_11		;serial line
; no protocols, rsvd, baud=9600, no parity, 1 stop, 8-bit

	db	0,0,0,0,0,0,0,0	; 8 empty disk table slots
	times (31-8-2) db 0



segment _TEXT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; initb_cx	primitive entry
; initb		callable entry (but uses CX)
;
;    Enter with:
;
;	DS:SI	pointing at the table of BYTES to init.
;	CX	used to hold the return address
;
;    Exit with:
;	AX,DX	trashed
;	CX	used to hold the return
;	SI	updated
;	
;	All other registers preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	initb
initb:
        pop     cx
initb_cx:
	lodsw                   ; get destination port
        mov     dx,ax		; put where useful
        inc     ax              ; test for EOF
	jz	.9		; EOF? if so, return

	lodsb                   ; get port value
        out     dx,al           ; output port value
        jmp     initb_cx
.9:
        jmp     cx              ; EOF, return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; initw_cx	primitive entry
; initw		callable entry (but uses CX)
;
;    Enter with:
;
;	DS:SI	pointing at the table of WORDS to init.
;	CX	used to hold the return address
;
;    Exit with:
;	AX,DX	trashed
;	CX	used to hold the return
;	SI	updated
;	
;	All other registers preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
initw:
        pop     cx
initw_cx:
	lodsw                   ; get destination port
        mov     dx,ax		; put where useful
        inc     ax              ; test for EOF
	jz	.9		; EOF? if so, return

	lodsw                   ; get port value
        out     dx,ax           ; output to word port
        jmp     initw_cx
.9:	jmp	cx		; EOF, return



segment _TEXT
;       global  start
start:
        cli
	mov	bp,dx		;save Component ID
; Enable access to the Expanded I/O ports (F000..FXXX)
        in	al,REMAPCFGH	; reset the state machine (state A)
        mov     ax,0x8000
        out     REMAPCFGH,al	; move to (state B)
        xchg    ah,al
        out     REMAPCFGL,al	; move to (state C)
        out     REMAPCFG,ax	; move to (state D), sets ESE bit
; Expanded I/O is now available -- ESE bit is set
        cld                     ; do this as insurance (direction=forward)

	mov	ax,DGROUP	; set up data area (CONST & CONST2)
	mov	ds,ax		;  addressing thru DS
	cnop
	mov	es,ax		;  and ES
	cnop

; Do the word port initialization
;
        mov     si,wtab1        ; get table address to SI
        mov     cx,return2      ; set return address
        jmp     initw_cx        ; simulate call
return2:

; Do the byte port initialization
;
        mov     si,btab1        ; get table address to SI
        mov     cx,return1      ; set return address
        jmp     initb_cx        ; simulate call
return1:

	cmp	bp,0x2309	; device ID
	je	$+3
	hlt			; not on this device
	xor	bp,bp		; restore to 0

%if 1
	mov	dx,0x4FF
	mov	al,dl
	out	dx,al		; Zap jrc LEDs to 0xFF
%endif


; Size the SRAM
size_SRAM:
	mov	di,SRAM_AD>>4	; SRAM segment
	mov	ss,di		; set up SS
	cnop
	mov	es,di		; set ES for later testing
	cnop
	mov	dx,(32<<8)	; DH=32, DL=0
.2:
	mov	di,dx		; get address
	shl	di,10		; convert to Kilobytes
   ss	mov	[di],dl		; store a byte
   	inc	dl
	cmp	dl,dh		; test up to 32K
	jb	.2
; compute SRAM size
   ss	sub	dl,[0]
   	shl	dx,10		; convert DL to DX=?? Kilobytes
	mov	sp,dx		; SS:8000h is stack start for 32K SRAM

; test the SRAM
	shr	dx,2		; count of DWORDs
	xor	si,si		; ES:SI is area to test
	mov	bx, .3
	jmp	seg_test_bx	; do the single bit test
.3:  ; return here


; All okay with the SRAM
; We now have a stack, & can use CALL
;	shr	dx,8    (already shifted by 2) == Kbytes in DL
;   so we will just use DH as the Kilobyte count
%if HALF_MEM
	mov	bp,dx		; Save SRAM size in BP for later
%else
	xor	bp,bp		; No SRAM, just DRAM was tested
%endif


;
; Test low 64K memory and ROM checksum
;
	mov	al,0001b	; show '0001' in the LITES
	call	lites
;
; Test and zero the entirety of SEGMENT 0x0000:xxxx
;
	xor	si,si
	mov	es,si		; select segment 0
	mov	dx,1<<14	; 16K dwords = 64K bytes
	call	seg_test

; Will halt with '0001' in the LITES if there is a memory problem


; Calculate ROM CRC
;
crc_computation:
	mov	ax,cs
	mov	es,ax		; ES:BX addresses ROM
	cnop

	xor	ax,ax
	mov	bx,(CRC_AT+2)&0xFFFF	;start here
	xor	cx,cx
	xor	dx,dx		;overflow for 1's complement
; CRC16 computation
	extern	crc16

	call	crc16
	or	ax,ax		; test for zero checksum
	jz	.1
	hlt
.1:



; Determine the CPU frequency

get_CLKOUT:
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

;
; set up the refresh counter correctly
	mov	ax,bx		; count in khz
	shr	ax,6		; divide by 64khz
	mov	dx,RFSCIR	; Refresh Count
	out	dx,ax

; put out CPU frequency message

	lea	ax,[bx+500]	; round to nearest integer
	mov	cx,1000
	xor	dx,dx
	div	cx		;integer frequency
%if 1
	mov	dx,0x4FF	; jrc LEDs
	out	dx,al
%endif
	dec	ax
	dec	ax		; divisor is 2 less
	mov	dx,CLKPRS	; pre-scale clock
	out	dx,ax		; PSCLK is now 1.000 mhz (1 usec clock)

	get_bda	ES
   es	mov	[CPU_freq],bx
	mov	bx,bp		;restore SRAM size to BH
   es	mov	[SRAM_size],bh


%if 0
	pusha

	extern	uart_det_
	mov	ax,0x3F8
; this call will trash AX,BX,CX,DX
	call	uart_det_
; this detection code confirms that the UART on the 386EX is a 16450

%if 1
	mov	dx,0x4FF	; jrc LEDs
	out	dx,al
%endif
	popa
%endif


	mov	al,0010b	; show '0010' in the LITES
	call	lites

;
; Test memory from 1000:0000h to 7000:FFFFh
;
test_1to8:
	xor	si,si
	mov	dx,1<<14	; 16K dwords
	mov	ax,1000h	; 2nd 64K segment
.1:	mov	es,ax		; set the segment register
	cnop
	call	seg_test	; halts on error
	mov	ax,es
	add	ah,10h		; increment to next segment
%if HALF_MEM
	cmp	ah,0x80		; are we done
%else
	cmp	ah,0xA0		; test all of low 64K
%endif
	jb	.1

	; segment 8000:0000 is not yet enabled


;
; Set up the interrupt vectors in 0x0000:  0000h..0200h
;
; ES will point at location 0:0
;
set_the_vectors:
	get_loc0 ES
	xor	di,di
; DS is set to DGROUP already
	mov	si,page0vectors	; DS:SI points at word addresses
	mov	cx,n_page0vectors
	mov	ax,cs		; CS=0xF000
.1:
	movsw			;move low word of address
	stosw			;set segment part
	loop	.1

%if 0
	get_bda	ES
	xor	di,di		; set to zero the BDA
	mov	cx,AT_status_byte	; length
;;;	mov	al,0		; AX is F000 from above
	rep stosb
%endif

;
; vectors for int's 00..7Fh are set
;

	get_bda	ES		;get the BDA pointer
   es	mov	word [memory_size],640	; conventional memory size


; test for presence of the FPU
;
	mov     dx,P3PIN        ; get P3 port status
        in      al,dx           ; P3.0 is co-processor presence detect
	test	al,01		; test for FPU present==0, absent==1
	jnz	skip_fpu	

    es	or	word [equip_flag],BIT1	;set h/w FPU flag

	mov	al,0101b		; FPU error code
	call	lites

	fninit				; this may hang

skip_fpu:
	mov	al,0100b		; FPU clear code
	call	lites

	extern	ext_mem_size
	call	ext_mem_size

	get_BDA	ES

	dec	ax
	mov	dx,0x4FF
	out	dx,al
	shl	ax,20-10			;convert MB count to Kbyte count

   es	mov	[extended_memory],ax	; save Ext Mem count

; 
; read the NVRAM into the BIOS Data Area
;
	get_BDA	ES
	mov	bx,nvram_info		; ES:BX points at BDA extension

	mov	ax, 0x20<<8 | 31	; burst read all NVRAM
	extern	ds_read
	call	ds_read
	jnc	form_crc
ds_err:
	mov	al,1111b
	call	lites
	hlt

form_crc:
	get_BDA	ES
	mov	bx,nvram_info		; ES:BX points at BDA extension
	mov	cx,31			; use 31 bytes
	extern	crc7
	call	crc7

	push	0
	mov	bp,sp			; address the stack

	or	al,al			; is the CRC zero?
	jz	.2
	or	byte [bp],1		; flag CRC error

	mov	si,DGROUP		; make sure DS is correct
	mov	ds,si

	mov	si,NVRAM00		;DS is already set

	mov	di,nvram_info		; ES is *BDA
	mov	cx,31
	rep	movsb

.2:
	extern	get_time
	call	get_time
	jnc	.3
	or	byte [bp],2		; flag clock stopped
.3:
	extern	ds_get_charge
	call	ds_get_charge
	xor	al,0xA0
	test	al,0xF0			; charge enabled flag is 1010_....
	jnz	.7
	test	al,0x03			; charge disabled if R not in [1,2,3]
	jz	.7
	and	al,0x0C			; charge disabled if D==0
	jz	.7
	xor	al,0x0C			; charge disabled if D==3
;;;;	jz	.7
	jnz	.8

.7:	or	byte [bp],4		; charging disabled
.8:

	extern	start_timer0_
	call	start_timer0_		; in 1Ah_time.asm

	mov	ax,[bp]			; argument to _main_

	extern	_main__			; C-callable
	sti			; enable interrupts
	call	_main__
  
	call	lites

	cli
	hlt
	jmp	$-2


; STOP STOP STOP STOP
segment CONST
	global _SecBuffer		; for TESTIDE.C
_SecBuffer	dw	0x0200,0x6000 ;  in high memory

segment	_TEXT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; seg_test -- test a segment of memory (variable size)
; seg_test_bx	ditto, but returns through BX
;
;    Enter with:
;	ES:SI	points at area to test
;	DX	count of size of area in DWORDS (16K==full segment)
;
;    Exit with:
;	ES:SI	unchanged
;	DX	unchanged
;	memory area is cleared to Zeroes if successful
;
;    Error Condition:
;	*** WILL HALT ***	so have the LITES set up
;
;    Trashes:
;	EAX
;	BX	is used for the return
;	CX
;	DI
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

seg_test:
	pop	bx
seg_test_bx:

	mov	eax,1		; EAX = 0000_0001h
.4:
	xor	di,di		;
	mov	cx,dx		; set DWORD count
	rep stosd		; store all of memory

	mov	cx,dx		; reset the count
	xor	di,di		; reset start address
	repe	scasd		;
	je	.5		; continue on no error
	hlt			; with the LITES as set

.5:	shl	eax,1
	jnc	.4
; now zero the SRAM
	xor	di,di		; reset the start address
	mov	cx,dx		; reset the count
	rep	stosd		; zero the SRAM

	jmp	bx	; return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; lites -- show a 4-bit value in the lites
; lites_ -- Watcom C callable:   "int lites(int value);"
;
;    Enter with:
;	AL	set to value to display (0h..0Fh)
;
;    Exit with:
;	All registers preserved
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	lites_
lites_:
lites:
	pushm	ax,dx

	cli
	cld
	mov	dx,P1LTC	; get the LITES latch
	not	al
	shl	al,4		; shift complement to position
	mov	ah,al		; save in AH
	in	al,dx		; read the latch
	and	al,0Fh		; preserve bits
	or	al,ah		; set the new bits
	out	dx,al		; put out the new LITES value

	popm	ax,dx
	ret

	global	jleds_
jleds_:
	pushm	dx
	mov	dx,0x4FF
	out	dx,al
	popm	dx
	ret

	global	jledsh_
jledsh_:
	pushm	dx
	mov	dx,0x4FF
	out	dx,al
	popm	dx
	cli
	hlt
	ret



;****** debugging stuff ******
%if 0


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
%endif



;        setloc (0x100000-(ROM<<10)-16)
	align	16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Real Mode statup jump
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	bits	16
	jmp	far origin
	times 9 db 0FFh
	db	0FCh, 00h		; PC/AT

segment BOOT
%include "boot.asm"

