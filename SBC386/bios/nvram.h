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
