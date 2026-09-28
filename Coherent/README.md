# COHERENT on the SBC-386EX

How to build a CompactFlash image that boots COHERENT 4.2 on the RetroBrew
SBC-386EX, and what was changed to make it work.

The image is a whole-disk image for a CF card of at least 62,720 sectors
(30 MB): a COHERENT partition, the COHERENT master boot, and a system that
comes up multi-user with a login on the serial port and, if an ECB VGA3 is
fitted, a second login on its screen and PS/2 keyboard.

Everything is built on a Windows PC in QEMU: the kernel is linked inside
COHERENT, from MWC's 4.2.12 kernel sources and objects with our changes,
and the finished disk image is written to the card. Nothing is built on
the board.

---

## Contents

1. [What you need](#1-what-you-need)
2. [Rebuilding the image](#2-rebuilding-the-image) — the usual case; or [an install set](#2a-or-an-sbc-386ex-install-set)
3. [Making the development disk from scratch](#3-making-the-development-disk-from-scratch) — once
4. [Writing the card and first boot](#4-writing-the-card-and-first-boot)
5. [Settings: tunables and patching](#5-settings-tunables-and-patching)
6. [Debugging aids](#6-debugging-aids)
7. [What was changed, and why](#7-what-was-changed-and-why)
8. [Known limitations](#8-known-limitations)

---

## 1. What you need

| | |
|---|---|
| QEMU | `qemu-system-i386`, installed at `C:\Program Files\qemu` (`winget install SoftwareFreedomConservancy.QEMU`) |
| Git Bash | the scripts are `sh`; run them from Git Bash |
| Python 3 | the `py` launcher; the tools use only the standard library |
| A raw disk writer | anything that writes an image file to a CF card byte for byte |
| The install kit | `Coherent/distrib/coherent/4_2_10/d1`–`d4`, COHERENT 4.2.10 on four 1.44 MB floppies |

Optional: `py -m pip install --user capstone keystone-engine` for
`tools/kdis.py` (disassemble the kernel) and `tools/mkcom.py`.

**Git Bash rewrites command arguments that start with `/`** into Windows
paths. Anything that passes a COHERENT path to a tool needs
`MSYS_NO_PATHCONV=1` set; the scripts do this themselves.

### The pieces

| Path | What it is |
|---|---|
| `emu/run.sh` | start QEMU with the CF card's geometry (490/4/32), serial port on TCP 4555, control on TCP 4444 |
| `emu/boot.sh KERNEL` | reset the VM and boot a named kernel from the `tboot` prompt |
| `emu/pushsrc.sh` | copy `sys.r12/` and `board/` into the VM, under `/u/sbc` |
| `emu/mkrelease.sh OUT.img` | make a tidy board image from the development disk |
| `emu/mkdisks.sh` | make the SBC-386EX install set, `sbc-d1.img` … `sbc-d5.img` |
| `tools/cohfsw.py` | write COHERENT filesystem images from the host: `mkfs`, `put`, `mkdir`, `rm` |
| `tools/sercon.py` | run a shell command on the VM's serial port; `pull` copies a file out |
| `tools/push.sh` | copy files into the VM (tar on a FAT floppy QEMU builds from `emu/xfer/`) |
| `tools/cohfs.py` | read a COHERENT filesystem image from Windows |
| `board/mkkconf.sh` | *(runs in COHERENT)* build the kernel configuration tree `/u/sbc/kconf` |
| `board/mkboard.sh` | *(runs in COHERENT)* link the board kernel `/coh.sbc` and its QEMU twin `/coh.sbcq` |
| `board/setup.sh` | *(runs in COHERENT)* serial console, VGA3 terminal, clock, timezone, `/autoboot` |
| `board/sdevice`, `board/stune` | the board's driver list and settings |
| `sys.r12/` | MWC's COHERENT 4.2.12 kernel tree, with our changes (git history shows each one against the original) |

`emu/cf.img` is the **development disk**: an installed COHERENT, 490/4/32,
that holds the build trees. It is not in git — section 3 makes it.

---

## 2. Rebuilding the image

After a change to anything in `sys.r12/` or `board/`. From Git Bash, in
`Coherent/emu`:

**1. Start QEMU and boot the stock kernel.** It has the floppy driver the
file transfer needs; the board kernel does not.

```sh
./run.sh d1.img c &
until py ../tools/qmp.py hmp "info status" >/dev/null 2>&1; do sleep 1; done
./boot.sh coherent
py ../tools/sercon.py watch 120 'login: $'
py ../tools/sercon.py login root
```

**2. Copy the source in.** About ten minutes; one floppy-load at a time.

```sh
./pushsrc.sh
```

**3. Build the kernel configuration tree, then the kernel, then the system
settings.** Each takes a few minutes; the second argument to `run` is a
timeout in seconds.

```sh
export MSYS_NO_PATHCONV=1
py ../tools/sercon.py run "cd /u/sbc/board; sh mkkconf.sh > /tmp/mkk.log 2>&1; echo rc=\$?" 900
py ../tools/sercon.py run "cd /u/sbc/board; sh mkboard.sh > /tmp/mkb.log 2>&1; echo rc=\$?" 900
py ../tools/sercon.py run "cd /u/sbc/board; sh setup.sh > /tmp/setup.log 2>&1; echo rc=\$?" 300
```

Each should say `rc=0`. The logs stay in `/tmp` in the VM:
`py ../tools/sercon.py run "cat /tmp/mkb.log"`.

**4. Optional: try the QEMU twin.** `/coh.sbcq` is the board kernel with
the settings that differ in QEMU — 16-bit IDE, a 1.19 MHz timer, PC
keyboard and video ports. Everything on the serial port should look as
on the board, and the QEMU screen shows the second login.

```sh
./boot.sh coh.sbcq
```

**5. Stop QEMU and make the board image.**

```sh
py ../tools/sercon.py login root
py ../tools/sercon.py run "sync; sync; sync" 30
py ../tools/qmp.py hmp quit
./mkrelease.sh sbc-cf.img
```

`mkrelease.sh` copies `cf.img`, boots the copy, deletes the build trees
and anything else the board does not need, and prints the SHA1. The
development disk is left as it was.

`mkkconf.sh` is safe to run again after any source change, and
`mkboard.sh` always relinks from scratch. The build is reproducible: two
builds of the same source differ only in the kernel's COFF timestamp.

### 2a. Or: an SBC-386EX install set

`mkrelease.sh` trims the development disk. The alternative is a set of
install diskettes that make a board disk from nothing: the COHERENT
4.2.10 kit plus a fifth diskette, installed in QEMU exactly as the
original kit is (section 3.1). The installer finishes with a disk that
boots the board — no pushing, building or trimming.

```sh
./mkdisks.sh          # after steps 1-3 above: it takes the kernels from cf.img
```

This writes `sbc-d1.img` … `sbc-d5.img`, on the host and in seconds —
the diskettes are written with `tools/cohfsw.py`, not through COHERENT's
floppy driver, which in QEMU now and then never finishes a write.

| Disk | Contents |
|---|---|
| 1 | the original, with `/etc/brc.install` and `/etc/brc.update` asking for five diskettes, and `board/Coh_420.post.sbc` appended to `/conf/Coh_420.post` |
| 2–4 | the originals |
| 5 | new, the board supplement: `/Coh_420.5` (the marker the installer checks for) and `compressed/sbc.taz` — `/coh.sbc`, `/coh.sbc.sym`, `/coh.sbcq` and `/u/sbc/board` |

Install them onto a blank image as in section 3.1, with `sbc-d1.img` in
place of `d1.img` and so on (`IMG=inst.img GUI=1 ./run.sh sbc-d1.img a`
for the first stage). The installer asks for disk 5 after disk 4 and
unpacks it like the others. At the very end, after its own questions,
`/conf/Coh_420.post` runs `board/setup.sh`:

```
SBC-386EX: setting up the board system.
...
SBC-386EX: done.  This disk now boots the board kernel, /coh.sbc;
in QEMU, boot coh.sbcq at the tboot prompt instead.
```

The image is then ready for a card. It keeps the QEMU twin `/coh.sbcq`
(`./boot.sh coh.sbcq`) so it can be tried in the emulator first.

---

## 3. Making the development disk from scratch

Once, or to start again. About forty minutes, most of it the installer.

### 3.1 Install COHERENT 4.2.10 in QEMU

```sh
cd Coherent/emu
for d in d1 d2 d3 d4; do cp ../distrib/coherent/4_2_10/$d $d.img; done
"/c/Program Files/qemu/qemu-img.exe" create -f raw cf.img 32112640
GUI=1 ./run.sh d1.img a
```

`GUI=1` opens a QEMU window. At the `?` prompt type `begin`, then answer:

| Question | Answer |
|---|---|
| Serial number from the card | `146401000` (passes the installer's check; COHERENT is freely licensed now) |
| Type of disk controller | `1`, AT-compatible |
| Use NORMAL polling | `y` (the board kernel sets its own) |
| Number of non-SCSI hard drives | `1` |
| IBM PS1 or ValuePoint | `n` |
| Install the COHERENT master boot | `y` |
| Are the values correct (490 cyl, 4 heads, 32 sectors) | `y` |
| Exit instead of zeroing the partition table | `n` |
| fdisk | `2` (change one), partition `0`, bases in cylinders `n`, sizes in tracks `y`, COHERENT partition `y`, base track Enter (1), size Enter (1959); then `1` (active) `y` partition `0`; then `0` (quit), write `y` |
| Scan for bad blocks | `n` |
| Create a new filesystem | `y` |

It reboots from the floppy when done. Close QEMU, then boot the hard
disk with disk 2 in the drive:

```sh
GUI=1 ./run.sh d2.img c
```

It asks for disks 2, 3 and 4; disk 2 is already in. To change disks,
from another Git Bash window in `Coherent/emu`:

```sh
py ../tools/qmp.py hmp "change floppy0 d3.img raw"
py ../tools/qmp.py hmp "change floppy0 d4.img raw"
```

Then the configuration questions:

| Question | Answer |
|---|---|
| AT hard drive: change status / configuration | Enter, Enter |
| Adaptec (twice), Seagate/Future Domain | Enter (not enabled) |
| Enable serial port driver | Enter (`y`) |
| Link `/dev/lp` / `/dev/modem` to a COM port | Enter / `n` |
| Virtual consoles | `n` |
| Keyboard | U.S. 101-key, not loadable (Enter) |
| Floating point emulation | either — the board kernel sets its own |
| Parallel printer | change status `y` (disable it) |
| ptys, STREAMS | Enter throughout |
| Daylight saving, date, timezone | anything — `setup.sh` sets GMT, and the board reads its DS1302 |
| Site name | e.g. `sbc386`; domain Enter |
| Dictionary | `2` |
| Skip spooler configuration | `y` |
| Passwords, extra users | Enter throughout |

### 3.2 A login on the serial port

The tools talk to COHERENT over the serial port, so it needs a login
there. In the QEMU window, log in as `root` and:

```sh
sed 's/^0lPcom1l/1lPcom1l/' /etc/ttys >/tmp/t; cp /tmp/t /etc/ttys; sync
```

then halt (`sync; sync`) and close QEMU. From here on use `./run.sh`
without `GUI=1` and the tools. Keep a copy of this disk as it stands
(`cp cf.img cf-installed.img`); it is a clean start for next time.

Now carry on with [section 2](#2-rebuilding-the-image).

---

## 4. Writing the card and first boot

Write the image raw to the card — it is a whole disk, partition table and
all, and replaces everything on the card.

**The card's BIOS geometry must have 4 heads and 32 sectors per track.**
The partition table was written for 490/4/32 and the master boot finds
the partition by CHS. A card the SBC BIOS translates to 492/4/32 works
(same heads and sectors; the cylinder count only has to be at least 490).
For a card that comes out otherwise, set 490/4/32 (or 492/4/32) in
SETUP's fixed-disk geometry override.

Terminal: 9600 baud, 8N1. A normal boot:

```
Mark Williams
Drive 0
Partition 0
COHERENT Tertiary boot Version 1.2.7
...
!rootdev = (11,0)
pipedev = (11,0)
com1 port 3F8: 8250A/16450      com2 port 2F8: 8250A/16450
Using INT 0x41 drive 0 parameters
at0: ncyl=492 nhead=4 wpcc=0 eccl=0 ctrl=0 landc=0 nspt=32
*** COHERENT Version 4.2.12.jsbach26 - 386 Mode.  12492KB free memory. ***
Color.  NDP=387.  4528 buffers.  4523 buckets.  64 clists.
...
Time set from the BIOS clock.
Checking filesystems...
...
Going multiuser...
Coherent 386 login:
```

Log in as `root`; there is no password. With a VGA3 fitted the monitor
shows a second `login:` for the PS/2 keyboard (`/dev/vga3`), whatever
SETUP's console choice. Without one, the serial side is unaffected.

`/etc/reboot` or `shutdown` restarts the board through the BIOS.

---

## 5. Settings: tunables and patching

The board kernel is MWC's with a handful of settings. Most are
**tunables**, set at link time from `board/stune`; `mkboard.sh` patches
the few that are not.

| Setting | Board | PC / QEMU | What it is |
|---|---|---|---|
| `ATSREG` | `0x1FE` | `0x3F6` | IDE status polling port — **alternate** status. Reading `1F7` clears the drive's next interrupt, and multi-sector reads crawl |
| `AT_HFREG` | `0x1FE` | `0x3F6` | IDE device control register |
| `AT_8BIT` | 1 | 0 | byte-wide IDE data, `SET FEATURES 01h` after every reset |
| `AT_DRIVE_CT` | 1 | 0 | IDE drives; 0 would count them from CMOS, which the SBC lacks |
| `NDP_TYPE` | 3 | 0 | 80387 fitted — skips COHERENT's FPU probe, which faults on the 386EX |
| `CYRIX_CPU` | `0xFFFF` | 0 | skip Cyrix detection, which pokes port 22h |
| `CON_VGA` | 2 | 1 | VGA3 console: 2 = if its 8242 answers, 1 = always, 0 = never |
| `CON_CRTC` | `0x4E2` | 0 | CRTC port (HD6445 on the VGA3); 0 = the PC's |
| `CON_CGA` | 0 | 1 | the CGA mode/border/status registers exist |
| `KB_DATA`, `KB_STAT` | `0x4E0`, `0x4E1` | `0x60`, `0x64` | keyboard controller |
| `KB_XT`, `KB_SPKR` | 0, 0 | 1, 1 | XT keyboard acknowledge and PC speaker, both through port 61h |
| `pit_count` *(patched)* | 9216 | 11932 | timer 0 reload for 100 Hz: the SBC's timer runs at 921,600 Hz |
| `condev` *(patched)* | `0x580` | `0x200` | kernel console: `/dev/com1l` |
| `early_con` *(patched)* | 0 | 0 | see section 6 |

Any of these can be changed in a built kernel, on the board or in QEMU:

```sh
/conf/patch -v /coh.sbc ATSREG=0x1FE     # the kernel file: from the next boot
/conf/patch -k /coh.sbc AT_TRACE=1       # the running kernel: now, until reboot
```

**Always give a value.** `/conf/patch /coh.sbc ATSREG` with no `=value`
does not display the setting — it sets it to zero.

---

## 6. Debugging aids

**Early console.** `/conf/patch /coh.sbc early_con=0x3F8`, then reboot.
Everything the kernel says before its drivers are up — normally held
back and printed later, so a crash there shows nothing after `!` — goes
straight to COM1, along with progress markers:

```
!A*2[00068000 00F00000]zZY3456789UIa01234 ... 5 ... 678***
```

`A`–`I` are memory and paging set-up (the bracket is memory below 640K
above the kernel, and memory above 1 MB, in hex bytes); `a0`–`8` are
`main()`'s start-up steps. The last marker printed says how far it got.

**IDE trace.** `/conf/patch -k /coh.sbc AT_TRACE=1` prints a line of
the driver's activity on COM1 — `R08` a read of 8 sectors, `i58` an
interrupt with status 58, `.` a sector moved, `T` a watchdog timeout.
Healthy:

```
R08i58.i58.i58.i58.i58.i58.i58.i58.
```

**Symbols.** `/coh.sbc.sym` maps addresses to names; `tools/kdis.py`
disassembles a kernel pulled out of an image with `tools/cohfs.py`.

---

## 7. What was changed, and why

Each is a separate commit on the `coherent` branch with the reasoning
and the evidence.

| Where | Change | Why |
|---|---|---|
| `i386/k0.s` | A20 through port 92h | the stock code spun on an 8042 at 64h; with none there it would never finish |
| `i386/k0.s`, `coh.386/misc.c` | `pit_count` | the timer input is 921,600 Hz, not 1.19 MHz |
| `i386/k0.s`, `i386/mchinit.c` | memory size from INT 12h / 15h 88h | it came from CMOS, and would have read as 64 MB below 640K |
| `i386/k0.s`, `coh.386/fs2.c` | time from INT 1Ah | the DS1302 is readable only through the BIOS |
| `i386/k0.s` | reset through port 92h | `reboot` otherwise halted |
| `conf/at` | `ATSREG`/`AT_HFREG`/`AT_8BIT` | 8-bit IDE at 01F0–01FF only |
| `coh.386/lib/ksynch.c`, `i386/mchinit.c` | sleep locks initialised; memory cleared at start | kernel code assumed zeroed memory; the SBC's RAM holds the BIOS memory test's patterns |
| `conf/kb`, `conf/mm`, `conf/console` | VGA3 console and 8242 keyboard | ports, no port 61h, CGA registers skipped, bounded waits, presence by probing |
| `i386/die.c`, `io.386/putchar.c` | `early_con` | bring-up visibility |
| `board/setup.sh` | serial `/dev/console`, `rtcok` | no CMOS clock: `/etc/ATclock` would wait for hours |
| `board/mkboard.sh` | COM3/COM4 not configured | each probe of an absent port costs a 209 ms bus timeout |

---

## 8. Known limitations

- **The clock is read, not written.** `date -s` sets COHERENT's time but
  not the DS1302; set the clock in the BIOS SETUP.
- **The FPU is assumed.** `NDP_TYPE 3` says an 80387 is fitted; without
  one, floating point would misbehave. COHERENT's own probe faults on the
  386EX for a reason not yet found (under DOS the 387 passes the same
  sequence).
- **The VGA3 snows.** Screen writes are not yet confined to vertical
  blanking as the SBC BIOS's are.
- **16 MB.** The kernel uses 16 MB of the board's 64 (`HACK_LIMIT` in
  `mchinit.c`, MWC's own cap).
- **No floppy.** The board kernel has no floppy driver; the ECB floppy
  controller has no DMA, and COHERENT's driver needs it.
