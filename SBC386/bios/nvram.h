/* nvram.h */

#ifndef __NVRAM_H
#define __NVRAM_H
#include "mytypes.h"
#define XXX
#include "bda.h"
#undef XXX
#include "serial.h"


extern T_BDA* bda_ptr;
#define bda (*bda_ptr)

#define NDISKS nelem(bda.disk_tab)

enum {	FX_NONE, FX_uSD,	/* not paired -- micro SD on-board	*/
		FX_SD0, FX_SD1,		/* paired -- Dual SD card add-on	*/
		FX_IDEm, FX_IDEs,	/* paired -- on-board IDE i/f		*/

		FX_END				/* not paired						*/
	};


/* Floppy drive types.
 *
 * These are the PC/AT CMOS values and the numbering is deliberate, not
 * arbitrary: INT 13h AH=08h hands the type back in BL and software has
 * recognised these particular numbers since 1984.
 *
 * Type 5, the 2.88Mb drive, is absent on purpose -- it needs a 1 Mbps data
 * rate and the FDC9266 on the Disk I/O board does not reach it.
 *
 * There is no way to detect what is plugged into a PC floppy cable, which
 * is why this is a SETUP question rather than something POST works out.
 */
enum {	FD_NONE,	/* 0				*/
	FD_360,		/* 1   360Kb  5.25"  40 trk   9 sec  250 kbps	*/
	FD_1200,	/* 2  1.2Mb   5.25"  80 trk  15 sec  500 kbps	*/
	FD_720,		/* 3   720Kb  3.5"   80 trk   9 sec  250 kbps	*/
	FD_1440,	/* 4  1.44Mb  3.5"   80 trk  18 sec  500 kbps	*/

	FD_END
	};

#define NFLOPPY nelem(bda.floppy_tab)


/* Boot order, in bda.boot_order and inside the NVRAM checksum.
 *
 * Zero has to mean the order the board already used, because that is what
 * every NVRAM written before this field existed carries -- the byte comes
 * out of nvram_unused, which has always been zero.  A board upgraded to
 * this BIOS therefore keeps behaving as it did, without anyone having to
 * visit SETUP first.
 *
 * Floppy-then-fixed is also the right default on its own merits: it is what
 * a PC has always done, and it is the order that lets a bad fixed disk be
 * repaired rather than merely reported.
 */
enum {	BOOT_AC,	/* 0  floppy, then the fixed disk -- the PC's order */
	BOOT_CA,	/* 1  fixed disk, then the floppy                    */
	BOOT_A,		/* 2  floppy only                                    */
	BOOT_C,		/* 3  fixed disk only                                */

	BOOT_END
	};


/* Which console INT 10h drives, in bda.console_sel and inside the same
 * NVRAM checksum, carved from nvram_unused for the same reason: zero is
 * what every NVRAM written before this field existed carries, so zero has
 * to mean what the board did before there was a choice -- both at once.
 *
 * The choice is worth having because the two consoles are not equal in
 * cost.  With both selected every character also goes out the UART, and at
 * 9600 baud that is a millisecond each, so the display runs no faster than
 * the serial line however quick the video path is.  Selecting video alone
 * is the way to get the board's real speed; selecting serial alone is for
 * running headless with a transcript.
 *
 * CONSEL_VIDEO falls back to serial when no board answers.  Without that,
 * choosing it and then pulling the card would leave a machine with no
 * console at all and no way into SETUP to undo it.
 */
enum {	CONSEL_BOTH,	/* 0  video and serial together -- what it did before */
	CONSEL_SERIAL,	/* 1  serial only, even with a board fitted           */
	CONSEL_VIDEO,	/* 2  video only, when a board answered              */

	CONSEL_END
	};


typedef
struct _NVRAM {
	T_CONFIG_SERIAL sio0;
	byte floppy_io[2];
	byte disk_io[NDISKS];
} T_NVRAM;



typedef
union {
	byte b[31];
	T_NVRAM nvram;
} T_NVRAM_UNION;


#define ASM   __asm
#define T_STR   const char * const

/* setup routines */

#define VOID void __pascal

int day_of_week(int AX, int DX, int BX, int CX);

int option_get(char *title, T_STR *choice, word nchoice);
VOID set_top(int modified);
int set_fixed(void);
int set_floppy(void);
int set_serial(void);
int set_boot(void);
VOID set_clock(void);
VOID set_time(void);
VOID set_date(void);
VOID set_chg(void);

#endif
