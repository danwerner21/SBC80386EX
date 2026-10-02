# mkkconf.sh -- make /u/sbc/kconf, the kernel configuration tree the board
# kernel is linked from, out of the source in /u/sbc/sys.r12.  Run inside
# Coherent, as root, after emu/pushsrc.sh has copied the source in:
#	cd /u/sbc/board && sh mkkconf.sh
# then build the kernel with mkboard.sh.
#
# kconf is sys.r12/conf -- the COHERENT 4.2.12 configuration: prebuilt
# driver objects, k0.o and k386.a -- laid out like /etc/conf, without the
# per-driver src directories (the 4.2.12 Makefile would rebuild them, and
# several need headers the 4.2.10 system lacks).  Every object we change
# is then rebuilt from source and put in place.  MWC's originals are kept
# once, as *.mwc.  Safe to run again after changing any of the sources.

S=/u/sbc/sys.r12
K=/u/sbc/kconf

if [ ! -d $K ]; then
	echo "mkkconf.sh: creating $K"
	( cd $S/conf && tar cf /tmp/kconf.tar . ) || exit 1
	mkdir $K
	( cd $K && tar xf /tmp/kconf.tar && rm -f /tmp/kconf.tar && rm -rf */src ) || exit 1
	for f in lib/k0.o lib/k386.a at/Driver.o kb/Driver.o mm/Driver.a fdc/Driver.o; do
		cp $K/$f $K/$f.mwc
	done
fi

# A kconf made before a driver was added to the list above.
for f in fdc/Driver.o; do
	[ -f $K/$f.mwc ] || cp $K/$f $K/$f.mwc
done

# git on Windows does not keep execute bits.
chmod a+x $K/bin/* $K/*/mkdev $K/*/after $K/install_conf/keeplist 2>/dev/null

# The kernel core: k0.o, and our members of k386.a.
echo "mkkconf.sh: core"
cd $S/i386 && as -o $K/lib/k0.o k0.s || exit 1
cd $S/i386 && cc -c mchinit.c die.c || exit 1
cd $S/coh.386 && cc -c misc.c fs2.c || exit 1
cd $S/coh.386/lib && cc -c ksynch.c || exit 1
cd $S/io.386 && cc -c putchar.c || exit 1
cd $S && ar r $K/lib/k386.a i386/mchinit.o i386/die.o coh.386/misc.o \
	coh.386/fs2.o coh.386/lib/ksynch.o io.386/putchar.o || exit 1

# Drivers: at (IDE), kb (8242), mm (VGA3), fdc (the ECB FDC9266, our own
# sbcfd.c in place of MWC's fdc+fl386).  mmas.s through cc, as MWC did.
echo "mkkconf.sh: drivers"
cd $S/conf/at/src && cc -o $K/at/Driver.o -c at.c || exit 1
cd $S/conf/kb/src && cc -o $K/kb/Driver.o -c kb.c || exit 1
cd $S/conf/mm/src && cc -c mm.c mmas.s && ar r $K/mm/Driver.a mm.o mmas.o || exit 1
cd $S/conf/fdc/src && cc -o $K/fdc/Driver.o -c sbcfd.c || exit 1

# Configuration files we changed.
cp $S/conf/at/Space.c $K/at/Space.c
cp $S/conf/console/Space.c $K/console/Space.c
cp $S/conf/mtune $K/mtune
cp $S/conf/install_conf/keeplist $K/install_conf/keeplist
chmod a+x $K/install_conf/keeplist

# Whatever was generated from an earlier configuration goes.
rm -f $K/drvbld.mak $K/conf.c $K/conf.h $K/obj/*.o
echo "mkkconf.sh: done"
