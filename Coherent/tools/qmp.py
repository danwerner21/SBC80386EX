#!/usr/bin/env python3
"""Drive a running QEMU through its QMP socket (-qmp tcp:127.0.0.1:4444,server,nowait).

    qmp.py type TEXT          type TEXT; \\n is Enter
    qmp.py key KEY...         send keys by QEMU name (ret, esc, ctrl-c, f1 ...)
    qmp.py shot FILE.png      screenshot of the display
    qmp.py hmp COMMAND...     any human-monitor command (change, info, quit ...)
"""
import json
import socket
import sys
import time

PORT = 4444

SHIFTED = {'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7',
           '*': '8', '(': '9', ')': '0', '_': 'minus', '+': 'equal', '{': 'bracket_left',
           '}': 'bracket_right', '|': 'backslash', ':': 'semicolon', '"': 'apostrophe',
           '<': 'comma', '>': 'dot', '?': 'slash', '~': 'grave_accent'}
PLAIN = {' ': 'spc', '\n': 'ret', '-': 'minus', '=': 'equal', '[': 'bracket_left',
         ']': 'bracket_right', '\\': 'backslash', ';': 'semicolon', "'": 'apostrophe',
         ',': 'comma', '.': 'dot', '/': 'slash', '`': 'grave_accent', '\t': 'tab'}


def keyname(c):
    if c.isalpha():
        return ('shift-' + c.lower()) if c.isupper() else c
    if c.isdigit():
        return c
    if c in PLAIN:
        return PLAIN[c]
    if c in SHIFTED:
        return 'shift-' + SHIFTED[c]
    raise ValueError('no key for %r' % c)


class QMP:
    def __init__(self):
        self.s = socket.create_connection(('127.0.0.1', PORT))
        self.f = self.s.makefile('rw')
        self.f.readline()
        self.cmd('qmp_capabilities')

    def cmd(self, name, **args):
        self.f.write(json.dumps({'execute': name, 'arguments': args}) + '\n')
        self.f.flush()
        while True:
            r = json.loads(self.f.readline())
            if 'return' in r or 'error' in r:
                return r

    def hmp(self, line):
        r = self.cmd('human-monitor-command', **{'command-line': line})
        return r.get('return', r)


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    q = QMP()
    op, rest = argv[1], argv[2:]
    if op == 'type':
        text = ' '.join(rest).encode().decode('unicode_escape')
        for c in text:
            q.hmp('sendkey ' + keyname(c))
            time.sleep(0.05)
    elif op == 'key':
        for k in rest:
            q.hmp('sendkey ' + k)
            time.sleep(0.05)
    elif op == 'shot':
        print(q.hmp('screendump %s -f png' % rest[0]))
    elif op == 'hmp':
        print(q.hmp(' '.join(rest)))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
