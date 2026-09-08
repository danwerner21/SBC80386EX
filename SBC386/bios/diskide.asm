;/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; diskide.asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Copyright (C) 2017,2018 John R. Coffman.  All rights reserved.
; Portions (C) 2018 Dan Werner
;
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
; IDE HARDWARE SPECIFIC VALUES	DEFAULT 01F0h - 01FFh
;
;  -  CONTROLLER I/O PORT
;     > WHEN READ FROM
;	HF_PORT+0 - READ DATA (FROM CONTROLLER TO CPU)
;	HF_PORT+1 - --
;	HF_PORT+2 - GET SECTOR COUNT
;	HF_PORT+3 - GET LBA LOW (7:0)
;	HF_PORT+4 - GET LBA MID {15:8)
;	HF_PORT+5 - GET LBA HIGH (23:16)
;	HF_PORT+6 - GET (1: LBA(1/0) : 1 : MST(0)/SLV(1) : LBA (27 :24)  )
;	HF_PORT+7 - GET STATUS REGISTER
;
;     > WHEN WRITTEN TO:
;	HF_PORT+0 - WRITE DATA (FROM CPU TO CONTROLLER)
;	HF_PORT+1 - SET FEATURES
;	HF_PORT+2 - SET SECTOR COUNT
;	HF_PORT+3 - SET LBA LOW (7:0)
;	HF_PORT+4 - SET LBA MID {15:8)
;	HF_PORT+5 - SET LBA HIGH (23:16)
;	HF_PORT+6 - SET (1: LBA(1/0) : 1 : MST(0)/SLV(1) : LBA (27 :24)  )
;	HF_PORT+7 - SET COMMAND REGISTER
;
HF_PORT		EQU		01F0h		; DISK PORT
IDEDTA		EQU     HF_PORT+0	; DATA PORT (16 BIT)
IDEERR		EQU     HF_PORT+1	; READ: ERROR REGISTER; WRITE: PRECOMP
IDESECC		EQU     HF_PORT+2	; SECTOR COUNT
IDELBAL		EQU     HF_PORT+3	; SECTOR NUMBER
IDELBAM		EQU     HF_PORT+4	; CYLINDER LOW
IDELBAH		EQU     HF_PORT+5	; CYLINDER HIGH
IDEDRV 		EQU     HF_PORT+6	; DRIVE/HEAD
IDESTTS		EQU     HF_PORT+7	; READ: STATUS; WRITE: COMMAND
IDEALTS		EQU     HF_PORT+14	; ALTERNATE STATUS(Not IBM Compat)
IDEADDR		EQU     HF_PORT+15	; DRIVE ADDRESS   (Not IBM Compat)
;
;
; IDE/ATA COMMANDS
;
;
IDE_CMD_RECAL		EQU     010h
IDE_CMD_PIO_READ    EQU 	020h
IDE_CMD_PIO_WRITE   EQU 	030h
IDE_CMD_INIT_PARAM  EQU 	091h
IDE_CMD_DMA_READ    EQU 	0C8h
IDE_CMD_DMA_WRITE   EQU 	0CAh
IDE_CMD_SPINDOWN    EQU 	0E0h
IDE_CMD_SPINUP      EQU 	0E1h
IDE_CMD_IDENT       EQU 	0ECh
IDE_CMD_SET_FEATURE EQU 	0EFh


%include "seg_def.inc"
%include "i386EX.inc"
%include "macro.inc"
%define XXX
%include "bda.inc"
%include "error.inc"		; BIOS status codes for ide_error
%undef XXX

%define ARG(n) [bp+2+(n)*2]

	SEGMENT	_TEXT

; -----------------------------------------------------------------------------
;  IDE_READ_SECTOR
; -----------------------------------------------------------------------------
; read a sector, specified by the 4 bytes in "lba",
; Return, acc is zero on success, non-zero for an error
;
;  int IDE_READ_SECTOR(byte master_slave,byte far *buffer, dword sector_start,byte nsectors);
;
;
;-----------------------------------------------------------------------------
        global  IDE_READ_SECTOR
        global  IDE_READ_SECTOR_
IDE_READ_SECTOR:
IDE_READ_SECTOR_:
		push 	DX
		push    BX
		push 	CX
        push    bp
        mov     bp,sp
        push 	ES
        push	DI

; Master/slave must be taken out of AL BEFORE the wait below:
;  ide_wait_not_busy returns the drive status in AL, so reading
;  the argument afterwards always yielded 0 -- the master.  BX
;  is preserved across the call.
        mov     bh,al                   ; Master/slave INTO BH
		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,ARG(6) 				; COUNT OF SECTORS
        mov     dx,ARG(5)
        mov     ax,ARG(4)
		call	wr_lba					; tell it which sector we want

        mov     al,IDE_CMD_PIO_READ
		mov		dx,IDESTTS
		out		dx,al

        mov     CX,ARG(6) 				; COUNT OF SECTORS
        mov     es,ARG(0) 				; high address INTO es
        mov     bx,ARG(1)				; low address into bx
.4:
; ATA raises DRQ once per sector during a multi-sector PIO transfer, so
; the wait belongs inside this loop.  Polled once before it, the second
; and later sectors ran ahead of the drive and desynchronised.
		call	ide_wait_drq
		jnz	.2
		call	read_data				; grab the data
		loop	.4

        xor     ax,ax
		jmp	.9
.2:
		call	ide_error				; real status, not -1
.9:
   		POP 	DI
   		POP 	ES
        leave
        pop 	CX
        pop 	BX
        pop 	DX
        ret	6	; was 'ret', but Watcom proc must remove args!!!


; -----------------------------------------------------------------------------
;  IDE_WRITE_SECTOR
; -----------------------------------------------------------------------------
; write a sector, specified by the 4 bytes in "lba",
; Return, acc is zero on success, non-zero for an error
;
;  int IDE_WRITE_SECTOR(byte master_slave,byte far *buffer, dword sector_start,byte nsectors);
;
;
;-----------------------------------------------------------------------------
        global  IDE_WRITE_SECTOR
        global  IDE_WRITE_SECTOR_
IDE_WRITE_SECTOR:
IDE_WRITE_SECTOR_:
		push 	DX
		push    BX
		push 	CX
        push    bp
        mov     bp,sp
        push 	DS
        push	SI

; Master/slave must be taken out of AL BEFORE the wait below:
;  ide_wait_not_busy returns the drive status in AL, so reading
;  the argument afterwards always yielded 0 -- the master.  BX
;  is preserved across the call.
        mov     bh,al                   ; Master/slave INTO BH
		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,ARG(6) 				; COUNT OF SECTORS
        mov     dx,ARG(5)
        mov     ax,ARG(4)
		call	wr_lba					; tell it which sector we want

        mov     al,IDE_CMD_PIO_WRITE
		mov		dx,IDESTTS
		out		dx,al


        mov     CX,ARG(6) 				; COUNT OF SECTORS
        mov     ds,ARG(0) 				; high address INTO ds
        mov     bx,ARG(1)				; low address into bx
.4:
; DRQ is raised once per sector on the way out too, so the wait goes
; inside the loop here for the same reason as the read path.
		call	ide_wait_drq
		jnz	.2
		call	write_data				; send the data
		loop	.4

; The drive is still writing the last sector when the loop ends: wait for
; it to finish so a failure is reported to this caller and not the next.
		call	ide_wait_not_busy
		jnz	.2

        xor     ax,ax
		jmp	.9
.2:
		call	ide_error				; real status, not -1
.9:
   		POP 	SI
   		POP 	DS
        leave
        pop 	CX
        pop 	BX
        pop 	DX
        ret	6	; was 'ret', but Watcom proc must remove args!!!


; -----------------------------------------------------------------------------
; IDE_READ_ID
; -----------------------------------------------------------------------------
; Read the 512 byte ID information from the attached drive
;
;  int DIDE_READ_ID(byte master_slave, byte far *buffer);
;
;
;-----------------------------------------------------------------------------
		global	IDE_READ_ID
		global	IDE_READ_ID_
IDE_READ_ID:
IDE_READ_ID_:
		push 	DX
		push    BX
		push 	CX
        push    bp
        mov     bp,sp
        push 	ES
        push	DI


; Master/slave must be taken out of AL BEFORE the wait below:
;  ide_wait_not_busy returns the drive status in AL, so reading
;  the argument afterwards always yielded 0 -- the master.  BX
;  is preserved across the call.
        mov     bh,al                   ; Master/slave INTO BH
		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,0	 				; COUNT OF SECTORS TO READ INTO BL
        mov     ax,0
        mov     dx,0
		call	wr_lba					; tell it which sector we want

; GET DRIVE IDENT
		mov	al,IDE_CMD_IDENT
		mov	dx,IDESTTS
		out	dx,al

		call	ide_wait_drq			;wait until it's got the data
		jz	.3
.2:
   		call	ide_error				; real status, not -1
		jmp	.9
.3:

        mov     es,ARG(0) 				; high address INTO ax
        mov     bx,ARG(1)				; low address into bx
		call	read_dataBE				; grab the data

        xor     ax,ax

.9:
   		POP 	DI
   		POP 	ES
        leave
        pop 	CX
        pop 	BX
        pop 	DX
        ret



; -----------------------------------------------------------------------------
;  IDE_INITIALIZE
; -----------------------------------------------------------------------------
; IDE INITIALIZE DRIVE FOR OPERATION
;
;  int IDE_INITIALIZE(byte master_slave);
;
;
;-----------------------------------------------------------------------------
 		global 	IDE_INITIALIZE
 		global 	IDE_INITIALIZE_
IDE_INITIALIZE:
IDE_INITIALIZE_:
        pushm   bx,es,ax,dx,cx
        push    bp
        mov     bp,sp
        pushm   es,bx,di



		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,0	 				; COUNT OF SECTORS TO READ INTO BL
        mov     bh,ARG(0) 				; Master/slave INTO BH
        mov     ax,0
        mov     dx,0
		call	wr_lba					; tell it which sector we want

; SET 8-BIT MODE
	  	call	ide_wait_not_busy		;make sure drive is ready
		jnz	.2

		mov	al,01h
		mov	dx,IDEERR
		out	dx,al
		mov	al,IDE_CMD_SET_FEATURE
		mov	dx,IDESTTS
		out	dx,al
		call	ide_wait_not_busy		;make sure drive is ready
		jz	.3
.2:
		call	ide_error				; real status, not -1
		jmp	.9
.3:
        xor     ax,ax
.9:
        popm    es,bx,di
        leave
        popm    bx,es,ax,dx,cx
		ret




;------------------------------------------------------------------------------
; IDE INTERNAL SUBROUTINES
;------------------------------------------------------------------------------
;-----------------------------------------------------------------------------
;  ide_wait_not_busy -- wait for BSY to clear
;
;  Exit with:
;       AL      the status register as read
;       ZF      set on success, clear on timeout
;       All other registers preserved
;
;  The old form of this spun on "mov cx,0FFFFh / loopnz", which is both
;  clock-dependent and far too short -- a few milliseconds at 20mhz, where
;  ATA allows seconds for a reset and a card can take hundreds of
;  milliseconds to come ready.  The 18.2hz BDA tick is used instead: it is
;  the only clock still running after POST, since start_timer0_ in
;  1Ah_time.asm gates counters 1 and 2 off.  A single word read of
;  timer_count_low cannot tear against IRQ0, and the unsigned subtraction
;  rides through the wrap.
;------------------------------------------------------------------------------
IDE_TIMEOUT	equ	18*5		; five seconds, in 18.2hz ticks

ide_wait_not_busy:
        pushm   bx,cx,dx,es
	get_bda	ES
    es	mov	bx,[timer_count_low]		; when we started
.1:
	mov	dx,IDESTTS
	in	al,dx
	test	al,80h				; BSY
	jz	.9				; clear: ZF is already set

    es	mov	cx,[timer_count_low]
	sub	cx,bx
	cmp	cx,IDE_TIMEOUT
	jb	.1

	mov	cx,1
	or	cx,cx				; ZF clear -- timed out
	jmp	short .10
.9:
	xor	cx,cx				; ZF set -- ready
.10:
        popm    bx,cx,dx,es
	ret


;------------------------------------------------------------------------------
; ide_wait_drq -- wait for BSY clear and DRQ set
;
;  Exit with:
;       AL      the status register as read
;       ZF      set on success, clear on timeout or drive error
;       All other registers preserved
;
;  ERR is watched for as well as the timeout, so a drive that rejects the
;  command is noticed immediately instead of after five seconds.
;------------------------------------------------------------------------------
ide_wait_drq:
        pushm   bx,cx,dx,es
	get_bda	ES
    es	mov	bx,[timer_count_low]
.1:
	mov	dx,IDESTTS
	in	al,dx

	test	al,01h				; ERR -- do not wait it out
	jnz	.8

	mov	cl,al
	and	cl,10001000b			; BSY and DRQ
	cmp	cl,00001000b			; want BSY=0, DRQ=1
	je	.9

    es	mov	cx,[timer_count_low]
	sub	cx,bx
	cmp	cx,IDE_TIMEOUT
	jb	.1
.8:
	mov	cx,1
	or	cx,cx				; ZF clear -- failed
	jmp	short .10
.9:
	xor	cx,cx				; ZF set -- data is ready
.10:
        popm    bx,cx,dx,es
	ret


;------------------------------------------------------------------------------
; ide_error -- turn the drive's status and error registers into a BIOS
;              status code, and record it where INT 13h fn 01h will find it
;
;  Exit with:
;       AX      the BIOS status code, never zero
;       bda.hd_status set to the same value
;       All other registers preserved
;
;  Every failure used to collapse to AX=-1, which gave INT 13h nothing to
;  report and DOS nothing to base a retry on.
;------------------------------------------------------------------------------
ide_error:
	pushm	bx,cx,dx,es

	mov	dx,IDESTTS
	in	al,dx
	mov	ah,al				; keep the status register

	test	al,80h				; still busy: it never answered
	jnz	.timeout
	test	al,01h				; no ERR either: we timed out
	jz	.timeout

	test	ah,20h				; DF -- device fault
	jz	.decode
	mov	bl,WRITE_FAULT
	jmp	short .done

.decode:
	mov	dx,IDEERR
	in	al,dx				; the error register

	mov	bl,BAD_SECTOR_FLAG
	test	al,80h				; BBK  bad block mark
	jnz	.done
	mov	bl,BAD_CRC
	test	al,40h				; UNC  uncorrectable data
	jnz	.done
	mov	bl,SECTOR_NOT_FOUND
	test	al,10h				; IDNF sector id not found
	jnz	.done
	mov	bl,INVALID_COMMAND
	test	al,04h				; ABRT command aborted
	jnz	.done
	mov	bl,BAD_SEEK
	test	al,02h				; TK0NF track 0 not found
	jnz	.done
	mov	bl,ADDRESS_MARK_NOT_FOUND
	test	al,01h				; AMNF
	jnz	.done
	mov	bl,UNDEFINED_ERROR
	jmp	short .done

.timeout:
	mov	bl,TIME_OUT

.done:
	get_bda	ES
    es	mov	[hd_status],bl			; INT 13h fn 01h reads this
	movzx	ax,bl

	popm	bx,cx,dx,es
	ret

; Read a sector of 512 bytes into memory at ES:[BX]
;
;  Call with:
;       ES:BX -- pointer to the data block
;
;  Exit with:
;       AX and DX are destroyed; other registers preserved
;
; "BE" version is for ide id information
;-----------------------------------------------------------------------------
read_dataBE:
    pushm   bx,cx
	mov		dx,IDEDTA

    xchg    di,bx

	mov     cx,256          ; sector size in words
rdblk2BE:
	in	al,dx
	mov ah,al
	in	al,dx
	stosb
	mov al,ah
	stosb
    loop    rdblk2BE
    popm    bx,cx
	ret

read_data:
    pushm   cx
	mov		dx,IDEDTA
    xchg    di,bx
	mov     cx,512          ; sector size in words
rdblk2:
	in	al,dx
	stosb
    loop    rdblk2
    xchg    di,bx
    popm    cx
	ret

;------------------------------------------------------------------------------
; Write a sector of 512 bytes from memory at ES:[BX]
;
;  Call with:
;       ES:BX -- pointer to the data block
;
;  Exit with:
;       AX and DX are destroyed; other registers preserved
;
;-----------------------------------------------------------------------------
write_data:
    pushm   cx
	mov		dx,IDEDTA
    xchg    si,bx
	mov     cx,512          ; sector size in words
wtblk2:
	lodsb
	out	dx,al
    loop    wtblk2
    xchg    si,bx
    popm    cx
	ret



;-----------------------------------------------------------------------------
; write the logical block address to the drive's registers
;
;  Call with:
;       DX:AX = logical block address
;		BH = Master/Slave selection in bit 4
;       BL = Sector read count
;
;  Exit with:
;       AX, BX, DX are destroyed
;
;-----------------------------------------------------------------------------
wr_lba:
		push 	cx
        push    ax
        push    dx
        mov 	CX,BX

        mov     al,10h          ; Master/Slave mask
        and     al,ch           ; mask bit
        mov     bl,dh           ; high order
        and     bl,00Fh
        or      bl,0E0h         ; mark as LBA

		or		al,bl
		mov		dx,IDEDRV
		out		dx,al			; DRV

        pop     bx              ; get DL to BL

		mov		al,bl
		dec		dx
		out		dx,al			; LBA - H

        pop     bx

		mov		al,bh
		dec		dx
		out		dx,al			; LBA - M

		mov		al,bl
		dec		dx
		out		dx,al			; LBA - L

		mov		al,cl
		dec		dx
		out		dx,al 			; SET SECTOR COUNT

		POP 	CX
		ret
