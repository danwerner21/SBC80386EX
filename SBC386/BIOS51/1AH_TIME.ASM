;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1Ah_time.asm -- date/time, NVRAM, and timers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "bda.inc"
%include "macro.inc"

%ifndef DEBUG
%define	DEBUG 1
%endif

	global	int_1Ah

segment	CODE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; INT 1A
;
; Enter with:
;       AH      function code
;
; Exit with:
;	varies
;
;       Carry clear
;
; Error:
;	AH	error code
;       Carry set
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_1Ah:
	sti			;turn on interrupts
	pushm	bx

	cmp	ah,len_dispatch0/2
	jb	low_dispatch
	sub	ah,0x20		;NVRAM SBC386 extensions
	cmp	ah,len_dispatch20/2
	jb	exec_dispatch20

fn_not_defined:
	mov	ah,0x86		;function not defined
	stc
exit:	
	popm	bx
	retf	2		;return from call

low_dispatch:
	sub	bh,bh		;zero BH
	mov	bl,ah		;index bytes
	add	bx,bx		;index words
	call	[dispatch0 + bx]
	jmp	exit

exec_dispatch20:
	sub	bh,bh		;zero BH
	mov	bl,ah		;index bytes
	add	bx,bx		;index words
	call	[dispatch20 + bx]
	jmp	exit



	align	2
dispatch0:
	dw	get_tick_count
	dw	set_tick_count
	dw	get_time
	dw	set_time
	dw	get_date
	dw	set_date
	dw	set_alarm
	dw	reset_alarm
len_dispatch0	equ	$-dispatch0

dispatch20:
	dw	ds_read
	dw	ds_write
len_dispatch20	equ	$-dispatch20

set_time:
get_date:
set_date:
set_alarm:
reset_alarm:
	jmp	fn_not_defined
;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 1A
; function 00	get_tick_count
;
;    Enter with:
;	AH	20h
;
;    Exit with:
;	CX:DX	tick count
;	AL	rolled over flag  0=no	1=day rollover
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	align	2
get_tick_count:
	push	ds		;save
	get_bda	DS
	cli		;disable interrupts
	mov	dx,[timer_count_low]
	mov	cx,[timer_count_high]
	xor	al,al
	xchg	al,[timer_overflow]
	sti		;restore interrupts
	clc
	pop	ds
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer 0 interrupt handler
;
;	Count down the tick timer
;	Reset if it reaches zero
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	int_irq0
	align	2
int_irq0:
	pushm	ds

	get_bda	DS
	inc	dword [timer_count]
	cmp	dword [timer_count],tick
	jae	.5
.2:
	int	0x1C
	popm	ds

	extern	clear_irq0	; currently in stub.asm
	jmp	clear_irq0

; tick went to zero (or negative)
.5:
	mov	byte [timer_overflow],1
	mov	dword [timer_count],0
	jmp	.2


; Timer 0 constants
;
clock	equ	921600
divide	equ	50619
tick	equ	clock*86400/divide
ttime	equ	(divide*1000000)/(clock)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 1A
; function 01	set_tick_count
;
;    Enter with:
;	AH	20h
;	CX:DX	tick count
;
;    Exit with:
;	nothing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set_tick_count:
	push	ds
	get_bda	DS	;address BDA
	cli		;disable interrupts
	mov	[timer_count_low],dx
	mov	[timer_count_high],cx
	mov	byte [timer_overflow],0	; 'byte' qualifier needed
	sti		;interrupts back on
	clc
	pop	ds
	ret




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; INT 1A
; function 02   Get Time
;
; Enter with:
;       AH      0x02
;
; Exit with:
;	CH	hours in BCD
;	CL	minutes in BCD
;	DH	seconds in BCD
;	DL	daylight savings time flag
;		  00=not DST, 01==DST
;	
;       Carry clear	if clock is running
;
; Error:
;       Carry set	if clock is stopped
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	global	get_time
get_time:
	pushm	ax
	xor	bx,bx		; saved at a higher level
	mov	ax, 1000_0001B << 8 | 0		;seconds
	mov	dl,al		; DST off
	call	byte_read
	mov	dh,ah		; save seconds

.1:	push	dx
	mov	ax, 1000_0001B << 8 | 1		; minutes
	call	byte_read
	mov	cl,ah		; save minutes
	mov	ax, 1000_0001B << 8 | 2		; hours
	call	byte_read
	mov	ch,ah		; save hours
	mov	ax, 1000_0001B << 8 | 0		;seconds
	call	byte_read
	pop	dx
	xchg	dh,ah
	cmp	ah,dh
	jne	.1		; loop back

	and	dh,0x7F		; mask clock halt bit
	add	ah,ah		; set carry if halted

	popm	ax
	ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;








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
	global	ds_read
ds_read:
        pushm   ax,dx

	cmp	al,31
	jae	ds_burstr	; burst or error
	
	mov	ah,1100_0001B	; NVRAM read
 	call	byte_read

ds_read_exit:
	mov	al,ah		;return in AL
	pop	dx		;get old ax
	mov	ah,dh		;restore AH
ds_good_exit:
	clc 			;signal good return
ds_exit:
	popm	dx
	ret	
;	IRET or  "retf 2"


ds_error:
	popm	ax
	stc
	jmp    ds_exit




;
; handle burst read
ds_burstr:
        jne	ds_error	;must be 31 exactly, else error

	pushm	bx,cx		;extra save

	call	ds_reset_on	;reset before command byte
	call	ds_reset_off	;set for read


	mov	ah,1111_1111B	;burst read command
	call	ds_outb		;output the command

	mov	cx,31		;
ds_read2:
	call	ds_inb		;retrieve a byte in AH
  es	mov	byte [bx],ah	;save in the array
  	inc	bx
	loop	ds_read2	;and loop back

	call	ds_reset_on	;terminate read

	popm	bx,cx		;and restore
        jmp	ds_read_exit	;return AH
 

; byte read into AH
;	AH = command bits
;	AL = register number
;
;  Uses AX, DX
;
byte_read:
; single byte read
	shl	al,1		; shift by one
        or      al,ah		; Clock or NVRAM read
	mov	ah,al		; command byte to AH

	call	ds_reset_on	;start of command, set AL & DX
	call	ds_reset_off	;remove the Reset

; output the command
        call    ds_outb

	call	ds_inb		;input byte to AH

	call	ds_reset_on	;terminate command

	ret



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
ds_write:
        pushm   ax,dx

	cmp	al,31
	jae	ds_burstw	; burst or error

; single byte write
	shl	al,1		; prepare command
        or      al,1100_0000B   ; RAM/WRITE
	mov	ah,al		; command byte to AH

	call	ds_reset_on	;start of command, set AL & DX
	call	ds_reset_off	;prepare for read

; output the command, will turn Reset off
        call    ds_outb

        mov     ah,cl		;single byte to write
        call    ds_outb

	call	ds_reset_on	;terminate the write

ds_full_exit:
	popm	ax
	jmp	ds_good_exit

	
	
; burst write
ds_burstw:
        jne	ds_error	;must be 31 exactly, else error

	pushm	bx,cx		;extra save

	call	ds_reset_on	;reset before command byte
	call	ds_reset_off	;prepare for burst write

	mov	ah,1111_1110B	;burst write command
	call	ds_outb		;output the command

	mov	cx,31		;
ds_write2:
   es	mov	ah,byte [bx]	;get byte to write
   	call	ds_outb
	inc	bx		;increment
	loop	ds_write2

	call	ds_reset_on	;terminate the write

	popm	bx,cx
	jmp	ds_full_exit	;restore & return



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


%macro  us_delay 0
        jmp     $+2
        jmp     $+2
        jmp     $+2
%endmacro


	align	2
ds_out_latch:
	out	dx,al
	us_delay
	ret

;
; initializes the DSLTC in DX
; sets the Clock low, then asserts Reset
;
ds_reset_on:
	mov	dx,DSLTC	;set I/O latch address in DX
	in	al,dx		;get the latch value
	and	al,~DSCLK	;set the clock low (should be idle state)
	or	al,DSDAT	;set data for input
	call	ds_out_latch
	and	al,~DSRST	;assert RESET#
	call	ds_out_latch
	ret

;
; sets the Clock low, then removes the Reset
;
ds_reset_off:		; assume DX is set
	and	al,~DSCLK	;set the clock low (idle)
	or	al,DSDAT	;set data for input
	call	ds_out_latch
	or	al,DSRST	;deassert RESET#
	call	ds_out_latch
	ret			;clock idles low

;
; moves output bit into position, and then drops the clock low
; pauses, then sets the clock high to clock in the data bit
; loops back for all 8 bits
; exits with the clock HIGH
;
ds_outb:	;output the byte in AH
	pushm	cx
	mov	cx,8		;8 bits go out

.1:	and	al,~DSCLK	;drop the clock
	shr	ax,1		;LSB to AL
	rol	al,1		;data bit to position
	call	ds_out_latch
	or	al,DSCLK	
	call	ds_out_latch
	loop	.1

	popm	cx
   	ret			;clock is high on exit

;
; sets clock High and data bit for input
; pauses, drops the clock, pauses, reads the data bit
; shifts 8 bits into AH from the left, hence LSB ends up in AX bit 8
; exits with the clock low
;
ds_inb:		;input a byte to AH
	pushm	cx
	mov	cx,8

.2:	or	al,DSCLK+DSDAT	;raise the clock, O.C. data set for input
	call	ds_out_latch
	and	al,~DSCLK	;drop the clock
	call	ds_out_latch
	push	dx
   	mov	dx,DSPIN	;set to read data bit
	in	al,dx		;data bit to LSB
	pop	dx
	ror	ax,1		;data to AH MSB
	shl	al,1		;restore latch value just read in
	loop	.2

	popm	cx
	ret		; exit with clock Low


%if DEBUG
segment CONST
	dw	ttime		; 54925 == 0_D68Dh
	dw	54925 ; ms.
	dd	tick		; 1573050
	dd	1573050 ; ticks/day
%endif
