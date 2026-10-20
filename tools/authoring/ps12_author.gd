class_name Ps12Author
# Authoring script for PS-12 "Dawn", a 108 m passenger liner (design/ships/
# PS-12_晨光_设计稿.md v2 and PS-12_结构图.png, as drawn). Not part of the game:
# tools/ship_export.gd runs it and writes ships/ps12.json.
# Metres, x bow (0) to the nozzles (108), y down.
#
# Three levels in the main hull: the six suites on the top level forward and the
# crew quarters aft of the core, the upper passenger cabins (ten and seven rows),
# the lower living deck (twelve rest pods, the sanitation modules, the galley,
# baggage) forward and the small equipment room aft. Forward, the observation hall
# behind its big glass with the cockpit; amidships the service core runs through
# every level (stairs, the lift, the main distribution, the air handling, the
# standby generator and the battery) with a door on each level each side. Aft the
# long service section: the pressurised maintenance tunnel through an airlock, a
# propellant tank above and below it, the radiators, three engines. Four escape
# pods hang under the belly on launch clamps.
# What it asks of you: every pod's launch clamps carry a pyrotechnic charge (a
# hazard for the hazard bay; scripts/liner.gd) — a contract may leave one pod's
# firing circuit charged, and then its clamp undone before its arming switch in
# the core is opened fires the bolts and throws the pod off. The observation glass
# holds the hall's pressure: a pane freed with the hall still pressurised is blown
# out and shatters. The core links the levels: with a door open on two levels the
# two are one room.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, -0.4), Vector2(9.3, -7.2), Vector2(17.9, -8.4), Vector2(27.6, -8.8), Vector2(53.8, -8.8),
	Vector2(61.4, -7.7), Vector2(71.7, -7.7), Vector2(71.7, 4.6), Vector2(61.4, 7.7), Vector2(25.5, 8.1),
	Vector2(9.3, 6.2), Vector2(4.6, 3.4)]
const OUT_M := [Vector2(71.7, -3.1), Vector2(96.9, -3.1), Vector2(96.9, 3.1), Vector2(71.7, 3.1)]
const B1 := 17.9                 # the observation hall | the cabins (to 18.3)
const B2 := 43.8                 # forward | the core (to 44.2)
const B3 := 51.3                 # the core | aft (to 51.7)
const D1 := -4.4                 # the top level's floor (to -4.0)
const D2 := -0.2                 # the upper cabins' floor (to 0.2)
const AFT := 71.25               # the main hull's aft wall, inside
const PODS := [15.7, 35.9, 54.5, 65.0]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "PS12")
	w = world
	by_tag = K.by_tag
	_hull()
	_bulkheads()
	_decks()
	_forward()
	_suites()
	_cabins()
	_lower()
	_core()
	_crew()
	_tunnel()
	_pods()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "PS12")
	w = world
	_rooms()


static func _iy(out: Array, i: int, x: float) -> float:
	var inn := K.inner(out, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


static func _ix(out: Array, i: int, y: float) -> float:
	var inn := K.inner(out, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x)


static func _oy(i: int, x: float) -> float:
	var a: Vector2 = OUT[i]
	var b: Vector2 = OUT[(i + 1) % OUT.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# the inner floor under x along the bottom (edges 7 to 10)
static func _floor(x: float) -> float:
	if x >= 61.4:
		return _iy(OUT, 7, x)
	if x >= 25.5:
		return _iy(OUT, 8, x)
	if x >= 9.3:
		return _iy(OUT, 9, x)
	return _iy(OUT, 10, x)


# the outside of the bottom under x
static func _belly(x: float) -> float:
	if x >= 61.4:
		return _oy(7, x)
	if x >= 25.5:
		return _oy(8, x)
	return _oy(9, x)


# ---------------------------------------------------------------- the shells

static func _hull() -> void:
	var base := {"density": 1.6, "barrier": true, "cut_speed": 210.0}
	var glass := {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.3, "value": 2500.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_obs_glass"}
	K.ring(OUT, T, {
		0: [0.25, 0.5, 0.75],
		1: [0.3, 0.5],
		3: [0.1, 0.17, 0.802, 0.855],
		5: [0.3, 0.45],
		6: [0.431, 0.593],
		7: [0.262, 0.456],
		8: [0.3, 0.45, 0.6],
		9: [0.321, 0.401],
	}, {
		"0:0": glass.merged({"tag": "OBS-1"}), "0:1": glass.merged({"tag": "OBS-2"}), "0:2": glass.merged({"tag": "OBS-3"}), "0:3": glass.merged({"tag": "OBS-4"}),
		"1:1": {"kind": "hatch", "door": true, "tag": "HT-O", "open_dir": Vector2(2.2, -0.3) * Geom.M, "cut_speed": 200.0},
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-S", "open_dir": Vector2(2.0, 0) * Geom.M, "cut_speed": 200.0},
		"3:3": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(-1.6, 0) * Geom.M, "cut_speed": 200.0},
		"5:1": {"kind": "hatch", "door": true, "tag": "HT-Q", "open_dir": Vector2(1.6, 0) * Geom.M, "cut_speed": 200.0},
		"6:1": {"kind": "door", "door": true, "tag": "D-UM1", "open_dir": Vector2(0, -2.1) * Geom.M, "cut_speed": 190.0},
		"7:1": {"kind": "hatch", "door": true, "tag": "HT-L2", "open_dir": Vector2(2.0, -0.6) * Geom.M, "cut_speed": 200.0},
		"9:1": {"kind": "hatch", "door": true, "tag": "HT-L1", "open_dir": Vector2(-2.0, 0) * Geom.M, "cut_speed": 200.0},
	}, base, "HP")
	# the panes sit in glazing bars, not welds: the wrench undoes them
	for t in ["OBS-1", "OBS-2", "OBS-3", "OBS-4"]:
		for j in w.joints_of(by_tag[t]):
			j.type = "bolt"
	K.ring(OUT_M, T, {
		0: [0.29, 0.33],
		2: [0.792, 0.827],
		3: [0.565, 0.887],
	}, {
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-M", "open_dir": Vector2(-1.1, 0) * Geom.M, "cut_speed": 200.0},
		"3:1": {"kind": "door", "door": true, "tag": "D-UM2", "open_dir": Vector2(0, -2.1) * Geom.M, "cut_speed": 190.0},
	}, base, "HM")
	# the service section welded to the main hull's aft wall
	K.bolt(by_tag["HM3-0"], by_tag["HP6-2"], 71.7, 2.0, "weld")
	K.bolt(by_tag["HM3-2"], by_tag["HP6-0"], 71.7, -2.8, "weld")
	K.clamp(1, 27.0, _belly(27.0), _belly(27.0) - 0.2)
	K.clamp(2, 45.0, _belly(45.0), _belly(45.0) - 0.2)
	K.clamp(3, 60.0, _belly(60.0), _belly(60.0) - 0.2)


# ---------------------------------------------------------------- bulkheads, each with its doors

static func _wall(name: String, x: float, top: float, bot: float, doors: Array, anchor := true) -> void:
	# doors: [[tag, y0, y1, room the control is in]]
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	var y := top
	var prev = null
	var k := 0
	var cuts: Array = []
	for d in doors:
		cuts.append([d[1], d[2], d[0]])
	cuts.append([bot, bot, ""])
	for c in cuts:
		if c[0] > y + 0.01:
			k += 1
			var pl = K.plate("%s-%d" % [name, k], K.R(x, y, x + 0.4, c[0]), S, "bulkhead")
			if prev != null:
				K.bolt(pl, prev, x + 0.2, y, "weld")
			else:
				K.bolt(pl, K.at(x + 0.2, y - 0.2, ["hull"]), x + 0.2, y, "weld")
			prev = pl
		if c[2] != "":
			var dp = K.plate(c[2], K.R(x, c[0], x + 0.4, c[1]), {"density": 1.0, "door": true, "barrier": true, "open_dir": Vector2(0, -(c[1] - c[0]) - 0.1) * Geom.M, "cut_speed": 190.0}, "door")
			if prev != null:
				K.bolt(dp, prev, x + 0.2, c[0], "weld")
			prev = dp
		y = c[1]
	if anchor:
		K.bolt(prev, K.at(x + 0.2, bot + 0.2, ["hull"]), x + 0.2, bot, "weld")


static func _bulkheads() -> void:
	_wall("B1", B1, _iy(OUT, 2, B1 + 0.2), D2, [["D-OU", -2.4, -0.4, "O"]], false)
	_wall("B2", B2, _iy(OUT, 3, B2 + 0.2), _floor(B2 + 0.2), [["D-SC", -6.6, D1, "C"], ["D-UC", -2.6, D2, "C"], ["D-LC", 3.4, 5.6, "C"]])
	_wall("B3", B3, _iy(OUT, 3, B3 + 0.2), _floor(B3 + 0.2), [["D-CQ", -6.6, D1, "C"], ["D-CU", -2.6, D2, "C"], ["D-CL", 3.4, 5.6, "C"]])


# ---------------------------------------------------------------- the decks

static func _decks() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 200.0, "name_key": "p_deck"}
	var d1f = K.plate("D1-F", K.R(B1 + 0.4, D1, B2, D1 + 0.4), S, "deck")
	K.bolt(d1f, by_tag["B1-1"], B1 + 0.4, D1 + 0.2, "weld")
	K.bolt(d1f, by_tag["B2-2"], B2, D1 + 0.2, "weld")
	var d1a = K.plate("D1-A", K.R(B3 + 0.4, D1, AFT, D1 + 0.4), S, "deck")
	K.bolt(d1a, by_tag["B3-2"], B3 + 0.4, D1 + 0.2, "weld")
	K.bolt(d1a, K.at(AFT + 0.2, D1 + 0.2, ["hull"]), AFT, D1 + 0.2, "weld")
	var xf := _ix(OUT, 11, D2 + 0.2)
	var d2f = K.plate("D2-F", K.R(xf, D2, B2, D2 + 0.4), S, "deck")
	K.bolt(d2f, K.at(xf - 0.2, D2 + 0.2, ["hull"]), xf, D2 + 0.2, "weld")
	K.bolt(d2f, by_tag["B1-2"], B1 + 0.2, D2, "weld")
	K.bolt(d2f, by_tag["B2-3"], B2, D2 + 0.2, "weld")
	var d2a = K.plate("D2-A", K.R(B3 + 0.4, D2, AFT, D2 + 0.4), S, "deck")
	K.bolt(d2a, by_tag["B3-3"], B3 + 0.4, D2 + 0.2, "weld")
	K.bolt(d2a, K.at(AFT + 0.2, D2 + 0.2, ["hull"]), AFT, D2 + 0.2, "weld")


# ---------------------------------------------------------------- forward: the observation hall and the cockpit

static func _forward() -> void:
	var d2 = by_tag["D2-F"]
	for e in [["SEAT-P", 3.2], ["SEAT-C", 4.6]]:
		var st = K.seat(e[0], Rect2(e[1], D2 - 1.5, 0.8, 1.5), {"room": "O", "name_key": "p_seat_pilot"})
		K.bolt(st, d2, e[1] + 0.2, D2)
		K.bolt(st, d2, e[1] + 0.6, D2, "lock")
	var hm = K.equip("HELM", "console", K.rect(5.8, D2 - 1.2, 8.4, D2), {"mass": 0.3, "value": 5500.0, "fragile": 0.5, "room": "O", "name_key": "p_helm"})
	K.bolt(hm, d2, 6.2, D2)
	K.bolt(hm, d2, 8.0, D2)
	var nv = K.equip("NAV-P", "nav_rack", K.rect(8.8, D2 - 2.4, 9.9, D2), {"mass": 0.3, "value": 7000.0, "fragile": 0.5, "room": "O", "name_key": "p_nav_station"})
	K.bolt(nv, d2, 9.1, D2)
	K.bolt(nv, d2, 9.6, D2)
	for i in 3:
		var sx := 10.4 + i * 2.4
		var os = K.seat("OSEAT-%d" % (i + 1), Rect2(sx, D2 - 1.5, 0.9, 1.5), {"room": "O", "value": 1500.0, "mass": 0.4, "name_key": "p_seat_row"})
		K.bolt(os, d2, sx + 0.2, D2, "lock")
		K.bolt(os, d2, sx + 0.7, D2, "lock")
	var vd = K.equip("VDR", "blackbox", K.rect(16.2, D2 - 1.4, B1, D2), {"mass": 0.15, "value": 8000.0, "fragile": 0.5, "room": "O", "mandatory": true, "name_key": "p_voyage_recorder"})
	K.bolt(vd, d2, 16.6, D2)
	K.bolt(vd, d2, 17.5, D2)
	K.lamp("LAMP-O", 10.2, _iy(OUT, 1, 10.2), "O", K.at(10.2, _iy(OUT, 1, 10.2) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the top level: six suites

static func _suites() -> void:
	var d1 = by_tag["D1-F"]
	for i in 6:
		var x0 := 18.6 + i * 4.2
		var su = K.equip("SUITE-%d" % (i + 1), "bed", K.rect(x0, -7.6, x0 + 3.8, D1), {"mass": 0.6, "value": 3000.0, "fragile": 0.35, "room": "S", "name_key": "p_suite"})
		K.bolt(su, d1, x0 + 0.5, D1)
		K.bolt(su, d1, x0 + 3.3, D1)
	K.lamp("LAMP-S", 37.0, -8.35, "S", K.at(37.0, -8.55, ["hull"]))


# ---------------------------------------------------------------- the upper cabins: a row of seats a piece

static func _row(tag: String, x: float, deck, room: String) -> void:
	var st = K.seat(tag, Rect2(x, D2 - 1.5, 0.9, 1.5), {"room": room, "value": 1500.0, "mass": 0.4, "name_key": "p_seat_row"})
	K.bolt(st, deck, x + 0.2, D2, "lock")
	K.bolt(st, deck, x + 0.7, D2, "lock")


static func _cabins() -> void:
	var d2f = by_tag["D2-F"]
	var d2a = by_tag["D2-A"]
	for k in 10:
		_row("ROW-%d" % (k + 1), 19.0 + k * 2.3, d2f, "U1")
	var cs = K.equip("CREW-ST", "console", K.rect(42.0, -2.6, B2, D2), {"mass": 0.3, "value": 4000.0, "fragile": 0.45, "room": "U1", "name_key": "p_crew_station"})
	K.bolt(cs, d2f, 42.4, D2)
	K.bolt(cs, d2f, 43.4, D2)
	for k in 7:
		_row("ROW-%d" % (k + 11), 52.6 + k * 2.3, d2a, "U2")
	var k2 := 0
	for e in [["BIN-1", 18.6, 30.6, "D1-F", "U1"], ["BIN-2", 31.0, 43.0, "D1-F", "U1"], ["BIN-3", 52.0, 64.0, "D1-A", "U2"]]:
		k2 += 1
		var bn = K.equip(e[0], "locker", K.rect(e[1], D1 + 0.4, e[2], D1 + 1.1), {"mass": 0.6, "value": 1000.0, "fragile": 0.3, "room": e[4], "name_key": "p_bins"})
		K.bolt(bn, by_tag[e[3]], e[1] + 0.6, D1 + 0.4)
		K.bolt(bn, by_tag[e[3]], e[2] - 0.6, D1 + 0.4)
	K.lamp("LAMP-U1", 31.0, D1 + 1.1, "U1", by_tag["BIN-2"])
	K.lamp("LAMP-U2", 66.0, D1 + 0.4, "U2", by_tag["D1-A"])


# ---------------------------------------------------------------- the lower deck: rest pods, sanitation, galley, baggage; the equipment room aft

static func _lower() -> void:
	# twelve rest pods, two high
	for c in 6:
		var x0 := 9.8 + c * 2.6
		var fy := _floor(x0)
		var lo = K.equip("BUNK-%d" % (c + 1), "bunk", K.rect(x0, fy - 1.5, x0 + 2.4, fy), {"mass": 0.5, "value": 2000.0, "fragile": 0.3, "room": "L1", "name_key": "p_rest_pod"})
		K.bolt(lo, K.at(x0 + 0.3, _floor(x0 + 0.3) + 0.2, ["hull"]), x0 + 0.3, fy)
		K.bolt(lo, K.at(x0 + 0.9, _floor(x0 + 0.9) + 0.2, ["hull"]), x0 + 0.9, fy)
		var hi = K.equip("BUNK-%d" % (c + 7), "bunk", K.rect(x0, fy - 3.2, x0 + 2.4, fy - 1.7), {"mass": 0.5, "value": 2000.0, "fragile": 0.3, "room": "L1", "name_key": "p_rest_pod"})
		K.bolt(hi, lo, x0 + 0.5, fy - 1.7)
		K.bolt(hi, lo, x0 + 1.9, fy - 1.7)
	for k in 3:
		var x0 := 26.0 + k * 2.6
		var fy := minf(_floor(x0), _floor(x0 + 2.2))
		var sn = K.equip("SAN-%d" % (k + 1), "water", K.rect(x0, fy - 3.4, x0 + 2.2, fy), {"mass": 0.5, "value": 3000.0, "fragile": 0.35, "room": "L1", "name_key": "p_sanitation"})
		K.bolt(sn, K.at(x0 + 1.8, fy + 0.2, ["hull"]), x0 + 1.8, fy)
		K.bolt(sn, K.at(x0 + 2.0, fy + 0.2, ["hull"]), x0 + 2.0, fy)
	var gx := 34.4
	var gy := minf(_floor(gx), _floor(gx + 3.6))
	var gl = K.equip("GALLEY", "cabinet", K.rect(gx, gy - 3.0, gx + 3.6, gy), {"mass": 0.8, "value": 6000.0, "fragile": 0.4, "room": "L1", "name_key": "p_galley"})
	K.bolt(gl, K.at(gx + 3.0, gy + 0.2, ["hull"]), gx + 3.0, gy)
	K.bolt(gl, K.at(gx + 3.4, gy + 0.2, ["hull"]), gx + 3.4, gy)
	var bx := 38.8
	var by := minf(_floor(bx), _floor(43.6))
	var bg = K.equip("BAGS", "locker", K.rect(bx, by - 4.4, 43.6, by), {"mass": 0.6, "value": 1800.0, "fragile": 0.3, "room": "L1", "name_key": "p_baggage"})
	K.bolt(bg, K.at(43.2, by + 0.2, ["hull"]), 43.2, by)
	K.bolt(bg, by_tag["B2-4"], B2, by - 1.0)
	K.lamp("LAMP-L1", 30.0, D2 + 0.4, "L1", by_tag["D2-F"])
	# the small equipment room aft
	var ab = K.equip("AUX-BATT", "battery", K.rect(51.7, _floor(54.7) - 2.9, 54.7, _floor(54.7)), {"mass": 0.8, "value": 6000.0, "fragile": 0.4, "room": "L2", "hazard": "battery", "name_key": "p_aux_battery"})
	K.bolt(ab, K.at(54.4, _floor(54.4) + 0.2, ["hull"]), 54.4, _floor(54.7))
	K.bolt(ab, by_tag["B3-4"], B3 + 0.4, _floor(54.7) - 1.0)
	var pl = K.equip("PUMP-L", "pump", K.rect(56.0, _floor(58.4) - 1.8, 58.4, _floor(58.4)), {"mass": 0.6, "value": 4500.0, "fragile": 0.35, "room": "L2", "name_key": "p_pump"})
	K.bolt(pl, K.at(58.0, _floor(58.0) + 0.2, ["hull"]), 58.0, _floor(58.4))
	K.bolt(pl, K.at(58.3, _floor(58.3) + 0.2, ["hull"]), 58.3, _floor(58.4))
	var cl = K.equip("COOL-L", "radiator", K.rect(60.4, _floor(63.4) - 2.2, 63.4, _floor(63.4)), {"mass": 0.7, "value": 5000.0, "fragile": 0.35, "room": "L2", "name_key": "p_heat_exchanger"})
	K.bolt(cl, K.at(63.0, _floor(63.0) + 0.2, ["hull"]), 63.0, _floor(63.4))
	K.bolt(cl, K.at(63.3, _floor(63.3) + 0.2, ["hull"]), 63.3, _floor(63.4))
	K.lamp("LAMP-L2", 60.0, D2 + 0.4, "L2", by_tag["D2-A"])


# ---------------------------------------------------------------- the service core

static func _core() -> void:
	var top := -8.35
	var bot := _floor(48.0)
	var b3x := B3
	var st = K.equip("STAIR", "ladder", K.rect(B2 + 0.4, top, 45.8, bot), {"cls": "metal", "dest": "metal", "mass": 0.8, "cut_speed": 170.0, "name_key": "p_stairs"})
	for yy in [-7.0, -3.4, 1.5, 6.5]:
		K.bolt(st, by_tag[_b2_at(yy)], B2 + 0.4, yy)
	var lr = K.plate("LIFT-R", K.R(48.2, top, 48.4, bot), {"density": 1.4, "barrier": false, "cut_speed": 160.0, "name_key": "p_lift_rail"}, "strut")
	K.bolt(lr, K.at(48.3, top - 0.2, ["hull"]), 48.3, top, "weld")
	K.bolt(lr, K.at(48.3, _floor(48.3) + 0.2, ["hull"]), 48.3, _floor(48.3), "weld")
	var lf = K.equip("LIFT", "locker", K.rect(46.2, -2.6, 48.2, D2), {"mass": 1.4, "value": 9000.0, "fragile": 0.35, "room": "C", "name_key": "p_lift_car"})
	K.bolt(lf, lr, 48.2, -2.2)
	K.bolt(lf, lr, 48.2, -0.6)
	var md = K.equip("MAIN-DIST", "swb", K.rect(49.0, -8.0, b3x, -5.4), {"mass": 0.6, "value": 8000.0, "fragile": 0.4, "room": "C", "name_key": "p_main_dist"})
	K.bolt(md, by_tag["B3-1"], b3x, -7.4)
	K.bolt(md, by_tag["B3-1"], b3x, -6.8)
	var hv = K.equip("HVAC", "env", K.rect(49.0, -4.6, b3x, -1.4), {"mass": 0.9, "value": 9000.0, "fragile": 0.4, "room": "C", "name_key": "p_hvac"})
	K.bolt(hv, by_tag["B3-2"], b3x, -4.0)
	K.bolt(hv, by_tag["B3-2"], b3x, -3.0)
	var gn = K.equip("GEN-P", "gen", K.rect(49.0, 0.4, b3x, 3.0), {"mass": 1.2, "value": 11000.0, "fragile": 0.35, "room": "C", "name_key": "p_standby_gen"})
	K.bolt(gn, by_tag["B3-3"], b3x, 1.0)
	K.bolt(gn, by_tag["B3-3"], b3x, 2.4)
	var bt = K.equip("BAT", "battery", K.rect(49.0, 5.8, b3x, _floor(b3x)), {"mass": 1.2, "value": 7000.0, "fragile": 0.4, "room": "C", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, by_tag["B3-4"], b3x, 6.3)
	K.bolt(bt, K.at(50.0, _floor(50.0) + 0.2, ["hull"]), 50.0, _floor(b3x))
	var pc = K.equip("PODCP", "insp", K.rect(46.2, 4.2, 48.2, 5.8), {"mass": 0.1, "value": 3000.0, "fragile": 0.45, "room": "C", "name_key": "p_pod_panel"})
	K.bolt(pc, lr, 48.2, 4.6)
	K.bolt(pc, lr, 48.2, 5.4)
	K.lamp("LAMP-C", 47.0, top, "C", K.at(47.0, top - 0.2, ["hull"]))


# the B2 piece at height y
static func _b2_at(y: float) -> String:
	for k in range(1, 8):
		var t := "B2-%d" % k
		if not by_tag.has(t):
			continue
		var bb := Geom.bbox(by_tag[t].poly)
		if y * Geom.M >= bb.position.y and y * Geom.M <= bb.end.y:
			return t
	return "B2-1"


# ---------------------------------------------------------------- the crew quarters, top level aft

static func _crew() -> void:
	var d1 = by_tag["D1-A"]
	for c in 3:
		var x0 := 52.4 + c * 2.6
		var lo = K.equip("CREW-B%d" % (c + 1), "bunk", K.rect(x0, -5.8, x0 + 2.4, D1), {"mass": 0.3, "value": 800.0, "fragile": 0.3, "room": "Q", "name_key": "p_crew_bunk"})
		K.bolt(lo, d1, x0 + 0.4, D1)
		K.bolt(lo, d1, x0 + 2.0, D1)
		var hi = K.equip("CREW-B%d" % (c + 4), "bunk", K.rect(x0, -7.2, x0 + 2.4, -5.9), {"mass": 0.3, "value": 800.0, "fragile": 0.3, "room": "Q", "name_key": "p_crew_bunk"})
		K.bolt(hi, lo, x0 + 0.6, -5.9)
		K.bolt(hi, lo, x0 + 1.8, -5.9)
	var ms = K.equip("MESS", "cabinet", K.rect(61.0, -5.6, 65.0, D1), {"mass": 0.4, "value": 2500.0, "fragile": 0.35, "room": "Q", "name_key": "p_crew_mess"})
	K.bolt(ms, d1, 61.4, D1)
	K.bolt(ms, d1, 64.6, D1)
	var ah = K.equip("AHU-T", "env", K.rect(66.0, -7.0, 70.8, D1), {"mass": 0.7, "value": 6000.0, "fragile": 0.4, "room": "Q", "name_key": "p_ahu"})
	K.bolt(ah, d1, 66.4, D1)
	K.bolt(ah, d1, 70.4, D1)
	K.lamp("LAMP-Q", 63.0, _iy(OUT, 5, 63.0), "Q", K.at(63.0, _iy(OUT, 5, 63.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the service section

static func _tunnel() -> void:
	for k in 6:
		var x0 := 73.0 + k * 4.0
		var pump := k % 2 == 0
		var u = K.equip("SVC-%d" % (k + 1), "pump" if pump else "cabinet", K.rect(x0, 0.25, x0 + 3.0, 2.65), {"mass": 0.7, "value": 4500.0 if pump else 3500.0, "fragile": 0.35, "room": "M", "name_key": "p_svc_pump" if pump else "p_svc_cabinet"})
		K.bolt(u, K.at(x0 + 0.4, 2.85, ["hull"]), x0 + 0.4, 2.65)
		K.bolt(u, K.at(x0 + 2.6, 2.85, ["hull"]), x0 + 2.6, 2.65)
	K.lamp("LAMP-M", 86.0, -2.65, "M", K.at(86.0, -2.85, ["hull"]))
	for e in [["PROP-1", -4.9, -3.1, -2.9], ["PROP-2", 3.1, 4.9, 2.9]]:
		var pp = K.equip(e[0], "fueltank", K.rect(73.0, e[1], 78.5, e[2]), {"mass": 1.0, "value": 2500.0, "fragile": 0.3, "hazard": "fuel_tank", "name_key": "p_svc_prop"})
		var yb: float = e[2] if e[0] == "PROP-1" else e[1]
		K.bolt(pp, K.at(73.6, e[3], ["hull"]), 73.6, yb, "lock")
		K.bolt(pp, K.at(77.9, e[3], ["hull"]), 77.9, yb, "lock")
	for e in [["RAD-T", -8.2, -3.1, -2.9], ["RAD-B", 3.1, 8.2, 2.9]]:
		var y0: float = e[1]
		var y1: float = e[2]
		var poly := K.mp([Vector2(80.0, y1), Vector2(94.0, y1), Vector2(92.0, y0), Vector2(82.0, y0)]) if e[0] == "RAD-T" else K.mp([Vector2(80.0, y0), Vector2(94.0, y0), Vector2(92.0, y1), Vector2(82.0, y1)])
		var rd = K.equip(e[0], "radiator", K.rect(80.0, y0, 94.0, y1), {"mass": 1.0, "value": 6000.0, "fragile": 0.35, "name_key": "p_radiator"}, poly)
		var yb2: float = y1 if e[0] == "RAD-T" else y0
		for bx in [81.0, 87.0, 93.0]:
			K.bolt(rd, K.at(bx, e[3], ["hull"]), bx, yb2)
	for i in 3:
		var y0 := -4.2 + i * 2.9
		var en = K.equip("ENG-%d" % (i + 1), "eng_core", K.rect(96.9, y0, 101.0, y0 + 2.6), {"mass": 1.8, "value": 9000.0, "fragile": 0.3, "name_key": "p_engine"})
		var by := clampf(y0 + 1.3, -2.6, 2.6)
		K.bolt(en, K.at(96.65, by, ["hull"]), 96.9, by)
		var nz = K.equip("NOZ-%d" % (i + 1), "nozzle", K.rect(101.0, y0 - 0.3, 107.6, y0 + 2.9), {"cls": "metal", "dest": "metal", "mass": 0.4, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(101.0, y0 + 0.4), Vector2(107.6, y0 - 0.3), Vector2(107.6, y0 + 2.9), Vector2(101.0, y0 + 2.2)]))
		K.bolt(nz, en, 101.0, y0 + 0.8)
		K.bolt(nz, en, 101.0, y0 + 1.8)


# ---------------------------------------------------------------- the escape pods under the belly

static func _pods() -> void:
	for i in 4:
		var n := str(i + 1)
		var cx: float = PODS[i]
		var top: float = maxf(_belly(cx - 1.7), _belly(cx + 1.7)) + 0.6
		var pd = K.equip("POD-" + n, "module", K.rect(cx - 1.7, top, cx + 1.7, top + 1.5), {"mass": 2.5, "value": 18000.0, "fragile": 0.3, "name_key": "p_escape_pod"})
		var k := 0
		for xa in [cx - 1.2, cx + 0.9]:
			k += 1
			var ht: float = maxf(_belly(xa), _belly(xa + 0.3))
			var cp = K.plate("CLP-%s%d" % [n, k], K.R(xa, ht, xa + 0.3, top), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_launch_clamp"}, "strut")
			K.bolt(cp, K.at(xa + 0.15, ht - 0.2, ["hull"]), xa + 0.15, ht, "weld")
			K.bolt(pd, cp, xa + 0.15, top, "lock", "LC-%s%d" % [n, k])
		# the pyrotechnic charge on the forward clamp
		var ht1: float = maxf(_belly(cx - 1.2), _belly(cx - 0.9))
		var py = K.equip("PYRO-" + n, "cap", K.rect(cx - 1.55, ht1 + 0.1, cx - 1.2, ht1 + 0.4), {"mass": 0.02, "value": 400.0, "fragile": 0.5, "hazard": "explosive", "name_key": "p_pyro"})
		K.bolt(py, by_tag["CLP-%s1" % n], cx - 1.2, ht1 + 0.25, "bolt", "PB-" + n)
		# its firing capacitor on the other side of the clamp
		var fc = K.equip("FCAP-" + n, "cap", K.rect(cx - 0.9, ht1 + 0.1, cx - 0.55, ht1 + 0.4), {"mass": 0.03, "value": 300.0, "fragile": 0.5, "name_key": "p_firing_cap"})
		K.bolt(fc, by_tag["CLP-%s1" % n], cx - 0.9, ht1 + 0.25)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(49.4, 5.8), "MAIN-DIST", Vector2(49.4, -5.4), [Vector2(48.8, 5.8), Vector2(48.8, -5.4)])
	K.line("p2", "cable", "power", "MAIN-DIST", Vector2(49.0, -6.0), "LAMP-C", Vector2(47.0, -8.19), [Vector2(48.0, -6.0), Vector2(48.0, -8.0), Vector2(47.0, -8.0)])
	K.line("p3", "cable", "power", "MAIN-DIST", Vector2(49.0, -7.0), "LAMP-S", Vector2(37.0, -8.19), [Vector2(46.0, -7.0), Vector2(46.0, -8.05), Vector2(37.0, -8.05)])
	K.line("p4", "cable", "power", "LAMP-S", Vector2(36.8, -8.19), "LAMP-O", Vector2(10.2, _iy(OUT, 1, 10.2) + 0.16), [Vector2(36.8, -7.8), Vector2(18.1, -7.8), Vector2(18.1, -7.0), Vector2(10.2, -7.0)])
	K.line("p5", "cable", "power", "LAMP-O", Vector2(10.4, _iy(OUT, 1, 10.2) + 0.16), "HELM", Vector2(7.0, D2 - 1.2), [Vector2(10.4, -3.0), Vector2(7.0, -3.0)])
	K.line("p6", "cable", "power", "HELM", Vector2(8.4, D2 - 0.6), "NAV-P", Vector2(8.8, D2 - 0.6))
	K.line("p7", "cable", "power", "NAV-P", Vector2(9.6, D2 - 2.4), "VDR", Vector2(16.8, D2 - 1.4), [Vector2(9.6, -3.2), Vector2(16.8, -3.2)])
	K.line("p8", "cable", "power", "MAIN-DIST", Vector2(49.0, -5.6), "LAMP-U1", Vector2(31.0, D1 + 1.26), [Vector2(46.4, -5.6), Vector2(46.4, -3.1), Vector2(31.0, -3.1)])
	K.line("p9", "cable", "power", "LAMP-U1", Vector2(31.2, D1 + 1.26), "CREW-ST", Vector2(42.6, -2.6), [Vector2(31.2, -3.0), Vector2(42.6, -3.0)])
	K.line("p10", "cable", "power", "HVAC", Vector2(49.0, -2.0), "LAMP-L1", Vector2(30.0, D2 + 0.56), [Vector2(46.0, -2.0), Vector2(46.0, 0.7), Vector2(30.0, 0.7)])
	K.line("p11", "cable", "power", "MAIN-DIST", Vector2(50.0, -5.4), "HVAC", Vector2(50.0, -4.6))
	K.line("p12", "cable", "power", "HVAC", Vector2(50.2, -1.4), "GEN-P", Vector2(50.2, 0.4))
	K.line("p13", "cable", "power", "LAMP-L1", Vector2(30.2, D2 + 0.56), "GALLEY", Vector2(35.0, _floor(34.4) - 3.0), [Vector2(30.2, 1.0), Vector2(35.0, 1.0)])
	K.line("p14", "cable", "power", "MAIN-DIST", Vector2(50.6, -8.0), "LAMP-Q", Vector2(63.0, _iy(OUT, 5, 63.0) + 0.16), [Vector2(50.6, -8.2), Vector2(52.2, -8.2), Vector2(52.2, -7.4), Vector2(63.0, -7.4)])
	K.line("p15", "cable", "power", "LAMP-Q", Vector2(63.2, _iy(OUT, 5, 63.0) + 0.16), "AHU-T", Vector2(67.0, -7.0), [Vector2(67.0, -7.15)])
	K.line("p16", "cable", "power", "GEN-P", Vector2(50.6, 3.0), "LAMP-L2", Vector2(60.0, D2 + 0.56), [Vector2(50.6, 3.4), Vector2(52.0, 3.4), Vector2(52.0, 0.8), Vector2(60.0, 0.8)])
	K.line("p17", "cable", "power", "LAMP-L2", Vector2(60.2, D2 + 0.56), "PUMP-L", Vector2(57.0, _floor(58.4) - 1.8), [Vector2(60.2, 1.2), Vector2(57.0, 1.2)])
	K.line("p18", "cable", "power", "MAIN-DIST", Vector2(51.0, -5.4), "LAMP-U2", Vector2(66.0, D1 + 0.56), [Vector2(51.0, -3.6), Vector2(66.0, -3.6)])
	K.line("p19", "cable", "power", "LAMP-U2", Vector2(66.2, D1 + 0.56), "LAMP-M", Vector2(86.0, -2.49), [Vector2(70.0, -3.6), Vector2(70.0, -1.8), Vector2(86.0, -1.8)])
	K.line("p20", "cable", "power", "LAMP-M", Vector2(86.2, -2.49), "SVC-4", Vector2(86.0, 0.25), [Vector2(86.2, -1.4), Vector2(86.0, -1.4)])
	K.line("p21", "cable", "power", "GEN-P", Vector2(49.0, 2.0), "PODCP", Vector2(47.2, 4.2), [Vector2(47.2, 2.0)])
	# the coolant between the radiators, down through the tunnel
	for i in 4:
		var cx: float = PODS[i]
		var ht1: float = maxf(_belly(cx - 1.2), _belly(cx - 0.9))
		K.line("fc%d" % (i + 1), "cable", "power", "FCAP-%d" % (i + 1), Vector2(cx - 0.72, ht1 + 0.4), "PYRO-%d" % (i + 1), Vector2(cx - 1.38, ht1 + 0.4), [Vector2(cx - 0.72, ht1 + 0.5), Vector2(cx - 1.38, ht1 + 0.5)])
	K.line("q1", "pipe", "coolant", "RAD-T", Vector2(93.0, -3.2), "RAD-B", Vector2(93.0, 3.2), [Vector2(95.5, -3.2), Vector2(95.5, 3.2)])
	# the service propellant to the engines
	K.line("f1", "pipe", "fuel", "PROP-1", Vector2(78.5, -4.0), "ENG-1", Vector2(97.5, -4.2), [Vector2(79.0, -4.0), Vector2(79.0, -2.4), Vector2(96.0, -2.4), Vector2(96.0, -4.4), Vector2(97.5, -4.4)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-O", "port", K.at(15.5, _iy(OUT, 1, 15.5) - 0.25, ["hull"]), Vector2(15.5, _oy(1, 15.5) - 0.25), {"medium": "gas", "target": "O"})
	K.ctrl("G-U1", "port", by_tag["B1-1"], Vector2(B1 - 0.05, -3.4), {"medium": "gas", "target": "U1", "hidden_room": "O"})
	K.ctrl("G-S", "port", K.at(33.0, -8.55, ["hull"]), Vector2(33.0, -9.05), {"medium": "gas", "target": "S"})
	K.ctrl("G-L1", "port", K.at(32.0, _floor(32.0) + 0.25, ["hull"]), Vector2(32.0, _belly(32.0) + 0.25), {"medium": "gas", "target": "L1"})
	K.ctrl("G-C", "port", K.at(45.2, -8.55, ["hull"]), Vector2(45.2, -9.05), {"medium": "gas", "target": "C"})
	K.ctrl("G-Q", "port", K.at(68.0, -7.45, ["hull"]), Vector2(68.0, -7.95), {"medium": "gas", "target": "Q"})
	K.ctrl("G-U2", "port", K.at(71.45, -3.6, ["hull"]), Vector2(71.95, -3.6), {"medium": "gas", "target": "U2"})
	K.ctrl("G-L2", "port", K.at(57.0, _floor(57.0) + 0.25, ["hull"]), Vector2(57.0, _belly(57.0) + 0.25), {"medium": "gas", "target": "L2"})
	K.ctrl("G-M", "port", K.at(79.2, -2.85, ["hull"]), Vector2(79.2, -3.35), {"medium": "gas", "target": "M"})
	var px = K.equip("PNL-X", "panel", K.rect(39.0, _belly(43.0), 42.6, _belly(43.0) + 0.5), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(39.4, _belly(39.4) - 0.2, ["hull"]), 39.4, _belly(39.4))
	K.bolt(px, K.at(42.2, _belly(42.2) - 0.2, ["hull"]), 42.2, _belly(42.2))
	var py := _belly(43.0) + 0.25
	K.ctrl("K-M", "switch", px, Vector2(39.4, py), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(40.6, py), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(42.2, py), {"target": "aux", "state": false})
	for h in [["HT-O", ""], ["HT-S", ""], ["HT-C", ""], ["HT-Q", ""], ["HT-L1", ""], ["HT-L2", ""], ["HT-M", ""],
			["D-OU", "O"], ["D-SC", "C"], ["D-UC", "C"], ["D-LC", "C"], ["D-CQ", "C"], ["D-CU", "C"], ["D-CL", "C"], ["D-UM1", "U2"], ["D-UM2", "U2"]]:
		K.door(h[0], h[1])
	for i in 4:
		K.ctrl("ARM-%d" % (i + 1), "switch", by_tag["PODCP"], Vector2(46.6 + i * 0.4, 5.0), {"target": "ARM-%d" % (i + 1), "state": true, "hidden_room": "C"})
	K.ctrl("PP-1", "port", by_tag["PROP-1"], Vector2(75.0, -4.7), {"medium": "fuel", "target": "prop1"})
	K.ctrl("PP-2", "port", by_tag["PROP-2"], Vector2(75.0, 4.7), {"medium": "fuel", "target": "prop2"})
	K.ctrl("PC", "port", by_tag["RAD-T"], Vector2(87.0, -7.9), {"medium": "coolant", "target": "cool"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(OUT, i, x))
	var mi := K.inner(OUT_M, T)
	w.add_room("O", K.mp([Vector2(_ix(OUT, 11, D2), D2), inn[0], inn[1], at.call(1, B1), Vector2(B1, D2)]))
	w.add_room("S", K.mp([at.call(2, B1 + 0.4), inn[3], at.call(3, B2), Vector2(B2, D1), Vector2(B1 + 0.4, D1)]))
	w.add_room("U1", K.mp([Vector2(B1 + 0.4, D1 + 0.4), Vector2(B2, D1 + 0.4), Vector2(B2, D2), Vector2(B1 + 0.4, D2)]))
	w.add_room("L1", K.mp([Vector2(_ix(OUT, 11, D2 + 0.4), D2 + 0.4), Vector2(B2, D2 + 0.4), at.call(8, B2), inn[9], inn[10], inn[11]]))
	w.add_room("C", K.mp([at.call(3, B2 + 0.4), at.call(3, B3), at.call(8, B3), at.call(8, B2 + 0.4)]))
	w.add_room("Q", K.mp([at.call(3, B3 + 0.4), inn[4], inn[5], inn[6], Vector2(AFT, D1), Vector2(B3 + 0.4, D1)]))
	w.add_room("U2", K.mp([Vector2(B3 + 0.4, D1 + 0.4), Vector2(AFT, D1 + 0.4), Vector2(AFT, D2), Vector2(B3 + 0.4, D2)]))
	w.add_room("L2", K.mp([Vector2(B3 + 0.4, D2 + 0.4), Vector2(AFT, D2 + 0.4), inn[7], inn[8], at.call(8, B3 + 0.4)]))
	w.add_room("M", K.mp([mi[0], mi[1], mi[2], mi[3]]))


static func meta() -> Dictionary:
	var pods := {}
	var iso: Array = []
	for i in 4:
		var n := str(i + 1)
		pods["POD-" + n] = {"clamps": ["LC-%s1" % n, "LC-%s2" % n], "charge": "PYRO-" + n, "bolt": "PB-" + n, "circuit": "FCAP-" + n, "lead": "fc" + n, "kick": [0.0, 3.0]}
		iso.append({"piece": "FCAP-" + n, "volts": 28.0, "charge": 0.0, "switch": "ARM-" + n})
	var rooms := {"O": 101.0, "S": 101.0, "U1": 101.0, "L1": 101.0, "C": 101.0, "Q": 101.0, "U2": 101.0, "L2": 101.0, "M": 101.0}
	var mrooms := {}
	for r in rooms:
		mrooms[r] = [0.2, 40.0, 101.0]
	return {
		"id": "ps12",
		"name": "PS-12 DAWN",
		"title": ["PS-12「晨光」客运飞船 · 108 m", "PS-12 DAWN · PASSENGER LINER · 108 m"],
		"contract": "PS-12",
		"length": 108.0,
		"value": {"total": 408140.0, "metal": 50000.0},
		"clamps": [[27.0, _belly(27.0)], [45.0, _belly(45.0)], [60.0, _belly(60.0)]],
		"room_names": {"O": "room_psO", "S": "room_psS", "U1": "room_psU1", "L1": "room_psL1", "C": "room_psC", "Q": "room_psQ", "U2": "room_psU2", "L2": "room_psL2", "M": "room_psM"},
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 4000.0},
		"liner": {"pods": pods, "glazing": {"room": "O", "panes": ["OBS-1", "OBS-2", "OBS-3", "OBS-4"], "kpa": 20.0}},
		"power": {
			"bus": "MAIN-DIST",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			# each pod's firing circuit: dead unless a contract left it charged
			"isolated": iso,
			"lamps": {"O": "LAMP-O", "S": "LAMP-S", "U1": "LAMP-U1", "L1": "LAMP-L1", "C": "LAMP-C", "Q": "LAMP-Q", "U2": "LAMP-U2", "L2": "LAMP-L2", "M": "LAMP-M"},
		},
		"fluids": {"volumes": {
			"prop1": {"fluid": "fuel", "amount": 0.3, "piece": "PROP-1", "port": "PP-1", "full": 0.6, "content": 1.0, "leak": 0.1, "pump": [0.12, 0.008]},
			"prop2": {"fluid": "fuel", "amount": 0.3, "piece": "PROP-2", "port": "PP-2", "full": 0.6, "content": 1.0, "leak": 0.1, "pump": [0.12, 0.008]},
			"fuel_line": {"fluid": "fuel", "amount": 0.02, "nets": ["fuel"], "leak": 0.05, "leak_min": 0.005},
			"cool": {"fluid": "coolant", "amount": 0.3, "piece": "RAD-T", "port": "PC", "full": 0.3, "nets": ["coolant"], "leak": 0.2, "pump": [0.22, 0.006]},
		}, "joins": [{"a": "prop1", "b": "fuel_line", "valves": ["PP-1"], "mode": "fill", "cap": 0.02}], "value": {"fuel": 5000.0, "coolant": 1200.0}},
		"ctrls_cfg": {"G-O": {"rate": 40.0}, "G-U1": {"rate": 36.0}, "G-S": {"rate": 36.0}, "G-L1": {"rate": 60.0}, "G-C": {"rate": 40.0},
			"G-Q": {"rate": 26.0}, "G-U2": {"rate": 30.0}, "G-L2": {"rate": 34.0}, "G-M": {"rate": 40.0}},
		"labels": {"BAT": "BAT", "MAIN-DIST": "MAIN DIST", "AUX-BATT": "AUX BATT", "GEN-P": "STBY GEN", "HVAC": "HVAC", "VDR": "VDR", "LIFT": "LIFT",
			"POD-1": "POD 1", "POD-2": "POD 2", "POD-3": "POD 3", "POD-4": "POD 4", "PYRO-1": "PYRO", "PYRO-2": "PYRO", "PYRO-3": "PYRO", "PYRO-4": "PYRO", "PODCP": "POD CTRL"},
		"hints": {},
		"market": {
			"class": "PS", "name": ["晨光级客运飞船", "DAWN-CLASS PASSENGER LINER"], "time": 60.0,
			"rooms": mrooms,
			"charge": {"BAT": [0.3, 1.0]},
			"fluids": {"prop1": [0.1, 0.5], "prop2": [0.1, 0.5]}, "fill": {"fuel_line": "prop1"},
			"knockable": ["HELM", "CREW-ST"],
			"drift": [],
			"section_x": 31.0,
			"slots": {"hidden_damage": {"plates": ["HP2-0", "HP3-0", "HP3-4", "HP4-0"]},
				"fire_system": {"x": 59.0, "y0": _floor(59.8) - 1.4, "y1": _floor(59.8), "base": ["HP8-0", _floor(59.8)], "room": "L2", "port": [59.4, _floor(59.8) - 1.33]},
				"second_source": {"at": [64.2, _floor(66.2) - 1.8], "size": [2.0, 1.8], "base": [["HP7-2", 64.6, _floor(66.2)], ["HP7-2", 65.8, _floor(66.2)]], "room": "L2", "open_first": "L2",
					"bus": "MAIN-DIST", "path": [[65.2, _floor(66.2) - 1.8], [65.2, 1.6], [50.8, 1.6], [50.8, -5.4]], "switch_at": [64.6, _floor(66.2) - 1.2], "proc": "VDR", "test": "E-1", "volts": 230.0},
				"pod_armed": {"pods": ["POD-1", "POD-2", "POD-3", "POD-4"]}},
			"mechanisms": true,
		},
		"procedures": {
			"VDR": [
				{"do": "hose", "ctrl": "G-L2"},
				{"do": "wait", "until": {"P": ["L2", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-L2"},
				{"do": "wait", "until": {"open": ["L2"]}, "max": 5.0},
				{"do": "hose", "ctrl": "G-O"},
				{"do": "wait", "until": {"P": ["O", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-O"},
				{"do": "wait", "until": {"open": ["O"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "VDR"},
				{"do": "deliver", "piece": "VDR", "zone": "equip"},
			],
		},
	}
