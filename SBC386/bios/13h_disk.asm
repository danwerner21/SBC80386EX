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
	jnb	ret_invalid_command	; was JB -- inverted, so every packet
					;  call was rejected and anything above
					;  the table jumped through a bad index
dispatch:
	mov	bl,ah
	xor	bh,bh
	add	bx,bx		; word indexing
   cs	jmp	word [bx+di]



; the call is to the floppy driver
floppy_call:
	int	0x40		;call the floppy driver
	retf	2		; an INT handler returns FAR -- a near RET here
				;  popped IP, threw away CS and left the
				;  callers flags on the stack


; Still unimplemented -- falls through to the invalid-command return.
fn4E_set_hardware_configuration:
	jmp	ret_invalid_command

	align	2
chs_call_tab:
	dw	fn00_reset_disk
	dw	fn01_get_status
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
	jmp	short record_status
good_return:
	xor	ah,ah		;zero Carry & AH
good_return_AH:
	and	byte [bp+offset_flags], ~01

; Every path through here records the outcome, so that INT 13h function
; 01h has something to report.  DOS reads it after a failure to decide
; whether to retry.  Errors raised inside this module land here with AH
; already set; errors from the driver were recorded by ide_error, and
; the code it returned has been carried up into AH, so the two agree.
record_status:
	push	es
	get_bda	ES
    es	mov	[hd_status],ah
	pop	es

do_return:
	mov	byte [bp+offset_ax+1],ah	;save error code

	mov	sp,bp
	popm	all,ds,es
	iret		; must use IRET because CLD was used


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn01 -- Get Disk System Status
;
;  Enter with:
;	AH = 01h
;	DL = drive code
;
;  Exit with:
;	AH = the status left by the previous operation
;	Carry set if that status was non-zero
;
;  The drive code is deliberately not validated: this call has to work
;  after a failure, including one caused by a bad drive code.  The status
;  is not cleared, so it can be read more than once.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn01_get_status:
	get_bda	ES
    es	mov	ah,[hd_status]
	or	ah,ah
	jnz	.bad
	and	byte [bp+offset_flags], ~01
	jmp	do_return
.bad:
	or	byte [bp+offset_flags], 01
	jmp	do_return
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get_disk_table -- locate the parameter table for a BIOS drive code
;
;  Enter with:
;	DL	drive code, 80h and up
;
;  Exit with:
;	ES:DI	points at the T_DISKTAB for the drive
;	BX	driver index, for read_tab / write_tab
;	AX, CX, DX unchanged
;
;  A bad drive code does not return: it jumps to ret_invalid_command,
;  which resets SP from BP, so the return address left on the stack
;  here does not matter.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
get_disk_table:
	push	ax

	mov	al,dl
	and	al,0x7F			; drive number, counting from 0
	get_bda	ES			; BIOS data area segment
    es	cmp	al,[hd_number]
	jnb	.bad
	movzx	di,al			; byte index into disk_tab

    es	mov	al,[di+disk_tab]	; the FX_ device code POST recorded
	or	al,al
	jz	.bad			; FX_NONE -- nothing registered here
	cmp	al,len_drv_index
	jnb	.bad

	movzx	bx,al
    cs	mov	bl,[bx+drv_index]	; device code -> driver index
	cmp	bl,0xFF
	je	.bad			; no driver for that device code
	xor	bh,bh

; dtab_vectors is a table of BYTES: 41h, 46h, 68h ...  It used to be
; read a word at a time, which returned 4641h for index 0 and turned the
; shift and LES below into a garbage far pointer.
    cs	movzx	di,byte [di+dtab_vectors]
	shl	di,2			; interrupt number -> vector address
	get_loc0 ES
    es	les	di,[di]			; ES:DI -> T_DISKTAB

	pop	ax
	ret

.bad:
	pop	ax
	jmp	ret_invalid_command


; FX_ device code (see the enum in nvram.h) -> index into read_tab and
; write_tab.  FFh marks a code with no driver behind it.
	align	2
drv_index:
	db	0xFF			; FX_NONE
	db	0			; FX_uSD   -> microSD
	db	1			; FX_SD0   -> dual SD
	db	1			; FX_SD1
	db	2			; FX_IDEm  -> IDE
	db	2			; FX_IDEs
len_drv_index	equ	$ - drv_index


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
     es	test	byte [di+disk_flags],USE_LBA	; was [bx+...], and BX still
						;  held the callers 55AA magic
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
; The driver index used to be hard-coded to 1, which selected the null
; DualSD slot in read_tab.  Take it from the drive's own device code,
; and take master/slave from its parameter table.
	call	get_disk_table		; ES:DI -> T_DISKTAB, BX = driver
	movzx	ax,byte [es:di+unit_number]
	shl	ax,4			; 0 -> 00h master, 1 -> 10h slave

	call	pkt_rw_validate
	add	bx,bx
   cs	mov	di,[read_tab + bx]	;routine to call
	or	di,di
	jz	ret_invalid_command

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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The C:H:S entry points, ported from SBC386/HardDisk/DIDE.ASM.
;
; The shape of the original is kept -- validate, convert to LBA, then a
; one-sector-at-a-time transfer loop -- but everything it read out of
; the SBC-188 fx80/fx81 tables now comes from a T_DISKTAB, and the 32x16
; multiply helper it needed is a single 386 instruction here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ret_sector_not_found:
	mov	ah,SECTOR_NOT_FOUND
	jmp	error_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cv_lba -- convert the C:H:S in CX and DX to an LBA sector number
;
;  Enter with:
;	ES:DI	points at the T_DISKTAB for the drive
;	CH	low 8 bits of the cylinder number
;	CL	bits 7:6 high 2 bits of cylinder, bits 5:0 sector (1..63)
;	DH	head number
;
;  Exit with:
;	EAX	the LBA sector number
;	Carry set if the address is outside the drive's geometry
;
;  Trashes:
;	EBX, ECX, EDX
;
;  The geometry used is the TRANSLATED one in ncylinders/n__heads/
;  nsectors, which is the same geometry AH=08h reports -- so a caller
;  that asks for what fn08 told it will always land inside the drive.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
cv_lba:
	mov	bl,cl
	and	bl,0x3F			; sector, numbered from 1
	mov	bh,dh			; head

	mov	al,cl
	and	ax,0x00C0		; high 2 cylinder bits, in 7:6
	shl	ax,2			; ...to 9:8, so AH = them and AL = 0
	mov	al,ch			; AX = cylinder number

; range check before doing any arithmetic
	or	bl,bl
	jz	.bad			; sector 0 does not exist
    es	cmp	bl,[di+nsectors]
	ja	.bad
    es	cmp	bh,[di+n__heads]
	jnb	.bad			; heads count from 0
    es	cmp	ax,[di+ncylinders]
	jnb	.bad

	movzx	eax,ax
	movzx	ecx,byte [es:di+n__heads]
	mul	ecx			; EAX = cylinder * heads
	movzx	ecx,bh
	add	eax,ecx			; + head number

	movzx	ecx,byte [es:di+nsectors]
	mul	ecx			; EAX = (cyl*heads + head) * sectors
	movzx	ecx,bl
	dec	ecx			; sectors are numbered from 1
	add	eax,ecx

	clc
	ret
.bad:
	stc
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn00 -- Reset Disk System
;
;  Enter with:
;	AH = 0
;	DL = drive code
;
;  A soft reset drops both devices on the cable back to 16-bit PIO, and
;  every transfer routine in diskide.asm moves single bytes, so 8-bit
;  mode has to be put back before anything else touches the drives.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	extern	hd_reset_
	extern	hd_set_8bit_

fn00_reset_disk:
	call	get_disk_table		; validates the drive code

	push	ds
	mov	ax,DGROUP
	mov	ds,ax			; the C helpers address through DGROUP

	call	hd_reset_
	or	ax,ax
	jnz	.failed

	xor	ax,ax
	call	hd_set_8bit_		; master

	get_bda	ES
    es	cmp	byte [hd_number],1
	jbe	.done
	mov	ax,1
	call	hd_set_8bit_		; slave, if one was registered
.done:
	pop	ds
	jmp	good_return

.failed:
	pop	ds
	mov	ah,RESET_FAILED
	jmp	error_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn02 -- Read Sectors
; fn03 -- Write Sectors
; fn04 -- Verify Sectors
;
;  Enter with:
;	AH	2 read, 3 write, 4 verify
;	AL	number of sectors
;	CH	low 8 bits of cylinder
;	CL	bits 7:6 cylinder high, bits 5:0 sector
;	DH	head
;	DL	drive code
;	ES:BX	caller's buffer (not used by verify)
;
;  Exit with:
;	AL	number of sectors actually transferred
;	AH	0 and Carry clear, or an error code with Carry set
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; locals, carved below BP.  The return path does MOV SP,BP, so they are
; discarded for free.
%define	lcl_lba		[bp-4]		; dword, current LBA
%define lcl_count	[bp-6]		; sectors still to do
%define lcl_drv		[bp-8]		; driver entry point
%define lcl_unit	[bp-10]		; 00h master, 10h slave
%define lcl_off		[bp-12]		; buffer offset
%define lcl_seg		[bp-14]		; buffer segment
%define lcl_want	[bp-16]		; sectors asked for
LCL_SIZE	equ	16

fn02_read_sector:
	mov	si,read_tab
	jmp	short rwv_common
fn03_write_sector:
	mov	si,write_tab
	jmp	short rwv_common
fn04_verify_sector:
	mov	si,read_tab		; verify reads and throws away

rwv_common:
	call	get_disk_table		; ES:DI -> T_DISKTAB, BX = driver
	add	bx,bx			; word index
   cs	mov	si,[bx+si]		; driver entry for this device
	or	si,si
	jz	ret_invalid_command	; slot is null -- no such driver

	call	cv_lba			; EAX = LBA, Carry if out of range
	jc	ret_sector_not_found

	sub	sp,LCL_SIZE
	mov	lcl_drv,si
	mov	dword lcl_lba,eax

	movzx	ax,byte [es:di+unit_number]
	shl	ax,4			; 0 -> 00h, 1 -> 10h
	mov	lcl_unit,ax

	mov	al,[bp+offset_ax]	; sector count from the caller
	xor	ah,ah
	mov	lcl_count,ax
	mov	lcl_want,ax

	mov	ax,[bp+offset_bx]
	mov	lcl_off,ax
	mov	ax,[bp+offset_es]
	mov	lcl_seg,ax

	cmp	byte [bp+offset_ax+1],4		; is this a verify?
	jne	.loop
; Verify has no buffer of its own.  Read into the BIOS sector buffer and
; discard: proving the sectors read back is what verify is for.
	extern	_SecBuffer
   cs	mov	ax,[_SecBuffer]
	mov	lcl_off,ax
   cs	mov	ax,[_SecBuffer+2]
	mov	lcl_seg,ax

.loop:
	cmp	word lcl_count,0
	je	.done

; One sector per call.  The DRQ wait in diskide.asm sits outside its own
; sector loop, so a multi-sector request there runs ahead of the drive.
	push	word 1
	push	dword lcl_lba
	mov	bx,lcl_off
	mov	cx,lcl_seg
	mov	ax,lcl_unit		; AL = 00h or 10h
	call	word lcl_drv		; the driver pops its own arguments

	or	ax,ax
	jnz	.failed

	inc	dword lcl_lba
	dec	word lcl_count

	cmp	byte [bp+offset_ax+1],4
	je	.loop			; verify keeps reusing the one buffer

	add	word lcl_off,512
	jnc	.loop
	add	word lcl_seg,0x1000	; the offset wrapped 64K
	jmp	.loop

.done:
	mov	ax,lcl_want
	mov	[bp+offset_ax],al	; all of them transferred
	jmp	good_return

.failed:
; Report how many sectors did make it before reporting the error.
	mov	bx,ax			; the driver left a real status code
	mov	ax,lcl_want
	sub	ax,lcl_count
	mov	[bp+offset_ax],al	; sectors that did transfer
	mov	ah,bl			; carry the code up, do not invent one
	jmp	error_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn08 -- Get Drive Parameters
;
;  Enter with:
;	AH = 8
;	DL = drive code
;
;  Exit with:
;	CH	low 8 bits of the maximum cylinder number
;	CL	bits 7:6 cylinder high, bits 5:0 sectors per track
;	DH	maximum head number
;	DL	number of fixed disks in the system
;	AH	0, Carry clear
;
;  The geometry returned is the TRANSLATED one, which is what makes the
;  numbers safe to feed back into AH=02h.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn08_get_drive_parameters:
	mov	byte [bp+offset_dx],0	; no drives, until proven otherwise
	call	get_disk_table		; ES:DI -> T_DISKTAB

    es	mov	ax,[di+ncylinders]
	or	ax,ax
	jz	ret_invalid_command	; no usable geometry to report
	dec	ax			; maximum cylinder number
	mov	ch,al			; low 8 bits
	mov	cl,ah
	shl	cl,6			; high 2 bits into 7:6
    es	or	cl,[di+nsectors]	; sectors per track into 5:0
	mov	[bp+offset_cx],cx

    es	mov	dh,[di+n__heads]
	dec	dh			; maximum head number
	get_bda	ES
    es	mov	dl,[hd_number]
	mov	[bp+offset_dx],dx

	jmp	good_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn15 -- Get Disk Type
;
;  Enter with:
;	AH = 15h
;	DL = drive code
;
;  Exit with:
;	AH	3, meaning a fixed disk
;	CX:DX	number of 512-byte sectors on the drive
;	Carry clear
;
;  The count is max_lba, the drive's real capacity, rather than the
;  product of the translated geometry -- translation rounds the cylinder
;  count down and would under-report the disk.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn15_get_disk_type:
	call	get_disk_table		; ES:DI -> T_DISKTAB

    es	mov	eax,[di+max_lba]
	mov	[bp+offset_dx],ax	; low order word
	shr	eax,16
	mov	[bp+offset_cx],ax	; high order word

	mov	ah,3			; code for a fixed disk
	jmp	good_return_AH


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn43 -- Extended Write (packet call)
;
;  Enter with:
;	AH = 43h
;	AL bit 0 selects write-with-verify, which this driver cannot do
;	   any more cheaply than a plain write, so it is ignored
;	DL = drive code
;	DS:SI = the 16-byte disk packet
;
;  The mirror of fn42, against write_tab.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn43_write_sector:
	call	get_disk_table		; ES:DI -> T_DISKTAB, BX = driver
	movzx	ax,byte [es:di+unit_number]
	shl	ax,4			; 0 -> 00h master, 1 -> 10h slave

	call	pkt_rw_validate
	add	bx,bx
   cs	mov	di,[write_tab + bx]	;routine to call
	or	di,di
	jz	ret_invalid_command	; no write driver for this device

	mov	cx,[si + pkt_blocks]
	and	cx,127

	push	cx		; number of sectors
	push	dword [si + pkt_disk_LBA]
	les	bx,[si + pkt_address]
	mov	cx,es		; CX:BX is the source address
	; AX is Slave/master

	call	di
; the driver removes the arguments from the stack

	cmp	al,NO_ERROR
	je	good_return

	shl	ax,8
	mov	byte [si + pkt_blocks],al
	mov	byte [bp + offset_ax],al
	jmp	error_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn44 -- Extended Verify (packet call)
;
;  Enter with:
;	AH = 44h
;	DL = drive code
;	DS:SI = the 16-byte disk packet
;
;  pkt_address is not used: verify reads the sectors and throws the data
;  away, one at a time into the BIOS sector buffer.  On failure
;  pkt_blocks is set to the number that did verify.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn44_verify_sector:
	call	get_disk_table		; ES:DI -> T_DISKTAB, BX = driver
	movzx	ax,byte [es:di+unit_number]
	shl	ax,4

	call	pkt_rw_validate
	add	bx,bx
   cs	mov	di,[read_tab + bx]
	or	di,di
	jz	ret_invalid_command

	sub	sp,LCL_SIZE
	mov	lcl_drv,di
	mov	lcl_unit,ax

	mov	ax,[si + pkt_blocks]
	and	ax,127
	mov	lcl_count,ax
	mov	lcl_want,ax

	mov	eax,[si + pkt_disk_LBA]
	mov	dword lcl_lba,eax

   cs	mov	ax,[_SecBuffer]
	mov	lcl_off,ax
   cs	mov	ax,[_SecBuffer+2]
	mov	lcl_seg,ax

.loop:
	cmp	word lcl_count,0
	je	.done

	push	word 1
	push	dword lcl_lba
	mov	bx,lcl_off
	mov	cx,lcl_seg
	mov	ax,lcl_unit
	call	word lcl_drv

	or	ax,ax
	jnz	.failed

	inc	dword lcl_lba
	dec	word lcl_count
	jmp	.loop

.done:
	jmp	good_return

.failed:
	mov	bx,ax			; the driver left a real status code
	mov	ax,lcl_want
	sub	ax,lcl_count
	mov	[si + pkt_blocks],ax	; how many did verify
	mov	ah,bl
	jmp	error_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn47 -- Extended Seek (packet call)
;
;  Enter with:
;	AH = 47h
;	DL = drive code
;	DS:SI = the 16-byte disk packet
;
;  There is no seek command in the 8-bit PIO path -- the drive seeks as
;  part of the next transfer -- so the useful work here is checking that
;  the caller is asking for somewhere that exists.  Unlike fn42/43/44,
;  which leave the drive to reject a bad address, this one has nothing
;  else to do, so it range-checks against max_lba.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn47_extended_seek:
	call	get_disk_table		; ES:DI -> T_DISKTAB, BX = driver
	call	pkt_rw_validate

	mov	eax,[si + pkt_disk_LBA]
    es	cmp	eax,[di+max_lba]
	jnb	ret_sector_not_found

	jmp	good_return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fn48 -- Get Drive Parameters (packet call)
;
;  Enter with:
;	AH = 48h
;	DL = drive code
;	DS:SI = the result buffer, with pkt_param_size already set
;
;  Exit with:
;	the buffer filled in, pkt_param_size set to what was written
;	AH = 0, Carry clear
;
;  The C:H:S reported is the TRANSLATED geometry, the same one AH=08h
;  gives, so the two calls cannot disagree.  pkt_total_sectors is
;  max_lba, the real capacity, which is generally larger -- that is
;  expected, and is the whole reason the packet calls exist.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fn48_get_drive_parameters:
	call	get_disk_table		; ES:DI -> T_DISKTAB

	cmp	word [si + pkt_param_size],26
	jb	ret_invalid_command	; buffer too small to fill in

	movzx	eax,word [es:di+ncylinders]
	mov	[si + pkt_phys_cylinders],eax
	movzx	eax,byte [es:di+n__heads]
	mov	[si + pkt_phys_heads],eax
	movzx	eax,byte [es:di+nsectors]
	mov	[si + pkt_phys_sectors],eax

    es	mov	eax,[di+max_lba]
	mov	[si + pkt_total_sectors],eax
	mov	dword [si + pkt_total_sectors+4],0

	mov	word [si + pkt_bytes],512
	mov	word [si + ppt_info],0x0002	; bit 1: geometry is valid

	cmp	word [si + pkt_param_size],30
	jb	.short_form

; room for the EDD pointer, which this BIOS does not publish
	mov	dword [si + pkt_EDD_param_ptr],0xFFFFFFFF
	mov	word [si + pkt_param_size],30
	jmp	good_return

.short_form:
	mov	word [si + pkt_param_size],26
	jmp	good_return
