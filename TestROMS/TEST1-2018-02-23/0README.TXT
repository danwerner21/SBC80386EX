File:  0README.TXT
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
