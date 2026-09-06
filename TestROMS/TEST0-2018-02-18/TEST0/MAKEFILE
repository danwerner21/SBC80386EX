# Makefile for the RetroBrew SBC-386 relocatable BIOS
#  Use Open Watcom C 1.9
#  Use NASM version 2.08 (cwsdpmi needed, or WINNT)
#       NASM ver. 2.09 is reported to have problems
#  Use Open Watcom NMAKE to make
#
#
FAST = -DHAS_FASTCALL=1

# Set FPU to 1 if Math Co-processor is present
FPU = 1

ROM = 0xF000
ROM512 = 0x7F000
ROM128 = 0x1F000
ROM064 = 0x0F000


CC = wcl -c
#COPT = /Gs2 /Zp1 /Ois /DSBC188=1 /Fl
# Open Watcom C Compiler options:
# -mc   compact memory morm -f
# -zdp  DS == DGROUP
# -zu   SS != DGROUP
# -s    remove stack overflow checks
# -zp1  set struct packing alignment to 1
# -oi   inline intrinsic functions
# -os   optimize for space
# -1    generate code for 186 or higher
# -fpi87 use 8087 instructions
# -q	quiet compile
COPT = -q -mc -zdp -zu -s -zp1 -oi -os -1 -fpi87 -DSBC386=1
CLIST = wdis -l -s $*
SIZE = -DROM=$(ROM) -DCHIP=$(CHIP) $(RED)
#
# The newer version of NASM provides the __DATE__ & __TIME__ 
#NASM = nasm
NASM = nasm208
#
NOPT = $(FAST) -dFPU=$(FPU) -O9+
LINK = wcl
# Open Watcom linker options:
# -lr   create a DOS real-mode program
#LOPT = -mc -lr
LOPT = -lr -q

!ifdef __UNIX__
RM=rm -f
EXE2ROM=tools/exe2rom
HEX2BIN=tools/hex2bin.exe
BIN2HEX=tools/bin2hex.exe
CP=cp
CAT=cat
PLUS=
!else
RM=rm -f
EXE2ROM=..\tools\exe2rom.exe
HEX2BIN=..\tools\hex2bin.exe
BIN2HEX=..\tools\bin2hex.exe
CP=copy
CAT=copy/b
PLUS=+
!endif


all:    startup.hex rom128.hex rom512.hex rom064.hex


startup.bin:    startup.asm i386ex.inc macro.inc ds1302.asm
        $(NASM) -fbin $(NOPT) -o$*.bin -l$*.lst  $*.asm

startup.hex:    startup.asm i386ex.inc macro.inc ds1302.asm
        $(NASM) -fith $(NOPT) -dROM=$(ROM) -o$*.hex -l$*.lst  $*.asm



rom064.hex:     startup.hex
        $(HEX2BIN) -R64k -o FOO -s$(ROM) -d$(ROM064)  startup.hex
        $(BIN2HEX) -R64k -o $@  FOO
#       $(RM) FOO

rom128.hex:     startup.hex
        $(HEX2BIN) -R128k -o FOO -s$(ROM) -d$(ROM128)  startup.hex
        $(BIN2HEX) -R128k -o $@  FOO
        $(RM) FOO

rom512.hex:     startup.hex
        $(HEX2BIN) -R512k -o FOO -s$(ROM) -d$(ROM512)  startup.hex
        $(BIN2HEX) -R512k -o $@  FOO
        $(RM) FOO



tidy:
	$(RM) FOO
        $(RM) *.lst

clean:  tidy
        $(RM) *.hex
