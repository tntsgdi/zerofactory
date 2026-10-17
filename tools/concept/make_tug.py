# TUG work boat, 16 m: concept structure sheet (opening: first real ship after training).
# A short, tall push boat: fendered push plate at the bow, a raised wheelhouse,
# a heavy keel, the engine room, an open aft deck with the winch under an A-frame,
# and two thruster pods slung under the hull.
import sys
sys.path.insert(0, '.')
from kit import Kit, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

k = Kit(300, 480, 64.0)
# ---------------- far-side pod first (dashed, behind the hull)
k.poly([(8.6, 3.5), (14.4, 3.5), (15.6, 3.9), (15.6, 4.7), (14.4, 5.1), (8.6, 5.1), (8.0, 4.3)], fill='none', stroke=FAINT, w=1.0, dash='5 4')
# ---------------- the push plate: fender blocks on a bolted plate
k.plate([(-0.35, -2.3), (0.05, -2.3), (0.05, 2.3), (-0.35, 2.3)], fill='#4a505c')
for y in (-2.0, -0.9, 0.2, 1.3):
    k.rect(-0.95, y, 0.6, 0.85, fill='#262b33', stroke=DIM, sw=1.2, rx=0.12)
    k.bolt(-0.2, y + 0.42)
# ---------------- hull: A (pressurised cabin + wheelhouse), M (engine room), T (open deck)
hull = [(0.05, -2.0), (0.5, -2.4), (12.0, -2.4), (12.0, 1.6), (16.0, 1.6), (16.0, 2.4), (11.6, 2.6), (1.0, 2.6), (0.05, 1.7)]
wh = [(0.9, -2.4), (1.9, -4.5), (5.3, -4.5), (5.6, -2.4)]
hin = offset(hull, 0.16)
k.shell(hull, hin)
k.seams(hull, hin)
k.shell([(0.9, -2.3), (1.9, -4.5), (5.3, -4.5), (5.6, -2.3)], [(1.12, -2.3), (2.03, -4.3), (5.12, -4.3), (5.4, -2.3)])
k.room([(1.12, -2.3), (2.03, -4.3), (5.12, -4.3), (5.4, -2.3)])
k.room([(0.25, -1.95), (0.6, -2.24), (5.9, -2.24), (5.9, 2.42), (1.05, 2.42), (0.25, 1.62)])
k.room([(6.1, -2.24), (11.84, -2.24), (11.84, 2.42), (6.1, 2.42)])
k.plate([(1.12, -2.3), (2.03, -4.3), (2.25, -4.3), (1.36, -2.3)], fill='#1b3550', stroke=AIR)     # windscreen
k.plate([(5.9, -2.24), (6.1, -2.24), (6.1, 2.42), (5.9, 2.42)])
k.door(5.92, 0.2, 0.16, 2.0)                                              # A ↔ M inner door
k.door(5.12, -4.1, 0.16, 1.5)                                             # entry hatch at the back of the wheelhouse
k.port(4.9, -3.4, AIR)                                                    # measure-before-opening point
k.plate([(11.84, -2.24), (12.0, -2.24), (12.0, 1.6), (11.84, 1.6)])
# keel: one heavy bolted beam under the whole boat
k.plate([(1.2, 2.6), (15.4, 2.6), (15.0, 3.15), (1.6, 3.15)], fill='#4a505c')
for x in range(2, 16, 1):
    k.bolt(x + 0.1, 2.88)
# floors
k.plate([(0.6, 1.2), (5.9, 1.2), (5.9, 1.32), (0.6, 1.32)], fill='#2a3140')
k.plate([(1.3, -2.3), (5.5, -2.3), (5.5, -2.18), (1.3, -2.18)], fill='#2a3140')
# ---------------- A: wheelhouse (pilot + one seat, nav) and lower cabin (FDR, O2)
k.seat(2.6, -2.3, 1.45)
k.seat(3.8, -2.3, 1.45, op=0.6)
k.eq(1.75, -3.55, 0.6, 0.55, art="console")
k.eq(4.6, -4.25, 0.5, 0.9, art="nav", col=VIO, tag="NAV-T")
k.eq(1.2, -0.6, 1.2, 1.8, art="locker")
k.eq(2.6, 0.45, 0.62, 0.62, art="blackbox", must=True, tag="FDR-T")
k.eq(3.5, -1.6, 0.42, 1.55, art="gastank", col=AIR, hazard="gas_tank", tag="O2-T")
k.eq(4.2, -0.2, 1.4, 1.36, art="env", col=AIR)
k.eq(1.6, 1.4, 4.0, 1.0, art="grating")
# ---------------- M: engine, battery, fuel tank, main switch
k.eq(6.4, -0.6, 3.0, 2.9, art="eng_core", tag="ENG-T")
k.eq(9.9, -2.0, 1.7, 1.1, art="battery", col=VIO, tag="BAT-T")
k.switch(9.6, -0.3, HEAT)
k.label(9.6, -0.6, "K-T", 9, HEAT, 'middle')
k.eq(9.8, 0.5, 1.8, 1.7, art="fueltank", col=FLUID, hazard="fluid", tag="FT-T")
k.port(11.2, 2.3, FLUID)
k.label(11.2, 2.05, "回收口", 9, FLUID, 'middle')
k.cable([(10.75, -0.9), (10.75, -0.3), (9.6, -0.3), (8.0, -0.3), (8.0, -1.9), (5.0, -1.9), (5.0, -3.6), (4.85, -3.6)], HEAT)
k.cable([(10.75, -0.9), (10.75, -1.95), (11.9, -1.95), (12.4, -1.95), (12.4, 0.4)], HEAT)
k.pipe([(9.8, 1.4), (9.4, 1.4)], FLUID)
k.pipe([(10.7, 2.2), (10.7, 3.6), (11.0, 3.6)], FLUID)
# ---------------- T: open deck, winch, A-frame, tow line, bulwark
for x in (12.6, 13.6, 14.6, 15.6):
    k.line(x, 1.6, x, 1.0, HULLS, 2.0)
k.line(12.2, 1.0, 16.0, 1.0, HULLS, 1.4)
k.plate([(12.5, 1.6), (12.75, 1.6), (14.1, -3.8), (13.9, -3.8)], fill='#4a505c')
k.plate([(15.6, 1.6), (15.85, 1.6), (14.25, -3.8), (14.05, -3.8)], fill='#4a505c')
k.circ(14.08, -3.75, 0.32, fill=EQF, stroke=DIM, sw=1.3)
k.eq(12.5, -0.3, 2.6, 1.9, art="reel", must=True, tag="WINCH-T")
k.lock(12.7, 1.5)
k.lock(14.9, 1.5)
k.bolts(12.6, 1.62, 15.0, 1.62, 4)
k.pline([(13.8, -0.25), (13.85, -3.45), (14.3, -3.9), (16.8, -1.6), (17.4, -0.4)], DIM, 1.4)
k.poly([(17.2, -0.4), (17.6, -0.4), (17.55, 0.1), (17.25, 0.1)], fill=EQF, stroke=EQ)
# ---------------- thruster pod (near side) under the hull
k.plate([(9.6, 3.15), (10.2, 3.15), (10.4, 3.6), (9.4, 3.6)], fill='#4a505c')
k.plate([(13.6, 3.15), (14.2, 3.15), (14.4, 3.6), (13.4, 3.6)], fill='#4a505c')
k.poly([(8.4, 3.6), (14.4, 3.6), (15.2, 3.9), (15.2, 4.9), (14.4, 5.2), (8.4, 5.2), (7.8, 4.4)], fill=HULLF, stroke=HULLS)
k.peq([(15.2, 3.95), (16.4, 3.7), (16.4, 5.1), (15.2, 4.85)])
k.pipe([(11.0, 3.6), (11.0, 4.2), (14.6, 4.2)], FLUID)
for x in (9.2, 10.4, 11.6, 12.8):
    k.bolt(x, 3.75)
for y in (-2.2, 1.9):
    k.eq(0.35, y - 0.18, 0.6, 0.36, art="rcs_quad")
k.label(-0.65, -2.6, "顶推护舷", 10, DIM, 'middle')

calls = []


def c(n, x, y, row, kind, text):
    calls.append((n, x, y, 0, 170 if row == 0 else 930, kind, text))


c(1, -0.65, -1.5, 0, "struct", "顶推护舷（橡胶块 + 螺栓压板）")
c(2, 1.7, -3.4, 0, "room", "驾驶室挡风玻璃")
c(3, 2.9, -3.0, 0, "sys", "驾驶座 + 副座")
c(4, 4.85, -3.8, 0, "energy", "导航计算机 NAV-T")
c(5, 5.2, -3.3, 0, "room", "入口舱门 + 测压点（先测再开门）")
c(6, 2.9, 0.75, 1, "haz", "记录仪 FDR-T（强制，剧情物件位）")
c(7, 3.7, -0.8, 1, "room", "氧瓶 O2-T")
c(8, 5.95, 1.2, 1, "room", "A ↔ M 内门")
c(9, 7.9, 0.8, 1, "sys", "主机 ENG-T")
c(10, 10.75, -1.45, 0, "energy", "电池 BAT-T")
c(11, 9.6, -0.3, 0, "haz", "总闸 K-T（断开前切线会打火）")
c(12, 10.7, 1.35, 1, "fluid", "燃料罐 FT-T + 回收口")
c(13, 13.8, 0.65, 1, "haz", "拖缆绞车 WINCH-T（强制，1.2 t，螺栓 + 2 把锁）")
c(14, 14.08, -3.75, 0, "struct", "A 形吊架 + 滑轮")
c(15, 17.4, -0.15, 0, "sys", "拖缆 + 钩头")
c(16, 8.0, 2.88, 1, "struct", "龙骨梁（整条螺栓）")
c(17, 12.0, 4.4, 1, "sys", "推进吊舱 ×2（近侧实线，远侧虚线）")
c(18, 12.4, 0.0, 1, "haz", "绞车电缆（穿舱壁）")
zones = [(-1.0, 6.0, 6.2, "A 驾驶 / 乘员舱（有压）", "room"), (6.0, 12.0, 6.2, "M 机舱（有压）", "sys"), (12.0, 16.0, 6.2, "T 拖曳甲板（无压）", "struct")]
sheet('tug.html', 1800, 1200, '作业艇（TUG）· 16 m · 结构图（设计稿，开局：训练后的第一艘真船）',
      ['短而高的顶推艇：船头一块护舷顶推板，驾驶室高高架在前舱上，下面一根粗龙骨，船尾敞开甲板上一台绞车压在 A 形吊架下。',
       '每样危险只出现一次、都很温和：先测再开门 · 断电 · 回收液体 · 大件拖运。没有陷阱。'],
      k.svg(), k.P, calls, zones, legend_cols=2, auto=True, scale_at=(8.0, -4.4), scale_m=2)
print('ok')
