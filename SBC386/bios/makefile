# Makefile for the RetroBrew SBC-386 relocatable BIOS
#  Use Open Watcom C 1.9
#   or NASM version 2.08 (cwsdpmi needed, or WINNT)
#       NASM ver. 2.09 is reported to have problems
#
ROM = 64
CHIP = 64


MAKEFLAGS += -r

# Set CRC option:  0, 1, 2, 16
CRC = 16
CRC_AT = 0xFFEE
BIN = __FOO__

CC = wcl -c
#COPT = /Gs2 /Zp1 /Ois /DSBC188=1 /Fl
# Open Watcom C Compiler options:
# -bt=DOS  build target
# -mc   compact memory model  -f
# -zdp  DS == DGROUP
# -zu   SS != DGROUP
# -s    remove stack overflow checks
# -zp1  set struct packing alignment to 1
# -oa	relax aliasing
# -ob	branch prediction
# -oi   inline intrinsic functions
# -ol	loop optimizations
# -os   optimize for space (dangerous -- switch in cprintf.c fails)
# -ot	optimize for time
# -ox	extensive optimization -obmiler
# -1    generate code for 186 or higher
# -2    generate code for 286 or higher
# -3    generate code for 386 or higher
# -fpi87 use 8087 instructions
# -q	quiet compile
#
# N.B.:  Watcom 1.9 mishandles SWITCH statements with the '-os' option
#COPT = -q -mc -zdp -zu -s -zp1 -oi -ox -3 -fpi87 -DSBC386=1
#COPT = -q -mc -zdp -zu -s -zp1 -ox -3 -fpi87 -DSBC386=1
COPT = -q -mc -zdp -zu -s -zp1 -oxs -3 -fpi87 -DSBC386=1

CLIST = wdis -l -s $@
SIZE = -DROM=$(ROM) -DCHIP=$(CHIP) $(RED)
#
# The newer version of NASM provides the __DATE__ & __TIME__
#NASM = nasm
NASM = nasm
ASM = $(NASM) -fobj
#
NOPT = -O9 -dROM=$(ROM)
LINK = wcl
#LINK = wlink
# Open Watcom linker options:
# -lr   create a DOS real-mode program
LOPT = -lr -q

WLIB2 = $(WATCOM)/lib286/dos
LIBS = lib/sbc386.lib $(WLIB2)/clibc.lib


# Watcom tools

RM=rm -f
EXE2ROM=../tools/exe2rom
HEX2BIN=../tools/hex2bin
BIN2HEX=../tools/bin2hex
COPT18=../tools/copt
CP=cp




H2INC = -c@ -b9

INCLUDES = seg_def.inc i386EX.inc macro.inc bda.inc disktab.inc timer.inc \
	stack.inc zero.inc date.inc error.inc
CINCL = mytypes.h cprintf.h bda.h getline.h ascii.h sbc188.h serial.h nvram.h \
	strtobcd.h strtoint.h zero.h disk.h disktab.h debugmon.h hdinit.h

OBJECTS = start.o sizer.o crc16.o diskide.o errno.o \
	11h_12h.o 13h_disk.o 14h_sio0.o 15h_misc.o 1Ah_time.o \
	main.o signon.o getline.o set1302.o icu.o \
	strtobcd.o strtoint.o testmain.o stub.o debugmon.o monitor.o hdinit.o \
	19h_boot.o 17h_prn.o 10h_video.o 16h_kbd.o

TEST = test.o cprintf.o

.SUFFIXES:
.SUFFIXES: .bin .o .exe .asm .c .h .tmp

.asm.bin:
	$(NASM) $(NOPT) -f bin -o $@ -l $*.lst  $*.asm
.asm.o:
	$(ASM) $(NOPT) -o $@ -l $*.lst $*.asm

.c.o:
	$(CC) $(COPT) -fo=$@ $*.c
	$(CLIST)
.c:
	wcl386 -DMSDOS=1 -fo$@  $@.c

all:	new o rom064.hex rom128.hex rom256.hex rom512.hex
	$(RM) $(BIN)


new:
	$(RM) signon.o

o:	$(OBJECTS)

test:	test.exe

.PHONY: all new o test tidy clean spotless dseg FORCE

date.inc: FORCE
	@printf '\tdb\t"%s"\n' "$$(date +%m/%d/%y)" > $@.tmp
	@cmp -s $@.tmp $@ || mv $@.tmp $@
	@rm -f $@.tmp


test.exe:  test.o $(TEST)
	wcl -lr -k1024 -fo$@  $<

start.exe:	$(OBJECTS) $(LIBS)
	$(LINK) -fm=start.map  $(OBJECTS) $(LIBS)

zero.h:	zero.inc zero.rul
	$(COPT18) $(H2INC) -f zero.inc -o zero.h zero.rul

zero.o:	zero.inc
	$(NASM) -fobj -O1+ -dXXX -lzero.lst -ozero.o zero.inc
disktab.inc:	disktab.h bda.rul
	$(COPT18) $(H2INC) -f disktab.h -o disktab.inc bda.rul
disktab.o:	disktab.inc
	$(NASM) -fobj -O1+ -dXXX -ldisktab.lst -odisktab.o disktab.inc
stack.inc:	stack.h bda.rul
	$(COPT18) $(H2INC) -f stack.h -o stack.inc bda.rul
stack.o:	stack.inc
	$(NASM) -fobj -O1+ -dXXX -lstack.lst -ostack.o stack.inc
error.inc:	error.h bda.rul
	$(COPT18) $(H2INC) -f error.h -o error.inc bda.rul
bda.inc:	bda.h bda.rul
	$(COPT18) $(H2INC) -f bda.h -o bda.inc bda.rul
bda.o:	bda.inc
	$(NASM) -fobj -O1+ -dXXX -lbda.lst -obda.o bda.inc
boot.tmp:	boot.asm $(INCLUDES)
	$(NASM) -fbin $(NOPT) -dROM=$(ROM) -o boot.tmp -l boot.lst  boot.asm
rom064.hex:	start.exe boot.tmp
	$(EXE2ROM) -v -s boot.tmp -r $(ROM) -e $(CHIP) start.exe $(BIN)
	$(BIN2HEX) -c$(CRC)=$(CRC_AT) -R $(CHIP)K $(BIN) -o rom064.hex

rom128.hex:	rom064.hex
	$(HEX2BIN) -R128k -o$(BIN) -d64K rom064.hex
	$(BIN2HEX) -R128k -o$@ $(BIN)
rom256.hex:	rom064.hex
	$(HEX2BIN) -R256k -o$(BIN) -d192K rom064.hex
	$(BIN2HEX) -R256k -o$@ $(BIN)
rom512.hex:	rom064.hex
	$(HEX2BIN) -R512k -o$(BIN) -d448K rom064.hex
	$(BIN2HEX) -R512k -o$@ $(BIN)

start.o:	start.asm  $(INCLUDES) boot.asm
	$(ASM) $(NOPT) -o$@ -l start.lst -dCRC=$(CRC) -dCRC_AT=$(CRC_AT) start.asm

crc16.o:	crc.asm $(INCLUDES) crc16tab.inc
	$(ASM) $(NOPT) -o$@ -lcrc16.lst -dCRC16=1  crc.asm

1Ah_time.o:	1Ah_time.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l1Ah_time.lst   1Ah_time.asm

sizer.o:	sizer.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -lsizer.lst   sizer.asm

diskide.o:	diskide.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -ldiskide.lst   diskide.asm

errno.o:	errno.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -lerrno.lst   errno.asm

11h_12h.o:	11h_12h.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l11h_12h.lst   11h_12h.asm

13h_disk.o:	13h_disk.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l13h_disk.lst   13h_disk.asm

14h_sio0.o:	14h_sio0.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l14h_sio0.lst   14h_sio0.asm

15h_misc.o:	15h_misc.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l15h_misc.lst   15h_misc.asm

icu.o: 		icu.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -licu.lst   icu.asm

stub.o:		stub.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -lstub.lst   stub.asm

19h_boot.o:	19h_boot.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l19h_boot.lst   19h_boot.asm

17h_prn.o:	17h_prn.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l17h_prn.lst   17h_prn.asm

10h_video.o:	10h_video.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l10h_video.lst   10h_video.asm

16h_kbd.o:	16h_kbd.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -l16h_kbd.lst   16h_kbd.asm


crc7.o:	crc.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -lcrc7.lst -dCRC7=1  crc.asm

# copy of 1985 PC/AT bios data area
dseg:	dseg.asm
	masm /X dseg.asm,nul,dseg.lst;



# Maintenance

tidy:
	$(RM) *.lst
	$(RM) *.map
	$(RM) *.err
	$(RM) $(BIN)

clean:	tidy
	$(RM) bda.inc disktab.inc stack.inc error.inc date.inc
	$(RM) zero.h
	$(RM) *.tmp
	$(RM) *.o
	$(RM) *.exe

spotless: clean
	$(RM) *.lib
	$(RM) *.hex
	$(RM) *.bak
	$(RM) *.bk?
	$(RM) foo*
	$(RM) goo*
	$(RM) foo*.*
	$(RM) goo*.*

# Dependencies
foo.o:	foo.c
11h_12h.o:	11h_12h.asm	$(INCLUDES)
13h_disk.o:	13h_disk.asm	$(INCLUDES)
14h_sio0.o:	14h_sio0.asm	$(INCLUDES)
15h_misc.o:	15h_misc.asm	$(INCLUDES)
errno.o:	errno.asm	$(INCLUDES)
icu.o:	icu.asm		$(INCLUDES)
muldiv.o:	muldiv.asm	$(INCLUDES)
stub.o:	stub.asm	$(INCLUDES)
monitor.o:	monitor.asm	$(INCLUDES)
sizer.o:	sizer.asm	$(INCLUDES)
diskide.o:	diskide.asm	$(INCLUDES)

signon.o:	signon.c $(CINCL)
set1302.o:	set1302.c $(CINCL)
libc.o:	libc.c libc.h
microSD.o:	microSD.c disk.h $(CINCL)
main.o:	main.c $(CINCL)
getline.o:	getline.c $(CINCL)
strtobcd.o:	strtobcd.c $(CINCL)
strtoint.o:	strtoint.c $(CINCL)
debugmon.o:	debugmon.c $(CINCL)
hdinit.o:	hdinit.c $(CINCL)
testmain.o:	testmain.c $(CINCL)
testide.o:	testide.c $(CINCL)

test.o:	test.c $(CINCL)
