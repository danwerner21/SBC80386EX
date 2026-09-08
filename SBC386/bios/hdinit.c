/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; hdinit.c -- IDE interface reset, IDENTIFY, and drive enumeration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2026 Dan Werner.  All rights reserved.
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
*/

#include "mytypes.h"
#include "cprintf.h"
#include "nvram.h"		/* the bda macro, and the ASM keyword */
#include "hdinit.h"

/*
 * IDE task file.  These mirror the EQUs at the head of diskide.asm --
 * the board puts the alternate status / device control register at
 * HF_PORT+14 rather than the PC/AT 3F6h.
 */
#define HF_PORT		0x01F0
#define IDEDTA		(HF_PORT+0)
#define IDEERR		(HF_PORT+1)	/* read: error, write: precomp */
#define IDESECC		(HF_PORT+2)
#define IDELBAL		(HF_PORT+3)
#define IDELBAM		(HF_PORT+4)
#define IDELBAH		(HF_PORT+5)
#define IDEDRV		(HF_PORT+6)
#define IDESTTS		(HF_PORT+7)	/* read: status, write: command */
#define IDEALTS		(HF_PORT+14)	/* read: alt status, write: dev control */

/* status register */
#define STS_BSY		0x80
#define STS_DRDY	0x40
#define STS_DF		0x20
#define STS_DRQ		0x08
#define STS_ERR		0x01

/* device control register */
#define DC_nIEN		0x02
#define DC_SRST		0x04

/* IDENTIFY word 49, capabilities */
#define CAP_DMA		0x0100
#define CAP_LBA		0x0200

/*
 * Timeouts, in 18.2hz ticks.  Coarse, but the tick is the only clock
 * still running once POST is over: start_timer0_ in 1Ah_time.asm gates
 * counters 1 and 2 off, so Timer 1 is not available as a microsecond
 * source without enabling it first.
 */
#define TICKS_PER_SEC	18
#define RESET_TICKS	(6*TICKS_PER_SEC)
#define SELECT_TICKS	(1*TICKS_PER_SEC)

/* in diskide.asm -- declared as lib/testide.c declares it, so that the
   Watcom register calling convention matches */
int IDE_READ_ID(byte,byte far *);

/* A000:8000, the base of the SRAM.  Declared in start.asm. */
extern byte *SecBuffer;


/*
 * Byte in / byte out.  Written out rather than called through
 * inp()/outp() so the access width is unambiguous, and to avoid relying
 * on the library prototypes in mytypes.h matching what Open Watcom
 * actually exports.
 */
static byte pin( word port )
{
	word	v;

	ASM {
		mov	dx,[port]
		in	al,dx
		xor	ah,ah
		mov	[v],ax
	}
	return( (byte)v );
}


static void pout( word port, word val )
{
	ASM {
		mov	dx,[port]
		mov	ax,[val]
		out	dx,al
	}
}


/*
 * A single word read of timer_count_low cannot tear against the IRQ0
 * handler, and unsigned subtraction rides through the 16-bit wrap --
 * which is a little over an hour away, far beyond any timeout here.
 */
static word tick( void )
{
	return( bda.timer_count_low );
}


static int expired( word start, word ticks )
{
	return( (word)(tick() - start) > ticks );
}


/*
 * ATA wants SRST asserted for at least 5us, and 400ns of settling after
 * a drive select.  With no microsecond clock available the delay is
 * spent reading the ALTERNATE status register, which has no side
 * effects -- unlike the primary status register, which acknowledges a
 * pending interrupt.
 */
static void short_delay( int n )
{
	while( n-- > 0 )
		pin(IDEALTS);
}


static int wait_not_busy( word ticks )
{
	word	start = tick();

	for(;;) {
		if( !(pin(IDEALTS) & STS_BSY) )
			return( 0 );
		if( expired(start,ticks) )
			return( -1 );
	}
}


static void select_drive( int drive )
{
	pout( IDEDRV, (word)(0xE0 | (drive ? 0x10 : 0x00)) );
	short_delay(4);
}


/*
 * IDENTIFY data is collected by read_dataBE in diskide.asm, which
 * stores each ATA word with its bytes reversed so that the model and
 * serial strings come out readable.  Every numeric field therefore sits
 * big-endian and has to be put back together by hand.
 */
word id_word( byte *b, int n )
{
	return( (word)(((word)b[n*2] << 8) | b[n*2+1]) );
}


dword id_dword( byte *b, int n )
{
	/* The two halves are an ordinary little-endian pair of words. */
	return( ((dword)id_word(b,n+1) << 16) | id_word(b,n) );
}


/*
 * Soft-reset the interface.  SRST resets both devices on the cable, so
 * this is done once, before either drive is probed.
 *
 * nIEN is held asserted throughout: this driver polls, and the ICU has
 * no handler wired for the IDE interrupt.
 */
int hd_reset( void )
{
	pout( IDEALTS, DC_SRST | DC_nIEN );
	short_delay(40);			/* well over the 5us minimum */
	pout( IDEALTS, DC_nIEN );
	short_delay(40);

	select_drive(0);
	return( wait_not_busy(RESET_TICKS) );
}


/*
 * Is anything there, and what is it?
 *
 * Must be called before any IDENTIFY: the signature left in the LBA mid
 * and high registers by the reset stays valid only until something
 * writes them, and IDE_READ_ID goes through wr_lba, which does exactly
 * that.
 */
/*
 * Put one drive into 8-bit PIO: SET FEATURES (EFh) with feature 01h.
 *
 * This is NOT optional on this board.  read_data and read_dataBE in
 * diskide.asm move 512 single bytes through the data port, but a card
 * comes out of reset in 16-bit mode, where a byte access still advances
 * the card by a whole word.  The result is that every other byte is
 * dropped, the transfer runs off the end of the 512-byte IDENTIFY block
 * halfway through, and the tail of the buffer fills with zeroes --
 * which is exactly what words 49 and 60/61 reading back as zero looks
 * like.
 *
 * IDE_INITIALIZE in diskide.asm does the same thing, but it takes its
 * drive argument in BL where IDE_READ_ID takes it in AL, so it is not
 * safe to call the two with the same C prototype.  Done here instead.
 */
int hd_set_8bit( int drive )
{
	select_drive(drive);
	if( wait_not_busy(SELECT_TICKS) )
		return( -1 );

	pout( IDEERR,  0x01 );		/* feature 01h: enable 8-bit */
	pout( IDESTTS, 0xEF );		/* SET FEATURES */

	if( wait_not_busy(SELECT_TICKS) )
		return( -1 );

	return( (pin(IDESTTS) & STS_ERR) ? -1 : 0 );
}


/*
 * Does anything actually answer as this unit?
 *
 * The signature test alone is not enough: with no device 1 on the
 * cable, reads of device 1 registers commonly return device 0 values,
 * so an absent slave can look exactly like a duplicate of the master.
 * Writing a pattern to two scratch registers and reading it back
 * narrows it down.
 *
 * It is not conclusive, though, and should not be read as such: on many
 * interfaces device 0 answers writes as well as reads for an absent
 * device 1, and will hold the pattern quite happily.  A pass here means
 * "something responded", not "the slave exists".  The identical-geometry
 * warning in hd_report() is the backstop.
 *
 * This destroys the reset signature, so call it after hd_probe().
 */
int hd_present( int drive )
{
	select_drive(drive);
	if( wait_not_busy(SELECT_TICKS) )
		return( 0 );

	pout( IDESECC, 0x55 );
	pout( IDELBAL, 0xAA );
	pout( IDESECC, 0xAA );
	pout( IDELBAL, 0x55 );
	pout( IDESECC, 0x55 );
	pout( IDELBAL, 0xAA );

	return( pin(IDESECC) == 0x55 && pin(IDELBAL) == 0xAA );
}


/*
 * Is anything there, and what is it?
 *
 * Must be called before any IDENTIFY and before hd_present(): the
 * signature left in the LBA mid and high registers by the reset stays
 * valid only until something writes them.
 */
int hd_probe( int drive )
{
	byte	sts, lm, lh;

	select_drive(drive);
	if( wait_not_busy(SELECT_TICKS) )
		return( HD_ABSENT );

	sts = pin(IDEALTS);
	if( sts == 0x00 || sts == 0xFF )	/* nothing driving the bus */
		return( HD_ABSENT );

	lm = pin(IDELBAM);
	lh = pin(IDELBAH);

	if( lm == 0x00 && lh == 0x00 )	return( HD_ATA );
	if( lm == 0x14 && lh == 0xEB )	return( HD_ATAPI );
	return( HD_UNKNOWN );
}


/*
 * IDENTIFY one drive and fill in its parameter table.
 *
 * The geometry stored here is what the drive itself reports, straight
 * out of words 1/3/6.  No translation is applied: picking an LBA-assist
 * geometry that holds the cylinder count under 1024 is a separate step,
 * and AH=08h will want both the physical and the translated numbers.
 */
/*
 * LBA-assist translation.
 *
 * INT 13h can express at most 1024 cylinders, 255 heads and 63 sectors
 * per track, so a drive whose own geometry runs past that has to be
 * presented differently from the way it really is.  Sectors per track
 * is pinned at 63 and the head count is raised through 16/32/64/128/255
 * until the cylinder count fits.
 *
 * The break points are simply H*63*1024, the largest LBA each head
 * count can reach.  The last of them, 255*63*1024, is 16,450,560
 * sectors -- the familiar 8.4Gb ceiling on CHS addressing.  Past that
 * the tail of the drive cannot be reached through AH=02h at all and the
 * LBA packet calls have to be used.
 *
 * A drive that already fits inside the INT 13h limits is left alone.
 * Its own geometry reaches every sector it has, and translating would
 * only round the capacity down for no gain.
 */
static void hd_translate( T_DISKTAB *dt )
{
	dword	lba = dt->max_lba;
	word	h;

	if( dt->phys_cylinders >= 1 && dt->phys_cylinders <= 1024
	 && dt->phys_heads     >= 1
	 && dt->phys_sectors   >= 1 && dt->phys_sectors <= 63 ) {
		dt->ncylinders = dt->phys_cylinders;
		dt->n__heads   = dt->phys_heads;
		dt->nsectors   = dt->phys_sectors;
		return;
	}

	/* Nothing usable to translate from: no sane CHS and no LBA count.
	   Leave the geometry zeroed so hd_report() says so rather than
	   inventing numbers. */
	if( lba == 0UL )
		return;

	if	( lba <= 1032192UL )	h = 16;		/*  16*63*1024 */
	else if ( lba <= 2064384UL )	h = 32;
	else if ( lba <= 4128768UL )	h = 64;
	else if ( lba <= 8257536UL )	h = 128;
	else				h = 255;	/* 255*63*1024 */

	dt->n__heads = (byte)h;
	dt->nsectors = 63;

	lba /= (dword)h * 63UL;
	dt->ncylinders = (lba > 1024UL) ? 1024 : (word)lba;
}


int hd_identify( int drive, T_DISKTAB *dt )
{
	byte	*b = SecBuffer;
	byte	*p = (byte *)dt;
	word	caps, c, h, s;
	int	i;

	if( IDE_READ_ID( (byte)(drive ? 0x10 : 0x00), b ) )
		return( -1 );

	for( i = 0; i < sizeof(T_DISKTAB); i++ )	/* start clean */
		p[i] = 0;

	caps = id_word(b,49);
	c    = id_word(b,1);
	h    = id_word(b,3);
	s    = id_word(b,6);

	/* Range-check before narrowing.  phys_heads and phys_sectors are
	   bytes, and a straight cast would quietly turn a nonsense 800
	   into 32 -- which reads like a plausible geometry and hides the
	   fault. */
	dt->phys_cylinders = c;
	dt->phys_heads     = (h >= 1 && h <= 255) ? (byte)h : 0;
	dt->phys_sectors   = (s >= 1 && s <=  63) ? (byte)s : 0;

	dt->max_lba     = id_dword(b,60);
	dt->unit_number = (byte)drive;

	hd_translate(dt);

	/* PC/AT convention: bit 3 marks a drive with more than 8 heads.
	   Keyed off the translated count, since that is the one exposed. */
	if( dt->n__heads > 8 )
		dt->control_bits = 0x08;

	/* USE_8BIT is a property of this driver, not of the drive:
	   read_data and write_data in diskide.asm move 512 single bytes
	   through the data port rather than 256 words. */
	dt->disk_flags = USE_CHS | USE_8BIT;
	if( caps & CAP_LBA )	dt->disk_flags |= USE_LBA;
	if( caps & CAP_DMA )	dt->disk_flags |= USE_DMA;

	return( 0 );
}

int hdinit( T_DISKTAB *tabs, int ntabs )
{
	int	kind[2];
	int	n = 0;
	int	d;

	if( hd_reset() ) {
		printf("IDE: no response to soft reset\n");
		return( 0 );
	}

	for( d = 0; d < 2; d++ )		/* signatures first: no writes */
		kind[d] = hd_probe(d);

	for( d = 0; d < 2; d++ ) {
		if( kind[d] == HD_ATA && !hd_present(d) )
			kind[d] = HD_ABSENT;	/* registers do not hold */
	}

	for( d = 0; d < 2 && n < ntabs; d++ ) {

		if( kind[d] == HD_ATAPI ) {
			printf("IDE %s: ATAPI device, not a fixed disk\n",
				d ? "slave " : "master");
			continue;
		}
		if( kind[d] != HD_ATA )
			continue;

		if( hd_set_8bit(d) ) {
			printf("IDE %s: will not accept 8-bit PIO mode\n",
				d ? "slave " : "master");
			continue;
		}

		if( hd_identify(d,&tabs[n]) == 0 )
			++n;
		else
			printf("IDE %s: IDENTIFY failed\n",
				d ? "slave " : "master");
	}

	return( n );
}


void hd_report( T_DISKTAB *tabs, int n )
{
	T_DISKTAB	*dt;
	int		i;

	if( n == 0 ) {
		printf("IDE: no drives found\n");
		return;
	}

	for( i = 0; i < n; i++ ) {
		dt = &tabs[i];

		printf("IDE %s  LBA %lu = %lu Mb  flags %02X\n",
			dt->unit_number ? "slave " : "master",
			dt->max_lba,
			dt->max_lba / 2048UL,
			(word)dt->disk_flags);

		printf("            drive %u/%u/%u   INT 13h %u/%u/%u%s\n",
			dt->phys_cylinders,
			(word)dt->phys_heads,
			(word)dt->phys_sectors,
			dt->ncylinders,
			(word)dt->n__heads,
			(word)dt->nsectors,
			(dt->ncylinders == 0 || dt->n__heads == 0 ||
			 dt->nsectors   == 0)
				? "   (no usable geometry)"
			: (dt->ncylinders != dt->phys_cylinders ||
			   dt->n__heads   != dt->phys_heads     ||
			   dt->nsectors   != dt->phys_sectors)
				? "   (translated)" : "");
	}

	/* Two units reporting the same size is the signature of a slave
	   that is not really there, answering with the master's registers. */
	if( n == 2 && tabs[0].max_lba == tabs[1].max_lba
		   && tabs[0].phys_cylinders == tabs[1].phys_cylinders )
		printf("IDE: both units report identical geometry"
		       " -- check the slave jumper/strap\n");
}


/*
 * Where the fixed-disk parameter tables live.
 *
 * They have to outlast POST: the INT 41h and INT 46h vectors point at
 * them and DOS reads them long afterwards, so the stack is no good, and
 * this build has no writable statics at all -- _DATA and _BSS are both
 * zero length and must stay that way.  There is no EBDA allocator to
 * fall back on either: ebda_alloc() is declared in main.c but has never
 * been written.
 *
 * So they are carved out of the 41 reserved bytes in the BDA, which is
 * exactly what that space is labelled for.  T_DISKTAB is 20 bytes since
 * the physical geometry was added, so two of them take 40 of the 41.
 * That is the whole budget: a third drive will not fit here, and the
 * guard in hd_enumerate() is what catches it if the struct grows again.
 */
#define HD_MAX_DRIVES	2
#define hd_tables	((T_DISKTAB *)(bda.rsvd_unused))


/*
 * Write one interrupt vector.
 *
 * The far pointer is built through a union rather than by casting an
 * integer.  The obvious form,
 *
 *	*(void **)(((dword)seg << 16) | off) = addr;
 *
 * looks right and is what was here first, but Open Watcom does not
 * reinterpret an integer as a segment:offset pair -- it produced a
 * DS-relative address, so the write landed at DGROUP:0104 in the ROM
 * and did nothing at all.  bda.hd_number and bda.disk_tab[] were
 * written correctly the whole time, because those go through the real
 * far pointer in bda_ptr, which is why the symptom looked like only
 * the vectors failing.
 */
static void *get_vector( int intno )
{
	union {
		void	**p;
		struct { word off; word seg; } fp;
	} v;

	v.fp.off = (word)(intno * 4);
	v.fp.seg = 0x0000;

	return( *(v.p) );
}


static void set_vector( int intno, void *addr )
{
	union {
		void	**p;
		struct { word off; word seg; } fp;
	} v;

	v.fp.off = (word)(intno * 4);
	v.fp.seg = 0x0000;

	*(v.p) = addr;
}


/*
 * Enumerate the IDE drives, publish them, and report.
 *
 * INT 41h and INT 46h are data vectors, not code: on a PC/AT they point
 * at the fixed-disk parameter table for drive 80h and 81h.  Until now
 * both pointed at int_nop in stub.asm, which is an IRET.
 */
void hd_enumerate( void )
{
	T_DISKTAB	*tabs = hd_tables;
	int		n, i;

	if( sizeof(T_DISKTAB) * HD_MAX_DRIVES > sizeof(bda.rsvd_unused) ) {
		printf("IDE: parameter tables do not fit the reserved BDA area\n");
		return;
	}

	n = hdinit( tabs, HD_MAX_DRIVES );
	hd_report( tabs, n );

	/* Unconditionally.  The assignment this replaces, in main.c, ran
	   only when 'code' was non-zero -- that is, only when the NVRAM
	   checksum was bad, the clock had stopped, or charging was off.
	   On a healthy board no drive was ever registered. */
	bda.hd_number = (byte)n;

	for( i = 0; i < NDISKS; i++ )
		bda.disk_tab[i] = FX_NONE;

	for( i = 0; i < n; i++ )
		bda.disk_tab[i] = (byte)(tabs[i].unit_number ? FX_IDEs
							    : FX_IDEm);

	if( n > 0 )	set_vector( 0x41, &tabs[0] );
	if( n > 1 )	set_vector( 0x46, &tabs[1] );
	if( n ) {
		union {
			void	*p;
			struct { word off; word seg; } fp;
		} chk;

		/* Read the vector back rather than reporting what we meant
		   to write.  The previous message claimed "INT 41h/46h set"
		   from constants, and went on saying it for days while the
		   write was going into the ROM. */
		chk.p = get_vector(0x41);
		printf("IDE: %d drive(s) registered, INT 41h -> %04X:%04X\n",
			n, chk.fp.seg, chk.fp.off);
	}
}
