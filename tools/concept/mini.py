# Minimal line-art drawing kit in the game's own look (dark ground, pale outlines,
# navy hatched rooms, colour only for systems): px-space helpers around a ship
# origin (ox, oy) and a scale s (px per metre). Used by make_lineup.py / make_s09.py.
import math

BG = '#1d222a'
HULLF = '#3a3f48'
HULLS = '#cfd5dd'
ROOM = '#0b0e24'
EQF = '#1a1f2c'
EQ = '#d5dae1'
DIM = '#8d96a3'
FAINT = '#5a6371'
AIR = '#7fb6ff'
FLUID = '#62e6a0'
HEAT = '#ff8a3a'
HAZ = '#ffcc44'
VIO = '#c09aff'

DEFS = '''
<pattern id="hatch" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="7" stroke="#1a2250" stroke-width="1.2"/></pattern>
<pattern id="hatch2" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="5" stroke="#1a2250" stroke-width="1"/></pattern>
'''


class Pen:
    def __init__(self, ox, oy, s):
        self.ox, self.oy, self.s = ox, oy, s
        self.o = []

    def P(self, x, y):
        return (self.ox + x * self.s, self.oy + y * self.s)

    def _pts(self, pts):
        return ' '.join('%.1f,%.1f' % self.P(x, y) for x, y in pts)

    def poly(self, pts, fill=HULLF, stroke=HULLS, w=1.4, op=1.0, dash=None):
        self.o.append(f'<polygon points="{self._pts(pts)}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" opacity="{op}" stroke-linejoin="round"' + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')

    def room(self, pts):
        self.poly(pts, fill=ROOM, stroke='#4a5568', w=1.0)
        self.poly(pts, fill='url(#hatch)', stroke='none', w=0)

    def line(self, x1, y1, x2, y2, c=HULLS, w=1.2, op=1.0, dash=None):
        a, b = self.P(x1, y1), self.P(x2, y2)
        self.o.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{c}" stroke-width="{w}" opacity="{op}"' + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')

    def pline(self, pts, c=HULLS, w=1.2, op=1.0, dash=None):
        self.o.append(f'<polyline points="{self._pts(pts)}" fill="none" stroke="{c}" stroke-width="{w}" opacity="{op}" stroke-linejoin="round"' + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')

    def rect(self, x, y, w, h, fill=EQF, stroke=EQ, sw=1.1, rx=0.0, op=1.0, dash=None):
        a = self.P(x, y)
        self.o.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{w * self.s:.1f}" height="{h * self.s:.1f}" rx="{rx * self.s:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}"' + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')

    def circ(self, x, y, r, fill=EQF, stroke=EQ, sw=1.1, op=1.0):
        a = self.P(x, y)
        self.o.append(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{r * self.s:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}"/>')

    def ell(self, x, y, rx, ry, fill=EQF, stroke=EQ, sw=1.1, op=1.0):
        a = self.P(x, y)
        self.o.append(f'<ellipse cx="{a[0]:.1f}" cy="{a[1]:.1f}" rx="{rx * self.s:.1f}" ry="{ry * self.s:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}"/>')

    def node(self, x, y, r=None):
        r = r if r else max(1.6, 0.12 * self.s) / self.s
        self.circ(x, y, r, fill='#9aa3af', stroke='none')

    def text(self, x, y, t, size=12, c=DIM, anchor='start', weight=400):
        a = self.P(x, y)
        self.o.append(f'<text x="{a[0]:.1f}" y="{a[1]:.1f}" font-size="{size}" fill="{c}" text-anchor="{anchor}" font-weight="{weight}">{t}</text>')

    def truss(self, x0, x1, y0, y1, bay, c=DIM, w=1.2, nodes=True):
        # a side-on lattice: two chords, posts and alternating diagonals, node joints
        self.line(x0, y0, x1, y0, c, w * 1.4)
        self.line(x0, y1, x1, y1, c, w * 1.4)
        x = x0
        k = 0
        while x < x1 - 0.01:
            nx = min(x + bay, x1)
            self.line(x, y0, x, y1, c, w)
            if k % 2 == 0:
                self.line(x, y0, nx, y1, c, w * 0.9)
            else:
                self.line(x, y1, nx, y0, c, w * 0.9)
            if nodes:
                self.node(x, y0)
                self.node(x, y1)
            x = nx
            k += 1
        self.line(x1, y0, x1, y1, c, w)
        if nodes:
            self.node(x1, y0)
            self.node(x1, y1)

    def arc_pts(self, cx, cy, rx, ry, a0, a1, n=24):
        return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

    def svg(self):
        return '\n'.join(self.o)


HEAD = '''<html><head><style>@font-face{font-family:N;src:url(file:///tmp/claude-0/fontsrc/NotoSansSC-VF.ttf)}
body{margin:0;background:%s;font-family:N}</style></head><body>''' % BG
