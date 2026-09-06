# makefile for the IBM 1985 PC/AT BIOS
#
# Use MASM.EXE to assemble
#
#

ASM = masm
AOPT = /L /W2 /P /V /Z /Mu /I.

I = modref.inc postequ.inc dseg.inc sysdata.inc



.asm.obj:
	$(ASM) $(AOPT) $*.ASM,$*,$*;
	

all:	test1.obj


test1.obj:	test1.asm $I
keybd.obj:	keybd.asm $I
