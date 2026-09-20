# SBC-386EX BIOS — what is left

Opened 2026-09-20, the day Phase 6 closed. `0BRINGUP.md` is the record of how the board
got here and why things are the way they are; this is the shorter question of what remains.
Numbering is stable — items keep their number as they are done, so "item 9" means the same
thing in a commit message next month as it does here.

**All six phases of the bring-up plan are complete.** The board boots MS-DOS 6 to a prompt
over the serial console from either a floppy or the fixed disk, formats its own disks, and
nothing on this list blocks anything else on it.

---

## Now — housekeeping

**9 · Shorten the watchdog reload. Blocked on one measurement, and possibly not worth
doing at all.**

Section 06d established the arithmetic: the bus-monitor timeout is about 209ms against a
slowest legitimate access of roughly 450ns, five orders of magnitude of slack. It cannot
trip during real I/O, which was the question being asked at the time. What it also means is
that a probe of an address nothing answers *might* cost a fifth of a second — and that
matters for a Unix, which walks lists of candidate addresses looking for hardware, far more
than for DOS, which probes almost nothing.

**"Might" is the whole of it.** 06d says plainly that whether an undecoded cycle reaches the
watchdog at all is not yet known. One run settles it:

```
IOTIME 64 10        undecoded -- nothing claims port 64h
IOTIME 1F7 10       decoded -- the IDE status register
```

If the undecoded read already returns inside a tick, there is nothing to reclaim, and the
right outcome is to strike this item and record the answer in 06d rather than to do the
work. If it does cost 209ms, the fix is to write `WDTRLDH`/`WDTRLDL` at init — registers
this BIOS has never written, so the reload in use is whatever reset left there.

That second path wants the datasheet open. The reload registers may need a `WDTCLR`
sequence before a new value takes effect, and `PWRCON` already reads back `1C` where POST
writes `0C`, which 06d flags as unexplained. Getting it wrong terminates a live bus cycle
early with whatever happened to be on the bus — silent bad data, which is the hardest
class of fault to find on this board and precisely what the watchdog is otherwise
protecting against.

*(Items 7 and 8 were here and are done — see Done, below.)*

---

## Next — the functional gaps

**1 · `INT 15h 89h`, enter protected mode. Recommend deferring — see below.** The only one
of these with real code behind it, and the only one that can leave the board unrecoverable
if it is wrong.

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

**5 · `INT 10h 08h` cannot report screen contents. Genuinely blocked on item 12**, not
merely waiting for attention: it needs a display buffer, and whether there is one depends
on what the video hardware turns out to be. Carried into item 12 rather than left here.

### Why item 1 should wait

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

**If it is wanted, build the test with it** — a monitor command that constructs the GDT,
calls `89h`, checks `CR0.PE` and the loaded selectors, and returns to real mode the way
`AH=87h` already does. That makes it a rung on the ladder rather than an article of faith,
and it is the condition on which this should be done at all.

---

## Then — the console, item 12

**12 · Video card and keyboard.** New hardware, not yet chosen. Expect more than one
candidate to evaluate, and expect the evaluation to be part of the work rather than
something settled beforehand.

**There is room for it.** The ROM is at 24% free, which is not much, but `MONITOR=0`
reclaims about 25K and takes that to roughly 75% — see item 14. The switch exists so the
space is available without a decision having to be made in a hurry partway through.

**VT100/ANSI over the serial line stays a first-class console, not a stepping stone.** This
is a change from how `0BRINGUP.md` has been describing it, and the distinction matters for
how the console layer gets built:

- The serial console is what makes this board debuggable. Everything found in Phases 4
  through 6 was found down that wire, and a board whose only console is a video card it
  shares with the fault under investigation is a worse board to work on.
- It is also the only console that works headless, over a cable, from another room, with a
  transcript. None of that stops being useful once a video card exists.
- So the right shape is a console layer that can drive **more than one output**, chosen at
  configuration time, rather than an INT 10h that assumes a frame buffer and a serial path
  bolted alongside it. If several video candidates are in play, that indirection has to
  exist anyway to evaluate them.

**VT100 escape translation** — arrow keys, Home and End arriving as escape sequences and
leaving as scan codes — belongs to this item. It was deferred through Phases 3 to 6 on the
grounds that the hardware transition would change what needed translating. That reasoning
still holds for *when*; it no longer implies the serial path is temporary.

Item 5 lands here too: a display buffer is what lets `INT 10h 08h` report screen contents,
and whether there is one depends on what the video hardware turns out to be.

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

- **7 · Retake the metrics table.** 2026-09-20. 49,648 B of 65,536, 24% free, 14 vectors,
  measured from `start.map`.

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
