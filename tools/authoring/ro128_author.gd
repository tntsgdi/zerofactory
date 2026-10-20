class_name Ro128Author
# Authoring script for RO-128 "Long Bridge", a 129 m roll-on roll-off carrier (R2
# fleet, design/ships/全新舰队_R2_2026-10-18/RO-128_长桥.md; lengths as drawn,
# heights at 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/ro128.json.
# Metres, x bow (0) to the nozzles (129), y down.
#
# A long hull: a hinged bow visor over the inner bow door, the through vehicle
# deck with four units of heavy engineering cargo, each on its own lock rail,
# the bearing deck girder under it all, the aft hydraulics and power room, the
# raised bridge aft on the roof, two engines on the stern.
# What it asks of you: each unit is held by its lock rail (the wrench can't undo
# it); released, it rolls forward along the deck and out through the bow, so the
# bow visor and the inner bow door must be open first (on the bus) and the front
# unit go first, or the one behind runs into it. Cut the vehicle deck or the
# bearing girder (or its posts) while units are still locked on and the deck
# sags: every locked unit is damaged. The visor hangs on its hinge on its own
# accumulator: bled and unpinned before its hinge comes out, or it springs.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(13.0, -9.92), Vector2(27.0, -10.8), Vector2(86.0, -10.8), Vector2(103.0, -8.4), Vector2(115.0, -4.2),
	Vector2(115.0, 6.0), Vector2(105.0, 10.8), Vector2(22.0, 10.8), Vector2(13.0, 8.49)]
const A1 := 93.0                 # the vehicle deck | aft (to 93.4)
const VDECK := 6.0               # the vehicle deck (to 6.4)
const BELLY := 10.35
const CARGO := [17.0, 35.0, 53.0, 71.0]   # each unit's forward end, 12 m long
const RAILY := 5.7               # the lock rails' top

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "RO128")
	w = world
	by_tag = K.by_tag
	_hull()
	_visor()
	_deck()
	_cargo()
	_bridge()
	_aft()
	_engines()
	_fitout()
	_lines()
	_fit_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "RO128")
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


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	K.ring(OUT, T, {
		1: [0.6, 0.63],
		3: [0.5],
		6: [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
		8: [0.12],
	}, {
		"1:1": {"kind": "hatch", "door": true, "tag": "HT-V", "open_dir": Vector2(2.0, 0) * Geom.M, "cut_speed": 200.0},
		"3:0": {"kind": "hatch", "door": true, "tag": "HT-U", "open_dir": Vector2(-1.8, -0.6) * Geom.M, "cut_speed": 200.0},
		"6:1": {"kind": "hatch", "door": true, "tag": "HT-U2", "open_dir": Vector2(-3.0, 0) * Geom.M, "cut_speed": 200.0},
		"8:0": {"tag": "SILL"},
		"8:1": {"kind": "door", "door": true, "tag": "BOWDOOR", "open_dir": Vector2(0, -17.0) * Geom.M, "cut_speed": 190.0, "density": 1.3, "name_key": "p_bow_seal"},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HL")
	K.clamp(1, 34.0, 10.8, 10.6)
	K.clamp(2, 62.0, 10.8, 10.6)
	K.clamp(3, 90.0, 10.8, 10.6)


# ---------------------------------------------------------------- the bow visor

static func _visor() -> void:
	var vz = K.plate("VISOR", K.mp([Vector2(0.0, -5.4), Vector2(8.0, -9.6), Vector2(13.0, -9.92), Vector2(13.0, 8.49), Vector2(8.0, 7.2), Vector2(0.0, 3.0)]),
		{"density": 0.5, "door": true, "barrier": true, "open_dir": Vector2(-2.0, -17.0) * Geom.M, "cut_speed": 170.0, "art": "", "name_key": "p_visor"}, "door")
	# hung on its hinge at the top, latched at the top and the sill
	K.bolt(vz, K.at(13.8, -9.75, ["hull"]), 13.0, -9.75, "bolt", "VH")
	K.bolt(vz, K.at(14.4, -9.75, ["hull"]), 13.0, -9.5, "lock", "VL-1")
	K.bolt(vz, by_tag["SILL"], 13.0, 7.6, "lock", "VL-2")


# ---------------------------------------------------------------- the decks

static func _deck() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	var a1 = K.plate("A1", K.R(A1, _iy(2, A1 + 0.2) - 0.1, A1 + 0.4, BELLY + 0.1), S, "bulkhead")
	K.bolt(a1, K.at(A1 + 0.2, _iy(2, A1 + 0.2) - 0.25, ["hull"]), A1 + 0.2, _iy(2, A1 + 0.2), "weld")
	K.bolt(a1, K.at(A1 + 0.2, BELLY + 0.25, ["hull"]), A1 + 0.2, BELLY, "weld")
	var vd = K.plate("VDECK", K.R(13.45, VDECK, A1, VDECK + 0.4), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "name_key": "p_vehicle_deck"}, "deck")
	K.bolt(vd, by_tag["SILL"], 13.45, VDECK + 0.2, "weld")
	K.bolt(vd, a1, A1, VDECK + 0.2, "weld")
	# the bearing girder along the bottom, posts up to the deck
	var kg = K.plate("KEEL", K.R(22.0, 9.4, 92.6, BELLY), {"density": 2.2, "barrier": false, "cut_speed": 120.0, "name_key": "p_bearing_keel"}, "keel")
	for kx in [24.0, 40.0, 56.0, 72.0, 90.0]:
		K.bolt(kg, K.at(kx, BELLY + 0.25, ["hull"]), kx, BELLY, "weld")
	var k := 0
	for px in [30.0, 50.0, 70.0, 88.0]:
		k += 1
		var po = K.plate("KP-%d" % k, K.R(px, VDECK + 0.4, px + 0.5, 9.4), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_bearing_keel"}, "strut")
		K.bolt(po, vd, px + 0.25, VDECK + 0.4, "weld")
		K.bolt(po, kg, px + 0.25, 9.4, "weld")


# ---------------------------------------------------------------- the cargo on its lock rails

static func _cargo() -> void:
	var vd = by_tag["VDECK"]
	var R := {"density": 1.2, "barrier": false, "cut_speed": 180.0, "name_key": "p_lock_rail"}
	var ends := [13.45, 33.0, 51.0, 69.0, 87.0]
	for i in 4:
		var n := str(i + 1)
		var rl = K.plate("RAIL-" + n, K.R(ends[i], RAILY, ends[i + 1], VDECK), R, "rail")
		K.bolt(rl, vd, ends[i] + 1.0, VDECK, "weld")
		K.bolt(rl, vd, ends[i + 1] - 1.0, VDECK, "weld")
		var x0: float = CARGO[i]
		var cg = K.equip("CARGO-" + n, "cargo", K.rect(x0, RAILY - 6.0, x0 + 12.0, RAILY), {"mass": 4.8, "value": 15000.0, "fragile": 0.35, "room": "V", "name_key": "p_ro_cargo"})
		K.bolt(cg, rl, x0 + 2.0, RAILY, "lock")
		K.bolt(cg, rl, x0 + 10.0, RAILY, "lock")
	K.lamp("LAMP-V1", 30.0, -10.35, "V", K.at(30.0, -10.55, ["hull"]))
	K.lamp("LAMP-V2", 70.0, -10.35, "V", K.at(70.0, -10.55, ["hull"]))


# ---------------------------------------------------------------- the raised bridge aft

static func _bridge() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 190.0}
	var bf = K.plate("BR-F", K.mp([Vector2(74.0, -10.8), Vector2(77.0, -16.2), Vector2(77.4, -15.8), Vector2(74.6, -10.8)]), S.merged({"art": "window"}))
	var r1 = K.plate("BR-R1", K.R(77.0, -16.2, 82.0, -15.8), S)
	var hb = K.plate("HT-B", K.R(82.0, -16.2, 83.8, -15.8), {"density": 1.0, "door": true, "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 180.0}, "hatch")
	var r2 = K.plate("BR-R2", K.R(83.8, -16.2, 90.0, -15.8), S)
	var y96 := _oy(2, 96.0)
	var ba = K.plate("BR-A", K.mp([Vector2(90.0, -16.2), Vector2(96.0, y96), Vector2(95.4, y96 - 0.1), Vector2(89.8, -15.8)]), S)
	K.bolt(bf, K.at(74.3, -10.55, ["hull"]), 74.3, -10.8, "weld")
	K.bolt(ba, K.at(95.7, y96 + 0.25, ["hull"]), 95.7, y96, "weld")
	K.bolt(r1, bf, 77.2, -16.0, "weld")
	K.bolt(hb, r1, 82.0, -16.0, "weld")
	K.bolt(hb, r2, 83.8, -16.0, "weld")
	K.bolt(r2, ba, 89.9, -16.0, "weld")
	for i in 2:
		var sx := 78.0 + i * 2.6
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, -12.3, 0.8, 1.5), {"room": "B", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, -10.55, ["hull"]), sx + 0.2, -10.8)
		K.bolt(st, K.at(sx + 0.6, -10.55, ["hull"]), sx + 0.6, -10.8, "lock")
	var hm = K.equip("HELM", "console", K.rect(83.6, -12.4, 86.6, -10.8), {"mass": 0.3, "value": 5500.0, "fragile": 0.5, "room": "B", "name_key": "p_helm"})
	K.bolt(hm, K.at(84.0, -10.55, ["hull"]), 84.0, -10.8)
	K.bolt(hm, K.at(86.2, -10.55, ["hull"]), 86.2, -10.8)
	var cl = K.equip("CARGOLOG", "cabinet", K.rect(87.4, -12.4, 89.0, _oy(2, 88.2)), {"mass": 0.15, "value": 7500.0, "fragile": 0.5, "room": "B", "mandatory": true, "name_key": "p_cargo_log"})
	K.bolt(cl, K.at(87.8, _oy(2, 87.8) + 0.25, ["hull"]), 87.8, _oy(2, 87.8))
	K.lamp("LAMP-B", 80.0, -15.8, "B", r1)


# ---------------------------------------------------------------- aft: the door hydraulics and power

static func _aft() -> void:
	var a1 = by_tag["A1"]
	var hp = K.equip("HPU-D", "gen", K.rect(101.2, 7.0, 104.8, BELLY), {"mass": 1.2, "value": 6500.0, "fragile": 0.35, "room": "U", "name_key": "p_door_hpu"})
	K.bolt(hp, K.at(101.8, BELLY + 0.25, ["hull"]), 101.8, BELLY)
	K.bolt(hp, K.at(104.2, BELLY + 0.25, ["hull"]), 104.2, BELLY)
	var ac = K.equip("ACC-D", "gastank", K.rect(94.0, 5.8, 95.6, BELLY), {"mass": 0.4, "value": 2400.0, "fragile": 0.3, "room": "U", "hazard": "gas_tank", "name_key": "p_accumulator"})
	K.bolt(ac, K.at(94.8, BELLY + 0.25, ["hull"]), 94.8, BELLY, "lock")
	var bt = K.equip("BAT", "battery", K.rect(A1 + 0.4, -3.6, 99.6, 2.4), {"mass": 1.6, "value": 7500.0, "fragile": 0.4, "room": "U", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, a1, A1 + 0.4, -2.6)
	K.bolt(bt, a1, A1 + 0.4, 1.4)
	var sw = K.equip("SWB", "swb", K.rect(A1 + 0.4, 3.0, 95.4, 5.8), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "U", "name_key": "p_swb"})
	K.bolt(sw, a1, A1 + 0.4, 3.6)
	K.bolt(sw, a1, A1 + 0.4, 5.2)
	K.lamp("LAMP-U", 99.0, _iy(2, 99.0), "U", K.at(99.0, _iy(2, 99.0) - 0.2, ["hull"]))


static func _engines() -> void:
	for e in [["U", -5.4, 1.8, [-3.6, 1.2]], ["L", 3.9, 9.3, [4.4, 5.6]]]:
		var y0: float = e[1]
		var y1: float = e[2]
		var en = K.equip("ENG-" + e[0], "eng_core", K.rect(115.0, y0, 124.0, y1), {"mass": 3.8, "value": 15000.0, "fragile": 0.3, "name_key": "p_engine"})
		for by in e[3]:
			K.bolt(en, K.at(114.75, by, ["hull"]), 115.0, by)
		var nz = K.equip("NOZ-" + e[0], "nozzle", K.rect(124.0, y0 - 0.6, 129.0, y1 + 0.6), {"cls": "metal", "dest": "metal", "mass": 0.6, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(124.0, y0 + 0.6), Vector2(129.0, y0 - 0.6), Vector2(129.0, y1 + 0.6), Vector2(124.0, y1 - 0.6)]))
		K.bolt(nz, en, 124.0, y0 + 1.4)
		K.bolt(nz, en, 124.0, y1 - 1.4)


# ---------------------------------------------------------------- the fit-out (player 2026-10-19: fill the rooms with what a ro-ro carries)

# equipment hung from the hull above (its top on inner edge i)
static func _hang(tag: String, art: String, x0: float, x1: float, y1: float, i: int, opts: Dictionary):
	var top: float = maxf(_iy(i, x0), _iy(i, x1))
	var p = K.equip(tag, art, K.rect(x0, top, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, K.at(x, _iy(i, x) - 0.2, ["hull"]), x, top)
	return p


# equipment standing on a piece below it (or hung under it)
static func _stand(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, base, opts: Dictionary, under := false, type := "bolt"):
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, base, x, y0 if under else y1, type)
	return p


const HDY := -5.6                # the hoistable car deck (to -5.2)
const HD := [[16.0, 36.0], [38.0, 58.0], [60.0, 80.0]]


static func _fitout() -> void:
	var vd = by_tag["VDECK"]
	# the hoistable car deck over the heavy units: three panels on hanger rods off the
	# roof, three cars lashed on each
	for i in 3:
		var x0: float = HD[i][0]
		var x1: float = HD[i][1]
		var n := str(i + 1)
		var pn = K.plate("HD-" + n, K.R(x0, HDY, x1, HDY + 0.4), {"density": 1.0, "barrier": false, "cut_speed": 200.0, "name_key": "p_hoist_deck"}, "deck")
		for rx in [x0 + 2.0, x1 - 2.4]:
			var ei := 0 if rx < 27.0 else 1
			var ry := maxf(_iy(ei, rx), _iy(ei, rx + 0.3))
			var rd = K.plate("", K.R(rx, ry, rx + 0.3, HDY), {"density": 1.4, "barrier": false, "cut_speed": 170.0, "name_key": "p_hanger"}, "strut")
			K.bolt(rd, K.at(rx + 0.15, _iy(ei, rx + 0.15) - 0.2, ["hull"]), rx + 0.15, ry, "weld")
			K.bolt(rd, pn, rx + 0.15, HDY, "weld")
		for c in 3:
			var cx := x0 + 0.8 + c * 6.4
			_stand("CAR-%d%d" % [i + 1, c + 1], "cargo", cx, HDY - 1.6, cx + 5.0, HDY, pn, {"mass": 1.4, "value": 5000.0, "fragile": 0.4, "room": "V", "name_key": "p_car"}, false, "lock")
	# under the roof: exhaust fans, the cameras, the drencher valves on the aft bulkhead
	for e in [["FAN-1", 24.0], ["FAN-2", 44.0], ["FAN-3", 64.6]]:
		_hang(e[0], "env", e[1], e[1] + 3.6, -8.6, 1, {"mass": 0.6, "value": 3500.0, "fragile": 0.35, "room": "V", "name_key": "p_deck_fan"})
	for e in [["CCTV-1", 36.4], ["CCTV-2", 58.4], ["CCTV-3", 82.0]]:
		_hang(e[0], "insp", e[1], e[1] + 1.2, -9.4, 1, {"mass": 0.05, "value": 2500.0, "fragile": 0.6, "room": "V", "name_key": "p_cargo_mon"})
	var dr = K.equip("DRENCH", "pump", K.rect(90.6, -8.0, A1, -4.4), {"mass": 0.8, "value": 4500.0, "fragile": 0.35, "room": "V", "name_key": "p_drencher"})
	K.bolt(dr, by_tag["A1"], A1, -7.4)
	K.bolt(dr, by_tag["A1"], A1, -5.0)
	# aft of the last unit: the deck tractor and the lashing gear
	_stand("TRACTOR", "module", 87.4, 3.4, 91.0, VDECK, vd, {"mass": 2.6, "value": 9000.0, "fragile": 0.3, "room": "V", "name_key": "p_deck_tractor"}, false, "lock")
	var ls = K.equip("LASH", "locker", K.rect(91.4, -2.4, A1, 2.8), {"mass": 0.5, "value": 2000.0, "fragile": 0.3, "room": "V", "name_key": "p_lashing"})
	K.bolt(ls, by_tag["A1"], A1, -1.8)
	K.bolt(ls, by_tag["A1"], A1, 2.2)
	# under the vehicle deck, on the bearing girder: the ballast pump and three ballast tanks
	var kg = by_tag["KEEL"]
	_stand("BPUMP", "pump", 24.0, 7.4, 29.4, 9.4, kg, {"mass": 1.2, "value": 6000.0, "fragile": 0.35, "name_key": "p_ballast_pump"})
	for e in [["BT-1", 32.0], ["BT-2", 52.0], ["BT-3", 72.0]]:
		_stand(e[0], "water", e[1], 6.8, e[1] + 9.0, 9.4, kg, {"mass": 1.8, "value": 3000.0, "fragile": 0.3, "name_key": "p_ballast"})
	# aft: the door controls and air under the roof, the emergency switchboard, the
	# thruster hydraulics and the tool locker on the stern wall
	_hang("AHU-U", "env", 94.2, 98.2, -6.4, 2, {"mass": 0.6, "value": 5000.0, "fragile": 0.4, "room": "U", "name_key": "p_ahu"})
	_hang("DOOR-CON", "screen", 99.6, 102.6, -6.6, 2, {"mass": 0.2, "value": 4500.0, "fragile": 0.5, "room": "U", "name_key": "p_ramp_ctrl"})
	_stand("EMG-SWB", "swb", 101.4, 5.0, 104.6, 7.0, by_tag["HPU-D"], {"mass": 0.6, "value": 5500.0, "fragile": 0.4, "room": "U", "name_key": "p_lv_dist"})
	var sg = K.equip("THR-HPU", "gen", K.rect(110.5, -2.4, 114.55, 1.6), {"mass": 1.4, "value": 7000.0, "fragile": 0.35, "room": "U", "name_key": "p_hpu"})
	K.bolt(sg, K.at(114.75, -1.8, ["hull"]), 114.55, -1.8)
	K.bolt(sg, K.at(114.75, 1.0, ["hull"]), 114.55, 1.0)
	var tl = K.equip("TOOLS-U", "locker", K.rect(112.0, 2.2, 114.55, 5.4), {"mass": 0.4, "value": 2500.0, "fragile": 0.3, "room": "U", "name_key": "p_locker"})
	K.bolt(tl, K.at(114.75, 2.8, ["hull"]), 114.55, 2.8)
	K.bolt(tl, K.at(114.75, 4.8, ["hull"]), 114.55, 4.8)
	# the bridge: radar and camera screens under the roof, the loading computer, comms, air
	_stand("RADAR-D", "radar", 77.4, -15.8, 79.4, -14.8, by_tag["BR-R1"], {"mass": 0.1, "value": 6000.0, "fragile": 0.5, "room": "B", "name_key": "p_radar"}, true)
	_stand("CCTV-B", "screen", 84.2, -15.8, 87.0, -14.6, by_tag["BR-R2"], {"mass": 0.1, "value": 3000.0, "fragile": 0.5, "room": "B", "name_key": "p_cargo_mon"}, true)
	_stand("LOADCOMP", "console", 81.7, -12.0, 83.4, -10.8, K.at(82.5, -10.55, ["hull"]), {"mass": 0.15, "value": 6500.0, "fragile": 0.5, "room": "B", "name_key": "p_load_mon"})
	for e in [["COMMS-B", "nav", 89.4, 91.4, -13.0, 5000.0, "p_comms"], ["AHU-B", "env", 91.8, 93.4, -11.9, 3000.0, "p_ahu"]]:
		var x0: float = e[2]
		var x1: float = e[3]
		var q = K.equip(e[0], e[1], K.rect(x0, e[4], x1, _oy(2, x1)), {"mass": 0.2, "value": e[5], "fragile": 0.45, "room": "B", "name_key": e[6]},
			K.mp([Vector2(x0, e[4]), Vector2(x1, e[4]), Vector2(x1, _oy(2, x1)), Vector2(x0, _oy(2, x0))]))
		for x in [x0 + 0.3, x1 - 0.3]:
			K.bolt(q, K.at(x, _oy(2, x) + 0.25, ["hull"]), x, _oy(2, x))


static func _fit_lines() -> void:
	# the deck's fans and cameras off its lamps
	K.line("f1", "cable", "power", "LAMP-V1", Vector2(29.8, -10.19), "FAN-1", Vector2(27.6, -9.0), [Vector2(29.8, -9.0)])
	K.line("f2", "cable", "power", "LAMP-V1", Vector2(30.2, -10.19), "CCTV-1", Vector2(36.4, -9.6), [Vector2(30.2, -9.6)])
	K.line("f3", "cable", "power", "CCTV-1", Vector2(37.6, -9.6), "FAN-2", Vector2(44.0, -9.6))
	K.line("f4", "cable", "power", "FAN-2", Vector2(47.6, -9.6), "CCTV-2", Vector2(58.4, -9.6))
	K.line("f5", "cable", "power", "CCTV-2", Vector2(59.6, -9.6), "FAN-3", Vector2(64.6, -9.6))
	K.line("f6", "cable", "power", "LAMP-V2", Vector2(70.2, -10.19), "CCTV-3", Vector2(82.0, -9.6), [Vector2(70.4, -9.6)])
	K.line("f7", "cable", "power", "CCTV-3", Vector2(83.2, -9.6), "DRENCH", Vector2(90.6, -7.4), [Vector2(86.0, -9.6), Vector2(86.0, -7.4)])
	# aft: the switchboard to the emergency board, the thruster unit, the door console, the air
	K.line("f8", "cable", "power", "SWB", Vector2(95.4, 5.4), "EMG-SWB", Vector2(101.4, 5.6), [Vector2(96.4, 5.4), Vector2(96.4, 5.6)])
	K.line("f9", "cable", "power", "HPU-D", Vector2(104.8, 8.0), "THR-HPU", Vector2(111.0, 1.6), [Vector2(111.0, 8.0)])
	K.line("f10", "cable", "power", "LAMP-U", Vector2(99.2, _iy(2, 99.0) + 0.16), "DOOR-CON", Vector2(100.0, -6.6), [Vector2(99.2, -6.0), Vector2(100.0, -6.0)])
	K.line("f11", "cable", "power", "LAMP-U", Vector2(98.8, _iy(2, 99.0) + 0.16), "AHU-U", Vector2(98.2, -7.0), [Vector2(98.8, -7.0)])
	# the bridge
	K.line("f12", "cable", "power", "LAMP-B", Vector2(79.8, -15.64), "RADAR-D", Vector2(79.4, -15.2), [Vector2(79.8, -15.2)])
	K.line("f13", "cable", "power", "HELM", Vector2(83.6, -11.4), "LOADCOMP", Vector2(83.4, -11.4))
	K.line("f14", "cable", "power", "HELM", Vector2(86.0, -12.4), "CCTV-B", Vector2(86.0, -14.6))
	K.line("f15", "cable", "power", "CARGOLOG", Vector2(89.0, -11.9), "COMMS-B", Vector2(89.4, -11.9))
	K.line("f16", "cable", "power", "COMMS-B", Vector2(91.4, -11.4), "AHU-B", Vector2(91.8, -11.4))
	# the ballast pump off the emergency board, under the deck; the ballast main
	K.line("f17", "cable", "power", "EMG-SWB", Vector2(101.4, 6.6), "BPUMP", Vector2(29.4, 8.4), [Vector2(100.6, 6.6), Vector2(100.6, 9.0), Vector2(92.4, 9.0), Vector2(30.0, 9.0), Vector2(30.0, 8.4)])
	K.line("w1", "pipe", "bal", "BPUMP", Vector2(29.4, 7.8), "BT-1", Vector2(32.0, 7.8))
	K.line("w2", "pipe", "bal", "BT-1", Vector2(41.0, 7.8), "BT-2", Vector2(52.0, 7.8))
	K.line("w3", "pipe", "bal", "BT-2", Vector2(61.0, 7.8), "BT-3", Vector2(72.0, 7.8))

# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(96.0, 2.4), "SWB", Vector2(94.4, 3.0), [Vector2(96.0, 2.7), Vector2(94.4, 2.7)])
	K.line("p2", "cable", "power", "SWB", Vector2(95.4, 4.0), "HPU-D", Vector2(102.0, 7.0), [Vector2(102.0, 4.0)])
	K.line("p3", "cable", "power", "SWB", Vector2(95.4, 5.0), "LAMP-U", Vector2(99.0, _iy(2, 99.0) + 0.16), [Vector2(99.0, 5.0)])
	K.line("p4", "cable", "power", "SWB", Vector2(94.0, 3.0), "LAMP-V2", Vector2(70.0, -10.19), [Vector2(94.0, 2.8), Vector2(92.6, 2.8), Vector2(92.6, -9.9), Vector2(70.0, -9.9)])
	K.line("p5", "cable", "power", "LAMP-V2", Vector2(69.8, -10.19), "LAMP-V1", Vector2(30.0, -10.19), [Vector2(69.8, -9.95), Vector2(30.0, -9.95)])
	K.line("p6", "cable", "power", "LAMP-V2", Vector2(70.2, -10.19), "HELM", Vector2(85.0, -12.4), [Vector2(70.2, -10.0), Vector2(85.0, -10.0)])
	K.line("p7", "cable", "power", "HELM", Vector2(86.6, -11.6), "CARGOLOG", Vector2(87.4, -11.6))
	K.line("p8", "cable", "power", "HELM", Vector2(84.2, -12.4), "LAMP-B", Vector2(80.0, -15.64), [Vector2(84.2, -15.2), Vector2(80.0, -15.2)])
	K.line("h1", "pipe", "hyd", "HPU-D", Vector2(101.2, 8.0), "ACC-D", Vector2(95.6, 8.0))


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-V", "port", K.at(50.0, -10.55, ["hull"]), Vector2(50.0, -11.05), {"medium": "gas", "target": "V"})
	K.ctrl("G-U", "port", K.at(112.0, _iy(3, 112.0) - 0.25, ["hull"]), Vector2(112.1, _oy(3, 112.0) - 0.2), {"medium": "gas", "target": "U"})
	K.ctrl("G-B", "port", by_tag["BR-R2"], Vector2(87.0, -16.4), {"medium": "gas", "target": "B"})
	var px = K.equip("PNL-X", "panel", K.rect(40.6, 10.8, 44.2, 11.3), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(41.0, 10.6, ["hull"]), 41.0, 10.8)
	K.bolt(px, K.at(43.8, 10.6, ["hull"]), 43.8, 10.8)
	K.ctrl("K-M", "switch", px, Vector2(41.0, 11.05), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(42.2, 11.05), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(43.8, 11.05), {"target": "aux", "state": false})
	for h in [["HT-U", ""], ["HT-U2", ""], ["HT-B", ""], ["HT-V", ""]]:
		K.door(h[0], h[1])
	K.ctrl("VISOR", "door", by_tag["VISOR"], Vector2(4.0, -7.4), {"target": "VISOR", "state": false})
	K.ctrl("BOWDOOR", "door", by_tag["BOWDOOR"], Vector2(13.5, -1.0), {"target": "BOWDOOR", "state": false, "hidden_room": "V"})
	for i in 4:
		var x0: float = CARGO[i]
		K.ctrl("LR-%d" % (i + 1), "switch", by_tag["RAIL-%d" % (i + 1)], Vector2(x0 + 6.0, RAILY + 0.15), {"target": "LR-%d" % (i + 1), "state": true, "hidden_room": "V"})
	K.ctrl("PA-D", "port", by_tag["ACC-D"], Vector2(94.8, 6.0), {"medium": "gas", "target": "ACC-D", "hidden_room": "U"})
	K.ctrl("PH", "port", by_tag["HPU-D"], Vector2(103.0, 7.2), {"medium": "hydraulic", "target": "hyd", "hidden_room": "U"})
	K.ctrl("T-VH", "probe", by_tag["VISOR"], Vector2(11.0, -8.6), {"medium": "tension", "target": "VH"})
	K.ctrl("PBT", "port", by_tag["BT-1"], Vector2(36.5, 7.0), {"medium": "water", "target": "ballast"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	w.add_room("V", K.mp([inn[0], inn[1], inn[2], at.call(2, A1), Vector2(A1, VDECK), Vector2(13.45, VDECK)]))
	w.add_room("U", K.mp([at.call(2, A1 + 0.4), inn[3], inn[4], inn[5], inn[6], Vector2(A1 + 0.4, BELLY)]))
	var y96 := _oy(2, 96.0)
	w.add_room("B", K.mp([Vector2(74.6, -10.8), Vector2(77.4, -15.8), Vector2(89.8, -15.8), Vector2(95.4, y96 - 0.1), Vector2(86.0, -10.8)]))


static func meta() -> Dictionary:
	var rails := {}
	for i in 4:
		var n := str(i + 1)
		rails["C" + n] = {"lock": "LR-" + n, "boxes": ["CARGO-" + n], "rails": ["RAIL-" + n], "out": [-2.4, 0.0], "doors": ["VISOR", "BOWDOOR"],
			"hangs": ["VDECK", "KEEL", "KP-1", "KP-2", "KP-3", "KP-4"], "say": "cargo"}
	return {
		"id": "ro128",
		"name": "RO-128 LONG BRIDGE",
		"title": ["RO-128「长桥」滚装运输船 · 129 m", "RO-128 LONG BRIDGE · RO-RO CARRIER · 129 m"],
		"contract": "RO-128",
		"length": 129.0,
		"value": {"total": 318200.0, "metal": 44000.0},
		"clamps": [[34.0, 10.8], [62.0, 10.8], [90.0, 10.8]],
		"room_names": {"V": "room_roV", "U": "room_roU", "B": "room_roB"},
		"gas": {"rooms": {"V": 101.0, "U": 101.0, "B": 101.0},
			"vessels": {"ACC-D": {"V": 0.08, "kpa": 1800.0, "piece": "ACC-D", "burst": 200.0}}, "valves": [], "value": 2400.0},
		"rails": rails,
		"preloads": {
			"VH": {"pins": ["VL-1", "VL-2"], "vessel": "ACC-D", "kpa": 300.0, "piece": "VISOR", "push": [-0.8, -0.6], "hits": "", "kn": 52.0},
		},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"V": "LAMP-V1", "U": "LAMP-U", "B": "LAMP-B"},
		},
		"fluids": {"volumes": {
			"hyd": {"fluid": "hydraulic", "amount": 0.5, "piece": "HPU-D", "content": 1.0, "leak": 0.12, "port": "PH", "pump": [0.12, 0.008]},
			"hyd_line": {"fluid": "hydraulic", "amount": 0.02, "nets": ["hyd"], "leak": 0.06, "leak_min": 0.004},
			"ballast": {"fluid": "water", "amount": 2.4, "piece": "BT-1", "port": "PBT", "full": 3.0, "content": 1.0, "nets": ["bal"], "leak": 0.2, "pump": [0.3, 0.01]},
		}, "joins": [], "value": {"hydraulic": 700.0, "water": 1200.0}},
		"ctrls_cfg": {"G-V": {"rate": 150.0}, "G-U": {"rate": 26.0}, "G-B": {"rate": 12.0}, "PA-D": {"rate": 0.4}},
		"labels": {"BAT": "BAT", "SWB": "SWB", "HPU-D": "HPU", "ACC-D": "ACC", "CARGOLOG": "CARGO LOG", "CARGO-1": "UNIT 1", "CARGO-2": "UNIT 2", "CARGO-3": "UNIT 3", "CARGO-4": "UNIT 4"},
		"hints": {},
		"market": {
			"class": "RO", "name": ["长桥级滚装运输船", "LONG BRIDGE-CLASS RO-RO CARRIER"], "time": 60.0,
			"rooms": {"V": [0.2, 40.0, 101.0], "U": [0.2, 40.0, 101.0], "B": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"hyd": [0.2, 0.5]}, "fill": {"hyd_line": "hyd"},
			"knockable": ["HELM", "SWB"],
			"drift": [],
			"section_x": 51.0,
			"slots": {"hidden_damage": {"plates": ["HL6-2", "HL6-4", "HL6-6", "HL1-0"]},
				"fire_system": {"x": 95.8, "y0": 8.6, "y1": BELLY, "base": ["HL6-2", BELLY], "room": "U", "port": [96.2, 8.67]}},
			"mechanisms": true,
		},
		"procedures": {
			"CARGOLOG": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CARGOLOG"},
				{"do": "deliver", "piece": "CARGOLOG", "zone": "equip"},
			],
		},
	}
