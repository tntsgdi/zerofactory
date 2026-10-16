import sys, math, random
sys.path.insert(0, '.')
import shipsvg as S
from shipsvg import a, ln, rect, poly, pline, circ, ell, led, CY, CYD, HEAT, AMB, FL, GAS, VIO, EDGE, LIT, PARTE

W, H = 1700, 900
SC = 21.0
OX, OY = 313, 560
FLOOR_Y, FLOOR_X1, TOWER_X, ARM_X1 = 9.0, 50.0, -7.4, 27.5


def port_body():
    S.out = []
    o = S.out
    # force-field boundary (the edge pull that brings drifting pieces back)
    a('<rect x="-6.8" y="-15" width="63" height="24.6" rx="2.5" fill="url(#hex)" opacity="0.10"/>')
    a(f'<rect x="-6.8" y="-15" width="63" height="24.6" rx="2.5" fill="none" stroke="{CY}" stroke-width="1.4" opacity="0.5" stroke-dasharray="6 5" vector-effect="non-scaling-stroke" filter="url(#gm)"/>')
    # back wall: hex-plated, light strips
    wall = [(TOWER_X + 0.6, -10.0), (ARM_X1, -10.0), (ARM_X1 + 4.0, -5.0), (FLOOR_X1 - 6.0, -5.0), (FLOOR_X1 - 2.0, FLOOR_Y), (TOWER_X + 0.6, FLOOR_Y)]
    poly(wall, fill='#0b1119', stroke='#24364a', sw=1.2)
    a('<polygon points="' + ' '.join(f'{x},{y}' for x, y in wall) + '" fill="url(#hex)" opacity="0.18"/>')
    for yy in (-7.5, -2.0, 5.5):
        x1 = ARM_X1 if yy < -5 else (FLOOR_X1 - 6.0 + (yy + 5) / 14 * 4)
        ln(TOWER_X + 1.0, yy, x1 - 0.5, yy, CY, 1.0, 0.35, glow=True, dash='2 0.6')
    a(f'<text x="{TOWER_X + 1.0}" y="3.2" font-size="5.2" font-weight="800" fill="#16324a" font-family="N">07</text>')
    # floor platform: armoured deck, light strip, legs into the dark
    rect(TOWER_X, FLOOR_Y, FLOOR_X1 - TOWER_X, 0.9, fill='#18212c', stroke=LIT, sw=1.4)
    ln(TOWER_X + 0.3, FLOOR_Y + 0.3, FLOOR_X1 - 0.3, FLOOR_Y + 0.3, CY, 1.6, 0.8, glow=True, dash='1.4 0.5')
    for lx in (-2.0, 10.0, 22.0, 34.0, 46.0):
        poly([(lx, FLOOR_Y + 0.9), (lx + 1.4, FLOOR_Y + 0.9), (lx + 2.2, FLOOR_Y + 5.5), (lx - 0.8, FLOOR_Y + 5.5)], fill='#0e141b', stroke='#23303f')
        led(lx + 0.7, FLOOR_Y + 5.2, '#ff4444', 0.08)
    S.rect(FLOOR_X1 - 2.2, FLOOR_Y + 0.15, 2.0, 0.6, fill=AMB, stroke='none', op=0.6)
    # control tower with its glass control room
    rect(TOWER_X - 1.2, -13.2, 1.8, 22.2 + 0.9, fill='#141c26', stroke=LIT, sw=1.2)
    for yy in range(-12, 9, 2):
        ln(TOWER_X - 1.0, yy, TOWER_X + 0.4, yy + 1.2, '#23303f', 1.0)
    ln(TOWER_X - 0.3, -12.8, TOWER_X - 0.3, 9.4, CY, 1.4, 0.7, glow=True, dash='0.6 0.4')
    poly([(-12.0, -13.2), (-3.2, -13.2), (-2.4, -15.0), (-3.6, -17.0), (-11.6, -17.0), (-12.6, -15.0)], fill='#18212c', stroke=LIT, sw=1.4)
    poly([(-11.2, -16.5), (-4.0, -16.5), (-3.1, -15.0), (-11.9, -15.0)], fill='url(#glass)', stroke=CY, sw=1.2)
    for i in range(5):
        x = -10.6 + i * 1.6
        a(f'<ellipse cx="{x}" cy="-15.35" rx="0.25" ry="0.3" fill="#36e6ff" opacity="0.35"/>')     # people at the consoles
    ln(-11.8, -13.9, -3.0, -13.9, CY, 1.4, 0.8, glow=True)
    ln(-7.6, -17.0, -7.6, -18.6, LIT, 1.4)
    led(-7.6, -18.7, '#ff4444', 0.12)
    # holo sign above the tower
    a(f'<rect x="-12.6" y="-21.6" width="12.2" height="2.4" fill="#36e6ff" opacity="0.07" stroke="{CY}" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    a(f'<text x="-12.1" y="-19.75" font-size="1.45" font-weight="800" fill="{CY}" font-family="N" filter="url(#gm)">BERTH 07</text>')
    a(f'<text x="-4.0" y="-19.9" font-size="0.6" fill="{CY}" opacity="0.8" font-family="N">SALVAGE</text>')
    # the gantry boom with a maglev rail underneath
    rect(TOWER_X, -11.2, ARM_X1 - TOWER_X, 1.2, fill='#18212c', stroke=LIT, sw=1.4)
    x = TOWER_X + 0.4
    k = 0
    while x < ARM_X1 - 0.6:
        ln(x, -11.1, x + 0.9, -10.1, '#2b3a4c', 1.0)
        ln(x + 0.9, -11.1, x, -10.1, '#2b3a4c', 1.0)
        x += 1.2
    ln(TOWER_X, -9.95, ARM_X1, -9.95, CY, 2.0, 0.9, glow=True)
    S.rect(ARM_X1 - 1.8, -11.05, 1.5, 0.9, fill=AMB, stroke='none', op=0.5)
    # tractor emitters: beams down onto the ship
    for fx in (9.5, 19.0):
        rect(fx - 0.7, -9.95, 1.4, 0.55, fill='#202a36', stroke=PARTE)
        ell(fx, -9.3, 0.6, 0.15, fill='none', stroke=CY, sw=1.6, glow=True)
        a(f'<polygon points="{fx - 0.5},-9.3 {fx + 0.5},-9.3 {fx + 2.6},-3.8 {fx - 2.6},-3.8" fill="url(#holo2)" opacity="0.9"/>')
    # equipment mouth: a scanning gate under the boom
    ex, ey = 14.0, -8.4
    rect(ex - 2.3, ey - 1.5, 4.6, 0.5, fill='#202a36', stroke=LIT)
    rect(ex - 2.3, ey - 1.0, 0.35, 1.5, fill='#202a36', stroke=LIT)
    rect(ex + 1.95, ey - 1.0, 0.35, 1.5, fill='#202a36', stroke=LIT)
    a(f'<rect x="{ex - 1.95}" y="{ey - 0.2}" width="3.9" height="0.18" fill="{CY}" opacity="0.9" filter="url(#gm)"/>')
    a(f'<polygon points="{ex - 1.95},{ey} {ex + 1.95},{ey} {ex + 1.6},{ey + 1.6} {ex - 1.6},{ey + 1.6}" fill="url(#holo)" opacity="0.5"/>')
    # hose / fluid couplers: articulated arms with glowing couplings
    for mx, my, dn in ((5.0, -10.0, 1), (23.0, -10.0, 1), (38.0, 6.6, -1)):
        rect(mx - 0.5, my - (0.1 if dn > 0 else -0.1), 1.0, 0.6 * dn, fill='#202a36', stroke=PARTE)
        pline([(mx, my + 0.5 * dn), (mx + 0.8, my + 1.6 * dn), (mx + 0.4, my + 2.4 * dn)], '#4c6078', 3.0)
        circ(mx + 0.4, my + 2.5 * dn, 0.22, fill='#0b1119', stroke=FL, sw=1.6, glow=True)
    pline([(38.0, 6.6), (38.0, FLOOR_Y)], '#4c6078', 4.0)
    # magnetic clamp arms from the floor up to the hull
    for cx in (7.0, 15.8, 23.4, 28.6):
        poly([(cx - 0.6, FLOOR_Y), (cx + 0.6, FLOOR_Y), (cx + 0.3, 4.6), (cx - 0.3, 4.6)], fill='#18212c', stroke=LIT)
        ln(cx, FLOOR_Y - 0.3, cx, 4.8, CY, 1.0, 0.6, glow=True, dash='0.3 0.3')
        ell(cx, 4.3, 0.7, 0.18, fill='#0b1119', stroke=CY, sw=2.0, glow=True)
        ell(cx, 4.3, 0.45, 0.1, fill='none', stroke=CY, sw=1.0)
    # maglev trough along the floor with light pulses running to the furnace
    rect(5.5, 8.2, 35.0, 0.8, fill='#0b1119', stroke=LIT, sw=1.0)
    for i in range(36):
        xx = 5.8 + i * 0.98
        if abs(xx - 21) < 2.6:
            continue
        d = 1 if xx < 21 else -1
        c = CY if i % 4 else '#ffffff'
        pline([(xx, 8.45), (xx + 0.25 * d, 8.6), (xx, 8.75)], c, 1.2, 0.8, glow=(i % 4 == 0))
    # plasma furnace: magnetic funnel rings and a white-hot core
    fx, fy = 21.0, 7.7
    a('<circle cx="21" cy="7.7" r="7" fill="none" stroke="#ff7a2a" stroke-width="1" stroke-dasharray="3 6" opacity="0.4" vector-effect="non-scaling-stroke"/>')
    a('<circle cx="21" cy="7.7" r="4.6" fill="none" stroke="#ff7a2a" stroke-width="1" stroke-dasharray="2 5" opacity="0.35" vector-effect="non-scaling-stroke"/>')
    poly([(fx - 2.6, fy), (fx + 2.6, fy), (fx + 1.3, FLOOR_Y + 1.6), (fx - 1.3, FLOOR_Y + 1.6)], fill='#140d0a', stroke=HEAT, sw=1.6)
    for k in range(4):
        w = 2.5 - k * 0.32
        ell(fx, fy + 0.35 + k * 0.6, w, 0.16, fill='none', stroke=HEAT, sw=2.2, glow=True)
    a(f'<ellipse cx="{fx}" cy="{FLOOR_Y + 1.4}" rx="1.6" ry="0.9" fill="url(#hot)" filter="url(#gb)"/>')
    a(f'<ellipse cx="{fx}" cy="{FLOOR_Y + 1.35}" rx="0.7" ry="0.35" fill="#fff4dd"/>')
    # hazard containment pod
    hx, hy = 43.6, 6.9
    poly([(hx - 1.8, hy), (hx + 1.8, hy), (hx + 1.3, FLOOR_Y), (hx - 1.3, FLOOR_Y)], fill='#0f1610', stroke=FL, sw=1.4)
    ell(hx, hy - 0.05, 1.9, 0.3, fill='none', stroke=FL, sw=2.0, glow=True)
    ell(hx, hy - 0.9, 1.4, 0.2, fill='none', stroke=AMB, sw=1.2, op=0.8)
    a(f'<text x="{hx}" y="{hy - 1.35}" font-size="0.7" text-anchor="middle" fill="{AMB}" font-family="N">⚠</text>')
    # debris net: a hex force net
    a('<path d="M-0.2 8.3 Q2.8 10.4 5.8 8.3" fill="url(#hex)" stroke="#36e6ff" stroke-width="1.4" vector-effect="non-scaling-stroke" opacity="0.9" filter="url(#gm)"/>')
    # drone launch bay with a charging ring
    bx, by = -5.0, -6.0
    rect(bx - 4.3, by - 2.0, 4.3, 4.0, fill='#141c26', stroke=LIT, sw=1.4)
    rect(bx - 4.0, by - 1.7, 3.8, 3.4, fill='#0b1119', stroke='#24364a')
    ell(bx - 1.9, by + 0.9, 1.2, 0.25, fill='none', stroke=CY, sw=2.0, glow=True)
    ln(bx, by - 2.0, bx, by - 1.4, AMB, 3.0)
    ln(bx, by + 2.0, bx, by + 1.4, AMB, 3.0)
    a(f'<polygon points="{bx - 2.4},{by + 0.4} {bx - 1.4},{by + 0.4} {bx - 1.6},{by - 0.2} {bx - 2.2},{by - 0.2}" fill="#26313f" stroke="{LIT}" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    led(bx - 1.9, by - 0.05, CY, 0.08)
    # the drone R-02 at work
    dx, dy = 12.2, -5.6
    circ(dx, dy, 0.42, fill='#202a36', stroke=LIT, sw=1.4)
    circ(dx, dy, 0.16, fill=CY, stroke='none', glow=True)
    a(f'<line x1="{dx + 0.3}" y1="{dy + 0.3}" x2="13.6" y2="-3.0" stroke="#ff7a2a" stroke-width="2" vector-effect="non-scaling-stroke" filter="url(#gm)"/>')
    return '\n'.join(S.out)


def build():
    random.seed(5)
    defs = S.DEFS + '''
<linearGradient id="holo2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#36e6ff" stop-opacity="0.22"/><stop offset="1" stop-color="#36e6ff" stop-opacity="0"/></linearGradient>
<radialGradient id="hot" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff2c8"/><stop offset="0.4" stop-color="#ff9a3a"/><stop offset="1" stop-color="#ff5a1a" stop-opacity="0"/></radialGradient>
<radialGradient id="planet" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#284a6a"/><stop offset="0.7" stop-color="#0f2033"/><stop offset="1" stop-color="#060c14"/></radialGradient>
'''
    stars = ''.join(f'<circle cx="{random.uniform(0, W):.0f}" cy="{random.uniform(0, H):.0f}" r="{random.uniform(0.4, 1.3):.2f}" fill="#cfe6ff" opacity="{random.uniform(0.15, 0.8):.2f}"/>' for _ in range(320))
    station = []
    # far station superstructure: arcs and spokes with lit windows
    for r, op in ((900, 0.18), (760, 0.12)):
        station.append(f'<circle cx="{W * 0.15}" cy="{-r + 330}" r="{r}" fill="none" stroke="#2a4460" stroke-width="18" opacity="{op}"/>')
    for i in range(40):
        x = 300 + i * 34
        station.append(f'<rect x="{x}" y="{70 + math.sin(i * 0.4) * 6:.0f}" width="5" height="3" fill="#ffd27a" opacity="0.35"/>')
    ship = S.draw_ship()
    port = port_body()
    calls = [
        (1, -7.6, -16.0, 'f'), (2, -7.3, -20.4, 'f'), (3, 9.5, -6.5, 'f'), (4, 14.0, -8.6, 'f'), (5, 21.0, 9.6, 'f'), (6, 12.0, 8.6, 'f'),
        (7, 43.6, 7.4, 'f'), (8, 2.8, 8.9, 'f'), (9, -6.9, -5.0, 'f'), (10, 15.8, 4.3, 'f'), (11, 23.4, -9.0, 'f'), (12, 50.0, -12.0, 'f'), (13, 59.0, 12.0, 'f'),
    ]
    lab = {1: (330, 205), 2: (330, 135), 3: (420, 120), 4: (560, 120), 5: (720, 820), 6: (560, 820), 7: (1300, 820), 8: (300, 820), 9: (90, 330), 10: (900, 820), 11: (860, 120), 12: (1560, 140), 13: (1640, 760)}
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="N"><defs>{defs}</defs>',
           f'<rect width="{W}" height="{H}" fill="#03060a"/>', stars,
           f'<circle cx="{W * 0.92}" cy="{H + 900}" r="1150" fill="url(#planet)"/>',
           f'<circle cx="{W * 0.92}" cy="{H + 900}" r="1150" fill="none" stroke="#3a7ab0" stroke-width="6" opacity="0.5" filter="url(#gp)"/>',
           ''.join(station),
           f'<g transform="translate({OX},{OY}) scale({SC})">{port}</g>',
           f'<g transform="translate({OX},{OY}) scale({SC})">{ship}</g>']
    for n, x, y, _ in calls:
        px, py = OX + x * SC, OY + y * SC
        lx, ly = lab[n]
        out.append(f'<line x1="{px}" y1="{py}" x2="{lx}" y2="{ly}" stroke="#36e6ff" stroke-width="1" opacity="0.6"/><circle cx="{px}" cy="{py}" r="3" fill="#36e6ff"/>')
        out.append(f'<circle cx="{lx}" cy="{ly}" r="12" fill="#03060a" stroke="#36e6ff" stroke-width="1.5"/><text x="{lx}" y="{ly + 4.5}" font-size="13" fill="#36e6ff" text-anchor="middle" font-weight="700">{n}</text>')
    out.append(f'<text x="40" y="44" font-size="26" fill="#e8f2ff" font-weight="700">BERTH 07 · 科幻改版泊位（设计稿）</text>')
    out.append(f'<text x="40" y="70" font-size="14" fill="#7f97b3">位置、尺寸、回收口和玩法不变，只换成高科技设施的样子；青色 = 运行中的设施</text>')
    legend = [
        (1, '控制塔：玻璃控制室，里面有人值班'), (2, '全息泊位招牌：BERTH 07 + 公司名'), (3, '牵引光束发射器（吊臂上，照亮船）'), (4, '设备口 → 扫描门：光幕扫过完整设备'),
        (5, '熔炉 → 等离子熔炉：磁约束环 + 白热核心，画出吸力范围'), (6, '废料长槽 → 磁悬浮输送槽：光脉冲流向熔炉'), (7, '危险品口 → 隔离舱：绿色密封环 + 警示'),
        (8, '碎屑网 → 六边形力场网'), (9, '无人机舱 → 发射坞：充电环 + 黄黑门轨'), (10, '夹具 → 磁力夹臂：环亮 = 夹紧'), (11, '流体接驳臂（原软管桅杆）'),
        (12, '泊位力场边界（原边缘牵引场）'), (13, '背景：空间站结构、远处行星'),
    ]
    for i, (n, t) in enumerate(legend):
        col, row = i // 4, i % 4
        x = 40 + col * 420
        y = 840 + row * 0 if False else 0
    # legend as a strip at the very bottom: 4 columns
    for i, (n, t) in enumerate(legend):
        col, row = i % 4, i // 4
        x, y = 40 + col * 415, 850 + row * 0
    return out, legend


out, legend = build()
H2 = H + 100
out[0] = out[0].replace(f'height="{H}"', f'height="{H2}"')
out[1] = f'<rect width="{W}" height="{H2}" fill="#03060a"/>'
for i, (n, t) in enumerate(legend):
    col, row = i % 4, i // 4
    x, y = 40 + col * 415, H - 10 + row * 24
    out.append(f'<circle cx="{x + 9}" cy="{y - 4}" r="9" fill="none" stroke="#36e6ff" stroke-width="1.2"/><text x="{x + 9}" y="{y}" font-size="11" fill="#36e6ff" text-anchor="middle" font-weight="700">{n}</text>')
    out.append(f'<text x="{x + 26}" y="{y + 1}" font-size="13" fill="#c9d6e6">{t}</text>')
out.append('</svg>')
HEAD = '''<html><head><style>@font-face{font-family:N;src:url(file:///tmp/claude-0/fontsrc/NotoSansSC-VF.ttf)}
body{margin:0;background:#03060a;font-family:N}</style></head><body>'''
open('port.html', 'w').write(HEAD + ''.join(out) + '</body></html>')
print('ok', H2)
