/*
 * sbcsd.c -- the SBC-386EX's on-board microSD socket, through the 386EX's
 * synchronous serial unit (SSIO) in SPI mode.  Polled, synchronous.
 *
 *	/dev/mmc0a .. mmc0d	the four partitions of the card's MBR
 *	/dev/mmc0x		the whole card
 *	(minor 0-3; 128 for x)	block and character, major 14
 *
 * so the DOS partition of a card written on a PC is "dos t /dev/mmc0a".
 *
 * Everything here was found on the board first, by SDTEST, and proved
 * again by SD.SYS: SBC386/sdcard/sdtest.asm says how, sdcore.inc is the
 * code this follows.  The bursts themselves are in sdspi.s.  The rules:
 *
 *   - the card's clock is STXCLK and SRXCLK tied: transmitter master,
 *     receiver slave, never both master (SSIOCON2 = 2 and nothing else)
 *   - CS# (P3.6) is open drain, pulled up to the card's 3.3V; P3DIR bit 6
 *     must stay set, or 5V reaches the card.  Nothing here writes P3DIR;
 *     the latch bit alone pulls CS# low or lets it go
 *   - every burst restarts the baud-rate generator and waits sd_phd before
 *     starting (sdspi.s)
 *   - twenty bytes of FF go before every command frame: a burst can begin
 *     with an edge the card counts while DI floats low, and the card takes
 *     a phantom command; the FFs let it end before the real one
 *   - the card's bytes arrive at an offset, usually a bit early: it is
 *     found from R1's first 0 bit and everything after it reassembled
 *   - a read -- command, R1, wait, token, data, CRC -- is one burst; so is
 *     a write up to the card's data response
 *   - CRC16 is checked on every read; a write must be accepted, the card
 *     not busy within half a second, and CMD13 report 00 00
 *
 * The card is brought up at the first open after it goes in: the fastest
 * clock (1.67, 1.25 or 1 MHz) at which some start delay reads sector 0
 * correctly, as SD.SYS does.  Card detect (P3.1) is looked at on every
 * open and request; a card taken out fails until it is opened again.
 */

#include <sys/coherent.h>
#include <sys/errno.h>
#include <sys/stat.h>
#include <sys/uproc.h>
#include <sys/buf.h>
#include <sys/con.h>
#include <sys/fdisk.h>

#define	MMC_MAJOR	14

#define	P3PIN		0xF870
#define	P3LTC		0xF872
#define	SSIOCON1	0xF486
#define	SSIOCON2	0xF488
#define	SSIOBAUD	0xF484
#define	SSIORBUF	0xF482
#define	SDnCS		0x40		/* P3.6 */
#define	SDnCD		0x02		/* P3.1, low with a card in */
#define	TXM		0x02		/* SSIOCON2: transmitter master */
#define	BEN		0x80		/* SSIOBAUD: generator enable */
#define	TUE		0x80
#define	ROE		0x08
#define	BV_SLOW		12		/* 10 MHz / (2*BV+2): 385 kHz */
#define	NPHD		8		/* start delays tried */

#define	PRE		20		/* FFs before a frame */
#define	WINLEN		(PRE + 24)	/* and 8 of frame, 16 of window */
#define	XDATA		262		/* > 1 + 257 words: token, 512+2 */
#define	RINGW		560		/* > XDATA + 257: all-FF data */
#define	CAPMAX		30000		/* FFFF words to wait for a token */
#define	WRESP		8
#define	WTXW		((WINLEN + 2 + 512 + 2 + WRESP) / 2)
#define	TRIES		3

#define	XDEV		0x80		/* minor bit: the whole card */
#define	WHOLE		NPARTN		/* pparm [WHOLE]: the whole card */

/* the parameter block sdspi.s takes: its offsets are fixed there */
struct sdio {
	unsigned char *	tx;
	unsigned char *	rx;
	int		n;
	unsigned char *	ring;
	int		ringw;
	int		xdata;
	int		capmax;
	int		baud;
	int		phd;
	int		rtot;
	unsigned char *	rwp;
	int		err;
};

int	sdburst ();
int	sdxact ();
int	busyWait ();

/* Patchable: 1 shows every command, its R1, offset, SSIO flags and the
   window as it came; 2 also each data transfer's result.
	/conf/patch -k /coh.sbc MMC_DEBUG=1 */
int	MMC_DEBUG = 0;

static struct sdio	io;
static unsigned char	cmdbuf [WINLEN];	/* preamble, frame, window */
static unsigned char	win [WINLEN];
static unsigned char	ffbuf [32];
/* a read's window, and the ring straight after it: unless the ring wraps
   (a long wait for the token) the stream is already in order here */
static unsigned char	rbuf [WINLEN + RINGW * 2 + 8];
static unsigned char	xbuf [WINLEN + RINGW * 2 + 8];	/* when it wraps */
static unsigned char	wtx [WTXW * 2];
static unsigned char	secbuf [520];
static unsigned short	crctab [256];

/* the parameter block sdspi.s's sdalign takes */
struct sdal {
	unsigned char *	src;
	int		bit;
	unsigned char *	dst;
	int		n;
	unsigned short * tab;
};
int	sdalign ();
static struct sdal	al;

static int	up;			/* the card is up */
static int	ccs;			/* block addressed */
static int	r1bit;			/* R1's first bit in win */
static unsigned char bvlist [] = { 2, 3, 4 };	/* 1.67, 1.25, 1 MHz */
static struct fdisk_s	pparm [NPARTN + 1];

/* ---------------------------------------------------------------------
 * Bytes and bits.
 */
static void
copy (d, s, n)
unsigned char *d, *s;
int n;
{
	while (n -- > 0)
		* d ++ = * s ++;
}

static void
fill (d, c, n)
unsigned char *d;
int c, n;
{
	while (n -- > 0)
		* d ++ = c;
}

/* The 8 bits of buf from bit b, most significant first. */
static int
xbits (buf, b)
unsigned char *buf;
int b;
{
	unsigned char *p = buf + (b >> 3);

	return (((p [0] << 8) | p [1]) << (b & 7)) >> 8 & 0xFF;
}

/* The first 0 bit from frame byte 6 on: where R1 starts.  -1 if none. */
static int
find_r1 (buf)
unsigned char *buf;
{
	int b;

	for (b = (PRE + 6) * 8; b < (WINLEN - 6) * 8; b ++)
		if ((buf [b >> 3] & (0x80 >> (b & 7))) == 0)
			return b;
	return -1;
}

static void
crcinit ()
{
	int b, i;
	unsigned int c;

	for (b = 0; b < 256; b ++) {
		c = b << 8;
		for (i = 0; i < 8; i ++)
			c = (c & 0x8000) ? (c << 1) ^ 0x1021 : c << 1;
		crctab [b] = c;
	}
}

static int
card ()
{
	return (inb (P3PIN) & SDnCD) == 0;
}

/* ---------------------------------------------------------------------
 * Bursts.
 */
static int
burst (tx, rx, n)
unsigned char *tx, *rx;
int n;
{
	io.tx = tx;
	io.rx = rx;
	io.n = n;
	return sdburst (& io);
}

/* CS high, then a word of clocks for the card to let go of DO. */
static void
cs_high ()
{
	unsigned char junk [4];

	outb (P3LTC, inb (P3LTC) | SDnCS);
	(void) burst (ffbuf, junk, 2);
}

static void
cs_low ()
{
	outb (P3LTC, inb (P3LTC) & ~ SDnCS);
}

/* The command into cmdbuf's frame: FF, 40|cmd, the argument big end first,
   the CRC, FF.  The preamble before it and the window after are FFs. */
static void
mkframe (cmd, arg, crc)
int cmd, crc;
unsigned long arg;
{
	unsigned char *f = cmdbuf + PRE;

	f [0] = 0xFF;
	f [1] = 0x40 | cmd;
	f [2] = arg >> 24;
	f [3] = arg >> 16;
	f [4] = arg >> 8;
	f [5] = arg;
	f [6] = crc;
	f [7] = 0xFF;
}

/* A command without data, the card selected: its R1, or -1.  The bytes
   after R1 are sd_next (1), sd_next (2) ... */
static void
show (cmd, r, rc)
int cmd, r, rc;
{
	int i;

	printf ("mmc0: CMD%d R1 %x @%d err %x rc %d:", cmd, r & 0xFF,
		r1bit & 7, io.err, rc);
	for (i = PRE; i < WINLEN; i ++)
		printf (" %x", win [i]);
	printf ("\n");
}

static int
sd_cmd (cmd, arg, crc)
int cmd, crc;
unsigned long arg;
{
	int rc, r = -1;

	mkframe (cmd, arg, crc);
	r1bit = 0;
	if ((rc = burst (cmdbuf, win, WINLEN / 2)) >= 0
	 && (r1bit = find_r1 (win)) >= 0)
		r = xbits (win, r1bit);
	if (MMC_DEBUG)
		show (cmd, r, rc);
	return r;
}

static int
sd_next (k)
int k;
{
	return xbits (win, r1bit + 8 * k);
}

/* ---------------------------------------------------------------------
 * A data command, one burst: n bytes of data to dst, set straight and
 * CRC16-checked by sdalign as they go.  0, or -1.  Tried again, up to
 * three times, if the block was not kept whole.
 */
static int
rd_xact (cmd, arg, dst, n)
int cmd, n;
unsigned long arg;
unsigned char *dst;
{
	int t, rc, z, b, end, i, len;
	unsigned char *buf;
	unsigned int c;

	for (t = 0; t < TRIES; t ++) {
		mkframe (cmd, arg, 0x01);
		io.tx = cmdbuf;
		io.rx = rbuf;
		io.n = WINLEN / 2;
		io.ring = rbuf + WINLEN;
		io.ringw = RINGW;
		io.xdata = XDATA;
		io.capmax = CAPMAX;
		cs_low ();
		rc = sdxact (& io);
		i = io.err;
		cs_high ();
		if (MMC_DEBUG > 1)
			printf ("mmc0: data CMD%d rc %d err %x rtot %d\n", cmd,
				rc, i, io.rtot);
		if (rc < 0 || (i & ROE))
			return -1;

		if (io.rtot <= RINGW) {		/* in order already */
			buf = rbuf;
			len = WINLEN + io.rtot * 2;
		} else {			/* wrapped: oldest first */
			buf = xbuf;
			copy (xbuf, rbuf, WINLEN);
			i = (rbuf + WINLEN + RINGW * 2) - io.rwp;
			copy (xbuf + WINLEN, io.rwp, i);
			copy (xbuf + WINLEN + i, rbuf + WINLEN, RINGW * 2 - i);
			len = WINLEN + RINGW * 2;
		}

		if ((z = find_r1 (buf)) < 0 || xbits (buf, z) != 0) {
			if (MMC_DEBUG > 1)
				printf ("mmc0: data R1 %x @%d\n",
					z < 0 ? 0xFF : xbits (buf, z), z);
			return -1;
		}
		end = len * 8 - 16;		/* the token, at R1's offset */
		for (b = z + 8; b < end && xbits (buf, b) == 0xFF; b += 8)
			;
		if (b >= end || xbits (buf, b) != 0xFE) {
			if (MMC_DEBUG > 1)
				printf ("mmc0: data token %x at %d of %d\n",
					b < end ? xbits (buf, b) : 0xFF, b, end);
			return -1;
		}
		b += 8;				/* the data's first bit */
		if (b + (n + 2) * 8 + 8 > len * 8)
			continue;		/* not all kept: again */
		al.src = buf;
		al.bit = b;
		al.dst = dst;
		al.n = n;
		al.tab = crctab;
		c = sdalign (& al);
		b += n * 8;
		if (c != ((xbits (buf, b) << 8) | xbits (buf, b + 8))) {
			if (MMC_DEBUG > 1)
				printf ("mmc0: data CRC %x, block says %x\n", c,
					(xbits (buf, b) << 8) | xbits (buf, b + 8));
			return -1;
		}
		return 0;
	}
	return -1;
}

/* Sector lba of the card to p, CRC16 checked.  0 or -1. */
static int
sd_read (lba, p)
unsigned long lba;
unsigned char *p;
{
	return rd_xact (17, ccs ? lba : lba << 9, p, 512);
}

/* p to sector lba of the card.  0 or -1.
 *
 * One burst: the preamble, the CMD24 frame and window (R1 comes in it),
 * FF FE -- the token, a byte at least after R1 -- the data, its CRC16, and
 * WRESP FFs in which the data response comes: the first byte after the
 * CRC, at R1's offset, that is not FF, and it must say accepted (xxx0
 * 0101).  Then busy -- DO held low, all 0s, the offset does not matter --
 * polled until a word of FFFF, and CMD13 must report 00 00.
 */
static int
sd_write (lba, p)
unsigned long lba;
unsigned char *p;
{
	unsigned char *w = wtx;
	unsigned int c;
	unsigned char rx [4];
	int z, b, k, r, n;

	mkframe (24, ccs ? lba : lba << 9, 0x01);
	copy (w, cmdbuf, WINLEN);
	w += WINLEN;
	* w ++ = 0xFF;
	* w ++ = 0xFE;
	al.src = p;				/* the data, and its CRC */
	al.bit = 0;
	al.dst = w;
	al.n = 512;
	al.tab = crctab;
	c = sdalign (& al);
	w += 512;
	* w ++ = c >> 8;
	* w ++ = c;
	fill (w, 0xFF, WRESP);

	cs_low ();
	if (burst (wtx, xbuf, WTXW) < 0 || (io.err & (TUE | ROE))
	 || (z = find_r1 (xbuf)) < 0 || xbits (xbuf, z) != 0)
		goto fail;
	/* the card's byte sent with the host's byte t starts at bit 8t,
	   less 8 when the offset is not 0 (it comes a bit early) */
	b = (WINLEN + 2 + 512 + 2) * 8;
	if (z & 7)
		b += (z & 7) - 8;
	for (k = 0; k < WRESP - 2 && (r = xbits (xbuf, b)) == 0xFF; k ++)
		b += 8;
	if ((r & 0x1F) != 0x05)
		goto fail;
	for (n = 0; n < 100000; n ++) {		/* busy */
		if (burst (ffbuf, rx, 2) < 0)
			goto fail;
		if (rx [0] == 0xFF && rx [1] == 0xFF)
			break;
	}
	if (n == 100000)
		goto fail;
	cs_high ();
	cs_low ();				/* CMD13: status */
	r = sd_cmd (13, 0L, 0x01);
	k = sd_next (1);
	cs_high ();
	return r == 0 && k == 0 ? 0 : -1;
fail:
	cs_high ();
	return -1;
}

/* ---------------------------------------------------------------------
 * The card from nothing.  0, or -1.
 */
static int
sd_start ()
{
	int d, i, r, hcs;
	unsigned char csd [18];
	unsigned long sz;

	up = 0;
	if (! card ())
		return -1;
	outb (SSIOCON1, 0);
	outb (SSIOCON2, TXM);			/* never RXM: see the top */
	(void) inw (SSIORBUF);			/* clears RHBF */
	io.baud = BEN | BV_SLOW;
	cs_high ();
	(void) burst (ffbuf, xbuf, 10);		/* 160 clocks: a card wants 74 */

	for (d = 0; d < NPHD; d ++) {		/* a start delay CMD0 likes */
		io.phd = d;
		for (i = 0; i < 2; i ++) {
			cs_low ();
			r = sd_cmd (0, 0L, 0x95);
			cs_high ();
			if (r != 0x01)
				break;
		}
		if (i == 2)
			break;
	}
	if (d == NPHD) {
		printf ("mmc0: no answer to CMD0 at any start delay (R1 %x)\n",
			r & 0xFF);
		return -1;
	}

	hcs = 0;				/* CMD8: v2 echoes 1AA */
	cs_low ();
	r = sd_cmd (8, 0x1AAL, 0x87);
	if (r == 0x01 && sd_next (3) == 0x01 && sd_next (4) == 0xAA)
		hcs = 1;
	cs_high ();
	if (! hcs && (r < 0 || (r & 0x04) == 0)) {
		printf ("mmc0: CMD8 R1 %x %x %x %x %x\n", r & 0xFF,
			sd_next (1), sd_next (2), sd_next (3), sd_next (4));
		return -1;			/* neither v2 nor v1 */
	}

	for (i = 0; i < 200; i ++) {		/* ACMD41: 2s */
		cs_low ();
		r = sd_cmd (55, 0L, 0x01);
		cs_high ();
		if (r < 0 || r > 1) {
			printf ("mmc0: CMD55 R1 %x\n", r & 0xFF);
			return -1;
		}
		cs_low ();
		r = sd_cmd (41, hcs ? 0x40000000L : 0L, 0x01);
		cs_high ();
		if (r == 0)
			break;
		if (r != 1) {
			printf ("mmc0: ACMD41 R1 %x\n", r & 0xFF);
			return -1;
		}
		busyWait (NULL, 1);
	}
	if (i == 200) {
		printf ("mmc0: ACMD41: still not ready after 2s\n");
		return -1;
	}

	cs_low ();				/* CMD58: CCS */
	r = sd_cmd (58, 0L, 0x01);
	ccs = (sd_next (1) & 0x40) != 0;
	cs_high ();
	if (r != 0) {
		printf ("mmc0: CMD58 R1 %x\n", r & 0xFF);
		return -1;
	}
	if (! ccs) {				/* CMD16: 512-byte blocks */
		cs_low ();
		r = sd_cmd (16, 512L, 0x01);
		cs_high ();
		if (r != 0) {
			printf ("mmc0: CMD16 R1 %x\n", r & 0xFF);
			return -1;
		}
	}

	if (rd_xact (9, 0L, csd, 16) < 0) {	/* CMD9: the size */
		printf ("mmc0: the CSD would not read\n");
		return -1;
	}
	if ((csd [0] >> 6) == 1)		/* CSD 2.0 */
		sz = ((((unsigned long) csd [7] & 0x3F) << 16
		      | csd [8] << 8 | csd [9]) + 1) << 10;
	else {					/* CSD 1.0 */
		sz = ((((unsigned long) csd [6] & 3) << 10 | csd [7] << 2
		      | csd [8] >> 6) + 1)
		     << (((csd [9] & 3) << 1 | csd [10] >> 7) + 2);
		sz <<= (csd [5] & 0x0F) - 9;
	}
	for (i = 0; i <= NPARTN; i ++)
		pparm [i].p_base = pparm [i].p_size = 0;
	pparm [WHOLE].p_size = sz;

	r = io.phd;				/* the fastest that reads */
	for (i = 0; i < sizeof (bvlist); i ++) {
		io.baud = BEN | bvlist [i];
		for (d = 0; d < NPHD; d ++) {
			io.phd = d;
			if (sd_read (0L, secbuf) == 0) {
				up = 1;
				goto said;
			}
		}
	}
	io.baud = BEN | BV_SLOW;
	io.phd = r;
	up = 1;
said:	printf ("mmc0: %ld MB, %d kHz\n", (long) (sz >> 11),
		10000 / (2 * (io.baud & 0x7F) + 2));
	return 0;
}

/* ---------------------------------------------------------------------
 * The device.
 */
#define	part(dev)	((minor (dev) & XDEV) ? WHOLE : minor (dev) & 3)

static void
mmcload ()
{
	crcinit ();
	fill (cmdbuf, 0xFF, WINLEN);
	fill (ffbuf, 0xFF, sizeof (ffbuf));
}

static void
mmcunload ()
{
}

static void
mmcopen (dev, mode)
dev_t dev;
int mode;
{
	int p = part (dev);

	if ((minor (dev) & ~ (XDEV | 3)) != 0 || (minor (dev) & XDEV &&
	    minor (dev) & 3)) {
		set_user_error (ENXIO);
		return;
	}
	if (! card ()) {
		up = 0;
		set_user_error (ENXIO);
		return;
	}
	if (! up && sd_start () < 0) {
		printf ("mmc0: the card did not come up\n");
		set_user_error (EIO);
		return;
	}
	if (p == WHOLE)
		return;
	if (pparm [p].p_size == 0)
		(void) fdisk (makedev (MMC_MAJOR, XDEV), pparm);
	if (pparm [p].p_size == 0)
		set_user_error (ENXIO);
	else if (pparm [p].p_base + pparm [p].p_size > pparm [WHOLE].p_size)
		set_user_error (EINVAL);
}

static void
mmcclose (dev, mode)
dev_t dev;
int mode;
{
}

static void
mmcblock (bp)
BUF *bp;
{
	struct fdisk_s *pp = pparm + part (bp->b_dev);
	unsigned long bno;
	paddr_t addr;
	unsigned char *p;
	int n, t;

	bp->b_resid = bp->b_count;
	if (bp->b_req == BREAD && bp->b_bno == pp->p_size) {
		bdone (bp);			/* the end */
		return;
	}
	if (! card ())
		up = 0;
	if (! up || bp->b_bno + bp->b_count / BSIZE > pp->p_size
	 || bp->b_count % BSIZE != 0 || bp->b_count == 0) {
		bp->b_flag |= BFERR;
		bdone (bp);
		return;
	}
	bno = pp->p_base + bp->b_bno;
	addr = bp->b_paddr;
	for (n = bp->b_count / BSIZE; n > 0; n --) {
		for (t = 0; t < TRIES; t ++) {
			p = (unsigned char *) __PTOV (P2P (addr));
			if ((bp->b_req == BWRITE ? sd_write (bno, p)
						 : sd_read (bno, p)) == 0)
				break;
		}
		if (t == TRIES) {
			printf ("mmc0: %s block %ld failed\n",
				bp->b_req == BWRITE ? "write" : "read", bno);
			bp->b_flag |= BFERR;
			break;
		}
		bno ++;
		addr += BSIZE;
		bp->b_resid -= BSIZE;
	}
	bdone (bp);
}

static void
mmcread (dev, iop)
dev_t dev;
IO *iop;
{
	ioreq (NULL, iop, dev, BREAD, BFRAW | BFBLK | BFIOC);
}

static void
mmcwrite (dev, iop)
dev_t dev;
IO *iop;
{
	ioreq (NULL, iop, dev, BWRITE, BFRAW | BFBLK | BFIOC);
}

static void
mmcioctl (dev, cmd, vec)
dev_t dev;
int cmd;
char *vec;
{
	set_user_error (EINVAL);
}

CON mmccon = {
	DFBLK | DFCHR,			/* Flags */
	MMC_MAJOR,			/* Major index */
	mmcopen,			/* Open */
	mmcclose,			/* Close */
	mmcblock,			/* Block */
	mmcread,			/* Read */
	mmcwrite,			/* Write */
	mmcioctl,			/* Ioctl */
	NULL,				/* Powerfail */
	NULL,				/* Timeout */
	mmcload,			/* Load */
	mmcunload,			/* Unload */
	NULL				/* Poll */
};
