# H-22 "Double Hook" engineering tug, 38 m: concept structure sheet (no ship file yet).
import sys
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO, DEFS
from sheet import sheet

k = Kit(130, 470, 40)
# ---------------- tow arms (upper / lower, mirrored) with magnetic tow heads
for sg in (-1, 1):
    Y = lambda y: y * sg
    # telescopic inner section and the fixed sleeve
    k.plate([(1.9, Y(5.38)), (7.4, Y(5.38)), (7.4, Y(4.62)), (1.9, Y(4.62))], fill='#323844')
    for x in (2.6, 3.6, 4.6, 5.6, 6.6):
        k.line(x, Y(5.38), x, Y(4.62), FAINT, 1.0)
    k.plate([(6.6, Y(5.65)), (13.0, Y(5.65)), (13.0, Y(4.35)), (6.6, Y(4.35))])
    k.line(6.6, Y(5.0), 13.0, Y(5.0), '#0d1117', 1.0)
    for x in (7.8, 9.4, 11.0):
        k.line(x, Y(5.65), x, Y(4.35), '#0d1117', 1.2)
    k.lock(6.85, Y(5.4))
    k.lock(6.85, Y(4.6))
    # the tow head: a claw with the electromagnet pad on its inner face
    head = [(2.3, Y(5.9)), (1.0, Y(6.25)), (0.1, Y(5.7)), (0.0, Y(4.1)), (0.55, Y(3.55)), (1.35, Y(3.75)), (1.4, Y(4.25)), (1.0, Y(4.55)), (1.0, Y(5.2)), (2.3, Y(5.25))]
    k.plate(head, fill='#2c323d')
    for i in range(4):
        yy = Y(3.85 + i * 0.18)
        k.ell(0.72, yy, 0.42, 0.06, fill='none', stroke=VIO, sw=1.3)
    k.eq(2.15, Y(5.0) - 0.22, 0.5, 0.44, col=EQ)                                  # tension sensor
    k.label(2.4, Y(5.0) + (0.95 if sg > 0 else -0.6), "TS-%d" % (1 if sg < 0 else 2), 9, DIM, 'middle')
    # hinge and the exposed drive cylinder from the H-frame
    k.circ(13.3, Y(5.0), 0.38, fill=EQF, stroke=HULLS, sw=1.4)
    k.circ(13.3, Y(5.0), 0.12, fill='#b4c0cf', stroke='none')
    k.pline([(13.6, Y(2.6)), (10.4, Y(4.35))], EQ, 9, 1.0)
    k.pline([(13.6, Y(2.6)), (10.4, Y(4.35))], EQF, 5, 1.0)
    k.pline([(11.9, Y(3.52)), (10.4, Y(4.35))], '#b4c0cf', 2.4, 1.0)
    k.circ(13.6, Y(2.6), 0.16, fill='#b4c0cf', stroke='none')
    k.circ(10.4, Y(4.35), 0.16, fill='#b4c0cf', stroke='none')
    k.port(12.9, Y(3.0), FLUID)
    # coil power and coolant run out along the arm, in the open
    k.cable([(17.0, Y(3.0)), (14.6, Y(3.0)), (13.9, Y(4.2)), (7.0, Y(4.2)), (2.3, Y(4.75))], HEAT)
    k.pipe([(17.0, Y(3.3)), (14.4, Y(3.3)), (13.7, Y(4.05)), (6.8, Y(4.05)), (1.4, Y(4.0))], FLUID, 1.6)
# ---------------- the H-frame
k.plate([(12.8, -6.35), (13.85, -6.35), (13.85, 6.35), (12.8, 6.35)])
k.plate([(15.0, -5.2), (16.05, -5.2), (16.05, 5.2), (15.0, 5.2)])
k.plate([(13.85, -0.75), (15.0, -0.75), (15.0, 0.75), (13.85, 0.75)])
for sg in (-1, 1):
    k.plate([(13.85, sg * 0.75), (15.0, sg * 0.75), (15.0, sg * 2.0)], fill='#323844')
    k.plate([(13.85, sg * 4.6), (15.0, sg * 4.6), (13.85, sg * 5.6)], fill='#323844')
for y in (-6.0, -3.2, -0.4, 0.4, 3.2, 6.0):
    k.bolt(13.3, y)
for y in (-4.8, -2.4, 2.4, 4.8):
    k.bolt(15.5, y)
k.bolts(13.85, -0.5, 15.0, -0.5, 3)
k.bolts(13.85, 0.5, 15.0, 0.5, 3)
# ---------------- main hull, short and thick
outer = [(16.0, -3.0), (17.2, -4.25), (29.8, -4.25), (31.0, -3.0), (31.0, 3.0), (29.8, 4.25), (17.2, 4.25), (16.0, 3.0)]
inner = offset(outer, 0.42)
k.shell(outer, inner)
k.seams(outer, inner)
for x in (20.2, 23.2, 26.6):
    k.line(x, -4.25, x, -3.83, '#0d1117', 1.3)
    k.line(x, 4.25, x, 3.83, '#0d1117', 1.3)
# rooms: control cabin (pressurised) above, hydraulic bay below it, power room aft
k.room([(16.45, -2.82), (17.4, -3.83), (23.0, -3.83), (23.0, -0.45), (16.45, -0.45)])
k.room([(16.45, -0.15), (23.0, -0.15), (23.0, 3.83), (17.4, 3.83), (16.45, 2.82)])
k.room([(23.3, -3.83), (29.6, -3.83), (30.58, -2.82), (30.58, 2.82), (29.6, 3.83), (23.3, 3.83)])
k.plate([(16.45, -0.45), (23.0, -0.45), (23.0, -0.15), (16.45, -0.15)])
k.plate([(23.0, -3.83), (23.3, -3.83), (23.3, 3.83), (23.0, 3.83)])
k.door(22.98, 1.0, 0.34, 2.2)
k.door(18.2, -0.47, 0.9, 0.34)
# forward windows over the H-frame
k.plate([(16.0, -3.0), (17.2, -4.25), (17.55, -3.85), (16.42, -2.78)], fill='#1b3550', stroke=AIR)
# --- control cabin
k.eq(16.7, -1.45, 1.3, 1.0, art="console")                                   # tow operations console
k.seat(18.25, -0.45, 1.75)
k.eq(20.0, -2.6, 0.75, 2.15, art="nav_rack", col=VIO)                        # load monitoring unit
k.eq(21.15, -2.2, 0.6, 0.9, col=HEAT)                                        # emergency cut-off
k.line(21.3, -1.85, 21.6, -1.6, HEAT, 2.4)
k.circ(21.62, -1.58, 0.07, fill=HEAT, stroke='none')
k.eq(21.95, -1.25, 0.9, 0.8, art="env")                                       # cabin life support
k.eq(17.6, -3.8, 2.0, 0.3, art="overhead")
k.port(19.5, -4.4, AIR)
# --- hydraulic bay below the cabin
k.eq(16.9, 1.9, 1.9, 1.45, art="pump", col=FLUID)                             # hydraulic power unit
k.tank(19.1, 0.6, 0.85, 2.8, FLUID, "HYD")                                    # accumulator (pressure)
k.eq(20.3, 2.3, 2.2, 1.05, art="swb")                                         # arm drive valve block
k.port(20.0, 4.4, FLUID)
k.pipe([(18.8, 2.5), (19.1, 2.5)], FLUID)
k.pipe([(20.0, 3.35), (20.3, 3.0)], FLUID)
k.pipe([(17.4, 1.9), (17.4, 0.6), (16.0, 0.6), (13.6, 2.6)], FLUID, 2.0)
k.pipe([(17.4, 1.9), (17.4, 0.6), (16.0, -0.6), (13.6, -2.6)], FLUID, 2.0)
# --- power room
k.eq(23.6, -3.6, 1.7, 2.3, art="battery", col=VIO)                            # medium battery
k.eq(25.5, -3.6, 1.0, 2.3, art="cap", col=VIO)                                # capacitor bank
k.eq(26.8, -3.6, 2.2, 3.0, art="swb", col=HEAT)                               # traction coil power cabinet (HV)
k.label(27.9, -0.3, "COIL PWR", 9, HEAT, 'middle')
k.eq(23.6, 1.2, 2.6, 2.4, art="radiator", col=FLUID)                          # cooling module
k.eq(26.6, 1.9, 1.3, 1.7, art="pump", col=FLUID)
k.eq(28.2, 0.7, 1.8, 2.9, art="swb")                                          # main switchboard
k.switch(29.1, 0.4, HEAT)
k.switch(29.5, 0.4, HEAT)
k.cable([(26.8, -2.2), (24.0, -0.6), (17.0, -0.6), (17.0, -3.0)], HEAT)
k.cable([(26.8, -2.6), (24.2, 0.0), (17.0, 0.2), (17.0, 3.0)], HEAT)
k.cable([(25.3, -1.3), (25.5, -1.3)], VIO)
k.pipe([(24.9, 1.2), (24.9, 0.4), (17.0, 0.4), (17.0, 3.3)], FLUID, 1.6)
k.pipe([(24.9, 1.2), (24.9, 0.4), (17.0, -0.3), (17.0, -3.3)], FLUID, 1.6)
k.port(25.0, 4.45, FLUID)
k.switch(29.95, -4.45, HEAT)
k.port(28.0, -4.45, AIR)
# ---------------- rear propulsion: three short, wide nozzles on a thrust frame
k.plate([(31.0, -3.0), (32.0, -3.0), (32.0, 3.0), (31.0, 3.0)], fill='#323844')
for i, yc in enumerate((-2.15, 0.0, 2.15)):
    k.eq(32.0, yc - 0.85, 1.6, 1.7, art="eng_front")
    k.peq([(33.6, yc - 0.7), (36.4, yc - 1.05), (36.4, yc + 1.05), (33.6, yc + 0.7)])
    for x in (34.3, 35.0, 35.7):
        k.line(x, yc - 0.82, x, yc + 0.82, FAINT, 1.0)
# stabiliser beams and attitude ports
for sg in (-1, 1):
    k.plate([(29.0, sg * 4.25), (37.6, sg * 4.25), (37.6, sg * 4.85), (29.0, sg * 4.85)])
    k.plate([(35.6, sg * 4.85), (37.6, sg * 4.85), (37.0, sg * 6.0), (35.9, sg * 6.0)], fill='#323844')
    k.bolts(29.4, sg * 4.55, 31.0, sg * 4.55, 2)
    k.eq(36.9, sg * 3.2 - 0.3, 0.9, 0.6, art="rcs_quad")
    k.line(36.4, sg * 2.4, 37.3, sg * 3.2, DIM, 1.2)
k.tank(32.1, 3.2, 2.8, 0.85, HAZ, "PROP")
k.tank(32.1, -4.05, 2.8, 0.85, HAZ, "PROP")
k.pipe([(33.0, 3.2), (33.0, 2.95)], HAZ)
k.pipe([(33.0, -3.2), (33.0, -2.95)], HAZ)
k.port(34.9, 3.62, HAZ)
k.port(34.9, -3.62, HAZ)
# dock clamps under the hull
for x in (18.5, 27.5):
    a, b = k.P(x, 4.25)
    k.o.append(f'<polygon points="{a-18:.0f},{b+90:.0f} {a+18:.0f},{b+90:.0f} {a+9:.0f},{b+4:.0f} {a-9:.0f},{b+4:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

calls = []
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 150 if row == 0 else 840, kind, text))
c(1, 0.7, -4.0, 80, 0, "energy", "磁力牵引头（上下各一）：内侧电磁线圈，断电后仍有残磁")
c(2, 3.5, -5.0, 150, 0, "struct", "可伸缩锁定臂：内节伸缩进固定套筒")
c(3, 6.85, -5.4, 220, 0, "haz", "套筒锁销 ×2（锁死状态：销子插着 + 液压保持）")
c(4, 2.4, -5.0, 290, 0, "sys", "拉力传感器 TS-1 / TS-2")
c(5, 12.0, -3.6, 360, 0, "fluid", "外露液压驱动缸（铰接在 H 框架上）")
c(6, 13.3, -5.0, 430, 0, "struct", "拖臂铰轴（大螺栓销）")
c(7, 13.3, 0.0, 80, 1, "struct", "H 形框架：两根立柱 + 横梁 + 角撑（全船最厚的结构）")
c(8, 9.0, 4.2, 150, 1, "energy", "沿拖臂外露的线圈电缆 + 冷却管")
c(9, 16.4, -3.3, 500, 0, "room", "前观察窗（俯看框架）")
c(10, 17.3, -0.95, 570, 0, "sys", "拖拽作业控制台")
c(11, 18.6, -1.2, 640, 0, "sys", "驾驶位（螺栓 + 滑轨锁）")
c(12, 20.4, -1.5, 710, 0, "energy", "牵引负载监测单元")
c(13, 21.45, -1.8, 780, 0, "haz", "紧急切断模块（红色拉杆）")
c(14, 22.4, -0.85, 850, 0, "room", "驾驶舱生命维持")
c(15, 17.85, 2.6, 220, 1, "fluid", "液压站：液压泵")
c(16, 19.5, 2.0, 290, 1, "haz", "蓄能器 HYD（高压液压油）")
c(17, 21.4, 2.8, 360, 1, "sys", "拖臂驱动阀组")
c(18, 24.4, -2.4, 920, 0, "energy", "中型电池组")
c(19, 26.0, -2.4, 990, 0, "energy", "电容组")
c(20, 27.9, -2.1, 1060, 0, "haz", "牵引线圈供电柜（高压）")
c(21, 24.9, 2.4, 430, 1, "fluid", "冷却模块 + 冷却泵（管路通到两个牵引头）")
c(22, 29.1, 2.1, 500, 1, "energy", "主配电盘 + 总闸")
c(23, 34.5, 0.0, 1130, 0, "sys", "三联短粗大功率喷口")
c(24, 33.5, 3.62, 570, 1, "haz", "推进剂罐 ×2")
c(25, 33.0, 4.55, 640, 1, "struct", "尾部稳定梁 + 尾鳍")
c(26, 37.3, 3.2, 710, 1, "sys", "姿态喷口 ×2")
zones = [(0.0, 16.0, 7.0, "① 前拖拽框架（真空，外置大件）", "struct"), (16.0, 23.0, 7.0, "② 主控制舱（有压）/ 液压站", "room"),
         (23.0, 31.0, 7.0, "③ 动力舱", "energy"), (31.0, 38.0, 7.0, "④ 后推进舱", "struct")]
sheet('h22.html', 1800, 1180, 'H-22「双钩」工程拖船 · 38 m · 结构图（设计稿）',
      ['船头厚重的 H 形框架 + 两根外伸拖臂（像双钩），中部短粗船体，后部大功率短喷口 —— 一台「太空叉车」。',
       '重点不在气压，而在外置大件和高受力部件：看着在外面，其实还连着内部的电、液压和冷却。'], k.svg(), k.P, calls, zones, legend_cols=2, scale_at=(0.0, -7.2))
print('ok')
