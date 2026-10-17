# VT-80 "Long Whale" propellant tanker, 96 m: concept structure sheet.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

k = Kit(100, 470, 16.4)
ST, SB = -2.9, -0.6                        # the spine girder
# ---------------- the spine: a slender box girder with lightening holes, fore to aft
k.plate([(8.5, ST), (88.0, ST), (88.0, SB), (8.5, SB)])
for x in range(10, 88, 3):
    k.circ(x + 1.5, (ST + SB) / 2, 0.55, fill='#1d222a', stroke='#56606e', sw=1.0)
for x in range(12, 88, 6):
    k.line(x, ST, x, SB, '#0d1117', 1.3)
    k.bolt(x - 0.3, ST + 0.25)
    k.bolt(x + 0.3, ST + 0.25)
k.room([(9.0, ST - 1.35), (87.5, ST - 1.35), (87.5, ST - 0.05), (9.0, ST - 0.05)])        # the crawl tube on top (pressurised)
k.plate([(8.5, ST - 1.65), (88.0, ST - 1.65), (88.0, ST - 1.35), (8.5, ST - 1.35)])
k.label(50.0, ST - 0.45, "CRAWL TUBE (pressurised, 1.3 m)", 9, AIR, 'middle')
# ---------------- the whale's head: control cabin
head = [(0.4, -1.0), (1.8, -4.0), (5.0, -5.0), (10.0, -5.0), (10.0, 1.6), (5.5, 2.4), (1.6, 1.4)]
k.shell(head, offset(head, 0.4))
k.room(offset(head, 0.4))
k.plate([(0.4, -1.0), (1.8, -4.0), (2.21, -3.62), (0.84, -0.99)], fill='#1b3550', stroke=AIR)
k.eq(1.4, -1.6, 1.2, 1.3, art="console")
k.seat(2.9, -0.2, 1.55)
k.eq(4.3, -4.4, 3.4, 1.8, art="swb", col=HAZ)                                     # valve schematic panel
k.label(6.0, -2.3, "VALVES", 9, HAZ, 'middle')
k.eq(4.3, -1.9, 1.8, 2.0, art="nav_rack", col=VIO)                                # fluid monitor terminal
k.eq(6.6, -1.6, 2.8, 2.6, art="env")
k.door(9.85, -4.45, 0.3, 1.3)
# ---------------- front valve and distribution section, hung under the spine
vs = [(10.4, SB), (20.2, SB), (20.2, 4.2), (11.4, 4.2), (10.4, 3.2)]
k.shell(vs, offset(vs, 0.35))
k.room(offset(vs, 0.35))
for i, x in enumerate((11.6, 13.6, 15.6)):                                        # the main valve group
    k.circ(x, 1.2, 0.75, fill=EQF, stroke=HAZ, sw=1.4)
    k.line(x - 0.75, 1.2, x + 0.75, 1.2, HAZ, 1.0)
    k.line(x, 0.45, x, 1.95, HAZ, 1.0)
    k.circ(x, 1.2, 0.2, fill=HAZ, stroke='none')
k.pipe([(11.0, 2.6), (19.5, 2.6)], HAZ, 3.0)
for x in (11.6, 13.6, 15.6):
    k.pipe([(x, 1.95), (x, 2.6)], HAZ, 1.8)
k.eq(17.4, 0.0, 2.2, 1.6, art="swb")                                              # flow controller
k.label(18.5, -0.1, "FLOW", 9, DIM, 'middle')
k.eq(17.4, 2.9, 2.2, 1.0, col=HEAT)                                               # emergency shut-off
k.line(17.7, 3.4, 19.2, 3.4, HEAT, 2.2)
k.label(18.5, 4.45, "ESD", 9, HEAT, 'middle')
# ---------------- the tank group: three pairs (near tank drawn, its far-side partner behind), cross-connected
pairs = [(21.0, 37.0, "T1", 0.35), (38.0, 54.0, "T2", 0.05), (55.0, 71.0, "T3", 0.6)]
for x0, x1, nm, lvl in pairs:
    r = 3.5
    cy = SB + 0.6 + r
    k.rect(x0 + 0.6, cy - r - 0.5, x1 - x0, 2 * r, fill='#1a1f28', stroke=FAINT, sw=1.0, rx=r * 0.95, dash='5 4')   # far-side partner
    k.rect(x0, cy - r, x1 - x0, 2 * r, fill='#151a22', stroke=HAZ, sw=1.5, rx=r * 0.95)
    # the propellant left in it
    ly = cy + r - 2 * r * lvl
    k.rect(x0 + 0.6, ly, x1 - x0 - 1.2, cy + r - ly - 0.4, fill='#3a2e14', stroke='none', rx=0.3)
    k.line(x0 + 0.8, ly, x1 - 0.8, ly, HAZ, 1.0, 0.8)
    for xx in (x0 + 2.5, x1 - 2.5):                                               # saddle frames to the spine
        k.plate([(xx - 0.5, SB), (xx + 0.5, SB), (xx + 0.7, cy - r + 0.35), (xx - 0.7, cy - r + 0.35)], fill='#323844')
        k.lock(xx, SB + 0.25)
    for i in range(4):
        xx = x0 + 3.5 + i * 3.0
        k.line(xx, cy - r, xx, cy + r, '#2d3440', 1.0)
    k.label((x0 + x1) / 2, cy - 0.6, nm + "-L  /  " + nm + "-R", 15, HAZ, 'middle')
    k.label((x0 + x1) / 2, cy + 0.6, "%d %%" % int(lvl * 100), 12, HAZ, 'middle')
    k.port(x0 + 1.4, cy - r + 0.3, HAZ)                                           # each tank's own test point
    k.circ(x1 - 1.6, cy - r - 0.2, 0.3, fill=EQF, stroke=HAZ, sw=1.3)           # vent valve
# cross-connections: a manifold under the tanks, branches with valves; a crossfeed between the pair members
man_y = SB + 0.6 + 7.0 + 0.9
k.pipe([(19.5, 2.6), (19.5, man_y), (78.0, man_y)], HAZ, 2.6)
for x0, x1, nm, lvl in pairs:
    for xx in (x0 + 4.5, x1 - 4.5):
        k.pipe([(xx, man_y - 0.9), (xx, man_y)], HAZ, 1.6)
        k.circ(xx, man_y - 0.45, 0.28, fill=EQF, stroke=HAZ, sw=1.3)
    k.pipe([((x0 + x1) / 2 - 1.0, man_y - 0.9), ((x0 + x1) / 2 - 1.0, man_y - 0.3), ((x0 + x1) / 2 + 1.0, man_y - 0.3), ((x0 + x1) / 2 + 1.0, man_y - 0.9)], HAZ, 1.2)
# the valve that reads closed and seeps (variant)
lx = 54.0 - 4.5
k.circ(lx, man_y - 0.45, 0.32, fill=EQF, stroke=HEAT, sw=1.8)
for d in (0.5, 0.9, 1.3):
    k.circ(lx + 0.15, man_y - 0.45 + d, 0.07, fill=HAZ, stroke='none')
# ---------------- the pump room
pr = [(72.0, SB), (84.5, SB), (84.5, 5.4), (73.0, 5.4), (72.0, 4.4)]
k.shell(pr, offset(pr, 0.35))
k.room(offset(pr, 0.35))
k.eq(72.8, 0.2, 3.6, 3.2, art="pump", col=HAZ)                                     # main pump
k.label(74.6, 3.9, "MAIN PUMP", 9, HAZ, 'middle')
k.eq(76.9, 0.4, 2.4, 2.4, art="pump", col=HAZ)                                     # return pump
k.eq(79.8, 0.0, 1.6, 3.2, art="radiator")                                           # filter assembly
k.label(80.6, 3.7, "FILTER", 9, DIM, 'middle')
k.pipe([(73.0, 4.6), (84.0, 4.6)], HAZ, 2.6)                                        # relief manifold
k.pipe([(83.6, 4.6), (83.6, 6.6)], HAZ, 2.0)
k.port(83.6, 6.8, HAZ)
k.label(82.2, 6.9, "RELIEF", 9, HAZ, 'end')
k.pipe([(78.0, man_y), (78.0, 5.4)], HAZ, 2.4)
k.eq(81.8, 0.0, 2.2, 2.6, art="swb", col=HEAT)                                      # pump control distribution
k.switch(82.5, -0.9, HEAT)
k.switch(83.0, -0.9, HEAT)
# ---------------- tail: main engine, attitude jets
k.plate([(84.5, -4.4), (85.5, -4.4), (85.5, 2.4), (84.5, 2.4)], fill='#323844')
k.eq(85.5, -2.6, 3.0, 3.6, art="eng_core")
k.peq([(88.5, -2.3), (95.6, -4.0), (95.6, 2.8), (88.5, 0.7)])
for x in (90.0, 91.6, 93.2, 94.8):
    k.line(x, -2.6 - (x - 88.5) * 0.24, x, 1.0 + (x - 88.5) * 0.24, FAINT, 1.0)
for sg, y in ((-1, -4.9), (1, 3.4)):
    k.eq(84.0, y, 1.4, 0.7, art="rcs_quad")
k.tank(85.6, -4.4, 2.6, 0.9, HAZ, "PROP")
k.cable([(82.9, -0.3), (82.9, -1.5), (88.0, -1.5)], HEAT)
k.cable([(10.0, ST - 0.7), (84.5, ST - 0.7)], HEAT)
for x in (29.0, 46.0, 63.0):
    a, b = k.P(x, SB + 0.6 + 7.0)
    k.o.append(f'<polygon points="{a-14:.0f},{b+60:.0f} {a+14:.0f},{b+60:.0f} {a+7:.0f},{b+4:.0f} {a-7:.0f},{b+4:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

# ---------------- v2 fill: crew block, pressurant spheres, vent header, tank internals, aux power, more pump room
TOP = ST - 1.65
crew = [(10.0, TOP), (20.0, TOP), (20.0, -9.2), (11.6, -9.2), (10.0, -7.4)]
k.shell(crew, offset(crew, 0.35))
k.room(offset(crew, 0.35))
k.plate([(10.4, -6.45), (19.6, -6.45), (19.6, -6.25), (10.4, -6.25)])
for i in range(3):                                                                # crew berths (long hauls)
    k.eq(12.0 + i * 2.6, -8.75, 2.4, 1.0, art="bunk")
    k.eq(12.0 + i * 2.6, -7.6, 2.4, 1.0, art="locker")
k.eq(10.8, -6.05, 2.0, 1.5, art="console")                                       # galley table
k.eq(13.2, -6.05, 1.8, 1.5, art="cabinet")
k.eq(15.3, -6.05, 2.0, 1.5, art="env", col=AIR)                                  # life support
k.tank(17.6, -6.2, 0.8, 1.6, AIR, "")
k.tank(18.6, -6.2, 0.8, 1.6, AIR, "")
k.door(19.65, -8.6, 0.3, 1.6)                                                    # airlock out to the spine walkway
# pressurant: nitrogen spheres on the spine keep the tanks pressurised; a line down to each tank
for i, x in enumerate((24.0, 29.0, 41.0, 46.0, 58.0, 63.0)):
    k.sphere(x, TOP - 1.7, 1.55, AIR, "N₂", jacket=0.25)
    k.plate([(x - 0.9, TOP - 0.2), (x + 0.9, TOP - 0.2), (x + 0.5, TOP), (x - 0.5, TOP)], fill='#323844')
k.pipe([(22.5, TOP - 3.6), (70.0, TOP - 3.6)], AIR, 1.4)
for x in (24.0, 29.0, 41.0, 46.0, 58.0, 63.0):
    k.pipe([(x, TOP - 3.25), (x, TOP - 3.6)], AIR, 1.0)
for x0, x1, nm, lvl in pairs:
    xm = (x0 + x1) / 2 + 3.0
    k.pipe([(xm, TOP - 3.6), (xm + 0.6, TOP - 3.6), (xm + 0.6, SB + 0.65)], AIR, 1.0)
    k.circ(xm + 0.6, SB - 0.3, 0.26, fill=EQF, stroke=AIR, sw=1.2)
# the vent header: every tank's vent valve to one stack aft
k.pline([(21.6, SB + 0.3), (86.8, SB + 0.3), (86.8, -6.6)], AIR, 1.2, 0.85, dash='7 3')
k.rect(86.3, -7.6, 1.0, 1.0, fill=EQF, stroke=AIR, sw=1.2)
for x0, x1, nm, lvl in pairs:
    r = 3.5
    cy = SB + 0.6 + r
    k.rect(x0 + 6.5, cy - r - 0.35, 1.6, 0.4, fill='#2a3140', stroke=HAZ, sw=1.0)    # manhole
    k.line(x0 + 1.2, cy - r + 0.6, x0 + 1.2, cy + r - 0.6, VIO, 1.0)                # level probe
    for j in range(5):
        k.circ(x0 + 1.2, cy - r + 1.1 + j * 1.2, 0.11, fill=VIO, stroke='none')
    k.rect(x1 - 3.8, cy + r - 1.2, 1.2, 0.9, fill=EQF, stroke=HAZ, sw=1.0)          # sump well with its pump
    k.eq(x1 - 2.4, cy - r + 0.6, 0.8, 2 * r - 1.2, art="ladder")
    for xx in (x0 + 5.0, x0 + 8.0, x0 + 11.0):                                       # anti-slosh baffles (holed)
        k.line(xx, cy - r + 0.2, xx, cy - 0.8, '#3d4654', 1.6)
        k.line(xx, cy + 0.8, xx, cy + r - 0.2, '#3d4654', 1.6)
# aux power over the pump room: APU, batteries, fire bottles
ap = [(72.0, TOP), (85.5, TOP), (85.5, -8.6), (72.0, -8.6)]
k.shell(ap, offset(ap, 0.35))
k.room(offset(ap, 0.35))
k.eq(72.6, -8.1, 3.6, 3.4, art="gen", col=HEAT)
k.label(74.4, -8.4, "APU", 9, HEAT, 'middle')
k.eq(76.6, -7.9, 3.6, 3.2, art="battery", col=VIO)
k.tank(80.6, -8.1, 0.8, 3.3, HEAT, "")
k.tank(81.6, -8.1, 0.8, 3.3, HEAT, "")
k.label(82.0, -8.4, "CO₂", 9, HEAT, 'middle')
k.eq(82.8, -8.0, 2.2, 3.3, art="swb", col=HEAT)
k.cable([(83.9, -4.7), (83.9, ST - 0.7)], HEAT)
# more in the pump room: a second transfer pump, a boost pump, a flow meter
k.eq(72.8, 3.6 - 0.1, 1.6, 1.4, art="pump", col=HAZ)
k.eq(76.9, 3.0, 2.4, 1.3, art="aux", col=HAZ)
k.label(78.1, 4.5, "FLOW METER", 7, HAZ, 'middle')
# the valve section: purge panel and pressure transmitters
k.eq(10.9, -0.2, 1.6, 0.9, art="panel", col=AIR)
k.label(11.7, -0.35, "N₂ PURGE", 7, AIR, 'middle')
for x in (12.6, 14.6):
    k.rect(x - 0.15, 0.1, 0.3, 0.5, fill=EQF, stroke=VIO, sw=1.0)

calls = []
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 150 if row == 0 else 800, kind, text))
c(1, 2.0, -1.0, 80, 0, "sys", "驾驶位 + 驾驶台")
c(2, 3.3, -1.0, 150, 0, "energy", "流体监控终端")
c(3, 6.0, -3.5, 220, 0, "haz", "阀门图示面板（显示的是「指令」，不是阀门真实位置）")
c(4, 40.0, ST - 0.7, 290, 0, "room", "脊梁顶部的有压爬行管（贯穿全船）")
c(5, 30.0, (ST + SB) / 2, 360, 0, "struct", "细长脊梁：箱形梁 + 减重孔，储罐挂在下面")
c(6, 13.6, 1.2, 80, 1, "haz", "主阀组（三联大阀）")
c(7, 18.5, 0.8, 150, 1, "sys", "流量控制器")
c(8, 18.5, 3.4, 220, 1, "haz", "紧急切断系统 ESD")
c(9, 29.0, 4.7, 430, 0, "haz", "三对巨型推进剂罐：近侧画实线，远侧那只画虚线")
c(10, 33.0, 4.0, 500, 0, "haz", "罐内残液（各罐液位不同）")
c(11, 22.4, 1.5, 290, 1, "haz", "每罐独立测点（但罐与罐并非完全独立）")
c(12, 23.5, 0.0, 570, 0, "struct", "鞍座吊架 + 锁扣")
c(13, 45.0, man_y, 360, 1, "haz", "交叉连通总管 + 支管阀门")
c(14, 46.0, man_y - 0.6, 430, 1, "haz", "罐对之间的交叉连通管（残液）")
c(15, lx, man_y - 0.45, 500, 1, "haz", "坏阀门：表面关闭，实际内漏")
c(16, 74.6, 1.8, 640, 0, "haz", "大泵")
c(17, 78.1, 1.6, 710, 0, "haz", "回流泵")
c(18, 78.0, 4.6, 570, 1, "haz", "泄放总管 + 排放口（泄放顺序错了会影响另一侧储罐）")
c(19, 80.6, 1.6, 780, 0, "sys", "滤网组件")
c(20, 82.9, 1.3, 850, 0, "energy", "泵控配电设备 + 开关")
c(21, 91.0, -1.0, 920, 0, "sys", "尾部主推进器")
c(22, 84.7, -4.55, 990, 0, "sys", "姿态喷口")
c(0, 13.2, -8.25, 0, 0, "room", "船员舱：铺位 ×3 + 储物 + 餐桌 + 厨柜（长途航行）")
c(0, 16.3, -5.3, 0, 0, "room", "生命维持 + 氧瓶 + 通往脊梁的气闸")
c(0, 41.0, TOP - 1.7, 0, 0, "room", "增压氮气球罐 ×6（给推进剂罐保压）")
c(0, 52.0, TOP - 3.6, 0, 0, "room", "增压管 → 每罐增压阀")
c(0, 60.0, SB + 0.3, 0, 1, "room", "排气总管 → 尾部排气塔")
c(0, 44.5, SB + 0.35, 0, 1, "haz", "人孔盖（每罐顶部）")
c(0, 39.2, 2.5, 0, 1, "energy", "液位探杆")
c(0, 49.7, 6.7, 0, 1, "haz", "罐底集液井 + 集液泵")
c(0, 45.0, 1.5, 0, 1, "struct", "防晃隔板（带孔）+ 罐内检修梯")
c(0, 74.4, -6.4, 0, 0, "haz", "辅助动力 APU + 电池")
c(0, 81.0, -6.4, 0, 0, "haz", "灭火 CO₂ 瓶组")
c(0, 73.6, 4.3, 0, 1, "haz", "第二台输送泵")
c(0, 78.1, 3.6, 0, 1, "haz", "流量计")
c(0, 11.7, 0.25, 0, 1, "room", "氮气吹扫面板 + 压力变送器")
zones = [(0.4, 10.0, 13.6, "① 前控制舱", "room"), (10.0, 20.2, 13.6, "② 阀门与分配段", "haz"), (20.2, 72.0, 13.6, "③ 中央储罐群（三对）", "haz"),
         (72.0, 84.5, 13.6, "④ 泵房", "haz"), (84.5, 95.6, 13.6, "⑤ 尾推进", "struct")]
sheet('vt80.html', 1800, 1260, 'VT-80「长鲸」推进剂运输船 · 96 m · 结构图（设计稿 v2）',
      ['船体狭长，腹部挂着三对巨型推进剂罐，前后细梁 —— 一条拖着肚子游的长鲸。',
       '「流体网络关」：罐与罐交叉连通，错误的隔离 / 泄放顺序会让别的罐出问题，要先做工程流程设计。'], k.svg(), k.P, calls, zones, legend_cols=2, auto=True, scale_at=(0.0, -10.4), scale_m=10)
print('ok')
