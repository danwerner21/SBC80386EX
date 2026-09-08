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
*/
#include "mytypes.h"
#include "cprintf.h"
#include "nvram.h"
#include "hdinit.h"

#define ALL 0
#define CPRINTF	ALL|0
#define C_DOW	ALL|0
#define DOW		ALL|0
#define DAY_OF_WEEK ALL|0
#define T_IDE	ALL|0
#define TICKER	ALL|0
#define TICKER2	ALL|1
#define TMODEM	ALL|1
#define TSET1	ALL|0
#define TEQUIP	ALL|1
#define TVGA3	ALL|1
#define TCVDU	ALL|1
#define T4UART	ALL|1
#define THDINIT	ALL|0	/* now done by _main_() before INT 19h */


void lites(int);
void unmask_interrupt(int);
int _testide_(void);
int bcd2int(byte bcd);

extern T_BDA* bda_ptr;
#define bda (*bda_ptr)

int day_of_week(int AX, int DX, int BX, int CX);
int dow(int mo, int da, int ce, int yr);


#if TCVDU

const byte bitrev[16] = {0,8,4,12,2,10,6,14, 1,9,5,13,3,11,7,15};

byte cvdu_get(word addr)
{
	word dev = bda.vid_addr_chip;	/* address high */
	outp(dev+bitrev[2], addr);
	return inp(dev+bitrev[3]);
}

void cvdu_put(word addr, byte data)
{
	word dev = bda.vid_addr_chip;	/* address high */
	outp(dev+bitrev[2], addr);
	outp(dev+bitrev[3], data);
}

int test_cvdu(byte ecbdev)
{
	int present = 0;
	bda.vid_addr_chip = 0x400 + ecbdev;

	cvdu_put(00, 0x5A);
	cvdu_put(21, 0xC6);
	cvdu_put(13, 0xAC);

	present = (	(cvdu_get(00)==0x5A) &&
				(cvdu_get(21)==0xC6) &&
				(cvdu_get(13)==0xAC)  );

	return present;
}
#endif

#if TVGA3
byte vga_get(word addr)
{
	word dev = bda.vid_addr_chip + 5;	/* address high */
	outp(dev, addr>>8);
	outp(++dev, addr);
	return inp(++dev);
}

void vga_put(word addr, byte data)
{
	word dev = bda.vid_addr_chip + 5;	/* address high */
	outp(dev, addr>>8);
	outp(++dev, addr);
	outp(++dev, data);
}

int test_vga(byte ecbdev)
{
	int present = 0;
	bda.vid_addr_chip = 0x400 + ecbdev;

	vga_put(00, 0xA5);
	vga_put(11, 0xC6);
	vga_put(23, 0x5C);

	present = (	(vga_get(00)==0xA5) &&
				(vga_get(11)==0xC6) &&
				(vga_get(23)==0x5C)  );

	return present;
}

int test_vga_mem(byte ecbdev)
{
	int okay = 0;
	byte *vmem = (void*)(0xB800ul << 16);

	outp(0x404+ecbdev, 0x81);	/* enable memory at B800:xxxx */

	if (	vmem[00] == 0xA5	&&
			vmem[11] == 0xC6	&&
			vmem[23] == 0x5C	)		okay = 1;

	return okay;
}
#endif	/* TVGA3 */



#if T4UART
word uart_det(word dev);

int test_4uart(byte ecbdev)
{
	word dev;
	int i, okay;

	if ( (ecbdev & 0x1F) != 0 ) return 0;	/* uses 32 I/O locations */
	dev = 0x400+ecbdev;
	for (i=0; i<4; i++) {
		okay = uart_det(dev);
//		printf("uart_det(0x%x) -> %04x\n", dev, okay);
		if (okay == 0) return 0;
		dev += 8;
	}

	return okay;
}
#endif




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
ASM {
	int 0x11
	mov	[eflag],ax
}
	return eflag;
}

int _cdecl conv_mem(void)
{
	int mem;
ASM {
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

	ASM {
		xor	ah,ah
		int 1Ah
		mov word ptr [ticks+2],cx
		mov word ptr [ticks],dx
	}
	return ticks;
}
#endif

dword _cdecl set_tick_count(dword ticks)
{
	ASM {
		mov	dx,word ptr [ticks]
		mov	cx,word ptr [ticks+2]
		mov	ah,1
		int 1Ah
	}
	return ticks;
}


dword _cdecl get_time(void)
{
	dword time;
	ASM {
		mov	ah,2
		int	1Ah
		mov	word ptr [time+2],cx
		mov word ptr [time],dx
	}
	return time;
}


void testmain(void)
{
	int i;
	static const int bits[4]={5,6,7,8};
	static const char parity[] = "no?e?m?s";
 	int tries;

#if THDINIT
	/* Enumeration moved to _main_(): it has to happen on every
	   boot, not only when the self test is run. */
	hd_enumerate();
#endif


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
	printf("\nSIO0 is set:   %d%c%d at speed_index = %d (Setup %d.)\n",
		bits[sio.nbits], parity[sio.parity], sio.stop+1,
		sio.baud, sio.baud+1);


#if DAY_OF_WEEK

	day_of_week(0,0x1207,0,0x1941);
#endif

#if TMODEM
	{
		word status;
		ASM {
			mov ah,3
			xor dx,dx
			int 14h
			mov [status],ax
		}
		printf("\nPort status 0x%02x   Modem status 0x%02x\n",
			(status>>8), (status&0xFF)   );

	}
#endif


#if TSET1
	tries = TSET1;

	while (tries--) {
		printf("***\n");
		set_top(1);
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
{
	int hrs, mins, secs;
	printf("\nTimer is ticking ...\n");
#if TICKER2
	{
		dword bcd_time = get_time();
		hrs = bcd2int(bcd_time>>24);
		mins = bcd2int(bcd_time>>16);
		secs = bcd2int(bcd_time>>8);
		printf(" h=%d m=%d s=%d\n", hrs, mins, secs);
		bcd_time = (dword)(secs + 60ul*(mins + 60*hrs));
		bcd_time = (1573050ull * bcd_time)/86400ull;
		printf("ticks = %lu\n", bcd_time);
		set_tick_count(bcd_time);
	}
#endif
	i = NTICKS;
	do {
		dword x = get_tick_count();
		printf("%12lu\n", x);
	} while (--i);
	printf("Timer tick display terminated\n");
#if TICKER2
 	printf(" h=%d m=%d s=%d\n", hrs, mins, secs);
#endif
}
#endif

#if T4UART
{
	word uart4;
	for (uart4 = 0x00; uart4 < 0xF0; uart4 += 0x20) {
		if (test_4uart(uart4))
			printf("4UART board found at 0x4%02x\n", (int)uart4);
	}
}
#endif

#if TVGA3
{
	word vga_dev = 0;

	if (test_vga(0xE8)) printf("VGA3 found at 0x4E8\n"), vga_dev = 0xE8 ;
	if (test_vga(0xE0)) printf("VGA3 found at 0x4E0\n"), vga_dev = 0xE0 ;
	if (test_vga(0xD8)) printf("VGA3 found at 0x4D8\n"), vga_dev = 0xD8 ;
	if (test_vga(0xF0)) printf("VGA3 found at 0x4F0\n"), vga_dev = 0xF0 ;

	if (vga_dev) {
		printf("VGA3 direct access to video memory%soperable.\n",
			test_vga_mem(vga_dev) ? " " : " not ");
	}
}
#endif
#if TCVDU
{
	if (test_cvdu(0xC0)) printf("CVDU found at 0x4E8\n");
	if (test_cvdu(0xD0)) printf("CVDU found at 0x4D8\n");
	if (test_cvdu(0xE0)) printf("CVDU found at 0x4E0\n");
	if (test_cvdu(0xF0)) printf("CVDU found at 0x4F0\n");
}
#endif


} /* end testmain.c */
