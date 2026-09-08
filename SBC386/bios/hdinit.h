/* hdinit.h -- IDE interface reset, IDENTIFY, and drive enumeration */
#ifndef __HDINIT_H
#define __HDINIT_H 1

#include "mytypes.h"

/* "disktab.h" carries no include guard of its own and opens with the
   bare XXX marker that copt uses when it generates disktab.inc, so it
   is wrapped here rather than included directly. */
#ifndef __DISKTAB_INCLUDED
#define __DISKTAB_INCLUDED 1
#define XXX
#include "disktab.h"
#undef XXX
#endif

/*
 * Where the SETUP geometry overrides live: the first four spare bytes
 * of the 31-byte NVRAM block, two per unit -- heads then sectors.  A
 * heads value of zero means no override for that unit.
 *
 * nvram_unused[] has 17 bytes, so there is room for six more drives
 * before this becomes a problem.
 */
#define HD_GEO_NVRAM	0

/* hd_probe() results */
#define HD_ABSENT	0
#define HD_ATA		1
#define HD_ATAPI	2
#define HD_UNKNOWN	3

int  hd_reset(void);
int  hd_probe(int drive);
int  hd_present(int drive);
int  hd_set_8bit(int drive);
int  hd_identify(int drive, T_DISKTAB *dt);
int  hdinit(T_DISKTAB *tabs, int ntabs);
void hd_report(T_DISKTAB *tabs, int n);

/* Enumerate, publish to the BDA, and point INT 41h/46h at the tables */
void hd_enumerate(void);

/* IDENTIFY data arrives byte-swapped -- see the note in hdinit.c */
word  id_word(byte *b, int n);
dword id_dword(byte *b, int n);

#endif	/* __HDINIT_H */
