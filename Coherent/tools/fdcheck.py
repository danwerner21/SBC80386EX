#!/usr/bin/env python3
"""Read a 1.44 MB diskette back and compare it with the image it was written from.

    py fdcheck.py IMAGE [DRIVE]        e.g. py fdcheck.py ..\\images\\sbc-d4.img A:

Windows only: reads the drive raw (\\\\.\\A:), a track at a time, then a
sector at a time where a track will not read.  Prints every 512-byte block
that differs or cannot be read, with its cylinder, head and sector, and a
summary.  Blocks are COHERENT's numbering: block N is sector N of the disk,
as in the board's "fd0: block N" messages.  Run it from an Administrator
prompt if Windows refuses to open the drive.
"""
import sys

SECT, SPT, HEADS, CYLS = 512, 18, 2, 80
TRACK = SECT * SPT


def chs(block):
    return block // (SPT * HEADS), block // SPT % HEADS, block % SPT + 1


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    image = open(argv[1], 'rb').read()
    drive = (argv[2] if len(argv) > 2 else 'A:').rstrip('\\')
    if len(image) != TRACK * HEADS * CYLS:
        sys.exit('%s is not a 1.44 MB image' % argv[1])
    bad = []
    with open(r'\\.\%s' % drive, 'rb', buffering=0) as fd:
        for t in range(HEADS * CYLS):
            want = image[t * TRACK:(t + 1) * TRACK]
            try:
                fd.seek(t * TRACK)
                got = fd.read(TRACK)
            except OSError:
                got = None
            if got == want:
                continue
            for s in range(SPT):             # find which sectors
                b = t * SPT + s
                try:
                    fd.seek(b * SECT)
                    one = fd.read(SECT)
                    why = 'differs' if one != want[s * SECT:(s + 1) * SECT] else None
                except OSError as e:
                    why = 'unreadable (%s)' % e.strerror
                if why:
                    bad.append(b)
                    print('block %4d  cyl %2d head %d sector %2d  %s' % ((b,) + chs(b) + (why,)))
            sys.stdout.flush()
    if bad:
        print('%d bad blocks, cylinders %d to %d' % (len(bad), chs(bad[0])[0], chs(bad[-1])[0]))
        sys.exit(1)
    print('all 2880 blocks match %s' % argv[1])


if __name__ == '__main__':
    main(sys.argv)
