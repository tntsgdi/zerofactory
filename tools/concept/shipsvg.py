# GR-7 sci-fi interior concept: drawn in metres (x bow->stern, y down), returned as SVG
CY = '#36e6ff'      # powered / emissive
CYD = '#1b8fa3'
HEAT = '#ff7a2a'
AMB = '#ffb43a'
FL = '#5dffa0'
GAS = '#79b4ff'
VIO = '#b07cff'
HULL = '#1b232e'
EDGE = '#4c6078'
LIT = '#8fb0d4'
DARK = '#0a0f16'
PART = '#222c39'
PARTE = '#5b7088'

out = []


def a(s):
    out.append(s)


def ln(x1, y1, x2, y2, c=EDGE, w=1.0, op=1.0, glow=False, dash=None):
    a(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{w}" opacity="{op}" vector-effect="non-scaling-stroke"'
      + (f' stroke-dasharray="{dash}"' if dash else '') + (' filter="url(#gm)"' if glow else '') + '/>')


def rect(x, y, w, h, fill=PART, stroke=PARTE, sw=1.0, rx=0.0, op=1.0, glow=False):
    a(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" vector-effect="non-scaling-stroke"' + (' filter="url(#gm)"' if glow else '') + '/>')


def poly(pts, fill=PART, stroke=PARTE, sw=1.0, op=1.0, glow=False):
    p = ' '.join(f'{x},{y}' for x, y in pts)
    a(f'<polygon points="{p}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" vector-effect="non-scaling-stroke"' + (' filter="url(#gm)"' if glow else '') + '/>')


def pline(pts, c=EDGE, w=1.0, op=1.0, glow=False, dash=None):
    p = ' '.join(f'{x},{y}' for x, y in pts)
    a(f'<polyline points="{p}" fill="none" stroke="{c}" stroke-width="{w}" opacity="{op}" stroke-linejoin="round" vector-effect="non-scaling-stroke"'
      + (f' stroke-dasharray="{dash}"' if dash else '') + (' filter="url(#gm)"' if glow else '') + '/>')


def circ(x, y, r, fill='none', stroke=EDGE, sw=1.0, op=1.0, glow=False):
    a(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" vector-effect="non-scaling-stroke"' + (' filter="url(#gm)"' if glow else '') + '/>')


def ell(x, y, rx, ry, fill='none', stroke=EDGE, sw=1.0, op=1.0, glow=False):
    a(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" vector-effect="non-scaling-stroke"' + (' filter="url(#gm)"' if glow else '') + '/>')


def bolt(x, y):
    circ(x, y, 0.045, fill='#9fb4cc', stroke='none')


def led(x, y, c=CY, r=0.035):
    circ(x, y, r * 2.2, fill=c, stroke='none', op=0.35, glow=True)
    circ(x, y, r, fill=c, stroke='none')


DEFS = '''
<filter id="gm" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="0.06" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="gb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="0.25"/></filter>
<filter id="gp" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<linearGradient id="hull" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a3442"/><stop offset="0.5" stop-color="#1a212b"/><stop offset="1" stop-color="#11161d"/></linearGradient>
<linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7fe9ff" stop-opacity="0.55"/><stop offset="1" stop-color="#0b3a52" stop-opacity="0.35"/></linearGradient>
<linearGradient id="holo" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#36e6ff" stop-opacity="0.55"/><stop offset="1" stop-color="#36e6ff" stop-opacity="0.02"/></linearGradient>
<radialGradient id="air" cx="0.5" cy="0.4" r="0.8"><stop offset="0" stop-color="#16324a" stop-opacity="0.55"/><stop offset="1" stop-color="#0a0f16" stop-opacity="0"/></radialGradient>
<linearGradient id="seat" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#2e3a4a"/><stop offset="1" stop-color="#1c2430"/></linearGradient>
<radialGradient id="core" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#9ff6ff"/><stop offset="1" stop-color="#36e6ff" stop-opacity="0"/></radialGradient>
<radialGradient id="plume" cx="0" cy="0.5" r="1"><stop offset="0" stop-color="#d9b8ff" stop-opacity="0.9"/><stop offset="1" stop-color="#7a3cff" stop-opacity="0"/></radialGradient>
<pattern id="grid" width="0.5" height="0.5" patternUnits="userSpaceOnUse"><path d="M0.5 0 L0 0 0 0.5" fill="none" stroke="#132231" stroke-width="0.02"/></pattern>
<pattern id="hex" width="1.2" height="0.693" patternUnits="userSpaceOnUse"><path d="M0.2 0 L0.6 0 L0.8 0.346 L0.6 0.693 L0.2 0.693 L0 0.346 Z" fill="none" stroke="#36e6ff" stroke-width="0.03" opacity="0.5"/></pattern>
'''

ROOMS = {
    'A': [(4.85, 3.55), (4.66, 3.55), (2.60, 2.99), (1.18, 1.92), (0.68, 0.50), (1.30, -1.37), (2.66, -2.91), (4.67, -3.55), (4.85, -3.55)],
    'B': [(5.15, -3.55), (9.85, -3.55), (9.85, 2.95), (5.15, 2.95)],
    'C': [(10.15, -3.55), (26.85, -3.55), (26.85, 2.95), (10.15, 2.95)],
    'D': [(27.15, -3.55), (32.55, -3.55), (32.55, -0.15), (27.15, -0.15)],
    'E': [(27.15, 0.15), (32.55, 0.15), (32.55, 2.95), (27.15, 2.95)],
}
OUTER = [(4.7, -4.05), (33.0, -4.05), (33.0, 4.05), (4.7, 4.05), (2.45, 3.55), (0.85, 2.45), (0.15, 0.55), (0.15, -0.25), (0.85, -2.2), (2.45, -3.45)]

FLOOR = 2.95


def seat(x, yf, name_led=CY):
    # a crash couch on a floor rail, facing the bow (-x)
    rect(x - 0.55, yf - 0.1, 1.1, 0.1, fill='#1a222c', stroke=PARTE)
    for bx in (x - 0.45, x + 0.45):
        bolt(bx, yf - 0.05)
    rect(x - 0.09, yf - 0.62, 0.18, 0.52, fill='#151b23', stroke=PARTE)          # pedestal
    ln(x - 0.09, yf - 0.4, x + 0.09, yf - 0.4, LIT, 0.8, 0.5)
    poly([(x - 0.55, yf - 0.62), (x + 0.42, yf - 0.66), (x + 0.48, yf - 0.82), (x - 0.5, yf - 0.8)], fill='url(#seat)', stroke=PARTE)  # pan
    poly([(x + 0.32, yf - 0.8), (x + 0.5, yf - 0.8), (x + 0.92, yf - 2.05), (x + 0.72, yf - 2.1)], fill='url(#seat)', stroke=PARTE)    # back
    poly([(x + 0.72, yf - 2.1), (x + 0.95, yf - 2.05), (x + 1.02, yf - 2.42), (x + 0.8, yf - 2.47)], fill='#2b3646', stroke=PARTE)     # headrest
    ln(x + 0.36, yf - 0.84, x + 0.76, yf - 2.02, CY, 1.2, 0.8, glow=True)          # cyan piping
    pline([(x - 0.35, yf - 0.82), (x + 0.1, yf - 1.05), (x + 0.1, yf - 1.12)], '#2f3b4c', 3.0)   # armrest
    ln(x - 0.25, yf - 1.12, x - 0.22, yf - 1.35, LIT, 1.4)                         # side stick
    led(x - 0.22, yf - 1.37, AMB, 0.03)
    pline([(x + 0.78, yf - 1.95), (x + 0.2, yf - 1.2), (x - 0.1, yf - 0.85)], AMB, 1.2, 0.8)   # harness
    pline([(x + 0.9, yf - 2.3), (x + 0.55, yf - 1.6)], AMB, 1.2, 0.6)


def holo_console(x0, x1, yf):
    poly([(x0, yf), (x1, yf), (x1, yf - 0.85), (x0 + 0.25, yf - 1.2), (x0, yf - 1.2)], fill='#1d2632', stroke=PARTE)
    rect(x0 + 0.08, yf - 1.12, 0.55, 0.32, fill='#06283a', stroke=CYD, glow=True)
    for i in range(4):
        ln(x0 + 0.13, yf - 1.05 + i * 0.07, x0 + 0.13 + 0.15 + (i % 3) * 0.1, yf - 1.05 + i * 0.07, CY, 0.8, 0.8)
    for i in range(5):
        led(x0 + 0.15 + i * 0.16, yf - 0.62, [CY, CY, AMB, CY, FL][i], 0.025)
    em = ((x0 + x1) / 2 + 0.1, yf - 1.2)
    poly([(em[0] - 0.08, em[1]), (em[0] + 0.08, em[1]), (em[0] + 0.75, em[1] - 1.5), (em[0] - 0.75, em[1] - 1.5)], fill='url(#holo)', stroke='none', op=0.8)
    # a wireframe of the ship turning in the projection
    cx, cy = em[0], em[1] - 1.05
    pline([(cx - 0.55, cy), (cx - 0.35, cy - 0.15), (cx + 0.45, cy - 0.15), (cx + 0.55, cy), (cx + 0.45, cy + 0.15), (cx - 0.35, cy + 0.15), (cx - 0.55, cy)], CY, 1.0, 0.9, glow=True)
    ln(cx - 0.1, cy - 0.15, cx - 0.1, cy + 0.15, CY, 0.7, 0.6)
    ln(cx + 0.2, cy - 0.15, cx + 0.2, cy + 0.15, CY, 0.7, 0.6)
    ell(em[0], em[1], 0.12, 0.04, fill=CY, stroke='none', glow=True)


def capsule(x, y, w, h, label=''):
    rect(x, y, w, h, fill='#18202a', stroke=PARTE, rx=h * 0.45)
    rect(x + 0.25, y + h * 0.18, w * 0.42, h * 0.32, fill='url(#glass)', stroke=CYD, rx=0.08)
    rect(x + 0.15, y + h * 0.62, w - 0.3, h * 0.16, fill='#2b3646', stroke='none', rx=0.06)   # mattress
    ln(x + 0.2, y + h - 0.06, x + w - 0.2, y + h - 0.06, GAS, 1.4, 0.8, glow=True)              # pod light
    led(x + w - 0.25, y + 0.15, FL, 0.03)
    for bx in (x + 0.3, x + w - 0.3):
        bolt(bx, y + h + 0.05)


def lockers(x, y, w, h, n):
    cw = w / n
    for i in range(n):
        rect(x + i * cw, y, cw - 0.03, h, fill='#1c2530', stroke=PARTE)
        ln(x + i * cw + cw - 0.12, y + h * 0.4, x + i * cw + cw - 0.12, y + h * 0.6, LIT, 1.4)
        led(x + i * cw + 0.1, y + 0.1, [CY, AMB, CY][i % 3], 0.022)
        for k in range(3):
            ln(x + i * cw + 0.06, y + h * 0.75 + k * 0.05, x + i * cw + cw - 0.1, y + h * 0.75 + k * 0.05, EDGE, 0.6, 0.6)


def galley(x, y, w, h):
    rect(x, y, w, h, fill='#1c2530', stroke=PARTE)
    rect(x + 0.1, y + 0.12, w * 0.5, h * 0.3, fill='#06283a', stroke=CYD, glow=True)
    for i in range(3):
        ln(x + 0.15, y + 0.2 + i * 0.07, x + 0.15 + w * 0.3, y + 0.2 + i * 0.07, CY, 0.8, 0.8)
    rect(x + w * 0.62, y + 0.15, w * 0.28, h * 0.5, fill='#0e141b', stroke=PARTE)      # print bay
    ell(x + w * 0.76, y + h * 0.45, 0.1, 0.03, fill=AMB, stroke='none', glow=True)
    ln(x + w * 0.76, y + 0.18, x + w * 0.76, y + 0.3, LIT, 1.2)
    rect(x + 0.05, y + h * 0.72, w - 0.1, 0.06, fill=EDGE, stroke='none')
    pline([(x + w, y + h * 0.3), (x + w + 0.12, y + h * 0.3), (x + w + 0.12, y - 0.6)], FL, 1.4, 0.7)  # water line


def tank(x, y, w, h, lab):
    rect(x, y, w, h, fill='#18212c', stroke=GAS, rx=w * 0.45, op=1)
    for k in (0.25, 0.75):
        ln(x, y + h * k, x + w, y + h * k, EDGE, 1.0)
    rect(x + w * 0.3, y + h * 0.35, w * 0.4, h * 0.3, fill='none', stroke=GAS, op=0.6)
    a(f'<text x="{x + w / 2}" y="{y + h * 0.56}" font-size="0.22" fill="{GAS}" text-anchor="middle" font-family="N">{lab}</text>')
    ln(x + w / 2, y, x + w / 2, y - 0.25, LIT, 1.2)


def env(x, y, w, h):
    rect(x, y, w, h, fill='#1c2530', stroke=PARTE)
    circ(x + h / 2, y + h / 2, h * 0.36, fill='#0f151c', stroke=GAS)
    for k in range(4):
        import math
        an = k * math.pi / 2 + 0.4
        ln(x + h / 2, y + h / 2, x + h / 2 + math.cos(an) * h * 0.3, y + h / 2 + math.sin(an) * h * 0.3, GAS, 1.2, 0.8)
    for k in range(4):
        ln(x + h + 0.05, y + 0.25 + k * 0.2, x + w - 0.1, y + 0.25 + k * 0.2, EDGE, 0.8)
    led(x + w - 0.15, y + 0.12, FL, 0.03)


def container(x, y, w, h, lab, stripe):
    rect(x, y, w, h, fill='#1a222d', stroke=PARTE)
    for k in range(1, 9):
        ln(x + w * k / 9, y + 0.1, x + w * k / 9, y + h - 0.1, '#2d3a4a', 1.0)
    rect(x, y + 0.08, w, 0.12, fill=stripe, stroke='none', op=0.85)
    a(f'<text x="{x + 0.15}" y="{y + 0.55}" font-size="0.3" fill="#c9d6e6" font-family="N" font-weight="600">{lab}</text>')
    # maglev cradle
    rect(x - 0.1, y + h, w + 0.2, 0.12, fill='#141b23', stroke=PARTE)
    ln(x, y + h + 0.13, x + w, y + h + 0.13, CY, 1.6, 0.9, glow=True)
    # magnetic cargo locks at both ends
    for lx in (x - 0.18, x + w + 0.02):
        rect(lx, y + h - 0.45, 0.16, 0.45, fill='#2a3546', stroke=PARTE)
        led(lx + 0.08, y + h - 0.35, AMB, 0.025)


def reactor(x, y, w, h):
    rect(x, y, w, h, fill='#151c25', stroke=PARTE, rx=h * 0.3)
    ell(x + w / 2, y + h / 2, w * 0.28, h * 0.28, fill='url(#core)', stroke='none')
    for k, rx in enumerate((0.22, 0.5, 0.78)):
        ell(x + w * rx, y + h / 2, 0.12, h * 0.52, fill='none', stroke=CY, sw=2.0, glow=True)
    ln(x + 0.1, y + h + 0.02, x + w - 0.1, y + h + 0.02, EDGE, 2)
    a(f'<text x="{x + 0.1}" y="{y - 0.12}" font-size="0.22" fill="{CY}" font-family="N">G-01 · 紧凑聚变堆</text>')


def battery(x, y, w, h):
    rect(x, y, w, h, fill='#1a222c', stroke=PARTE)
    n = 4
    for i in range(n):
        cx = x + 0.08 + i * (w - 0.16) / n
        rect(cx, y + 0.12, (w - 0.16) / n - 0.05, h - 0.24, fill='#0f151c', stroke=EDGE)
        rect(cx + 0.03, y + h - 0.15 - (h - 0.35) * (0.4 + 0.15 * i), (w - 0.16) / n - 0.11, (h - 0.35) * (0.4 + 0.15 * i), fill=FL, stroke='none', op=0.7)


def capbank(x, y, w, h):
    rect(x, y, w, h, fill='#1a222c', stroke=PARTE)
    for i in range(5):
        ell(x + w / 2, y + 0.15 + i * (h - 0.3) / 4, w * 0.35, 0.05, fill='none', stroke=VIO, sw=1.5, glow=True)


def switchboard(x, y, w, h):
    rect(x, y, w, h, fill='#1a222c', stroke=PARTE)
    for r in range(6):
        for c in range(3):
            led(x + 0.12 + c * (w - 0.24) / 2, y + 0.2 + r * (h - 0.4) / 5, [CY, CY, AMB, CY, FL, CY][(r + c) % 6], 0.025)


def pump(x, y, w, h):
    rect(x, y, w, h, fill='#1a222c', stroke=PARTE)
    circ(x + w / 2, y + h / 2, h * 0.32, fill='#0f151c', stroke=FL, sw=1.4, glow=True)
    circ(x + w / 2, y + h / 2, h * 0.1, fill=FL, stroke='none')


def radiator(x, y, w, h, c=HEAT):
    rect(x, y, w, h, fill='#1a222c', stroke=PARTE)
    k = 0
    xx = x + 0.08
    while xx < x + w - 0.05:
        ln(xx, y + 0.08, xx, y + h - 0.08, c, 1.2, 0.55)
        xx += 0.12
        k += 1


def rcs(x, y, up):
    s = -1 if up else 1
    rect(x - 0.35, y if not up else y - 0.3, 0.7, 0.3, fill='#202a36', stroke=PARTE)
    for dx in (-0.22, 0.22):
        poly([(x + dx - 0.07, y + s * 0.3), (x + dx + 0.07, y + s * 0.3), (x + dx + 0.12, y + s * 0.48), (x + dx - 0.12, y + s * 0.48)], fill='#2a3442', stroke=PARTE)
    led(x, y + s * 0.15, '#ff4444', 0.03)


def extinguisher(x, yb):
    rect(x - 0.09, yb - 0.55, 0.18, 0.55, fill='#7a1f1f', stroke='#c84a4a', rx=0.08)
    ln(x, yb - 0.55, x, yb - 0.65, LIT, 1.2)
    ln(x, yb - 0.62, x + 0.14, yb - 0.6, LIT, 1.0)
    rect(x - 0.13, yb - 0.4, 0.26, 0.05, fill=EDGE, stroke='none')


def handrail(x0, x1, y):
    ln(x0, y, x1, y, '#6f86a3', 1.6)
    xx = x0 + 0.2
    while xx < x1:
        ln(xx, y, xx, y - 0.18, '#6f86a3', 1.2)
        xx += 0.9


def crate(x, y, w, h, c):
    rect(x, y, w, h, fill='#1d2531', stroke=PARTE)
    ln(x, y, x + w, y + h, '#2d3a4a', 0.8)
    ln(x + w, y, x, y + h, '#2d3a4a', 0.8)
    rect(x + 0.05, y + 0.05, w * 0.35, 0.08, fill=c, stroke='none', op=0.8)


def quilt(x0, y0, x1, y1):
    # insulation blankets on the hold's back wall
    x = x0
    while x < x1 - 0.1:
        rect(x + 0.03, y0, min(1.3, x1 - x) - 0.06, y1 - y0, fill='#101822', stroke='#1b2836', sw=0.8)
        yy = y0 + 0.35
        while yy < y1:
            ln(x + 0.1, yy, x + min(1.3, x1 - x) - 0.1, yy, '#1b2836', 0.6)
            yy += 0.35
        x += 1.3


def draw_ship(full=True):
    global out
    out = []
    # exterior: hull with panel seams, running strips
    poly(OUTER, fill='url(#hull)', stroke=LIT, sw=1.6)
    # interior cut-outs
    for k, r in ROOMS.items():
        poly(r, fill=DARK, stroke='#3b4a5c', sw=1.0)
        poly(r, fill='url(#grid)', stroke='none')
        poly(r, fill='url(#air)', stroke='none')
    # hull panel seams (angled, like the game's plates)
    xs = [4.6, 7.8, 10.0, 12.7, 15.4, 18.4, 21.4, 24.2, 27.0, 30.0]
    for x in xs:
        ln(x, -4.05, x + 0.15, -3.55, '#0b0f14', 1.4)
        ln(x, 3.55, x + 0.15, 4.05, '#0b0f14', 1.4)
    # emissive strips along the hull: lit while the ship has power
    ln(4.9, -3.82, 32.6, -3.82, CY, 1.6, 0.85, glow=True, dash='0.9 0.25')
    ln(4.9, 3.82, 32.6, 3.82, CY, 1.6, 0.85, glow=True, dash='0.9 0.25')
    # bulkhead frames with lightening holes
    for fx in (14.55, 18.85, 23.2):
        rect(fx - 0.12, -3.2, 0.24, 6.15, fill='#1d2632', stroke=PARTE)
        for fy in (-2.4, -0.8, 0.8):
            circ(fx, fy, 0.07, fill=DARK, stroke=EDGE, sw=0.8)
    # cable trays along the ceiling with power pulses
    pline([(5.2, -3.3), (26.8, -3.3)], '#2a3646', 3.0)
    ln(5.2, -3.3, 26.8, -3.3, CY, 1.0, 0.7, glow=True, dash='0.08 0.6')
    pline([(27.2, -3.3), (32.5, -3.3)], '#2a3646', 3.0)
    ln(27.2, -3.3, 32.5, -3.3, CY, 1.0, 0.7, glow=True, dash='0.08 0.6')
    # bulkheads with doors (DR-AB, DR-BC, DR-CD/CE): lit door frames
    for dx in (5.0, 10.0):
        rect(dx - 0.15, -3.55, 0.3, 4.35, fill='#1d2632', stroke=PARTE)
        rect(dx - 0.1, 0.8, 0.2, 2.15, fill='#11171e', stroke=CYD)
        led(dx, 0.62, FL, 0.03)
    rect(26.85, -3.55, 0.3, 6.5, fill='#1d2632', stroke=PARTE)
    rect(27.15, -0.15, 5.4, 0.3, fill='#1d2632', stroke=PARTE)
    for dy in (-2.6, 0.7):
        rect(26.9, dy, 0.2, 2.0, fill='#11171e', stroke=CYD)
    # ---- A: cockpit
    poly([(0.95, -3.25), (2.7, -3.25), (2.7, -1.45), (0.95, -1.45)], fill='url(#glass)', stroke=CY, sw=1.2)
    ln(1.1, -2.9, 2.5, -2.9, CY, 0.6, 0.5)
    ln(1.1, -2.5, 2.2, -2.5, CY, 0.6, 0.35)
    holo_console(1.2, 2.45, FLOOR - 0.15)
    a('<g opacity="0.45">')
    seat(3.4, FLOOR)
    a('</g>')
    seat(3.0, FLOOR)
    handrail(1.6, 4.5, -2.75)
    extinguisher(4.3, 2.4)
    rect(2.6, -3.35, 1.9, 0.38, fill='#1c2530', stroke=PARTE)      # overhead panel
    for i in range(8):
        led(2.75 + i * 0.22, -3.16, [CY, CY, AMB, CY, FL, CY, CY, '#ff4444'][i], 0.025)
    rect(4.05, -2.55, 0.6, 0.85, fill='#2a1d14', stroke=AMB)       # emergency O2
    a(f'<text x="4.35" y="-2.05" font-size="0.18" fill="{AMB}" text-anchor="middle" font-family="N">O₂</text>')
    rect(4.1, -1.35, 0.55, 1.3, fill='#1c2530', stroke=PARTE)       # nav rack
    for i in range(5):
        ln(4.15, -1.2 + i * 0.25, 4.6, -1.2 + i * 0.25, EDGE, 0.8)
        led(4.55, -1.1 + i * 0.25, CY, 0.022)
    rect(3.95, 2.62, 0.6, 0.33, fill='#3a2412', stroke=HEAT)         # black box under its floor cover
    # ---- B: crew deck
    handrail(5.3, 9.7, -1.95)
    extinguisher(9.55, 1.55)
    extinguisher(26.5, 2.85)
    extinguisher(32.3, 0.95)
    capsule(5.35, -3.15, 2.1, 0.95)
    capsule(7.6, -3.15, 2.1, 0.95)
    lockers(5.3, -1.7, 1.2, 2.25, 3)
    galley(8.35, -1.7, 1.35, 1.55)
    tank(5.5, 1.1, 0.7, 1.85, 'O₂')
    tank(6.45, 1.1, 0.7, 1.85, 'N₂')
    env(7.6, 1.7, 1.95, 1.25)
    pline([(7.9, 1.7), (7.9, 0.95), (9.75, 0.95)], GAS, 2.0, 0.6)
    # ---- C: the hold
    for qx0, qx1 in ((10.3, 14.4), (14.7, 18.7), (19.0, 23.05), (23.35, 26.8)):
        quilt(qx0, -3.15, qx1, 2.9)
    for tx in (11.4, 13.4, 16.0, 18.0, 19.8, 21.4, 22.6, 24.0, 25.6):
        circ(tx, 2.88, 0.06, fill='none', stroke=LIT, sw=1.0)         # tie-down rings
    # a ladder up the middle frame to the crane rail
    for ly in [ -2.9 + k * 0.4 for k in range(15)]:
        ln(18.55, ly, 18.75, ly, '#6f86a3', 1.0)
    ln(18.55, -3.0, 18.55, 2.9, '#6f86a3', 1.0)
    # a pallet of small crates under the cargo terminal
    rect(22.4, 2.78, 3.3, 0.17, fill='#2a2218', stroke=AMB, sw=0.8)
    for i in range(3):
        crate(22.5 + i * 1.05, 2.15, 1.0, 0.62, '#5a7aa0' if i != 1 else FL)
        if i < 2:
            crate(22.95 + i * 1.05, 1.5, 1.0, 0.62, AMB)
    pline([(22.45, 1.45), (23.5, 0.95), (24.6, 0.95), (25.65, 1.45)], AMB, 1.0, 0.6, dash='0.12 0.08')   # strap net
    rect(10.2, -3.5, 16.65, 0.28, fill='#1d2632', stroke=CYD)          # crane rail
    ln(10.3, -3.36, 26.7, -3.36, CY, 1.4, 0.8, glow=True, dash='0.5 0.3')
    rect(16.3, -3.22, 1.5, 0.55, fill='#26313f', stroke=PARTE)          # crane trolley
    led(16.45, -3.05, AMB, 0.03)
    led(17.65, -3.05, AMB, 0.03)
    ln(17.05, -2.67, 17.05, -1.6, LIT, 1.2)
    pline([(16.85, -1.6), (16.85, -1.35), (17.05, -1.2), (17.25, -1.35), (17.25, -1.6)], LIT, 1.6)
    for hx in (12.2, 20.5):                                             # parked hooks
        ln(hx, -3.22, hx, -2.7, EDGE, 1.2)
        pline([(hx - 0.15, -2.7), (hx - 0.15, -2.55), (hx, -2.45), (hx + 0.15, -2.55)], EDGE, 1.4)
    container(11.0, 0.65, 2.8, 2.15, 'C-01', '#5a7aa0')
    container(15.6, 0.65, 2.8, 2.15, 'C-02', AMB)
    container(19.4, 0.95, 2.4, 1.85, 'C-03', VIO)
    rect(25.3, -1.3, 1.2, 1.5, fill='#1c2530', stroke=PARTE)           # cargo terminal
    rect(25.38, -1.2, 1.04, 0.7, fill='#06283a', stroke=CYD, glow=True)
    for i in range(4):
        ln(25.45, -1.1 + i * 0.13, 25.45 + 0.3 + (i % 2) * 0.4, -1.1 + i * 0.13, CY, 0.8, 0.8)
    # top hatches: a force-field seal across the opening
    rect(15.3, -4.05, 6.1, 0.5, fill='#1f2834', stroke=LIT)
    ln(15.4, -3.8, 21.3, -3.8, CY, 2.0, 0.6, glow=True)
    # ---- D: the power room
    reactor(27.45, -2.55, 2.4, 1.7)
    battery(30.05, -1.05, 1.0, 0.85)
    capbank(31.15, -1.4, 0.55, 1.2)
    switchboard(31.85, -2.95, 0.6, 2.0)
    # ---- E: coolant & machine bay
    pump(27.4, 1.95, 1.0, 1.0)
    pline([(28.4, 2.3), (28.7, 2.3), (28.7, 0.6), (30.3, 0.6), (30.3, 1.7)], FL, 2.0, 0.85, glow=True)
    rect(28.8, 1.6, 1.0, 1.35, fill='#1c2530', stroke=PARTE)
    radiator(30.5, 1.7, 1.8, 1.25, FL)
    rect(31.6, 0.2, 0.6, 0.45, fill='#1c2530', stroke=CYD)
    # ---- exterior fittings
    rcs(5.6, -4.05, True)
    rcs(5.6, 4.05, False)
    rcs(31.6, -4.05, True)
    rcs(31.6, 4.05, False)
    poly([(3.1, -4.0), (3.25, -4.45), (3.85, -4.45), (4.0, -4.0)], fill='#202a36', stroke=PARTE)   # sensor dome base
    a(f'<path d="M3.2 -4.45 A0.35 0.35 0 0 1 3.9 -4.45 Z" fill="url(#glass)" stroke="{CY}" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    ln(24.6, -4.05, 24.6, -5.0, LIT, 1.6)                                # comms mast
    a(f'<path d="M24.1 -5.2 Q24.6 -4.7 25.1 -5.2" fill="none" stroke="{LIT}" stroke-width="1.6" vector-effect="non-scaling-stroke"/>')
    led(24.6, -5.05, '#ff4444', 0.035)
    for rx in (28.0, 29.6):                                               # radiator fins
        poly([(rx, -4.05), (rx + 0.25, -5.4), (rx + 1.2, -5.4), (rx + 1.45, -4.05)], fill='#1a222c', stroke=PARTE)
        for k in range(5):
            ln(rx + 0.35 + k * 0.2, -5.3, rx + 0.3 + k * 0.22, -4.15, HEAT, 1.0, 0.45)
    led(0.35, -0.6, '#ff4444', 0.05)                                     # running lights
    led(0.35, 0.9, '#3dff7a', 0.05)
    # ---- F: propulsion on its open frame
    rect(33.0, -3.3, 7.6, 0.4, fill='#1d2632', stroke=PARTE)
    rect(33.0, 2.9, 7.6, 0.4, fill='#1d2632', stroke=PARTE)
    x = 33.4
    while x < 40.4:
        ln(x, -2.9, x + 0.6, -2.4, EDGE, 0.8, 0.6)
        ln(x, 2.9, x + 0.6, 2.4, EDGE, 0.8, 0.6)
        x += 1.2
    rect(34.0, -2.8, 3.2, 1.3, fill='#18202a', stroke=AMB, rx=0.6)        # propellant tank
    a(f'<text x="35.6" y="-2.05" font-size="0.22" fill="{AMB}" text-anchor="middle" font-family="N">T-F01 推进剂</text>')
    rect(33.0, -1.1, 1.8, 2.2, fill='#1c2530', stroke=PARTE)               # engine front
    rect(34.8, -0.9, 3.2, 1.8, fill='#18202a', stroke=PARTE)               # engine core
    for k in range(5):
        ell(35.2 + k * 0.6, 0.0, 0.08, 0.95, fill='none', stroke=VIO, sw=2.0, glow=True)
    poly([(38.0, -0.75), (38.0, 0.75), (40.4, 1.55), (40.4, -1.55)], fill='#1a222c', stroke=PARTE)   # magnetic nozzle
    for k in range(3):
        xk = 38.5 + k * 0.7
        hk = 0.85 + k * 0.28
        ln(xk, -hk, xk, hk, VIO, 1.6, 0.8, glow=True)
    ell(40.6, 0.0, 1.4, 1.2, fill='url(#plume)', stroke='none', op=0.55)
    return '\n'.join(out)
