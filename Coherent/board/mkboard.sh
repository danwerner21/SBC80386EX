# mkboard.sh -- build the SBC-386EX kernel.  Run inside Coherent:
#	cd /u/sbc/board && sh mkboard.sh
#
# Links the 4.2.12 kernel in /u/sbc/kconf (sys.r12/conf plus our changes)
# with this directory's sdevice and stune, which idmkcoh finds here first:
#   sdevice	fd, fdc, mm, kb, console off -- PC hardware the SBC lacks
#   stune	CYRIX_CPU 0xFFFF (no port 22h probing), ATSREG 1F7,
#		AT_HFREG 1FE, AT_8BIT 1
# then patches what is not a tunable:
#   condev	(5,128) = /dev/com1l, so kernel messages go to the serial port
#   pit_count	9216, for the SBC's 921600 Hz timer 0
#   early_con	0x3F8: progress markers and early printf straight to COM1
#
# /coh.sbc is the board kernel.  /coh.sbcq is the same with AT_8BIT=0 and
# pit_count=11932, for booting in QEMU, whose IDE is 16-bit and whose
# timer runs at 1.19 MHz.

K=/coh.sbc
# Files arrive from push.sh dated 1994, older than whatever was generated
# from the last configuration built, so make would keep that one.  Remove
# the generated files so this sdevice and stune are the ones used, and the
# old kernel so that it is always relinked.
C=/u/sbc/kconf
rm -f $C/drvbld.mak $C/conf.c $C/conf.h $C/obj/*.o $K /coh.sbcq
/u/sbc/kconf/bin/idmkcoh -o $K || exit 1
/conf/patch -v $K condev=0x0580 pit_count=9216 early_con=0x3F8 || exit 1
cp $K /coh.sbcq
/conf/patch -v /coh.sbcq AT_8BIT=0 pit_count=11932 || exit 1
# Relinking replaced the file, so point /autoboot at the new one.
ln -f $K /autoboot
ls -li $K /coh.sbcq /autoboot
