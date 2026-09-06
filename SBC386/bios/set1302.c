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
#include "mytypes.h"
#include "cprintf.h"
#include "strtobcd.h"
#include "nvram.h"
#include "getline.h"
#include "disk.h"



#define Rnone	0
#define R2k		1
#define R4k		2
#define R8k		3
#define Diode2	(2<<2)
#define Diode1	(1<<2)
#define Enable	0xA0
#define Disable	0x00

#define SC43	(Enable | Diode1 | R2k)
#define NC36	(Enable | Diode2 | R4k)

#define LINE 40
#define NCHG 3

T_STR name[NCHG] = {
	 "Non-rechargeable"	,
	 "Super-Cap 4.3v"	,
	 "NiCad/NiMH 3.6v"
};
const byte value[NCHG] = { Disable, SC43, NC36 };

/* procedure prototype */
word get_nvram_crc(int);
void put_nvram_info(void);



#define N 16
int option_get(char *title, const char *const *choice, word nchoice)
{
/* option_get always returns:
	0 if one of [ESC, CR, LF] was encountered
	1..nchoice if '1'..'n' was typed  (9 choices max.)
*/
	int i;
	int opt = 0;
	int ch;

	while (opt==0) {
		printf("\n%s:\n", title);
		for (i=0; i<nchoice; i++) {
			printf("%5d. %s\n", i+1, choice[i]);
		}
		printf("Choice: ");

		ch = getchar();
		if (is_print(ch)) {
			opt = ch - '0';
			putchar(ch);
			if (nchoice>9 && opt==1) {
				ch = getchar();
				if (is_print(ch)) {
					i = ch - '0';
					putchar(ch);
					opt = 10*opt + i;
				}
			}
			printf("\n");
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
	byte cur;

	ASM {
		mov	ah,0x24		;get charge parameter
		int 0x1A
		mov	[cur],al
	}
	for (opt=0; opt<nelem(value); ++opt) {
		if (value[opt]==cur) break;
	}
	printf("\nCurrently:  ");
	if (opt>=nelem(value))
		printf("<unknown>");
	else
		printf(name[opt]);

	opt = option_get(
		"DS1302 battery backup",
		name, NCHG
		);
//	printf(" option = %d\n", opt);
	if (opt) {
		opt = value[opt-1];
		ASM {
			mov ax,0x2200	;write protect off
			int 0x1A
			mov	ax,[opt]
			mov	ah,0x23
			int 0x1A
			mov ax,0x2280	;write protect on
			int 0x1A
		}
//		printf("  charge param = %02xh\n", opt);
	}
}


T_STR top_name[] = {
	"Fixed Disks"		,
	"Floppy Disks"		,
	"RS-232 Serial"		,
	"Date/Time/Battery"
};

VOID set_top(int modified)
{
	int opt, i;
	word temp;

	temp = get_nvram_crc(29);
//	printf("\nNVRAM calculated CRC = %04x   read CRC = %04x\n",
//					temp, bda.nvram_checksum);

	do {
		opt = option_get(
			"SBC-386EX system setup",
			top_name, nelem(top_name)
			);
		switch(opt) {
			case 1:
				modified |= set_fixed();
				break;
			case 2:
				modified |= set_floppy();
				break;
			case 3:
				modified |= set_serial();
				break;
			case 4:
				set_clock();
				break;
		}
	} while(opt);

	if (modified) {
#if 0
		for (i=0; i<31; i++) bda.nvram_info[i] = 0;
#endif
		temp = get_nvram_crc(29);
//		printf("\n2NVRAM calculated CRC = %04x   read CRC = %04x\n",
//					temp, bda.nvram_checksum);

		bda.nvram_checksum = temp;
		put_nvram_info();
		printf("\nReboot required!\n");
		temp = get_nvram_crc(31);
//		printf("\n3NVRAM calculated CRC = %04x   new read CRC = %04x\n",
//					temp, bda.nvram_checksum);

		exit(15);
	}
}


/* the following must correspond exactly with the ENUM in 'nvram.h' */
T_STR fixed_disks[] = {
	"None",
	"micro SD card",
	"dual SD slot 0",
	"dual SD slot 1",
	"local IDE master",
	"local IDE slave",
	};



int set_fixed(void)
{
	printf("\nFixed disk setup is not implemented\n");
	return 0;
}
int set_floppy(void)
{
	printf("\nFloppy disk setup is not implemented\n");
	return 0;
}



T_STR clock_name[] = {
	"Set Date"		,
	"Set Time"		,
	"Set Battery Charger",
};

VOID set_clock(void)
{
	int opt;

	do {
		opt = option_get(
			"Date/Time/Battery",
			clock_name, nelem(clock_name)
			);
		switch(opt) {
			case 1:
				set_date();
				break;
			case 2:
				set_time();
				break;
			case 3:
				set_chg();
				break;
		}
	} while(opt);
}


T_STR Day[7] = {
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
	};

VOID set_date(void)
{
	byte mo,da,yr,ce,dow,clk;
	char line[LINE], *cp;
	int temp,day,month,year;

	ASM {
		mov ah,4
		int	0x1A
		mov [ce],ch
		mov [yr],cl
		mov [mo],dh
		mov [da],dl
		dec	al
		mov [clk],al
		call day_of_week
		mov	[dow],al
	}
	printf("\nCurrently:  %s", Day[dow]);

	printf(" %02x/%02x/%02x%02x DOW=%d  clkDOW=%d\n", mo,da,ce,yr,dow,clk);

	do {
		dow = 99;
		printf("Update [mm/dd/yyyy]: ");
		if (!getline(line,LINE)) break;
		cp = line;

		temp = strtobcd(cp,&cp);
		if (temp && temp<0x13) mo = temp;
		else continue;

		temp = strtobcd(++cp, &cp);
		if (temp && temp<0x32) da = temp;
		else continue;

		temp = strtobcd(++cp, &cp);
		if (temp && temp>=0x1970 && temp<0x2070) {
			yr = (byte)temp;
			ce = (byte)(temp>>8);
		} else continue;

		year = bcd2int(yr);
		month = bcd2int(mo);
		day = bcd2int(da);
		temp = 0x28;
		if (year % 4 == 0) ++temp;
		if (month==2 && da>temp) continue;
		temp = 0x31;
		month -= 3;
		if (month<0) month += 12;
		month %= 5;
		if ( month & 1 ) --temp;
		if ( da>temp ) continue;

		dow = 1;
		printf(" %02x/%02x/%02x%02x\n", mo,da,ce,yr);

	/* Do the date set */
		ASM {
			mov	ah,5
			mov ch,[ce]
			mov cl,[yr]
			mov	dh,[mo]
			mov dl,[da]
			int 0x1A
		}
	} while (dow>=7);

}


VOID set_time(void)
{
	byte hr,min,sec,stop;
	char line[LINE], *cp;
	int temp;

	ASM {
		mov ah,2
		int 0x1A
		mov [hr],ch
		mov [min],cl
		mov [sec],dh
		lahf
		and ah,1
		mov	[stop],ah
	}
	printf("\nCurrent time:  %x:%02x:%02x    The clock is ", hr, min, sec);
	if (stop) printf("stopped\n");
	else printf("running\n");
	do {
		printf("Update [hh:mm[:ss]]: ");
		if (!getline(line,LINE)) break;
		cp = line;

		temp = strtobcd(cp,&cp);
		if (temp<0x24) hr = temp;
		else continue;

		if (*cp == ':') temp = strtobcd(++cp,&cp);
		else continue;
		if (temp<0x60) min = temp;
		else continue;

		if (*cp == ':') temp = strtobcd(++cp,&cp);
		else temp = 0;
		if (temp<0x60) sec = temp;
		else continue;

		ASM {
			mov ah,3
			mov	ch,[hr]
			mov cl,[min]
			mov dh,[sec]
			mov dl,0		; no DST in chip
			int 0x1A
		}

		stop = 2;
	} while (stop < 2);
}


T_STR speeds[] = {
	"110", "150", "300", "600", "1200", "2400", "4800",
	"9600", "19200", "38400", "56000/57600", "115200",
	"230400", "460800", };

int set_line_speed(T_CONFIG_SERIAL *line)
{
extern word sio_divisors[];
	int opt, modified=0;
	int n = nelem(speeds);
#define OSC (1843200ul*4/16)
//	dword div;

	if (line->clk_737 == 0) n -= 2;

	do {
//		div = (dword)sio_divisors[line->baud];

		printf("\nCurrent speed %lu bps", OSC/sio_divisors[line->baud] );
		opt = option_get(
			"Serial Line bits/second",
			speeds,  n);
		if (opt >= 1  &&  opt <= n) {
			line->baud = opt-1;
			printf("Set speed %lu bps\n", OSC/sio_divisors[opt-1] );
			modified = 1;
			break;
		}
	} while (opt);

	return modified;
}


T_STR stop_bits[] = {
	"1 bit",
	"2 bits"
};


int set_stop_bits(T_CONFIG_SERIAL *line)
{
	int opt, modified=0;

	do {
		printf("\nCurrent stop bits = %d", line->stop + 1);
		opt = option_get("Number of Stop Bits", stop_bits, nelem(stop_bits));
		if (opt > 0  &&  opt <=2) {
			line->stop = opt-1;
			modified = 1;
			break;
		}
	} while (opt);

	return modified;
}



T_STR char_char[] = {
	"8 bits, no parity",
	"7 bits, even parity",
	"7 bits, odd parity"
};

int set_char_format(T_CONFIG_SERIAL *line)
{
	int opt, modified=0;
	word nbits, parity;

	nbits = line->nbits + 5;
	parity = line->parity;

	do {
		printf("\nCurrently: %u bits, %s parity", nbits,
			parity==0 ? "no" : parity==1 ? "odd" : "even" );
		opt = option_get("Character Makeup", char_char, nelem(char_char));
		switch (opt) {
			case 1:
				parity = 0;	/* none */
				nbits = 3;
				modified = 1;
				break;
			case 2:
				parity = 3;	/* even */
				nbits = 2;
				modified = 1;
				break;
			case 3:
				parity = 1;	/* odd */
				nbits = 2;
				modified = 1;
				break;
		}
	} while (opt && !modified);

	if (modified) {
		line->nbits = nbits;
		line->parity = parity;
	}

	return modified;
}

T_STR serial[] = {
	"Line Speed"		,
	"Stop Bits"			,
	"#Bits/Parity"		,
	};

int set_serial(void)
{
	T_CONFIG_SERIAL *line;
	int opt, modified=0;

	line = (void*)bda.nvram_info;

	do {
		opt = option_get("Serial Setup",
			serial, nelem(serial) );
		switch (opt) {
			case 1:
				modified |= set_line_speed(line);
				break;
			case 2:
				modified |= set_stop_bits(line);
				break;
			case 3:
				modified |= set_char_format(line);
				break;
		}
	} while (opt);

	return modified;
}
