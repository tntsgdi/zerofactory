# S-09 "Swift" maintenance shuttle: side cutaway in the game's minimal style.
# python3 make_s09.py && node shot.js s09.html ../../design/S-09_结构图.png 1600 960
import sys
sys.path.insert(0, '.')
from mini import *

W, H = 1600, 960
p = Pen(150, 440, 50)

# ---------------- forked tail booms (behind everything): radiators + RCS at the tips
for sgn in (-1, 1):
    p.poly([(20.6, 0.9 * sgn), (21.6, 0.9 * sgn), (26.0, 4.1 * sgn), (25.0, 4.45 * sgn)], fill=HULLF, stroke=HULLS)
    # radiator fins along the boom
    for k in range(6):
        t = 0.15 + k * 0.13
        bx, by = 21.1 + t * 4.4, (0.9 + t * 3.4) * sgn
        p.line(bx, by, bx - 0.55, by + 0.75 * sgn, HEAT, 1.1, 0.7)
    p.rect(25.0, 4.1 * sgn - (0.45 if sgn > 0 else 0.0) + (0.0 if sgn > 0 else -0.1), 1.0, 0.55, fill=EQF, stroke=EQ)

# ---------------- the spine: an open lattice, nothing pressurised
p.truss(9.4, 21.6, -1.0, 1.0, 1.525)
# equipment bolted into the truss bays (each on a pallet: 4 bolts)
p.rect(11.0, -0.75, 2.6, 1.5, rx=0.1)                                   # fuel cell
for k in range(5):
    p.line(11.2 + k * 0.5, -0.6, 11.2 + k * 0.5, 0.6, FAINT, 1)
p.ell(15.0, 0.0, 1.25, 0.65, fill=EQF, stroke=HAZ, sw=1.4)              # H2 tank
p.ell(17.8, 0.0, 0.85, 0.6, fill=EQF, stroke=AIR, sw=1.4)               # O2 tank
p.rect(19.1, -0.7, 1.0, 1.4, fill=EQF, stroke=VIO, sw=1.3)              # capacitor bank
for k in range(4):
    p.line(19.2, -0.45 + k * 0.3, 20.0, -0.45 + k * 0.3, VIO, 1, 0.8)
# gas lines to the fuel cell, power trunk on the lower chord
p.pline([(13.75, -0.3), (13.6, -0.3)], HAZ, 2)
p.pline([(16.95, 0.3), (16.6, 0.85), (13.0, 0.85), (13.0, 0.75)], AIR, 1.6)
p.pline([(13.75, 0.0), (13.6, 0.0)], HAZ, 2)
p.line(10.4, 1.15, 21.4, 1.15, HEAT, 1.4, 0.8, dash='6 3')

# ---------------- dorsal arm rail and the folded manipulator arm
p.rect(9.4, -1.45, 11.4, 0.25, fill=HULLF, stroke=HULLS)
for lx in (11.0, 13.6, 16.2, 18.8):                                     # launch locks
    p.rect(lx - 0.18, -1.7, 0.36, 0.3, fill=EQF, stroke=HAZ, sw=1.2)
p.rect(19.4, -2.2, 1.0, 0.75, fill=EQF, stroke=EQ)                      # shoulder + brake
p.rect(20.45, -2.05, 0.45, 0.45, fill=EQF, stroke=HEAT, sw=1.2)         # brake supply
p.pline([(19.9, -2.0), (12.6, -2.35)], EQ, 7)                           # upper boom
p.pline([(19.9, -2.0), (12.6, -2.35)], EQF, 4)
p.circ(12.6, -2.35, 0.32)
p.pline([(12.6, -2.35), (16.8, -2.95)], EQ, 6)                          # forearm
p.pline([(12.6, -2.35), (16.8, -2.95)], EQF, 3)
p.pline([(16.8, -2.95), (17.5, -2.75), (17.4, -3.2)], EQ, 2)            # end effector
p.pline([(16.8, -2.95), (17.5, -3.15)], EQ, 2)

# ---------------- crew sphere: a two-deck pressure ball, then a narrow airlock neck
p.poly([(5.6, -1.45), (9.4, -1.45), (9.4, 1.45), (5.6, 1.45)], fill=HULLF, stroke=HULLS, w=1.6)      # airlock neck
p.room([(6.0, -1.2), (9.2, -1.2), (9.2, 1.2), (6.0, 1.2)])
sph = p.arc_pts(3.2, 0, 3.15, 3.15, 0, 360, 64)
p.poly(sph, fill=HULLF, stroke=HULLS, w=1.6)
p.room(p.arc_pts(3.2, 0, 2.9, 2.9, 0, 360, 64))
for rr in (2.9,):
    pass
# ring frames (latitude lines of the ball)
for fx in (1.0, 3.2, 5.4):
    hy = (2.9 ** 2 - (fx - 3.2) ** 2) ** 0.5
    p.line(fx, -hy, fx, -hy + 0.22, HULLS, 2)
    p.line(fx, hy, fx, hy - 0.22, HULLS, 2)
# bubble window over the upper deck
p.pline(p.arc_pts(3.2, 0, 3.15, 3.15, 195, 250, 16), AIR, 4, 0.9)
# the deck splits the ball: flight deck above, cabin below; a ladder hatch between
p.line(0.45, 0.35, 5.95, 0.35, HULLS, 1.8)
p.rect(3.0, 0.27, 0.6, 0.16, fill='#2a3140', stroke=EQ, sw=1)
for k in range(5):
    p.line(3.1, 0.55 + k * 0.38, 3.5, 0.55 + k * 0.38, DIM, 1.2)
p.line(3.1, 0.43, 3.1, 2.3, DIM, 1.2)
p.line(3.5, 0.43, 3.5, 2.3, DIM, 1.2)
# lower deck floor and the run under it
p.line(1.0, 2.3, 5.4, 2.3, HULLS, 1.6)
p.line(1.4, 2.55, 5.0, 2.55, HEAT, 1.2, 0.7, dash='5 3')
# --- flight deck: console at the window, two seats in tandem, overhead panel
p.poly([(0.6, 0.35), (1.6, 0.35), (1.6, -0.45), (0.95, -0.75), (0.55, -0.4)], fill=EQF, stroke=EQ)
p.rect(0.75, -0.6, 0.55, 0.3, fill='#10233a', stroke=AIR, sw=1)
p.rect(2.2, -2.75, 1.9, 0.3, fill=EQF, stroke=EQ)
for k in range(6):
    p.circ(2.35 + k * 0.3, -2.6, 0.04, fill=EQ, stroke='none')


def seat(x, yf, op=1.0):
    p.rect(x - 0.45, yf - 0.1, 0.9, 0.1, fill=EQF, stroke=EQ, op=op)
    p.rect(x - 0.07, yf - 0.55, 0.14, 0.45, fill=EQF, stroke=EQ, op=op)
    p.poly([(x - 0.45, yf - 0.55), (x + 0.35, yf - 0.57), (x + 0.4, yf - 0.73), (x - 0.42, yf - 0.71)], fill=EQF, stroke=EQ, op=op)
    p.poly([(x + 0.28, yf - 0.71), (x + 0.42, yf - 0.71), (x + 0.75, yf - 1.85), (x + 0.6, yf - 1.9)], fill=EQF, stroke=EQ, op=op)
    p.poly([(x + 0.6, yf - 1.9), (x + 0.77, yf - 1.85), (x + 0.82, yf - 2.15), (x + 0.66, yf - 2.19)], fill=EQF, stroke=EQ, op=op)
    p.pline([(x + 0.62, yf - 1.75), (x + 0.15, yf - 1.1), (x - 0.15, yf - 0.73)], HAZ, 1.2, 0.8 * op)


seat(2.75, 0.35, 0.45)
seat(2.25, 0.35)
p.rect(4.6, -1.6, 0.9, 1.2, fill=EQF, stroke=EQ)                        # nav rack on the aft wall
for k in range(4):
    p.line(4.7, -1.4 + k * 0.28, 5.4, -1.4 + k * 0.28, FAINT, 1)
# --- cabin deck: two EVA suits, tool lockers, battery and recorder under the floor
for sx in (1.55, 2.35):
    p.ell(sx, 0.75, 0.22, 0.24, fill=EQF, stroke=EQ)
    p.poly([(sx - 0.3, 1.0), (sx + 0.3, 1.0), (sx + 0.25, 1.7), (sx + 0.13, 2.3), (sx - 0.13, 2.3), (sx - 0.25, 1.7)], fill=EQF, stroke=EQ)
    p.rect(sx - 0.18, 1.12, 0.36, 0.3, fill=EQF, stroke=AIR, sw=1)
for k in range(4):
    p.rect(3.75 + k * 0.42, 0.6, 0.38, 0.85, fill=EQF, stroke=EQ)
    p.line(4.05 + k * 0.42, 0.9, 4.05 + k * 0.42, 1.1, EQ, 1.4)
p.rect(3.8, 1.6, 1.3, 0.12, fill=EQF, stroke=EQ)                        # workbench
p.line(3.9, 1.72, 3.9, 2.3, EQ, 1.1)
p.line(5.0, 1.72, 5.0, 2.3, EQ, 1.1)
p.rect(1.6, 2.38, 1.1, 0.35, fill=EQF, stroke=VIO, sw=1.2)              # battery
p.rect(3.6, 2.38, 0.55, 0.32, fill='#3a2412', stroke=HEAT, sw=1.3)      # flight recorder
# --- airlock neck: inner hatch at the ball, outer hatch in the belly, valve, reel
p.rect(5.92, -1.0, 0.16, 2.0, fill='#2a3140', stroke=AIR, sw=1.2)
p.rect(7.1, 1.3, 1.2, 0.2, fill='#2a3140', stroke=AIR, sw=1.4)
p.circ(8.8, -0.7, 0.18, fill=EQF, stroke=AIR, sw=1.3)
p.circ(6.7, -0.65, 0.28, fill=EQF, stroke=EQ)
p.rect(8.5, 0.1, 0.45, 0.6, fill=EQF, stroke=EQ)
# docking port on top of the neck
p.rect(6.9, -2.0, 1.8, 0.55, fill=HULLF, stroke=HULLS)
p.line(7.05, -2.0, 8.55, -2.0, AIR, 2.2)
# floodlights and forward RCS on the ball
for ang in (235, 125):
    import math
    fx, fy = 3.2 + 3.15 * math.cos(math.radians(ang)), 3.15 * math.sin(math.radians(ang))
    p.rect(fx - 0.3, fy - (0.35 if fy < 0 else -0.0), 0.6, 0.35, fill=EQF, stroke=EQ)
p.rect(4.9, -3.05, 0.6, 0.3, fill=EQF, stroke=EQ)

# ---------------- propulsion: a thrust cone of struts to the engine mount
for y0 in (-1.0, 1.0):
    p.line(21.6, y0, 23.0, 0.0, DIM, 2)
p.line(21.6, -1.0, 21.6, 1.0, DIM, 2)
p.circ(22.35, -1.6, 0.55, fill=EQF, stroke=FLUID, sw=1.4)               # RCS propellant
p.circ(22.35, 1.6, 0.55, fill=EQF, stroke=FLUID, sw=1.4)
p.line(22.35, -1.05, 22.2, -0.6, FLUID, 1.2)
p.line(22.35, 1.05, 22.2, 0.6, FLUID, 1.2)
p.rect(22.9, -0.55, 1.4, 1.1, fill=EQF, stroke=EQ)                      # engine
p.poly([(24.3, -0.4), (24.3, 0.4), (25.9, 1.0), (25.9, -1.0)], fill=EQF, stroke=EQ)
for k in range(3):
    p.line(24.7 + k * 0.4, -0.55 - k * 0.15, 24.7 + k * 0.4, 0.55 + k * 0.15, FAINT, 1)

# ---------------- callouts
calls = [
    (1, 1.8, -1.2, 100, 205, 'pressure', '上层驾驶甲板：气泡观察窗、正副驾驶座（螺栓 + 束带）、顶部开关面板'),
    (2, 3.85, 2.55, 100, 735, 'must', '飞行记录仪 FDR-S（强制，在下层地板下）'),
    (3, 4.4, 1.0, 300, 205, 'pressure', '下层乘员舱：工具柜 ×4、工作台、两套舱外服（贵重）；梯子连上下层'),
    (4, 2.15, 2.55, 300, 735, 'sys', '地板下：电池 PWR-B、电缆槽'),
    (5, 7.7, 1.4, 500, 735, 'pressure', '气闸颈：内门接球舱、外门在腹部；先关内门、泄压、再开外门'),
    (6, 7.8, -1.9, 450, 205, 'sys', '对接口（气闸颈顶部，带一道气密盖）'),
    (7, 12.3, 0.0, 640, 735, 'sys', '燃料电池 FC-01（螺栓固定在桁架托盘上）'),
    (8, 15.0, 0.4, 780, 735, 'haz', '氢罐 H2-T：易爆，连着燃料电池'),
    (9, 17.8, 0.3, 920, 735, 'sys', '氧罐 O2-T（储气）'),
    (10, 19.6, -0.4, 1060, 735, 'sys', '电容组 CAP-A：机械臂电源，要放电'),
    (11, 14.5, -2.6, 700, 205, 'must', '机械臂 ARM-01（强制，1.6 t）：折叠在背部导轨上'),
    (12, 16.2, -1.55, 860, 205, 'haz', '4 把发射锁 + 制动器：制动器独立电源，断总闸后仍抱死'),
    (13, 15.8, 1.0, 1200, 735, 'struct', '桁架脊梁：节点螺栓连接，拆螺栓为主，切得少'),
    (14, 22.35, -1.6, 1180, 205, 'haz', '姿控推进剂球罐 ×2'),
    (15, 24.0, 0.0, 1440, 735, 'sys', '主推进器：挂在推力锥上'),
    (16, 23.6, -2.6, 1340, 205, 'sys', '燕尾双尾梁：散热片 + 尾部姿控喷嘴'),
]
col = {'pressure': AIR, 'must': HEAT, 'sys': EQ, 'haz': HAZ, 'struct': DIM}
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="N"><defs>{DEFS}</defs><rect width="{W}" height="{H}" fill="{BG}"/>']
out.append(p.svg())
for n, x, y, lx, ly, k, _ in calls:
    px, py = p.P(x, y)
    c = col[k]
    out.append(f'<line x1="{px:.0f}" y1="{py:.0f}" x2="{lx}" y2="{ly}" stroke="{c}" stroke-width="1" opacity="0.55"/><circle cx="{px:.0f}" cy="{py:.0f}" r="2.6" fill="{c}"/>')
    out.append(f'<circle cx="{lx}" cy="{ly}" r="11" fill="{BG}" stroke="{c}" stroke-width="1.4"/><text x="{lx}" y="{ly + 4}" font-size="12" fill="{c}" text-anchor="middle" font-weight="700">{n}</text>')
out.append(f'<text x="40" y="50" font-size="24" fill="#e6ebf1" font-weight="700">S-09「雨燕」维修穿梭机 · 结构图（设计稿）</text>')
out.append(f'<text x="40" y="78" font-size="14" fill="{DIM}">26 m · 侧视剖面 · 和灰鹭号的「长方形货船壳」完全不同：前面一颗双层耐压球，细气闸颈，中间是镂空桁架，背上一条折叠机械臂，后面燕尾形双尾梁</text>')
# zones under the ship
for x0, x1, t, c in ((0.05, 9.4, '有压 · 双层球形乘员舱 + 气闸颈（球壳切开前必须先泄压）', AIR), (9.4, 21.6, '无压 · 桁架脊梁（真空，设备挂在托盘上）', DIM), (21.6, 26.0, '无压 · 推进 / 尾梁', DIM)):
    a, b = p.P(x0, 4.9), p.P(x1, 4.9)
    out.append(f'<line x1="{a[0] + 4:.0f}" y1="{a[1]:.0f}" x2="{b[0] - 4:.0f}" y2="{b[1]:.0f}" stroke="{c}" stroke-width="2"/><text x="{(a[0] + b[0]) / 2:.0f}" y="{a[1] + 20:.0f}" font-size="13" fill="{c}" text-anchor="middle">{t}</text>')
# legend
for i, (n, x, y, lx, ly, k, t) in enumerate(calls):
    cx, cy = 40 + (i % 2) * 760, 785 + (i // 2) * 21
    c = col[k]
    out.append(f'<circle cx="{cx + 9}" cy="{cy - 4}" r="9" fill="none" stroke="{c}" stroke-width="1.2"/><text x="{cx + 9}" y="{cy}" font-size="10" fill="{c}" text-anchor="middle" font-weight="700">{n}</text><text x="{cx + 26}" y="{cy + 1}" font-size="13" fill="#c3cad3">{t}</text>')
# scale bar
a, b = p.P(0, -4.2), p.P(5, -4.2)
out.append(f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" stroke="{DIM}" stroke-width="2"/><text x="{b[0] + 8}" y="{b[1] + 4}" font-size="12" fill="{DIM}">5 m</text>')
out.append('</svg>')
open('s09.html', 'w').write(HEAD + ''.join(out) + '</body></html>')
print('ok')
