# ARK-01 "Voyager" colony ship, 190 m: concept structure sheet.
# Side view: a long truss spine with a pressurised tube inside, two rotating
# habitat rings seen edge-on (rim modules top and bottom, floors face outward),
# an industrial block, the shielded power core with radiator wings, and the
# engine array on a heavy thrust frame.
import sys, math
sys.path.insert(0, '.')
from kit import Kit, arc, offset
from mini import BG, HULLF, HULLS, EQF, EQ, DIM, FAINT, AIR, FLUID, HEAT, HAZ, VIO
from sheet import sheet

GREEN = '#5fbf7a'
k = Kit(150, 760, 12.0)

# ---------------- ring ghosts first (the rest of each ring, going round towards the viewer)
for cx, ry, rx in ((35.0, 31.0, 9.0), (73.0, 32.0, 13.0)):
    k.ell(cx, 0.0, rx, ry, fill='none', stroke=FAINT, sw=1.0)
    k.ell(cx, 0.0, rx * 0.7, ry - 5.0, fill='none', stroke=FAINT, sw=0.8)

# ---------------- the spine: a pressurised tube (three layers) inside a truss
k.shell([(22.0, -3.4), (160.0, -3.4), (160.0, 3.4), (22.0, 3.4)], [(22.0, -3.0), (160.0, -3.0), (160.0, 3.0), (22.0, 3.0)])
k.room([(22.0, -3.0), (160.0, -3.0), (160.0, 3.0), (22.0, 3.0)])
for y in (-1.1, 1.1):
    k.plate([(22.0, y - 0.12), (160.0, y - 0.12), (160.0, y + 0.12), (22.0, y + 0.12)], fill='#2a3140')
for x0, x1 in ((22.0, 29.0), (41.0, 60.0), (86.0, 92.0), (124.0, 128.0), (158.0, 162.0)):
    k.truss(x0, x1, -5.2, -3.4, 2.2, DIM, 1.1)
    k.truss(x0, x1, 3.4, 5.2, 2.2, DIM, 1.1)
# spine sections: each with its own local switchboard; a dead one and one running on backup
SECT = [(22.0, 29.0, "L1"), (41.0, 60.0, "L2"), (86.0, 92.0, "L3"), (124.0, 128.0, "L4"), (158.0, 162.0, "L5")]
for x0, x1, t in SECT:
    k.plate([(x0 - 0.15, -3.0), (x0 + 0.15, -3.0), (x0 + 0.15, 3.0), (x0 - 0.15, 3.0)])
    k.door(x0 - 0.12, -0.9, 0.24, 1.8)
    xm = (x0 + x1) / 2
    k.eq(xm - 0.7, -2.85, 1.4, 1.6, art="swb", col=HEAT if t != "L3" else FAINT)
    k.label(xm, 2.65, t, 9, DIM if t != "L3" else FAINT, 'middle')
k.eq(88.0, 1.25, 2.0, 1.55, art="battery", col=VIO)                     # L3 below: backup still live
k.label(89.0, -3.7, "L3 主电断 / 下层备用在跑", 9, HAZ, 'middle')
# main power trunk (top layer), maintenance lift + emergency passage (middle), main pipes (bottom)
k.cable([(22.0, -1.6), (160.0, -1.6)], HEAT, 2.0)
k.line(22.0, 0.0, 160.0, 0.0, DIM, 1.0, dash='8 4')
k.rect(52.0, -0.9, 3.0, 1.8, fill=EQF, stroke=AIR, sw=1.2)            # the maintenance car on its rail
k.label(53.5, 0.3, "LIFT", 8, AIR, 'middle')
k.pipe([(22.0, 1.65), (160.0, 1.65)], FLUID, 2.0)
k.pipe([(22.0, 2.35), (160.0, 2.35)], AIR, 1.4)
for x in range(24, 160, 6):
    k.bolt(x, -3.2)
    k.bolt(x, 3.2)
# the load path along the spine: cutting a chord changes how the whole spine carries the tail
k.pline([(24.0, -5.9), (158.0, -5.9)], HAZ, 1.0, 0.6, dash='3 6')
k.label(110.0, -6.3, "主轴承力弦杆：切断任一段，后段（反应堆 + 引擎 ≈ 1.9 万 t）的力要换路走", 9, HAZ, 'middle')

# ---------------- ① forward command section
nose = [(0.0, 0.0), (3.0, -4.2), (10.0, -8.0), (22.0, -8.6), (22.0, 8.6), (10.0, 8.0), (3.0, 4.2)]
nin = offset(nose, 0.5)
k.shell(nose, nin)
k.seams(nose, nin)
k.room(nin)
k.plate([(0.0, 0.0), (3.0, -4.2), (10.0, -8.0), (10.05, -7.5), (3.35, -3.85), (0.55, 0.0)], fill='#1b3550', stroke=AIR)
k.plate([(1.2, -0.15), (21.5, -0.15), (21.5, 0.15), (1.2, 0.15)])
k.plate([(13.0, -8.1), (13.3, -8.1), (13.3, -0.15), (13.0, -0.15)])
k.door(13.03, -2.3, 0.24, 2.0)
for i, x in enumerate((4.2, 6.0, 7.8, 9.6)):                            # main bridge: four stations
    k.seat(x, -0.15, 1.6)
    k.eq(x - 1.0, -2.3 - (0.0 if i else 0.0), 0.9, 0.8, art="console")
k.eq(4.6, -5.0, 5.0, 0.4, art="overhead")
k.eq(14.0, -3.0, 3.2, 2.7, art="console")                               # command terminal
k.seat(17.6, -0.15, 1.6, facing=-1)
k.eq(19.0, -6.6, 2.4, 2.8, art="swb", col=VIO)
for i in range(4):                                                       # navigation data centre
    k.eq(5.0 + i * 2.2, 0.6, 1.9, 4.2, art="nav_rack", col=VIO)
k.eq(14.4, 0.6, 3.4, 2.6, art="env", col=AIR)
k.eq(18.2, 0.6, 3.0, 3.2, art="cabinet", col=VIO)
k.eq(14.4, 3.6, 7.0, 2.6, art="cargo", tag="COMMS")
k.line(16.0, -8.4, 16.0, -14.0, HULLS, 2.4)                              # long-range comms mast + dish
k.ell(16.0, -14.6, 3.6, 1.0, fill=EQF, stroke=VIO, sw=1.3)
k.line(16.0, -14.6, 16.0, -17.0, VIO, 1.0)
k.cable([(16.2, -8.2), (16.2, -7.0), (19.0, -6.0)], VIO)
k.eq(5.0, 6.3, 1.2, 0.7, art="rcs_quad")
k.eq(5.0, -7.0, 1.2, 0.7, art="rcs_quad")
k.label(11.0, 9.8, "DOCK PORT", 9, AIR, 'middle')
k.rect(9.0, 8.0, 4.0, 0.9, fill='#2a3140', stroke=AIR, sw=1.2)


# ---------------- habitat rings: hub with bearing + slip ring, spokes with lifts, rim modules
def hub(x0, x1, h):
    k.shell([(x0, -h), (x1, -h), (x1, h), (x0, h)], [(x0 + 0.5, -h + 0.5), (x1 - 0.5, -h + 0.5), (x1 - 0.5, h - 0.5), (x0 + 0.5, h - 0.5)])
    k.room([(x0 + 0.5, -h + 0.5), (x1 - 0.5, -h + 0.5), (x1 - 0.5, h - 0.5), (x0 + 0.5, h - 0.5)])
    for xb in (x0 + 0.9, x1 - 1.5):                                        # bearing races
        k.rect(xb, -h + 0.5, 0.6, 2 * h - 1.0, fill='#2a3140', stroke=DIM, sw=1.0)
        for j in range(int(2 * h - 1)):
            k.circ(xb + 0.3, -h + 1.0 + j, 0.2, fill='none', stroke=DIM, sw=0.8)
    k.eq((x0 + x1) / 2 - 1.0, -h + 0.9, 2.0, 1.4, art="aux", col=HEAT)    # slip ring: power across the joint
    k.label((x0 + x1) / 2, -h + 2.9, "SLIP RING", 8, HEAT, 'middle')


def spoke(x, y0, y1, w=2.6):
    k.shell([(x, y0), (x + w, y0), (x + w, y1), (x, y1)], [(x + 0.35, y0), (x + w - 0.35, y0), (x + w - 0.35, y1), (x + 0.35, y1)])
    k.room([(x + 0.35, y0), (x + w - 0.35, y0), (x + w - 0.35, y1), (x + 0.35, y1)])
    k.line(x + w / 2, y0, x + w / 2, y1, DIM, 0.9, dash='6 3')
    ym = (y0 + y1) / 2
    k.rect(x + 0.5, ym - 0.9, w - 1.0, 1.8, fill=EQF, stroke=AIR, sw=1.1)  # lift car
    k.cable([(x + 0.55, y0), (x + 0.55, y1)], HEAT, 1.0)
    k.pipe([(x + w - 0.55, y0), (x + w - 0.55, y1)], AIR, 1.0)


def rim(x0, x1, yi, yo):
    """a rim module: yi inner face (towards the hub), yo outer face (the floor under spin)"""
    sg = 1 if yo > yi else -1
    o = [(x0 + 1.2, yi), (x1 - 1.2, yi), (x1, yi + sg * 1.2), (x1, yo - sg * 1.2), (x1 - 1.2, yo), (x0 + 1.2, yo), (x0, yo - sg * 1.2), (x0, yi + sg * 1.2)]
    i = offset(o, 0.45 if sg > 0 else -0.45)
    k.shell(o, i)
    k.seams(o, i, 2)
    k.room(i)
    ym = (yi + yo) / 2
    k.plate([(x0 + 0.4, ym - 0.13), (x1 - 0.4, ym - 0.13), (x1 - 0.4, ym + 0.13), (x0 + 0.4, ym + 0.13)])
    k.plate([(x0 + 0.4, yo - sg * 0.55 - 0.1), (x1 - 0.4, yo - sg * 0.55 - 0.1), (x1 - 0.4, yo - sg * 0.55 + 0.1), (x0 + 0.4, yo - sg * 0.55 + 0.1)], fill='#2a3140')
    for x in range(int(x0) + 2, int(x1) - 1, 3):
        k.bolt(x, ym)
    return ym


# ring A
hub(29.0, 41.0, 7.0)
spoke(33.7, -26.0, -7.0)
spoke(33.7, 7.0, 26.0)
ymA = rim(26.0, 44.0, -26.0, -36.0)
ymA2 = rim(26.0, 44.0, 26.0, 36.0)
k.label(35.0, -37.4, "旋转重力：地板朝外 ↑", 9, DIM, 'middle')
k.label(35.0, 38.4, "旋转重力：地板朝外 ↓", 9, DIM, 'middle')
for i in range(5):                                                       # A top, outer deck: living modules
    k.eq(27.0 + i * 3.3, -35.3, 3.0, 2.0, art="bunk")
    k.eq(27.0 + i * 3.3, -33.1, 3.0, 1.6, art="locker")
k.eq(27.0, -30.6, 4.4, 1.7, art="console")                                # A top, inner deck: public living area
k.eq(32.0, -30.6, 4.4, 1.7, art="console")
k.eq(37.6, -30.6, 2.6, 3.8, art="cabinet")
k.eq(40.6, -30.6, 2.4, 3.8, art="locker")
k.eq(27.0, -28.6, 9.6, 1.6, art="overhead")
# the breach: ring A is open to vacuum on this variant
k.poly([(29.6, -36.05), (30.4, -35.4), (31.1, -36.05), (30.7, -35.6), (31.4, -35.0), (30.2, -35.2)], fill=BG, stroke=HAZ, w=1.4)
k.label(30.6, -37.4 + 2.8, "", 9, HAZ, 'middle')
for i in range(3):                                                       # A bottom, outer deck: study + medical
    k.eq(27.0 + i * 3.2, 33.2, 2.9, 2.0, art="bunk")
k.eq(36.8, 32.0, 3.0, 3.2, art="console")
k.eq(40.2, 32.0, 2.6, 3.2, art="cabinet", col=FLUID)
k.eq(27.0, 28.4, 3.4, 2.6, art="env", col=AIR)                            # A bottom, inner deck: own air loop
k.eq(30.8, 28.4, 2.6, 2.6, art="pump", col=AIR)
k.eq(33.8, 28.4, 2.2, 2.6, art="o2cab", col=AIR, hazard="gas_tank")
k.tank(36.4, 28.0, 2.2, 3.0, AIR, "O₂")
k.eq(39.2, 28.4, 3.6, 2.6, art="radiator", col=FLUID)
k.pipe([(28.7, 28.4), (28.7, 27.0), (35.0, 27.0), (35.0, 26.0)], AIR, 1.3)

# ring B: bigger, two spokes each side, agriculture
hub(66.0, 80.0, 8.0)
for xs in (67.4, 76.0):
    spoke(xs, -26.0, -8.0)
    spoke(xs, 8.0, 26.0)
rim(60.0, 86.0, -26.0, -38.0)
rim(60.0, 86.0, 26.0, 38.0)
k.label(73.0, -39.4, "旋转重力：地板朝外 ↑", 9, DIM, 'middle')
k.plate([(61.4, -38.05), (84.6, -38.05), (84.6, -37.55), (61.4, -37.55)], fill='#1b3550', stroke=AIR)   # glazed roof
for i in range(7):                                                       # greenhouse beds, plants hanging "down" to the floor
    x = 61.4 + i * 3.25
    k.rect(x, -37.2, 2.9, 1.0, fill='#1d2a1f', stroke=GREEN, sw=1.1)
    for j in range(4):
        k.line(x + 0.4 + j * 0.7, -36.2, x + 0.4 + j * 0.7, -34.4 + (j % 2) * 0.5, GREEN, 1.0)
k.pipe([(61.0, -33.9), (85.0, -33.9)], FLUID, 1.2)                          # irrigation
for i in range(4):                                                       # food production modules
    k.eq(61.4 + i * 5.8, -31.2, 5.2, 3.6, art="module", col=GREEN)
k.eq(61.4, 33.5, 5.0, 3.6, art="pump", col=FLUID)                          # water cycle: tanks, pumps, filters
k.tank(67.0, 30.6, 3.0, 6.6, FLUID, "H₂O")
k.tank(70.6, 30.6, 3.0, 6.6, FLUID, "H₂O")
k.eq(74.2, 33.5, 3.4, 3.6, art="cabinet", col=FLUID)
k.eq(78.2, 33.5, 6.4, 3.6, art="radiator", col=FLUID)
k.pipe([(64.0, 33.5), (64.0, 32.2), (84.0, 32.2)], FLUID, 1.4)
k.label(73.0, 39.5, "B 环水循环：停机后管里仍有残留水", 9, FLUID, 'middle')
k.eq(61.4, 27.0, 4.4, 2.8, art="env", col=AIR)                             # aux life support + air loop
k.eq(66.4, 27.0, 2.4, 2.8, art="o2cab", col=AIR, hazard="gas_tank")
k.eq(79.4, 27.0, 5.2, 2.8, art="gen", col=HEAT)
k.eq(74.0, 27.0, 4.6, 2.8, art="battery", col=VIO)

# ---------------- ⑤ industry and storage block
ind = [(92.0, -12.0), (124.0, -12.0), (124.0, 12.0), (92.0, 12.0)]
iin = offset(ind, -0.5)
k.shell(ind, iin)
k.seams(ind, iin)
k.room([(92.5, -11.5), (123.5, -11.5), (123.5, -3.4), (92.5, -3.4)])
k.room([(92.5, 3.4), (123.5, 3.4), (123.5, 11.5), (92.5, 11.5)])
k.plate([(92.5, -7.6), (110.0, -7.6), (110.0, -7.35), (92.5, -7.35)])
k.plate([(109.9, -11.5), (110.2, -11.5), (110.2, -3.4), (109.9, -3.4)])
k.door(109.93, -5.6, 0.24, 2.0)
k.eq(93.2, -11.0, 4.0, 3.0, art="console")                                 # engineering bay
k.eq(97.6, -11.0, 3.0, 3.2, art="swb", col=HEAT)
k.eq(101.0, -11.0, 3.6, 3.2, art="panel")
k.eq(105.2, -11.0, 4.0, 3.2, art="cabinet")
for i in range(4):                                                       # repair stations: arms over benches
    x = 93.4 + i * 4.2
    k.eq(x, -5.6, 3.6, 2.0, art="panel")
    k.eq(x + 0.6, -7.2, 2.4, 1.4, art="arm")
for i in range(4):                                                       # spare parts store: racks of crates
    for j in range(3):
        k.eq(110.8 + i * 3.15, -11.0 + j * 2.5, 2.9, 2.2, art="cargo")
k.plate([(104.9, 3.4), (105.2, 3.4), (105.2, 11.5), (104.9, 11.5)])
k.door(104.93, 8.6, 0.24, 2.4)
for i in range(3):
    k.eq(93.2 + i * 3.8, 4.0, 3.4, 3.0, art="locker")
k.eq(93.2, 7.6, 11.0, 3.4, art="cargo", tag="SPARES")
k.peq([(108.0, 10.6), (108.6, 8.4), (113.5, 8.0), (116.4, 8.4), (117.0, 10.6)])  # small work vehicle in its garage
k.circ(110.0, 10.8, 0.6, fill=EQF, stroke=EQ)
k.circ(115.0, 10.8, 0.6, fill=EQF, stroke=EQ)
k.eq(118.8, 4.2, 4.0, 3.0, art="arm")
k.rect(107.0, 11.5, 15.0, 0.5, fill='#2a3140', stroke=AIR, sw=1.3)            # garage door, outward
k.label(114.5, 13.4, "GARAGE DOOR", 9, AIR, 'middle')

# ---------------- ⑥ power core: shield, main + secondary reactor, radiator wings, distribution centre
for sg in (-1, 1):                                                       # radiator wings
    k.plate([(131.0, sg * 11.0), (155.0, sg * 11.0), (153.0, sg * 31.0), (133.0, sg * 31.0)], fill='#262b34')
    for i in range(1, 16):
        t = i / 16
        k.line(131.0 + 24.0 * t, sg * 11.0, 133.0 + 20.0 * t, sg * 31.0, FLUID, 0.9, 0.4)
    k.pipe([(132.0, sg * 11.5), (132.6, sg * 30.0), (153.4, sg * 30.0), (154.0, sg * 11.5)], FLUID, 1.6)
    k.eq(141.0, sg * 11.0 - (1.4 if sg < 0 else 0.0), 6.0, 1.4, art="aux", col=FLUID)
core = [(128.0, -11.0), (158.0, -11.0), (158.0, 11.0), (128.0, 11.0)]
cin = offset(core, -1.4)
k.shell(core, cin, fill='#4a505c')
for x in range(130, 158, 3):
    k.line(x, -11.0, x, -9.6, '#22262d', 1.4)
    k.line(x, 11.0, x, 9.6, '#22262d', 1.4)
k.room(cin)
k.plate([(144.5, -9.6), (145.0, -9.6), (145.0, 9.6), (144.5, 9.6)], fill='#4a505c')
k.door(144.6, -1.0, 0.3, 2.0)
k.circ(137.0, 0.0, 7.0, fill='#2a2f39', stroke=DIM, sw=1.2)                 # main reactor in its own shield
k.circ(137.0, 0.0, 5.2, fill=EQF, stroke=HEAT, sw=1.6)
k.circ(137.0, 0.0, 3.6, fill='none', stroke=HEAT, sw=1.0)
for a in range(0, 360, 30):
    k.line(137.0 + 3.6 * math.cos(math.radians(a)), 3.6 * math.sin(math.radians(a)), 137.0 + 5.2 * math.cos(math.radians(a)), 5.2 * math.sin(math.radians(a)), HEAT, 0.8, 0.6)
k.label(137.0, 0.4, "MAIN REACTOR", 11, HEAT, 'middle')
k.label(137.0, 1.8, "停堆", 10, DIM, 'middle')
k.circ(150.5, -5.0, 3.4, fill='#2a2f39', stroke=DIM, sw=1.1)               # secondary reactor
k.circ(150.5, -5.0, 2.4, fill=EQF, stroke=HEAT, sw=1.4)
k.label(150.5, -4.6, "SEC", 10, HEAT, 'middle')
for i in range(3):                                                       # power distribution centre
    k.eq(146.0 + i * 3.6, 1.6, 3.2, 3.8, art="swb", col=HEAT)
k.eq(146.0, 5.8, 10.6, 2.6, art="battery", col=VIO)
k.label(151.3, 9.2, "AUX GRID（主堆停了它还活着）", 9, VIO, 'middle')
k.pipe([(130.4, -9.4), (130.4, 9.4)], FLUID, 1.6)
k.cable([(146.0, 3.5), (145.2, 3.5), (145.2, -1.6), (128.0, -1.6)], HEAT, 2.0)
k.cable([(150.5, -2.6), (150.5, 1.6)], HEAT)

# ---------------- ⑦ tail: propellant trunk, thrust frame, engine array, RCS clusters
for sg in (-1, 1):
    k.plate([(160.0, sg * 3.4), (161.0, sg * 3.4), (170.0, sg * 6.2), (170.0, sg * 7.4)], fill='#4a505c')   # giant fixing beams
    k.plate([(158.0, sg * 11.0), (160.0, sg * 11.0), (171.0, sg * 18.2), (169.4, sg * 19.4)], fill='#4a505c')
    k.bolts(158.6, sg * 11.4, 169.8, sg * 18.6, 6)
    k.bolts(160.6, sg * 3.7, 169.6, sg * 6.6, 4)
    k.sphere(164.6, sg * 10.6, 3.4, HAZ, "PROP", jacket=0.4)
    k.pipe([(164.6, sg * 7.2), (164.6, sg * 2.6), (170.0, sg * 2.6)], HAZ, 2.2)
    k.eq(170.6, sg * 21.0 - 0.6, 2.2, 1.2, art="rcs_quad")
    k.eq(156.0, sg * 12.4 - 0.6, 2.2, 1.2, art="rcs_quad")
k.pipe([(170.0, -2.6), (170.0, 2.6)], HAZ, 2.2)
k.plate([(170.0, -19.0), (172.4, -19.0), (172.4, 19.0), (170.0, 19.0)], fill='#4a505c')   # thrust plate
for y in range(-18, 19, 3):
    k.bolt(171.2, y)
for yc in (-14.0, -7.0, 0.0, 7.0, 14.0):
    k.eq(172.4, yc - 2.3, 3.2, 4.6, art="eng_front")
    k.peq([(175.6, yc - 1.8), (189.0, yc - 3.3), (189.0, yc + 3.3), (175.6, yc + 1.8)])
    k.line(175.6, yc, 189.0, yc, FAINT, 0.8)
    k.pipe([(172.4, yc), (170.0, yc)], HAZ, 1.2)

calls = []


def c(n, x, y, row, kind, text):
    calls.append((n, x, y, 0, 210 if row == 0 else 1330, kind, text))


c(1, 6.0, -1.0, 0, "room", "主舰桥：4 个座席 + 头顶面板")
c(2, 15.6, -1.6, 0, "sys", "指挥终端")
c(3, 16.0, -14.6, 0, "energy", "长程通讯天线（桅杆 + 碟）")
c(4, 8.0, 2.5, 1, "energy", "航行数据中心（机架 ×4）")
c(5, 11.0, 8.4, 1, "room", "前对接口")
c(6, 33.0, -29.8, 0, "room", "A 环公共生活区")
c(7, 30.0, -34.3, 0, "sys", "A 环居住模块（铺位 + 储物）")
c(8, 30.4, -35.4, 0, "haz", "A 环失压破口（变体：A 环失压，B 环仍正常）")
c(9, 35.0, -16.0, 0, "room", "轮辐电梯井（每根轮辐一部，带电缆和风管）")
c(10, 35.0, -6.2, 0, "haz", "环毂旋转轴承 + 滑环（电力跨过旋转面）")
c(11, 31.0, 34.2, 1, "sys", "A 环学习 / 医疗空间")
c(12, 30.0, 29.7, 1, "room", "A 环独立空气循环（O₂ 柜 + 储罐）")
c(13, 53.5, 0.0, 1, "room", "主轴：维护电梯与应急通道（中层）")
c(14, 48.0, -1.6, 0, "haz", "主配电主干（上层）")
c(15, 48.0, 1.65, 1, "fluid", "主管路（下层：水 + 空气）")
c(16, 74.0, -36.0, 0, "fluid", "B 环温室（种植床 + 灌溉，玻璃顶）")
c(17, 70.0, -29.4, 0, "sys", "B 环食物生产模块")
c(18, 68.5, 33.9, 1, "fluid", "B 环水循环（水箱 + 泵 + 过滤，残留水）")
c(19, 63.6, 28.4, 1, "room", "B 环辅助生命维持 + 独立空气循环")
c(20, 76.3, 28.4, 1, "energy", "B 环备用电池 + 发电机")
c(21, 50.0, -5.9, 0, "haz", "主轴承力弦杆（切割会改变整根主轴受力）")
c(22, 89.0, -2.0, 0, "haz", "主轴分段配电 L1–L5（L3 断电，下层备用仍在运行）")
c(23, 99.0, -9.4, 0, "sys", "工程舱")
c(24, 95.2, -6.5, 0, "sys", "维修工位 ×4（机械臂 + 工作台）")
c(25, 115.0, -7.0, 0, "sys", "备件仓（货架）")
c(26, 112.4, 9.2, 1, "room", "小型作业车库 + 外开库门")
c(27, 137.0, -3.0, 0, "haz", "主反应堆（已停堆，屏蔽层内）")
c(28, 150.5, -5.0, 0, "haz", "次级反应堆")
c(29, 143.0, -22.0, 0, "fluid", "大型散热翼（上下各一）")
c(30, 150.0, 3.4, 1, "haz", "电力分配中心")
c(31, 150.0, 7.0, 1, "energy", "辅助电网（主堆停了它还活着）")
c(32, 164.6, 10.6, 1, "haz", "推进剂球罐 + 推进剂主干")
c(33, 166.0, 16.0, 1, "struct", "巨型结构固定梁（推力板 ↔ 主轴）")
c(34, 182.0, 0.0, 0, "sys", "主引擎阵列 ×5")
c(35, 171.7, -21.0, 0, "haz", "姿控群（引擎架 + 动力核心）")
c(36, 171.2, 12.0, 1, "struct", "推力板（整排螺栓）")
zones = [(0.0, 22.0, 41.5, "① 前指挥段", "room"), (22.0, 48.0, 41.5, "② 居住环 A", "room"), (48.0, 58.0, 41.5, "③ 中央主轴", "energy"),
         (58.0, 90.0, 41.5, "④ 居住环 B / 农业", "fluid"), (90.0, 126.0, 41.5, "⑤ 工业与仓储", "sys"), (126.0, 159.0, 41.5, "⑥ 动力核心", "haz"),
         (159.0, 190.0, 41.5, "⑦ 尾推进段", "struct")]
sheet('ark01.html', 2600, 1660, 'ARK-01「远航者」殖民飞船 · 190 m · 结构图（设计稿）',
      ['中央长主轴 + 两个旋转居住环（侧视看到环的上下两段）+ 中段工业块 + 尾部巨型动力总成 —— 一座会飞的殖民地。',
       '全游戏最综合的工程：多系统并行、多日拆解。重点不是「多」，而是哪些系统还活着、主轴的力从哪里走。'],
      k.svg(), k.P, calls, zones, legend_cols=3, auto=True, scale_at=(0.0, -24.0), scale_m=10)
print('ok')
