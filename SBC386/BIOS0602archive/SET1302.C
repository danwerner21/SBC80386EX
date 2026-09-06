/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; set1302.c -- set charging for the DS1302 Clk/Cal/NVRAM chip
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
#include "getline.h"
#include "nvram.h"


#define Rnone	0
#define R2k		1
#define R4k		2
#define R8k		3
#define Diode2	(2<<2)
#define Diode1	(1<<2)
#define Enable	0xA0
#define Disable	0x00

#define SC43	(Enable | Diode1 | R4k)
#define NC36	(Enable | Diode2 | R4k)

#define NCHG 3

const char * const name[NCHG] = {
	 "Non-rechargeable"	,
	 "Super-Cap 4.3v"	,
	 "NiCad/NiMN 3.6v"
};
const byte value[NCHG] = { Disable, SC43, NC36 };

#if 0
const struct CHG {
	const word value;
	const char * const name;
} charge[NCHG+1] = {
	{	Disable,	"Non-rechargeable"	},
	{	SC43,		"Super-Cap 4.3v"	},
	{	NC36,		"NiCad/NiMN 3.6v"	},
};
#endif

int option_get(char *title, char const *const *choice, word nchoice);
void set_chg(void);


#define N 16
int option_get(char *title, char const *const *choice, word nchoice)
{
/* option_get always returns:
	0 if one of [ESC, CR, LF] was encountered
	1..nchoice if '1'..'n' was typed  (9 choices max.)
*/
	int i;
	int opt = 0;
//	char cbuf[N];
	int ch;

	while (opt==0) {
		printf("\n%s:\n", title);
		for (i=0; i<nchoice; i++) {
			printf("%5d. %s\n", i+1, choice[i]);
		}
		printf("Choice: ");
		ch = getchar();
		if (is_print(ch)) {
			printf("%c\n", ch);
			opt = ch - '0';
		} else {
			printf("\n");
			break;
		}
		if (opt<1 || opt > nchoice) opt = 0;
	}
	return opt;
}


VOID set_chg(void)
{
	int opt;

	opt = option_get(
		"DS1302 battery backup",
		name, NCHG
		);
//	printf(" option = %d\n", opt);
	if (opt) {
		opt = value[opt-1];
		_asm {
			mov	ax,[opt]
			mov	ah,0x23
			int 0x1A
		}
//		printf("  charge param = %02xh\n", opt);
	}
}


char const * const top_name[] = {
	"Fixed Disks"		,
	"Floppy Disks"		,
	"RS-232 Serial"		,
	"Clock/Calendar"
};

VOID set_top(void)
{
	int opt;

	do {
		opt = option_get(
			"SBC-386EX system setup",
			top_name, nelem(top_name)
			);
		switch(opt) {
			case 1:
				set_fixed();
				break;
			case 2:
				set_floppy();
				break;
			case 3:
				set_serial();
				break;
			case 4:
				set_clock();
				break;
		}
	} while(opt);

}

VOID set_fixed(void)
{
	printf("Fixed disk setup is not implemented\n");
}
VOID set_floppy(void)
{
	printf("Floppy disk setup is not implemented\n");
}
VOID set_serial(void)
{
	printf("Serial setup is not implemented\n");
}
VOID set_clock(void)
{
	printf("Date/Time setup is being implemented\n");
}

