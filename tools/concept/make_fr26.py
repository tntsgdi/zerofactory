# FR-26 "Frostline" cryogenic transport, 72 m: concept structure sheet.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

COLD = '#9fe3ff'
k = Kit(110, 520, 22.0)
KT, KB = -6.1, -5.3                       # the keel the tanks hang from
# ---------------- radiator wings (behind): two pairs, over the front and rear equipment
for x0, x1 in ((8.0, 14.0), (59.5, 65.0)):
    for sg in (-1, 1):
        y0 = KT if sg < 0 else 4.4
        y1 = -10.6 if sg < 0 else 9.6
        k.plate([(x0, y0), (x1, y0), (x1 - 1.2, y1), (x0 + 0.6, y1)], fill='#262b34')
        n = 12
        for i in range(1, n):
            t = i / n
            k.line(x0 + (x1 - x0) * t - 0.6 * t, y0, x0 + 0.6 + (x1 - 1.8 - x0) * t, y1, FLUID, 0.9, 0.35)
        k.line(x0 + 0.3, (y0 + y1) / 2, x1 - 0.6, (y0 + y1) / 2, FLUID, 1.4, 0.7)
# ---------------- the keel: a box girder along the top, bolted segments
k.plate([(6.5, KT), (70.0, KT), (70.0, KB), (6.5, KB)])
for x in range(8, 70, 4):
    k.line(x, KT, x, KB, '#0d1117', 1.2)
    k.bolt(x - 0.25, (KT + KB) / 2)
    k.bolt(x + 0.25, (KT + KB) / 2)
k.line(6.5, KT + 0.18, 70.0, KT + 0.18, FAINT, 0.8)
# ---------------- front control cabin: a streamlined nose module
nose = [(0.4, -0.6), (1.4, -3.4), (4.0, -5.2), (7.6, -5.3), (7.6, 3.6), (4.0, 3.6), (1.2, 2.2)]
k.shell(nose, offset(nose, 0.4))
k.room(offset(nose, 0.4))
k.plate([(0.4, -0.6), (1.4, -3.4), (1.82, -3.05), (0.87, -0.68)], fill='#1b3550', stroke=AIR)
k.eq(1.5, -1.2, 1.1, 1.3, art="console")
k.seat(2.9, 0.2, 1.6)
k.eq(4.2, -3.6, 1.3, 2.4, art="swb", col=COLD)                        # temperature control master panel
k.label(4.85, -0.9, "TEMP", 9, COLD, 'middle')
k.eq(5.8, -3.6, 1.2, 2.4, art="nav_rack", col=VIO)                    # cargo monitor terminal
k.eq(4.3, 0.9, 2.6, 2.2, art="env")
k.port(3.6, -5.2, AIR)
# ---------------- front equipment: main chiller, valve box, heat-exchange loop (enclosed, unpressurised)
k.plate([(7.6, KB), (14.2, KB), (14.2, 4.0), (7.6, 4.0)], fill='#2a2f39')
k.room([(7.9, KB + 0.3), (13.9, KB + 0.3), (13.9, 3.7), (7.9, 3.7)])
k.eq(8.2, -4.6, 2.8, 3.2, art="pump", col=COLD)                      # main chiller (cryocooler)
k.label(9.6, -1.1, "CHILLER-1", 9, COLD, 'middle')
k.eq(11.4, -4.6, 2.2, 2.0, art="swb", col=HAZ)                        # electric valve box
k.eq(8.2, 0.4, 5.4, 2.9, art="radiator", col=FLUID)                   # heat-exchange loop
k.pipe([(13.6, -1.0), (15.0, -1.0)], COLD, 2.6)
k.pipe([(13.6, -1.0), (15.0, -1.0)], BG, 0.9)
k.switch(9.2, 4.3, HEAT)
k.switch(9.7, 4.3, HEAT)
# ---------------- three cryogenic tanks, each: inner tank, vacuum jacket, relief valve, temperature sensors
tanks = [(14.8, 28.8, "T-1"), (30.0, 44.0, "T-2"), (45.2, 59.2, "T-3")]
for x0, x1, nm in tanks:
    r = 4.55
    k.rect(x0, -r, x1 - x0, 2 * r, fill='#20252e', stroke=HULLS, sw=1.4, rx=r * 0.9)          # outer vacuum jacket
    k.rect(x0 + 0.55, -r + 0.55, x1 - x0 - 1.1, 2 * r - 1.1, fill='none', stroke=FAINT, sw=0.8, rx=(r - 0.55) * 0.9, dash='3 4')
    k.rect(x0 + 0.85, -r + 0.85, x1 - x0 - 1.7, 2 * r - 1.7, fill='#0f2230', stroke=COLD, sw=1.6, rx=(r - 0.85) * 0.9)   # inner tank
    for xx in (x0 + 3.0, (x0 + x1) / 2, x1 - 3.0):                                         # jacket supports
        k.line(xx, -r + 0.1, xx, -r + 0.85, DIM, 1.2)
        k.line(xx, r - 0.1, xx, r - 0.85, DIM, 1.2)
    for i in range(7):                                                                    # the cold cargo
        yy = -1.8 + i * 0.75
        k.line(x0 + 1.6, yy, x1 - 1.6, yy, COLD, 0.7, 0.25)
    k.label((x0 + x1) / 2, 0.4, nm, 22, COLD, 'middle')
    k.label((x0 + x1) / 2, 1.5, "−163 °C · 220 kPa", 12, COLD, 'middle')
    for i, xx in enumerate((x0 + 2.6, (x0 + x1) / 2, x1 - 2.6)):                           # temperature sensors
        k.circ(xx, 3.0, 0.16, fill=BG, stroke=COLD, sw=1.2)
    # hangers to the keel, relief valve and its vent stack up through the keel
    for xx in (x0 + 2.0, x1 - 2.0):
        k.plate([(xx - 0.35, KB), (xx + 0.35, KB), (xx + 0.35, -r + 0.05), (xx - 0.35, -r + 0.05)], fill='#323844')
        k.lock(xx, KB + 0.2)
    vx = (x0 + x1) / 2 + 2.6
    k.pipe([(vx, -r + 0.85), (vx, KT - 0.9)], COLD, 1.6)
    k.circ(vx, -r + 0.4, 0.3, fill=EQF, stroke=HAZ, sw=1.4)
    k.label(vx + 0.5, KT - 0.6, "PSV", 9, HAZ)
    k.port((x0 + x1) / 2 - 3.0, -r - 0.1, COLD)
# the cryogenic piping: an insulated (double) manifold under the keel, branches into each tank
man = [(14.2, -4.95), (60.0, -4.95)]
k.pipe(man, COLD, 3.4)
k.pipe(man, BG, 1.4)
for x0, x1, nm in tanks:
    for xx in (x0 + 4.0, x1 - 4.0):
        k.pipe([(xx, -4.95), (xx, -3.7)], COLD, 1.4)
    k.circ(x1 + 0.6, -4.95, 0.28, fill=EQF, stroke=HAZ, sw=1.3)                            # isolation valves between tanks
k.circ(29.4, -4.95, 0.3, fill=EQF, stroke=COLD, sw=1.6)
k.line(29.25, -5.1, 29.55, -4.8, COLD, 2.0)                                                 # a frozen section (variant)
# ---------------- rear equipment: backup chiller, coolant pump, frost vent, emergency heater
k.plate([(59.6, KB), (65.4, KB), (65.4, 4.4), (59.6, 4.4)], fill='#2a2f39')
k.room([(59.9, KB + 0.3), (65.1, KB + 0.3), (65.1, 4.1), (59.9, 4.1)])
k.eq(60.2, -4.6, 2.6, 2.8, art="pump", col=COLD)
k.label(61.5, -1.4, "CHILLER-2", 9, COLD, 'middle')
k.eq(63.0, -4.6, 1.8, 2.0, art="pump", col=FLUID)
k.eq(60.2, -0.9, 4.5, 1.6, art="radiator", col=HEAT)                 # emergency heater
k.label(62.45, 1.0, "HEATER", 9, HEAT, 'middle')
k.port(64.0, 4.6, COLD)
k.label(64.0, 5.6, "FROST VENT", 9, COLD, 'middle')
k.eq(60.2, 1.6, 2.0, 2.2, art="battery", col=VIO)
k.switch(62.8, 2.6, HEAT)
k.pipe([(59.6, -3.0), (59.2, -3.0)], COLD, 1.4)
k.cable([(62.5, 1.6), (62.5, 0.7)], HEAT)
k.cable([(65.0, -2.5), (66.4, -2.5)], HEAT)
# ---------------- tail: conventional thrusters and the aft distribution box
k.plate([(65.4, -5.3), (66.4, -5.3), (66.4, 4.4), (65.4, 4.4)], fill='#323844')
for yc in (-2.6, 1.6):
    k.eq(66.4, yc - 1.0, 1.8, 2.0, art="eng_front")
    k.peq([(68.2, yc - 0.85), (71.5, yc - 1.4), (71.5, yc + 1.4), (68.2, yc + 0.85)])
k.eq(66.6, -0.45, 1.5, 1.1, art="swb", col=HEAT)
k.cable([(14.2, -4.4), (59.6, -4.4)], HEAT)
for x in (21.8, 37.0, 52.2):
    a, b = k.P(x, 4.55)
    k.o.append(f'<polygon points="{a-16:.0f},{b+80:.0f} {a+16:.0f},{b+80:.0f} {a+8:.0f},{b+4:.0f} {a-8:.0f},{b+4:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

calls = []
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 150 if row == 0 else 860, kind, text))
c(1, 2.0, -0.5, 80, 1, "sys", "驾驶台 + 驾驶座")
c(2, 4.85, -2.5, 150, 1, "fluid", "温控总控面板")
c(3, 6.4, -2.4, 220, 1, "energy", "货物监测终端")
c(4, 9.6, -3.0, 80, 0, "fluid", "主制冷机 CHILLER-1")
c(5, 12.5, -3.6, 150, 0, "haz", "电控阀箱（阀门状态全在这里）")
c(6, 10.9, 1.8, 290, 1, "fluid", "热交换回路")
c(7, 11.0, -8.5, 220, 0, "fluid", "散热翼（前后各一对）")
c(8, 20.0, -5.7, 290, 0, "struct", "龙骨：箱形梁，储罐挂在下面（每罐 2 个吊架 + 锁扣）")
c(9, 21.8, 0.0, 360, 1, "fluid", "低温储罐 T-1 / T-2 / T-3：内罐（−163 °C）")
c(10, 16.0, 3.9, 430, 1, "struct", "外层真空隔热壳（支撑架 + 真空夹层）")
c(11, 24.4, -4.15, 360, 0, "haz", "安全泄放阀 PSV + 排放管（可能冻结卡死）")
c(12, 21.0, 3.0, 500, 1, "fluid", "温度传感器（每罐 3 个）")
c(13, 40.0, -4.95, 430, 0, "fluid", "低温管网：双层保温总管，罐与罐之间有隔离阀")
c(14, 29.4, -4.95, 500, 0, "haz", "一段管线冻住（事故变体）")
c(15, 61.5, -3.2, 570, 0, "fluid", "备用制冷机 CHILLER-2")
c(16, 63.9, -3.6, 640, 0, "fluid", "冷却泵")
c(17, 64.0, 4.6, 570, 1, "fluid", "霜冻排放接口")
c(18, 62.4, -0.1, 640, 1, "haz", "冻结应急加热装置（可能被错误启动）")
c(19, 61.2, 2.7, 710, 1, "energy", "备用电池 + 开关")
c(20, 69.5, -2.6, 710, 0, "sys", "常规推进器 ×2")
c(21, 67.35, 0.1, 780, 1, "energy", "尾部电力配电箱")
zones = [(0.4, 7.6, 7.6, "① 前控制舱（有压）", "room"), (7.6, 14.2, 7.6, "② 前设备段", "fluid"), (14.2, 59.6, 7.6, "③ 三联低温储罐", "fluid"),
         (59.6, 65.4, 7.6, "④ 后设备段", "fluid"), (65.4, 71.5, 7.6, "⑤ 尾推进", "struct")]
sheet('fr26.html', 1800, 1150, 'FR-26「霜线」低温运输船 · 72 m · 结构图（设计稿）',
      ['三个串联的大型圆柱冷藏罐挂在一根龙骨上，船体细长，两侧散热翼。',
       '第一次把温度当成重要状态：只看电和压不够，还要看「低温是否失控」。'], k.svg(), k.P, calls, zones, legend_cols=2, scale_at=(0.0, -11.6), scale_m=10)
print('ok')
