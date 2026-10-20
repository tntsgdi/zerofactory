class_name Cv138Author
# Authoring script for CV-138 "Wayfarer", a 138 m drone maintenance and recovery
# carrier (R2 fleet, design/ships/全新舰队_R2_2026-10-18/CV-138_行舟.md; lengths as
# drawn, heights at 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/cv138.json.
# Metres, x bow (0) to the nozzles (138), y down.
#
# The forward bay with the main battery and the low-voltage distribution, the
# raised dispatch bridge on the roof, the closed six-drone workshop (two rows of
# three bays, a charger module for each on the rack at its aft end), the sealed
# accumulator room for the hangar's lift, the pressurised hangar aft with the
# recovery drone parked on its scissor lift, two engines on the stern.
# What it asks of you: the main battery, every bay's charger and every drone's
# own battery pack are each live on their own; the bus dead, the bays and the
# drones are not. Isolate the bay (its charger's switch on the rack) and the drone
# (its pack's isolator on the drone) before unplugging either lead; a drone freed
# from its cradle with its pack still on it and live wakes and throws itself into
# the bay (badly damaged). The lift is held up by its own accumulator: bled and
# its locks out before its base pivot, or it springs (into the drone if it is
# still on it).

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, 0.0), Vector2(8.0, -7.2), Vector2(22.0, -10.2), Vector2(84.0, -10.2), Vector2(95.0, -8.4),
	Vector2(104.0, -10.4), Vector2(116.0, -10.4), Vector2(124.0, -6.6), Vector2(124.0, 8.6), Vector2(116.0, 13.0),
	Vector2(31.0, 13.0), Vector2(10.8, 8.1)]
const A1 := 33.0                 # forward bay | workshop (to 33.4)
const A2 := 82.0                 # workshop | accumulator room (to 82.4)
const A3 := 91.6                 # accumulator room | hangar (to 92.0)
const WDECK := 9.6               # the workshop deck (to 10.0)
const SHELF := -0.2              # the upper bays' shelf (to 0.2)
const BELLY := 12.55
const BAYS := [35.5, 49.0, 62.5]  # each bay's drone, 9 m long
const DW := 9.0
const DH := 5.4

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "CV138")
	w = world
	by_tag = K.by_tag
	_hull()
	_decks()
	_bays()
	_rack()
	_forward()
	_bridge()
	_lift()
	_engines()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "CV138")
	w = world
	_rooms()


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


static func _oy(i: int, x: float) -> float:
	var a: Vector2 = OUT[i]
	var b: Vector2 = OUT[(i + 1) % OUT.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# a drone's outline: a long octagon in its bay
static func _octo(x0: float, y0: float, ww: float, hh: float) -> PackedVector2Array:
	var c := minf(ww, hh) * 0.24
	return K.mp([Vector2(x0 + c, y0), Vector2(x0 + ww - c, y0), Vector2(x0 + ww, y0 + c), Vector2(x0 + ww, y0 + hh - c),
		Vector2(x0 + ww - c, y0 + hh), Vector2(x0 + c, y0 + hh), Vector2(x0, y0 + hh - c), Vector2(x0, y0 + c)])


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	K.ring(OUT, T, {
		1: [0.55, 0.7],
		2: [0.2, 0.42, 0.484, 0.516, 0.7, 0.85],
		3: [0.5],
		5: [0.3, 0.55],
		9: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
	}, {
		"1:1": {"kind": "hatch", "door": true, "tag": "HT-F", "open_dir": Vector2(-2.0, -0.4) * Geom.M, "cut_speed": 200.0},
		"2:3": {"kind": "hatch", "door": true, "tag": "HT-W", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0},
		"3:0": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(-1.6, -0.6) * Geom.M, "cut_speed": 200.0},
		"5:1": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(3.2, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HL")
	K.clamp(1, 40.0, 13.0, 12.8)
	K.clamp(2, 70.0, 13.0, 12.8)
	K.clamp(3, 100.0, 13.0, 12.8)


# ---------------------------------------------------------------- bulkheads and decks

static func _decks() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	for e in [["A1", A1, 2], ["A2", A2, 2], ["A3", A3, 3]]:
		var x: float = e[1]
		var top := _iy(e[2], x + 0.2)
		var a = K.plate(e[0], K.R(x, top - 0.1, x + 0.4, BELLY + 0.1), S, "bulkhead")
		K.bolt(a, K.at(x + 0.2, top - 0.25, ["hull"]), x + 0.2, top, "weld")
		K.bolt(a, K.at(x + 0.2, BELLY + 0.25, ["hull"]), x + 0.2, BELLY, "weld")
	var wd = K.plate("WDECK", K.R(A1 + 0.4, WDECK, A2, WDECK + 0.4), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "name_key": "p_bay_deck"}, "deck")
	K.bolt(wd, by_tag["A1"], A1 + 0.4, WDECK + 0.2, "weld")
	K.bolt(wd, by_tag["A2"], A2, WDECK + 0.2, "weld")
	# trusses under the workshop deck down to the bottom
	var k := 0
	for tx in [40.0, 52.0, 64.0, 76.0]:
		k += 1
		var tp = K.plate("TP-%d" % k, K.R(tx, WDECK + 0.4, tx + 0.5, BELLY), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_truss"}, "strut")
		K.bolt(tp, wd, tx + 0.25, WDECK + 0.4, "weld")
		K.bolt(tp, K.at(tx + 0.25, BELLY + 0.25, ["hull"]), tx + 0.25, BELLY, "weld")
	# the upper bays' shelf, on the forward bulkhead and three posts
	var sh = K.plate("SHELF", K.R(A1 + 0.4, SHELF, 72.8, SHELF + 0.4), {"density": 1.1, "barrier": false, "cut_speed": 190.0, "name_key": "p_bay_shelf"}, "deck")
	K.bolt(sh, by_tag["A1"], A1 + 0.4, SHELF + 0.2, "weld")
	k = 0
	for px in [46.6, 60.1, 72.4]:
		k += 1
		var po = K.plate("SP-%d" % k, K.R(px, SHELF + 0.4, px + 0.4, WDECK), {"density": 1.4, "barrier": false, "cut_speed": 160.0, "name_key": "p_truss"}, "strut")
		K.bolt(po, sh, px + 0.2, SHELF + 0.4, "weld")
		K.bolt(po, wd, px + 0.2, WDECK, "weld")


# ---------------------------------------------------------------- the six bays

static func _bays() -> void:
	for i in 6:
		var n := str(i + 1)
		var x0: float = BAYS[i % 3]
		var upper := i < 3
		var floor_y: float = SHELF if upper else WDECK
		var base = by_tag["SHELF"] if upper else by_tag["WDECK"]
		var y0 := floor_y - DH
		var dr = K.equip("DR-" + n, "uav", K.rect(x0, y0, x0 + DW, floor_y), {"mass": 2.2, "value": 11000.0, "fragile": 0.35, "room": "W", "name_key": "p_bay_drone"}, _octo(x0, y0, DW, DH))
		K.bolt(dr, base, x0 + 2.0, floor_y)
		K.bolt(dr, base, x0 + 7.0, floor_y)
		# its own battery pack, latched on its back
		var pk = K.equip("DP-" + n, "battery", K.rect(x0 + 3.3, y0 - 1.2, x0 + 5.7, y0), {"mass": 0.35, "value": 1600.0, "fragile": 0.4, "room": "W", "hazard": "battery", "name_key": "p_drone_pack"})
		K.bolt(pk, dr, x0 + 3.7, y0, "lock")
		K.bolt(pk, dr, x0 + 5.3, y0, "lock")
	K.lamp("LAMP-W1", 44.0, _iy(2, 44.0), "W", K.at(44.0, _iy(2, 44.0) - 0.2, ["hull"]))
	K.lamp("LAMP-W2", 66.0, _iy(2, 66.0), "W", K.at(66.0, _iy(2, 66.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the charger rack

static func _rack() -> void:
	var top := _iy(2, 77.3)
	var rs = K.plate("RACK", K.R(76.8, top, 77.4, WDECK), {"density": 1.2, "barrier": false, "cut_speed": 170.0, "name_key": "p_charge_rack"}, "beam")
	K.bolt(rs, K.at(77.1, top - 0.2, ["hull"]), 77.1, top, "weld")
	K.bolt(rs, by_tag["WDECK"], 77.1, WDECK, "weld")
	for i in 6:
		var y0 := -9.0 + i * 3.0
		var ch = K.equip("CHG-%d" % (i + 1), "cap", K.rect(73.6, y0, 76.8, y0 + 2.6), {"mass": 0.25, "value": 2600.0, "fragile": 0.4, "room": "W", "name_key": "p_bay_charger"})
		K.bolt(ch, rs, 76.8, y0 + 0.6)
		K.bolt(ch, rs, 76.8, y0 + 2.0)


# ---------------------------------------------------------------- the forward bay: main battery, distribution

static func _forward() -> void:
	var a1 = by_tag["A1"]
	var bt = K.equip("BAT", "battery", K.rect(26.6, 5.0, A1, 9.8), {"mass": 1.8, "value": 7500.0, "fragile": 0.4, "room": "F", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, a1, A1, 6.0)
	K.bolt(bt, a1, A1, 8.8)
	var sw = K.equip("SWB", "swb", K.rect(30.4, -2.0, A1, 4.4), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "F", "name_key": "p_lv_dist"})
	K.bolt(sw, a1, A1, -1.0)
	K.bolt(sw, a1, A1, 3.4)
	var sp = K.equip("SPARES", "locker", K.rect(29.0, -8.4, A1, -2.6), {"mass": 0.4, "value": 3200.0, "fragile": 0.35, "room": "F", "name_key": "p_rotor_spares"})
	K.bolt(sp, a1, A1, -7.6)
	K.bolt(sp, a1, A1, -3.4)
	K.lamp("LAMP-F", 26.0, _iy(2, 26.0), "F", K.at(26.0, _iy(2, 26.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the raised dispatch bridge

static func _bridge() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 190.0}
	var bf = K.plate("BR-F", K.mp([Vector2(22.6, -10.2), Vector2(25.0, -17.6), Vector2(25.5, -17.2), Vector2(23.2, -10.2)]), S.merged({"art": "window"}))
	var r1 = K.plate("BR-R1", K.R(25.0, -17.6, 30.0, -17.2), S)
	var hb = K.plate("HT-B", K.R(30.0, -17.6, 31.8, -17.2), {"density": 1.0, "door": true, "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 180.0}, "hatch")
	var r2 = K.plate("BR-R2", K.R(31.8, -17.6, 38.7, -17.2), S)
	var ba = K.plate("BR-A", K.mp([Vector2(38.7, -17.6), Vector2(48.0, -10.2), Vector2(47.3, -10.2), Vector2(38.5, -17.2)]), S)
	K.bolt(bf, K.at(22.9, -9.95, ["hull"]), 22.9, -10.2, "weld")
	K.bolt(ba, K.at(47.6, -9.95, ["hull"]), 47.6, -10.2, "weld")
	K.bolt(r1, bf, 25.2, -17.4, "weld")
	K.bolt(hb, r1, 30.0, -17.4, "weld")
	K.bolt(hb, r2, 31.8, -17.4, "weld")
	K.bolt(r2, ba, 38.6, -17.4, "weld")
	# the dispatch mast on the roof
	var an = K.equip("ANT", "radar", K.rect(33.4, -21.2, 36.2, -17.6), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "name_key": "p_dispatch_mast"})
	K.bolt(an, r2, 34.0, -17.6)
	K.bolt(an, r2, 35.6, -17.6)
	for i in 2:
		var sx := 27.0 + i * 2.6
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, -11.7, 0.8, 1.5), {"room": "B", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, -9.95, ["hull"]), sx + 0.2, -10.2)
		K.bolt(st, K.at(sx + 0.6, -9.95, ["hull"]), sx + 0.6, -10.2, "lock")
	var hm = K.equip("HELM", "console", K.rect(33.0, -11.8, 36.4, -10.2), {"mass": 0.3, "value": 5500.0, "fragile": 0.5, "room": "B", "name_key": "p_helm"})
	K.bolt(hm, K.at(33.4, -9.95, ["hull"]), 33.4, -10.2)
	K.bolt(hm, K.at(36.0, -9.95, ["hull"]), 36.0, -10.2)
	var dl = K.equip("DISPATCH", "cabinet", K.rect(37.4, -12.6, 39.4, -10.2), {"mass": 0.15, "value": 8000.0, "fragile": 0.5, "room": "B", "mandatory": true, "name_key": "p_dispatch_log"})
	K.bolt(dl, K.at(37.8, -9.95, ["hull"]), 37.8, -10.2)
	K.bolt(dl, K.at(39.0, -9.95, ["hull"]), 39.0, -10.2)
	K.lamp("LAMP-B", 28.0, -17.2, "B", r1)


# ---------------------------------------------------------------- the hangar's lift, its accumulator, the recovery drone

static func _lift() -> void:
	var a2 = by_tag["A2"]
	var ac = K.equip("ACC-G", "gastank", K.rect(84.0, -4.0, 90.0, BELLY), {"mass": 0.9, "value": 3000.0, "fragile": 0.3, "room": "P", "hazard": "gas_tank", "name_key": "p_lift_accumulator"})
	K.bolt(ac, K.at(85.0, BELLY + 0.25, ["hull"]), 85.0, BELLY, "lock")
	K.bolt(ac, K.at(89.0, BELLY + 0.25, ["hull"]), 89.0, BELLY, "lock")
	K.lamp("LAMP-P", 90.6, _iy(3, 90.6), "P", K.at(90.6, _iy(3, 90.6) - 0.2, ["hull"]))
	# the scissor lift on the hangar floor: its base pivot, its two locks
	var lf = K.equip("LIFT", "lift", K.rect(96.0, 10.2, 114.0, BELLY), {"mass": 2.6, "value": 9000.0, "fragile": 0.3, "room": "H", "name_key": "p_hangar_lift"})
	K.bolt(lf, K.at(97.0, BELLY + 0.25, ["hull"]), 97.0, BELLY, "bolt", "LP")
	K.bolt(lf, K.at(103.0, BELLY + 0.25, ["hull"]), 103.0, BELLY, "lock", "LL-1")
	K.bolt(lf, K.at(113.0, BELLY + 0.25, ["hull"]), 113.0, BELLY, "lock", "LL-2")
	# the recovery drone parked on it, its pack on its back
	var dr = K.equip("DR-7", "uav", K.rect(99.0, 3.0, 111.0, 10.2), {"mass": 2.9, "value": 16000.0, "fragile": 0.35, "room": "H", "name_key": "p_recovery_drone"}, _octo(99.0, 3.0, 12.0, 7.2))
	K.bolt(dr, lf, 101.5, 10.2)
	K.bolt(dr, lf, 108.5, 10.2)
	var pk = K.equip("DP-7", "battery", K.rect(103.6, 1.6, 106.4, 3.0), {"mass": 0.45, "value": 2000.0, "fragile": 0.4, "room": "H", "hazard": "battery", "name_key": "p_drone_pack"})
	K.bolt(pk, dr, 104.0, 3.0, "lock")
	K.bolt(pk, dr, 106.0, 3.0, "lock")
	# the hangar's own charger, hung from the roof
	var ch = K.equip("CHG-7", "cap", K.rect(112.0, _iy(5, 112.0), 115.2, -7.4), {"mass": 0.3, "value": 2800.0, "fragile": 0.4, "room": "H", "name_key": "p_bay_charger"})
	K.bolt(ch, K.at(112.6, _iy(5, 112.6) - 0.2, ["hull"]), 112.6, _iy(5, 112.6))
	K.bolt(ch, K.at(114.6, _iy(5, 114.6) - 0.2, ["hull"]), 114.6, _iy(5, 114.6))
	K.lamp("LAMP-H", 100.0, _iy(4, 100.0), "H", K.at(100.0, _iy(4, 100.0) - 0.2, ["hull"]))


static func _engines() -> void:
	for e in [["U", -6.0, 0.4, [-4.6, -0.8]], ["L", 2.6, 8.2, [3.6, 7.2]]]:
		var y0: float = e[1]
		var y1: float = e[2]
		var en = K.equip("ENG-" + e[0], "eng_core", K.rect(124.0, y0, 133.0, y1), {"mass": 4.0, "value": 15000.0, "fragile": 0.3, "name_key": "p_engine"})
		for by in e[3]:
			K.bolt(en, K.at(123.75, by, ["hull"]), 124.0, by)
		var nz = K.equip("NOZ-" + e[0], "nozzle", K.rect(133.0, y0 - 0.6, 138.0, y1 + 0.6), {"cls": "metal", "dest": "metal", "mass": 0.6, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(133.0, y0 + 0.6), Vector2(138.0, y0 - 0.6), Vector2(138.0, y1 + 0.6), Vector2(133.0, y1 - 0.6)]))
		K.bolt(nz, en, 133.0, y0 + 1.4)
		K.bolt(nz, en, 133.0, y1 - 1.4)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	var tw := _iy(2, 50.0) + 0.25
	K.line("p1", "cable", "power", "BAT", Vector2(28.0, 5.0), "SWB", Vector2(31.4, 4.4), [Vector2(28.0, 4.7), Vector2(31.4, 4.7)])
	K.line("p2", "cable", "power", "SWB", Vector2(30.4, -1.0), "LAMP-F", Vector2(26.0, _iy(2, 26.0) + 0.16), [Vector2(26.0, -1.0)])
	K.line("p3", "cable", "power", "SWB", Vector2(30.4, 0.5), "LAMP-W1", Vector2(44.0, _iy(2, 44.0) + 0.16), [Vector2(28.4, 0.5), Vector2(28.4, tw), Vector2(44.0, tw)])
	K.line("p4", "cable", "power", "LAMP-W1", Vector2(44.2, _iy(2, 44.0) + 0.16), "LAMP-W2", Vector2(66.0, _iy(2, 66.0) + 0.16), [Vector2(44.2, tw), Vector2(66.0, tw)])
	K.line("p5", "cable", "power", "LAMP-W2", Vector2(66.2, _iy(2, 66.0) + 0.16), "LAMP-P", Vector2(90.6, _iy(3, 90.6) + 0.16), [Vector2(66.2, tw), Vector2(81.0, tw), Vector2(81.0, -7.0), Vector2(90.6, -7.0)])
	K.line("p6", "cable", "power", "LAMP-P", Vector2(90.8, _iy(3, 90.6) + 0.16), "LAMP-H", Vector2(100.0, _iy(4, 100.0) + 0.16), [Vector2(90.8, -7.4), Vector2(100.0, -7.4)])
	K.line("p7", "cable", "power", "LAMP-F", Vector2(25.8, _iy(2, 26.0) + 0.16), "HELM", Vector2(33.4, -11.8), [Vector2(25.8, -10.6), Vector2(24.4, -10.6), Vector2(24.4, -12.4), Vector2(33.4, -12.4)])
	K.line("p8", "cable", "power", "HELM", Vector2(36.4, -11.2), "DISPATCH", Vector2(37.4, -11.2))
	K.line("p9", "cable", "power", "HELM", Vector2(34.0, -11.8), "LAMP-B", Vector2(28.0, -17.04), [Vector2(34.0, -13.0), Vector2(28.4, -13.0), Vector2(28.4, -16.8), Vector2(28.0, -16.8)])
	# each bay's charger lead, and each drone's pack lead
	for i in 6:
		var n := str(i + 1)
		var c := i % 3
		var x0: float = BAYS[c]
		var upper := i < 3
		var floor_y: float = SHELF if upper else WDECK
		var y0 := floor_y - DH
		var ym := -9.0 + i * 3.0 + 1.3
		var xv := 73.3 - 0.1 * c
		var yr := (-8.9 + 0.35 * c) if upper else (1.6 + 0.35 * c)
		K.line("c" + n, "cable", "power", "CHG-" + n, Vector2(73.6, ym), "DR-" + n, Vector2(x0 + 8.0, y0 + 1.0),
			[Vector2(xv, ym), Vector2(xv, yr), Vector2(x0 + 8.0, yr)])
		K.line("k" + n, "cable", "power", "DP-" + n, Vector2(x0 + 5.7, y0 - 0.6), "DR-" + n, Vector2(x0 + 6.4, y0 + 0.4), [Vector2(x0 + 6.4, y0 - 0.6)])
	K.line("c7", "cable", "power", "CHG-7", Vector2(113.6, -7.4), "DR-7", Vector2(109.6, 4.4), [Vector2(113.6, 2.4), Vector2(109.6, 2.4)])
	K.line("k7", "cable", "power", "DP-7", Vector2(106.4, 2.3), "DR-7", Vector2(107.6, 3.4), [Vector2(107.6, 2.3)])
	K.line("h1", "pipe", "hyd", "ACC-G", Vector2(90.0, 11.0), "LIFT", Vector2(96.0, 11.4), [Vector2(94.0, 11.0), Vector2(94.0, 11.4)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-F", "port", K.at(12.0, _iy(1, 12.0) - 0.25, ["hull"]), Vector2(12.0, _oy(1, 12.0) - 0.25), {"medium": "gas", "target": "F"})
	K.ctrl("G-W", "port", K.at(60.0, _iy(2, 60.0) - 0.25, ["hull"]), Vector2(60.0, -10.45), {"medium": "gas", "target": "W"})
	K.ctrl("G-P", "port", K.at(90.0, _iy(3, 90.0) - 0.25, ["hull"]), Vector2(90.0, _oy(3, 90.0) - 0.25), {"medium": "gas", "target": "P"})
	K.ctrl("G-H", "port", K.at(114.0, _iy(5, 114.0) - 0.25, ["hull"]), Vector2(114.0, -10.65), {"medium": "gas", "target": "H"})
	K.ctrl("G-B", "port", by_tag["BR-R2"], Vector2(37.0, -17.8), {"medium": "gas", "target": "B"})
	var px = K.equip("PNL-X", "panel", K.rect(42.6, 13.0, 46.2, 13.5), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(43.0, 12.8, ["hull"]), 43.0, 13.0)
	K.bolt(px, K.at(45.8, 12.8, ["hull"]), 45.8, 13.0)
	K.ctrl("K-M", "switch", px, Vector2(43.0, 13.25), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(44.2, 13.25), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(45.8, 13.25), {"target": "aux", "state": false})
	for h in [["HT-F", ""], ["HT-W", ""], ["HT-P", ""], ["HT-H", ""], ["HT-B", ""]]:
		K.door(h[0], h[1])
	# each bay's charger switch on its module, each drone's pack isolator on the drone
	for i in 7:
		var n := str(i + 1)
		var hr := "W" if i < 6 else "H"
		var cp := Vector2(75.8, -9.0 + i * 3.0 + 1.3) if i < 6 else Vector2(114.2, -8.4)
		K.ctrl("CH-" + n, "switch", by_tag["CHG-" + n], cp, {"target": "CH-" + n, "state": true, "hidden_room": hr})
		var dp := Vector2(BAYS[i % 3] + 1.4, (SHELF if i < 3 else WDECK) - DH * 0.5) if i < 6 else Vector2(100.6, 6.6)
		K.ctrl("PK-" + n, "switch", by_tag["DR-" + n], dp, {"target": "PK-" + n, "state": true, "hidden_room": hr})
	K.ctrl("PA-G", "port", by_tag["ACC-G"], Vector2(87.0, -3.8), {"medium": "gas", "target": "ACC-G", "hidden_room": "P"})
	K.ctrl("PL", "port", by_tag["LIFT"], Vector2(98.0, 10.4), {"medium": "hydraulic", "target": "lift_hyd", "hidden_room": "H"})
	K.ctrl("T-LP", "probe", by_tag["LIFT"], Vector2(97.6, 11.6), {"medium": "tension", "target": "LP", "hidden_room": "H"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	w.add_room("F", K.mp([inn[0], inn[1], inn[2], at.call(2, A1), Vector2(A1, BELLY), inn[10], inn[11]]))
	w.add_room("W", K.mp([at.call(2, A1 + 0.4), at.call(2, A2), Vector2(A2, WDECK), Vector2(A1 + 0.4, WDECK)]))
	w.add_room("P", K.mp([at.call(2, A2 + 0.4), inn[3], at.call(3, A3), Vector2(A3, BELLY), Vector2(A2 + 0.4, BELLY)]))
	w.add_room("H", K.mp([at.call(3, A3 + 0.4), inn[4], inn[5], inn[6], inn[7], inn[8], inn[9], Vector2(A3 + 0.4, BELLY)]))
	w.add_room("B", K.mp([Vector2(23.2, -10.2), Vector2(25.5, -17.2), Vector2(38.5, -17.2), Vector2(47.3, -10.2)]))


static func meta() -> Dictionary:
	var drones := {}
	var iso: Array = []
	for i in 7:
		var n := str(i + 1)
		drones["DR-" + n] = {"pack": "DP-" + n, "kick": [0.0, -2.6] if i != 6 else [0.0, -2.0]}
		iso.append({"piece": "CHG-" + n, "volts": 120.0, "charge": 0.9, "switch": "CH-" + n})
		iso.append({"piece": "DP-" + n, "volts": 96.0, "charge": 0.8, "switch": "PK-" + n})
	return {
		"id": "cv138",
		"name": "CV-138 WAYFARER",
		"title": ["CV-138「行舟」无人机维护母船 · 138 m", "CV-138 WAYFARER · DRONE TENDER · 138 m"],
		"contract": "CV-138",
		"length": 138.0,
		"value": {"total": 248700.0, "metal": 52000.0},
		"clamps": [[40.0, 13.0], [70.0, 13.0], [100.0, 13.0]],
		"room_names": {"F": "room_cvF", "W": "room_cvW", "P": "room_cvP", "H": "room_cvH", "B": "room_cvB"},
		"gas": {"rooms": {"F": 101.0, "W": 101.0, "P": 101.0, "H": 101.0, "B": 101.0},
			"vessels": {"ACC-G": {"V": 0.3, "kpa": 2400.0, "piece": "ACC-G", "burst": 200.0}}, "valves": [], "value": 3000.0},
		"drones": drones,
		"preloads": {
			"LP": {"pins": ["LL-1", "LL-2"], "vessel": "ACC-G", "kpa": 300.0, "piece": "LIFT", "push": [0.0, -1.0], "hits": "DR-7", "kn": 64.0},
		},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			# every bay's charger and every drone's own pack: each a supply of its own
			"isolated": iso,
			"lamps": {"F": "LAMP-F", "W": "LAMP-W1", "P": "LAMP-P", "H": "LAMP-H", "B": "LAMP-B"},
		},
		"fluids": {"volumes": {
			"lift_hyd": {"fluid": "hydraulic", "amount": 0.3, "piece": "LIFT", "content": 1.0, "leak": 0.1, "port": "PL", "pump": [0.1, 0.008]},
			"lift_line": {"fluid": "hydraulic", "amount": 0.02, "nets": ["hyd"], "leak": 0.06, "leak_min": 0.004},
		}, "joins": [], "value": {"hydraulic": 500.0}},
		"ctrls_cfg": {"G-F": {"rate": 40.0}, "G-W": {"rate": 120.0}, "G-P": {"rate": 24.0}, "G-H": {"rate": 70.0}, "G-B": {"rate": 14.0}, "PA-G": {"rate": 0.8}},
		"labels": {"BAT": "BAT", "SWB": "LV DIST", "ACC-G": "ACC", "LIFT": "LIFT", "DISPATCH": "DISPATCH",
			"DR-1": "DRONE 1", "DR-2": "DRONE 2", "DR-3": "DRONE 3", "DR-4": "DRONE 4", "DR-5": "DRONE 5", "DR-6": "DRONE 6", "DR-7": "RECOVERY",
			"CHG-1": "CHG 1", "CHG-2": "CHG 2", "CHG-3": "CHG 3", "CHG-4": "CHG 4", "CHG-5": "CHG 5", "CHG-6": "CHG 6", "CHG-7": "CHG 7"},
		"hints": {},
		"market": {
			"class": "CV", "name": ["行舟级无人机维护母船", "WAYFARER-CLASS DRONE TENDER"], "time": 55.0,
			"rooms": {"F": [0.2, 40.0, 101.0], "W": [0.2, 40.0, 101.0], "P": [0.2, 40.0, 101.0], "H": [0.2, 40.0, 101.0], "B": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"lift_hyd": [0.15, 0.3]}, "fill": {"lift_line": "lift_hyd"},
			"knockable": ["HELM", "SWB"],
			"drift": [],
			"section_x": 58.0,
			"slots": {"hidden_damage": {"plates": ["HL9-4", "HL9-6", "HL2-1", "HL2-5"]},
				"fire_system": {"x": 93.0, "y0": 10.8, "y1": BELLY, "base": ["HL9-2", BELLY], "room": "H", "port": [93.4, 10.87]}},
			"mechanisms": true,
		},
		"procedures": {
			"DISPATCH": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "DISPATCH"},
				{"do": "deliver", "piece": "DISPATCH", "zone": "equip"},
			],
		},
	}
