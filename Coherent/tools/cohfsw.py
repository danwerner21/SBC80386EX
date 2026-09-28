#!/usr/bin/env python3
"""Write COHERENT filesystem images from the host -- floppies, mostly.

    cohfsw.py IMAGE mkfs NBLOCKS          new, empty filesystem (as COHERENT's mkfs)
    cohfsw.py IMAGE put HOSTFILE PATH [MODE]  create or replace a file
    cohfsw.py IMAGE mkdir PATH [MODE]     make a directory
    cohfsw.py IMAGE rm PATH               remove a file

For building the SBC-386EX install diskettes without writing floppies
through COHERENT's driver in QEMU, which now and then never finishes a
transfer.  Check a result with /etc/fsck; cohfs.py reads it back.

The layout is the one cohfs.py reads (V7-style; PDP-11-order longs; block
addresses packed three bytes in the inode).  Allocation follows the V7
kernel: the superblock holds up to 64 free block numbers, entry 0 linking
to a block that holds the next batch; inodes come from the superblock's
cache, then from a scan.  mkfs reproduces COHERENT's own mkfs exactly,
timestamps apart.
"""
import stat
import struct
import sys
import time

from cohfs import BSIZE, INOSZ, ND, ROOTINO, FS, pdplong, l3

NICFREE = 64
NICINOD = 100
NIND = BSIZE // 4       # block numbers per indirect block

# superblock offsets
SB_ISIZE, SB_FSIZE, SB_NFREE, SB_FREE = 0, 2, 6, 8
SB_NINODE, SB_INODE = 264, 266
SB_FLAGS, SB_TIME, SB_TFREE, SB_TINODE = 466, 470, 474, 478
SB_M, SB_N, SB_FNAME, SB_FPACK, SB_UNIQUE = 480, 482, 484, 490, 496


def putpdp(b, o, v):
    struct.pack_into('<HH', b, o, (v >> 16) & 0xFFFF, v & 0xFFFF)


def putl3(b, o, v):
    b[o], b[o + 1], b[o + 2] = (v >> 16) & 0xFF, v & 0xFF, (v >> 8) & 0xFF


class FSW(FS):
    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as f:
            self.img = bytearray(f.read())
        self._load_super()

    # -- raw access ---------------------------------------------------------
    def block(self, n):
        return bytes(self.img[n * BSIZE:(n + 1) * BSIZE])

    def wblock(self, n, data):
        data = bytes(data).ljust(BSIZE, b'\0')
        self.img[n * BSIZE:(n + 1) * BSIZE] = data

    def save(self):
        self._store_super()
        with open(self.path, 'wb') as f:
            f.write(self.img)

    # -- superblock ---------------------------------------------------------
    def _load_super(self):
        sb = self.block(1)
        self.isize = struct.unpack_from('<H', sb, SB_ISIZE)[0]
        self.fsize = pdplong(sb, SB_FSIZE)
        self.nfree = struct.unpack_from('<h', sb, SB_NFREE)[0]
        self.free = [pdplong(sb, SB_FREE + 4 * i) for i in range(NICFREE)]
        self.ninode = struct.unpack_from('<h', sb, SB_NINODE)[0]
        self.icache = list(struct.unpack_from('<%dH' % NICINOD, sb, SB_INODE))
        self.tfree = pdplong(sb, SB_TFREE)
        self.tinode = struct.unpack_from('<H', sb, SB_TINODE)[0]

    def _store_super(self):
        sb = bytearray(self.block(1))
        struct.pack_into('<H', sb, SB_ISIZE, self.isize)
        putpdp(sb, SB_FSIZE, self.fsize)
        struct.pack_into('<h', sb, SB_NFREE, self.nfree)
        for i in range(NICFREE):
            putpdp(sb, SB_FREE + 4 * i, self.free[i])
        struct.pack_into('<h', sb, SB_NINODE, self.ninode)
        struct.pack_into('<%dH' % NICINOD, sb, SB_INODE, *self.icache)
        putpdp(sb, SB_TIME, int(time.time()))
        putpdp(sb, SB_TFREE, self.tfree)
        struct.pack_into('<H', sb, SB_TINODE, self.tinode)
        self.wblock(1, sb)

    # -- blocks -------------------------------------------------------------
    def balloc(self):
        if self.nfree <= 0:
            raise OSError('filesystem full')
        self.nfree -= 1
        bno = self.free[self.nfree]
        if bno == 0:
            raise OSError('filesystem full')
        if self.nfree == 0:          # bno was the link: its list comes in
            b = self.block(bno)
            self.nfree = struct.unpack_from('<h', b, 0)[0]
            self.free = [pdplong(b, 2 + 4 * i) for i in range(NICFREE)]
        self.tfree -= 1
        self.wblock(bno, b'')
        return bno

    def bfree(self, bno):
        if self.nfree >= NICFREE:    # list full: it moves into this block
            b = bytearray(BSIZE)
            struct.pack_into('<h', b, 0, self.nfree)
            for i in range(NICFREE):
                putpdp(b, 2 + 4 * i, self.free[i])
            self.wblock(bno, b)
            self.nfree = 0
            self.free = [0] * NICFREE
        self.free[self.nfree] = bno
        self.nfree += 1
        self.tfree += 1

    # -- inodes -------------------------------------------------------------
    def _ioff(self, ino):
        return 2 * BSIZE + (ino - 1) * INOSZ

    def iread(self, ino):
        o = self._ioff(ino)
        raw = self.img[o:o + INOSZ]
        mode, nlink, uid, gid = struct.unpack_from('<HhHH', raw, 0)
        return {'mode': mode, 'nlink': nlink, 'uid': uid, 'gid': gid,
                'size': pdplong(raw, 8),
                'addr': [l3(raw, 12 + 3 * i) for i in range(13)]}

    def iwrite(self, ino, ip, t=None):
        t = int(time.time()) if t is None else t
        raw = bytearray(INOSZ)
        struct.pack_into('<HhHH', raw, 0, ip['mode'], ip['nlink'], ip['uid'], ip['gid'])
        putpdp(raw, 8, ip['size'])
        for i, a in enumerate(ip['addr']):
            putl3(raw, 12 + 3 * i, a)
        for o in (52, 56, 60):          # atime, mtime, ctime
            putpdp(raw, o, t)
        o = self._ioff(ino)
        self.img[o:o + INOSZ] = raw

    def ialloc(self):
        while self.ninode > 0:
            self.ninode -= 1
            ino = self.icache[self.ninode]
            if self.iread(ino)['mode'] == 0:
                break
        else:
            ninodes = (self.isize - 2) * (BSIZE // INOSZ)
            for ino in range(ROOTINO + 1, ninodes + 1):
                if self.iread(ino)['mode'] == 0:
                    break
            else:
                raise OSError('out of inodes')
        self.tinode -= 1
        return ino

    # -- file contents ------------------------------------------------------
    def _blocks(self, ip):
        """Every block of the file, data and indirect alike."""
        out = []
        for a in ip['addr'][:ND]:
            if a:
                out.append(a)

        def ind(a, level):
            if not a:
                return
            b = self.block(a)
            for i in range(NIND):
                p = pdplong(b, 4 * i)
                if level > 1:
                    ind(p, level - 1)
                elif p:
                    out.append(p)
            out.append(a)
        for level, a in enumerate(ip['addr'][ND:], 1):
            ind(a, level)
        return out

    def truncate(self, ip):
        for b in self._blocks(ip):
            self.bfree(b)
        ip['addr'] = [0] * 13
        ip['size'] = 0

    def setdata(self, ip, data):
        """Replace the file's contents with data."""
        self.truncate(ip)
        n = (len(data) + BSIZE - 1) // BSIZE
        blocks = []
        for i in range(n):
            b = self.balloc()
            self.wblock(b, data[i * BSIZE:(i + 1) * BSIZE])
            blocks.append(b)
        ip['addr'][:min(n, ND)] = blocks[:ND]
        rest = blocks[ND:]
        if rest:
            single, rest = rest[:NIND], rest[NIND:]
            ip['addr'][ND] = self._indirect(single)
        if rest:
            doubles, rest = rest[:NIND * NIND], rest[NIND * NIND:]
            firsts = [self._indirect(doubles[i:i + NIND]) for i in range(0, len(doubles), NIND)]
            ip['addr'][ND + 1] = self._indirect(firsts)
        if rest:
            raise OSError('file too large for this writer')
        ip['size'] = len(data)

    def _indirect(self, ptrs):
        bno = self.balloc()
        b = bytearray(BSIZE)
        for i, p in enumerate(ptrs):
            putpdp(b, 4 * i, p)
        self.wblock(bno, b)
        return bno

    def data(self, ino):
        return self.inode(ino).data()

    # -- names --------------------------------------------------------------
    def lookup(self, path):
        ino = ROOTINO
        for part in [p for p in path.split('/') if p]:
            for name, i in self.readdir(self.inode(ino)):
                if name == part:
                    ino = i
                    break
            else:
                return None
        return ino

    def _split(self, path):
        parts = [p for p in path.split('/') if p]
        parent = self.lookup('/'.join(parts[:-1]))
        if parent is None:
            raise FileNotFoundError('no directory for ' + path)
        name = parts[-1]
        if len(name) > 14:
            raise ValueError('name longer than 14: ' + name)
        return parent, name

    def _dirent(self, dino, name, ino):
        ip = self.iread(dino)
        d = bytearray(self.data(dino))
        ent = struct.pack('<H', ino) + name.encode().ljust(14, b'\0')
        for o in range(0, len(d), 16):
            if struct.unpack_from('<H', d, o)[0] == 0:
                d[o:o + 16] = ent
                break
        else:
            d += ent
        self.setdata(ip, bytes(d))
        self.iwrite(dino, ip)

    def _undirent(self, dino, name):
        ip = self.iread(dino)
        d = bytearray(self.data(dino))
        for o in range(0, len(d), 16):
            ino = struct.unpack_from('<H', d, o)[0]
            if ino and d[o + 2:o + 16].split(b'\0')[0].decode('latin-1') == name:
                d[o:o + 16] = bytes(16)
                self.setdata(ip, bytes(d))
                self.iwrite(dino, ip)
                return ino
        raise FileNotFoundError(name)

    # -- operations ---------------------------------------------------------
    def put(self, path, data, mode=0o644, uid=0, gid=0):
        ino = self.lookup(path)
        if ino is None:
            parent, name = self._split(path)
            ino = self.ialloc()
            ip = {'mode': stat.S_IFREG | mode, 'nlink': 1, 'uid': uid, 'gid': gid,
                  'size': 0, 'addr': [0] * 13}
            self.setdata(ip, data)
            self.iwrite(ino, ip)
            self._dirent(parent, name, ino)
        else:
            ip = self.iread(ino)
            if not stat.S_ISREG(ip['mode']):
                raise IsADirectoryError(path)
            self.setdata(ip, data)
            self.iwrite(ino, ip)
        return ino

    def mkdir(self, path, mode=0o755, uid=0, gid=0):
        parent, name = self._split(path)
        if self.lookup(path) is not None:
            raise FileExistsError(path)
        ino = self.ialloc()
        ip = {'mode': stat.S_IFDIR | mode, 'nlink': 2, 'uid': uid, 'gid': gid,
              'size': 0, 'addr': [0] * 13}
        ents = (struct.pack('<H', ino) + b'.'.ljust(14, b'\0') +
                struct.pack('<H', parent) + b'..'.ljust(14, b'\0'))
        self.setdata(ip, ents)
        self.iwrite(ino, ip)
        self._dirent(parent, name, ino)
        pp = self.iread(parent)
        pp['nlink'] += 1
        self.iwrite(parent, pp)
        return ino

    def rm(self, path):
        parent, name = self._split(path)
        ino = self._undirent(parent, name)
        ip = self.iread(ino)
        if stat.S_ISDIR(ip['mode']):
            raise IsADirectoryError(path)
        ip['nlink'] -= 1
        if ip['nlink'] <= 0:
            self.truncate(ip)
            ip = {'mode': 0, 'nlink': 0, 'uid': 0, 'gid': 0, 'size': 0, 'addr': [0] * 13}
            self.tinode += 1
        self.iwrite(ino, ip)


def mkfs(path, nblocks, ninodes=None):
    """A new filesystem, laid out as COHERENT 4.2's mkfs lays one out."""
    if ninodes is None:
        ninodes = (nblocks // 7 + 7) // 8 * 8
    iblocks = ninodes * INOSZ // BSIZE
    isize = 2 + iblocks
    rootblk = isize
    img = bytearray(nblocks * BSIZE)
    t = int(time.time())

    # free list: blocks after the root directory, ascending runs of 63
    # plus a link block, the last link holding an empty list
    blocks = list(range(rootblk + 1, nblocks))
    groups = []
    while blocks:
        k = min(NICFREE - 1, len(blocks) - 1)
        entries, blocks = blocks[:k], blocks[k:]
        link, blocks = blocks[0], blocks[1:]
        groups.append((link, entries))
    lists = [[link] + entries[::-1] for link, entries in groups] + [[]]

    sb = bytearray(BSIZE)
    struct.pack_into('<H', sb, SB_ISIZE, isize)
    putpdp(sb, SB_FSIZE, nblocks)
    first = lists[0]
    struct.pack_into('<h', sb, SB_NFREE, len(first))
    for i, b in enumerate(first):
        putpdp(sb, SB_FREE + 4 * i, b)
    cache = list(range(min(ninodes, NICINOD + 2), 2, -1))[:NICINOD]
    struct.pack_into('<h', sb, SB_NINODE, len(cache))
    struct.pack_into('<%dH' % len(cache), sb, SB_INODE, *cache)
    putpdp(sb, SB_TIME, t)
    putpdp(sb, SB_TFREE, nblocks - rootblk - 1)
    struct.pack_into('<H', sb, SB_TINODE, ninodes - 2)
    struct.pack_into('<HH', sb, SB_M, 1, 1)
    sb[SB_FNAME:SB_FNAME + 6] = b'noname'
    sb[SB_FPACK:SB_FPACK + 6] = b'nopack'
    img[BSIZE:2 * BSIZE] = sb

    for (link, _), lst in zip(groups, lists[1:]):
        b = bytearray(BSIZE)
        struct.pack_into('<h', b, 0, len(lst))
        for i, x in enumerate(lst):
            putpdp(b, 2 + 4 * i, x)
        img[link * BSIZE:(link + 1) * BSIZE] = b

    def inode(ino, mode, nlink, size, addr0):
        raw = bytearray(INOSZ)
        struct.pack_into('<HhHH', raw, 0, mode, nlink, 0, 0)
        putpdp(raw, 8, size)
        putl3(raw, 12, addr0)
        for o in (52, 56, 60):
            putpdp(raw, o, t)
        o = 2 * BSIZE + (ino - 1) * INOSZ
        img[o:o + INOSZ] = raw
    inode(1, stat.S_IFREG, 0, 0, 0)                          # bad blocks
    inode(ROOTINO, stat.S_IFDIR | 0o777, 3, 32, rootblk)     # as COHERENT's mkfs
    d = (struct.pack('<H', ROOTINO) + b'.'.ljust(14, b'\0') +
         struct.pack('<H', ROOTINO) + b'..'.ljust(14, b'\0'))
    img[rootblk * BSIZE:rootblk * BSIZE + len(d)] = d

    with open(path, 'wb') as f:
        f.write(img)


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    img, op, args = argv[1], argv[2], argv[3:]
    if op == 'mkfs':
        mkfs(img, int(args[0], 0))
        return
    fs = FSW(img)
    if op == 'put':
        data = open(args[0], 'rb').read()
        fs.put(args[1], data, int(args[2], 8) if len(args) > 2 else 0o644)
    elif op == 'mkdir':
        fs.mkdir(args[0], int(args[1], 8) if len(args) > 1 else 0o755)
    elif op == 'rm':
        fs.rm(args[0])
    else:
        sys.exit(__doc__)
    fs.save()


if __name__ == '__main__':
    main(sys.argv)
