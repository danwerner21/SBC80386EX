;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; i386EX.inc  --  register definitions for the Intel 80386EX processor
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2018 John R. Coffman.  All rights reserved.
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

;/* i386EX.inc  --  register definitions for the Intel 80386EX processor
;
%define defb
%define defw
%define defd
;*/

;/* The Address Configuration register
;*/
defb REMAPCFGH  equ     0x0023
defb REMAPCFGL  equ     0x0022
defw REMAPCFG   equ     0x0022

;/* The A20gate and fast CPU Reset
;*/
defb PORT92     equ     0xF092
defb PORT92_AT  equ     0x0092

; 
;/* The DMA Controller and Bus Arbiter
;*/
defb DMA0TAR    equ     0xF000
defb DMA0TAR_AT equ     0x0000
defb DMA0BYC    equ     0xF001
defb DMA0BYC_AT equ     0x0001
defb DMA1TAR    equ     0xF002
defb DMA1TAR_AT equ     0x0002
defb DMA1BYC    equ     0xF003
defb DMA1BYC_AT equ     0x0003
defb DMACMD1    equ     0xF008
defb DMACMD1_AT equ     0x0008
defb DMASTS     equ     0xF008
defb DMASTS_AT  equ     0x0008
defb DMASRR     equ     0xF009
defb DMASRR_AT  equ     0x0009
defb DMAMSK     equ     0xF00A
defb DMAMSK_AT  equ     0x000A
defb DMAMOD1    equ     0xF00B
defb DMAMOD1_AT equ     0x000B
defb DMACLRBP   equ     0xF00C
defb DMACLRBP_AT equ    0x000C
defb DMACLR     equ     0xF00D
defb DMACLR_AT  equ     0x000D
defb DMACLRMSK  equ     0xF00E
defb DMACLRMSK_AT equ   0x000E
defb DMAGRPMSK  equ     0xF00F
defb DMAGRPMSK_AT equ   0x000F
defb DMA0REQ0_1 equ     0xF010
defb DMA0REQ2_3 equ     0xF011
defb DMA1REQ0_1 equ     0xF012
defb DMA1REQ2_3 equ     0xF013
defb DMABSR     equ     0xF018
defb DMACHR     equ     0xF019
defb DMAIS      equ     0xF019
defb DMACMD2    equ     0xF01A
defb DMAMOD2    equ     0xF01B
defb DMAIEN     equ     0xF01C
defb DMAOVFE    equ     0xF01D
defb DMACLRTC   equ     0xF01E
;
;/* The DMA Page Registers
;*/
defb DMA1TAR2    equ    0xF083
defb DMA1TAR2_AT equ    0x0083
defb DMA1TAR3    equ    0xF085
defb DMA1TAR3_AT equ    0x0085
defb DMA0TAR3    equ    0xF086
defb DMA0TAR3_AT equ    0x0086
defb DMA0TAR2    equ    0xF087
defb DMA0TAR2_AT equ    0x0087
;
defb DMA0BYC2   equ     0xF098
defb DMA1BYC2   equ     0xF099

;
;/* The Master Interrupt Controller
;*/
defb ICW1M_AT   equ     0x0020
defb ICW2M_AT   equ     0x0021
defb ICW3M_AT   equ     0x0021
defb ICW4M_AT   equ     0x0021
defb OCW1M_AT   equ     0x0021
defb OCW2M_AT   equ     0x0020
defb OCW3M_AT   equ     0x0020

defb ICW1M      equ     0xF020
defb ICW2M      equ     0xF021
defb ICW3M      equ     0xF021
defb ICW4M      equ     0xF021
defb OCW1M      equ     0xF021
defb OCW2M      equ     0xF020
defb OCW3M      equ     0xF020
defb IRR_M	equ	0xF020

;
;/* The Slave Interrupt Controller
;*/
defb ICW1S_AT   equ     0x00A0
defb ICW2S_AT   equ     0x00A1
defb ICW3S_AT   equ     0x00A1
defb ICW4S_AT   equ     0x00A1
defb OCW1S_AT   equ     0x00A1
defb OCW2S_AT   equ     0x00A0
defb OCW3S_AT   equ     0x00A0
defb IRR_M_AT	equ	0x00A0

defb ICW1S      equ     0xF0A0
defb ICW2S      equ     0xF0A1
defb ICW3S      equ     0xF0A1
defb ICW4S      equ     0xF0A1
defb OCW1S      equ     0xF0A1
defb OCW2S      equ     0xF0A0
defb OCW3S      equ     0xF0A0

;
;/* The Timer/Counter Unit
;*/
defb    TMR0    equ     0xF040
defb    TMR0_AT equ     0x0040
defb    TMR1    equ     0xF041
defb    TMR1_AT equ     0x0041
defb    TMR2    equ     0xF042
defb    TMR2_AT equ     0x0042
defb    TMRCON  equ     0xF043
defb    TMRCON_AT  equ  0x0043

;
;/* The Chip Select Unit
;*/
defw    CS0ADL  equ     0xF400
defw    CS0ADH  equ     0xF402
defw    CS0MSKL equ     0xF404
defw    CS0MSKH equ     0xF406
defw    CS1ADL  equ     0xF408
defw    CS1ADH  equ     0xF40A
defw    CS1MSKL equ     0xF40C
defw    CS1MSKH equ     0xF40E
defw    CS2ADL  equ     0xF410
defw    CS2ADH  equ     0xF412
defw    CS2MSKL equ     0xF414
defw    CS2MSKH equ     0xF416
defw    CS3ADL  equ     0xF418
defw    CS3ADH  equ     0xF41A
defw    CS3MSKL equ     0xF41C
defw    CS3MSKH equ     0xF41E
defw    CS4ADL  equ     0xF420
defw    CS4ADH  equ     0xF422
defw    CS4MSKL equ     0xF424
defw    CS4MSKH equ     0xF426
defw    CS5ADL  equ     0xF428
defw    CS5ADH  equ     0xF42A
defw    CS5MSKL equ     0xF42C
defw    CS5MSKH equ     0xF42E
defw    CS6ADL  equ     0xF430
defw    CS6ADH  equ     0xF432
defw    CS6MSKL equ     0xF434
defw    CS6MSKH equ     0xF436
defw    UCSADL  equ     0xF438
defw    UCSADH  equ     0xF43A
defw    UCSMSKL equ     0xF43C
defw    UCSMSKH equ     0xF43E

;
;/* The Synchronous Serial I/O Unit
;*/
defw    SSIOTBUF equ    0xF480
defw    SSIORBUF equ    0xF482
defw    SSIOBAUD equ    0xF484
defw    SSIOCON1 equ    0xF486
defw    SSIOCON2 equ    0xF488
defw    SSIOCTR  equ    0xF48A

;
;/* The Refresh Control Unit
;*/
defw    RFSBAD  equ     0xF4A0
defw    RFSCIR  equ     0xF4A2
defw    RFSCON  equ     0xF4A4
defw    RFSADD  equ     0xF4A6

;
;/* The Watchdog Timer Unit
;*/
defw    WDTRLDH equ     0xF4C0
defw    WDTRLDL equ     0xF4C2
defw    WDTCNTH equ     0xF4C4
defw    WDTCNTL equ     0xF4C6
defw    WDTCLR  equ     0xF4C8
defb    WDTSTATUS  equ  0xF4CA

;
;/* Clock Generation and Power Management
;*/
defb    PWRCON  equ     0xF800
defw    CLKPRS  equ     0xF804

;
;/* Device Configuration Registers
;*/
defb    P1CFG   equ     0xF820
defb    P2CFG   equ     0xF822
defb    P3CFG   equ     0xF824
defb    PINCFG  equ     0xF826
defb    DMACFG  equ     0xF830
defb    INTCFG  equ     0xF832
defb    TMRCFG  equ     0xF834
defb    SIOCFG  equ     0xF836

;
;/* Parallel I/O Ports
;*/
defb    P1PIN   equ     0xF860
defb    P1LTC   equ     0xF862
defb    P1DIR   equ     0xF864
defb    P2PIN   equ     0xF868
defb    P2LTC   equ     0xF86A
defb    P2DIR   equ     0xF86C
defb    P3PIN   equ     0xF870
defb    P3LTC   equ     0xF872
defb    P3DIR   equ     0xF874


; bits.inc
;
; assembly language bit definitions
;
defb    BIT0    equ     0x01
defb    BIT1    equ     0x02
defb    BIT2    equ     0x04
defb    BIT3    equ     0x08
defb    BIT4    equ     0x10
defb    BIT5    equ     0x20
defb    BIT6    equ     0x40
defb    BIT7    equ     0x80

defw    BIT8    equ     0x0100
defw    BIT9    equ     0x0200
defw    BIT10   equ     0x0400
defw    BIT11   equ     0x0800
defw    BIT12   equ     0x1000
defw    BIT13   equ     0x2000
defw    BIT14   equ     0x4000
defw    BIT15   equ     0x8000

defd    BIT16   equ     0x00010000
defd    BIT31   equ     0x80000000

defb    ZBIT0    equ     0
defb    ZBIT1    equ     0
defb    ZBIT2    equ     0
defb    ZBIT3    equ     0
defb    ZBIT4    equ     0
defb    ZBIT5    equ     0
defb    ZBIT6    equ     0
defb    ZBIT7    equ     0

defw    ZBIT8    equ     0
defw    ZBIT9    equ     0
defw    ZBIT10   equ     0
defw    ZBIT11   equ     0
defw    ZBIT12   equ     0
defw    ZBIT13   equ     0
defw    ZBIT14   equ     0
defw    ZBIT15   equ     0


;
;/* Asynchronout Serial I/O channel 0  (COM1)
;*/
defb    RBR0_F4 equ     0xF4F8
defb    TBR0_F4 equ     0xF4F8
defb    DLL0_F4 equ     0xF4F8
defb    DLH0_F4 equ     0xF4F9
defb    IER0_F4 equ     0xF4F9
defb    IIR0_F4 equ     0xF4FA
defb    LCR0_F4 equ     0xF4FB
defb    MCR0_F4 equ     0xF4FC
defb    LSR0_F4 equ     0xF4FD
defb    MSR0_F4 equ     0xF4FE
defb    SCR0_F4 equ     0xF4FF

defb    RBR0    equ     0x03F8
defb    TBR0    equ     0x03F8
defb    DLL0    equ     0x03F8
defb    DLH0    equ     0x03F9
defb    IER0    equ     0x03F9
defb    IIR0    equ     0x03FA
defb    LCR0    equ     0x03FB
defb    MCR0    equ     0x03FC
defb    LSR0    equ     0x03FD
defb    MSR0    equ     0x03FE
defb    SCR0    equ     0x03FF

;
;/* Asynchronout Serial I/O channel 1  (COM2)
;*/
defb    RBR1_F8 equ     0xF8F8
defb    TBR1_F8 equ     0xF8F8
defb    DLL1_F8 equ     0xF8F8
defb    DLH1_F8 equ     0xF8F9
defb    IER1_F8 equ     0xF8F9
defb    IIR1_F8 equ     0xF8FA
defb    LCR1_F8 equ     0xF8FB
defb    MCR1_F8 equ     0xF8FC
defb    LSR1_F8 equ     0xF8FD
defb    MSR1_F8 equ     0xF8FE
defb    SCR1_F8 equ     0xF8FF

defb    RBR1    equ     0x02F8
defb    TBR1    equ     0x02F8
defb    DLL1    equ     0x02F8
defb    DLH1    equ     0x02F9
defb    IER1    equ     0x02F9
defb    IIR1    equ     0x02FA
defb    LCR1    equ     0x02FB
defb    MCR1    equ     0x02FC
defb    LSR1    equ     0x02FD
defb    MSR1    equ     0x02FE
defb    SCR1    equ     0x02FF

; LSRx bits

defb    LSR_TE  equ     BIT6
defb    LSR_TBE equ     BIT5
defb    LSR_BI  equ     BIT4
defb    LSR_FE  equ     BIT3
defb    LSR_PE  equ     BIT2
defb    LSR_OE  equ     BIT1
defb    LSR_RBF equ     BIT0

;
; Bits in CR0
;
defb    CR0_PE  equ     BIT0
defb    CR0_MP  equ     BIT1
defb    CR0_EM  equ     BIT2
defb    CR0_TS  equ     BIT3
defd    CR0_WP  equ     BIT16
defd    CR0_PG  equ     BIT31

;
; Some ASCII character codes
;
defb    ASCII_NUL       equ     0x00
defb    ASCII_BS        equ     0x08
defb    ASCII_HT        equ     0x09
defb    ASCII_NL        equ     0x0A
defb    ASCII_FF        equ     0x0C
defb    ASCII_CR        equ     0x0D
defb	ASCII_ESC	equ	0x1B
defb    ASCII_SP        equ     0x20
defb    ASCII_DEL       equ     0x7F


;/* End of i386EX.inc */
