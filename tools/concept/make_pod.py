# POD cargo pod, 20 m: concept structure sheet.
# An open cage, not a hull: a front module with the docking ring, then three
# cargo cells whose roof steps down towards the stern, motor-hinged roof
# covers, a lifting yoke bolted over the cage, and two small RCS tanks aft.
import sys
sys.path.insert(0, '.')
from kit import Kit, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

k = Kit(290, 560, 52.0)
FLOOR = 3.0
CELLS = [(4.0, 9.2, -3.2, "H1"), (9.2, 14.4, -2.7, "H2"), (14.4, 20.0, -2.0, "H3")]
# ---------------- front module + docking ring
front = [(0.0, -1.6), (1.2, -3.0), (4.0, -3.4), (4.0, 3.4), (1.2, 3.0), (0.0, 1.6)]
fin = offset(front, 0.2)
k.shell(front, fin)
k.seams(front, fin)
k.poly(fin, fill='#1a1f28', stroke='none')
k.plate([(-0.7, -1.9), (0.0, -1.9), (0.0, 1.9), (-0.7, 1.9)], fill='#4a505c')
k.ell(-0.7, 0.0, 0.35, 1.9, fill=EQF, stroke=AIR, sw=1.4)
k.bolts(-0.35, -1.7, -0.35, 1.7, 6)
k.eq(1.2, -2.2, 2.2, 1.6, art="nav", col=VIO, tag="AV-P")
k.eq(1.4, 0.2, 2.2, 1.4, art="battery", col=VIO, tag="BAT-P")
k.switch(2.5, 2.2, HEAT)
k.label(2.5, 2.75, "K-P", 9, HEAT, 'middle')
# ---------------- the cage: rails, frames, stepped roof
for x0, x1, top, t in CELLS:
    k.plate([(x0, top - 0.25), (x1, top - 0.25), (x1, top + 0.05), (x0, top + 0.05)], fill='#4a505c')
    k.plate([(x0 - 0.18, top - 0.25), (x0 + 0.18, top - 0.25), (x0 + 0.18, FLOOR + 0.3), (x0 - 0.18, FLOOR + 0.3)], fill='#4a505c')
    k.room([(x0 + 0.2, top + 0.05), (x1 - 0.2, top + 0.05), (x1 - 0.2, FLOOR), (x0 + 0.2, FLOOR)])
    k.label((x0 + x1) / 2, top - 0.5, t, 11, DIM, 'middle')
# ---------------- far-side bracing (behind the cargo)
for x0, x1, top, _ in CELLS:
    k.line(x0, top, x1, FLOOR, '#3a4456', 1.2, dash='5 4')
    k.line(x0, FLOOR, x1, top, '#3a4456', 1.2, dash='5 4')
k.plate([(19.82, -2.25), (20.18, -2.25), (20.18, FLOOR + 0.3), (19.82, FLOOR + 0.3)], fill='#4a505c')
k.plate([(4.0, FLOOR), (20.0, FLOOR), (20.0, FLOOR + 0.3), (4.0, FLOOR + 0.3)], fill='#4a505c')   # floor rails
for x in range(5, 20):
    k.bolt(x, FLOOR + 0.15)
# roof covers on motor hinges (one per cell), open one shown on H3
for x0, x1, top, t in CELLS[:2]:
    k.plate([(x0 + 0.3, top - 0.55), (x1 - 0.3, top - 0.55), (x1 - 0.3, top - 0.3), (x0 + 0.3, top - 0.3)], fill='#2a3140', stroke=AIR)
    k.circ(x0 + 0.45, top - 0.43, 0.2, fill=EQF, stroke=HEAT, sw=1.3)
k.plate([(14.75, -2.55), (15.0, -2.55), (16.9, -5.9), (16.65, -5.9)], fill='#2a3140', stroke=AIR)
k.circ(14.85, -2.43, 0.2, fill=EQF, stroke=HEAT, sw=1.3)
k.cable([(2.5, 2.2), (3.6, 2.2), (3.6, -3.7), (4.45, -3.7), (4.45, -3.6)], HEAT)
k.cable([(4.45, -3.7), (9.4, -3.7), (9.4, -3.2), (9.65, -3.2)], HEAT)
k.cable([(9.65, -3.2), (14.6, -3.2), (14.85, -2.6)], HEAT)
k.cable([(2.0, 0.9), (2.5, 0.9), (2.5, 2.2)], HEAT)
# ---------------- lifting yoke over H1-H2
k.plate([(5.0, -3.45), (5.5, -3.45), (8.5, -5.6), (8.0, -5.6)], fill='#4a505c')
k.plate([(13.4, -2.95), (13.9, -2.95), (11.0, -5.6), (10.5, -5.6)], fill='#4a505c')
k.plate([(8.0, -5.9), (11.0, -5.9), (11.0, -5.5), (8.0, -5.5)], fill='#4a505c')
k.circ(9.5, -6.35, 0.42, fill='none', stroke=DIM, sw=2.0)
k.bolts(5.0, -3.4, 5.6, -3.4, 2)
k.bolts(13.3, -2.9, 13.9, -2.9, 2)
# ---------------- cargo: containers on rails with locks; heavy, hazardous, loose bulk
def box(x, y, w, h, tag, must=False, col=None, hz=""):
    k.eq(x, y, w, h, art="cargo", tag=tag, must=must, col=col, hazard=hz)
    k.lock(x + 0.25, y + h + 0.0)
    k.lock(x + w - 0.25, y + h + 0.0)


box(4.5, 0.4, 2.1, 2.6, "CG-1")
box(6.8, -0.4, 2.1, 3.4, "CG-2")
box(9.6, -1.6, 3.4, 4.6, "CG-3", col=HAZ)
k.label(11.3, -1.9, "3.5–4.2 t", 10, HAZ, 'middle')
box(13.1, 1.0, 1.1, 2.0, "CG-4")
box(14.8, 0.2, 2.3, 2.8, "CG-5", col=HAZ, hz="fluid")
k.rect(17.4, -0.6, 2.2, 3.6, fill='none', stroke=DIM, sw=1.0, dash='3 3')     # loose bulk in a net
for i, (x, y, w, h) in enumerate([(17.6, 2.2, 0.6, 0.7), (18.3, 2.4, 0.5, 0.5), (18.9, 2.1, 0.55, 0.8), (17.7, 1.4, 0.7, 0.7), (18.5, 1.6, 0.45, 0.7), (19.0, 1.3, 0.45, 0.7), (17.9, 0.6, 0.5, 0.7), (18.6, 0.9, 0.6, 0.6)]):
    k.rect(x, y, w, h, fill=EQF, stroke=EQ, sw=0.9)
k.label(18.5, -0.85, "CG-6 散装", 10, DIM, 'middle')
# ---------------- aft: RCS tanks + thruster quads
for sg in (-1, 1):
    k.sphere(20.9, sg * 1.5, 0.65, FLUID, "", jacket=0.0)
    k.pipe([(20.9, sg * 0.85), (20.9, 0.0), (20.2, 0.0)], FLUID, 1.2)
    k.eq(20.2, sg * 2.6 - 0.25, 0.9, 0.5, art="rcs_quad")
    k.eq(0.6, sg * 2.2 - 0.25, 0.9, 0.5, art="rcs_quad")
for x in (6.0, 12.0, 18.0):
    a, b = k.P(x, FLOOR + 0.3)
    k.o.append(f'<polygon points="{a-12:.0f},{b+48:.0f} {a+12:.0f},{b+48:.0f} {a+6:.0f},{b+3:.0f} {a-6:.0f},{b+3:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

calls = []


def c(n, x, y, row, kind, text):
    calls.append((n, x, y, 0, 170 if row == 0 else 900, kind, text))


c(1, -0.7, -1.0, 0, "room", "对接环 DOCK-P（螺栓一圈）")
c(2, 2.3, -1.4, 0, "energy", "航电 AV-P")
c(3, 2.5, 0.9, 1, "energy", "电池 BAT-P（舱盖电机的电源）")
c(4, 2.5, 2.2, 1, "haz", "总闸 K-P")
c(5, 4.45, -3.7, 0, "haz", "舱盖电机 ×3（带电硬撬会烧电机）")
c(6, 7.0, -3.75, 0, "room", "顶部舱盖（关）")
c(7, 16.2, -5.0, 0, "room", "顶部舱盖（开）")
c(8, 9.5, -6.35, 0, "struct", "吊装轭架 + 吊环（螺栓在笼顶）")
c(9, 6.0, 1.6, 1, "sys", "货柜 CG-1 / CG-2（导轨 + 每个 4 把锁）")
c(10, 11.3, 0.8, 1, "haz", "超重货柜 CG-3（超过 3 t 抓钩上限）")
c(11, 13.6, 2.0, 1, "sys", "小货柜 CG-4")
c(12, 15.9, 1.6, 1, "haz", "危险品货柜 CG-5 → 危险品口")
c(13, 18.5, 1.4, 1, "sys", "散装 CG-6 → 熔炉 / 碎屑网")
c(14, 12.0, 3.15, 1, "struct", "底部导轨（整排螺栓）")
c(15, 11.7, -0.7, 0, "struct", "笼架斜撑（远侧，虚线）")
c(16, 20.9, -1.5, 0, "fluid", "姿控推进剂小罐 RCS-P1 / P2")
c(17, 20.65, 2.6, 1, "sys", "姿控喷口")
zones = [(-1.0, 4.0, 5.2, "F 前端", "energy"), (4.0, 9.2, 5.2, "H1 货舱一", "sys"), (9.2, 14.4, 5.2, "H2 货舱二", "sys"), (14.4, 21.6, 5.2, "H3 货舱三 + 尾", "haz")]
sheet('pod.html', 1800, 1160, '货运吊舱（POD）· 20 m · 结构图（设计稿，合同市场）',
      ['不是船壳，是一只敞开的笼子：前端对接环，后面三格货舱、顶部一格比一格低，顶上一副吊装轭架。几乎没有系统，难点全在货。',
       '顺序：断电 → 手动开舱盖 → 按货单分拣（普通 → 设备口，危险品 → 危险品口，散装 → 熔炉）→ 超重货柜要么换 5 吨抓钩、要么切开。'],
      k.svg(), k.P, calls, zones, legend_cols=2, auto=True, scale_at=(-0.5, -5.2), scale_m=2)
print('ok')
