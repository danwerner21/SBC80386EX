/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; TESTIDE.c -- SBC386 IDE TEST CODE  called from  START.asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Copyright (C) 2018 Dan Werner.  All rights reserved.
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
#include "bda.h"
#include "cprintf.h"
#include "nvram.h"

int IDE_READ_SECTOR(byte,byte far *, dword,byte);
int IDE_WRITE_SECTOR(byte,byte far *, dword,byte);
int IDE_READ_ID(byte,byte far *);
int IDE_INITIALIZE(byte);

int PrintBuffer(byte far *);
int ideerr(void);
int ClearBuffer(byte far *);
int BufferTestPattern(byte far *);

extern byte* SecBuffer;


int _testide_(void)
{
	cprintf("\n\nBegin Test IDE function\n");
	if(!IDE_INITIALIZE(0))
	{
		cprintf("Initialized Primary IDE Drive\n");
	}
	else
	{
		ideerr();
	}


	cprintf("Get IDE Drive Info into address %08lx\n",SecBuffer);
	if(!IDE_READ_ID(0,SecBuffer))
	{
		cprintf("Retrieved IDE Drive Info\n");

		SecBuffer[40]=0;
		cprintf("IDE SERIAL NUMBER: %s\n",SecBuffer+20);
		SecBuffer[94]=0;
		cprintf("IDE MODEL NUMBER: %s\n",SecBuffer+54);
		SecBuffer[54]=0;
		cprintf("IDE FIRMWARE REVISION: %s\n",SecBuffer+46);

		if((SecBuffer[98] & 1)!=0)
		{
			cprintf("DRIVE SUPPORTS DMA.\n");
		}
		else
		{
			cprintf("DRIVE DOES NOT SUPPORT DMA.\n");
		}

		if((SecBuffer[98] & 2)!=0)
		{
			cprintf("DRIVE SUPPORTS LBA.\n");
		}
		else
		{
			cprintf("DRIVE DOES NOT SUPPORT LBA.\n");
		}

		if((SecBuffer[167] & 4)!=0)
		{
			cprintf("DRIVE SUPPORTS CFA EXTENSIONS (8-BIT).\n");
		}
		else
		{
			cprintf("DRIVE DOES NOT SUPPORT CFA EXTENSIONS (8-BIT).\n");
		}
	}
	else
	{
		ideerr();
	}


	cprintf("Test Read of 1 LBA sector 0 into address %08lx\n",SecBuffer);
	if(!IDE_READ_SECTOR(0,SecBuffer,(dword)0,1))
	{
    	PrintBuffer(SecBuffer);
	}
	else
	{
		ideerr();
	}


	cprintf("Test Read of LBA sector 1 into address %08lx\n",SecBuffer);
	if(!IDE_READ_SECTOR(0,SecBuffer,(dword)1,1))
	{
    	PrintBuffer(SecBuffer);
	}
	else
	{
		ideerr();
	}


    cprintf("Test Read of LBA sector 100 into address %08lx\n",SecBuffer);
	if(!IDE_READ_SECTOR(0,SecBuffer,(dword)100,1))
	{
    	PrintBuffer(SecBuffer);
	}
	else
	{
		ideerr();
	}


	cprintf("Test Read of 2 LBA sectors 0+1 into address %08lx\n",SecBuffer);
	if(!IDE_READ_SECTOR(0,SecBuffer,(dword)0,2))
	{
    	PrintBuffer(SecBuffer);
    	PrintBuffer(SecBuffer+512);
	}
	else
	{
		ideerr();
	}


	cprintf("Clear buffer @ address %08lx\n",SecBuffer);
	ClearBuffer(SecBuffer);
	PrintBuffer(SecBuffer);
	cprintf("Place Test Pattern  @ address %08lx\n",SecBuffer);
	BufferTestPattern(SecBuffer);
	PrintBuffer(SecBuffer);

	cprintf("WRITE Test Pattern  @ address %08lx to LBA SECTOR 100\n",SecBuffer);
	if(IDE_WRITE_SECTOR(0,SecBuffer,(dword)100,1))
	{
		ideerr();
	}

	cprintf("Test Read (Test Pattern) of LBA sector 100 into address %08lx\n",SecBuffer);
	if(!IDE_READ_SECTOR(0,SecBuffer,(dword)100,1))
	{
    	PrintBuffer(SecBuffer);
	}
	else
	{
		ideerr();
	}

	cprintf("Clear buffer @ address %08lx\n",SecBuffer);
	ClearBuffer(SecBuffer);
	PrintBuffer(SecBuffer);

	cprintf("WRITE zeros Pattern  @ address %08lx to LBA SECTOR 100\n",SecBuffer);
	if(IDE_WRITE_SECTOR(0,SecBuffer,(dword)100,1))
	{
		ideerr();
	}

	cprintf("Test Read (Zeros) of LBA sector 100 into address %08lx\n",SecBuffer);
	if(!IDE_READ_SECTOR(0,SecBuffer,(dword)100,1))
	{
    	PrintBuffer(SecBuffer);
	}
	else
	{
		ideerr();
	}

	cprintf("END OF IDE TEST.\n");

	return 8;
}


int PrintBuffer(byte far *SecBuffer)
{
   int count=0;
   int count1=0;

   cprintf("\nBUFFER->%08lx\n",SecBuffer);

   for(count=0;count<512;count++)
   {
   		cprintf("%04x ",count);
   		for(count1=0;count1<16;count1++)
   			cprintf("%02x ",*(SecBuffer+count+count1));

   		cprintf("-");
		for(count1=0;count1<16;count1++)
		{
			if((*(SecBuffer+count)>31) && (*(SecBuffer+count)<128))
			{
   				cprintf("%c",*(SecBuffer+count));
   			}
   			else
			{
   				cprintf(".");
   			}
   			count++;
		}
		cprintf("\n");
		count--;
	}

	cprintf("\n");
	return 0;
}


int ClearBuffer(byte far *SecBuffer)
{
   int count=0;

   cprintf("\nCLEAR BUFFER->%08lx\n",SecBuffer);
   for(count=0;count<512;count++) *(SecBuffer+count)=0;

   return 0;
}

int BufferTestPattern(byte far *SecBuffer)
{
   int count=0;

   cprintf("\nWRITE TEST PATTERN TO BUFFER->%08lx\n",SecBuffer);
   for(count=0;count<512;count++) *(SecBuffer+count)=(count & 0xFF);

   return 0;
}

int ideerr()
{
	cprintf("IDE I/O Error\n");
	return -1;
}
