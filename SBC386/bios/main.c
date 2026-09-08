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
#include "hdinit.h"	/* hd_enumerate() */

void lites(int);
int install_SIO0(int);
void unmask_interrupt(int);
void testmain(void);
void kbd_init(void);	/* in 16h_kbd.asm */
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

/* The drive registration that used to sit here was inverted: it ran
   only when 'code' was non-zero, which is to say only when the NVRAM
   checksum was bad, the clock had stopped, or battery charging was
   disabled.  On a healthy board no disk was ever registered.
   hd_enumerate() in hdinit.c now does it unconditionally. */

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

	/* Bring up the video state.  Mode 3 with bit 7 set initialises the
	   BDA fields -- mode, columns, cursor table -- without clearing the
	   terminal, which already has POST output on it.

	   equip_flag bits 5:4 say which display the machine came up in;
	   10b is 80x25 colour, which is what INT 10h presents.  DOS reads
	   it to choose its initial mode. */
	ASM {
		mov	ax,0x0083
		int	0x10
	}
	bda.equip_flag = (bda.equip_flag & ~0x0030) | 0x0020;


	/* Set the keyboard ring buffer up and turn the SIO0 receive
	   interrupt on.  From here the UART is drained by the ISR the
	   moment a character arrives, so nothing may poll INT 14h for
	   input any more -- KBD_getchar goes through INT 16h instead. */
	kbd_init();


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

	/* Enumerate the fixed disks.
	 *
	 * This has to happen BEFORE set_top().  SETUP and the debug monitor
	 * both sit under it, and both want to talk to the disks -- with the
	 * enumeration after it, bda.hd_number was still 0 and INT 41h/46h
	 * still pointed at int_nop while the monitor was running, so every
	 * INT 13h call from there came straight back with INVALID_COMMAND.
	 */
	hd_enumerate();

/* NOW -- we may check for waiting input */

#define KEY_STRUCK 0x10

	/* Was the SETUP key struck while the licence scrolled past?
	   Ask INT 16h, not the line status: the receive interrupt has
	   already emptied the UART into the ring buffer, so INT 14h
	   would report nothing however hard the operator typed. */
	{
		word waiting = 0;

		ASM {
			mov	ah,1		; is a key waiting?
			int	0x16
			jz	no_setup_key
			mov	word ptr [waiting],1
		no_setup_key:
		}

		if (waiting) {
			getchar(0);
			printf("got a character\n");
			code |= KEY_STRUCK;
		}
	}

	if (code) set_top(code & ~KEY_STRUCK);
	else delay(20); /* delay 2.0 seconds */

	/* Boot.  INT 19h takes over the stack and does not return; anything
	   below here runs only if the vector was never set up. */
	ASM {
		int	0x19
	}

	printf("\nINT 19h returned -- nothing to boot.\n");
	return 8;
}
