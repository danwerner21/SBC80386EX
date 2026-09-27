#!/usr/bin/env python3
"""Disassemble part of a COHERENT 386 kernel (COFF) by virtual address.

    kdis.py KERNEL ADDR [BYTES]      e.g. kdis.py coh.sbc ffc1fcef 120

KERNEL is a file on the host (pull it out of an image with cohfs.py).
Needs the capstone module (py -m pip install --user capstone).
"""
import struct
import sys

import capstone


def sections(img):
    nscns, = struct.unpack_from('<H', img, 2)
    opthdr, = struct.unpack_from('<H', img, 16)
    off = 20 + opthdr
    for i in range(nscns):
        name = img[off:off + 8].split(b'\0')[0].decode()
        paddr, vaddr, size, scnptr = struct.unpack_from('<IIII', img, off + 8)
        yield name, vaddr, size, scnptr
        off += 40


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    img = open(argv[1], 'rb').read()
    addr = int(argv[2], 16)
    n = int(argv[3], 0) if len(argv) > 3 else 64
    for name, vaddr, size, ptr in sections(img):
        if vaddr <= addr < vaddr + size:
            code = img[ptr + addr - vaddr: ptr + addr - vaddr + n]
            md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
            for ins in md.disasm(code, addr):
                print('%08x  %-20s %s %s' % (ins.address, ins.bytes.hex(), ins.mnemonic, ins.op_str))
            return
    for s in sections(img):
        print('%-8s vaddr %08x size %08x file %08x' % s)
    sys.exit('address not in any section')


if __name__ == '__main__':
    main(sys.argv)
