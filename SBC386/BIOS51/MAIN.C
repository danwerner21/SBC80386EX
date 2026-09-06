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

extern T_BDA* bda_ptr;
#define bda (*bda_ptr)

int _main_(int code)
{
	int i;
	static const int bits[4]={5,6,7,8};
	static const char parity[] = "no?e?m?s";


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

	printf("\n    Testing CPRINTF.C\n");
	printf("Char print:  A->%c\n", 'A');
	printf("String: hello->%s\n", "hello");
	printf("int print:  99->%d\n", 99);
	printf("short print:  332->%hd\n", 332);
	printf("int print:  -32 = %d\n", -32);
	printf("hex print:  -32=FFE0->%x\n", -32);
	printf("long int:  999999->%ld\n", 999999l);
	printf("long int:  -999799->%ld\n", -999799l);
	printf("hex long:  00400000->%08lx\n", (dword)bda_ptr);
	printf("all: %c %s %d %hd %d %x %ld %08lx\n",
		'A', "hello", 99, 332, -32, -32, 999999ul, (dword)bda_ptr);

#if 0
	i = ((T_NVRAM_UNION)bda.nvram_info).nvram.sio0.baud;



	printf("\nSIO0 default is %d%c%d at speed_index = %d\n",
		bits[sio.nbits], parity[sio.parity], sio.stop+1, sio.baud);
#endif

	return 8;
}
