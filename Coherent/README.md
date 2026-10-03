# COHERENT on the SBC-386EX

COHERENT 4.2, Mark Williams Company's UNIX-like system for the 386, running
on the RetroBrew SBC-386EX: multi-user, with a login on the serial port and,
if an ECB VGA3 is fitted, a second login on its screen and PS/2 keyboard.
It runs from a CompactFlash card on the board's IDE port, and reads and
writes diskettes on an ECB Disk I/O V3.

There are two ways to put it on a board:

- **[Write the ready-made CF image](#1-quick-start-the-cf-card-image)** to
  a card. A few minutes; recommended.
- **[Install from diskettes](#3-installing-from-diskettes-on-the-board)**
  on the board itself, as the original kit was installed on a PC.
  *Not yet verified on hardware.*

Everything needed is in this folder. The rest of this file is
[how the images are built](#5-building-from-source) and
[what was changed](#9-what-was-changed-and-why), for anyone who wants to
change the kernel.

---

## Contents

1. [Quick start: the CF card image](#1-quick-start-the-cf-card-image)
2. [Using the system](#2-using-the-system)
3. [Installing from diskettes on the board](#3-installing-from-diskettes-on-the-board)
4. [What is in this folder](#4-what-is-in-this-folder)
5. [Building from source](#5-building-from-source)
6. [Making the development disk from scratch](#6-making-the-development-disk-from-scratch)
7. [Settings: tunables and patching](#7-settings-tunables-and-patching)
8. [Debugging aids](#8-debugging-aids)
9. [What was changed, and why](#9-what-was-changed-and-why)
10. [Known limitations](#10-known-limitations)
11. [Licence](#11-licence)

---

## 1. Quick start: the CF card image

### What you need

| | |
|---|---|
| Board | an SBC-386EX running the BIOS in this repository (`SBC386/bios`). Tested with 64 MB; COHERENT uses up to 16 MB |
| CF card | 32 MB or larger, on the board's IDE port. The image uses the first 30 MB (62,720 sectors); the rest is left alone |
| Terminal | on the board's first serial port (SIO0, COM1), **9600 baud, 8N1** |
| Optional | an ECB VGA3 with a PS/2 keyboard, for a second login |
| Optional | an ECB Disk I/O V3 floppy controller, jumpered for I/O 30h–3Fh, for diskettes |
| On the PC | a decompressor for `.gz` (7-Zip, or `gzip -d`), and a raw disk writer (Win32 Disk Imager, balenaEtcher, or `dd`) |

### Steps

1. **Unpack the image.** `images/sbc-cf.img.gz` becomes `sbc-cf.img`,
   32,112,640 bytes. (balenaEtcher can write the `.gz` directly.)
2. **Write it raw to the card.** It is a whole-disk image: partition table,
   master boot and filesystem. It replaces everything on the card.
3. **Check the card's geometry in SETUP.** The BIOS must see the card with
   **4 heads and 32 sectors per track**. The partition table was written
   for 490/4/32, and the master boot finds the partition by CHS. 492/4/32
   also works: the heads and sectors match, and the cylinder count only has
   to be at least 490. If the card comes out otherwise, set 490/4/32 in
   SETUP's fixed-disk geometry override.
4. **Boot.** On the serial terminal:

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

5. **Log in as `root`.** There is no password; set one with `passwd`.

With a VGA3 fitted, the monitor shows a second `login:` for the PS/2
keyboard, whatever SETUP's console choice. Without one, the serial side is
unaffected.

To check the download: `images/SHA1SUMS` has the SHA1 of every file in
`images/`.

---

## 2. Using the system

| | |
|---|---|
| Shut down | `shutdown` (or `sync; sync` then `/etc/reboot`). It restarts the board through the BIOS |
| The clock | read from the board's DS1302 at boot, through the BIOS. Set it in the BIOS SETUP; `date -s` changes only COHERENT's copy |
| Time zone | GMT, showing the DS1302's time unchanged: keep the DS1302 in local time, as DOS does |
| Diskettes | `/dev/fva0` 1.44 MB, `/dev/fha0` 1.2 MB, `/dev/fqa0` 720K, `/dev/f9a0` 360K; drive 1 is `fva1` and so on |
| DOS diskettes | `dos t /dev/fva0` lists one; `dos x /dev/fva0 FILE` extracts; `dos r /dev/fva0 FILE` writes. See `man dos` |
| COHERENT diskettes | `/etc/mkfs /dev/fva0 2880`, then `mount /dev/fva0 /mnt`. Diskettes must already be formatted (format them under DOS) |
| Manual pages | `man` *topic* |

The FPU is assumed fitted (an 80387; see [section 10](#10-known-limitations)).

---

## 3. Installing from diskettes on the board

> **Not yet verified on hardware.** Every step has been checked in QEMU
> except the parts only the board can run: booting from the floppy and
> reading the diskettes with the SBC floppy driver. Use the
> [CF image](#1-quick-start-the-cf-card-image) unless you want to try this.

This is the original COHERENT 4.2.10 install, adapted to the board. It
partitions the CF card, makes the filesystem and copies five diskettes
onto it. The result is the same system as the CF image.

**It erases the CF card.**

You need everything in [section 1](#what-you-need), including the floppy
controller and a 1.44 MB drive as drive A:, a BIOS that boots from A:,
and five 1.44 MB diskettes, write-protect off.

| Diskette | Image | |
|---|---|---|
| 1 | `images/sbc-b1.img` | boot diskette: the board kernel, console on the serial port |
| 2, 3, 4 | `images/sbc-d2.img` … `sbc-d4.img` | the original COHERENT 4.2.10 kit |
| 5 | `images/sbc-d5.img` | the board supplement: kernel and settings |

Write each raw (RawWrite for Windows, or `dd if=sbc-b1.img of=/dev/fd0` on
Linux). Use `sbc-b1.img`, not `sbc-d1.img`, which is disk 1 for a QEMU
install ([section 5.1](#51-or-an-install-set-for-qemu)).

1. Boot the board from diskette 1. Everything happens on the serial
   terminal.
2. At the `?` prompt type `begin`, then answer:

| Question | Answer |
|---|---|
| Serial number from the card | `146401000` (passes the installer's check) |
| Type of disk controller | `1`, AT-compatible |
| Use NORMAL polling | either; both give the board's port |
| Number of non-SCSI hard drives | `1` |
| IBM PS1 or ValuePoint | `n` |
| Install the COHERENT master boot | `y` |
| Are the values correct (490 or 492 cyl, 4 heads, 32 sectors) | `y` |
| Exit instead of zeroing the partition table | `n` |
| fdisk | `2` (change one), partition `0`, bases in cylinders `n`, sizes in tracks `y`, COHERENT partition `y`, base track Enter (1), size Enter; then `1` (active) `y` partition `0`; then `0` (quit), write `y` |
| Scan for bad blocks | `n` |
| Create a new filesystem | `y` |

3. It reboots when done. **Take diskette 1 out**, so the board boots the
   CF card. It asks for diskettes 2 to 5, then the configuration questions
   in [section 6.1](#61-install-coherent-4210-in-qemu) (the second table).
4. At the end it sets the system up for the board, ending with:

```
SBC-386EX: setting up the board system.
...
SBC-386EX: done.  This disk now boots the board kernel, /coh.sbc;
```

and reboots into the finished system.

---

## 4. What is in this folder

| Path | What it is |
|---|---|
| `images/` | **the finished images**: `sbc-cf.img.gz` (the CF card), `sbc-b1.img` and `sbc-d2.img`–`sbc-d5.img` (the board install set), `sbc-d1.img` (disk 1 for installing in QEMU), `SHA1SUMS` |
| `distrib/coherent/4_2_10/` | the original COHERENT 4.2.10 install kit, four 1.44 MB diskettes (`d1`–`d4`), which the images are built from |
| `sys.r12/` | MWC's COHERENT 4.2.12 kernel tree (from `gtz/src.gtz`), with our changes. Git history shows each change against the original |
| `board/` | the board's driver list and settings, and the scripts that build the kernel and set the system up, run inside COHERENT |
| `emu/` | scripts that run COHERENT in QEMU, build the images and transfer files |
| `tools/` | Python tools that read and write COHERENT filesystems from Windows and talk to the emulator |
| `readme.txt` | the archive's original index of `gtz/`, `romana/` and `distrib/` |

Not in git: `gtz/` and `romana/`, the source archives this was taken from,
and `emu/*.img`, the working disks.

---

## 5. Building from source

Only needed to change the kernel or the images. Everything is built on a
Windows PC in QEMU: the kernel is linked inside COHERENT, from MWC's 4.2.12
kernel sources and objects with our changes. Nothing is built on the board.

### What you need

| | |
|---|---|
| QEMU | `qemu-system-i386`, installed at `C:\Program Files\qemu` (`winget install SoftwareFreedomConservancy.QEMU`) |
| Git Bash | the scripts are `sh`; run them from Git Bash |
| Python 3 | the `py` launcher; the tools use only the standard library |
| The development disk | `emu/cf.img`, an installed COHERENT that holds the build trees. Not in git: [section 6](#6-making-the-development-disk-from-scratch) makes it, once |

Optional: `py -m pip install --user capstone keystone-engine` for
`tools/kdis.py` (disassemble the kernel) and `tools/mkcom.py`.

**Git Bash rewrites command arguments that start with `/`** into Windows
paths. Anything that passes a COHERENT path to a tool needs
`MSYS_NO_PATHCONV=1` set; the scripts do this themselves. Set it only for
`sercon.py`: `tools/push.sh` breaks under it.

### The pieces

| Path | What it is |
|---|---|
| `emu/run.sh` | start QEMU with the CF card's geometry (490/4/32), serial port on TCP 4555, control on TCP 4444 |
| `emu/boot.sh KERNEL` | reset the VM and boot a named kernel from the `tboot` prompt |
| `emu/pushsrc.sh` | copy `sys.r12/` and `board/` into the VM, under `/u/sbc` |
| `emu/mkrelease.sh OUT.img` | make a tidy board image from the development disk |
| `emu/mkdisks.sh` | make the install diskettes in `images/` |
| `tools/cohfsw.py` | write COHERENT filesystem images from the host: `mkfs`, `put`, `mkdir`, `rm`, `zerofree` |
| `tools/sercon.py` | run a shell command on the VM's serial port; `pull` copies a file out |
| `tools/push.sh` | copy files into the VM (tar on a FAT floppy QEMU builds from `emu/xfer/`) |
| `tools/cohfs.py` | read a COHERENT filesystem image from Windows |
| `board/mkkconf.sh` | *(runs in COHERENT)* build the kernel configuration tree `/u/sbc/kconf` |
| `board/mkboard.sh` | *(runs in COHERENT)* link the board kernel `/coh.sbc`, its QEMU twin `/coh.sbcq`, and the install diskette's kernel `/u/sbc/coh.fd` |
| `board/setup.sh` | *(runs in COHERENT)* serial console, VGA3 terminal, clock, timezone, `/autoboot` |
| `board/sdevice`, `board/stune` | the board's driver list and settings |

### Rebuilding

After a change to anything in `sys.r12/` or `board/`. From Git Bash, in
`Coherent/emu`:

**1. Start QEMU and boot the stock kernel.** It has the PC floppy driver
the file transfer needs; the board kernel drives the ECB controller instead.

```sh
./run.sh d1.img c &
until py ../tools/qmp.py hmp "info status" >/dev/null 2>&1; do sleep 1; done
./boot.sh coherent
py ../tools/sercon.py watch 120 'login: $'
py ../tools/sercon.py login root
```

**2. Copy the source in.** About ten minutes; one floppy-load at a time.
After that, push only what changed: `cd ..; tools/push.sh /u/sbc PATH...`.

```sh
./pushsrc.sh
```

**3. Build the kernel configuration tree, then the kernels, then the
system settings.** Each takes a few minutes; the second argument to `run`
is a timeout in seconds. Keep each command under about 250 characters:
COHERENT's terminal truncates longer lines.

```sh
export MSYS_NO_PATHCONV=1
py ../tools/sercon.py run "cd /u/sbc/board; sh mkkconf.sh > /tmp/mkk.log 2>&1; echo rc=\$?" 900
py ../tools/sercon.py run "cd /u/sbc/board; sh mkboard.sh > /tmp/mkb.log 2>&1; echo rc=\$?" 900
py ../tools/sercon.py run "cd /u/sbc/board; sh setup.sh > /tmp/setup.log 2>&1; echo rc=\$?" 300
```

Each should say `rc=0`. The logs stay in `/tmp` in the VM:
`py ../tools/sercon.py run "cat /tmp/mkb.log"`.

**4. Optional: try the QEMU twin.** `/coh.sbcq` is the board kernel with
the settings that differ in QEMU: 16-bit IDE, a 1.19 MHz timer, PC
keyboard and video ports. Everything on the serial port should look as
on the board, and the QEMU screen shows the second login.

```sh
./boot.sh coh.sbcq
```

**5. Stop QEMU and make the images.**

```sh
py ../tools/sercon.py login root
py ../tools/sercon.py run "sync; sync; sync" 30
py ../tools/qmp.py hmp quit
./mkrelease.sh ../images/sbc-cf.img && gzip -9 -n -f ../images/sbc-cf.img
./mkdisks.sh
(cd ../images && sha1sum *.img *.gz > SHA1SUMS)
```

`mkrelease.sh` copies `cf.img`, boots the copy, deletes the build trees
and anything else the board does not need, and zeroes the free blocks,
so the image holds nothing it does not use and compresses to about 5 MB.
The development disk is left as it was. `mkdisks.sh` writes the
diskettes on the host, in seconds, with `tools/cohfsw.py`, not through
COHERENT's floppy driver, which in QEMU now and then never finishes a write.

`mkkconf.sh` is safe to run again after any source change, and
`mkboard.sh` always relinks from scratch. The build is reproducible: two
builds of the same source differ only in the kernel's COFF timestamp.

### 5.1 Or: an install set for QEMU

The other way to make a board disk is to install it in QEMU, exactly as
the original kit is installed ([section 6.1](#61-install-coherent-4210-in-qemu)),
with `images/sbc-d1.img` … `sbc-d5.img` in place of `d1`–`d4`. The
installer finishes with a disk that boots the board: no pushing, building
or trimming.

```sh
"/c/Program Files/qemu/qemu-img.exe" create -f raw inst.img 32112640
IMG=inst.img GUI=1 ./run.sh ../images/sbc-d1.img a
```

| Disk | Contents |
|---|---|
| 1 (`sbc-d1.img`) | the original, with `/etc/brc.install` and `/etc/brc.update` asking for five diskettes, and `board/Coh_420.post.sbc` appended to `/conf/Coh_420.post` |
| 1 for the board (`sbc-b1.img`) | `sbc-d1.img` with the board kernel `/u/sbc/coh.fd` (root on the floppy) as `/coherent`; `/dev/console` on the serial port; and `/etc/mkdev`'s IDE status port choices, 3F6 and 1F7, both made 1FE |
| 2–4 | the originals |
| 5 | new, the board supplement: `/Coh_420.5` (the marker the installer checks for) and `compressed/sbc.taz`, holding `/coh.sbc`, `/coh.sbc.sym`, `/coh.sbcq` and `/u/sbc/board` |

The installer asks for disk 5 after disk 4 and unpacks it like the others.
At the very end, after its own questions, `/conf/Coh_420.post` runs
`board/setup.sh`. The disk keeps the QEMU twin `/coh.sbcq`
(`./boot.sh coh.sbcq`) so it can be tried in the emulator first.

---

## 6. Making the development disk from scratch

Once, or to start again. About forty minutes, most of it the installer.

### 6.1 Install COHERENT 4.2.10 in QEMU

```sh
cd Coherent/emu
for d in d1 d2 d3 d4; do cp ../distrib/coherent/4_2_10/$d $d.img; done
"/c/Program Files/qemu/qemu-img.exe" create -f raw cf.img 32112640
GUI=1 ./run.sh d1.img a
```

`GUI=1` opens a QEMU window. At the `?` prompt type `begin`, then answer:

| Question | Answer |
|---|---|
| Serial number from the card | `146401000` (passes the installer's check) |
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
| Floating point emulation | either; the board kernel sets its own |
| Parallel printer | change status `y` (disable it) |
| ptys, STREAMS | Enter throughout |
| Daylight saving, date, timezone | anything; `setup.sh` sets GMT, and the board reads its DS1302 |
| Site name | e.g. `sbc386`; domain Enter |
| Dictionary | `2` |
| Skip spooler configuration | `y` |
| Passwords, extra users | Enter throughout |

### 6.2 A login on the serial port

The tools talk to COHERENT over the serial port, so it needs a login
there. In the QEMU window, log in as `root` and:

```sh
sed 's/^0lPcom1l/1lPcom1l/' /etc/ttys >/tmp/t; cp /tmp/t /etc/ttys; sync
```

then halt (`sync; sync`) and close QEMU. From here on use `./run.sh`
without `GUI=1` and the tools. Keep a copy of this disk as it stands
(`cp cf.img cf-installed.img`); it is a clean start for next time.

Now carry on with [section 5](#rebuilding).

---

## 7. Settings: tunables and patching

The board kernel is MWC's with a handful of settings. Most are
**tunables**, set at link time from `board/stune`; `mkboard.sh` patches
the few that are not.

| Setting | Board | PC / QEMU | What it is |
|---|---|---|---|
| `ATSREG` | `0x1FE` | `0x3F6` | IDE status polling port, the **alternate** status. Reading `1F7` clears the drive's next interrupt, and multi-sector reads crawl |
| `AT_HFREG` | `0x1FE` | `0x3F6` | IDE device control register |
| `AT_8BIT` | 1 | 0 | byte-wide IDE data, `SET FEATURES 01h` after every reset |
| `AT_DRIVE_CT` | 1 | 0 | IDE drives; 0 would count them from CMOS, which the SBC lacks |
| `NDP_TYPE` | 3 | 0 | 80387 fitted; skips COHERENT's FPU probe, which faults on the 386EX |
| `CYRIX_CPU` | `0xFFFF` | 0 | skip Cyrix detection, which pokes port 22h |
| `CON_VGA` | 2 | 1 | VGA3 console: 2 = if its 8242 answers, 1 = always, 0 = never |
| `CON_CRTC` | `0x4E2` | 0 | CRTC port (HD6445 on the VGA3); 0 = the PC's |
| `CON_CGA` | 0 | 1 | the CGA mode/border/status registers exist |
| `KB_DATA`, `KB_STAT` | `0x4E0`, `0x4E1` | `0x60`, `0x64` | keyboard controller |
| `KB_XT`, `KB_SPKR` | 0, 0 | 1, 1 | XT keyboard acknowledge and PC speaker, both through port 61h |
| `FD_BASE` | `0x430` | | ECB floppy controller base port |
| `pit_count` *(patched)* | 9216 | 11932 | timer 0 reload for 100 Hz: the SBC's timer runs at 921,600 Hz |
| `condev` *(patched)* | `0x580` | `0x200` | kernel console: `/dev/com1l` |
| `early_con` *(patched)* | 0 | 0 | see section 8 |

Any of these can be changed in a built kernel, on the board or in QEMU:

```sh
/conf/patch -v /coh.sbc ATSREG=0x1FE     # the kernel file: from the next boot
/conf/patch -k /coh.sbc AT_TRACE=1       # the running kernel: now, until reboot
```

**Always give a value.** `/conf/patch /coh.sbc ATSREG` with no `=value`
does not display the setting: it sets it to zero.

---

## 8. Debugging aids

**Early console.** `/conf/patch /coh.sbc early_con=0x3F8`, then reboot.
Everything the kernel says before its drivers are up goes straight to
COM1, along with progress markers. (Normally that output is held back and
printed later, so a crash there shows nothing after `!`.)

```
!A*2[00068000 00F00000]zZY3456789UIa01234 ... 5 ... 678***
```

`A`–`I` are memory and paging set-up (the bracket is memory below 640K
above the kernel, and memory above 1 MB, in hex bytes); `a0`–`8` are
`main()`'s start-up steps. The last marker printed says how far it got.

**IDE trace.** `/conf/patch -k /coh.sbc AT_TRACE=1` prints a line of
the driver's activity on COM1: `R08` a read of 8 sectors, `i58` an
interrupt with status 58, `.` a sector moved, `T` a watchdog timeout.
Healthy:

```
R08i58.i58.i58.i58.i58.i58.i58.i58.
```

**Floppy errors** print the controller's status: `fd0: block N: ST0 x
ST1 y ST2 z`. ST1 `10` is an overrun (data not collected in time), ST1
`02` is write-protect (reported as `fd0: write protected`), ST1 `01` or
`04` is a missing or unreadable sector.

**Symbols.** `/coh.sbc.sym` maps addresses to names; `tools/kdis.py`
disassembles a kernel pulled out of an image with `tools/cohfs.py`.

---

## 9. What was changed, and why

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
| `coh.386/null.c` | `/dev/clock` fails at once when register A reads FFh | the same wait, in the kernel; the installer calls `ATclock` from places `setup.sh` cannot reach |
| `conf/fdc/src/sbcfd.c`, `fdpio.s` | floppy driver for the ECB FDC9266 at 430h, polled, ported from the SBC BIOS | no DMA or interrupt on that board; MWC's driver needs both. The data phase is assembly: in C it overran (ST1 10) |
| `conf/patch`, `install_conf/keeplist`, `board/sdevice` | `/dev/patch` in the board kernel, its tables cut to IDE, a repeat attach accepted; `ronflag`, `at_drive_ct`, `fl_dsk_ch_prob` patchable | the installer patches the running kernel and the one it installs, by name |
| `board/mkboard.sh` | COM3/COM4 not configured | each probe of an absent port costs a 209 ms bus timeout |

---

## 10. Known limitations

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
- **30 MB.** The image's partition is 30 MB, whatever the card's size.
  The rest of a larger card can be partitioned with `/etc/fdisk` and given
  a filesystem with `/etc/mkfs`.
- **Floppy: read and write only.** `sbcfd.c` reads and writes drives 0 and
  1 in the standard formats, polled, with interrupts held off for each
  sector's 512 bytes. It cannot format (`fdformat`); format diskettes
  under DOS. The autosensing "special" devices are not supported.
- **The board install is unverified.** [Section 3](#3-installing-from-diskettes-on-the-board)
  has not yet been run on a board.

---

## 11. Licence

COHERENT was released as open source, under the three-clause BSD licence,
by Mark Williams Company's founder Robert Swartz in 2015. That covers the
4.2.10 install kit in `distrib/` and the kernel in `sys.r12/`.
