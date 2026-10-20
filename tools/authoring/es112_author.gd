class_name Es112Author
# Authoring script for ES-112 "Iron Oath", a 115 m armoured custody transport (R2
# fleet, design/ships/全新舰队_R2_2026-10-18/ES-112_铁誓.md; lengths as drawn,
# heights at 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/es112.json.
# Metres, x bow (0) to the nozzles (115), y down.
#
# An armoured hull with a blunt bow of layered plate, the bridge sunk into the
# roof, the security room over its power room forward, two vaults with thick walls
# standing in the hull's middle, the mechanical release cabinet aft, two heavy
# engines on the stern, armour strakes along the roof and the belly.
# What it asks of you: each vault door is held by a lock solenoid on two circuits:
# the main bus, and the locks' own backup supply in the release cabinet, which
# also feeds back into the bus through them. With the main breaker open the bus
# test point outside reads dead, and the locks (and everything on the bus) are
# still live. Both dead, the cabinet's release levers will move; thrown, the vault
# door opens with no power of its own. Vent each vault through its own port
# first (the doors seal it); take the sealed custody boxes out whole.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.7
const OUT := [Vector2(0.0, -3.6), Vector2(7.0, -9.6), Vector2(28.0, -12.0), Vector2(78.0, -12.0), Vector2(95.0, -9.6), Vector2(102.0, -4.2),
	Vector2(102.0, 6.6), Vector2(93.0, 10.8), Vector2(28.0, 10.8), Vector2(8.0, 7.8), Vector2(0.0, 3.0)]
const B1 := 19.6                 # the bow's armour | security (to 20.0)
const B2 := 40.6                 # security | vault one (to 41.0), open at the vault door
const B3 := 90.0                 # vault two | the release cabinet (to 90.4), open at the vault door
const SDECK := 3.6               # security's floor (to 3.9), the power room under it
const ROOF := -11.3
const BELLY := 10.1
const VAULTS := [[41.0, 65.0, "1", true], [66.0, 90.0, "2", false]]   # x0, x1, n, door forward
const VW := 1.0                  # vault walls
const VTOP := -9.6
const VBOT := 8.4
const DOOR := [-3.0, 3.0]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "ES112")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	for v in VAULTS:
		_vault(v)
	_bridge()
	_security()
	_cabinet()
	_engines()
	_strakes()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "ES112")
	w = world
	_rooms()


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# ---------------------------------------------------------------- the armoured hull

static func _hull() -> void:
	K.ring(OUT, T, {
		1: [0.667, 0.781],
		2: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
		4: [0.5],
		7: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
		8: [0.2, 0.4],
	}, {
		"1:1": {"kind": "hatch", "door": true, "tag": "HT-S", "open_dir": Vector2(2.2, 0.2) * Geom.M, "cut_speed": 90.0, "art": ""},
		"4:0": {"kind": "hatch", "door": true, "tag": "HT-M", "open_dir": Vector2(-1.2, -0.8) * Geom.M, "cut_speed": 90.0, "art": ""},
		"8:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(-3.0, -0.5) * Geom.M, "cut_speed": 90.0, "art": ""},
	}, {"density": 2.2, "barrier": true, "cut_speed": 60.0, "art": "armor", "name_key": "p_armor"}, "HL")
	K.clamp(1, 36.0, 10.8, 10.4)
	K.clamp(2, 62.0, 10.8, 10.4)
	K.clamp(3, 86.0, 10.8, 10.4)


static func _inside() -> void:
	var S := {"density": 1.4, "barrier": true, "cut_speed": 180.0}
	var b1 = K.plate("B1", K.R(B1, _iy(1, B1 + 0.2) - 0.1, B1 + 0.4, _iy(8, B1 + 0.2) + 0.1), S, "bulkhead")
	K.bolt(b1, K.at(B1 + 0.2, _iy(1, B1 + 0.2) - 0.35, ["hull"]), B1 + 0.2, _iy(1, B1 + 0.2), "weld")
	K.bolt(b1, K.at(B1 + 0.2, _iy(8, B1 + 0.2) + 0.35, ["hull"]), B1 + 0.2, _iy(8, B1 + 0.2), "weld")
	# the bow's layered armour: three thick plates across it
	for i in 3:
		var ax := 5.0 + i * 5.0
		var top: float = _iy(0, ax + 0.2) if ax < 7.2 else _iy(1, ax + 0.2)
		var bot: float = _iy(9, ax + 0.2) if ax < 8.2 else _iy(8, ax + 0.2)
		var ar = K.plate("BA-%d" % (i + 1), K.R(ax, top - 0.1, ax + 0.4, bot + 0.1), {"density": 2.6, "barrier": false, "cut_speed": 40.0, "art": "armor", "name_key": "p_bow_armor"}, "bulkhead")
		K.bolt(ar, K.at(ax + 0.2, top - 0.35, ["hull"]), ax + 0.2, top, "weld")
		K.bolt(ar, K.at(ax + 0.2, bot + 0.35, ["hull"]), ax + 0.2, bot, "weld")
	# B2 and B3, open where the vault doors stand
	for b in [["B2", B2], ["B3", B3]]:
		var bx: float = b[1]
		var top2: float = ROOF if bx < 78.0 else _iy(3, bx + 0.2)
		var bt = K.plate(b[0] + "-T", K.R(bx, top2 - 0.1, bx + 0.4, DOOR[0]), S, "bulkhead")
		var bb = K.plate(b[0] + "-B", K.R(bx, DOOR[1], bx + 0.4, BELLY + 0.1), S, "bulkhead")
		K.bolt(bt, K.at(bx + 0.2, top2 - 0.35, ["hull"]), bx + 0.2, top2, "weld")
		K.bolt(bb, K.at(bx + 0.2, BELLY + 0.35, ["hull"]), bx + 0.2, BELLY, "weld")
	# security's floor, the hatch down to the power room
	var D := {"density": 1.1, "barrier": true, "cut_speed": 200.0}
	var d1 = K.plate("SD-1", K.R(B1 + 0.4, SDECK, 30.0, SDECK + 0.3), D, "deck")
	var dh = K.plate("DK-H", K.R(30.0, SDECK, 31.8, SDECK + 0.3), {"density": 1.0, "door": true, "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 190.0}, "hatch")
	var d2 = K.plate("SD-2", K.R(31.8, SDECK, B2, SDECK + 0.3), D, "deck")
	K.bolt(d1, b1, B1 + 0.4, SDECK + 0.15, "weld")
	K.bolt(d2, by_tag["B2-B"], B2, SDECK + 0.15, "weld")
	K.bolt(dh, d1, 30.0, SDECK + 0.15, "weld")
	K.bolt(dh, d2, 31.8, SDECK + 0.15, "weld")


# ---------------------------------------------------------------- a vault

static func _vault(v: Array) -> void:
	var x0: float = v[0]
	var x1: float = v[1]
	var n: String = v[2]
	var fwd: bool = v[3]
	var A := {"density": 2.4, "barrier": true, "cut_speed": 35.0, "art": "armor", "name_key": "p_vault_wall"}
	var tp = K.plate("V%s-T" % n, K.R(x0, VTOP, x1, VTOP + VW), A)
	var bt = K.plate("V%s-B" % n, K.R(x0, VBOT - VW, x1, VBOT), A)
	# the end with the door, the blind end
	var dx: float = x0 if fwd else x1 - VW
	var bx: float = x1 - VW if fwd else x0
	var dt = K.plate("V%s-DT" % n, K.R(dx, VTOP + VW, dx + VW, DOOR[0]), A)
	var dd = K.plate("VD-" + n, K.R(dx, DOOR[0], dx + VW, DOOR[1]), {"density": 2.4, "door": true, "open_dir": Vector2(0, -(DOOR[1] - DOOR[0]) - 0.4) * Geom.M,
		"cut_speed": 30.0, "art": "vault", "name_key": "p_vault_door"}, "door")
	var db = K.plate("V%s-DB" % n, K.R(dx, DOOR[1], dx + VW, VBOT - VW), A)
	var bl = K.plate("V%s-E" % n, K.R(bx, VTOP + VW, bx + VW, VBOT - VW), A)
	for pr in [[dt, tp, dx + 0.5, VTOP + VW], [db, bt, dx + 0.5, VBOT - VW], [bl, tp, bx + 0.5, VTOP + VW], [bl, bt, bx + 0.5, VBOT - VW]]:
		K.bolt(pr[0], pr[1], pr[2], pr[3], "weld")
	K.bolt(dd, dt, dx + 0.5, DOOR[0], "weld")
	K.bolt(dd, db, dx + 0.5, DOOR[1], "weld")
	# it stands on posts off the belly and hangs from the roof
	for px in [x0 + 3.0, (x0 + x1) * 0.5, x1 - 3.4]:
		var po = K.plate("", K.R(px, VBOT, px + 0.4, BELLY), {"density": 1.4, "barrier": false, "cut_speed": 150.0}, "strut")
		K.bolt(po, bt, px + 0.2, VBOT, "weld")
		K.bolt(po, K.at(px + 0.2, BELLY + 0.35, ["hull"]), px + 0.2, BELLY, "weld")
		var top: float = ROOF if px < 78.0 else _iy(3, px + 0.2)
		var hg = K.plate("", K.R(px, top, px + 0.4, VTOP), {"density": 1.4, "barrier": false, "cut_speed": 150.0}, "strut")
		K.bolt(hg, tp, px + 0.2, VTOP, "weld")
		K.bolt(hg, K.at(px + 0.2, top - 0.35, ["hull"]), px + 0.2, top, "weld")
	# the shelf, four sealed custody boxes
	var ix0 := x0 + VW
	var ix1 := x1 - VW
	var sh = K.plate("", K.R(ix0, 1.0, ix1, 1.3), {"density": 1.2, "barrier": false, "cut_speed": 170.0}, "rail")
	K.bolt(sh, bl, ix1 if fwd else ix0, 1.15, "weld")
	# at the door end it stands on a post off the floor (the door itself swings clear)
	var px := ix0 + 0.6 if fwd else ix1 - 1.0
	var sp = K.plate("", K.R(px, 1.3, px + 0.4, VBOT - VW), {"density": 1.0, "barrier": false, "cut_speed": 170.0}, "strut")
	K.bolt(sp, sh, px + 0.2, 1.3, "weld")
	K.bolt(sp, bt, px + 0.2, VBOT - VW, "weld")
	var k := 0
	for row in [[sh, 1.0], [bt, VBOT - VW]]:
		for c in 2:
			k += 1
			var cx := ix0 + 1.2 + c * 10.6
			var sb = K.equip("SAFE-%s%d" % [n, k], "cabinet", K.rect(cx, row[1] - 4.6, cx + 8.0, row[1]), {"mass": 2.2, "value": 11000.0, "fragile": 0.3, "room": "V" + n, "name_key": "p_safe_box"})
			K.bolt(sb, row[0], cx + 1.4, row[1], "lock")
			K.bolt(sb, row[0], cx + 6.6, row[1], "lock")
	K.lamp("LAMP-V" + n, (x0 + x1) * 0.5 + 4.0, VTOP + VW, "V" + n, tp)


# ---------------------------------------------------------------- the sunken bridge

static func _bridge() -> void:
	var S := {"density": 1.8, "barrier": true, "cut_speed": 80.0, "art": "armor", "name_key": "p_armor"}
	var bf = K.plate("BR-F", K.mp([Vector2(30.0, -12.0), Vector2(33.0, -15.0), Vector2(33.6, -14.4), Vector2(30.9, -12.0)]), {"density": 1.2, "barrier": true, "cut_speed": 120.0, "art": "window"})
	var r1 = K.plate("BR-R1", K.R(33.0, -15.0, 36.2, -14.4), S)
	var hb = K.plate("HATCH-B", K.R(36.2, -15.0, 38.2, -14.4), {"density": 1.4, "door": true, "open_dir": Vector2(1.8, 0) * Geom.M, "cut_speed": 90.0}, "hatch")
	var r2 = K.plate("BR-R2", K.R(38.2, -15.0, 42.0, -14.4), S)
	var ba = K.plate("BR-A", K.mp([Vector2(42.0, -15.0), Vector2(46.0, -12.0), Vector2(45.1, -12.0), Vector2(41.4, -14.4)]), S)
	K.bolt(bf, K.at(30.5, -11.7, ["hull"]), 30.5, -12.0, "weld")
	K.bolt(ba, K.at(45.5, -11.7, ["hull"]), 45.5, -12.0, "weld")
	K.bolt(r1, bf, 33.2, -14.7, "weld")
	K.bolt(hb, r1, 36.2, -14.7, "weld")
	K.bolt(hb, r2, 38.2, -14.7, "weld")
	K.bolt(r2, ba, 41.8, -14.7, "weld")
	var fl := -12.0
	for i in 2:
		var sx := 33.6 + i * 2.4
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, fl - 1.5, 0.8, 1.5), {"room": "B", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, fl + 0.3, ["hull"]), sx + 0.2, fl)
		K.bolt(st, K.at(sx + 0.6, fl + 0.3, ["hull"]), sx + 0.6, fl, "lock")
	var hm = K.equip("HELM", "console", K.rect(38.8, fl - 1.4, 41.0, fl), {"mass": 0.3, "value": 5000.0, "fragile": 0.5, "room": "B", "name_key": "p_helm"})
	K.bolt(hm, K.at(39.2, fl + 0.3, ["hull"]), 39.2, fl)
	K.bolt(hm, K.at(40.6, fl + 0.3, ["hull"]), 40.6, fl)
	var cu = K.equip("CUSTODY", "cabinet", K.rect(41.4, fl - 1.6, 43.2, fl), {"mass": 0.2, "value": 9000.0, "fragile": 0.5, "room": "B", "mandatory": true, "name_key": "p_custody"})
	K.bolt(cu, K.at(41.8, fl + 0.3, ["hull"]), 41.8, fl)
	K.bolt(cu, K.at(42.8, fl + 0.3, ["hull"]), 42.8, fl, "lock")
	K.lamp("LAMP-B", 34.6, -14.4, "B", r1)


# ---------------------------------------------------------------- security over the power room

static func _security() -> void:
	var cn = K.equip("S-CON", "console", K.rect(21.0, SDECK - 1.8, 24.6, SDECK), {"mass": 0.3, "value": 4500.0, "fragile": 0.5, "room": "S", "name_key": "p_sec_console"})
	K.bolt(cn, by_tag["SD-1"], 21.6, SDECK)
	K.bolt(cn, by_tag["SD-1"], 24.0, SDECK)
	for i in 3:
		var lx := 25.2 + i * 1.5
		var lk = K.equip("GUARD-%d" % (i + 1), "locker", K.rect(lx, SDECK - 2.2, lx + 1.2, SDECK), {"mass": 0.2, "value": 2200.0, "fragile": 0.3, "room": "S", "name_key": "p_guard_locker"})
		K.bolt(lk, by_tag["SD-1"], lx + 0.6, SDECK, "lock")
	var rk = K.equip("S-RACK", "nav_rack", K.rect(33.4, -3.0, 36.4, SDECK), {"mass": 0.5, "value": 7000.0, "fragile": 0.5, "room": "S", "name_key": "p_cic_rack"})
	K.bolt(rk, by_tag["SD-2"], 34.0, SDECK)
	K.bolt(rk, by_tag["SD-2"], 35.8, SDECK)
	# vault one's lock solenoid over its door, on B2
	var ls = K.equip("LS-1", "swb", K.rect(B2 - 1.4, -5.6, B2, -3.4), {"mass": 0.3, "value": 3000.0, "fragile": 0.4, "room": "S", "name_key": "p_lock_solenoid"})
	K.bolt(ls, by_tag["B2-T"], B2, -5.0)
	K.bolt(ls, by_tag["B2-T"], B2, -3.8)
	K.lamp("LAMP-S", 30.0, ROOF, "S", K.at(30.0, ROOF - 0.3, ["hull"]))
	# the power room under it
	var bt = K.equip("BAT", "battery", K.rect(30.0, 7.4, 37.0, BELLY), {"mass": 1.8, "value": 8000.0, "fragile": 0.35, "room": "P", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(30.6, BELLY + 0.35, ["hull"]), 30.6, BELLY)
	K.bolt(bt, K.at(36.4, BELLY + 0.35, ["hull"]), 36.4, BELLY)
	var sw = K.equip("SWB", "swb", K.rect(B1 + 0.4, SDECK + 0.3, 22.4, 6.8), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "P", "name_key": "p_swb"})
	K.bolt(sw, by_tag["B1"], B1 + 0.4, 4.6)
	K.bolt(sw, by_tag["B1"], B1 + 0.4, 6.2)
	K.lamp("LAMP-P", 26.0, SDECK + 0.3, "P", by_tag["SD-1"])


# ---------------------------------------------------------------- the release cabinet aft

static func _cabinet() -> void:
	var ls = K.equip("LS-2", "swb", K.rect(B3 + 0.4, -5.6, B3 + 1.8, -3.4), {"mass": 0.3, "value": 3000.0, "fragile": 0.4, "room": "M", "name_key": "p_lock_solenoid"})
	K.bolt(ls, by_tag["B3-T"], B3 + 0.4, -5.0)
	K.bolt(ls, by_tag["B3-T"], B3 + 0.4, -3.8)
	var mp = K.equip("MRP", "panel", K.rect(B3 + 0.4, 3.4, B3 + 1.2, 6.4), {"cls": "metal", "dest": "metal", "mass": 0.1, "room": "M", "cut_speed": 200.0, "name_key": "p_release_panel"})
	K.bolt(mp, by_tag["B3-B"], B3 + 0.4, 4.0)
	K.bolt(mp, by_tag["B3-B"], B3 + 0.4, 5.8)
	var lb = K.equip("LB", "battery", K.rect(99.4, 0.4, 101.3, 4.6), {"mass": 0.5, "value": 3500.0, "fragile": 0.4, "room": "M", "hazard": "battery", "name_key": "p_lock_ups"})
	K.bolt(lb, K.at(101.5, 1.2, ["hull"]), 101.3, 1.2)
	K.bolt(lb, K.at(101.5, 3.8, ["hull"]), 101.3, 3.8)
	K.lamp("LAMP-M", 94.0, _iy(3, 94.0), "M", K.at(94.0, _iy(3, 94.0) - 0.3, ["hull"]))


# ---------------------------------------------------------------- the stern engines

static func _engines() -> void:
	for e in [["U", -6.6, -0.6, [-3.6, -1.4]], ["L", 2.4, 8.4, [3.4, 5.8]]]:
		var y0: float = e[1]
		var y1: float = e[2]
		var en = K.equip("ENG-" + e[0], "eng_core", K.rect(102.0, y0, 110.0, y1), {"mass": 4.4, "value": 16000.0, "fragile": 0.3, "name_key": "p_engine"})
		for by in e[3]:
			K.bolt(en, K.at(101.7, by, ["hull"]), 102.0, by)
		var nz = K.equip("NOZ-" + e[0], "nozzle", K.rect(110.0, y0 - 0.6, 115.0, y1 + 0.6), {"cls": "metal", "dest": "metal", "mass": 0.7, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(110.0, y0 + 0.6), Vector2(115.0, y0 - 0.6), Vector2(115.0, y1 + 0.6), Vector2(110.0, y1 - 0.6)]))
		K.bolt(nz, en, 110.0, y0 + 1.6)
		K.bolt(nz, en, 110.0, y1 - 1.6)


# ---------------------------------------------------------------- armour strakes outside

static func _strakes() -> void:
	var A := {"density": 2.4, "barrier": false, "cut_speed": 45.0, "art": "armor", "name_key": "p_armor_strake"}
	var k := 0
	for sx in [[47.0, 59.0], [59.0, 71.0], [71.0, 77.4]]:
		k += 1
		var st = K.plate("STK-T%d" % k, K.R(sx[0], -13.8, sx[1], -12.0), A, "rib")
		K.bolt(st, K.at(sx[0] + 1.0, -11.7, ["hull"]), sx[0] + 1.0, -12.0)
		K.bolt(st, K.at(sx[1] - 1.0, -11.7, ["hull"]), sx[1] - 1.0, -12.0)
	k = 0
	for sx in [[32.0, 44.0], [44.0, 56.0], [56.0, 68.0], [68.0, 80.0], [80.0, 92.0]]:
		k += 1
		var st = K.plate("STK-B%d" % k, K.R(sx[0], 10.8, sx[1], 12.6), A, "rib")
		K.bolt(st, K.at(sx[0] + 1.0, 10.5, ["hull"]), sx[0] + 1.0, 10.8)
		K.bolt(st, K.at(sx[1] - 1.0, 10.5, ["hull"]), sx[1] - 1.0, 10.8)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(30.4, 7.4), "SWB", Vector2(22.4, 6.0), [Vector2(30.4, 6.0)])
	K.line("p2", "cable", "power", "SWB", Vector2(21.0, SDECK + 0.3), "S-CON", Vector2(22.0, SDECK), [Vector2(21.0, SDECK + 0.2), Vector2(22.0, SDECK + 0.2)])
	K.line("p3", "cable", "power", "S-CON", Vector2(24.6, 2.6), "S-RACK", Vector2(33.4, 2.6))
	K.line("p4", "cable", "power", "S-CON", Vector2(22.0, 1.8), "LAMP-S", Vector2(30.0, ROOF + 0.16), [Vector2(22.0, -10.6), Vector2(30.0, -10.6)])
	K.line("p5", "cable", "power", "LAMP-S", Vector2(30.2, ROOF + 0.16), "HELM", Vector2(39.6, -13.4), [Vector2(31.0, -10.7), Vector2(39.6, -10.7)])
	K.line("p6", "cable", "power", "HELM", Vector2(41.0, -12.8), "CUSTODY", Vector2(41.4, -12.8))
	K.line("p7", "cable", "power", "HELM", Vector2(39.0, -13.4), "LAMP-B", Vector2(34.6, -14.24), [Vector2(39.0, -14.0), Vector2(34.6, -14.0)])
	K.line("p8", "cable", "power", "SWB", Vector2(22.0, 6.8), "LAMP-P", Vector2(26.0, SDECK + 0.46), [Vector2(22.0, 7.0), Vector2(26.0, 7.0)])
	# lock circuit A: the bus, along the belly, to each vault's lock solenoid
	K.line("la1", "cable", "power", "SWB", Vector2(22.4, 5.0), "LS-1", Vector2(B2 - 0.7, -3.4), [Vector2(39.8, 5.0), Vector2(39.8, -3.2), Vector2(B2 - 0.7, -3.2)])
	K.line("la2", "cable", "power", "SWB", Vector2(21.6, 6.8), "LS-2", Vector2(B3 + 1.1, -3.4), [Vector2(21.6, 9.6), Vector2(91.0, 9.6), Vector2(91.0, -3.2)])
	K.line("la3", "cable", "power", "LS-2", Vector2(B3 + 1.8, -4.4), "LAMP-M", Vector2(94.0, _iy(3, 94.0) + 0.16), [Vector2(94.0, -4.4)])
	K.line("la4", "cable", "power", "LS-1", Vector2(B2 - 1.4, -4.4), "LAMP-V1", Vector2(57.0, VTOP + VW + 0.16), [Vector2(38.0, -4.4), Vector2(38.0, -10.9), Vector2(57.0, -10.9)])
	K.line("la5", "cable", "power", "LAMP-V1", Vector2(57.2, VTOP + VW + 0.16), "LAMP-V2", Vector2(82.0, VTOP + VW + 0.16), [Vector2(57.2, -10.9), Vector2(82.0, -10.9)])
	# lock circuit B: the locks' own backup supply in the cabinet, along the roof
	K.line("lb1", "cable", "power", "LB", Vector2(99.4, 1.0), "LS-2", Vector2(B3 + 1.8, -5.2), [Vector2(97.0, 1.0), Vector2(97.0, -5.2)])
	K.line("lb2", "cable", "power", "LS-2", Vector2(B3 + 1.0, -5.6), "LS-1", Vector2(B2 - 0.4, -5.6), [Vector2(B3 + 1.0, -10.6), Vector2(B2 - 0.4, -10.6)])
	# each solenoid to its door's bolts
	K.line("ld1", "cable", "power", "LS-1", Vector2(B2, -3.6), "VD-1", Vector2(41.5, -2.8), [Vector2(41.5, -3.6)])
	K.line("ld2", "cable", "power", "LS-2", Vector2(B3 + 0.4, -3.6), "VD-2", Vector2(89.5, -2.8), [Vector2(89.5, -3.6)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-S", "port", K.at(25.0, _iy(1, 25.0) - 0.35, ["hull"]), Vector2(25.0, _iy(1, 25.0) - 0.95), {"medium": "gas", "target": "S"})
	K.ctrl("G-P", "port", K.at(26.0, _iy(8, 26.0) + 0.35, ["hull"]), Vector2(26.0, _iy(8, 26.0) + 0.95), {"medium": "gas", "target": "P"})
	K.ctrl("G-B", "port", by_tag["BR-R2"], Vector2(40.0, -15.15), {"medium": "gas", "target": "B"})
	K.ctrl("G-M", "port", K.at(100.0, _iy(4, 100.0) - 0.3, ["hull"]), Vector2(100.3, _iy(4, 100.0) - 0.9), {"medium": "gas", "target": "M"})
	# each vault's own port on its door wall, by its lock
	K.ctrl("G-V1", "port", by_tag["V1-DT"], Vector2(40.95, -6.4), {"medium": "gas", "target": "V1", "hidden_room": "S"})
	K.ctrl("G-V2", "port", by_tag["V2-DT"], Vector2(90.05, -6.4), {"medium": "gas", "target": "V2", "hidden_room": "M"})
	# the outside panel on the belly
	var px = K.equip("PNL-X", "panel", K.rect(28.4, 10.8, 31.6, 11.3), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(28.8, 10.5, ["hull"]), 28.8, 10.8)
	K.bolt(px, K.at(31.2, 10.5, ["hull"]), 31.2, 10.8)
	K.ctrl("K-M", "switch", px, Vector2(28.8, 11.05), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(29.9, 11.05), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(31.2, 11.05), {"target": "aux", "state": false})
	for h in [["HT-S", ""], ["HT-M", ""], ["HT-P", ""], ["HATCH-B", ""], ["DK-H", "S"], ["VD-1", "S"], ["VD-2", "M"]]:
		K.door(h[0], h[1])
	# in the cabinet: the backup supply's switch, the release levers, test points on both locks
	K.ctrl("K-LB", "switch", by_tag["LB"], Vector2(100.3, 4.2), {"target": "K-LB", "state": true, "hidden_room": "M"})
	K.ctrl("MR-1", "switch", by_tag["MRP"], Vector2(B3 + 0.8, 4.0), {"target": "MR-1", "state": false, "hidden_room": "M"})
	K.ctrl("MR-2", "switch", by_tag["MRP"], Vector2(B3 + 0.8, 5.6), {"target": "MR-2", "state": false, "hidden_room": "M"})
	K.ctrl("E-L1", "test", by_tag["LS-1"], Vector2(B2 - 0.7, -4.0), {"medium": "volt", "target": "LS-1", "hidden_room": "S"})
	K.ctrl("E-L2", "test", by_tag["LS-2"], Vector2(B3 + 1.1, -4.0), {"medium": "volt", "target": "LS-2", "hidden_room": "M"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	w.add_room("S", K.mp([at.call(1, B1 + 0.4), inn[2], Vector2(B2, ROOF), Vector2(B2, DOOR[0]), Vector2(41.0, DOOR[0]), Vector2(41.0, DOOR[1]), Vector2(B2, DOOR[1]),
		Vector2(B2, SDECK), Vector2(B1 + 0.4, SDECK)]))
	w.add_room("P", K.mp([Vector2(B1 + 0.4, SDECK + 0.3), Vector2(B2, SDECK + 0.3), Vector2(B2, BELLY), inn[8], at.call(8, B1 + 0.4)]))
	w.add_room("B", K.mp([Vector2(30.9, -12.0), Vector2(33.6, -14.4), Vector2(41.4, -14.4), Vector2(45.1, -12.0)]))
	for v in VAULTS:
		w.add_room("V" + v[2], K.R(v[0] + VW, VTOP + VW, v[1] - VW, VBOT - VW))
	w.add_room("M", K.mp([at.call(3, B3 + 0.4), inn[4], inn[5], inn[6], inn[7], Vector2(B3 + 0.4, BELLY), Vector2(B3 + 0.4, DOOR[1]), Vector2(B3, DOOR[1]), Vector2(B3, DOOR[0]), Vector2(B3 + 0.4, DOOR[0])]))


static func meta() -> Dictionary:
	var labels := {"BAT": "BAT", "SWB": "SWB", "LB": "LOCK UPS", "LS-1": "LOCK", "LS-2": "LOCK", "CUSTODY": "CUSTODY", "MRP": "RELEASE"}
	for v in VAULTS:
		for k in 4:
			labels["SAFE-%s%d" % [v[2], k + 1]] = "SEAL %s-%d" % [v[2], k + 1]
	return {
		"id": "es112",
		"name": "ES-112 IRON OATH",
		"title": ["ES-112「铁誓」装甲保管运输舰 · 115 m", "ES-112 IRON OATH · ARMOURED CUSTODY TRANSPORT · 115 m"],
		"contract": "ES-112",
		"length": 115.0,
		"value": {"total": 228000.0, "metal": 48000.0},
		"clamps": [[36.0, 10.8], [62.0, 10.8], [86.0, 10.8]],
		"room_names": {"S": "room_esS", "P": "room_esP", "B": "room_esB", "V1": "room_esV1", "V2": "room_esV2", "M": "room_esM"},
		"gas": {"rooms": {"S": 101.0, "P": 101.0, "B": 101.0, "V1": 101.0, "V2": 101.0, "M": 101.0}, "vessels": {}, "valves": [], "value": 1800.0},
		"vaults": {"VD-1": {"locks": ["LS-1"], "release": "MR-1"}, "VD-2": {"locks": ["LS-2"], "release": "MR-2"}},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			# the locks' own backup supply: it feeds the locks, and through them the bus
			"isolated": [
				{"piece": "LB", "volts": 220.0, "charge": 0.95, "switch": "K-LB"},
			],
			"lamps": {"S": "LAMP-S", "P": "LAMP-P", "B": "LAMP-B", "V1": "LAMP-V1", "V2": "LAMP-V2", "M": "LAMP-M"},
		},
		"ctrls_cfg": {"G-S": {"rate": 14.0}, "G-P": {"rate": 10.0}, "G-B": {"rate": 6.0}, "G-M": {"rate": 9.0}, "G-V1": {"rate": 18.0}, "G-V2": {"rate": 18.0}},
		"labels": labels,
		"hints": {},
		"market": {
			"class": "ES", "name": ["铁誓级装甲保管运输舰", "IRON OATH-CLASS CUSTODY TRANSPORT"], "time": 46.0,
			"rooms": {"S": [0.2, 40.0, 101.0], "P": [0.2, 40.0, 101.0], "B": [0.2, 40.0, 101.0], "M": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {},
			"knockable": ["S-CON", "S-RACK", "HELM"],
			"drift": [],
			"section_x": 66.0,
			"slots": {"hidden_damage": {"plates": ["HL7-2", "HL7-4", "HL7-6", "HL2-5"]}},
			"mechanisms": true,
		},
		"procedures": {
			"CUSTODY": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HATCH-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 5.0},
				{"do": "hose", "ctrl": "G-M"},
				{"do": "wait", "until": {"P": ["M", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-M"},
				{"do": "wait", "until": {"open": ["M"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "operate", "ctrl": "K-LB"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CUSTODY"},
				{"do": "deliver", "piece": "CUSTODY", "zone": "equip"},
			],
		},
	}
