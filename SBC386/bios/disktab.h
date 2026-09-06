XXX
/* disktab.h -- layout of the fixed disk parameter table */

typedef struct _DISKTAB {
/* */
/* N.B.:   Disk Driver INIT must fill in at least:				*/
/* */
/*		ncylinders	1..1024		*/
/*		n__heads	1..254		*/
/*		nsectors	1..63		*/
/*		max_lba		up to 2^28    number of LBA sectors		*/
/*		flags		(see below)		*/
/* */
#define USE_CHS 0x01			/* may use Cyl:Hd:Sec access */
#define USE_LBA 0x02			/* may use LBA access up to 28-bits */
#define USE_DMA 0x04			/* may use DMA access */
#define USE_8BIT 0x08			/* may/must use 8 bit access */
#define USE_16BIT 0x10			/* may/must use 16 bit access */
#define USE_BIG_LBA 0x20		/* may use LBA 40-bit addressing */
/* */
	word	ncylinders;		/* maximum number of cylinders */
	byte	n__heads;		/* maximum number of heads */
	word	used_on_XT;
	word	precomp_cylinder;
/* was	byte	ECC_length;		*/
	byte	unit_number;	/* unit number Master=0, Slave=1 */
	byte	control_bits;	/* PC/AT definitions below */
/* bit 7 -or- bit 6 disables retries */
/* bit 3 - more than 8 heads */
			/* SBC-386EX definitions TBD */
/* */
/* was	byte	reserved[3];	/* may become more control bit options */
	byte	res1;
/*	byte	res2;
/*	byte	res3;
/*	word	landing_zone;	/* 386EX does not use this */
	dword	max_lba;	/* up to 28 bits  ==  128Gb = 137gb */
	byte	nsectors;	/* maximum number of sectors per track */
/* was	byte	reserved2;	   386EX usage TBD */
	byte	disk_flags;		/* see bit definitions above */

} T_DISKTAB;
/* */
/* */
/* */
/* */




/* disk packet call structure */
typedef struct _PACKET {
	word	pkt_size;		/* R/W = 16 */
	word	pkt_blocks;		/* blocks to transfer up to 127 */
	dword	pkt_address;	/* Seg:Off of source/destination */
	dword	pkt_disk_LBA;	/* LBA address on disk (only 28 bits implemented) */
	dword	pkt_LBA_high;	/* extension to 40-bit LBA (not used) */
} T_PACKET;
/* */
/* */
/* */
/* */


/* disk parameter packet (for return) */
/* */
typedef struct _PARAM_PACKET {
	word	pkt_param_size;		/* same offset as 'pkt_size' above */
/* Size will be 26 (no EDD ptr) or 30 (EDD ptr present, but may be invalid */
	word	ppt_info;
/*        ; bit   usage		*/
/*        ;  0    DMA boundary errors are handled transparently		*/
/*        ;  1    Geometry valid (bytes 8-12)		*/
/*        ;  2    Removable device (no)		*/
/*        ;  3    Supports Write with Verify (no)		*/
/*        ;  4    change line support (no)		*/
/*        ;  5    removable & lockable (no)		*/
/*        ;  6    max. geometry for a removable drive (no)		*/
/*        ;  7-15  MBZ		*/
	dword	pkt_phys_cylinders;	/* cylinders per disk */
	dword	pkt_phys_heads;		/* tracks per cylinder */
	dword	pkt_phys_sectors;	/* sectors per track */
	dword	pkt_total_sectors[2];	/* total sectors on disk */
	word	pkt_bytes;		/* bytes per sector (512) */
	dword	pkt_EDD_param_ptr;	/* EDD configuration parameter pointer */
					/* FFFF:FFFF means invalid pointer */
} T_PARAM_PACKET;
/* */


/*------------------------------------------------------------------
/*   Specific to the IDE drivers
/* More symbolic constants... these should not be changed, unless of
/* course the IDE drive interface changes, perhaps when drives get
/* to 128G and the PC industry will do yet another kludge.
/* */
/*IDE Command Constants.  These should never change.
#define	ide_cmd_recal	0x10
#define	ide_cmd_read	0x20
#define	ide_cmd_write	0x30
#define	ide_cmd_init	0x91
#define	ide_cmd_dma_read	0xC8
#define	ide_cmd_dma_write	0xCA
#define	ide_cmd_spindown	0xE0
#define	ide_cmd_spinup	0xE1
#define	ide_cmd_ident	0xEC
#define	ide_cmd_set_feature	0xEF
