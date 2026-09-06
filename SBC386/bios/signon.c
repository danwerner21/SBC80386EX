/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; signon.c -- display notices at startup
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
;	SBC-386EX 2.0	production / January 2017
;
; Assembly by NASM 2.08 is preferred
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
*/
#include <string.h>
#include "mytypes.h"
#include "cprintf.h"
#include "nvram.h"

static
const
char license[] =
"\n"
"Copyright (C) 2018 John R. Coffman.  All rights reserved.\n"
"Provided for hobbyist use on the RetroBrew SBC-386EX board.\n"
"\n"
"This program is free software: you can redistribute it and/or modify\n"
"it under the terms of the GNU General Public License as published by\n"
"the Free Software Foundation, either version 3 of the License, or\n"
"(at your option) any later version.\n"
"\n"
"This program is distributed in the hope that it will be useful,\n"
"but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
"GNU General Public License for more details.\n"
"\n"
"You should have received a copy of the GNU General Public License\n"
"along with this program in the file COPYING in the topmost source\n"
"directory.  If not, see <http://www.gnu.org/licenses/>.\n"
"\n"
;


static
dword get_time(void)
{
	dword time;
ASM {
	mov ah,2
	int 0x1A
	mov	ah,dh
	mov word ptr [time+2],cx
	mov word ptr [time],ax
}
	return time;
}

static
dword get_date(void)
{
	dword date;
ASM {
	mov ah,4
	int 0x1A
	mov word ptr [date+2],cx
	mov word ptr [date],dx
}
	return date;
}

void pr_lic(void)
{
	char *ptr = (char*)(0xF000FFF5ul);
	char date[9];
	dword temp;

#if 0
	memcpy(date, ptr, 8);
#else
	{ int i;
		for (i=0; i<8; i++) date[i] = ptr[i];
	}
#endif
	date[8] = 0;


	printf(license);
	printf("Release: %s          Compiled:  " __DATE__ "  at  "
				__TIME__ "\n\n", date);
	temp = get_time();
	printf("            Boot at %02x:%02x:%02x",
		(byte)(temp>>24), (byte)(temp>>16), (byte)(temp>>8)    );
	temp = get_date();
	printf("  on  %02x/%02x/%04x\n\n",
		(byte)(temp>>8), (byte)temp, (word)(temp>>16)    );
}
