XXX
; disktab.h -- layout of the fixed disk parameter table */
struc _DISKTAB
; */
; N.B.:   Disk Driver INIT must fill in at least:				*/
; */
;		ncylinders	1..1024		*/
;		n__heads	1..254		*/
;		nsectors	1..63		*/
;		max_lba		up to 2^28    number of LBA sectors		*/
;		flags		(see below)		*/
; */
%define USE_CHS 0x01			; may use Cyl:Hd:Sec access */
%define USE_LBA 0x02			; may use LBA access up to 28-bits */
%define USE_DMA 0x04			; may use DMA access */
%define USE_8BIT 0x08			; may/must use 8 bit access */
%define USE_16BIT 0x10			; may/must use 16 bit access */
%define USE_BIG_LBA 0x20		; may use LBA 40-bit addressing */
; */
ncylinders	resw	1		; maximum number of cylinders */
n__heads	resb	1		; maximum number of heads */
used_on_XT	resw	1
precomp_cylinder	resw	1
; was	byte	ECC_length;		*/
unit_number	resb	1	; unit number Master=0, Slave=1 */
control_bits	resb	1	; PC/AT definitions below */
; bit 7 -or- bit 6 disables retries */
; bit 3 - more than 8 heads */
; SBC-386EX definitions TBD */
; */
; was	byte	reserved[3];	; may become more control bit options */
res1	resb	1
;	byte	res2;
;	byte	res3;
;	word	landing_zone;	; 386EX does not use this */
max_lba	resd	1	; up to 28 bits  ==  128Gb = 137gb */
nsectors	resb	1	; maximum number of sectors per track**/
; was	byte	reserved2;	   386EX usage TBD */
disk_flags	resb	1		; see bit definitions above */
endstruc
; */
; */
; */
; */
; disk packet call structure */
struc _PACKET
pkt_size	resw	1		; R/W = 16 */
pkt_blocks	resw	1		; blocks to transfer up to 127 */
pkt_address	resd	1	; Seg:Off of source/destination */
pkt_disk_LBA	resd	1	; LBA address on disk (only 28 bits implemented)**/
pkt_LBA_high	resd	1	; extension to 40-bit LBA (not ueed) */
endstruc
; */
; */
; */
; */
; disk parameter packet (for return) */
; */
struc _PARAM_PACKET
pkt_param_size	resw	1		; same offset as 'pkt_size' aovve */
; Size will be 26 (no EDD ptr) or 30 (EDD ptr present, but may be invalid */
ppt_info	resw	1
;        ; bit   usage		*/
;        ;  0    DMA boundary errors are handled transparently		*/
;        ;  1    Geometry valid (bytes 8-12)		*/
;        ;  2    Removable device (no)		*/
;        ;  3    Supports Write with Verify (no)		*/
;        ;  4    change line support (no)		*/
;        ;  5    removable & lockable (no)		*/
;        ;  6    max. geometry for a removable drive (no)		*/
;        ;  7-15  MBZ		*/
pkt_phys_cylinders	resd	1	; cylinders per disk */
pkt_phys_heads	resd	1		; tracks per cylinder */
pkt_phys_sectors	resd	1	; sectors per track */
pkt_total_sectors	resd	2	; total sectors on disk*//
pkt_bytes	resw	1		; bytes per sector (512) */
pkt_EDD_param_ptr	resd	1	; EDD configuration parameter pointer */
; FFFF:FFFF means invalid pointer */
endstruc
; */
;------------------------------------------------------------------
;   Specific to the IDE drivers
; More symbolic constants... these should not be changed, unless of
; course the IDE drive interface changes, perhaps when drives get
; to 128G and the PC industry will do yet another kludge.
; */
;IDE Command Constants.  These should never change.
%define	ide_cmd_recal	0x10
%define	ide_cmd_read	0x20
%define	ide_cmd_write	0x30
%define	ide_cmd_init	0x91
%define	ide_cmd_dma_read	0xC8
%define	ide_cmd_dma_write	0xCA
%define	ide_cmd_spindown	0xE0
%define	ide_cmd_spinup	0xE1
%define	ide_cmd_ident	0xEC
%define	ide_cmd_set_feature	0xEF
