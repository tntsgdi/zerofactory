# Draws a ship file (ships/<id>.json, metres, y down) as a structure drawing in
# the game's minimal style: rooms navy and hatched, structure grey, equipment
# with its own line art (ported from scripts/art.gd), cables / pipes coloured by
# what runs in them, bolts and locks, ports and switches, the dock clamps.
import json, math
from mini import BG, HULLF, HULLS, ROOM, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO

STRUCT = {"hull", "hatch", "bulkhead", "door", "deck", "keel", "strut", "rib", "beam", "rail", "plate"}
NET_COL = {"power": HEAT, "nav": VIO, "brake": VIO, "coolant": FLUID, "coolant_broken": FLUID, "gas": AIR, "fuel": HAZ, "rcs": HAZ, "none": DIM}


class SVG:
    def __init__(self, s, ox, oy):
        self.s, self.ox, self.oy = s, ox, oy
        self.o = []

    def P(self, x, y):
        return (self.ox + x * self.s, self.oy + y * self.s)

    def pts(self, poly):
        return ' '.join('%.1f,%.1f' % self.P(q[0], q[1]) for q in poly)


def _art(o, art, w, h, piece, sw):
    """line art inside the piece's own rectangle (0,0)-(w,h), metres; o collects SVG elements"""
    L = lambda x1, y1, x2, y2, a=0.5, wd=1.0: o.append(f'<line x1="{x1:.3f}" y1="{y1:.3f}" x2="{x2:.3f}" y2="{y2:.3f}" stroke="{EQ}" stroke-opacity="{a}" stroke-width="{wd}" vector-effect="non-scaling-stroke"/>')
    B = lambda x, y, ww, hh, a=0.5: o.append(f'<rect x="{x:.3f}" y="{y:.3f}" width="{ww:.3f}" height="{hh:.3f}" fill="none" stroke="{EQ}" stroke-opacity="{a}" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    C = lambda x, y, r, a=0.5, fill="none": o.append(f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{r:.3f}" fill="{fill}" stroke="{EQ}" stroke-opacity="{a}" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    D = lambda x, y, r=0.035, col=EQ, a=0.7: o.append(f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{r:.3f}" fill="{col}" fill-opacity="{a}"/>')
    T = lambda x, y, t, size, a=0.6: o.append(f'<text x="{x:.3f}" y="{y:.3f}" font-size="{size:.3f}" fill="{EQ}" fill-opacity="{a}" font-family="N">{t}</text>')
    label = piece.get("label", "")
    if art == "nav_rack":
        for i in range(5):
            B(w * 0.12, h * (0.06 + i * 0.18), w * 0.76, h * 0.14, 0.4)
            D(w * 0.76, h * (0.13 + i * 0.18))
    elif art == "nav":
        B(w * 0.08, h * 0.12, w * 0.5, h * 0.42, 0.6)
        for i in range(3):
            C(w * (0.68 + i * 0.1), h * 0.3, w * 0.035)
    elif art == "seat":
        L(w * 0.83, h * 0.17, w * 0.97, h * 0.2, 0.4)
        L(w * 0.06, h * 0.69, w * 0.62, h * 0.68, 0.3)
        o.append(f'<polyline points="{w*0.88:.3f},{h*0.24:.3f} {w*0.42:.3f},{h*0.5:.3f} {w*0.2:.3f},{h*0.64:.3f}" fill="none" stroke="{HAZ}" stroke-opacity="0.6" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        L(w * 0.12, h * 0.64, w * 0.1, h * 0.5, 0.5, 1.2)
    elif art == "overhead":
        for i in range(7):
            D(w * (0.1 + i * 0.13), h * 0.55, 0.025)
    elif art == "o2cab":
        B(w * 0.08, h * 0.06, w * 0.84, h * 0.88, 0.4)
        o.append(f'<rect x="{w*0.26:.3f}" y="{h*0.18:.3f}" width="{w*0.48:.3f}" height="{h*0.68:.3f}" rx="{w*0.22:.3f}" fill="none" stroke="{AIR}" stroke-opacity="0.7" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        T(w * 0.33, h * 0.6, label, h * 0.14)
    elif art == "console":
        o.append(f'<polyline points="{w*0.1:.3f},{h:.3f} {w*0.1:.3f},{h*0.45:.3f} {w*0.95:.3f},{h*0.2:.3f} {w*0.95:.3f},{h:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.5" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        for i in range(4):
            D(w * (0.25 + i * 0.17), h * (0.42 - i * 0.05), 0.03)
    elif art == "blackbox":
        B(w * 0.12, h * 0.15, w * 0.76, h * 0.7, 0.7)
        for i in range(3):
            L(w * 0.12, h * (0.3 + i * 0.18), w * 0.88, h * (0.3 + i * 0.18), 0.55, 1.4)
    elif art == "cover":
        L(w * 0.2, h * 0.5, w * 0.8, h * 0.5, 0.3)
    elif art in ("gastank",):
        o.append(f'<rect x="{w*0.08:.3f}" y="{0.02:.3f}" width="{w*0.84:.3f}" height="{h-0.04:.3f}" rx="{w*0.4:.3f}" fill="none" stroke="{AIR}" stroke-opacity="0.75" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        for i in range(2):
            L(w * 0.08, h * (0.38 + i * 0.24), w * 0.92, h * (0.38 + i * 0.24), 0.3)
        T(w * 0.25, h * 0.56, label, w * 0.32)
    elif art == "env":
        C(w * 0.3, h * 0.45, h * 0.26, 0.55)
        for i in range(6):
            a = math.tau * i / 6
            L(w * 0.3, h * 0.45, w * 0.3 + math.cos(a) * h * 0.22, h * 0.45 + math.sin(a) * h * 0.22, 0.35)
        for i in range(4):
            L(w * 0.62, h * (0.22 + i * 0.16), w * 0.9, h * (0.22 + i * 0.16), 0.4)
    elif art == "bunk":
        L(0.08, h * 0.35, w - 0.08, h * 0.35, 0.35)
        B(0.12, h * 0.05, w * 0.18, h * 0.28, 0.3)
    elif art == "cargo":
        n = max(2, int(w / 0.33))
        for i in range(1, n):
            L(w * i / n, 0.06, w * i / n, h - 0.06, 0.22)
        B(0.06, 0.06, w - 0.12, h - 0.12, 0.4)
        T(w * 0.08, h * 0.2, piece.get("tag", ""), 0.25, 0.75)
        T(w * 0.08, h * 0.2 + 0.27, label, 0.17, 0.45)
    elif art == "hook":
        L(w * 0.5, 0, w * 0.5, h * 0.7, 0.5)
        o.append(f'<path d="M{w*0.3:.3f},{h*0.78:.3f} A{w*0.22:.3f},{w*0.22:.3f} 0 1 0 {w*0.72:.3f},{h*0.78:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.6" stroke-width="1.2" vector-effect="non-scaling-stroke"/>')
    elif art == "lamp":
        L(0.06, h * 0.6, w - 0.06, h * 0.6, 0.5)
    elif art == "gen":
        for i in range(3):
            cx = w * (0.2 + i * 0.22)
            B(cx - w * 0.08, h * 0.18, w * 0.16, h * 0.6, 0.45)
        T(w * 0.06, h * 0.12, label, min(0.2, h * 0.1), 0.5)
    elif art == "battery":
        for i in range(4):
            for k in range(2):
                B(w * (0.08 + i * 0.22), h * (0.2 + k * 0.36), w * 0.18, h * 0.3, 0.35)
                o.append(f'<rect x="{w*(0.09+i*0.22):.3f}" y="{h*(0.2+k*0.36)+h*0.3*0.4:.3f}" width="{w*0.16:.3f}" height="{h*0.3*0.58:.3f}" fill="{FLUID}" fill-opacity="0.3"/>')
    elif art == "cap":
        for i in range(5):
            o.append(f'<ellipse cx="{w*0.5:.3f}" cy="{h*(0.15+i*0.17):.3f}" rx="{w*0.36:.3f}" ry="{h*0.05:.3f}" fill="none" stroke="{VIO}" stroke-opacity="0.8" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    elif art == "swb":
        for i in range(6):
            B(w * 0.18, h * (0.08 + i * 0.14), w * 0.64, h * 0.09, 0.35)
            D(w * 0.7, h * (0.125 + i * 0.14), 0.025)
    elif art == "pump":
        C(w * 0.38, h * 0.5, h * 0.3, 0.55)
        C(w * 0.38, h * 0.5, h * 0.1, 0.4)
        B(w * 0.72, h * 0.25, w * 0.2, h * 0.5, 0.45)
    elif art == "cabinet":
        L(w * 0.5, 0.08, w * 0.5, h - 0.08, 0.35)
        for i in range(3):
            L(0.12, h * (0.3 + i * 0.22), w - 0.12, h * (0.3 + i * 0.22), 0.2)
    elif art == "radiator":
        n = max(3, int(w / 0.12))
        for i in range(1, n):
            L(w * i / n, 0.06, w * i / n, h - 0.06, 0.3)
    elif art == "module":
        B(w * 0.15, h * 0.2, w * 0.7, h * 0.6, 0.6)
    elif art == "eng_front":
        for i in range(4):
            L(w * 0.15, h * (0.2 + i * 0.2), w * 0.85, h * (0.2 + i * 0.2), 0.3)
        C(w * 0.5, h * 0.5, h * 0.18)
    elif art in ("eng_core",):
        for i in range(7):
            L(w * (0.08 + i * 0.14), h * 0.1, w * (0.08 + i * 0.14), h * 0.9, 0.25)
    elif art == "shroud":
        for i in range(8):
            L(w * (0.06 + i * 0.12), 0.04, w * (0.06 + i * 0.12), h - 0.04, 0.25)
    elif art == "nozzle":
        for i in range(5):
            t = (i + 1) / 6
            hh = (0.75 + 0.75 * t) / 3.0 * h
            L(w * t, h * 0.5 - hh * 0.96, w * t, h * 0.5 + hh * 0.96, 0.22)
    elif art == "aux":
        o.append(f'<polyline points="{w*0.05:.3f},{h*0.3:.3f} {w*0.6:.3f},{h*0.3:.3f} {w*0.95:.3f},{h*0.1:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.4" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        o.append(f'<polyline points="{w*0.05:.3f},{h*0.7:.3f} {w*0.6:.3f},{h*0.7:.3f} {w*0.95:.3f},{h*0.9:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.4" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    elif art == "fueltank":
        col = HAZ if piece.get("hazard", "") in ("fuel_tank",) else (AIR if piece.get("hazard", "") == "gas_tank" else EQ)
        o.append(f'<rect x="0.04" y="0.04" width="{w-0.08:.3f}" height="{h-0.08:.3f}" rx="{h*0.46:.3f}" fill="none" stroke="{col}" stroke-opacity="0.8" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        for i in range(3):
            L(w * (0.3 + i * 0.2), 0.06, w * (0.3 + i * 0.2), h - 0.06, 0.25)
        T(w * 0.32, h * 0.6, (piece.get("tag", "") + "  " + label).strip(), min(0.22, h * 0.2), 0.6)
    elif art == "guard":
        L(w * 0.5, 0.06, w * 0.45, h - 0.06, 0.3)
    elif art == "panel":
        pass
    elif art == "suit":
        o.append(f'<ellipse cx="{w*0.5:.3f}" cy="{h*0.09:.3f}" rx="{w*0.36:.3f}" ry="{h*0.08:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.7" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        o.append(f'<polyline points="{w*0.1:.3f},{h*0.22:.3f} {w*0.9:.3f},{h*0.22:.3f} {w*0.8:.3f},{h*0.62:.3f} {w*0.62:.3f},{h:.3f} {w*0.38:.3f},{h:.3f} {w*0.2:.3f},{h*0.62:.3f} {w*0.1:.3f},{h*0.22:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.6" stroke-width="1" vector-effect="non-scaling-stroke"/>')
        o.append(f'<rect x="{w*0.25:.3f}" y="{h*0.28:.3f}" width="{w*0.5:.3f}" height="{h*0.17:.3f}" fill="none" stroke="{AIR}" stroke-opacity="0.7" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    elif art == "locker":
        B(w * 0.08, h * 0.05, w * 0.84, h * 0.9, 0.45)
        L(w * 0.75, h * 0.35, w * 0.75, h * 0.55, 0.6, 1.4)
        for k in range(3):
            L(w * 0.15, h * (0.72 + k * 0.06), w * 0.6, h * (0.72 + k * 0.06), 0.3)
    elif art == "dock":
        L(w * 0.08, 0.02, w * 0.92, 0.02, 0.8, 1.6)
        B(w * 0.2, h * 0.25, w * 0.6, h * 0.55, 0.45)
    elif art == "sphere_tank":
        C(w * 0.5, h * 0.5, w * 0.36, 0.45)
        L(w * 0.14, h * 0.5, w * 0.86, h * 0.5, 0.3)
        T(w * 0.3, h * 0.42, label, w * 0.2)
    elif art == "arm":
        for x in (0.6, 2.4, 4.2, 6.0):
            L(x, h * 0.65, x, h * 0.95, 0.3)
        C(w * 0.02 + 0.2, h * 0.55, 0.18, 0.6)
        C(w - 0.6, h * 0.35, 0.22, 0.6)
    elif art == "rcs_quad":
        for dx in (0.2, 0.5, 0.8):
            L(w * dx, h * 0.2, w * dx, h * 0.8, 0.45)
    elif art == "brake":
        B(w * 0.1, h * 0.1, w * 0.8, h * 0.8, 0.5)
        T(w * 0.14, h * 0.62, "BRK", h * 0.3, 0.6)
    elif art == "engine_s":
        for i in range(5):
            L(w * (0.08 + i * 0.08), h * 0.3, w * (0.08 + i * 0.08), h * 0.7, 0.3)
        for i in range(3):
            t = 0.55 + i * 0.13
            L(w * t, h * (0.32 - i * 0.08), w * t, h * (0.68 + i * 0.08), 0.25)
    elif art == "grating":
        n = max(3, int(w / 0.12))
        for i in range(1, n):
            L(w * i / n, 0.02, w * i / n, h - 0.02, 0.25)
    elif art == "ladder":
        L(w * 0.15, 0, w * 0.15, h, 0.55)
        L(w * 0.85, 0, w * 0.85, h, 0.55)
        k = 0.2
        while k < h:
            L(w * 0.15, k, w * 0.85, k, 0.4)
            k += 0.3
    elif art == "glove":
        C(w * 0.5, h * 0.3, w * 0.32, 0.6)
        for gx in (0.32, 0.68):
            o.append(f'<path d="M{w*gx:.3f},{h*0.45:.3f} q{w*0.08:.3f},{h*0.25:.3f} 0,{h*0.45:.3f}" fill="none" stroke="{EQ}" stroke-opacity="0.5" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    elif art == "reel":
        C(w * 0.5, h * 0.5, min(w, h) * 0.38, 0.55)
        C(w * 0.5, h * 0.5, min(w, h) * 0.12, 0.45)


def render(ship_file, s, ox, oy, show_bolts=True):
    d = json.load(open(ship_file))
    g = SVG(s, ox, oy)
    o = g.o
    # rooms
    for r in d["rooms"]:
        o.append(f'<polygon points="{g.pts(r["poly"])}" fill="{ROOM}" stroke="#4a5568" stroke-width="1"/>')
        o.append(f'<polygon points="{g.pts(r["poly"])}" fill="url(#hatch)" stroke="none"/>')
    # dock clamps (the berth's arms, from below)
    for c in d.get("clamps", []):
        x, y = g.P(c[0], c[1])
        o.append(f'<polygon points="{x-0.45*s:.1f},{y+2.2*s:.1f} {x+0.45*s:.1f},{y+2.2*s:.1f} {x+0.22*s:.1f},{y+0.1*s:.1f} {x-0.22*s:.1f},{y+0.1*s:.1f}" fill="#222731" stroke="{FAINT}" stroke-width="1" stroke-dasharray="4 3"/>')
    pieces = d["pieces"]
    by_key = {p["key"]: p for p in pieces}
    # structure first, then fixtures and equipment on top
    order = sorted(pieces, key=lambda p: 0 if p["kind"] in STRUCT else 1)
    for p in order:
        kind = p["kind"]
        poly = p["poly"]
        if kind in STRUCT:
            fill = HULLF if kind not in ("door", "hatch") else "#2a3140"
            stroke = HULLS if kind not in ("door", "hatch") else AIR
            if p.get("art") == "window":
                fill = "#1b3550"
            o.append(f'<polygon points="{g.pts(poly)}" fill="{fill}" stroke="{stroke}" stroke-width="1.2" stroke-linejoin="round"/>')
            continue
        col = EQ
        if p.get("mandatory"):
            col = HEAT
        o.append(f'<polygon points="{g.pts(poly)}" fill="{EQF}" stroke="{col}" stroke-width="{1.4 if p.get("mandatory") else 1.1}" stroke-linejoin="round"/>')
        if p.get("art") and "art_xf" in p:
            a, b, c, dd, x0, y0 = p["art_xf"]
            w, h = p["art_size"]
            inner = []
            _art(inner, p["art"], w, h, p, 1.0)
            o.append(f'<g transform="translate({ox},{oy}) scale({s}) matrix({a} {b} {c} {dd} {x0} {y0})">' + ''.join(inner) + '</g>')
    # lines
    for l in d["lines"]:
        col = NET_COL.get(l["net"], DIM)
        dash = ' stroke-dasharray="5 3"' if l["kind"] == "cable" else ''
        o.append(f'<polyline points="{g.pts(l["path"])}" fill="none" stroke="{col}" stroke-width="{1.3 if l["kind"] == "cable" else 1.8}" stroke-opacity="0.85"{dash} stroke-linejoin="round"/>')
    # fixings: bolts pale, locks amber; welds left out (they would cover the drawing)
    if show_bolts:
        for j in d["joints"]:
            x, y = g.P(j["at"][0], j["at"][1])
            if j["type"] == "bolt":
                o.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{max(1.4, 0.06*s):.1f}" fill="#b4c0cf"/>')
            elif j["type"] == "lock":
                r = max(2.0, 0.08 * s)
                o.append(f'<rect x="{x-r:.1f}" y="{y-r:.1f}" width="{2*r:.1f}" height="{2*r:.1f}" fill="{HAZ}"/>')
            elif j["type"] == "clamp":
                o.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{max(2.5, 0.1*s):.1f}" fill="none" stroke="{HAZ}" stroke-width="1.5"/>')
    # controls
    for c in d["ctrls"]:
        x, y = g.P(c["at"][0], c["at"][1])
        kind = c["kind"]
        col = {"port": AIR if c.get("medium") == "gas" else (HAZ if c.get("medium") == "fuel" else FLUID), "switch": HEAT, "discharge": VIO, "test": HEAT, "stop": HEAT,
               "remote": HEAT, "valve": FLUID, "door": AIR, "hatch": AIR, "jam": HAZ, "socket": HEAT}.get(kind, EQ)
        r = max(2.2, 0.09 * s)
        if kind == "port":
            o.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{BG}" stroke="{col}" stroke-width="1.4"/>')
        elif kind == "door":
            continue
        else:
            o.append(f'<rect x="{x-r:.1f}" y="{y-r:.1f}" width="{2*r:.1f}" height="{2*r:.1f}" fill="{BG}" stroke="{col}" stroke-width="1.4"/>')
    return d, g


def where(d, tag):
    """centre of a piece by tag (or key), metres"""
    for p in d["pieces"]:
        if p.get("tag") == tag or p.get("key") == tag:
            xs = [q[0] for q in p["poly"]]
            ys = [q[1] for q in p["poly"]]
            return ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
    for c in d["ctrls"]:
        if c["id"] == tag:
            return tuple(c["at"])
    raise KeyError(tag)
