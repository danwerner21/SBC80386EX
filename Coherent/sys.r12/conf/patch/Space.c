/* Generated from Space.spc on Tue Jul 26 15:10:41 1994 PDT */
/*
 * Configurable information for the patch driver.
 *
 * SBC-386EX: the board kernel links no SCSI driver, so only the IDE
 * entries, and the installer's other variables, are left in the tables.
 */
#define __KERNEL__	1

#include <sys/patch.h>
#include <sys/compat.h>
#include <sys/con.h>
#include <kernel/param.h>

/*
 * These devices need deferred startup during installation.
 */
extern CON	atcon;	/* IDE hard disk. */

#define PATCHABLE_VAR(var)	{ STRING(var), &(var), sizeof(var) }
#define PATCHABLE_CON(var)	{ STRING(var), &(var) }

extern unsigned long _bar;
extern int ronflag;
extern unsigned long _entry;
extern int kb_lang;
extern int ATSREG;
extern short at_drive_ct;
extern int fl_dsk_ch_prob;

struct patchVarInternal	patchVarTable [] = {
	PATCHABLE_VAR(_bar),
	PATCHABLE_VAR(ronflag),
	PATCHABLE_VAR(_entry),
	PATCHABLE_VAR(kb_lang),
	PATCHABLE_VAR(ATSREG),
	PATCHABLE_VAR(at_drive_ct),
	PATCHABLE_VAR(fl_dsk_ch_prob)
};

int	patchVarCount = sizeof(patchVarTable)/sizeof(patchVarTable[0]);

struct patchConInternal	patchConTable [] = {
	PATCHABLE_CON(atcon)
};

int	patchConCount = sizeof(patchConTable)/sizeof(patchConTable[0]);
