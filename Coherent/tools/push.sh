#!/bin/sh
# push.sh GUESTDIR PATH... -- copy host files into the running Coherent VM.
#
# PATHs are relative to the current directory and keep that relative form
# under GUESTDIR.  They travel as a v7 tar (what Coherent's tar reads) on a
# FAT floppy that QEMU builds from Coherent/emu/xfer, and are unpacked over
# the serial console with sercon.py.  QEMU scans the folder only when the
# floppy is attached, so it is re-attached on every push.
#
# Every file is stamped 28 Jul 1994, the date of the sys.r12 objects, so
# prebuilt objects never look older than their sources and make leaves them
# alone; objects we change are rebuilt explicitly.  (The VM clock starts in
# 1999 -- see run.sh -- so these are never in its future.)
set -e
[ $# -ge 2 ] || { echo "usage: push.sh GUESTDIR PATH..." >&2; exit 2; }
DEST=$1; shift
TOOLS=$(cd "$(dirname "$0")" && pwd)
XFER=$TOOLS/../emu/xfer
mkdir -p "$XFER"
# QEMU holds the folder's files open while the floppy is attached.
( cd "$TOOLS/../emu" && py ../tools/qmp.py hmp "eject -f floppy0" >/dev/null )
rm -f "$XFER/push.tar"
tar --format=v7 --owner=0 --group=0 --mtime='1994-07-28 12:00' -cf "$XFER/push.tar" "$@"
# The FAT floppy holds 1.44 MB; push big trees a directory at a time.
SIZE=$(wc -c < "$XFER/push.tar")
[ "$SIZE" -le 1400000 ] || { echo "push.sh: $SIZE bytes will not fit a floppy -- split it" >&2; exit 1; }
( cd "$TOOLS/../emu" &&
  py ../tools/qmp.py hmp "change floppy0 fat:floppy:12:xfer vvfat read-only" )
# Coherent's mkdir -p fails on a directory that already exists.
py "$TOOLS/sercon.py" run "{ [ -d $DEST ] || mkdir -p $DEST; } && cd $DEST && dos x /dev/fha0 push.tar && tar xvf push.tar && rm push.tar; cd" 300
