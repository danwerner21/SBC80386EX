# setup.sh -- make an installed COHERENT 4.2.10 root ready for the SBC-386EX.
# Run inside Coherent, as root, after mkboard.sh:
#	cd /u/sbc/board && sh setup.sh
# Safe to run more than once.  Leaves /coherent, the stock kernel, alone.
# No set -e: Coherent's sh exits on a false test even in an if condition.

# Console on the serial port.  The board kernel sends its own messages to
# condev = (5,128), /dev/com1l; make /dev/console the same device, so init,
# the rc scripts and single-user mode use it too.  The PC console node is
# kept as /dev/console.pc.
if [ ! -f /dev/console.pc ] && [ ! -c /dev/console.pc ]; then
	mv /dev/console /dev/console.pc
fi
rm -f /dev/console
/etc/mknod /dev/console c 5 128
chmod 622 /dev/console

# Log in on com1l, not on the PC console -- they are now the same line.
sed -e 's/^[01]lPconsole$/0lPconsole/' -e 's/^[01]lPcom1l$/1lPcom1l/' /etc/ttys >/tmp/ttys
cp /tmp/ttys /etc/ttys
rm /tmp/ttys

# Set the date only if there is a CMOS clock to read it from.  See rtcok.c:
# without one, ATclock waits about seven and a half hours.
cc -o /etc/rtcok rtcok.c || { echo setup.sh: rtcok did not build; exit 1; }
for f in /etc/rc /etc/brc; do
	sed -e 's|^/bin/date -s `/etc/ATclock`|/etc/rtcok \&\& &|' $f >/tmp/rc
	cp /tmp/rc $f
	rm /tmp/rc
	grep -n ATclock $f
done

# The board kernel sets its clock from the DS1302, through the BIOS, taking
# what it holds as UTC.  Show it unchanged: GMT, no daylight-saving rule.
# (The DS1302 is kept in local time, as DOS does.)
cat >/etc/timezone <<'TZEND'
export TIMEZONE="GMT:000"
export TZ="GMT0"
TZEND

# Boot the board kernel by default.  tboot loads /autoboot.
ln -f /coh.sbc /autoboot
ls -li /autoboot /coh.sbc /coherent
sync
