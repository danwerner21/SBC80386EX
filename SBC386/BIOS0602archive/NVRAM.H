/* nvram.h */

#ifndef __NVRAM_H
#define __NVRAM_H
#include "mytypes.h"
#include "serial.h"


#define NDISKS 8



typedef
struct _NVRAM {
	T_CONFIG_SERIAL sio0;
	byte disk_io[NDISKS];
} T_NVRAM;



typedef
union {
	byte b[31];
	T_NVRAM nvram;
} T_NVRAM_UNION;
	


/* setup routines */

#define VOID void

VOID set_top(void);
VOID set_fixed(void);
VOID set_floppy(void);
VOID set_serial(void);
VOID set_clock(void);

VOID set_chg(void);

#endif
