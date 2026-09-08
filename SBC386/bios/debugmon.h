/* debugmon.h */
#ifndef __DEBUGMON_H
#define __DEBUGMON_H 1

#include "mytypes.h"

/*
 * Register set handed to and returned from the GO command.
 * The member order is fixed: go_call() in monitor.asm indexes it by
 * word offset.  AX +0, BX +2, CX +4, DX +6, SI +8, DI +10,
 * DS +12, ES +14, FLAGS +16.
 */
typedef
struct _REGS {
	word	ax, bx, cx, dx;
	word	si, di;
	word	ds, es;
	word	flags;
} T_REGS;

extern void debugmon(void);
extern void DumpMemory(dword start, dword end);
extern void DumpBDA(void);
extern void DumpIdentify(int drive);
extern void DumpSector(dword lba, int drive);

/* in sizer.asm -- enters Protected Mode to reach all of physical memory */
extern void __cdecl pm_read(dword linear, byte *dest, word count);

/* in monitor.asm -- FAR CALL an arbitrary Real Mode address */
extern void __cdecl go_call(word seg, word off, T_REGS *regs);

#endif
