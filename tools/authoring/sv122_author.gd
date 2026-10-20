class_name Sv122Author
# Authoring script for SV-122 "Watchtower", a 126 m survey ship (R2 fleet,
# design/ships/全新舰队_R2_2026-10-18/SV-122_望楼.md; lengths as drawn, heights at
# 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/sv122.json.
# Metres, x bow (0) to the nozzle (126), y down.
#
# A long low hull with a staffed two-level observation tower forward carrying a
# fixed deep-space array, a raised sensor bay aft, and a near-field scanner slung
# under the bow. Inside: the equipment room and airlock, the mapping room, the
# instrument cradle hall (three precision instruments hanging from a damped
# cradle, the cradle from the main beam), and the uninterruptible supply aft.
# What it asks of you: each instrument is held to the cradle by its damping lock,
# which the wrench can't undo: release it (the cradle hall's lock on it) and the
# instrument comes off whole. Cut or take out the main beam or a damper link
# while an instrument is still locked on and the whole cradle drops: badly
# damaged instruments. The instruments run on their own uninterruptible supply,
# not the bus: its switch is aft, in its own room.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, 0.6), Vector2(10.0, -6.0), Vector2(23.0, -7.2), Vector2(42.0, -7.2), Vector2(54.0, -5.4), Vector2(91.0, -5.4),
	Vector2(108.0, -2.4), Vector2(110.0, 4.8), Vector2(99.0, 8.4), Vector2(39.0, 8.4), Vector2(28.0, 10.8), Vector2(10.0, 8.4)]
const W1 := 25.0                 # equipment / airlock | mapping (to 25.4)
const W2 := 51.6                 # mapping | the cradle hall (to 52.0)
const W3 := 85.0                 # the cradle hall | the supply (to 85.4)
const BELLY := 7.95
const MDECK := 4.2               # the mapping room's floor grating
const EDECK := 6.0               # the equipment room's floor grating
const OPTS := [56.5, 65.5, 74.5] # each instrument's forward edge, 6 m wide
const TDECK := -14.4             # the tower's cabin deck (to -14.1)

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "SV122")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	_tower()
	_array()
	_sensor_bay()
	_equipment_room()
	_mapping()
	_cradle()
	_supply()
	_scanner()
	_engine()
	_fitout()
	_lines()
	_fit_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "SV122")
	w = world
	_rooms()


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# the outside of edge i at x
static func _oy(i: int, x: float) -> float:
	var a: Vector2 = OUT[i]
	var b: Vector2 = OUT[(i + 1) % OUT.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


static func _bar(a: Vector2, b: Vector2, t: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * t * 0.5
	return K.mp([a + n, b + n, b - n, a - n])


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	K.ring(OUT, T, {
		2: [0.48, 0.58],
		4: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
		5: [0.5],
		8: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9],
		10: [0.5, 0.7],
	}, {
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-T", "open_dir": Vector2(-2.2, 0) * Geom.M, "cut_speed": 200.0},
		"5:1": {"kind": "hatch", "door": true, "tag": "HT-U", "open_dir": Vector2(-1.6, -0.3) * Geom.M, "cut_speed": 200.0},
		"8:8": {"kind": "hatch", "door": true, "tag": "HT-M", "open_dir": Vector2(-3.2, 0) * Geom.M, "cut_speed": 200.0},
		"10:1": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(-3.0, -0.4) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 220.0}, "HL")
	K.clamp(1, 44.0, 8.4, 8.2)
	K.clamp(2, 68.0, 8.4, 8.2)
	K.clamp(3, 92.0, 8.4, 8.2)


static func _inside() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	for b in [["W1", W1, 2], ["W2", W2, 3], ["W3", W3, 4]]:
		var bx: float = b[1]
		var top: float = _iy(b[2], bx + 0.2)
		var bot: float = _iy(10, bx + 0.2) if bx < 28.0 else BELLY
		var pc = K.plate(b[0], K.R(bx, top - 0.1, bx + 0.4, bot + 0.1), S, "bulkhead")
		K.bolt(pc, K.at(bx + 0.2, top - 0.25, ["hull"]), bx + 0.2, top, "weld")
		K.bolt(pc, K.at(bx + 0.2, bot + 0.25, ["hull"]), bx + 0.2, bot, "weld")
	# floor gratings in the equipment and mapping rooms (open: the bilge under them is the same room)
	var G := {"density": 0.8, "barrier": false, "cut_speed": 220.0}
	var bow := 0.771 + (EDECK - 0.63) / (7.97 - 0.63) * (10.18 - 0.771)
	var ed = K.plate("ED", K.R(bow, EDECK, W1, EDECK + 0.25), G, "rib")
	K.bolt(ed, K.at(bow - 0.25, EDECK + 0.12, ["hull"]), bow, EDECK + 0.12, "weld")
	K.bolt(ed, by_tag["W1"], W1, EDECK + 0.12, "weld")
	var md = K.plate("MD", K.R(W1 + 0.4, MDECK, W2, MDECK + 0.25), G, "rib")
	K.bolt(md, by_tag["W1"], W1 + 0.4, MDECK + 0.12, "weld")
	K.bolt(md, by_tag["W2"], W2, MDECK + 0.12, "weld")


# ---------------------------------------------------------------- the observation tower

static func _tower() -> void:
	var S := {"density": 1.3, "barrier": true, "cut_speed": 190.0}
	var tf = K.plate("T-F", K.mp([Vector2(24.0, -7.2), Vector2(27.0, -21.0), Vector2(27.4, -20.8), Vector2(24.4, -7.2)]), S.merged({"art": "window"}))
	var ts = K.plate("T-FS", K.mp([Vector2(27.0, -21.0), Vector2(34.0, -25.2), Vector2(34.0, -24.8), Vector2(27.4, -20.8)]), S.merged({"art": "window"}))
	var r1 = K.plate("T-R1", K.R(34.0, -25.2, 36.0, -24.8), S)
	var hc = K.plate("HT-C", K.R(36.0, -25.2, 37.8, -24.8), {"density": 1.0, "door": true, "open_dir": Vector2(-1.9, 0) * Geom.M, "cut_speed": 180.0}, "hatch")
	var r2 = K.plate("T-R2", K.R(37.8, -25.2, 43.0, -24.8), S)
	var ta = K.plate("T-AS", K.mp([Vector2(43.0, -25.2), Vector2(48.0, -21.0), Vector2(47.6, -20.8), Vector2(43.0, -24.8)]), S)
	var tw = K.plate("T-A", K.mp([Vector2(48.0, -21.0), Vector2(47.0, -6.45), Vector2(46.6, -6.51), Vector2(47.6, -20.8)]), S)
	K.bolt(tf, K.at(24.2, -6.95, ["hull"]), 24.2, -7.2, "weld")
	K.bolt(tw, K.at(46.8, -6.25, ["hull"]), 46.8, -6.48, "weld")
	K.bolt(ts, tf, 27.2, -20.9, "weld")
	K.bolt(ts, r1, 33.9, -24.95, "weld")
	K.bolt(hc, r1, 36.0, -25.0, "weld")
	K.bolt(hc, r2, 37.8, -25.0, "weld")
	K.bolt(ta, r2, 43.0, -25.0, "weld")
	K.bolt(ta, tw, 47.8, -20.9, "weld")
	# the cabin deck, its hatch down to the lower level
	var fx := 24.4 + (TDECK + 7.2) / (-20.8 + 7.2) * 3.0
	var ax := 46.6 + (TDECK + 6.51) / (-20.8 + 6.51) * 1.0
	var D := {"density": 1.0, "barrier": true, "cut_speed": 200.0}
	var d1 = K.plate("TD-1", K.R(fx, TDECK, 30.0, TDECK + 0.3), D, "deck")
	var dh = K.plate("DK-T", K.R(30.0, TDECK, 31.8, TDECK + 0.3), {"density": 1.0, "door": true, "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 190.0}, "hatch")
	var d2 = K.plate("TD-2", K.R(31.8, TDECK, ax, TDECK + 0.3), D, "deck")
	K.bolt(d1, tf, fx, TDECK + 0.15, "weld")
	K.bolt(d2, tw, ax, TDECK + 0.15, "weld")
	K.bolt(dh, d1, 30.0, TDECK + 0.15, "weld")
	K.bolt(dh, d2, 31.8, TDECK + 0.15, "weld")
	# the truss inside the lower level carries the cabin
	var tr = K.plate("T-TRUSS", K.R(33.0, TDECK + 0.3, 41.0, -7.2), {"density": 0.6, "barrier": false, "cut_speed": 170.0, "art": "", "name_key": "p_tower_truss"}, "beam")
	K.bolt(tr, d2, 37.0, TDECK + 0.3, "weld")
	K.bolt(tr, K.at(37.0, -6.95, ["hull"]), 37.0, -7.2, "weld")
	# the cabin: two seats, the survey console
	for i in 2:
		var sx := 33.2 + i * 5.0
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, TDECK - 1.5, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, TDECK + 0.15, ["deck"]), sx + 0.2, TDECK)
		K.bolt(st, K.at(sx + 0.6, TDECK + 0.15, ["deck"]), sx + 0.6, TDECK, "lock")
	var cn = K.equip("T-CON", "console", K.rect(34.4, TDECK - 1.6, 37.6, TDECK), {"mass": 0.3, "value": 5500.0, "fragile": 0.5, "room": "C", "name_key": "p_helm"})
	K.bolt(cn, d2, 35.0, TDECK)
	K.bolt(cn, d2, 37.0, TDECK)
	K.lamp("LAMP-C", 40.0, -24.8, "C", r2)
	K.lamp("LAMP-T", 30.0, TDECK + 0.3, "T", d1)


static func _array() -> void:
	var ms = K.equip("MAST", "", K.rect(38.0, -28.4, 38.8, -25.2), {"cls": "metal", "dest": "metal", "mass": 0.4, "cut_speed": 170.0, "name_key": "p_array_mast"})
	K.bolt(ms, by_tag["T-R2"], 38.4, -25.2, "weld")
	var dish = K.equip("ARRAY", "radar", K.rect(26.4, -37.8, 50.0, -28.4), {"mass": 2.6, "value": 30000.0, "fragile": 0.45, "name_key": "p_array"},
		K.mp([Vector2(35.0, -28.4), Vector2(27.5, -32.8), Vector2(26.4, -35.8), Vector2(33.0, -37.6), Vector2(42.0, -36.8), Vector2(50.0, -33.6), Vector2(44.0, -30.2), Vector2(41.0, -28.4)]))
	K.bolt(dish, ms, 38.2, -28.4)
	K.bolt(dish, ms, 38.6, -28.4)


# ---------------------------------------------------------------- the sensor bay on the roof aft

static func _sensor_bay() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 200.0}
	var sf = K.plate("S-F", K.mp([Vector2(55.0, -5.4), Vector2(61.0, -11.4), Vector2(61.4, -11.0), Vector2(55.6, -5.4)]), S)
	var s1 = K.plate("S-R1", K.R(61.0, -11.4, 72.0, -11.0), S)
	var hs = K.plate("HT-S", K.R(72.0, -11.4, 74.0, -11.0), {"density": 1.0, "door": true, "open_dir": Vector2(2.1, 0) * Geom.M, "cut_speed": 190.0}, "hatch")
	var s2 = K.plate("S-R2", K.R(74.0, -11.4, 88.0, -11.0), S)
	var sa = K.plate("S-A", K.mp([Vector2(88.0, -11.4), Vector2(91.0, -5.4), Vector2(90.5, -5.4), Vector2(87.8, -11.0)]), S)
	K.bolt(sf, K.at(55.3, -5.15, ["hull"]), 55.3, -5.4, "weld")
	K.bolt(sa, K.at(90.75, -5.15, ["hull"]), 90.75, -5.4, "weld")
	K.bolt(s1, sf, 61.2, -11.2, "weld")
	K.bolt(hs, s1, 72.0, -11.2, "weld")
	K.bolt(hs, s2, 74.0, -11.2, "weld")
	K.bolt(s2, sa, 87.9, -11.2, "weld")
	for i in 3:
		var x0 := 62.0 + i * 9.0
		var sn = K.equip("SEN-%d" % (i + 1), "nav_rack", K.rect(x0, -9.0, x0 + 6.0, -5.4), {"mass": 0.8, "value": 6500.0, "fragile": 0.5, "room": "S", "name_key": "p_sensor_head"})
		K.bolt(sn, K.at(x0 + 1.0, -5.15, ["hull"]), x0 + 1.0, -5.4)
		K.bolt(sn, K.at(x0 + 5.0, -5.15, ["hull"]), x0 + 5.0, -5.4)
	K.lamp("LAMP-S", 66.0, -11.0, "S", s1)


# ---------------------------------------------------------------- the equipment room and airlock

static func _equipment_room() -> void:
	var ed = by_tag["ED"]
	var rk = K.equip("EQR", "nav_rack", K.rect(11.0, 0.0, 15.0, EDECK), {"mass": 0.7, "value": 6000.0, "fragile": 0.45, "room": "E", "name_key": "p_parts_rack"})
	K.bolt(rk, ed, 11.6, EDECK)
	K.bolt(rk, ed, 14.4, EDECK)
	var sw = K.equip("SWB", "swb", K.rect(W1 - 1.8, -2.0, W1, 1.0), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "E", "name_key": "p_swb"})
	K.bolt(sw, by_tag["W1"], W1, -1.4)
	K.bolt(sw, by_tag["W1"], W1, 0.4)
	var bt = K.equip("BAT", "battery", K.rect(19.6, EDECK + 0.25, 24.6, _iy(10, 24.6) - 0.05), {"mass": 1.0, "value": 6000.0, "fragile": 0.4, "room": "E", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, ed, 20.2, EDECK + 0.25)
	K.bolt(bt, ed, 24.0, EDECK + 0.25)
	for i in 2:
		var lx := 16.0 + i * 1.5
		var lk = K.equip("SUIT-%d" % (i + 1), "locker", K.rect(lx, EDECK - 2.2, lx + 1.2, EDECK), {"mass": 0.15, "value": 1800.0, "fragile": 0.3, "room": "E", "name_key": "p_suit_locker"})
		K.bolt(lk, ed, lx + 0.6, EDECK, "lock")
	K.lamp("LAMP-E", 16.0, _iy(1, 16.0), "E", K.at(16.0, _iy(1, 16.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the mapping room

static func _mapping() -> void:
	var md = by_tag["MD"]
	for i in 2:
		var x0 := 27.4 + i * 9.0
		var mc = K.equip("MAP-%d" % (i + 1), "nav_rack", K.rect(x0, -2.4, x0 + 7.0, MDECK), {"mass": 1.6, "value": 15000.0, "fragile": 0.45, "room": "M", "name_key": "p_map_computer"})
		K.bolt(mc, md, x0 + 1.0, MDECK)
		K.bolt(mc, md, x0 + 6.0, MDECK)
	var sc = K.equip("SURVEY", "cabinet", K.rect(46.0, 1.2, 48.6, MDECK), {"mass": 0.3, "value": 9000.0, "fragile": 0.5, "room": "M", "mandatory": true, "name_key": "p_survey_log"})
	K.bolt(sc, md, 46.6, MDECK)
	K.bolt(sc, md, 48.0, MDECK, "lock")
	K.lamp("LAMP-M", 30.0, -6.75, "M", K.at(30.0, -6.95, ["hull"]))


# ---------------------------------------------------------------- the instrument cradle

static func _cradle() -> void:
	var B := {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_main_beam"}
	var mb = K.plate("MB-T", K.R(W2 + 0.4, -4.4, W3, -3.8), B, "beam")
	K.bolt(mb, by_tag["W2"], W2 + 0.4, -4.1, "weld")
	K.bolt(mb, by_tag["W3"], W3, -4.1, "weld")
	var cr = K.plate("CRADLE", K.R(53.6, -1.6, 83.4, -1.0), {"density": 1.4, "barrier": false, "cut_speed": 150.0, "name_key": "p_cradle"}, "rail")
	var k := 0
	for dx in [54.6, 63.6, 72.6, 81.6]:
		k += 1
		var dm = K.plate("DMP-%d" % k, K.R(dx, -3.8, dx + 0.3, -1.6), {"density": 1.0, "barrier": false, "cut_speed": 170.0, "name_key": "p_damper"}, "strut")
		K.bolt(dm, mb, dx + 0.15, -3.8, "weld")
		K.bolt(dm, cr, dx + 0.15, -1.6, "weld")
	for i in 3:
		var x0: float = OPTS[i]
		var op = K.equip("OPT-%d" % (i + 1), "nav", K.rect(x0, -1.0, x0 + 6.0, 3.8), {"mass": 1.4, "value": 16000.0, "fragile": 0.7, "room": "I", "name_key": "p_optics"})
		K.bolt(op, cr, x0 + 1.0, -1.0, "lock")
		K.bolt(op, cr, x0 + 5.0, -1.0, "lock")
	K.lamp("LAMP-I", 68.0, -4.95, "I", K.at(68.0, -5.15, ["hull"]))


# ---------------------------------------------------------------- the uninterruptible supply

static func _supply() -> void:
	var pl = K.plate("", K.R(89.6, 6.0, 98.4, BELLY), {"density": 1.4, "barrier": false, "cut_speed": 170.0}, "strut")
	K.bolt(pl, K.at(91.0, BELLY + 0.25, ["hull"]), 91.0, BELLY, "weld")
	K.bolt(pl, K.at(97.0, BELLY + 0.25, ["hull"]), 97.0, BELLY, "weld")
	var up = K.equip("UPS", "battery", K.rect(90.0, 0.6, 98.0, 6.0), {"mass": 2.8, "value": 12000.0, "fragile": 0.35, "room": "U", "hazard": "battery", "name_key": "p_ups"})
	K.bolt(up, pl, 91.0, 6.0)
	K.bolt(up, pl, 97.0, 6.0)
	K.lamp("LAMP-U", 92.0, -4.95, "U", K.at(92.0, -5.15, ["hull"]))


# ---------------------------------------------------------------- the near-field scanner under the bow

static func _scanner() -> void:
	var st: Array = []
	for sx in [14.0, 22.0]:
		var top := _oy(10, sx + 0.2)
		var s = K.plate("", K.R(sx, top - 0.1, sx + 0.4, 10.4), {"density": 1.4, "barrier": false, "cut_speed": 160.0, "name_key": "p_pylon"}, "beam")
		K.bolt(s, K.at(sx + 0.2, top - 0.25, ["hull"]), sx + 0.2, top, "weld")
		st.append(s)
	var sc = K.equip("SCAN", "radar", K.rect(12.0, 10.4, 24.0, 13.0), {"mass": 2.0, "value": 15000.0, "fragile": 0.45, "name_key": "p_scanner"},
		K.mp([Vector2(12.0, 10.4), Vector2(24.0, 10.4), Vector2(23.0, 13.0), Vector2(13.4, 13.0)]))
	K.bolt(sc, st[0], 14.2, 10.4)
	K.bolt(sc, st[1], 22.2, 10.4)


static func _engine() -> void:
	var en = K.equip("ENG", "eng_core", K.rect(108.55, -0.7, 121.0, 4.6), {"mass": 4.0, "value": 17000.0, "fragile": 0.3, "name_key": "p_engine_big"},
		K.mp([Vector2(108.55, -0.7), Vector2(121.0, -0.7), Vector2(121.0, 4.6), Vector2(110.05, 4.6)]))
	K.bolt(en, K.at(108.5, 0.5, ["hull"]), 108.85, 0.5)
	K.bolt(en, K.at(109.35, 3.6, ["hull"]), 109.7, 3.6)
	var nz = K.equip("NOZ", "nozzle", K.rect(121.0, -1.6, 126.0, 5.5), {"cls": "metal", "dest": "metal", "mass": 0.7, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(121.0, -0.2), Vector2(126.0, -1.6), Vector2(126.0, 5.5), Vector2(121.0, 4.1)]))
	K.bolt(nz, en, 121.0, 0.6)
	K.bolt(nz, en, 121.0, 3.4)


# ---------------------------------------------------------------- the fit-out (player 2026-10-19: fill the rooms with what a survey ship carries)

# equipment hung from the hull above (its top on inner edge i)
static func _hang(tag: String, art: String, x0: float, x1: float, y1: float, i: int, opts: Dictionary):
	var top: float = maxf(_iy(i, x0), _iy(i, x1))
	var p = K.equip(tag, art, K.rect(x0, top, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, K.at(x, _iy(i, x) - 0.2, ["hull"]), x, top)
	return p


# equipment standing on a piece below it (or hung under it)
static func _stand(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, base, opts: Dictionary, under := false):
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, base, x, y0 if under else y1)
	return p


static func _fitout() -> void:
	var ed = by_tag["ED"]
	var md = by_tag["MD"]
	# the equipment room: survey probes ready to launch, comms, air, oxygen, a sample
	# freezer, the calibration bench, fresh water under the grating
	for i in 3:
		var x0 := 8.0 + i * 0.95
		_stand("PROBE-%d" % (i + 1), "cap", x0, 4.4, x0 + 0.85, EDECK, ed, {"mass": 0.3, "value": 3500.0, "fragile": 0.5, "room": "E", "name_key": "p_survey_probe"})
	_hang("COMM-E", "nav", 11.2, 13.8, -3.6, 1, {"mass": 0.3, "value": 7000.0, "fragile": 0.5, "room": "E", "name_key": "p_comms"})
	_hang("AHU-E", "env", 15.0, 19.0, -3.4, 1, {"mass": 0.6, "value": 6000.0, "fragile": 0.4, "room": "E", "name_key": "p_ahu"})
	_hang("O2-E", "gastank", 19.6, 20.6, -3.0, 1, {"mass": 0.15, "value": 900.0, "fragile": 0.3, "room": "E", "hazard": "gas_tank", "name_key": "p_o2_bottle"})
	_hang("SAMPLE-F", "freezer", 21.0, 22.9, -3.4, 1, {"mass": 0.4, "value": 8000.0, "fragile": 0.45, "room": "E", "name_key": "p_sample_freezer"})
	_stand("BENCH-E", "cabinet", 19.4, 4.4, 22.9, EDECK, ed, {"mass": 0.4, "value": 4000.0, "fragile": 0.4, "room": "E", "name_key": "p_cal_bench"})
	_stand("WATER-E", "water", 11.0, EDECK + 0.25, 17.0, 8.05, ed, {"mass": 0.8, "value": 2500.0, "fragile": 0.3, "room": "E", "name_key": "p_water_tank"}, true)
	# the mapping room: the chart display over the consoles, the data racks, an
	# operator's seat; under the grating the computers' chiller, the inertial unit, the archive
	_hang("CHART", "screen", 27.0, 41.5, -5.9, 2, {"mass": 0.4, "value": 7000.0, "fragile": 0.6, "room": "M", "name_key": "p_chart_display"})
	_stand("DATA-1", "nav_rack", 44.0, -2.0, 45.7, MDECK, md, {"mass": 0.5, "value": 8000.0, "fragile": 0.45, "room": "M", "name_key": "p_data_rack"})
	_stand("DATA-2", "nav_rack", 49.0, -2.0, 51.4, MDECK, md, {"mass": 0.6, "value": 8000.0, "fragile": 0.45, "room": "M", "name_key": "p_data_rack"})
	var sm = K.seat("SEAT-M", Rect2(35.0, MDECK - 1.5, 0.8, 1.5), {"room": "M", "name_key": "p_seat_pilot"})
	K.bolt(sm, md, 35.2, MDECK)
	K.bolt(sm, md, 35.6, MDECK, "lock")
	_stand("CHILL-M", "pump", 28.5, MDECK + 0.25, 32.5, 7.2, md, {"mass": 0.6, "value": 6000.0, "fragile": 0.35, "room": "M", "name_key": "p_chiller"}, true)
	_stand("GYRO", "nav", 36.0, MDECK + 0.25, 39.0, 6.6, md, {"mass": 0.4, "value": 11000.0, "fragile": 0.6, "room": "M", "name_key": "p_inertial_unit"}, true)
	_stand("ARCHIVE", "vault", 44.0, MDECK + 0.25, 48.6, 7.4, md, {"mass": 1.2, "value": 9000.0, "fragile": 0.3, "room": "M", "name_key": "p_data_archive"}, true)
	# the cradle hall: an alignment bench under each instrument, thermal control at
	# each end, the optics' nitrogen purge
	for i in 3:
		var x0: float = OPTS[i] + 1.0
		var al = K.equip("ALIGN-%d" % (i + 1), "insp", K.rect(x0, 5.6, x0 + 4.0, BELLY), {"mass": 0.4, "value": 3500.0, "fragile": 0.5, "room": "I", "name_key": "p_align_bench"})
		K.bolt(al, K.at(x0 + 0.4, BELLY + 0.2, ["hull"]), x0 + 0.4, BELLY)
		K.bolt(al, K.at(x0 + 3.6, BELLY + 0.2, ["hull"]), x0 + 3.6, BELLY)
	for e in [["TCU-1", 52.4, 55.0], ["TCU-2", 82.2, 84.8]]:
		var tc = K.equip(e[0], "radiator", K.rect(e[1], 3.0, e[2], BELLY), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "I", "name_key": "p_thermal_unit"})
		K.bolt(tc, K.at(e[1] + 0.4, BELLY + 0.2, ["hull"]), e[1] + 0.4, BELLY)
		K.bolt(tc, K.at(e[2] - 0.4, BELLY + 0.2, ["hull"]), e[2] - 0.4, BELLY)
	var n2 = K.equip("N2-I", "gastank", K.rect(81.0, 3.6, 81.9, BELLY), {"mass": 0.15, "value": 900.0, "fragile": 0.3, "room": "I", "hazard": "gas_tank", "name_key": "p_n2_bottle"})
	K.bolt(n2, K.at(81.45, BELLY + 0.2, ["hull"]), 81.45, BELLY, "lock")
	# the supply room: the inverter and the battery management
	var iv = K.equip("INV", "swb", K.rect(98.8, 2.0, 101.3, 7.15), {"mass": 0.5, "value": 6000.0, "fragile": 0.4, "room": "U", "name_key": "p_inverter"})
	K.bolt(iv, K.at(100.6, _iy(7, 100.6) + 0.2, ["hull"]), 100.6, 7.15)
	K.bolt(iv, K.at(101.0, _iy(7, 101.0) + 0.2, ["hull"]), 101.0, 7.15)
	var bm = K.equip("BMS", "cabinet", K.rect(W3 + 0.4, -3.6, 88.4, 0.0), {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "U", "name_key": "p_bms"})
	K.bolt(bm, by_tag["W3"], W3 + 0.4, -3.0)
	K.bolt(bm, by_tag["W3"], W3 + 0.4, -0.6)
	# the sensor bay: its cooler; a mast on its roof
	var cs = K.equip("COOLER-S", "radiator", K.rect(86.2, -9.0, 87.6, -5.4), {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "S", "name_key": "p_sensor_cooler"})
	K.bolt(cs, K.at(86.5, -5.15, ["hull"]), 86.5, -5.4)
	K.bolt(cs, K.at(87.3, -5.15, ["hull"]), 87.3, -5.4)
	var mt = K.equip("MAST-S", "radar", K.rect(76.0, -13.6, 79.0, -11.4), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "name_key": "p_sensor_mast"})
	K.bolt(mt, by_tag["S-R2"], 76.6, -11.4)
	K.bolt(mt, by_tag["S-R2"], 78.4, -11.4)
	# the tower's lower level: its life support, the data link, a locker
	for e in [["LIFE-T", "env", 25.4, 28.6, -9.6, 7000.0, "p_life_support"], ["DATA-T", "nav_rack", 29.4, 32.4, -10.8, 7500.0, "p_data_link"], ["LOCKER-T", "locker", 42.0, 44.6, -10.2, 1500.0, "p_locker"]]:
		var tp = K.equip(e[0], e[1], K.rect(e[2], e[4], e[3], -7.2), {"mass": 0.4, "value": e[5], "fragile": 0.4, "room": "T", "name_key": e[6]})
		K.bolt(tp, K.at(e[2] + 0.3, -7.0, ["hull"]), e[2] + 0.3, -7.2)
		K.bolt(tp, K.at(e[2] + 1.0, -7.0, ["hull"]), e[2] + 1.0, -7.2)
	# the cabin: the observation scope, the navigation unit, the comms display under the roof
	var d1 = by_tag["TD-1"]
	var d2 = by_tag["TD-2"]
	_stand("OBS-SCOPE", "insp", 27.0, TDECK - 1.4, 29.6, TDECK, d1, {"mass": 0.3, "value": 9000.0, "fragile": 0.6, "room": "C", "name_key": "p_obs_scope"})
	_stand("NAV-C", "nav", 39.4, TDECK - 1.4, 42.0, TDECK, d2, {"mass": 0.3, "value": 8000.0, "fragile": 0.5, "room": "C", "name_key": "p_nav"})
	# the supply room's upper half: spares, a power board, the charge controller
	_hang("SPARE-U", "locker", 88.4, 90.9, -1.6, 4, {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "room": "U", "name_key": "p_locker"})
	_hang("PDU-U", "swb", 92.6, 95.2, -2.0, 5, {"mass": 0.3, "value": 4500.0, "fragile": 0.4, "room": "U", "name_key": "p_power_board"})
	_hang("CHG-U", "cap", 96.0, 99.6, -2.0, 5, {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "U", "name_key": "p_charge_ctrl"})
	# the tower cabin: the star tracker under the roof, the cabin's air
	var sk = K.equip("STAR-TRK", "insp", K.rect(34.2, -24.8, 35.8, -23.6), {"mass": 0.1, "value": 6000.0, "fragile": 0.6, "room": "C", "name_key": "p_star_tracker"})
	K.bolt(sk, by_tag["T-R1"], 34.5, -24.8)
	K.bolt(sk, by_tag["T-R1"], 35.5, -24.8)
	_stand("AIR-C", "env", 43.0, TDECK - 2.2, 45.8, TDECK, by_tag["TD-2"], {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "C", "name_key": "p_ahu"})
	var cm = K.equip("COMMS-C", "screen", K.rect(41.0, -24.8, 43.0, -23.8), {"mass": 0.1, "value": 3000.0, "fragile": 0.5, "room": "C", "name_key": "p_comms"})
	K.bolt(cm, by_tag["T-R2"], 41.4, -24.8)
	K.bolt(cm, by_tag["T-R2"], 42.6, -24.8)


static func _fit_lines() -> void:
	# the fit-out on the bus
	K.line("f1", "cable", "power", "SWB", Vector2(23.2, -1.6), "COMM-E", Vector2(13.8, -4.0), [Vector2(22.6, -1.6), Vector2(22.6, -2.6), Vector2(14.2, -2.6), Vector2(14.2, -4.0)])
	K.line("f2", "cable", "power", "COMM-E", Vector2(13.8, -3.8), "AHU-E", Vector2(15.0, -3.8))
	K.line("f3", "cable", "power", "AHU-E", Vector2(19.0, -3.6), "SAMPLE-F", Vector2(21.0, -3.6), [Vector2(19.3, -3.6), Vector2(19.3, -2.8), Vector2(20.8, -2.8), Vector2(20.8, -3.6)])
	K.line("f4", "cable", "power", "MAP-2", Vector2(40.0, -2.4), "CHART", Vector2(40.0, -5.9))
	K.line("f5", "cable", "power", "SURVEY", Vector2(46.0, 1.6), "DATA-1", Vector2(45.7, 1.6))
	K.line("f6", "cable", "power", "SURVEY", Vector2(48.6, 1.6), "DATA-2", Vector2(49.0, 1.6))
	K.line("f7", "cable", "power", "MAP-1", Vector2(32.0, MDECK), "CHILL-M", Vector2(32.0, MDECK + 0.25))
	K.line("f8", "cable", "power", "MAP-2", Vector2(37.4, MDECK), "GYRO", Vector2(37.4, MDECK + 0.25))
	K.line("f9", "cable", "power", "LAMP-I", Vector2(68.2, -4.79), "TCU-1", Vector2(53.6, 3.0), [Vector2(68.2, -4.6), Vector2(53.6, -4.6)])
	K.line("f10", "cable", "power", "LAMP-I", Vector2(67.8, -4.79), "TCU-2", Vector2(83.4, 3.0), [Vector2(67.8, -4.5), Vector2(83.4, -4.5)])
	K.line("f11", "cable", "power", "SEN-3", Vector2(86.0, -7.0), "COOLER-S", Vector2(86.2, -7.0))
	K.line("f12", "cable", "power", "LAMP-S", Vector2(66.2, -10.84), "MAST-S", Vector2(77.5, -11.4), [Vector2(77.5, -10.84)])
	K.line("f13", "cable", "power", "LAMP-T", Vector2(29.8, TDECK + 0.46), "DATA-T", Vector2(30.9, -10.8), [Vector2(30.9, -13.6)])
	K.line("f14", "cable", "power", "DATA-T", Vector2(29.4, -9.0), "LIFE-T", Vector2(28.6, -9.0))
	K.line("f15", "cable", "power", "T-CON", Vector2(34.4, TDECK - 0.8), "OBS-SCOPE", Vector2(29.6, TDECK - 0.8))
	K.line("f16", "cable", "power", "T-CON", Vector2(37.6, TDECK - 0.6), "NAV-C", Vector2(39.4, TDECK - 0.6))
	K.line("f17", "cable", "power", "LAMP-C", Vector2(39.8, -24.64), "COMMS-C", Vector2(41.0, -24.3), [Vector2(39.8, -24.3)])
	K.line("f18", "cable", "power", "LAMP-U", Vector2(92.2, -4.79), "PDU-U", Vector2(93.0, -2.0), [Vector2(93.0, -4.6)])
	K.line("f19", "cable", "power", "PDU-U", Vector2(95.2, -2.4), "CHG-U", Vector2(96.0, -2.4))
	K.line("f20", "cable", "power", "NAV-C", Vector2(42.0, TDECK - 0.6), "AIR-C", Vector2(43.0, TDECK - 0.6))
	# the instruments' supply through its inverter, watched by the battery management
	K.line("u4", "cable", "power", "UPS", Vector2(98.0, 3.0), "INV", Vector2(98.8, 3.0))
	K.line("u5", "cable", "power", "UPS", Vector2(90.6, 0.6), "BMS", Vector2(87.6, 0.0), [Vector2(90.6, 0.3), Vector2(87.6, 0.3)])
	# the chiller's loop to the two map computers
	K.line("c1", "pipe", "mcool", "CHILL-M", Vector2(29.5, MDECK + 0.25), "MAP-1", Vector2(29.5, MDECK))
	K.line("c2", "pipe", "mcool", "CHILL-M", Vector2(32.5, 6.0), "MAP-2", Vector2(41.5, MDECK), [Vector2(41.5, 6.0)])

# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(20.6, EDECK + 0.25), "SWB", Vector2(24.0, 1.0), [Vector2(20.6, 5.0), Vector2(24.0, 5.0)])
	K.line("p2", "cable", "power", "SWB", Vector2(23.4, -1.0), "EQR", Vector2(15.0, 1.0), [Vector2(22.0, -1.0), Vector2(22.0, 1.0)])
	K.line("p3", "cable", "power", "SWB", Vector2(24.0, -2.0), "LAMP-E", Vector2(16.0, _iy(1, 16.0) + 0.16), [Vector2(24.0, -5.6), Vector2(16.0, -5.6)])
	K.line("p4", "cable", "power", "SWB", Vector2(24.6, -2.0), "LAMP-M", Vector2(30.0, -6.59), [Vector2(24.6, -6.3), Vector2(30.0, -6.3)])
	K.line("p5", "cable", "power", "LAMP-M", Vector2(30.2, -6.59), "MAP-1", Vector2(31.0, -2.4), [Vector2(31.0, -6.0)])
	K.line("p6", "cable", "power", "MAP-1", Vector2(34.4, -1.0), "MAP-2", Vector2(36.4, -1.0))
	K.line("p7", "cable", "power", "MAP-2", Vector2(43.4, -1.0), "SURVEY", Vector2(46.0, 2.0), [Vector2(45.0, -1.0), Vector2(45.0, 2.0)])
	# up into the tower through the roof by the truss
	K.line("p8", "cable", "power", "LAMP-M", Vector2(29.8, -6.59), "LAMP-T", Vector2(30.0, TDECK + 0.46), [Vector2(29.6, -6.0), Vector2(29.6, -7.4), Vector2(30.0, -7.4)])
	K.line("p9", "cable", "power", "LAMP-T", Vector2(30.2, TDECK + 0.46), "T-CON", Vector2(36.0, TDECK - 1.6), [Vector2(32.8, -13.6), Vector2(32.8, -16.4), Vector2(36.0, -16.4)])
	K.line("p10", "cable", "power", "T-CON", Vector2(37.6, TDECK - 1.0), "LAMP-C", Vector2(40.0, -24.64), [Vector2(40.0, TDECK - 1.0)])
	K.line("p11", "cable", "power", "LAMP-C", Vector2(40.2, -24.64), "ARRAY", Vector2(38.8, -28.6), [Vector2(40.2, -25.0), Vector2(39.0, -25.0), Vector2(39.0, -28.6)])
	# aft along the mapping room's floor to the sensor bay
	K.line("p12", "cable", "power", "SURVEY", Vector2(48.6, 3.0), "SEN-1", Vector2(63.0, -5.4), [Vector2(50.6, 3.0), Vector2(50.6, -4.7), Vector2(63.0, -4.7)])
	K.line("p13", "cable", "power", "SEN-1", Vector2(68.0, -5.4), "SEN-2", Vector2(72.0, -5.4), [Vector2(68.0, -4.75), Vector2(72.0, -4.75)])
	K.line("p14", "cable", "power", "SEN-2", Vector2(77.0, -5.4), "SEN-3", Vector2(81.0, -5.4), [Vector2(77.0, -4.75), Vector2(81.0, -4.75)])
	K.line("p15", "cable", "power", "SEN-3", Vector2(84.0, -5.4), "LAMP-S", Vector2(66.0, -10.84), [Vector2(84.0, -10.6), Vector2(66.0, -10.6)])
	K.line("p16", "cable", "power", "SCAN", Vector2(18.0, 10.4), "BAT", Vector2(20.0, _iy(10, 20.0) - 0.05), [Vector2(18.0, 9.0), Vector2(20.0, 9.0)])
	# the instruments' own supply
	K.line("u1", "cable", "power", "UPS", Vector2(90.0, 2.0), "OPT-3", Vector2(80.5, 2.0), [Vector2(86.0, 2.0)])
	K.line("u2", "cable", "power", "OPT-3", Vector2(74.5, 2.0), "OPT-2", Vector2(71.5, 2.0))
	K.line("u3", "cable", "power", "OPT-2", Vector2(65.5, 2.0), "OPT-1", Vector2(62.5, 2.0))
	# the hall's and the supply room's lamps are on the bus, down through the roof from the sensors
	K.line("p17", "cable", "power", "SEN-1", Vector2(66.0, -5.4), "LAMP-I", Vector2(68.0, -4.79), [Vector2(66.0, -4.85), Vector2(68.0, -4.85)])
	K.line("p18", "cable", "power", "SEN-3", Vector2(85.0, -5.4), "LAMP-U", Vector2(92.0, -4.79), [Vector2(85.0, -4.85), Vector2(92.0, -4.85)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-E", "port", K.at(6.0, _iy(0, 6.0) - 0.25, ["hull"]), Vector2(5.8, _iy(0, 6.0) - 0.75), {"medium": "gas", "target": "E"})
	K.ctrl("G-M", "port", K.at(44.0, BELLY + 0.25, ["hull"]), Vector2(44.0, 8.65), {"medium": "gas", "target": "M"})
	K.ctrl("G-I", "port", K.at(64.0, BELLY + 0.25, ["hull"]), Vector2(64.0, 8.65), {"medium": "gas", "target": "I"})
	K.ctrl("G-U", "port", K.at(96.0, _iy(5, 96.0) - 0.25, ["hull"]), Vector2(96.1, _iy(5, 96.0) - 0.7), {"medium": "gas", "target": "U"})
	K.ctrl("G-T", "port", by_tag["T-A"], Vector2(47.6, -12.0), {"medium": "gas", "target": "T"})
	K.ctrl("G-C", "port", by_tag["T-R1"], Vector2(35.0, -25.4), {"medium": "gas", "target": "C"})
	K.ctrl("G-S", "port", by_tag["S-R2"], Vector2(80.0, -11.6), {"medium": "gas", "target": "S"})
	var px = K.equip("PNL-X", "panel", K.rect(52.0, 8.4, 55.6, 8.9), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(52.4, 8.2, ["hull"]), 52.4, 8.4)
	K.bolt(px, K.at(55.2, 8.2, ["hull"]), 55.2, 8.4)
	K.ctrl("K-M", "switch", px, Vector2(52.4, 8.65), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(53.6, 8.65), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(55.2, 8.65), {"target": "aux", "state": false})
	for h in [["HT-T", "M"], ["HT-U", ""], ["HT-M", ""], ["HT-E", ""], ["HT-C", ""], ["HT-S", ""], ["DK-T", "T"]]:
		K.door(h[0], h[1])
	K.ctrl("K-UPS", "switch", by_tag["UPS"], Vector2(91.0, 1.2), {"target": "K-UPS", "state": true, "hidden_room": "U"})
	K.ctrl("E-U", "test", by_tag["UPS"], Vector2(96.0, 1.2), {"medium": "volt", "target": "UPS", "hidden_room": "U"})
	for i in 3:
		var x0: float = OPTS[i]
		K.ctrl("DL-%d" % (i + 1), "switch", by_tag["CRADLE"], Vector2(x0 + 3.0, -1.3), {"target": "DL-%d" % (i + 1), "state": true, "hidden_room": "I"})
	K.ctrl("PO2", "port", by_tag["O2-E"], Vector2(20.1, -3.4), {"medium": "gas", "target": "O2E", "hidden_room": "E"})
	K.ctrl("PN2", "port", by_tag["N2-I"], Vector2(81.45, 4.0), {"medium": "gas", "target": "N2I", "hidden_room": "I"})
	K.ctrl("PW-E", "port", by_tag["WATER-E"], Vector2(14.0, 7.6), {"medium": "water", "target": "water", "hidden_room": "E"})
	K.ctrl("PCM", "port", by_tag["CHILL-M"], Vector2(30.5, 6.8), {"medium": "coolant", "target": "mcool", "hidden_room": "M"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	w.add_room("E", K.mp([inn[0], inn[1], inn[2], Vector2(W1, -6.75), at.call(10, W1), inn[11]]))
	w.add_room("M", K.mp([Vector2(W1 + 0.4, -6.75), inn[3], at.call(3, W2), Vector2(W2, BELLY), inn[9], inn[10], at.call(10, W1 + 0.4)]))
	w.add_room("I", K.mp([at.call(3, W2 + 0.4), inn[4], Vector2(W3, -4.95), Vector2(W3, BELLY), Vector2(W2 + 0.4, BELLY)]))
	w.add_room("U", K.mp([Vector2(W3 + 0.4, -4.95), inn[5], inn[6], inn[7], inn[8], Vector2(W3 + 0.4, BELLY)]))
	var fx := 24.4 + (TDECK + 7.2) / (-20.8 + 7.2) * 3.0
	var fx2 := 24.4 + (TDECK + 0.3 + 7.2) / (-20.8 + 7.2) * 3.0
	var ax := 46.6 + (TDECK + 6.51) / (-20.8 + 6.51) * 1.0
	var ax2 := 46.6 + (TDECK + 0.3 + 6.51) / (-20.8 + 6.51) * 1.0
	w.add_room("T", K.mp([Vector2(24.4, -7.2), Vector2(fx2, TDECK + 0.3), Vector2(ax2, TDECK + 0.3), Vector2(46.6, -6.51), Vector2(42.0, -7.2)]))
	w.add_room("C", K.mp([Vector2(fx, TDECK), Vector2(27.4, -20.8), Vector2(34.0, -24.8), Vector2(43.0, -24.8), Vector2(47.6, -20.8), Vector2(ax, TDECK)]))
	w.add_room("S", K.mp([Vector2(55.6, -5.4), Vector2(61.4, -11.0), Vector2(87.8, -11.0), Vector2(90.5, -5.4)]))


static func meta() -> Dictionary:
	var rails := {}
	for i in 3:
		var n := str(i + 1)
		rails["OPT" + n] = {"lock": "DL-" + n, "boxes": ["OPT-" + n], "rails": ["CRADLE"], "out": [0.0, 0.0], "doors": [],
			"hangs": ["MB-T", "DMP-1", "DMP-2", "DMP-3", "DMP-4"], "say": "cradle"}
	return {
		"id": "sv122",
		"name": "SV-122 WATCHTOWER",
		"title": ["SV-122「望楼」测绘船 · 126 m", "SV-122 WATCHTOWER · SURVEY SHIP · 126 m"],
		"contract": "SV-122",
		"length": 126.0,
		"value": {"total": 438700.0, "metal": 34000.0},
		"clamps": [[44.0, 8.4], [68.0, 8.4], [92.0, 8.4]],
		"room_names": {"E": "room_svE", "M": "room_svM", "I": "room_svI", "U": "room_svU", "T": "room_svT", "C": "room_svC", "S": "room_svS"},
		"gas": {"rooms": {"E": 101.0, "M": 101.0, "I": 101.0, "U": 101.0, "T": 101.0, "C": 101.0, "S": 101.0}, "vessels": {"O2E": {"V": 0.08, "kpa": 8000.0, "piece": "O2-E", "burst": 200.0}, "N2I": {"V": 0.08, "kpa": 3000.0, "piece": "N2-I", "burst": 200.0}},
			"valves": [], "value": 2800.0},
		"fluids": {"volumes": {
			"water": {"fluid": "water", "amount": 0.3, "piece": "WATER-E", "port": "PW-E", "full": 0.4, "content": 1.0, "leak": 0.1, "pump": [0.15, 0.006]},
			"mcool": {"fluid": "coolant", "amount": 0.15, "piece": "CHILL-M", "port": "PCM", "full": 0.15, "nets": ["mcool"], "leak": 0.2, "pump": [0.2, 0.006]},
		}, "joins": [], "value": {"water": 600.0, "coolant": 900.0}},
		"rails": rails,
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			# the instruments' own uninterruptible supply, apart from the bus
			"isolated": [
				{"piece": "UPS", "volts": 220.0, "charge": 0.95, "switch": "K-UPS"},
			],
			"lamps": {"E": "LAMP-E", "M": "LAMP-M", "I": "LAMP-I", "U": "LAMP-U", "T": "LAMP-T", "C": "LAMP-C", "S": "LAMP-S"},
		},
		"ctrls_cfg": {"G-E": {"rate": 22.0}, "G-M": {"rate": 40.0}, "G-I": {"rate": 30.0}, "G-U": {"rate": 22.0}, "G-T": {"rate": 16.0}, "G-C": {"rate": 12.0}, "G-S": {"rate": 16.0}},
		"labels": {"BAT": "BAT", "SWB": "SWB", "UPS": "UPS", "SURVEY": "SURVEY", "ARRAY": "ARRAY", "SCAN": "SCAN", "MAP-1": "MAP", "MAP-2": "MAP"},
		"hints": {},
		"market": {
			"class": "SV", "name": ["望楼级测绘船", "WATCHTOWER-CLASS SURVEY SHIP"], "time": 56.0,
			"rooms": {"E": [0.2, 40.0, 101.0], "M": [0.2, 40.0, 101.0], "U": [0.2, 40.0, 101.0], "S": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {},
			"knockable": ["EQR", "MAP-1", "T-CON", "SEN-2"],
			"drift": [],
			"section_x": W3,
			"slots": {"hidden_damage": {"plates": ["HL8-1", "HL8-3", "HL8-5", "HL4-6"]},
				"fire_system": {"x": 86.4, "y0": 6.3, "y1": BELLY, "base": ["HL8-1", BELLY], "room": "U", "port": [86.8, 6.37]}},
			"mechanisms": true,
		},
		"procedures": {
			"SURVEY": [
				{"do": "hose", "ctrl": "G-M"},
				{"do": "wait", "until": {"P": ["M", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-M"},
				{"do": "wait", "until": {"open": ["M"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "SURVEY"},
				{"do": "deliver", "piece": "SURVEY", "zone": "equip"},
			],
		},
	}
