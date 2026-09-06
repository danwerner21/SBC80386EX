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

		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,ARG(6) 				; COUNT OF SECTORS 
        mov     bh,al	 				; Master/slave INTO BH       
        mov     dx,ARG(5)
        mov     ax,ARG(4)
		call	wr_lba					; tell it which sector we want

        mov     al,IDE_CMD_PIO_READ
		mov		dx,IDESTTS
		out		dx,al

		call	ide_wait_drq			; wait until it's got the data
		jz	.3							; NO ERROR, CONTINUE
.2:
   		mov		ax,-1					; MARK ERROR, ABORT
		jmp	.9
.3:

        mov     CX,ARG(6) 				; COUNT OF SECTORS 
        mov     es,ARG(0) 				; high address INTO es	
        mov     bx,ARG(1)				; low address into bx
.4:
		call	read_data				; grab the data
		loop	.4

        xor     ax,ax

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

		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,ARG(6) 				; COUNT OF SECTORS 
        mov     bh,al	 				; Master/slave INTO BH       
        mov     dx,ARG(5)
        mov     ax,ARG(4)
		call	wr_lba					; tell it which sector we want

        mov     al,IDE_CMD_PIO_WRITE
		mov		dx,IDESTTS
		out		dx,al

		call	ide_wait_drq			; wait until it wants the data
		jz	.3							; NO ERROR, CONTINUE
.2:
   		mov		ax,-1					; MARK ERROR, ABORT
		jmp	.9
.3:

        mov     CX,ARG(6) 				; COUNT OF SECTORS 
        mov     ds,ARG(0) 				; high address INTO ds
        mov     bx,ARG(1)				; low address into bx
.4:
		call	write_data				; send the data
		loop	.4

        xor     ax,ax

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


		call	ide_wait_not_busy		; make sure drive is ready
		jnz	.2

        mov     bl,0	 				; COUNT OF SECTORS TO READ INTO BL
        mov     bh,al 					; Master/slave INTO BH
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
   		mov		ax,-1					; MARK ERROR, ABORT
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
		mov		ax,-1					; MARK ERROR, ABORT
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
;  Wait for RDY to be set
;
;  Exit with:
;       AL contains status
;       All other registers preserved
;
;------------------------------------------------------------------------------
ide_wait_not_busy:
        pushm   bx,dx,cx
		mov	cx,0FFFFh
.1:
		mov	dx,IDESTTS
		in	al,dx

        and     al,10000000b
		loopnz	.1

		or	al,al
        popm    bx,dx,cx
		ret
;------------------------------------------------------------------------------
; Wait for the drive to be ready to transfer data (DRQ = data request)
; Returns the drive's status in Acc
;
;  Exit with:
;       AL contains status
;       All other registers preserved
;------------------------------------------------------------------------------
ide_wait_drq:
        pushm   bx,dx,cx
		mov	cx,0FFFFh
.1:
   		mov	dx,IDESTTS
		in	al,dx

        and     al,10001000b		; Mask off Busy(7) and DRQ(3)
        xor     al,00001000b		; We want Busy(7) to be 0 and DRQ (3) to be 1

		loopnz	.1

		or	al,al
        popm    bx,dx,cx
	ret
;------------------------------------------------------------------------------
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
