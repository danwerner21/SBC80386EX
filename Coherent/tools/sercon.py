#!/usr/bin/env python3
"""Talk to a Coherent shell over a TCP serial line (QEMU -serial tcp:127.0.0.1:4555,server,nowait).

    sercon.py run 'COMMAND' [TIMEOUT]    send COMMAND, print output up to the next prompt
    sercon.py login [USER]               answer a login: prompt (default root)
    sercon.py raw 'TEXT' [SECONDS]       send TEXT (\\r is Enter), print whatever comes back
    sercon.py pull GUESTFILE HOSTFILE    copy a file out, byte exact (uuencode over the line)
    sercon.py watch SECONDS [UNTIL]      just listen, e.g. through a boot; stop early on regex UNTIL

Everything received is also appended to emu/serial.log.  Not com1.log:
COM1 is a reserved device name on Windows even with an extension, which
is also why QEMU's chardev logfile=com1.log silently did nothing.
Git Bash rewrites arguments that start with '/', so call this with
MSYS_NO_PATHCONV=1 when passing guest paths.
"""
import os
import re
import socket
import sys
import time

PORT = 4555
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'emu', 'serial.log')
PROMPT = re.compile(rb'(root|\$): $')


def connect():
    s = socket.create_connection(('127.0.0.1', PORT))
    s.settimeout(0.2)
    return s


def drain(s, until=None, timeout=10.0):
    buf, end = b'', time.time() + timeout
    while time.time() < end:
        # A prompt only counts once the line has gone quiet, so text that
        # merely looks like one in the middle of the output does not end it.
        try:
            d = s.recv(4096)
        except socket.timeout:
            if until and until.search(buf):
                return buf
            continue
        if not d:
            break
        with open(LOG, 'ab') as f:
            f.write(d)
        buf += d
    return buf


def send(s, text):
    for c in text.encode('latin-1'):
        s.sendall(bytes([c]))
        time.sleep(0.002)


def show(b):
    sys.stdout.write(b.decode('latin-1').replace('\r', ''))
    sys.stdout.flush()


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    s = connect()
    drain(s, timeout=0.3)
    op = argv[1]
    if op == 'run':
        timeout = float(argv[3]) if len(argv) > 3 else 30
        send(s, argv[2] + '\r')
        out = drain(s, PROMPT, timeout)
        lines = out.split(b'\n')
        show(b'\n'.join(lines[1:]) + b'\n')   # drop the echoed command
    elif op == 'login':
        send(s, '\r')
        drain(s, re.compile(rb'login: ?$'), 10)
        send(s, (argv[2] if len(argv) > 2 else 'root') + '\r')
        show(drain(s, PROMPT, 15))
    elif op == 'pull':
        # The terminal expands tabs and adds CRs, so text cannot come out
        # as-is; uuencode survives both.
        send(s, 'uuencode %s x\r' % argv[2])
        text = drain(s, PROMPT, 600).decode('latin-1').replace('\r', '')
        lines = text.split('\n')
        begin = next(i for i, l in enumerate(lines) if l.startswith('begin '))
        data = bytearray()
        for l in lines[begin + 1:]:
            if l == 'end' or l in ('`', ' ', ''):
                if l == 'end':
                    break
                continue
            # Decoded by hand: Coherent fills the unused bytes of a line's
            # last group with whatever followed, which binascii.a2b_uu
            # rejects as trailing garbage.  Keep the count byte's worth.
            n = (ord(l[0]) - 32) & 63
            chars = [(ord(c) - 32) & 63 for c in l[1:1 + (n + 2) // 3 * 4].ljust((n + 2) // 3 * 4, '`')]
            out = bytearray()
            for i in range(0, len(chars), 4):
                a, b, c, d = chars[i:i + 4]
                out += bytes([(a << 2 | b >> 4) & 255, (b << 4 | c >> 2) & 255, (c << 6 | d) & 255])
            data += out[:n]
        with open(argv[3], 'wb') as f:
            f.write(data)
        print('%s: %d bytes' % (argv[3], len(data)))
    elif op == 'watch':
        until = re.compile(argv[3].encode()) if len(argv) > 3 else None
        show(drain(s, until, float(argv[2])))
    elif op == 'raw':
        send(s, argv[2].encode().decode('unicode_escape'))
        show(drain(s, None, float(argv[3]) if len(argv) > 3 else 3))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
