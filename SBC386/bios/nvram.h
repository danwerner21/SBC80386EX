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
VOID set_clock(void);
VOID set_time(void);
VOID set_date(void);
VOID set_chg(void);

#endif
