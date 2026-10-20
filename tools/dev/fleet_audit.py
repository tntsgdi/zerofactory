# Fleet audit (2026-10-19, user: "fill the interiors; big recoverable equipment must be
# cuttable or smaller, or the drone can't take it"): for each ship file, equipment that
# a 3 t grapple can't take whole and whose marked lines don't cut it into parts it can,
# and how densely its rooms are fitted (equipment per 100 m2 of room, lines per room).
# usage: python tools/dev/fleet_audit.py [ship ids...]
import json, math, sys, glob, os

GRAB = 3.0

def area(poly):
    a = 0.0
    for i in range(len(poly)):
        x0, y0 = poly[i]; x1, y1 = poly[(i + 1) % len(poly)]
        a += x0 * y1 - x1 * y0
    return abs(a) * 0.5

ids = sys.argv[1:] or [os.path.basename(f)[:-5] for f in sorted(glob.glob('ships/*.json'))]
print("%-7s %6s %6s %6s %7s %5s  heavy" % ("ship", "equip", "rooms", "m2", "eq/100", "lines"))
for sid in ids:
    try:
        d = json.load(open('ships/%s.json' % sid, encoding='utf-8'))
    except Exception:
        continue
    eq = [p for p in d['pieces'] if p.get('cls') == 'equip']
    ra = sum(area(r['poly']) for r in d.get('rooms', []))
    heavy = []
    for p in eq:
        m = float(p.get('mass', 0.0))
        parts = len(p.get('segments', [])) + 1
        if m / parts > GRAB + 1e-6:
            heavy.append("%s %.1ft/%d" % (p.get('tag', '?'), m, parts))
    dens = 100.0 * len(eq) / ra if ra > 0 else 0.0
    print("%-7s %6d %6d %6.0f %7.1f %5d  %s" % (sid, len(eq), len(d.get('rooms', [])), ra, dens, len(d.get('lines', [])), ", ".join(heavy)))
