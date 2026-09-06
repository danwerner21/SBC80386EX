/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; getline.c -- get an ASCII line
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
#include "ascii.h"
#include "cprintf.h"
#define XXX
#include "bda.h"
#include "nvram.h"


#define putchar(x) VIDEO_putchar((x),7)
#define getchar(x) KBD_getchar()

int is_print(int ch)
{
	if (ch < ASCII_SP || ch >= ASCII_DEL) return 0;
	return 1;
}

void putline(char *str)
{
	while (*str) {
		putchar(*str);
		++str;
	}
}

int getline(char *buffer, int length)
{  /* length is size of buffer; string returned will be length-1 or less */
   int n = 0;
   int ch = ASCII_SP;
   
   length--;	/* account for terminating NUL */
   while (n < length) {
      ch = getchar();
      if (is_print(ch)) buffer[n++] = ch;
      else {
         switch (ch) {
         case ASCII_NL:
            putchar((char)ch);
            buffer[n] = 0;
            return n;
         case ASCII_DEL:
         case ASCII_BS:
            if (n > 0) {
               putline("\010\040\010");
               --n;
            }
            break;
         case ASCII_HT:
            putchar(ASCII_SP);
            buffer[n++] = ASCII_SP;
            break;
         case ASCII_CTRLU:
         case ASCII_CTRLX:
            while (n) {
               putline("\010\040\010");
               --n;
            }
            break;
         default:
            putchar(ASCII_BEL);
         }
      }   
      if (n == length) {
         putchar(ASCII_BEL);
         putchar(ASCII_BS);
         --n;
      }
   }
   return n;
}
