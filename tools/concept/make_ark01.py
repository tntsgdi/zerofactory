# ARK-01 "Voyager" colony ship, ~600 m (user 2026-10-17: much bigger than the patrol ship;
# both rings still spinning when it arrives): concept structure sheet.
# Top: the whole ship at one scale, with PT-34 and GR-7 drawn to the same scale under it.
# Bottom: five enlarged cutaways (ring A rim, ring B farm rim, a ring hub with its de-spin gear,
# the power core, the industry block / hangar), each at its own scale.
import sys, math, random
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

GREEN = '#5fbf7a'
ARM = '#4a505c'
rnd = random.Random(7)
W, H = 3000, 2440
k = Kit(170, 770, 4.2)                  # the overview, metres
calls = []


def C(kit, x, y, row_y, kind, text):
    px, py = kit.P(x, y)
    calls.append((0, px, py, 0, row_y, kind, text))


TOP_ROW, INSET_ROW = 182, 1955


# ================================================================ overview
def spin_arrows(cx, ry, rx):
    for a0, a1 in ((200, 250), (20, 70)):
        pts = [(cx + rx * 1.18 * math.cos(math.radians(a)), ry * 1.04 * math.sin(math.radians(a))) for a in range(a0, a1 + 1, 5)]
        k.pline(pts, HAZ, 1.6, 0.9)
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        d = math.atan2(y2 - y1, x2 - x1)
        for s in (-1, 1):
            k.line(x2, y2, x2 - 4.5 * math.cos(d + s * 0.5), y2 - 4.5 * math.sin(d + s * 0.5), HAZ, 1.6, 0.9)


# ring ghosts (the rest of each ring going round), spinning
for cx, ry, rx in ((85.0, 105.0, 20.0), (193.0, 110.0, 26.0)):
    k.ell(cx, 0.0, rx, ry, fill='none', stroke=FAINT, sw=1.2)
    k.ell(cx, 0.0, rx * 0.8, ry - 14.0, fill='none', stroke=FAINT, sw=0.9)
    spin_arrows(cx, ry, rx)
k.label(85.0, -126.0, "旋转中 · 3.0 rpm", 12, HAZ, 'middle')
k.label(193.0, -129.0, "旋转中 · 2.9 rpm", 12, HAZ, 'middle')

# radiator wings behind the power core
for sg in (-1, 1):
    k.plate([(390.0, sg * 28.0), (472.0, sg * 28.0), (464.0, sg * 112.0), (398.0, sg * 112.0)], fill='#262b34')
    for i in range(1, 22):
        t = i / 22
        k.line(390.0 + 82.0 * t, sg * 28.0, 398.0 + 66.0 * t, sg * 112.0, FLUID, 0.8, 0.4)
    k.pipe([(392.0, sg * 30.0), (399.0, sg * 108.0), (463.0, sg * 108.0), (470.0, sg * 30.0)], FLUID, 1.4)
    for yy in (55.0, 82.0):
        k.line(392.0 + (yy - 28) * 0.095, sg * yy, 470.0 - (yy - 28) * 0.095, sg * yy, FLUID, 1.0, 0.7)

# the spine: a pressurised tube inside a truss, 50 -> 488 m
k.truss(50.0, 488.0, -10.5, -7.5, 10.0, DIM, 1.0)
k.truss(50.0, 488.0, 7.5, 10.5, 10.0, DIM, 1.0)
k.shell([(50.0, -6.5), (488.0, -6.5), (488.0, 6.5), (50.0, 6.5)], [(50.0, -5.6), (488.0, -5.6), (488.0, 5.6), (50.0, 5.6)])
k.room([(50.0, -5.6), (488.0, -5.6), (488.0, 5.6), (50.0, 5.6)])
for y in (-2.0, 2.0):
    k.line(50.0, y, 488.0, y, '#2a3140', 1.4)
k.cable([(50.0, -3.8), (488.0, -3.8)], HEAT, 1.6)
k.line(50.0, 0.0, 488.0, 0.0, DIM, 0.9, dash='8 4')
k.pipe([(50.0, 3.2), (488.0, 3.2)], FLUID, 1.6)
k.pipe([(50.0, 4.6), (488.0, 4.6)], AIR, 1.1)
SECT = list(range(110, 480, 30))
for i, x in enumerate(SECT):
    k.line(x, -5.6, x, 5.6, HULLS, 2.0)
    k.label(x + 15.0, -12.5, "L%d" % (i + 1), 9, DIM if i != 5 else HAZ, 'middle')
k.label(275.0, -16.5, "L6 主干断电 · 下层备用在跑", 10, HAZ, 'middle')
k.pline([(52.0, -13.5), (486.0, -13.5)], HAZ, 1.0, 0.55, dash='3 6')

# ---- ① command section
nose = [(0.0, 0.0), (8.0, -11.0), (24.0, -17.0), (50.0, -18.0), (50.0, 18.0), (24.0, 17.0), (8.0, 11.0)]
k.shell(nose, offset(nose, 1.0))
k.room(offset(nose, 1.0))
k.plate([(0.0, 0.0), (8.0, -11.0), (9.2, -10.0), (1.4, 0.0)], fill='#1b3550', stroke=AIR)
for y in (-6.0, 6.0):
    k.line(6.0, y, 49.0, y, HULLS, 1.6)
for i in range(6):                                                      # bridge stations
    k.rect(8.0 + i * 3.6, -9.6, 2.4, 2.4, fill=EQF, stroke=EQ, sw=0.9)
for i in range(8):                                                      # navigation data centre racks
    k.rect(8.0 + i * 4.6, -4.4, 3.4, 8.6, fill=EQF, stroke=VIO, sw=0.9)
k.rect(30.0, 7.6, 18.0, 8.0, fill=EQF, stroke=EQ, sw=0.9)
k.line(32.0, -18.0, 32.0, -40.0, HULLS, 2.0)                             # long-range comms mast
k.ell(32.0, -42.0, 11.0, 2.4, fill=EQF, stroke=VIO, sw=1.3)
k.ell(42.0, -30.0, 5.0, 1.4, fill=EQF, stroke=VIO, sw=1.1)
k.line(36.0, -24.0, 42.0, -30.0, HULLS, 1.4)
for x in (16.0, 34.0):                                                  # docking ports
    k.rect(x, 17.5, 9.0, 3.5, fill='#2a3140', stroke=AIR, sw=1.2)


# ---- rings
def hub(x0, x1, h):
    k.shell([(x0, -h), (x1, -h), (x1, h), (x0, h)], offset([(x0, -h), (x1, -h), (x1, h), (x0, h)], -0.8))
    k.room(offset([(x0, -h), (x1, -h), (x1, h), (x0, h)], -0.8))
    for xb in (x0 + 1.2, x1 - 2.6):
        k.rect(xb, -h + 0.8, 1.4, 2 * h - 1.6, fill='#2a3140', stroke=HAZ, sw=1.0)
    k.rect((x0 + x1) / 2 - 3.0, -h + 1.2, 6.0, 3.0, fill=EQF, stroke=HEAT, sw=1.0)


def spoke(x, y0, y1, w=6.0):
    k.shell([(x, y0), (x + w, y0), (x + w, y1), (x, y1)], [(x + 0.8, y0), (x + w - 0.8, y0), (x + w - 0.8, y1), (x + 0.8, y1)])
    k.room([(x + 0.8, y0), (x + w - 0.8, y0), (x + w - 0.8, y1), (x + 0.8, y1)])
    k.line(x + w / 2, y0, x + w / 2, y1, DIM, 0.8, dash='6 3')
    ym = (y0 + y1) / 2
    k.rect(x + 1.2, ym - 2.5, w - 2.4, 5.0, fill=EQF, stroke=AIR, sw=1.1)


def rim(x0, x1, yi, yo, decks=3, green=False):
    sg = 1 if yo > yi else -1
    c = 2.4
    o = [(x0 + c, yi), (x1 - c, yi), (x1, yi + sg * c), (x1, yo - sg * c), (x1 - c, yo), (x0 + c, yo), (x0, yo - sg * c), (x0, yi + sg * c)]
    inn = offset(o, 1.0 if sg > 0 else -1.0)
    k.shell(o, inn)
    k.seams(o, inn, 2)
    k.room(inn)
    for d in range(1, decks):
        yy = yi + (yo - yi) * d / decks
        k.line(x0 + 1.2, yy, x1 - 1.2, yy, HULLS, 1.4)
    for x in range(int(x0) + 3, int(x1) - 1, 3):                        # windows on the outer deck
        k.rect(x, yo - sg * 1.2 - 0.6, 1.4, 1.2, fill='#1b3550' if not green else '#1d2a1f', stroke=AIR if not green else GREEN, sw=0.7)
    # contents at overview scale: little rooms along each deck
    for d in range(decks):
        ya = yi + (yo - yi) * d / decks
        yb = yi + (yo - yi) * (d + 1) / decks
        top, bot = min(ya, yb), max(ya, yb)
        n = int((x1 - x0) / 4.2)
        for i in range(n):
            xx = x0 + 1.8 + i * 4.2
            if green and d == decks - 1:
                k.rect(xx, top + 1.0, 3.2, bot - top - 2.0, fill='#1d2a1f', stroke=GREEN, sw=0.8)
            else:
                k.rect(xx, top + 1.0, 3.2, bot - top - 2.0, fill=EQF, stroke=EQ if d != 0 else (FLUID if green else AIR), sw=0.7)


hub(76.0, 94.0, 15.0)
spoke(82.0, -92.0, -15.0)
spoke(82.0, 15.0, 92.0)
rim(68.0, 102.0, -92.0, -118.0)
rim(68.0, 102.0, 92.0, 118.0)
k.poly([(78.0, -118.2), (80.5, -116.5), (82.5, -118.2), (81.5, -117.0), (83.0, -115.8), (79.6, -116.2)], fill=BG, stroke=HAZ, w=1.4)
hub(182.0, 204.0, 18.0)
for xs in (184.0, 196.0):
    spoke(xs, -96.0, -18.0)
    spoke(xs, 18.0, 96.0)
rim(168.0, 218.0, -96.0, -124.0, green=True)
rim(168.0, 218.0, 96.0, 124.0)
k.plate([(170.5, -124.2), (215.5, -124.2), (215.5, -123.0), (170.5, -123.0)], fill='#1b3550', stroke=AIR)

# ---- ⑤ industry and storage block (with the hangar)
ind = [(240.0, -36.0), (360.0, -36.0), (360.0, 36.0), (240.0, 36.0)]
k.shell(ind, offset(ind, -1.2))
k.seams(ind, offset(ind, -1.2), 1)
k.room(offset(ind, -1.2))
k.line(241.2, -18.0, 358.8, -18.0, HULLS, 1.4)
k.line(241.2, 18.0, 358.8, 18.0, HULLS, 1.4)
for i in range(12):                                                     # warehouse: container stacks
    for j in range(3):
        k.rect(300.0 + i * 4.8, -34.0 + j * 5.2, 4.2, 4.6, fill=EQF, stroke=EQ, sw=0.7)
for i in range(6):                                                      # fabrication / repair stations
    k.rect(244.0 + i * 9.0, -32.0, 7.0, 10.0, fill=EQF, stroke=EQ, sw=0.8)
    k.line(247.5 + i * 9.0, -22.0, 249.0 + i * 9.0, -27.0, EQ, 1.2)
for x in (248.0, 280.0):                                                # two shuttles in the hangar (S-09 class)
    k.ell(x + 4.0, 27.0, 4.0, 4.0, fill=EQF, stroke=AIR, sw=1.0)
    k.rect(x + 7.5, 25.5, 18.0, 3.0, fill=EQF, stroke=EQ, sw=0.8)
k.rect(244.0, 35.2, 60.0, 1.6, fill='#2a3140', stroke=AIR, sw=1.3)
for i in range(8):
    k.rect(312.0 + i * 5.6, 20.0, 4.8, 14.0, fill=EQF, stroke=EQ, sw=0.7)

# ---- ⑥ power core
core = [(385.0, -28.0), (475.0, -28.0), (475.0, 28.0), (385.0, 28.0)]
k.shell(core, offset(core, -3.0), fill=ARM)
k.room(offset(core, -3.0))
k.circ(412.0, 0.0, 19.0, fill='#2a2f39', stroke=DIM, sw=1.2)
k.circ(412.0, 0.0, 14.0, fill=EQF, stroke=HEAT, sw=1.6)
k.circ(412.0, 0.0, 9.0, fill='none', stroke=HEAT, sw=1.0)
k.label(412.0, 1.5, "MAIN", 10, HEAT, 'middle')
k.circ(452.0, -12.0, 9.0, fill='#2a2f39', stroke=DIM, sw=1.1)
k.circ(452.0, -12.0, 6.0, fill=EQF, stroke=HEAT, sw=1.3)
for i in range(4):
    k.rect(440.0 + i * 7.5, 6.0, 6.0, 9.0, fill=EQF, stroke=HEAT, sw=0.9)
k.rect(440.0, 16.5, 30.0, 6.0, fill=EQF, stroke=VIO, sw=1.0)

# ---- ⑦ tail: propellant, thrust frame, engines, RCS
for sg in (-1, 1):
    for x in (505.0, 532.0):
        k.sphere(x, sg * 24.0, 12.5, HAZ, "", jacket=1.2)
    k.plate([(488.0, sg * 6.5), (492.0, sg * 6.5), (550.0, sg * 54.0), (546.0, sg * 56.0)], fill=ARM)
    k.plate([(475.0, sg * 28.0), (480.0, sg * 28.0), (550.0, sg * 46.0), (548.0, sg * 49.0)], fill=ARM)
    k.rect(548.0, sg * 60.0 - 3.0, 8.0, 6.0, fill=EQF, stroke=EQ, sw=1.0)
k.pipe([(505.0, -11.0), (505.0, 11.0)], HAZ, 2.0)
k.pipe([(532.0, -11.0), (532.0, 11.0)], HAZ, 2.0)
k.pipe([(488.0, 0.0), (550.0, 0.0)], HAZ, 2.4)
k.plate([(550.0, -58.0), (556.0, -58.0), (556.0, 58.0), (550.0, 58.0)], fill=ARM)
for yc in (-44.0, -22.0, 0.0, 22.0, 44.0):
    k.rect(556.0, yc - 7.0, 8.0, 14.0, fill=EQF, stroke=EQ, sw=1.0)
    k.peq([(564.0, yc - 5.5), (600.0, yc - 10.5), (600.0, yc + 10.5), (564.0, yc + 5.5)])
    k.line(564.0, yc, 600.0, yc, FAINT, 0.8)

# ---- the same scale: PT-34 and GR-7 under the ship
pt = [(0.0, 0.8), (14.0, -5.6), (34.0, -9.4), (56.0, -10.2), (104.0, -10.2), (113.0, -8.0), (134.0, -7.0), (134.0, 7.0), (113.0, 7.4), (104.0, 9.0), (40.0, 9.0), (16.0, 6.0)]
k.poly([(232.0 + x, 92.0 + y) for x, y in pt], fill='#2a2f39', stroke=HEAT, w=1.3)
k.label(299.0, 108.5, "PT-34 隼鹰 · 134 m（同比例）", 12, HEAT, 'middle')
gr = [(0.2, 0.5), (2.4, -3.3), (4.6, -4.0), (33.0, -4.0), (42.0, -2.0), (42.0, 2.0), (33.0, 4.0), (4.6, 4.0), (0.8, 2.2)]
k.poly([(232.0 + x, 120.0 + y) for x, y in gr], fill='#2a2f39', stroke=AIR, w=1.3)
k.label(282.0, 121.5, "GR-7 灰鹭 · 42 m", 12, AIR, 'start')
k.line(0.0, -70.0, 50.0, -70.0, DIM, 2.0)                                # scale bar
k.label(53.0, -69.0, "50 m", 12, DIM)

# overview callouts
C(k, 10.0, -8.0, TOP_ROW, "room", "① 主舰桥：6 个席位")
C(k, 22.0, 0.0, TOP_ROW, "energy", "① 航行数据中心（机架 ×8）")
C(k, 32.0, -42.0, TOP_ROW, "energy", "① 长程通讯：主碟 + 副碟")
C(k, 20.5, 19.2, TOP_ROW, "room", "① 对接口 ×2")
C(k, 85.0, -105.0, TOP_ROW, "room", "② 居住环 A：三层外缘舱，地板朝外（半径 105 m）")
C(k, 80.5, -117.0, TOP_ROW, "haz", "② A 环破口（变体：A 环失压、B 环正常）")
C(k, 85.0, -50.0, TOP_ROW, "room", "轮辐电梯井（A 环 2 根、B 环 4 根）")
C(k, 85.0, 0.0, TOP_ROW, "haz", "环毂：旋转轴承 + 滑环 + 消旋机构（见下 C）")
C(k, 85.0, -126.0, TOP_ROW, "haz", "两个环进坞时还在转：先消旋，才能拆")
C(k, 193.0, -118.0, TOP_ROW, "fluid", "④ 居住环 B / 农业：温室、食物、水循环（见下 B）")
C(k, 145.0, -3.8, TOP_ROW, "haz", "③ 主轴上层：主配电主干")
C(k, 160.0, 0.0, TOP_ROW, "room", "③ 主轴中层：维护电梯 + 应急通道")
C(k, 130.0, 3.2, TOP_ROW, "fluid", "③ 主轴下层：主管路（水 + 空气）")
C(k, 275.0, -12.5, TOP_ROW, "haz", "③ 主轴分段 L1–L12（L6 主干断电，下层备用在跑）")
C(k, 230.0, -13.5, TOP_ROW, "haz", "③ 承力弦杆：切割会改变整根 440 m 主轴的受力")
C(k, 280.0, -27.0, TOP_ROW, "sys", "⑤ 工程舱 + 维修工位 ×6")
C(k, 330.0, -27.0, TOP_ROW, "sys", "⑤ 备件仓：货柜 36 个")
C(k, 264.0, 27.0, TOP_ROW, "room", "⑤ 机库：两艘 S-09 级穿梭机 + 外开库门")
C(k, 412.0, 0.0, TOP_ROW, "haz", "⑥ 主反应堆（已停）")
C(k, 452.0, -12.0, TOP_ROW, "haz", "⑥ 次级反应堆")
C(k, 430.0, -80.0, TOP_ROW, "fluid", "⑥ 大型散热翼（上下各一，翼展 220 m）")
C(k, 455.0, 19.5, TOP_ROW, "energy", "⑥ 电力分配中心 + 辅助电网（主堆停了它还活着）")
C(k, 518.0, -24.0, TOP_ROW, "haz", "⑦ 推进剂球罐 ×8 + 推进剂主干")
C(k, 520.0, -32.0, TOP_ROW, "struct", "⑦ 巨型结构固定梁")
C(k, 580.0, 0.0, TOP_ROW, "sys", "⑦ 主引擎阵列 ×5")
C(k, 552.0, -60.0, TOP_ROW, "haz", "⑦ 姿控群")
C(k, 299.0, 92.0, TOP_ROW, "struct", "比例参照：PT-34 与 GR-7")

zones = [(0.0, 50.0, 131.0, "① 前指挥段", "room"), (50.0, 140.0, 131.0, "② 居住环 A", "room"), (140.0, 230.0, 131.0, "④ 居住环 B / 农业", "fluid"),
         (230.0, 370.0, 131.0, "⑤ 工业与仓储", "sys"), (370.0, 482.0, 131.0, "⑥ 动力核心", "haz"), (482.0, 600.0, 131.0, "⑦ 尾推进段", "struct")]
zones_px = [(k.P(x0, 0)[0], k.P(x1, 0)[0], k.P(0, y)[1], t, kd) for x0, x1, y, t, kd in zones]
k.label(5.0, 131.0 + 9.0, "③ 中央主轴贯穿 50–488 m", 12, VIO, 'start')

# ================================================================ insets
INSETS = []


def frame(x, y, w, h, title, note=""):
    INSETS.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" stroke="#3a4352" stroke-width="1.2" rx="6"/>'
                  f'<text x="{x + 14}" y="{y + 24}" font-size="15" fill="#e6ebf1" font-weight="700">{title}</text>'
                  f'<text x="{x + 14}" y="{y + 43}" font-size="12" fill="{DIM}">{note}</text>')


IY, IH = 1390, 520
# ---- A: ring A rim module (upper rim; floor outward = up), metres along x 0..34, y 0 (outer) .. 26 (hub side incl. spoke)
frame(40, IY, 570, IH, "A · 居住环 A 外缘舱（剖面）", "34 m 宽 · 三层 · 旋转重力：地板朝外（图中朝上）")
a = Kit(70, IY + 80, 15.0)
ao = [(0, 0), (34, 0), (34, 14), (0, 14)]
a.shell(ao, offset(ao, -0.5))
a.room(offset(ao, -0.5))
for yy in (4.8, 9.6):
    a.plate([(0.5, yy - 0.15), (33.5, yy - 0.15), (33.5, yy + 0.15), (0.5, yy + 0.15)])
for i in range(6):                                                      # outer deck: cabins (bed, locker, desk), floor at the top
    x = 0.8 + i * 5.5
    a.eq(x, 0.6, 2.6, 1.0, art="bunk")
    a.eq(x + 2.8, 0.6, 1.0, 2.2, art="locker")
    a.eq(x, 1.8, 1.6, 0.9, art="console")
    a.plate([(x + 5.0, 0.5), (x + 5.2, 0.5), (x + 5.2, 4.65), (x + 5.0, 4.65)], fill='#2a3140')
    a.door(x + 5.02, 2.0, 0.16, 2.4)
for i in range(3):                                                      # middle deck: mess, school, sick bay
    a.eq(1.0 + i * 3.4, 5.1, 2.8, 1.1, art="console")
a.eq(11.4, 5.1, 2.0, 2.6, art="cabinet")
for i in range(4):
    a.eq(14.2 + i * 2.2, 5.1, 1.6, 0.9, art="console")
a.label(18.2, 8.6, "SCHOOL", 9, DIM, 'middle')
for i in range(2):
    a.eq(24.0 + i * 3.4, 5.1, 3.0, 1.0, art="bunk")
a.eq(30.8, 5.1, 2.6, 2.4, art="cabinet", col=FLUID)
a.label(28.0, 8.6, "SICK BAY", 9, FLUID, 'middle')
a.eq(1.0, 10.1, 4.0, 3.2, art="env", col=AIR)                             # inner deck: the ring's own air loop
a.eq(5.4, 10.1, 3.0, 3.2, art="pump", col=AIR)
a.eq(8.8, 10.1, 3.4, 3.2, art="o2cab", col=AIR, hazard="gas_tank")
a.tank(12.6, 10.0, 1.6, 3.4, AIR, "O₂")
a.tank(14.4, 10.0, 1.6, 3.4, AIR, "N₂")
a.eq(22.0, 10.1, 3.4, 3.2, art="radiator", col=FLUID)
a.eq(25.8, 10.1, 3.6, 3.2, art="swb", col=HEAT)
a.eq(29.8, 10.1, 3.6, 3.2, art="battery", col=VIO)
a.shell([(16.6, 14.0), (20.4, 14.0), (20.4, 26.0), (16.6, 26.0)], [(17.1, 14.0), (19.9, 14.0), (19.9, 26.0), (17.1, 26.0)])
a.room([(17.1, 9.75), (19.9, 9.75), (19.9, 26.0), (17.1, 26.0)])
a.rect(17.3, 17.0, 2.4, 3.0, fill=EQF, stroke=AIR, sw=1.1)
a.cable([(17.4, 14.0), (17.4, 26.0)], HEAT)
a.pipe([(19.6, 14.0), (19.6, 26.0)], AIR, 1.2)
a.label(18.5, 27.3, "→ 环毂", 10, DIM, 'middle')
a.poly([(4.0, -0.05), (5.0, 0.6), (5.8, -0.05), (5.4, 0.45), (6.2, 0.9), (4.8, 0.8)], fill=BG, stroke=HAZ, w=1.4)
C(a, 2.1, 1.1, INSET_ROW, "room", "A：舱室 ×6（床 + 储物柜 + 书桌 + 隔墙门）")
C(a, 5.0, 0.4, INSET_ROW, "haz", "A：外壳破口（A 环已失压）")
C(a, 4.4, 5.6, INSET_ROW, "sys", "A：公共餐厅")
C(a, 18.2, 5.6, INSET_ROW, "sys", "A：学习区")
C(a, 28.0, 6.0, INSET_ROW, "fluid", "A：医疗室")
C(a, 8.0, 11.7, INSET_ROW, "room", "A：独立空气循环（空气机 + 泵 + O₂ 柜 + 储罐）")
C(a, 27.6, 11.7, INSET_ROW, "energy", "A：环内配电 + 电池（经滑环供电）")
C(a, 18.5, 18.5, INSET_ROW, "room", "A：轮辐电梯")

# ---- B: ring B farm rim (lower rim; floor outward = down)
frame(625, IY, 570, IH, "B · 居住环 B / 农业外缘舱（剖面）", "50 m 宽 · 三层 · 地板朝外（图中朝下）")
b = Kit(650, IY + 84, 10.4)
bo = [(0, 0), (50, 0), (50, 34), (0, 34)]
b.shell([(20.5, 0), (25.5, 0), (25.5, 12), (20.5, 12)], [(21.1, 0), (24.9, 0), (24.9, 12), (21.1, 12)])
b.room([(21.1, 0), (24.9, 0), (24.9, 12.5), (21.1, 12.5)])
b.rect(21.4, 3.0, 3.2, 3.6, fill=EQF, stroke=AIR, sw=1.1)
bo = [(0, 12), (50, 12), (50, 34), (0, 34)]
b.shell(bo, offset(bo, -0.6))
b.room(offset(bo, -0.6))
for yy in (19.0, 26.0):
    b.plate([(0.6, yy - 0.18), (49.4, yy - 0.18), (49.4, yy + 0.18), (0.6, yy + 0.18)])
b.plate([(0.6, 33.4), (49.4, 33.4), (49.4, 34.0), (0.6, 34.0)], fill='#1b3550', stroke=AIR)
for i in range(4):                                                      # inner deck: water cycle
    b.tank(1.0 + i * 3.6, 12.8, 3.0, 5.8, FLUID, "H₂O")
b.eq(15.6, 14.4, 3.6, 4.2, art="pump", col=FLUID)
b.eq(26.4, 14.4, 3.6, 4.2, art="radiator", col=FLUID)
b.eq(30.4, 13.2, 4.6, 5.4, art="env", col=AIR)
b.eq(35.4, 13.2, 3.6, 5.4, art="o2cab", col=AIR, hazard="gas_tank")
b.eq(39.4, 13.2, 4.6, 5.4, art="battery", col=VIO)
b.eq(44.4, 13.2, 4.8, 5.4, art="gen", col=HEAT)
for i in range(5):                                                      # middle deck: food production
    b.eq(1.0 + i * 6.2, 20.0, 5.6, 5.4, art="module", col=GREEN)
b.eq(32.4, 20.0, 5.6, 5.4, art="locker", col=FLUID)
b.label(35.2, 25.8, "COLD STORE", 8, FLUID, 'middle')
b.eq(38.6, 20.0, 5.0, 5.4, art="cabinet")
b.eq(44.2, 20.0, 5.0, 5.4, art="console")
for i in range(12):                                                     # outer deck: greenhouse racks, four tiers, grow lights
    x = 0.9 + i * 4.05
    for t in range(4):
        y = 26.8 + t * 1.6
        b.rect(x, y + 1.0, 3.4, 0.35, fill='#1d2a1f', stroke=GREEN, sw=0.9)
        for j in range(4):
            b.line(x + 0.5 + j * 0.8, y + 1.0, x + 0.5 + j * 0.8, y + 0.35 + (j % 2) * 0.2, GREEN, 1.0)
        b.line(x + 0.2, y + 0.15, x + 3.2, y + 0.15, HAZ, 1.0, 0.5)
b.pipe([(0.6, 26.5), (49.4, 26.5)], FLUID, 1.2)
b.label(25.0, 36.0, "旋转重力：地板朝外 ↓", 10, DIM, 'middle')
C(b, 23.0, 4.8, INSET_ROW, "room", "B：轮辐电梯（B 环共 4 根）")
C(b, 6.0, 15.7, INSET_ROW, "fluid", "B：水循环：水箱 ×4（停机后管里有残留水）")
C(b, 17.4, 16.5, INSET_ROW, "fluid", "B：水泵 + 过滤")
C(b, 32.7, 15.9, INSET_ROW, "room", "B：辅助生命维持 + 独立空气循环")
C(b, 46.8, 15.9, INSET_ROW, "energy", "B：备用电池 + 发电机")
C(b, 12.0, 22.7, INSET_ROW, "fluid", "B：食物生产模块 ×5 + 冷库")
C(b, 20.0, 30.0, INSET_ROW, "fluid", "B：温室：12 列 × 4 层种植架 + 补光灯 + 灌溉")
C(b, 40.0, 33.7, INSET_ROW, "room", "B：外层玻璃顶")

# ---- C: a ring hub with its de-spin gear
frame(1210, IY, 520, IH, "C · 环毂与消旋机构（剖面）", "外圈随环旋转 · 中间的主轴不转 · 先消旋才能拆")
c = Kit(1300, IY + 290, 11.5)
c.shell([(0, -17), (26, -17), (26, 17), (0, 17)], [(0, -15.6), (26, -15.6), (26, 15.6), (0, 15.6)])
c.room([(0, -15.6), (26, -15.6), (26, -8.0), (0, -8.0)])
c.room([(0, 8.0), (26, 8.0), (26, 15.6), (0, 15.6)])
c.plate([(-4.0, -6.5), (30.0, -6.5), (30.0, 6.5), (-4.0, 6.5)], fill='#2a2f39')
c.room([(-4.0, -5.6), (30.0, -5.6), (30.0, 5.6), (-4.0, 5.6)])
c.label(21.0, 4.6, "主轴（不转）", 11, DIM, 'middle')
for xb in (0.6, 23.4):                                                  # main bearings
    c.rect(xb, -8.0, 2.0, 16.0, fill='#2a3140', stroke=HAZ, sw=1.2)
    for j in range(8):
        c.circ(xb + 1.0, -7.0 + j * 2.0, 0.55, fill='none', stroke=HAZ, sw=0.9)
c.rect(4.0, -8.0, 3.0, 1.5, fill=EQF, stroke=HEAT, sw=1.2)              # slip ring (power across the joint)
c.rect(4.0, 6.5, 3.0, 1.5, fill=EQF, stroke=HEAT, sw=1.2)
c.rect(8.0, -8.0, 2.4, 1.5, fill=EQF, stroke=AIR, sw=1.2)               # rotary air seal
c.rect(8.0, 6.5, 2.4, 1.5, fill=EQF, stroke=AIR, sw=1.2)
for x in (12.0, 17.0):                                                  # de-spin motors / brakes
    c.eq(x, -14.8, 3.8, 3.4, art="eng_front", col=HEAT)
    c.eq(x, 11.4, 3.8, 3.4, art="eng_front", col=HEAT)
c.eq(2.0, -14.8, 4.6, 3.4, art="swb", col=HEAT)
c.eq(2.0, 11.4, 4.6, 3.4, art="cap", col=VIO)
c.eq(21.5, -14.8, 3.6, 3.4, art="pump", col=FLUID)
c.rect(10.4, -2.4, 5.2, 4.8, fill='none', stroke=AIR, sw=1.3, dash='4 3')
c.label(13.0, -3.0, "转运气闸", 9, AIR, 'middle')
for sg in (-1, 1):
    c.shell([(10.6, sg * 17.0), (15.4, sg * 17.0), (15.4, sg * 19.5), (10.6, sg * 19.5)], [(11.2, sg * 17.0), (14.8, sg * 17.0), (14.8, sg * 19.5), (11.2, sg * 19.5)])
    c.rect(11.4, sg * 18.3 - 0.9, 3.2, 1.8, fill=EQF, stroke=AIR, sw=1.0)
for a0, a1, y in ((200, 340, -18.4), (20, 160, 18.4)):
    pts = [(13.0 + 15.0 * math.cos(math.radians(t)), y * 0.0 + 18.6 * math.sin(math.radians(t))) for t in range(a0, a1 + 1, 6)]
    c.pline(pts, HAZ, 1.4, 0.8, dash='6 4')
c.label(13.0, -21.0 + 0.0, "", 10, HAZ)
C(c, 1.6, 0.0, INSET_ROW, "haz", "C：主轴承（滚子）")
C(c, 5.5, -7.25, INSET_ROW, "haz", "C：滑环（电力跨过旋转面）")
C(c, 9.2, 7.25, INSET_ROW, "room", "C：旋转气密封")
C(c, 13.9, -13.1, INSET_ROW, "haz", "C：消旋电机 / 制动器 ×4（停转前必须先把环刹停）")
C(c, 4.3, -13.1, INSET_ROW, "energy", "C：消旋控制柜 + 制动电容")
C(c, 13.0, 0.0, INSET_ROW, "room", "C：转运气闸（转 ↔ 不转之间）")
C(c, 13.0, 18.3, INSET_ROW, "room", "C：轮辐根部电梯平台")

# ---- D: power core
frame(1745, IY, 590, IH, "D · 动力核心（剖面）", "90 m · 屏蔽舱 · 主堆已停，辅助电网仍活着")
d = Kit(1770, IY + 290, 5.9)
dc = [(0, -28), (90, -28), (90, 28), (0, 28)]
d.shell(dc, offset(dc, -3.0), fill=ARM)
d.room(offset(dc, -3.0))
d.circ(27.0, 0.0, 19.0, fill='#2a2f39', stroke=DIM, sw=1.2)
d.circ(27.0, 0.0, 14.0, fill=EQF, stroke=HEAT, sw=1.6)
for i in range(7):
    d.rect(17.5 + i * 2.8, -12.0, 1.2, 6.0, fill='none', stroke=HEAT, sw=0.8)
for i in range(6):
    d.rect(18.0 + i * 3.0, -24.5, 1.4, 5.0, fill=EQF, stroke=HEAT, sw=0.9)
d.label(27.0, 4.5, "MAIN REACTOR", 11, HEAT, 'middle')
for sg in (-1, 1):                                                      # primary pumps, heat exchangers
    d.eq(46.0, sg * 13.0 - 4.0, 7.0, 8.0, art="pump", col=FLUID)
    d.eq(54.5, sg * 13.0 - 5.0, 8.0, 10.0, art="radiator", col=FLUID)
    d.pipe([(41.0, sg * 6.0), (46.0, sg * 9.0)], FLUID, 1.8)
for i in range(2):                                                      # turbine-generators
    d.eq(64.0, -22.0 + i * 11.0, 14.0, 9.0, art="gen", col=HEAT)
d.circ(72.0, 10.0, 7.0, fill='#2a2f39', stroke=DIM, sw=1.1)
d.circ(72.0, 10.0, 5.0, fill=EQF, stroke=HEAT, sw=1.3)
d.label(72.0, 10.6, "SEC", 10, HEAT, 'middle')
for i in range(5):                                                      # distribution centre
    d.eq(64.0 + i * 4.2, 19.0, 3.6, 5.0, art="swb", col=HEAT)
d.eq(4.0, 18.0, 10.0, 6.0, art="battery", col=VIO)
d.eq(4.0, 10.0, 10.0, 6.0, art="battery", col=VIO)
d.label(9.0, 25.4, "AUX GRID", 9, VIO, 'middle')
d.eq(4.0, -24.0, 9.0, 8.0, art="swb", col=HEAT)
C(d, 27.0, 0.0, INSET_ROW, "haz", "D：主反应堆（已停）+ 控制棒驱动")
C(d, 49.5, -13.0, INSET_ROW, "fluid", "D：一回路泵 ×2 + 换热器 ×2")
C(d, 71.0, -17.5, INSET_ROW, "haz", "D：涡轮发电机 ×2")
C(d, 72.0, 10.0, INSET_ROW, "haz", "D：次级反应堆")
C(d, 72.0, 21.5, INSET_ROW, "haz", "D：电力分配中心（开关柜 ×5）")
C(d, 9.0, 16.0, INSET_ROW, "energy", "D：辅助电网电池组（主堆停了它还活着）")

# ---- E: industry block and hangar
frame(2350, IY, 610, IH, "E · 工业与仓储 / 机库（剖面）", "120 m · 三层 · 机库停两艘 S-09 级穿梭机")
e = Kit(2370, IY + 290, 4.75)
eo = [(0, -36), (120, -36), (120, 36), (0, 36)]
e.shell(eo, offset(eo, -1.2))
e.room(offset(eo, -1.2))
for yy in (-18.0, 18.0):
    e.plate([(1.2, yy - 0.4), (118.8, yy - 0.4), (118.8, yy + 0.4), (1.2, yy + 0.4)])
e.plate([(-2.0, -6.5), (122.0, -6.5), (122.0, 6.5), (-2.0, 6.5)], fill='#2a2f39')
e.label(60.0, 1.0, "主轴穿过", 10, DIM, 'middle')
for i in range(6):                                                      # upper deck: fabrication and repair stations
    x = 2.0 + i * 9.4
    e.eq(x, -27.0, 7.4, 8.4, art="panel")
    e.eq(x + 1.0, -33.8, 5.4, 5.8, art="arm")
for i in range(6):                                                      # warehouse racks
    for j in range(3):
        e.eq(60.0 + i * 9.6, -34.6 + j * 5.4, 8.8, 5.0, art="cargo")
for i in range(4):                                                      # middle-lower: engineering bay
    e.eq(2.0 + i * 7.2, -16.6, 6.4, 9.0, art="console" if i < 2 else "swb")
for i in range(5):
    e.eq(62.0 + i * 11.2, -16.6, 10.0, 9.4, art="locker")
for sx in (6.0, 38.0):                                                  # hangar: two shuttles
    e.circ(sx + 4.2, 27.0, 4.2, fill=EQF, stroke=AIR, sw=1.2)
    e.rect(sx + 8.0, 25.4, 16.0, 3.2, fill=EQF, stroke=EQ, sw=1.0)
    e.plate([(sx + 22.0, 24.0), (sx + 26.0, 22.0), (sx + 26.0, 32.0), (sx + 22.0, 30.0)], fill='#323844')
e.rect(2.0, 35.0, 64.0, 2.0, fill='#2a3140', stroke=AIR, sw=1.3)
e.label(34.0, 39.6, "HANGAR DOOR", 9, AIR, 'middle')
for i in range(5):                                                      # vehicle bay: small work vehicles + chargers
    e.eq(72.0 + i * 9.2, 22.0, 8.0, 6.0, art="aux")
    e.eq(73.0 + i * 9.2, 29.0, 3.0, 5.0, art="battery", col=VIO)
C(e, 30.0, -25.0, INSET_ROW, "sys", "E：维修工位 ×6（机械臂 + 加工台）")
C(e, 89.0, -27.0, INSET_ROW, "sys", "E：备件仓（货架 6 × 3）")
C(e, 16.0, -12.0, INSET_ROW, "sys", "E：工程舱")
C(e, 88.0, -12.0, INSET_ROW, "sys", "E：工具 / 材料柜")
C(e, 26.0, 27.0, INSET_ROW, "room", "E：机库：S-09 级穿梭机 ×2（各自带燃料与电池）")
C(e, 90.0, 25.0, INSET_ROW, "energy", "E：作业车 ×5 + 充电桩")
C(e, 34.0, 36.0, INSET_ROW, "room", "E：机库大门（外开）")

body = k.svg() + a.svg() + b.svg() + c.svg() + d.svg() + e.svg() + ''.join(INSETS)
sheet('ark01.html', W, H, 'ARK-01「远航者」殖民飞船 · 约 600 m · 结构图（设计稿 v2）',
      ['中央长主轴（440 m）+ 两个旋转居住环（半径 105 / 110 m，进坞时还在转）+ 工业块 + 屏蔽动力核心与 220 m 散热翼 + 五联引擎 —— 一座会飞的殖民地。',
       '全游戏最综合的工程：多系统并行、多日拆解。下方 A–E 为放大剖面；左下角 PT-34 与 GR-7 按同一比例画出。'],
      body, lambda x, y: (x, y), calls, zones_px, legend_cols=4, auto=True, scale_at=None)
print('ok')
