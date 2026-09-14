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
| Last updated | 2026-09-13 — ROM shadowing working on hardware; Phase 4 still unrun |

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
| ROM image | 12,896 B | 34,448 B | of 65,536 — 47% free |
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
| 12 | `diskide.asm` | A sector count of zero reached the drive as a count of zero, which ATA defines as **256 sectors**, while the `LOOP` that drains DRQ ran 65536 times — 32 MB driven through the caller's buffer from a drive sending 128 KB | `IDE_READ_SECTOR` and `IDE_WRITE_SECTOR` now return success without touching the drive when the count is zero. Confirmed on hardware |
| 13 | `19h_boot.asm` | `reboot_` jumped to the reset entry without setting **DX**, so POST's first instruction — `cmp dx,DEVICE_ID` — failed and dropped into `error_halt`. The board stopped dead with nothing on the console | `mov dx,DEVICE_ID` before the jump. Confirmed on hardware 2026-09-13 |

`fn42` and `fn43` can deliver one. `pkt_rw_validate` rejects a block count of 128 and
above but says nothing about zero, and the EDD packet interface both permits it and
defines it as "transfer nothing". The CHS path never could — `rwv_common` tests its own
count before the loop — which is part of why this sat unnoticed: DOS boots entirely
through CHS.

Defect 13 is the only one on either list that was found by **running** the code rather
than reading it, and it is a good argument for why that has to happen. Nothing about
`reboot_` looks wrong on the page: the routine assembles to exactly what it says, the far
jump lands on `bootstrap` in `boot.asm`, and `bootstrap` jumps to `F000:0000` the way it
does after a cold reset. What the page does not show is that DX carries the 386EX
component identifier out of a hardware reset and that `start.asm` tests it before doing
anything else — so a software restart has to present the register state a reset would
have, and this one did not. The value is a named constant in `i386ex.inc` now, used by
both the test and the routine that has to satisfy it, so the two cannot drift apart.

Two smaller things went with defect 12. `IDE_READ_SECTOR` took the loop count with `mov CX,ARG(6)`
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

- ~~**reset** — Ctrl-Alt-Del path.~~ **Done, confirmed on hardware 2026-09-13.** `reboot_` writes `1234h` to `40:72`, POST reads it before
  the segment-0 test and skips the 576K memory march, and the POST line confirms which
  path was taken. `reboot_` itself is proven, defect 13 and all. Section 06c.

  **The console reset trigger is done too**, and confirmed on hardware 2026-09-13.
  Operating notes for it live in `0README.TXT`, which is where someone looking at this
  board in a year will actually look. An earlier version of this note called it
  blocked, on the grounds that a serial console has no Ctrl and no Alt — `kbd_flag` is
  zeroed at init and never written, so there are no modifier states to test. True, and
  beside the point: nothing requires the sequence to be *Ctrl-Alt-Del*. Control characters
  arrive over the wire as ordinary bytes.

  **Three `Ctrl-^` in a row restarts the board.** `int_irq4` watches for them before the
  character goes anywhere and jumps straight to `reboot_`, so the restart is the same one
  SETUP uses, warm-boot flag and all. The matching characters are eaten rather than
  delivered — this is an escape out of the running system, not data, and a partial sequence
  reaching DOS would be worse than losing it.

  `1Eh` was picked over the more obvious Ctrl-`]` (`1Dh`) because that is the **telnet
  escape** and would be swallowed by the terminal program before ever reaching the board,
  and over Ctrl-`\` (`1Ch`) because that is SIGQUIT to a Unix terminal. Nothing in common
  use binds Ctrl-`^`. Both the character and the repeat count are named constants at the
  top of `16h_kbd.asm`.

  The counter lives in `alt_input`, the BDA byte that on a PC accumulates Alt+numpad digits
  and here has nothing to do. If real keyboard hardware ever arrives this moves to a real
  Ctrl-Alt-Del and the field goes back to its proper job.

  Any program can also set `40:72` and jump to `FFFF:0000`, which is the PC convention and
  this BIOS honours it.
- ~~**speed** — Shadow the ROM into DRAM (`SHADOW_MODE`).~~ **Done, confirmed on
  hardware 2026-09-13.** `shadow_rom` in `start.asm`; POST reports it and DOS boots from
  the shadowed copy. Section 06b.
- ~~**watchdog** — Confirm the bus-monitor watchdog does not trip during long DOS I/O.~~
  **Answered 2026-09-13, by measurement.** It cannot. Section 06d.
- ~~**slave** — Second IDE device.~~ **Done, confirmed on hardware 2026-09-13 at every
  layer**: enumeration, the driver transfer path, and INT 13h.
  A second CF card was fitted and both `IDENT 1` and `HDINIT` handle it:

  ```
  IDE master  LBA 62976 = 30 Mb  flags 0B
              drive 492/8/16   INT 13h 492/4/32   (translated)
  IDE slave   LBA 254208 = 124 Mb  flags 0F
              drive 993/8/32   INT 13h 993/8/32
  ```

  The slave needs no translation — 993 cylinders is inside the 1024 limit, so what INT 13h
  reports is the geometry the card reports. The master is translated and both figures come
  to the same 62976 sectors. Enumeration, the parameter tables and INT 41h/46h were already
  written for two drives in Phase 1; this is the first time a second drive existed to prove
  it.

  **The transfer path on unit 1 is confirmed too**, once `SECCMP` could reach it:

  ```
  MON>SECCMP 0 8 1
  SECCMP: slave, 8 sectors from LBA 0
  SECCMP: slave -- one command and 8 singles agree byte for byte
  SECCMP: zero-count guard ... returned 00 (want 00)
  ```

  It could not before. `SECCMP` took no drive argument and silently read the master —
  which is an easy thing to run against a freshly fitted slave and believe, and was run
  that way once. It takes a trailing drive now, like `IDENT` and `LBA`, and names the drive
  in its own output so the default cannot mislead again.

  **INT 13h against drive 81h** now has a command. `INT13 [drive]` calls AH=08h for the
  geometry, then AH=02h for a sector, and compares that against a direct driver read of the
  same sector — the INT 13h analogue of what `SECCMP` does one layer down. It proves
  `get_disk_table` finding the right `T_DISKTAB` for the drive code, `cv_lba` turning CHS
  into an LBA, and the dispatch through `bda.disk_tab[]` reaching the right unit. For the
  master all of that runs every time DOS boots; for the slave nothing exercises it, and
  nothing will until there is a filesystem on that card.

  The read is deliberately **not** at cylinder 0, head 0, sector 1. That is LBA 0 whatever
  `cv_lba` does with it, so the test would pass with the conversion completely broken. A
  cylinder, head and sector away from the origin are used instead, the LBA is computed from
  the geometry AH=08h reported, and the two reads are compared — so agreement means the
  BIOS and the monitor reached the same sector by different routes.

  Both drives pass:

  ```
  INT13: drive 81 -- 993 cyl, 8 head, 32 sec/trk;  2 drive(s) present
         reading C1 H2 S3, which is LBA 322
  INT13: slave -- INT 13h C1 H2 S3 and the driver at LBA 322 agree

  INT13: drive 80 -- 492 cyl, 4 head, 32 sec/trk;  2 drive(s) present
         reading C1 H2 S3, which is LBA 194
  INT13: master -- INT 13h C1 H2 S3 and the driver at LBA 194 agree
  ```

  The arithmetic cross-checks from two directions: `((1x8)+2)x32+2 = 322` for the slave and
  `((1x4)+2)x32+2 = 194` for the master, with the master using the **translated** 492/4/32
  rather than its physical 492/8/16 — which is the geometry AH=08h is supposed to report
  and the one `cv_lba` is supposed to convert against. `2 drive(s) present` is AH=08h
  returning the count from `bda.hd_number`.

  The master was worth running as a control even though DOS exercises that path daily: DOS
  never reads a sector at a CHS chosen to make a broken `cv_lba` visible.

  The SD-card slots in `read_tab`/`write_tab` remain reserved and empty.

### Phase 6 · Floppy — **starting**

> The first hardware added to this board since the BIOS began. Everything before this
> phase worked with what was already soldered down.

**The hardware.** An ECB Disk I/O V3, built around an SMC **FDC9266** — uPD765/8272
compatible with an integrated data separator. 34-pin connector, jumperable to Shugart or
PC pinout: four drives Shugart, two PC. 720 KB and 1.44 MB among the supported formats.

**It has no DMA.** That is stated by the board and corroborated by its own register map:
TC, which on a PC is a signal from the DMA controller, is a software-writable bit of the
digital output register here. So a transfer is the CPU moving 512 bytes through the data
register while polling the main status register, and asserting TC by hand at the end.

**Where it lives.** Z80 I/O port N reaches the 386EX at `0x400 + N` — the rule
`0README.TXT` records for the MF/PIC, and the reason `install_SIO0(0x448)` works. A card
jumpered to `30h-3Fh` is therefore at `0x430-0x43F`: status at `430` (aliases `432`, `434`,
`436`), data at `431` (aliases `433`, `435`, `437`), DOR/DIR at `438`.

**It will be polled, and that is a simplification rather than a compromise.** Every jumper
option for the interrupt pin is Z80-world — Z80 `~INT`, `~NMI`, the MF/PIC, or an
ECB-ModPrn CTC — and none of them is a 386EX ICU input. Since PIO puts the CPU in the
transfer loop regardless, an interrupt would only help with seek and motor-spinup
completion, and those poll perfectly well through MSR and SENSE INTERRUPT STATUS. `int_irq6`
stays the EOI-only stub it has always been.

**One consequence worth deciding before the driver is written.** 1.44 MB is 500 kbps — a
byte every 16 microseconds, about 320 clocks at 20 MHz. Comfortable, but nothing may stall
the loop for longer than that, and IRQ4 currently runs on every character the console
receives. Either the data phase runs with interrupts off, which is 8.2 ms a sector and will
drop keystrokes typed during a transfer, or it stays open and the IRQ4 handler has to be
measured against a 16 microsecond budget. The tick survives either way: 8.2 ms is well
inside one 54.9 ms period.

**Open, and being answered by probing rather than by asking:**

- ~~Shugart or PC pinout, and how many drives of what type~~ — **PC pinout, so two
  drives.** All four common types are wanted and configurable: 360Kb and 1.2Mb 5.25 inch,
  720Kb and 1.44Mb 3.5 inch. `set_floppy()` in `set1302.c` is implemented and stores the
  answer in `bda.floppy_tab[]`, inside the NVRAM checksum, exactly as `disk_tab[]` works
  for the hard disks. The type codes are the PC/AT CMOS values deliberately, because
  INT 13h AH=08h hands them back in BL. Nothing is probed and nothing can be: a PC floppy
  interface offers no way to ask a drive what it is, or even whether it is there
- ~~DOR bit 7~~ — **`~FDC_RST`, software-controlled reset.** Settled, and it matters more
  than it looks. The latch at `38h` is a **74LS273**, which clears to zero at power-on, so
  the board comes up with the controller **held in reset** and stays that way until
  software writes bit 7. A cold machine will read `00` from the status register, not `80h`.

  That latch is also **write only** — reading `38h` returns the digital input register, not
  what was last written — so every write has to supply all eight bits at once. A driver
  needs a shadow byte, and `bda.motor_status` is the place for it: it is the byte a PC uses
  for the same job, and the motor-timeout machinery around it is already wired. `int_irq0`
  counts `motor_count` down and calls `FDC_stop_motor`, which is a bare `ret` in `stub.asm`
  waiting to be filled in
- The P0/P1/P2 drive-select encoding — a single motor bit and three select bits is nothing
  like a PC DOR
- Which alias the board is actually jumpered to
- ~~How the data rate is selected~~ — **`MINI`, latch bit 2.** The schematic settles it.
  `FDC_CLK` comes from U16, a fixed 8 MHz oscillator with no divider and nothing switching
  it, which on a 765-family part is 500 kbps MFM. Taken alone that would make the board
  high-density only. But `MINI` is latch bit 2 wired to the FDC's MINI pin — the
  eight-inch-versus-mini-floppy input — and those two classes differ by exactly the factor
  of two between 500 kbps and 250 kbps.

  So the rate control is `MINI`, and **DENSEL is not a rate control at all**. JP6 connects
  DENSEL to the latch and from there out to the drive's density pin, which is why the
  board's own notes describe that bit purely in terms of what the drive does with it. Both
  rates are available and all four drive types are reachable. Worth confirming against the
  FDC9266 datasheet's description of the MINI pin before the driver depends on it.

  360Kb media in a 1.2Mb drive stays out of reach regardless — that needs 300 kbps, which
  two-rate hardware does not have. Genuine 360Kb drives are unaffected, and there are some
  here.

**Four more facts from the schematic that shape the driver:**

- **JP3 defaults to open — the FDC interrupt is not connected at all.** The polled design
  was already the right call for lack of a 386EX-compatible interrupt target; it is now
  simply the only option, unless that jumper is changed.
- **JP4 defaults to RDY tied to ground.** PC drives do not supply a ready signal, so the
  board fakes one and the controller always believes a drive is ready. The driver cannot
  use RDY to notice a missing drive, which is another reason drive presence has to come
  from the SETUP configuration.
- **JP5 defaults to always reporting TWO SIDES.** Harmless — all four supported types are
  double-sided.
- **Drive select does not come from the latch.** The FDC's own `US0`/`US1` outputs, which
  carry the drive number from the command byte, are decoded by a 74LS139 into four select
  lines. The latch's P0/P1/P2 bits feed the IBM-PC connector's motor and select pins
  instead. This is the part of the schematic hardest to read at the resolution available
  and the one place a driver is most likely to get it wrong, so it wants confirming before
  anything tries to select drive 1.

The `FDC` monitor command is the first step. It reads the status register at all four
aliases and the digital input register, and distinguishes a live controller from an empty
bus the only way that is reliable: an idle 765 reads `80h` and a floating bus reads `FF`.
If something answers, it issues SENSE INTERRUPT STATUS — a command that moves no media and
touches no motor — and reports what comes back. It writes nothing to the DOR.

---

## 06 · Bring-up ladder

Each rung is independently observable on the serial console, and each one only depends on
the rungs below it. Do not skip ahead — a failure at rung 9 with rungs 1–8 unverified is
very hard to diagnose.

**All ten rungs are climbed.** Rung 3 was the last, and it fell on 2026-09-13:

```
MON>SECCMP 0 8
SECCMP: 8 sectors from LBA 0 -- one command and 8 singles agree byte for byte
SECCMP: zero-count guard ... returned 00 (want 00)
```

`SECCMP <lba> [<sectors>]` reads N sectors in one driver call, then reads the same N one
at a time, and compares them byte for byte. Both paths go through `IDE_READ_SECTOR`, so
what is under test is the driver's own multi-sector loop — the per-sector DRQ wait and the
buffer advance `read_data` leaves in BX — rather than the raw port sequence `SEC2` walks.
The second line is defect 12: the driver called with a count of zero, which before the fix
would have asked the drive for 256 sectors and run the DRQ loop 65536 times.

This is the path `fn42` and `fn43` take. The CHS calls sidestep it by asking for one sector
at a time, which is why a DOS that boots proved nothing about it, and why it stayed the
last unverified thing below the boot for so long.

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

## 06b · ROM shadowing — **working**

Confirmed on hardware 2026-09-13. POST prints the shadowed line and MS-DOS 6 boots to a
prompt from the DRAM copy:

```
CPU_clk 20.00mhz  EquipFlag 0222h  ConvMem 640Kb  ExtMem 63Mb  SRAM 32Kb
BIOS running from DRAM, 16-bit at 2 wait states (shadowed)
```

The BIOS executed from 8-bit ROM at 5 wait states, and every INT 10h character and every
IDE sector paid for it. CS2 already covers the whole first megabyte of DRAM — 16 bits wide
at 2 wait states — and the two overlap at `F0000`. While UCS is enabled it is the one that
answers there, so the ROM cannot be copied over itself: the copy has to run from somewhere
else while UCS is switched off.

`shadow_rom` in `start.asm` runs immediately after `test_1to8`, which is the first moment
there is tested DRAM to copy into, and before anything records an `F000`-relative address:

1. Copy the ROM to a scratch segment at `XFER_AD` (`0x20000`), and compare it back.
2. Far jump into that copy, so execution is no longer inside the ROM.
3. Clear the enable bit in `UCSMSKL`. `F0000` answers from DRAM from here on.
4. Copy the scratch back to `F0000`, and compare it back.
5. Far jump to `F000`, which is now the DRAM copy.

There was an implementation in `unused/startup.asm` from the SBC188 era and it is where
the structure came from, but it could not be used as it stood: its jump back to `F000` is
inside an `%if 0`, so POST would have carried on at `CS=0x2000` and `set_the_vectors`
would have built the entire interrupt table with `mov ax,cs` pointing into scratch memory
that DOS later overwrites.

**Both checks can fail without consequence**, which is the part that made this safe enough
to enable by default. A failure at step 1 leaves the ROM exactly as it was. A failure at
step 4 switches UCS back on, and the far jump at step 5 returns to the real ROM rather
than to a copy that is not there. The board boots either way — slowly, but it boots. This
matters more than it looks: the DRAM under `F0000` is the **one part of the first megabyte
`test_1to8` never reaches**, and shadowing is what writes to it.

Because those fallbacks are silent, POST now prints which one happened:

```
BIOS running from DRAM, 16-bit at 2 wait states (shadowed)
BIOS running from EPROM, 8-bit at 5 wait states
```

That is read from the UCS enable bit, not from a flag anyone set — it is the hardware's
own answer. Without the line, a board that quietly fell back would look identical to one
that worked.

Two things to know about the result:

- **`F0000` is writable now.** Writes into the BIOS used to land on ROM and do nothing.
  Nothing in this BIOS writes there — `_DATA` and `_BSS` are empty by design — but a stray
  far pointer that used to be harmless is not any more.
- **`SHADOW_MODE` and `HALF_MEM` are mutually exclusive**, since `HALF_MEM` exists
  precisely to exclude the DRAM shadowing needs. Setting both is now an assembly-time
  `%error` rather than a build that copies 64K into nothing and jumps to it.

---

## 06c · The warm-boot flag — **working**

Confirmed on hardware 2026-09-13: a save from SETUP restarts the board and POST reports
the march skipped.

`reboot_` writes `WARM_BOOT` (`1234h`) to `bda.reset_flag` at `40:72` before restarting,
and POST skips the memory march when it finds it there.

The saving is worth more than it first looks. `seg_test` walks a single bit through all 32
bit positions, so every 64K segment costs 32 passes of a `REP STOSD` **and** a
`REPE SCASD` over 16384 dwords — about 1.05M dword bus cycles a segment, across nine
segments. On a 16-bit bus at 2 wait states that is seconds, not milliseconds.

POST says which path it took, because the first version of this did not and the difference
turned out to be hard to judge by eye against a boot that also spends 2.3 seconds in a
deliberate `delay(23)` waiting for a SETUP keypress:

```
Memory march skipped -- warm start, flag 1234h was set at 40:72
Memory march ran -- cold start
```

The answer is carried in `bda.mfg_test`, the BDA's own initialization-flags byte, which
nothing else in this BIOS writes. POST sets it on the warm path only, after the test of
segment 0 has zeroed the area, so a cold start leaves it at zero by simply not passing
through there.

The thing that needed care is **when** the flag can be read. POST's test of segment 0
zeroes the whole first 64K and the BDA lives inside it, so the flag has to be read before
that test and carried across to `test_1to8`, which is much later. It is parked in the
stack segment — the 32K at `A8000` that `size_SRAM` points SS at, which neither memory
test reaches (segment 0 covers `00000-0FFFF`, `test_1to8` covers `10000-9FFFF`). SP starts
at `8000h` and grows down, so a word at offset 4 is 32K clear of anything the stack will
touch, and `seg_test` has already been over that memory.

Being zeroed by the segment-0 test is also what **clears** the flag, so the start after a
warm one is cold again with nothing having to reset it explicitly. The magic value is
defined once in `bda.h` and reaches the assembly through the `bda.inc` that `copt`
generates from it, so `reboot_` and POST cannot drift apart on it.

Two things worth knowing:

- **A warm start does not zero memory.** `seg_test` clears what it tests, so `10000-9FFFF`
  keeps its previous contents on this path. Nothing in the BIOS depends on that zeroing,
  and segment 0 — vectors and BDA — is still tested and cleared every time. But it is the
  difference to reach for if something ever behaves differently after a SETUP reboot than
  after a power cycle.
- **A cold start could take the warm path by accident.** DRAM comes up indeterminate, so
  there is a 1-in-65536 chance the flag reads as `1234h` on a genuine power-on and the
  march is skipped. That is the same exposure every PC BIOS has had with this flag, and
  the cost is a boot that did not test its memory rather than one that misbehaves.

---

## 06d · The bus-monitor watchdog — answered

The Phase 5 item asked whether the watchdog can trip during long DOS I/O. It cannot, and
the margin is not close.

First, what a trip would actually do, because this is not the usual watchdog story.
`start.asm` sets BUSMON in `WDTSTATUS` and WDTRDY in `PWRCON`, so the watchdog's job is to
**supply READY** to a bus cycle that has not finished in time. A trip does not reset the
board; it terminates the cycle early with whatever happened to be on the bus. The symptom
would be silent bad data, which is why this could never have been settled by watching the
machine and waiting for something to go wrong.

The `WDT` monitor command reads the configuration out:

```
WDT: WDTSTATUS 02 -- bus monitor ON
     PWRCON    1C -- WDTRDY on, HSREADY on
     reload 003FFFFF = 4194303 counts   (never written by this BIOS)
     count  003FFFFF 003FFFFF 003FFFFF 003FFFFF
     at 20 mhz that is about 209715 usec before READY is forced
```

The reload value is `003FFFFF` — 2^22-1, the power-on default, since nothing in this BIOS
ever writes `WDTRLDH`/`WDTRLDL`. At 20 MHz that is **209 ms**. The slowest legitimate
access on this board is CS0 or CS1 at 7 wait states, which is roughly 9 clocks, or 450 ns.
The watchdog has about **466,000 times** the headroom it needs.

That conclusion does not depend on knowing the watchdog's exact clock source, which is the
one thing the command cannot tell you. Even at CLK2 rather than the CPU clock the timeout
is 105 ms; even at an implausible one count per nanosecond it would still be four
milliseconds, or nine thousand times the slowest access. Any reading of the datasheet
gives the same answer.

Two honest notes on that output:

- **The four count samples prove nothing**, and cannot. Reading the counter takes a bus
  cycle, and a bus cycle is exactly what reloads it in this mode, so `003FFFFF` is the only
  value the monitor can ever observe. The conclusion rests on the arithmetic, not on the
  samples.
- **`PWRCON` reads back `1C` where `start.asm` writes `0C`.** Bit 4 is set by something
  other than this BIOS. Nothing appears to depend on it and the board has run this way for
  years, but it is unexplained, and worth a glance by anyone who has the datasheet open.

### What this means for a future Unix

The watchdog needs no driver and cannot be starved: in BUSMON+WDTRDY mode there is no
interrupt, no reset and nothing to service. Coherent, or anything else, can ignore it.

The risk that does matter for a Unix is **device probing**. A Unix boot walks a list of
candidate I/O addresses looking for hardware. On this board only CS0 (`0400-04FF`), CS1
(`01F0-01FF`) and the 386EX internal peripherals claim a cycle at all. If an unclaimed
cycle runs all the way to the watchdog, every probe of absent hardware costs 209 ms — a
dozen probes is three seconds, and a driver polling a missing device in a loop is
indistinguishable from a hang. DOS gets away with this because it probes almost nothing.

**This is not yet known.** The HIMEM lockup is the one piece of evidence and it is
ambiguous: HIMEM spun reading port `64h`, which nothing decodes, and whether those reads
returned floating-bus `FF` immediately or took 209 ms each cannot be told apart from the
console. The `IOTIME` monitor command exists to settle it — time a read of an undecoded
port (`64`, `300`) against a decoded one (`1F7`, `F834`).

If undecoded cycles do cost 209 ms, the fix is cheap and belongs in the BIOS rather than
in the OS: shorten `WDTRLDH`/`WDTRLDL`, which this BIOS currently never writes at all.
There is five orders of magnitude of slack between the slowest real access and the current
reload, so a much shorter timeout would still be a safe bus-hang backstop while making a
failed probe cost microseconds instead of a fifth of a second.

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

### The makefile cleanup — **done 2026-09-13**

Two of these were real: a file could be edited and the build would not rebuild what
depended on it, which is the kind of fault that wastes an afternoon and a ROM burn before
anyone suspects the makefile.

- **`serial.inc` appeared in no dependency list at all**, though 14h_sio0.asm includes it.
  Added to `INCLUDES`.
- **`i386ex.h` was missing from `CINCL`**, though main.c includes it. The same fault, on
  the C side, and not previously noticed. Added.
- `zero.inc` left `INCLUDES`; `zero.h` and `sbc188.h` left `CINCL`. Nothing includes any
  of the three.
- Dependency lines for `foo.c`, `muldiv.asm`, `libc.c`, `microSD.c`, `testide.c` and
  `test.c` were removed. None of those sources is in this directory.

A third problem turned up while checking the first two, and it was the worst of them:
**eight modules spelled the include `i386EX.inc` while git tracks the file as
`i386ex.inc`**, and `INCLUDES` used the uppercase spelling too. That resolves only because
the filesystem is case-insensitive. On a case-sensitive one — which is what the build host
looks like from `start.map`, and what any Linux CI would be — eight of the sixteen assembly
modules would simply have failed to find their include file. All now spell it the way git
does.

Both variables are now derived from what the tree actually includes, transitive headers
included, and every name in them exists. Verified with a clean rebuild on 2026-09-13 —
which is the only way to check this particular class of fix, since the symptom of getting
it wrong is a build that does too little rather than one that fails.

> The **`0rom128.HEX`** item that used to sit here was overstated. There is no such file in
> `SBC386/bios`; the only copies in the tree are in `TestROMS/TEST1-2018-02-23/`, which is a
> 2018 archive and obviously not current. The `all:` target builds `rom064` through
> `rom512` and is self-consistent. **Decided 2026-09-13: no archive copies.** The build
> produces `rom064` through `rom512` and that is all it needs to produce; git already keeps
> the history, and a second set of files with a different naming convention was only ever a
> way to get that wrong.

---

## 09 · Open items

Small things that are known, deliberate, or simply not done yet. None of them block the
DOS prompt.

### Running DOS on this board

- **HIMEM.SYS needs `/MACHINE:PS2`.** Without it the machine locks up during CONFIG.SYS
  processing, before any driver message appears.

  HIMEM drives the A20 line, and on an AT-class machine it does that through the 8042
  keyboard controller. This board has no 8042 -- the keyboard is the serial console fed
  from IRQ4 -- and the only external I/O windows it decodes are CS0 at `0400-04FF` and CS1
  at `01F0-01FF`. A read of port `64h` therefore returns floating-bus `FF`, the
  input-buffer-full bit is set forever, and HIMEM spins in its wait loop. A20 here is the
  386EX PORT92, which POST enables once at `start.asm` and never touches again.

  `/MACHINE:PS2` selects handler 2, which uses port `92h`. Confirmed 2026-09-13:

  ```
  HIMEM: DOS XMS Driver, Version 3.09 - 02/23/93
  Installed A20 handler number 2.
  64K High Memory Area is available.
  ```

  This is not a workaround for a BIOS bug and there is nothing to fix in the ROM. No model
  byte says "AT in every respect except that it has no 8042", so `AH=C0h` reports the
  truth -- model FCh -- and the switch says the rest. It was worth asking whether a
  different submodel would steer HIMEM's auto-detection to handler 2 on its own; the answer
  is to leave it alone. An explicit switch is immune to HIMEM version differences, and
  reporting a PS/2 model to every other program that reads `C0h` in order to influence one
  driver is a bad trade. Revisit when real keyboard hardware lands after Phase 5 -- if it
  brings an 8042, auto-detection starts working by itself.

- **Three `Ctrl-^` restarts the board.** The console stands in for Ctrl-Alt-Del; see
  Phase 5. The characters are eaten, so a single stray `Ctrl-^` never reaches DOS. The
  restart sets the warm-boot flag, so it skips the memory march — power-cycle instead if
  what you want is a full test.

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

  Note that this reasoning does **not** extend to a console reset trigger, which was
  briefly listed as blocked for the same reason and is not — see Phase 5.
- **INT 10h function 08h cannot report screen contents.** There is no display buffer —
  a deliberate choice, since real memory-mapped video is planned for this board and a
  pretend buffer at `B800:0000` would only have to be torn out again. `08h` returns a
  space in attribute `07h`; `09h`/`0Ah` write to the terminal and restore the cursor
  rather than editing a buffer. Everything DOS leans on is honest.
- **INT 13h `4Eh`** (set hardware configuration) still returns invalid-command. Normal.
- ~~**`equip_flag` floppy bits** are still never set.~~ **Done** — set from the SETUP
  floppy configuration. Bit 0 for presence, bits 7:6 for the count less one. Until now
  INT 11h had been telling DOS this machine has no floppy drives, which until now was
  true.
- ~~**Multi-sector transfers are unverified.**~~ **Verified on hardware 2026-09-13**
  with `SECCMP 0 8`, along with the defect 12 guard. See the ladder note above.
- ~~**All of Phase 4 is unverified.**~~ **Phase 4 is fully verified on hardware**,
  2026-09-13. `87h` moved the first 512 bytes of the BIOS from `F0000` to the 2Mb mark
  through protected mode and compared clean -- the item that could have taken the board
  down. `88h` agrees with the BDA and is consumed successfully by HIMEM.SYS. `C0h` reads
  back correctly. `86h` measured **99%** of the time it was asked for over a 1.1 second
  run, which settles the one thing a single call could not: the counter is genuinely at
  1mhz, not merely moving. Section 06a.
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
- ~~**The `0rom128.HEX` copy rule is still missing.**~~ **Not a real problem** — no such
  file exists in the build directory, and `all:` is self-consistent. See section 08.
- ~~**SETUP halts instead of rebooting.**~~ **Done, and confirmed working on hardware
  2026-09-13** — saving from SETUP restarts the board and it comes back up through POST.
  `set_top()` now calls `reboot()` in `19h_boot.asm`, which drains the console, loads DX
  with `DEVICE_ID`, and jumps to `FFFF:0000` — the reset entry, where `bootstrap` in
  `boot.asm` sits — so a warm start takes the same path a cold one does. The DX load is
  defect 13: without it POST's first test fails and the board halts silently.

  It is not a hardware reset and the peripherals keep their state, but `start.asm`
  survives re-entry. The expanded I/O unlock is the part that had to be checked, and it
  is safe for a reason worth writing down: it talks to ports `22h`/`23h`, which are in the
  fixed AT range and respond whether or not the ESE bit is already set, and it opens with
  a read that returns the state machine to a known point from wherever it was. Everything
  else that matters is written from `wtab1`/`btab1` rather than assumed.
- ~~**The makefile dependency block.**~~ **Done 2026-09-13**, and it turned up two
  missing dependencies rather than one, plus an include-case mismatch that would have
  broken the build on any case-sensitive filesystem. See section 08.

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
`BOOTCHK` `BOOT` `IOR` `IORW` `IOW` `IOWW` `IOTIME` `IRQFIND` `GO` `INT13` `INT15`
`SECCMP` `WDT` `EXIT`

Several were written to answer one question and kept because they answered it — `IRQFIND`
found the SIO0 interrupt line, `SECRAW` proved a card was short a byte per sector,
`MKBOOT` separated the boot path from the console, and `GEO` let a geometry be tried
without a rebuild.
