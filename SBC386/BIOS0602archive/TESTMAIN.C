/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; testmain.c -- SBC386 collected tests
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

#define ALL 0
#define CPRINTF	ALL|0
#define C_DOW	ALL|0
#define TSET1	ALL|1
#define DOW		ALL|0
#define DAY_OF_WEEK ALL|0
#define T_IDE	ALL|1
#define TEQUIP	ALL|1
#define TICKER	ALL|0

void lites(int);
int install_SIO0(int);
void unmask_interrupt(int);
int _testide_(void);

extern T_BDA* bda_ptr;
#define bda (*bda_ptr)

int day_of_week(int AX, int DX, int BX, int CX);
int dow(int mo, int da, int ce, int yr);


#if C_DOW
int C_dow(int mo, int da, int ce, int yr)
{
	static const int tab[5] = {0, 31, 61, 92, 122};
	int d;

	mo = mo-3;	 /* make it zero based */
	if (mo < 0) {
		mo += 12;
		yr -= 1;
		if (yr < 0) {
			ce -= 1;
			yr = 99;
		}
	}
	d = da + ce*5 + ce/4;
	d += yr + yr/4;
	d += (mo/5)*6;
	d += tab[mo%5] + 2;

	return  d % 7;	  /* Sun==0, ..., Sat==6 */
}
#endif
#if TEQUIP

int	_cdecl equip_flag(void)
{
	int eflag;
_asm {
	int 0x11
	mov	[eflag],ax
}
	return eflag;
}

int _cdecl conv_mem(void)
{
	int mem;
_asm {
	int 0x12
	mov	[mem],ax
}
	return mem;
}
#endif

#if TICKER
#define NTICKS 500
dword _cdecl get_tick_count(void)
{
	dword ticks;

	_asm {
		xor	ah,ah
		int 1Ah
		mov word ptr [ticks+2],cx
		mov word ptr [ticks],dx
	}
	return ticks;
}
#endif

void testmain(void)
{
	int i;
	static const int bits[4]={5,6,7,8};
	static const char parity[] = "no?e?m?s";
 	int tries;


#if CPRINTF

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
#endif


#define sio ((T_NVRAM_UNION*)bda.nvram_info)->nvram.sio0

	i = ((T_NVRAM_UNION*)bda.nvram_info)->nvram.sio0.baud;
	printf("\nSIO0 default is %d%c%d at speed_index = %d\n",
		bits[sio.nbits], parity[sio.parity], sio.stop+1, sio.baud);


#if DAY_OF_WEEK

	day_of_week(0,0x1207,0,0x1941);
#endif

#if TSET1
	tries = 2;

	while (tries--) {
		printf("***\n");
		set_top();
		printf("###\n");
	}

#endif

#if DOW
	printf("\nUsing 'dow'\n");
	printf("4/11/2018 -> %d\n", dow(4,11,20,18));
	printf("1/01/1899 -> %d\n", dow(1,01,18,99));
	printf("1/01/1900 -> %d\n", dow(1,01,19,00));
	printf("1/01/1901 -> %d\n", dow(1,01,19,01));
	printf("12/7/1941 -> %d\n", dow(12,7,19,41));
	printf("9/11/2001 -> %d\n", dow(9,11,20,01));
	printf("1/01/1999 -> %d\n", dow(1,01,19,99));
	printf("1/01/2000 -> %d\n", dow(1,01,20,00));
	printf("1/01/2001 -> %d\n", dow(1,01,20,01));
#endif
#if DAY_OF_WEEK
	printf("\nUsing 'day_of_week'\n");
	printf("4/11/2018 -> %d\n", day_of_week(0,0x0411,0,0x2018));
	printf("1/01/1899 -> %d\n", day_of_week(0,0x0101,0,0x1899));
	printf("1/01/1900 -> %d\n", day_of_week(0,0x0101,0,0x1900));
	printf("1/01/1901 -> %d\n", day_of_week(0,0x0101,0,0x1901));
	printf("12/7/1941 -> %d\n", day_of_week(0,0x1207,0,0x1941));
	printf("9/11/2001 -> %d\n", day_of_week(0,0x0911,0,0x2001));
	printf("1/01/1999 -> %d\n", day_of_week(0,0x0101,0,0x1999));
	printf("1/01/2000 -> %d\n", day_of_week(0,0x0101,0,0x2000));
	printf("1/01/2001 -> %d\n", day_of_week(0,0x0101,0,0x2001));
#endif

#if T_IDE
{
	i=_testide_();
	printf("Return from '_testide_()' is = %d\n", i);
}
#endif

#if TEQUIP
{
	word equip = equip_flag();

	printf("\nConventional Memory available = %dK bytes\n", conv_mem() );

	if (!(equip&1)) printf("No ");
	else printf("%d ", ((equip>>6)&3)+1);
	printf("floppy drive(s) attached\n");

	if (!(equip&2)) printf("No ");
	printf("Math co-processor installed\n");

	printf("%d serial RS-232 port(s)\n", (equip>>9)&7 );

}
#endif

#if TICKER
	printf("\nTimer is ticking ...\n");
	i = NTICKS;
	do {
		dword x = get_tick_count();
		printf("%12lu\n", x);
	} while (--i);
	printf("Timer tick display terminated\n");
#endif
} /* end testmain.c */

