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
*/
#define XXX
#include "mytypes.h"
#include "i386ex.h"
#include "cprintf.h"
#include "nvram.h"
#include "getline.h"

void lites(int);
int install_SIO0(int);
void unmask_interrupt(int);
void testmain(void);
void *ebda_alloc(word nbytes);
word uart_det(word sio_dev);

int	ds_read_reg(byte);



void install_serial_console(void)
{
	word status;
	T_NVRAM *pnvr = (void*)(bda.nvram_info);

#if 0
	if (pnvr->sio0.baud <= 7) {
		byte bits = bda.nvram_info[0];
		ASM {
			mov ah,0
			mov	al,[bits]
			xor dx,dx
			int 14h
			mov [status],ax
		}
	}
	else
#endif
	{
		word parity_stop = pnvr->sio0.stop;
		word nbits_baud = pnvr->sio0.baud | 0x300;
		ASM {
			mov ax,0x0400
			mov bx,[parity_stop]
			mov cx,[nbits_baud]
			xor dx,dx
			int 14h
			mov [status],ax
		}
//		lites(0xF);
	}
		printf("port status 0x%02x   modem status 0x%02x\n",
			(status>>8), (status&0xFF)   );
}


word __cdecl serial_port_status(int port)
{
	word status;
ASM	{
	mov	dx,[port]
	mov	ah,3
	int	0x14		; get status call
	mov	[status],ax
	}
	return status;
}



void delay(word tsec)	/* delay in tenths of a second */
{
	dword usec = tsec*100000ul;

	ASM {
		mov	ah,0x86
		mov dx,word ptr [usec]
		mov cx,word ptr [usec+2]
		int	0x15
	}
}

int _main_(int code)
{
	int i;
jleds(code);

#if 1
	if (code) {
		bda.disk_tab[0] = FX_IDEm;
	}
#endif

	i = RBR0;
#if 0
	if (uart_det(0x448)) i = 0x448;	/* MF/PIC used for console */
#endif
	i = install_SIO0(i);		/* was hex constant */
	if (i != 0) return i;

	install_serial_console(); /* install serial console on SIO(i) */

	if (sizeof(T_BDA) != 0x102) {
		printf("\"bda.h\" is the wrong size: %d\n", sizeof(T_BDA));
		return 0xF;
	}


	unmask_interrupt(0);	/* turn on the 18.2hz timer */
	pr_lic();	/* print the Copyright & GPL license */
	if (code==0) printf("Hit any key during text display/scroll to enter SETUP\n");

	delay(23);	/* delay 2.3 seconds */

	lites(0);		/* run with all lites off */

	i = bda.CPU_freq + 5;	/* round up */

	printf("CPU_clk %d.%02umhz  EquipFlag %04xh  ConvMem %dKb  ExtMem %uMb  SRAM %uKb\n",
			i / 1000u,
			(i/10u) % 100u,
			bda.equip_flag,
			bda.memory_size,
			bda.extended_memory / 1024u,
			(word)bda.SRAM_size
			);

#if 0
	cprintf("\n\nThe output routine \"cprintf\" is now attached to SIO0\n"
			"by a direct connection of VIDEO_putchar to the INT 14h write\n"
			"call.  VIDEO_putchar is in STUB.ASM.\n\n");
#else
	printf("\n");
#endif
	i = ds_read_reg(0x8F);	/* WP bit */
	printf("WP bit = %02xh\n", i);
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

/* NOW -- we may check for waiting input */

#define KEY_STRUCK 0x10

	if (serial_port_status(0) & 0x0100) {
		getchar(0);
		printf("got a character\n");
		code |= KEY_STRUCK;
	}

	if (code) set_top(code & ~KEY_STRUCK);
	else delay(20); /* delay 2.0 seconds */

	testmain();

	printf("\nShutdown.\n");
	return 8;
}
