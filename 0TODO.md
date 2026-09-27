# SBC-386EX BIOS — what is left

Opened 2026-09-20, the day Phase 6 closed. `0BRINGUP.md` is the record of how the board
got here and why things are the way they are; this is the shorter question of what remains.
Numbering is stable — items keep their number as they are done, so "item 9" means the same
thing in a commit message next month as it does here.

**All six phases of the bring-up plan are complete, and the board now has a console of its
own.** It boots MS-DOS 6 to a prompt from either a floppy or the fixed disk, formats its own
disks, and drives an 80x25 colour display and a PS/2 keyboard on the ECB VGA3 board — with
the serial console still live alongside it. Nothing on this list blocks anything else on it.

**The ROM is the constraint now.** 59,536 bytes of 65,536 are used: 9.2% free, down from 24%
when item 7 was measured. See item 15.

---

## Now — housekeeping

**9 · Shorten the watchdog reload. Closed 2026-09-20: cannot be done as written.**

An undecoded read costs **209.7 ms**, confirmed against the DS1302 — which is exactly `3FFFFF` counts at the 20 MHz CPU clock, the figure 06d derived in the first place.

`WDTSET` wrote reloads across an eight-to-one range, sent the reload sequence, and read the values back correctly. The timeout did not move. Since the duration matches 2^22 counts exactly, the bus monitor appears to use a fixed timeout rather than the programmable reload, so there is no value to pick. Shortening a probe would mean changing the watchdog's *mode*, which changes what happens on a real bus hang — datasheet work with a silent-bad-data failure mode, for a cost only a future Unix pays.

Two things came out of it that matter more than the item did. **Undecoded reads make the board lose time** — three IRQ0s in four are dropped during each stall, about 39 seconds lost in a single 256-read test. And **`int_1Ah` preserved only SI**, which DOS has been relying on not to matter every time it reads the tick. Both are written up in 06d.

---

## Resolved — the functional gaps

**1 · `INT 15h 89h`, enter protected mode. Deferred 2026-09-20, by decision rather than
by omission.** It reports unsupported and will keep reporting unsupported.

**2 · `INT 15h C1h`, get EBDA. Closed 2026-09-20: already correct.** It returns `AH=86h`
with carry set, and feature byte 1 bit 2 reports no EBDA, so nothing is misled. Answering
it properly would mean *allocating* an EBDA — a kilobyte off the top of conventional memory
to hold data nothing on this board produces. The PS/2 pointing device is what an EBDA is
usually for, and there is no pointing device. Reporting one we do not keep would be a lie
software could act on. Reopen this if a real EBDA ever gets allocated, not before.

**3 · `INT 13h 4Eh`, set hardware configuration. Closed 2026-09-20: already correct.** It
reaches `ret_invalid_command` through a real slot in `packet_call_tab`, not by falling off
the end of a table. The call is PS/2 ESDI-specific — it is not part of the EDD set, which
is `41h`-`48h` — and rejecting it is what a non-PS/2 BIOS is supposed to do.

**4 · Boot-device byte in NVRAM. Done 2026-09-20.** See Done, below.

**5 · `INT 10h 08h` cannot report screen contents. Closed 2026-09-26 by item 12.** The VGA3's
memory is the display buffer, so fn 08 reads the cell under the cursor off the board and
returns what is actually there. It still answers a space in the normal attribute when the
video board is absent and only the serial console is running, because a terminal cannot be
asked — that part was never solvable and is not a defect.

### Why item 1 is deferred

Not because it is hard. The machinery mostly exists — `AH=87h` already builds descriptors,
loads `GDTR`, sets `PE` and far-jumps, so the shape is known and much of it is reusable.

Because **it cannot be tested, and nothing calls it.**

- There is no software on this board that issues `AH=89h`. Testing it means writing a
  protected-mode program with its own eight-descriptor GDT, which is a larger exercise than
  the function.
- `89h` enters protected mode and *stays* there. A defect does not return an error; it
  leaves the board in protected mode with a bad descriptor and no way out but the reset
  button. Every other call in this BIOS can be wrong and still be debugged.
- The software that historically used it — OS/2 1.x, a few early extenders — is not what
  this board runs. DOS extenders switch modes themselves. Coherent will switch modes
  itself. Nothing in item 13 wants it.
- It costs ROM in a window that is 24% free, immediately before item 12 spends more.

Every defect found in Phase 6 was in code that looked right and had not been exercised.
Adding two hundred bytes of unexercisable code that nothing calls, in a ROM about to get
tighter, is the same bet again with nothing to win.

**And the software that would use it is software this board will not run.** That is the
owner's call and it is settled: this machine will never have the video hardware for OS/2,
and the early DOS extenders are not of interest. There is no third user of `AH=89h`.

So it is deferred on purpose, not left undone. If that ever changes, the condition for
building it is that the test gets built with it — a monitor command that constructs the
GDT, calls `89h`, checks `CR0.PE` and the loaded selectors, and returns to real mode the
way `AH=87h` already does. A rung on the ladder rather than an article of faith. Without
that it should stay unsupported, because unsupported is at least honest.

---

## Then — the console, item 12

**12 · Video card and keyboard. Largely done 2026-09-26.** The hardware turned out to be the
**ECB VGA3** — an HD6445 CRTC with 32K of display memory and an Intel 8242 keyboard
controller on one card. `0BRINGUP.md` section 07 is the full record; the facts that matter
for future work are these.

| | |
|---|---|
| I/O block | `04E0`–`04E7`, P3 jumpered to `E0h`, inside the window CS0 already decodes |
| `+0` `+1` | 8242 keyboard controller — the PC/AT `60h`/`64h` protocol at another address |
| `+2` `+3` | HD6445 address and data registers |
| `+4` | CFG, write only, cleared by RESET |
| `+5`–`+7` | address-register path to the 32K — used only by the monitor now |
| Memory window | CFG bit 7 set puts the 32K at `B8000`, which is where DOS expects it |
| K4 | 8242 interrupt: either position reaches 386EX INT0 = master IR1 = `INT 09h` |
| K1 | video interrupt: unused, so either position. See below |
| Sync jumpers | H negative, V positive for 80x25 |

**The display is written only during vertical blanking**, which the CRTC reports in bit 1 of
register 31. That is the whole snow-avoidance strategy and it is deliberately dull: the RAM
is not arbitrated, so any CPU access during a fetch corrupts the fetch. Two faster designs
were built and both failed — see `vga3.asm`'s header and section 07 — and the second failure
was never explained. Do not re-attempt beam tracking without new evidence.

**Both consoles are first-class, as this file said they should be.** `bda.console` carries
`CON_SERIAL` and `CON_VIDEO`; POST sets serial, and `vga3_init` adds video if the board
answers. With both set the screen is mirrored down the serial line, which is how the board
stays debuggable from another room. `INT 10h` gates the entire ANSI path on one test in
`vputc` and hooks the video path at the points where something is drawn.

**What is left of item 12:**

- **VT100 escape translation. Done 2026-09-26.** `vt_in` in `16h_kbd.asm` is a state machine
  across interrupts — `ESC`, then `[` (CSI) or `O` (SS3), then digits, then a letter or `~` —
  turning what a terminal sends into the scan codes a PC program expects. Three bytes of
  state in the BDA, taken from the reserved block. A sequence the BIOS does not know is
  dropped rather than delivered as letters.

  **A lone Escape is the hard case**, and the reason `vt_tick` is called from the timer: the
  character that opens every sequence is also a keystroke, and nothing tells them apart but
  what does or does not follow. A held Escape is delivered after two ticks of silence.
  Without that, Escape in an editor would not arrive until the next keystroke.

  This closes Phase 3, which had said "complete except for VT100 escape translation" since
  the plan was written.
- **A SETUP entry to choose the console.** The byte and the switch exist; the menu entry does
  not, so today the video board is used whenever it answers.
- **Keyboard LEDs. Done 2026-09-26.** `kbd_leds` in `16h_kbd.asm` runs after every make
  code and sends `ED` plus the lamp mask when the lock bits have changed, taking both `FA`
  acknowledgements itself so they never reach the scan-code path. `kbd_flag2` records what
  the lamps were last set to.
- **Item 16**, below, which is about DOS programs rather than about the BIOS.

## Also now — what the console brought with it

**15 · The ROM is nearly full. Eased 2026-09-26; still the constraint.** 59,360 of 65,536
bytes, **6,176 free (9.4%)**. It was 1,568 free before the VGA3 bring-up commands came out.

The cut was the one this item predicted: `V3CRTC`, `V3BEAM`, `V3RDCHK`, `V3DUMP`, `VIDEO` and
`V3KBD`'s scan-code and interrupt-hunting modes, plus the helpers only they used — **4,608
bytes**, of which 2,096 were string constants. The board had been proven rung by rung and
section 10 of `0BRINGUP.md` records what each rung established, so the scaffolding had done
its job; it is in the history if it is ever wanted again.

`VGA3` stayed: its address-dependent march over all 32K is the only thing that would catch a
failing RAM chip on that board, which is a live failure mode for socketed parts. `V3KBD`'s
basic probe stayed: a keyboard going quiet has already cost one long session, and it names
the cause in five lines.

The largest modules are now `debugmon.o`, `vga3.o` at 6,191 bytes and `set1302.o` at 2,475;
string constants are 16,736 bytes, most of them still the monitor's.

This is not yet an emergency, because **`MONITOR=0` still reclaims about 25K** and takes the
free space to roughly 40%. That switch was built in item 14 for exactly this moment. But it
is a one-shot escape: spending it leaves the board without the tool that found every defect
in Phases 4 through 7, so it should be spent on shipping a ROM, not on making room for
development.

Cheaper savings, in the order they should be taken:

- The 4K font could be dropped to the 8x8 set for a 43-line mode only, or generated at POST
  rather than stored — but it is permanent BIOS content that `INT 10h` needs, so it is not
  really overhead.
- The monitor's help and error strings are the single largest block of text in the tree. The
  Phase 6 and VGA3 probes have now gone. What remains is in use; the next candidates would be
  the floppy bring-up commands (`FDC`, `FDID`, `FDREAD`, `FDWRITE`, `FDFMT`, `FD13`) on the
  same argument, once the floppy stops being new.
- `set1302.o` is 2,475 bytes for a SETUP screen that runs once.

**16 · DOS programs that drive the screen themselves.** Three were tried. Turbo Pascal's IDE
works. Turbo C's IDE locks the machine up. WordPerfect Program Editor displays badly and does
not get past its startup screen, though it is fine on the serial console.

The likely mechanism, not yet proven, is the **CGA status port at `3DAh`**. A program that
decides it is talking to a CGA polls that port to avoid snow. No chip select on this board
claims `3B0`–`3DF`, so the cycle matches nothing, nothing terminates it, and the bus monitor
times out — 209 ms a read, returning a floating bus. A wait-for-retrace loop then never
finishes. The BIOS now answers `INT 10h 12h BL=10h` and `1Ah` as VGA colour, which is what
stops a well-behaved program from going down that path; Turbo C was still locking up when
last tried, so either it does not ask or something else is wrong.

Two possible answers, and they are not equivalent:

- **Cheap:** claim `3B0`–`3DF` with a spare chip select (the PLD notes CS5 as an unused second
  window) so those cycles finish in wait states instead of stalling. This fixes programs that
  merely *probe* the ports. It does **not** fix retrace polling, because a claimed but empty
  port reads `FF` forever and the loop still never exits.
- **Real:** run DOS in virtual-8086 mode with a monitor in the BIOS that traps I/O to
  `3B0`–`3DF` and answers it — `3DAh`'s retrace bits from the CRTC's own status, `3D4h`/`3D5h`
  cursor writes forwarded to the HD6445. This fixes everything and is a genuine project with
  its own bring-up ladder. It is also the mechanism that would let any other PC hardware this
  board lacks be emulated, which may matter for item 13.

Do not start either until it is known how many programs that are actually wanted fall into
which category. One program that matters is worth the emulator; three that do not are worth
nothing.

**17 · Nothing verifies the font table.** `mkfont.py` regenerates `font3270.inc` from
`3270.SFD`, and hand edits to the output would be silently lost on the next run. If any glyph
is ever adjusted by hand, add an overrides table to the generator rather than editing the
generated file.

---

## Later

**13 · Coherent.** A Unix clone, and the long-term reason for a good deal of this. Far
enough out that nothing above should be shaped around it, but worth remembering that it
will exercise paths DOS never touches.

---

## Done

- **14 · A build switch for the debug monitor.** 2026-09-20. `MONITOR` in the makefile,
  default **1**. Setting it to 0 drops `debugmon.o`, `monitor.o` and `strtoint.o` from
  `OBJECTS`, removes the SETUP menu entry, and makes INT 18h wait for a key instead of
  offering a monitor it has not got.

  Measured, not estimated: `debugmon.o` is **13,969** bytes of code — the largest module in
  the ROM by a factor of seven — and owns about **10,360** bytes of string constants, being
  two thirds of every literal in the tree. With `monitor.o` and `strtoint.o` that is
  **~25,140 bytes**, or free space rising from 15,888 to about 41,000.

  `getline.c` is deliberately **not** in the switch: SETUP uses it too.

- **7 · Retake the metrics table.** 2026-09-20: 49,648 B of 65,536, 24% free, 14 vectors,
  measured from `start.map`. **Retaken 2026-09-26: 63,968 B, 2.4% free** — the video console
  cost about 14K, of which 4K is the font. Superseded by item 15, which is the same number
  treated as a problem rather than a record.

- **8 · Remove the source files that never reach the ROM.** 2026-09-20. Thirty files — the
  twenty-seven already quarantined in `unused/` plus three root duplicates — and the dead
  `zero.*` makefile rules. Membership decided by closure from `start.map` rather than from
  the old list, because the makefile still carried rules for things that had not been built
  in years. Re-running the closure afterwards reports zero files outside it.

- **4 · Boot-device byte in NVRAM.** 2026-09-20. `bda.boot_order`, taken from the first
  byte of `nvram_unused` and so inside the existing checksum. Four orders: floppy then
  fixed, fixed then floppy, floppy only, fixed only. SETUP gains a "Boot Order" entry, and
  INT 19h honours it through `try_floppy`/`try_fixed` rather than the hard-coded pair.

  **Zero means floppy-then-fixed on purpose.** That byte reads zero in every NVRAM written
  before the field existed, so a board upgraded to this BIOS boots exactly as it did with
  nobody having to visit SETUP. It is also the right default on its own merits: it is what
  a PC has always done, and it is the order that lets a bad fixed disk be repaired instead
  of merely reported — which is the whole reason the floppy work happened.

- **2, 3 · `INT 15h C1h` and `INT 13h 4Eh`.** 2026-09-20. Closed as already correct; see
  above. No code changed.

- **10 · Repartition the CF and fix the BPB totals.** 2026-09-20. The blocker that started
  the floppy work: the partition table was oversized and there was no bootable medium to
  repair it from.
- **11 · The bad primary CF card.** 2026-09-20. Diagnosed by swapping it to the secondary
  position, where it also failed — the interface and the BIOS were both innocent.
- **Phases 0 through 6.** See `0BRINGUP.md`.
