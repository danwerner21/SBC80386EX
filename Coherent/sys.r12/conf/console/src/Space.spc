/*
 * Configurable information for the console driver(s).
 */

#define __KERNEL__	 1

#include <sys/kb.h>
#include "conf.h"

int		kb_lang = kb_lang_us;

/* Number of virtual console sessions on monochrome display. */
int		mono_count = MONO_COUNT;	/* Tunable */

/* Number of virtual console sessions on color display. */
int		vga_count = VGA_COUNT;		/* Tunable */

/* Greek keyboard option in vtnkb - 1=enabled, 0=disabled. */
int		VTGREEK = VTGREEK_SPEC;

int		sep_shift = 0;

/* Console beeps on <Ctrl-G>; 1=beeps, 0=no beeps. */
int		con_beep = 1;

/*
 * SBC-386EX: where the console hardware is, and whether it is there.
 * The defaults are a PC's.  For the ECB VGA3: CON_VGA 2 (use it only if
 * the BIOS found it: CON_VIDEO in bda.console), CON_CRTC 0x4E2 (HD6445),
 * CON_CGA 0 (no CGA mode/border/status registers), KB_DATA 0x4E0 and
 * KB_STAT 0x4E1 (the 8242), KB_XT 0 (no XT acknowledge through 61h),
 * KB_SPKR 0 (no PC speaker).
 */

unsigned	CON_VGA = CON_VGA_SPEC;	/* 0 never, 1 always, 2 if the BIOS found it */
unsigned	CON_CRTC = CON_CRTC_SPEC;	/* CRTC index port; 0: 3D4h/3B4h as a PC */
unsigned	CON_CGA = CON_CGA_SPEC;	/* nonzero: CGA/MDA registers exist */
unsigned	KB_DATA = KB_DATA_SPEC;	/* keyboard controller data port */
unsigned	KB_STAT = KB_STAT_SPEC;	/* ... status and command port */
unsigned	KB_XT = KB_XT_SPEC;	/* nonzero: XT acknowledge through 61h */
unsigned	KB_SPKR = KB_SPKR_SPEC;	/* nonzero: PC speaker through 61h */
