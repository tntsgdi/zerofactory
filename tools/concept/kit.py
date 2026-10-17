# Drawing kit for ship design sheets that have no ship file yet: the same look
# as shipdraw.py (rooms navy and hatched, structure grey, equipment with its
# line art, colour-coded lines, bolts, locks, ports), drawn in metres.
import math
from mini import Pen, BG, HULLF, HULLS, ROOM, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from shipdraw import _art


class Kit(Pen):
    def shell(self, outer, inner, fill=HULLF):
        """a hull band between two outlines (evenodd), metres"""
        d = 'M' + ' L'.join('%.1f,%.1f' % self.P(x, y) for x, y in outer) + ' Z M' + ' L'.join('%.1f,%.1f' % self.P(x, y) for x, y in inner) + ' Z'
        self.o.append(f'<path d="{d}" fill="{fill}" fill-rule="evenodd" stroke="{HULLS}" stroke-width="1.4" stroke-linejoin="round"/>')

    def seams(self, outer, inner, every=1):
        """plate seams: short lines from outer to inner vertex pairs"""
        for i in range(0, min(len(outer), len(inner)), every):
            self.line(outer[i][0], outer[i][1], inner[i][0], inner[i][1], '#0d1117', 1.2)

    def plate(self, pts, fill=HULLF, stroke=HULLS, w=1.3):
        self.poly(pts, fill=fill, stroke=stroke, w=w)

    def box(self, x, y, w, h, fill=HULLF, stroke=HULLS, sw=1.3):
        self.rect(x, y, w, h, fill=fill, stroke=stroke, sw=sw)

    def eq(self, x, y, w, h, art=None, label="", tag="", must=False, col=None, hazard=""):
        c = HEAT if must else (col if col else EQ)
        self.rect(x, y, w, h, fill=EQF, stroke=c, sw=1.4 if must else 1.1)
        if art:
            inner = []
            _art(inner, art, w, h, {"label": label, "tag": tag, "hazard": hazard}, 1.0)
            ox, oy = self.P(x, y)
            self.o.append(f'<g transform="translate({ox:.1f},{oy:.1f}) scale({self.s})">' + ''.join(inner) + '</g>')

    def peq(self, pts, col=EQ, must=False):
        self.poly(pts, fill=EQF, stroke=HEAT if must else col, w=1.4 if must else 1.1)

    def tank(self, x, y, w, h, col=AIR, label=""):
        r = min(w, h) * 0.48
        self.rect(x, y, w, h, fill=EQF, stroke=col, sw=1.3, rx=r)
        if label:
            fs = max(9, min(15, h * self.s * 0.28))
            px, py = self.P(x + w / 2, y + h / 2)
            self.o.append(f'<text x="{px:.0f}" y="{py + fs * 0.35:.0f}" font-size="{fs:.0f}" fill="{col}" text-anchor="middle">{label}</text>')

    def sphere(self, cx, cy, r, col=AIR, label="", jacket=0.0):
        if jacket > 0:
            self.circ(cx, cy, r + jacket, fill=EQF, stroke=DIM, sw=1.0)
            self.circ(cx, cy, r + jacket * 0.5, fill='none', stroke=FAINT, sw=0.8)
        self.circ(cx, cy, r, fill=EQF, stroke=col, sw=1.3)
        if label:
            fs = max(9, min(15, r * self.s * 0.4))
            px, py = self.P(cx, cy)
            self.o.append(f'<text x="{px:.0f}" y="{py + fs * 0.35:.0f}" font-size="{fs:.0f}" fill="{col}" text-anchor="middle">{label}</text>')

    def bolt(self, x, y):
        a = self.P(x, y)
        self.o.append(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{max(1.3, 0.06 * self.s):.1f}" fill="#b4c0cf"/>')

    def bolts(self, x0, y0, x1, y1, n):
        for i in range(n):
            t = (i + 0.5) / n
            self.bolt(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)

    def lock(self, x, y):
        a = self.P(x, y)
        r = max(1.8, 0.08 * self.s)
        self.o.append(f'<rect x="{a[0] - r:.1f}" y="{a[1] - r:.1f}" width="{2 * r:.1f}" height="{2 * r:.1f}" fill="{HAZ}"/>')

    def port(self, x, y, col=AIR):
        a = self.P(x, y)
        r = max(2.0, 0.09 * self.s)
        self.o.append(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{r:.1f}" fill="{BG}" stroke="{col}" stroke-width="1.4"/>')

    def switch(self, x, y, col=HEAT):
        a = self.P(x, y)
        r = max(2.0, 0.09 * self.s)
        self.o.append(f'<rect x="{a[0] - r:.1f}" y="{a[1] - r:.1f}" width="{2 * r:.1f}" height="{2 * r:.1f}" fill="{BG}" stroke="{col}" stroke-width="1.4"/>')

    def cable(self, pts, col=HEAT, w=1.3):
        self.pline(pts, col, w, 0.85, dash='5 3')

    def pipe(self, pts, col=FLUID, w=1.8):
        self.pline(pts, col, w, 0.85)

    def door(self, x, y, w, h):
        self.rect(x, y, w, h, fill='#2a3140', stroke=AIR, sw=1.2)

    def seat(self, x, floor_y, h=1.75, facing=-1, op=1.0):
        """a crash couch in profile on its floor rail; facing -1 = towards -x"""
        sh = [(0.02, 1.0), (0.98, 1.0), (0.98, 0.92), (0.6, 0.92), (0.6, 0.75), (0.78, 0.72), (1.0, 0.18), (1.0, 0.02), (0.86, 0.0), (0.82, 0.15),
              (0.6, 0.63), (0.02, 0.64), (0.02, 0.75), (0.38, 0.75), (0.38, 0.92), (0.02, 0.92)]
        w = 0.72
        pts = []
        for qx, qy in sh:
            if facing > 0:
                qx = 1.0 - qx
            pts.append((x + qx * w, floor_y - h + qy * h))
        self.poly(pts, fill=EQF, stroke=EQ, w=1.0, op=op)
        self.pline([(x + (0.88 if facing < 0 else 0.12) * w, floor_y - h * 0.76), (x + 0.42 * w, floor_y - h * 0.5), (x + (0.2 if facing < 0 else 0.8) * w, floor_y - h * 0.36)], HAZ, 1.0, 0.6 * op)
        self.bolt(x + 0.15, floor_y - 0.03)
        self.bolt(x + w - 0.15, floor_y - 0.03)

    def label(self, x, y, t, size=11, col=DIM, anchor='start'):
        a = self.P(x, y)
        self.o.append(f'<text x="{a[0]:.0f}" y="{a[1]:.0f}" font-size="{size}" fill="{col}" text-anchor="{anchor}">{t}</text>')

    def frames(self, xs, ytop_fn, ybot_fn, w=0.18):
        """ring frames / ribs: short stubs inside the shell at each station"""
        for x in xs:
            yt, yb = ytop_fn(x), ybot_fn(x)
            self.line(x, yt, x, yt + 0.35, HULLS, 2.0)
            self.line(x, yb, x, yb - 0.35, HULLS, 2.0)

    def grid(self, x0, x1, y, n=None, col=FAINT):
        pass


def arc(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def offset(poly, d):
    """inset a closed polygon by d (convex-ish outlines, CCW in screen y-down = clockwise visually)"""
    n = len(poly)
    out = []
    for i in range(n):
        ax, ay = poly[(i - 1) % n]
        bx, by = poly[i]
        cx, cy = poly[(i + 1) % n]
        d1 = (bx - ax, by - ay)
        l1 = math.hypot(*d1) or 1
        d1 = (d1[0] / l1, d1[1] / l1)
        d2 = (cx - bx, cy - by)
        l2 = math.hypot(*d2) or 1
        d2 = (d2[0] / l2, d2[1] / l2)
        n1 = (-d1[1], d1[0])
        n2 = (-d2[1], d2[0])
        # intersection of the two offset lines
        p1 = (ax + n1[0] * d, ay + n1[1] * d)
        p2 = (bx + n2[0] * d, by + n2[1] * d)
        den = d1[0] * d2[1] - d1[1] * d2[0]
        if abs(den) < 1e-6:
            out.append((bx + n1[0] * d, by + n1[1] * d))
            continue
        t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / den
        out.append((p1[0] + d1[0] * t, p1[1] + d1[1] * t))
    return out
