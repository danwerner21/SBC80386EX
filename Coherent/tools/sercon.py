#!/usr/bin/env python3
"""Talk to a Coherent shell over a TCP serial line (QEMU -serial tcp:127.0.0.1:4555,server,nowait).

    sercon.py run 'COMMAND' [TIMEOUT]    send COMMAND, print output up to the next prompt
    sercon.py login [USER]               answer a login: prompt (default root)
    sercon.py raw 'TEXT' [SECONDS]       send TEXT (\\r is Enter), print whatever comes back
"""
import re
import socket
import sys
import time

PORT = 4555
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
    elif op == 'raw':
        send(s, argv[2].encode().decode('unicode_escape'))
        show(drain(s, None, float(argv[3]) if len(argv) > 3 else 3))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
