class_name Hb86Author
# Authoring script for HB-86 "Haven Cove", an 89 m culture ship (R2 fleet,
# design/ships/全新舰队_R2_2026-10-18/HB-86_栖湾.md; lengths as drawn, heights at
# 0.6 of the drawing, player 2026-10-19). Not part of the game:
# tools/ship_export.gd runs it and writes ships/hb86.json.
# Metres, x bow (0) to the nozzles (89), y down.
#
# A garden inside a hull: the cockpit forward with the machinery room under its
# deck, then three culture halls in a row under a glazed roof (six panes of
# precision glass, each under its own shutter, between thick shutter ribs), the
# nutrient bay under the halls, the environmental plant aft, two stern engines and
# a load-bearing keel under the belly.
# What it asks of you: each hall's air is its own mixture, oxygen-rich and not
# alike (an oxygen probe in each reads it): recover each hall's air through its own
# port before any cut is made beside it, or the hall flashes over. Recover the
# nutrient solution; take the culture racks and the environmental plant out whole;
# open the shutters (on the bus) and unbolt the glass from its ribs: the beam
# working beside a pane crazes it.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.4
const OUT := [Vector2(0.0, 0.0), Vector2(4.0, -4.8), Vector2(7.0, -8.4), Vector2(18.0, -8.4), Vector2(22.0, -9.6), Vector2(28.0, -13.8),
	Vector2(60.0, -13.8), Vector2(71.0, -9.6), Vector2(75.0, -7.8), Vector2(78.0, -1.8), Vector2(78.0, 6.0), Vector2(67.0, 9.0),
	Vector2(15.0, 9.0), Vector2(6.0, 5.4)]
const ROOF := -13.4              # inside the roof ribs and shutters
const BELLY := 8.6
const B1 := 19.6                 # cockpit / machinery | the halls (to 20.0)
const S1 := 38.58                # hall 1 | hall 2 (to 38.98), under a rib
const S2 := 49.02                # hall 2 | hall 3 (to 49.42), under a rib
const S3 := 65.0                 # hall 3 | the environmental plant (to 65.4)
const CDECK := 3.6               # the cockpit deck (plate to 3.9)
const HDECK := 6.0               # the halls' deck (plate to 6.3); the nutrient bay under it
# the roof between 28 and 60: thick ribs 0.7 m, six panes between them
const RIB := 0.7
const PANE := (32.0 - 7.0 * RIB) / 6.0

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "HB86")
	w = world
	by_tag = K.by_tag
	_hull()
	_inside()
	_glass()
	_cockpit()
	_machinery()
	_halls()
	_nutrient()
	_plant()
	_engines()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "HB86")
	w = world
	_rooms()


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# where along the roof (edge 5, x 28 to 60) a rib or a pane starts
static func _roof_x(k: int) -> float:
	# k even: rib k / 2 starts; k odd: pane (k + 1) / 2 starts
	var x := 28.0
	for i in k:
		x += RIB if i % 2 == 0 else PANE
	return x


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	var roof_splits: Array = []
	for k in range(1, 13):
		roof_splits.append((_roof_x(k) - 28.0) / 32.0)
	var sp := {
		"1:0": {"art": "window", "tag": "CAN-F"},
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(1.8, 0) * Geom.M, "cut_speed": 200.0},
		"8:0": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(-0.6, -1.4) * Geom.M, "cut_speed": 200.0},
		"11:5": {"kind": "hatch", "door": true, "tag": "HT-N", "open_dir": Vector2(1.8, 0) * Geom.M, "cut_speed": 200.0},
		"12:1": {"kind": "hatch", "door": true, "tag": "HT-M", "open_dir": Vector2(-1.4, -0.6) * Geom.M, "cut_speed": 200.0},
	}
	for k in 13:
		if k % 2 == 0:
			sp["5:%d" % k] = {"tag": "RIB-%d" % (k / 2), "density": 2.0, "cut_speed": 150.0, "name_key": "p_shutter_rib"}
		else:
			sp["5:%d" % k] = {"kind": "door", "door": true, "tag": "SH-%d" % ((k + 1) / 2), "open_dir": Vector2(0, -1.0) * Geom.M, "cut_speed": 190.0, "density": 1.2, "name_key": "p_shutter"}
	K.ring(OUT, T, {
		2: [0.5, 0.7],
		5: roof_splits,
		8: [0.5],
		11: [0.1, 0.2, 0.3, 0.4, 0.5, 0.55, 0.65, 0.75, 0.85],
		12: [0.3, 0.6],
	}, sp, {"density": 1.5, "barrier": true, "cut_speed": 220.0}, "HL")
	# the load-bearing keel under the belly, the berth's clamps on it
	var kl = K.plate("KEEL", K.R(18.0, 9.0, 66.0, 10.8), {"density": 1.6, "barrier": false, "cut_speed": 140.0, "name_key": "p_keel"}, "keel")
	for kx in [20.0, 30.0, 42.0, 54.0, 64.0]:
		K.bolt(kl, K.at(kx, 8.8, ["hull"]), kx, 9.0, "weld")
	K.clamp(1, 24.0, 10.8, 10.6, ["keel"])
	K.clamp(2, 42.0, 10.8, 10.6, ["keel"])
	K.clamp(3, 60.0, 10.8, 10.6, ["keel"])


# ---------------------------------------------------------------- bulkheads and decks

static func _wall(tag: String, x: float, y0: float, y1: float, doors: Array) -> void:
	# a bulkhead from y0 to y1 with doors [[tag, y0, y1, room the control hides in]]
	var S := {"density": 1.2, "barrier": true, "cut_speed": 220.0}
	var cuts: Array = [y0]
	for d in doors:
		cuts.append(d[1])
		cuts.append(d[2])
	cuts.append(y1)
	var prev = null
	var k := 0
	for i in cuts.size() - 1:
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		if b - a < 0.05:
			continue
		var pc
		if i % 2 == 1:
			var d: Array = doors[(i - 1) / 2]
			pc = K.plate(d[0], K.R(x, a, x + 0.4, b), {"density": 1.0, "door": true, "open_dir": Vector2(0, -(b - a) - 0.2) * Geom.M, "cut_speed": 210.0}, "door")
		else:
			k += 1
			pc = K.plate("%s-%d" % [tag, k], K.R(x, a, x + 0.4, b), S, "bulkhead")
		if prev != null:
			K.bolt(pc, prev, x + 0.2, a, "weld")
		prev = pc


static func _inside() -> void:
	_wall("B1", B1, _iy(3, B1 + 0.2) - 0.1, BELLY + 0.1, [["DR-CU", 0.8, CDECK, "C"], ["DR-MN", 6.4, 8.4, "M"]])
	K.bolt(by_tag["B1-1"], K.at(B1 + 0.2, _iy(3, B1 + 0.2) - 0.25, ["hull"]), B1 + 0.2, _iy(3, B1 + 0.2), "weld")
	K.bolt(by_tag["B1-3"], K.at(B1 + 0.2, BELLY + 0.25, ["hull"]), B1 + 0.2, BELLY, "weld")
	for s in [["S1", S1, "DR-12", "U1"], ["S2", S2, "DR-23", "U2"]]:
		_wall(s[0], s[1], ROOF - 0.05, HDECK, [[s[2], 3.0, HDECK, s[3]]])
		K.bolt(by_tag[s[0] + "-1"], K.at(s[1] + 0.2, ROOF - 0.2, ["hull"]), s[1] + 0.2, ROOF, "weld")
	_wall("S3", S3, _iy(6, S3 + 0.2) - 0.1, BELLY + 0.1, [["DR-3E", 3.0, HDECK, "U3"], ["DR-NE", 6.5, 8.4, "N"]])
	K.bolt(by_tag["S3-1"], K.at(S3 + 0.2, _iy(6, S3 + 0.2) - 0.25, ["hull"]), S3 + 0.2, _iy(6, S3 + 0.2), "weld")
	K.bolt(by_tag["S3-3"], K.at(S3 + 0.2, BELLY + 0.25, ["hull"]), S3 + 0.2, BELLY, "weld")
	# the halls' deck, the nutrient bay under it
	var hd = K.plate("HDECK", K.R(B1 + 0.4, HDECK, S3, HDECK + 0.3), {"density": 1.1, "barrier": true, "cut_speed": 220.0}, "deck")
	K.bolt(hd, by_tag["B1-2"], B1 + 0.4, HDECK + 0.15, "weld")
	K.bolt(hd, by_tag["S3-2"], S3, HDECK + 0.15, "weld")
	for s in [["S1", S1], ["S2", S2]]:
		K.bolt(by_tag["DR-" + ("12" if s[0] == "S1" else "23")], hd, s[1] + 0.2, HDECK, "weld")
	# the cockpit's deck over the machinery room
	var cx0 := 4.6
	var cd = K.plate("CDECK", K.R(cx0, CDECK, B1, CDECK + 0.3), {"density": 1.0, "barrier": true, "cut_speed": 220.0}, "deck")
	K.bolt(cd, K.at(cx0 - 0.25, CDECK + 0.15, ["hull"]), cx0, CDECK + 0.15, "weld")
	K.bolt(cd, by_tag["B1-2"], B1, CDECK + 0.15, "weld")


# ---------------------------------------------------------------- the glass under the shutters

static func _glass() -> void:
	for i in 6:
		var x0 := _roof_x(2 * i + 1)
		var x1 := x0 + PANE
		var g = K.equip("GL-%d" % (i + 1), "glass", K.rect(x0 - 0.2, ROOF, x1 + 0.2, ROOF + 0.35), {"mass": 0.35, "value": 4200.0, "fragile": 0.8, "barrier": true, "cut_speed": 160.0,
			"room": _hall_at(x0 + PANE * 0.5), "name_key": "p_glass_cover"})
		K.bolt(g, by_tag["RIB-%d" % i], x0 - 0.1, ROOF)
		K.bolt(g, by_tag["RIB-%d" % (i + 1)], x1 + 0.1, ROOF)


static func _hall_at(x: float) -> String:
	if x < S1:
		return "U1"
	if x < S2:
		return "U2"
	return "U3"


# ---------------------------------------------------------------- the cockpit

static func _cockpit() -> void:
	var dk = by_tag["CDECK"]
	var nav = K.equip("NAV", "nav", K.rect(2.0, 0.8, 6.8, CDECK), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "room": "C", "name_key": "p_nav"},
		K.mp([Vector2(4.6, CDECK), Vector2(6.8, CDECK), Vector2(6.8, 0.8), Vector2(2.0, 0.8)]))
	K.bolt(nav, dk, 5.4, CDECK)
	K.bolt(nav, dk, 6.4, CDECK)
	for i in 2:
		var sx := 8.0 + i * 2.6
		var st = K.seat("SEAT-%d" % (i + 1), Rect2(sx, CDECK - 1.5, 0.8, 1.5), {"room": "C", "name_key": "p_seat_pilot"})
		K.bolt(st, dk, sx + 0.2, CDECK)
		K.bolt(st, dk, sx + 0.6, CDECK, "lock")
	var cn = K.equip("CON", "console", K.rect(13.8, 1.8, 17.4, CDECK), {"mass": 0.3, "value": 4000.0, "fragile": 0.5, "room": "C", "name_key": "p_culture_console"})
	K.bolt(cn, dk, 14.4, CDECK)
	K.bolt(cn, dk, 16.8, CDECK)
	var sv = K.equip("SEED", "cabinet", K.rect(17.8, 0.6, B1, CDECK), {"mass": 0.5, "value": 16000.0, "fragile": 0.5, "room": "C", "mandatory": true, "name_key": "p_seed_vault"})
	K.bolt(sv, dk, 18.4, CDECK)
	K.bolt(sv, by_tag["B1-1"], B1, 1.4, "lock")
	K.lamp("LAMP-C", 10.0, -8.0, "C", K.at(10.0, -8.2, ["hull"]))


# ---------------------------------------------------------------- the machinery room under the cockpit deck

static func _machinery() -> void:
	var dk = by_tag["CDECK"]
	var bt = K.equip("BAT", "battery", K.rect(15.4, 6.0, 19.4, BELLY), {"mass": 1.0, "value": 6000.0, "fragile": 0.4, "room": "M", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(16.0, 8.8, ["hull"]), 16.0, BELLY)
	K.bolt(bt, K.at(18.8, 8.8, ["hull"]), 18.8, BELLY)
	var ap = K.equip("AIR", "env", K.rect(11.6, 4.2, 15.0, 7.2), {"mass": 0.6, "value": 6000.0, "fragile": 0.4, "room": "M", "name_key": "p_air_plant"})
	K.bolt(ap, dk, 12.2, CDECK + 0.3)
	K.bolt(ap, dk, 14.4, CDECK + 0.3)
	var sw = K.equip("SWB", "swb", K.rect(7.6, CDECK + 0.3, 9.8, 5.6), {"mass": 0.4, "value": 4000.0, "fragile": 0.4, "room": "M", "name_key": "p_swb"})
	K.bolt(sw, dk, 8.0, CDECK + 0.3)
	K.bolt(sw, dk, 9.4, CDECK + 0.3)
	K.lamp("LAMP-M", 10.6, CDECK + 0.3, "M", dk)


# ---------------------------------------------------------------- the culture halls

static func _halls() -> void:
	var dk = by_tag["HDECK"]
	var spans := [["U1", 22.0, 37.6], ["U2", 40.0, 48.0], ["U3", 50.6, 63.8]]
	for h in spans:
		var n: String = h[0]
		var x0: float = h[1]
		var x1: float = h[2]
		# posts at the racks' ends, from the deck up
		var posts: Array = []
		for px in [x0 - 0.3, x1]:
			var po = K.plate("", K.R(px, -4.2, px + 0.3, HDECK), {"density": 0.8, "barrier": false, "cut_speed": 200.0}, "strut")
			K.bolt(po, dk, px + 0.15, HDECK, "weld")
			posts.append(po)
		for row in 2:
			var y0 := -3.6 + row * 4.2
			var rk = K.equip("CR-%s%s" % [n.substr(1), "ab"[row]], "plants", K.rect(x0, y0, x1, y0 + 2.4), {"mass": 0.9, "value": 3800.0, "fragile": 0.5, "room": n, "name_key": "p_culture_rack"})
			K.bolt(rk, posts[0], x0, y0 + 1.2)
			K.bolt(rk, posts[1], x1, y0 + 1.2)
		# the hall's grow lamp hangs off a post's top
		var gl = K.equip("GROW-" + n.substr(1), "lamp", K.rect(x0 + 0.2, -4.2, x0 + 2.2, -3.9), {"cls": "metal", "dest": "metal", "mass": 0.06, "room": n, "cut_speed": 260.0, "name_key": "p_grow_lamp"})
		K.bolt(gl, posts[0], x0, -4.05)


# ---------------------------------------------------------------- the nutrient bay

static func _nutrient() -> void:
	var tk = K.equip("NUT", "fueltank", K.rect(24.0, 6.6, 40.0, BELLY), {"mass": 1.4, "value": 3000.0, "fragile": 0.3, "room": "N", "name_key": "p_nutrient_tank"})
	K.bolt(tk, K.at(25.0, 8.8, ["hull"]), 25.0, BELLY, "lock")
	K.bolt(tk, K.at(37.0, 8.8, ["hull"]), 37.0, BELLY, "lock")
	var pm = K.equip("NPMP", "pump", K.rect(44.0, 6.6, 48.0, BELLY), {"mass": 0.5, "value": 3500.0, "fragile": 0.35, "room": "N", "name_key": "p_nutrient_pump"})
	K.bolt(pm, K.at(44.6, 8.8, ["hull"]), 44.6, BELLY)
	K.bolt(pm, K.at(47.4, 8.8, ["hull"]), 47.4, BELLY)
	K.lamp("LAMP-N", 56.0, HDECK + 0.3, "N", by_tag["HDECK"])


# ---------------------------------------------------------------- the environmental plant aft

static func _plant() -> void:
	var ec = K.equip("ECS", "env", K.rect(65.4, -3.6, 73.6, 5.4), {"mass": 1.6, "value": 12000.0, "fragile": 0.4, "room": "E", "name_key": "p_ecs_big"})
	K.bolt(ec, by_tag["S3-2"], S3 + 0.4, -2.0)
	K.bolt(ec, by_tag["S3-2"], S3 + 0.4, 4.0)
	var o2 = K.equip("O2-T", "gastank", K.rect(74.4, -3.4, 76.6, 2.6), {"mass": 0.4, "value": 1500.0, "fragile": 0.3, "room": "E", "hazard": "gas_tank", "name_key": "p_o2_store"})
	K.bolt(o2, K.at(77.75, -1.0, ["hull"]), 76.6, -1.0)
	K.bolt(o2, K.at(77.75, 1.8, ["hull"]), 76.6, 1.8, "lock")
	var hu = K.equip("HUM", "pump", K.rect(65.4, 6.0, 70.0, _iy(10, 70.0) - 0.05), {"mass": 0.5, "value": 3500.0, "fragile": 0.4, "room": "E", "name_key": "p_humidity"})
	K.bolt(hu, by_tag["S3-3"], S3 + 0.4, 7.0)
	K.lamp("LAMP-E", 69.0, _iy(6, 69.0), "E", K.at(69.0, _iy(6, 69.0) - 0.2, ["hull"]))


# ---------------------------------------------------------------- the stern engines

static func _engines() -> void:
	for e in [["1", -4.8, 1.2, [-1.0, 0.8]], ["2", 3.0, 7.8, [3.6, 5.6]]]:
		var y0: float = e[1]
		var y1: float = e[2]
		var en = K.equip("ENG-" + e[0], "eng_core", K.rect(78.0, y0, 84.0, y1), {"mass": 2.8, "value": 14000.0, "fragile": 0.3, "name_key": "p_engine"})
		for by in e[3]:
			K.bolt(en, K.at(77.8, by, ["hull"]), 78.0, by)
		var nz = K.equip("NOZ-" + e[0], "nozzle", K.rect(84.0, y0 - 0.6, 89.0, y1 + 0.6), {"cls": "metal", "dest": "metal", "mass": 0.5, "cut_speed": 170.0, "name_key": "p_nozzle"},
			K.mp([Vector2(84.0, y0 + 0.6), Vector2(89.0, y0 - 0.6), Vector2(89.0, y1 + 0.6), Vector2(84.0, y1 - 0.6)]))
		K.bolt(nz, en, 84.0, y0 + 1.4)
		K.bolt(nz, en, 84.0, y1 - 1.4)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT", Vector2(15.6, 6.0), "SWB", Vector2(9.8, 5.2), [Vector2(15.6, 5.2)])
	K.line("p2", "cable", "power", "SWB", Vector2(9.0, CDECK + 0.3), "NAV", Vector2(6.4, 2.6), [Vector2(9.0, 2.6)])
	K.line("p3", "cable", "power", "NAV", Vector2(6.8, 1.2), "CON", Vector2(13.8, 2.4), [Vector2(13.0, 1.2), Vector2(13.0, 2.4)])
	K.line("p4", "cable", "power", "CON", Vector2(15.6, 1.8), "LAMP-C", Vector2(10.0, -7.84), [Vector2(15.6, -6.0), Vector2(10.0, -6.0)])
	K.line("p5", "cable", "power", "SWB", Vector2(9.8, 4.4), "AIR", Vector2(11.6, 4.6))
	K.line("p6", "cable", "power", "SWB", Vector2(7.8, 5.6), "LAMP-M", Vector2(10.6, CDECK + 0.46), [Vector2(7.8, 5.9), Vector2(10.2, 5.9), Vector2(10.2, 4.2), Vector2(10.6, 4.2)])
	K.line("p7", "cable", "power", "CON", Vector2(17.4, 2.0), "SEED", Vector2(17.8, 2.0))
	# along the halls' deck to each grow lamp and on to the environmental plant
	K.line("p8", "cable", "power", "SWB", Vector2(9.4, 5.6), "GROW-1", Vector2(22.4, -3.9), [Vector2(9.4, 6.2), Vector2(21.0, 5.7), Vector2(21.0, -3.6), Vector2(22.4, -3.6)])
	K.line("p9", "cable", "power", "GROW-1", Vector2(24.0, -3.9), "GROW-2", Vector2(40.4, -3.9), [Vector2(24.0, -4.6), Vector2(40.4, -4.6)])
	K.line("p10", "cable", "power", "GROW-2", Vector2(42.0, -3.9), "GROW-3", Vector2(51.0, -3.9), [Vector2(42.0, -4.6), Vector2(51.0, -4.6)])
	K.line("p11", "cable", "power", "GROW-3", Vector2(52.6, -3.9), "ECS", Vector2(66.0, -2.8), [Vector2(52.6, -4.6), Vector2(64.4, -4.6), Vector2(64.4, -2.8)])
	K.line("p12", "cable", "power", "ECS", Vector2(70.0, -3.6), "LAMP-E", Vector2(69.0, _iy(6, 69.0) + 0.16), [Vector2(70.0, -6.0), Vector2(69.0, -6.0)])
	K.line("p13", "cable", "power", "ECS", Vector2(68.0, 5.4), "HUM", Vector2(68.0, 6.0))
	K.line("p14", "cable", "power", "SWB", Vector2(8.6, 5.6), "NPMP", Vector2(44.4, 6.6), [Vector2(8.6, 6.4), Vector2(20.4, 6.4), Vector2(20.4, 6.45), Vector2(44.4, 6.45)])
	K.line("p15", "cable", "power", "NPMP", Vector2(47.6, 6.6), "LAMP-N", Vector2(56.0, HDECK + 0.46), [Vector2(47.6, 6.5), Vector2(56.0, 6.5)])
	# the nutrient loop: tank, pump, up through the deck to each hall's racks
	K.line("n1", "pipe", "nut", "NUT", Vector2(39.6, 7.0), "NPMP", Vector2(44.0, 7.0))
	K.line("n2", "pipe", "nut", "NPMP", Vector2(45.0, 6.6), "CR-1b", Vector2(37.2, 3.0), [Vector2(45.0, 6.4), Vector2(41.5, 6.4), Vector2(41.5, 5.2), Vector2(37.2, 5.2)])
	K.line("n3", "pipe", "nut", "NPMP", Vector2(46.0, 6.6), "CR-2b", Vector2(44.0, 3.0), [Vector2(46.0, 5.0), Vector2(44.0, 5.0)])
	K.line("n4", "pipe", "nut", "NPMP", Vector2(47.0, 6.6), "CR-3b", Vector2(55.0, 3.0), [Vector2(47.0, 5.6), Vector2(55.0, 5.6)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	# each hall's own port, on a rib above it; the cockpit's, the bays'
	K.ctrl("G-U1", "port", by_tag["RIB-1"], Vector2(_roof_x(2) + 0.35, -14.0), {"medium": "gas", "target": "U1"})
	K.ctrl("G-U2", "port", by_tag["RIB-3"], Vector2(_roof_x(6) + 0.35, -14.0), {"medium": "gas", "target": "U2"})
	K.ctrl("G-U3", "port", by_tag["RIB-5"], Vector2(_roof_x(10) + 0.35, -14.0), {"medium": "gas", "target": "U3"})
	K.ctrl("G-C", "port", K.at(16.0, -8.2, ["hull"]), Vector2(16.0, -8.6), {"medium": "gas", "target": "C"})
	K.ctrl("G-M", "port", K.at(13.5, 8.17, ["hull"]), Vector2(13.5, 8.6), {"medium": "gas", "target": "M"})
	K.ctrl("G-N", "port", K.at(29.0, 8.8, ["hull"]), Vector2(30.0, 9.0), {"medium": "gas", "target": "N"})
	K.ctrl("G-E", "port", K.at(77.02, -3.31, ["hull"]), Vector2(77.38, -3.49), {"medium": "gas", "target": "E"})
	# the outside panel under the bow, clear of the keel
	var px = K.equip("PNL-X", "panel", K.rect(15.2, 9.0, 17.8, 9.5), {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_panel"})
	K.bolt(px, K.at(15.6, 8.8, ["hull"]), 15.6, 9.0)
	K.bolt(px, K.at(17.4, 8.8, ["hull"]), 17.4, 9.0)
	K.ctrl("K-M", "switch", px, Vector2(15.6, 9.3), {"target": "K-M", "state": true})
	K.ctrl("E-1", "test", px, Vector2(16.5, 9.3), {"medium": "volt", "target": "bus"})
	K.ctrl("AUX-P", "socket", px, Vector2(17.5, 9.3), {"target": "aux", "state": false})
	for h in [["HT-C", ""], ["HT-M", ""], ["HT-N", ""], ["HT-E", ""], ["DR-CU", "C"], ["DR-MN", "M"], ["DR-12", "U1"], ["DR-23", "U2"], ["DR-3E", "U3"], ["DR-NE", "N"]]:
		K.door(h[0], h[1])
	for i in 6:
		K.door("SH-%d" % (i + 1), "")
	# the halls' oxygen probes
	for h in [["O2-1", "U1", "CR-1a", 24.0], ["O2-2", "U2", "CR-2a", 42.0], ["O2-3", "U3", "CR-3a", 53.0]]:
		K.ctrl(h[0], "probe", by_tag[h[2]], Vector2(h[3], -3.4), {"medium": "o2", "target": h[1], "hidden_room": h[1]})
	K.ctrl("PN", "port", by_tag["NUT"], Vector2(32.0, 6.8), {"medium": "nutrient", "target": "nut", "hidden_room": "N"})
	K.ctrl("PO2", "port", by_tag["O2-T"], Vector2(75.5, -3.2), {"medium": "gas", "target": "O2", "hidden_room": "E"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT, T)
	var at := func(i: int, x: float) -> Vector2: return Vector2(x, _iy(i, x))
	var bow := func(y: float) -> Vector2:
		var a: Vector2 = inn[13]
		var b: Vector2 = inn[0]
		return Vector2(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x), y)
	w.add_room("C", K.mp([bow.call(CDECK), inn[0], inn[1], inn[2], inn[3], at.call(3, B1), Vector2(B1, CDECK)]))
	w.add_room("M", K.mp([bow.call(CDECK + 0.3), Vector2(B1, CDECK + 0.3), Vector2(B1, BELLY), inn[12], inn[13]]))
	w.add_room("U1", K.mp([Vector2(B1 + 0.4, _iy(3, B1 + 0.4)), inn[4], inn[5], Vector2(S1, ROOF), Vector2(S1, HDECK), Vector2(B1 + 0.4, HDECK)]))
	w.add_room("U2", K.mp([Vector2(S1 + 0.4, ROOF), Vector2(S2, ROOF), Vector2(S2, HDECK), Vector2(S1 + 0.4, HDECK)]))
	w.add_room("U3", K.mp([Vector2(S2 + 0.4, ROOF), inn[6], at.call(6, S3), Vector2(S3, HDECK), Vector2(S2 + 0.4, HDECK)]))
	w.add_room("N", K.mp([Vector2(B1 + 0.4, HDECK + 0.3), Vector2(S3, HDECK + 0.3), Vector2(S3, BELLY), Vector2(B1 + 0.4, BELLY)]))
	w.add_room("E", K.mp([at.call(6, S3 + 0.4), inn[7], inn[8], inn[9], inn[10], at.call(10, S3 + 0.4) if S3 + 0.4 > inn[11].x else inn[11], Vector2(S3 + 0.4, BELLY)]))


static func meta() -> Dictionary:
	var glass: Array = []
	for i in 6:
		glass.append("GL-%d" % (i + 1))
	return {
		"id": "hb86",
		"name": "HB-86 HAVEN COVE",
		"title": ["HB-86「栖湾」培育船 · 89 m", "HB-86 HAVEN COVE · CULTURE SHIP · 89 m"],
		"contract": "HB-86",
		"length": 89.0,
		"value": {"total": 180000.0, "metal": 30000.0},
		"clamps": [[24.0, 10.8], [42.0, 10.8], [60.0, 10.8]],
		"room_names": {"C": "room_hbC", "M": "room_hbM", "U1": "room_hbU1", "U2": "room_hbU2", "U3": "room_hbU3", "N": "room_hbN", "E": "room_hbE"},
		"gas": {"rooms": {"C": 101.0, "M": 101.0, "U1": 104.0, "U2": 101.0, "U3": 108.0, "N": 101.0, "E": 101.0},
			"vessels": {"O2": {"V": 0.08, "kpa": 1600.0, "piece": "O2-T", "burst": 200.0}}, "valves": [], "value": 2600.0},
		# each hall its own mixture
		"atmos": {"o2": {"U1": 0.45, "U2": 0.30, "U3": 0.62}, "glass": glass},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "BAT", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "M": "LAMP-M", "U1": "GROW-1", "U2": "GROW-2", "U3": "GROW-3", "N": "LAMP-N", "E": "LAMP-E"},
		},
		"fluids": {"volumes": {
			"nut": {"fluid": "nutrient", "amount": 1.4, "piece": "NUT", "content": 1.6, "leak": 0.12, "port": "PN", "pump": [0.14, 0.01]},
			"nut_line": {"fluid": "nutrient", "amount": 0.02, "nets": ["nut"], "leak": 0.06, "leak_min": 0.004},
		}, "joins": [], "value": {"nutrient": 2200.0}},
		"ctrls_cfg": {"G-U1": {"rate": 30.0}, "G-U2": {"rate": 18.0}, "G-U3": {"rate": 26.0}, "G-C": {"rate": 14.0}, "G-M": {"rate": 6.0}, "G-N": {"rate": 9.0}, "G-E": {"rate": 16.0}, "PO2": {"rate": 0.3}},
		"labels": {"NUT": "NUTRIENT", "BAT": "BAT", "SWB": "SWB", "SEED": "SEED", "ECS": "ECS", "O2-T": "O₂", "AIR": "AIR"},
		"hints": {},
		"market": {
			"class": "HB", "name": ["栖湾级培育船", "HAVEN COVE-CLASS CULTURE SHIP"], "time": 36.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "N": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0], "M": [0.2, 40.0, 101.0]},
			"charge": {"BAT": [0.2, 1.0]},
			"fluids": {"nut": [0.2, 1.4]}, "fill": {"nut_line": "nut"},
			"knockable": ["NAV", "CON", "AIR", "HUM"],
			"drift": [],
			"section_x": S2,
			"slots": {"hidden_damage": {"plates": ["HL11-2", "HL11-3", "HL11-7", "HL11-8"]}, "fire_system": {"x": 44.0, "y0": 4.4, "y1": 6.0, "base": ["HDECK", 6.0], "room": "U2", "port": [44.4, 4.47]}},
			"mechanisms": true,
		},
		"procedures": {
			"SEED": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "SEED"},
				{"do": "deliver", "piece": "SEED", "zone": "equip"},
			],
		},
	}
