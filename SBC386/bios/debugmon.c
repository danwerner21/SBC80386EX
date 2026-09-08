/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; debugmon.c -- trivial level debug monitor for bios debugging and visibility
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
#include "strtobcd.h"
#include "strtoint.h"
#include "getline.h"
#include "nvram.h"		/* ASM keyword, T_STR, and the bda macro */
#include "debugmon.h"
#include "hdinit.h"

#define LINE 40
#define BYTES_PER_LINE 16
#define DEFAULT_LEN 0x80	/* bytes shown when no end address is given */
#define MAX_IO_COUNT 0x100	/* ceiling on the IOR port sweep */


/*
 * Parse one address token.  Two forms are accepted:
 *
 *	F000:FFF0	segment:offset, folded to seg*16 + off
 *	FFFF0		a flat physical address, up to 8 hex digits
 *
 * strtoint() eats leading blanks and ':' and hands back an unmoved
 * pointer when it finds no digits, which is what "nothing here" is
 * tested with.  Returns 0 if no address was present.
 */
static int parse_addr( char **pp, dword *out )
{
	char	*before = *pp;
	dword	v, off;

	v = strtoint( *pp, pp );
	if( *pp == before )
		return( 0 );		/* nothing consumed */

	if( **pp == ':' ) {
		++(*pp);
		off = strtoint( *pp, pp );
		v = (v << 4) + off;
	}

	*out = v;
	return( 1 );
}


/*
 * Parse a GO target.  "F000:E000" is taken exactly as written so the
 * callee sees the CS it was asked for -- that matters for any routine
 * with CS-relative data.  A flat address is folded to seg:off with the
 * offset held to 0..15.
 *
 * Returns 1 on success, 0 if no address was present, -1 if a flat
 * address was given that Real Mode cannot reach.
 */
static int parse_far( char **pp, word *seg, word *off )
{
	char	*before = *pp;
	dword	v, o;

	v = strtoint( *pp, pp );
	if( *pp == before )
		return( 0 );			/* nothing consumed */

	if( **pp == ':' ) {
		++(*pp);
		o = strtoint( *pp, pp );
		*seg = (word)v;
		*off = (word)o;
		return( 1 );
	}

	if( v >= 0x100000UL )
		return( -1 );			/* above the 1Mb wall */

	*seg = (word)(v >> 4);
	*off = (word)(v & 0x0FUL);
	return( 1 );
}


/*
 * Optional hex value.  *out is left alone and 0 returned when the line
 * has run out, so trailing arguments can simply be omitted.
 */
static int parse_val( char **pp, dword *out )
{
	char	*before = *pp;
	dword	v;

	v = strtoint( *pp, pp );
	if( *pp == before )
		return( 0 );

	*out = v;
	return( 1 );
}


static int parse_word( char **pp, word *val )
{
	dword	v;

	if( !parse_val( pp, &v ) )
		return( 0 );

	*val = (word)v;
	return( 1 );
}


/*
 * Match a command keyword.  The keyword has to be followed by a blank
 * or the end of the line, which is what lets IOR and IORW be told
 * apart -- a plain strncmp() on the shorter name matches both.  On a
 * match *pp is advanced past the keyword.
 */
static int is_cmd( char **pp, const char *kw )
{
	int	n = 0;
	char	c;

	while( kw[n] ) {
		if( (*pp)[n] != kw[n] )
			return( 0 );
		++n;
	}

	c = (*pp)[n];
	if( c != '\0' && c != ' ' && c != 0x09 )
		return( 0 );

	*pp += n;
	return( 1 );
}


/*
 * Byte and word access to an I/O port.  Written out here rather than
 * called through inp()/outp() so that the access width is exactly what
 * was asked for: the 386EX peripheral control block has genuine 16-bit
 * registers (the chip select, refresh, watchdog and SSIO blocks) that
 * must not be reached a byte at a time.
 */
static word io_read( word port, int wide )
{
	word	v;

	if( wide ) {
		ASM {
			mov	dx,[port]
			in	ax,dx
			mov	[v],ax
		}
	} else {
		ASM {
			mov	dx,[port]
			in	al,dx
			xor	ah,ah
			mov	[v],ax
		}
	}
	return( v );
}


static void io_write( word port, word val, int wide )
{
	if( wide ) {
		ASM {
			mov	dx,[port]
			mov	ax,[val]
			out	dx,ax
		}
	} else {
		ASM {
			mov	dx,[port]
			mov	ax,[val]
			out	dx,al
		}
	}
}


/*
 * Read a run of ports and display them.  The address advances with each
 * access, which is what makes a sweep of the 386EX peripheral block
 * worth having.
 *
 * Reading a port is not free of consequence: it pulls a character out
 * of a UART receive register, clears an interrupt identification
 * register, and so on.  A sweep across a live device will disturb it.
 */
static void io_dump( word port, word count, int wide )
{
	word	step     = wide ? 2 : 1;
	word	per_line = wide ? 8 : 16;
	word	col = 0;
	word	i;

	for( i = 0; i < count; i++ ) {

		if( col == 0 )
			printf( "%04X  ", port );

		if( wide )
			printf( "%04X ", io_read(port,1) );
		else
			printf( "%02X ", io_read(port,0) );

		port += step;

		if( ++col == per_line ) {
			printf( "\n" );
			col = 0;
		}
	}

	if( col )
		printf( "\n" );
}


/*
 * True if the operator has typed Ctrl-C.  A long dump at 9600 baud takes
 * a while, so Ctrl-C stops it.  Anything else typed is swallowed rather
 * than left in the UART, where it would turn up in the next MON> prompt.
 *
 * The status call comes first so this never blocks when nothing has been
 * typed.  The character is then taken with INT 14h directly rather than
 * through KBD_getchar(), because that routine retries whenever a line
 * error bit is set -- it would sit and wait for the next keystroke,
 * which is the opposite of what an abort check should do.
 */
static int abort_requested( void )
{
	word status;

	ASM {
		xor	dx,dx
		mov	ah,3
		int	0x14		; get serial port status
		mov	[status],ax
	}

	if( !(status & 0x0100) )	/* no character waiting */
		return( 0 );

	ASM {
		xor	dx,dx
		mov	ah,2		; a character is ready: this returns at once
		int	0x14
		mov	[status],ax
	}

	return( (status & 0x7F) == ASCII_CTRLC );	/* AL, masked to 7 bits */
}


/*
 * Dump physical memory between two flat addresses.
 *
 * The bytes are fetched through pm_read(), which drops into Protected
 * Mode for the length of the move, so the whole 4Gb physical space is
 * reachable -- not just the first megabyte the old real-mode far
 * pointer could form.  Everything else here runs in Real Mode, which
 * keeps printf and the INT 14h console working normally.
 *
 * One pm_read() per display line means one mode switch per 16 bytes.
 * That is deliberate: the line buffer lives on the stack in Real Mode,
 * and a short move keeps interrupts disabled for only a few
 * microseconds at a time.
 */
void DumpMemory( dword start, dword end )
{
	dword	lineBase;
	byte	buf[BYTES_PER_LINE];
	byte	b;
	int	first, last, i;

	if( end < start )
		return;

	/* Start the display on a 16-byte boundary so the columns line up. */
	lineBase = start & ~0x0FUL;

	for( ;; ) {

		/* Which columns of this line fall inside the requested range. */
		first = (lineBase < start) ? (int)(start - lineBase) : 0;
		last  = (end - lineBase < BYTES_PER_LINE)
				? (int)(end - lineBase) : BYTES_PER_LINE - 1;

		/* Fetch the line first: exactly one bus cycle per location. */
		pm_read( lineBase + (dword)first,
			 &buf[first],
			 (word)(last - first + 1) );

		printf( "%08lX  ", lineBase );

		for( i = 0; i < BYTES_PER_LINE; i++ ) {
			if( i >= first && i <= last )
				printf( "%02X ", buf[i] );
			else
				printf( "   " );
			if( i == 7 )
				printf( " " );
		}

		printf( " |" );
		for( i = 0; i < BYTES_PER_LINE; i++ ) {
			if( i < first || i > last ) {
				printf( " " );
			} else {
				b = buf[i];
				printf( "%c", (b >= 0x20 && b < 0x7F) ? (char)b : '.' );
			}
		}
		printf( "|\n" );

		/* Unsigned compare, so the last line ends the loop before
		   lineBase can be stepped past the top of memory. */
		if( end - lineBase < BYTES_PER_LINE )
			break;
		lineBase += BYTES_PER_LINE;

		if( abort_requested() ) {
			printf( "^C  -- dump stopped --\n" );
			break;
		}
	}
}


/* Must correspond exactly with the ENUM in "nvram.h".  Short forms of
   the names in "fixed_disks[]" in set1302.c, to keep the table on two
   display lines. */
T_STR disk_short[] = {
	"none",
	"uSD ",
	"SD0 ",
	"SD1 ",
	"IDEm",
	"IDEs",
	};


/*
 * Decode the BIOS Data Area at 0040:0000.
 *
 * Only the fields this BIOS actually maintains are broken out.  The
 * PC/AT EGA and hard-disk media areas are carried in the structure for
 * layout compatibility but are never written here, so they are left
 * out rather than displayed as meaningless zeroes -- "DUMP 40:0 40:101"
 * shows the raw 258 bytes when that is what is wanted.
 */
void DumpBDA( void )
{
	dword	tc;
	word	f, khz;
	int	i;

	f  = bda.equip_flag;
	tc = ((dword)bda.timer_count_high << 16) | bda.timer_count_low;
	khz = bda.CPU_freq + 5;			/* round up, as main.c does */

	printf("BIOS Data Area at %04X:0000\n\n", BDA_segment);

	printf("Equip    %04X  FPU %s  serial ports %u  mfg %02X %02X %02X\n",
		f,
		(f & 0x0002) ? "yes" : "no ",
		(word)((f >> 9) & 7),
		bda.mfg_test, bda.mfg_err_flag, bda.mfg_err_flag2);

	printf("Memory   conv %uKb  ext %uKb  SRAM %uKb  CPU %u.%02umhz\n",
		bda.memory_size,
		bda.extended_memory,
		(word)bda.SRAM_size,
		(word)(khz / 1000u),
		(word)((khz / 10u) % 100u));

	printf("Misc     EBDA %04X  errno %04X  ATstat %02X  reset %04X"
	       "  ROMinit %08lX\n",
		bda.ebda_seg_ptr,
		bda.errno,
		(word)bda.AT_status_byte,
		bda.reset_flag,
		bda.io_rom_addr);

	printf("\nSerial   dev %04X %04X %04X %04X   flags %02X %02X %02X %02X\n",
		bda.serial_dev[0], bda.serial_dev[1],
		bda.serial_dev[2], bda.serial_dev[3],
		(word)bda.serial_flags[0], (word)bda.serial_flags[1],
		(word)bda.serial_flags[2], (word)bda.serial_flags[3]);
	printf("         timeout %02X %02X %02X %02X\n",
		(word)bda.serial_timeout[0], (word)bda.serial_timeout[1],
		(word)bda.serial_timeout[2], (word)bda.serial_timeout[3]);

	printf("Parallel dev %04X %04X %04X %04X   timeout %02X %02X %02X %02X\n",
		bda.parallel_dev[0], bda.parallel_dev[1],
		bda.parallel_dev[2], bda.parallel_dev[3],
		(word)bda.printer_timeout[0], (word)bda.printer_timeout[1],
		(word)bda.printer_timeout[2], (word)bda.printer_timeout[3]);

	printf("\nTimer    %08lX  overflow %02X  intflag %02X  RTCwait %02X\n",
		tc,
		(word)bda.timer_overflow,
		(word)bda.interrupt_flag,
		(word)bda.rtc_wait_active);

	printf("Keybd    flag %02X %02X %02X %02X  head %04X tail %04X"
	       "  buf %04X..%04X  brk %02X\n",
		(word)bda.kbd_flag,  (word)bda.kbd_flag1,
		(word)bda.kbd_flag2, (word)bda.kbd_flag3,
		bda.buffer_head, bda.buffer_tail,
		bda.buffer_start, bda.buffer_end,
		(word)bda.kbd_break_flag);

	printf("\nFloppy   seek %02X motor %02X count %02X status %02X"
	       "  rate %02X  tab %02X %02X\n",
		(word)bda.seek_status, (word)bda.motor_status,
		(word)bda.motor_count, (word)bda.fd_status,
		(word)bda.fd_last_data_rate,
		(word)bda.floppy_tab[0], (word)bda.floppy_tab[1]);

	printf("FixedDsk n %u  status %02X  ctrl %02X  port %02X  track %04X"
	       "  sts/err %02X/%02X\n",
		(word)bda.hd_number,
		(word)bda.hd_status,
		(word)bda.control_byte,
		(word)bda.port_offset,
		bda.hd_track,
		(word)bda.hd_status_reg,
		(word)bda.hd_error_reg);

	for( i = 0; i < NDISKS; i++ ) {
		byte d = bda.disk_tab[i];

		if( (i & 3) == 0 )
			printf("Disktab ");
		if( d < FX_END )
			printf(" %u:%s", i, disk_short[d]);
		else
			printf(" %u:?%02X", i, (word)d);
		if( (i & 3) == 3 )
			printf("\n");
	}

	printf("\nNVRAM    sio0 %02X %02X  checksum %04X\n",
		(word)bda.nvram_info[0], (word)bda.nvram_info[1],
		bda.nvram_checksum);
}


/*
 * IDE entry points, in diskide.asm.  Declared exactly as lib/testide.c
 * declares them so the Watcom register calling convention matches.
 *
 * 'master_slave' is a mask, not an index: wr_lba tests bit 4, so it
 * wants 00h for the master and 10h for the slave.
 */
int IDE_READ_SECTOR(byte,byte far *, dword,byte);
int IDE_READ_ID(byte,byte far *);
int IDE_WRITE_SECTOR(byte,byte far *, dword,byte);

/* A000:8000 -- the base of the SRAM, declared in start.asm.  The stack
   lives at the top of the same 32Kb and grows down, so a 512-byte
   sector at the bottom is well clear of it. */
extern byte *SecBuffer;

#define SECTOR_SIZE 512

/* id_word() and id_dword() live in hdinit.c -- see the note there about
   the byte order IDE_READ_ID leaves the IDENTIFY data in. */

/*
 * Copy one of the space-padded ATA strings out and trim it.  'out' must
 * hold len+1 bytes.
 */
static void id_string( byte *b, int off, int len, char *out )
{
	int i;

	for( i = 0; i < len; i++ )
		out[i] = (char)b[off+i];

	while( i > 0 && (out[i-1] == ' ' || out[i-1] == '\0') )
		--i;

	out[i] = '\0';
}


/*
 * Hex and ASCII dump of a Real Mode buffer, offsets counted from zero.
 * Ctrl-C stops it, the same as the memory dump.
 */
static void dump_buffer( byte *buf, word len )
{
	word	base;
	byte	b;
	int	i;

	for( base = 0; base < len; base += BYTES_PER_LINE ) {

		printf( "%04X  ", base );

		for( i = 0; i < BYTES_PER_LINE; i++ ) {
			printf( "%02X ", (word)buf[base+i] );
			if( i == 7 )
				printf( " " );
		}

		printf( " |" );
		for( i = 0; i < BYTES_PER_LINE; i++ ) {
			b = buf[base+i];
			printf( "%c", (b >= 0x20 && b < 0x7F) ? (char)b : '.' );
		}
		printf( "|\n" );

		if( abort_requested() ) {
			printf( "^C  -- dump stopped --\n" );
			return;
		}
	}
}


/*
 * ATA IDENTIFY DEVICE, decoded.
 *
 * The raw 512 bytes are left in SecBuffer afterwards, so
 * "DUMP A000:8000 A000:81FF" shows them -- remembering that every word
 * in there is byte-swapped.
 */
void DumpIdentify( int drive )
{
	byte	*b = SecBuffer;
	char	str[41];
	word	cfg, caps;
	dword	lba28;

	/* The card leaves reset in 16-bit mode, and read_dataBE moves
	   single bytes -- without this the buffer comes back with every
	   other byte missing.  See hd_set_8bit() in hdinit.c. */
	if( hd_set_8bit(drive) ) {
		printf("IDE %s: will not accept 8-bit PIO mode\n",
			drive ? "slave" : "master");
		return;
	}

	if( IDE_READ_ID( (byte)(drive ? 0x10 : 0x00), b ) ) {
		printf("IDE %s: IDENTIFY failed\n", drive ? "slave" : "master");
		return;
	}

	cfg   = id_word(b,0);
	caps  = id_word(b,49);
	lba28 = id_dword(b,60);

	printf("IDE %s IDENTIFY   (raw data at %08lX)\n",
		drive ? "slave" : "master", SecBuffer);

	id_string(b,54,40,str);		printf("  Model     \"%s\"\n", str);
	id_string(b,20,20,str);		printf("  Serial    \"%s\"\n", str);
	id_string(b,46, 8,str);		printf("  Firmware  \"%s\"\n", str);

	printf("  Config    %04X   caps %04X   DMA %s   LBA %s   CFA-8bit %s\n",
		cfg, caps,
		(caps & 0x0100) ? "yes" : "no ",
		(caps & 0x0200) ? "yes" : "no ",
		(id_word(b,83) & 0x0004) ? "yes" : "no ");

	printf("  Geometry  %u cyl  %u head  %u sec/trk   multiple %u\n",
		id_word(b,1), id_word(b,3), id_word(b,6),
		(word)(id_word(b,47) & 0xFF));

	printf("  LBA28     %lu sectors  = %lu Mb\n",
		lba28, lba28 / 2048UL);
}


/*
 * Read one sector by LBA and dump it.
 */
void DumpSector( dword lba, int drive )
{
	/* read_data moves single bytes too -- same reason as IDENT. */
	if( hd_set_8bit(drive) ) {
		printf("IDE %s: will not accept 8-bit PIO mode\n",
			drive ? "slave" : "master");
		return;
	}

	if( IDE_READ_SECTOR( (byte)(drive ? 0x10 : 0x00),
			     SecBuffer, lba, 1 ) ) {
		printf("IDE %s: read of LBA %lu failed\n",
			drive ? "slave" : "master", lba);
		return;
	}

	printf("IDE %s  LBA %lu (%08lX)\n",
		drive ? "slave" : "master", lba, lba);

	dump_buffer( SecBuffer, SECTOR_SIZE );
}


void debugmon(void)
{
	char line[LINE], *cp;
	int _cont=1;
	int wide;

	do {
		printf("MON>");
		if (!getline(line,LINE)) continue;
		cp = line;

		if( is_cmd(&cp,"DUMP") )
		{
			dword start, end;

			if( !parse_addr(&cp,&start) ) {
				printf("usage: DUMP <addr> [<end>]\n"
				       "       addr is F000:FFF0 or a flat 3F00000\n");
				continue;
			}
			if( !parse_addr(&cp,&end) )
				end = start + (DEFAULT_LEN - 1);

			DumpMemory(start,end);
			continue;
		}

		if( is_cmd(&cp,"BDA") )
		{
			DumpBDA();
			continue;
		}

		if( is_cmd(&cp,"SEC2") )
		{
			dword	lba;
			word	n, sts, blk;
			byte	*b = SecBuffer;

			/* Read TWO sectors and count the bytes in each DRQ
			   block separately.  Read-only, so nothing here
			   depends on the untested write path.
			   511 + 511 -> the loss is once per block.
			   512 + 511 -> it is once per command, and the first
			                sector of a multi-sector read is whole.
			   512 + 512 -> single-sector reads are the special
			                case. */
			if( !parse_val(&cp,&lba) ) {
				printf("usage: SEC2 <lba>\n");
				continue;
			}

			hd_set_8bit(0);

			io_write(0x1F6,(word)(0xE0 | (word)((lba>>24) & 0x0FUL)),0);
			io_write(0x1F2,2,0);		/* two sectors */
			io_write(0x1F3,(word)(lba & 0xFFUL),0);
			io_write(0x1F4,(word)((lba>>8) & 0xFFUL),0);
			io_write(0x1F5,(word)((lba>>16) & 0xFFUL),0);
			io_write(0x1F7,0x20,0);

			for( blk = 0; blk < 2; blk++ ) {

				for( n = 0; n < 30000; n++ ) {
					sts = io_read(0x1F7,0);
					if( sts & 0x01 ) break;
					if( (sts & 0x88) == 0x08 ) break;
				}
				if( !(sts & 0x08) ) {
					printf("block %u: no DRQ, status %02X\n",
						blk, sts);
					break;
				}

				for( n = 0; n < 600; n++ ) {
					sts = io_read(0x1F7,0);
					if( !(sts & 0x08) ) break;
					b[ (n < 512) ? n : 511 ] =
						(byte)io_read(0x1F0,0);
				}
				printf("block %u: %u bytes, status %02X,"
				       " last 4: %02X %02X %02X %02X\n",
					blk, n, sts,
					(word)b[508], (word)b[509],
					(word)b[510], (word)b[511]);
			}
			continue;
		}

		if( is_cmd(&cp,"SECTEST") )
		{
			dword	lba;
			word	i, bad, first;
			byte	*b = SecBuffer;
			byte	pre[16];

			/* *** THIS DESTROYS THE SECTOR IT IS GIVEN ***
			 *
			 * Round-trip a pattern of our own choosing, so the
			 * result does not depend on what happens to be on the
			 * card.  Reading alone cannot tell a byte that arrived
			 * correctly from a constant the bus happened to be
			 * holding -- which is what 60h at byte 511 of two
			 * different sectors looks like.
			 */
			if( !parse_val(&cp,&lba) ) {
				printf("usage: SECTEST <lba>"
				       "   *** OVERWRITES that sector ***\n");
				continue;
			}

			/* Read the sector twice FIRST.  If two reads of the
			   same untouched sector disagree, the read path is
			   unreliable on this card and nothing the write test
			   reports afterwards can be attributed.  This is the
			   step that was missing when SECTEST was first run on
			   a card already known to drop its last byte. */
			if( IDE_READ_SECTOR(0,b,lba,1) ) {
				printf("pre-read of LBA %lu failed\n", lba);
				continue;
			}
			for( i = 0; i < SECTOR_SIZE; i++ )
				pre[i & 0x0F] = b[i];		/* keep a tail */
			printf("pre-read  0..3: %02X %02X %02X %02X"
			       "   508..511: %02X %02X %02X %02X\n",
				(word)b[0], (word)b[1], (word)b[2], (word)b[3],
				(word)b[508], (word)b[509],
				(word)b[510], (word)b[511]);

			if( IDE_READ_SECTOR(0,b,lba,1) ) {
				printf("second pre-read failed\n");
				continue;
			}
			bad = 0;
			for( i = 0; i < SECTOR_SIZE; i++ )
				if( b[i] != pre[i & 0x0F] && (i & 0x0F) == 0x0F )
					++bad;
			printf("two reads of the same sector %s\n",
				bad ? "DISAGREE -- read path is unreliable"
				    : "agree");

			for( i = 0; i < SECTOR_SIZE; i++ )
				b[i] = (byte)(i ^ 0x5A);

			if( IDE_WRITE_SECTOR(0,b,lba,1) ) {
				printf("write of LBA %lu failed\n", lba);
				continue;
			}

			for( i = 0; i < SECTOR_SIZE; i++ )	/* scrub */
				b[i] = 0;

			if( IDE_READ_SECTOR(0,b,lba,1) ) {
				printf("read back of LBA %lu failed\n", lba);
				continue;
			}

			bad = 0;
			first = 0xFFFF;
			for( i = 0; i < SECTOR_SIZE; i++ ) {
				if( b[i] != (byte)(i ^ 0x5A) ) {
					if( first == 0xFFFF ) first = i;
					++bad;
				}
			}

			printf("LBA %lu round trip: %u of %u bytes wrong\n",
				lba, bad, (word)SECTOR_SIZE);
			if( bad )
				printf("first bad at %u: expected %02X got %02X\n",
					first, (word)(byte)(first ^ 0x5A),
					(word)b[first]);
			printf("byte 511: expected %02X got %02X   %s\n",
				(word)(byte)(511 ^ 0x5A), (word)b[511],
				(b[511] == (byte)(511 ^ 0x5A)) ? "OK" : "WRONG");
			continue;
		}

		if( is_cmd(&cp,"SECRAW16") )
		{
			dword	lba;
			word	n, sts, w;
			byte	*b = SecBuffer;

			if( !parse_val(&cp,&lba) ) {
				printf("usage: SECRAW16 <lba>\n");
				continue;
			}

			/* Turn 8-bit PIO back OFF (SET FEATURES 81h) and read
			   the sector as 256 words.  The card powers up in
			   16-bit mode -- that is what the garbled IDENTIFY
			   looked like before hd_set_8bit() existed -- so if
			   word reads work, the whole 8-bit path is a
			   workaround we may not need, and it moves half as
			   many bus cycles. */
			io_write(0x1F1,0x81,0);
			io_write(0x1F7,0xEF,0);
			for( n = 0; n < 30000; n++ ) {
				sts = io_read(0x1F7,0);
				if( !(sts & 0x80) ) break;
			}
			printf("SET FEATURES 81h -> status %02X\n", sts);

			io_write(0x1F6,(word)(0xE0 | (word)((lba>>24) & 0x0FUL)),0);
			io_write(0x1F2,1,0);
			io_write(0x1F3,(word)(lba & 0xFFUL),0);
			io_write(0x1F4,(word)((lba>>8) & 0xFFUL),0);
			io_write(0x1F5,(word)((lba>>16) & 0xFFUL),0);
			io_write(0x1F7,0x20,0);

			for( n = 0; n < 30000; n++ ) {
				sts = io_read(0x1F7,0);
				if( sts & 0x01 ) break;
				if( (sts & 0x88) == 0x08 ) break;
			}
			printf("status at DRQ %02X\n", sts);

			for( n = 0; n < 256; n++ ) {
				sts = io_read(0x1F7,0);
				if( !(sts & 0x08) )
					break;
				w = io_read(0x1F0,1);		/* IN AX,DX */
				b[n*2]   = (byte)w;
				b[n*2+1] = (byte)(w >> 8);
			}
			printf("drive supplied %u words, final status %02X\n",
				n, sts);
			printf("bytes 0..3:     %02X %02X %02X %02X\n",
				(word)b[0], (word)b[1], (word)b[2], (word)b[3]);
			printf("bytes 508..511: %02X %02X %02X %02X\n",
				(word)b[508], (word)b[509],
				(word)b[510], (word)b[511]);

			/* Put the card back the way the driver expects it. */
			hd_set_8bit(0);
			continue;
		}

		if( is_cmd(&cp,"SECRAW") )
		{
			dword	lba;
			word	n, sts;
			byte	*b = SecBuffer;

			if( !parse_val(&cp,&lba) ) {
				printf("usage: SECRAW <lba>\n");
				continue;
			}

			/* Before blaming the drive: can that byte of the
			   buffer even hold a value?  b[511] is A000:81FF,
			   and this board had an SRAM fault in exactly this
			   region earlier that cleared itself without a
			   repair.  A stuck cell there would make the last
			   byte of every sector read back as 00 no matter
			   what the drive sent. */
			b[508] = 0x11; b[509] = 0x22;
			b[510] = 0x33; b[511] = 0x44;
			printf("buffer writeback 508..511: %02X %02X %02X %02X"
			       "   (expect 11 22 33 44)\n",
				(word)b[508], (word)b[509],
				(word)b[510], (word)b[511]);

			hd_set_8bit(0);

			/* Issue READ SECTORS by hand and then count how many
			   bytes the drive actually hands over before it drops
			   DRQ.  That separates "the transfer loop is short" from
			   "the drive stops supplying data", which reading the
			   sector through the driver cannot. */
			io_write(0x1F6,(word)(0xE0 | (word)((lba>>24) & 0x0FUL)),0);
			io_write(0x1F2,1,0);
			io_write(0x1F3,(word)(lba & 0xFFUL),0);
			io_write(0x1F4,(word)((lba>>8) & 0xFFUL),0);
			io_write(0x1F5,(word)((lba>>16) & 0xFFUL),0);
			io_write(0x1F7,0x20,0);		/* READ SECTORS */

			sts = 0;
			for( n = 0; n < 30000; n++ ) {
				sts = io_read(0x1F7,0);
				if( sts & 0x01 ) break;		/* ERR */
				if( (sts & 0x88) == 0x08 ) break;	/* DRQ, !BSY */
			}
			printf("status at DRQ %02X\n", sts);

			for( n = 0; n < 600; n++ ) {
				sts = io_read(0x1F7,0);
				if( !(sts & 0x08) )		/* DRQ dropped */
					break;
				b[ (n < 512) ? n : 511 ] = (byte)io_read(0x1F0,0);
			}

			printf("drive supplied %u bytes, final status %02X\n",
				n, sts);
			printf("bytes 508..511: %02X %02X %02X %02X\n",
				(word)b[508], (word)b[509],
				(word)b[510], (word)b[511]);

			/* The drive still owes one byte.  Ask for it anyway:
			   if it comes back AA the data is there and only the
			   DRQ handshake is early -- which is what a latching
			   8-bit adapter looks like.  If it comes back 00 or FF
			   the byte is genuinely not obtainable. */
			printf("one more read after DRQ dropped: %02X"
			       "   (status now %02X)\n",
				io_read(0x1F0,0), io_read(0x1F7,0));

			/* CF True IDE mode has a duplicate-even-data register
			   at offset 8.  If this card parks the final byte
			   there for 8-bit hosts, that is where it will be. */
			printf("dup data 1F8: %02X   1F9: %02X   err 1F1: %02X\n",
				io_read(0x1F8,0), io_read(0x1F9,0),
				io_read(0x1F1,0));

			/* And the same sector again with no DRQ gating at all,
			   512 straight reads -- exactly what read_data does --
			   so the two can be compared directly. */
			io_write(0x1F6,(word)(0xE0 | (word)((lba>>24) & 0x0FUL)),0);
			io_write(0x1F2,1,0);
			io_write(0x1F3,(word)(lba & 0xFFUL),0);
			io_write(0x1F4,(word)((lba>>8) & 0xFFUL),0);
			io_write(0x1F5,(word)((lba>>16) & 0xFFUL),0);
			io_write(0x1F7,0x20,0);

			for( n = 0; n < 30000; n++ ) {
				sts = io_read(0x1F7,0);
				if( sts & 0x01 ) break;
				if( (sts & 0x88) == 0x08 ) break;
			}
			for( n = 0; n < 512; n++ )
				b[n] = (byte)io_read(0x1F0,0);

			printf("ungated first bytes 0..3: %02X %02X %02X %02X\n",
				(word)b[0], (word)b[1], (word)b[2], (word)b[3]);
			printf("ungated 512 reads, 508..511: %02X %02X %02X %02X"
			       "   (status now %02X)\n",
				(word)b[508], (word)b[509],
				(word)b[510], (word)b[511],
				io_read(0x1F7,0));
			continue;
		}

		if( is_cmd(&cp,"BOOTCHK") )
		{
			word	rst_ax, rst_fl, rd_ax, rd_fl;
			byte	sig[4];
			byte	sts;

			pm_read(0x00000104UL,sig,4);	/* the INT 41h vector */
			printf("hd_number=%u  disk_tab[0]=%02X  INT41h=%02X%02X:%02X%02X\n",
				(word)bda.hd_number, (word)bda.disk_tab[0],
				(word)sig[3], (word)sig[2],
				(word)sig[1], (word)sig[0]);

			/* Exactly the sequence INT 19h uses, one step at a
			   time, so it is visible which one fails. */
			ASM {
				push	es
				mov	ah,0
				mov	dl,0x80
				int	0x13
				pushf
				pop	bx
				mov	[rst_ax],ax
				mov	[rst_fl],bx
				pop	es
			}
			printf("AH=00 reset  AX=%04X  %s\n",
				rst_ax, (rst_fl & 1) ? "CARRY" : "ok");

			ASM {
				push	es
				mov	ax,0x0201
				mov	cx,0x0001
				mov	dh,0
				mov	dl,0x80
				xor	bx,bx
				mov	es,bx
				mov	bx,0x7C00
				int	0x13
				pushf
				pop	bx
				mov	[rd_ax],ax
				mov	[rd_fl],bx
				pop	es
			}
			printf("AH=02 read   AX=%04X  %s\n",
				rd_ax, (rd_fl & 1) ? "CARRY" : "ok");

			ASM {
				push	es
				mov	ah,1
				mov	dl,0x80
				int	0x13
				mov	[sts],ah
				pop	es
			}
			printf("AH=01 status AH=%02X   bda.hd_status=%02X\n",
				(word)sts, (word)bda.hd_status);

			/* what actually landed at 0000:7C00 */
			pm_read(0x00007C00UL, sig, 2);
			pm_read(0x00007DFEUL, &sig[2], 2);
			printf("0000:7C00 = %02X %02X ...  7DFE = %02X %02X\n",
				(word)sig[0], (word)sig[1],
				(word)sig[2], (word)sig[3]);
			continue;
		}

		if( is_cmd(&cp,"BOOT") )
		{
			/* INT 19h replaces the stack and does not come back. */
			printf("INT 19h -- the monitor does not get control back\n");
			ASM {
				int	0x19
			}
			continue;
		}

		if( is_cmd(&cp,"HDINIT") )
		{
			T_DISKTAB	tabs[2];
			int		n;

			printf("resetting the IDE interface ...\n");
			n = hdinit(tabs,2);
			hd_report(tabs,n);
			continue;
		}

		if( is_cmd(&cp,"IDENT") )
		{
			dword	v;
			int	drive = 0;

			if( parse_val(&cp,&v) ) {
				if( v > 1UL ) {
					printf("usage: IDENT [drive]   0 = master, 1 = slave\n");
					continue;
				}
				drive = (int)v;
			}
			DumpIdentify(drive);
			continue;
		}

		if( is_cmd(&cp,"LBA") )
		{
			dword	lba, v;
			int	drive = 0;

			if( !parse_val(&cp,&lba) ) {
				printf("usage: LBA <sector> [drive]"
				       "   0 = master, 1 = slave\n");
				continue;
			}
			if( lba > 0x0FFFFFFFUL ) {
				printf("LBA: 28-bit addressing only, max FFFFFFF\n");
				continue;
			}
			if( parse_val(&cp,&v) ) {
				if( v > 1UL ) {
					printf("LBA: drive is 0 or 1\n");
					continue;
				}
				drive = (int)v;
			}
			DumpSector(lba,drive);
			continue;
		}

		/* IOR reads bytes, IORW reads words. */
		if( is_cmd(&cp,"IORW") )	wide = 1;
		else if( is_cmd(&cp,"IOR") )	wide = 0;
		else				wide = -1;

		if( wide >= 0 )
		{
			dword	v;
			word	port, count;

			if( !parse_val(&cp,&v) || v > 0xFFFFUL ) {
				printf("usage: IOR <port> [count]    byte ports\n"
				       "       IORW <port> [count]   word ports\n");
				continue;
			}
			port = (word)v;

			count = 1;
			if( parse_val(&cp,&v) ) {
				if( v == 0 || v > MAX_IO_COUNT ) {
					printf("IOR: count is 1..%X\n", MAX_IO_COUNT);
					continue;
				}
				count = (word)v;
			}

			io_dump(port,count,wide);
			continue;
		}

		/* IOW writes a byte, IOWW writes a word. */
		if( is_cmd(&cp,"IOWW") )	wide = 1;
		else if( is_cmd(&cp,"IOW") )	wide = 0;
		else				wide = -1;

		if( wide >= 0 )
		{
			dword	v;
			word	port, val;

			if( !parse_val(&cp,&v) || v > 0xFFFFUL ) {
				printf("usage: IOW <port> <byte>    byte ports\n"
				       "       IOWW <port> <word>   word ports\n");
				continue;
			}
			port = (word)v;

			if( !parse_val(&cp,&v) ) {
				printf("IOW: a value is required\n");
				continue;
			}
			if( v > (wide ? 0xFFFFUL : 0xFFUL) ) {
				printf("IOW: value is %s\n",
					wide ? "0000..FFFF" : "00..FF");
				continue;
			}
			val = (word)v;

			io_write(port,val,wide);

			if( wide )	printf("%04X <- %04X\n", port, val);
			else		printf("%04X <- %02X\n", port, val);
			continue;
		}

		if( is_cmd(&cp,"GO") )
		{
			word	seg, off, cur_ds;
			T_REGS	regs;
			int	r;

			r = parse_far(&cp,&seg,&off);
			if( r < 0 ) {
				printf("GO: Real Mode cannot reach above 1Mb"
				       " -- give the address as seg:off\n");
				continue;
			}
			if( r == 0 ) {
				printf("usage: GO <addr> [AX [BX [CX [DX]]]]\n"
				       "       addr is F000:E000 or a flat FE000\n"
				       "       the target must return with a far RET\n");
				continue;
			}

			/* DS and ES default to the monitor's own DS so that a
			   called BIOS routine sees the addressing it expects.
			   SI and DI start clear. */
			ASM {
				mov	ax,ds
				mov	[cur_ds],ax
			}
			regs.ax = regs.bx = regs.cx = regs.dx = 0;
			regs.si = regs.di = 0;
			regs.ds = regs.es = cur_ds;
			regs.flags = 0;

			parse_word(&cp,&regs.ax);
			parse_word(&cp,&regs.bx);
			parse_word(&cp,&regs.cx);
			parse_word(&cp,&regs.dx);

			printf("call %04X:%04X  "
			       "AX=%04X BX=%04X CX=%04X DX=%04X DS=%04X\n",
				seg, off,
				regs.ax, regs.bx, regs.cx, regs.dx, regs.ds);

			go_call(seg,off,&regs);

			printf("back AX=%04X BX=%04X CX=%04X DX=%04X"
			       " SI=%04X DI=%04X\n",
				regs.ax, regs.bx, regs.cx, regs.dx,
				regs.si, regs.di);
			printf("     DS=%04X ES=%04X FL=%04X  %s %s\n",
				regs.ds, regs.es, regs.flags,
				(regs.flags & 0x0001) ? "CY" : "NC",
				(regs.flags & 0x0040) ? "ZR" : "NZ");
			continue;
		}

		if( is_cmd(&cp,"EXIT") )
		{
			printf("Quit Monitor\n");
			_cont=0;
			break;
		}

		printf("**ERR\n");

	} while (_cont==1);

}
