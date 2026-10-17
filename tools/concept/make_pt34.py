# PT-34 "Falcon" decommissioned patrol ship, 134 m: concept structure sheet.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

ARM = '#4a505c'
k = Kit(90, 600, 16.6)
# ---------------- the armoured hull: a sharp faceted wedge, armour outside, a pressure hull inside,
# the maintenance tunnels in between
outer = [(0.0, 0.8), (14.0, -5.6), (34.0, -9.4), (56.0, -10.2), (104.0, -10.2), (113.0, -8.0), (113.0, 7.4), (104.0, 9.0), (40.0, 9.0), (16.0, 6.0)]
armour_in = offset(outer, 1.0)
k.shell(outer, armour_in, fill=ARM)
for i in range(len(outer)):
    k.line(outer[i][0], outer[i][1], armour_in[i][0], armour_in[i][1], '#22262d', 1.6)
for x in range(20, 112, 7):
    k.line(x, -10.3 if 56 <= x <= 104 else -9.0, x, -9.2 if 56 <= x <= 104 else -8.2, '#22262d', 1.4)
    k.line(x, 9.0, x, 8.0, '#22262d', 1.4)
# armour bolts that only show once the plate next to them is off (dashed: behind armour)
for x in range(24, 108, 7):
    for y in (-9.6 if 56 <= x <= 104 else -8.6, 8.5):
        a = k.P(x + 3.5, y)
        k.o.append(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="2.2" fill="none" stroke="#b4c0cf" stroke-width="1" stroke-dasharray="2 1.5"/>')
tun_top = [(40.0, -8.4), (106.0, -8.4), (106.0, -7.2), (40.0, -7.2)]
tun_bot = [(42.0, 6.7), (106.0, 6.7), (106.0, 7.9), (42.0, 7.9)]
press = offset(armour_in, 0.45)
k.shell(armour_in, press)
k.room(press)
for t in (tun_top, tun_bot):
    k.plate([(t[0][0], t[0][1] - 0.2), (t[1][0], t[1][1] - 0.2), (t[2][0], t[2][1] + 0.2), (t[3][0], t[3][1] + 0.2)], fill='#2c313b')
    k.room(t)
k.label(73.0, -7.6, "MAINTENANCE TUNNEL (between armour and pressure hull)", 9, AIR, 'middle')
k.label(73.0, 7.5, "MAINTENANCE TUNNEL", 9, AIR, 'middle')
k.cable([(42.0, -7.85), (104.0, -7.85)], HEAT)                     # a control line in the tunnel nobody remembers
k.door(44.0, -8.35, 0.25, 1.1)
k.door(80.0, -8.35, 0.25, 1.1)
# three decks between the tunnels (upper / mid / lower), bulkheads with an isolation door on each deck
DK = [(-2.5, -2.1), (2.1, 2.5)]
for x0, x1 in ((34.2, 90.0), (104.0, 111.3)):
    for y0, y1 in DK:
        k.plate([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
k.plate([(11.0, 0.0), (34.0, 0.0), (34.0, 0.3), (11.0, 0.3)])
for x in (34.0, 48.0, 64.0, 90.0, 104.0):
    k.plate([(x - 0.2, -7.2 if x > 36 else -7.8), (x + 0.2, -7.2 if x > 36 else -7.8), (x + 0.2, 6.6), (x - 0.2, 6.6)])
    for yd in (-2.5, 2.1, 6.5):
        if x == 34.0 and yd == 6.5:
            continue
        k.door(x - 0.17, yd - 1.9, 0.34, 1.9)
for x in (46.6, 61.6, 87.6, 108.4):                                     # ladders through deck hatches
    k.eq(x, -2.5, 0.8, 4.6, art="ladder")
    k.rect(x - 0.1, -2.5, 1.0, 0.4, fill='#2a3140', stroke=AIR, sw=1.0)


def shell(x, y, w=0.42, h=1.15, col=HAZ):
    """one round of gun ammunition standing in its rack: casing and pointed projectile"""
    k.poly([(x, y + h), (x, y + h * 0.42), (x + w * 0.5, y), (x + w, y + h * 0.42), (x + w, y + h)], fill=EQF, stroke=col, w=0.9)
    k.line(x, y + h * 0.55, x + w, y + h * 0.55, col, 0.7, 0.6)


def missile(x, y, l, d=0.62, vertical=False, col=HAZ):
    if vertical:
        k.poly([(x, y + l), (x, y + 0.9), (x + d / 2, y), (x + d, y + 0.9), (x + d, y + l), (x + d + 0.25, y + l + 0.3), (x - 0.25, y + l + 0.3)], fill=EQF, stroke=col, w=1.0)
    else:
        k.poly([(x, y), (x + l - 0.9, y), (x + l, y + d / 2), (x + l - 0.9, y + d), (x, y + d), (x - 0.3, y + d + 0.25), (x - 0.3, y - 0.25)], fill=EQF, stroke=col, w=1.0)


# ---------------- the bridge: raised, faceted, behind the forward guns; a mast with the search radar
br = [(36.0, -9.1), (38.5, -13.4), (49.0, -13.8), (52.0, -10.0)]
k.plate(br, fill=ARM)
k.room(offset([(37.2, -9.6), (39.1, -12.9), (48.5, -13.25), (50.9, -9.7)], 0.05))
k.plate([(38.5, -13.4), (43.0, -13.6), (43.0, -13.15), (38.9, -12.98)], fill='#1b3550', stroke=AIR)
for i in range(3):
    k.seat(39.6 + i * 2.6, -9.75, 1.4)
k.eq(46.0, -12.5, 1.7, 2.6, art="nav_rack", col=HEAT)               # fire control
k.label(46.85, -9.5, "FIRE CTL", 8, HEAT, 'middle')
k.eq(48.0, -12.0, 1.6, 2.1, art="swb", col=VIO)                     # crypto comm cabinet
k.label(48.8, -9.5, "CRYPTO", 8, VIO, 'middle')
k.line(45.0, -13.7, 45.0, -17.6, HULLS, 2.4)
k.ell(45.0, -18.1, 2.6, 0.55, fill=EQF, stroke=VIO, sw=1.3)
k.rect(44.3, -16.4, 1.4, 0.8, fill=EQF, stroke=VIO, sw=1.0)
# ---------------- forward weapons: main gun, hoist, VLS cells, torpedo / missile tubes, reloads, shell magazine
k.plate([(17.0, -7.4), (27.0, -7.4), (26.0, -9.6), (18.2, -9.6)], fill=ARM)
k.ell(22.0, -9.8, 3.6, 1.4, fill='#3a404b', stroke=HULLS, sw=1.4)
k.plate([(18.6, -10.4), (4.0, -11.4), (4.0, -10.8), (18.6, -9.8)], fill='#3a404b')     # the barrel
k.plate([(18.6, -10.6), (15.6, -10.75), (15.6, -9.65), (18.6, -9.6)], fill='#2c313b')
k.eq(19.2, -6.0, 4.6, 2.2, art="eng_front", col=HEAT)                # gun mount base (training gear)
k.label(21.5, -3.5, "GUN MOUNT", 9, HEAT, 'middle')
for i in range(4):                                                     # ready-use rounds round the mount
    shell(19.4 + i * 0.55, -2.6)
for i in range(6):                                                     # the hoist: from the magazine up to the gun
    k.rect(23.9, -3.4 + i * 1.25, 0.9, 0.95, fill=EQF, stroke=HAZ, sw=1.0)
    shell(24.13, -3.3 + i * 1.25, 0.44, 0.75)
k.line(25.0, -3.6, 25.0, 4.4, HAZ, 1.6)
k.eq(13.0, -2.6, 3.6, 2.3, art="radiator", col=FLUID)                # weapon cooling module
k.pipe([(16.6, -1.4), (19.2, -4.6)], FLUID, 1.6)
for i in range(5):                                                     # vertical launch cells, hatches flush in the armour
    x = 27.0 + i * 1.32
    k.rect(x, -8.4, 1.18, 8.1, fill='#20252e', stroke=DIM, sw=1.0)
    missile(x + 0.28, -7.6, 6.6, 0.62, vertical=True)
    k.rect(x - 0.05, -8.9 - i * 0.03, 1.28, 0.32, fill=ARM, stroke=HAZ, sw=1.0)
k.label(30.3, -9.6, "VLS ×5", 9, HAZ, 'middle')
for y in (0.55, 1.55):                                                 # two tubes in the bow, a round in each
    x0 = 6.2 if y < 1 else 9.0
    k.rect(x0, y - 0.05, 15.2 - x0, 0.82, fill='#20252e', stroke=DIM, sw=1.0, rx=0.3)
    missile(x0 + 0.5, y + 0.05, 14.0 - x0, 0.6)
    k.rect(15.2, y - 0.1, 0.5, 0.92, fill=ARM, stroke=HAZ, sw=1.0)   # breech door
for j in range(3):                                                     # reload rack
    missile(16.6, 0.7 + j * 1.15, 5.6, 0.6)
k.rect(16.0, 0.45, 6.6, 3.6, fill='none', stroke=FAINT, sw=1.0, dash='4 3')
k.label(19.3, 4.6, "RELOADS", 8, HAZ, 'middle')
k.rect(26.0, 0.6, 7.6, 5.2, fill='#1f1b16', stroke=HAZ, sw=1.4)     # the shell magazine: armoured box, racks of rounds
for row in range(3):
    for i in range(13):
        shell(26.3 + i * 0.56, 0.85 + row * 1.6, 0.42, 1.25)
    k.line(26.1, 2.2 + row * 1.6, 33.5, 2.2 + row * 1.6, HAZ, 0.8, 0.7)
k.pipe([(26.2, 0.75), (33.4, 0.75)], FLUID, 1.4)                       # sprinkler / flood main
k.eq(33.0, -1.6, 0.8, 1.2, art="pump", col=FLUID)
k.label(29.8, 6.5, "MAGAZINE (flood valve)", 9, HAZ, 'middle')
# ---------------- 34–48 under the bridge: CIC, armory + comms, damage control
for i in range(3):
    k.eq(34.8 + i * 4.0, -5.6, 1.4, 1.5, art="console")
    k.seat(36.3 + i * 4.0, -2.5, 1.4, facing=-1)
k.eq(46.2, -6.6, 1.6, 2.4, art="nav_rack", col=VIO)
k.label(41.0, -6.4, "CIC", 10, AIR, 'middle')
for i in range(4):                                                     # armory: weapon lockers
    k.eq(34.6 + i * 1.5, -1.8, 1.3, 3.7, art="locker", col=HAZ)
k.label(37.5, 1.9, "ARMORY", 8, HAZ, 'middle')
for i in range(3):                                                     # comms room
    k.eq(40.8 + i * 1.9, -1.8, 1.7, 3.7, art="nav_rack", col=VIO)
k.tank(34.7, 2.8, 1.6, 3.5, FLUID)                              # damage control
k.tank(36.6, 2.8, 1.6, 3.5, FLUID)
k.tank(38.6, 2.8, 1.1, 3.5, AIR, "O₂")
k.tank(39.9, 2.8, 1.1, 3.5, AIR, "O₂")
k.eq(41.4, 2.8, 2.6, 3.5, art="cabinet")
k.eq(44.2, 3.4, 2.2, 2.9, art="pump", col=FLUID)
k.label(41.0, 7.0, "DAMAGE CONTROL", 8, FLUID, 'middle')
# ---------------- 48–64: twin distribution, sensors, main computer, electronic warfare
k.eq(48.6, -6.6, 3.0, 3.9, art="swb", col=HEAT)
k.label(50.1, -2.85, "DIST-A", 9, HEAT, 'middle')
for i in range(4):
    k.eq(52.0 + i * 2.3, -6.6, 1.9, 3.9, art="nav_rack", col=VIO)       # sensor processing
k.label(56.3, -2.85, "SENSOR PROC", 9, VIO, 'middle')
for i in range(4):
    k.eq(48.6 + i * 2.2, -1.8, 1.9, 3.7, art="nav_rack", col=VIO)       # main computer
k.label(52.8, 2.0, "MAIN CPU", 8, VIO, 'middle')
k.eq(58.0, -1.6, 1.6, 1.4, art="console")                              # EW station
k.seat(59.7, 2.1, 1.4, facing=-1)
k.eq(61.0, -1.8, 0.5, 3.7, art="cabinet", col=VIO)
k.eq(48.6, 2.8, 3.0, 3.6, art="swb", col=HEAT)
k.label(50.1, 6.8, "DIST-B", 9, HEAT, 'middle')
k.eq(52.0, 2.8, 4.0, 3.6, art="battery", col=VIO)
k.tank(56.4, 2.8, 2.2, 3.6, FLUID, "H₂O")
k.tank(58.9, 2.8, 2.2, 3.6, FLUID, "H₂O")
k.cable([(51.6, -4.6), (90.0, -4.6)], HEAT)
k.cable([(51.6, 4.6), (90.0, 4.6)], HEAT)
# ---------------- 64–90: berths, mess, sick bay, weapon capacitors, CIWS magazine, stores
for col in range(6):                                                   # three-high crew berths
    for j in range(3):
        k.eq(64.6 + col * 3.0, -6.8 + j * 1.45, 2.8, 1.3, art="bunk")
k.eq(82.8, -6.6, 2.0, 3.9, art="locker")
k.eq(85.0, -6.6, 2.0, 3.9, art="locker")
for i in range(2):                                                     # mess tables
    k.eq(64.6 + i * 3.6, -0.6, 3.0, 1.0, art="console")
k.eq(71.8, -1.8, 2.2, 3.7, art="cabinet")
k.label(68.0, 1.9, "MESS / GALLEY", 8, DIM, 'middle')
k.eq(74.4, -0.4, 2.8, 1.0, art="bunk")                                 # sick bay
k.eq(74.4, 0.8, 2.8, 1.1, art="cabinet", col=FLUID)
k.label(75.8, -0.8, "SICK BAY", 8, FLUID, 'middle')
k.eq(78.0, -1.9, 2.6, 3.8, art="cap", col=VIO)                         # weapon capacitors (own circuit)
k.eq(80.9, -1.9, 2.6, 3.8, art="cap", col=VIO)
k.label(80.6, 2.0, "WPN CAP", 8, VIO, 'middle')
k.eq(84.2, -1.8, 3.0, 3.7, art="swb", col=VIO)
k.label(85.7, 2.0, "WPN DIST", 8, VIO, 'middle')
k.ell(66.0, 9.3, 2.4, 0.9, fill='#3a404b', stroke=HULLS, sw=1.3)      # the ventral point-defence turret
k.plate([(64.8, 9.8), (56.0, 10.6), (56.0, 10.2), (64.8, 9.4)], fill='#3a404b')
for i in range(4):                                                     # its ammunition drums
    k.circ(65.4 + i * 1.6, 4.4, 0.72, fill=EQF, stroke=HAZ, sw=1.2)
    k.circ(65.4 + i * 1.6, 4.4, 0.3, fill='none', stroke=HAZ, sw=0.8)
k.eq(71.7, 2.8, 1.8, 3.6, art="cap", col=VIO)
k.cable([(72.6, 6.4), (72.6, 7.3), (60.0, 7.3)], HEAT)                 # the control line through the lower tunnel
for i in range(3):                                                     # stores: food and spares
    k.eq(74.0 + i * 3.1, 2.9, 2.8, 3.4, art="cargo", tag="STORES")
k.eq(83.4, 2.8, 3.0, 3.6, art="cabinet")
k.eq(86.6, 2.8, 3.0, 3.6, art="locker")
# the dorsal missile launcher box and decoy launchers on the armour
k.plate([(73.0, -10.2), (85.0, -10.2), (84.2, -12.8), (73.8, -12.8)], fill=ARM)
for i in range(6):
    k.rect(74.2 + i * 1.62, -12.6, 1.4, 2.3, fill='#20252e', stroke=HAZ, sw=1.0)
    k.circ(74.9 + i * 1.62, -11.45, 0.45, fill=EQF, stroke=HAZ, sw=1.0)
for x in (60.0, 98.0):
    k.rect(x, -11.0, 1.6, 0.8, fill=EQF, stroke=HAZ, sw=1.1)
    for j in range(3):
        k.circ(x + 0.3 + j * 0.5, -10.6, 0.16, fill='none', stroke=HAZ, sw=0.8)
# ---------------- mid-aft: reactor and backup power, armour-internal access pipes
k.rect(91.0, -6.2, 11.0, 12.0, fill='#1c2129', stroke=HULLS, sw=1.6, rx=1.2)       # shielding
k.rect(92.4, -4.6, 8.2, 8.8, fill=EQF, stroke=HEAT, sw=1.6, rx=3.6)                # the reactor vessel
for i in range(5):
    k.line(93.2 + i * 1.6, -3.6, 93.2 + i * 1.6, 3.2, FAINT, 1.0)
for i in range(4):                                                     # control-rod drives on the lid
    k.rect(93.6 + i * 1.6, -6.0, 0.6, 1.4, fill=EQF, stroke=HEAT, sw=0.9)
k.label(96.5, 0.2, "REACTOR", 13, HEAT, 'middle')
k.eq(104.6, -6.6, 3.0, 3.9, art="gen", col=HEAT)                       # backup power
k.eq(108.0, -6.0, 2.6, 3.3, art="pump", col=FLUID)
k.eq(104.6, -1.8, 3.4, 3.7, art="battery", col=VIO)
k.eq(108.4, -1.6, 2.4, 1.6, art="swb", col=HEAT)
k.tank(104.6, 2.8, 2.9, 3.4, HAZ, "PROP")
k.tank(107.8, 2.8, 2.9, 3.4, HAZ, "PROP")
for y in (-5.6, 5.0):
    k.pipe([(90.2, y), (104.2, y)], FLUID, 2.4)
k.pipe([(102.0, -0.4), (104.6, -0.4)], FLUID, 1.8)
# ---------------- tail: heavy beams, thrust-vectoring gimbals, two big engines
for sg in (-1, 1):
    k.plate([(110.0, sg * 7.6), (130.0, sg * 6.4), (130.0, sg * 7.6), (110.0, sg * 9.0)], fill=ARM)
k.plate([(113.0, -8.0), (115.0, -8.0), (115.0, 7.4), (113.0, 7.4)], fill=ARM)
for yc in (-3.2, 3.0):
    k.eq(115.0, yc - 2.0, 4.0, 4.0, art="eng_core")
    for i in range(3):
        k.ell(119.6, yc, 0.4 + i * 0.25, 2.2 + i * 0.3, fill='none', stroke=HAZ, sw=1.2)
    k.peq([(120.0, yc - 1.8), (133.6, yc - 3.0), (133.6, yc + 3.0), (120.0, yc + 1.8)])
    for x in (123.0, 126.0, 129.0, 132.0):
        k.line(x, yc - 1.8 - (x - 120) * 0.09, x, yc + 1.8 + (x - 120) * 0.09, FAINT, 1.0)
    k.pline([(115.5, yc - 2.6), (119.4, yc - 2.0)], EQ, 3)
    k.pline([(115.5, yc + 2.6), (119.4, yc + 2.0)], EQ, 3)
for x in (40.0, 75.0, 98.0):
    a, b = k.P(x, 9.0)
    k.o.append(f'<polygon points="{a-14:.0f},{b+56:.0f} {a+14:.0f},{b+56:.0f} {a+7:.0f},{b+4:.0f} {a-7:.0f},{b+4:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

calls = []


def c(x, y, row, kind, text):
    calls.append((0, x, y, 0, 210 if row == 0 else 868, kind, text))


c(41.0, -10.5, 0, "sys", "舰桥：战术座席 ×3")
c(46.85, -11.2, 0, "haz", "火控系统")
c(48.8, -11.0, 0, "energy", "通讯加密柜")
c(45.0, -18.1, 0, "energy", "搜索雷达桅杆")
c(10.0, -11.0, 0, "haz", "舰炮 + 炮塔")
c(21.5, -5.0, 0, "haz", "舰炮基座（转动机构）+ 待发弹")
c(25.0, -1.0, 0, "haz", "弹药升降机（弹库 → 炮）")
c(14.8, -1.4, 0, "fluid", "武器冷却模块")
c(29.6, -5.0, 0, "haz", "垂直发射单元 ×5（每格一枚导弹，舱盖在装甲上）")
c(10.0, 0.95, 1, "haz", "舰首发射管 ×2（管里各一枚）")
c(19.3, 1.85, 1, "haz", "备弹架（3 枚）")
c(29.8, 3.0, 1, "haz", "主弹药库：3 排 × 13 发（爆炸物）")
c(29.8, 0.75, 1, "fluid", "弹库喷淋 / 注水阀")
c(6.0, 1.6, 1, "struct", "厚装甲外壳（多层，切割极慢）")
c(31.0, -8.6, 0, "struct", "装甲板后面藏着的固定件（虚线螺栓）")
c(41.0, -5.0, 0, "room", "作战情报中心 CIC")
c(37.5, 0.0, 1, "haz", "军械库（武器柜 ×4）")
c(42.7, 0.0, 1, "energy", "通讯舱")
c(36.5, 4.5, 1, "fluid", "损管：泡沫罐、氧瓶、损管泵")
c(73.0, -7.8, 0, "room", "维护通道：夹在装甲层与耐压壳之间（上下各一条）")
c(90.0, -7.85, 0, "haz", "隐藏通道里没断开的控制线路")
c(50.1, -4.6, 0, "energy", "主配电 A（A 网）")
c(50.1, 4.6, 1, "energy", "主配电 B + B 网电池（两张独立电网）")
c(56.3, -4.6, 0, "energy", "传感器处理舱")
c(52.8, 0.0, 1, "energy", "主计算机")
c(58.8, -0.9, 0, "energy", "电子战席位")
c(57.5, 4.6, 1, "fluid", "淡水罐 ×2")
c(70.0, -5.0, 0, "sys", "三层舰员铺位 ×18 + 储物柜")
c(68.0, -0.1, 1, "sys", "餐厅 / 厨房")
c(75.8, 0.0, 1, "fluid", "医务室")
c(80.6, 0.0, 0, "energy", "独立武器电容（外部标准接口隔离不了）+ 武器配电")
c(79.0, -11.5, 0, "haz", "背部导弹发射箱（6 格）")
c(60.8, -10.6, 0, "haz", "诱饵弹发射器 ×2")
c(66.0, 9.3, 1, "haz", "腹部近防炮塔 + 弹鼓 ×4 + 局部电容")
c(78.6, 4.6, 1, "sys", "补给库：食品 + 备件")
c(96.5, 2.0, 1, "haz", "反应堆 / 主电源（屏蔽层内，控制棒驱动在顶上）")
c(106.1, -4.6, 0, "haz", "备用动力：发电机 + 电池 + 配电")
c(106.1, 4.4, 1, "haz", "推进剂罐 ×2")
c(97.0, 5.0, 1, "fluid", "装甲内部检修管道")
c(103.98, -3.4, 0, "room", "局部隔离门（每层每段一道）")
c(119.6, -3.2, 0, "haz", "推力矢量机构（万向环 + 作动杆）")
c(127.0, 3.0, 1, "sys", "大型推进器 ×2")
c(120.0, 8.0, 1, "struct", "厚重尾梁")
zones = [(0.0, 34.0, 11.6, "② 前武器段", "haz"), (34.0, 52.0, 11.6, "① 舰桥（上方）+ CIC", "room"), (52.0, 90.0, 11.6, "③ 中央主舰体（三层）", "energy"),
         (90.0, 113.0, 11.6, "④ 中后设备段", "haz"), (113.0, 133.6, 11.6, "⑤ 尾推进段", "struct")]
sheet('pt34.html', 2400, 1330, 'PT-34「隼鹰」退役巡逻舰 · 134 m · 结构图（设计稿 v2）',
      ['尖锐楔形舰首，厚装甲外壳，舰身有炮塔、垂直发射单元、背部发射箱和腹部近防炮，整体线条锋利、紧凑、压迫感强。',
       '军舰不是「大一点的民船」：舰体里塞满弹药、补给和武器子系统；隐藏维护路线、厚装甲、两套分离电网 —— 第一次需要「找路」。'], k.svg(), k.P, calls, zones, legend_cols=3, auto=True, scale_at=(0.0, -16.0), scale_m=10)
print('ok')
