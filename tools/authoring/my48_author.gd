class_name My48Author
# Authoring script for MY-48 "Dewdrop", a 48 m single-volume yacht (exotic batch
# 09/10, design/ships/MY-48_露珠_设计稿.md and MY-48_线稿.png, as drawn). Not part of
# the game: tools/ship_export.gd runs it and writes ships/my48.json.
# Metres, x bow (0) to the engine (48), y down.
#
# A teardrop with no bulkheads: one 46 m cabin from the nose glass to the tail. The
# helm under the nose glass, the salon along a band of windows (the sofas, the bed, the
# zero-g spa sphere on its stand, the wine wall, the bar, the piano) on a deck with the
# owner's safe, the spa's pump and tank, the air plant and the distribution under it;
# aft the empty halon bottle and the jammed vent valve under the roof, the oxygen tank,
# the battery and the fuel cell on the floor; the engine on the tail.
# What it asks of you: the whole cabin is one volume, 60 kPa of 32 % oxygen, its only
# vent valve jammed: free the valve from outside (the wrench) and draw the cabin down
# through it before any cut (a spark beside it flashes the whole cabin over; the halon
# is spent). The bus has two supplies: the battery (the outside panel) and the fuel
# cell (its own switch aft). The window band crazes if the beam works by it.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0.0, 0.0), Vector2(2.0, -3.6), Vector2(5.0, -5.8), Vector2(9.0, -7.0), Vector2(14.0, -7.4), Vector2(22.0, -7.0),
	Vector2(30.0, -5.4), Vector2(36.0, -4.0), Vector2(42.0, -2.0), Vector2(45.5, -0.8), Vector2(45.5, 0.8), Vector2(42.0, 1.6),
	Vector2(36.0, 3.4), Vector2(30.0, 4.8), Vector2(22.0, 6.6), Vector2(14.0, 7.4), Vector2(9.0, 7.0), Vector2(5.0, 5.6), Vector2(2.0, 3.4)]
const DECK := 3.6                # the salon deck's top (to 3.9)
const PANES := [10.0, 15.4, 20.8, 26.2, 31.6]   # the window band, 3.6 m each

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "MY48")
	w = world
	by_tag = K.by_tag
	_hull()
	_deck()
	_windows()
	_helm()
	_salon()
	_under()
	_aft()
	_engine()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "MY48")
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


# the roof's / the floor's inner edge at x
static func roof(x: float) -> float:
	for i in range(0, 9):
		if x >= OUT[i].x and x <= OUT[i + 1].x:
			return _iy(i, x)
	return 0.0


static func bottom(x: float) -> float:
	for i in range(10, 18):
		if x <= OUT[i].x and x >= OUT[i + 1].x:
			return _iy(i, x)
	return 0.0


# where between lo and hi the floor's inner edge comes up to the deck's underside
static func _meets(lo: float, hi: float) -> float:
	var fwd := lo < 20.0
	for k in 40:
		var mid := (lo + hi) * 0.5
		var below: bool = bottom(mid) > DECK + 0.3
		if below == fwd:
			hi = mid
		else:
			lo = mid
	return (lo + hi) * 0.5


# equipment hung from the roof (its top at the lower of the roof's two heights)
static func _hang(tag: String, art: String, x0: float, x1: float, y1: float, opts: Dictionary):
	opts = opts.duplicate()
	if not opts.has("room"):
		opts.room = "S"
	var ya: float = roof(x0) + 0.05
	var yb: float = roof(x1) + 0.05
	var p = K.equip(tag, art, K.rect(x0, minf(ya, yb), x1, y1), opts, K.mp([Vector2(x0, ya), Vector2(x1, yb), Vector2(x1, y1), Vector2(x0, y1)]))
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, K.at(x, roof(x) - 0.2, ["hull"]), x, roof(x))
	return p


# equipment on the sloping floor, h tall at its high end
static func _floor(tag: String, art: String, x0: float, x1: float, h: float, opts: Dictionary):
	opts = opts.duplicate()
	if not opts.has("room"):
		opts.room = "S"
	var ya: float = bottom(x0) - 0.05
	var yb: float = bottom(x1) - 0.05
	var top := minf(ya, yb) - h
	var p = K.equip(tag, art, K.rect(x0, top, x1, maxf(ya, yb)), opts, K.mp([Vector2(x0, top), Vector2(x1, top), Vector2(x1, yb), Vector2(x0, ya)]))
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, K.at(x, bottom(x) + 0.2, ["hull"]), x, bottom(x))
	return p


# equipment on the deck (y1 on its top) or hung under it (y0 on its bottom)
static func _stand(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, base, opts: Dictionary, under := false):
	opts = opts.duplicate()
	if not opts.has("room"):
		opts.room = "S"
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, base, x, y0 - 0.05 if under else y1 + 0.05)
	return p


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	K.ring(OUT, T, {4: [0.5], 5: [0.3, 0.525], 13: [0.5], 14: [0.5]}, {
		"5:1": {"kind": "hatch", "door": true, "tag": "HT-S", "open_dir": Vector2(1.9, 0.4) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.4, "barrier": true, "cut_speed": 220.0, "name_key": "p_yacht_hull"}, "HY")
	K.clamp(1, 12.0, _oy(15, 12.0), _oy(15, 12.0) - 0.2)
	K.clamp(2, 28.0, _oy(13, 28.0), _oy(13, 28.0) - 0.2)


static func _deck() -> void:
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_salon_deck"}
	# the salon deck in two, a stair gap between
	# its ends where the floor rises to meet it
	var xf := _meets(2.0, 9.0)
	var xa := _meets(22.0, 36.0)
	var d1 = K.plate("DK-1", K.R(xf, DECK, 20.0, DECK + 0.3), D, "deck")
	var d2 = K.plate("DK-2", K.R(22.0, DECK, xa, DECK + 0.3), D, "deck")
	K.bolt(d1, K.at(xf - 0.1, DECK + 0.45, ["hull"]), xf, DECK + 0.3, "weld")
	K.bolt(d2, K.at(xa + 0.1, DECK + 0.45, ["hull"]), xa, DECK + 0.3, "weld")
	for e in [["P-1", 12.0, d1], ["P-2", 18.6, d1], ["P-3", 30.6, d2]]:
		var px: float = e[1]
		var po = K.plate(e[0], K.R(px, DECK + 0.3, px + 0.4, bottom(px + 0.2) + 0.05), {"density": 1.0, "barrier": false, "cut_speed": 200.0}, "strut")
		K.bolt(po, e[2], px + 0.2, DECK + 0.3, "weld")
		K.bolt(po, K.at(px + 0.2, bottom(px + 0.2) + 0.25, ["hull"]), px + 0.2, bottom(px + 0.2), "weld")


# ---------------------------------------------------------------- the nose glass, the window band

static func _windows() -> void:
	var gf = K.equip("GL-F", "glass", K.rect(1.6, -3.0, 2.0, 3.0), {"mass": 0.3, "value": 5000.0, "fragile": 0.8, "room": "S", "name_key": "p_nose_glass"})
	K.bolt(gf, K.at(1.4, -2.0, ["hull"]), 1.6, -2.4)
	K.bolt(gf, K.at(1.4, 2.0, ["hull"]), 1.6, 2.4)
	var k := 0
	for x0 in PANES:
		k += 1
		var x1: float = x0 + 3.6
		var ya: float = roof(x0) + 0.05
		var yb: float = roof(x1) + 0.05
		var g = K.equip("GL-%d" % k, "glass", K.rect(x0, minf(ya, yb), x1, maxf(ya, yb) + 0.35), {"mass": 0.25, "value": 3800.0, "fragile": 0.8, "room": "S", "name_key": "p_window_band"},
			K.mp([Vector2(x0, ya), Vector2(x1, yb), Vector2(x1, yb + 0.35), Vector2(x0, ya + 0.35)]))
		for x in [x0 + 0.3, x1 - 0.3]:
			K.bolt(g, K.at(x, roof(x) - 0.2, ["hull"]), x, roof(x))


# ---------------------------------------------------------------- the helm under the nose

static func _helm() -> void:
	var d1 = by_tag["DK-1"]
	_stand("CON-N", "console", 4.2, 2.0, 7.0, DECK - 0.05, d1, {"mass": 0.3, "value": 7000.0, "fragile": 0.5, "name_key": "p_helm"})
	var st = K.seat("SEAT-P", Rect2(7.4, DECK - 1.55, 0.8, 1.5), {"room": "S", "name_key": "p_seat_pilot"})
	K.bolt(st, d1, 7.6, DECK)
	K.bolt(st, d1, 8.0, DECK, "lock")
	_hang("NAV-N", "nav", 5.6, 8.4, -3.8, {"mass": 0.2, "value": 6000.0, "fragile": 0.5, "name_key": "p_nav"})
	var rc = K.equip("RCS-N", "rcs_quad", K.rect(-1.0, -0.7, 0.0, 0.7), {"mass": 0.2, "value": 3000.0, "fragile": 0.35, "name_key": "p_rcs_q"})
	K.bolt(rc, K.at(0.6, -0.4, ["hull"]), 0.0, -0.4)
	K.bolt(rc, K.at(0.6, 0.4, ["hull"]), 0.0, 0.4)


# ---------------------------------------------------------------- the salon

static func _salon() -> void:
	var d1 = by_tag["DK-1"]
	var d2 = by_tag["DK-2"]
	var top := DECK - 0.05
	_stand("SOFA-1", "seat", 9.8, 2.2, 12.2, top, d1, {"mass": 0.3, "value": 4500.0, "fragile": 0.4, "name_key": "p_sofa"})
	_stand("BED", "bed", 12.6, 2.2, 16.2, top, d1, {"mass": 0.4, "value": 6000.0, "fragile": 0.4, "name_key": "p_bed"})
	# the spa sphere on its stand
	var sp = K.plate("SPA-ST", K.R(16.6, -1.0, 17.4, DECK), {"density": 1.0, "barrier": false, "cut_speed": 200.0, "name_key": "p_spa_stand"}, "strut")
	K.bolt(sp, d1, 17.0, DECK, "weld")
	var pts: Array = []
	for i in 24:
		pts.append(Vector2(17.0, -3.25) + Vector2.from_angle(TAU * (i + 0.5) / 24.0) * 2.2)
	var spa = K.equip("SPA", "sphere_tank", K.rect(14.8, -5.45, 19.2, -1.05), {"mass": 0.6, "value": 9000.0, "fragile": 0.4, "room": "S", "name_key": "p_spa"}, K.mp(pts))
	K.bolt(spa, sp, 16.8, -1.0)
	K.bolt(spa, sp, 17.2, -1.0)
	_stand("TABLE", "cabinet", 18.0, 2.8, 19.6, top, d1, {"mass": 0.1, "value": 2500.0, "fragile": 0.4, "name_key": "p_table"})
	_stand("WINE", "cabinet", 22.4, 0.6, 24.6, top, d2, {"mass": 0.4, "value": 9000.0, "fragile": 0.5, "name_key": "p_wine_wall"})
	_stand("BAR", "cabinet", 25.0, 1.4, 27.4, top, d2, {"mass": 0.6, "value": 8000.0, "fragile": 0.4, "name_key": "p_bar"})
	_stand("PIANO", "console", 27.8, 1.6, 31.2, top, d2, {"mass": 0.8, "value": 14000.0, "fragile": 0.5, "name_key": "p_piano"})
	# between the panes: the light, the speakers, the smoke detector, the art
	K.lamp("LAMP-S", 14.5, roof(14.5), "S", K.at(14.5, roof(14.5) - 0.2, ["hull"]))
	_hang("SPK-1", "screen", 19.4, 20.6, -5.8, {"mass": 0.05, "value": 2500.0, "fragile": 0.5, "name_key": "p_speaker"})
	_hang("SMOKE-D", "insp", 29.9, 31.4, -4.0, {"mass": 0.03, "value": 1500.0, "fragile": 0.6, "name_key": "p_gas_det"})
	_hang("ART", "plants", 6.0 + 2.6, 9.6, -5.6, {"mass": 0.08, "value": 7000.0, "fragile": 0.7, "name_key": "p_artwork"})


# ---------------------------------------------------------------- under the deck

static func _under() -> void:
	var d1 = by_tag["DK-1"]
	var d2 = by_tag["DK-2"]
	var b := DECK + 0.35
	_stand("SAFE", "vault", 8.0, b, 10.4, 5.6, d1, {"mass": 0.4, "value": 15000.0, "fragile": 0.3, "mandatory": true, "name_key": "p_owner_safe"}, true)
	_stand("SPA-PUMP", "pump", 13.4, b, 16.2, 5.4, d1, {"mass": 0.3, "value": 3500.0, "fragile": 0.35, "name_key": "p_spa_pump"}, true)
	_stand("WATER-T", "water", 16.4, b, 18.4, 5.6, d1, {"mass": 0.4, "value": 1500.0, "fragile": 0.3, "name_key": "p_water_tank"}, true)
	_stand("ECS-S", "env", 5.0, b, 7.6, 5.0, d1, {"mass": 0.5, "value": 7000.0, "fragile": 0.4, "name_key": "p_ecs"}, true)
	_stand("DIST-S", "swb", 22.4, b, 24.8, 5.4, d2, {"mass": 0.3, "value": 5000.0, "fragile": 0.4, "name_key": "p_swb"}, true)


# ---------------------------------------------------------------- aft: the spent halon, the jammed vent, the tanks, the supplies

static func _aft() -> void:
	_hang("HALON", "gastank", 36.0, 38.0, -2.0, {"mass": 0.2, "value": 500.0, "fragile": 0.3, "name_key": "p_halon"})
	_hang("VENT", "insp", 38.6, 40.8, -1.2, {"mass": 0.2, "value": 2000.0, "fragile": 0.3, "name_key": "p_vent_valve"})
	_floor("O2-T", "gastank", 36.2, 38.4, 1.6, {"mass": 0.4, "value": 3000.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_o2_store"})
	_floor("BAT-Y", "battery", 38.8, 41.0, 1.1, {"mass": 0.8, "value": 6000.0, "fragile": 0.4, "hazard": "battery", "name_key": "p_battery"})
	_floor("FC", "gen", 41.4, 43.4, 0.6, {"mass": 0.6, "value": 6000.0, "fragile": 0.4, "name_key": "p_fuel_cell"})


static func _engine() -> void:
	var en = K.equip("ENG", "eng_core", K.rect(45.5, -1.4, 48.0, 1.4), {"mass": 2.8, "value": 32000.0, "fragile": 0.3, "name_key": "p_engine"})
	K.bolt(en, K.at(45.3, -0.5, ["hull"]), 45.5, -0.5)
	K.bolt(en, K.at(45.3, 0.5, ["hull"]), 45.5, 0.5)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	var bt_top: float = minf(bottom(38.8), bottom(41.0)) - 0.05 - 1.1
	var fc_top: float = minf(bottom(41.4), bottom(43.4)) - 0.05 - 0.6
	# the two supplies forward over the salon, down through the stair gap to the distribution
	K.line("b1", "cable", "power", "BAT-Y", Vector2(39.6, bt_top), "DIST-S", Vector2(22.4, 4.6), [Vector2(39.6, -0.6), Vector2(21.4, -0.6), Vector2(21.4, 4.6)])
	K.line("b2", "cable", "power", "FC", Vector2(42.4, fc_top), "DIST-S", Vector2(22.4, 4.9), [Vector2(42.4, -0.9), Vector2(21.2, -0.9), Vector2(21.2, 4.9)])
	# forward under the deck: the air plant, the spa pump; up to the helm
	K.line("p1", "cable", "power", "DIST-S", Vector2(22.4, 5.2), "ECS-S", Vector2(7.0, 5.0), [Vector2(21.8, 5.2), Vector2(21.8, 5.9), Vector2(7.0, 5.9)])
	K.line("p2", "cable", "power", "DIST-S", Vector2(22.4, 5.35), "SPA-PUMP", Vector2(16.0, 5.4), [Vector2(21.6, 5.35), Vector2(21.6, 5.75), Vector2(16.0, 5.75)])
	K.line("p3", "cable", "power", "ECS-S", Vector2(6.0, 3.95), "CON-N", Vector2(6.0, 3.55))
	K.line("p4", "cable", "power", "CON-N", Vector2(5.0, 2.0), "NAV-N", Vector2(6.6, -3.8), [Vector2(5.0, -0.8), Vector2(6.6, -0.8)])
	K.line("p5", "cable", "power", "CON-N", Vector2(6.6, 2.0), "LAMP-S", Vector2(14.5, roof(14.5) + 0.16), [Vector2(6.6, -0.4), Vector2(14.5, -0.4)])
	K.line("p6", "cable", "power", "LAMP-S", Vector2(14.7, roof(14.5) + 0.16), "SPK-1", Vector2(19.4, -6.0), [Vector2(14.7, -6.0)])
	K.line("p7", "cable", "power", "LAMP-S", Vector2(14.3, roof(14.5) + 0.16), "ART", Vector2(9.6, -6.0), [Vector2(14.3, -6.0)])
	K.line("p8", "cable", "power", "DIST-S", Vector2(24.8, 4.4), "BAR", Vector2(25.6, 3.55), [Vector2(25.6, 4.4)])
	K.line("p9", "cable", "power", "BAR", Vector2(25.0, 2.0), "WINE", Vector2(24.6, 2.0))
	K.line("p10", "cable", "power", "BAR", Vector2(27.0, 1.4), "SMOKE-D", Vector2(30.6, -4.0), [Vector2(27.0, 0.4), Vector2(30.6, 0.4)])
	K.line("w1", "pipe", "spa", "SPA-PUMP", Vector2(16.0, 3.95), "SPA", Vector2(16.4, -1.15), [Vector2(16.4, 3.8)])


static func b_top() -> float:
	return DECK + 0.35


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	# the only vent, outside on the roof over the valve, and the jam on it
	var rp = K.at(39.7, roof(39.7) - 0.2, ["hull"])
	K.ctrl("G-S", "port", rp, Vector2(39.7, _oy(7, 39.7) - 0.3), {"medium": "gas", "target": "S"})
	K.ctrl("VENT-JAM", "jam", rp, Vector2(40.6, _oy(7, 40.6) - 0.3), {"target": "G-S"})
	K.door("HT-S", "")
	# the outside panel under the salon
	var px = K.equip("PNL-X", "panel", K.rect(15.0, 7.04, 17.6, 7.8), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_panel"},
		K.mp([Vector2(15.0, _oy(14, 15.0) + 0.05), Vector2(17.6, _oy(14, 17.6) + 0.05), Vector2(17.6, _oy(14, 17.6) + 0.55), Vector2(15.0, _oy(14, 15.0) + 0.55)]))
	K.bolt(px, K.at(15.4, _oy(14, 15.4) - 0.2, ["hull"]), 15.4, _oy(14, 15.4))
	K.bolt(px, K.at(17.2, _oy(14, 17.2) - 0.2, ["hull"]), 17.2, _oy(14, 17.2))
	K.ctrl("K-M", "switch", px, Vector2(15.4, _oy(14, 15.4) + 0.3), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(16.3, _oy(14, 16.3) + 0.3), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(17.2, _oy(14, 17.2) + 0.3), {"target": "aux", "state": false})
	# inside: the fuel cell's own switch, the oxygen's, the halon's and the spa's ports, the cabin's oxygen probe
	K.ctrl("K-FC", "switch", by_tag["FC"], Vector2(42.4, bottom(42.4) - 0.4), {"target": "K-FC", "state": true, "hidden_room": "S"})
	K.ctrl("PO2", "port", by_tag["O2-T"], Vector2(37.3, bottom(37.3) - 1.0), {"medium": "gas", "target": "O2", "hidden_room": "S"})
	K.ctrl("PHA", "port", by_tag["HALON"], Vector2(37.0, -2.2), {"medium": "gas", "target": "HAL", "hidden_room": "S"})
	K.ctrl("PSPA", "port", by_tag["SPA-PUMP"], Vector2(14.0, 5.2), {"medium": "water", "target": "spa", "hidden_room": "S"})
	K.ctrl("O2-S", "probe", by_tag["SMOKE-D"], Vector2(30.6, -4.3), {"medium": "o2", "target": "S", "hidden_room": "S"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	w.add_room("S", K.mp(K.inner(OUT, T)))


static func meta() -> Dictionary:
	var glass: Array = ["GL-F", "GL-1", "GL-2", "GL-3", "GL-4", "GL-5"]
	return {
		"id": "my48",
		"name": "MY-48 DEWDROP",
		"title": ["MY-48「露珠」单体游艇 · 48 m", "MY-48 DEWDROP · SINGLE-VOLUME YACHT · 48 m"],
		"contract": "MY-48",
		"length": 48.0,
		"value": {"total": 204200.0, "metal": 14000.0},
		"clamps": [[12.0, 7.24], [28.0, 5.25]],
		"room_names": {"S": "room_myS"},
		"gas": {"rooms": {"S": 60.0},
			"vessels": {"O2": {"V": 0.08, "kpa": 14000.0, "piece": "O2-T", "burst": 200.0}, "HAL": {"V": 0.05, "kpa": 0.0, "piece": "HALON", "burst": 200.0}},
			"valves": [], "value": 1800.0},
		# 32 % oxygen, and a flash over it
		"atmos": {"o2": {"S": 0.32}, "fire_o2": 0.30, "glass": glass},
		"power": {
			"bus": "DIST-S",
			"sources": [
				{"piece": "BAT-Y", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "b1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
				{"piece": "FC", "kind": "gen", "volts": 220.0, "cable": "b2", "switch": "K-FC", "running": true},
			],
			"lamps": {"S": "LAMP-S"},
		},
		"fluids": {"volumes": {
			"spa": {"fluid": "water", "amount": 1.8, "piece": "SPA", "port": "PSPA", "full": 2.2, "content": 1.0, "nets": ["spa"], "leak": 0.15, "pump": [0.18, 0.008]},
		}, "joins": [], "value": {"water": 900.0}},
		"ctrls_cfg": {"G-S": {"rate": 26.0, "jam": "VENT-JAM"}, "PO2": {"rate": 0.4}},
		"labels": {"BAT-Y": "BAT", "FC": "FC", "DIST-S": "BUS", "O2-T": "O₂", "HALON": "HALON 0", "VENT": "VENT STUCK", "SAFE": "SAFE"},
		"hints": {},
		"market": {
			"class": "MY", "name": ["露珠级单体游艇", "DEWDROP-CLASS YACHT"], "time": 24.0,
			"rooms": {"S": [0.3, 40.0, 60.0]},
			"charge": {"BAT-Y": [0.3, 1.0]},
			"fluids": {"spa": [0.6, 1.8]},
			"knockable": ["CON-N", "NAV-N"],
			"drift": [],
			"section_x": 36.0,
			"slots": {"fire_system": {"x": 8.6, "y0": 2.0, "y1": DECK, "base": ["DK-1", DECK], "room": "S", "port": [9.0, 2.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"SAFE": [
				{"do": "operate", "ctrl": "VENT-JAM"},
				{"do": "hose", "ctrl": "G-S"},
				{"do": "wait", "until": {"P": ["S", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-S"},
				{"do": "wait", "until": {"open": ["S"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "operate", "ctrl": "K-FC"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "SAFE"},
				{"do": "deliver", "piece": "SAFE", "zone": "equip"},
			],
		},
	}
