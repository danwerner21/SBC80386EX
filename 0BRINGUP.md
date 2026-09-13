# SBC-386EX BIOS Bring-Up

**The plan that took this BIOS from "has never executed INT 13h" to a DOS 6 prompt, what
was found on the way, and what is left.**

| | |
|---|---|
| Tree | `SBC386/bios` |
| Board | RetroBrew SBC-386EX v2.0 |
| Toolchain | NASM + Open Watcom C 1.9 |
| Target | 64K ROM at `F000:0000` |
| Assessed | 2026-09-06, by code inspection |
| Last updated | 2026-09-12 — Phase 4 written and building, **not yet run** |

---

## The short version

**The board boots MS-DOS 6 to a `C:\>` prompt over the serial console, and the keyboard
works.** Phases 0 through 3 are complete and verified on hardware. Phase 4 — the INT 15h
calls DOS's standard drivers want — is written and **assembles clean**, but it has **never
been run**. Not one of those four calls has executed on the board. Section 06a is the
sequence for taking it to hardware.

The original assessment held up: nothing was architecturally wrong, and the work went in
the predicted order. What it could not predict was the hardware, and most of the time
spent went there rather than on the code. Section 04a records what the board and the
media actually turned out to do; several of those findings contradict what the source
comments and the datasheet-derived guesses said.

| Metric | Then | Now | |
|---|---:|---:|---|
| ROM image | 12,896 B | 32,768 B | of 65,536 — 50% free |
| Writable data segment | 0 B | 0 B | `_DATA` + `_BSS` still empty, as required |
| INT vectors that work | 4 | 13 | 10h, 11h, 12h, 13h, 14h, 15h, 16h, 17h, 18h, 19h, 1Ah, 1Eh*, IRQ0, IRQ4 |
| Blocking defects | 11 | 0 | all eleven fixed and confirmed on hardware |

\* INT 1Eh is a data vector, not a handler — it now points at a real diskette parameter
table instead of an `IRET`.

---

## 01 · What already works

Read against the source, POST is substantially complete and the low-level drivers are
real code, not placeholders.

### Board initialisation — `start.asm`

- Expanded I/O unlock (the `REMAPCFG` state machine), flags-register sanity test, then
  table-driven word and byte port init.
- Chip selects: UCS = 64K ROM at `F0000` (8-bit, 5 ws); CS0 = ECB I/O at `0400–04FF`;
  CS1 = IDE at `01F0` (8-bit, 3 ws); CS2 = DRAM `00000–FFFFF` (16-bit, 2 ws); CS3 =
  external memory at `B0000`; CS4 = SRAM, *disabled* at `HALF_MEM=0`. Refresh unit and
  watchdog bus monitor both enabled.
- Memory: walking-ones dword march over `0000:0000–9000:FFFF`, plus SRAM sizing.
  Extended memory is sized by dropping into 32-bit protected mode (`sizer.asm`) and
  returning to real mode — that machinery is working and will be reusable for INT 15h
  AH=87h.
- ROM CRC16 verified against the value planted at `0xFFEE` by `bin2hex`.
- CPU clock measured with the Timer 0 / Timer 1 gate trick, then PSCLK reprogrammed to
  exactly 1 MHz and the refresh counter recalculated for the measured clock. Nicely done.
- FPU probed via `FNINIT`/`FNSTSW`/`FNSTCW`; `equip_flag` bit 1 set accordingly.

### Drivers and services

- **INT 14h** (`14h_sio0.asm`) — complete and correct: init, write, read, status, PS/2
  extended init, divisor table to 460,800 baud. This is the console the whole BIOS
  currently speaks through.
- **INT 1Ah** (`1Ah_time.asm`) — functions 00–05 plus a DS1302-specific 20h–24h group
  (burst NVRAM read/write, write-protect, trickle-charge control). Timer 0 drives INT 08h
  at 18.2066 Hz, chaining INT 1Ch and servicing the BDA tick count, FDC motor timeout and
  the printer/serial countdown bytes.
- **INT 11h / INT 12h** — real, reading `equip_flag` and `memory_size` from the BDA.
- **ICU** — master and slave 8259s initialised AT-compatibly (vectors 08–0F and 70–77),
  with `mask_interrupt`/`unmask_interrupt` helpers.
- **IDE** (`diskide.asm`) — 8-bit PIO read, write, IDENTIFY and init. It enables ATA
  `SET FEATURES 01h` (8-bit transfers), which the board requires because CS1 is wired
  8-bit.
- **C runtime** — `printf` over INT 14h, `getchar`/`getline`, and `option_get` (a
  numbered-choice prompt). These are assembled into `set_top()`, a genuinely interactive
  SETUP menu reached by pressing a key during the POST scroll, backed by a CRC-protected
  31-byte NVRAM image. It now has six entries: Fixed Disks (geometry override, written),
  Floppy Disks (still a stub — there is no FDC), RS-232 Serial, Date/Time/Battery, Debug
  Monitor and Self test.

> **This section describes the tree as first assessed.** What follows in 02, 03 and 04a
> is what changed. The one structural claim here that is no longer true is the note that
> there was no command monitor: `debugmon.c` is now the largest single source file in the
> tree and the instrument most of the rest of this document was proven with. It hangs off
> SETUP entry 5, not off `set_fixed()` as originally suggested — `set_fixed()` turned out
> to be the natural home for the disk geometry override instead.

---

## 02 · The interrupt map

Everything the original assessment listed as missing or returning an error now works.
The remaining stubs are deliberate.

| Vector | Service | State | Notes |
|---|---|---|---|
| `00–07` | CPU exceptions | stub | All alias to a single `IRET`. Unchanged. |
| `08` | IRQ0 — timer tick | **working** | 18.2066 Hz, chains INT 1Ch, maintains BDA counters. |
| `0C` | IRQ4 — SIO0 receive | **working** | New. Drains the UART into the BDA ring buffer. |
| `09–0F` | other IRQs | EOI only | Non-specific EOI then `IRET`. |
| `10` | Video | **working** | `10h_video.asm`. Serial-only, ANSI/VT100. See section 04a. |
| `11` | Equipment list | **working** | Video bits now set; floppy bits still not. |
| `12` | Conventional memory | **working** | Reports 640K. |
| `13` | Disk | **working** | CHS 00/02/03/04/08/15 and packet 41–44/47/48. `4Eh` still stubbed. |
| `14` | Serial | **complete** | Console port now protected from re-initialisation. |
| `15` | Misc / system | **written** | 86h, 87h, 88h, C0h and 4Fh. Phase 4 — not yet built or run. |
| `16` | Keyboard | **working** | `16h_kbd.asm`. Interrupt-driven, 00/01/02 + 10h/11h/12h. |
| `17` | Printer | **working** | `17h_prn.asm`. Returns a clean not-present status. |
| `18` | Boot failure | **working** | Prints, drops into the monitor, retries on exit. |
| `19` | Bootstrap loader | **working** | `19h_boot.asm`. Loads and enters the boot sector. |
| `1A` | Time / RTC | **working** | Plus the DS1302 extension group. |
| `1B` / `1C` | Break / user tick | IRET | Correct as-is. |
| `1E` | Diskette parameter table | **written** | Real 1.44 Mb table in `stub.asm`. Not yet built or run. |
| `1D` / `1F` | Parameter tables | **not tables** | Still vector to code. No reader has ever asked. |
| `40` | Floppy | invalid cmd | Correct — no FDC. `floppy_call` now returns `RETF 2`. |
| `41` / `46` | Fixed disk parameter tables | **working** | Real `T_DISKTAB`s in the BDA, written at POST. |
| `70–77` | IRQ8–15 | EOI only | Cascade EOI handled correctly. |


## 03 · Defects found by inspection — all fixed

Eleven defects were found by reading the source before any of it had run. **All eleven
were real**, and all are now fixed and confirmed on hardware. The list is kept because
it is a fair record of what a careful read can and cannot find: every one of these was
genuine, and none of the problems that actually cost the most time are on it.

| # | Where | Defect | Fix |
|---|---|---|---|
| 1 | `main.c` | Drive registration ran only when `code` was non-zero — the condition was inverted, so a healthy board registered no disk | Removed; `hd_enumerate()` does it unconditionally |
| 2 | POST | `bda.hd_number` never written, so `get_disk_table` rejected every call | Written by `hd_enumerate()` |
| 3 | `13h_disk.asm` | `dtab_vectors` is a `db` table read as a word — index 0 returned `4641h` and the following `LES` built a garbage far pointer | Zero-extended byte load |
| 4 | `13h_disk.asm` | `fn41` tested `[bx+disk_flags]` with BX still holding the caller's `55AA` magic | `[di+disk_flags]` |
| 5 | `13h_disk.asm` | `fn42` hard-coded driver index 1, selecting the null DualSD slot | Derived from `disk_tab[]` via a new `drv_index` table |
| 6 | `13h_disk.asm` | `floppy_call` used a near `RET 2` inside an interrupt handler | `RETF 2` |
| 7 | `13h_disk.asm` | CHS entry points all aliased to invalid-command | Ported from `HardDisk/DIDE.ASM`; packet calls written |
| 8 | `diskide.asm` | DRQ polled once *before* the sector loop; ATA raises it per sector | Wait moved inside the loop, both directions |
| 9 | `diskide.asm` | Every failure collapsed to `AX=-1` | `ide_error` reads status + error registers, maps to BIOS codes, records `bda.hd_status` |
| 10 | `diskide.asm` | `loopnz CX=0FFFFh` timeouts — clock-dependent and milliseconds long | 5-second deadlines off the 18.2 Hz tick |
| 11 | `main.c` | `_main_()` ended in `testmain()` then powered down; no `INT 19h` anywhere | Tail replaced with `hd_enumerate()` then `INT 19h` |

Two more were found while working on the above, and are worth recording separately
because inspection had missed them:

- **`13h_disk.asm` — the packet dispatch range test was inverted.** `cmp ah,len_packet_call_tab / jb ret_invalid_command` rejected every valid packet call and let anything above the table jump through an out-of-range index. Now `jnb`.
- **`disktab.h` ended inside an unterminated comment.** Line 97 opened `/*IDE Command Constants...` and nothing closed it, so the file ran to EOF mid-comment. Harmless to `copt`, which does line-pattern rewriting, but no C file could ever have included it.


## 03a · Found after the fact

One more defect, found while building the rung 3 test rather than by the original read.
It is listed separately because section 03 is a record of what inspection caught *before
anything had run*, and this was not part of that.

| # | Where | Defect | Fix |
|---|---|---|---|
| 12 | `diskide.asm` | A sector count of zero reached the drive as a count of zero, which ATA defines as **256 sectors**, while the `LOOP` that drains DRQ ran 65536 times — 32 MB driven through the caller's buffer from a drive sending 128 KB | `IDE_READ_SECTOR` and `IDE_WRITE_SECTOR` now return success without touching the drive when the count is zero |

`fn42` and `fn43` can deliver one. `pkt_rw_validate` rejects a block count of 128 and
above but says nothing about zero, and the EDD packet interface both permits it and
defines it as "transfer nothing". The CHS path never could — `rwv_common` tests its own
count before the loop — which is part of why this sat unnoticed: DOS boots entirely
through CHS.

Two smaller things went with it. `IDE_READ_SECTOR` took the loop count with `mov CX,ARG(6)`
— a **word** load of an argument whose low byte alone had just been handed to the drive in
`wr_lba`, so the two could disagree the moment anything put rubbish in the high half; both
directions now zero-extend the same byte. And `write_data` was documented as taking its
buffer in `ES:[BX]` when `LODSB` reads it through `DS:[BX]`, which is what
`IDE_WRITE_SECTOR` has always set up. The code was right and the comment was wrong, which
is the more dangerous way round.

---

## 04 · Constraints that shape the work

Four properties of this build will dictate how you write every new module. Two of them
are easy to violate accidentally.

> **The one that will catch you out: there is no writable data segment.**
> The makefile puts `_TEXT`, `CONST`, `CONST2`, `_DATA` and `_BSS` all in `DGROUP`, which
> lives entirely in ROM — `start.map` shows `_DATA` and `_BSS` at zero length. Any C
> global or `static` you add lands in ROM. `const` data is fine and belongs there —
> `testmain.c` already uses `static const` tables — but anything you intend to *write*
> will silently discard the write. All mutable state must live in the BDA at `0040:xxxx`
> or on the stack. Add the field to `bda.h` and let `copt` regenerate `bda.inc`.

- **64K ROM window, ~52K free.** The UCS covers `F0000–FFFFF` only, and the current image
  is 12,896 bytes. Everything below fits comfortably; you are not space-constrained.
- **The console is SIO0, and only SIO0.** There is no video controller and no PS/2
  keyboard on the board. INT 10h and INT 16h must be a terminal emulation layered on the
  serial port — that is the single largest piece of new code in this plan, and the one
  most likely to need iteration.
- **IDE is wired 8-bit.** CS1 is configured with the bus-size bit clear, which is why
  `IDE_INITIALIZE` issues `SET FEATURES 01h`. Only drives that honour the 8-bit transfer
  feature will work.  Plan on CF -- but see 04a: the IDENTIFY bit that reports the
  feature turned out not to predict which cards actually work on this board.
- **The POST stack sits at `A800:0000`.** Because CS4 is disabled at `HALF_MEM=0`, that
  address is actually served by DRAM through CS2. It is above the 640K the BIOS reports,
  so it will not collide with DOS — worth keeping that way deliberately rather than by
  accident.
- **BIOS code executes from 8-bit ROM at 5 wait states.** Every INT 13h and INT 10h call
  pays for that. If disk or console throughput disappoints later, `SHADOW_MODE` is the
  lever.

---
## 04a · What the hardware actually does

Everything in this section was learned by measurement, on the board, after the original
assessment. Several items contradict what the source comments, the plan, or a reasonable
datasheet guess said — which is why they are written down.

### The IDE interface

- **The board is 8-bit only, and this is now proven rather than inferred.** A 16-bit
  `IN AX,DX` from the data port returns the low byte correct and **D8–D15 as zero**,
  while the card advances a full word — so half the sector is lost. `SET FEATURES 01h`
  is mandatory, not an optimisation.
- **`CFA-8bit` in IDENTIFY word 83 does not predict whether a card will work.** A
  SanDisk-class card reporting `no` reads flawlessly; two others reporting the same
  value return a fixed `XX XX XX 60` pattern with no disk content in it. Whatever
  separates working cards from broken ones on this board, it is not that bit. Test each
  card; do not trust the flag.
- **Some cards deliver 511 bytes per sector and drop DRQ a byte early.** An STI Flash
  card read bytes 0–510 perfectly and never presented byte 511, so every sector came
  back with its last byte missing — enough to fail the `AA55h` signature test while
  looking otherwise healthy. Not the board: another card in the same socket delivers 512.
  Ruled out with evidence: the transfer loop, DRQ gating, the SRAM buffer, byte
  alignment, a latching adapter, and 16-bit transfers.
- **CS1 wait states were 3**, against 7 for the other external peripheral on `CS0`. Not
  the cause of anything found so far, but thin for a CF card. Still `3` in `wtab1`.

### Timers and interrupts

- **Timer 1 is not running.** `start_timer0_` in `1Ah_time.asm` writes
  `TIMER_STOP + BIT1`, which opens counter 0's gate only. Anywhere this plan says "use
  the 1 MHz Timer 1", it must be enabled first. The IDE timeouts use the 18.2 Hz tick
  instead, which is coarse but running and clock-independent.
- **PSCLK is nearer 400 kHz than 1 MHz.** `CLKPRS` is set to 48 in `start.asm`, and by
  the divider in that comment `(CLK2/2)/(denom+2)` gives 400 kHz at a 20 MHz core. The
  "1 MHz Timer 1" in Phase 4 needs checking before it is relied on.
- **SIO0 receive is on IRQ4 — INT 0Ch.** Measured with the monitor's `IRQFIND`, which
  samples the ICU request registers with all masks closed. The vector table already
  labelled `int_irq4` "(COM1)", so wiring and measurement agree.

### The toolchain

- **Open Watcom will not reinterpret an integer as a far pointer.** The obvious idiom
  for writing an interrupt vector,
  `*(void **)(((dword)seg << 16) | off) = addr`, produced a **DS-relative** address —
  the write went into ROM at `DGROUP:0104` and did nothing, silently, while
  `bda.hd_number` written through the real far pointer in `bda_ptr` worked fine. Build
  far pointers through a union. This cost a long detour: INT 41h pointed at ROM, so
  `cv_lba` read its geometry out of code and every INT 13h read timed out.
- **`cprintf` keeps the character in BX across the `putch(CR)` that precedes
  `putch(LF)`.** It is in the prebuilt `lib/sbc386.lib`, so the callee has to
  accommodate it: `VIDEO_putchar_` must preserve BX. Adding an innocuous `xor bx,bx`
  cost every line feed in the BIOS. Watcom's register convention says BX is scratch, so
  this is `cprintf` relying on something it should not — worth remembering if
  `sbc386.lib` is ever rebuilt.
- **A makefile rule inserted between a target and its recipe silently breaks both.**
  `stub.o` lost its recipe and stub's command became the second line of `19h_boot.o`'s,
  so building `19h_boot.o` assembled `19h_boot.asm` and then overwrote it with
  `stub.asm`. The object's THEADR record is what gives this away.

### DOS and the media

- **DOS reprograms COM1 during SYSINIT.** Its AUX device initialisation calls INT 14h
  `AH=00`, and on this board AUX *is* the console — so the divisor latch changed and
  every byte after it arrived at the wrong rate. `init_sio` now leaves the console port
  alone. Function 4, the extended init, is deliberately still open because that is what
  `install_serial_console()` uses at POST.
- **CHS geometry must match whatever partitioned the card, not what the card reports.**
  A card reporting 492/8/16 held an image built as 492/4/32; the MBR locates the boot
  record by the CHS in the partition entry, so it read LBA 16 instead of 32 and printed
  "Missing operating system" while being entirely intact. Both geometries are exact for
  the card — CHS on a translating BIOS is a convention, not a property of the medium.
  SETUP now stores an override in NVRAM.
- **`ebda_alloc()` does not exist.** It is declared in `main.c` and has never been
  written. The fixed-disk parameter tables live in `bda.rsvd_unused[]` instead — two
  20-byte `T_DISKTAB`s in 41 bytes, with one byte spare. A third drive will not fit.

### Method

The single most valuable thing built was the monitor, and the most valuable habit was
**measuring instead of reasoning**. Every problem in this section that resisted
inspection — the missing sector byte, the IRQ number, the lost line feeds, the INT 41h
vector — was settled by adding a command that reported what the hardware was actually
doing, usually in one build cycle. Several confident diagnoses made from the source
alone turned out to be wrong.

---


## 05 · The plan

Ordered by dependency, not by size. Phase 0 builds the instrument the rest of the plan is
tested with; disk comes next, because with that instrument in hand you can prove out
storage over the serial console you already have, before taking on the much fuzzier
console emulation. Effort figures assume you already know this codebase.

### Phase 0 · Ground truth and a monitor — **DONE**

> Before changing anything, make the build reproducible and build the instrument you will
> diagnose everything else with. You are about to do a lot of surgery on code that has
> never run, and right now the ROM has no way to ask the hardware a question
> interactively.

- **git** — Put the tree under version control. There is no repository here today, and
  the next four phases touch nearly every file.
- **build** — Fix the `rom128/256/512.hex` targets; they currently emit empty files
  (`:00000001FF`), only `rom064.hex` is real. Generate `date.inc` from the build rather
  than hand-editing it.
- **new** — **Build the command monitor.** A `while` loop over `getline()` and a small
  command table is all that is missing — `printf`, `getchar`, `getline` and `option_get`
  already work. Hang it on the `set_fixed()` entry in `set_top()`, which is a stub today
  and is exactly where disk commands belong.
- **commands** — Start with four: IDENTIFY dump, LBA sector dump in hex, BDA dump, and an
  I/O port peek/poke. These are the instrument for all of Phase 1 and the first six rungs
  of the bring-up ladder.
- **watch out** — No writable statics, see section 04. A command table must be `const`;
  any line buffer or parsed argument has to be a local on the stack.
- **log** — Capture a serial log of the current POST as a baseline to diff against.

### Phase 1 · Make INT 13h real — **DONE**

> The deepest work in the plan. Target: `AH=02h` CHS reads and `AH=08h` geometry queries
> that a DOS boot sector will accept, backed by an IDE driver that survives multi-sector
> transfers.

- **new file** — **Disk enumeration at POST.** Add a `hdinit` module: soft-reset the
  interface, issue IDENTIFY to master and slave, and parse words 1/3/6 (default
  geometry), 49 (capabilities) and 60–61 (LBA sector count).
- **tables** — Build a `T_DISKTAB` per drive and point the **INT 41h and INT 46h vectors**
  at them; they currently point at an `IRET`. Set `bda.hd_number` and `bda.disk_tab[]`
  here, unconditionally, and delete the inverted assignment in `main.c`.
- **geometry** — Choose an LBA-assist translation (16/32/64/128/255 heads × 63 sectors)
  so the reported cylinder count stays ≤1024. Store both the physical and translated
  geometry; AH=08h returns the translated one.
- **port** — **Port the CHS entry points from `SBC386/HardDisk/DIDE.ASM`.** The SBC-188
  driver already implements fn00, 02, 03, 04, 08, 15 and a working `cv_lba` CHS→LBA
  conversion against the same BDA layout. This is the single biggest shortcut available
  to you.
- **fix** — Repair defects 03–07: byte-load `dtab_vectors`, use `DI` in fn41, derive the
  driver index from `disk_tab[]` in fn42, and change `floppy_call` to `retf 2`.
- **driver** — In `diskide.asm`: move the DRQ wait inside the sector loop, read the error
  register on failure and map it to BIOS status codes, and replace the `loopnz` timeouts
  with 1 MHz Timer 1 deadlines.
- **status** — Record the last operation's result in `bda.hd_status` and implement fn01
  (get status); DOS reads it after failures.

### Phase 2 · Bootstrap and hand-off — **DONE**

> Small, and it makes the machine feel like a PC for the first time. Prove it with a
> hand-written boot sector that prints through INT 14h — that isolates the boot path from
> the console work in Phase 3.

- **new file** — **INT 19h.** Model it on `ATBIOS/test6.asm : BOOT_STRAP_1`, which you
  already have: clear `0000:7C00`, retry loop, read drive 80h cylinder 0 / head 0 /
  sector 1 via `AH=02h`, verify the `0AA55h` signature at offset 510, set `DL=80h`, then
  `jmp 0000:7C00` with DS=ES=0 and a sane SS:SP.
- **POST** — Replace the tail of `_main_()`: after the summary, issue `int 19h` instead of
  `testmain()`. Keep the self-test reachable from a keypress or a SETUP menu entry so you
  do not lose it.
- **INT 18h** — On boot failure, print a real message and drop into the Phase 0 monitor
  rather than halting or returning an error code. This is what makes a failed boot
  debuggable instead of silent.
- **setup** — Implement `set_fixed()`; currently it prints "not implemented". A
  boot-device byte in NVRAM plus the drive table it already has room for.

### Phase 3 · Console — INT 10h, 16h, 17h — **DONE except VT100 escape translation**

> A serial terminal pretending to be a PC display and keyboard. Scope this to what IO.SYS
> and COMMAND.COM actually call; resist building a full VGA BIOS.

- **INT 10h** — Minimum viable set: `0Eh` teletype, `0Fh` get mode, `03h` get cursor,
  `02h` set cursor, `06h`/`07h` scroll, `09h`/`0Ah` write char (+attr), `00h` set mode,
  `08h` read char/attr, `01h` cursor shape (accept and ignore), `05h` set page. Emit
  ANSI/VT100 sequences for positioning and scrolling; maintain `vid_mode`, `vid_columns`
  and `vid_cursor[]` in the BDA as you go.
- **decision** — Keep a real 80×25×2 text buffer at `B800:0000` (DRAM already covers it)
  and mirror writes to the serial line. It costs 4K of DRAM you are not using, makes
  `08h`/`09h`/`0Ah` honest, and gives programs that write video memory directly somewhere
  valid to land.
- **INT 16h** — Functions 00/01/02 and 10h/11h/12h, fed from a ring buffer in the BDA;
  `buffer_head`, `buffer_tail` and `kbd_buffer[16]` are already defined. Translate inbound
  VT100 escapes (arrows, Home/End, function keys) into PC scan codes, map DEL/BS sensibly,
  and synthesise a scan code for each ASCII character from a table.
- **important** — **Make serial receive interrupt-driven.** INT 14h is polled; if INT 16h
  only polls, every keystroke typed while DOS is producing output is lost. Enable the SIO0
  receive interrupt and fill the BDA ring buffer from the handler. Decide this now —
  retrofitting it later means rewriting INT 16h.
- **INT 17h** — Return a clean "not present / timeout" status so DOS's LPT probe
  terminates instead of reading the invalid-command return.
- **plumbing** — Point `VIDEO_putchar_` in `stub.asm` at INT 10h so POST messages and DOS
  output share one path. Set the video bits (4:5) and floppy bits in `equip_flag`.

### Phase 4 · INT 15h and the parameter tables — **WRITTEN, NOT YET BUILT**

> The remaining calls DOS and its standard drivers make. None are needed for a bare boot;
> all are needed before the system feels finished.

All five items are implemented and the ROM builds. None has been **run** — see section
06a for the sequence.

The build confirmed the three encodings that could only be settled by assembling:
`lgdt [es:si+8]` came out `26 0F 01 54 08` with no `66` prefix, so it is the 16-bit
operand form that loads a 24-bit base, which is what the descriptor-as-pseudo-descriptor
trick depends on; both far jumps took the `EA` form with the right selector and segment
(`EA [offset] 2000` and `EA [offset] 00F0`); and the forward `ja .bad` was promoted by
`-O9` to the near form `0F 87 BE 00` rather than failing as an out-of-range short jump.
`_DATA` and `_BSS` are still zero bytes.

- **AH=88h** — Returns `bda.extended_memory` directly. That field is already the count of
  kilobytes above the first megabyte: `start.asm` sizes memory with `ext_mem_size`,
  subtracts one megabyte and stores the remainder, which is exactly what the call wants.
  HIMEM.SYS will not load without it.
- **AH=87h** — Extended-memory block move, in `15h_misc.asm`. It does **not** reuse
  `sizer.asm`'s machinery as the plan assumed, and the reason is worth recording: the
  interface hands the BIOS a GDT built by the *caller*, so `sizer.asm`'s ROM-resident
  `gdt0` is the wrong table. The three descriptors the interface reserves for the BIOS —
  08h, 20h and 28h — are written into the caller's table, which is the only writable
  memory this ROM has. The move runs in **16-bit** protected mode, not 32-bit: the
  caller's source and destination descriptors are 286-form with a 16-bit limit, so a plain
  `REP MOVSW` from offset zero reaches every byte either one can describe, and none of the
  32-bit entry and exit `sizer.asm` needs applies. Descriptor 08h is used as the `LGDT`
  operand where it sits — in 16-bit operand size `LGDT` takes a 16-bit limit and a 24-bit
  base, which is the first six bytes of a 286 descriptor exactly.
- **AH=86h** — Waits below 250 ms now go to `short_delay`, which samples Timer 1 at 1 µs.
  Two things the plan did not know: POST leaves **counter 1 gated off** (`start_timer0_`
  in `1Ah_time.asm` writes `TIMER_STOP+BIT1`, opening counter 0's gate only), so the gate
  has to be opened before the counter can be read; and `timer.inc` cannot be included to
  get the constants, because it emits a `binit` record at file scope that would plant three
  stray bytes in `_TEXT`. The ports and gate bits are spelled out locally instead, with a
  note saying why. The loop also watches the 18.2 Hz tick and gives up after eight of
  them: a counter that never moves would otherwise hang DOS inside INT 15h forever, and
  the tick comes from a different counter on a different clock, so it is independent
  evidence that time is passing.
- **AH=C0h** — Returns `ES:BX` pointing at a ten-byte configuration table in ROM: model
  FCh (PC/AT), submodel 01h, revision 00h, and feature byte 1 = 60h — bit 6 for the second
  interrupt controller (the 386EX ICU is a cascaded pair, master 20h and slave A0h) and
  bit 5 for the real-time clock (the DS1302, reached through INT 1Ah functions 02h–05h).
  Bit 4 stays clear because the keyboard path does not call AH=4Fh; bit 2 stays clear
  because no EBDA is allocated.
- **tables** — INT 1Eh now points at `disk_base_table` in `stub.asm`, the standard 1.44 Mb
  diskette parameter block, instead of at an `IRET`. Nothing ever acts on it — INT 13h
  sends every floppy call to `int_40h`, which returns invalid-command — but DOS reads it at
  startup and some drivers copy it into RAM and patch it rather than calling the BIOS at
  all, so what used to happen was that they read eleven bytes of a code stream and believed
  it.
- **verified by inspection, no change needed** — the INT 41h/46h tables from Phase 1 are
  what DOS expects. `T_DISKTAB` is `-zp1` packed, and every field a DOS-era reader looks
  for lands on its PC/AT offset: cylinders at 00h, heads at 02h, write-precompensation
  cylinder at 05h, the control byte at 08h (with bit 3 set for more than 8 heads), and
  sectors per track at 0Eh. `hd_identify()` zeroes the table before filling it, so the
  reduced-write-current and precompensation words read as 0, which is the AT convention.
  The private fields sit only where the standard put things no DOS reads: `unit_number` at
  07h (ECC burst length), `max_lba` across 0Ah–0Dh (the XT timeouts and the landing zone)
  and `disk_flags` at 0Fh (reserved).

### Phase 5 · Hardening — **not started**

> After DOS boots. None of this blocks the milestone.

- **reset** — Ctrl-Alt-Del path: warm-boot flag `1234h` at `40:72` and a clean re-entry to
  INT 19h.
- **speed** — Shadow the ROM into DRAM (`SHADOW_MODE`); the BIOS currently executes from
  8-bit ROM at 5 wait states, which every disk and console call pays for.
- **watchdog** — Confirm the bus-monitor watchdog does not trip during long DOS I/O. It is
  enabled today (`WATCH_BUS 1`).
- **slave** — Second IDE device, and the SD-card driver slots already reserved in
  `read_tab`/`write_tab`.

---

## 06 · Bring-up ladder

Each rung is independently observable on the serial console, and each one only depends on
the rungs below it. Do not skip ahead — a failure at rung 9 with rungs 1–8 unverified is
very hard to diagnose.

**All ten rungs are climbed except rung 3.** The CHS transfer loop calls the driver one
sector at a time and so sidesteps the multi-sector path, but `fn42` and `fn43` pass the
block count straight through and do depend on it — it is the only thing below the DOS boot
that remains unverified.

Rung 3 now has the command the rung actually describes: **`SECCMP <lba> [<sectors>]`**
reads N sectors in one driver call, then reads the same N one at a time, and compares them
byte for byte. Both paths go through `IDE_READ_SECTOR`, so what is under test is the
driver's own multi-sector loop rather than the raw port sequence `SEC2` walks. It finishes
by calling the driver with a count of zero, which is what defect 12 above was about — if
that line is the last thing on the console, the guard is not working.

The ladder earned its keep. Rungs 7 and 8 in particular — a hand-written boot sector
printing through INT 14h, then the same sector printing through INT 10h — were what
separated a boot-path fault from a console fault at the moment both were unproven.

1. **IDENTIFY dump** — Words 1/3/6 and 60–61 from the monitor. Proves the CF card, the
   8-bit feature negotiation, and CS1 timing.
2. **Raw LBA 0 dump** — 512 bytes in hex, ending in `55 AA`. Proves the PIO read path.
3. **Multi-sector read** — `SECCMP 0 8`. Reads 8 sectors in one command and compares
   against 8 single-sector reads. This is the test that catches defect 08, and it is how
   defect 12 was found.
4. **INT 13h AH=08h** — Geometry from the monitor. Proves enumeration, the disk tables,
   and the INT 41h vector.
5. **INT 13h AH=02h** — CHS read of cylinder 0 / head 0 / sector 1, byte-identical to
   rung 2. Proves the CHS→LBA conversion.
6. **Write and read back** — A scratch sector well away from anything you care about.
7. **Custom boot sector, INT 14h output** — A hand-written 512-byte sector that prints
   "HELLO" through the serial driver. Proves INT 19h with the console still out of the
   picture.
8. **Custom boot sector, INT 10h output** — Same sector, printing via `AH=0Eh`. Proves the
   video emulation's most-used entry point. Then a variant that echoes INT 16h input.
9. **DOS boot sector** — A real VBR that loads IO.SYS. Expect to iterate on INT 10h
   coverage here.
10. **Full boot to the prompt** — COMMAND.COM will exercise far more of INT 10h and
    INT 16h than anything before it.

### Media and DOS version

Prepare a CompactFlash card on a PC: one primary FAT16 partition, **504 MB or smaller**,
geometry 16 heads × 63 sectors. That keeps the whole boot chain inside plain CHS
addressing with no 1024-cylinder translation, which removes an entire class of problem
from the first bring-up. You can relax it later once the LBA packet calls are trusted.

Start with **MS-DOS 6.22**. Its BIOS demands are the most predictable and best documented,
and the AT BIOS listing you already have in `SBC386/ATBIOS` is the exact reference for
what it expects. Keep FreeDOS as a second target — it is more tolerant and more talkative
about what it finds, which makes it a useful diagnostic when 6.22 fails silently.

---

## 06a · Checking Phase 4

Phase 4 was written on a machine with no NASM and no Open Watcom, so none of it has been
assembled. Treat the first build as part of the work, not a formality.

The build is done and clean — see the note under Phase 4 for what it settled. What
remains is execution.

From the monitor (SETUP entry 5), the new `INT15` command. Each case checks the answer
against something other than the handler's own word for it.

| Rung | Command | What it proves | What failure looks like |
|---|---|---|---|
| 1 | `INT15 88` | AH=88h agrees with the BDA field and with what POST printed | `CY`, or a figure that does not match the `ExtMem` line |
| 2 | `INT15 C0` | the configuration table reads back with model FCh and features 60h | a length that is not 8, or a garbage model byte |
| 3 | `INT15 86 1000` | a 1 ms request returns quickly but not instantly | `0 tick(s)` every time means the counter never moved |
| 4 | `INT15 86 200000` | a 200 ms request waits about 4 ticks | `8 tick(s)` means the bailout tripped — counter 1 is not running |
| 5 | `INT15 87 100000 200000 256` | a 512-byte move between two extended-memory addresses | `CY`, a hang, or two lines that disagree |

Rung 3 is where a dead Timer 1 shows up, and rung 4 is where it shows up unmistakably:
the bailout exists precisely so that a counter that never moves costs 439 ms instead of
hanging DOS, and seeing 8 ticks is the symptom. If that happens, the gate write to
`TMRCFG` is the first thing to check — `IOR F834` reads it back.

Rung 5 is the one that can take the board down rather than return an error: a protected
mode fault has no IDT to land in. Write something recognisable into the source first
(`DUMP 100000` to see what is there), and expect to reset if it goes wrong.

Once those pass, the real test is DOS: `HIMEM.SYS` in `CONFIG.SYS` exercises 88h and 87h
together and is the reason 88h was the first item of the phase.

---

## 07 · Risks worth naming now

- **Serial input loss** is the most likely source of mysterious behaviour once DOS runs.
  Polled receive plus a busy CPU equals dropped keystrokes. Handle it in Phase 3, not
  later.
- **The ROM CRC check halts the machine.** POST verifies CRC16 against the value
  `bin2hex` plants at `0xFFEE` and executes `HLT` on mismatch. Any hand-patched image
  will brick silently — always go back through the makefile.
- **CS2 and UCS overlap at `F0000`.** Intel warns against overlapping chip selects and the
  README records real trouble here. It appears resolved, but a DOS program writing into
  segment F000 will land in DRAM, not ROM.
- **8-bit IDE limits your drive choice.** If a drive does not accept `SET FEATURES 01h`,
  no amount of BIOS work will make it read. Confirm at rung 1.
- **The 64K ROM window is a hard ceiling.** You have ample room today, but INT 10h with a
  text buffer, INT 16h with scan-code translation, and full INT 13h will together add real
  bulk. Watch `start.map` as you go.

### Where the leverage is

Two pieces of code already in this tree do most of the heavy lifting if you reuse rather
than rewrite: `SBC386/HardDisk/DIDE.ASM` is a complete, working INT 13h for the SBC-188
against the same BDA layout, and `SBC386/ATBIOS/ATBIOS/` is the IBM AT BIOS listing — the
definitive answer to "what exactly does DOS expect here" for the bootstrap, the disk calls
and the parameter tables. Between them, Phases 1 and 2 are largely a porting exercise.
Phase 3 is the part that is genuinely new work.

---

## 08 · Source tree inventory

Every source file in `SBC386/bios`, and whether the build actually touches it. Membership
was determined from the makefile's `OBJECTS` list cross-checked against the module list in
`start.map`, so "linked" means the object is genuinely in the ROM image, not merely that a
rule exists for it.

**40 of the 93 source files never reach the ROM.** Thirty-eight are not compiled at all;
two more are compiled into `sbc386.lib` but the linker never pulls them in. Almost all of
it is either SBC-188 heritage, prototype-era experiments, or the author's own numbered
backup snapshots.

| Metric | Count | |
|---|---:|---|
| Source files | 93 | 86 in root, 7 in `lib/` |
| Linked into the ROM | 22 | 19 asm/C + 3 from lib |
| Includes & build inputs | 27 | 7 of them generated |
| Not in the build | 40 | safe to remove after Phase 0 |

### A · Assembly modules in the ROM

| File | State | What it does |
|---|---|---|
| `start.asm` | linked | POST. Chip-select and port init tables, IVT population, memory march test, ROM CRC, CPU clock measurement, FPU probe, LED codes, then calls `_main_()`. |
| `boot.asm` | linked | The 16-byte reset block at `FFFF:0` — `jmp F000:0000` plus the date stamp. Both `%include`d by start.asm and assembled standalone to `boot.tmp` for exe2rom. |
| `sizer.asm` | linked | GDT prototype and the protected-mode entry/exit used to size extended memory in 1 MB steps. Reuse this for INT 15h AH=87h. |
| `crc.asm` | linked | CRC16 over `ES:BX`; built as `crc16.o` with `-dCRC16=1`. Used for the ROM self-check and the NVRAM checksum. |
| `diskide.asm` | linked | 8-bit PIO IDE driver: read, write, IDENTIFY, and the SET FEATURES 01h init. Defects 08–10 live here. |
| `13h_disk.asm` | linked | INT 13h dispatcher, driver tables and packet validation. Defects 03–07 live here. |
| `14h_sio0.asm` | linked | INT 14h serial driver plus `install_SIO0()` and the baud divisor table. |
| `15h_misc.asm` | linked | INT 15h dispatcher. Still only AH=86h, and only for delays over 250 ms. **Phase 4.** |
| `1Ah_time.asm` | linked | INT 1Ah, the IRQ0 tick handler, and the entire DS1302 RTC/NVRAM bit-banger. The largest module in the tree. |
| `11h_12h.asm` | linked | INT 11h equipment word and INT 12h conventional memory size. Both trivial, both correct. |
| `icu.asm` | linked | `mask_interrupt` / `unmask_interrupt` for the 8259 pair, callable from C. |
| `errno.asm` | linked | Returns a far pointer to the `errno` word in the BDA — the C library's only writable global. |
| `stub.asm` | linked | Placeholder handlers for every unimplemented vector. This is the file you delete from as Phases 2–4 land. |

### B · C modules in the ROM

| File | State | What it does |
|---|---|---|
| `main.c` | linked | `_main_()` — installs the serial console, prints the banner and machine summary, enters SETUP when needed, then calls `testmain()`. Defects 01 and 11 live here. |
| `set1302.c` | linked | The SETUP menu: `set_top`, `option_get`, and the clock, date, charger and serial editors. `set_fixed()` and `set_floppy()` are stubs. |
| `testmain.c` | linked | The compile-time-selected test script — CPRINTF, day-of-week, tick display, and probes for 4UART / VGA3 / CVDU ECB boards. |
| `getline.c` | linked | Line editor over the serial console. One of the pieces the Phase 0 monitor is built from. |
| `signon.c` | linked | `pr_lic()` copyright and GPL banner, plus `get_time`/`get_date` wrappers over INT 1Ah. |
| `strtobcd.c` | linked | BCD string parser used by the SETUP date and time editors. |

### C · lib/sbc386.lib

| File | State | What it does |
|---|---|---|
| `lib/cprintf.c` | linked | `printf`/`cprintf`. Output goes out through `VIDEO_putchar` in stub.asm, which today calls INT 14h directly. |
| `lib/strlen.c` | linked | Pulled in by cprintf's `%s` handling. |
| `lib/uart_det.asm` | linked | UART type detection. Reaches the ROM only because `test_4uart()` in testmain.c calls it. |
| `lib/atoi.c` | unlinked | In the library, but nothing references it. |
| `lib/testide.c` | unlinked | IDE exerciser. In the library, but `T_IDE` is 0 in testmain.c so it is never called. Worth reading before you write the Phase 0 monitor's disk commands. |
| `lib/libc.c` | unused | Commented out of the library makefile's `OBJECTS`. |
| `lib/makefile` | build | Builds `SBC386.lib`. Note it is *not* invoked by the top-level makefile — the library is stale unless you build it by hand. |

### D · Includes, headers and generated files

| File | State | What it does |
|---|---|---|
| `seg_def.inc` | included | Segment and DGROUP definitions. This file is the origin of the no-writable-data constraint in section 04. |
| `i386ex.inc` | included | 386EX peripheral register addresses and bit names, for assembly. |
| `i386ex.h` | included | The same register set for C. Used by main.c. |
| `macro.inc` | included | `binit`/`winit` init-table macros, `pushm`/`popm`, `get_bda`, and the GDT descriptor builders. |
| `timer.inc` | included | Timer and PSCLK constants, the MS18 / MS50 divisors, and the baud rate base. |
| `serial.inc` | included | Serial constants; included only by 14h_sio0.asm. |
| `CRC16TAB.INC` | included | CRC16 lookup table for crc.asm. |
| `date.inc` | included | The 8-character build date stamped into the reset block. Hand-edited — currently reads `09/26/26`. Phase 0 automates it. |
| `bda.h` + `bda.rul` | build input | The BIOS Data Area layout, and the `copt` rules that translate a C struct into NASM equates. `bda.rul` drives all four generated `.inc` files. |
| `bda.inc` | generated | From bda.h. Included by eleven modules — the shared vocabulary of the whole BIOS. |
| `disktab.h` → `disktab.inc` | generated | Fixed-disk parameter table and the INT 13h packet structures. Central to Phase 1. |
| `error.h` → `error.inc` | generated | BIOS status/error codes. |
| `stack.h` → `stack.inc` | generated | `offset_ax`, `offset_flags` and friends — for reaching into a saved register frame from inside an interrupt handler. |
| `nvram.h` | included | NVRAM layout and the device-code enum (`FX_IDEm`, `FX_uSD`…). Also pulls in bda.h and serial.h. |
| `disk.h` | included | Disk driver signatures and the device-number enum. Included by set1302.c. |
| `mytypes.h`, `cprintf.h`, `getline.h`, `ascii.h`, `serial.h`, `strtobcd.h` | included | Small C headers — base types, the printf and line-editor prototypes, ASCII names, serial config struct, BCD parser prototype. |

### E · Not in the build — the dust

| File | State | What it is, and whether to keep it |
|---|---|---|
| `alloc.asm` | unused | EBDA / UMB allocator. `main.c` declares `ebda_alloc()` but never calls it. **Keep** — Phase 4 may want it. |
| `baseio.asm` | **broken** | Dual-SD-card board I/O. It `%include`s `sdcard.inc`, which does not exist anywhere in the tree, so it cannot assemble even if you added it to the makefile. |
| `microsd.c` | unused | On-board micro-SD driver skeleton. The matching slots in `read_tab`/`write_tab` in 13h_disk.asm are null pointers. |
| `ds1302.asm` | superseded | Earlier standalone RTC driver. The live version lives inside 1Ah_time.asm. |
| `dsreg.asm` | superseded | DS1302 register definitions in *MASM* syntax (`TITLE`, `PAGE`, `.xlist`) — wrong assembler for this build entirely. |
| `muldiv.asm` | unused | Its entire body is wrapped in `%if 0`. |
| `notice.asm` | unused | A boilerplate copyright block meant for inclusion everywhere. Nothing includes it. |
| `equates.asm` | unused | SBC-188 equates. |
| `sbc188.h`, `libc.h` | unused | SBC-188 leftovers. Both are still listed in the makefile's `CINCL` variable but included by nothing. |
| `pm_sio.asm`, `pm_test.asm`, `rm_test.asm` | unused | Prototype-era protected-mode serial and memory-test experiments. `sizer.asm` is the survivor of this line of work. |
| `startup.asm` | superseded | The old monolithic TEST1 ROM. The makefile still carries a rule for it, explicitly labelled "obsolete". |
| `seg.c`, `seg_at.asm`, `make.seg` | unused | A self-contained three-file experiment proving `SEGMENT AT 40h` addressing of the BDA. Its conclusion is already baked into bda.inc. |
| `zero.asm`, `zero.inc`, `zero.h`, `zero.rul` | unused | A BDA-zeroing helper, fully wired into the makefile — `zero.inc` is even listed in `INCLUDES` — but `%include`d by nothing. The corresponding zeroing code in start.asm is inside a `%if 0`. |
| `disk.inc` | unused | A copt-generated copy of disk.h that no module includes. |
| `remover.h` | unused | Three `#define` tricks that let one file serve as both a `.inc` and a `.h`. Nothing uses it, but it documents the technique — **keep the comment** if you delete the file. |
| `test.c`, `tcrc.c`, `testide.c` (root) | unused | Scratch and host-side test programs. The root `testide.c` is a duplicate of `lib/testide.c`; check which is newer before deleting either. |
| `start.lkk` | unused | An old wlink response file. The makefile line that used it (`WLINK @start.lkk`) is commented out. |
| `makefile.188`, `makefile.abs` | unused | The SBC-188 makefile and an absolute-address build variant. |
| `1Ah_time.as0`, `diskide.as0`, `start.as1`, `startup.as0`, `uart_det.as0/.as1/.as2`, `main.c7` | backups | The author's own numbered snapshots of files that still exist in current form. `main.c7` is a Microsoft C7 variant of main.c. **Delete these only after Phase 0 puts the tree under git** — they are the sole record of some earlier revisions. |

### F · Documentation

| File | State | What it is |
|---|---|---|
| `0UPDATE.TXT` | read this | Mandatory board wiring updates, including the DCTL16-7 GAL change and the FPU-detect jumper. Check it before flashing anything. |
| `0README.TXT` | keep | Dated build history back to 2017 — the overlapping chip-select saga and the MF/PIC console fallback are both documented here. |
| `0USAGE.TXT` | keep | The BDA fields regrouped by subsystem rather than by address. Derived from bda.h; genuinely useful reference for Phases 1–3. |
| `COPYING` | keep | GPLv3. |

### Two makefile cleanups worth doing at the same time

The bottom of the makefile carries a "Leftovers from SBC188" dependency block naming
eleven files that do not exist in this tree — `sio.c`, `nvram.c`, `debug.c`, `kbd.c`,
`m8563lib.c`, `vga3lib.c`, `fdc8272.c`, `wd37c65.c`, `dprintf.c`, `font2.c` and `foo.c`.
They are harmless, but they make the file much harder to read than it needs to be.

The dependency variables are stale in both directions. `INCLUDES` still lists `zero.inc`,
and `CINCL` still lists `zero.h` and `sbc188.h`, none of which anything includes any more.
More usefully, **`serial.inc` appears in no dependency list at all** even though
14h_sio0.asm includes it — edit that file today and the build will not notice.

---

## 09 · Open items

Small things that are known, deliberate, or simply not done yet. None of them block the
DOS prompt.

### Functional gaps

- **VT100 escape translation — deliberately not being done.** Arrow keys, Home/End and
  the function keys arrive as `ESC [ A` and reach the ring buffer as three separate
  characters, so DOS's command-line editing is broken at every prompt. It would need a
  small state machine in the IRQ4 handler. **Deferred on purpose:** a real video card and
  a real keyboard go onto this board after Phase 5, and at that point INT 16h stops
  translating a terminal's escape sequences and starts reading scan codes from hardware
  that emits them natively. Writing the state machine now means writing something built to
  be deleted. The serial console keeps working for everything except in-line editing until
  then.
- **INT 10h function 08h cannot report screen contents.** There is no display buffer —
  a deliberate choice, since real memory-mapped video is planned for this board and a
  pretend buffer at `B800:0000` would only have to be torn out again. `08h` returns a
  space in attribute `07h`; `09h`/`0Ah` write to the terminal and restore the cursor
  rather than editing a buffer. Everything DOS leans on is honest.
- **INT 13h `4Eh`** (set hardware configuration) still returns invalid-command. Normal.
- **`equip_flag` floppy bits** are still never set. Video bits now are.
- **Multi-sector transfers are unverified** — but `SECCMP` now exists to verify them,
  and writing it turned up defect 12. See the ladder note above.
- **All of Phase 4 is unverified.** It assembles; it has never run. Section 06a.
- **No boot-device byte in NVRAM.** Phase 2 called for one; `set_fixed()` stores geometry
  overrides instead, and `19h_boot.asm` has drive 80h hardwired. Nothing needs it yet,
  but the plan said otherwise and the plan was not followed here.
- **INT 15h `C1h`** (get EBDA) still reports unsupported, and feature byte 1 bit 2 says so.
  Nothing allocates an EBDA.
- **INT 15h `89h`** (enter protected mode) still reports unsupported. `AH=87h` now
  contains most of the machinery it would need.

### Housekeeping

- ~~**IDE wait states are still `3`** in `wtab1`.~~ **Done.** `CS1ADL` now carries 7,
  matching `CS0`. The value had already been proven at runtime from the monitor; it is
  just permanent now.
- **The `0rom128.HEX` copy rule is still missing** from the makefile. It was removed
  while `all:` still listed the target, which made every build fail at the last step;
  the target was dropped from `all:`, so nothing regenerates that file now. Whatever you
  burn, do not burn `0rom128.HEX` expecting it to be current.
- ~~**SETUP halts instead of rebooting.**~~ **Done.** `set_top()` now calls `reboot()`
  in `19h_boot.asm`, which drains the console and jumps to `FFFF:0000` — the reset entry,
  where `bootstrap` in `boot.asm` sits — so a warm start takes the same path a cold one
  does. It is not a hardware reset and the peripherals keep their state, but `start.asm`
  survives re-entry: the expanded I/O unlock opens with a read of `REMAPCFGH` precisely to
  put that state machine back to a known point, and every port that matters is written
  from `wtab1`/`btab1` rather than assumed.
- **The makefile dependency block** still needs the cleanup described above — stale
  entries, and `serial.inc` in no list at all.

### Files added during this work

| File | Purpose |
|---|---|
| `debugmon.c` | The command monitor. Grew into the main diagnostic instrument. |
| `monitor.asm` | `go_call` — far-call an arbitrary address for the `GO` command. |
| `hdinit.c` / `.h` | IDE reset, IDENTIFY, geometry translation, enumeration, INT 41h/46h. |
| `strtoint.c` / `.h` | Hex string parsing for the monitor. `strtoint.h` did not exist; the function was being called with no declaration, so its `unsigned long` return was truncated. |
| `19h_boot.asm` | INT 19h bootstrap and INT 18h boot-failure handler. |
| `10h_video.asm` | INT 10h over ANSI/VT100. |
| `16h_kbd.asm` | INT 16h, the IRQ4 receive ISR, and the ASCII→scan-code table. |
| `17h_prn.asm` | INT 17h. |

Phase 4 added no files. `15h_misc.asm`, `stub.asm`, `start.asm`, `monitor.asm`,
`debugmon.c` and `debugmon.h` were extended.

### Monitor commands

`DUMP` `BDA` `IDENT` `LBA` `HDINIT` `GEO` `SECRAW` `SECRAW16` `SEC2` `SECTEST` `MKBOOT`
`BOOTCHK` `BOOT` `IOR` `IORW` `IOW` `IOWW` `IRQFIND` `GO` `INT15` `SECCMP` `EXIT`

Several were written to answer one question and kept because they answered it — `IRQFIND`
found the SIO0 interrupt line, `SECRAW` proved a card was short a byte per sector,
`MKBOOT` separated the boot path from the console, and `GEO` let a geometry be tried
without a rebuild.
