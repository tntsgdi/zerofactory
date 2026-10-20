class_name Cl104Author
# Authoring script for CL-104 "Frost Store", a 107 m zoned cold-chain carrier (R2
# fleet, design/ships/全新舰队_R2_2026-10-18/CL-104_霜仓.md; lengths as drawn,
# heights at 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/cl104.json.
# Metres, x bow (0) to the nozzle (107), y down.
#
# The cockpit raised forward over its buffer airlock, then three thick-walled
# insulated cold holds standing in a vacuum-insulated hull, each with six pallets
# on two shelves and its floor, an evaporator on its wall, its own chiller under
# it in the keel bay; the refrigeration plant aft behind its bulkhead; a power
# section that comes off the stern whole on four separation bolts.
# What it asks of you: the holds are kept at -25 °C by their chillers and the
# plant, on the ship's own power. Plug the berth's temporary cooling into the
# outside panel before the power goes off (or the refrigeration is cut into), or
# the holds warm, and at -5 °C a hold's pallets have thawed: less than half their
# value, for good. A temperature probe on each hold reads it. Vent each hold
# through its own port before its roof hatch opens; recover the refrigerant.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, -4.2), Vector2(5.0, -7.2), Vector2(9.0, -9.6), Vector2(20.0, -10.8), Vector2(23.0, -8.4), Vector2(27.0, -10.8),
	Vector2(82.0, -10.8), Vector2(91.0, -7.2), Vector2(94.0, -0.6), Vector2(94.0, 7.8), Vector2(83.0, 10.2), Vector2(15.0, 10.2),
	Vector2(4.0, 6.6), Vector2(0.0, 4.2)]
const F1 := 24.6                 # cockpit / airlock | the holds (to 25.0)
const F2 := 85.6                 # the holds | the plant (to 86.0)
const CDECK := 2.4               # the cockpit deck (to 2.7), the airlock under it
const KDECK := 7.2               # the holds' deck (to 7.5), the keel bay under it
const BELLY := 9.75
const PODS := [27.0, 46.0, 65.0] # each hold's forward wall; 17.6 m long
const PW := 17.6
const WALL := 0.8                # insulated walls
const PTOP := -10.0              # a hold's roof (its inside from -9.2)
const PFLOOR := 6.4              # a hold's floor (to 7.2, on the deck)

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "CL104")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	for i in 3:
		_hold(i)
	_cockpit()
	_airlock()
	_plant()
	_tail()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "CL104")
	w = world
	_rooms()


# the cockpit deck plate under x
static func _deck(x: float):
	return K.at(x, CDECK + 0.15, ["deck"])


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	var roof: Array = []
	for x0 in PODS:
		roof.append((x0 + 5.4 - 27.0) / 55.0)
		roof.append((x0 + 12.2 - 27.0) / 55.0)
	var sp := {
		"1:0": {"art": "window", "tag": "CAN-1"},
		"2:0": {"art": "window", "tag": "CAN-2"},
		"7:0": {"kind": "hatch", "door": true, "tag": "HT-R", "open_dir": Vector2(-0.8, -1.4) * Geom.M, "cut_speed": 200.0},
		"10:10": {"kind": "hatch", "door": true, "tag": "HT-A", "open_dir": Vector2(-2.0, 0) * Geom.M, "cut_speed": 200.0},
	}
	for i in 3:
		sp["5:%d" % (2 * i + 1)] = {"kind": "hatch", "door": true, "tag": "HR-%d" % (i + 1), "open_dir": Vector2(0, -1.2) * Geom.M, "cut_speed": 200.0}
	K.ring(OUT, T, {
		2: [0.6],
		5: roof,
		10: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.89, 0.93],
	}, sp, {"density": 1.5, "barrier": true, "cut_speed": 220.0}, "HL")
	K.clamp(1, 32.0, 10.2, 10.0)
	K.clamp(2, 55.0, 10.2, 10.0)
	K.clamp(3, 76.0, 10.2, 10.0)


static func _inside() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	var f1 = K.plate("F1", K.R(F1, _iy(4, F1 + 0.2) - 0.1, F1 + 0.4, BELLY + 0.1), S, "bulkhead")
	K.bolt(f1, K.at(F1 + 0.2, _iy(4, F1 + 0.2) - 0.25, ["hull"]), F1 + 0.2, _iy(4, F1 + 0.2), "weld")
	K.bolt(f1, K.at(F1 + 0.2, BELLY + 0.25, ["hull"]), F1 + 0.2, BELLY, "weld")
	var f2 = K.plate("F2", K.R(F2, _iy(6, F2 + 0.2) - 0.1, F2 + 0.4, _iy(9, F2 + 0.2) + 0.1), S, "bulkhead")
	K.bolt(f2, K.at(F2 + 0.2, _iy(6, F2 + 0.2) - 0.25, ["hull"]), F2 + 0.2, _iy(6, F2 + 0.2), "weld")
	K.bolt(f2, K.at(F2 + 0.2, _iy(9, F2 + 0.2) + 0.25, ["hull"]), F2 + 0.2, _iy(9, F2 + 0.2), "weld")
	var kd = K.plate("KDECK", K.R(F1 + 0.4, KDECK, F2, KDECK + 0.3), {"density": 1.2, "barrier": false, "cut_speed": 220.0}, "deck")
	K.bolt(kd, f1, F1 + 0.4, KDECK + 0.15, "weld")
	K.bolt(kd, f2, F2, KDECK + 0.15, "weld")
	# posts from the deck down to the belly between the holds
	for px in [45.0, 64.0]:
		var po = K.plate("", K.R(px, KDECK + 0.3, px + 0.4, BELLY), {"density": 1.0, "barrier": false, "cut_speed": 200.0}, "strut")
		K.bolt(po, kd, px + 0.2, KDECK + 0.3, "weld")
		K.bolt(po, K.at(px + 0.2, BELLY + 0.25, ["hull"]), px + 0.2, BELLY, "weld")
	# the cockpit deck, the hatch through it from the airlock below
	var D := {"density": 1.0, "barrier": true, "cut_speed": 220.0}
	var c1 = K.plate("CD-1", K.R(0.45, CDECK, 12.0, CDECK + 0.3), D, "deck")
	var dh = K.plate("DK-H", K.R(12.0, CDECK, 13.8, CDECK + 0.3), {"density": 1.0, "door": true, "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 200.0}, "hatch")
	var c2 = K.plate("CD-2", K.R(13.8, CDECK, F1, CDECK + 0.3), D, "deck")
	K.bolt(c1, K.at(0.25, CDECK + 0.15, ["hull"]), 0.45, CDECK + 0.15, "weld")
	K.bolt(c2, f1, F1, CDECK + 0.15, "weld")
	K.bolt(dh, c1, 12.0, CDECK + 0.15, "weld")
	K.bolt(dh, c2, 13.8, CDECK + 0.15, "weld")


# ---------------------------------------------------------------- a cold hold

static func _hold(i: int) -> void:
	var n := str(i + 1)
	var x0: float = PODS[i]
	var x1: float = x0 + PW
	var xm := x0 + PW * 0.5
	var IW := {"density": 1.1, "barrier": true, "cut_speed": 110.0, "art": "insul", "name_key": "p_hold_wall"}
	var lw = K.plate("K%s-WF" % n, K.R(x0, PTOP + WALL, x0 + WALL, PFLOOR), IW)
	var rw = K.plate("K%s-WA" % n, K.R(x1 - WALL, PTOP + WALL, x1, PFLOOR), IW)
	var fl = K.plate("K%s-FL" % n, K.R(x0, PFLOOR, x1, KDECK), IW)
	var ra = K.plate("K%s-RF" % n, K.R(x0, PTOP, xm - 3.4, PTOP + WALL), IW)
	var hh = K.plate("PH-%s" % n, K.R(xm - 3.4, PTOP, xm + 3.4, PTOP + WALL), {"density": 1.0, "door": true, "open_dir": Vector2(0, -0.7) * Geom.M + Vector2(7.2, 0) * Geom.M, "cut_speed": 120.0, "art": "insul"}, "hatch")
	var rb = K.plate("K%s-RA" % n, K.R(xm + 3.4, PTOP, x1, PTOP + WALL), IW)
	K.bolt(lw, fl, x0 + 0.4, PFLOOR, "weld")
	K.bolt(rw, fl, x1 - 0.4, PFLOOR, "weld")
	K.bolt(ra, lw, x0 + 0.4, PTOP + WALL, "weld")
	K.bolt(rb, rw, x1 - 0.4, PTOP + WALL, "weld")
	K.bolt(hh, ra, xm - 3.4, PTOP + 0.4, "weld")
	K.bolt(hh, rb, xm + 3.4, PTOP + 0.4, "weld")
	# the hold stands bolted to the deck
	for bx in [x0 + 1.0, xm, x1 - 1.0]:
		K.bolt(fl, by_tag["KDECK"], bx, KDECK)
	# two shelves across it, six pallets
	var shelves: Array = []
	for sy in [1.0, -4.4]:
		var sh = K.plate("", K.R(x0 + WALL, sy, x1 - WALL, sy + 0.2), {"density": 1.0, "barrier": false, "cut_speed": 190.0}, "rail")
		K.bolt(sh, lw, x0 + WALL, sy + 0.1, "weld")
		K.bolt(sh, rw, x1 - WALL, sy + 0.1, "weld")
		shelves.append(sh)
	var rows := [[fl, PFLOOR], [shelves[0], 1.0], [shelves[1], -4.4]]
	var k := 0
	for row in rows:
		for c in 2:
			k += 1
			var cx := x0 + 1.4 + c * 8.2
			var pl = K.equip("PAL-%s%d" % [n, k], "cargo", K.rect(cx, row[1] - 2.4, cx + 6.0, row[1]), {"mass": 1.1, "value": 4800.0, "fragile": 0.35, "room": "K" + n, "name_key": "p_cold_pallet"})
			K.bolt(pl, row[0], cx + 1.0, row[1], "lock")
			K.bolt(pl, row[0], cx + 5.0, row[1], "lock")
	# the evaporator on its aft wall
	var ev = K.equip("EV-" + n, "radiator", K.rect(x1 - 1.9, -8.8, x1 - WALL, -5.0), {"mass": 0.4, "value": 2600.0, "fragile": 0.4, "room": "K" + n, "name_key": "p_evaporator"})
	K.bolt(ev, rw, x1 - WALL, -8.0)
	K.bolt(ev, rw, x1 - WALL, -5.8)
	K.lamp("LAMP-K" + n, x0 + 3.0, PTOP + WALL, "K" + n, ra)
	# its chiller under it in the keel bay
	var ch = K.equip("CH-" + n, "pump", K.rect(xm - 1.6, KDECK + 0.3, xm + 1.6, BELLY), {"mass": 0.9, "value": 5200.0, "fragile": 0.35, "name_key": "p_chiller"})
	K.bolt(ch, by_tag["KDECK"], xm - 1.0, KDECK + 0.3)
	K.bolt(ch, K.at(xm + 1.0, BELLY + 0.25, ["hull"]), xm + 1.0, BELLY)


# ---------------------------------------------------------------- the cockpit

static func _cockpit() -> void:
	var nav = K.equip("NAV", "nav", K.rect(1.2, 0.4, 5.6, CDECK), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "room": "C", "name_key": "p_nav"})
	K.bolt(nav, _deck(2.0), 2.0, CDECK)
	K.bolt(nav, _deck(5.0), 5.0, CDECK)
	for i in 2:
		var sx := 7.4 + i * 2.6
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, CDECK - 1.5, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
		K.bolt(st, _deck(sx + 0.2), sx + 0.2, CDECK)
		K.bolt(st, _deck(sx + 0.6), sx + 0.6, CDECK, "lock")
	var cn = K.equip("CON", "console", K.rect(14.0, 0.8, 18.0, CDECK), {"mass": 0.3, "value": 4000.0, "fragile": 0.5, "room": "C", "name_key": "p_cold_console"})
	K.bolt(cn, _deck(14.6), 14.6, CDECK)
	K.bolt(cn, _deck(17.4), 17.4, CDECK)
	var mf = K.equip("MANIFEST", "cabinet", K.rect(21.2, -0.6, F1, CDECK), {"mass": 0.3, "value": 7000.0, "fragile": 0.5, "room": "C", "mandatory": true, "name_key": "p_manifest"})
	K.bolt(mf, _deck(21.8), 21.8, CDECK)
	K.bolt(mf, by_tag["F1"], F1, 0.4, "lock")
	K.lamp("LAMP-C", 15.0, _iy(2, 15.0), "C", K.at(15.0, _iy(2, 15.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the buffer airlock under the cockpit deck

static func _airlock() -> void:
	var bt = K.equip("BAT", "battery", K.rect(18.4, 7.6, 24.2, BELLY), {"mass": 1.4, "value": 7000.0, "fragile": 0.4, "room": "A", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(19.0, BELLY + 0.25, ["hull"]), 19.0, BELLY)
	K.bolt(bt, K.at(23.6, BELLY + 0.25, ["hull"]), 23.6, BELLY)
	var sw = K.equip("SWB", "swb", K.rect(14.6, CDECK + 0.3, 17.0, 5.4), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "A", "name_key": "p_swb"})
	K.bolt(sw, _deck(15.2), 15.2, CDECK + 0.3)
	K.bolt(sw, _deck(16.4), 16.4, CDECK + 0.3)
	for i in 2:
		var lx := 8.0 + i * 1.6
		var lk = K.equip("SUIT-%d" % (i + 1), "locker", K.rect(lx, CDECK + 0.3, lx + 1.2, 5.0), {"mass": 0.15, "value": 1800.0, "fragile": 0.3, "room": "A", "name_key": "p_suit_locker"})
		K.bolt(lk, _deck(lx + 0.6), lx + 0.6, CDECK + 0.3, "lock")
	K.lamp("LAMP-A", 11.0, CDECK + 0.3, "A", _deck(11.0))


# ---------------------------------------------------------------- the refrigeration plant aft

static func _plant() -> void:
	var f2 = by_tag["F2"]
	var rf = K.equip("RF", "pump", K.rect(F2 + 0.4, -2.4, 91.6, 5.0), {"mass": 2.4, "value": 15000.0, "fragile": 0.35, "room": "R", "name_key": "p_ref_plant"})
	K.bolt(rf, f2, F2 + 0.4, -1.4)
	K.bolt(rf, f2, F2 + 0.4, 4.0)
	var rv = K.equip("RCV", "gastank", K.rect(92.0, 0.6, 93.55, 6.6), {"mass": 0.5, "value": 2500.0, "fragile": 0.3, "room": "R", "name_key": "p_ref_receiver"})
	K.bolt(rv, K.at(93.75, 2.0, ["hull"]), 93.55, 2.0)
	K.bolt(rv, K.at(93.75, 5.6, ["hull"]), 93.55, 5.6, "lock")
	var vb = K.equip("RVALVE", "panel", K.rect(F2 + 0.4, -6.4, 88.8, -5.4), {"cls": "metal", "dest": "metal", "mass": 0.06, "room": "R", "cut_speed": 230.0, "name_key": "p_ref_valve"})
	K.bolt(vb, f2, F2 + 0.4, -5.9)
	K.lamp("LAMP-R", 89.0, _iy(6, 89.0), "R", K.at(89.0, _iy(6, 89.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the power section on the stern

static func _tail() -> void:
	var en = K.equip("ENG", "eng_core", K.rect(94.0, -2.6, 102.0, 6.0), {"mass": 4.6, "value": 18000.0, "fragile": 0.3, "name_key": "p_power_tail"})
	var n := 0
	for by in [-0.2, 1.8, 3.8, 5.8]:
		n += 1
		K.bolt(en, K.at(93.8, by, ["hull"]), 94.0, by, "bolt", "SEP-%d" % n)
	var nz = K.equip("NOZ", "nozzle", K.rect(102.0, -3.4, 107.0, 6.8), {"cls": "metal", "dest": "metal", "mass": 0.8, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(102.0, -1.6), Vector2(107.0, -3.4), Vector2(107.0, 6.8), Vector2(102.0, 5.0)]))
	K.bolt(nz, en, 102.0, 0.0)
	K.bolt(nz, en, 102.0, 3.4)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(18.8, 7.6), "SWB", Vector2(16.6, 5.4), [Vector2(18.8, 6.4), Vector2(16.6, 6.4)])
	K.line("p2", "cable", "power", "SWB", Vector2(15.0, CDECK + 0.3), "CON", Vector2(15.4, CDECK), [Vector2(15.0, CDECK + 0.15), Vector2(15.4, CDECK + 0.15)])
	K.line("p3", "cable", "power", "CON", Vector2(14.0, 1.2), "NAV", Vector2(5.6, 1.2))
	K.line("p4", "cable", "power", "CON", Vector2(18.0, 1.2), "MANIFEST", Vector2(21.2, 1.2))
	K.line("p5", "cable", "power", "CON", Vector2(16.0, 0.8), "LAMP-C", Vector2(15.0, _iy(2, 15.0) + 0.16), [Vector2(16.0, -4.0), Vector2(15.0, -4.0)])
	K.line("p6", "cable", "power", "SWB", Vector2(14.6, 3.4), "LAMP-A", Vector2(11.0, CDECK + 0.46), [Vector2(11.0, 3.4)])
	# aft along the keel bay: the chillers, the plant, the holds' lamps
	K.line("p7", "cable", "power", "SWB", Vector2(17.0, 4.6), "CH-1", Vector2(34.2, 8.2), [Vector2(17.6, 4.6), Vector2(17.6, 7.4), Vector2(25.4, 8.0), Vector2(34.2, 8.0)])
	K.line("p8", "cable", "power", "CH-1", Vector2(37.4, 8.2), "CH-2", Vector2(53.2, 8.2), [Vector2(37.4, 8.0), Vector2(53.2, 8.0)])
	K.line("p9", "cable", "power", "CH-2", Vector2(56.4, 8.2), "CH-3", Vector2(72.2, 8.2), [Vector2(56.4, 8.0), Vector2(72.2, 8.0)])
	K.line("p10", "cable", "power", "CH-3", Vector2(75.4, 8.2), "RF", Vector2(87.0, 5.0), [Vector2(75.4, 8.0), Vector2(85.2, 8.0), Vector2(87.0, 6.2)])
	K.line("p11", "cable", "power", "RF", Vector2(88.6, -2.4), "LAMP-R", Vector2(89.0, _iy(6, 89.0) + 0.16))
	for i in 3:
		var x0: float = PODS[i]
		K.line("pk%d" % (i + 1), "cable", "power", "CH-%d" % (i + 1), Vector2(x0 + PW * 0.5 - 1.2, KDECK + 0.4), "LAMP-K%d" % (i + 1), Vector2(x0 + 3.0, PTOP + WALL + 0.16),
			[Vector2(x0 + PW * 0.5 - 1.2, KDECK + 0.35), Vector2(x0 + 2.2, KDECK + 0.35), Vector2(x0 + 2.2, PTOP + WALL + 0.4), Vector2(x0 + 3.0, PTOP + WALL + 0.4)])
	# the refrigerant: the receiver, the plant, each chiller and up into its hold's evaporator
	K.line("r1", "pipe", "ref", "RCV", Vector2(92.0, 2.0), "RF", Vector2(91.6, 2.0))
	K.line("r2", "pipe", "ref", "RF", Vector2(90.0, 5.0), "CH-3", Vector2(75.0, 8.6), [Vector2(90.0, 9.0), Vector2(76.2, 9.0), Vector2(75.0, 8.6)])
	K.line("r3", "pipe", "ref", "CH-3", Vector2(72.4, 8.6), "CH-2", Vector2(56.2, 8.6), [Vector2(72.4, 9.2), Vector2(56.2, 9.2)])
	K.line("r4", "pipe", "ref", "CH-2", Vector2(53.4, 8.6), "CH-1", Vector2(37.2, 8.6), [Vector2(53.4, 9.2), Vector2(37.2, 9.2)])
	for i in 3:
		var x1: float = PODS[i] + PW
		var xm: float = PODS[i] + PW * 0.5
		K.line("re%d" % (i + 1), "pipe", "ref", "CH-%d" % (i + 1), Vector2(xm + 1.4, KDECK + 0.4), "EV-%d" % (i + 1), Vector2(x1 - 1.4, -5.0),
			[Vector2(xm + 1.4, KDECK + 0.35), Vector2(x1 - 1.4, KDECK + 0.35)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-C", "port", K.at(12.0, -9.6, ["hull"]), Vector2(12.0, -10.2), {"medium": "gas", "target": "C"})
	K.ctrl("G-A", "port", K.at(9.0, _iy(11, 9.0) + 0.25, ["hull"]), Vector2(9.0, _iy(11, 9.0) + 0.75), {"medium": "gas", "target": "A"})
	K.ctrl("G-R", "port", K.at(88.0, _iy(6, 88.0) - 0.25, ["hull"]), Vector2(88.0, _iy(6, 88.0) - 0.75), {"medium": "gas", "target": "R"})
	for i in 3:
		var x0: float = PODS[i]
		var n := str(i + 1)
		K.ctrl("G-K" + n, "port", by_tag["K%s-RF" % n], Vector2(x0 + 1.4, PTOP - 0.1), {"medium": "gas", "target": "K" + n})
		K.ctrl("T-K" + n, "probe", by_tag["K%s-WF" % n], Vector2(x0 - 0.1, -2.0), {"medium": "cold", "target": "K" + n})
		K.door("PH-" + n, "")
		K.door("HR-" + n, "")
	# the outside panel on the belly: the bus breaker, a test point, the berth's power and its temporary cooling
	var px = K.equip("PNL-X", "panel", K.rect(26.0, 10.2, 31.0, 10.7), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(26.6, 10.0, ["hull"]), 26.6, 10.2)
	K.bolt(px, K.at(30.4, 10.0, ["hull"]), 30.4, 10.2)
	K.ctrl("K-M", "switch", px, Vector2(26.6, 10.45), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(27.6, 10.45), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(28.8, 10.45), {"target": "aux", "state": false})
	K.ctrl("COLD-X", "socket", px, Vector2(30.4, 10.45), {"target": "cold", "state": false})
	for h in [["HT-A", ""], ["HT-R", ""]]:
		K.door(h[0], h[1])
	K.door("DK-H", "A")
	K.ctrl("PR", "port", by_tag["RCV"], Vector2(92.8, 0.8), {"medium": "refrigerant", "target": "ref", "hidden_room": "R"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	var bow := func(y: float) -> Vector2:
		var a: Vector2 = inn[13]
		var b: Vector2 = inn[0]
		return Vector2(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x), y)
	w.add_room("C", K.mp([bow.call(CDECK), bow.call(-3.9), inn[1], inn[2], inn[3], inn[4], at.call(4, F1), Vector2(F1, CDECK)]))
	w.add_room("A", K.mp([bow.call(CDECK + 0.3), Vector2(F1, CDECK + 0.3), Vector2(F1, BELLY), inn[11], inn[12], inn[13]]))
	for i in 3:
		var x0: float = PODS[i]
		w.add_room("K%d" % (i + 1), K.R(x0 + WALL, PTOP + WALL, x0 + PW - WALL, PFLOOR))
	w.add_room("R", K.mp([at.call(6, F2 + 0.4), inn[7], inn[8], inn[9], at.call(9, F2 + 0.4)]))


static func meta() -> Dictionary:
	var cargo := {}
	var labels := {"BAT": "BAT", "SWB": "SWB", "RF": "REFRIG", "RCV": "R-404", "MANIFEST": "MANIFEST"}
	for i in 3:
		var n := str(i + 1)
		var tags: Array = []
		for k in 6:
			tags.append("PAL-%s%d" % [n, k + 1])
			labels["PAL-%s%d" % [n, k + 1]] = "C0%s FROZEN" % n
		cargo["K" + n] = tags
	return {
		"id": "cl104",
		"name": "CL-104 FROST STORE",
		"title": ["CL-104「霜仓」分区冷链运输船 · 107 m", "CL-104 FROST STORE · ZONED COLD-CHAIN CARRIER · 107 m"],
		"contract": "CL-104",
		"length": 107.0,
		"value": {"total": 220000.0, "metal": 34000.0},
		"clamps": [[32.0, 10.2], [55.0, 10.2], [76.0, 10.2]],
		"room_names": {"C": "room_clC", "A": "room_clA", "K1": "room_clK1", "K2": "room_clK2", "K3": "room_clK3", "R": "room_clR"},
		"gas": {"rooms": {"C": 101.0, "A": 101.0, "K1": 98.0, "K2": 98.0, "K3": 98.0, "R": 101.0}, "vessels": {}, "valves": [], "value": 1600.0},
		"cold": {"rooms": {"K1": -25.0, "K2": -25.0, "K3": -25.0}, "chillers": {"CH-1": ["K1"], "CH-2": ["K2"], "CH-3": ["K3"]}, "plant": "RF",
			"supply": "COLD-X", "warm": 0.05, "thaw": -5.0, "keep": 0.45, "cargo": cargo},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "A": "LAMP-A", "K1": "LAMP-K1", "K2": "LAMP-K2", "K3": "LAMP-K3", "R": "LAMP-R"},
		},
		"fluids": {"volumes": {
			"ref": {"fluid": "refrigerant", "amount": 0.6, "piece": "RCV", "content": 1.0, "leak": 0.12, "port": "PR", "pump": [0.12, 0.008], "hazard": 0.02},
			"ref_line": {"fluid": "refrigerant", "amount": 0.02, "nets": ["ref"], "leak": 0.06, "leak_min": 0.004},
		}, "joins": [], "value": {"refrigerant": 3200.0}},
		"ctrls_cfg": {"G-C": {"rate": 12.0}, "G-A": {"rate": 9.0}, "G-R": {"rate": 9.0}, "G-K1": {"rate": 22.0}, "G-K2": {"rate": 22.0}, "G-K3": {"rate": 22.0}},
		"labels": labels,
		"hints": {},
		"market": {
			"class": "CL", "name": ["霜仓级冷链运输船", "FROST STORE-CLASS COLD-CHAIN CARRIER"], "time": 42.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "A": [0.2, 40.0, 101.0], "R": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"ref": [0.15, 0.6]}, "fill": {"ref_line": "ref"},
			"knockable": ["NAV", "CON", "SWB"],
			"drift": [],
			"section_x": 64.0,
			"slots": {"hidden_damage": {"plates": ["HL10-1", "HL10-2", "HL10-4", "HL10-6"]}, "fire_system": {"x": 89.6, "y0": 6.5, "y1": 8.2, "base": ["HL9-0", 8.2], "room": "R", "port": [90.0, 6.57]}},
			"mechanisms": true,
		},
		"procedures": {
			"MANIFEST": [
				{"do": "operate", "ctrl": "COLD-X"},
				{"do": "hose", "ctrl": "G-A"},
				{"do": "wait", "until": {"P": ["A", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-A"},
				{"do": "wait", "until": {"open": ["A"]}, "max": 5.0},
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "DK-H"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "MANIFEST"},
				{"do": "deliver", "piece": "MANIFEST", "zone": "equip"},
			],
		},
	}
