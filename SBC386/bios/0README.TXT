File:  0README.TXT

===============
Sat 13-Sep-2026
===============
DW:  Operating notes for the current ROM.

CONSOLE RESET -- three Ctrl-^ (1Eh) in a row, typed at the serial console,
restarts the board.  This is the machine's Ctrl-Alt-Del: a serial console
delivers characters rather than key events, so there is no Ctrl and no Alt
to press, and any sufficiently unlikely character sequence will do instead.

The three characters are eaten rather than passed to DOS, so a stray single
Ctrl-^ never reaches an application.  The restart goes through reboot_ in
19h_boot.asm and sets the warm-boot flag at 40:72, which means POST skips
the memory march -- power-cycle instead when a full memory test is wanted.

Ctrl-^ was chosen over the more obvious Ctrl-] (1Dh) because Ctrl-] is the
telnet escape and would be swallowed by the terminal program before ever
reaching the board.  Ctrl-\ (1Ch) is SIGQUIT to a Unix terminal and was
rejected for the same kind of reason.  The character and the repeat count
are RESET_KEY and RESET_COUNT at the top of 16h_kbd.asm.

SETUP -- press any key during the POST scroll.  Entry 5 is the debug
monitor; type EXIT to leave it.  Monitor commands are UPPER CASE, and every
numeric argument is hexadecimal.

HIMEM.SYS -- must be loaded with /MACHINE:PS2.  Without it the machine locks
up in CONFIG.SYS.  HIMEM drives the A20 line through the 8042 keyboard
controller on an AT, and this board has no 8042; the read of port 64h
returns floating-bus FF and HIMEM spins forever.  A20 here is the 386EX
PORT92, enabled once at POST.

ECB I/O ADDRESSING -- Z80 I/O port N appears to the 386EX at 0x400 + N, as
the 13-May-2018 entry below describes for the MF/PIC.  An ECB card jumpered
to Z80 30h-3Fh is therefore at 0x430-0x43F.


===============
Sun 13-May-2018
===============
JRC:  After the disaster with the orginal DRAM board, and with no
working UART on the replacement, the serial console will be on the
MF/PIC board if it is present.  The board must be set for its default
location in Z80 I/O space:  0x40.  (board in portrait orientation,
jumpers set on,on,off,on)  The SBC386 device code will thus be 0x448,
0x400 to access the Z80 ECB bus, and +8 on-board offset for the UART.

Without the MF/PIC board installed, the 386EX on-board SIO0 will be
used as before.





===============
Fri 02-Mar-2018
===============
Save file 'EX2-30.zip' represents the first steps toward a real BIOS
ROM.  Notably, the assembly language BIOS Data Area include file is
derived from the BDA.H file.  A derivative of BCC / LCC 'copt' is
used to do the translation.  Translation rules are in the *.RUL
files.




===============
Sun 18-Feb-2018
===============
The overlapping Chip Select problem is believed to be solved as of this date.  There is one circuit update, and the included Test 0 ROM images attempt to make the problem appear.  So far, I have not had any failures at 33, 25, 20, or 16 mhz.



===============
Thu 08-Feb-2018
===============
The spurious (false) memory error reports are probably due to the
overlapping Chip Selects, specifically, DRAM and ROM.  Removing the
overlap removes the errors, and altering the wait states also seems
to remove the problem (DRAM, 2ws; ROM 3ws).  ROM was 2ws, and the
problem occasionally showed up, depending upon instruction alignment
at the beginning of a loop.

*** Intel warns against overlapping Chip Selects. ***


===============
Wed 07-Feb-2018     SBC-386EX v. 2.0
===============
There are no circuit wiring updates. (see 0UPDATE.TXT)

Without FPU, board checks to 33mhz.  The Cyrix 33mhz CPU will not
init at 33mhz.  It would on the prototype board (no DRAM, different
layout).  Signal crosstalk is suspected at this time.

With the FPU, board checks to 25mhz.  Still, the FPU initialization
hangs occasionally at the FNINIT instruction.  Workaround: hit Reset
again.




**** Below comments apply to the 386EX prototype board only.  They do
not necessarily apply to Version 2.0 or later. ****

===============
Sat 25-Nov-2017
===============

In order to get around the Gmail restrictions on files included
within ZIP files, the compiled ROMs are now distributed as HEX files.
This makes them more compact, too.

MAKE.BAT is eliminated.  Right now it is named MAKE.TAB, and I copy
it to a directory on my search path so that I can say "make", rather
than remember to type "NMAKE".  MAKE.TAB will soon disappear.

This 11/25 code will output at 9600 bps to the serial line.

===============
Sun 26-Nov-2017
===============

Co-processor works.  Enable by setting "FPU = 1" in the Makefile.

===============
Wed 29-Nov-2017
===============

Circuit update (mandatory) to allow auto-detect of FPU chip
     Wire from U8.6 (RTC_DQ) to RR1.8 (10k p.u.)
     Wire from U2.56 (PEREQ) to RR1.9 (10k p.u.)
     Wire from U1.89 (PEREQ) to U1.105 (port P1 bit3)
See the accompanying photo for easy pin location.

After this update is installed, DO NOT RUN earlier versions of the
ROM 'romXXX.hex' (or STARTUP.hex).

The FPU is now detected if it is present.  The DS1302 NVRAM is also
tested, both individual and burst reads/writes.

===============
Sat 02-Dec-2017
===============

Initialization of TCU (3 timers) & ICU (master/slave).  Both play a
role in determining the CPU clock frequency, needed for setting up
the Timer1 1mhz (1usec resolution) clock.

===============
Thu 07-Dec-2017
===============

Tests of eXternal I/O (XIO) and eXternal memory r/w (XMEM) are
implemented using the VGA3 board for testing.  A 64Kb memory hole at
$B000:0000 to $B000:FFFF is used.  Direct (XMEM) r/w is to the 32K
VGA area at $B800:0.  The entirety of VGA3 memory is not tested, just
that the data paths on all bits are operational.  The CRTC is not
programmed.  There is no keyboard or video activity.  No connections
to the board are needed (video or KBD).

The VGA3 board is set-up in a fashion identical to the SBC-188.
Jumper settings:
	P4:	off, off, off, off, off, off, off, off		$FF
	P5:	off, off, off, off, off, on , off, off		$FB

	P3:	off, off, off, on, on					$E0

If the test program is run without the VGA3 board, it simply will
repeat "failure" for the 4 tests.

--JRC
