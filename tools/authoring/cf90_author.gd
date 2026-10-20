class_name Cf90Author
# Authoring script for CF-90 "Hive", a 90 m container frame (exotic batch 01/10,
# design/ships/CF-90_蜂巢_设计稿.md and CF-90_线稿+蓝图.png, as drawn). Not part of
# the game: tools/ship_export.gd runs it and writes ships/cf90.json.
# Metres, x bow (0) to the stern (90), y down.
#
# No hold: a small cockpit with its docking ring, then a wall of seven bays of
# four 12 m containers between an upper and a lower chord and eight posts; the
# containers in their slots are the beam (scripts/boxbeam.gd). Four pretension
# rods (two over the top chord, two under the bottom one), the crane rail and its
# trolley on top, four strain gauges on the lower chord. In bay four the
# pressurised habitat container, in bay six a horizontal cryogenic tank container,
# in bay seven the dangerous-goods container and the one crushed under it, with an
# empty slot under that.
# What it asks of you: each container is held by four twist locks (the wrench
# undoes them); the bays come off from the ends inwards to the one the berth holds
# (bay four), each from the top: empty a bay with the bays beyond it still full and
# the wall kinks there; take a container from under others and the stack above
# sags. The rods' turnbuckles are slackened before a rod is cut, or it whips loose.
# The habitat container still holds 60 kPa: vented first, or cut it bursts.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT_N := [Vector2(0.8, -3.6), Vector2(6.0, -4.6), Vector2(6.0, 4.6), Vector2(0.8, 3.6), Vector2(0.0, 1.5), Vector2(0.0, -1.5)]
const X0 := 6.0
const BAY := 12.0
const TOP := -7.0                # the top chord's underside
const BOT := 7.0                 # the bottom chord's top
const TIER := 3.5
# each bay's containers, top tier first: [tag, art, mass, value, special] ("" an empty slot)
const SLOTS := [
	[["C11", 6.2, 5200.0], ["C12", 7.4, 6400.0], ["C13", 6.8, 4800.0], ["C14", 8.1, 7200.0]],
	[["C21", 6.0, 4400.0], ["C22", 7.9, 6800.0], ["C23", 6.6, 5600.0], ["C24", 8.4, 7600.0]],
	[["C31", 6.4, 5000.0], ["C32", 7.2, 6000.0], ["C33", 6.9, 5400.0], ["C34", 8.0, 7000.0]],
	[["C41", 8.0, 18000.0, "hab"], ["", 0.0, 0.0], ["C43", 6.6, 5200.0], ["C44", 7.8, 6600.0]],
	[["C51", 6.3, 4600.0], ["C52", 7.5, 6200.0], ["C53", 6.8, 5000.0], ["C54", 8.2, 7400.0]],
	[["C61", 9.0, 9000.0, "cryo"], ["C62", 7.0, 5800.0], ["C63", 6.5, 4800.0], ["C64", 8.0, 6800.0]],
	[["C71", 6.4, 5000.0], ["C72", 7.5, 6000.0, "hazard"], ["C73", 4.5, 1500.0, "crushed"], ["", 0.0, 0.0]],
]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "CF90")
	w = world
	by_tag = K.by_tag
	_cockpit()
	_frame()
	_containers()
	_rods()
	_crane()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "CF90")
	w = world
	_rooms()


static func _iy(i: int, x: float) -> float:
	var inn := K.inner(OUT_N, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


static func _post_x(k: int) -> float:
	return X0 + BAY * k


# a bay's inside, between its posts
static func _bay(k: int) -> Vector2:
	var l := X0 + 0.6 if k == 0 else _post_x(k) + 0.3
	var r := _post_x(7) - 0.6 if k == 6 else _post_x(k + 1) - 0.3
	return Vector2(l, r)


# ---------------------------------------------------------------- the cockpit

static func _cockpit() -> void:
	K.ring(OUT_N, T, {0: [0.6, 0.9]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-N", "open_dir": Vector2(1.2, -0.2) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HN")
	var cn = K.equip("CON-N", "console", K.rect(1.6, _iy(0, 3.8), 3.8, -2.2), {"mass": 0.4, "value": 8000.0, "fragile": 0.5, "room": "N", "mandatory": true, "name_key": "p_cockpit_console"})
	K.bolt(cn, K.at(1.9, _iy(0, 1.9) - 0.2, ["hull"]), 1.9, _iy(0, 3.8))
	K.bolt(cn, K.at(3.5, _iy(0, 3.5) - 0.2, ["hull"]), 3.5, _iy(0, 3.8))
	var st = K.seat("SEAT", Rect2(2.4, _iy(2, 3.2) - 1.5, 0.8, 1.5), {"room": "N", "name_key": "p_seat_pilot"})
	K.bolt(st, K.at(2.6, _iy(2, 2.6) + 0.2, ["hull"]), 2.6, _iy(2, 3.2))
	K.bolt(st, K.at(3.0, _iy(2, 3.0) + 0.2, ["hull"]), 3.0, _iy(2, 3.2), "lock")
	var bt = K.equip("BAT-P", "battery", K.rect(4.2, 0.4, 5.55, 3.4), {"mass": 0.4, "value": 5000.0, "fragile": 0.4, "room": "N", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(5.8, 1.0, ["hull"]), 5.55, 1.0)
	K.bolt(bt, K.at(5.8, 2.8, ["hull"]), 5.55, 2.8)
	var av = K.equip("AV-P", "nav_rack", K.rect(4.2, -3.4, 5.55, -0.4), {"mass": 0.2, "value": 6000.0, "fragile": 0.5, "room": "N", "name_key": "p_avionics"})
	K.bolt(av, K.at(5.8, -2.8, ["hull"]), 5.55, -2.8)
	K.bolt(av, K.at(5.8, -1.0, ["hull"]), 5.55, -1.0)
	K.lamp("LAMP-N", 2.8, _iy(0, 2.8), "N", K.at(2.8, _iy(0, 2.8) - 0.2, ["hull"]))
	# the docking ring on the bow
	var dk = K.equip("DOCK", "dock", K.rect(-1.2, -1.4, 0.0, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(0.2, -1.0, ["hull"]), 0.0, -1.0)
	K.bolt(dk, K.at(0.2, 1.0, ["hull"]), 0.0, 1.0)
	K.clamp(2, 3.0, 4.02, 3.82)


# ---------------------------------------------------------------- the frame: chords and posts

static func _frame() -> void:
	var C := {"density": 2.2, "barrier": false, "cut_speed": 120.0}
	for k in 7:
		var x0 := _post_x(k)
		var x1 := _post_x(k + 1)
		var tc = K.plate("TC-%d" % (k + 1), K.R(x0, TOP - 0.6, x1, TOP), C.merged({"name_key": "p_top_chord"}), "keel")
		var bc = K.plate("BC-%d" % (k + 1), K.R(x0, BOT, x1, BOT + 0.6), C.merged({"name_key": "p_bottom_chord"}), "keel")
		if k > 0:
			K.bolt(tc, by_tag["TC-%d" % k], x0, TOP - 0.3, "weld")
			K.bolt(bc, by_tag["BC-%d" % k], x0, BOT + 0.3, "weld")
	for k in 8:
		var x := _post_x(k)
		var xa := x if k == 0 else (x - 0.6 if k == 7 else x - 0.3)
		var po = K.plate("P%d" % k, K.R(xa, TOP, xa + 0.6, BOT), {"density": 1.8, "barrier": false, "cut_speed": 140.0, "name_key": "p_post"}, "beam")
		var bk := mini(k, 6) + 1
		K.bolt(po, by_tag["TC-%d" % bk], xa + 0.3, TOP, "weld")
		K.bolt(po, by_tag["BC-%d" % bk], xa + 0.3, BOT, "weld")
	# the frame on the cockpit's aft wall
	K.bolt(by_tag["P0"], K.at(5.8, 0.0, ["hull"]), 6.0, 0.0, "weld")
	K.bolt(by_tag["P0"], K.at(5.8, -3.0, ["hull"]), 6.0, -3.0, "weld")


# ---------------------------------------------------------------- the containers, four twist locks each

static func _containers() -> void:
	for k in 7:
		var bx := _bay(k)
		var x0: float = bx.x + 0.1
		var x1: float = bx.y - 0.1
		for t in 4:
			var e: Array = SLOTS[k][t]
			if e[0] == "":
				continue
			var y0 := TOP + TIER * t + 0.1
			var y1 := y0 + TIER - 0.2
			var sp: String = e[3] if e.size() > 3 else ""
			var art := "cryotank" if sp == "cryo" else "cargo"
			var opts := {"mass": e[1], "value": e[2], "fragile": 0.3, "name_key": "p_container"}
			var poly = null
			match sp:
				"hab":
					opts.name_key = "p_hab_container"
					opts.fragile = 0.45
				"cryo":
					opts.name_key = "p_cryo_container"
					opts.hazard = "gas_tank"
				"hazard":
					opts.name_key = "p_dg_container"
					opts.hazard = "chem"
				"crushed":
					opts.name_key = "p_crushed_container"
					poly = K.mp([Vector2(x0, y0 + 0.9), Vector2(x1, y0 + 1.7), Vector2(x1, y1), Vector2(x0, y1 - 0.4)])
			var c = K.equip(e[0], art, K.rect(x0, y0, x1, y1), opts, poly)
			if sp != "crushed" and float(e[1]) > 5.0:
				var third := (x1 - x0) / 3.0
				c.set_meta("segments", [[x0 + third, y0, x0 + third, y1], [x1 - third, y0, x1 - third, y1]])
			if sp == "crushed":
				# jammed at its ends against the posts, its corners torn
				K.bolt(c, by_tag["P%d" % k], bx.x, y1 - 0.6, "lock")
				K.bolt(c, by_tag["P%d" % (k + 1)], bx.y, y1 - 0.3, "lock")
				continue
			# the twist locks: the top corners to what is above, the bottom ones to what is below
			var above = by_tag["TC-%d" % (k + 1)] if t == 0 else by_tag.get(SLOTS[k][t - 1][0] if SLOTS[k][t - 1][0] != "" else "-", null)
			if above != null:
				K.bolt(c, above, x0 + 0.5, y0 - 0.05, "lock")
				K.bolt(c, above, x1 - 0.5, y0 - 0.05, "lock")
			if t == 3:
				K.bolt(c, by_tag["BC-%d" % (k + 1)], x0 + 0.5, y1 + 0.05, "lock")
				K.bolt(c, by_tag["BC-%d" % (k + 1)], x1 - 0.5, y1 + 0.05, "lock")
			elif SLOTS[k][t + 1][0] == "" or (SLOTS[k][t + 1].size() > 3 and SLOTS[k][t + 1][3] == "crushed"):
				# nothing sound under it: braced to its posts instead
				K.bolt(c, by_tag["P%d" % k], bx.x, y1 - 0.5, "lock")
				K.bolt(c, by_tag["P%d" % (k + 1)], bx.y, y1 - 0.5, "lock")


# ---------------------------------------------------------------- the pretension rods, the gauges

static func _rods() -> void:
	var L := {"density": 1.6, "barrier": false, "cut_speed": 150.0}
	var ends := [[6.0, 6.6, 1], [47.7, 48.3, 4], [89.4, 90.0, 7]]
	var k := 0
	for e in ends:
		k += 1
		var lg = K.plate("LG-%d" % k, K.R(e[0], BOT + 0.6, e[1], BOT + 1.6), L.merged({"name_key": "p_rod_lug"}), "strut")
		K.bolt(lg, by_tag["BC-%d" % e[2]], (e[0] + e[1]) * 0.5, BOT + 0.6, "weld")
		var rb = K.plate("RB-%d" % k, K.R(e[0], TOP - 2.6, e[1], TOP - 0.6), L.merged({"name_key": "p_rail_bracket"}), "strut")
		K.bolt(rb, by_tag["TC-%d" % e[2]], (e[0] + e[1]) * 0.5, TOP - 0.6, "weld")
	K.clamp(1, 48.0, BOT + 1.6, BOT + 1.4, ["strut"])
	var R := {"density": 1.4, "barrier": false, "cut_speed": 160.0, "name_key": "p_tension_rod"}
	for e in [["TR-1", 6.6, 47.7, BOT + 1.0, "LG-1", "LG-2"], ["TR-2", 48.3, 89.4, BOT + 1.0, "LG-2", "LG-3"],
			["TR-3", 6.6, 47.7, TOP - 1.2, "RB-1", "RB-2"], ["TR-4", 48.3, 89.4, TOP - 1.2, "RB-2", "RB-3"]]:
		var y: float = e[3]
		var rd = K.plate(e[0], K.R(e[1], y, e[2], y + 0.2), R, "rail")
		K.bolt(rd, by_tag[e[4]], e[1], y + 0.1, "bolt")
		K.bolt(rd, by_tag[e[5]], e[2], y + 0.1, "bolt")
	# the strain gauges on the lower chord, under bays two, three, five and six
	k = 0
	for b in [1, 2, 4, 5]:
		k += 1
		var cx := _post_x(b) + BAY * 0.5
		var sg = K.equip("SG-%d" % k, "insp", K.rect(cx - 0.4, BOT + 0.6, cx + 0.4, BOT + 0.9), {"mass": 0.02, "value": 1500.0, "fragile": 0.5, "name_key": "p_strain_gauge"})
		K.bolt(sg, by_tag["BC-%d" % (b + 1)], cx, BOT + 0.6)


# ---------------------------------------------------------------- the crane rail and its trolley

static func _crane() -> void:
	var rl = K.plate("CR-1", K.R(6.0, TOP - 3.0, 90.0, TOP - 2.6), {"density": 1.6, "barrier": false, "cut_speed": 140.0, "name_key": "p_crane_rail"}, "beam")
	for k in 3:
		var x: float = [6.3, 48.0, 89.7][k]
		K.bolt(rl, by_tag["RB-%d" % (k + 1)], x, TOP - 2.6, "weld")
	var tr = K.equip("CR-T", "hook", K.rect(52.0, TOP - 4.25, 57.0, TOP - 3.05), {"mass": 1.2, "value": 12000.0, "fragile": 0.35, "name_key": "p_crane_trolley"})
	K.bolt(tr, rl, 52.8, TOP - 3.0)
	K.bolt(tr, rl, 56.2, TOP - 3.0)


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT-P", Vector2(4.8, 0.4), "AV-P", Vector2(4.8, -0.4))
	K.line("p2", "cable", "power", "AV-P", Vector2(4.2, -2.0), "LAMP-N", Vector2(2.8, _iy(0, 2.8) + 0.16), [Vector2(3.9, -2.0), Vector2(3.9, -1.8), Vector2(2.8, -1.8)])
	K.line("p3", "cable", "power", "AV-P", Vector2(4.2, -3.0), "CON-N", Vector2(3.8, -2.6), [Vector2(4.0, -3.0), Vector2(4.0, -2.6)])
	# up the forward post to the trolley on the rail
	K.line("p4", "cable", "power", "AV-P", Vector2(5.2, -3.4), "CR-T", Vector2(52.4, TOP - 3.6), [Vector2(5.2, -3.9), Vector2(6.3, -3.9), Vector2(6.3, TOP - 3.4), Vector2(52.0, TOP - 3.4)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-N", "port", K.at(2.0, _iy(0, 2.0) - 0.25, ["hull"]), Vector2(2.0, -4.07), {"medium": "gas", "target": "N"})
	K.ctrl("K-P", "switch", K.at(5.8, 3.8, ["hull"]), Vector2(5.65, 3.8), {"target": "K-P", "state": true, "hidden_room": "N"})
	K.ctrl("E-1", "test", by_tag["AV-P"], Vector2(4.8, -1.0), {"medium": "volt", "target": "bus", "hidden_room": "N"})
	K.door("HT-N", "")
	var k := 0
	for e in [["TR-1", 27.0, BOT + 1.1], ["TR-2", 69.0, BOT + 1.1], ["TR-3", 27.0, TOP - 1.1], ["TR-4", 69.0, TOP - 1.1]]:
		k += 1
		K.ctrl("TB-%d" % k, "switch", by_tag[e[0]], Vector2(e[1], e[2]), {"target": "TB-%d" % k, "state": true})
		K.ctrl("T-TR%d" % k, "probe", by_tag[e[0]], Vector2(e[1] + 2.0, e[2]), {"medium": "rod", "target": e[0]})
	for i in 4:
		var b: int = [1, 2, 4, 5][i]
		K.ctrl("SG-%d" % (i + 1), "probe", by_tag["SG-%d" % (i + 1)], Vector2(_post_x(b) + BAY * 0.5, BOT + 0.75), {"medium": "strain", "target": str(b)})
	var hb := _bay(3)
	K.ctrl("HP-H", "port", by_tag["C41"], Vector2(hb.x + 1.0, TOP + 0.6), {"medium": "gas", "target": "C41"})
	var cb := _bay(5)
	K.ctrl("CP-C", "port", by_tag["C61"], Vector2(cb.x + 1.0, TOP + 0.6), {"medium": "gas", "target": "C61"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	var inn := K.inner(OUT_N, T)
	w.add_room("N", K.mp(inn))


static func meta() -> Dictionary:
	var bays: Array = []
	for k in 7:
		var b: Array = []
		for t in 4:
			if SLOTS[k][t][0] != "":
				b.append(SLOTS[k][t][0])
		bays.append(b)
	return {
		"id": "cf90",
		"name": "CF-90 HIVE",
		"title": ["CF-90「蜂巢」集装箱承力货架 · 90 m", "CF-90 HIVE · CONTAINER FRAME · 90 m"],
		"contract": "CF-90",
		"length": 90.0,
		"value": {"total": 234200.0, "metal": 30000.0},
		"clamps": [[48.0, BOT + 1.6], [3.0, 4.02]],
		"room_names": {"N": "room_cfN"},
		"gas": {"rooms": {"N": 101.0},
			"vessels": {"C41": {"V": 40.0, "kpa": 60.0, "piece": "C41", "burst": 40.0}, "C61": {"V": 6.0, "kpa": 450.0, "piece": "C61", "burst": 200.0}},
			"valves": [], "value": 1500.0},
		"boxbeam": {"bays": bays, "support": 3, "stiff": 0.75, "limit": 6.0,
			"gauges": {"SG-1": 1, "SG-2": 2, "SG-3": 4, "SG-4": 5},
			"rods": {"TR-1": {"turnbuckle": "TB-1", "bays": [0], "hits": [], "kn": 85.0}, "TR-2": {"turnbuckle": "TB-2", "bays": [6], "hits": [], "kn": 85.0},
				"TR-3": {"turnbuckle": "TB-3", "bays": [0], "hits": ["CR-T"], "kn": 85.0}, "TR-4": {"turnbuckle": "TB-4", "bays": [6], "hits": ["CR-T"], "kn": 85.0}}},
		"power": {
			"bus": "AV-P",
			"sources": [
				{"piece": "BAT-P", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-P", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"N": "LAMP-N"},
		},
		"ctrls_cfg": {"G-N": {"rate": 20.0}, "HP-H": {"rate": 30.0}, "CP-C": {"rate": 1.5}},
		"labels": {"BAT-P": "BAT", "AV-P": "AV", "CR-T": "TROLLEY", "C41": "C-HAB", "C61": "CRYO", "C72": "DG", "C73": "C73"},
		"hints": {},
		"market": {
			"class": "CF", "name": ["蜂巢级集装箱承力货架", "HIVE-CLASS CONTAINER FRAME"], "time": 35.0,
			"rooms": {"N": [0.2, 40.0, 101.0]},
			"charge": {"BAT-P": [0.3, 1.0]},
			"knockable": ["CON-N", "AV-P"],
			"drift": [],
			"section_x": 54.0,
			"slots": {"fire_system": {"x": 1.4, "y0": 2.0, "y1": _iy(2, 2.2), "base": ["HN2-0", _iy(2, 2.2)], "room": "N", "port": [1.8, 2.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"CON-N": [
				{"do": "hose", "ctrl": "G-N"},
				{"do": "wait", "until": {"P": ["N", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-N"},
				{"do": "wait", "until": {"open": ["N"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-P"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CON-N"},
				{"do": "deliver", "piece": "CON-N", "zone": "equip"},
			],
		},
	}
