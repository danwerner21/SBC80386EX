;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 13h_disk.asm -- hard disk calls
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
%include "stack.inc"
%include "disktab.inc"
%include "error.inc"


	global	int_13h

segment	_TEXT


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT 13H
;
; The C:H:S calls:
;
;    Function         Operation
;    ========         =========
;	00:           ; Reset Disk System
;---	01:           ; Get Disk System Status
;	02:           ; Read Sector
;	03:           ; Write Sector
;	04:           ; Verify Sector
;---	05:           ; Format Track
;---	06:           ; Format Bad Track (fixed disk) [PC]
;---	07:           ; Format Drive (fixed disk)     [PC]
;	08:           ; Get Drive Parameters
;---	09:           ; Initialize Fixed Disk Characteristics [PC,AT,PS/2]
;---	0A:           ; Read Sector Long (fixed disk) [PC,AT,PS/2]
;---	0B:           ; Write Sector Long (fixed disk) [PC,AT,PS/2]
;---	0C:           ; Seek (fixed disk)
;---	0D:           ; Reset Fixed Disk System
;---	0E:           ; Read Sector Buffer (fixed disk) [PC only]
;---	0F:           ; Write Sector Buffer (fixed disk) [PC only]
;---	10:           ; Get Drive Status (fixed disk)
;---	11:           ; Recalibrate Drive (fixed disk)
;---	12:           ; Controller RAM Diagnostic (fixed disk) [PC/XT]
;---	13:           ; Controller Drive Diagnostic (fixed disk) [PC/XT]
;---	14:           ; Controller Internal Diagnostic (fixed disk) [PC,AT,PS/2]
;	15:           ; Get Disk Type                 [AT]
;---	16:           ; Get Disk Change Status (floppy)
;---	17:           ; Set Disk Type (floppy)
;---	18:           ; Set Media Type for Format (floppy)
;
;
; The packet calls (LBA):
;
;    Function         Operation
;    ========         =========
;	41:           ; Check Extensions Present
;	42:           ; Extended Read
;	43:           ; Extended Write
;	44:           ; Extended Verify
;---	45:           ; Lock/Unlock Drive
;---	46:           ; Eject Drive
;	47:           ; Extended Seek
;	48:           ; Get Drive Parameters
;---	49:           ; Get Extended Disk Change Status
;	4E:           ; Set Hardware Configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
int_13h:
	sti
	test	dl,0x80		;Fixed disk or floppy disk call
	jz	floppy_call
; the call is to the fixed disk driver
	pushm	all,ds,es
	mov	bp,sp		;establish stack addressing

	cld			;just in case

	mov	di,chs_call_tab
	cmp	ah,len_chs_call_tab
	jb	dispatch
; not CHS call; test for Packet call
	sub	ah,0x41
	mov	di,packet_call_tab
	cmp	ah,len_packet_call_tab
	jb	ret_invalid_command
dispatch:
	mov	bl,ah
	xor	bh,bh
	add	bx,bx		; word indexing
   cs	jmp	word [bx+di]



; the call is to the floppy driver
floppy_call:
	int	0x40		;call the floppy driver
	ret	2


fn00_reset_disk:
fn02_read_sector:
fn03_write_sector:
fn04_verify_sector:
fn08_get_drive_parameters:
fn15_get_disk_type:
;;fn41_check_extensions_present:	;below
;;fn42_read_sector:			;below
fn43_write_sector:
fn44_verify_sector:
fn47_extended_seek:
fn48_get_drive_parameters:
fn4E_set_hardware_configuration:
	jmp	ret_invalid_command

	align	2
chs_call_tab:
	dw	fn00_reset_disk
	dw	ret_invalid_command	; fn01_get_error_status
	dw	fn02_read_sector
	dw	fn03_write_sector
	dw	fn04_verify_sector
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	fn08_get_drive_parameters
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command	; fn0C_seek
	dw	ret_invalid_command	; fn0D_reset_fixed_disk
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	fn15_get_disk_type
len_chs_call_tab	equ	($-chs_call_tab)/2

packet_call_tab:
	dw	fn41_check_extensions_present
	dw	fn42_read_sector
	dw	fn43_write_sector
	dw	fn44_verify_sector
	dw	ret_invalid_command	; fn45_lock_unlock_drive
	dw	ret_invalid_command	; fn46_eject_drive
	dw	fn47_extended_seek
	dw	fn48_get_drive_parameters
	dw	ret_invalid_command	; fn49_get_disk_change_status
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	ret_invalid_command
	dw	fn4E_set_hardware_configuration
len_packet_call_tab	equ	($-packet_call_tab)/2




; error & good returns
;
ret_invalid_command:
	mov	ah,INVALID_COMMAND
error_return:
	or	byte [bp+offset_flags], 01
	jmp	do_return
good_return:
	xor	ah,ah		;zero Carry & AH
good_return_AH:
	and	byte [bp+offset_flags], ~01
do_return:
	mov	byte [bp+offset_ax+1],ah	;save error code

	mov	sp,bp
	popm	all,ds,es
	iret		; must use IRET because CLD was used



; the tables of interrupt vectors which point to the disk tables
;
	global	_dtab_vectors
_dtab_vectors:
dtab_vectors:
	db	0x41,0x46,0x68,0x69,0x6A,0x6B,0x6C,0x6D ; 8 of them
len_dtab_vectors	equ	$ - dtab_vectors

; the DRIVER Tables
;
read_tab:
	dw	0			;driver 0  micro SD
	dw	0			;driver 1  Dual SD card
	extern	IDE_READ_SECTOR_
	dw	IDE_READ_SECTOR_	;driver 2
len_read_tab	equ	($ - read_tab)/2

write_tab:
	dw	0			;driver 0  micro SD
	dw	0			;driver 1  Dual SD card
	extern	IDE_WRITE_SECTOR_
	dw	IDE_WRITE_SECTOR_	;driver 2
len_write_tab	equ	($ - write_tab)/2


; get the disk table pointer to ES:DI, validating that the disk
; code in DL is withing bounds
; DL is returned as the driver number
;
get_disk_table:
	sub	dl,0x80			; remove the high bit
	get_bda	ES			; get BIOS data area segment pointer
    es	cmp	dl,[hd_number]
    	jnb	ret_invalid_command	; invalid command
	mov	di,dx
	and	di,0x00FF		; convert to byte offset

    es	mov	dl,[di+disk_tab]	; get the driver number in DL
    	or	dl,dl
	jz	ret_invalid_command	; sanity check (should not be needed)

    cs	mov	di,[di+dtab_vectors]	; get interrupt number of disktab
    	get_loc0 ES
	shl	di,2			; ES:DI points to disktab pointer
    es	les	di,[di]
	ret


; validate a R/W disk packet
;	DS:SI points at the packet
;
pkt_rw_validate:
	cmp	byte [pkt_size + si], 16	; must be 16 bytes
	jne	ret_invalid_command
	cmp	byte [pkt_blocks + si], 128	; must be .le. 127
	jnb	ret_invalid_command
	cmp	dword [pkt_LBA_high + si], 0	; must be zero
	jne	ret_invalid_command
	cmp	dword [pkt_disk_LBA + si],0x0FFF_FFFF	; max. LBA
	ja	ret_invalid_command
	cmp	bx,len_read_tab
	jnb	ret_invalid_command
	ret			; packet validates for Read/Write


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn41 -- Check Extensions Present
;
;  Call With:
;       AH = 41h        function code
;       BX = 55AAh      magic number
;       DL = drive code (80h or 81h)
;
;  Exit With:
;     carry clear
;       AH = 21h        version 1.1 support
;       BX = AA55h      magic number II
;       CX = 0001b  bit0=packet support; bit2=EDD drive support
;
;     carry set
;       AH = 01h        Invalid Command
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn41_check_extensions_present:
	call	get_disk_table	; validate
; ES:DI now points at the disktab.inc data area for the disk
	cmp	word [bp+offset_bx],0x55AA
	jne	ret_invalid_command
     es	test	byte [bx+disk_flags],USE_LBA
	jz	ret_invalid_command
; it is okay to use LBA calls for this disk
        mov     word [offset_bx + bp],0xAA55	; magic number II
        mov     word [offset_cx + bp],00000101b ; packet calls & EDD i/f
        mov     ah,21h				; version 1.1
	jmp	good_return_AH



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn42 -- read sectors (packet call)
;
;  Enter with:
;	DS:SI	pointer to disk packet (16 bytes)
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn42_read_sector:
	mov	bx,1		; this gets more involved for > 1 disk
	mov	ax,0		; ** (Slave/master)

	call	pkt_rw_validate
	add	bx,bx
   cs	mov	di,[read_tab + bx]	;routine to call

	mov	cx,[si + pkt_blocks]
	and	cx,127

	push	cx		; push number of sectors to read
	push	dword [si + pkt_disk_LBA]	; push LBA
	les	bx,[si + pkt_address]
	mov	cx,es		; CX:BX is address
	; AX is Slave/master

	call	di
; the driver removes the arguments from the stack

	cmp	al,NO_ERROR
	je	good_return

	shl	ax,8
	mov	byte [si + pkt_blocks],al
	mov	byte [bp + offset_ax],al
	jmp	error_return
