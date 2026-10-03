#!/bin/sh
# mkdisks.sh -- make the SBC-386EX install set, sbc-d1.img .. sbc-d5.img,
# and sbc-b1.img, disk 1 for installing on the board itself.
#
# Installing these in QEMU, exactly as the original COHERENT 4.2.10 kit
# (README.md, section 3), gives a disk that boots the SBC-386EX directly.
# On the board, sbc-b1.img takes the place of sbc-d1.img.
#
#   disks 2-4  the 4.2.10 originals
#   disk 1     the original with /etc/brc.install and /etc/brc.update
#              asking for five diskettes, and board/Coh_420.post.sbc
#              appended to /conf/Coh_420.post, which runs board/setup.sh
#   board 1    disk 1 with the board kernel (/u/sbc/coh.fd: root on the
#              floppy) as /coherent, /begin and /update; /dev/console on
#              the serial port (the PC console kept as /dev/console.pc);
#              and /etc/mkdev's two IDE polling choices, ATSREG 3F6 and
#              1F7, both made the board's 1FE
#   disk 5     new, the board supplement: /Coh_420.5 (the marker
#              /etc/install looks for) and compressed/sbc.taz -- /coh.sbc,
#              /coh.sbc.sym, /coh.sbcq and /u/sbc/board -- which the
#              installer unpacks like the other disks' archives
#
# All on the host: the kernels are read out of the development disk,
# cf.img (so build them first, README.md section 2, steps 1-3), and the
# floppies are written with tools/cohfsw.py, not through COHERENT's floppy
# driver in QEMU, which now and then never finishes a transfer.
set -e
cd "$(dirname "$0")"
K=../distrib/coherent/4_2_10

for n in 1 2 3 4; do cp $K/d$n sbc-d$n.img; done

py - <<'EOF'
import io, os, shutil, stat, sys, tarfile, time
sys.path.insert(0, '../tools')
import cohfs, cohfsw

# disk 1: ask for five disks; run board/setup.sh at the end of the install
d1 = cohfsw.FSW('sbc-d1.img')
for f in ('/etc/brc.install', '/etc/brc.update'):
    old = d1.data(d1.lookup(f))
    new = old.replace(b'/dev/fva0 4\n', b'/dev/fva0 5\n')
    assert new != old, f
    d1.put(f, new)
post = d1.data(d1.lookup('/conf/Coh_420.post'))
assert b'SBC-386EX' not in post
d1.put('/conf/Coh_420.post', post + open('../board/Coh_420.post.sbc', 'rb').read())
d1.save()

dev = cohfs.FS('cf.img', 32)             # the partition starts at track 1

# board disk 1
shutil.copyfile('sbc-d1.img', 'sbc-b1.img')
b1 = cohfsw.FSW('sbc-b1.img')
b1.put('/coherent', dev.namei('/u/sbc/coh.fd').data())  # one inode, three names
b1.mknod('/dev/console', stat.S_IFCHR | 0o700, 5, 128)  # /dev/com1l
b1.mknod('/dev/console.pc', stat.S_IFCHR | 0o700, 2, 0)
mkdev = b1.data(b1.lookup('/etc/mkdev'))
for old in (b'ATSREG=0x3F6 ', b'ATSREG=0x1F7 '):
    assert mkdev.count(old) == 1, old
    mkdev = mkdev.replace(old, b'ATSREG=0x1FE ')
b1.put('/etc/mkdev', mkdev)
b1.save()
print('board disk 1: %d blocks free' % b1.tfree)

# disk 5: the board supplement
buf = io.BytesIO()
now = time.time()
with tarfile.open(fileobj=buf, mode='w:gz', format=tarfile.USTAR_FORMAT) as tar:
    def add(name, data=None, mode=0o644):
        ti = tarfile.TarInfo(name)
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = 'root'
        ti.mtime = now
        ti.mode = mode
        if data is None:
            ti.type = tarfile.DIRTYPE
            tar.addfile(ti)
        else:
            ti.size = len(data)
            tar.addfile(ti, io.BytesIO(data))
    for f, mode in (('coh.sbc', 0o755), ('coh.sbc.sym', 0o644), ('coh.sbcq', 0o755)):
        add(f, dev.namei('/' + f).data(), mode)
    add('u', mode=0o755)
    add('u/sbc', mode=0o755)
    add('u/sbc/board', mode=0o755)
    for f in sorted(os.listdir('../board')):
        add('u/sbc/board/' + f, open('../board/' + f, 'rb').read())
taz = buf.getvalue()

cohfsw.mkfs('sbc-d5.img', 2880)
d5 = cohfsw.FSW('sbc-d5.img')
d5.put('/Coh_420.5', b'')
d5.mkdir('/compressed', 0o700)
d5.put('/compressed/sbc.taz', taz)
d5.save()
print('sbc.taz: %d bytes; disk 5: %d blocks free' % (len(taz), d5.tfree))
EOF

sha1sum sbc-d?.img sbc-b1.img
