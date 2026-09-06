/*;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; strtobcd -- convert a string to an unsigned long BCD number
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;*/
#include <stdlib.h>		// for errno
//#include <stdio.h>
//#include <limits.h>
//#include <string.h>
#include "mytypes.h"
#define SP 040
#define HT 011
#define RUB 0377
/*
 *  cp is first advanced over whitespaces (SP or HT), then the conversion
 *  is done.
 *
 *  errno is set if an error occurs
 *
 */

int errno;		/* should be in stdlib */


static
char ndigit(char ch)
{
    register char c;

    c = ch;

    if (c >= '0' && c <= '9') c -= '0';
    else c = RUB;

//    printf("exit ndigit   c = %d\n", (int)c);
    return c;
}

unsigned long int strtobcd(const char *cptr, char **endptr)
{
    signed char sign = 0;
    unsigned long int  value = 0UL;
    char *cp;
    byte digit;
    unsigned long int  max;
    byte maxdigit;
	int radix = 10;

    cp = (char*)cptr;
    errno = 0;
    while (*cp == SP  ||  *cp == HT) ++cp;

    if (*cp == '-') sign = -1, ++cp;
    else if (*cp == '+') sign = 1, ++cp;

    digit = ndigit(*cp);
//    printf("stage 1   digit=%d\n", (int)digit);

//    printf("stage 2   radix=%d\n", (int)radix);
    if (digit >= radix) {	/* invalid digit */
        cp = (char*)cptr;
        errno = 1;
    }
    else {
//        printf("stage 3\n");
        max = 0x09999999UL;
		maxdigit = 9;

//        printf("stage 4\n");
        value = digit;
        while ( (digit = ndigit(*++cp)) != RUB) {
            if (digit < radix  &&  (value < max ) ) {
				value <<= 4;
                value += digit;
            }
            else {
                errno = 1;
                value = 0;
                ++cp;
            }
        }
        --cp;
        if (sign<0) value = 0x99999999UL - value;	/* 9's complement */
    }
    if (endptr) *endptr = ++cp;

    return value;
}
