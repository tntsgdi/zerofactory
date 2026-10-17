# MED-47 "Silence" medical / isolation ship, 82 m: concept structure sheet.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

COLD = '#9fe3ff'
k = Kit(105, 520, 19.6)
CT, CB = -1.75, 1.75                     # the main corridor tube
# ---------------- the pods (drawn first: they sit on the corridor like the teeth of a comb)
POD_X = [14.0, 22.5, 31.0, 39.5, 48.0, 56.5]
KINDS_TOP = ["emer", "surg", "iso", "cryo", "emer", "iso"]
KINDS_BOT = ["surg", "cryo", "iso", "emer", "surg", "cryo"]
NAMES = {"emer": "急救舱", "surg": "手术舱", "iso": "隔离舱", "cryo": "冷冻保存舱"}


def pod(cx, sg, kind, idx):
    w, h = 6.6, 5.6
    y0 = CT - 1.1 if sg < 0 else CB + 1.1           # neck end
    ny0, ny1 = (CT, y0) if sg < 0 else (y0, CB)
    # the neck (docking collar with the pod's own door)
    k.plate([(cx - 1.0, min(ny0, ny1)), (cx + 1.0, min(ny0, ny1)), (cx + 1.0, max(ny0, ny1)), (cx - 1.0, max(ny0, ny1))])
    k.door(cx - 0.65, min(ny0, ny1) + 0.15, 1.3, abs(ny1 - ny0) - 0.3)
    py0 = y0 - h if sg < 0 else y0
    outer = [(cx - w / 2 + 0.8, py0), (cx + w / 2 - 0.8, py0), (cx + w / 2, py0 + 0.8), (cx + w / 2, py0 + h - 0.8), (cx + w / 2 - 0.8, py0 + h), (cx - w / 2 + 0.8, py0 + h), (cx - w / 2, py0 + h - 0.8), (cx - w / 2, py0 + 0.8)]
    inner = offset(outer, 0.32)
    k.shell(outer, inner)
    k.room(inner)
    # each pod's own power and air
    fy = py0 + 0.45 if sg < 0 else py0 + h - 1.25
    k.eq(cx + w / 2 - 1.35, fy, 0.95, 0.8, art="battery", col=VIO)
    k.eq(cx + w / 2 - 2.45, fy, 0.95, 0.8, art="env", col=AIR)
    floor = py0 + h - 0.32 if sg < 0 else py0 + 0.32         # the side towards the corridor is the floor
    up = -1 if sg < 0 else 1
    if kind == "emer":
        k.eq(cx - 2.5, floor + up * 0.0 - (0.9 if up < 0 else 0.0), 3.2, 0.9 if True else 0.9, art="bunk")
        k.eq(cx - 2.6, floor - (2.6 if up < 0 else -1.5), 1.0, 1.1, art="nav_rack", col=VIO)
    elif kind == "surg":
        k.eq(cx - 1.9, floor - (1.0 if up < 0 else -0.2), 3.0, 0.8, art="cabinet")
        lx, ly = cx - 0.4, (py0 + 0.32 if sg < 0 else py0 + h - 0.32)
        k.line(lx, ly, lx, ly - up * 1.5, EQ, 1.6)
        k.ell(lx, ly - up * 1.7, 0.7, 0.18, fill=EQF, stroke=EQ, sw=1.2)
    elif kind == "iso":
        k.eq(cx - 2.5, floor - (0.9 if up < 0 else 0.0), 3.0, 0.9, art="bunk")
        k.eq(cx - 2.6, floor - (2.5 if up < 0 else -1.3), 0.9, 1.0, art="radiator", col=AIR)
        k.eq(cx + 0.7, floor - (2.0 if up < 0 else -1.2), 0.6, 0.75, art="glove")
        k.label(cx, py0 + h / 2 + 0.2, "−15 Pa", 9, AIR, 'middle')
    elif kind == "cryo":
        for i in range(3):
            k.tank(cx - 2.6 + i * 1.15, py0 + 0.6 if sg < 0 else py0 + 1.2, 0.9, 3.4, COLD)
        k.eq(cx + w / 2 - 2.45, fy + (-1.0 if sg < 0 else 1.0) * 0.0 - (0.0), 0.95, 0.8, art="pump", col=COLD)
        k.label(cx - 1.4, py0 + h / 2 + 0.25, "−80 °C", 9, COLD, 'middle')
    # v2 fill: on the floor by the far wall a kind-specific unit, an oxygen bottle, a supply cabinet overhead
    def stand(x, ww, hh):
        return (x, floor - hh) if sg < 0 else (x, floor)
    x, y = stand(cx + 2.05, 0.5, 1.6)
    k.tank(x, y, 0.5, 1.6, AIR)
    if kind == "emer":
        x, y = stand(cx + 0.8, 1.0, 1.4)
        k.eq(x, y, 1.0, 1.4, art="env", col=AIR)                               # ventilator
        x, y = stand(cx - 0.3, 0.9, 0.7)
        k.eq(x, y - up * 0.0, 0.9, 0.7, art="cap", col=HEAT)                   # defibrillator
    elif kind == "surg":
        x, y = stand(cx + 0.8, 1.1, 1.7)
        k.eq(x, y, 1.1, 1.7, art="o2cab", col=AIR, hazard="gas_tank")          # anaesthesia machine
    elif kind == "iso":
        x, y = stand(cx + 0.8, 1.0, 1.1)
        k.eq(x, y, 1.0, 1.1, col=HAZ)                                           # biohazard waste bin
        k.label(cx + 1.3, y + 0.7, "BIO", 8, HAZ, 'middle')
    elif kind == "cryo":
        x, y = stand(cx + 0.9, 0.9, 1.3)
        k.eq(x, y, 0.9, 1.3, art="panel", col=COLD)
    k.label(cx, (py0 - 0.4) if sg < 0 else (py0 + h + 0.9), NAMES[kind] + " %s%d" % ("U" if sg < 0 else "L", idx + 1), 10, AIR if kind != "cryo" else COLD, 'middle')
    k.port(cx - w / 2 + 0.6, py0 + (0.05 if sg < 0 else h - 0.05), AIR)


for i, cx in enumerate(POD_X):
    pod(cx, -1, KINDS_TOP[i], i)
    pod(cx, 1, KINDS_BOT[i], i)
# ---------------- the main corridor: one pressurised tube the length of the ship
k.plate([(9.6, CT), (62.4, CT), (62.4, CB), (9.6, CB)])
k.room([(9.6, CT + 0.35), (62.4, CT + 0.35), (62.4, CB - 0.35), (9.6, CB - 0.35)])
for cx in POD_X:
    k.plate([(cx - 1.0, CT - 0.02), (cx + 1.0, CT - 0.02), (cx + 1.0, CT + 0.36), (cx - 1.0, CT + 0.36)], fill='#1d222a', stroke=AIR)
    k.plate([(cx - 1.0, CB - 0.36), (cx + 1.0, CB - 0.36), (cx + 1.0, CB + 0.02), (cx - 1.0, CB + 0.02)], fill='#1d222a', stroke=AIR)
for x in range(12, 62, 3):
    k.line(x, CT, x, CT + 0.35, '#0d1117', 1.2)
    k.line(x, CB, x, CB - 0.35, '#0d1117', 1.2)
k.line(10.0, 1.0, 62.0, 1.0, EQ, 1.4)                                  # walkway
for x in range(11, 62, 2):
    k.line(x, 1.0, x + 0.6, 1.4, FAINT, 0.8)
for x in (18.2, 26.7, 35.2, 43.7, 52.2):                               # life-support interfaces along the corridor
    k.eq(x - 0.4, -1.3, 0.8, 0.8, art="env", col=AIR)
k.door(35.0, CT + 0.35, 0.3, CB - CT - 0.7)                             # a pressure door half way
k.cable([(10.0, -0.3), (62.0, -0.3)], HEAT)
k.pipe([(10.0, 0.2), (62.0, 0.2)], AIR, 1.4)
k.pipe([(10.0, 0.45), (62.0, 0.45)], FLUID, 1.2)
# ---------------- front cockpit and dispatch
nose = [(0.4, -0.4), (1.6, -2.8), (4.6, -3.6), (9.6, -3.6), (9.6, 3.6), (4.6, 3.6), (1.6, 2.8), (0.4, 0.4)]
k.shell(nose, offset(nose, 0.35))
k.room(offset(nose, 0.35))
k.plate([(0.4, -0.4), (1.6, -2.8), (1.95, -2.45), (0.79, -0.32)], fill='#1b3550', stroke=AIR)
k.eq(1.3, -0.4, 1.2, 1.1, art="console")
k.seat(2.8, 0.7, 1.55)
k.eq(4.2, -0.6, 1.8, 1.3, art="console")                                 # medical dispatch desk
k.eq(4.3, -3.2, 4.8, 1.5, art="swb", col=AIR)                            # pod status overview wall
k.label(6.7, -1.45, "PODS 12 / 12", 9, AIR, 'middle')
k.eq(6.6, 0.9, 2.6, 2.2, art="nav_rack", col=VIO)
k.door(9.45, -1.2, 0.3, 2.3)
# ---------------- life support: air regeneration, water cycle, drug stores, filters, backup power
ls = [(62.4, -5.2), (74.0, -5.2), (75.6, -3.6), (75.6, 3.6), (74.0, 5.2), (62.4, 5.2)]
k.shell(ls, offset(ls, 0.4))
k.room(offset(ls, 0.4))
k.eq(63.0, -4.6, 4.2, 3.0, art="env", col=AIR)                           # air regeneration
k.label(65.1, -1.2, "AIR REGEN", 9, AIR, 'middle')
k.tank(67.6, -4.6, 1.3, 3.0, FLUID)
k.tank(69.1, -4.6, 1.3, 3.0, FLUID)
k.label(68.95, -1.2, "WATER", 9, FLUID, 'middle')
k.eq(70.7, -4.6, 1.6, 1.6, art="pump", col=FLUID)
for i in range(3):
    k.eq(63.0 + i * 1.5, 0.9, 1.3, 3.5, art="locker")                    # drug storage
k.label(65.2, 4.8, "PHARMACY", 9, DIM, 'middle')
k.eq(67.8, 1.2, 2.2, 1.6, art="radiator", col=AIR)                       # filter units
k.eq(70.4, 0.6, 2.4, 2.8, art="gen", col=HEAT)                           # backup power
k.label(71.6, 3.9, "BACKUP GEN", 9, HEAT, 'middle')
k.eq(72.2, -2.4, 1.6, 2.4, art="swb", col=HEAT)
k.pipe([(68.25, -1.6), (68.25, -0.2), (62.4, -0.2)], FLUID)
k.port(73.0, -5.45, AIR)
# v2 fill: CO2 scrubber, O2 generator, medical gas bottles, biohazard waste tank, battery bank
k.eq(72.6, -4.6, 2.2, 2.0, art="env", col=AIR)
k.label(73.7, -2.3, "CO₂ SCRUB", 7, AIR, 'middle')
for i in range(5):
    k.tank(62.9 + i * 0.75, -1.35, 0.55, 1.0, AIR)
k.label(64.7, -1.55, "MED GAS", 7, AIR, 'middle')
k.eq(67.4, -1.4, 2.4, 1.0, art="o2cab", col=AIR, hazard="gas_tank")
k.label(68.6, -1.55, "O₂ GEN", 7, AIR, 'middle')
k.tank(73.1, 0.8, 1.6, 3.4, HAZ, "BIO")
k.eq(70.0, -1.3, 2.0, 0.95, art="battery", col=VIO)
# corridor: emergency lockers between the interfaces, a decontamination lock at the pressure door
for x in (15.6, 24.1, 32.6, 41.1, 49.6, 58.1):
    k.rect(x, -1.38, 0.62, 0.55, fill=EQF, stroke=AIR, sw=1.0)
k.rect(33.6, -1.38, 3.3, 2.75, fill='none', stroke=HAZ, sw=1.2, dash='4 3')
k.label(35.25, 1.85, "DECON", 8, HAZ, 'middle')
k.switch(74.6, 4.9, HEAT)
# ---------------- tail: small thrusters, the aft maintenance crawlway
k.plate([(75.6, -1.2), (81.0, -1.2), (81.0, 1.2), (75.6, 1.2)], fill='#2a2f39')
k.room([(75.8, -0.95), (80.8, -0.95), (80.8, 0.95), (75.8, 0.95)])
k.label(78.3, 0.25, "MAINT", 9, DIM, 'middle')
for sg in (-1, 1):
    k.eq(75.8, sg * 2.6 - 0.7, 1.6, 1.4, art="eng_front")
    k.peq([(77.4, sg * 2.6 - 0.55), (80.6, sg * 2.6 - 0.95), (80.6, sg * 2.6 + 0.95), (77.4, sg * 2.6 + 0.55)])
for x in (18.25, 43.75):
    a, b = k.P(x, CB)
    b2 = k.P(x, 9.4)[1]
    k.o.append(f'<polygon points="{a-12:.0f},{b2:.0f} {a+12:.0f},{b2:.0f} {a+6:.0f},{b+3:.0f} {a-6:.0f},{b+3:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

calls = []
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 150 if row == 0 else 880, kind, text))
c(1, 1.9, 0.1, 80, 1, "sys", "驾驶位 + 驾驶台")
c(2, 5.1, 0.0, 150, 1, "sys", "医疗调度台")
c(3, 6.7, -2.5, 80, 0, "room", "舱段状态总览屏（12 个医疗舱）")
c(4, 30.0, 1.0, 220, 1, "room", "中央主廊：贯穿全船的加压廊道 + 走道")
c(5, 26.7, -0.9, 150, 0, "room", "主廊上的生命支持接口（每 8.5 m 一组）")
c(6, 35.15, 0.0, 290, 1, "room", "主廊中段压力门")
c(7, 22.5, CT - 0.55, 220, 0, "room", "每个医疗舱：独立舱门（对接颈）")
c(8, 15.8, -7.6, 290, 0, "energy", "每个医疗舱：独立电源（小电池）")
c(9, 14.7, -7.6, 360, 0, "room", "每个医疗舱：独立空气循环")
c(10, 12.5, -3.5, 430, 0, "sys", "急救舱：担架床 + 监护仪")
c(11, 22.5, -5.2, 500, 0, "sys", "手术舱：手术台 + 无影灯")
c(12, 31.0, -6.3, 570, 0, "haz", "隔离舱：负压 + 过滤器 + 手套口（可能残压）")
c(13, 39.5, -6.3, 640, 0, "fluid", "冷冻保存舱：冷冻柜（可能仍在工作）")
c(14, 63.6, 3.0, 360, 1, "sys", "药剂储存柜")
c(15, 65.1, -3.0, 710, 0, "room", "空气再生系统")
c(16, 68.4, -3.0, 780, 0, "fluid", "水循环：水箱 + 泵")
c(17, 68.9, 2.0, 430, 1, "room", "过滤单元")
c(18, 71.6, 2.0, 500, 1, "haz", "备用发电机（可能还在给局部生命支持供电）")
c(19, 73.0, -1.2, 850, 0, "energy", "生命维持段配电")
c(20, 78.3, 0.0, 570, 1, "room", "后部维保通道")
c(21, 79.0, -2.6, 920, 0, "sys", "小型推进器 ×2")
c(0, 15.6, -6.8, 0, 0, "room", "每个医疗舱：氧瓶 + 专用设备（呼吸机 / 除颤仪 / 麻醉机 / 控制面板）")
c(0, 31.8, -7.4, 0, 0, "haz", "隔离舱：生物危险废物箱（BIO，新危险品）")
c(0, 49.0, -1.1, 0, 0, "room", "主廊应急柜（氧气面罩 / 灭火器）")
c(0, 35.25, 0.8, 0, 1, "haz", "中段洗消气闸（隔离区 ↔ 清洁区）")
c(0, 73.7, -3.6, 0, 0, "room", "CO₂ 洗涤器")
c(0, 64.7, -0.8, 0, 1, "room", "医用气体瓶组 ×5")
c(0, 68.6, -0.9, 0, 1, "room", "电解制氧机")
c(0, 73.9, 2.5, 0, 1, "haz", "生物废液罐 BIO")
c(0, 71.0, -0.8, 0, 1, "energy", "生命维持电池组")
zones = [(0.4, 9.6, 14.0, "① 驾驶与调度舱", "room"), (9.6, 62.4, 14.0, "② 中央主廊 + ③ 两侧独立医疗舱阵列（12 个）", "room"),
         (62.4, 75.6, 14.0, "④ 生命维持段", "room"), (75.6, 81.0, 14.0, "⑤ 尾部", "struct")]
sheet('med47.html', 1800, 1300, 'MED-47「缄默」医疗船 · 82 m · 结构图（设计稿 v2）',
      ['中央细长主船体，两侧像梳子一样伸出 12 个独立医疗舱，尾部一大块生命维持模块 —— 模块化、洁净、脆弱。',
       '第一次面对「每个舱都有一点不一样」：独立门、独立电源、独立空气循环，像剥洋葱一样一层层拆。'], k.svg(), k.P, calls, zones, legend_cols=2, auto=True, scale_at=(0.0, -12.6), scale_m=10)
print('ok')
