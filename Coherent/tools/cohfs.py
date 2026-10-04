#!/usr/bin/env python3
"""Read-only access to a COHERENT filesystem image.

    cohfs.py IMAGE ls [PATH]          list a directory
    cohfs.py IMAGE tree [PATH]        list everything below PATH
    cohfs.py IMAGE cat PATH           file contents to stdout
    cohfs.py IMAGE get PATH OUTDIR    extract a file or a whole subtree
    cohfs.py IMAGE super              print the superblock

IMAGE may be a raw filesystem (a floppy) or a disk; with a disk, give the
filesystem's starting sector as --offset N.

On-disk format (COHERENT 4.x, sys/filsys.h and sys/ino.h): 512-byte blocks,
superblock in block 1, 64-byte inodes from block 2, root is inode 2, 16-byte
directory entries.  Longs are in PDP-11 order -- high word first, each word
little-endian -- and block addresses in the inode are packed three bytes each
in the same order with the top byte dropped.
"""
import os
import stat
import struct
import sys

BSIZE = 512
INOSZ = 64
ROOTINO = 2
NADDR = 13
ND = 10  # direct blocks


def pdplong(b, o=0):
    hi, lo = struct.unpack_from('<HH', b, o)
    return (hi << 16) | lo


def l3(b, o):
    # three bytes: bits 16-23, bits 0-7, bits 8-15
    return (b[o] << 16) | b[o + 1] | (b[o + 2] << 8)


class Inode:
    def __init__(self, fs, ino, raw):
        self.fs, self.ino = fs, ino
        (self.mode, self.nlink, self.uid, self.gid) = struct.unpack_from('<HhHH', raw, 0)
        self.size = pdplong(raw, 8)
        self.addr = [l3(raw, 12 + 3 * i) for i in range(NADDR)]
        self.mtime = pdplong(raw, 56)

    def isdir(self):
        return stat.S_ISDIR(self.mode)

    def blocks(self):
        n = (self.size + BSIZE - 1) // BSIZE
        out = []
        for a in self.addr[:ND]:
            out.append(a)
        for level, a in enumerate(self.addr[ND:], 1):
            out.extend(self.fs.indirect(a, level))
        return out[:n]

    def data(self):
        if stat.S_IFMT(self.mode) in (stat.S_IFCHR, stat.S_IFBLK):
            return b''
        buf = bytearray()
        for a in self.blocks():
            buf += self.fs.block(a) if a else bytes(BSIZE)
        return bytes(buf[:self.size])


class FS:
    def __init__(self, path, offset=0):
        with open(path, 'rb') as f:
            f.seek(offset * BSIZE)
            self.img = f.read()
        sb = self.block(1)
        self.isize = struct.unpack_from('<H', sb, 0)[0]
        self.fsize = pdplong(sb, 2)
        self.tfree = pdplong(sb, 2 + 4 + 2 + 64 * 4 + 2 + 100 * 2 + 4 + 4)

    def block(self, n):
        return self.img[n * BSIZE:(n + 1) * BSIZE]

    def indirect(self, a, level):
        if not a:
            return []
        b = self.block(a)
        ptrs = [pdplong(b, 4 * i) for i in range(BSIZE // 4)]
        if level == 1:
            return ptrs
        out = []
        for p in ptrs:
            out.extend(self.indirect(p, level - 1) if p else [0] * (128 ** (level - 1)))
        return out

    def inode(self, ino):
        off = 2 * BSIZE + (ino - 1) * INOSZ
        return Inode(self, ino, self.img[off:off + INOSZ])

    def readdir(self, ip):
        d = ip.data()
        for o in range(0, len(d), 16):
            ino = struct.unpack_from('<H', d, o)[0]
            if ino:
                yield d[o + 2:o + 16].split(b'\0')[0].decode('latin-1'), ino

    def namei(self, path):
        ip = self.inode(ROOTINO)
        for part in [p for p in path.split('/') if p]:
            for name, ino in self.readdir(ip):
                if name == part:
                    ip = self.inode(ino)
                    break
            else:
                raise FileNotFoundError(path)
        return ip


def fmt(ip, name):
    return '%06o %3d %5d %9d %s' % (ip.mode, ip.nlink, ip.uid, ip.size, name)


def walk(fs, ip, path):
    for name, ino in sorted(fs.readdir(ip)):
        if name in ('.', '..'):
            continue
        sub = fs.inode(ino)
        p = path.rstrip('/') + '/' + name
        yield sub, p
        if sub.isdir():
            yield from walk(fs, sub, p)


def get(fs, ip, path, outdir):
    dest = os.path.join(outdir, path.strip('/'))
    if ip.isdir():
        os.makedirs(dest, exist_ok=True)
        for sub, p in walk(fs, ip, path):
            d = os.path.join(outdir, p.strip('/'))
            if sub.isdir():
                os.makedirs(d, exist_ok=True)
            elif stat.S_ISREG(sub.mode):
                with open(d, 'wb') as f:
                    f.write(sub.data())
    else:
        os.makedirs(os.path.dirname(dest) or '.', exist_ok=True)
        with open(dest, 'wb') as f:
            f.write(ip.data())


def main(argv):
    offset = 0
    if '--offset' in argv:
        i = argv.index('--offset')
        offset = int(argv[i + 1], 0)
        del argv[i:i + 2]
    if len(argv) < 3:
        sys.exit(__doc__)
    fs = FS(argv[1], offset)
    cmd, args = argv[2], argv[3:]
    if cmd == 'super':
        print('isize %d  fsize %d  tfree %d' % (fs.isize, fs.fsize, fs.tfree))
    elif cmd == 'ls':
        ip = fs.namei(args[0] if args else '/')
        for name, ino in sorted(fs.readdir(ip)):
            print(fmt(fs.inode(ino), name))
    elif cmd == 'tree':
        path = args[0] if args else '/'
        for sub, p in walk(fs, fs.namei(path), path):
            print(fmt(sub, p))
    elif cmd == 'cat':
        sys.stdout.buffer.write(fs.namei(args[0]).data())
    elif cmd == 'get':
        get(fs, fs.namei(args[0]), args[0], args[1])
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
