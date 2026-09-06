/* serial.h */
#ifndef __SERIAL_H
#define __SERIAL_H 1

/*enum {SERIAL_8250=1, SERIAL_Z180_0, SERIAL_Z180_1};*/
enum {BITS_NONE, BITS_6, BITS_7, BITS_8};
enum {B_110, B_150, B_300, B_600, B_1200, B_2400, B_4800, B_9600=7,
		B_19200, B_38400, B_56000_57600, B_115200, B_230400=12,
		B_460800_500000, B_1000000, B_1500000};
enum {PARITY_NONE, PARITY_ODD=1, PARITY_EVEN=3, PARITY_MARK=5, PARITY_SPACE=7};

typedef
struct CONFIG_SERIAL {			/* bits are positioned for 8250/16550 */
	word	nbits		: 2;	/* 0=not used, 1=6bits, 2=7 bits, 3=8bits */
	word	stop		: 1;	/* 0=1 stop bit, 1=2 stop bits */
	word	parity		: 2;	/* per ENUM above    */
	word	baud		: 5;	/* enumerated baud rates */
	word	reserved	: 4;	/* MBZ = must be zero*/
	word	xon_xoff	: 1;	/* use XON/XOFF protocol */
	word	rts_cts		: 1;	/* use RTS/CTS protocol */
} T_CONFIG_SERIAL;

/*				0 0 0000 00_111 00 0 11		*/
#define SIO0_INIT0 0x00E3u

#endif
