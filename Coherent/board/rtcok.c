/*
 * rtcok -- exit 0 if a PC CMOS clock answers at ports 70h/71h, else 1.
 *
 * /etc/rc and /etc/brc set the date with /etc/ATclock, which reads
 * /dev/clock.  The kernel's clock read first waits for the update-in-
 * progress bit in register A to clear, up to 65536 tries of a write to
 * 70h and a read from 71h.  The SBC-386EX decodes neither port: each
 * access is a 209 ms bus-monitor timeout and reads FFh, so the bit never
 * clears and the wait lasts about seven and a half hours.
 *
 * Register D of an MC146818 reads 80h (valid RAM and time, the rest
 * zero); a port nobody answers reads FFh.  /dev/cmos reads one register
 * directly, with no wait loop, so this costs the SBC one timeout.
 *
 *	cc -o /etc/rtcok rtcok.c
 */

#include <stdio.h>

main()
{
	int fd;
	unsigned char d;

	if ((fd = open("/dev/cmos", 0)) < 0)
		exit(1);
	if (lseek(fd, 13L, 0) != 13L || read(fd, &d, 1) != 1)
		exit(1);
	exit(d == 0x80 ? 0 : 1);
}
