/* strtoint.c -- hexadecimal string to unsigned long
 *
 * Adapted from strtobcd().  Space, tab and ':' are delimiters: they are
 * eaten ahead of the number and terminate it, so successive calls walk a
 * command line without the caller stepping over separators.
 *
 *      cp = line;
 *      fromSeg = (unsigned int)strtoint( cp, &cp );
 *      fromOff = (unsigned int)strtoint( cp, &cp );
 *
 * parses "F000:FFF0", "f000 fff0" and " F000 : FFF0 " identically.
 *
 * On a malformed or overflowing token errno is set to 1 and 0 is returned.
 * A valid "0" also returns 0, so check errno if you need to tell them apart.
 */
#include <stdlib.h>		// for errno
#include "mytypes.h"

/*
 * Character to value.  Returns RUB for anything that is not a hex digit,
 * which is also what terminates the scan.
 */


static byte hexdigit( char c )
{
    if( c >= '0' && c <= '9' ) return( (byte)(c - '0') );
    if( c >= 'A' && c <= 'F' ) return( (byte)(c - 'A' + 10) );
    if( c >= 'a' && c <= 'f' ) return( (byte)(c - 'a' + 10) );
    return( 0x11 );
}

unsigned long int strtoint( const char *cptr, char **endptr )
{
    signed char         sign = 0;
    unsigned long int   value = 0UL;
    char                *cp;
    byte                digit;

    cp = (char *)cptr;
    errno = 0;

    /* Eat leading whitespace and delimiters. */
    while( *cp == ' ' || *cp == 0x09 || *cp == ':' ) ++cp;

    if( *cp == '-' )      { sign = -1; ++cp; }
    else if( *cp == '+' ) { sign =  1; ++cp; }

    if( hexdigit( *cp ) == 0x11 ) {

        /* No digits at all.  Report failure and hand back the original
           pointer so the caller can see nothing was consumed. */
        cp = (char *)cptr;
        errno = 1;

    } else {

        while( (digit = hexdigit( *cp )) != 0x11 ) {

            /* Check before shifting: anything above 0x0FFFFFFF cannot
               take another nibble.  Keep scanning so endptr still lands
               past the whole token. */
            if( value > (0xFFFFFFFFUL >> 4) )
                errno = 1;
            else
                value = (value << 4) + (unsigned long int)digit;

            ++cp;
        }

        if( errno )
            value = 0UL;
        else if( sign < 0 )
            value = ~value + 1UL;       /* two's complement */
    }

    if( endptr ) *endptr = cp;

    return( value );
}
