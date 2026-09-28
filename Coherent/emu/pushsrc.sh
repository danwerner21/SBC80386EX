#!/bin/sh
# pushsrc.sh -- copy the kernel source (sys.r12) and board/ into the running
# Coherent VM, under /u/sbc, a floppy-sized piece at a time.
# Needs the VM booted on a kernel with the floppy driver (the stock
# /coherent: ./boot.sh coherent) and logged in as root on COM1.
cd "$(dirname "$0")/.." || exit 1
for d in sys.r12/i386 sys.r12/coh.386 sys.r12/io.386 sys.r12/conf/* board; do
	case $d in
	*/Doit|*/drvbld.mak)	continue ;;	# generated / not wanted
	esac
	printf '%s ... ' "$d"
	if tools/push.sh /u/sbc "$d" > /tmp/pushsrc.out 2>&1; then
		echo ok
	else
		echo FAILED; tail -3 /tmp/pushsrc.out; exit 1
	fi
done
