class_name Ih55Author
# Authoring script for IH-55 "Puffer", a 55 m inflatable habitat transport (exotic
# batch 04/10, design/ships/IH-55_河豚_设计稿.md and IH-55_线稿.png, as drawn). Not
# part of the game: tools/ship_export.gd runs it and writes ships/ih55.json.
# Metres, x bow (0) to the nozzle (58), y down.
#
# The docking node forward (a 3.5 m sphere, the only rigid way in), the rigid spine
# with its equipment between two beams, four soft bags hung on it (19 m forward,
# 21 m aft, above and below), three straps round each on a tensioner, a bulging
# patch on the aft upper bag, the rigid service module aft with its fuel cell,
# battery and engine.
# What it asks of you (scripts/softshell.gd): each bag is a 30 kPa gas volume that
# keeps its shape only by its pressure. Let each down at its port on the spine (it
# folds flat), then slacken its tensioner, then the straps come off and the bag
# after them. Cut a bag (or its patch) still inflated and it rips and comes down on
# the spine's equipment; cut a strap taut and it whips.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const SPINE := [7.0, 15.0, 23.0, 31.0, 39.0, 47.1]
const OUT_S := [Vector2(47.1, -4.0), Vector2(48.1, -5.0), Vector2(54.0, -5.0), Vector2(55.0, -4.0), Vector2(55.0, 4.0),
	Vector2(54.0, 5.0), Vector2(48.1, 5.0), Vector2(47.1, 4.0)]
# the bags: [tag, centre, radius, side]
const BAGS := [["L1", Vector2(16.0, -11.1), 9.5, -1], ["L2", Vector2(16.0, 11.1), 9.5, 1],
	["L3", Vector2(37.6, -12.1), 10.5, -1], ["L4", Vector2(37.6, 12.1), 10.5, 1]]

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "IH55")
	w = world
	by_tag = K.by_tag
	_node()
	_spine()
	_service()
	_equipment()
	_bags()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "IH55")
	w = world
	_rooms()


static func _circle(c: Vector2, r: float, n: int) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * (float(i) + 0.5) / n - PI / 2.0
		out.append(c + Vector2.from_angle(a) * r)
	return out


static func _seg(top: bool, x: float) -> String:
	for i in SPINE.size() - 1:
		if x >= SPINE[i] and x <= SPINE[i + 1]:
			return ("SP-T%d" if top else "SP-B%d") % (i + 1)
	return ""


# ---------------------------------------------------------------- the docking node

static func _node() -> void:
	var out := _circle(Vector2(3.8, 0.0), 3.5, 16)
	K.ring(out, T, {}, {"13:0": {"kind": "hatch", "door": true, "tag": "HT-N", "open_dir": Vector2(-1.0, 1.0) * Geom.M, "cut_speed": 200.0}},
		{"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HN")
	var av = K.equip("AV-N", "nav_rack", K.rect(2.6, -2.78, 4.6, -1.2), {"mass": 0.3, "value": 6000.0, "fragile": 0.5, "room": "N", "mandatory": true, "name_key": "p_avionics"})
	K.bolt(av, K.at(3.2, -3.2, ["hull"]), 3.2, -2.78)
	K.bolt(av, K.at(4.2, -3.2, ["hull"]), 4.2, -2.78)
	var bt = K.equip("BAT-N", "battery", K.rect(3.4, 0.6, 5.4, 2.4), {"mass": 0.4, "value": 4000.0, "fragile": 0.4, "room": "N", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(4.4, 3.0, ["hull"]), 4.4, 2.4)
	K.bolt(bt, K.at(5.2, 2.75, ["hull"]), 5.2, 2.4)
	K.lamp("LAMP-N", 5.8, -2.4, "N", K.at(6.0, -2.6, ["hull"]))
	var dk = K.equip("DOCK", "dock", K.rect(-0.9, -1.4, 0.35, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(0.55, -0.9, ["hull"]), 0.35, -0.9)
	K.bolt(dk, K.at(0.55, 0.9, ["hull"]), 0.35, 0.9)


# ---------------------------------------------------------------- the spine

static func _spine() -> void:
	var S := {"density": 2.2, "barrier": false, "cut_speed": 130.0, "name_key": "p_spine"}
	for i in SPINE.size() - 1:
		var x0: float = SPINE[i]
		var x1: float = SPINE[i + 1]
		var t = K.plate("SP-T%d" % (i + 1), K.R(x0, -1.6, x1, -1.2), S, "beam")
		var b = K.plate("SP-B%d" % (i + 1), K.R(x0, 1.2, x1, 1.6), S, "beam")
		if i > 0:
			K.bolt(t, by_tag["SP-T%d" % i], x0, -1.4, "weld")
			K.bolt(b, by_tag["SP-B%d" % i], x0, 1.4, "weld")
			var po = K.plate("SPP-%d" % i, K.R(x0 - 0.2, -1.2, x0 + 0.2, 1.2), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_spine"}, "strut")
			K.bolt(po, t, x0, -1.2, "weld")
			K.bolt(po, b, x0, 1.2, "weld")
	K.bolt(by_tag["SP-T1"], K.at(6.8, -1.4, ["hull"]), 7.0, -1.4, "weld")
	K.bolt(by_tag["SP-B1"], K.at(6.8, 1.4, ["hull"]), 7.0, 1.4, "weld")
	K.clamp(1, 11.0, 1.6, 1.4, ["beam"])
	K.clamp(2, 43.0, 1.6, 1.4, ["beam"])


# ---------------------------------------------------------------- the service module

static func _service() -> void:
	K.ring(OUT_S, T, {1: [0.65, 0.85]}, {"1:1": {"kind": "hatch", "door": true, "tag": "HT-S", "open_dir": Vector2(1.0, 0) * Geom.M, "cut_speed": 200.0}},
		{"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HS")
	K.bolt(by_tag["SP-T5"], K.at(47.3, -1.4, ["hull"]), 47.1, -1.4, "weld")
	K.bolt(by_tag["SP-B5"], K.at(47.3, 1.4, ["hull"]), 47.1, 1.4, "weld")
	var top := -5.0 + T
	var bot := 5.0 - T
	var fc = K.equip("FC-S", "cap", K.rect(48.6, top, 51.4, -1.8), {"mass": 1.0, "value": 12000.0, "fragile": 0.4, "room": "S", "name_key": "p_fuel_cell"})
	K.bolt(fc, K.at(49.0, top - 0.2, ["hull"]), 49.0, top)
	K.bolt(fc, K.at(51.0, top - 0.2, ["hull"]), 51.0, top)
	var bt = K.equip("BAT-T", "battery", K.rect(48.6, 2.0, 51.4, bot), {"mass": 0.6, "value": 5000.0, "fragile": 0.4, "room": "S", "hazard": "battery", "name_key": "p_battery"})
	K.bolt(bt, K.at(49.0, bot + 0.2, ["hull"]), 49.0, bot)
	K.bolt(bt, K.at(51.0, bot + 0.2, ["hull"]), 51.0, bot)
	var en = K.equip("ENG-S", "eng_core", K.rect(52.0, -2.4, 54.55, 2.4), {"mass": 1.6, "value": 10000.0, "fragile": 0.3, "room": "S", "name_key": "p_engine"})
	K.bolt(en, K.at(54.8, -1.6, ["hull"]), 54.55, -1.6)
	K.bolt(en, K.at(54.8, 1.6, ["hull"]), 54.55, 1.6)
	K.lamp("LAMP-S", 50.0, top, "S", K.at(50.0, top - 0.2, ["hull"]))
	var nz = K.equip("NOZ-S", "nozzle", K.rect(55.0, -1.8, 58.0, 1.8), {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 160.0, "name_key": "p_nozzle"},
		K.mp([Vector2(55.0, -1.0), Vector2(58.0, -1.8), Vector2(58.0, 1.8), Vector2(55.0, 1.0)]))
	K.bolt(nz, K.at(54.8, -0.6, ["hull"]), 55.0, -0.6)
	K.bolt(nz, K.at(54.8, 0.6, ["hull"]), 55.0, 0.6)
	var rc = K.equip("RCS-S", "rcs_quad", K.rect(53.2, -5.8, 54.0, -5.0), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 180.0, "name_key": "p_rcs"})
	K.bolt(rc, K.at(53.6, -4.8, ["hull"]), 53.6, -5.0)


# ---------------------------------------------------------------- the spine's equipment

static func _equipment() -> void:
	for e in [["ENV-1", "env", 7.4, 10.6, 1.2, 9000.0, "p_env_control"], ["PNL-1", "monitor", 11.0, 14.6, 0.3, 2500.0, "p_monitor_panel"],
			["GAS-P", "pump", 15.6, 18.6, 0.8, 6000.0, "p_bag_pump"], ["BAT-S", "battery", 19.0, 22.6, 0.6, 5000.0, "p_battery"],
			["CON-S", "console", 23.6, 26.6, 0.3, 6000.0, "p_spine_console"], ["CAP-S", "cap", 27.0, 30.6, 0.3, 3000.0, "p_capacitor"],
			["STORE-1", "locker", 31.6, 35.0, 0.4, 2000.0, "p_locker"], ["STORE-2", "locker", 39.6, 43.0, 0.4, 2000.0, "p_locker"]]:
		var opts := {"mass": e[4], "value": e[5], "fragile": 0.4, "name_key": e[6]}
		if e[0] == "BAT-S":
			opts.hazard = "battery"
		var p = K.equip(e[0], e[1], K.rect(e[2], -1.2, e[3], 1.2), opts)
		K.bolt(p, by_tag[_seg(true, e[2] + 0.4)], e[2] + 0.4, -1.2)
		K.bolt(p, by_tag[_seg(false, e[3] - 0.4)], e[3] - 0.4, 1.2)


# ---------------------------------------------------------------- the bags, their straps, the patch

static func _bags() -> void:
	for b in BAGS:
		var c: Vector2 = b[1]
		var r: float = b[2]
		var side: int = b[3]
		var edge := -1.6 if side < 0 else 1.6
		var bag = K.plate(b[0], K.mp(_circle(c, r, 28)), {"cls": "metal", "dest": "metal", "mass": 1.8 if r < 10.0 else 2.2, "density": 0.2, "barrier": false, "cut_speed": 320.0, "name_key": "p_gas_bag"}, "plate")
		# its collar on the spine
		for dx in [-2.0, 2.0]:
			K.bolt(bag, by_tag[_seg(side < 0, c.x + dx)], c.x + dx, edge, "bolt")
		# three straps round it, on its tensioner
		var k := 0
		for dx in [-5.0, 0.0, 5.0]:
			k += 1
			var x: float = c.x + dx
			var far: float = c.y + float(side) * sqrt(r * r - dx * dx)
			var y0 := minf(edge, far)
			var y1 := maxf(edge, far)
			var st = K.equip("ST-%s%d" % [b[0], k], "harness", K.rect(x - 0.2, y0, x + 0.2, y1), {"mass": 0.1, "value": 800.0, "fragile": 0.2, "name_key": "p_bag_strap"})
			K.bolt(st, by_tag[_seg(side < 0, x)], x, edge, "bolt")
			K.bolt(st, bag, x, far - float(side) * 0.3, "bolt")
	# the bulging patch on the aft upper bag
	var pt = K.plate("PATCH", K.mp([Vector2(31.4, -19.6), Vector2(36.6, -21.4), Vector2(39.8, -18.2), Vector2(38.6, -15.4), Vector2(33.0, -15.0)]),
		{"density": 0.4, "barrier": false, "cut_speed": 300.0, "name_key": "p_bag_patch"}, "plate")
	K.bolt(pt, by_tag["L3"], 34.0, -17.0, "bolt")
	K.bolt(pt, by_tag["L3"], 37.4, -17.6, "bolt")


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT-S", Vector2(20.8, 1.2), "CON-S", Vector2(24.4, 1.0), [Vector2(20.8, 1.0)])
	K.line("p2", "cable", "power", "CON-S", Vector2(23.6, 0.0), "GAS-P", Vector2(18.6, 0.0))
	K.line("p3", "cable", "power", "GAS-P", Vector2(15.6, 0.0), "ENV-1", Vector2(10.6, 0.0))
	K.line("p4", "cable", "power", "ENV-1", Vector2(7.4, 0.0), "LAMP-N", Vector2(5.8, -2.24), [Vector2(6.2, 0.0), Vector2(6.2, -2.24)])
	K.line("p5", "cable", "power", "LAMP-N", Vector2(5.6, -2.24), "AV-N", Vector2(4.2, -1.6), [Vector2(5.0, -2.24), Vector2(5.0, -1.6)])
	K.line("p6", "cable", "power", "CON-S", Vector2(26.6, 0.6), "LAMP-S", Vector2(50.0, -4.39), [Vector2(46.8, 0.6), Vector2(46.8, -0.8), Vector2(50.0, -0.8)])
	K.line("p7", "cable", "power", "BAT-T", Vector2(50.0, 2.0), "FC-S", Vector2(50.0, -1.8))
	K.line("p9", "cable", "power", "FC-S", Vector2(51.4, -2.2), "ENG-S", Vector2(52.0, -2.0), [Vector2(51.7, -2.2), Vector2(51.7, -2.0)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-N", "port", K.at(5.66, -2.72, ["hull"]), Vector2(5.9, -3.1), {"medium": "gas", "target": "N"})
	K.ctrl("G-S", "port", K.at(52.6, 4.8, ["hull"]), Vector2(52.6, 5.25), {"medium": "gas", "target": "S"})
	K.door("HT-N", "")
	K.door("HT-S", "")
	K.ctrl("K-S", "switch", by_tag["BAT-S"], Vector2(19.6, -0.6), {"target": "K-S", "state": true})
	K.ctrl("K-T", "switch", by_tag["BAT-T"], Vector2(49.2, 3.0), {"target": "K-T", "state": true, "hidden_room": "S"})
	K.ctrl("E-1", "test", by_tag["CON-S"], Vector2(25.0, 0.6), {"medium": "volt", "target": "bus"})
	K.ctrl("DIS-S", "discharge", by_tag["CAP-S"], Vector2(28.8, 0.6), {"target": "CAP-S", "state": false})
	var k := 0
	for b in BAGS:
		k += 1
		var c: Vector2 = b[1]
		var side: int = b[3]
		var y := -1.4 if side < 0 else 1.4
		K.ctrl("BV-%d" % k, "port", by_tag[_seg(side < 0, c.x - 1.0)], Vector2(c.x - 1.0, y), {"medium": "gas", "target": "BAG-%d" % k})
		K.ctrl("TN-%d" % k, "switch", by_tag[_seg(side < 0, c.x + 1.0)], Vector2(c.x + 1.0, y), {"target": "TN-%d" % k, "state": true})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	w.add_room("N", K.mp(K.inner(_circle(Vector2(3.8, 0.0), 3.5, 16), T)))
	w.add_room("S", K.mp(K.inner(OUT_S, T)))


static func meta() -> Dictionary:
	var bags := {}
	var vessels := {}
	var near := {"L1": ["ENV-1", "PNL-1", "GAS-P", "BAT-S"], "L2": ["ENV-1", "PNL-1", "GAS-P", "BAT-S"],
		"L3": ["CON-S", "CAP-S", "STORE-1", "STORE-2"], "L4": ["CON-S", "CAP-S", "STORE-1", "STORE-2"]}
	var k := 0
	for b in BAGS:
		k += 1
		var vk := "BAG-%d" % k
		bags[b[0]] = {"vessel": vk, "straps": ["ST-%s1" % b[0], "ST-%s2" % b[0], "ST-%s3" % b[0]], "tensioner": "TN-%d" % k,
			"near": near[b[0]], "patch": "PATCH" if b[0] == "L3" else "", "side": b[3], "port": "BV-%d" % k}
		vessels[vk] = {"V": 60.0 if b[2] < 10.0 else 75.0, "kpa": 30.0, "piece": b[0], "burst": 1000.0}
	return {
		"id": "ih55",
		"name": "IH-55 PUFFER",
		"title": ["IH-55「河豚」充气居住舱运输船 · 55 m", "IH-55 PUFFER · INFLATABLE HABITAT TRANSPORT · 55 m"],
		"contract": "IH-55",
		"length": 58.0,
		"value": {"total": 103500.0, "metal": 15000.0},
		"clamps": [[11.0, 1.6], [43.0, 1.6]],
		"room_names": {"N": "room_ihN", "S": "room_ihS"},
		"gas": {"rooms": {"N": 101.0, "S": 101.0}, "vessels": vessels, "valves": [], "value": 2500.0},
		"softshell": {"bags": bags, "flat": 3.0},
		"power": {
			"bus": "CON-S",
			"sources": [
				{"piece": "BAT-S", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-S", "charge": 0.9, "drain": 0.0003},
			],
			# the service module's own battery, apart from the bus
			"isolated": [{"piece": "CAP-S", "volts": 380.0, "charge": 1.0, "kind": "cap", "discharge": "DIS-S"},
				{"piece": "BAT-T", "volts": 220.0, "charge": 0.9, "switch": "K-T"}],
			"lamps": {"N": "LAMP-N", "S": "LAMP-S"},
		},
		"ctrls_cfg": {"G-N": {"rate": 10.0}, "G-S": {"rate": 14.0}, "BV-1": {"rate": 3.0}, "BV-2": {"rate": 3.0}, "BV-3": {"rate": 3.5}, "BV-4": {"rate": 3.5}},
		"labels": {"BAT-S": "BAT", "BAT-T": "BAT", "CON-S": "CON", "CAP-S": "CAP", "GAS-P": "BAG PUMP", "L1": "BAG", "L2": "BAG", "L3": "BAG", "L4": "BAG"},
		"hints": {},
		"market": {
			"class": "IH", "name": ["河豚级充气居住舱运输船", "PUFFER-CLASS INFLATABLE HABITAT TRANSPORT"], "time": 30.0,
			"rooms": {"N": [0.2, 40.0, 101.0], "S": [0.2, 40.0, 101.0]},
			"charge": {"BAT-S": [0.3, 1.0]},
			"knockable": ["CON-S", "PNL-1"],
			"drift": [],
			"section_x": 27.0,
			"slots": {"fire_system": {"x": 51.8, "y0": 3.0, "y1": 5.0 - T, "base": ["HS5-0", 5.0 - T], "room": "S", "port": [52.2, 3.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"AV-N": [
				{"do": "hose", "ctrl": "G-N"},
				{"do": "wait", "until": {"P": ["N", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-N"},
				{"do": "wait", "until": {"open": ["N"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-S"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "AV-N"},
				{"do": "deliver", "piece": "AV-N", "zone": "equip"},
			],
		},
	}
