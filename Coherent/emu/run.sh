#!/bin/sh
# run.sh [floppy.img] [boot a|c] -- start Coherent in QEMU, headless, QMP on 4444.
# The hard disk is cf.img with the SBC's CF geometry, 490/4/32, untranslated.
FD=${1:-d2.img}; BOOT=${2:-c}
# The VM clock runs 27 years behind: Coherent reads a 2026 CMOS date as
# 1970, and a fixed start date would send the clock backwards on restart.
exec "/c/Program Files/qemu/qemu-system-i386.exe" -M pc -cpu 486 -m 16 -nic none -rtc base=$(date -d "-27 years" +%Y-%m-%dT%H:%M:%S) \
  -display none -qmp tcp:127.0.0.1:4444,server,nowait -name coherent \
  -drive file=$FD,if=floppy,format=raw,index=0 \
  -drive file=cf.img,if=none,id=hd0,format=raw \
  -device ide-hd,drive=hd0,bus=ide.0,unit=0,cyls=490,heads=4,secs=32,bios-chs-trans=none \
  -boot $BOOT -chardev socket,id=com1,host=127.0.0.1,port=4555,server=on,wait=off -serial chardev:com1
