;
; start.asm
;
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
;
%define P3_FPU_CHECK 	0
%define wFPU 		1
%define HALF_MEM 	0		; 1 = exclude DRAM that overlaps the ROM
				; 0 = DRAM & ROM overlap
%define SHADOW_MODE 	0		; shadow ROM in DRAM
%define WATCH_BUS 	1		; Watchdog timer monitors bus

;%define MFPIC 		1	; no COMCLK, use MFPIC (defined in i386ex.inc)

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
%include "timer.inc"
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
	winit	CS4ADL, (SRAM_AD&0xF800)| ZBIT9+BIT8 + 0;w.s.  8-bit, MEM, ~RDY
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
	winit	CS1ADL, (0x1F0 <<10) & 0xFFFF | ZBIT9+ZBIT8 + ZBIT7+ 3;w.s.
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

%if WATCH_BUS
; set up the WATCHDOG timer to monitor the bus
;  try to trap FPU hangs
;
	winit	WDTSTATUS, BIT1		; set BUSMON
; PWRCON must also be set to enable this function (a byte init)
%endif

	dw	-1		;EOF marker




btab1:
        binit   PORT92_AT,0x02  ; enable the A20 line
;    LITES[3:0], DSRST, DSCLK, RTS0#, DSDAT
	binit   P1LTC, 0x63	; LITES (weak)1100 --> 1001 (inverted outputs)
				; DSRST asserted, DSCLK low, RTS0# de-asserted, DSDAT o.c. high
	binit	P1DIR, 0x00+BIT0 	; LITES (7..4) are DRIVEN now, DSDAT is input
        binit   P1CFG, BIT1     ; RTS0# is connected to SIO0

%if WATCH_BUS|1
; for the WATCHDOG timer bus monitor READY function
	binit	PWRCON, BIT3+BIT2	; WDTRDY | HSREADY  enable
%endif

;    CTS0#, TXD0, RXD0, CS4, CS3, CS2, CS1, CS0
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

        binit   TMRCFG, ZBIT7+TIMER_STOP ; bit6: s/w control of GATEn, bit7=0 enables all clocks

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
        binit   LCR0, 7         ; 8-bit, no parity, 2 stop bits
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
	dw	00_0000_00111_00_1_11B		;serial line
; no protocols, rsvd, baud=9600, no parity, 2 stop, 8-bit

	db	0,0		; 2 empty floppy slots
	db	0,0,0,0,0,0,0,0	; 8 empty disk table slots
	times (NVRAM00+31-$) db 0



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
;	global	start		; declared above
start:
        cli
	cmp	dx,0x2309	; device ID
	je	start1
error_halt:
	cli
	hlt
	jmp	$-1

start1:
; test the Flags register
%if 1
	mov	ah,0xD5		;set the S, Z, A, P, C flags
	sahf
	nop
	nop
	jnc	error_halt
	jnz	error_halt
	jns	error_halt
	jnp	error_halt

	clc
	jc	error_halt
	xor	ah,ah
	jc	error_halt
	jnz	error_halt
	sahf
	jp	error_halt
	js	error_halt
	jz	error_halt
	jc	error_halt

%endif

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


%if 1
	mov	dx,0x4FF
	mov	al,dl
	out	dx,al		; Zap jrc LEDs to 0xFF
%endif

	mov al,0011b
	call lites

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
%if HALF_MEM | 1
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
; removed for debug purposes
crc_computation:
;	mov	ax,cs
;	mov	es,ax		; ES:BX addresses ROM
;	cnop
;
;	xor	ax,ax
;	mov	bx,(CRC_AT+2)&0xFFFF	;start here
;	xor	cx,cx
;	xor	dx,dx		;overflow for 1's complement
; CRC16 computation
	extern	crc16
;
;	call	crc16
;	or	ax,ax		; test for zero checksum
;	jz	.1
;	hlt
.1:



; Determine the CPU frequency

get_CLKOUT:
%if MFPIC & 0
	mov	bx,33000	; 33mhz clock
%else
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
%endif
%if MFPIC
	mov	ax,bx
	call	wout
%endif
;

; set up the refresh counter correctly
	mov	ax,bx		; count in khz
	add	ax,5		; round up a bit
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

;;	pushm	bx,bp		; save CPU_freq & SRAM_size
  ;; 	popm	bx,bp

	get_bda	ES
   es	mov	[CPU_freq],bx
	mov	bx,bp		;restore SRAM size to BH
   es	mov	[SRAM_size],bh


%if 0
	pusha

	extern	uart_det_
;;;	mov	ax,RBR0
	mov	ax,0x03F8	;;; see what is on-chip
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

	shr	ax,6		; size in K bytes
	mov	bx,ax		; save in BX

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
  es	mov	word [memory_size],bx	; conventional memory size

; test for presence of the FPU
;

%if P3_FPU_CHECK
	mov     dx,P3PIN        ; get P3 port status
        in      al,dx           ; P3.0 is co-processor presence detect
	test	al,01		; test for FPU present==0, absent==1
	jnz	skip_fpu

    es	or	word [equip_flag],BIT1	;set h/w FPU flag

	mov	al,0101b		; FPU error code
	call	lites

	fninit				; this may hang

skip_fpu:

%else

; Intel code to check for FPU

fpu_check:
	mov	al,0111b
	call	lites

	mov	eax,cr0
	and	ax,~(CR0_EM+CR0_MP)	; make sure these are off
	mov	cr0,eax

	fninit

	mov	al,1001b
	call	lites

	push	bp
	mov	ax,5A5Ah	; garbage
	push	ax
	mov	bp,sp		; [bp] points at word

	fnstsw	[bp]

%if 0
	mov	ax,[bp]
	call	wout
%endif
	cmp	byte [bp],0	; .eq. if FPU present
	jne	.7

	mov	al,1010b
	call	lites

	fnstcw	[bp]

%if 0
	mov	ax,[bp]
	call	wout
%endif
	mov	ax,[bp]
	and	ax,103Fh
	cmp	ax,3Fh
	jne	.7

	mov	al,1011b
	call	lites

    es	or	word [equip_flag],BIT1	;set h/w FPU flag
.7:
	pop	bp
	pop	bp
%endif

	mov	al,0100b		; FPU clear code
	call	lites


	extern	ext_mem_size
	call	ext_mem_size

	get_bda	ES

	dec	ax
	mov	dx,0x4FF
	out	dx,al
	shl	ax,20-10			;convert MB count to Kbyte count

   es	mov	[extended_memory],ax	; save Ext Mem count

; prime the DS1302
;
	extern	ds_reset_on, ds_reset_off

	call	ds_reset_on
;;;	call	ds_reset_off
;;;	call	ds_reset_on
;;;	call	ds_reset_off

;
; read the NVRAM into the BIOS Data Area
;
	get_bda	ES
	mov	bx,nvram_info		; ES:BX points at BDA extension

	mov	ax, 0x20<<8 | 31	; burst read all NVRAM
	int	0x1A
	jnc	form_crc
ds_err:
	mov	al,1111b
	call	lites
	hlt

form_crc:
	push	0			; assume CRC okay
	mov	bp,sp			; saved in [bp]

	mov	ax,31			; actual CRC check
	call	get_nvram_crc_
%if 0
	push	ax
	mov	al,1010B
	call	lites
	pop	ax
%endif
	or	ax,ax
	jz	.2

	mov	si,DGROUP		; make sure DS is correct
	mov	ds,si
	mov	si,NVRAM00		;DS is already set

	get_bda	ES
	mov	di,nvram_info		; ES is *BDA
	mov	cx,31
	rep	movsb
	inc	byte [bp]		; flag bad

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

	mov	al,0101B	;calling _MAIN_
	call	lites

	mov	ax,DGROUP
	mov	ds,ax
	mov	es,ax

	mov	ax,[bp]			; argument to _main_

	extern	_main__			; C-callable
	sti			; enable interrupts
	call	_main__

	global	exit_
exit_:
%if 1
	mov	dx,0x4FF	; jrc LEDs
	out	dx,al
%endif
	call	lites

	cli
; enter POWERDOWN mode
	mov	dx,PWRCON
	in	al,dx
	and	al,~3
	or	al,BIT0
	out	dx,al
	nop
	hlt
	jmp	$-1


; STOP STOP STOP STOP
segment CONST
	global _SecBuffer		; for TESTIDE.C
;_SecBuffer	dw	0x0200,0x6000 ;  in high memory

_SecBuffer	dw	0x8000,0xA000	;

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

%if 1
	mov	dx,0x4FF
	mov	al,0xF5		; error code
	out	dx,al		; Zap jrc LEDs to 0xFF
	hlt			; with the LITES as set
%endif

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
	pushm	f,ax,dx

	mov	dx,P1LTC	; get the LITES latch
	not	al
	shl	al,4		; shift complement to position
	mov	ah,al		; save in AH
	cli
	in	al,dx		; read the latch
	and	al,0Fh		; preserve bits
	or	al,ah		; set the new bits
	out	dx,al		; put out the new LITES value

	popm	f,ax,dx
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
%if 1
	global	eout,dout,wout,bout,nout
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
%if 1
	pushm	dx,ax
	mov	ah,1		;write char
	mov	dx,0
	int	14h		;serial out
	popm	dx,ax
	ret
%else
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
%endif

;
; word get_nvram_crc(word n);
;	n = 31 (checks crc)
;	n = 29 (forms crc)
;
	global	get_nvram_crc_
get_nvram_crc_:
	pushm	bx,cx,es
	push	ax		; save count for nvram bytes

	mov	al,1001B
	call	lites

	sub	ax,ax		; start CRC at 0000
%if 1
	mov	bx,0xF000
	mov	es,bx
	mov	bx,0xFFF0
	mov	cx,16
	call	crc16
%endif
	get_bda	ES
	mov	bx,nvram_info
	pop	cx		; retrieve count in NVRAM
	call	crc16
	xchg	ah,al		; compensate for BIG Endian CRC16

	popm	bx,cx,es
	ret

	global	put_nvram_info_
put_nvram_info_:
	pushm	ax,bx,es

   	mov	ax,0x2200		;disable write protect
	int	0x1A

	mov	bx,nvram_info
	get_bda	ES
	mov	ax,0x211F		; write 31 burst bytes
	int	0x1A

	mov	ax,0x2280		; set write protect
	int	0x1A

	popm	ax,bx,es
	ret




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
