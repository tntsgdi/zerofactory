class_name Fl116Author
# Authoring script for FL-116 "Tide", a 118 m process ship (R2 fleet,
# design/ships/全新舰队_R2_2026-10-18/FL-116_潮汐.md; lengths as drawn, heights at
# 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/fl116.json.
# Metres, x bow (0) to the nozzle (118), y down.
#
# The cockpit raised forward over its airlock, then the process hall: three big
# closed process tanks on saddles, a rigid separator tower over each on the roof,
# the pump bay under the hall's deck (a pump and a branch valve under each tank),
# and aft the control cabinet and the precision manifold where the three branches
# come out; the main engine on the stern.
# What it asks of you: three media in three tanks (a solvent, an acid, a glycol),
# their pipes all alike, and the branches cross on the way aft: manifold port one
# is not tank one. A sample point at each port reads what comes out there. Draw a
# branch off through its port with the other two branches' valves shut, or the
# media mix in the manifold into worthless waste with a disposal charge. Bleed the
# separators; take the manifold out only once every branch is empty, or the
# branches spill through it.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, -4.2), Vector2(5.0, -7.8), Vector2(10.0, -10.2), Vector2(23.0, -10.8), Vector2(26.0, -9.6), Vector2(28.0, -10.8),
	Vector2(77.0, -10.8), Vector2(91.0, -6.0), Vector2(98.0, -2.4), Vector2(102.0, -0.6), Vector2(102.0, 8.4), Vector2(96.0, 11.4),
	Vector2(86.0, 13.8), Vector2(27.0, 13.8), Vector2(6.0, 9.6), Vector2(0.0, 4.2)]
const F1 := 27.0                 # cockpit / airlock | the process hall (to 27.4)
const F2 := 83.6                 # the process hall | aft (to 84.0)
const CDECK := 3.0               # the cockpit deck (to 3.3), the airlock under it
const PDECK := 7.8               # the process deck (to 8.1), the pump bay under it
const ROOF := -10.35
const BELLY := 13.35
const TANKS := [36.0, 54.0, 72.0]   # each tank's (and tower's, pump's) middle
# the branches cross: tank n comes out at manifold port PORT_OF[n]
const PORT_OF := [2, 3, 1]
const FLUIDS := ["solvent", "acid", "glycol"]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "FL116")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	for i in 3:
		_tower(i)
		_tank(i)
	_cockpit()
	_airlock()
	_aft()
	_engine()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "FL116")
	w = world
	_rooms()


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	# the roof: a hatch into the hall between towers one and two
	K.ring(OUT, T, {
		2: [0.45, 0.65],
		5: [0.1, 0.2, 0.3, 0.367, 0.408, 0.5, 0.6, 0.7, 0.8, 0.9],
		7: [0.5],
		12: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.83, 0.88, 0.95],
		13: [0.3, 0.6],
	}, {
		"2:0": {"art": "window", "tag": "CAN-1"},
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(2.0, 0.1) * Geom.M, "cut_speed": 200.0},
		"5:4": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
		"7:0": {"kind": "hatch", "door": true, "tag": "HT-A", "open_dir": Vector2(-1.0, -1.2) * Geom.M, "cut_speed": 200.0},
		"12:4": {"kind": "hatch", "door": true, "tag": "HT-B", "open_dir": Vector2(2.4, 0) * Geom.M, "cut_speed": 200.0},
		"13:1": {"kind": "hatch", "door": true, "tag": "HT-L", "open_dir": Vector2(2.4, 0.4) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 220.0}, "HL")
	K.clamp(1, 34.0, 13.8, 13.6)
	K.clamp(2, 56.0, 13.8, 13.6)
	K.clamp(3, 78.0, 13.8, 13.6)


static func _inside() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	var f1 = K.plate("F1", K.R(F1, _iy(4, F1 + 0.2) - 0.1, F1 + 0.4, BELLY + 0.1), S, "bulkhead")
	K.bolt(f1, K.at(F1 + 0.2, _iy(4, F1 + 0.2) - 0.25, ["hull"]), F1 + 0.2, _iy(4, F1 + 0.2), "weld")
	K.bolt(f1, K.at(F1 + 0.2, BELLY + 0.25, ["hull"]), F1 + 0.2, BELLY, "weld")
	var f2 = K.plate("F2", K.R(F2, _iy(6, F2 + 0.2) - 0.1, F2 + 0.4, BELLY + 0.1), S, "bulkhead")
	K.bolt(f2, K.at(F2 + 0.2, _iy(6, F2 + 0.2) - 0.25, ["hull"]), F2 + 0.2, _iy(6, F2 + 0.2), "weld")
	K.bolt(f2, K.at(F2 + 0.2, BELLY + 0.25, ["hull"]), F2 + 0.2, BELLY, "weld")
	var pd = K.plate("PDECK", K.R(F1 + 0.4, PDECK, F2, PDECK + 0.3), {"density": 1.2, "barrier": true, "cut_speed": 220.0}, "deck")
	K.bolt(pd, f1, F1 + 0.4, PDECK + 0.15, "weld")
	K.bolt(pd, f2, F2, PDECK + 0.15, "weld")
	var cd = K.plate("CDECK", K.R(0.45, CDECK, F1, CDECK + 0.3), {"density": 1.0, "barrier": true, "cut_speed": 220.0}, "deck")
	K.bolt(cd, K.at(0.25, CDECK + 0.15, ["hull"]), 0.45, CDECK + 0.15, "weld")
	K.bolt(cd, f1, F1, CDECK + 0.15, "weld")


# ---------------------------------------------------------------- a separator tower on the roof

static func _tower(i: int) -> void:
	var n := str(i + 1)
	var x0: float = TANKS[i] - 5.0
	var S := {"density": 1.3, "barrier": true, "cut_speed": 200.0}
	var fw = K.plate("T%s-F" % n, K.R(x0, -16.2, x0 + 0.4, -10.8), S)
	var fs = K.plate("T%s-FS" % n, K.mp([Vector2(x0, -16.2), Vector2(x0 + 2.0, -18.0), Vector2(x0 + 2.3, -17.6), Vector2(x0 + 0.4, -15.9)]), S)
	var t1 = K.plate("T%s-R1" % n, K.R(x0 + 2.0, -18.0, x0 + 4.0, -17.6), S)
	var hh = K.plate("HT-T" + n, K.R(x0 + 4.0, -18.0, x0 + 6.0, -17.6), {"density": 1.0, "door": true, "open_dir": Vector2(2.0, 0) * Geom.M, "cut_speed": 190.0}, "hatch")
	var t2 = K.plate("T%s-R2" % n, K.R(x0 + 6.0, -18.0, x0 + 8.0, -17.6), S)
	var as_ = K.plate("T%s-AS" % n, K.mp([Vector2(x0 + 8.0, -18.0), Vector2(x0 + 10.0, -16.2), Vector2(x0 + 9.6, -15.9), Vector2(x0 + 7.7, -17.6)]), S)
	var aw = K.plate("T%s-A" % n, K.R(x0 + 9.6, -16.2, x0 + 10.0, -10.8), S)
	K.bolt(fw, K.at(x0 + 0.2, -10.6, ["hull"]), x0 + 0.2, -10.8, "weld")
	K.bolt(aw, K.at(x0 + 9.8, -10.6, ["hull"]), x0 + 9.8, -10.8, "weld")
	K.bolt(fs, fw, x0 + 0.2, -16.1, "weld")
	K.bolt(fs, t1, x0 + 2.1, -17.8, "weld")
	K.bolt(hh, t1, x0 + 4.0, -17.8, "weld")
	K.bolt(hh, t2, x0 + 6.0, -17.8, "weld")
	K.bolt(as_, t2, x0 + 7.9, -17.8, "weld")
	K.bolt(as_, aw, x0 + 9.8, -16.1, "weld")
	var sp = K.equip("SEP-" + n, "fueltank", K.rect(x0 + 0.4, -15.4, x0 + 9.6, -11.6), {"mass": 1.6, "value": 7000.0, "fragile": 0.3, "room": "T" + n, "hazard": "gas_tank", "name_key": "p_separator"})
	K.bolt(sp, fw, x0 + 0.4, -13.5)
	K.bolt(sp, aw, x0 + 9.6, -13.5)
	K.lamp("LAMP-T" + n, x0 + 3.0, -17.6, "T" + n, t1)


# ---------------------------------------------------------------- a process tank, its pump

static func _tank(i: int) -> void:
	var n := str(i + 1)
	var xm: float = TANKS[i]
	var pd = by_tag["PDECK"]
	var saddles: Array = []
	for sx in [xm - 4.6, xm + 4.2]:
		var sd = K.plate("", K.R(sx, 5.4, sx + 0.4, PDECK), {"density": 1.4, "barrier": false, "cut_speed": 160.0}, "strut")
		K.bolt(sd, pd, sx + 0.2, PDECK, "weld")
		saddles.append(sd)
	var tk = K.equip("TK-" + n, "fueltank", K.rect(xm - 7.0, -6.0, xm + 7.0, 5.4), {"mass": 4.6, "value": 8000.0, "fragile": 0.25, "room": "P", "hazard": "fuel_tank" if FLUIDS[i] == "solvent" else "",
		"name_key": "p_process_tank"})
	K.bolt(tk, saddles[0], xm - 4.4, 5.4)
	K.bolt(tk, saddles[1], xm + 4.4, 5.4)
	var pm = K.equip("PM-" + n, "pump", K.rect(xm - 1.8, 9.8, xm + 1.8, BELLY), {"mass": 0.8, "value": 4500.0, "fragile": 0.35, "room": "B", "name_key": "p_process_pump"})
	K.bolt(pm, K.at(xm - 1.2, BELLY + 0.25, ["hull"]), xm - 1.2, BELLY)
	K.bolt(pm, K.at(xm + 1.2, BELLY + 0.25, ["hull"]), xm + 1.2, BELLY)


# ---------------------------------------------------------------- the cockpit

static func _cockpit() -> void:
	var dk = by_tag["CDECK"]
	var nav = K.equip("NAV", "nav", K.rect(1.0, 0.8, 5.6, CDECK), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "room": "C", "name_key": "p_nav"})
	K.bolt(nav, dk, 1.8, CDECK)
	K.bolt(nav, dk, 5.0, CDECK)
	for i in 2:
		var sx := 7.6 + i * 2.6
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, CDECK - 1.5, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
		K.bolt(st, dk, sx + 0.2, CDECK)
		K.bolt(st, dk, sx + 0.6, CDECK, "lock")
	var cn = K.equip("CON", "console", K.rect(14.0, 1.2, 19.0, CDECK), {"mass": 0.35, "value": 4500.0, "fragile": 0.5, "room": "C", "name_key": "p_process_console"})
	K.bolt(cn, dk, 14.6, CDECK)
	K.bolt(cn, dk, 18.4, CDECK)
	var lg = K.equip("BATCHLOG", "cabinet", K.rect(23.6, 0.0, F1, CDECK), {"mass": 0.3, "value": 7500.0, "fragile": 0.5, "room": "C", "mandatory": true, "name_key": "p_batch_log"})
	K.bolt(lg, dk, 24.2, CDECK)
	K.bolt(lg, by_tag["F1"], F1, 1.0, "lock")
	K.lamp("LAMP-C", 13.0, _iy(2, 13.0), "C", K.at(13.0, _iy(2, 13.0) - 0.2, ["hull"]))


static func _airlock() -> void:
	var dk = by_tag["CDECK"]
	var bt = K.equip("BAT", "battery", K.rect(21.0, 10.2, F1, 12.1), {"mass": 1.2, "value": 6500.0, "fragile": 0.4, "room": "L", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(21.6, _iy(13, 21.6) + 0.25, ["hull"]), 21.6, _iy(13, 21.6))
	K.bolt(bt, by_tag["F1"], F1, 11.2)
	var sw = K.equip("SWB", "swb", K.rect(14.0, CDECK + 0.3, 16.4, 6.0), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "L", "name_key": "p_swb"})
	K.bolt(sw, dk, 14.6, CDECK + 0.3)
	K.bolt(sw, dk, 15.8, CDECK + 0.3)
	K.lamp("LAMP-L", 10.0, CDECK + 0.3, "L", dk)


# ---------------------------------------------------------------- aft: the control cabinet and the manifold

static func _aft() -> void:
	var f2 = by_tag["F2"]
	var ct = K.equip("CTL", "nav_rack", K.rect(F2 + 0.4, -4.0, 90.4, 4.0), {"mass": 0.9, "value": 8000.0, "fragile": 0.45, "room": "A", "name_key": "p_process_cabinet"})
	K.bolt(ct, f2, F2 + 0.4, -3.0)
	K.bolt(ct, f2, F2 + 0.4, 3.0)
	var mf = K.equip("MANIFOLD", "swb", K.rect(F2 + 0.4, 7.0, 93.4, 11.6), {"mass": 1.4, "value": 14000.0, "fragile": 0.5, "room": "A", "name_key": "p_manifold"})
	K.bolt(mf, f2, F2 + 0.4, 8.0)
	K.bolt(mf, f2, F2 + 0.4, 10.6)
	K.lamp("LAMP-A", 95.6, _iy(7, 95.6), "A", K.at(95.6, _iy(7, 95.6) - 0.2, ["hull"]))
	K.lamp("LAMP-B", 46.0, PDECK + 0.3, "B", by_tag["PDECK"])
	K.lamp("LAMP-P", 45.0, ROOF, "P", K.at(45.0, ROOF - 0.2, ["hull"]))


static func _engine() -> void:
	var en = K.equip("ENG", "eng_core", K.rect(102.0, 0.0, 112.0, 7.8), {"mass": 4.6, "value": 18000.0, "fragile": 0.3, "name_key": "p_engine_big"})
	K.bolt(en, K.at(101.75, 1.2, ["hull"]), 102.0, 1.2)
	K.bolt(en, K.at(101.75, 6.6, ["hull"]), 102.0, 6.6)
	var nz = K.equip("NOZ", "nozzle", K.rect(112.0, -0.8, 118.0, 8.6), {"cls": "metal", "dest": "metal", "mass": 0.8, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(112.0, 0.8), Vector2(118.0, -0.8), Vector2(118.0, 8.6), Vector2(112.0, 7.0)]))
	K.bolt(nz, en, 112.0, 2.0)
	K.bolt(nz, en, 112.0, 5.8)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(21.4, 10.2), "SWB", Vector2(16.0, 6.0), [Vector2(21.4, 7.0), Vector2(16.0, 7.0)])
	K.line("p2", "cable", "power", "SWB", Vector2(14.4, CDECK + 0.3), "CON", Vector2(15.0, CDECK), [Vector2(14.4, CDECK + 0.2), Vector2(15.0, CDECK + 0.2)])
	K.line("p3", "cable", "power", "CON", Vector2(14.0, 2.0), "NAV", Vector2(5.6, 2.0))
	K.line("p4", "cable", "power", "CON", Vector2(19.0, 2.0), "BATCHLOG", Vector2(23.6, 2.0))
	K.line("p5", "cable", "power", "CON", Vector2(17.0, 1.2), "LAMP-C", Vector2(13.0, _iy(2, 13.0) + 0.16), [Vector2(17.0, -6.0), Vector2(13.0, -6.0)])
	K.line("p6", "cable", "power", "SWB", Vector2(14.0, 4.6), "LAMP-L", Vector2(10.0, CDECK + 0.46), [Vector2(10.0, 4.6)])
	# aft under the process deck: the pumps, the cabinet; the hall's and the towers' lamps off the cabinet
	K.line("p7", "cable", "power", "SWB", Vector2(16.4, 5.4), "PM-1", Vector2(34.6, 9.8), [Vector2(26.6, 5.4), Vector2(26.6, 8.4), Vector2(34.6, 8.4)])
	K.line("p8", "cable", "power", "PM-1", Vector2(37.4, 9.8), "PM-2", Vector2(52.6, 9.8), [Vector2(37.4, 8.5), Vector2(52.6, 8.5)])
	K.line("p9", "cable", "power", "PM-2", Vector2(55.4, 9.8), "PM-3", Vector2(70.6, 9.8), [Vector2(55.4, 8.5), Vector2(70.6, 8.5)])
	K.line("p10", "cable", "power", "PM-3", Vector2(73.4, 9.8), "CTL", Vector2(86.0, 4.0), [Vector2(73.4, 8.5), Vector2(83.0, 8.5), Vector2(83.0, 5.0), Vector2(86.0, 5.0)])
	K.line("p11", "cable", "power", "CTL", Vector2(89.0, -4.0), "LAMP-A", Vector2(95.6, _iy(7, 95.6) + 0.16), [Vector2(89.0, -4.6), Vector2(95.6, -4.6)])
	K.line("p12", "cable", "power", "PM-1", Vector2(35.0, 9.8), "LAMP-B", Vector2(46.0, PDECK + 0.46), [Vector2(35.0, 8.6), Vector2(46.0, 8.6)])
	K.line("p13", "cable", "power", "CTL", Vector2(84.6, -4.0), "LAMP-P", Vector2(45.0, ROOF + 0.16), [Vector2(84.6, -7.6), Vector2(83.2, -7.6), Vector2(83.2, -9.95), Vector2(45.0, -9.95)])
	for i in 3:
		var x0: float = TANKS[i] - 5.0
		K.line("pt%d" % (i + 1), "cable", "power", "LAMP-P", Vector2(45.2, ROOF + 0.16), "LAMP-T%d" % (i + 1), Vector2(x0 + 3.0, -17.44),
			[Vector2(45.2, -10.0), Vector2(x0 + 1.0, -10.0), Vector2(x0 + 1.0, -17.2), Vector2(x0 + 3.0, -17.2)])
	# each branch: the separator down into its tank, the tank down to its pump, the pump aft to its port
	for i in 3:
		var n := i + 1
		var xm: float = TANKS[i]
		var net := "m%d" % n
		K.line("s%d" % n, "pipe", net, "SEP-%d" % n, Vector2(xm, -11.6), "TK-%d" % n, Vector2(xm, -6.0))
		K.line("d%d" % n, "pipe", net, "TK-%d" % n, Vector2(xm + 0.6, 5.4), "PM-%d" % n, Vector2(xm + 0.6, 9.8))
		var port: int = PORT_OF[i]
		var px := 85.0 + (port - 1) * 3.0
		var ly := 8.9 + i * 0.35
		K.line("b%d" % n, "pipe", net, "PM-%d" % n, Vector2(xm + 1.8, 10.6), "MANIFOLD", Vector2(px, 7.0),
			[Vector2(xm + 2.4, 10.6), Vector2(xm + 2.4, ly), Vector2(82.6 + i * 0.3, ly), Vector2(82.6 + i * 0.3, 6.4), Vector2(px, 6.4)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-C", "port", K.at(20.0, _iy(2, 20.0) - 0.2, ["hull"]), Vector2(20.0, _iy(2, 20.0) - 0.75), {"medium": "gas", "target": "C"})
	K.ctrl("G-L", "port", K.at(14.0, _iy(13, 14.0) + 0.25, ["hull"]), Vector2(14.0, _iy(13, 14.0) + 0.6), {"medium": "gas", "target": "L"})
	K.ctrl("G-P", "port", K.at(63.0, ROOF - 0.2, ["hull"]), Vector2(63.0, -11.05), {"medium": "gas", "target": "P"})
	K.ctrl("G-B", "port", K.at(66.0, BELLY + 0.25, ["hull"]), Vector2(66.0, 14.05), {"medium": "gas", "target": "B"})
	K.ctrl("G-A", "port", K.at(97.0, _iy(7, 97.0) - 0.2, ["hull"]), Vector2(97.15, _iy(7, 97.0) - 0.6), {"medium": "gas", "target": "A"})
	for i in 3:
		var n := str(i + 1)
		var x0: float = TANKS[i] - 5.0
		K.ctrl("G-T" + n, "port", by_tag["T%s-R2" % n], Vector2(x0 + 7.0, -18.15), {"medium": "gas", "target": "T" + n})
		K.ctrl("PS-" + n, "port", by_tag["SEP-" + n], Vector2(x0 + 5.0, -11.8), {"medium": "gas", "target": "SV" + n, "hidden_room": "T" + n})
		K.door("HT-T" + n, "")
		# each branch's valve on its pump
		K.ctrl("V-" + n, "valve", by_tag["PM-" + n], Vector2(TANKS[i], 11.0), {"target": "V-" + n, "state": true, "hidden_room": "B"})
	# the manifold's three ports and their sample points
	for k in 3:
		var px := 85.0 + k * 3.0
		K.ctrl("MP-%d" % (k + 1), "port", by_tag["MANIFOLD"], Vector2(px + 0.6, 7.3), {"medium": "process", "target": "", "hidden_room": "A"})
		K.ctrl("SP-%d" % (k + 1), "probe", by_tag["MANIFOLD"], Vector2(px + 1.4, 7.3), {"medium": "sample", "target": "", "hidden_room": "A"})
	# the outside panel under the airlock
	var px2 = K.equip("PNL-X", "panel", K.rect(29.0, 13.8, 32.6, 14.3), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px2, K.at(29.4, 13.6, ["hull"]), 29.4, 13.8)
	K.bolt(px2, K.at(32.2, 13.6, ["hull"]), 32.2, 13.8)
	K.ctrl("K-M", "switch", px2, Vector2(29.4, 14.05), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px2, Vector2(30.6, 14.05), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px2, Vector2(32.2, 14.05), {"target": "aux", "state": false})
	for h in [["HT-C", ""], ["HT-P", ""], ["HT-A", ""], ["HT-B", ""], ["HT-L", ""]]:
		K.door(h[0], h[1])


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	var bow := func(y: float) -> Vector2: return Vector2(0.45, y)
	w.add_room("C", K.mp([bow.call(CDECK), inn[0], inn[1], inn[2], inn[3], inn[4], at.call(4, F1), Vector2(F1, CDECK)]))
	w.add_room("L", K.mp([bow.call(CDECK + 0.3), Vector2(F1, CDECK + 0.3), Vector2(F1, BELLY), inn[14], inn[15]]))
	w.add_room("P", K.mp([at.call(4, F1 + 0.4), inn[5], inn[6], at.call(6, F2), Vector2(F2, PDECK), Vector2(F1 + 0.4, PDECK)]))
	w.add_room("B", K.mp([Vector2(F1 + 0.4, PDECK + 0.3), Vector2(F2, PDECK + 0.3), Vector2(F2, BELLY), Vector2(F1 + 0.4, BELLY)]))
	w.add_room("A", K.mp([at.call(6, F2 + 0.4), inn[7], inn[8], inn[9], inn[10], inn[11], inn[12], Vector2(F2 + 0.4, BELLY)]))
	for i in 3:
		var x0: float = TANKS[i] - 5.0
		w.add_room("T%d" % (i + 1), K.mp([Vector2(x0 + 0.4, -10.8), Vector2(x0 + 0.4, -15.9), Vector2(x0 + 2.3, -17.6), Vector2(x0 + 7.7, -17.6), Vector2(x0 + 9.6, -15.9), Vector2(x0 + 9.6, -10.8)]))


static func meta() -> Dictionary:
	var vessels := {}
	var vols := {}
	var branches := {}
	var labels := {"BAT": "BAT", "SWB": "SWB", "MANIFOLD": "MANIFOLD", "BATCHLOG": "BATCH LOG", "CTL": "CONTROL"}
	for i in 3:
		var n := str(i + 1)
		vessels["SV" + n] = {"V": 0.3, "kpa": 640.0, "piece": "SEP-" + n, "burst": 200.0}
		vols["t" + n] = {"fluid": FLUIDS[i], "amount": 1.5, "piece": "TK-" + n, "content": 1.5, "leak": 0.12, "port": "MP-%d" % PORT_OF[i], "pump": [0.14, 0.01], "hazard": 0.03 if FLUIDS[i] == "solvent" else 0.0}
		vols["l" + n] = {"fluid": FLUIDS[i], "amount": 0.02, "nets": ["m" + n], "leak": 0.06, "leak_min": 0.004}
		branches[n] = {"vol": "t" + n, "valve": "V-" + n, "port": "MP-%d" % PORT_OF[i], "sample": "SP-%d" % PORT_OF[i]}
		labels["TK-" + n] = "PROCESS %s" % n
		labels["SEP-" + n] = "S%s" % n
	return {
		"id": "fl116",
		"name": "FL-116 TIDE",
		"title": ["FL-116「潮汐」工艺船 · 118 m", "FL-116 TIDE · PROCESS SHIP · 118 m"],
		"contract": "FL-116",
		"length": 118.0,
		"value": {"total": 180000.0, "metal": 36000.0},
		"clamps": [[34.0, 13.8], [56.0, 13.8], [78.0, 13.8]],
		"room_names": {"C": "room_flC", "L": "room_flL", "P": "room_flP", "B": "room_flB", "A": "room_flA", "T1": "room_flT", "T2": "room_flT", "T3": "room_flT"},
		"gas": {"rooms": {"C": 101.0, "L": 101.0, "P": 101.0, "B": 101.0, "A": 101.0, "T1": 101.0, "T2": 101.0, "T3": 101.0}, "vessels": vessels, "valves": [], "value": 2400.0},
		"media": {"branches": branches, "manifold": "MANIFOLD"},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "L": "LAMP-L", "P": "LAMP-P", "B": "LAMP-B", "A": "LAMP-A", "T1": "LAMP-T1", "T2": "LAMP-T2", "T3": "LAMP-T3"},
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"solvent": 3200.0, "acid": 2600.0, "glycol": 2800.0}},
		"ctrls_cfg": {"G-C": {"rate": 30.0}, "G-L": {"rate": 22.0}, "G-P": {"rate": 48.0}, "G-B": {"rate": 22.0}, "G-A": {"rate": 22.0},
			"G-T1": {"rate": 6.0}, "G-T2": {"rate": 6.0}, "G-T3": {"rate": 6.0}, "PS-1": {"rate": 0.6}, "PS-2": {"rate": 0.6}, "PS-3": {"rate": 0.6}},
		"labels": labels,
		"hints": {},
		"market": {
			"class": "FL", "name": ["潮汐级工艺船", "TIDE-CLASS PROCESS SHIP"], "time": 44.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "L": [0.2, 40.0, 101.0], "B": [0.2, 40.0, 101.0], "A": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"t1": [0.3, 1.5], "t2": [0.3, 1.5], "t3": [0.3, 1.5]}, "fill": {"l1": "t1", "l2": "t2", "l3": "t3"},
			"knockable": ["NAV", "CON", "CTL"],
			"drift": [],
			"section_x": 63.0,
			"slots": {"hidden_damage": {"plates": ["HL12-1", "HL12-3", "HL12-5", "HL5-7"]}, "fire_system": {"x": 45.0, "y0": 11.6, "y1": 13.35, "base": ["HL12-6", 13.35], "room": "B", "port": [45.4, 11.67]}},
			"mechanisms": true,
		},
		"procedures": {
			"BATCHLOG": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "BATCHLOG"},
				{"do": "deliver", "piece": "BATCHLOG", "zone": "equip"},
			],
		},
	}
