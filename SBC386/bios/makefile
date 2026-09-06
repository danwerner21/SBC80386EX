# Makefile for the RetroBrew SBC-386 relocatable BIOS
#  Use Open Watcom NMAKE to make (or NMAKE?)
#  Use Open Watcom C 1.9
#   or NASM version 2.08 (cwsdpmi needed, or WINNT)
#       NASM ver. 2.09 is reported to have problems
#
#
ROM = 64
CHIP = 64

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
COPT = -q -mc -zdp -zu -s -zp1 -oxs -3 -fpi87 -DSBC386=1
#COPT = -q -mc -zdp -zu -s -zp1 -ox -3 -fpi87 -DSBC386=1

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
CAT=cp -b
PLUS=+


H2INC = -c@ -b9

INCLUDES = seg_def.inc i386EX.inc macro.inc bda.inc disktab.inc timer.inc \
	stack.inc zero.inc date.inc error.inc
CINCL = mytypes.h cprintf.h bda.h getline.h ascii.h sbc188.h serial.h nvram.h \
	strtobcd.h zero.h disk.h disktab.h

OBJECTS = start.o sizer.o crc16.o diskide.o errno.o \
	11h_12h.o 13h_disk.o 14h_sio0.o 15h_misc.o 1Ah_time.o \
	main.o signon.o getline.o set1302.o icu.o \
	strtobcd.o testmain.o stub.o

TEST = test.o cprintf.o

.EXTENSIONS:
.EXTENSIONS: .bin .o .exe .asm .c .h .tmp

.asm.bin:
	$(NASM) $(NOPT) -f bin -o $@ -l $@.lst  $@.asm
.asm.o:
	$(ASM) $(NOPT) -o $@ -l $*.lst $*.asm

.c.o:
	$(CC) $(COPT) -fo=$@ $*.c
	$(CLIST)
.c:
	wcl386 -DMSDOS=1 -fo$@  $@.c

all:	new o rom064.hex rom128.hex rom256.hex rom512.hex    0rom128.hex
	$(RM) $(BIN)
###	$(HEX2BIN) -R64K rom064.hex -o rom.tmp

new:
	$(RM) signon.o

o:	$(OBJECTS)

test:	test.exe


test.exe:  test.o $(TEST)
	wcl -lr -k1024 -fo$@  $<

start.exe:	$(OBJECTS) $(LIBS)
	$(LINK) -fm=start.map  $(OBJECTS) $(LIBS)
#	WLINK @start.lkk

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
	$(HEX2BIN) -R128k -o$(BIN) -d64K $*
	$(BIN2HEX) -R128k -o$@ $(BIN)
rom256.hex:	rom064.hex
	$(HEX2BIN) -R256k -o$(BIN) -d192K $*
	$(BIN2HEX) -R256k -o$@ $(BIN)
rom512.hex:	rom064.hex
	$(HEX2BIN) -R512k -o$(BIN) -d448K $*
	$(BIN2HEX) -R512k -o$@ $(BIN)

# do the following since "0rom..." is easier to find when burning ROM chip
0rom128.hex:	rom128.hex
	$(CP) rom128.hex 0rom128.HEX



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


crc7.o:	crc.asm $(INCLUDES)
	$(ASM) $(NOPT) -o$@ -lcrc7.lst -dCRC7=1  crc.asm


## obsolete -- from TEST1
startup.hex:	startup.asm $(INCLUDE) $(ASM_INC)
	$(NASM) -fith $(NOPT) -dCRC=$(CRC) -dROM=$(ROM_START) -o startup.hex -l startup.lst  startup.asm

# copy of 1985 PC/AT bios data area
dseg:	dseg.asm	.SYMBOLIC
	masm /X dseg.asm,nul,dseg.lst;



# Maintenance

tidy:
	$(RM) *.lst
	$(RM) *.map
	$(RM) *.err
	$(RM) $(BIN)

clean:	tidy
	$(RM) bda.inc disktab.inc stack.inc error.inc
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
#uart_det.o:	uart_det.asm	$(INCLUDES)
errno.o:	errno.asm	$(INCLUDES)
icu.o:	icu.asm		$(INCLUDES)
muldiv.o:	muldiv.asm	$(INCLUDES)
stub.o:	stub.asm	$(INCLUDES)
sizer.o:	sizer.asm	$(INCLUDES)
diskide.o:	diskide.asm	$(INCLUDES)

signon.o:	signon.c $(CINCL)
set1302.o:	set1302.c $(CINCL)
libc.o:	libc.c libc.h
microSD.o:	microSD.c disk.h $(CINCL)
main.o:	main.c $(CINCL)
getline.o:	getline.c $(CINCL)
strtobcd.o:	strtobcd.c $(CINCL)
testmain.o:	testmain.c $(CINCL)
testide.o:	testide.c $(CINCL)

test.o:	test.c $(CINCL)


#########################################################################
# Leftovers from SBC188

sio.o:	sio.c sbc188.h sio.h
nvram.o:      nvram.c sbc188.h ds1302.h sio.h equates.h ide.h bda.inc sdcard.h libc.h
libc.o:	libc.c
debug.o:      debug.c mytypes.h equates.h sio.h debug.h bda.inc
kbd.o:	kbd.c mytypes.h sbc188.h equates.h kbd_pc.h kbd_stat.h config.asm
m8563lib.o:	m8563lib.c mytypes.h sbc188.h equates.h m8563inc.h ega9a.h
vga3lib.o:	vga3lib.c mytypes.h sbc188.h equates.h vga3inc.h v3std.h v3_par1.h vga_def.h
fdc8272.o:	fdc8272.c mytypes.h sbc188.h io.h fdc8272.h wd37c65.h
wd37c65.o:	wd37c65.c mytypes.h sbc188.h io.h wd37c65.h

dprintf.o:	dprintf.c sbc188.h

font2.o:	font2.c font_vga.h
font2.exe:	font2.o
	$(LINK) $(LOPT) -k1024 -fe=$@ -fm=$@.map $<
font2.bin:	font2.exe
	$(EXE2ROM) font2.exe font2.bin -s NUL -r 32K -e 32K
font2.hex:	font2.bin
	$(BIN2HEX) -o font2.hex -S 4k font2.bin
font2a.bin:	font2.hex
	$(HEX2BIN) -R 4K -o font2a.bin font2.hex


#########################################################################
