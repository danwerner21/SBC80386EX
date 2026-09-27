#!/usr/bin/env python3
"""mkfont.py -- rasterize a FontForge .sfd into an 8x16 code-page-437 font.

Reads the outlines directly, so it needs nothing but Python: no FontForge,
no freetype.  Cubic contours are flattened, filled by the non-zero winding
rule on a supersampled grid, and thresholded.  Box-drawing and block
characters (B0..DF) are not rasterized but drawn, pixel by pixel, because
they must butt against their neighbours exactly and no outline scaled to
eight pixels will do that.

    py mkfont.py 3270.SFD font3270.inc [--show 41 42 ...]

A .inc output is a NASM include (db lines under the label v3_font);
a .h output is a C table.
"""
import sys

W, H  = 8, 16          # pixels per cell that the glyph may occupy
S     = 8              # supersamples per pixel, each axis
ADV   = 1080           # the font's advance width, in its own units
CELLW = 9              # what one advance maps to on screen

# ---------------------------------------------------------------- SFD ----

def parse_sfd(path):
    glyphs_by_uni, glyphs_by_gid = {}, {}
    cur = None; in_fore = False; in_ss = False
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            if line.startswith('StartChar:'):
                cur = {'name': line.split(':',1)[1].strip(), 'contours': [],
                       'refs': [], 'width': ADV, 'uni': -1, 'gid': -1}
                in_fore = in_ss = False
            elif cur is None:
                continue
            elif line.startswith('EndChar'):
                if cur['uni'] >= 0: glyphs_by_uni[cur['uni']] = cur
                if cur['gid'] >= 0: glyphs_by_gid[cur['gid']] = cur
                cur = None
            elif line.startswith('Encoding:'):
                a = line.split()
                cur['uni'] = int(a[2]); cur['gid'] = int(a[3])
            elif line.startswith('Width:'):
                cur['width'] = int(line.split()[1])
            elif line.startswith('Fore'):
                in_fore = True
            elif line.startswith('Back'):
                in_fore = False
            elif line.startswith('SplineSet'):
                if in_fore: in_ss = True; cur['contours'].append([])
            elif line.startswith('EndSplineSet'):
                in_ss = False
            elif line.startswith('Refer:') and in_fore:
                a = line.split()
                gid = int(a[1]); m = [float(x) for x in a[4:10]]
                cur['refs'].append((gid, m))
            elif in_ss:
                parse_spline_line(line, cur['contours'])
    return glyphs_by_uni, glyphs_by_gid

def parse_spline_line(line, contours):
    toks = line.split()
    if not toks: return
    # trailing flag tokens like "1", "0", "1024,-1,-1" follow the op letter
    op = None
    for i, t in enumerate(toks):
        if t in ('m', 'l', 'c'):
            op = t; nums = [float(x) for x in toks[:i]]; break
    if op is None: return
    poly = contours[-1]
    if op == 'm':
        poly.append(('m', nums[0], nums[1]))
    elif op == 'l':
        poly.append(('l', nums[0], nums[1]))
    elif op == 'c':
        poly.append(('c', *nums[:6]))

def outline(glyph, by_gid, mat=(1,0,0,1,0,0), depth=0):
    """Flattened polygons for a glyph, references resolved, as lists of
    (x, y) in font units."""
    polys = []
    def xf(x, y):
        a, b, c, d, e, f = mat
        return (a*x + c*y + e, b*x + d*y + f)
    for ss in glyph['contours']:
        pts = []; cur = None
        for seg in ss:
            if seg[0] == 'm':
                if len(pts) > 1: polys.append(pts)
                pts = [xf(seg[1], seg[2])]; cur = (seg[1], seg[2])
            elif seg[0] == 'l':
                pts.append(xf(seg[1], seg[2])); cur = (seg[1], seg[2])
            else:
                x0, y0 = cur; _, x1, y1, x2, y2, x3, y3 = seg
                for i in range(1, 9):
                    t = i / 8.0; u = 1 - t
                    x = u*u*u*x0 + 3*u*u*t*x1 + 3*u*t*t*x2 + t*t*t*x3
                    y = u*u*u*y0 + 3*u*u*t*y1 + 3*u*t*t*y2 + t*t*t*y3
                    pts.append(xf(x, y))
                cur = (x3, y3)
        if len(pts) > 1: polys.append(pts)
    if depth < 4:
        for gid, m in glyph['refs']:
            g = by_gid.get(gid)
            if g is None: continue
            # compose: apply m (in referencing glyph's space) then mat
            a, b, c, d, e, f = m
            A, B, C, D, E, F = mat
            comp = (a*A + b*C, a*B + b*D, c*A + d*C, c*B + d*D,
                    e*A + f*C + E, e*B + f*D + F)
            polys += outline(g, by_gid, comp, depth+1)
    return polys

def bbox(polys):
    xs = [p[0] for poly in polys for p in poly]
    ys = [p[1] for poly in polys for p in poly]
    return (min(xs), min(ys), max(xs), max(ys)) if xs else None

# ---------------------------------------------------------- rasterize ----

def edges_of(polys, sx, sy, ox, oy):
    """Outline edges in pixel units: font (x,y) -> ((x - ox) * sx,
    (oy - y) * sy), rows counted downward.  Every edge is kept: the ones
    that are horizontal here are the ones the column pass needs."""
    edges = []
    for poly in polys:
        n = len(poly)
        for i in range(n):
            x0, y0 = poly[i]; x1, y1 = poly[(i+1) % n]
            e = ((x0 - ox) * sx, (oy - y0) * sy, (x1 - ox) * sx, (oy - y1) * sy)
            edges.append(e)
    return edges

def spans(edges, yc):
    """Filled intervals [xa, xb) along the line y = yc, non-zero winding."""
    xs = []
    for x0, y0, x1, y1 in edges:
        if (y0 <= yc < y1) or (y1 <= yc < y0):
            t = (yc - y0) / (y1 - y0)
            xs.append((x0 + t*(x1 - x0), 1 if y1 > y0 else -1))
    xs.sort()
    out = []; wind = 0; xa = 0.0
    for x, d in xs:
        prev = wind; wind += d
        if prev == 0 and wind != 0: xa = x
        elif prev != 0 and wind == 0: out.append((xa, x))
    return out

def coverage(edges):
    """Coverage grid H x W in 0..S*S from S sub-scanlines a row."""
    cov = [[0]*W for _ in range(H)]
    for r in range(H * S):
        for xa, xb in spans(edges, (r + 0.5) / S):
            c0 = int(xa * S + 0.5); c1 = int(xb * S + 0.5)
            for c in range(max(c0, 0), min(c1, W*S)):
                cov[r // S][c // S] += 1
    return cov

def dropout(bits, edges):
    """Where the outline crosses a pixel row or column but the threshold
    lit nothing there, light the pixel under the middle of the crossing.
    This is what lets the threshold sit high enough for one-pixel stems
    without a stem that straddles a boundary disappearing."""
    for r in range(H):
        for xa, xb in spans(edges, r + 0.5):
            if xb <= 0 or xa >= W: continue
            c0, c1 = max(int(xa), 0), min(int(xb - 1e-9), W - 1)
            if not any(bits[r][c] for c in range(c0, c1 + 1)):
                bits[r][min(max(int((xa + xb) / 2), 0), W - 1)] = 1
    tedges = [(y0, x0, y1, x1) for x0, y0, x1, y1 in edges]
    for c in range(W):
        for ya, yb in spans(tedges, c + 0.5):
            if yb <= 0 or ya >= H: continue
            r0, r1 = max(int(ya), 0), min(int(yb - 1e-9), H - 1)
            if not any(bits[r][c] for r in range(r0, r1 + 1)):
                bits[min(max(int((ya + yb) / 2), 0), H - 1)][c] = 1
    return bits

def normalize(bits, edges, maxw=1.6):
    """One stroke, one pixel.  Where the outline crosses a column or a row
    in a span narrower than maxw pixels it is a single stroke, and only
    the pixel under the middle of the span is kept lit.  Wider crossings
    are two strokes meeting, or a bowl, and are left as thresholded.
    Columns first, rows last, so a steep diagonal ends up with exactly
    one pixel a row and stays connected."""
    tedges = [(y0, x0, y1, x1) for x0, y0, x1, y1 in edges]
    for c in range(W):
        for ya, yb in spans(tedges, c + 0.5):
            if yb - ya >= maxw or yb <= 0 or ya >= H: continue
            r0, r1 = max(int(ya), 0), min(int(yb - 1e-9), H - 1)
            for r in range(r0, r1 + 1): bits[r][c] = 0
            bits[min(max(int((ya + yb) / 2), 0), H - 1)][c] = 1
    for r in range(H):
        for xa, xb in spans(edges, r + 0.5):
            if xb - xa >= maxw or xb <= 0 or xa >= W: continue
            c0, c1 = max(int(xa), 0), min(int(xb - 1e-9), W - 1)
            for c in range(c0, c1 + 1): bits[r][c] = 0
            bits[r][min(max(int((xa + xb) / 2), 0), W - 1)] = 1
    return bits

def threshold(cov, level):
    return [[1 if v >= level else 0 for v in row] for row in cov]

def show(bits, label=''):
    print(label)
    for row in bits:
        print('   ' + ''.join('#' if b else '.' for b in row) + '|')

# ------------------------------------------------------------- layout ----

SX, OX = 1.0/120, 0        # 9 px to the 1080 advance, H stems on cols 1,7
SY     = 1.0/110           # caps 1096 tall -> 10 rows
BASE   = 98                # y of the baseline in font units
OY     = BASE + 12/SY      # baseline lands at pixel row 12

def render(glyph, by_gid, level):
    polys = outline(glyph, by_gid)
    if not polys: return [[0]*W for _ in range(H)]
    edges = edges_of(polys, SX, SY, OX, OY)
    return normalize(dropout(threshold(coverage(edges), level), edges), edges)

def preview(uni, gid, codes, level):
    for c in codes:
        g = uni.get(c)
        if g is None: print('%04X missing' % c); continue
        show(render(g, gid, level), '%04X %s' % (c, g['name']))

# Of S*S = 64.  High on purpose: the 3270 face is thin and crisp and its
# stems are about one pixel at this scale, so a pixel has to be mostly
# covered to light.  Dropout control keeps the strokes that would
# otherwise fall between two pixels.
LEVEL = 44

# ------------------------------------------------------------- CP437 ----

# Python's cp437 codec gives the printable range but leaves 00..1F and 7F
# as control characters; the IBM glyphs that live there are these.
LOW = [0x0000, 0x263A, 0x263B, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
       0x25D8, 0x25CB, 0x25D9, 0x2642, 0x2640, 0x266A, 0x266B, 0x263C,
       0x25BA, 0x25C4, 0x2195, 0x203C, 0x00B6, 0x00A7, 0x25AC, 0x21A8,
       0x2191, 0x2193, 0x2192, 0x2190, 0x221F, 0x2194, 0x25B2, 0x25BC]

def cp437_to_unicode(code):
    if code < 0x20: return LOW[code]
    if code == 0x7F: return 0x2302
    return ord(bytes([code]).decode('cp437'))

# ------------------------------------------------- box drawing, drawn ----
#
# Arms are (up, down, left, right), each 0 none, 1 single, 2 double.  The
# geometry is VGA's: a single line is two pixels wide vertically (cols 3
# and 4) but one row horizontally (row 7), because the pixels are not
# square; double rails sit at cols 1-2 and 5-6, rows 6 and 8.  The rules
# for where an arm stops at a junction were read off the VGA font and
# reproduce its corners exactly.

BOX = {
 0xB3:(1,1,0,0), 0xB4:(1,1,1,0), 0xB5:(1,1,2,0), 0xB6:(2,2,1,0),
 0xB7:(0,2,1,0), 0xB8:(0,1,2,0), 0xB9:(2,2,2,0), 0xBA:(2,2,0,0),
 0xBB:(0,2,2,0), 0xBC:(2,0,2,0), 0xBD:(2,0,1,0), 0xBE:(1,0,2,0),
 0xBF:(0,1,1,0), 0xC0:(1,0,0,1), 0xC1:(1,0,1,1), 0xC2:(0,1,1,1),
 0xC3:(1,1,0,1), 0xC4:(0,0,1,1), 0xC5:(1,1,1,1), 0xC6:(1,1,0,2),
 0xC7:(2,2,0,1), 0xC8:(2,0,0,2), 0xC9:(0,2,0,2), 0xCA:(2,0,2,2),
 0xCB:(0,2,2,2), 0xCC:(2,2,0,2), 0xCD:(0,0,2,2), 0xCE:(2,2,2,2),
 0xCF:(1,0,2,2), 0xD0:(2,0,1,1), 0xD1:(0,1,2,2), 0xD2:(0,2,1,1),
 0xD3:(2,0,0,1), 0xD4:(1,0,0,2), 0xD5:(0,1,0,2), 0xD6:(0,2,0,1),
 0xD7:(2,2,1,1), 0xD8:(1,1,2,2), 0xD9:(1,0,1,0), 0xDA:(0,1,0,1),
}

def box(U, D, L, R):
    px = set()
    V, Hs = max(U, D), max(L, R)

    # vertical
    if V == 1:
        rows = set()
        if Hs == 2:
            if U and D:          rows = set(range(0, 16))
            elif U:              rows = set(range(0, 7) if (L and R) else range(0, 9))
            elif D:              rows = set(range(8, 16) if (L and R) else range(6, 16))
        else:
            if U: rows |= set(range(0, 8))
            if D: rows |= set(range(7, 16))
        for r in rows: px |= {(3, r), (4, r)}
    elif V == 2:
        for cols, cut in (((1, 2), L), ((5, 6), R)):   # a rail is cut by the arm on its side
            rows = set()
            if Hs == 2:
                if cut:
                    if U: rows |= set(range(0, 7))
                    if D: rows |= set(range(8, 16))
                else:
                    if U and D: rows = set(range(0, 16))
                    elif U:     rows = set(range(0, 9))
                    elif D:     rows = set(range(6, 16))
            else:
                if U: rows |= set(range(0, 8))
                if D: rows |= set(range(7, 16))
            for r in rows:
                for c in cols: px.add((c, r))

    # horizontal
    if Hs == 1:
        cols = set()
        if V == 2:
            if U and D:
                if L and R: cols = set(range(0, 8))
                else:
                    if L: cols |= set(range(0, 3))
                    if R: cols |= set(range(5, 8))
            else:
                if L and R: cols = set(range(0, 8))
                elif L:     cols = set(range(0, 7))
                elif R:     cols = set(range(1, 8))
        else:
            if L: cols |= set(range(0, 5))
            if R: cols |= set(range(3, 8))
        for c in cols: px.add((c, 7))
    elif Hs == 2:
        for row, cut in ((6, U), (8, D)):
            cols = set()
            if V == 2:
                if cut:
                    if L: cols |= set(range(0, 3))
                    if R: cols |= set(range(5, 8))
                else:
                    if L and R: cols = set(range(0, 8))
                    elif L:     cols = set(range(0, 7))
                    elif R:     cols = set(range(1, 8))
            else:
                if L: cols |= set(range(0, 5))
                if R: cols |= set(range(3, 8))
            for c in cols: px.add((c, row))

    return [[1 if (c, r) in px else 0 for c in range(W)] for r in range(H)]

def drawn(code):
    """Pixel-defined glyphs: box drawing, blocks and shades."""
    if code in BOX: return box(*BOX[code])
    full = lambda r, c: 1
    rules = {
        0xB0: lambda r, c: (0x22 if r % 2 == 0 else 0x88) >> (7 - c) & 1,
        0xB1: lambda r, c: (0x55 if r % 2 == 0 else 0xAA) >> (7 - c) & 1,
        0xB2: lambda r, c: (0xDD if r % 2 == 0 else 0x77) >> (7 - c) & 1,
        0xDB: full,
        0xDC: lambda r, c: r >= 8,
        0xDD: lambda r, c: c <= 3,
        0xDE: lambda r, c: c >= 4,
        0xDF: lambda r, c: r < 8,
        0xFE: lambda r, c: 5 <= r <= 10 and 1 <= c <= 6,
    }
    f = rules.get(code)
    if f is None: return None
    return [[1 if f(r, c) else 0 for c in range(W)] for r in range(H)]

# ------------------------------------------------------------- output ----

def glyph_bits(code, uni, gid):
    d = drawn(code)
    if d is not None: return d, 'drawn'
    u = cp437_to_unicode(code)
    g = uni.get(u)
    if g is None or u == 0 or u == 0x20 or u == 0xA0:
        return [[0]*W for _ in range(H)], 'blank' if u in (0, 0x20, 0xA0) else 'MISSING U+%04X' % u
    return render(g, gid, LEVEL), g['name']

def rows_to_bytes(bits):
    return [sum(b << (7 - c) for c, b in enumerate(row)) for row in bits]

def main():
    args = sys.argv[1:]
    showlist = []
    if '--show' in args:
        i = args.index('--show'); showlist = [int(x, 16) for x in args[i+1:]]; args = args[:i]
    sfd, out = args[0], (args[1] if len(args) > 1 else None)
    uni, gid = parse_sfd(sfd)
    table, missing = [], []
    for code in range(256):
        bits, how = glyph_bits(code, uni, gid)
        if how.startswith('MISSING'): missing.append((code, how))
        table.append((code, bits, how))
    if showlist:
        for code in showlist:
            show(table[code][1], '%02X %s' % (code, table[code][2]))
    if missing:
        print('%d code points have no glyph and are blank:' % len(missing), file=sys.stderr)
        print('   ' + ' '.join('%02X' % c for c, _ in missing), file=sys.stderr)
    if out:
        nasm = out.lower().endswith('.inc')
        c1, c2, c3 = (';', ';', '') if nasm else ('/*', ' *', ' */')
        with open(out, 'w', newline='\n') as f:
            f.write('%s %s -- an 8x16 code page 437 font, generated.  Do not edit.\n' % (c1, out))
            f.write('%s\n%s Made by mkfont.py from %s: the IBM 3270 face by the 3270font\n' % (c2, c2, sfd.replace(chr(92), '/')))
            f.write('%s project (rbanffy), rasterized to eight by sixteen; box drawing and\n' % c2)
            f.write('%s blocks B0..DF drawn to VGA geometry so they tile.  Sixteen bytes a\n' % c2)
            f.write('%s character, top row first, bit 7 leftmost.  4096 bytes.%s\n\n' % (c2, c3))
            if nasm:
                f.write('v3_font:\n')
                for code, bits, how in table:
                    bs = rows_to_bytes(bits)
                    f.write('\tdb ' + ','.join('0x%02X' % b for b in bs) + '\t; %02X\n' % code)
                f.write('v3_font_len\tequ\t$ - v3_font\n')
            else:
                f.write('static const byte v3_font[4096] = {\n')
                for code, bits, how in table:
                    bs = rows_to_bytes(bits)
                    f.write('/* %02X */ ' % code + ','.join('0x%02X' % b for b in bs) + ',\n')
                f.write('};\n')
        print('wrote', out)

if __name__ == '__main__':
    main()
