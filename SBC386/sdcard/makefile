# Makefile for the SBC-386EX microSD programs:
#   SD.SYS      the DOS block device driver (sd.asm + sdcore.inc)
#   SDTEST.COM  the bring-up and test program (sdtest.asm)
#
# GNU make and NASM, as the BIOS's makefile.  -O9 lets NASM size the
# jumps; both sources rely on it.
#
#   make          both
#   make clean    the outputs and listings

NASM = nasm
NOPT = -O9
RM   = rm -f

all: SD.SYS SDTEST.COM

SD.SYS: sd.asm sdcore.inc
	$(NASM) $(NOPT) -f bin -o $@ -l sd.lst sd.asm

SDTEST.COM: sdtest.asm
	$(NASM) $(NOPT) -f bin -o $@ -l sdtest.lst sdtest.asm

clean:
	$(RM) SD.SYS SDTEST.COM sd.lst sdtest.lst

.PHONY: all clean
