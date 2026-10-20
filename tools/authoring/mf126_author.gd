class_name Mf126Author
# Authoring script for MF-126 "Molten Ridge", a 129 m smelter ship (R2 fleet,
# design/ships/全新舰队_R2_2026-10-18/MF-126_熔脊.md; lengths as drawn, heights at
# 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/mf126.json.
# Metres, x bow (0) to the nozzle (129), y down.
#
# A feed intake cut into the bow with its rollers, the sealed control cab on the
# roof, the sorting and feed room (the feed ram, the conveyor, the sorter) over
# its power room, the insulated smelting hall with the furnace shell and its core
# under a thick insulated roof, the heat exchange room aft with two pumps, the
# coolant tank and the radiators outside; the engine on the stern.
# What it asks of you: the furnace is shut down but its core is still at 760 °C.
# It only cools while its heat-exchange pumps run (on the bus) and the cooling
# loop is still full. Open the main breaker, cut the loop or drain it while the
# core is over 350 °C and the thermal shock cracks it (less than half its value);
# lift it out over 150 °C and it cracks as it leaves its cradle. A probe on the
# shell reads it. Meanwhile the feed ram is still preloaded on its accumulator:
# bleed it and pull its pins before its pivot comes out.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, -2.4), Vector2(11.0, -8.4), Vector2(32.0, -9.6), Vector2(42.0, -13.2), Vector2(80.0, -13.2), Vector2(93.0, -9.6),
	Vector2(107.0, -5.4), Vector2(110.0, -3.0), Vector2(110.0, 9.0), Vector2(93.0, 12.0), Vector2(30.0, 12.0), Vector2(12.0, 7.8),
	Vector2(0.0, 4.2), Vector2(0.0, 2.4), Vector2(14.0, 2.4), Vector2(17.0, 0.0), Vector2(14.0, -2.4)]
const B1 := 17.6                 # the intake | sorting (to 18.0)
const B2 := 40.6                 # sorting | the smelting hall (to 41.0)
const B3 := 80.6                 # the smelting hall | heat exchange (to 81.0)
const SDECK := 4.8               # sorting's floor (to 5.1), the power room under it
const BELLY := 11.55

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "MF126")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	_cab()
	_intake()
	_sorting()
	_furnace()
	_heat_exchange()
	_engine()
	_fitout()
	_lines()
	_fit_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "MF126")
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
		2: [0.66, 0.84],
		3: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
		5: [0.5],
		9: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
		10: [0.4, 0.6],
	}, {
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-S", "open_dir": Vector2(1.6, -0.6) * Geom.M, "cut_speed": 200.0},
		"5:1": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(-1.8, -0.5) * Geom.M, "cut_speed": 200.0},
		"9:5": {"kind": "hatch", "door": true, "tag": "HT-F", "open_dir": Vector2(-3.0, 0) * Geom.M, "cut_speed": 200.0},
		"10:1": {"kind": "hatch", "door": true, "tag": "HT-L", "open_dir": Vector2(-3.0, -0.6) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HL")
	K.clamp(1, 36.0, 12.0, 11.8)
	K.clamp(2, 62.0, 12.0, 11.8)
	K.clamp(3, 88.0, 12.0, 11.8)


static func _inside() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	for b in [["B1", B1, 1, 10], ["B2", B2, 2, 9], ["B3", B3, 4, 9]]:
		var bx: float = b[1]
		var top: float = _iy(b[2], bx + 0.2)
		var bot: float = _iy(b[3], bx + 0.2) if bx < 30.0 else BELLY
		var pc = K.plate(b[0], K.R(bx, top - 0.1, bx + 0.4, bot + 0.1), S, "bulkhead")
		K.bolt(pc, K.at(bx + 0.2, top - 0.25, ["hull"]), bx + 0.2, top, "weld")
		K.bolt(pc, K.at(bx + 0.2, bot + 0.25, ["hull"]), bx + 0.2, bot, "weld")
	var sd = K.plate("SDECK", K.R(B1 + 0.4, SDECK, B2, SDECK + 0.3), {"density": 1.1, "barrier": true, "cut_speed": 220.0}, "deck")
	K.bolt(sd, by_tag["B1"], B1 + 0.4, SDECK + 0.15, "weld")
	K.bolt(sd, by_tag["B2"], B2, SDECK + 0.15, "weld")


# ---------------------------------------------------------------- the sealed control cab on the roof

static func _cab() -> void:
	var S := {"density": 1.3, "barrier": true, "cut_speed": 190.0}
	var y18 := _oy(1, 18.0)
	var y38 := _oy(2, 37.4)
	var y37 := _oy(2, 36.8)
	var cf = K.plate("CAB-F", K.mp([Vector2(18.0, y18), Vector2(23.0, -14.4), Vector2(23.4, -14.0), Vector2(18.6, y18)]), S.merged({"art": "window"}))
	var r1 = K.plate("CAB-R1", K.R(23.0, -14.4, 28.0, -14.0), S)
	var hc = K.plate("HT-C", K.R(28.0, -14.4, 29.8, -14.0), {"density": 1.0, "door": true, "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 180.0}, "hatch")
	var r2 = K.plate("CAB-R2", K.R(29.8, -14.4, 35.0, -14.0), S)
	var ca = K.plate("CAB-A", K.mp([Vector2(35.0, -14.4), Vector2(37.4, y38), Vector2(36.8, y37), Vector2(34.8, -14.0)]), S)
	K.bolt(cf, K.at(18.3, y18 + 0.25, ["hull"]), 18.3, y18, "weld")
	K.bolt(ca, K.at(37.1, _oy(2, 37.1) + 0.3, ["hull"]), 37.1, _oy(2, 37.1), "weld")
	K.bolt(r1, cf, 23.2, -14.2, "weld")
	K.bolt(hc, r1, 28.0, -14.2, "weld")
	K.bolt(hc, r2, 29.8, -14.2, "weld")
	K.bolt(r2, ca, 34.9, -14.2, "weld")
	for i in 2:
		var sx := 24.0 + i * 2.6
		var fl := _oy(1, sx + 0.4)
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, fl - 1.5, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
		K.bolt(st, K.at(sx + 0.2, fl + 0.25, ["hull"]), sx + 0.2, fl)
		K.bolt(st, K.at(sx + 0.6, fl + 0.25, ["hull"]), sx + 0.6, fl, "lock")
	var cn = K.equip("C-CON", "console", K.rect(29.6, _oy(1, 31.4) - 1.6, 32.0, _oy(1, 31.4)), {"mass": 0.3, "value": 5500.0, "fragile": 0.5, "room": "C", "name_key": "p_helm"})
	K.bolt(cn, K.at(30.0, _oy(1, 30.0) + 0.25, ["hull"]), 30.0, _oy(1, 30.0))
	var lg = K.equip("SMELTLOG", "cabinet", K.rect(33.0, _oy(2, 34.2) - 1.6, 34.4, _oy(2, 34.2)), {"mass": 0.15, "value": 7500.0, "fragile": 0.5, "room": "C", "mandatory": true, "name_key": "p_smelt_log"})
	K.bolt(lg, K.at(33.5, _oy(2, 33.5) + 0.3, ["hull"]), 33.5, _oy(2, 33.5))
	K.bolt(lg, K.at(34.0, _oy(2, 34.0) + 0.3, ["hull"]), 34.0, _oy(2, 34.0), "lock")
	K.lamp("LAMP-C", 26.0, -14.0, "C", r1)


# ---------------------------------------------------------------- the feed intake in the bow

static func _intake() -> void:
	for i in 3:
		var x0 := 3.0 + i * 5.0
		var rl = K.equip("IN-%d" % (i + 1), "drum", K.rect(x0, -2.4, x0 + 2.0, 2.4), {"cls": "metal", "dest": "metal", "mass": 0.5, "cut_speed": 150.0, "name_key": "p_roller"})
		K.bolt(rl, K.at(x0 + 1.0, -2.6, ["hull"]), x0 + 1.0, -2.4)
		K.bolt(rl, K.at(x0 + 1.0, 2.6, ["hull"]), x0 + 1.0, 2.4)


# ---------------------------------------------------------------- sorting and feed

static func _sorting() -> void:
	var cv = K.plate("CONV", K.R(B1 + 0.4, 0.6, B2, 1.2), {"density": 1.2, "barrier": false, "cut_speed": 180.0, "name_key": "p_conveyor"}, "rail")
	K.bolt(cv, by_tag["B1"], B1 + 0.4, 0.9, "weld")
	K.bolt(cv, by_tag["B2"], B2, 0.9, "weld")
	for i in 3:
		var rx := 22.0 + i * 6.5
		var rl = K.equip("RL-%d" % (i + 1), "drum", K.rect(rx - 0.9, 1.2, rx + 0.9, 3.0), {"cls": "metal", "dest": "metal", "mass": 0.25, "cut_speed": 160.0, "name_key": "p_roller"})
		K.bolt(rl, cv, rx, 1.2)
	var so = K.equip("SORT", "pump", K.rect(24.0, -6.0, 36.0, 0.6), {"mass": 2.9, "value": 13000.0, "fragile": 0.35, "room": "S", "name_key": "p_sorter"})
	K.bolt(so, cv, 25.0, 0.6)
	K.bolt(so, cv, 35.0, 0.6)
	# the feed ram off B1, pinned, on its own accumulator
	var fr = K.equip("FEED", "", K.rect(B1 + 0.4, 3.2, 23.0, 4.6), {"mass": 0.9, "value": 4500.0, "fragile": 0.3, "room": "S", "name_key": "p_feed_ram"})
	K.bolt(fr, by_tag["B1"], B1 + 0.4, 3.9, "bolt", "FR-P")
	K.bolt(fr, by_tag["SDECK"], 19.0, SDECK, "lock", "FR-L1")
	K.bolt(fr, by_tag["SDECK"], 22.0, SDECK, "lock", "FR-L2")
	var ac = K.equip("ACC-F", "gastank", K.rect(39.0, -3.0, B2, 0.6), {"mass": 0.25, "value": 1800.0, "fragile": 0.3, "room": "S", "hazard": "gas_tank", "name_key": "p_accumulator"})
	K.bolt(ac, by_tag["B2"], B2, -2.0)
	K.bolt(ac, cv, 39.8, 0.6, "lock")
	var cm = K.equip("CMOT", "pump", K.rect(36.6, 1.2, 40.4, 3.4), {"mass": 0.6, "value": 4000.0, "fragile": 0.35, "room": "S", "name_key": "p_motor"})
	K.bolt(cm, cv, 38.0, 1.2)
	K.bolt(cm, by_tag["B2"], B2, 2.6)
	K.lamp("LAMP-S", 30.0, _iy(1, 30.0), "S", K.at(30.0, _iy(1, 30.0) - 0.2, ["hull"]))
	# the power room under it
	var bt = K.equip("BAT", "battery", K.rect(30.0, 8.6, 38.0, BELLY), {"mass": 1.6, "value": 7500.0, "fragile": 0.4, "room": "L", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(31.0, BELLY + 0.25, ["hull"]), 31.0, BELLY)
	K.bolt(bt, K.at(37.0, BELLY + 0.25, ["hull"]), 37.0, BELLY)
	var sw = K.equip("SWB", "swb", K.rect(B2 - 2.2, SDECK + 0.3, B2, 7.6), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "L", "name_key": "p_swb"})
	K.bolt(sw, by_tag["B2"], B2, 6.0)
	K.bolt(sw, by_tag["B2"], B2, 7.2)
	K.lamp("LAMP-L", 26.0, SDECK + 0.3, "L", by_tag["SDECK"])


# ---------------------------------------------------------------- the smelting hall: the furnace

static func _furnace() -> void:
	var I := {"density": 1.4, "barrier": false, "cut_speed": 90.0, "art": "insul", "name_key": "p_furnace_shell"}
	var sh := [Vector2(47.0, -6.6), Vector2(73.0, -6.6), Vector2(77.0, -1.8), Vector2(73.0, 6.0), Vector2(47.0, 6.0), Vector2(44.0, -1.8)]
	# the shell: six thick insulated plates round the core
	var inn := K.inner(sh, 0.8)
	var prev = null
	var first = null
	for i in 6:
		var a: Vector2 = sh[i]
		var b: Vector2 = sh[(i + 1) % 6]
		var c: Vector2 = inn[(i + 1) % 6]
		var d: Vector2 = inn[i]
		var pc = K.plate("FS-%d" % (i + 1), K.mp([a, b, c, d]), I, "rib")
		if prev != null:
			K.bolt(prev, pc, a.x + (d.x - a.x) * 0.5, a.y + (d.y - a.y) * 0.5, "weld")
		else:
			first = pc
		prev = pc
	K.bolt(prev, first, (sh[0].x + inn[0].x) * 0.5, (sh[0].y + inn[0].y) * 0.5, "weld")
	# the shell stands on four legs off the belly
	for lx in [48.5, 54.4, 65.0, 71.5]:
		var lg = K.plate("", K.R(lx, 6.0, lx + 0.5, BELLY), {"density": 1.6, "barrier": false, "cut_speed": 150.0}, "strut")
		K.bolt(lg, by_tag["FS-4"], lx + 0.25, 6.0, "weld")
		K.bolt(lg, K.at(lx + 0.25, BELLY + 0.25, ["hull"]), lx + 0.25, BELLY, "weld")
	# the core in its cradle
	var cr = K.equip("CORE", "reactor", K.rect(51.0, -4.2, 69.0, 3.6), {"mass": 9.0, "value": 32000.0, "fragile": 0.25, "cut_speed": 60.0, "room": "F", "name_key": "p_furnace_core"})
	cr.set_meta("segments", [[57.0, -4.3, 57.0, 3.7], [63.0, -4.3, 63.0, 3.7]])
	for cx in [53.0, 60.0, 67.0]:
		var sd = K.plate("", K.R(cx - 0.3, 3.6, cx + 0.3, 5.2), {"density": 1.4, "barrier": false, "cut_speed": 150.0}, "strut")
		K.bolt(sd, by_tag["FS-4"], cx, 5.2, "weld")
		K.bolt(cr, sd, cx, 3.6)
	# the thick insulated roof over the hall, outside on the hull's top
	var R := {"density": 1.6, "barrier": false, "cut_speed": 80.0, "art": "insul", "name_key": "p_furnace_roof"}
	for i in 4:
		var x0 := 46.0 + i * 8.0
		var hp = K.plate("HS-%d" % (i + 1), K.R(x0, -16.4, x0 + 7.4, -13.2), R, "rib")
		K.bolt(hp, K.at(x0 + 1.0, -12.95, ["hull"]), x0 + 1.0, -13.2)
		K.bolt(hp, K.at(x0 + 6.4, -12.95, ["hull"]), x0 + 6.4, -13.2)
	K.lamp("LAMP-F", 60.0, -12.75, "F", K.at(60.0, -12.95, ["hull"]))


# ---------------------------------------------------------------- heat exchange and cooling aft

static func _heat_exchange() -> void:
	for i in 2:
		var x0 := 82.6 + i * 5.2
		var hx = K.equip("HX-%d" % (i + 1), "pump", K.rect(x0, 6.6, x0 + 4.6, BELLY), {"mass": 1.6, "value": 8000.0, "fragile": 0.35, "room": "H", "name_key": "p_heat_pump"})
		K.bolt(hx, K.at(x0 + 1.0, BELLY + 0.25, ["hull"]), x0 + 1.0, BELLY)
		K.bolt(hx, K.at(x0 + 3.6, BELLY + 0.25, ["hull"]), x0 + 3.6, BELLY)
	var ct = K.equip("CT", "gastank", K.rect(103.0, -2.4, 109.55, 4.6), {"mass": 1.2, "value": 3000.0, "fragile": 0.3, "room": "H", "name_key": "p_coolant_tank"})
	K.bolt(ct, K.at(109.75, -1.0, ["hull"]), 109.55, -1.0)
	K.bolt(ct, K.at(109.75, 3.6, ["hull"]), 109.55, 3.6)
	# radiators outside: over the aft top and under the belly
	var ru = K.equip("RAD-U", "radiator", K.rect(86.0, -12.4, 100.0, -10.6), {"cls": "metal", "dest": "metal", "mass": 0.9, "cut_speed": 170.0, "name_key": "p_radiator_fin"},
		K.mp([Vector2(86.0, _oy(4, 86.0) - 1.4), Vector2(100.0, _oy(5, 100.0) - 1.4), Vector2(100.0, _oy(5, 100.0)), Vector2(86.0, _oy(4, 86.0))]))
	K.bolt(ru, K.at(87.0, _oy(4, 87.0) + 0.25, ["hull"]), 87.0, _oy(4, 87.0))
	K.bolt(ru, K.at(99.0, _oy(5, 99.0) + 0.25, ["hull"]), 99.0, _oy(5, 99.0))
	var rd = K.equip("RAD-L", "radiator", K.rect(80.0, 12.0, 92.0, 13.6), {"cls": "metal", "dest": "metal", "mass": 0.9, "cut_speed": 170.0, "name_key": "p_radiator_fin"})
	K.bolt(rd, K.at(81.0, 11.8, ["hull"]), 81.0, 12.0)
	K.bolt(rd, K.at(91.0, 11.8, ["hull"]), 91.0, 12.0)
	K.lamp("LAMP-H", 95.0, _iy(5, 95.0), "H", K.at(95.0, _iy(5, 95.0) - 0.2, ["hull"]))


static func _engine() -> void:
	var en = K.equip("ENG", "eng_core", K.rect(110.0, -2.6, 124.0, 8.6), {"mass": 4.8, "value": 19000.0, "fragile": 0.3, "name_key": "p_engine_big"})
	K.bolt(en, K.at(109.75, -1.4, ["hull"]), 110.0, -1.4)
	K.bolt(en, K.at(109.75, 7.6, ["hull"]), 110.0, 7.6)
	var nz = K.equip("NOZ", "nozzle", K.rect(124.0, -3.6, 129.0, 9.6), {"cls": "metal", "dest": "metal", "mass": 0.9, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(124.0, -1.6), Vector2(129.0, -3.6), Vector2(129.0, 9.6), Vector2(124.0, 7.6)]))
	K.bolt(nz, en, 124.0, 0.0)
	K.bolt(nz, en, 124.0, 6.0)


# ---------------------------------------------------------------- the fit-out (player 2026-10-19: fill the rooms with what a smelter carries)

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
	var sd = by_tag["SDECK"]
	# the cab: comms and its own air under the roof
	_stand("COMMS-C", "screen", 30.4, -14.0, 32.4, -13.0, by_tag["CAB-R2"], {"mass": 0.1, "value": 3000.0, "fragile": 0.5, "room": "C", "name_key": "p_comms"}, true)
	_stand("AHU-C", "env", 32.8, -14.0, 34.8, -12.8, by_tag["CAB-R2"], {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "C", "name_key": "p_ahu"}, true)
	# sorting: the magnetic separator over the feed, the spectrometer by the sorter,
	# the sample bins and the tool locker on the deck under the conveyor
	_hang("MAG-SEP", "module", 19.0, 23.4, -5.4, 1, {"mass": 1.8, "value": 9000.0, "fragile": 0.35, "room": "S", "name_key": "p_mag_sep"})
	_hang("SPECTRO", "insp", 36.2, 38.2, -7.4, 2, {"mass": 0.3, "value": 12000.0, "fragile": 0.6, "room": "S", "name_key": "p_spectro"})
	_hang("CAM-S", "insp", 26.0, 29.0, -7.6, 1, {"mass": 0.15, "value": 4000.0, "fragile": 0.6, "room": "S", "name_key": "p_cargo_mon"})
	_hang("DUST-S", "overhead", 32.4, 35.6, -7.4, 2, {"mass": 0.6, "value": 3500.0, "fragile": 0.3, "room": "S", "name_key": "p_dust_filter"})
	_stand("BINS-S", "cargo", 24.0, 3.3, 27.0, SDECK, sd, {"mass": 0.8, "value": 3000.0, "fragile": 0.3, "room": "S", "name_key": "p_samples"})
	_stand("LOCK-S", "locker", 30.0, 3.2, 33.4, SDECK, sd, {"mass": 0.4, "value": 2000.0, "fragile": 0.3, "room": "S", "name_key": "p_locker"})
	# the power room: inverter, standby supply and charger under the deck, the battery's monitor on it
	_stand("INV-L", "swb", 19.0, SDECK + 0.3, 21.8, 6.8, sd, {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "L", "name_key": "p_inverter"}, true)
	_stand("UPS-L", "battery", 22.4, SDECK + 0.3, 25.4, 7.4, sd, {"mass": 0.7, "value": 6000.0, "fragile": 0.4, "room": "L", "name_key": "p_ups"}, true)
	_stand("CHG-L", "cap", 27.0, SDECK + 0.3, 29.6, 6.9, sd, {"mass": 0.4, "value": 4000.0, "fragile": 0.4, "room": "L", "name_key": "p_charge_ctrl"}, true)
	_stand("BMS-L", "panel", 31.0, 7.6, 33.0, 8.6, by_tag["BAT"], {"mass": 0.1, "value": 3500.0, "fragile": 0.5, "room": "L", "name_key": "p_bms"})
	# the smelting hall: fume hoods, the off-gas scrubber and bag filter under the roof,
	# pyrometers on the shell, the furnace control cabinet and the argon bank on the
	# walls, the slag carts under the furnace, the finished ingots on their racks
	_hang("FUME-1", "overhead", 46.5, 52.5, -10.8, 3, {"mass": 0.9, "value": 4000.0, "fragile": 0.3, "room": "F", "name_key": "p_fume_hood"})
	_hang("SCRUB", "filter", 54.0, 59.2, -9.4, 3, {"mass": 2.6, "value": 11000.0, "fragile": 0.35, "room": "F", "name_key": "p_scrubber"})
	_hang("BAGF", "filter", 61.0, 66.4, -10.2, 3, {"mass": 1.4, "value": 6000.0, "fragile": 0.35, "room": "F", "name_key": "p_dust_filter"})
	_hang("FUME-2", "overhead", 67.5, 73.5, -10.8, 3, {"mass": 0.9, "value": 4000.0, "fragile": 0.3, "room": "F", "name_key": "p_fume_hood"})
	for e in [["PYRO-1", 50.0], ["PYRO-2", 68.8]]:
		_stand(e[0], "insp", e[1], -7.6, e[1] + 1.2, -6.6, by_tag["FS-1"], {"mass": 0.1, "value": 3500.0, "fragile": 0.6, "room": "F", "name_key": "p_pyro"})
	var fc = K.equip("FCTL", "swb", K.rect(41.0, -5.0, 43.6, -0.5), {"mass": 0.6, "value": 9000.0, "fragile": 0.4, "room": "F", "name_key": "p_furnace_ctrl"})
	K.bolt(fc, by_tag["B2"], 41.0, -4.4)
	K.bolt(fc, by_tag["B2"], 41.0, -1.1)
	var ar = K.equip("ARGON", "gastank", K.rect(78.0, -4.5, B3, 0.5), {"mass": 0.6, "value": 2500.0, "fragile": 0.3, "room": "F", "hazard": "gas_tank", "name_key": "p_argon"})
	K.bolt(ar, by_tag["B3"], B3, -3.8)
	K.bolt(ar, by_tag["B3"], B3, -0.2)
	var mn = K.equip("MANI", "filter", K.rect(78.0, 1.5, B3, 5.0), {"mass": 0.5, "value": 3000.0, "fragile": 0.3, "room": "F", "name_key": "p_manifold"})
	K.bolt(mn, by_tag["B3"], B3, 2.0)
	K.bolt(mn, by_tag["B3"], B3, 4.5)
	for e in [["SLAG-1", 49.2, 54.0], ["SLAG-2", 65.7, 71.2]]:
		_stand(e[0], "cargo", e[1], 8.8, e[2], BELLY, K.at(e[1] + 1.0, BELLY + 0.25, ["hull"]), {"cls": "metal", "dest": "metal", "mass": 2.6, "cut_speed": 150.0, "name_key": "p_slag_car"})
	for e in [["INGOT-1", 41.4, 48.0], ["INGOT-2", 72.2, 77.4]]:
		_stand(e[0], "cargo", e[1], 8.0, e[2], BELLY, K.at(e[1] + 1.0, BELLY + 0.25, ["hull"]), {"mass": 2.8, "value": 14000.0, "fragile": 0.15, "room": "F", "name_key": "p_ingot_rack"})
	# heat exchange: pump controllers on the pumps, the panel on the bulkhead, the
	# expansion tank and the degasser under the roof, the steam drum, the booster pump
	_stand("HXC-1", "panel", 83.2, 5.0, 85.6, 6.6, by_tag["HX-1"], {"mass": 0.2, "value": 3000.0, "fragile": 0.45, "room": "H", "name_key": "p_flow_ctrl"})
	_stand("HXC-2", "panel", 88.4, 5.0, 90.8, 6.6, by_tag["HX-2"], {"mass": 0.2, "value": 3000.0, "fragile": 0.45, "room": "H", "name_key": "p_flow_ctrl"})
	var hm = K.equip("HMI-H", "screen", K.rect(B3 + 0.4, -5.0, 82.4, -2.0), {"mass": 0.1, "value": 2500.0, "fragile": 0.5, "room": "H", "name_key": "p_temp_panel"})
	K.bolt(hm, by_tag["B3"], B3 + 0.4, -4.4)
	K.bolt(hm, by_tag["B3"], B3 + 0.4, -2.6)
	_hang("EXP-T", "gastank", 82.6, 85.6, -8.0, 4, {"mass": 0.5, "value": 2500.0, "fragile": 0.3, "room": "H", "name_key": "p_expansion_tank"})
	_hang("DEGAS", "pump", 87.0, 91.0, -7.0, 4, {"mass": 1.1, "value": 5000.0, "fragile": 0.35, "room": "H", "name_key": "p_strainer"})
	_hang("DRUM", "sphere_tank", 96.0, 99.8, -4.0, 5, {"mass": 2.8, "value": 7000.0, "fragile": 0.3, "room": "H", "name_key": "p_steam_drum"})
	# a grating mezzanine across the room: the plate exchanger, the lube skid, the water treatment, spares
	var hg = K.plate("HGRATE", K.R(B3 + 0.4, 0.6, 102.6, 0.9), {"density": 0.6, "barrier": false, "cut_speed": 240.0, "art": "grating", "name_key": "p_floor"}, "deck")
	K.bolt(hg, by_tag["B3"], B3 + 0.4, 0.75, "weld")
	var hp = K.plate("", K.R(102.0, 0.9, 102.4, _iy(8, 102.4) + 0.05), {"density": 1.2, "barrier": false, "cut_speed": 180.0}, "strut")
	K.bolt(hp, hg, 102.2, 0.9, "weld")
	K.bolt(hp, K.at(102.2, _iy(8, 102.2) + 0.25, ["hull"]), 102.2, _iy(8, 102.2), "weld")
	_stand("PHX", "radiator", 84.0, -2.6, 88.0, 0.6, hg, {"mass": 1.4, "value": 7000.0, "fragile": 0.3, "room": "H", "name_key": "p_heat_exchanger"})
	_stand("LUBE", "pump", 89.0, -1.6, 92.0, 0.6, hg, {"mass": 0.6, "value": 3500.0, "fragile": 0.35, "room": "H", "name_key": "p_lube_pump"})
	_stand("WTREAT", "filter", 93.0, -2.2, 95.8, 0.6, hg, {"mass": 0.7, "value": 4500.0, "fragile": 0.35, "room": "H", "name_key": "p_water_treat"})
	_stand("SPARE-H", "locker", 99.6, -1.6, 101.8, 0.6, hg, {"mass": 0.4, "value": 2500.0, "fragile": 0.3, "room": "H", "name_key": "p_parts_rack"})
	var y0 := maxf(_iy(8, 94.2), _iy(8, 98.8))
	var bp = K.equip("BOOST", "pump", K.rect(94.2, y0 - 2.0, 98.8, y0), {"mass": 1.2, "value": 5500.0, "fragile": 0.35, "room": "H", "name_key": "p_return_pump"})
	for x in [94.6, 98.4]:
		K.bolt(bp, K.at(x, _iy(8, x) + 0.2, ["hull"]), x, y0)


static func _fit_lines() -> void:
	# the sorter's separator and spectrometer
	K.line("f1", "cable", "power", "SORT", Vector2(24.4, -6.0), "MAG-SEP", Vector2(23.0, -5.4), [Vector2(24.4, -5.0), Vector2(23.0, -5.0)])
	K.line("f2", "cable", "power", "SORT", Vector2(35.6, -6.0), "SPECTRO", Vector2(36.6, -7.4), [Vector2(35.6, -6.6), Vector2(36.6, -6.6)])
	# the power room's chain off the switchboard
	K.line("f3", "cable", "power", "SWB", Vector2(B2 - 2.2, 5.7), "CHG-L", Vector2(29.6, 5.7))
	K.line("f4", "cable", "power", "CHG-L", Vector2(27.0, 5.7), "UPS-L", Vector2(25.4, 5.7))
	K.line("f5", "cable", "power", "UPS-L", Vector2(22.4, 5.7), "INV-L", Vector2(21.8, 5.7))
	K.line("f6", "cable", "power", "SWB", Vector2(38.8, 7.6), "BMS-L", Vector2(33.0, 8.1), [Vector2(38.8, 8.1)])
	# the hall: off its lamp along the roof to the hoods, the scrubber and the filter
	K.line("f7", "cable", "power", "LAMP-F", Vector2(59.8, -12.59), "SCRUB", Vector2(58.8, -11.0), [Vector2(59.6, -11.0)])
	K.line("f8", "cable", "power", "SCRUB", Vector2(59.2, -10.0), "BAGF", Vector2(61.0, -10.4), [Vector2(60.4, -10.0), Vector2(60.4, -10.4)])
	K.line("f9", "cable", "power", "SCRUB", Vector2(54.0, -11.0), "FUME-1", Vector2(52.5, -11.0))
	K.line("f10", "cable", "power", "BAGF", Vector2(66.4, -11.0), "FUME-2", Vector2(67.5, -11.0))
	K.line("f11", "cable", "power", "FUME-1", Vector2(50.6, -10.8), "PYRO-1", Vector2(50.6, -7.6))
	K.line("f12", "cable", "power", "FUME-2", Vector2(69.4, -10.8), "PYRO-2", Vector2(69.4, -7.6))
	K.line("f13", "cable", "power", "FUME-1", Vector2(46.5, -11.4), "FCTL", Vector2(42.3, -5.0), [Vector2(42.3, -11.4)])
	# heat exchange: the controllers, the panel, the degasser, the drum's heater, the booster
	K.line("f14", "cable", "power", "HXC-1", Vector2(85.6, 5.8), "HXC-2", Vector2(88.4, 5.8))
	K.line("f15", "cable", "power", "HXC-1", Vector2(83.2, 5.8), "HMI-H", Vector2(82.0, -2.0), [Vector2(82.6, 5.8), Vector2(82.6, -1.4), Vector2(82.0, -1.4)])
	K.line("f16", "cable", "power", "HMI-H", Vector2(81.7, -5.0), "DEGAS", Vector2(88.0, -7.0), [Vector2(81.7, -6.0), Vector2(88.0, -6.0)])
	K.line("f17", "cable", "power", "HX-2", Vector2(92.4, 7.4), "BOOST", Vector2(94.2, y_boost() - 1.0), [Vector2(93.2, 7.4), Vector2(93.2, y_boost() - 1.0)])
	K.line("f18", "cable", "power", "LAMP-H", Vector2(95.2, _iy(5, 95.0) + 0.16), "DRUM", Vector2(96.0, -5.0), [Vector2(95.2, -5.0)])
	K.line("f19", "cable", "power", "HMI-H", Vector2(82.4, -2.4), "PHX", Vector2(84.0, -1.0), [Vector2(83.2, -2.4), Vector2(83.2, -1.0)])
	K.line("f20", "cable", "power", "PHX", Vector2(88.0, -0.4), "LUBE", Vector2(89.0, -0.4))
	K.line("f21", "cable", "power", "LUBE", Vector2(92.0, -0.4), "WTREAT", Vector2(93.0, -0.4))
	K.line("f22", "cable", "power", "LAMP-S", Vector2(29.8, _iy(1, 30.0) + 0.16), "CAM-S", Vector2(29.0, -7.8), [Vector2(29.8, -7.8)])
	K.line("f23", "cable", "power", "SPECTRO", Vector2(36.2, -7.6), "DUST-S", Vector2(35.6, -7.6))
	# the expansion tank feeds the degasser; the drum's water
	K.line("x1", "pipe", "xcool", "EXP-T", Vector2(85.6, -9.0), "DEGAS", Vector2(87.0, -9.0))


static func y_boost() -> float:
	return maxf(_iy(8, 94.2), _iy(8, 98.8))

# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(37.6, 8.6), "SWB", Vector2(39.6, 7.6), [Vector2(37.6, 8.2), Vector2(39.6, 8.2)])
	K.line("p2", "cable", "power", "SWB", Vector2(38.6, SDECK + 0.3), "CMOT", Vector2(38.6, 3.4))
	K.line("p3", "cable", "power", "CMOT", Vector2(36.6, 2.4), "SORT", Vector2(34.0, 0.6), [Vector2(34.0, 2.4)])
	K.line("p4", "cable", "power", "SORT", Vector2(26.0, -6.0), "LAMP-S", Vector2(30.0, _iy(1, 30.0) + 0.16), [Vector2(26.0, -7.6), Vector2(30.0, -7.6)])
	K.line("p5", "cable", "power", "LAMP-S", Vector2(30.2, _iy(1, 30.0) + 0.16), "C-CON", Vector2(30.6, _oy(1, 31.4) - 1.6), [Vector2(30.6, -8.6)])
	K.line("p7", "cable", "power", "C-CON", Vector2(30.0, _oy(1, 31.4) - 1.6), "LAMP-C", Vector2(26.0, -13.84), [Vector2(30.0, -13.6), Vector2(26.0, -13.6)])
	K.line("p8", "cable", "power", "SWB", Vector2(39.2, 7.6), "LAMP-L", Vector2(26.0, SDECK + 0.46), [Vector2(39.2, 7.9), Vector2(26.0, 7.9)])
	# aft along the belly to the heat exchange; the hall's lamp
	K.line("p9", "cable", "power", "SWB", Vector2(40.0, 7.6), "HX-1", Vector2(83.6, 6.6), [Vector2(40.0, 11.0), Vector2(82.0, 11.0), Vector2(82.0, 6.2), Vector2(83.6, 6.2)])
	K.line("p10", "cable", "power", "HX-1", Vector2(87.2, 7.6), "HX-2", Vector2(87.8, 7.6))
	K.line("p11", "cable", "power", "HX-2", Vector2(91.8, 6.6), "LAMP-H", Vector2(95.0, _iy(5, 95.0) + 0.16), [Vector2(91.8, 5.8), Vector2(95.0, 5.8)])
	K.line("p12", "cable", "power", "HX-1", Vector2(83.2, 6.6), "LAMP-F", Vector2(60.0, -12.59), [Vector2(83.2, 6.0), Vector2(79.0, 6.0), Vector2(79.0, -12.2), Vector2(60.0, -12.2)])
	# the cooling loop: the core's cradle out to the pumps, the tank, the radiators and back
	K.line("c1", "pipe", "cool", "CORE", Vector2(68.6, 3.6), "HX-1", Vector2(82.6, 9.0), [Vector2(68.6, 7.2), Vector2(78.0, 7.2), Vector2(78.0, 9.0)])
	K.line("c2", "pipe", "cool", "HX-1", Vector2(87.2, 9.6), "HX-2", Vector2(87.8, 9.6))
	K.line("c3", "pipe", "cool", "HX-2", Vector2(92.4, 8.0), "CT", Vector2(104.0, 4.6), [Vector2(104.0, 8.0)])
	K.line("c4", "pipe", "cool", "CT", Vector2(104.0, -2.4), "RAD-U", Vector2(99.5, _oy(5, 99.5) - 0.2), [Vector2(104.0, -5.0), Vector2(99.5, -5.0)])
	K.line("c5", "pipe", "cool", "CT", Vector2(108.0, 4.6), "RAD-L", Vector2(91.5, 12.3), [Vector2(108.0, 7.8), Vector2(96.0, 11.4), Vector2(91.5, 11.4)])
	K.line("c6", "pipe", "cool", "RAD-U", Vector2(86.5, _oy(4, 86.5) - 0.2), "CORE", Vector2(51.4, -4.2), [Vector2(86.5, -12.0), Vector2(51.4, -12.0)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-C", "port", by_tag["CAB-R2"], Vector2(33.0, -14.6), {"medium": "gas", "target": "C"})
	K.ctrl("G-S", "port", K.at(38.0, _iy(2, 38.0) - 0.25, ["hull"]), Vector2(38.0, _oy(2, 38.0) - 0.2), {"medium": "gas", "target": "S"})
	K.ctrl("G-L", "port", K.at(24.0, _iy(10, 24.0) + 0.25, ["hull"]), Vector2(24.0, _oy(10, 24.0) + 0.3), {"medium": "gas", "target": "L"})
	K.ctrl("G-F", "port", K.at(70.0, BELLY + 0.25, ["hull"]), Vector2(70.0, 12.2), {"medium": "gas", "target": "F"})
	K.ctrl("G-H", "port", K.at(97.0, _iy(5, 97.0) - 0.25, ["hull"]), Vector2(97.05, _oy(5, 97.0) - 0.2), {"medium": "gas", "target": "H"})
	var px = K.equip("PNL-X", "panel", K.rect(44.0, 12.0, 47.6, 12.5), {"cls": "metal", "dest": "metal", "mass": 0.06, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(44.4, 11.8, ["hull"]), 44.4, 12.0)
	K.bolt(px, K.at(47.2, 11.8, ["hull"]), 47.2, 12.0)
	K.ctrl("K-M", "switch", px, Vector2(44.4, 12.25), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(45.6, 12.25), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(47.2, 12.25), {"target": "aux", "state": false})
	for h in [["HT-S", ""], ["HT-H", ""], ["HT-F", ""], ["HT-L", ""], ["HT-C", ""]]:
		K.door(h[0], h[1])
	K.ctrl("T-CORE", "probe", by_tag["FS-1"], Vector2(60.0, -6.75), {"medium": "core", "target": "CORE", "hidden_room": "F"})
	K.ctrl("PA-F", "port", by_tag["ACC-F"], Vector2(39.8, -2.8), {"medium": "gas", "target": "ACC-F", "hidden_room": "S"})
	K.ctrl("PC", "port", by_tag["CT"], Vector2(106.0, 4.4), {"medium": "coolant", "target": "loop", "hidden_room": "H"})
	K.ctrl("T-FR", "probe", by_tag["FEED"], Vector2(21.0, 3.4), {"medium": "tension", "target": "FR-P", "hidden_room": "S"})
	K.ctrl("PAR", "port", by_tag["ARGON"], Vector2(79.3, 0.3), {"medium": "gas", "target": "ARGON", "hidden_room": "F"})
	K.ctrl("PEX", "port", by_tag["EXP-T"], Vector2(84.1, -8.2), {"medium": "coolant", "target": "exp", "hidden_room": "H"})
	K.ctrl("PDR", "port", by_tag["DRUM"], Vector2(97.9, -4.2), {"medium": "water", "target": "steam", "hidden_room": "H"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	w.add_room("C", K.mp([Vector2(18.6, _oy(1, 18.6)), Vector2(23.4, -14.0), Vector2(34.8, -14.0), Vector2(36.8, _oy(2, 36.8)), Vector2(32.0, -9.6)]))
	w.add_room("S", K.mp([at.call(1, B1 + 0.4), inn[2], at.call(2, B2), Vector2(B2, SDECK), Vector2(B1 + 0.4, SDECK)]))
	w.add_room("L", K.mp([Vector2(B1 + 0.4, SDECK + 0.3), Vector2(B2, SDECK + 0.3), Vector2(B2, BELLY), inn[10], at.call(10, B1 + 0.4)]))
	w.add_room("F", K.mp([at.call(2, B2 + 0.4), inn[3], inn[4], at.call(4, B3), Vector2(B3, BELLY), Vector2(B2 + 0.4, BELLY)]))
	w.add_room("H", K.mp([at.call(4, B3 + 0.4), inn[5], inn[6], inn[7], inn[8], inn[9], Vector2(B3 + 0.4, BELLY)]))


static func meta() -> Dictionary:
	return {
		"id": "mf126",
		"name": "MF-126 MOLTEN RIDGE",
		"title": ["MF-126「熔脊」熔炼船 · 129 m", "MF-126 MOLTEN RIDGE · SMELTER SHIP · 129 m"],
		"contract": "MF-126",
		"length": 129.0,
		"value": {"total": 347100.0, "metal": 40000.0},
		"clamps": [[36.0, 12.0], [62.0, 12.0], [88.0, 12.0]],
		"room_names": {"C": "room_mfC", "S": "room_mfS", "L": "room_mfL", "F": "room_mfF", "H": "room_mfH"},
		"gas": {"rooms": {"C": 101.0, "S": 101.0, "L": 101.0, "F": 101.0, "H": 101.0},
			"vessels": {"ACC-F": {"V": 0.05, "kpa": 1700.0, "piece": "ACC-F", "burst": 200.0}, "ARGON": {"V": 0.1, "kpa": 12000.0, "piece": "ARGON", "burst": 200.0}},
			"valves": [], "value": 2600.0},
		"furnace": {"core": "CORE", "T0": 760.0, "safe": 150.0, "crit": 350.0, "cool": 4.0, "idle": 0.1, "pumps": ["HX-1", "HX-2"], "loop": "loop", "loop_min": 0.6},
		"preloads": {
			"FR-P": {"pins": ["FR-L1", "FR-L2"], "vessel": "ACC-F", "kpa": 300.0, "piece": "FEED", "push": [1.0, -0.2], "hits": "SORT", "kn": 36.0},
		},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "S": "LAMP-S", "L": "LAMP-L", "F": "LAMP-F", "H": "LAMP-H"},
		},
		"fluids": {"volumes": {
			"loop": {"fluid": "coolant", "amount": 1.2, "piece": "CT", "content": 1.2, "leak": 0.14, "port": "PC", "pump": [0.12, 0.008]},
			"loop_line": {"fluid": "coolant", "amount": 0.02, "nets": ["cool"], "leak": 0.06, "leak_min": 0.004},
			"exp": {"fluid": "coolant", "amount": 0.15, "piece": "EXP-T", "port": "PEX", "full": 0.2, "nets": ["xcool"], "leak": 0.1, "pump": [0.15, 0.006]},
			"steam": {"fluid": "water", "amount": 0.4, "piece": "DRUM", "port": "PDR", "full": 0.5, "content": 1.0, "leak": 0.1, "pump": [0.15, 0.006]},
		}, "joins": [], "value": {"coolant": 1700.0, "water": 500.0}},
		"ctrls_cfg": {"G-C": {"rate": 12.0}, "G-S": {"rate": 34.0}, "G-L": {"rate": 22.0}, "G-F": {"rate": 48.0}, "G-H": {"rate": 30.0}, "PA-F": {"rate": 0.4}},
		"labels": {"BAT": "BAT", "SWB": "SWB", "CORE": "CORE", "CT": "COOLANT", "SMELTLOG": "SMELT LOG", "HX-1": "HX", "HX-2": "HX", "ACC-F": "ACC"},
		"hints": {},
		"market": {
			"class": "MF", "name": ["熔脊级熔炼船", "MOLTEN RIDGE-CLASS SMELTER"], "time": 60.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "S": [0.2, 40.0, 101.0], "L": [0.2, 40.0, 101.0], "H": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"loop": [0.9, 1.2]}, "fill": {"loop_line": "loop"},
			"knockable": ["C-CON", "SORT", "CMOT"],
			"drift": [],
			"section_x": B3,
			"slots": {"hidden_damage": {"plates": ["HL9-1", "HL9-3", "HL9-6", "HL3-7"]},
				"fire_system": {"x": 39.4, "y0": 9.9, "y1": BELLY, "base": ["HL9-8", BELLY], "room": "L", "port": [39.8, 9.97]}},
			"mechanisms": true,
		},
		"procedures": {
			"SMELTLOG": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 5.0},
				{"do": "free", "piece": "SMELTLOG"},
				{"do": "deliver", "piece": "SMELTLOG", "zone": "equip"},
			],
		},
	}
