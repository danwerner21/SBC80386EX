# mkboard.sh -- build the SBC-386EX kernel.  Run inside Coherent:
#	cd /u/sbc/board && sh mkboard.sh
#
# Links the 4.2.12 kernel in /u/sbc/kconf (sys.r12/conf plus our changes)
# with this directory's sdevice and stune, which idmkcoh finds here first:
#   sdevice	fd, fdc, mm, kb, console off -- PC hardware the SBC lacks
#   stune	CYRIX_CPU 0xFFFF (no port 22h probing), ATSREG 1FE (alternate
#		status: reading 1F7 would clear the next sector's interrupt),
#		AT_HFREG 1FE, AT_8BIT 1
# then patches what is not a tunable:
#   condev	(5,128) = /dev/com1l, so kernel messages go to the serial port
#   pit_count	9216, for the SBC's 921600 Hz timer 0
# early_con is left at 0.  For bring-up, /conf/patch it to 0x3F8 and the
# start-up markers and early printf go straight to COM1, polled.
#
# /coh.sbc is the board kernel.  /coh.sbcq is the same with AT_8BIT=0,
# ATSREG and AT_HFREG at the PC's 3F6, and
# pit_count=11932, for booting in QEMU, whose IDE is 16-bit and whose
# timer runs at 1.19 MHz.

K=/coh.sbc
# Files arrive from push.sh dated 1994, older than whatever was generated
# from the last configuration built, so make would keep that one.  Remove
# the generated files so this sdevice and stune are the ones used, and the
# old kernel so that it is always relinked.
C=/u/sbc/kconf

# The asy driver's channel table is patched in after the link from
# /etc/default/async.  The SBC has COM1 (3F8) and the 386EX's second UART
# at 2F8, and nothing at 3E8 or 2E8: every probe of those is a 209 ms
# bus-monitor timeout.  Comment them out.
sed -e 's/^P[ 	]*3e8[ 	]/#&/' -e 's/^P[ 	]*2e8[ 	]/#&/' /etc/default/async >/tmp/async
cp /tmp/async /etc/default/async
rm /tmp/async

rm -f $C/drvbld.mak $C/conf.c $C/conf.h $C/obj/*.o $K /coh.sbcq
/u/sbc/kconf/bin/idmkcoh -o $K || exit 1
/conf/patch -v $K condev=0x0580 pit_count=9216 || exit 1
cp $K /coh.sbcq
/conf/patch -v /coh.sbcq AT_8BIT=0 pit_count=11932 ATSREG=0x3F6 AT_HFREG=0x3F6 || exit 1
# ... and QEMU's console is a PC's: CRTC from the BIOS, 8042 at 60h/64h.
/conf/patch -v /coh.sbcq CON_VGA=1 CON_CRTC=0 CON_CGA=1 CON_VBLANK=0 || exit 1
/conf/patch -v /coh.sbcq KB_DATA=0x60 KB_STAT=0x64 || exit 1
# Relinking replaced the file, so point /autoboot at the new one.
ln -f $K /autoboot

# The SBC-386EX install diskette's kernel (emu/mkdisks.sh puts it on
# sbc-b1.img as /coherent): root on the 1.44M floppy, read-only, pipes on
# the RAM disk.  /etc/build patches its copy on the hard disk back.
cp $K /u/sbc/coh.fd
/conf/patch -v /u/sbc/coh.fd "rootdev=makedev(4,15)" ronflag=1 || exit 1
ls -li $K /coh.sbcq /autoboot
