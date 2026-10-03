/*
 * sbcfd.c -- the floppy driver for the SBC-386EX: an SMC FDC9266 on an ECB
 * Disk I/O V3, polled, no DMA.
 *
 * Replaces both halves of COHERENT's PC floppy support -- fl386.c (the "fd"
 * module) and the "fdc" device entry, major 4 -- which drive an 8237 DMA
 * channel and a controller at 3F0h, neither of which this board has.  The
 * device interface is the same, so /dev/fva0 and the rest mean what they
 * did:  minor xxuuhkkk -- uu the drive, kkk the format (fdata below), h set
 * on the ordinary devices.  The "special" devices, h clear, which autosense
 * and skip cylinder 0, are not supported.
 *
 * The hardware layer is the SBC BIOS's, from SBC386/bios/diskfdc.c and
 * fdcpio.asm, which read, write and format on this board under DOS.  The
 * notes there say why each step is as it is; the short version:
 *
 *   - the latch at base+8 is write only: reset, motor, data rate (MINI) and
 *     TC all live in it, so a shadow copy is the only record of it
 *   - reset is a pulse, after which one interrupt per drive is collected
 *   - SPECIFY (with the non-DMA bit) goes before every transfer
 *   - seeks are waited for by SENSE INTERRUPT STATUS, accepting only the
 *     answer for the drive asked about (JP3: the FDC interrupt is not wired)
 *   - one sector per command, the data phase polled, interrupts held off
 *     only for the 512-byte burst, TC pulsed by hand to end it
 *
 * Everything is synchronous: block() does the whole request before it
 * returns.  Floppy speed is not a goal; being right on this board is.
 */

#include <sys/coherent.h>
#include <sys/errno.h>
#include <sys/stat.h>
#include <sys/uproc.h>
#include <sys/buf.h>
#include <sys/con.h>
#include <sys/devices.h>

/* Where the controller is.  Z80 I/O port N is 0x400+N on the 386EX, and
   the card is jumpered to 30h-3Fh.  Patchable (/conf/patch FD_BASE=...). */
int	FD_BASE = 0x430;

/* Not used.  The installer's /etc/mkdev patches it ("Are you installing
   on an IBM PS1 or ValuePoint?") into the kernel it boots and the one it
   installs, as MWC's fl386.c had it; a patch of a missing symbol fails
   the install.  Initialised, as MWC's was, so that it is in .data: a
   .bss variable has no bytes in the kernel file for /conf/patch. */
int	fl_dsk_ch_prob = 1;

#define	FDC_MSR		(FD_BASE + 6)	/* main status, read		*/
#define	FDC_DATA	(FD_BASE + 7)	/* command and result		*/
#define	FDC_LATCH	(FD_BASE + 8)	/* 74LS273, WRITE ONLY		*/

#define	L_TC		0x01		/* terminal count, pulsed	*/
#define	L_MOTOR		0x02		/* motor on			*/
#define	L_MINI		0x04		/* 250 kbps (clear: 500)	*/
#define	L_NRESET	0x80		/* clear: FDC held in reset	*/

#define	FD_NDRV		2
#define	FD_SECSIZE		512
#define	FD_TRIES		4		/* attempts per sector		*/
#define	FD_MOTOR_SECS	3		/* idle seconds before motor off */

#define	funit(d)	((minor (d) >> 4) & 3)
#define	fkind(d)	(minor (d) & 7)
#define	fnormal(d)	(minor (d) & 8)

/* The formats, by minor "kind" -- fl386.c's fdata table.  mini says 250
   kbps; gpl is the read/write gap. */
static struct fkind {
	int	size;		/* 512-byte blocks */
	int	nhds;
	int	ncyl;
	int	nspt;
	int	gpl;
	int	mini;
} fk [8] = {
	{  320, 1, 40,  8, 0x20, 1 },	/* 0: 160K */
	{  640, 2, 40,  8, 0x20, 1 },	/* 1: 320K */
	{ 1280, 2, 80,  8, 0x20, 1 },	/* 2: 640K */
	{  360, 1, 40,  9, 0x20, 1 },	/* 3: 180K */
	{  720, 2, 40,  9, 0x20, 1 },	/* 4: 360K */
	{ 1440, 2, 80,  9, 0x20, 1 },	/* 5: 720K */
	{ 2400, 2, 80, 15, 0x1B, 0 },	/* 6: 1.2M */
	{ 2880, 2, 80, 18, 0x1B, 0 }	/* 7: 1.44M */
};

static int	fdpresent;		/* the controller answered at load */
static int	latch;			/* shadow of FDC_LATCH */
static int	needrecal [FD_NDRV];	/* drive's head position unknown */
static int	motorsecs;		/* idle seconds left before motor off */
static unsigned char	fdres [7];	/* last result phase */

int	busyWait ();
int	busyWait2 ();

/* ---------------------------------------------------------------------
 * The latch, through its shadow.
 */
static void
fdlatch (v)
int v;
{
	latch = v & 0xFF;
	outb (FDC_LATCH, latch);
}

/* ---------------------------------------------------------------------
 * Command and result bytes, gated by the main status register.  EXEC is
 * in the mask on purpose (see diskfdc.c):
 *	80	command phase, wants a byte
 *	C0	result phase, has a byte
 */
static int	fdwant;

static int
fdmsr_is ()
{
	return (inb (FDC_MSR) & 0xE0) == fdwant;
}

static int
fdwait (want)
int want;
{
	fdwant = want;
	return busyWait (fdmsr_is, 2 * HZ);	/* nonzero: got it */
}

static int
fdout (v)
int v;
{
	if (! fdwait (0x80))
		return -1;
	outb (FDC_DATA, v & 0xFF);
	return 0;
}

static int
fdin (vp)
unsigned char *vp;
{
	if (! fdwait (0xC0))
		return -1;
	* vp = inb (FDC_DATA);
	return 0;
}

/* SENSE INTERRUPT STATUS: ST0 and the cylinder, or 80h alone if nothing
   is pending. */
static int
fdsense (st0, pcn)
unsigned char *st0, *pcn;
{
	* st0 = 0x80;
	* pcn = 0;
	if (fdout (0x08) || fdin (st0))
		return -1;
	if (* st0 == 0x80)
		return 0;
	return fdin (pcn);
}

/* A seek or recalibrate has finished when SENSE answers for this drive;
   a leftover answer for another drive is discarded. */
static int
fdseekdone (drive, st0, pcn)
int drive;
unsigned char *st0, *pcn;
{
	int i;

	for (i = 0; i < 300; i ++) {		/* about three seconds */
		if (fdsense (st0, pcn))
			return -1;
		if (* st0 != 0x80 && (* st0 & 3) == drive)
			return 0;
		busyWait (NULL, 1);
	}
	return -1;
}

static int
fdspecify ()
{
	/* SRT 3ms, HUT 240ms; HLT 4ms, non-DMA */
	return fdout (0x03) || fdout (0xDF) || fdout (0x03) ? -1 : 0;
}

/* Reset is a pulse.  Four pending interrupts are collected after it. */
static int
fdreset ()
{
	unsigned char st0, pcn;
	int i;

	fdlatch (latch & ~ L_NRESET);
	busyWait2 (NULL, 20);			/* a few microseconds */
	fdlatch (latch | L_NRESET);

	fdwant = 0x80;
	if (! busyWait (fdmsr_is, 2 * HZ))
		return -1;
	for (i = 0; i < 4; i ++)
		if (fdsense (& st0, & pcn))
			return -1;
	if (fdspecify ())
		return -1;
	for (i = 0; i < FD_NDRV; i ++)
		needrecal [i] = 1;
	return 0;
}

/* ---------------------------------------------------------------------
 * Motor and data rate.  There is no ready line (JP4), so the motor is
 * turned on and given time.
 */
static void
fdmotor (kind)
int kind;
{
	int want = L_NRESET | L_MOTOR | (fk [kind].mini ? L_MINI : 0);
	int wasoff = (latch & L_MOTOR) == 0;

	if ((latch & (L_NRESET | L_MOTOR | L_MINI)) != want) {
		fdlatch ((latch & ~ (L_MOTOR | L_MINI)) | want);
		if (wasoff)
			busyWait (NULL, HZ / 2);	/* spin up */
	}
	motorsecs = FD_MOTOR_SECS;
	drvl [FL_MAJOR].d_time = 1;		/* fdtimeout each second */
}

/* ---------------------------------------------------------------------
 * Seek.  RECALIBRATE steps at most 77 tracks, so twice if need be.
 */
static int
fdseek (drive, head, cyl)
int drive, head, cyl;
{
	unsigned char st0, pcn;
	int try;

	if (needrecal [drive]) {
		for (try = 0; try < 2; try ++) {
			if (fdout (0x07) || fdout (drive))
				return -1;
			if (fdseekdone (drive, & st0, & pcn))
				return -1;
			if ((st0 & 0xC0) == 0 && pcn == 0)
				break;
		}
		if ((st0 & 0xC0) != 0 || pcn != 0)
			return -1;
		needrecal [drive] = 0;
	}
	if (cyl == 0)
		return 0;
	if (fdout (0x0F) || fdout ((head << 2) | drive) || fdout (cyl))
		return -1;
	if (fdseekdone (drive, & st0, & pcn))
		return -1;
	if ((st0 & 0xC0) != 0 || pcn != cyl) {
		needrecal [drive] = 1;
		return -1;
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * The data phase is assembly, fdpio.s, as the BIOS's fdcpio.asm: at
 * 500 kbps a byte not taken within 16us is an overrun, and this in C --
 * busyWait for the first byte, then sphi and inb through calls -- missed
 * the first byte of every sector (ST1 10).  0 all moved, 1 the
 * controller stopped asking early, 2 it stopped answering.
 */
int	fdpioa ();

#define fdpio(write, buf, n) 	fdpioa (FDC_MSR, (buf), (n), (write) ? 0xA0 : 0xE0)

/* ---------------------------------------------------------------------
 * One sector.  0 or -1.
 */
static int
fdresult ()
{
	int i;

	for (i = 0; i < 7; i ++)
		if (fdin (& fdres [i])) {
			fdres [i] = 0;
			return -1;
		}
	if ((fdres [0] & 0xC0) == 0)
		return 0;
	/* End of cylinder alone, when the command asked for exactly the
	   last sector it was allowed, is not a failure (diskfdc.c). */
	if (fdres [1] == 0x80 && fdres [2] == 0)
		return 0;
	return -1;
}

static int
fdsector (write, drive, kind, bno, buf)
int write, drive, kind;
long bno;
unsigned char *buf;
{
	struct fkind *k = & fk [kind];
	int cyl, head, sec, rc;

	fdres [0] = fdres [1] = fdres [2] = 0;	/* no stale result */
	cyl = bno / (k->nspt * k->nhds);
	head = (bno / k->nspt) % k->nhds;
	sec = bno % k->nspt + 1;

	fdmotor (kind);
	if (fdseek (drive, head, cyl) || fdspecify ())
		return -1;

	if (fdout (write ? 0x45 : 0x46)		/* MFM write / read */
	 || fdout ((head << 2) | drive)
	 || fdout (cyl) || fdout (head) || fdout (sec)
	 || fdout (2)				/* N: 512 bytes */
	 || fdout (sec)				/* EOT: just this one */
	 || fdout (k->gpl)
	 || fdout (0xFF))			/* DTL */
		return -1;

	rc = fdpio (write, buf, FD_SECSIZE);

	fdlatch (latch | L_TC);			/* TC ends the command */
	fdlatch (latch & ~ L_TC);

	if (fdresult () || rc != 0) {
		needrecal [drive] = 1;
		return -1;
	}
	return 0;
}

/* ---------------------------------------------------------------------
 * The device entry points.
 */
static void
fdload ()
{
	latch = 0;
	fdlatch (0);				/* motor off, in reset */
	fdpresent = fdreset () == 0;
	if (! fdpresent)
		printf ("fdc: no floppy controller at %x\n", FD_BASE);
}

static void
fdunload ()
{
	fdlatch (0);
}

static void
fdopen (dev, mode)
dev_t dev;
int mode;
{
	if (! fdpresent || funit (dev) >= FD_NDRV || ! fnormal (dev))
		set_user_error (ENXIO);
}

static void
fdclose (dev, mode)
dev_t dev;
int mode;
{
}

static void
fdblock (bp)
BUF *bp;
{
	int drive = funit (bp->b_dev), kind = fkind (bp->b_dev);
	struct fkind *k = & fk [kind];
	long bno;
	paddr_t addr;
	int n, try;

	bp->b_resid = bp->b_count;

	if (bp->b_req == BREAD && bp->b_bno == k->size) {
		bdone (bp);			/* end of the diskette */
		return;
	}
	if (! fdpresent || drive >= FD_NDRV || ! fnormal (bp->b_dev)
	 || bp->b_bno + bp->b_count / FD_SECSIZE > k->size
	 || bp->b_count % FD_SECSIZE != 0 || bp->b_count == 0) {
		bp->b_flag |= BFERR;
		bdone (bp);
		return;
	}

	bno = bp->b_bno;
	addr = bp->b_paddr;
	for (n = bp->b_count / FD_SECSIZE; n > 0; n --) {
		for (try = 0; try < FD_TRIES; try ++) {
			if (fdsector (bp->b_req == BWRITE, drive, kind, bno,
				      (unsigned char *) __PTOV (P2P (addr))) == 0)
				break;
			if (fdres [1] & 0x02) {		/* NW: no retry cures it */
				printf ("fd%d: write protected\n", drive);
				try = FD_TRIES + 1;
				break;
			}
			if (try == FD_TRIES / 2)
				(void) fdreset ();
		}
		if (try > FD_TRIES) {
			bp->b_flag |= BFERR;
			break;
		}
		if (try == FD_TRIES) {
			printf ("fd%d: block %ld: ST0 %x ST1 %x ST2 %x\n",
				drive, bno, fdres [0], fdres [1], fdres [2]);
			bp->b_flag |= BFERR;
			break;
		}
		bno ++;
		addr += FD_SECSIZE;
		bp->b_resid -= FD_SECSIZE;
	}
	bdone (bp);
}

static void
fdread (dev, iop)
dev_t dev;
IO *iop;
{
	ioreq (NULL, iop, dev, BREAD, BFRAW | BFBLK | BFIOC);
}

static void
fdwrite (dev, iop)
dev_t dev;
IO *iop;
{
	ioreq (NULL, iop, dev, BWRITE, BFRAW | BFBLK | BFIOC);
}

static void
fdioctl (dev, cmd, vec)
dev_t dev;
int cmd;
char *vec;
{
	set_user_error (EINVAL);		/* no formatting yet */
}

/* Called each second while d_time is set: the motor goes off when idle. */
static void
fdtimeout (dev)
dev_t dev;
{
	if (-- motorsecs > 0) {
		drvl [FL_MAJOR].d_time = 1;
		return;
	}
	fdlatch (latch & ~ L_MOTOR);
	drvl [FL_MAJOR].d_time = 0;
}

CON fdccon = {
	DFBLK | DFCHR,			/* Flags */
	FL_MAJOR,			/* Major index */
	fdopen,				/* Open */
	fdclose,			/* Close */
	fdblock,			/* Block */
	fdread,				/* Read */
	fdwrite,			/* Write */
	fdioctl,			/* Ioctl */
	NULL,				/* Powerfail */
	fdtimeout,			/* Timeout */
	fdload,				/* Load */
	fdunload,			/* Unload */
	NULL				/* Poll */
};
