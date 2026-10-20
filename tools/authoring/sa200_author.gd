class_name Sa200Author
# Authoring script for SA-200 "Kite", a light-sail cargo ship (exotic batch 02/10,
# design/ships/SA-200_纸鸢_设计稿.md and SA-200_线稿.png, as drawn): a 180 x 120 m
# sail facing the camera, a 24 m gondola in its middle. Not part of the game:
# tools/ship_export.gd runs it and writes ships/sa200.json.
# Metres, x left edge (0) to right edge (180), y down (-60 top to 60 bottom).
#
# The frame: four edge spars of three sections each. From the gondola, four
# braces run to the corners and twenty-four stays to the edges; between each two
# of them a panel of film (it hangs in the frame, the drone flies past it). The
# gondola: the only pressurised room, with its avionics and battery, fuel cell,
# the four sail winches, the water tank, the console; the docking ring on its left,
# the main engine on its right. A tear of 12 m already runs through the panel at
# the top right corner.
# What it asks of you (scripts/sail.gd): earth the sail at its clamp before you go
# near the film; let off the four winches' brakes in the gondola so the sail goes
# slack; then the film comes off whole, panel by panel, and the stays and braces
# after it. Taut, a panel cut or freed tears (and the tear runs on), a stay cut or
# freed snaps and its spar whips into the gondola.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.9
const W := 180.0
const H := 60.0
const SPAR := 1.2
const OUT_G := [Vector2(80.0, -8.0), Vector2(100.0, -8.0), Vector2(102.0, -6.0), Vector2(102.0, 6.0), Vector2(100.0, 8.0),
	Vector2(80.0, 8.0), Vector2(78.0, 6.0), Vector2(78.0, -6.0)]
const GC := Vector2(90.0, 0.0)

static var w
static var by_tag := {}
# the radial members in order round the gondola: [tag, gondola end, frame end, quadrant, corner after it or null]
static var members: Array = []


static func build(world) -> void:
	K.begin(world, "SA200")
	w = world
	by_tag = K.by_tag
	_plan()
	_frame()
	_gondola()
	_members()
	_film()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "SA200")
	w = world
	_rooms()


static func _quad(p: Vector2) -> String:
	return ("N" if p.y < 0.0 else "S") + ("W" if p.x < 90.0 else "E")


static func _plan() -> void:
	members = []
	var L := SPAR
	var R := W - SPAR
	var TT := -H + SPAR
	var BB := H - SPAR
	members.append(["BR-1", Vector2(79.0, -7.0), Vector2(L, TT), "NW", Vector2(80.0, -8.0)])
	for k in range(1, 9):
		var f := Vector2(L + (R - L) * k / 9.0, TT)
		var g := Vector2(80.0 + 20.0 * k / 9.0, -8.0)
		members.append(["ST-%d" % k, g, f, _quad(f), Vector2(100.0, -8.0) if k == 8 else null])
	members.append(["BR-2", Vector2(101.0, -7.0), Vector2(R, TT), "NE", null])
	var ry := [-6.0, -3.0, 3.0, 6.0]
	for k in range(1, 5):
		var f := Vector2(R, TT + (BB - TT) * k / 5.0)
		members.append(["ST-%d" % (8 + k), Vector2(102.0, ry[k - 1]), f, _quad(f), null])
	members.append(["BR-3", Vector2(101.0, 7.0), Vector2(R, BB), "SE", Vector2(100.0, 8.0)])
	for k in range(1, 9):
		var f := Vector2(R - (R - L) * k / 9.0, BB)
		var g := Vector2(100.0 - 20.0 * k / 9.0, 8.0)
		members.append(["ST-%d" % (12 + k), g, f, _quad(f), Vector2(80.0, 8.0) if k == 8 else null])
	members.append(["BR-4", Vector2(79.0, 7.0), Vector2(L, BB), "SW", null])
	for k in range(1, 5):
		var f := Vector2(L, BB - (BB - TT) * k / 5.0)
		members.append(["ST-%d" % (20 + k), Vector2(78.0, -ry[k - 1]), f, _quad(f), null])


# the spar section a frame point is on
static func _spar_at(p: Vector2) -> String:
	if p.y <= -H + SPAR + 0.01:
		return "SP-T%d" % (clampi(int(p.x / 60.0), 0, 2) + 1)
	if p.y >= H - SPAR - 0.01:
		return "SP-B%d" % (clampi(int(p.x / 60.0), 0, 2) + 1)
	var s := clampi(int((p.y + H - SPAR) / ((2.0 * H - 2.0 * SPAR) / 3.0)), 0, 2) + 1
	return ("SP-L%d" if p.x < 90.0 else "SP-R%d") % s


# ---------------------------------------------------------------- the frame

static func _frame() -> void:
	var S := {"cls": "equip", "dest": "equip", "mass": 0.8, "value": 5000.0, "fragile": 0.2, "density": 1.4, "cut_speed": 150.0, "art": "", "barrier": false, "name_key": "p_spar"}
	for i in 3:
		var x0 := 60.0 * i
		K.plate("SP-T%d" % (i + 1), K.R(x0, -H, x0 + 60.0, -H + SPAR), S, "beam")
		K.plate("SP-B%d" % (i + 1), K.R(x0, H - SPAR, x0 + 60.0, H), S, "beam")
	var seg := (2.0 * H - 2.0 * SPAR) / 3.0
	for i in 3:
		var y0 := -H + SPAR + seg * i
		K.plate("SP-L%d" % (i + 1), K.R(0.0, y0, SPAR, y0 + seg), S, "beam")
		K.plate("SP-R%d" % (i + 1), K.R(W - SPAR, y0, W, y0 + seg), S, "beam")
	for i in 2:
		var x := 60.0 * (i + 1)
		K.bolt(by_tag["SP-T%d" % (i + 1)], by_tag["SP-T%d" % (i + 2)], x, -H + SPAR * 0.5, "bolt")
		K.bolt(by_tag["SP-B%d" % (i + 1)], by_tag["SP-B%d" % (i + 2)], x, H - SPAR * 0.5, "bolt")
		var y := -H + SPAR + seg * (i + 1)
		K.bolt(by_tag["SP-L%d" % (i + 1)], by_tag["SP-L%d" % (i + 2)], SPAR * 0.5, y, "bolt")
		K.bolt(by_tag["SP-R%d" % (i + 1)], by_tag["SP-R%d" % (i + 2)], W - SPAR * 0.5, y, "bolt")
	# the corners, hinged
	K.bolt(by_tag["SP-T1"], by_tag["SP-L1"], SPAR * 0.5, -H + SPAR, "bolt")
	K.bolt(by_tag["SP-T3"], by_tag["SP-R1"], W - SPAR * 0.5, -H + SPAR, "bolt")
	K.bolt(by_tag["SP-B3"], by_tag["SP-R3"], W - SPAR * 0.5, H - SPAR, "bolt")
	K.bolt(by_tag["SP-B1"], by_tag["SP-L3"], SPAR * 0.5, H - SPAR, "bolt")
	K.clamp(1, 30.0, H, H - 0.2, ["beam"])
	K.clamp(2, 150.0, H, H - 0.2, ["beam"])


# ---------------------------------------------------------------- the gondola

static func _gondola() -> void:
	K.ring(OUT_G, T, {2: [0.783, 0.967]}, {
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-G", "open_dir": Vector2(0, -2.4) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 200.0}, "HG")
	var top := -8.0 + T
	var bot := 8.0 - T
	var E := func(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, opts: Dictionary, on_top: bool):
		var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts.merged({"room": "G"}))
		var yb := y0 if on_top else y1
		var yh := top - 0.2 if on_top else bot + 0.2
		K.bolt(p, K.at(x0 + 0.4, yh, ["hull"]), x0 + 0.4, yb)
		K.bolt(p, K.at(x1 - 0.4, yh, ["hull"]), x1 - 0.4, yb)
		return p
	E.call("AV-G", "nav_rack", 80.0, top, 83.0, -4.4, {"mass": 0.5, "value": 9000.0, "fragile": 0.5, "name_key": "p_avionics"}, true)
	E.call("BAT-G", "battery", 83.6, top, 86.6, -4.6, {"mass": 0.7, "value": 9000.0, "fragile": 0.4, "hazard": "battery", "name_key": "p_battery"}, true)
	E.call("FC-G", "cap", 87.2, top, 90.4, -4.4, {"mass": 1.0, "value": 12000.0, "fragile": 0.4, "name_key": "p_fuel_cell"}, true)
	E.call("WINCH-1", "reel", 91.0, top, 94.0, -4.0, {"mass": 0.8, "value": 8000.0, "fragile": 0.35, "name_key": "p_sail_winch"}, true)
	E.call("WINCH-2", "reel", 94.6, top, 97.6, -4.0, {"mass": 0.8, "value": 8000.0, "fragile": 0.35, "name_key": "p_sail_winch"}, true)
	E.call("WINCH-3", "reel", 80.0, 4.0, 83.0, bot, {"mass": 0.8, "value": 8000.0, "fragile": 0.35, "name_key": "p_sail_winch"}, false)
	E.call("WINCH-4", "reel", 83.6, 4.0, 86.6, bot, {"mass": 0.8, "value": 8000.0, "fragile": 0.35, "name_key": "p_sail_winch"}, false)
	E.call("TANK-G", "water", 87.2, 3.4, 92.8, bot, {"mass": 2.0, "value": 6000.0, "fragile": 0.35, "name_key": "p_water_tank"}, false)
	E.call("CON-G", "console", 93.4, 5.2, 97.6, bot, {"mass": 0.4, "value": 8000.0, "fragile": 0.5, "mandatory": true, "name_key": "p_gondola_console"}, false)
	K.lamp("LAMP-G", 90.0, bot, "G", K.at(90.0, bot + 0.2, ["hull"]))
	# the docking ring and the main engine outside
	var dk = K.equip("DOCK", "dock", K.rect(75.6, -1.6, 78.0, 1.6), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(78.3, -1.0, ["hull"]), 78.0, -1.0)
	K.bolt(dk, K.at(78.3, 1.0, ["hull"]), 78.0, 1.0)
	var en = K.equip("ENG-G", "eng_core", K.rect(102.0, -1.6, 105.6, 1.6), {"mass": 2.4, "value": 35000.0, "fragile": 0.3, "name_key": "p_engine"})
	K.bolt(en, K.at(101.7, -1.0, ["hull"]), 102.0, -1.0)
	K.bolt(en, K.at(101.7, 1.0, ["hull"]), 102.0, 1.0)
	var nz = K.equip("NOZ-G", "nozzle", K.rect(105.6, -2.2, 109.6, 2.2), {"cls": "metal", "dest": "metal", "mass": 0.6, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(105.6, -1.2), Vector2(109.6, -2.2), Vector2(109.6, 2.2), Vector2(105.6, 1.2)]))
	K.bolt(nz, en, 105.6, -0.6)
	K.bolt(nz, en, 105.6, 0.6)


# ---------------------------------------------------------------- the braces and stays

static func _members() -> void:
	for m in members:
		var g: Vector2 = m[1]
		var f: Vector2 = m[2]
		var brace: bool = str(m[0]).begins_with("BR")
		var wd := 0.8 if brace else 0.3
		var d := (f - g).normalized()
		var n := Vector2(-d.y, d.x) * wd * 0.5
		var a := g + d * 0.05
		var b := f - d * 0.05
		var opts := {"density": 0.6, "barrier": false, "cut_speed": 260.0, "name_key": "p_sail_brace" if brace else "p_sail_stay"}
		if brace:
			opts.merge({"cls": "equip", "dest": "equip", "mass": 1.2, "value": 3000.0, "fragile": 0.2, "art": ""})
		else:
			opts.merge({"mass": 0.05})
		var pc = K.plate(m[0], K.mp([a + n, b + n, b - n, a - n]), opts, "rail")
		K.bolt(pc, K.at(g.x - d.x * 0.3, g.y - d.y * 0.3, ["hull"]), a.x, a.y, "bolt")
		K.bolt(pc, by_tag[_spar_at(f)], b.x, b.y, "bolt")


# ---------------------------------------------------------------- the film, a panel between each two members

static func _film() -> void:
	var n := members.size()
	for i in n:
		var m0: Array = members[i]
		var m1: Array = members[(i + 1) % n]
		var pts: Array = [m0[1], m0[2]]
		# round a frame corner between them
		var f0: Vector2 = m0[2]
		var f1: Vector2 = m1[2]
		if absf(f0.x - f1.x) > 0.01 and absf(f0.y - f1.y) > 0.01:
			pts.append(Vector2(f1.x, f0.y) if absf(f0.y) > absf(f1.y) - 0.01 and absf(f0.y) >= H - SPAR - 0.01 else Vector2(f0.x, f1.y))
		pts.append(f1)
		pts.append(m1[1])
		if m0[4] != null:
			pts.append(m0[4])
		var poly := K.mp(pts)
		var fm = K.plate("FM-%d" % (i + 1), poly, {"cls": "metal", "dest": "metal", "mass": 0.03, "density": 0.05, "barrier": false, "cut_speed": 400.0, "name_key": "p_sail_film"}, "film")
		# its edge ropes: along both members and the spar
		for t in [0.35, 0.75]:
			var p0: Vector2 = (m0[1] as Vector2).lerp(m0[2], t)
			var p1: Vector2 = (m1[1] as Vector2).lerp(m1[2], t)
			K.bolt(fm, by_tag[m0[0]], p0.x, p0.y, "bolt")
			K.bolt(fm, by_tag[m1[0]], p1.x, p1.y, "bolt")
		var fe: Vector2 = (f0 + f1) * 0.5
		K.bolt(fm, by_tag[_spar_at(fe)], fe.x, fe.y, "bolt")


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT-G", Vector2(85.0, -4.6), "AV-G", Vector2(83.0, -5.0), [Vector2(85.0, -4.3), Vector2(83.3, -4.3), Vector2(83.3, -5.0)])
	K.line("p2", "cable", "power", "AV-G", Vector2(81.5, -4.4), "LAMP-G", Vector2(90.0, 8.0 - T - 0.16), [Vector2(81.5, 0.0), Vector2(90.0, 0.0)])
	K.line("p3", "cable", "power", "AV-G", Vector2(82.5, -4.4), "CON-G", Vector2(95.0, 5.2), [Vector2(82.5, -1.0), Vector2(95.0, -1.0)])
	K.line("p4", "cable", "power", "CON-G", Vector2(96.0, 5.2), "WINCH-2", Vector2(96.0, -4.0))
	K.line("p5", "cable", "power", "CON-G", Vector2(94.0, 5.2), "WINCH-1", Vector2(92.5, -4.0), [Vector2(94.0, 1.0), Vector2(92.5, 1.0)])
	K.line("p6", "cable", "power", "AV-G", Vector2(80.6, -4.4), "WINCH-3", Vector2(81.5, 4.0), [Vector2(80.6, 2.0), Vector2(81.5, 2.0)])
	K.line("p7", "cable", "power", "WINCH-3", Vector2(83.0, 5.0), "WINCH-4", Vector2(83.6, 5.0))
	K.line("p8", "cable", "power", "AV-G", Vector2(82.0, -4.4), "ENG-G", Vector2(102.4, -1.6), [Vector2(82.0, -2.4), Vector2(102.4, -2.4)])
	K.line("w1", "pipe", "water", "TANK-G", Vector2(92.8, 5.0), "CON-G", Vector2(93.4, 6.4), [Vector2(93.1, 5.0), Vector2(93.1, 6.4)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-G", "port", K.at(85.0, -7.8, ["hull"]), Vector2(85.0, -8.25), {"medium": "gas", "target": "G"})
	K.door("HT-G", "")
	K.ctrl("K-G", "switch", by_tag["AV-G"], Vector2(81.0, -5.0), {"target": "K-G", "state": true, "hidden_room": "G"})
	K.ctrl("E-1", "test", by_tag["AV-G"], Vector2(82.2, -5.6), {"medium": "volt", "target": "bus", "hidden_room": "G"})
	var k := 0
	for e in [["W-NW", "WINCH-1", 92.5], ["W-NE", "WINCH-2", 96.1], ["W-SE", "WINCH-4", 85.1], ["W-SW", "WINCH-3", 81.5]]:
		var wp = by_tag[e[1]]
		var bb := Geom.bbox(wp.poly)
		K.ctrl(e[0], "switch", wp, Vector2(e[2], bb.get_center().y / Geom.M), {"target": e[0], "state": true, "hidden_room": "G"})
		k += 1
	K.ctrl("PW", "port", by_tag["TANK-G"], Vector2(90.0, 3.8), {"medium": "water", "target": "water", "hidden_room": "G"})
	# the earthing clamp on the bottom left spar
	K.ctrl("GND", "switch", by_tag["SP-B1"], Vector2(4.0, H - SPAR * 0.5), {"target": "GND", "state": false})
	# a tension gauge on a stay in each quadrant
	for e in [["T-NW", "ST-2"], ["T-NE", "ST-7"], ["T-SE", "ST-14"], ["T-SW", "ST-19"]]:
		var m: Array = []
		for mm in members:
			if mm[0] == e[1]:
				m = mm
		var at: Vector2 = (m[1] as Vector2).lerp(m[2], 0.25)
		K.ctrl(e[0], "probe", by_tag[e[1]], at, {"medium": "stay", "target": e[1]})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	w.add_room("G", K.mp(K.inner(OUT_G, T)))


static func meta() -> Dictionary:
	if members.is_empty():
		_plan()
	var n := members.size()
	var panels := {}
	var stays := {}
	var hits := {"NW": ["WINCH-1", "AV-G"], "NE": ["WINCH-2", "ENG-G"], "SE": ["WINCH-4", "TANK-G"], "SW": ["WINCH-3", "DOCK"]}
	for i in n:
		var c: Vector2 = ((members[i][2] as Vector2) + (members[(i + 1) % n][2] as Vector2)) * 0.5
		panels["FM-%d" % (i + 1)] = {"quad": _quad(c), "next": ["FM-%d" % ((i - 1 + n) % n + 1), "FM-%d" % ((i + 1) % n + 1)]}
	for i in n:
		var m: Array = members[i]
		stays[m[0]] = {"quad": m[3], "panels": ["FM-%d" % ((i - 1 + n) % n + 1), "FM-%d" % (i + 1)], "hits": hits[m[3]], "kn": 12.0}
	return {
		"id": "sa200",
		"name": "SA-200 KITE",
		"title": ["SA-200「纸鸢」光帆货船 · 帆展 180 m", "SA-200 KITE · LIGHT-SAIL FREIGHTER · 180 m SAIL"],
		"contract": "SA-200",
		"length": 180.0,
		"value": {"total": 201300.0, "metal": 12000.0},
		"clamps": [[30.0, H], [150.0, H]],
		"room_names": {"G": "room_saG"},
		"gas": {"rooms": {"G": 101.0}, "vessels": {}, "valves": [], "value": 1500.0},
		"sail": {"quads": {"NW": "W-NW", "NE": "W-NE", "SE": "W-SE", "SW": "W-SW"}, "panels": panels, "stays": stays, "torn": ["FM-9"], "ground": "GND"},
		"power": {
			"bus": "AV-G",
			"sources": [
				{"piece": "BAT-G", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-G", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"G": "LAMP-G"},
		},
		"fluids": {"volumes": {
			"water": {"fluid": "water", "amount": 0.4, "piece": "TANK-G", "port": "PW", "full": 0.5, "content": 1.0, "leak": 0.1, "pump": [0.15, 0.006]},
			"water_line": {"fluid": "water", "amount": 0.02, "nets": ["water"], "leak": 0.05, "leak_min": 0.005},
		}, "joins": [], "value": {"water": 800.0}},
		"ctrls_cfg": {"G-G": {"rate": 30.0}},
		"labels": {"BAT-G": "BAT", "AV-G": "AV", "FC-G": "FUEL CELL", "TANK-G": "H2O", "WINCH-1": "WINCH NW", "WINCH-2": "WINCH NE", "WINCH-3": "WINCH SW", "WINCH-4": "WINCH SE"},
		"hints": {},
		"market": {
			"class": "SA", "name": ["纸鸢级光帆货船", "KITE-CLASS LIGHT-SAIL FREIGHTER"], "time": 45.0,
			"rooms": {"G": [0.2, 40.0, 101.0]},
			"charge": {"BAT-G": [0.3, 1.0]},
			"fluids": {"water": [0.1, 0.4]}, "fill": {"water_line": "water"},
			"knockable": ["CON-G", "AV-G"],
			"drift": [],
			"section_x": 90.0,
			"slots": {"fire_system": {"x": 98.2, "y0": 5.0, "y1": 8.0 - T, "base": ["HG4-0", 8.0 - T], "room": "G", "port": [98.6, 5.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"CON-G": [
				{"do": "hose", "ctrl": "G-G"},
				{"do": "wait", "until": {"P": ["G", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-G"},
				{"do": "wait", "until": {"open": ["G"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-G"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CON-G"},
				{"do": "deliver", "piece": "CON-G", "zone": "equip"},
			],
		},
	}
