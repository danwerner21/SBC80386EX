File:  0README.TXT

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

--JRC
