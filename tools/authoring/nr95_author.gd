class_name Nr95Author
# Authoring script for NR-95 "Hearth", a 95 m nuclear-thermal tug (exotic batch
# 03/10, design/ships/NR-95_灶王_设计稿.md and NR-95_线稿.png, as drawn). Not part of
# the game: tools/ship_export.gd runs it and writes ships/nr95.json.
# Metres, x bow (0) to the radiator tips (95), y down.
#
# The crew module forward (the only pressurised room, with its lead-lined shelter),
# the 5.6 t movable shield plate on its mounts behind it, the 42 m liquid-hydrogen
# tank on its saddles over the keel, the reactor housing with the core and its
# four control drums, the thrust chamber and bell, four radiator petals.
# What it asks of you (scripts/reactor.gd, scripts/furnace.gd): the core, eleven
# months shut down, still gives 3.2 Sv/h at a metre; the shield (and the shelter,
# and the tank) cast a shadow wherever they are, so the shield is lifted off its
# mounts and hung in front of the core before anyone works aft. The core's decay
# heat comes off only while its coolant pump runs (on the bus) and its loop is
# full: the petals fold, and the core is lifted, only once it is under 60 °C. Its
# four control drums are locked before the core comes out, and the core goes out
# whole, to the hazard bay: cut, it contaminates the ship.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT_H := [Vector2(1.5, -5.9), Vector2(14.4, -5.9), Vector2(15.9, -4.4), Vector2(15.9, 4.4), Vector2(14.4, 5.9),
	Vector2(1.5, 5.9), Vector2(0.0, 4.4), Vector2(0.0, -4.4)]
const OUT_R := [Vector2(62.1, -5.0), Vector2(72.1, -5.0), Vector2(72.1, 5.0), Vector2(62.1, 5.0)]
const KY := 5.9                  # the keel's top (to 6.5)

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "NR95")
	w = world
	by_tag = K.by_tag
	_hab()
	_keel()
	_shield()
	_tank()
	_reactor()
	_engine()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "NR95")
	w = world
	_rooms()


static func _iy(out: Array, i: int, x: float) -> float:
	var inn := K.inner(out, T)
	var a: Vector2 = inn[i]
	var b: Vector2 = inn[(i + 1) % inn.size()]
	return a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y)


# ---------------------------------------------------------------- the crew module

static func _hab() -> void:
	K.ring(OUT_H, T, {0: [0.75, 0.9]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(2.0, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HH")
	var top := -5.9 + T
	var bot := 5.9 - T
	var E := func(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, opts: Dictionary, on_top: bool):
		var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts.merged({"room": "H"}))
		var yb := y0 if on_top else y1
		var yh := top - 0.2 if on_top else bot + 0.2
		K.bolt(p, K.at(x0 + 0.3, yh, ["hull"]), x0 + 0.3, yb)
		K.bolt(p, K.at(x1 - 0.3, yh, ["hull"]), x1 - 0.3, yb)
		return p
	E.call("CON-H", "console", 2.2, 2.0, 5.0, bot, {"mass": 0.4, "value": 9000.0, "fragile": 0.5, "mandatory": true, "name_key": "p_tug_console"}, false)
	E.call("BAT-H", "battery", 5.6, 2.2, 8.0, bot, {"mass": 0.8, "value": 8000.0, "fragile": 0.4, "hazard": "battery", "name_key": "p_battery"}, false)
	E.call("LSS-H", "env", 8.6, 2.0, 11.6, bot, {"mass": 0.6, "value": 9000.0, "fragile": 0.4, "name_key": "p_life_support"}, false)
	E.call("BUNK-H", "bunk", 2.0, top, 5.6, -3.8, {"mass": 0.2, "value": 1200.0, "fragile": 0.3, "name_key": "p_bunk"}, true)
	E.call("NAV-H", "nav", 6.2, top, 8.4, -3.2, {"mass": 0.3, "value": 12000.0, "fragile": 0.5, "name_key": "p_nav"}, true)
	E.call("STORE-H", "locker", 8.8, top, 10.8, -2.4, {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "name_key": "p_locker"}, true)
	# the lead-lined shelter against the aft wall
	var sh = K.equip("SHELTER", "vault", K.rect(12.2, -4.8, 15.45, -1.4), {"mass": 3.5, "value": 8000.0, "fragile": 0.2, "room": "H", "name_key": "p_rad_shelter"})
	K.bolt(sh, K.at(15.7, -4.0, ["hull"]), 15.45, -4.0, "weld")
	K.bolt(sh, K.at(15.7, -2.0, ["hull"]), 15.45, -2.0, "weld")
	K.lamp("LAMP-H", 4.0, top, "H", K.at(4.0, top - 0.2, ["hull"]))
	var dk = K.equip("DOCK", "dock", K.rect(-1.2, -1.4, 0.0, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(0.2, -1.0, ["hull"]), 0.0, -1.0)
	K.bolt(dk, K.at(0.2, 1.0, ["hull"]), 0.0, 1.0)
	K.clamp(1, 8.0, 5.9, 5.7)


# ---------------------------------------------------------------- the keel under it all

static func _keel() -> void:
	var kl = K.plate("KEEL", K.R(12.0, KY, 63.2, KY + 0.6), {"density": 2.0, "barrier": false, "cut_speed": 120.0, "name_key": "p_keel_truss"}, "keel")
	K.bolt(kl, K.at(12.6, 5.7, ["hull"]), 12.6, KY, "weld")
	K.bolt(kl, K.at(13.8, 5.7, ["hull"]), 13.8, KY, "weld")
	K.clamp(2, 40.0, KY + 0.6, KY + 0.4, ["keel"])


# ---------------------------------------------------------------- the movable shield

static func _shield() -> void:
	var sd = K.equip("SHIELD", "vault", K.rect(16.0, -11.0, 20.0, KY - 0.05), {"mass": 5.6, "value": 20000.0, "fragile": 0.15, "name_key": "p_rad_shield"})
	sd.set_meta("segments", [[16.0, -2.6, 20.0, -2.6]])
	# eight big bolts: four to the crew module's aft wall, four to the keel
	for y in [-4.0, -1.5, 1.5, 4.0]:
		K.bolt(sd, K.at(15.7, y, ["hull"]), 16.0, y)
	for x in [16.5, 17.5, 18.5, 19.5]:
		K.bolt(sd, by_tag["KEEL"], x, KY - 0.05)


# ---------------------------------------------------------------- the liquid-hydrogen tank

static func _tank() -> void:
	var x0 := 20.4
	var x1 := 62.0
	var poly := K.mp([Vector2(x0 + 1.6, -5.6), Vector2(x1 - 1.6, -5.6), Vector2(x1, -3.6), Vector2(x1, 3.6), Vector2(x1 - 1.6, 5.6),
		Vector2(x0 + 1.6, 5.6), Vector2(x0, 3.6), Vector2(x0, -3.6)])
	var tk = K.equip("LH2-T", "cryotank", Geom.bbox(poly), {"mass": 28.0, "value": 90000.0, "fragile": 0.2, "hazard": "gas_tank", "name_key": "p_lh2_tank"}, poly)
	var seg: Array = []
	for i in range(1, 6):
		var sx := x0 + (x1 - x0) * i / 6.0
		seg.append([sx, -5.6, sx, 5.6])
	tk.set_meta("segments", seg)
	var k := 0
	for sx in [26.0, 41.0, 56.0]:
		k += 1
		var sd = K.plate("SD-%d" % k, K.R(sx, 5.6, sx + 1.0, KY), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_saddle"}, "strut")
		K.bolt(sd, by_tag["KEEL"], sx + 0.5, KY, "weld")
		K.bolt(tk, sd, sx + 0.2, 5.6, "lock")
		K.bolt(tk, sd, sx + 0.8, 5.6, "lock")
	var vv = K.equip("LH2-V", "pump", K.rect(29.0, -7.0, 31.0, -5.6), {"mass": 0.2, "value": 3000.0, "fragile": 0.4, "name_key": "p_vent_valve"})
	K.bolt(vv, tk, 29.4, -5.6)
	K.bolt(vv, tk, 30.6, -5.6)
	var dp = K.equip("DOSE-1", "insp", K.rect(59.6, -6.4, 60.6, -5.6), {"mass": 0.02, "value": 1500.0, "fragile": 0.5, "name_key": "p_dose_probe"})
	K.bolt(dp, tk, 60.1, -5.6)


# ---------------------------------------------------------------- the reactor and its drums

static func _reactor() -> void:
	K.ring(OUT_R, T, {}, {}, {"density": 2.0, "barrier": true, "cut_speed": 160.0}, "HR")
	# a post down to the keel
	var kp = K.plate("KP-R", K.R(62.4, 5.0, 63.0, KY), {"density": 1.8, "barrier": false, "cut_speed": 150.0, "name_key": "p_keel_truss"}, "strut")
	K.bolt(kp, K.at(62.7, 4.8, ["hull"]), 62.7, 5.0, "weld")
	K.bolt(kp, by_tag["KEEL"], 62.7, KY, "weld")
	var top := -5.0 + T
	var bot := 5.0 - T
	var cr = K.equip("CORE", "reactor", K.rect(65.7, -1.4, 68.5, 1.4), {"mass": 2.8, "value": 40000.0, "fragile": 0.2, "hazard": "rad", "name_key": "p_reactor_core"})
	# eight bolts and a clamp, to the housing's floor through a cradle
	var cd = K.plate("CRADLE", K.R(65.4, 1.4, 68.8, bot), {"density": 1.8, "barrier": false, "cut_speed": 150.0, "name_key": "p_core_cradle"}, "strut")
	K.bolt(cd, K.at(66.0, bot + 0.2, ["hull"]), 66.0, bot, "weld")
	K.bolt(cd, K.at(68.2, bot + 0.2, ["hull"]), 68.2, bot, "weld")
	for x in [65.9, 66.5, 67.1, 67.7, 68.3]:
		K.bolt(cr, cd, x, 1.4)
	K.bolt(cr, cd, 68.5, 1.4, "lock", "CORE-CL")
	for i in 4:
		var x0 := 62.9 + i * 2.25
		var dr = K.equip("DRUM-%d" % (i + 1), "drum", K.rect(x0, top, x0 + 1.8, top + 1.8), {"mass": 0.2, "value": 3000.0, "fragile": 0.4, "name_key": "p_control_drum"})
		K.bolt(dr, K.at(x0 + 0.4, top - 0.2, ["hull"]), x0 + 0.4, top)
		K.bolt(dr, K.at(x0 + 1.4, top - 0.2, ["hull"]), x0 + 1.4, top)
	var rp = K.equip("RCP", "pump", K.rect(69.4, 2.4, 71.65, bot), {"mass": 0.6, "value": 6000.0, "fragile": 0.35, "name_key": "p_core_pump"})
	K.bolt(rp, K.at(69.8, bot + 0.2, ["hull"]), 69.8, bot)
	K.bolt(rp, K.at(71.2, bot + 0.2, ["hull"]), 71.2, bot)


# ---------------------------------------------------------------- the thrust chamber, the bell, the petals

static func _engine() -> void:
	var poly := K.mp([Vector2(72.1, -4.6), Vector2(84.0, -6.9), Vector2(84.0, 6.9), Vector2(72.1, 4.6)])
	var nz = K.equip("NOZ", "nozzle", Geom.bbox(poly), {"mass": 8.0, "value": 70000.0, "fragile": 0.2, "name_key": "p_thrust_chamber"}, poly)
	nz.set_meta("segments", [[76.0, -5.4, 76.0, 5.4], [80.0, -6.2, 80.0, 6.2]])
	for y in [-3.6, -1.2, 1.2, 3.6]:
		K.bolt(nz, K.at(71.9, y, ["hull"]), 72.1, y)
	var d2 = K.equip("DOSE-2", "insp", K.rect(72.8, -5.6, 73.8, -4.8), {"mass": 0.02, "value": 1500.0, "fragile": 0.5, "name_key": "p_dose_probe"})
	K.bolt(d2, nz, 73.3, -4.8)
	var k := 0
	for e in [[-4.2, -5.5], [-1.6, -1.0], [1.6, 1.0], [4.2, 5.5]]:
		k += 1
		var ya: float = e[0]
		var yb: float = e[1]
		var pp := K.mp([Vector2(84.0, ya - 0.5), Vector2(95.0, yb - 0.5), Vector2(95.0, yb + 0.5), Vector2(84.0, ya + 0.5)])
		var pe = K.equip("RAD-%d" % k, "radiator", Geom.bbox(pp), {"mass": 1.2, "value": 7500.0, "fragile": 0.3, "name_key": "p_radiator_petal"}, pp)
		K.bolt(pe, nz, 84.0, ya - 0.2, "bolt")
		K.bolt(pe, nz, 84.0, ya + 0.2, "lock")


# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("p1", "cable", "power", "BAT-H", Vector2(6.8, 2.2), "CON-H", Vector2(4.4, 2.0), [Vector2(6.8, 1.6), Vector2(4.4, 1.6)])
	K.line("p2", "cable", "power", "CON-H", Vector2(2.8, 2.0), "LAMP-H", Vector2(4.0, -5.29), [Vector2(2.8, 1.0), Vector2(1.6, 1.0), Vector2(1.6, -5.0), Vector2(4.0, -5.0)])
	K.line("p3", "cable", "power", "CON-H", Vector2(3.6, 2.0), "NAV-H", Vector2(7.2, -3.2), [Vector2(3.6, 1.2), Vector2(7.2, 1.2)])
	K.line("p4", "cable", "power", "CON-H", Vector2(4.8, 2.0), "LSS-H", Vector2(9.0, 2.0), [Vector2(4.8, 1.4), Vector2(9.0, 1.4)])
	# aft along the keel to the coolant pump
	K.line("p5", "cable", "power", "BAT-H", Vector2(7.6, 5.45), "RCP", Vector2(70.4, 2.4), [Vector2(7.6, 6.3), Vector2(64.0, 6.3), Vector2(64.0, 2.0), Vector2(70.4, 2.0)])
	K.line("c1", "pipe", "rcool", "RCP", Vector2(69.4, 3.0), "CRADLE", Vector2(68.8, 3.0))


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-H", "port", K.at(3.5, -5.7, ["hull"]), Vector2(3.5, -6.15), {"medium": "gas", "target": "H"})
	K.door("HT-H", "")
	K.ctrl("K-H", "switch", by_tag["BAT-H"], Vector2(6.0, 3.0), {"target": "K-H", "state": true, "hidden_room": "H"})
	K.ctrl("E-1", "test", by_tag["CON-H"], Vector2(3.0, 3.0), {"medium": "volt", "target": "bus", "hidden_room": "H"})
	for i in 4:
		var x0 := 62.9 + i * 2.25
		K.ctrl("DL-%d" % (i + 1), "switch", by_tag["DRUM-%d" % (i + 1)], Vector2(x0 + 0.9, -3.8), {"target": "DL-%d" % (i + 1), "state": false})
	K.ctrl("D-1", "probe", by_tag["DOSE-1"], Vector2(60.1, -6.0), {"medium": "dose", "target": "CORE"})
	K.ctrl("D-2", "probe", by_tag["DOSE-2"], Vector2(73.3, -5.2), {"medium": "dose", "target": "CORE"})
	K.ctrl("T-CORE", "probe", by_tag["CRADLE"], Vector2(67.1, 3.0), {"medium": "core", "target": "CORE"})
	K.ctrl("PRC", "port", by_tag["RCP"], Vector2(70.5, 2.8), {"medium": "coolant", "target": "rcool"})
	K.ctrl("PV-H2", "port", by_tag["LH2-V"], Vector2(30.0, -6.8), {"medium": "gas", "target": "LH2"})
	K.ctrl("PL-H2", "port", by_tag["LH2-T"], Vector2(58.0, 4.8), {"medium": "lng", "target": "lh2"})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	w.add_room("H", K.mp(K.inner(OUT_H, T)))


static func meta() -> Dictionary:
	return {
		"id": "nr95",
		"name": "NR-95 HEARTH",
		"title": ["NR-95「灶王」核热拖船 · 95 m", "NR-95 HEARTH · NUCLEAR-THERMAL TUG · 95 m"],
		"contract": "NR-95",
		"length": 95.0,
		"value": {"total": 320000.0, "metal": 20000.0},
		"clamps": [[8.0, 5.9], [40.0, KY + 0.6]],
		"room_names": {"H": "room_nrH"},
		"gas": {"rooms": {"H": 101.0},
			"vessels": {"LH2": {"V": 6.0, "kpa": 260.0, "piece": "LH2-T", "burst": 200.0}}, "valves": [], "value": 3000.0},
		"reactor": {"core": "CORE", "rate": 3200.0, "shields": ["SHIELD", "SHELTER", "LH2-T"], "limit": 150.0,
			"drums": {"DRUM-1": "DL-1", "DRUM-2": "DL-2", "DRUM-3": "DL-3", "DRUM-4": "DL-4"},
			"petals": ["RAD-1", "RAD-2", "RAD-3", "RAD-4"], "safe": 60.0},
		"furnace": {"core": "CORE", "T0": 380.0, "safe": 60.0, "crit": 99999.0, "cool": 4.0, "idle": 0.05, "pumps": ["RCP"], "loop": "rcool", "loop_min": 0.6},
		"power": {
			"bus": "CON-H",
			"sources": [
				{"piece": "BAT-H", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-H", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"H": "LAMP-H"},
		},
		"fluids": {"volumes": {
			"lh2": {"fluid": "lng", "amount": 0.6, "piece": "LH2-T", "port": "PL-H2", "full": 1.0, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"rcool": {"fluid": "coolant", "amount": 0.3, "piece": "RCP", "port": "PRC", "full": 0.3, "nets": ["rcool"], "leak": 0.2, "pump": [0.2, 0.006]},
		}, "joins": [], "value": {"lng": 6000.0, "coolant": 800.0}},
		"ctrls_cfg": {"G-H": {"rate": 26.0}, "PV-H2": {"rate": 2.0}},
		"labels": {"BAT-H": "BAT", "CON-H": "CON", "CORE": "CORE", "SHIELD": "SHIELD", "LH2-T": "LH2", "RCP": "RCP", "NOZ": "NOZZLE",
			"DRUM-1": "DRUM", "DRUM-2": "DRUM", "DRUM-3": "DRUM", "DRUM-4": "DRUM"},
		"hints": {},
		"market": {
			"class": "NR", "name": ["灶王级核热拖船", "HEARTH-CLASS NUCLEAR-THERMAL TUG"], "time": 50.0,
			"rooms": {"H": [0.2, 40.0, 101.0]},
			"charge": {"BAT-H": [0.4, 1.0]},
			"fluids": {"lh2": [0.2, 0.6]},
			"knockable": ["CON-H", "NAV-H"],
			"drift": [],
			"section_x": 62.0,
			"slots": {"fire_system": {"x": 12.4, "y0": 3.0, "y1": 5.9 - T, "base": ["HH4-0", 5.9 - T], "room": "H", "port": [12.8, 3.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"CON-H": [
				{"do": "hose", "ctrl": "G-H"},
				{"do": "wait", "until": {"P": ["H", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-H"},
				{"do": "wait", "until": {"open": ["H"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-H"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CON-H"},
				{"do": "deliver", "piece": "CON-H", "zone": "equip"},
			],
		},
	}
