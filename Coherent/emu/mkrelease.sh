#!/bin/sh
# mkrelease.sh OUT.img -- make a board image from the development disk.
#
# Copies cf.img (which must hold a current /coh.sbc and /coh.sbcq -- see
# board/mkboard.sh and board/setup.sh), boots the copy in QEMU on the QEMU
# twin /coh.sbcq, deletes what the board does not need -- the build trees
# under /u/sbc, test kernels, the twin itself -- and syncs.  The result is
# written raw to a CF card.  QEMU must not be running when this starts.
set -e
[ $# -eq 1 ] || { echo "usage: mkrelease.sh OUT.img" >&2; exit 2; }
cd "$(dirname "$0")"
OUT=$1
Q="py ../tools/qmp.py"
S="py ../tools/sercon.py"
export MSYS_NO_PATHCONV=1

if $Q hmp "info status" >/dev/null 2>&1; then
	echo "mkrelease.sh: QEMU is running; stop it first" >&2; exit 1
fi
cp cf.img "$OUT"
IMG=$OUT ./run.sh d1.img c >/dev/null 2>&1 &
until $Q hmp "info status" >/dev/null 2>&1; do sleep 1; done

# Boot the QEMU twin and wait for its serial login.
( $S watch 180 'login: $' >/dev/null 2>&1 & )
sleep 1
./boot.sh coh.sbcq
sleep 90
$S login root >/dev/null

$S run "rm -f /coh. /coh.mod /coh.mod.sym /coh.pit /coh.r12 /coh.r12.sym" 60 >/dev/null
$S run "rm -f /coh.test /coh.test.sym /hello.txt /coh.nov /coh.probe" 60 >/dev/null
$S run "rm -f /coh.sbcq; rm -rf /u/sbc" 300 >/dev/null
$S run "ls /; df; ls -li /autoboot /coh.sbc; sync; sync; sync" 60
sleep 2
$Q hmp quit >/dev/null
sleep 3
sha1sum "$OUT"
