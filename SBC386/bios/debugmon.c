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
#include "i386ex.h"		/* the watchdog and power-control registers */
#include "debugmon.h"
#include "hdinit.h"

int  vga3_init( void );		/* vga3.asm */

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
/* Counter 1, latched and read low-then-high, exactly as t1_read in
   "15h_misc.asm" does it.  Counts down at 1mhz. */
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
 * The ECB VGA3 board, reached through its I/O block only.
 *
 * P3 selects A7..A3 of an eight-port block, and the ECB rule this board
 * has used throughout puts Z80 port N at 386EX port 400h + N.  Jumpered
 * to E0h, as it is, the block is 4E0h..4E7h -- inside the 0400..04FF
 * window CS0 already decodes at seven wait states, so nothing has to be
 * reconfigured to talk to it.  The manual's own SBC-188 example puts CFG
 * at $4E4, which is the same arithmetic.
 *
 * The board offers two ways to its 32K: memory mapping, and these address
 * registers.  The registers are used here because they cannot conflict
 * with anything.  Memory mapping would land on CS3 at 000B_0000, which
 * CS2 also claims -- CS2 covers the whole first megabyte and HALF_MEM
 * cannot exclude it while SHADOW_MODE needs the DRAM under F0000.  That
 * is a chip-select problem to solve later and on purpose, not one to
 * stumble into while finding out whether the board works at all.
 */
#define V3_PORT		0x4E0		/* P3 jumpered to E0h */

#define V3_KBD_DATA	(V3_PORT+0)	/* 8242, A0 low  */
#define V3_KBD_CMD	(V3_PORT+1)	/* 8242, A0 high */
#define V3_CRTC_ADR	(V3_PORT+2)	/* HD6445 address register */
#define V3_CRTC_DAT	(V3_PORT+3)	/* HD6445 data register    */
#define V3_CFG		(V3_PORT+4)	/* write only */
#define V3_ADR_HI	(V3_PORT+5)	/* write only */
#define V3_ADR_LO	(V3_PORT+6)	/* write only */
#define V3_DATA		(V3_PORT+7)	/* read/write */

#define V3_SIZE		0x8000		/* one 32K x 8 SRAM */

/*
 * Both address bytes are written before every access.
 *
 * Whether the address register post-increments is not documented and has
 * not been established.  Re-seeking is correct either way and costs two
 * I/O cycles; assuming it increments would be correct only if it does.
 * When something later wants the speed, prove the behaviour first and
 * write a second accessor -- do not quietly stop seeking here.
 */
static void v3_seek( word addr )
{
	io_write(V3_ADR_HI,(word)((addr >> 8) & 0xFF),0);
	io_write(V3_ADR_LO,(word)(addr & 0xFF),0);
}

static byte v3_get( word addr )
{
	v3_seek(addr);
	return( (byte)io_read(V3_DATA,0) );
}

static void v3_put( word addr, byte v )
{
	v3_seek(addr);
	io_write(V3_DATA,v,0);
}

/* Depends on all fifteen address bits, so a dead or undecoded address
   line shows up as a mismatch rather than as a pattern that happens to
   agree with its own alias. */
static byte v3_pat( word addr )
{
	return( (byte)(((addr >> 8) ^ addr ^ 0x5A) & 0xFF) );
}

/*
 * The 8242 keyboard controller: an 8042 with the PC/AT firmware in it,
 * so this is the port 60h/64h protocol at 4E0h/4E1h.
 *
 * Status is read at +1.  Bit 0 (OBF) says a byte is waiting at +0; bit 1
 * (IBF) says the last byte written has not been taken yet, and nothing
 * may be written until it clears.  Every wait here is bounded by the
 * 18.2hz tick, because a controller that is not there reads FF -- both
 * bits set -- and a loop that trusted it would never end.
 */
#define K8_OBF		0x01
#define K8_IBF		0x02

#define K8_SELFTEST	0xAA		/* replies 55 */
#define K8_IFTEST	0xAB		/* replies 00, or 1-4 naming a stuck line */
#define K8_RDCMD	0x20		/* read the command byte */
#define K8_WRCMD	0x60
#define K8_ENABLE	0xAE		/* keyboard interface on */

#define KB_RESET	0xFF		/* to the keyboard: replies FA, then AA */
#define KB_ACK		0xFA
#define KB_BAT_OK	0xAA

static int v3_kbd_get( byte *v, word ticks )
{
	word	start = bda.timer_count_low;

	do {
		if( io_read(V3_KBD_CMD,0) & K8_OBF ) {
			*v = (byte)io_read(V3_KBD_DATA,0);
			return( 1 );
		}
	} while( (word)(bda.timer_count_low - start) < ticks );
	return( 0 );
}

/* To the controller through +1, or to the keyboard through +0. */
static int v3_kbd_put( word port, byte v )
{
	word	start = bda.timer_count_low;

	do {
		if( !(io_read(V3_KBD_CMD,0) & K8_IBF) ) {
			io_write(port,v,0);
			return( 1 );
		}
	} while( (word)(bda.timer_count_low - start) < 9 );
	return( 0 );
}

/* Controller command that answers with one byte. */
static int v3_kbd_ask( byte cmd, byte *reply )
{
	if( !v3_kbd_put(V3_KBD_CMD,cmd) )	return( 0 );
	return( v3_kbd_get(reply,18) );
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
 * Command and result bytes to and from a 765.
 *
 * Every byte in either direction is gated by the main status register: RQM
 * says the controller is ready for one, DIO says which way it is willing to
 * move.  Waiting for the pair rather than counting cycles is what makes the
 * sequence independent of the clock.
 *
 * The deadline is the 18.2hz tick rather than a spin count, and that is not
 * a detail.  A spin count has to be guessed against a wait whose real length
 * is set by the media: READ ID gives up only after two index pulses, which
 * at 300 rpm is 400ms, and a loop of 30000 port reads at seven wait states
 * is nearer 75ms.  Counting iterations gave an answer that looked like a
 * wedged controller and was nothing of the sort.  Two seconds is longer than
 * any single 765 operation and short enough to stay a diagnostic.
 */
#define FDC_TIMEOUT	36		/* 18.2hz ticks -- about two seconds */

static int fdc_wait( word base, word want )
{
	word	t0 = bda.timer_count_low;
	word	msr;

	do {
		msr = io_read(base,0);

		/* EXEC is in the mask deliberately.  During a non-DMA
		   execution phase MSR reads F0, and F0 & C0 is C0 -- so a
		   result-phase read that only looked at RQM and DIO would
		   cheerfully pull sector data out of the data register and
		   report it as status.  That is exactly what happened: the
		   first "ST0 ST1 ST2" printed were EB 4D 53, the opening
		   bytes of a DOS boot sector. */
		if( (msr & 0xE0) == want )	return( 0 );
	} while( (word)(bda.timer_count_low - t0) < FDC_TIMEOUT );

	return( -1 );
}


static int fdc_put( word base, word val )
{
	if( fdc_wait(base,0x80) )	return( -1 );	/* wants a byte in */
	io_write((word)(base + 1),val,0);
	return( 0 );
}


static int fdc_get( word base, word *val )
{
	if( fdc_wait(base,0xC0) )	return( -1 );	/* has a byte out */
	*val = io_read((word)(base + 1),0);
	return( 0 );
}


/*
 * True if the operator has typed Ctrl-C.  A long dump at 9600 baud takes
 * a while, so Ctrl-C stops it.  Anything else typed is swallowed rather
 * than left in the buffer, where it would turn up at the next MON>
 * prompt.
 *
 * INT 16h function 01h reports whether a key is waiting without taking
 * it, so this never blocks.  It has to be INT 16h rather than the INT
 * 14h line status this used to read: the receive interrupt empties the
 * UART into the ring buffer as characters arrive, so the line status
 * shows nothing even when a key has been struck.
 */
static int abort_requested( void )
{
	word	waiting, key;

	waiting = 0;
	ASM {
		mov	ah,1		; is a key waiting?
		int	0x16
		jz	no_key
		mov	word ptr [waiting],1
	no_key:
	}

	if( !waiting )
		return( 0 );

	ASM {
		xor	ah,ah		; take it; cannot block, one is there
		int	0x16
		mov	[key],ax
	}

	return( (key & 0x7F) == ASCII_CTRLC );
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


/*
 * A test boot sector, hand assembled.  It prints through INT 14h and
 * stops, so it proves the INT 19h hand-off on its own -- no INT 10h, no
 * console, nothing from Phase 3 involved.
 *
 * Entered at 0000:7C00 with DL = 80h.  The listing below is the whole
 * of it, so the bytes can be checked by eye:
 *
 *   0000  FA           cli
 *   0001  31 C0        xor  ax,ax
 *   0003  8E D0        mov  ss,ax          ; our own stack, as an MBR does
 *   0005  BC 00 7C     mov  sp,7C00
 *   0008  8E D8        mov  ds,ax
 *   000A  8E C0        mov  es,ax
 *   000C  FB           sti
 *   000D  FC           cld
 *   000E  BE 21 7C     mov  si,7C21        ; the message, just past the code
 *   0011  AC       .1: lodsb
 *   0012  08 C0        or   al,al
 *   0014  74 08        jz   .2             ; -> 001E
 *   0016  B4 01        mov  ah,1           ; write character
 *   0018  31 D2        xor  dx,dx          ; COM1
 *   001A  CD 14        int  14h
 *   001C  EB F3        jmp  .1             ; -> 0011
 *   001E  F4       .2: hlt
 *   001F  EB FD        jmp  .2             ; -> 001E
 *   0021           msg: the text, NUL terminated
 */
static const byte bootcode[] = {
	0xFA,
	0x31, 0xC0,
	0x8E, 0xD0,
	0xBC, 0x00, 0x7C,
	0x8E, 0xD8,
	0x8E, 0xC0,
	0xFB,
	0xFC,
	0xBE, 0x21, 0x7C,
	0xAC,
	0x08, 0xC0,
	0x74, 0x08,
	0xB4, 0x01,
	0x31, 0xD2,
	0xCD, 0x14,
	0xEB, 0xF3,
	0xF4,
	0xEB, 0xFD,
	/* 0021: the message */
	0x0D, 0x0A,
	'*','*','*',' ','T','E','S','T',' ','B','O','O','T',' ',
	'S','E','C','T','O','R',' ','R','U','N','N','I','N','G',' ','*','*','*',
	0x0D, 0x0A,
	'I','N','T',' ','1','9','h',' ','h','a','n','d','e','d',' ',
	'o','v','e','r',' ','c','o','r','r','e','c','t','l','y','.',
	0x0D, 0x0A,
	0x00
};


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

/*
 * FILL -- write one byte value over a run of memory.
 *
 * Real mode, one byte at a time, so it lands on whatever the address
 * decodes to -- including the ECB memory window at B0000..BFFFF, which
 * is how the VGA3 in its memory-mapped mode gets its first writes.
 */
		if( is_cmd(&cp,"FILL") )
		{
			dword	a, n, v, inc;
			word	i;
			union {
				byte	far *p;
				struct { word off; word seg; } fp;
			} m;

			if( !parse_addr(&cp,&a) || !parse_val(&cp,&n) || !parse_val(&cp,&v)
			    || n == 0 || n > 0xFFF0UL ) {
				printf("usage: FILL <addr> <count> <byte> [<step>]   count to FFF0\n"
				       "       with a step, each byte is the last plus step\n");
				continue;
			}
			m.fp.seg = (word)(a >> 4);
			m.fp.off = (word)(a & 0x0F);
			if( !parse_val(&cp,&inc) )	inc = 0;
			for( i = 0; i < (word)n; i++, v += inc )
				m.p[i] = (byte)v;
			printf("FILL: %04X:%04X, %u bytes\n", m.fp.seg, m.fp.off, (word)n);
			continue;
		}

		if( is_cmd(&cp,"IRQFIND") )
		{
			word	base_m, base_s, new_m, new_s;
			word	start, oldier, lsr;

			/* Which ICU input does the SIO0 receive interrupt
			 * land on?
			 *
			 * The 386EX routes internal peripherals to the ICU
			 * through INTCFG, and nothing in this BIOS has ever
			 * used the SIO interrupt, so the mapping is not
			 * recorded anywhere.  Rather than guess it, ask the
			 * hardware: the ICU request registers show a pending
			 * request whether or not it is masked, so this is
			 * safe with every mask still closed.
			 *
			 * Sample first with the interrupt off to learn which
			 * bits are already busy -- IRQ0, the 18.2hz tick, is
			 * always among them -- then enable SIO0 receive and
			 * sample again while a key is typed and deliberately
			 * NOT read.  The bits that appear are SIO0.
			 */
			printf("sampling the ICU with SIO0 receive OFF ...\n");
			base_m = base_s = 0;
			start = bda.timer_count_low;
			do {
				io_write(0x20,0x0A,0);
				base_m |= io_read(0x20,0);
				io_write(0xA0,0x0A,0);
				base_s |= io_read(0xA0,0);
			} while( (word)(bda.timer_count_low - start) < 18 );

			oldier = io_read(0x3F9,0);
			io_write(0x3F9,0x01,0);	/* receive data available */

			printf("baseline master %02X slave %02X\n",
				base_m, base_s);
			printf("NOW TYPE ONE KEY -- it will not be read, so the\n"
			       "request stays asserted.  Five seconds ...\n");

			new_m = new_s = 0;
			start = bda.timer_count_low;
			do {
				io_write(0x20,0x0A,0);
				new_m |= io_read(0x20,0);
				io_write(0xA0,0x0A,0);
				new_s |= io_read(0xA0,0);
			} while( (word)(bda.timer_count_low - start) < 5*18 );

			lsr = io_read(0x3FD,0);

			io_write(0x3F9,oldier,0);	/* put IER0 back */
			if( lsr & 0x01 )
				io_read(0x3F8,0);	/* drain the character */

			printf("with RX on   master %02X slave %02X   LSR %02X\n",
				new_m, new_s, lsr);
			printf("new bits     master %02X slave %02X",
				(word)(new_m & ~base_m),
				(word)(new_s & ~base_s));
			printf("   <-- that is SIO0\n");
			continue;
		}

		if( is_cmd(&cp,"GEO") )
		{
			dword		v, h, s;
			T_DISKTAB	*dt = (T_DISKTAB *)(bda.rsvd_unused);

			/* Override the translated geometry in the live disk
			   table, without a rebuild.
			 *
			 * CHS on a translating BIOS is a convention, not a
			 * property of the card: any heads x sectors that
			 * divides the sector count is equally valid.  What
			 * matters is agreeing with whatever partitioned the
			 * media -- the CHS in the partition entry and the
			 * heads/sectors in the BPB were written by that
			 * machine, and the MBR reads the boot sector by CHS.
			 */
			if( !parse_val(&cp,&h) || !parse_val(&cp,&s)
			 || h < 1 || h > 255 || s < 1 || s > 63 ) {
				printf("usage: GEO <heads> <sectors>\n");
				printf("current %u/%u/%u  LBA %lu\n",
					dt->ncylinders, (word)dt->n__heads,
					(word)dt->nsectors, dt->max_lba);
				continue;
			}

			v = dt->max_lba / (h * s);
			if( v == 0 || v > 1024UL ) {
				printf("GEO: %lu/%lu/%lu needs %lu cylinders,"
				       " outside 1..1024\n", v, h, s, v);
				continue;
			}

			dt->n__heads   = (byte)h;
			dt->nsectors   = (byte)s;
			dt->ncylinders = (word)v;
			dt->control_bits = (byte)((h > 8) ? 0x08 : 0x00);

			printf("INT 13h geometry now %u/%u/%u"
			       "  (covers %lu of %lu sectors)\n",
				dt->ncylinders, (word)dt->n__heads,
				(word)dt->nsectors,
				v * h * s, dt->max_lba);
			continue;
		}

		if( is_cmd(&cp,"BDA") )
		{
			DumpBDA();
			continue;
		}

		if( is_cmd(&cp,"MKBOOT") )
		{
			dword	lba;
			word	i, bad;
			byte	*b = SecBuffer;

			/* *** THIS DESTROYS THE SECTOR IT IS GIVEN ***
			 *
			 * Lay down the test boot sector.  Written to LBA 0 it
			 * becomes what INT 19h loads, and it reports itself
			 * through INT 14h -- so if it speaks, the whole boot
			 * path is proven without anything from Phase 3 being
			 * involved.  If it stays silent the fault is in the
			 * hand-off, not in the console.
			 */
			if( !parse_val(&cp,&lba) ) {
				printf("usage: MKBOOT <lba>"
				       "   *** OVERWRITES that sector ***\n"
				       "       write it to 0 to make it"
				       " the boot sector\n");
				continue;
			}

			for( i = 0; i < SECTOR_SIZE; i++ )
				b[i] = 0;
			for( i = 0; i < sizeof(bootcode); i++ )
				b[i] = bootcode[i];
			b[510] = 0x55;
			b[511] = 0xAA;

			if( IDE_WRITE_SECTOR(0,b,lba,1) ) {
				printf("write of LBA %lu failed\n", lba);
				continue;
			}

			/* Read it back before trusting it.  A bad write here
			   would look exactly like a bad hand-off later. */
			for( i = 0; i < SECTOR_SIZE; i++ )
				b[i] = 0;
			if( IDE_READ_SECTOR(0,b,lba,1) ) {
				printf("read back of LBA %lu failed\n", lba);
				continue;
			}

			bad = 0;
			for( i = 0; i < sizeof(bootcode); i++ )
				if( b[i] != bootcode[i] )
					++bad;
			if( b[510] != 0x55 || b[511] != 0xAA )
				++bad;

			printf("test boot sector -> LBA %lu, %u bytes of code,"
			       " verify %s\n",
				lba, (word)sizeof(bootcode),
				bad ? "FAILED" : "ok");
			printf("first bytes %02X %02X %02X   signature %02X %02X\n",
				(word)b[0], (word)b[1], (word)b[2],
				(word)b[510], (word)b[511]);
			continue;
		}

/*
 * SECCMP -- rung 3 of the bring-up ladder.
 *
 * Read N sectors in ONE driver call, then read the same N one at a time,
 * and compare.  Both go through IDE_READ_SECTOR, so what is under test is
 * the driver's own multi-sector loop -- the DRQ wait per sector and the
 * buffer advance that read_data leaves in BX -- and not the raw port
 * sequence SEC2 checks.
 *
 * This is the path fn42 and fn43 take.  The CHS calls sidestep it by
 * asking for one sector at a time, which is why a DOS that boots proves
 * nothing about it.
 *
 * The multi-sector buffer is at 1000:0000, the 64K mark.  POST finished
 * with that memory before SETUP was reachable, and the boot sector does
 * not land until 0000:7C00 much later.
 */
		if( is_cmd(&cp,"SECCMP") )
		{
			dword	lba;
			dword	nsec, v;
			word	i, j, bad;
			byte	*multi;
			byte	*one = SecBuffer;
			int	rc, drive = 0;
			byte	unit;
			union {
				byte	*p;
				struct { word off; word seg; } fp;
			} m;

			if( !parse_val(&cp,&lba) ) {
				printf("usage: SECCMP <lba> [<sectors>]"
				       " [<drive>]\n"
				       "       reads N in one command, then N"
				       " singly, and compares\n"
				       "       drive 0 = master (default),"
				       " 1 = slave\n"
				       "       every argument is HEX, like"
				       " everywhere else here\n");
				continue;
			}
			nsec = 8;
			parse_val(&cp,&nsec);

			if( nsec < 2 || nsec > 0x20 ) {
				printf("SECCMP: 2 to 20 sectors, and that"
				       " is hex -- 1 would not test"
				       " anything\n");
				continue;
			}

			if( parse_val(&cp,&v) ) {
				if( v > 1UL ) {
					printf("SECCMP: drive 0 = master,"
					       " 1 = slave\n");
					continue;
				}
				drive = (int)v;
			}
			unit = (byte)(drive ? 0x10 : 0x00);

			/* Name the drive on the way in, always.  This command
			   used to take no drive argument and silently read the
			   master, which is an easy thing to run against a
			   freshly installed slave and believe. */
			printf("SECCMP: %s, %lu sectors from LBA %lu\n",
				drive ? "slave" : "master", nsec, lba);

			m.fp.seg = 0x1000;
			m.fp.off = 0;
			multi = m.p;

			hd_set_8bit(drive);

			/* The whole run in one command. */
			rc = IDE_READ_SECTOR( unit, multi, lba, (byte)nsec );
			if( rc ) {
				printf("SECCMP: the %lu-sector read failed,"
				       " status %02X\n", nsec, (word)rc);
				continue;
			}

			/* The same sectors one at a time, each compared
			   against its slice of the block above. */
			bad = 0;
			for( i = 0; i < (word)nsec; i++ ) {

				rc = IDE_READ_SECTOR( unit, one, lba + i, 1 );
				if( rc ) {
					printf("SECCMP: single read of LBA %lu"
					       " failed, status %02X\n",
						lba + i, (word)rc);
					bad = 1;
					break;
				}

				for( j = 0; j < 512; j++ ) {
					if( multi[(dword)i * 512 + j] == one[j] )
						continue;

					printf("SECCMP: sector %u (LBA %lu)"
					       " differs at byte %u:"
					       " multi %02X, single %02X\n",
						i, lba + i, j,
						(word)multi[(dword)i*512 + j],
						(word)one[j]);
					bad = 1;
					break;
				}
				if( bad )	break;
			}

			if( !bad )
				printf("SECCMP: %s -- one command and %lu"
				       " singles agree byte for byte\n",
					drive ? "slave" : "master", nsec);

			/* A block count of zero has to come straight back.
			   ATA reads a sector count register of 0 as 256, and
			   before the guard in IDE_READ_SECTOR the loop ran
			   65536 times.  If this line is the last thing you
			   see, that guard is not doing its job. */
			printf("SECCMP: zero-count guard ... ");
			rc = IDE_READ_SECTOR( unit, one, lba, 0 );
			printf("returned %02X (want 00)\n", (word)rc);
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
			for( i = 0; i < 16; i++ )		/* keep the tail */
				pre[i] = b[SECTOR_SIZE-16+i];
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
			for( i = 0; i < 16; i++ )
				if( b[SECTOR_SIZE-16+i] != pre[i] )
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

/*
 * INT15 -- exercise the INT 15h calls DOS and its drivers make.
 *
 * These four are the Phase 4 work, and none of them can be reached from
 * the GO command: go_call() arrives with a FAR CALL, and every handler in
 * this BIOS returns with RETF 2 to throw away the flags word a real INT
 * pushed.  int15_call() in monitor.asm issues the interrupt instead.
 *
 * Each case checks the answer against something independent rather than
 * reporting what the handler said about itself.
 */
		if( is_cmd(&cp,"INT15") )
		{
			T_REGS	regs;
			word	fn, cur_ds;
			dword	usec, src, dst, nwords;
			dword	asked, measured;
			word	t0, t1, reps;
			byte	*tp;
			byte	gdt[6*8];
			byte	chk[16];
			union {
				byte	*p;
				struct { word off; word seg; } fp;
			} u;
			int	i;

			if( !parse_word(&cp,&fn) ) {
				printf("usage: INT15 86 [<usec>]\n"
				       "       INT15 87 <src> <dst> [<words>]\n"
				       "       INT15 88\n"
				       "       INT15 C0\n");
				continue;
			}

			ASM {
				mov	ax,ds
				mov	[cur_ds],ax
			}
			regs.ax = regs.bx = regs.cx = regs.dx = 0;
			regs.si = regs.di = 0;
			regs.ds = regs.es = cur_ds;
			regs.flags = 0;

			switch( fn ) {

/*
 * Function 86h.  The wait is timed against the 18.2hz tick, not against
 * the 1mhz counter the handler reads, so a counter that never moves cannot
 * certify its own delay.  One tick is 54.9ms, so the reading is coarse --
 * which is enough: what is being checked is that a sub-250ms request waits
 * roughly the right time instead of returning immediately, which is what
 * it did before Phase 4.
 */
			case 0x86:
				usec = 100000UL;
				parse_val(&cp,&usec);
				if( usec == 0 ) {
					printf("86h: give a microsecond"
					       " count\n");
					continue;
				}
				printf("86h: %s path\n",
					(usec < 262144UL)
					  ? "1mhz counter (the Phase 4 work)"
					  : "18.2hz tick (the old path)");

				/* The tick this is measured against is 54.9ms
				   wide, so one 100ms call is +/-55% -- enough
				   to show the counter is moving, nowhere near
				   enough to show it is moving at 1mhz.  Repeat
				   until at least a second has been asked for,
				   and the same +/-1 tick falls on the whole
				   run instead of on one call.

				   The monitor's own per-call overhead is in
				   the measured figure too.  At 100ms a call it
				   is noise; at 1ms a call it is not, which is
				   what the repetition count is capped for. */
				reps = 1;
				if( usec < 1000000UL )
					reps = (word)(1000000UL / usec) + 1;
				if( reps > 1000 )	reps = 1000;

				t0 = bda.timer_count_low;
				for( i = 0; i < (int)reps; i++ ) {
					regs.ax = 0x8600;
					regs.cx = (word)(usec >> 16);
					regs.dx = (word)(usec & 0xFFFFUL);
					int15_call(&regs);
					if( regs.flags & 1 )	break;
				}
				t1 = bda.timer_count_low;

				if( regs.flags & 1 ) {
					printf("86h: CY -- refused after"
					       " %d call(s)\n", i);
					break;
				}

				asked    = usec * (dword)reps;
				measured = (dword)(word)(t1 - t0) * 54925UL;

				printf("86h: %u x %lu usec = %lu usec asked\n",
					reps, usec, asked);
				printf("     %u ticks = %lu usec measured,"
				       " +/-54925 on the run\n",
					(word)(t1 - t0), measured);
				printf("     %lu%% of what was asked --"
				       " want about 100\n",
					asked ? (measured / (asked / 100UL))
					      : 0UL);
				break;

/*
 * Function 87h.  The six-entry descriptor table is built here, on the
 * stack, because the interface makes it the caller's job -- the BIOS has no
 * writable data of its own to build one in.  Only the source at 10h and the
 * destination at 18h are filled in; 08h, 20h and 28h are the handler's to
 * write, and leaving them zero is how that gets tested.
 *
 * The move is then checked rather than believed: sixteen bytes of each end
 * are read back through pm_read, which reaches above 1Mb where a Real Mode
 * compare cannot follow.
 */
			case 0x87:
				nwords = 256;
				if( !parse_val(&cp,&src) ||
				    !parse_val(&cp,&dst) ) {
					printf("usage: INT15 87 <src linear>"
					       " <dst linear> [<words>]\n"
					       "       linear addresses, so"
					       " 100000 is the 1Mb mark\n");
					continue;
				}
				parse_val(&cp,&nwords);

				if( nwords == 0 || nwords > 0x8000UL ) {
					printf("87h: 1 to 8000 words,"
					       " and that count is hex\n");
					continue;
				}

				for( i = 0; i < sizeof(gdt); i++ )
					gdt[i] = 0;

				/* 286 form: limit 15:0, base 23:0, access,
				   then the two bytes a 386 added. */
				tp = &gdt[0x10];		/* source */
				tp[0] = 0xFF;	tp[1] = 0xFF;	/* limit 64K */
				tp[2] = (byte)(src);
				tp[3] = (byte)(src >> 8);
				tp[4] = (byte)(src >> 16);
				tp[5] = 0x93;			/* data, r/w */
				tp[7] = (byte)(src >> 24);

				tp = &gdt[0x18];		/* destination */
				tp[0] = 0xFF;	tp[1] = 0xFF;
				tp[2] = (byte)(dst);
				tp[3] = (byte)(dst >> 8);
				tp[4] = (byte)(dst >> 16);
				tp[5] = 0x93;
				tp[7] = (byte)(dst >> 24);

				/* ES:SI has to be where the table really is,
				   which is the stack, not DGROUP. */
				u.p = &gdt[0];
				regs.ax = 0x8700;
				regs.cx = (word)nwords;
				regs.si = u.fp.off;
				regs.es = u.fp.seg;

				printf("87h: %lu words, %08lX -> %08lX,"
				       " GDT at %04X:%04X\n",
					nwords, src, dst, regs.es, regs.si);

				int15_call(&regs);

				printf("87h: AH=%02X  %s\n",
					(word)(regs.ax >> 8),
					(regs.flags & 1) ? "CY -- failed"
							 : "NC");
				if( regs.flags & 1 )	break;

				pm_read(src,chk,sizeof(chk));
				printf("     src %08lX: ", src);
				for( i = 0; i < sizeof(chk); i++ )
					printf("%02X ", (word)chk[i]);
				printf("\n");

				pm_read(dst,chk,sizeof(chk));
				printf("     dst %08lX: ", dst);
				for( i = 0; i < sizeof(chk); i++ )
					printf("%02X ", (word)chk[i]);
				printf("\n     the two lines must agree\n");
				break;

/*
 * Function 88h, checked against the BDA field it reports.  They have to
 * agree, and the megabyte figure has to match what POST printed.
 */
			case 0x88:
				regs.ax = 0x8800;
				int15_call(&regs);
				printf("88h: AX=%04X = %u Kb above 1Mb"
				       " (%u Mb);  BDA holds %u Kb  %s\n",
					regs.ax, regs.ax, regs.ax / 1024u,
					bda.extended_memory,
					(regs.flags & 1) ? "CY -- refused"
							 : "NC");
				break;

			case 0xC0:
				regs.ax = 0xC000;
				int15_call(&regs);
				if( regs.flags & 1 ) {
					printf("C0h: CY -- not supported\n");
					break;
				}
				u.fp.off = regs.bx;
				u.fp.seg = regs.es;
				tp = u.p;

				printf("C0h: table at %04X:%04X,"
				       " %u bytes follow\n",
					regs.es, regs.bx, *(word *)tp);
				printf("     model %02X  submodel %02X"
				       "  BIOS rev %02X\n",
					(word)tp[2], (word)tp[3], (word)tp[4]);
				printf("     features %02X %02X %02X %02X"
				       " %02X -- %s, %s\n",
					(word)tp[5], (word)tp[6], (word)tp[7],
					(word)tp[8], (word)tp[9],
					(tp[5] & 0x40) ? "2nd ICU"
						       : "no 2nd ICU",
					(tp[5] & 0x20) ? "RTC" : "no RTC");
				break;

			default:
				printf("INT15: 86, 87, 88 and C0 only\n");
				break;
			}
			continue;
		}

/*
 * WDT -- what the watchdog is actually set to.
 *
 * Phase 5 asks whether the bus-monitor watchdog can trip during long DOS
 * I/O.  That question cannot be answered by watching the board: in this
 * configuration a trip does not reset anything.  start.asm sets BUSMON in
 * WDTSTATUS and WDTRDY in PWRCON, which means the watchdog's job is to
 * supply READY to a bus cycle that has not finished in time -- so the
 * symptom of a trip is a cycle terminated early with whatever was on the
 * bus, not a reboot.  Silent bad data, in other words.
 *
 * What decides it is the timeout against the slowest legitimate access,
 * and this BIOS never writes WDTRLDH/WDTRLDL at all -- the reload value is
 * whatever reset left there.  So read it rather than assume it.
 *
 * The count is sampled repeatedly because in bus-monitor mode it reloads
 * on every bus cycle: pinned near the reload value means it is being fed
 * normally, and a low or moving value would be the interesting case.
 * The two halves are read separately and can tear; for this purpose that
 * does not matter.
 */
		if( is_cmd(&cp,"WDT") )
		{
			word	sts, pwr, i;
			word	hi[4], lo[4];
			dword	reload;
			word	mhz;

			sts = io_read(WDTSTATUS,0);
			pwr = io_read(PWRCON,0);

			reload  = (dword)io_read(WDTRLDH,1) << 16;
			reload |= (dword)io_read(WDTRLDL,1);

			for( i = 0; i < 4; i++ ) {
				hi[i] = io_read(WDTCNTH,1);
				lo[i] = io_read(WDTCNTL,1);
			}

			printf("WDT: WDTSTATUS %02X -- bus monitor %s\n",
				sts, (sts & 0x02) ? "ON" : "off");
			printf("     PWRCON    %02X -- WDTRDY %s,"
			       " HSREADY %s\n",
				pwr,
				(pwr & 0x08) ? "on" : "OFF",
				(pwr & 0x04) ? "on" : "off");
			printf("     reload %04X%04X = %lu counts"
			       "   (never written by this BIOS)\n",
				(word)(reload >> 16), (word)reload, reload);

			printf("     count ");
			for( i = 0; i < 4; i++ )
				printf(" %04X%04X", hi[i], lo[i]);
			printf("\n");

			/* Assumes the watchdog counts at the CPU clock.  If
			   the datasheet says it is prescaled, scale this by
			   hand -- the raw reload above is the fact, this line
			   is the convenience. */
			mhz = bda.CPU_freq / 1000u;
			if( mhz )
				printf("     at %u mhz that is about %lu usec"
				       " before READY is forced\n",
					mhz, reload / (dword)mhz);
			printf("     compare against the slowest real access:"
			       " CS0 and CS1 run 7 wait states\n");
			continue;
		}

/*
 * IOTIME -- how long a read of a given I/O port actually takes.
 *
 * The question this exists to answer: what happens to a bus cycle that no
 * chip select claims?  Only CS0 (0400-04FF), CS1 (01F0-01FF) and the 386EX
 * internal peripherals decode anything here.  If an unclaimed cycle runs to
 * the bus-monitor watchdog and is terminated by WDTRDY, it costs 209ms --
 * and any operating system that probes for absent hardware pays that per
 * probe.  That matters for a Unix far more than it does for DOS, which
 * probes almost nothing.
 *
 * The 18.2hz tick is the clock, deliberately: timer 1 wraps every 65.5ms
 * and could not measure a 209ms access without aliasing.  Coarse is fine --
 * the two possible answers are "under a millisecond" and "a fifth of a
 * second", and no amount of resolution is needed to tell those apart.
 *
 * Reads only.  Writing to an address at random is a different kind of
 * experiment.
 */
/*
 * VGA3 -- prove the video board is there, before anything depends on it.
 *
 * The first rung of the video phase, and deliberately the dullest: no
 * CRTC, no font, no configuration register, nothing that could put a
 * picture on a monitor.  Only "does the board decode where we think it
 * does, and does its memory hold what we write".
 *
 * Everything above this rung depends on the answer.  A CRTC that will
 * not program, a font that renders as noise and a screen that stays
 * blank are one symptom if the board is not answering at all, and three
 * different investigations if it is.  Phase 6 cost a week to learning
 * that the hard way with a floppy controller.
 *
 * Safe to run: CFG clears to zero at RESET, which blanks the video, so
 * nothing written here can reach a monitor.  It does overwrite the whole
 * 32K, which holds the font and the display memory both -- reload them
 * after running it.
 *
 *	VGA3			data path, then all 32K
 *	VGA3 <addr>		read one byte
 *	VGA3 <addr> <val>	write one byte and read it back
 */
/*
 * V3KBD -- the keyboard controller, rung by rung.
 *
 * The first four need no keyboard plugged in: they are the controller
 * proving it is an 8042 and that its connector wiring is sound.  Only
 * then is the keyboard itself asked to reset, and a silence there is
 * reported as a missing keyboard, not a fault.
 *
 * Status, self-test, interface test, command byte, keyboard reset.
 * Kept past the bring-up because a keyboard going quiet is a recurring
 * failure and this names the cause in five lines.  The scan-code and
 * interrupt-hunting modes went when the board stopped being new; they
 * are in the history if they are wanted again.
 */
		if( is_cmd(&cp,"V3KBD") )
		{
			byte	st, v, cmdb;
			word	i;

			/* The interface comes up disabled after a power cycle and
			   stays so until told otherwise. */
			v3_kbd_put(V3_KBD_CMD,K8_ENABLE);

			st = (byte)io_read(V3_KBD_CMD,0);
			printf("V3KBD: status %02X",(word)st);
			if( st == 0xFF ) {
				printf(" -- floating.  Nothing answers at %04X.\n",
					(word)V3_KBD_CMD);
				continue;
			}
			printf("  (OBF %u  IBF %u  SYS %u  INH %u)\n",
				(word)(st & 1), (word)(st >> 1 & 1),
				(word)(st >> 2 & 1), (word)(st >> 4 & 1));

			for( i = 0; i < 16 && (io_read(V3_KBD_CMD,0) & K8_OBF); i++ )
				printf("       flushed %02X\n",(word)io_read(V3_KBD_DATA,0));

			if( !v3_kbd_ask(K8_SELFTEST,&v) ) {
				printf("       self-test: no reply.  Not an 8042, or not running.\n");
				continue;
			}
			printf("       self-test %02X %s\n", (word)v,
				v == 0x55 ? "-- an 8042-class controller is there" : "-- WRONG, expected 55");
			if( v != 0x55 )	continue;

			if( v3_kbd_ask(K8_IFTEST,&v) )
				printf("       interface test %02X %s\n", (word)v,
					v == 0 ? "-- clock and data lines good" :
					v == 1 ? "-- CLOCK STUCK LOW" :
					v == 2 ? "-- CLOCK STUCK HIGH" :
					v == 3 ? "-- DATA STUCK LOW" :
					v == 4 ? "-- DATA STUCK HIGH" : "-- unknown");
			else
				printf("       interface test: no reply\n");

			if( v3_kbd_ask(K8_RDCMD,&cmdb) )
				printf("       command byte %02X: kbd IRQ %s, translate %s, kbd %s\n",
					(word)cmdb,
					cmdb & 0x01 ? "on" : "off",
					cmdb & 0x40 ? "ON (set 1 delivered)" : "off (set 2 raw)",
					cmdb & 0x10 ? "DISABLED" : "enabled");

			/* Self-test leaves the interface disabled on many parts;
			   turn it on before speaking to the keyboard. */
			v3_kbd_put(V3_KBD_CMD,K8_ENABLE);

			if( !v3_kbd_put(V3_KBD_DATA,KB_RESET) || !v3_kbd_get(&v,18) ) {
				printf("       keyboard reset: no reply.  No keyboard plugged in,\n"
				       "       or it is not getting power.  The controller is fine.\n");
				continue;
			}
			printf("       keyboard reset: %02X",(word)v);
			if( v == KB_ACK && v3_kbd_get(&v,36) )
				printf(" %02X",(word)v);
			printf(v == KB_BAT_OK ? " -- keyboard passed its self-test\n"
						: " -- expected FA then AA\n");
			continue;
		}

		if( is_cmd(&cp,"VGA3") )
		{
			dword	v;
			word	addr, i, bad, first;
			byte	got, got2, want;

			if( parse_val(&cp,&v) ) {
				addr = (word)(v & (V3_SIZE - 1));
				if( parse_val(&cp,&v) ) {
					v3_put(addr,(byte)v);
					printf("VGA3: %04X <- %02X, reads %02X\n",
						addr, (word)(v & 0xFF),
						(word)v3_get(addr));
				} else
					printf("VGA3: %04X = %02X\n",
						addr, (word)v3_get(addr));
				continue;
			}

			printf("VGA3: I/O %04X..%04X  "
			       "(kbd %04X/%04X  crtc %04X/%04X  cfg %04X)\n",
				(word)V3_PORT, (word)(V3_PORT+7),
				(word)V3_KBD_DATA, (word)V3_KBD_CMD,
				(word)V3_CRTC_ADR, (word)V3_CRTC_DAT,
				(word)V3_CFG);

			/* Two patterns at one address.  One proves nothing: a
			   floating bus reading FF agrees with a write of FF,
			   and a data line stuck high agrees with any pattern
			   that happens to have it set. */
			v3_put(0,0x55);
			got = v3_get(0);
			v3_put(0,0xAA);
			got2 = v3_get(0);

			printf("      data path at 0000: wrote 55 read %02X,  wrote AA read %02X\n",
				(word)got, (word)got2);

			if( got != 0x55 || got2 != 0xAA ) {
				printf("      Nothing is holding data.  Check P3 is jumpered E0h, and\n"
				       "      that the board is seated -- an undecoded read gives FF\n"
				       "      here and costs 209ms a time, so a wrong block is slow\n"
				       "      as well as wrong.\n");
				continue;
			}

			printf("      writing all %u bytes ...\n", (word)V3_SIZE);
			for( i = 0; i < V3_SIZE; i++ )
				v3_put(i,v3_pat(i));

			bad = 0;
			first = 0;
			for( i = 0; i < V3_SIZE; i++ ) {
				got  = v3_get(i);
				want = v3_pat(i);
				if( got == want )	continue;
				if( bad < 4 )
					printf("      %04X: want %02X got %02X\n",
						i, (word)want, (word)got);
				if( !bad )	first = i;
				bad++;
			}

			if( !bad ) {
				printf("      all %u bytes verified.  The board is there and its\n"
				       "      address path is sound.\n",
					(word)V3_SIZE);
			} else {
				printf("      %u byte(s) wrong, first at %04X.\n",
					bad, first);
				printf("      Wrong everywhere is a data path fault; wrong in blocks\n"
				       "      that repeat is an address line, and the repeat interval\n"
				       "      names which one.\n");
			}
			vga3_init();	/* the march overwrote the font and the screen */
			continue;
		}

		if( is_cmd(&cp,"IOTIME") )
		{
			word	port, reps, i, t0, t1, ticks;
			dword	us_each;

			if( !parse_word(&cp,&port) ) {
				printf("usage: IOTIME <port> [<reads>]\n"
				       "       hex, as everywhere here;"
				       " default 8 reads\n"
				       "       try a decoded port (1F7, F834)"
				       " against an undecoded one (64, 300)\n");
				continue;
			}
			reps = 8;
			parse_word(&cp,&reps);
			if( reps == 0 )		reps = 8;

			printf("IOTIME: %u read(s) of port %04X ...\n",
				reps, port);

			t0 = bda.timer_count_low;
			for( i = 0; i < reps; i++ )
				(void)io_read(port,0);
			t1 = bda.timer_count_low;

			ticks = (word)(t1 - t0);

			if( ticks == 0 ) {
				printf("IOTIME: under one tick for all %u --"
				       " faster than %lu usec each.\n",
					reps, 54925UL / (dword)reps);
				printf("        That port answers. The"
				       " watchdog is not involved.\n");
				continue;
			}

			us_each = ((dword)ticks * 54925UL) / (dword)reps;
			printf("IOTIME: %u tick(s) for %u reads"
			       " = about %lu usec each\n",
				ticks, reps, us_each);

			/* Do not name a cause from a threshold.  The 209ms this
			   used to test against came from assuming the watchdog
			   counts at the CPU clock, and measurement says otherwise:
			   an undecoded read costs about 55ms, which is this same
			   reload at roughly four times that rate.  A verdict built
			   on the wrong constant reported "not the watchdog" about a
			   number that fits the watchdog perfectly well.

			   WDTSET tried to settle it by shortening the reload and
			   found the timeout fixed; the command is gone.  Nothing
			   else on this board terminates an unclaimed cycle. */
			printf("        %lu usec a read BY THE TICK -- which undercounts.\n",
				us_each);
			printf("        A stall long enough to measure is long enough to lose\n"
			       "        IRQ0s: the 8259 latches one and drops the rest, so this\n"
			       "        counts reads, not time; the RTC gives the real figure.\n");
			continue;
		}

/*
 * INT13 -- the BIOS disk interface, as opposed to the driver under it.
 *
 * SECCMP proves the driver.  This proves the layer above it: get_disk_table
 * finding the right T_DISKTAB for the drive code, cv_lba turning CHS into
 * an LBA, and the dispatch through bda.disk_tab[] reaching the right unit.
 * For the master all of that is exercised every time DOS boots.  For the
 * slave nothing exercises it at all, and nothing will until there is a
 * filesystem on that card.
 *
 * The read is deliberately NOT at cylinder 0, head 0, sector 1.  That is
 * LBA 0 whatever cv_lba does with it, so it would pass with the conversion
 * completely broken.  A cylinder, head and sector are picked away from the
 * origin instead, the LBA computed here from the geometry AH=08h reported,
 * and the two reads compared.  Agreeing means the BIOS and this command
 * worked out the same address by different routes.
 */
		if( is_cmd(&cp,"INT13") )
		{
			T_REGS	regs;
			dword	v, lba;
			int	drive = 0, rc;
			byte	unit;
			word	cur_ds, i, bad;
			word	maxcyl, maxhead, spt, ndrv;
			word	cyl, head, sec;
			byte	*b13;
			byte	*bdrv = SecBuffer;
			union {
				byte	*p;
				struct { word off; word seg; } fp;
			} m;

			if( parse_val(&cp,&v) ) {
				if( v > 1UL ) {
					printf("usage: INT13 [drive]"
					       "   0 = master, 1 = slave\n");
					continue;
				}
				drive = (int)v;
			}
			unit = (byte)(drive ? 0x10 : 0x00);

			m.fp.seg = 0x1000;	/* scratch, as SECCMP uses */
			m.fp.off = 0;
			b13 = m.p;

			ASM {
				mov	ax,ds
				mov	[cur_ds],ax
			}

			hd_set_8bit(drive);

/* ---- AH=08h, get drive parameters ---------------------------------- */
			regs.ax = 0x0800;
			regs.bx = regs.cx = 0;
			regs.dx = (word)(0x0080 | drive);
			regs.si = regs.di = 0;
			regs.ds = regs.es = cur_ds;
			regs.flags = 0;

			int13_call(&regs);

			if( regs.flags & 1 ) {
				printf("INT13: drive %02X AH=08h failed,"
				       " AH=%02X\n",
					0x80 | drive, (word)(regs.ax >> 8));
				continue;
			}

			/* CH is the low 8 bits of the maximum cylinder, CL
			   carries the top two in bits 7:6 and the sectors per
			   track in bits 5:0. */
			maxcyl  = (word)(((regs.cx & 0x00C0) << 2)
					| ((regs.cx >> 8) & 0x00FF));
			spt     = (word)(regs.cx & 0x003F);
			maxhead = (word)((regs.dx >> 8) & 0x00FF);
			ndrv    = (word)(regs.dx & 0x00FF);

			printf("INT13: drive %02X -- %u cyl, %u head,"
			       " %u sec/trk;  %u drive(s) present\n",
				0x80 | drive, maxcyl + 1, maxhead + 1,
				spt, ndrv);

			if( spt == 0 ) {
				printf("INT13: zero sectors per track --"
				       " that geometry is unusable\n");
				continue;
			}

/* ---- AH=02h at a CHS away from the origin --------------------------- */
			cyl  = 1;
			head = (word)(maxhead >= 2 ? 2 : 0);
			sec  = (word)(spt >= 3 ? 3 : 1);

			lba = ((dword)cyl * (dword)(maxhead + 1)
					+ (dword)head) * (dword)spt
				+ (dword)(sec - 1);

			printf("       reading C%u H%u S%u, which is LBA %lu\n",
				cyl, head, sec, lba);

			regs.ax = 0x0201;		/* read one sector */
			regs.cx = (word)(((cyl & 0x00FF) << 8)
					| ((cyl >> 2) & 0x00C0)
					| (sec & 0x003F));
			regs.dx = (word)((head << 8) | (0x0080 | drive));
			regs.bx = m.fp.off;
			regs.es = m.fp.seg;
			regs.ds = cur_ds;
			regs.si = regs.di = 0;
			regs.flags = 0;

			int13_call(&regs);

			if( regs.flags & 1 ) {
				printf("INT13: AH=02h failed, AH=%02X\n",
					(word)(regs.ax >> 8));
				continue;
			}

/* ---- the same sector, straight from the driver ---------------------- */
			rc = IDE_READ_SECTOR( unit, bdrv, lba, 1 );
			if( rc ) {
				printf("INT13: the driver could not read LBA"
				       " %lu, status %02X\n", lba, (word)rc);
				continue;
			}

			bad = 0;
			for( i = 0; i < 512; i++ ) {
				if( b13[i] == bdrv[i] )		continue;
				printf("INT13: differs at byte %u --"
				       " INT 13h %02X, driver %02X\n",
					i, (word)b13[i], (word)bdrv[i]);
				bad = 1;
				break;
			}

			if( !bad )
				printf("INT13: %s -- INT 13h C%u H%u S%u and"
				       " the driver at LBA %lu agree\n",
					drive ? "slave" : "master",
					cyl, head, sec, lba);
			continue;
		}

/*
 * FDC -- is the floppy controller there, is it out of reset, does it answer?
 *
 * The ECB Disk I/O V3 carries an SMC FDC9266, uPD765/8272-compatible, with
 * an integrated data separator and no DMA.  Z80 I/O port N reaches the
 * 386EX at 0x400 + N (see 0README.TXT), so a card jumpered to 30h-3Fh is at
 * 0x430-0x43F here.
 *
 * The main status register is the tell.  An idle 765 reads 80h -- RQM set,
 * DIO clear, not busy.  A bus with nothing driving it floats to FF.  A part
 * held in reset reads 00.  Three states, none of them confusable, which is
 * what makes this worth doing before any driver exists.  All four aliases
 * are read because the board decodes 30h/32h/34h/36h to the same register
 * and only the jumpering says which is meant.
 *
 * Expect 00 on a cold machine.  The latch at 38h is a 74LS273, which clears
 * to zero at power-on, and bit 7 of it is ~FDC_RST -- so the board holds the
 * controller in reset until software says otherwise.
 *
 * Reset is PULSED here, not merely released: 00 to the latch and then 80.
 * Writing 80 on its own only resets the part if bit 7 happened to be low
 * beforehand, which is true exactly once in the life of a power-on.  A
 * controller left wedged mid-command -- and one will be, the first time a
 * driver gets a command sequence wrong -- needs a real falling edge, and
 * this is the only thing on the board that can produce one.
 *
 * Which also means a console reset does not clear it: Ctrl-^ jumps to the
 * reset vector rather than asserting the system reset line, so an ECB card
 * keeps whatever state it was in.
 *
 * MINI, bit 2, is the data rate: FDC_CLK is a fixed 8mhz oscillator and the
 * MINI pin is what halves it, so this is the 500 kbps setting.  Nothing is
 * transferred here, so it does not matter yet.  DENSEL is not a rate
 * control -- it goes out to the drive's density pin through JP6.
 *
 * That latch is WRITE ONLY.  Reading 38h returns the digital input
 * register, not what was last written, so every write has to supply all
 * eight bits at once.  A driver will need a shadow byte to do that;
 * bda.motor_status is the place for it, being the BDA byte a PC uses for
 * the same job.
 *
 * After a reset a 765 raises an interrupt and answers SENSE INTERRUPT
 * STATUS with ST0 bits 7:6 set -- C0h, "abnormal termination, reset" --
 * rather than the 80h "invalid command" it gives when nothing is pending.
 * Seeing C0h is proof that the reset took and the part is listening.
 */
		if( is_cmd(&cp,"FDC") )
		{
			word	base, msr, dir, i, live, present;
			word	st0, pcn = 0;
			static const word alias[4] = { 0x430, 0x432,
						       0x434, 0x436 };

			printf("FDC: main status register --");
			live = 0;
			present = 0;
			for( i = 0; i < 4; i++ ) {
				msr = io_read(alias[i],0);
				printf("  %03X=%02X", alias[i], msr);
				if( msr != 0xFF ) {
					present = 1;
					live = alias[i];
				}
			}
			printf("\n");

			dir = io_read(0x438,0);
			printf("     digital input 438=%02X   (bit 0 is ~DC,"
			       " disk change)\n", dir);

			if( !present ) {
				printf("FDC: nothing answering.  FF is a"
				       " floating bus -- no card, or not"
				       " jumpered to 30h-3Fh.\n");
				continue;
			}

			msr = io_read(live,0);

			printf("FDC: MSR %02X at %03X --%s pulsing reset"
			       " (latch 438 <- 00 then 80)\n",
				msr, live,
				(msr == 0x00)
				  ? " held in reset, as expected after"
				    " power-on;"
				  : (msr == 0x80)
				    ? " idle;"
				    : " wedged mid-command;");

			io_write(0x438,0x00,0);		/* ~FDC_RST low */
			for( i = 0; i < 200; i++ )
				(void)io_read(live,0);	/* a few microseconds */
			io_write(0x438,0x80,0);		/* and released */

			for( i = 0; i < 2000; i++ ) {
				msr = io_read(live,0);
				if( msr == 0x80 )	break;
			}

			printf("FDC: MSR %02X --%s%s%s%s\n", msr,
				(msr & 0x80) ? " RQM"    : " (no RQM)",
				(msr & 0x40) ? " DIO=in" : " DIO=out",
				(msr & 0x20) ? " EXEC"   : "",
				(msr & 0x10) ? " BUSY"   : " idle");

			if( (msr & 0xC0) != 0x80 ) {
				printf("     still not ready for a command"
				       " (want RQM set, DIO clear).\n");
				continue;
			}

			/* SENSE INTERRUPT STATUS: one byte out, two back. */
			base = (word)(live + 1);		/* data reg */
			io_write(base,0x08,0);

			for( i = 0; i < 2000; i++ ) {
				msr = io_read(live,0);
				if( (msr & 0xC0) == 0xC0 )	break;
			}
			if( (msr & 0xC0) != 0xC0 ) {
				printf("     command taken but no result"
				       " phase, MSR %02X\n", msr);
				continue;
			}
			st0 = io_read(base,0);

			for( i = 0; i < 2000; i++ ) {
				msr = io_read(live,0);
				if( (msr & 0xC0) != 0xC0 )	break;
				pcn = io_read(base,0);
			}

			printf("     SENSE INTERRUPT STATUS -> ST0 %02X", st0);
			if( (st0 & 0xC0) == 0xC0 )
				printf(", PCN %02X  (reset seen -- the part is"
				       " alive)\n", pcn);
			else if( st0 == 0x80 )
				printf("  (invalid command -- nothing was"
				       " pending)\n");
			else
				printf(", PCN %02X\n", pcn);

			printf("FDC: controller answering at %03X, data"
			       " register at %03X.\n", live, base);
			continue;
		}

/*
 * FDID -- spin a drive up and read a sector ID off the media.
 *
 * This is the rung above FDC.  READ ID is the smallest operation that
 * needs everything real: a drive selected, a motor turning, a head over a
 * track, the data separator locked to the bit stream, and the data rate
 * right.  What it does not need is a transfer loop or any TC handling, so
 * it isolates the analogue half of the problem from the driver half.
 *
 * Its result phase is the useful part.  Seven bytes come back, and the last
 * four are the C/H/R/N of whatever sector header passed under the head --
 * which is to say the drive tells you what geometry the media actually is,
 * rather than you telling it.
 *
 * The latch value is an argument because two of its fields are still
 * unknown.  P0/P1/P2 might or might not be how a drive gets selected on
 * this board -- the schematic suggests drive select comes from the FDC's
 * own US0/US1 through a 74LS139 instead -- and the sense of MINI, which is
 * the data rate, has not been confirmed against the FDC9266 datasheet.
 * Rather than guess either, both are yours to sweep:
 *
 *     82  motor on, MINI clear   -- 500 kbps, for 1.44Mb and 1.2Mb media
 *     86  motor on, MINI set     -- 250 kbps, for 720Kb and 360Kb media
 *
 * add 40 to either for DENSEL, and 08/10/20 for P2/P1/P0.
 *
 * ST0 is what to read first.  Bits 7:6 clear mean the ID was found.  40h
 * means abnormal termination, and then ST1 bit 0 -- missing address mark --
 * is the signature of a head that is reading nothing it recognises: wrong
 * data rate, wrong drive, no disk, or a motor that never span.
 */
		if( is_cmd(&cp,"FDID") )
		{
			dword	v;
			word	base, latch, drive, msr, i, t0;
			word	r[7];
			int	bad;

			base  = 0x436;
			latch = 0x82;
			drive = 0;

			if( parse_val(&cp,&v) )		latch = (word)v;
			if( parse_val(&cp,&v) )		drive = (word)(v & 3);

			printf("FDID: latch %02X, FDC drive %u\n",
				latch, drive);

			/* Pulse reset with the caller's bits, so this
			   recovers a wedged controller instead of refusing
			   to talk to one.  Bit 7 low asserts reset; the rest
			   of the latch -- motor, MINI, DENSEL, P0/P1/P2 --
			   is held across the pulse. */
			io_write(0x438,(word)(latch & 0x7F),0);
			for( i = 0; i < 200; i++ )
				(void)io_read(base,0);
			io_write(0x438,latch,0);

			/* A 3.5 inch drive wants about half a second to reach
			   speed; ten ticks of the 18.2hz clock is 550ms. */
			t0 = bda.timer_count_low;
			while( (word)(bda.timer_count_low - t0) < 10 )
				;

			msr = io_read(base,0);
			if( msr != 0x80 ) {
				printf("FDID: MSR %02X after a reset pulse --"
				       " the controller will not go idle.\n",
					msr);
				io_write(0x438,0x80,0);
				continue;
			}

			/* A 765 raises one reset interrupt per drive and will
			   not behave until they are all collected.  Four
			   SENSE INTERRUPT STATUS commands clear them, and the
			   answers run C0, C1, C2, C3 -- the low two bits are
			   the drive the interrupt belongs to.  A fifth call
			   would answer 80h, invalid command, which is what an
			   empty queue looks like. */
			for( i = 0; i < 4; i++ ) {
				if( fdc_put(base,0x08) )	break;
				fdc_get(base,&r[0]);
				fdc_get(base,&r[1]);
			}
			printf("      reset interrupts cleared,"
			       " last ST0 %02X\n", r[0]);

			/* SPECIFY: step rate 6ms, head unload 240ms, head
			   load 4ms, and the low bit set for non-DMA. */
			bad  = fdc_put(base,0x03);
			bad |= fdc_put(base,0xDF);
			bad |= fdc_put(base,0x03);
			if( bad ) {
				printf("FDID: SPECIFY was not accepted\n");
				io_write(0x438,0x80,0);
				continue;
			}

			/* RECALIBRATE: step to track 0. */
			bad  = fdc_put(base,0x07);
			bad |= fdc_put(base,drive);
			if( bad ) {
				printf("FDID: RECALIBRATE was not accepted\n");
				io_write(0x438,0x80,0);
				continue;
			}

			/* Waiting on the drive-busy bits was wrong: they are
			   not set yet when the last command byte goes in, so
			   the loop fell straight through and the SENSE that
			   followed asked a controller still working on the
			   seek.  Ask for the result instead, and keep asking.
			   80h means "nothing has finished", so anything else
			   is the answer -- which is what waiting for an
			   interrupt would have got, done by polling. */
			r[0] = 0x80;
			r[1] = 0;
			t0 = bda.timer_count_low;
			do {
				if( fdc_put(base,0x08) )	break;
				if( fdc_get(base,&r[0]) )	break;

				/* 80h is a one-byte answer.  Reading a PCN
				   after it waits for a byte the controller
				   was never going to send, which burns the
				   whole deadline on the first pass and
				   leaves the real completion uncollected --
				   and an uncollected seek keeps the drive
				   busy bit set, which is what MSR 81 was. */
				if( r[0] == 0x80 )		continue;

				fdc_get(base,&r[1]);		/* PCN */
				break;
			} while( (word)(bda.timer_count_low - t0)
							< FDC_TIMEOUT );

			msr = io_read(base,0);
			printf("      after RECALIBRATE, MSR %02X,"
			       " ST0 %02X  PCN %02X%s\n",
				msr, r[0], r[1],
				(r[0] == 0x80)
				  ? "   (never completed)"
				  : ((r[0] & 0xC0) == 0x00 && (r[0] & 0x20))
				    ? "   (seek end -- head is at track 0)"
				    : (r[0] & 0x10)
				      ? "   (equipment check -- no track 0"
					" signal, so no drive is answering)"
				      : (r[0] & 0x08)
					? "   (not ready)"
					: "");

			/* READ ID, MFM.  Head 0. */
			bad  = fdc_put(base,0x4A);
			bad |= fdc_put(base,(word)(drive & 3));
			if( bad ) {
				printf("FDID: READ ID was not accepted\n");
				io_write(0x438,0x80,0);
				continue;
			}

			bad = 0;
			for( i = 0; i < 7; i++ ) {
				if( fdc_get(base,&r[i]) ) {
					bad = 1;
					break;
				}
			}

			if( bad ) {
				printf("FDID: READ ID gave no result phase"
				       " -- the controller is stuck\n");
				io_write(0x438,0x80,0);
				continue;
			}

			printf("      READ ID -> ST0 %02X  ST1 %02X  ST2 %02X"
			       "   C%u H%u R%u N%u\n",
				r[0], r[1], r[2],
				r[3], r[4], r[5], r[6]);

			if( (r[0] & 0xC0) == 0x00 )
				printf("FDID: sector ID found."
				       "  N%u means %u bytes a sector.\n",
					r[6], (word)(128 << (r[6] & 7)));
			else if( r[1] & 0x01 )
				printf("FDID: missing address mark -- the head"
				       " is reading nothing it recognises.\n"
				       "      Wrong data rate, wrong drive,"
				       " no disk, or the motor never span.\n");
			else
				printf("FDID: abnormal termination,"
				       " ST1 %02X ST2 %02X\n", r[1], r[2]);

			io_write(0x438,0x80,0);	/* motor off, reset released */
			printf("      motor off\n");
			continue;
		}

/*
 * FDREAD -- read one sector off a floppy, the whole way through.
 *
 * The rung above FDID.  Everything FDID proved is reused: reset pulse,
 * interrupt queue drained, SPECIFY, RECALIBRATE.  What is new is the part
 * that could not be tested by reading an ID -- moving 512 bytes through the
 * data register with nothing allowed to interrupt, then terminating the
 * command with TC out of latch bit 0.
 *
 * This exists as a monitor command rather than going straight into a driver
 * because a transfer loop that is subtly wrong looks like bad media, and
 * debugging that through DOS and INT 13h at the same time is three unknowns
 * at once.  Here the sector arrives, or it does not, and the seven result
 * bytes say why.
 *
 * ST1 is where a transfer goes to explain itself.  Bit 4 is overrun -- the
 * loop was too slow and a byte went past uncollected, which is the failure
 * disabling interrupts is meant to prevent.  Bit 5 is a CRC error in the
 * data field.  Bit 2 is no data: the sector asked for is not on the track.
 */
		if( is_cmd(&cp,"FDREAD") )
		{
			dword	v;
			word	base, latch, drive, msr, i, t0;
			word	cyl, head, sec;
			word	r[7];
			byte	*buf;
			union {
				byte	*p;
				struct { word off; word seg; } fp;
			} m;
			int	rc;

			base  = 0x436;
			latch = 0x82;
			cyl   = 0;
			head  = 0;
			sec   = 1;
			drive = 0;

			if( parse_val(&cp,&v) )		latch = (word)v;
			if( parse_val(&cp,&v) )		cyl   = (word)v;
			if( parse_val(&cp,&v) )		head  = (word)(v & 1);
			if( parse_val(&cp,&v) )		sec   = (word)v;

			if( sec == 0 ) {
				printf("usage: FDREAD [<latch>] [<cyl>]"
				       " [<head>] [<sector>]\n"
				       "       hex; sectors count from 1."
				       "  Default 82 0 0 1.\n");
				continue;
			}

			m.fp.seg = 0x1000;	/* the scratch SECCMP uses */
			m.fp.off = 0;
			buf = m.p;

			printf("FDREAD: latch %02X, C%u H%u S%u\n",
				latch, cyl, head, sec);

			/* Reset pulse, then drain the four reset
			   interrupts, exactly as FDID does. */
			io_write(0x438,(word)(latch & 0x7F),0);
			for( i = 0; i < 200; i++ )	(void)io_read(base,0);
			io_write(0x438,latch,0);

			t0 = bda.timer_count_low;
			while( (word)(bda.timer_count_low - t0) < 10 )
				;

			if( io_read(base,0) != 0x80 ) {
				printf("FDREAD: controller will not go idle\n");
				io_write(0x438,0x80,0);
				continue;
			}
			for( i = 0; i < 4; i++ ) {
				if( fdc_put(base,0x08) )	break;
				fdc_get(base,&r[0]);
				fdc_get(base,&r[1]);
			}

			fdc_put(base,0x03);		/* SPECIFY */
			fdc_put(base,0xDF);
			fdc_put(base,0x03);		/* non-DMA */

			/* RECALIBRATE, then SEEK if the track is not 0. */
			fdc_put(base,0x07);
			fdc_put(base,drive);
			r[0] = 0x80;
			t0 = bda.timer_count_low;
			do {
				if( fdc_put(base,0x08) )	break;
				if( fdc_get(base,&r[0]) )	break;
				if( r[0] == 0x80 )		continue;
				fdc_get(base,&r[1]);
				break;
			} while( (word)(bda.timer_count_low - t0) < 36 );

			if( cyl ) {
				fdc_put(base,0x0F);		/* SEEK */
				fdc_put(base,(word)((head << 2) | drive));
				fdc_put(base,cyl);
				r[0] = 0x80;
				t0 = bda.timer_count_low;
				do {
					if( fdc_put(base,0x08) )	break;
					if( fdc_get(base,&r[0]) )	break;
					if( r[0] == 0x80 )		continue;
					fdc_get(base,&r[1]);
					break;
				} while( (word)(bda.timer_count_low - t0) < 36 );
				printf("        SEEK -> ST0 %02X  PCN %02X\n",
					r[0], r[1]);
			}

			/* READ DATA, MFM, one sector.  EOT is set to the
			   sector wanted so the controller stops there by
			   itself rather than running to the end of the
			   track. */
			rc  = fdc_put(base,0x46);
			rc |= fdc_put(base,(word)((head << 2) | drive));
			rc |= fdc_put(base,cyl);
			rc |= fdc_put(base,head);
			rc |= fdc_put(base,sec);
			rc |= fdc_put(base,0x02);	/* N: 512 bytes */
			rc |= fdc_put(base,sec);	/* EOT */
			rc |= fdc_put(base,0x1B);	/* GPL for MFM 512 */
			rc |= fdc_put(base,0xFF);	/* DTL, unused when N */
			if( rc ) {
				printf("FDREAD: the command was not taken\n");
				io_write(0x438,0x80,0);
				continue;
			}

			rc = fdc_pio_in(base,buf,512);

			/* TC ends the command.  Pulsed, not left asserted. */
			io_write(0x438,(word)(latch | 0x01),0);
			io_write(0x438,latch,0);

			for( i = 0; i < 7; i++ ) {
				if( fdc_get(base,&r[i]) ) {
					printf("FDREAD: result phase stopped"
					       " after %u bytes\n", i);
					break;
				}
			}

			msr = io_read(base,0);
			io_write(0x438,0x80,0);		/* motor off */

			printf("        transfer %s;  ST0 %02X ST1 %02X"
			       " ST2 %02X   C%u H%u R%u N%u   MSR %02X\n",
				(rc == 0) ? "complete"
					  : (rc == 1) ? "cut short"
						      : "timed out",
				r[0], r[1], r[2], r[3], r[4], r[5], r[6], msr);

			if( (r[0] & 0xC0) != 0x00 ) {
				printf("FDREAD: failed --%s%s%s%s\n",
					(r[1] & 0x10) ? " overrun (the loop"
							" was too slow)" : "",
					(r[1] & 0x20) ? " CRC error in the"
							" data field" : "",
					(r[1] & 0x04) ? " no data (sector not"
							" on this track)" : "",
					(r[1] & 0x01) ? " missing address"
							" mark" : "");
				continue;
			}

			printf("FDREAD: sector read.  First 16 bytes:\n       ");
			for( i = 0; i < 16; i++ )
				printf(" %02X", (word)buf[i]);
			printf("\n");
			if( cyl == 0 && head == 0 && sec == 1 )
				printf("        bytes 1FE-1FF are %02X %02X"
				       " -- %s\n",
					(word)buf[510], (word)buf[511],
					(buf[510] == 0x55 && buf[511] == 0xAA)
					  ? "a boot signature"
					  : "not a boot signature");
			continue;
		}

/*
 * FDWRITE -- write one sector, then read it back and compare.
 *
 * The last untested path on the floppy side, and the only destructive one.
 * Every argument is required, with no defaults at all: a command that
 * overwrites a sector should not be runnable by pressing return, and the
 * disk in the drive when this is tried should be one nobody minds losing.
 *
 * It verifies itself. Writing and reporting success on the controller's own
 * say-so proves very little -- the IDE driver in this tree had a write path
 * whose documentation and behaviour disagreed for years, and it was only
 * ever caught by reading back. So this fills the buffer with a pattern that
 * depends on the sector address, writes it, clears the buffer, reads it
 * again and compares. Nothing short of a byte-for-byte match is reported as
 * working.
 *
 * ST1 bit 1 is the one to watch: write protect. Bit 4 is underrun, the
 * write-side equivalent of overrun, and it means the sector on the media is
 * now damaged rather than merely unwritten.
 */
		if( is_cmd(&cp,"FDWRITE") )
		{
			dword	v;
			word	base, latch, drive, i, t0;
			word	cyl, head, sec;
			word	r[7];
			byte	*buf;
			union {
				byte	*p;
				struct { word off; word seg; } fp;
			} m;
			int	rc, bad;

			base  = 0x436;
			drive = 0;

			/* All four, or none: no defaults on a command that
			   overwrites something. */
			latch = cyl = head = sec = 0;
			rc = 0;
			if( parse_val(&cp,&v) )	{ latch = (word)v;       rc++; }
			if( parse_val(&cp,&v) )	{ cyl   = (word)v;       rc++; }
			if( parse_val(&cp,&v) )	{ head  = (word)(v & 1); rc++; }
			if( parse_val(&cp,&v) )	{ sec   = (word)v;       rc++; }

			if( rc != 4 || latch == 0 || sec == 0 ) {
				printf("usage: FDWRITE <latch> <cyl> <head>"
				       " <sector>\n"
				       "       every argument required, hex."
				       "  82 = 500kbps, 86 = 250kbps.\n"
				       "       THIS OVERWRITES THE SECTOR."
				       "  Use a disk you do not want.\n");
				continue;
			}

			m.fp.seg = 0x1000;
			m.fp.off = 0;
			buf = m.p;

			printf("FDWRITE: latch %02X, C%u H%u S%u --"
			       " overwriting\n", latch, cyl, head, sec);

			/* A pattern that depends on where it is going, so a
			   write that lands on the wrong sector cannot pass
			   by looking like the right one. */
			for( i = 0; i < 512; i++ )
				buf[i] = (byte)(i + cyl * 7 + head * 13
						  + sec * 29);

			io_write(0x438,(word)(latch & 0x7F),0);
			for( i = 0; i < 200; i++ )	(void)io_read(base,0);
			io_write(0x438,latch,0);
			t0 = bda.timer_count_low;
			while( (word)(bda.timer_count_low - t0) < 10 )
				;

			if( io_read(base,0) != 0x80 ) {
				printf("FDWRITE: controller will not go"
				       " idle\n");
				io_write(0x438,0x80,0);
				continue;
			}
			for( i = 0; i < 4; i++ ) {
				if( fdc_put(base,0x08) )	break;
				fdc_get(base,&r[0]);
				fdc_get(base,&r[1]);
			}

			fdc_put(base,0x03);		/* SPECIFY */
			fdc_put(base,0xDF);
			fdc_put(base,0x03);

			fdc_put(base,0x07);		/* RECALIBRATE */
			fdc_put(base,drive);
			r[0] = 0x80;
			t0 = bda.timer_count_low;
			do {
				if( fdc_put(base,0x08) )	break;
				if( fdc_get(base,&r[0]) )	break;
				if( r[0] == 0x80 )		continue;
				fdc_get(base,&r[1]);
				break;
			} while( (word)(bda.timer_count_low - t0) < 36 );

			if( cyl ) {
				fdc_put(base,0x0F);		/* SEEK */
				fdc_put(base,(word)((head << 2) | drive));
				fdc_put(base,cyl);
				r[0] = 0x80;
				t0 = bda.timer_count_low;
				do {
					if( fdc_put(base,0x08) )	break;
					if( fdc_get(base,&r[0]) )	break;
					if( r[0] == 0x80 )		continue;
					fdc_get(base,&r[1]);
					break;
				} while( (word)(bda.timer_count_low - t0)
								< 36 );
			}

			/* WRITE DATA, MFM, one sector. */
			rc  = fdc_put(base,0x45);
			rc |= fdc_put(base,(word)((head << 2) | drive));
			rc |= fdc_put(base,cyl);
			rc |= fdc_put(base,head);
			rc |= fdc_put(base,sec);
			rc |= fdc_put(base,0x02);
			rc |= fdc_put(base,sec);	/* EOT */
			rc |= fdc_put(base,0x1B);	/* GPL */
			rc |= fdc_put(base,0xFF);	/* DTL */
			if( rc ) {
				printf("FDWRITE: the command was not taken\n");
				io_write(0x438,0x80,0);
				continue;
			}

			rc = fdc_pio_out(base,buf,512);

			io_write(0x438,(word)(latch | 0x01),0);	/* TC */
			io_write(0x438,latch,0);

			for( i = 0; i < 7; i++ )
				if( fdc_get(base,&r[i]) )	break;

			printf("         write %s;  ST0 %02X ST1 %02X"
			       " ST2 %02X\n",
				(rc == 0) ? "complete"
					  : (rc == 1) ? "cut short"
						      : "timed out",
				r[0], r[1], r[2]);

			if( (r[0] & 0xC0) != 0x00 ) {
				printf("FDWRITE: failed --%s%s%s\n",
					(r[1] & 0x02) ? " WRITE PROTECTED" : "",
					(r[1] & 0x10) ? " underrun (the sector"
							" on the media is now"
							" damaged)" : "",
					(r[1] & 0x01) ? " missing address"
							" mark" : "");
				io_write(0x438,0x80,0);
				continue;
			}

			/* Read it back.  Clearing the buffer first means a
			   read that quietly does nothing cannot pass. */
			for( i = 0; i < 512; i++ )	buf[i] = 0;

			rc  = fdc_put(base,0x46);	/* READ DATA */
			rc |= fdc_put(base,(word)((head << 2) | drive));
			rc |= fdc_put(base,cyl);
			rc |= fdc_put(base,head);
			rc |= fdc_put(base,sec);
			rc |= fdc_put(base,0x02);
			rc |= fdc_put(base,sec);
			rc |= fdc_put(base,0x1B);
			rc |= fdc_put(base,0xFF);

			rc = fdc_pio_in(base,buf,512);
			io_write(0x438,(word)(latch | 0x01),0);
			io_write(0x438,latch,0);
			for( i = 0; i < 7; i++ )
				if( fdc_get(base,&r[i]) )	break;

			io_write(0x438,0x80,0);		/* motor off */

			if( (r[0] & 0xC0) != 0x00 || rc ) {
				printf("FDWRITE: the read back failed,"
				       " ST0 %02X ST1 %02X\n", r[0], r[1]);
				continue;
			}

			bad = -1;
			for( i = 0; i < 512; i++ ) {
				if( buf[i] == (byte)(i + cyl * 7 + head * 13
							+ sec * 29) )
					continue;
				bad = (int)i;
				break;
			}

			if( bad < 0 )
				printf("FDWRITE: written and read back,"
				       " 512 bytes agree\n");
			else
				printf("FDWRITE: differs at byte %u -- got"
				       " %02X, wanted %02X\n",
					(word)bad, (word)buf[bad],
					(word)(byte)(bad + cyl * 7
						+ head * 13 + sec * 29));
			continue;
		}

/*
 * FD13 -- call INT 13h against a floppy and report what the 765 said.
 *
 * FDREAD and FDWRITE reach the controller directly.  This goes the way DOS
 * goes -- INT 13h, int_40h, the driver -- and then prints the seven result
 * bytes the driver left in bda.fd_ctrl_stat[].  Those bytes are the whole
 * point: a status code alone says "seek error", which is a summary written
 * by fd_result() and can be wrong about the cause.  ST0, ST1 and ST2 say
 * what the controller actually reported.
 *
 * Reading them after a failed DOS operation is not possible any other way:
 * the monitor is only reachable through SETUP during POST, and the test of
 * segment 0 zeroes the BDA on the way there.
 *
 *	ST0 bits 7:6	00 normal, 01 abnormal, 10 invalid command
 *	ST1 bit 7	end of cylinder -- reached EOT rather than TC
 *	    bit 5	CRC error in the data field
 *	    bit 4	overrun or underrun: the loop was too slow
 *	    bit 2	no data: that sector is not on this track
 *	    bit 1	not writable: the disk is write protected
 *	    bit 0	missing address mark
 *	ST2 bit 5	CRC error in the data field
 *	    bit 4	wrong cylinder: the header says another track
 *	    bit 0	missing data address mark
 */
/*
 * FDFMT -- format one track through INT 13h function 05h.
 *
 * The rung below "FORMAT A:", and the reason to have it: a format that
 * fails under DOS says nothing about whether the driver, the identifier
 * table, or DOS's own use of the call is at fault.  This builds the
 * table itself, formats exactly one track, and prints the seven result
 * bytes -- so a failure here is the driver's and a failure only under
 * DOS is not.
 *
 * The identifier table is four bytes a sector: cylinder, head, record
 * and size.  Sectors are numbered from 1 with no interleave, which is
 * what a PC floppy has used since the format existed.
 *
 * This DESTROYS the track.  There is no confirmation, because every
 * other write command here has none either, but cylinder 0 carries the
 * boot sector and the start of the FAT.
 */
		if( is_cmd(&cp,"FDFMT") )
		{
			T_REGS	regs;
			dword	v;
			word	cyl, head, nsec, cur_ds, i, got;
			byte	far *t;
			union {
				byte	far *p;
				struct { word off; word seg; } fp;
			} m;

			cyl = head = 0;
			nsec = 18;
			got = 0;
			if( parse_val(&cp,&v) )	{ cyl  = (word)v;       got++; }
			if( parse_val(&cp,&v) )	{ head = (word)(v & 1); got++; }
			if( parse_val(&cp,&v) && v )	nsec = (word)v;

			if( got != 2 || nsec < 1 || nsec > 36 ) {
				printf("usage: FDFMT <cyl> <head> [<sectors>]\n"
				       "       hex.  drive A only, and it"
				       " ERASES that track.\n"
				       "       sectors defaults to 12h (18),"
				       " use 09 for 720Kb.\n");
				continue;
			}

			m.fp.seg = 0x1000;
			m.fp.off = 0;
			t = m.p;

			/* C, H, R, N for each sector.  N is 2, meaning 512. */
			for( i = 0; i < nsec; i++ ) {
				t[i*4+0] = (byte)cyl;
				t[i*4+1] = (byte)head;
				t[i*4+2] = (byte)(i + 1);
				t[i*4+3] = 2;
			}

			ASM {
				mov	ax,ds
				mov	[cur_ds],ax
			}

			regs.ax = (word)(0x0500 | (nsec & 0xFF));
			regs.cx = (word)(((cyl & 0x00FF) << 8)
					| ((cyl >> 2) & 0x00C0));
			regs.dx = (word)(head << 8);	/* DL = 0, drive A */
			regs.bx = m.fp.off;
			regs.es = m.fp.seg;
			regs.ds = cur_ds;
			regs.si = regs.di = 0;
			regs.flags = 0;

			printf("FDFMT: cyl %u head %u, %u sectors"
			       "  AX=%04X CX=%04X DX=%04X\n",
				cyl, head, nsec,
				regs.ax, regs.cx, regs.dx);

			int13_call(&regs);

			printf("      returned AH=%02X  %s\n",
				(word)(regs.ax >> 8),
				(regs.flags & 1) ? "CY -- failed" : "NC");

			printf("      765 result:");
			for( i = 0; i < 7; i++ )
				printf(" %02X", (word)bda.fd_ctrl_stat[i]);
			printf("\n      fd_status %02X  seek_status %02X"
			       "  latch %02X\n",
				(word)bda.fd_status,
				(word)bda.seek_status,
				(word)bda.motor_status);
			continue;
		}

		if( is_cmd(&cp,"FD13") )
		{
			T_REGS	regs;
			dword	v;
			word	fn, cyl, head, sec, cnt, cur_ds, i, got;
			union {
				byte	*p;
				struct { word off; word seg; } fp;
			} m;

			fn = cyl = head = sec = 0;
			cnt = 1;
			got = 0;
			if( parse_val(&cp,&v) )	{ fn   = (word)v;       got++; }
			if( parse_val(&cp,&v) )	{ cyl  = (word)v;       got++; }
			if( parse_val(&cp,&v) )	{ head = (word)(v & 1); got++; }
			if( parse_val(&cp,&v) )	{ sec  = (word)v;       got++; }
			parse_val(&cp,&v);
			if( got == 4 && v )	cnt = (word)v;

			if( got != 4 || sec == 0 ) {
				printf("usage: FD13 <fn> <cyl> <head> <sec>"
				       " [<count>]\n"
				       "       hex.  02 reads, 03 WRITES,"
				       " 04 verifies, 08 parameters.\n"
				       "       drive A only.  03 overwrites"
				       " the sector.\n");
				continue;
			}

			m.fp.seg = 0x1000;
			m.fp.off = 0;

			ASM {
				mov	ax,ds
				mov	[cur_ds],ax
			}

			regs.ax = (word)((fn << 8) | (cnt & 0xFF));
			regs.cx = (word)(((cyl & 0x00FF) << 8)
					| ((cyl >> 2) & 0x00C0)
					| (sec & 0x003F));
			regs.dx = (word)(head << 8);	/* DL = 0, drive A */
			regs.bx = m.fp.off;
			regs.es = m.fp.seg;
			regs.ds = cur_ds;
			regs.si = regs.di = 0;
			regs.flags = 0;

			printf("FD13: AH=%02X AL=%02X CX=%04X DX=%04X\n",
				fn, cnt, regs.cx, regs.dx);

			int13_call(&regs);

			printf("      returned AH=%02X AL=%02X  %s\n",
				(word)(regs.ax >> 8), (word)(regs.ax & 0xFF),
				(regs.flags & 1) ? "CY -- failed" : "NC");

			printf("      765 result:");
			for( i = 0; i < 7; i++ )
				printf(" %02X", (word)bda.fd_ctrl_stat[i]);
			printf("\n      ST0 %02X ST1 %02X ST2 %02X   C%u H%u"
			       " R%u N%u\n",
				(word)bda.fd_ctrl_stat[0],
				(word)bda.fd_ctrl_stat[1],
				(word)bda.fd_ctrl_stat[2],
				(word)bda.fd_ctrl_stat[3],
				(word)bda.fd_ctrl_stat[4],
				(word)bda.fd_ctrl_stat[5],
				(word)bda.fd_ctrl_stat[6]);
			printf("      fd_status %02X  seek_status %02X"
			       "  latch %02X\n",
				(word)bda.fd_status,
				(word)bda.seek_status,
				(word)bda.motor_status);
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
