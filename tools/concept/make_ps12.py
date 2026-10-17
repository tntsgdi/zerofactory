# PS-12 "Dawn" passenger ship, 108 m: concept structure sheet.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

k = Kit(100, 500, 14.6)
DECK = 0.0
# ---------------- the main hull: two decks, a bulge amidships like an airliner's cabin
outer = [(0.6, -0.6), (3.2, -4.6), (11.0, -7.4), (28.0, -8.8), (54.0, -8.8), (68.0, -6.6), (72.4, -4.0), (72.4, 4.0), (62.0, 7.8), (26.0, 8.2), (10.0, 6.4), (2.4, 3.0)]
inner = offset(outer, 0.42)
k.shell(outer, inner)
k.seams(outer, inner)
for x in range(14, 70, 4):
    yt = -8.8 if 28 <= x <= 54 else None
for x in range(8, 70, 2):
    # a row of cabin windows along each deck (glass in the hull band)
    if 12 <= x <= 66:
        k.rect(x, -7.95 if 26 <= x <= 56 else -7.4 + max(0, (26 - x)) * 0.04, 0.9, 0.3, fill='#1b3550', stroke=AIR, sw=0.8, rx=0.12)
    if 14 <= x <= 58:
        k.rect(x, 7.45 if x < 40 else 7.3, 0.9, 0.28, fill='#1b3550', stroke=AIR, sw=0.8, rx=0.12)
# the big observation glazing at the bow
k.plate([(0.6, -0.6), (3.2, -4.6), (11.0, -7.4), (11.1, -6.95), (3.55, -4.25), (1.03, -0.55)], fill='#1b3550', stroke=AIR)
# decks and bulkheads
k.plate([(1.2, DECK - 0.22), (72.0, DECK - 0.22), (72.0, DECK + 0.22), (1.6, DECK + 0.22)])
for x in range(4, 72, 3):
    k.bolt(x, DECK)
rooms_up = [(10.0, 18.5), (18.5, 44.0), (52.0, 72.0)]
k.room(offset([(1.6, -0.6), (3.4, -4.3), (10.0, -7.0), (10.0, DECK - 0.22), (1.6, DECK - 0.22)], 0.05))
for x0, x1 in rooms_up:
    top = -8.38 if 22 <= (x0 + x1) / 2 <= 60 else -7.6
    k.room([(x0 + 0.15, top if x0 > 12 else -6.95), (x1 - 0.15, top), (x1 - 0.15, DECK - 0.22), (x0 + 0.15, DECK - 0.22)])
for x0, x1 in [(6.0, 44.0), (52.0, 71.6)]:
    k.room([(x0 + 0.15, DECK + 0.22), (x1 - 0.15, DECK + 0.22), (x1 - 0.15, 7.6 if x1 < 60 else 4.6), (x0 + 0.15, 7.6 if x0 > 8 else 5.6)])
for x in (10.0, 18.5, 52.0):
    k.plate([(x - 0.15, -8.4 if x > 20 else -7.2), (x + 0.15, -8.4 if x > 20 else -7.2), (x + 0.15, DECK - 0.22), (x - 0.15, DECK - 0.22)])
    k.door(x - 0.12, -2.4, 0.24, 2.1)
k.plate([(43.85, -8.4), (44.15, -8.4), (44.15, 7.8), (43.85, 7.8)])
k.plate([(51.85, -8.4), (52.15, -8.4), (52.15, 7.8), (51.85, 7.8)])
k.door(43.88, -2.4, 0.24, 2.1)
k.door(51.88, -2.4, 0.24, 2.1)
k.door(43.88, 5.0, 0.24, 2.1)
k.door(51.88, 5.0, 0.24, 2.1)
k.plate([(71.85, -4.0), (72.15, -4.0), (72.15, 4.0), (71.85, 4.0)])
# ---------------- upper deck: bridge and navigator, observation lounge, passenger cabin, crew station, luggage
k.eq(2.2, -1.5, 1.2, 1.2, art="console")
k.seat(3.6, DECK - 0.22, 1.6)
k.seat(5.2, DECK - 0.22, 1.6)
k.eq(7.0, -2.8, 2.6, 2.5, art="nav_rack", col=VIO)                         # navigator station
k.eq(4.6, -4.55, 2.6, 0.32, art="overhead")
for i in range(3):                                                           # lounge seating facing the glazing
    k.seat(11.3 + i * 2.2, DECK - 0.22, 1.2)
k.eq(16.5, -1.0, 1.6, 0.78, art="cabinet")
for row in range(10):                                                        # passenger seat rows
    x = 19.4 + row * 2.4
    k.seat(x, DECK - 0.22, 1.3)
    k.seat(x + 0.85, DECK - 0.22, 1.3, op=0.5)
for row in range(7):
    x = 55.0 + row * 2.2
    k.seat(x, DECK - 0.22, 1.3)
for x0 in (19.0, 30.0, 55.0):                                               # luggage bins overhead
    k.eq(x0, -4.12, 9.0 if x0 < 50 else 12.0, 0.62, art="locker")
k.eq(43.0 - 2.4, -3.0, 2.2, 2.8, art="swb", col=AIR)                         # crew station
k.label(41.7, -3.4, "CREW", 9, AIR, 'middle')
k.cable([(19.0, -4.15), (70.0, -4.15)], HEAT)                               # ceiling wiring, in the deck above
k.pipe([(19.0, -3.42), (70.0, -3.42)], AIR, 1.2)
# ---------------- lower deck: rest pods, sanitation, galley, a small equipment room
for i in range(4):
    for j in range(3):
        k.eq(7.0 + i * 3.2, 0.8 + j * 1.9, 2.9, 1.6, art="bunk")
for i in range(3):
    k.eq(20.4 + i * 2.0, 1.2, 1.7, 3.6, art="cabinet", col=FLUID)          # sanitation modules
k.label(23.4, 5.6, "SANITATION", 9, FLUID, 'middle')
k.eq(27.0, 1.0, 5.0, 2.0, art="console")                                    # galley / supply station
k.eq(27.0, 3.4, 2.4, 2.4, art="cabinet")
k.tank(29.8, 3.2, 1.3, 3.2, FLUID)
k.label(29.5, 7.0, "GALLEY", 9, DIM, 'middle')
k.eq(33.0, 1.0, 10.0, 2.0, art="cargo", tag="BAGGAGE")
k.eq(33.0, 3.6, 3.0, 3.4, art="locker")
k.eq(36.4, 3.6, 3.0, 3.4, art="locker")
k.eq(39.8, 3.6, 3.6, 3.4, art="cabinet")
k.eq(53.0, 0.8, 4.0, 3.0, art="pump", col=FLUID)                             # small equipment room
k.eq(57.6, 0.8, 4.4, 3.2, art="battery", col=VIO)
k.label(59.8, 4.6, "AUX BATT (upper deck circuit)", 9, VIO, 'middle')
k.eq(62.6, 0.8, 3.8, 3.0, art="radiator", col=FLUID)
k.cable([(57.6, 2.0), (56.0, 2.0), (56.0, -4.15)], VIO)
# ---------------- central service core: a shaft through both decks (stairs + lift), main power, HVAC, backup gen
k.room([(44.3, -8.3), (51.7, -8.3), (51.7, 7.7), (44.3, 7.7)])
k.plate([(46.2, -8.3), (46.5, -8.3), (46.5, 7.7), (46.2, 7.7)], fill='#2a3140')
k.plate([(49.5, -8.3), (49.8, -8.3), (49.8, 7.7), (49.5, 7.7)], fill='#2a3140')
k.rect(46.6, -2.2, 2.8, 2.0, fill=EQF, stroke=EQ, sw=1.2)                    # lift car
k.line(48.0, -8.2, 48.0, -2.2, DIM, 1.0)
for i in range(8):                                                           # stairs zigzag
    y = -7.8 + i * 1.9
    k.line(44.5 if i % 2 == 0 else 46.1, y, 46.1 if i % 2 == 0 else 44.5, y + 1.9, EQ, 1.2)
k.eq(49.9, -7.9, 1.7, 3.6, art="swb", col=HEAT)                              # main power distribution
k.label(50.75, -3.9, "MAIN DIST", 8, HEAT, 'middle')
k.eq(49.9, -3.0, 1.7, 2.6, art="env", col=AIR)                               # HVAC
k.eq(49.9, 1.0, 1.7, 3.2, art="gen", col=HEAT)                               # backup generator
k.eq(49.9, 4.6, 1.7, 2.8, art="battery", col=VIO)
k.label(48.0, 8.6, "CORE SHAFT", 10, AIR, 'middle')
# ---------------- aft: a slender service section with the long maintenance tunnel, coolers and engines
k.plate([(72.4, -3.6), (97.0, -3.6), (97.0, 3.6), (72.4, 3.6)])
k.room([(72.8, -3.2), (96.6, -3.2), (96.6, 3.2), (72.8, 3.2)])
k.plate([(72.8, -1.0), (96.6, -1.0), (96.6, -0.75), (72.8, -0.75)], fill='#2a3140')
k.label(84.7, -1.4, "MAINTENANCE TUNNEL (60 m crawl, pressurised)", 9, AIR, 'middle')
for x in range(74, 96, 4):
    k.eq(x, 0.2, 2.6, 2.4, art="pump" if x % 8 == 2 else "swb", col=FLUID if x % 8 == 2 else HEAT)
for sg in (-1, 1):
    k.plate([(78.0, sg * 3.6), (94.0, sg * 3.6), (93.0, sg * 8.2), (79.5, sg * 8.2)], fill='#262b34')
    for i in range(1, 12):
        t = i / 12
        k.line(78.0 + 16.0 * t, sg * 3.6, 79.5 + 13.5 * t, sg * 8.2, FLUID, 0.8, 0.35)
k.plate([(97.0, -4.4), (98.0, -4.4), (98.0, 4.4), (97.0, 4.4)], fill='#323844')
for yc in (-2.8, 0.0, 2.8):
    k.eq(98.0, yc - 1.1, 2.2, 2.2, art="eng_front")
    k.peq([(100.2, yc - 0.9), (107.6, yc - 1.4), (107.6, yc + 1.4), (100.2, yc + 0.9)])
for sg in (-1, 1):
    k.eq(96.0, sg * 4.6 - 0.35, 1.2, 0.7, art="rcs_quad")
for x in (30.0, 60.0, 85.0):
    a, b = k.P(x, 8.2 if x < 70 else 3.6)
    k.o.append(f'<polygon points="{a-12:.0f},{b+52:.0f} {a+12:.0f},{b+52:.0f} {a+6:.0f},{b+3:.0f} {a-6:.0f},{b+3:.0f}" fill="#222731" stroke="{FAINT}" stroke-dasharray="4 3"/>')

# ---------------- v2 fill: a third level over the passenger cabins (suites forward, crew aft), escape pods, propellant
for x0, x1 in ((18.65, 43.85), (52.15, 71.85)):
    k.plate([(x0, -4.45), (x1, -4.45), (x1, -4.2), (x0, -4.2)])
for i in range(6):                                                           # suites: bed, wardrobe, partition with a door
    x = 19.0 + i * 4.1
    k.eq(x, -5.45, 2.4, 1.0, art="bunk")
    k.eq(x + 2.5, -6.5, 1.0, 2.05, art="cabinet")
    k.plate([(x + 3.75, -8.3), (x + 3.9, -8.3), (x + 3.9, -4.45), (x + 3.75, -4.45)], fill='#2a3140')
    k.door(x + 3.76, -6.3, 0.13, 1.8)
k.label(31.0, -7.6, "SUITES ×6", 9, AIR, 'middle')
for i in range(3):                                                           # crew quarters: two-high berths
    for j in range(2):
        k.eq(52.6 + i * 3.0, -7.0 + j * 1.25, 2.7, 1.1, art="bunk")
k.eq(61.8, -5.9, 2.8, 1.4, art="console")                                    # crew mess
k.eq(64.8, -6.4, 1.6, 1.95, art="cabinet")
k.eq(66.6, -6.7, 2.6, 2.25, art="env", col=AIR)                              # upper-level air handler
k.eq(69.4, -6.4, 2.0, 1.95, art="locker")
k.label(57.0, -7.7, "CREW", 9, AIR, 'middle')
for x in (20.0, 34.0, 55.0, 66.0):                                           # drop-down oxygen mask lines over the seats
    k.pline([(x, -3.35), (x + 8.0 if x < 50 else x + 5.0, -3.35)], AIR, 0.8, 0.6, dash='1 4')
for cx in (16.3, 36.3, 54.8, 65.3):                                          # escape pods under the hull, on launch clamps
    k.rect(cx - 1.8, 8.55, 3.6, 1.55, fill=EQF, stroke=AIR, sw=1.3, rx=0.7)
    k.rect(cx - 0.5, 8.8, 1.0, 0.5, fill='#1b3550', stroke=AIR, sw=0.9)
    k.plate([(cx - 1.2, 8.15), (cx - 0.8, 8.15), (cx - 0.8, 8.55), (cx - 1.2, 8.55)], fill='#4a505c')
    k.plate([(cx + 0.8, 8.15), (cx + 1.2, 8.15), (cx + 1.2, 8.55), (cx + 0.8, 8.55)], fill='#4a505c')
    k.lock(cx, 8.35)
for sg in (-1, 1):                                                           # propellant tanks on the service section
    k.tank(72.6, sg * 4.4 - 0.8, 5.2, 1.6, HAZ, "PROP")

calls = []
def c(n, x, y, lx, row, kind, text):
    calls.append((n, x, y, lx, 150 if row == 0 else 890, kind, text))
c(1, 2.8, -0.9, 80, 1, "sys", "驾驶舱：主驾 + 副驾")
c(2, 8.3, -1.5, 150, 1, "energy", "领航站")
c(3, 6.0, -5.0, 80, 0, "room", "前部观景窗（外侧可能已破损）")
c(4, 13.5, -1.0, 150, 0, "sys", "观景大厅")
c(5, 30.0, -1.0, 220, 0, "sys", "上层客舱：乘客座舱（10 + 7 排）")
c(6, 41.7, -2.0, 290, 0, "room", "乘务站")
c(7, 34.0, -3.8, 360, 0, "sys", "行李储物区（头顶）")
c(8, 40.0, -4.15, 430, 0, "energy", "天花板内走线（电缆 + 风管，在上一层地板里）")
c(9, 12.0, 3.5, 220, 1, "sys", "下层生活区：休息舱（12 个）")
c(10, 23.4, 3.0, 290, 1, "fluid", "卫生模块")
c(11, 29.5, 3.5, 360, 1, "sys", "厨房 / 供给站")
c(12, 38.0, 2.0, 430, 1, "sys", "行李舱 + 储物")
c(13, 47.0, -5.0, 500, 0, "room", "中央服务核心：电梯井 / 梯道（贯穿两层：可能成为气压联通点）")
c(14, 50.75, -6.0, 570, 0, "haz", "主配电")
c(15, 50.75, -1.7, 640, 0, "room", "空调循环")
c(16, 50.75, 2.6, 500, 1, "haz", "备用发电设备")
c(17, 55.0, 2.3, 570, 1, "fluid", "下层小型设备间")
c(18, 59.8, 2.4, 640, 1, "energy", "辅助电池：这条备用回路还给上层供电（变体）")
c(19, 84.7, -0.9, 710, 0, "room", "后部长维护通道")
c(20, 86.0, -6.0, 780, 0, "fluid", "冷却器（上下散热翼）")
c(21, 103.0, 0.0, 850, 0, "sys", "引擎 ×3")
c(22, 96.6, 4.6, 710, 1, "sys", "姿态喷口")
c(0, 27.2, -5.0, 0, 0, "room", "顶层：套间 ×6（床 + 衣柜 + 隔墙门）")
c(0, 55.0, -6.4, 0, 0, "room", "顶层：船员宿舍（双层铺 ×6）+ 船员餐厅")
c(0, 67.9, -5.6, 0, 0, "room", "顶层空气处理机")
c(0, 24.0, -3.35, 0, 0, "room", "氧气面罩线（座位上方）")
c(0, 36.3, 9.3, 0, 1, "haz", "救生舱 ×4（发射夹 + 火工品，新危险品）")
c(0, 75.2, -4.4, 0, 0, "haz", "推进剂罐（上下各一）")
zones = [(0.6, 18.5, 11.6, "① 前上层驾驶与观景区", "room"), (18.5, 44.0, 11.6, "② 上层客舱 / ③ 下层生活区", "room"),
         (44.0, 52.0, 11.6, "④ 中央服务核心", "haz"), (52.0, 72.4, 11.6, "上层客舱（后）/ 设备间", "room"), (72.4, 107.6, 11.6, "⑤ 后部推进与维护区", "struct")]
sheet('ps12.html', 1800, 1290, 'PS-12「晨光」客运飞船 · 108 m · 结构图（设计稿 v2）',
      ['三层主船体（顶层套间 / 船员、上层客舱、下层生活区），前部观景窗，中段鼓起（像民航客舱），后部细长服务与推进区。',
       '多层结构、多个气密分区互相嵌套 —— 拆起来像「解剖一栋会飞的楼」。'], k.svg(), k.P, calls, zones, legend_cols=2, auto=True, scale_at=(0.0, -10.6), scale_m=10)
print('ok')
