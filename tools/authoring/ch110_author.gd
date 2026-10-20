class_name Ch110Author
# Authoring script for CH-110 "Bookend", a 110 m twin-hull heavy lifter (exotic batch
# 08/10, design/ships/CH-110_书夹_设计稿.md and CH-110_线稿.png, as drawn). Not part
# of the game: tools/ship_export.gd runs it and writes ships/ch110.json.
# Metres, x bow (0) to the nozzles (~113), y down; the cargo's middle at y 0.
#
# Two 98 m hulls, one over and one under a 40 m prefab habitat, 2 m clear of it each
# side; four cross beams in tension and the yokes at both ends hold the hulls apart.
# The upper hull: the cockpit, the crew quarters, the power room. The lower hull: the
# propellant, the machinery (the clamps' hydraulics), the generator and the engines.
# The cargo: two decks of cabins, its own battery, 60 kPa inside. Eight hydraulic
# clamps (four over it, four under) and four tie rods hold it.
# What it asks of you (scripts/sandwich.gd): vent the cargo before any clamp lets go
# (or it springs); let the clamps go crosswise, a pair at a time (one side loosed
# ahead of the other twists the cargo and breaks beam 2, already cracked: its load
# cell reads high); and take beam 2 out only once the clamps beside it are off, or it
# tears the upper hull.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const UOUT := [Vector2(7.6, -20.0), Vector2(102.4, -20.0), Vector2(104.0, -18.4), Vector2(104.0, -13.6), Vector2(102.4, -12.0), Vector2(7.6, -12.0),
	Vector2(6.0, -13.6), Vector2(6.0, -18.4)]
const COUT := [Vector2(37.6, -10.0), Vector2(74.4, -10.0), Vector2(76.0, -8.4), Vector2(76.0, 8.4), Vector2(74.4, 10.0), Vector2(37.6, 10.0),
	Vector2(36.0, 8.4), Vector2(36.0, -8.4)]
const UF := -12.45               # the upper hull's floor, inside
const UC := -19.55               # its ceiling
const LC := 12.45                # the lower hull's ceiling, inside
const LF := 19.55                # its floor
const CLAMPS := [40.0, 50.0, 60.0, 70.0]
const BEAMS := [13.0, 33.0, 79.0, 97.0]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "CH110")
	w = world
	by_tag = K.by_tag
	_hulls()
	_cargo()
	_yokes()
	_beams()
	_clamps()
	_upper()
	_lower()
	_inside_cargo()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "CH110")
	w = world
	_rooms()


static func _dy(pts: Array, dy: float) -> Array:
	var out: Array = []
	for q in pts:
		out.append(q + Vector2(0.0, dy))
	return out


static func _bar(a: Vector2, b: Vector2, t: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * t * 0.5
	return K.mp([a + n, b + n, b - n, a - n])


# equipment bolted at y "at" (its top or bottom edge, a hand's breadth off the wall),
# to "base" or to whatever hull is found at y "probe"
static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, opts: Dictionary, base, at: float, probe := 0.0):
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		var b = base if base != null else K.at(x, probe, ["hull"])
		K.bolt(p, b, x, at)
	return p


static func floor_u(tag: String, art: String, x0: float, x1: float, h: float, opts: Dictionary):
	return E(tag, art, x0, UF - 0.05 - h, x1, UF - 0.05, opts, null, UF, UF + 0.25)


static func ceil_u(tag: String, art: String, x0: float, x1: float, h: float, opts: Dictionary):
	return E(tag, art, x0, UC + 0.05, x1, UC + 0.05 + h, opts, null, UC, UC - 0.25)


static func floor_l(tag: String, art: String, x0: float, x1: float, h: float, opts: Dictionary):
	return E(tag, art, x0, LF - 0.05 - h, x1, LF - 0.05, opts, null, LF, LF + 0.25)


static func ceil_l(tag: String, art: String, x0: float, x1: float, h: float, opts: Dictionary):
	return E(tag, art, x0, LC + 0.05, x1, LC + 0.05 + h, opts, null, LC, LC - 0.25)


# equipment bolted by its side to a wall at x
static func _wall(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, wall, wx: float, opts: Dictionary):
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	K.bolt(p, wall, wx, y0 + 0.5)
	K.bolt(p, wall, wx, y1 - 0.5)
	return p


# ---------------------------------------------------------------- the hulls

static func _hulls() -> void:
	K.ring(UOUT, T, {0: [0.0781, 0.0992, 0.2, 0.3629, 0.384, 0.5, 0.65, 0.8059, 0.827], 4: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-U1", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
		"0:4": {"kind": "hatch", "door": true, "tag": "HT-U2", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
		"0:8": {"kind": "hatch", "door": true, "tag": "HT-U3", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HU")
	K.ring(_dy(UOUT, 32.0), T, {0: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9], 4: [0.173, 0.1941, 0.4, 0.616, 0.6371, 0.9008, 0.9219]}, {
		"4:1": {"kind": "hatch", "door": true, "tag": "HT-L3", "open_dir": Vector2(-2.2, 0) * Geom.M, "cut_speed": 200.0},
		"4:4": {"kind": "hatch", "door": true, "tag": "HT-L2", "open_dir": Vector2(-2.2, 0) * Geom.M, "cut_speed": 200.0},
		"4:6": {"kind": "hatch", "door": true, "tag": "HT-L1", "open_dir": Vector2(-2.2, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HL")
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	for e in [["UB1", 22.0, UC, UF, -1.0], ["UB2", 64.0, UC, UF, -1.0], ["LB1", 40.0, LC, LF, 1.0], ["LB2", 80.0, LC, LF, 1.0]]:
		var x: float = e[1]
		var y0: float = e[2]
		var y1: float = e[3]
		var bh = K.plate(e[0], K.R(x, y0 - 0.05, x + 0.4, y1 + 0.05), S, "bulkhead")
		K.bolt(bh, K.at(x + 0.2, y0 - 0.25, ["hull"]), x + 0.2, y0, "weld")
		K.bolt(bh, K.at(x + 0.2, y1 + 0.25, ["hull"]), x + 0.2, y1, "weld")
	K.clamp(1, 30.0, 20.0, 19.8)
	K.clamp(2, 60.0, 20.0, 19.8)
	K.clamp(3, 90.0, 20.0, 19.8)
	K.clamp(4, 50.0, -20.0, -19.8)


# ---------------------------------------------------------------- the cargo: a prefab habitat, two decks

static func _cargo() -> void:
	K.ring(COUT, T, {0: [0.4728, 0.5272], 4: [0.25, 0.5, 0.75]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.4, "barrier": true, "cut_speed": 210.0, "name_key": "p_hab_shell"}, "HC")
	var D := {"density": 1.1, "barrier": true, "cut_speed": 210.0}
	var d1 = K.plate("DC-1", K.R(36.45, -0.15, 62.0, 0.15), D, "deck")
	var dh = K.plate("DK-C", K.R(62.0, -0.15, 63.8, 0.15), {"density": 1.0, "door": true, "open_dir": Vector2(2.0, 0) * Geom.M, "cut_speed": 200.0}, "hatch")
	var d2 = K.plate("DC-2", K.R(63.8, -0.15, 75.55, 0.15), D, "deck")
	K.bolt(d1, K.at(36.2, 0.6, ["hull"]), 36.45, 0.0, "weld")
	K.bolt(d2, K.at(75.8, 0.6, ["hull"]), 75.55, 0.0, "weld")
	K.bolt(dh, d1, 62.0, 0.0, "weld")
	K.bolt(dh, d2, 63.8, 0.0, "weld")
	K.clamp(5, 36.2, 2.0, 2.0)


# ---------------------------------------------------------------- the yokes at both ends

static func _yokes() -> void:
	var Y := {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_yoke"}
	for e in [["YF", 0.0, 4.0, 6.0], ["YS", 106.0, 110.0, 104.0]]:
		var x0: float = e[1]
		var x1: float = e[2]
		var prev = null
		for k in 4:
			var y0 := -20.0 + k * 10.0
			var pc = K.plate("%s-%d" % [e[0], k + 1], K.R(x0, y0, x1, y0 + 10.0), Y, "beam")
			if prev != null:
				K.bolt(pc, prev, (x0 + x1) * 0.5, y0, "bolt")
			prev = pc
		var hx: float = e[3]
		var ax0: float = minf(hx, x0 if x0 > hx else x1)
		var ax1: float = maxf(hx, x0 if x0 > hx else x1)
		for a in [["T", -18.0, -14.0, 1], ["B", 14.0, 18.0, 4]]:
			var arm = K.plate("%s-%s" % [e[0], a[0]], K.R(ax0, a[1], ax1, a[2]), Y, "beam")
			var ym: float = (a[1] + a[2]) * 0.5
			var yoke_x: float = x1 if x0 < hx else x0
			K.bolt(arm, by_tag["%s-%d" % [e[0], a[3]]], yoke_x, ym, "weld")
			K.bolt(arm, K.at(hx + (0.2 if hx < 50.0 else -0.2), ym, ["hull"]), hx, ym, "weld")
	var dk = K.equip("DOCK", "dock", K.rect(-1.2, -1.4, 0.0, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, by_tag["YF-2"], 0.0, -1.0)
	K.bolt(dk, by_tag["YF-3"], 0.0, 1.0)
	# the engines' nozzles on the stern yoke
	for e in [["NOZ-1", 11.0, 14.6], ["NOZ-2", 15.4, 19.0]]:
		var nz = K.equip(e[0], "nozzle", K.rect(110.0, e[1] - 0.6, 113.0, e[2] + 0.6), {"cls": "metal", "dest": "metal", "mass": 0.5, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(110.0, e[1]), Vector2(113.0, e[1] - 0.6), Vector2(113.0, e[2] + 0.6), Vector2(110.0, e[2])]))
		K.bolt(nz, by_tag["YS-4"], 110.0, e[1] + 0.8)
		K.bolt(nz, by_tag["YS-4"], 110.0, e[2] - 0.8)


# ---------------------------------------------------------------- the cross beams

static func _beams() -> void:
	var B := {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_cross_beam"}
	var n := 0
	for x in BEAMS:
		n += 1
		var parts: Array = [["%d-1" % n, -12.0, -4.0], ["%d-2" % n, -4.0, 4.0], ["%d-3" % n, 4.0, 12.0]]
		if n == 2:
			parts = [["2-1a", -12.0, -8.0], ["2-1b", -8.0, -4.0], ["2-2", -4.0, 4.0], ["2-3", 4.0, 12.0]]
		var prev = null
		for pr in parts:
			var pc = K.plate("BM" + pr[0], K.R(x, pr[1], x + 2.0, pr[2]), B, "beam")
			if prev != null:
				var cracked: bool = pr[0] == "2-1b"
				K.bolt(pc, prev, x + 0.5, pr[1], "crack" if cracked else "bolt")
				if not cracked:
					K.bolt(pc, prev, x + 1.5, pr[1], "bolt")
			prev = pc
		var top = by_tag["BM%d-1" % n] if n != 2 else by_tag["BM2-1a"]
		for bx in [x + 0.5, x + 1.5]:
			K.bolt(top, K.at(bx, -12.2, ["hull"]), bx, -12.0, "weld")
			K.bolt(prev, K.at(bx, 12.2, ["hull"]), bx, 12.0, "weld")


# ---------------------------------------------------------------- the clamps and tie rods

static func _clamps() -> void:
	var k := 0
	for c in CLAMPS:
		k += 1
		var cu = K.equip("CU-%d" % k, "cap", K.rect(c - 1.0, -11.95, c + 1.0, -10.05), {"mass": 0.8, "value": 3500.0, "fragile": 0.3, "name_key": "p_hyd_clamp"})
		K.bolt(cu, K.at(c - 0.5, -12.2, ["hull"]), c - 0.5, -12.0)
		K.bolt(cu, K.at(c + 0.5, -12.2, ["hull"]), c + 0.5, -12.0)
		K.bolt(cu, K.at(c - 0.5, -9.8, ["hull"]), c - 0.5, -10.0, "lock")
		K.bolt(cu, K.at(c + 0.5, -9.8, ["hull"]), c + 0.5, -10.0, "lock")
		var cl = K.equip("CL-%d" % k, "cap", K.rect(c - 1.0, 10.05, c + 1.0, 11.95), {"mass": 0.8, "value": 3500.0, "fragile": 0.3, "name_key": "p_hyd_clamp"})
		K.bolt(cl, K.at(c - 0.5, 12.2, ["hull"]), c - 0.5, 12.0)
		K.bolt(cl, K.at(c + 0.5, 12.2, ["hull"]), c + 0.5, 12.0)
		K.bolt(cl, K.at(c - 0.5, 9.8, ["hull"]), c - 0.5, 10.0, "lock")
		K.bolt(cl, K.at(c + 0.5, 9.8, ["hull"]), c + 0.5, 10.0, "lock")
	k = 0
	for e in [[38.4, -10.05, 36.6, -11.95], [73.6, -10.05, 75.4, -11.95], [38.4, 10.05, 36.6, 11.95], [73.6, 10.05, 75.4, 11.95]]:
		k += 1
		var a := Vector2(e[0], e[1])
		var b := Vector2(e[2], e[3])
		var poly := _bar(a, b, 0.3)
		var bb := Geom.bbox(poly)
		var ti = K.equip("TIE-%d" % k, "", Rect2(bb.position / Geom.M, bb.size / Geom.M), {"mass": 0.2, "value": 2000.0, "fragile": 0.2, "name_key": "p_tension_rod"}, poly)
		var sg: float = signf(e[1])
		K.bolt(ti, K.at(a.x, a.y - sg * 0.25, ["hull"]), a.x, a.y - sg * 0.05)
		K.bolt(ti, K.at(b.x, b.y + sg * 0.25, ["hull"]), b.x, b.y + sg * 0.05)


# ---------------------------------------------------------------- the upper hull: cockpit, crew, power

static func _upper() -> void:
	# U1 the cockpit
	floor_u("HELM-U", "console", 8.6, 12.0, 1.55, {"mass": 0.4, "value": 9000.0, "fragile": 0.5, "room": "U1", "name_key": "p_helm"})
	for i in 2:
		var sx := 12.4 + i * 1.2
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, UF - 1.55, 0.8, 1.5), {"room": "U1", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, UF + 0.25, ["hull"]), sx + 0.2, UF)
		K.bolt(st, K.at(sx + 0.6, UF + 0.25, ["hull"]), sx + 0.6, UF, "lock")
	floor_u("CAM-U", "screen", 14.8, 17.6, 2.45, {"mass": 0.2, "value": 6000.0, "fragile": 0.5, "room": "U1", "name_key": "p_cargo_view"})
	floor_u("AV-U", "nav_rack", 17.9, 19.4, 4.1, {"mass": 0.35, "value": 9000.0, "fragile": 0.5, "room": "U1", "name_key": "p_avionics"})
	floor_u("LOG-U", "blackbox", 19.6, 21.6, 2.1, {"mass": 0.2, "value": 9000.0, "fragile": 0.4, "room": "U1", "mandatory": true, "name_key": "p_voyage_recorder"})
	ceil_u("NAV-U", "nav_rack", 8.4, 11.0, 2.7, {"mass": 0.3, "value": 7000.0, "fragile": 0.5, "room": "U1", "name_key": "p_nav"})
	ceil_u("COMMS-U", "screen", 11.6, 14.4, 1.3, {"mass": 0.15, "value": 4000.0, "fragile": 0.5, "room": "U1", "name_key": "p_comms"})
	K.lamp("LAMP-U1", 18.0, UC, "U1", K.at(18.0, UC - 0.25, ["hull"]))
	# U2 the crew quarters
	var k := 0
	for x0 in [23.0, 28.0, 33.0]:
		k += 1
		var lo = floor_u("BUNK-%dA" % k, "bunk", x0, x0 + 4.4, 1.5, {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "U2", "name_key": "p_bunk"})
		var hi = K.equip("BUNK-%dB" % k, "bunk", K.rect(x0, UF - 3.3, x0 + 4.4, UF - 1.65), {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "U2", "name_key": "p_bunk"})
		K.bolt(hi, lo, x0 + 0.5, UF - 1.6)
		K.bolt(hi, lo, x0 + 3.9, UF - 1.6)
	floor_u("MESS-U", "cabinet", 38.4, 41.6, 1.3, {"mass": 0.3, "value": 1800.0, "fragile": 0.3, "room": "U2", "name_key": "p_crew_mess"})
	floor_u("GALLEY-U", "cabinet", 45.0, 48.4, 2.1, {"mass": 0.5, "value": 4500.0, "fragile": 0.35, "room": "U2", "name_key": "p_galley"})
	floor_u("ECS-U", "env", 49.0, 53.0, 2.9, {"mass": 0.8, "value": 9000.0, "fragile": 0.4, "room": "U2", "name_key": "p_ecs"})
	floor_u("MED-U", "cabinet", 53.6, 55.8, 2.3, {"mass": 0.3, "value": 6000.0, "fragile": 0.45, "room": "U2", "name_key": "p_pharmacy"})
	floor_u("WATER-U", "water", 56.4, 59.6, 1.9, {"mass": 0.5, "value": 1500.0, "fragile": 0.3, "room": "U2", "name_key": "p_water_tank"})
	floor_u("LOCKER-U1", "locker", 60.2, 61.8, 3.1, {"mass": 0.2, "value": 1800.0, "fragile": 0.3, "room": "U2", "name_key": "p_suit_locker"})
	floor_u("LOCKER-U2", "locker", 62.2, 63.8, 3.1, {"mass": 0.2, "value": 1800.0, "fragile": 0.3, "room": "U2", "name_key": "p_suit_locker"})
	ceil_u("AHU-U2", "env", 24.0, 27.6, 1.5, {"mass": 0.4, "value": 4500.0, "fragile": 0.4, "room": "U2", "name_key": "p_ahu"})
	ceil_u("HAB-PNL", "panel", 45.0, 48.0, 1.1, {"mass": 0.1, "value": 3000.0, "fragile": 0.45, "room": "U2", "name_key": "p_monitor_panel"})
	K.lamp("LAMP-U2", 30.0, UC, "U2", K.at(30.0, UC - 0.25, ["hull"]))
	# U3 the power room
	floor_u("GEN-U", "gen", 66.0, 71.0, 3.5, {"mass": 2.4, "value": 18000.0, "fragile": 0.35, "room": "U3", "name_key": "p_generator"})
	floor_u("BAT-U", "battery", 71.6, 75.6, 2.5, {"mass": 1.6, "value": 9000.0, "fragile": 0.4, "room": "U3", "hazard": "battery", "name_key": "p_battery"})
	floor_u("SWB-U", "swb", 76.2, 78.8, 3.5, {"mass": 0.5, "value": 6000.0, "fragile": 0.4, "room": "U3", "name_key": "p_swb"})
	floor_u("CAP-U", "cap", 79.4, 81.6, 2.9, {"mass": 0.6, "value": 7000.0, "fragile": 0.4, "room": "U3", "name_key": "p_capacitor"})
	floor_u("UPS-U", "battery", 82.2, 84.4, 2.1, {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "U3", "name_key": "p_ups"})
	floor_u("COOLP-U", "pump", 86.0, 89.0, 1.9, {"mass": 0.5, "value": 4000.0, "fragile": 0.35, "room": "U3", "name_key": "p_coolant_pump"})
	floor_u("COOL-T", "gastank", 90.0, 94.0, 2.5, {"mass": 0.6, "value": 2500.0, "fragile": 0.3, "room": "U3", "name_key": "p_coolant_tank"})
	ceil_u("RAD-U1", "radiator", 88.0, 94.0, 1.9, {"mass": 0.8, "value": 5000.0, "fragile": 0.35, "room": "U3", "name_key": "p_radiator"})
	ceil_u("RAD-U2", "radiator", 94.6, 100.6, 1.9, {"mass": 0.8, "value": 5000.0, "fragile": 0.35, "room": "U3", "name_key": "p_radiator"})
	ceil_u("INV-U", "cap", 72.0, 74.6, 1.3, {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "U3", "name_key": "p_inverter"})
	K.lamp("LAMP-U3", 70.0, UC, "U3", K.at(70.0, UC - 0.25, ["hull"]))


# ---------------------------------------------------------------- the lower hull: propellant, machinery, power and engines

static func _lower() -> void:
	# L1 propellant
	for e in [["RP-1", 18.0, 26.0], ["RP-2", 27.0, 35.0]]:
		floor_l(e[0], "fueltank", e[1], e[2], 6.3, {"mass": 2.6, "value": 6000.0, "fragile": 0.3, "room": "L1", "hazard": "fuel_tank", "name_key": "p_prop_tank"})
	floor_l("PUMP-T", "pump", 8.4, 11.4, 2.1, {"mass": 0.5, "value": 4000.0, "fragile": 0.35, "room": "L1", "name_key": "p_transfer_pump"})
	floor_l("VALVE-L", "panel", 11.8, 14.4, 1.7, {"mass": 0.3, "value": 3500.0, "fragile": 0.35, "room": "L1", "name_key": "p_valve_block"})
	ceil_l("PRES-L", "gastank", 8.6, 12.0, 1.3, {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "L1", "hazard": "gas_tank", "name_key": "p_pressurant"})
	floor_l("FUEL-MON", "screen", 36.0, 39.6, 1.6, {"mass": 0.1, "value": 3000.0, "fragile": 0.5, "room": "L1", "name_key": "p_fluid_monitor"})
	K.lamp("LAMP-L1", 36.6, LC, "L1", K.at(36.6, LC - 0.25, ["hull"]))
	# L2 machinery: the clamps' hydraulics
	floor_l("HPU-L", "gen", 45.0, 50.0, 3.3, {"mass": 1.8, "value": 9000.0, "fragile": 0.35, "room": "L2", "name_key": "p_hpu"})
	floor_l("HYD-T", "water", 50.6, 54.0, 2.7, {"mass": 0.6, "value": 2500.0, "fragile": 0.3, "room": "L2", "name_key": "p_hyd_tank"})
	floor_l("COMP-L", "pump", 54.6, 58.0, 2.7, {"mass": 0.6, "value": 4500.0, "fragile": 0.35, "room": "L2", "name_key": "p_compressor"})
	floor_l("BENCH-L", "cabinet", 58.6, 62.6, 1.5, {"mass": 0.4, "value": 3000.0, "fragile": 0.3, "room": "L2", "name_key": "p_workbench"})
	floor_l("SPARES-L", "locker", 63.0, 65.4, 3.1, {"mass": 0.3, "value": 2500.0, "fragile": 0.3, "room": "L2", "name_key": "p_parts_rack"})
	floor_l("WATRT-L", "filter", 67.4, 71.0, 2.9, {"mass": 0.5, "value": 4000.0, "fragile": 0.35, "room": "L2", "name_key": "p_water_treat"})
	floor_l("LUBE-L", "pump", 71.6, 74.4, 1.9, {"mass": 0.4, "value": 3000.0, "fragile": 0.35, "room": "L2", "name_key": "p_lube_pump"})
	floor_l("TOOLS-L", "locker", 74.8, 77.0, 3.1, {"mass": 0.3, "value": 2500.0, "fragile": 0.3, "room": "L2", "name_key": "p_locker"})
	ceil_l("HOIST-L", "arm", 60.0, 63.0, 1.9, {"mass": 0.3, "value": 3000.0, "fragile": 0.35, "room": "L2", "name_key": "p_hoist"})
	ceil_l("VENT-L", "env", 66.0, 70.0, 1.5, {"mass": 0.4, "value": 4000.0, "fragile": 0.4, "room": "L2", "name_key": "p_hvac"})
	K.lamp("LAMP-L2", 48.0, LC, "L2", K.at(48.0, LC - 0.25, ["hull"]))
	# L3 power and the engines
	floor_l("FPUMP-L", "pump", 81.0, 83.6, 1.9, {"mass": 0.4, "value": 4000.0, "fragile": 0.35, "room": "L3", "name_key": "p_transfer_pump"})
	floor_l("GEN-L", "gen", 87.0, 91.6, 3.5, {"mass": 2.2, "value": 16000.0, "fragile": 0.35, "room": "L3", "name_key": "p_generator"})
	floor_l("BAT-L", "battery", 92.0, 95.0, 2.5, {"mass": 1.4, "value": 8000.0, "fragile": 0.4, "room": "L3", "hazard": "battery", "name_key": "p_battery"})
	floor_l("PWR-L", "swb", 95.6, 97.6, 3.1, {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "L3", "name_key": "p_power_board"})
	floor_l("ENG-L1", "eng_core", 98.0, 102.0, 2.5, {"mass": 2.8, "value": 22000.0, "fragile": 0.3, "room": "L3", "name_key": "p_engine"})
	ceil_l("ENG-L2", "eng_core", 98.0, 102.0, 2.5, {"mass": 2.8, "value": 22000.0, "fragile": 0.3, "room": "L3", "name_key": "p_engine"})
	K.lamp("LAMP-L3", 90.0, LC, "L3", K.at(90.0, LC - 0.25, ["hull"]))


# ---------------------------------------------------------------- the cargo inside: cabins over the common deck

static func _inside_cargo() -> void:
	var d1 = by_tag["DC-1"]
	var d2 = by_tag["DC-2"]
	# C1: cabins
	var k := 0
	for x0 in [37.6, 42.4, 47.2]:
		k += 1
		var lo = E("CBUNK-%dA" % k, "bunk", x0, -1.6, x0 + 4.2, -0.2, {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "room": "C1", "name_key": "p_bunk"}, d1, -0.15)
		var hi = K.equip("CBUNK-%dB" % k, "bunk", K.rect(x0, -3.2, x0 + 4.2, -1.65), {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "room": "C1", "name_key": "p_bunk"})
		K.bolt(hi, lo, x0 + 0.5, -1.6)
		K.bolt(hi, lo, x0 + 3.7, -1.6)
	k = 0
	for x0 in [52.0, 54.0, 56.0]:
		k += 1
		E("CLOCK-%d" % k, "locker", x0, -3.0, x0 + 1.6, -0.2, {"mass": 0.2, "value": 2000.0, "fragile": 0.3, "room": "C1", "name_key": "p_suit_locker"}, d1, -0.15)
	E("DESK-C", "console", 58.4, -1.6, 61.6, -0.2, {"mass": 0.3, "value": 5000.0, "fragile": 0.5, "room": "C1", "name_key": "p_crew_station"}, d1, -0.15)
	E("ECS-C", "env", 64.4, -3.2, 68.4, -0.2, {"mass": 0.8, "value": 9000.0, "fragile": 0.4, "room": "C1", "name_key": "p_ecs"}, d2, -0.15)
	E("LIFE-C", "env", 69.0, -3.4, 73.0, -0.2, {"mass": 0.9, "value": 11000.0, "fragile": 0.4, "room": "C1", "name_key": "p_life_support"}, d2, -0.15)
	E("AHU-C", "env", 38.4, -9.5, 41.6, -8.2, {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "C1", "name_key": "p_ahu"}, null, -9.55, -9.8)
	E("FIRE-C", "gastank", 66.0, -9.5, 67.6, -7.8, {"mass": 0.2, "value": 1500.0, "fragile": 0.3, "room": "C1", "name_key": "p_foam"}, null, -9.55, -9.8)
	E("DATA-C", "cabinet", 69.0, -9.5, 72.4, -8.4, {"mass": 0.3, "value": 7000.0, "fragile": 0.45, "room": "C1", "name_key": "p_data_archive"}, null, -9.55, -9.8)
	k = 0
	for x0 in [43.0, 47.2, 58.0]:
		k += 1
		E("STOW-%d" % k, "locker", x0, -9.5, x0 + 3.6, -8.0, {"mass": 0.2, "value": 1800.0, "fragile": 0.3, "room": "C1", "name_key": "p_stores"}, null, -9.55, -9.8)
	K.lamp("LAMP-C1", 45.0, -9.55, "C1", K.at(45.0, -9.8, ["hull"]))
	# under the common deck: oxygen, the air filter, spares, the cargo's radio
	E("O2-C", "gastank", 37.0, 0.2, 39.0, 2.4, {"mass": 0.2, "value": 1500.0, "fragile": 0.3, "room": "C2", "hazard": "gas_tank", "name_key": "p_o2_bottle"}, d1, 0.15)
	E("FILT-C", "filter", 39.6, 0.2, 42.6, 1.6, {"mass": 0.3, "value": 3500.0, "fragile": 0.35, "room": "C2", "name_key": "p_iso_filter"}, d1, 0.15)
	E("SPARE-C", "locker", 43.0, 0.2, 45.0, 2.6, {"mass": 0.2, "value": 2000.0, "fragile": 0.3, "room": "C2", "name_key": "p_parts_rack"}, d1, 0.15)
	E("COMMS-C", "nav", 52.6, 0.2, 55.0, 1.4, {"mass": 0.15, "value": 4000.0, "fragile": 0.5, "room": "C2", "name_key": "p_comms"}, d1, 0.15)
	# C2: the common deck
	E("GALLEY-C", "cabinet", 38.0, 7.4, 42.0, 9.5, {"mass": 0.5, "value": 4500.0, "fragile": 0.35, "room": "C2", "name_key": "p_galley"}, null, 9.55, 9.8)
	E("MESS-C", "cabinet", 42.6, 8.2, 46.6, 9.5, {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "room": "C2", "name_key": "p_crew_mess"}, null, 9.55, 9.8)
	E("MED-C", "cabinet", 47.2, 6.8, 50.4, 9.5, {"mass": 0.4, "value": 8000.0, "fragile": 0.45, "room": "C2", "name_key": "p_pharmacy"}, null, 9.55, 9.8)
	E("WATER-C", "water", 51.0, 7.4, 54.4, 9.5, {"mass": 0.5, "value": 1500.0, "fragile": 0.3, "room": "C2", "name_key": "p_water_tank"}, null, 9.55, 9.8)
	E("BAT-C", "battery", 55.0, 7.4, 58.0, 9.5, {"mass": 0.9, "value": 6000.0, "fragile": 0.4, "room": "C2", "hazard": "battery", "name_key": "p_battery"}, null, 9.55, 9.8)
	E("PWR-C", "swb", 58.6, 6.4, 60.6, 9.5, {"mass": 0.3, "value": 4500.0, "fragile": 0.4, "room": "C2", "name_key": "p_power_board"}, null, 9.55, 9.8)
	E("CON-C", "console", 61.4, 8.0, 64.6, 9.5, {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "room": "C2", "name_key": "p_cargo_mon"}, null, 9.55, 9.8)
	E("STORES-C", "locker", 65.2, 6.8, 68.2, 9.5, {"mass": 0.4, "value": 3000.0, "fragile": 0.3, "room": "C2", "name_key": "p_stores"}, null, 9.55, 9.8)
	E("REC-C", "screen", 68.8, 8.0, 72.0, 9.5, {"mass": 0.2, "value": 3500.0, "fragile": 0.5, "room": "C2", "name_key": "p_monitor_panel"}, null, 9.55, 9.8)
	K.lamp("LAMP-C2", 50.0, 0.15, "C2", d1)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	# the upper hull's bus
	K.line("b1", "cable", "power", "BAT-U", Vector2(75.6, -14.0), "SWB-U", Vector2(76.2, -14.0))
	K.line("p1", "cable", "power", "SWB-U", Vector2(77.5, -16.0), "LAMP-U3", Vector2(70.0, -19.39), [Vector2(77.5, -17.2), Vector2(70.0, -17.2)])
	K.line("p2", "cable", "power", "LAMP-U3", Vector2(69.8, -19.39), "LAMP-U2", Vector2(30.0, -19.39), [Vector2(69.8, -17.2), Vector2(30.0, -17.2)])
	K.line("p3", "cable", "power", "LAMP-U2", Vector2(29.8, -19.39), "LAMP-U1", Vector2(18.0, -19.39), [Vector2(29.8, -17.4), Vector2(18.0, -17.4)])
	K.line("p4", "cable", "power", "LAMP-U1", Vector2(17.8, -19.39), "HELM-U", Vector2(11.6, -14.05), [Vector2(17.6, -16.2), Vector2(11.6, -16.2)])
	K.line("p5", "cable", "power", "HELM-U", Vector2(9.0, -14.05), "NAV-U", Vector2(9.0, -16.8))
	K.line("p6", "cable", "power", "LAMP-U1", Vector2(18.2, -19.39), "COMMS-U", Vector2(14.4, -18.8), [Vector2(18.2, -18.8)])
	K.line("p7", "cable", "power", "LAMP-U1", Vector2(18.4, -19.39), "AV-U", Vector2(18.6, -16.6), [Vector2(18.6, -19.2)])
	K.line("p8", "cable", "power", "AV-U", Vector2(17.9, -14.0), "CAM-U", Vector2(17.6, -14.0))
	K.line("p9", "cable", "power", "AV-U", Vector2(19.4, -14.0), "LOG-U", Vector2(19.6, -14.0))
	K.line("p10", "cable", "power", "LAMP-U2", Vector2(30.2, -19.39), "AHU-U2", Vector2(27.6, -18.6), [Vector2(30.2, -18.6)])
	K.line("p11", "cable", "power", "LAMP-U2", Vector2(30.4, -19.39), "HAB-PNL", Vector2(45.0, -18.8), [Vector2(30.4, -18.8)])
	K.line("p12", "cable", "power", "HAB-PNL", Vector2(46.5, -18.4), "ECS-U", Vector2(51.0, -15.4), [Vector2(46.5, -16.0), Vector2(51.0, -16.0)])
	K.line("p13", "cable", "power", "ECS-U", Vector2(49.0, -14.0), "GALLEY-U", Vector2(48.4, -14.0))
	K.line("p14", "cable", "power", "ECS-U", Vector2(53.0, -14.0), "MED-U", Vector2(53.6, -14.0))
	K.line("p15", "cable", "power", "SWB-U", Vector2(77.0, -16.0), "INV-U", Vector2(73.0, -18.2), [Vector2(77.0, -16.8), Vector2(73.0, -16.8)])
	K.line("p16", "cable", "power", "SWB-U", Vector2(78.8, -14.0), "CAP-U", Vector2(79.4, -14.0))
	K.line("p17", "cable", "power", "CAP-U", Vector2(81.6, -14.0), "UPS-U", Vector2(82.2, -14.0))
	K.line("p18", "cable", "power", "UPS-U", Vector2(84.4, -13.6), "COOLP-U", Vector2(86.0, -13.6))
	K.line("p19", "cable", "power", "GEN-U", Vector2(71.0, -14.0), "BAT-U", Vector2(71.6, -14.0))
	K.line("u1", "pipe", "ucool", "COOL-T", Vector2(90.0, -14.0), "COOLP-U", Vector2(89.0, -14.0))
	K.line("u2", "pipe", "ucool", "COOL-T", Vector2(92.0, -15.0), "RAD-U1", Vector2(92.0, -17.6))
	K.line("u3", "pipe", "ucool", "RAD-U1", Vector2(94.0, -18.6), "RAD-U2", Vector2(94.6, -18.6))
	# the lower hull on its own battery
	K.line("q1", "cable", "power", "BAT-L", Vector2(95.0, 18.0), "PWR-L", Vector2(95.6, 18.0))
	K.line("q2", "cable", "power", "GEN-L", Vector2(91.6, 18.0), "BAT-L", Vector2(92.0, 18.0))
	K.line("q3", "cable", "power", "PWR-L", Vector2(96.6, 16.4), "LAMP-L3", Vector2(90.0, 12.61), [Vector2(96.6, 14.0), Vector2(90.0, 14.0)])
	K.line("q4", "cable", "power", "LAMP-L3", Vector2(89.8, 12.61), "LAMP-L2", Vector2(48.0, 12.61), [Vector2(89.8, 15.2), Vector2(48.0, 15.2)])
	K.line("q5", "cable", "power", "LAMP-L2", Vector2(47.8, 12.61), "LAMP-L1", Vector2(36.6, 12.61), [Vector2(47.8, 13.4), Vector2(36.6, 13.4)])
	K.line("q6", "cable", "power", "PWR-L", Vector2(97.6, 18.0), "ENG-L1", Vector2(98.0, 18.0))
	K.line("q7", "cable", "power", "PWR-L", Vector2(97.4, 16.4), "ENG-L2", Vector2(98.4, 15.0), [Vector2(97.4, 15.6), Vector2(98.4, 15.6)])
	K.line("q8", "cable", "power", "LAMP-L3", Vector2(90.2, 12.61), "FPUMP-L", Vector2(82.6, 17.6), [Vector2(90.2, 13.0), Vector2(82.6, 13.0)])
	K.line("q9", "cable", "power", "LAMP-L2", Vector2(48.2, 12.61), "HPU-L", Vector2(48.2, 16.2))
	K.line("q10", "cable", "power", "HPU-L", Vector2(49.6, 16.2), "COMP-L", Vector2(56.0, 16.8), [Vector2(49.6, 15.8), Vector2(56.0, 15.8)])
	K.line("q11", "cable", "power", "COMP-L", Vector2(58.0, 18.6), "BENCH-L", Vector2(58.6, 18.6))
	K.line("q12", "cable", "power", "LAMP-L3", Vector2(89.6, 12.61), "VENT-L", Vector2(70.0, 13.4), [Vector2(89.6, 13.4)])
	K.line("q13", "cable", "power", "VENT-L", Vector2(68.0, 14.0), "WATRT-L", Vector2(69.0, 16.6), [Vector2(68.0, 14.8), Vector2(69.0, 14.8)])
	K.line("q14", "cable", "power", "WATRT-L", Vector2(71.0, 18.0), "LUBE-L", Vector2(71.6, 18.0))
	K.line("q15", "cable", "power", "VENT-L", Vector2(66.0, 13.4), "HOIST-L", Vector2(63.0, 13.4))
	K.line("q16", "cable", "power", "LAMP-L1", Vector2(36.4, 12.61), "PUMP-T", Vector2(11.0, 17.4), [Vector2(36.4, 12.9), Vector2(14.0, 12.9), Vector2(14.0, 16.8), Vector2(11.0, 16.8)])
	K.line("q17", "cable", "power", "LAMP-L1", Vector2(36.8, 12.61), "FUEL-MON", Vector2(37.6, 17.9), [Vector2(36.8, 17.0), Vector2(37.6, 17.0)])
	# the propellant feed: both tanks to the pump, the pump aft to the engines' pump
	K.line("f1", "pipe", "feed", "RP-1", Vector2(18.0, 17.2), "PUMP-T", Vector2(11.2, 17.4), [Vector2(11.2, 17.2)])
	K.line("f2", "pipe", "feed", "RP-2", Vector2(27.0, 18.8), "RP-1", Vector2(26.0, 18.8))
	K.line("f3", "pipe", "feed", "PUMP-T", Vector2(10.0, 17.4), "FPUMP-L", Vector2(81.6, 17.6), [Vector2(10.0, 16.6), Vector2(17.6, 16.6), Vector2(17.6, 12.7), Vector2(42.0, 12.7), Vector2(42.0, 16.1), Vector2(81.6, 16.1)])
	K.line("f4", "pipe", "feed", "FPUMP-L", Vector2(83.6, 18.6), "GEN-L", Vector2(87.0, 18.6))
	K.line("h1", "pipe", "hyd", "HYD-T", Vector2(50.6, 18.0), "HPU-L", Vector2(50.0, 18.0))
	# the cargo on its own battery
	K.line("r1", "cable", "power", "BAT-C", Vector2(58.0, 8.4), "PWR-C", Vector2(58.6, 8.4))
	K.line("r2", "cable", "power", "PWR-C", Vector2(59.6, 6.4), "LAMP-C2", Vector2(50.0, 0.31), [Vector2(59.6, 4.0), Vector2(50.0, 4.0)])
	K.line("r3", "cable", "power", "PWR-C", Vector2(60.6, 8.8), "CON-C", Vector2(61.4, 8.8))
	K.line("r4", "cable", "power", "LAMP-C2", Vector2(50.2, 0.31), "LAMP-C1", Vector2(45.0, -9.39), [Vector2(51.7, 0.4), Vector2(51.7, -4.0), Vector2(45.0, -4.0)])
	K.line("r5", "cable", "power", "LAMP-C1", Vector2(45.2, -9.39), "AHU-C", Vector2(41.6, -8.8), [Vector2(45.2, -8.8)])
	K.line("r6", "cable", "power", "PWR-C", Vector2(59.0, 6.4), "ECS-C", Vector2(66.4, -0.2), [Vector2(59.0, 5.0), Vector2(66.4, 5.0)])
	K.line("r7", "cable", "power", "ECS-C", Vector2(68.4, -1.6), "LIFE-C", Vector2(69.0, -1.6))
	K.line("r8", "cable", "power", "LIFE-C", Vector2(71.0, -3.4), "DATA-C", Vector2(71.0, -8.4))
	K.line("r9", "cable", "power", "DESK-C", Vector2(61.6, -1.0), "ECS-C", Vector2(64.4, -1.0))
	K.line("r10", "cable", "power", "CON-C", Vector2(63.0, 8.0), "REC-C", Vector2(70.4, 8.0), [Vector2(63.0, 5.6), Vector2(70.4, 5.6)])
	K.line("r12", "cable", "power", "LAMP-C2", Vector2(49.8, 0.31), "FILT-C", Vector2(42.6, 1.0), [Vector2(49.8, 1.0)])
	K.line("r13", "cable", "power", "PWR-C", Vector2(60.2, 6.4), "COMMS-C", Vector2(54.0, 1.4), [Vector2(60.2, 3.0), Vector2(54.0, 3.0)])
	K.line("r11", "cable", "power", "PWR-C", Vector2(60.0, 6.4), "GALLEY-C", Vector2(40.0, 7.4), [Vector2(60.0, 5.2), Vector2(40.0, 5.2)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	for g in [["G-U1", 10.0, -20.25, "U1"], ["G-U2", 33.0, -20.25, "U2"], ["G-U3", 95.0, -20.25, "U3"],
			["G-L1", 25.0, 20.25, "L1"], ["G-L2", 55.0, 20.25, "L2"], ["G-L3", 95.0, 20.25, "L3"],
			["G-C1", 45.0, -10.25, "C1"], ["G-C2", 45.0, 10.25, "C2"]]:
		var gy: float = g[2]
		K.ctrl(g[0], "port", K.at(g[1], gy + (0.45 if gy < 0.0 else -0.45), ["hull"]), Vector2(g[1], gy), {"medium": "gas", "target": g[3]})
	for h in [["HT-U1", ""], ["HT-U2", ""], ["HT-U3", ""], ["HT-L1", ""], ["HT-L2", ""], ["HT-L3", ""], ["HT-C", ""], ["DK-C", "C1"]]:
		K.door(h[0], h[1])
	# the outside panel on the upper hull's roof
	var px = K.equip("PNL-X", "panel", K.rect(26.0, -20.5, 28.6, -20.0), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(26.4, -19.8, ["hull"]), 26.4, -20.0)
	K.bolt(px, K.at(28.2, -19.8, ["hull"]), 28.2, -20.0)
	K.ctrl("K-M", "switch", px, Vector2(26.4, -20.25), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(27.3, -20.25), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(28.2, -20.25), {"target": "aux", "state": false})
	# each clamp's hold, the beams' load cells
	for k in 4:
		var c: float = CLAMPS[k]
		K.ctrl("HC-U%d" % (k + 1), "switch", by_tag["CU-%d" % (k + 1)], Vector2(c, -11.0), {"target": "HC-U%d" % (k + 1), "state": true})
		K.ctrl("HC-L%d" % (k + 1), "switch", by_tag["CL-%d" % (k + 1)], Vector2(c, 11.0), {"target": "HC-L%d" % (k + 1), "state": true})
		var bx: float = BEAMS[k]
		K.ctrl("LC-%d" % (k + 1), "probe", by_tag["BM%d-2" % (k + 1)], Vector2(bx + 1.0, 0.0), {"medium": "load", "target": "BM%d" % (k + 1)})
	# the lower hull's and the cargo's own supplies; the fluids' and the pressurant's ports
	K.ctrl("K-L", "switch", by_tag["BAT-L"], Vector2(93.5, 18.4), {"target": "K-L", "state": true, "hidden_room": "L3"})
	K.ctrl("K-C", "switch", by_tag["BAT-C"], Vector2(56.5, 8.4), {"target": "K-C", "state": true, "hidden_room": "C2"})
	K.ctrl("PF-1", "port", by_tag["RP-1"], Vector2(22.0, 13.6), {"medium": "fuel", "target": "pf1", "hidden_room": "L1"})
	K.ctrl("PF-2", "port", by_tag["RP-2"], Vector2(31.0, 13.6), {"medium": "fuel", "target": "pf2", "hidden_room": "L1"})
	K.ctrl("PHE-L", "port", by_tag["PRES-L"], Vector2(10.3, 13.4), {"medium": "gas", "target": "HEL", "hidden_room": "L1"})
	K.ctrl("PHL", "port", by_tag["HYD-T"], Vector2(52.3, 17.2), {"medium": "hydraulic", "target": "hyd", "hidden_room": "L2"})
	K.ctrl("PO2C", "port", by_tag["O2-C"], Vector2(38.0, 2.2), {"medium": "gas", "target": "O2C", "hidden_room": "C2"})
	K.ctrl("PCU", "port", by_tag["COOL-T"], Vector2(92.0, -13.4), {"medium": "coolant", "target": "ucool", "hidden_room": "U3"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var ui: Array = K.inner(UOUT, T)
	var li: Array = K.inner(_dy(UOUT, 32.0), T)
	w.add_room("U1", K.mp([ui[7], ui[0], Vector2(22.0, UC), Vector2(22.0, UF), ui[5], ui[6]]))
	w.add_room("U2", K.R(22.4, UC, 64.0, UF))
	w.add_room("U3", K.mp([Vector2(64.4, UC), ui[1], ui[2], ui[3], ui[4], Vector2(64.4, UF)]))
	w.add_room("L1", K.mp([li[7], li[0], Vector2(40.0, LC), Vector2(40.0, LF), li[5], li[6]]))
	w.add_room("L2", K.R(40.4, LC, 80.0, LF))
	w.add_room("L3", K.mp([Vector2(80.4, LC), li[1], li[2], li[3], li[4], Vector2(80.4, LF)]))
	var ci: Array = K.inner(COUT, T)
	w.add_room("C1", K.mp([Vector2(36.45, -0.15), ci[7], ci[0], ci[1], ci[2], Vector2(75.55, -0.15)]))
	w.add_room("C2", K.mp([Vector2(36.45, 0.15), Vector2(75.55, 0.15), ci[3], ci[4], ci[5], ci[6]]))


static func meta() -> Dictionary:
	var cargo_eq: Array = ["CBUNK-1A", "CBUNK-1B", "CBUNK-2A", "CBUNK-2B", "CBUNK-3A", "CBUNK-3B", "CLOCK-1", "CLOCK-2", "CLOCK-3", "DESK-C", "ECS-C", "LIFE-C",
		"AHU-C", "DATA-C", "GALLEY-C", "MESS-C", "MED-C", "WATER-C", "BAT-C", "PWR-C", "CON-C", "STORES-C", "REC-C", "STOW-1", "STOW-2", "STOW-3", "FILT-C", "SPARE-C", "COMMS-C"]
	var u2: Array = ["BUNK-1A", "BUNK-1B", "BUNK-2A", "BUNK-2B", "BUNK-3A", "BUNK-3B", "MESS-U", "GALLEY-U", "AHU-U2", "HAB-PNL"]
	var clamps := {}
	for k in 4:
		clamps["CU-%d" % (k + 1)] = "HC-U%d" % (k + 1)
		clamps["CL-%d" % (k + 1)] = "HC-L%d" % (k + 1)
	return {
		"id": "ch110",
		"name": "CH-110 BOOKEND",
		"title": ["CH-110「书夹」双体重吊船 · 110 m", "CH-110 BOOKEND · TWIN-HULL HEAVY LIFTER · 110 m"],
		"contract": "CH-110",
		"length": 113.0,
		"value": {"total": 493800.0, "metal": 40000.0},
		"clamps": [[30.0, 20.0], [60.0, 20.0], [90.0, 20.0], [50.0, -20.0], [36.2, 2.0]],
		"room_names": {"U1": "room_chU1", "U2": "room_chU2", "U3": "room_chU3", "L1": "room_chL1", "L2": "room_chL2", "L3": "room_chL3", "C1": "room_chC1", "C2": "room_chC2"},
		"gas": {"rooms": {"U1": 101.0, "U2": 101.0, "U3": 101.0, "L1": 101.0, "L2": 101.0, "L3": 101.0, "C1": 60.0, "C2": 60.0},
			"vessels": {"HEL": {"V": 0.08, "kpa": 18000.0, "piece": "PRES-L", "burst": 200.0}, "O2C": {"V": 0.06, "kpa": 12000.0, "piece": "O2-C", "burst": 200.0}}, "valves": [], "value": 2600.0},
		"sandwich": {
			"rooms": ["C1", "C2"], "spring_kpa": 20.0,
			"upper": ["HC-U1", "HC-U2", "HC-U3", "HC-U4"], "lower": ["HC-L1", "HC-L2", "HC-L3", "HC-L4"],
			"order": ["HC-U1", "HC-L4", "HC-U4", "HC-L1", "HC-U2", "HC-L3", "HC-U3", "HC-L2"],
			"clamps": clamps,
			"spring_hits": cargo_eq + ["CU-1", "CU-2", "CU-3", "CU-4", "CL-1", "CL-2", "CL-3", "CL-4"],
			"twist_hits": cargo_eq + u2,
			"cracked": {"pieces": ["BM2-1a", "BM2-1b", "BM2-2", "BM2-3"], "guards": ["HC-U1", "HC-L1"], "hits": u2 + ["LOCKER-U1", "LOCKER-U2", "WATER-U", "ECS-U", "MED-U"]},
			"loads": {"LC-1": {"base": 120.0}, "LC-2": {"base": 120.0, "k": 1.6, "clamps": ["HC-U1", "HC-L1"]}, "LC-3": {"base": 120.0, "clamps": ["HC-U4", "HC-L4"]}, "LC-4": {"base": 120.0}},
		},
		"power": {
			"bus": "SWB-U",
			"sources": [
				{"piece": "BAT-U", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "b1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			# three systems: the lower hull and the cargo each on their own battery
			"isolated": [{"piece": "BAT-L", "volts": 440.0, "charge": 0.9, "switch": "K-L"}, {"piece": "BAT-C", "volts": 220.0, "charge": 0.9, "switch": "K-C"}],
			"lamps": {"U1": "LAMP-U1", "U2": "LAMP-U2", "U3": "LAMP-U3"},
		},
		"fluids": {"volumes": {
			"pf1": {"fluid": "fuel", "amount": 1.2, "piece": "RP-1", "port": "PF-1", "full": 1.5, "content": 1.0, "leak": 0.12, "pump": [0.14, 0.008]},
			"pf2": {"fluid": "fuel", "amount": 1.2, "piece": "RP-2", "port": "PF-2", "full": 1.5, "content": 1.0, "leak": 0.12, "pump": [0.14, 0.008]},
			"feed_line": {"fluid": "fuel", "amount": 0.02, "nets": ["feed"], "leak": 0.06, "leak_min": 0.004},
			"hyd": {"fluid": "hydraulic", "amount": 0.5, "piece": "HYD-T", "port": "PHL", "full": 0.6, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"hyd_line": {"fluid": "hydraulic", "amount": 0.02, "nets": ["hyd"], "leak": 0.06, "leak_min": 0.004},
			"ucool": {"fluid": "coolant", "amount": 0.3, "piece": "COOL-T", "port": "PCU", "full": 0.4, "content": 1.0, "nets": ["ucool"], "leak": 0.2, "pump": [0.2, 0.006]},
		}, "joins": [], "value": {"fuel": 3600.0, "hydraulic": 700.0, "coolant": 600.0}},
		"ctrls_cfg": {"G-U1": {"rate": 20.0}, "G-U2": {"rate": 34.0}, "G-U3": {"rate": 34.0}, "G-L1": {"rate": 30.0}, "G-L2": {"rate": 34.0}, "G-L3": {"rate": 26.0},
			"G-C1": {"rate": 36.0}, "G-C2": {"rate": 36.0}, "PHE-L": {"rate": 0.4}},
		"labels": {"BAT-U": "BAT", "SWB-U": "BUS", "BAT-L": "BAT L", "BAT-C": "BAT C", "RP-1": "PROP 1", "RP-2": "PROP 2", "LOG-U": "LOG", "BM2-1a": "CRACK", "HPU-L": "HPU"},
		"hints": {},
		"market": {
			"class": "CH", "name": ["书夹级双体重吊船", "BOOKEND-CLASS TWIN-HULL LIFTER"], "time": 50.0,
			"rooms": {"U1": [0.2, 40.0, 101.0], "U2": [0.2, 40.0, 101.0], "U3": [0.2, 40.0, 101.0], "L1": [0.2, 40.0, 101.0], "L2": [0.2, 40.0, 101.0], "L3": [0.2, 40.0, 101.0]},
			"charge": {"BAT-U": [0.3, 1.0]},
			"fluids": {"pf1": [0.4, 1.2], "pf2": [0.4, 1.2], "hyd": [0.2, 0.5]}, "fill": {"feed_line": "pf1", "hyd_line": "hyd"},
			"knockable": ["HELM-U", "AV-U", "CON-C"],
			"drift": [],
			"section_x": 88.0,
			"slots": {"fire_system": {"x": 66.0, "y0": 18.0, "y1": LF, "base": ["HL4-2", LF], "room": "L2", "port": [66.4, 18.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"LOG-U": [
				{"do": "hose", "ctrl": "G-U1"},
				{"do": "wait", "until": {"P": ["U1", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-U1"},
				{"do": "wait", "until": {"open": ["U1"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "LOG-U"},
				{"do": "deliver", "piece": "LOG-U", "zone": "equip"},
			],
		},
	}
