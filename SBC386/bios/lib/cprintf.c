/* Copyright (C) 1996 Robert de Bath <robert@mayday.compulink.co.uk>
 * This file is part of the Linux-8086 C library and is distributed
 * under the GNU Library General Public License.
 */

/* Modified 14-Jan-2002 by John Coffman <johninsd@san.rr.com> for inclusion
 * in the set of LILO diagnostics.  This code is the property of Robert
 * de Bath, and is used with his permission.
 */

/* Modified 14-Sep-2010 by John Coffman <johninsd@gmail.com> for use with
 * the N8VEM SBC-188 BIOS project.
 */

#include <stdarg.h>
#include <string.h>
#include "mytypes.h"
#include "cprintf.h"

/* the default attribute is '7' */
#define ATTRIBUTE 7
#define putch(ch) VIDEO_putchar((char)(ch), (char)attr)

#ifndef NULL
# define NULL ((void*)0L)
#endif

#define NUMLTH 11
static unsigned char * __fastcall __numout(long i, int base, unsigned char out[]);

#if 1
char __fastcall nstring(byte digit)
{
	if (digit < 10) return ('0'+digit);
	return (('A'-10)+digit);
}
#else
//const char nstring[]="0123456789ABCDEF";
#define nstring(d) (char)((d)+'0'+((d)<10?0:'A'-'0'))
#endif


int __cdecl cprintf(const char * fmt, ...)
{
	register int c;
	int count = 0;
	unsigned int type, base;
	long val;
	char * cp;
	char padch=' ';
	char attr = ATTRIBUTE;		/* default attribute */
	int  minsize, maxsize;
	unsigned char out[NUMLTH+1];
	va_list ap;

	va_start(ap, fmt);

	while(c=*fmt++)
	{
		count++;
		if(c!='%')
		{
			if (c=='\n') {
//		attr = ATTRIBUTE;
				putch('\r');
			}
			putch(c);
		}
		else
		{
			type=1;
			padch = *fmt;
			maxsize=minsize=0;
			if(padch == '-') fmt++;

			for(;;)
			{
				c=*fmt++;
				if( c<'0' || c>'9' ) break;
				minsize*=10; minsize+=c-'0';
			}

			if( c == '.' )
				for(;;)
				{
					c=*fmt++;
					if( c<'0' || c>'9' ) break;
					maxsize*=10; maxsize+=c-'0';
				}

			if( padch == '-' ) minsize = -minsize;
			else
			if( padch != '0' ) padch=' ';

			if( c == 0 ) break;
			if(c=='h')
			{
				c=*fmt++;
				type = 0;
			}
			else if(c=='l')
			{
				c=*fmt++;
				type = 2;
			}

//		jleds(c);
			switch(c)
			{
				case 'X':
				case 'x': base=16; type |= 4; goto next1;
				case 'o': base= 8; type |= 4; goto next1;
				case 'u': base=10; type |= 4; goto next1;
				case 'd': base=-10;

				next1:
//			lites(8);
//			jleds(type);
#if 0
/* the Watcom C 1.9 compiler cannot handle the nested SWITCH statement */
					switch(type)
					{
		 				case 0: val=va_arg(ap, short);	break;
		 				case 1: val=va_arg(ap, int);	break;
		 				case 2: val=va_arg(ap, long);	break;
		 				case 4: val=va_arg(ap, unsigned short); break;
		 				case 5: val=va_arg(ap, unsigned int);	break;
		 				case 6: val=va_arg(ap, unsigned long);  break;
		 				default:val=0;
//								jledsh(val);
					}
#else
					if ( type < 2 )  val=va_arg(ap, short);
					else if ( (type-4) < 2 )  val=va_arg(ap, unsigned short);
					else if ( type < 7 ) val=va_arg(ap, long);
					else val = 0;
#endif

//			jleds((int)val);
//			lites(7);
					cp = __numout(val,base,out);
					goto next2;
				case 's':
						cp=va_arg(ap, char *);
				next2:
					count--;
//			jleds(0xA5);
					c = strlen(cp);
					if( !maxsize ) maxsize = c;
					if( minsize > 0 )
					{
				 		minsize -= c;
				 		while(minsize>0)
						{
							putch(padch);
							count++;
							minsize--;
						}
		 				minsize=0;
					}
					if( minsize < 0 ) minsize= -minsize-c;
					while(*cp && maxsize-->0 )
					{
				 		putch(*cp++);
				 		count++;
					}
					while(minsize>0) { putch(' '); count++; minsize--; }
					break;
				case 'c':
					putch(va_arg(ap, int));
					break;
				case 'a':
					if (minsize==0) attr = ATTRIBUTE;
					else if (minsize > 15) attr = 15;
					else attr = minsize;
					break;
				default:
					putch(c);
					break;
			}
		}
	}
	va_end(ap);
	return count;
}


static unsigned char *
__fastcall
__numout(long i, int base, unsigned char out[])
{
	int n;
	int flg = 0;
	unsigned long val;

	if (base<0)
	{
		base = -base;
		if (i<0)
		{
			flg = 1;
			i = -i;
		}
	}
	val = i;

	out[NUMLTH] = '\0';
	n = NUMLTH-1;
	do
	{
#if 1
		out[n--] = nstring((byte)(val % base));
		val /= base;
#else
		out[n--] = nstring[val % base];
		val /= base;
#endif
	}
	while(val);
	if(flg) out[n--] = '-';
	return &out[n+1];
}
