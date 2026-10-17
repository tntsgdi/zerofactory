# PT-34 "Falcon" decommissioned patrol ship, 134 m: concept structure sheet.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

ARM = '#4a505c'
k = Kit(90, 540, 16.6)
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
# internal bulkheads with local isolation doors
for x in (34.0, 48.0, 64.0, 90.0, 104.0):
    yt = -6.7 if x > 40 else -6.2
    k.plate([(x - 0.2, yt), (x + 0.2, yt), (x + 0.2, 6.2), (x - 0.2, 6.2)])
    k.door(x - 0.17, 0.4, 0.34, 2.4)
k.plate([(48.0, -0.2), (104.0, -0.2), (104.0, 0.2), (48.0, 0.2)])
# ---------------- the bridge: raised, faceted, behind the forward guns
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
# ---------------- forward weapons: the main gun on its mount, ammunition feed, weapon cooling, the magazine
k.plate([(17.0, -7.4), (27.0, -7.4), (26.0, -9.6), (18.2, -9.6)], fill=ARM)
k.ell(22.0, -9.8, 3.6, 1.4, fill='#3a404b', stroke=HULLS, sw=1.4)
k.plate([(18.6, -10.4), (4.0, -11.4), (4.0, -10.8), (18.6, -9.8)], fill='#3a404b')     # the barrel
k.plate([(18.6, -10.6), (15.6, -10.75), (15.6, -9.65), (18.6, -9.6)], fill='#2c313b')
k.eq(19.2, -6.0, 5.6, 2.2, art="eng_front", col=HEAT)                # gun mount base (training gear)
k.label(22.0, -3.5, "GUN MOUNT", 9, HEAT, 'middle')
for i in range(6):                                                     # ammunition feed: a hoist from the magazine
    k.rect(23.0, -3.2 + i * 1.3, 1.2, 1.0, fill=EQF, stroke=HAZ, sw=1.0)
k.line(24.2, -3.2, 24.2, 4.6, HAZ, 1.6)
k.eq(10.6, -2.8, 4.6, 2.6, art="radiator", col=FLUID)                # weapon cooling module
k.eq(13.5, 1.0, 10.5, 4.6, art="cargo", tag="MAGAZINE", col=HAZ)     # magazine (explosive)
k.label(18.75, 6.4, "弹药库", 10, HAZ, 'middle')
k.pipe([(15.2, -1.6), (19.2, -4.4)], FLUID, 1.6)
# ---------------- central hull: twin main power distribution, independent weapon capacitors, sensor processing
k.eq(49.0, -6.4, 3.2, 5.6, art="swb", col=HEAT)
k.label(50.6, -0.6, "DIST-A", 9, HEAT, 'middle')
k.eq(49.0, 1.0, 3.2, 4.8, art="swb", col=HEAT)
k.label(50.6, 6.3, "DIST-B", 9, HEAT, 'middle')
k.cable([(52.2, -3.0), (100.0, -3.0)], HEAT)
k.cable([(52.2, 3.0), (100.0, 3.0)], HEAT)
for i in range(4):
    k.eq(54.0 + i * 2.3, -6.4, 1.9, 4.6, art="nav_rack", col=VIO)     # sensor processing bay
k.label(58.4, -1.2, "SENSOR PROC", 9, VIO, 'middle')
k.eq(65.0, -6.4, 2.6, 4.0, art="cap", col=VIO)                       # weapon capacitors (own circuit)
k.eq(68.0, -6.4, 2.6, 4.0, art="cap", col=VIO)
k.label(67.3, -1.8, "WPN CAP (own circuit)", 9, VIO, 'middle')
# the ventral point-defence turret and its local capacitor
k.ell(66.0, 9.3, 2.4, 0.9, fill='#3a404b', stroke=HULLS, sw=1.3)
k.plate([(64.8, 9.8), (56.0, 10.6), (56.0, 10.2), (64.8, 9.4)], fill='#3a404b')
k.eq(64.4, 2.4, 3.2, 3.6, art="eng_front", col=HEAT)
k.eq(70.6, 1.0, 2.2, 3.0, art="cap", col=VIO)
k.cable([(69.4, -2.4), (69.4, 2.0), (67.6, 2.0)], VIO)
k.cable([(71.7, 4.0), (71.7, 7.2), (60.0, 7.2)], HEAT)                # the control line through the lower tunnel
for i in range(5):
    k.eq(74.0 + i * 3.0, 1.2, 2.5, 4.8, art="cabinet")                 # stores and crew lockers
for i in range(4):
    k.eq(74.0 + i * 3.5, -6.4, 3.0, 4.4, art="bunk")
# ---------------- mid-aft: reactor and backup power, armour-internal access pipes
k.rect(91.0, -6.2, 11.0, 12.0, fill='#1c2129', stroke=HULLS, sw=1.6, rx=1.2)       # shielding
k.rect(92.4, -4.6, 8.2, 8.8, fill=EQF, stroke=HEAT, sw=1.6, rx=3.6)                # the reactor vessel
for i in range(5):
    k.line(93.2 + i * 1.6, -3.6, 93.2 + i * 1.6, 3.2, FAINT, 1.0)
k.label(96.5, 0.2, "REACTOR", 13, HEAT, 'middle')
k.eq(104.6, -6.6, 3.0, 5.6, art="gen", col=HEAT)                       # backup power
k.eq(104.6, 0.6, 3.0, 5.4, art="battery", col=VIO)
for y in (-5.6, 5.0):
    k.pipe([(90.2, y), (104.2, y)], FLUID, 2.4)
k.pipe([(102.0, -0.4), (104.6, -0.4)], FLUID, 1.8)
k.door(103.83, -6.6, 0.34, 2.4)
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
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 200 if row == 0 else 810, kind, text))
c(1, 41.0, -10.5, 520, 0, "sys", "舰桥：战术座席 ×3")
c(2, 46.85, -11.2, 600, 0, "haz", "火控系统")
c(3, 48.8, -11.0, 680, 0, "energy", "通讯加密柜")
c(4, 10.0, -11.0, 80, 0, "haz", "舰炮 + 炮塔")
c(5, 22.0, -5.0, 160, 0, "haz", "舰炮基座（转动机构）")
c(6, 23.6, 0.0, 240, 1, "haz", "弹药供给机构（升降链）")
c(7, 12.9, -1.5, 320, 0, "fluid", "武器冷却模块")
c(8, 18.75, 3.3, 80, 1, "haz", "弹药库（爆炸物）")
c(9, 6.0, 1.0, 160, 1, "struct", "厚装甲外壳（多层，切割极慢）")
c(10, 31.0, -8.6, 400, 0, "struct", "装甲板后面藏着的固定件（虚线螺栓）")
c(11, 73.0, -7.8, 760, 0, "room", "维护通道：夹在装甲层与耐压壳之间（上下各一条）")
c(12, 90.0, -7.85, 840, 0, "haz", "隐藏通道里没断开的控制线路")
c(13, 50.6, -3.5, 240, 1, "energy", "双套主配电 DIST-A / DIST-B（两张独立电网）")
c(14, 58.4, -4.0, 920, 0, "energy", "传感器处理舱")
c(15, 67.3, -4.4, 1000, 0, "energy", "独立武器电容（外部标准接口隔离不了）")
c(16, 66.0, 9.3, 320, 1, "haz", "腹部近防炮塔 + 局部电容")
c(17, 78.0, -4.0, 1080, 0, "sys", "舰员铺位 / 储物")
c(18, 96.5, 2.0, 1160, 1, "haz", "反应堆 / 主电源（屏蔽层内）")
c(19, 106.1, -3.8, 1240, 0, "haz", "备用动力系统：发电机 + 电池")
c(20, 97.0, 5.0, 400, 1, "fluid", "装甲内部检修管道")
c(21, 103.98, -5.4, 1320, 0, "room", "局部隔离门（各舱段）")
c(22, 119.6, -3.2, 1400, 0, "haz", "推力矢量机构（万向环 + 作动杆）")
c(23, 127.0, 3.0, 1480, 1, "sys", "大型推进器 ×2")
c(24, 120.0, 8.0, 480, 1, "struct", "厚重尾梁")
zones = [(0.0, 34.0, 11.6, "② 前武器段", "haz"), (34.0, 52.0, 11.6, "① 舰桥（上方）", "room"), (52.0, 90.0, 11.6, "③ 中央主舰体", "energy"),
         (90.0, 113.0, 11.6, "④ 中后设备段", "haz"), (113.0, 133.6, 11.6, "⑤ 尾推进段", "struct")]
sheet('pt34.html', 2400, 1180, 'PT-34「隼鹰」退役巡逻舰 · 134 m · 结构图（设计稿）',
      ['尖锐楔形舰首，厚装甲外壳，舰身有武器凸起，整体线条锋利、紧凑、压迫感强。',
       '军舰不是「大一点的民船」：隐藏维护路线、厚装甲、两套分离电网、武器子系统 —— 第一次需要「找路」。'], k.svg(), k.P, calls, zones, legend_cols=3, auto=True, scale_at=(0.0, -14.6), scale_m=10)
print('ok')
