#!/usr/bin/env python3
"""Build a small DOS .COM from a NASM-style source, without NASM.

    mkcom.py SOURCE.asm OUT.COM

For machines without NASM (the SBC's own build machine has it; use
"nasm -f bin" there).  Code is assembled with keystone; the data at the
end -- everything from the first "label: db/dw" line on -- is laid out
here, because keystone cannot parse db strings.  Numbers in the code
should be written in hex (0x..): keystone reads some bare numbers as hex.

keystone emits 32-bit near call/ret (66 E8 rel32, 66 C3) even in 16-bit
mode; each is rewritten in place as the 16-bit form, padded with NOPs.
The result is disassembled with capstone for checking.
Needs: py -m pip install --user keystone-engine capstone
"""
import re
import sys

import capstone
import keystone


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    src = open(argv[1], encoding='utf-8').read().split('\n')
    split = next(i for i, l in enumerate(src) if re.match(r'\w+:\s*d[bw]\b', l))
    code_lines = [l for l in src[:split] if not l.strip().startswith('org')]

    labels, data = [], bytearray()
    for l in src[split:]:
        m = re.match(r'(\w+):\s*(db|dw)\s+(.*)', l)
        if not m:
            continue
        name, kind, rest = m.groups()
        labels.append((name, len(data)))
        if kind == 'dw':
            v = int(rest.split(';')[0].strip(), 0)
            data += bytes([v & 0xFF, (v >> 8) & 0xFF])
            continue
        for item in re.findall(r"'[^']*'|[^,]+", rest):
            item = item.strip()
            if item.startswith("'"):
                data += item[1:-1].encode()
            elif item:
                data.append(int(item, 0) & 0xFF)

    ks = keystone.Ks(keystone.KS_ARCH_X86, keystone.KS_MODE_16)
    ks.syntax = keystone.KS_OPT_SYNTAX_NASM

    def assemble(base):
        text = '\n'.join(code_lines)
        for name, off in sorted(labels, key=lambda x: -len(x[0])):
            text = re.sub(r'\b%s\b' % name, '0x%x' % (base + off), text)
        return bytes(ks.asm(text, 0x100)[0])

    code = assemble(0x1000)
    code = assemble(0x100 + len(code))

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_16)
    code = bytearray(code)
    for ins in list(md.disasm(bytes(code), 0x100)):
        b, o = bytes(ins.bytes), ins.address - 0x100
        if b[:2] == b'\x66\xe8' and len(b) == 6:
            target = ins.address + 6 + int.from_bytes(b[2:], 'little', signed=True)
            rel = (target - (ins.address + 3)) & 0xFFFF
            code[o:o + 6] = b'\xe8' + rel.to_bytes(2, 'little') + b'\x90\x90\x90'
        elif b == b'\x66\xc3':
            code[o:o + 2] = b'\x90\xc3'

    out = bytes(code) + bytes(data)
    open(argv[2], 'wb').write(out)
    print('%s: %d bytes (code %d, data %d at %04x)' % (argv[2], len(out), len(code), len(data), 0x100 + len(code)))
    for ins in md.disasm(bytes(code), 0x100):
        print('%04x  %-14s %s %s' % (ins.address, ins.bytes.hex(), ins.mnemonic, ins.op_str))


if __name__ == '__main__':
    main(sys.argv)
