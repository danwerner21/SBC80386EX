/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; main.c -- SBC386 top level C-code  called from  START.asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2018 John R. Coffman.  All rights reserved.
; Provided for hobbyist use on the RetroBrew SBC-386EX board.
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program in the file COPYING in the topmost source
; directory.  If not, see <http://www.gnu.org/licenses/>.
;
;
; SBC-386 board revisions:
;       SBC386-0   prototype / concept testing
;	SBC-386EX 2.0	production / January 2018
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "seg_def.inc"
%include "i386ex.inc"
%include "bda.inc"
%include "macro.inc"
*/
#define XXX
#include "mytypes.h"
#include "bda.h"
#include "cprintf.h"
#include "nvram.h"


void lites(int);
int install_SIO0(int);
void unmask_interrupt(int);
void testmain(void);


extern T_BDA* bda_ptr;
#define bda (*bda_ptr)


int _main_(int code)
{
	int i;

	if (code) {
		bda.nvram_info[0] = (byte)SIO0_INIT0;
		bda.nvram_info[1] = (byte)(SIO0_INIT0 >> 8);
	}

	i = install_SIO0(0x3F8);
	if (i != 0) return i;

	unmask_interrupt(0);	/* turn on the 18.2hz timer */
	pr_lic();	/* print the Copyright & GPL license */

	cprintf("\n\nThe output routine \"cprintf\" is now attached to SIO0\n"
			"by a direct connection of VIDEO_putchar to the INT 14h write\n"
			"call.  VIDEO_putchar is in STUB.ASM.\n\n");

	if (code & 1)
		printf("The NVRAM checksum is not valid.\n");
	if (code & 2)
		printf("The clock is stopped.\n");

	printf("DS1302 RTC/NVRAM backup battery charging is ");
	if (code & 4)
		printf("dis");
	else
		printf("en");
	printf("abled.\n");

	testmain();

	return 8;
}
