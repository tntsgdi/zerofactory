# M-14 "Mole" mining ship, 58 m: concept structure sheet.
import sys, math, random
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

k = Kit(120, 480, 26.5)
rnd = random.Random(4)
# ---------------- the hull: head low, back high, a deep belly under the ore bin
outer = [(5.2, -2.4), (9.0, -5.2), (13.0, -6.6), (47.5, -6.6), (51.0, -5.6), (51.0, 5.0), (46.0, 6.9), (17.0, 6.9), (12.0, 5.6), (5.6, 4.6)]
inner = offset(outer, 0.55)
k.shell(outer, inner)
k.seams(outer, inner)
for x in (16.0, 20.0, 24.0, 28.0, 32.0, 36.0, 40.0, 44.0):
    k.line(x, -6.6, x, -6.05, '#0d1117', 1.3)
    k.line(x, 6.9, x, 6.35, '#0d1117', 1.3)
# front armour: a second, thicker layer over the wedge, in bolted slabs
armour = [(4.3, -2.6), (8.6, -6.0), (12.8, -7.35), (13.6, -6.6), (9.0, -5.2), (5.2, -2.4), (5.6, 4.6), (12.0, 5.6), (12.6, 6.3), (4.8, 5.3)]
k.plate(armour, fill='#3f4552')
for (x0, y0, x1, y1) in ((4.6, -1.4, 5.4, -1.4), (6.0, -3.6, 6.6, -3.0), (8.4, -5.4, 8.9, -4.9), (11.0, -6.6, 11.3, -6.0), (5.0, 1.0, 5.6, 1.0), (5.0, 3.4, 5.6, 3.4), (8.6, 5.1, 8.6, 5.6)):
    k.line(x0, y0, x1, y1, '#0d1117', 1.4)
for (x, y) in ((4.9, -0.6), (5.1, 2.2), (6.9, -3.8), (10.5, -6.0), (7.6, 5.2), (11.5, 6.0)):
    k.bolt(x, y)
# rooms: the cab on top, the conveyor tunnel, the ore bin, the machine room
cab = [(13.6, -8.4), (18.6, -8.4), (18.6, -6.6), (13.0, -6.6)]
k.plate([(13.0, -6.6), (13.4, -8.8), (19.0, -8.8), (19.0, -6.6)])
k.room([(13.6, -8.4), (18.6, -8.4), (18.6, -6.85), (13.5, -6.85)])
k.plate([(13.0, -6.6), (13.4, -8.8), (13.9, -8.4), (13.55, -6.85)], fill='#1b3550', stroke=AIR)
k.eq(14.2, -7.6, 0.9, 0.75, art="console")
k.seat(15.4, -6.85, 1.45)
k.eq(16.8, -8.35, 1.6, 1.4, art="nav_rack", col=VIO)
k.port(18.0, -8.95, AIR)
k.room([(5.85, -2.0), (9.3, -4.65), (12.6, -6.05), (21.6, -6.05), (21.6, 6.35), (12.3, 5.1), (6.0, 4.15)])
k.room([(22.2, -6.05), (41.8, -6.05), (41.8, 6.35), (22.2, 6.35)])
k.room([(42.4, -6.05), (47.4, -6.05), (50.45, -5.2), (50.45, 4.6), (46.0, 6.35), (42.4, 6.35)])
for x in (21.6, 41.8):
    k.plate([(x, -6.05), (x + 0.6, -6.05), (x + 0.6, 6.35), (x, 6.35)])
# ---------------- the rock-breaker head: a toothed drum on two arms, the vibration-hammer driver behind
k.plate([(2.6, 1.0), (6.6, -0.2), (6.9, 0.7), (2.9, 1.9)], fill='#323844')
k.plate([(2.6, 2.4), (6.6, 3.4), (6.4, 4.2), (2.4, 3.2)], fill='#323844')
cx, cy, r = 2.7, 1.9, 2.35
k.circ(cx, cy, r, fill=EQF, stroke=HEAT, sw=1.6)
for i in range(18):
    a = math.tau * i / 18
    p1 = (cx + math.cos(a) * r, cy + math.sin(a) * r)
    p2 = (cx + math.cos(a + 0.12) * (r + 0.42), cy + math.sin(a + 0.12) * (r + 0.42))
    p3 = (cx + math.cos(a + 0.24) * r, cy + math.sin(a + 0.24) * r)
    k.poly([p1, p2, p3], fill='#4a5160', stroke=HULLS, w=0.8)
k.circ(cx, cy, 0.9, fill='#222731', stroke=EQ, sw=1.2)
k.circ(cx, cy, 0.25, fill='#b4c0cf', stroke='none')
for i in range(6):
    a = math.tau * i / 6
    k.line(cx + math.cos(a) * 0.9, cy + math.sin(a) * 0.9, cx + math.cos(a) * 2.0, cy + math.sin(a) * 2.0, FAINT, 1.0)
k.eq(7.0, -0.9, 2.6, 2.2, art="eng_front", col=HEAT)                      # vibration-hammer driver
k.pline([(6.9, 0.2), (3.3, 1.7)], EQ, 3)
k.eq(9.6, -4.3, 2.0, 1.3, art="radiator")                                # dust filter
k.label(10.6, -2.7, "DUST", 9, DIM, 'middle')
k.cable([(9.6, 0.2), (14.0, 0.2), (14.0, -5.5), (42.6, -5.5)], HEAT)
# ---------------- the conveyor run: crusher-screener, belt tunnel up to the bin, magnetic separator, jam hatch
belt0, belt1 = (8.2, 3.7), (20.8, -4.3)
dx, dy = belt1[0] - belt0[0], belt1[1] - belt0[1]
L = math.hypot(dx, dy)
ux, uy = dx / L, dy / L
nx, ny = -uy, ux
tun = [(belt0[0] + nx * 0.8, belt0[1] + ny * 0.8), (belt1[0] + nx * 0.8, belt1[1] + ny * 0.8), (belt1[0] - nx * 0.8, belt1[1] - ny * 0.8), (belt0[0] - nx * 0.8, belt0[1] - ny * 0.8)]
k.plate(tun, fill='#2a2f39')
k.line(belt0[0] + nx * 0.3, belt0[1] + ny * 0.3, belt1[0] + nx * 0.3, belt1[1] + ny * 0.3, EQ, 1.6)
k.line(belt0[0] - nx * 0.3, belt0[1] - ny * 0.3, belt1[0] - nx * 0.3, belt1[1] - ny * 0.3, EQ, 1.0)
for i in range(1, 15):
    t = i / 15
    k.circ(belt0[0] + dx * t, belt0[1] + dy * t, 0.22, fill=EQF, stroke=DIM, sw=0.9)
for i in range(9):                                                         # ore riding the belt (one clump jammed)
    t = 0.12 + i * 0.09
    k.circ(belt0[0] + dx * t + nx * 0.45, belt0[1] + dy * t + ny * 0.45, 0.16 + rnd.random() * 0.08, fill='#6b5f52', stroke='none')
jt = 0.62
for j in range(5):
    k.circ(belt0[0] + dx * jt + nx * (0.3 + 0.18 * j), belt0[1] + dy * jt + ny * (0.3 + 0.18 * j) + 0.1 * j, 0.25, fill='#7a6a58', stroke='none')
hx, hy = belt0[0] + dx * 0.55 + nx * 0.8, belt0[1] + dy * 0.55 + ny * 0.8
k.poly([(hx, hy), (hx + ux * 1.4, hy + uy * 1.4), (hx + ux * 1.4 + nx * 0.25, hy + uy * 1.4 + ny * 0.25), (hx + nx * 0.25, hy + ny * 0.25)], fill='#2a3140', stroke=AIR, w=1.2)
k.eq(13.7, 2.6, 3.0, 2.2, art="cargo", tag="SCR")                         # crusher-screener
k.eq(19.2, -5.95, 2.2, 1.0, art="cap", col=VIO)                           # magnetic separator
k.eq(14.4, 4.9, 2.6, 1.0, art="pump")                                     # belt drive motor
k.cable([(17.0, 5.4), (21.6, 5.4)], HEAT)
# ---------------- the ore bin: wear-lined, loose ore, a bottom door that opens downwards, load cells
bin_in = [(22.9, -5.7), (41.1, -5.7), (41.1, 2.6), (35.6, 5.7), (28.4, 5.7), (22.9, 2.6)]
k.poly(bin_in, fill='none', stroke=HULLS, w=2.4)
for i in range(len(bin_in) - 1):
    ax, ay = bin_in[i]
    bx, by = bin_in[i + 1]
    n = max(2, int(math.hypot(bx - ax, by - ay) / 1.8))
    for j in range(1, n):
        t = j / n
        k.bolt(ax + (bx - ax) * t, ay + (by - ay) * t)
lin = offset(bin_in, 0.3)
k.poly(lin, fill='none', stroke='#6c7686', w=1.0, dash='10 4')
for i in range(260):                                                      # the loose ore
    x = rnd.uniform(23.3, 40.7)
    y = rnd.uniform(-1.2, 5.4)
    if y > 2.6 and (x < 23.3 + (y - 2.6) * 1.75 or x > 40.7 - (y - 2.6) * 1.75):
        continue
    rr = rnd.uniform(0.12, 0.34)
    pts = [(x + math.cos(a) * rr * rnd.uniform(0.7, 1.2), y + math.sin(a) * rr * rnd.uniform(0.7, 1.2)) for a in [j * math.tau / 6 for j in range(6)]]
    k.poly(pts, fill=rnd.choice(['#5d5246', '#6b5f52', '#7a6a58', '#514840']), stroke='none')
k.line(23.3, -1.2, 40.7, -1.2, '#7a6a58', 0.8, 0.5, dash='3 4')
for x0 in (28.4, 32.0):
    k.plate([(x0, 5.7), (x0 + 3.6, 5.7), (x0 + 3.6, 6.25), (x0, 6.25)], fill='#2a3140', stroke=HAZ)
    k.lock(x0 + 0.2, 5.98)
    k.lock(x0 + 3.4, 5.98)
k.pline([(29.2, 6.25), (27.0, 6.3)], EQ, 5)
k.pline([(34.8, 6.25), (37.0, 6.3)], EQ, 5)
for x in (24.0, 28.0, 36.0, 40.0):
    k.eq(x - 0.3, 6.0 if x in (24.0, 40.0) else 6.25, 0.6, 0.3, col=VIO)
k.eq(22.95, -5.68, 3.0, 0.7, art="swb")                                   # bin level / weight monitor
# ---------------- the machine room: hydraulic unit, two high-load motors, cooling pump, power cabinet
k.tank(42.8, -5.6, 1.4, 3.6, FLUID, "HYD")
k.eq(44.5, -5.6, 2.2, 2.6, art="pump", col=FLUID)
k.eq(42.8, -1.3, 2.6, 2.6, art="eng_front", col=HEAT)
k.eq(42.8, 1.6, 2.6, 2.6, art="eng_front", col=HEAT)
k.eq(45.8, -2.5, 1.5, 2.0, art="pump", col=FLUID)
k.eq(47.6, -2.5, 2.5, 4.6, art="swb", col=HEAT)
k.label(48.85, 2.5, "PWR", 9, HEAT, 'middle')
k.eq(45.8, 0.0, 1.5, 3.2, art="radiator", col=FLUID)
k.pipe([(44.2, -2.0), (44.2, -0.9), (45.8, -0.9)], FLUID)
k.pipe([(44.2, -3.6), (40.0, -3.6), (40.0, 5.4), (36.0, 6.0)], FLUID, 1.4)
k.cable([(47.6, -1.2), (46.0, 4.6), (22.5, 4.6), (22.5, 5.4)], HEAT)
k.switch(49.2, -6.95, HEAT)
k.switch(49.7, -6.95, HEAT)
k.port(44.5, 7.25, FLUID)
# ---------------- the heavy propulsion: two thick engines, stabiliser beams, attitude jets
k.plate([(51.0, -5.6), (52.0, -5.6), (52.0, 5.0), (51.0, 5.0)], fill='#323844')
for yc in (-2.6, 2.0):
    k.eq(52.0, yc - 1.6, 2.4, 3.2, art="eng_core")
    k.peq([(54.4, yc - 1.3), (57.9, yc - 2.0), (57.9, yc + 2.0), (54.4, yc + 1.3)])
    for x in (55.2, 56.0, 56.8, 57.5):
        k.line(x, yc - 1.4 - (x - 54.4) * 0.18, x, yc + 1.4 + (x - 54.4) * 0.18, FAINT, 1.0)
for sg, y in ((-1, -6.6), (1, 6.9)):
    k.plate([(47.0, y), (57.0, y), (57.0, y + sg * 0.6), (47.0, y + sg * 0.6)])
    k.eq(55.9, y + sg * 0.6 - (0.6 if sg < 0 else 0.0), 1.1, 0.6, art="rcs_quad")
for x in (20.0, 34.0, 46.0):
    a, b = k.P(x, 6.9)
    k.o.append(f'<polygon points="{a-16:.0f},{b+70:.0f} {a+16:.0f},{b+70:.0f} {a+8:.0f},{b+4:.0f} {a-8:.0f},{b+4:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

calls = []
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 150 if row == 0 else 850, kind, text))
c(1, 2.7, 1.9, 80, 1, "haz", "破碎头（齿鼓，约 6 t：超过抓钩上限，要分段拆）")
c(2, 4.6, 1.3, 150, 1, "struct", "破碎头支臂 ×2")
c(3, 8.3, 0.2, 80, 0, "haz", "振动锤驱动器（可能未完全停机）")
c(4, 6.5, -3.3, 150, 0, "struct", "前部护甲层：加厚、整块螺栓固定")
c(5, 10.6, -3.6, 220, 0, "sys", "粉尘过滤器")
c(6, 16.0, -7.6, 290, 0, "room", "驾驶室（规格未列，按真实矿船补：控制台 / 座椅 / 机架）")
c(7, 14.0, 0.0, 220, 1, "struct", "输送带通道（斜向，滚筒 + 皮带）")
c(8, 15.8, -1.0, 290, 1, "haz", "卡矿：带上的矿团卡住，皮带仍绷着劲")
c(9, 16.2, 0.7, 360, 1, "room", "堵塞检修口")
c(10, 15.2, 3.7, 430, 1, "sys", "破碎筛选机")
c(11, 15.7, 5.4, 500, 1, "energy", "皮带驱动电机")
c(12, 20.3, -5.45, 360, 0, "energy", "磁选组件（进料口上方）")
c(13, 24.4, -5.3, 430, 0, "sys", "矿仓液位 / 重量监测")
c(14, 32.0, 2.0, 500, 0, "haz", "主矿仓：松散矿石（会流动、会倾泻）")
c(15, 23.2, 0.0, 570, 0, "struct", "内壁耐磨衬板（螺栓）")
c(16, 31.8, 6.0, 570, 1, "haz", "下开式放料门 ×2 + 锁扣 + 液压缸（可能变形卡死）")
c(17, 28.0, 6.4, 640, 1, "energy", "重量传感器 ×4（矿仓支脚）")
c(18, 43.5, -3.8, 710, 0, "fluid", "大型液压单元（油箱 + 泵）")
c(19, 44.1, 0.0, 780, 0, "energy", "高负载电机 ×2")
c(20, 46.5, -1.5, 850, 0, "fluid", "冷却泵 + 换热器")
c(21, 48.8, 0.0, 920, 0, "haz", "动力配电柜（高压）")
c(22, 49.5, -6.95, 990, 0, "energy", "外部总闸 ×2")
c(23, 55.0, -2.6, 1060, 0, "sys", "粗大型推进器 ×2")
c(24, 52.0, 6.6, 710, 1, "struct", "稳定尾梁（上下）")
c(25, 56.4, 7.2, 780, 1, "sys", "姿控喷口")
zones = [(2.6, 12.6, 7.9, "① 破岩船首", "haz"), (12.6, 21.6, 7.9, "② 矿石输送段", "struct"), (21.6, 41.8, 7.9, "③ 主矿仓", "haz"),
         (41.8, 50.5, 7.9, "④ 设备段", "energy"), (50.5, 57.9, 7.9, "⑤ 推进段", "struct")]
sheet('m14.html', 1800, 1200, 'M-14「鼹鼠」采矿船 · 58 m · 结构图（设计稿）',
      ['船头楔形破岩头（低头），腹部厚大，中央纵向矿仓，后部厚重推进段 —— 一只低头钻洞的鼹鼠。',
       '第一次引入松散内容物：不只是拆结构，还要处理矿石；超重设备要分段拆。'], k.svg(), k.P, calls, zones, legend_cols=2, scale_at=(0.0, -9.6), scale_m=10)
print('ok')
