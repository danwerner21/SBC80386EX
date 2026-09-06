;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ds1302.asm -- access to the RTC and NVRAM
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
;	SBC-386EX 2.0	production / January 2017
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/
;
;**********
; N.B. These will move to P1 from P3 on the final board
; Jan 2018 -- updated to P1 for rev 2.0 board
;**********
DSLTC   equ     P1LTC           ; DS1302 latch
DSPIN   equ     P1PIN           ;   pin value

DSDAT   equ     BIT0            ; Data must be bit 0 & idles high
DSCLK   equ     BIT2            ; Clock idles high
DSRST   equ     BIT3            ; Reset idles low (asserted)

DSMSK   equ     DSRST+DSCLK+DSDAT


%macro  nvdelay 0
        jmp     $+2
        jmp     $+2
        jmp     $+2
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; INT 1A
; function 20   Get NVRAM byte
;
; Enter with:
;       AH      0x20
;       AL      byte number ( 0 <= AL <= 30) 
;   (single byte read)
;
;       AH      0x20
;       AL      31
;       ES:BX   pointer to 31 byte buffer
;   (burst read)
;
; Exit with:
;       AL      byte read (single byte read)
;       Carry clear
;
;       AL      byte NVRAM[30] (burst read)
;       ES:BX buffer filled with bytes 0..30
;
;       Carry clear
;
; Error:
;       Carry set
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
nv_read:
        pushm   ax,dx

	cmp	al,31
	jae	nv_burstr	; burst or error

; single byte read
	shl	ax,9		; AH = AL<<1
        or      ah,1100_0001B   ; RAM/READ

	call	nv_reset_on	;start of command, set AL & DX

; output the command, will turn Reset off
        call    nv_outb

	call	nv_inb		;input byte to AH

nv_read_exit:
	mov	al,ah		;return in AL
	pop	dx		;get old ax
	mov	ah,dh		;restore AH
	jmp	nv_good_exit	;clear Carry & restore CX,DX



;
; handle burst read
nv_burstr:
        jne	nv_error	;must be 31 exactly, else error

	pushm	bx,cx		;extra save

	call	nv_reset_on	;reset before command byte

	mov	ah,1111_1111B	;burst read command
	call	nv_outb		;output the command

	mov	cx,31		;
nv_read2:
	call	nv_inb		;retrieve a byte in AH
  es	mov	byte [bx],ah	;save in the array
  	inc	bx
	loop	nv_read2	;and loop back

	popm	bx,cx		;and restore
        jmp	nv_read_exit	;return AH
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; INT 1A
; function 21   Set NVRAM byte
;
; Enter with:
;       AH      0x21
;       AL      byte number ( 0 <= AL <= 30) 
;   (single byte write)
;       CL      byte value to write
;
;       AH      0x21
;       AL      31
;       ES:BX   pointer to 31 byte buffer
;   (burst write)
;
; Exit with:
;       Carry clear
;
; Error:
;       Carry set
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
nv_write:
        pushm   ax,dx

	cmp	al,31
	jae	nv_burstw	; burst or error

; single byte write
	shl	ax,9		; AH = AL<<1
        or      ah,1100_0000B   ; RAM/WRITE

	call	nv_reset_on	;start of command, set AL & DX

; output the command, will turn Reset off
        call    nv_outb

        mov     ah,cl		;single byte to write
        call    nv_outb

nv_full_exit:
	popm	ax
nv_good_exit:
	clc 			;signal good return
nv_exit:
	popm	dx
	ret	
;	IRET


nv_error:
	pop	ax
	stc
	jmp	nv_exit


; burst write
nv_burstw:
        jne	nv_error	;must be 31 exactly, else error

	pushm	bx,cx		;extra save

	call	nv_reset_on	;reset before command byte

	mov	ah,1111_1110B	;burst write command
	call	nv_outb		;output the command

	mov	cx,31		;
nv_write2:
   es	mov	ah,byte [bx]	;get byte to write
   	call	nv_outb
	inc	bx		;increment
	loop	nv_write2

	popm	bx,cx
	jmp	nv_full_exit	;restore & return



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; utility programs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; assert the RTC reset pin
;
;	exit with Clock High and Input Mode
;
nv_reset_on:
	mov	dx,DSLTC	;Latch I/O address to be kept in DX
	in	al,dx		;read the latch value
	and	al,~DSRST	;set Reset asserted
	or	al,DSDAT+DSCLK	;set Clock high, Read mode
nv_out_latch:
	out	dx,al		;output to latch
nv_delay:
	nvdelay			;delay
        ret


; remove Reset from the RTC pin
;	do not affect the Clock pin
;
nv_reset_off:		;assume latch value is in AL
	or	al,DSRST	;
	jmp	nv_out_latch


; output a byte turning Reset off in the process
;	byte is in AH
;	latch status is in AL
;	exit with Clock High
;
nv_outb:
	pushm	cx		;save register

	mov	cx,8		;count 8 bits
	or	al,DSRST	;turn Reset off
nv_outb1:
	shr	ax,1		;data LSB to bit7
	rol	al,1		;data to bit0
	and	al,~DSCLK	;drop the clock
	call	nv_out_latch	;output the latch
	or	al,DSCLK	;raise the clock
	call	nv_out_latch	;clock in the data bit
	loop	nv_outb1	;count the bits

	popm	cx
        ret


; input a byte
;	latch status is in AL
;	return byte in AH
;	exit with Clock High
;
nv_inb:
	pushm	cx		;register save

	mov	cl,8		;count 8 bits
	or	al,DSDAT	;set Read mode
nv_inb1:
	and	al,~DSCLK	;drop the clock
	call	nv_out_latch	;**
	mov	dx,DSPIN	;set to read data bit
	mov	ch,al		;save latch in CH
	in	al,dx		;read the bit
	ror	ax,1		;shift data into bit15
	mov	al,ch		;restore latch
	mov	dx,DSLTC	;restore latch address
	or	al,DSCLK	;raise the clock
	call	nv_out_latch	;**
	dec	cl
	jnz	nv_inb1		;loop for 8 bits

	popm	cx		;restore
	ret




