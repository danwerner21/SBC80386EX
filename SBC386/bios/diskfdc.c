/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; diskfdc.c -- the floppy driver
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
; An SMC FDC9266 on an ECB Disk I/O V3.  uPD765/8272 compatible, integrated
; data separator, and no DMA at all -- so every byte of every sector goes
; through the CPU, and the two routines that do that are in "fdcpio.asm"
; where the timing can be controlled.  Everything else is here.
;
; The whole of this was proven from the monitor before any of it was written:
; FDC found the controller and reset it, FDID spun a drive up and read a
; sector ID off the media, FDREAD moved 512 bytes, and FDWRITE wrote a sector
; and read it back to compare.  Those commands remain, and remain the thing
; to fall back on when this misbehaves -- they exercise the same sequences
; without INT 13h or DOS in the way.
;
; State lives in the BDA, because this BIOS has no writable data segment.
; The fields are the ones a PC uses for the same purposes:
;
;	motor_status	the latch shadow.  A 74LS273 cannot be read back, so
;			every write has to supply all eight bits at once
;	motor_count	ticks until the motor stops.  int_irq0 counts it
;			down and calls FDC_stop_motor at zero
;	seek_status	bit per drive: this one needs recalibrating before
;			its next seek can be trusted
;	fd_status	the BIOS status code from the last operation
;	fd_ctrl_stat	the seven result bytes, for INT 13h function 01h
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/

#define XXX
#include "mytypes.h"
#include "nvram.h"		/* the bda macro, and the FD_ types */

/* "error.h" opens with a bare XXX, the marker copt uses when it generates
   error.inc, so it has to be read with XXX defined to nothing.  nvram.h
   undefines XXX on its way out, so defining it again here is not belt and
   braces -- without it that bare token survives into the stream and the
   compiler blames whatever declaration it meets next, in another file. */
#define XXX
#include "error.h"
#undef XXX

#include "diskfdc.h"


/* Bounded waits are all measured against the 18.2hz tick, as the IDE
   driver's are.  A spin count would have to be guessed against a deadline
   the media sets -- READ ID alone can take two index pulses, 400ms at
   300 rpm -- and guessing it short reports a working controller as a
   wedged one. */
#define FD_TIMEOUT	36		/* ticks: about two seconds	*/
#define FD_SPINUP	10		/* ticks: about 550ms		*/


/*----------------------------------------------------------------------
 * The latch, and its shadow.
 *
 * Nothing may write FDC_LATCH directly.  It is write-only hardware, so the
 * shadow in bda.motor_status is the only record of what the drive select,
 * the data rate, the motor and the reset line are currently set to.
 *---------------------------------------------------------------------*/
static void fd_latch( byte val )
{
	bda.motor_status = val;
	outp(FDC_LATCH,val);
}


static void fd_latch_bits( byte clear, byte set )
{
	fd_latch( (byte)((bda.motor_status & ~clear) | set) );
}


/*----------------------------------------------------------------------
 * Command and result bytes.
 *
 * The main status register gates each one: RQM says the controller is ready,
 * DIO says which direction it is willing to move.  EXEC is in the mask on
 * purpose -- during a non-DMA execution phase MSR reads F0, and a result
 * read that only looked at RQM and DIO would pull sector data out of the
 * data register and report it as status.
 *
 *	80	command phase, wants a byte in
 *	C0	result phase, has a byte out
 *---------------------------------------------------------------------*/
static int fd_wait( byte want )
{
	word	t0 = bda.timer_count_low;

	do {
		if( (inp(FDC_MSR) & 0xE0) == want )	return( 0 );
	} while( (word)(bda.timer_count_low - t0) < FD_TIMEOUT );

	return( -1 );
}


static int fd_out( word val )
{
	if( fd_wait(0x80) )	return( -1 );
	outp(FDC_DATA,(byte)val);
	return( 0 );
}


static int fd_in( byte *val )
{
	if( fd_wait(0xC0) )	return( -1 );
	*val = (byte)inp(FDC_DATA);
	return( 0 );
}


/*
 * SENSE INTERRUPT STATUS answers with two bytes -- ST0 and the present
 * cylinder -- unless it has nothing to report, when it answers 80h and
 * stops.  Reading a cylinder regardless waits out the whole deadline for a
 * byte that is never sent, and leaves the completion it was asked about
 * uncollected.  An uncollected seek keeps the drive busy bit set for ever.
 */
static int fd_sense( byte *st0, byte *pcn )
{
	*st0 = 0x80;
	*pcn = 0;

	if( fd_out(0x08) )		return( -1 );
	if( fd_in(st0) )		return( -1 );
	if( *st0 == 0x80 )		return( 0 );	/* nothing pending */
	if( fd_in(pcn) )		return( -1 );
	return( 0 );
}


/* Wait for a seek or recalibrate to finish, by asking until the answer
   stops being "nothing has finished".  This is what waiting for the
   interrupt would do, done by polling -- JP3 leaves the FDC interrupt
   unconnected, so polling is the only option there is.
 *
 * The answer has to be checked against the drive that was asked about.  A
 * 765 raises one interrupt per drive after a reset, and those sit in a
 * queue until they are collected -- so the first answer that is not 80h
 * may be a leftover belonging to a unit nobody has touched.  Taking it as
 * the seek result reads as a failed recalibrate: ST0 C2 is interrupt code
 * 11, ready changed, for unit 2, which is exactly what one of them looks
 * like. The low two bits of ST0 name the drive; anything else is discarded
 * and the question asked again.
 */
static int fd_seek_done( int drive, byte *st0, byte *pcn )
{
	word	t0 = bda.timer_count_low;

	do {
		if( fd_sense(st0,pcn) )			return( -1 );
		if( *st0 != 0x80
		 && (*st0 & 0x03) == (byte)drive )	return( 0 );
	} while( (word)(bda.timer_count_low - t0) < FD_TIMEOUT );

	return( -1 );
}


/*----------------------------------------------------------------------
 * SPECIFY -- step rate 3ms, head unload 240ms, head load 4ms, and the low
 * bit set for non-DMA.
 *
 * That low bit is not a formality.  After a hardware reset a 765 is in DMA
 * mode, where it asserts DRQ for each byte instead of handshaking through
 * RQM -- and this board has no DMA, so nothing answers.  A transfer started
 * without SPECIFY looks perfect right up to the data: the head finds the
 * sector, the separator locks, the ID comes back correct, and then the
 * controller streams 512 bytes at nobody and reports overrun.
 *
 * It is issued before every transfer rather than once at reset.  Three
 * command bytes cost microseconds, and the alternative is depending on some
 * earlier call having happened -- which is exactly what failed: fd_reset()
 * is only reachable through INT 13h function 00h, DOS did not call it first,
 * and the controller was left in the mode it powers up in.
 *---------------------------------------------------------------------*/
static int fd_specify( void )
{
	if( fd_out(0x03) )	return( -1 );
	if( fd_out(0xDF) )	return( -1 );	/* SRT 3ms, HUT 240ms	*/
	if( fd_out(0x03) )	return( -1 );	/* HLT 4ms, ND non-DMA	*/
	return( 0 );
}


/*----------------------------------------------------------------------
 * Reset.
 *
 * Bit 7 of the latch is ~FDC_RST, so reset is a PULSE -- low, then high.
 * Writing the released value on its own is only a reset if the bit was
 * already low, which is true exactly once, at power-on, because the 74LS273
 * clears to zero then.  A controller left wedged mid-command needs a real
 * falling edge, and this is the only thing on the board that makes one.
 *
 * Which also means a console reset does not clear it: Ctrl-^ jumps to the
 * reset vector rather than asserting the system reset line, so an ECB card
 * keeps whatever state it was in.  POST calls this for the same reason
 * hd_reset() exists on the IDE side.
 *
 * After a reset the part raises one interrupt per drive and misbehaves until
 * all four are collected.  They answer C0, C1, C2, C3 -- the low two bits
 * name the drive -- and a fifth call would answer 80h.
 *---------------------------------------------------------------------*/
int __cdecl fd_reset( void )
{
	byte	st0, pcn;
	word	t0;
	int	i;

	fd_latch_bits(L_NRESET,0);		/* assert */
	for( i = 0; i < 200; i++ )
		(void)inp(FDC_MSR);		/* a few microseconds */
	fd_latch_bits(0,L_NRESET);		/* release */

	t0 = bda.timer_count_low;
	while( inp(FDC_MSR) != 0x80 ) {
		if( (word)(bda.timer_count_low - t0) >= FD_TIMEOUT ) {
			bda.fd_status = CONTROLLER_FAILED;
			return( CONTROLLER_FAILED );
		}
	}

	for( i = 0; i < 4; i++ )
		if( fd_sense(&st0,&pcn) ) {
			bda.fd_status = CONTROLLER_FAILED;
			return( CONTROLLER_FAILED );
		}

	if( fd_specify() ) {
		bda.fd_status = CONTROLLER_FAILED;
		return( CONTROLLER_FAILED );
	}

	/* Every drive needs recalibrating, but the discovered data rates in
	   bits 4 and 5 survive.  Which rate the medium in the slot actually
	   wants is a property of the medium, not of the controller, and a
	   reset says nothing about it either way.

	   Clearing them here is not a small loss.  Every retry path resets
	   first -- DOS's own, the bootstrap's two attempts, INT 13h function
	   00h -- so a rate learned from a failure was always wiped before
	   the retry that was meant to use it, and a 720Kb disk in a 1.44Mb
	   drive would be tried at 500 kbps for ever. */
	bda.seek_status = (byte)((bda.seek_status & 0x30) | 0x0F);
	bda.fd_status   = NO_ERROR;
	return( NO_ERROR );
}


/*----------------------------------------------------------------------
 * Motor and data rate.
 *
 * There is no ready line to consult -- JP4 ties RDY to ground, because PC
 * drives do not supply one, so the controller always believes a drive is
 * there.  The motor is therefore turned on and given time, rather than
 * turned on and waited for.
 *---------------------------------------------------------------------*/
byte __cdecl fd_rate( int fdtype )
{
	/* 500 kbps for the high density formats, 250 for the rest.  MINI is
	   what halves it: FDC_CLK is a fixed 8mhz oscillator and the MINI pin
	   is the only thing that divides it.  DENSEL is not a rate control,
	   it goes out to the drive's density pin. */
	switch( fdtype ) {
		case FD_1440:
		case FD_1200:	return( 0 );
		default:	return( L_MINI );
	}
}


/* Which rate a drive is actually using, as opposed to the one its
   configured type implies.  A 1.44Mb drive reads 720Kb media perfectly
   well -- at 250 kbps, not the 500 its type calls for -- and nothing can
   be asked about what is in the slot.  So the configured rate is tried,
   and a failure that looks like the wrong one flips this bit for next
   time.  Bits 4 and 5 of seek_status are free; its documented use is the
   low four, one per drive, for "needs recalibrating". */
#define FD_ALTRATE(d)	((byte)(0x10 << (d)))

static void fd_motor_on( int drive, int fdtype )
{
	byte	rate = fd_rate(fdtype);
	byte	want;

	if( bda.seek_status & FD_ALTRATE(drive) )
		rate ^= L_MINI;

	want = (byte)(L_NRESET | L_MOTOR | rate);

	if( (bda.motor_status & (L_MOTOR|L_MINI|L_NRESET)) != want ) {
		fd_latch( want );
		bda.motor_count = FD_MOTOR_TIME;

		/* Only a motor that was not already turning needs the
		   spin-up.  Charging that half second to every sector of a
		   multi-sector read would be paying it dozens of times. */
		{
			word t0 = bda.timer_count_low;
			while( (word)(bda.timer_count_low - t0) < FD_SPINUP )
				continue;
		}
	}
	bda.motor_count = FD_MOTOR_TIME;	/* keep it turning */
}


/*----------------------------------------------------------------------
 * Seek.
 *---------------------------------------------------------------------*/
/* A seek failure leaves nothing in fd_ctrl_stat[], because no transfer
   ever ran -- so the one status that says why is the one that cannot be
   seen.  Put it there, ahead of the transfer that will overwrite it. */
static void fd_note_seek( byte st0, byte pcn )
{
	int	i;

	for( i = 0; i < 7; i++ )	bda.fd_ctrl_stat[i] = 0;
	bda.fd_ctrl_stat[0] = st0;
	bda.fd_ctrl_stat[3] = pcn;	/* where the C byte would sit */
}


int __cdecl fd_seek( int drive, int head, int cyl )
{
	byte	st0, pcn;
	int	try;

	/* A drive that has not been recalibrated does not know where its
	   head is, so a seek to a cylinder number means nothing yet. */
	if( bda.seek_status & (1 << drive) ) {

		/* Twice, if need be.  RECALIBRATE steps at most 77 tracks,
		   and these are 80-track drives: a head parked past track 77
		   cannot reach zero in one command, and the controller
		   reports equipment check rather than getting there.  The
		   second attempt starts 77 tracks closer and always makes
		   it. */
		for( try = 0; try < 2; try++ ) {

			if( fd_out(0x07) || fd_out((word)drive) ) {
				fd_note_seek(0,0);
				return( TIME_OUT );
			}
			if( fd_seek_done(drive,&st0,&pcn) ) {
				fd_note_seek(0,0);
				return( TIME_OUT );
			}
			if( (st0 & 0xC0) == 0x00 && pcn == 0 )
				break;
		}

		if( (st0 & 0xC0) != 0x00 || pcn != 0 ) {
			fd_note_seek(st0,pcn);
			return( BAD_SEEK );
		}

		bda.seek_status &= ~(1 << drive);
	}

	if( cyl == 0 )	return( NO_ERROR );	/* recalibrate got us there */

	if( fd_out(0x0F)
	 || fd_out((word)((head << 2) | drive))
	 || fd_out((word)cyl) )
		return( TIME_OUT );

	if( fd_seek_done(drive,&st0,&pcn) ) {
		fd_note_seek(0,0);
		return( TIME_OUT );
	}
	if( (st0 & 0xC0) != 0x00 || pcn != (byte)cyl ) {
		fd_note_seek(st0,pcn);
		bda.seek_status |= (1 << drive);	/* lost track of it */
		return( BAD_SEEK );
	}
	return( NO_ERROR );
}


/*----------------------------------------------------------------------
 * One sector, in or out.
 *
 * The result phase is kept in bda.fd_ctrl_stat[] so INT 13h function 01h
 * has something to report, and the status code derived from it in
 * bda.fd_status.
 *---------------------------------------------------------------------*/
static int fd_result( void )
{
	byte	st0, st1;
	int	i;

	for( i = 0; i < 7; i++ )
		if( fd_in(&bda.fd_ctrl_stat[i]) ) {
			bda.fd_ctrl_stat[i] = 0;
			return( TIME_OUT );
		}

	st0 = bda.fd_ctrl_stat[0];
	st1 = bda.fd_ctrl_stat[1];

	if( (st0 & 0xC0) == 0x00 )		return( NO_ERROR );

	/* ST1 bit 7 is end of cylinder: the command stopped because it
	   reached the last sector it was allowed rather than because TC
	   ended it.  A 765 calls that an abnormal termination even though
	   every byte moved, and a transfer asking for exactly one sector --
	   which is every transfer here, since EOT is set to the sector
	   wanted -- can reach it as a matter of course.  It is only a
	   failure if something else is flagged with it.

	   Left unhandled this fell through to the catch-all below and was
	   reported as a seek error, which is a long way from what happened
	   and sends anyone debugging it to the wrong part of the driver. */
	if( st1 == 0x80 && bda.fd_ctrl_stat[2] == 0 )
		return( NO_ERROR );

	/* Most specific first: write protect and overrun say what went
	   wrong, where a missing address mark only says the head read
	   nothing it recognised, which has several causes. */
	if( st1 & 0x02 )	return( WRITE_PROTECTED );
	if( st1 & 0x10 )	return( DMA_OVERRUN );
	if( st1 & 0x20 )	return( BAD_CRC );
	if( st1 & 0x04 )	return( SECTOR_NOT_FOUND );
	if( st1 & 0x01 )	return( ADDRESS_MARK_NOT_FOUND );
	if( st0 & 0x08 )	return( DRIVE_NOT_READY );

	return( BAD_SEEK );
}


int __cdecl fd_rw( int write, int drive, int fdtype,
		int cyl, int head, int sec, byte far *buf )
{
	int	rc;

	if( fdtype == FD_NONE )
		return( bda.fd_status = TIME_OUT );

	fd_motor_on(drive,fdtype);

	rc = fd_seek(drive,head,cyl);
	if( rc != NO_ERROR )
		return( bda.fd_status = (byte)rc );

	/* Every time, not once at reset.  See the note on fd_specify(). */
	if( fd_specify() )
		return( bda.fd_status = TIME_OUT );

	if( fd_out((word)(write ? 0x45 : 0x46))	/* MFM write / read	*/
	 || fd_out((word)((head << 2) | drive))
	 || fd_out((word)cyl)
	 || fd_out((word)head)
	 || fd_out((word)sec)
	 || fd_out(0x02)			/* N: 512 bytes		*/
	 || fd_out((word)sec)			/* EOT: stop after it	*/
	 || fd_out(0x1B)			/* GPL for MFM 512	*/
	 || fd_out(0xFF) )			/* DTL, unused when N	*/
		return( bda.fd_status = TIME_OUT );

	if( write )	rc = fdc_pio_out(FDC_MSR,buf,512);
	else		rc = fdc_pio_in (FDC_MSR,buf,512);

	/* TC ends the command.  Pulsed, not left asserted. */
	fd_latch_bits(0,L_TC);
	fd_latch_bits(L_TC,0);

	if( rc == 2 ) {
		bda.seek_status |= (1 << drive);
		(void)fd_result();
		return( bda.fd_status = TIME_OUT );
	}

	rc = fd_result();

	/* A missing address mark, or no data with nothing else wrong, is what
	   the wrong data rate looks like: the head is over real media and
	   reading nothing it recognises.  Flip the rate for this drive so the
	   retry -- DOS offers one, and the bootstrap makes two attempts of its
	   own -- comes back at the other speed.  If that was not the problem
	   the bit flips again next time and costs nothing but the attempt. */
	if( rc == ADDRESS_MARK_NOT_FOUND
	 || (rc == SECTOR_NOT_FOUND && bda.fd_ctrl_stat[2] == 0) )
		bda.seek_status ^= FD_ALTRATE(drive);

	/* Any failure puts the drive back in the "needs recalibrating" set,
	   so the next attempt homes the head before trusting a cylinder
	   number again.  Wrong-cylinder in ST2 is the case that matters:
	   the head is not where this driver believes, and no number of
	   retries at the same place will help until it is re-found.  DOS
	   offers Retry on exactly these errors, and this is what makes
	   taking it worth anything. */
	if( rc != NO_ERROR )
		bda.seek_status |= (1 << drive);

	return( bda.fd_status = (byte)rc );
}


/*----------------------------------------------------------------------
 * Format one track.
 *
 * The 765 writes a whole track in a single command.  The host does not
 * supply data -- it supplies four bytes an identifier, C H R N, one set
 * per sector, and the controller lays down the address marks, the gaps
 * and a data field of the filler byte in between.  Which is why the
 * execution phase here is nsec*4 bytes and not nsec*512: what is being
 * written is the track's structure, and the sector contents come from a
 * single byte repeated by the controller.
 *
 * INT 13h function 05h hands that identifier table down from the caller,
 * so the interleave, the numbering, and any deliberately odd sector are
 * the caller's to decide and none of this driver's business.
 *---------------------------------------------------------------------*/
int __cdecl fd_format( int drive, int fdtype, int cyl, int head,
		int nsec, int gpl, int fill, byte far *chrn )
{
	int	rc;

	if( fdtype == FD_NONE )
		return( bda.fd_status = TIME_OUT );

	/* nsec*4 is the byte count handed to the transfer, and the caller
	   set nsec.  A silly one would either run the execution phase off
	   the end of the caller's table or never satisfy the controller. */
	if( nsec < 1 || nsec > 36 )
		return( bda.fd_status = INVALID_COMMAND );

	/* The data rate follows the format being written, not whatever was
	   last discovered in the slot.  Formatting defines the medium
	   instead of reading one that already exists, so the rate cannot be
	   inherited from a previous read's guess -- a 720Kb disk read in a
	   1.44Mb drive leaves the alternate-rate bit set, and formatting at
	   that rate afterwards would quietly write the wrong format.
	   Sectors per track names it: 15 and 18 are the 500 kbps formats,
	   9 is 250. */
	if( fd_rate(fdtype) == (byte)((nsec >= 15) ? 0 : L_MINI) )
		bda.seek_status &= ~FD_ALTRATE(drive);
	else
		bda.seek_status |= FD_ALTRATE(drive);

	fd_motor_on(drive,fdtype);

	rc = fd_seek(drive,head,cyl);
	if( rc != NO_ERROR )
		return( bda.fd_status = (byte)rc );

	/* Every time, not once at reset.  See the note on fd_specify(). */
	if( fd_specify() )
		return( bda.fd_status = TIME_OUT );

	if( fd_out(0x4D)			/* MFM format a track	*/
	 || fd_out((word)((head << 2) | drive))
	 || fd_out(0x02)			/* N: 512 bytes		*/
	 || fd_out((word)nsec)			/* SC: sectors a track	*/
	 || fd_out((word)gpl)			/* GPL: the format gap	*/
	 || fd_out((word)fill) )		/* D: the filler byte	*/
		return( bda.fd_status = TIME_OUT );

	/* Two things about this transfer are unlike a sector write, and
	   both are relied on rather than arranged.

	   The controller asks for four bytes, writes a whole sector's worth
	   of track, then asks for the next four.  So the gap between groups
	   is a sector time -- about 10ms at 500 kbps, 22 at 250 -- where a
	   write never waits longer than a byte time.  The inter-byte
	   timeout in fdc_pio_out is around 65000 polls, near 100ms here,
	   which covers it; the comment there justifies the figure against
	   16 microseconds, which is the wrong quantity for this caller even
	   though the number happens to serve.

	   And the burst holds interrupts off for a whole revolution, near
	   200ms, instead of the 8ms a sector costs.  The tick is lost for
	   the duration, so a full format drifts the clock by a few seconds.
	   Formatting is rare and the alternative is a rewrite of the
	   transfer loop that the read path now depends on, so it stands --
	   but it is a cost, not an absence of one. */
	rc = fdc_pio_out(FDC_MSR,chrn,(word)(nsec * 4));

	/* TC ends the command.  Pulsed, not left asserted. */
	fd_latch_bits(0,L_TC);
	fd_latch_bits(L_TC,0);

	if( rc == 2 ) {
		bda.seek_status |= (1 << drive);
		(void)fd_result();
		return( bda.fd_status = TIME_OUT );
	}

	rc = fd_result();

	/* No rate fallback here, deliberately.  A read that finds nothing it
	   recognises has a medium to discover; a format that fails has only
	   the rate it was told to use, and flipping it would write the next
	   attempt in a format nobody asked for. */
	if( rc != NO_ERROR )
		bda.seek_status |= (1 << drive);

	return( bda.fd_status = (byte)rc );
}
