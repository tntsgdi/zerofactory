class_name TS1Author
# Authoring script for TS-1, the 12 m training section cut from a retired
# shuttle (tutorial "FIRST SHIFT"). tools/ship_export.gd runs it and writes
# ships/ts1.json. Metres, y down; the section sits at x 15–27 in the berth.
#
#   14.75–15.0  P-001 service cover on the left wall          lessons 1–2
#   15.4–18.6   TC-1 sealed bay: shell plate P-002, test port
#               PT-02 behind valve V-02, recovery port GAS-T1    lesson 3
#   18.9–21.2   power bay: main module G-T01 (off), battery
#               B-T01 on K-BT, capacitor C-T01 (bleed E-T02),
#               junction box BUS-T with test point E-T01        lesson 4
#   21.2–23.0   pump bay: CP-T on three mounts, two pipes (one
#               still holds residue, drain DR-T), a cable       lesson 5
#   23.3–27.0   frame: armour ARM-T, struts, a 4.8 t beam of two
#               welded modules, residue tank RT-T               lesson 6
#   (2026-10-20) the furnace lesson's three practice pieces: scrap SC-T1 under
#   P-001, sensor EQ-T1 and a chemical bottle HZ-T1 above it, all on the left wall; the liquids lesson's
#   coolant tank LQ-T on a bracket over the pump bay, drain DR-L, pipe LQ-1
#
# The shell (walls, plates, manifold) is the training rig: it stays clamped
# and retracts when the course is over ("rig" in the ship file).

static var w
static var by_tag := {}


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(x0, y0, x1, y1))


static func _piece(kind: String, r: Array, opts: Dictionary, rig: bool = false):
	var pc = w.add_piece(kind, R(r[0], r[1], r[2], r[3]), opts)
	if pc.tag != "":
		by_tag[pc.tag] = pc
	if rig:
		pc.set_meta("rig", true)
	return pc


static func _equip(tag: String, art: String, r: Array, opts: Dictionary):
	var rr := Rect2(r[0] * Geom.M, r[1] * Geom.M, (r[2] - r[0]) * Geom.M, (r[3] - r[1]) * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.cls == "equip" else "fixture"
	var pc = w.add_piece(kind, Geom.rect_poly(rr), o)
	by_tag[tag] = pc
	return pc


static func _j(a, b, type: String, x: float, y: float, tag: String = "") -> void:
	var j = w.add_joint(a, b, type, p(x, y))
	if tag != "":
		j.set_meta("tag", tag)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts := PackedVector2Array([pa * Geom.M])
	for q in via:
		pts.append(q * Geom.M)
	pts.append(pb * Geom.M)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, pts)


static func build(world) -> void:
	w = world
	by_tag = {}
	var SH := {"density": 1.4, "barrier": true, "cut_speed": 230.0}
	# ---- the rig: shell of the closed section
	var lw = _piece("hull", [15.0, -1.8, 15.4, 1.8], SH.merged({"tag": "TS-LW"}), true)
	var t1 = _piece("hull", [15.0, -2.2, 16.0, -1.8], SH.merged({"tag": "TS-T1"}), true)
	var shell = _piece("hull", [16.0, -2.2, 17.6, -1.8], {"density": 1.0, "barrier": true, "cut_speed": 230.0, "tag": "P-002", "name_key": "p_ts_shell", "mass": 0.64})
	var t2 = _piece("hull", [17.6, -2.2, 19.0, -1.8], SH.merged({"tag": "TS-T2"}), true)
	var bh = _piece("bulkhead", [18.6, -1.8, 18.9, 1.8], {"density": 1.2, "barrier": true, "cut_speed": 260.0, "tag": "TS-BH"}, true)
	var b1 = _piece("hull", [15.0, 1.8, 18.9, 2.2], SH.merged({"tag": "TS-B1"}), true)
	var b2 = _piece("hull", [18.9, 1.8, 23.0, 2.2], SH.merged({"tag": "TS-B2"}), true)
	var rw = _piece("bulkhead", [23.0, -2.2, 23.3, 2.2], {"density": 1.2, "cut_speed": 260.0, "tag": "TS-RW"}, true)
	_j(lw, t1, "weld", 15.2, -1.85)
	_j(lw, b1, "weld", 15.2, 1.85)
	_j(t2, bh, "weld", 18.75, -1.85)
	_j(bh, b1, "weld", 18.75, 1.85)
	_j(b1, b2, "weld", 18.9, 2.0)
	_j(b2, rw, "weld", 23.0, 2.0)
	# the shell plate over the bay: four bolts, two each side
	_j(shell, t1, "bolt", 16.08, -2.1)
	_j(shell, t1, "bolt", 16.08, -1.9)
	_j(shell, t2, "bolt", 17.52, -2.1)
	_j(shell, t2, "bolt", 17.52, -1.9)
	# dock clamps grip the floor plates
	# (both on the left floor plate: the furnace mouth sits under the right half)
	_j(b1, null, "clamp", 15.7, 2.15, "CL-01")
	_j(b1, null, "clamp", 18.2, 2.15, "CL-02")
	# ---- lessons 1–2: the service cover, four bolts down its edge
	var cov = _equip("P-001", "cover", [14.75, -0.7, 15.0, 0.7], {"cls": "metal", "dest": "metal", "mass": 0.18, "density": 0.6, "cut_speed": 260.0, "name_key": "p_ts_cover"})
	for y in [-0.6, -0.2, 0.2, 0.6]:
		_j(cov, lw, "bolt", 14.9, y)
	# ---- lesson 4: power bay
	var bus = _equip("BUS-T", "swb", [18.9, -1.4, 19.5, -0.2], {"mass": 0.25, "value": 300.0, "fragile": 0.4, "name_key": "p_ts_bus"})
	_j(bus, bh, "bolt", 18.95, -1.3)
	_j(bus, bh, "bolt", 18.95, -0.3)
	var lamp = _equip("LAMP-T", "lamp", [19.05, -1.58, 19.35, -1.4], {"cls": "metal", "dest": "metal", "mass": 0.03, "cut_speed": 260.0, "name_key": "p_ts_lamp"})
	_j(lamp, bus, "bolt", 19.2, -1.42)
	var gen = _equip("G-T01", "gen", [19.6, 0.8, 20.75, 1.8], {"mass": 0.9, "value": 1800.0, "fragile": 0.35, "hazard": "gen", "name_key": "p_ts_power"})
	_j(gen, b2, "bolt", 19.75, 1.8)
	_j(gen, b2, "bolt", 20.6, 1.8)
	var bat = _equip("B-T01", "battery", [20.85, 1.2, 21.2, 1.8], {"mass": 0.3, "value": 600.0, "fragile": 0.4, "hazard": "battery", "name_key": "p_ts_battery"})
	_j(bat, b2, "bolt", 20.92, 1.8)
	_j(bat, b2, "bolt", 21.13, 1.8)
	var cap = _equip("C-T01", "cap", [19.05, 0.9, 19.45, 1.8], {"mass": 0.2, "value": 400.0, "fragile": 0.4, "hazard": "cap", "name_key": "p_ts_cap"})
	_j(cap, b2, "bolt", 19.12, 1.8)
	_j(cap, b2, "bolt", 19.38, 1.8)
	# ---- lesson 5: pump bay
	var man = _equip("MAN-T", "module", [22.55, 0.15, 23.0, 1.05], {"cls": "metal", "dest": "metal", "mass": 0.15, "cut_speed": 240.0, "name_key": "p_ts_manifold"})
	man.set_meta("rig", true)
	_j(man, rw, "weld", 22.98, 0.3)
	_j(man, rw, "weld", 22.98, 0.9)
	var pump = _equip("CP-T", "pump", [21.4, 1.0, 22.4, 1.8], {"mass": 0.45, "value": 2450.0, "fragile": 0.4, "name_key": "p_ts_pump"})
	for x in [21.55, 21.9, 22.25]:
		_j(pump, b2, "bolt", x, 1.8)
	# ---- the furnace lesson: one practice piece for each mouth (scrap, equipment, hazard)
	var scr = _equip("SC-T1", "", [14.75, 0.85, 15.0, 1.75], {"cls": "metal", "dest": "metal", "mass": 0.12, "density": 0.6, "cut_speed": 260.0, "name_key": "p_ts_scrap"})
	_j(scr, lw, "bolt", 14.9, 0.95)
	_j(scr, lw, "bolt", 14.9, 1.65)
	var sen = _equip("EQ-T1", "sensor", [14.68, -1.78, 15.0, -1.3], {"mass": 0.06, "value": 400.0, "fragile": 0.4, "name_key": "p_ts_sensor"})
	_j(sen, lw, "bolt", 14.9, -1.7)
	_j(sen, lw, "bolt", 14.9, -1.38)
	var cell = _equip("HZ-T1", "gastank", [14.68, -1.22, 15.0, -0.78], {"mass": 0.08, "value": 300.0, "fragile": 0.4, "hazard": "chem", "dest": "hazard", "name_key": "p_ts_cell"})
	_j(cell, lw, "bolt", 14.9, -1.12)
	_j(cell, lw, "bolt", 14.9, -0.86)
	# ---- the liquids lesson: a small coolant tank on a bracket over the pump bay, its
	# drain port, and a short full pipe of its own to cut on purpose
	var brk = _equip("LQ-B", "module", [22.4, -1.55, 23.0, -1.15], {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_ts_bracket"})
	brk.set_meta("rig", true)
	_j(brk, rw, "weld", 22.98, -1.45)
	_j(brk, rw, "weld", 22.98, -1.25)
	var lqt = _equip("LQ-T", "water", [21.5, -1.75, 22.4, -0.95], {"mass": 0.12, "value": 600.0, "fragile": 0.35, "name_key": "p_ts_lqtank"})
	_j(lqt, brk, "bolt", 22.36, -1.5)
	_j(lqt, brk, "bolt", 22.36, -1.2)
	# ---- lesson 6: the frame
	var arm = _piece("beam", [23.3, -2.2, 27.0, -1.8], {"density": 0.81, "cut_speed": 170.0, "tag": "ARM-T", "name_key": "p_ts_armor", "mass": 1.2})
	_j(arm, rw, "weld", 23.32, -2.1)
	_j(arm, rw, "weld", 23.32, -1.9)
	var bm1 = _piece("beam", [23.3, 1.6, 25.15, 2.2], {"density": 2.16, "cut_speed": 120.0, "tag": "BM-1", "name_key": "p_ts_beam", "mass": 2.4})
	var bm2 = _piece("beam", [25.15, 1.6, 27.0, 2.2], {"density": 2.16, "cut_speed": 120.0, "tag": "BM-2", "name_key": "p_ts_beam", "mass": 2.4})
	# the reinforced joint between the two modules: welds only a cut undoes
	for y in [1.7, 1.9, 2.1]:
		_j(bm1, bm2, "weld", 25.15, y)
	_j(bm1, rw, "bolt", 23.32, 1.75)
	_j(bm1, rw, "bolt", 23.32, 2.05)
	for sx in [25.05, 26.7]:
		var st = _piece("strut", [sx, -1.8, sx + 0.22, 1.6], {"density": 0.45, "cut_speed": 220.0, "name_key": "p_ts_strut", "tag": "ST-1" if sx < 26.0 else "ST-2"})
		_j(st, arm, "bolt", sx + 0.11, -1.8)
		_j(st, bm1 if sx < 25.15 else bm2, "bolt", sx + 0.11, 1.6)
	var tank = _equip("RT-T", "fueltank", [25.6, 0.85, 26.45, 1.6], {"mass": 0.3, "value": 300.0, "fragile": 0.35, "hazard": "fuel_tank", "name_key": "p_ts_tank"})
	_j(tank, bm2, "bolt", 25.75, 1.6)
	_j(tank, bm2, "bolt", 26.3, 1.6)
	# ---- lines
	_line("c-g", "cable", "power", "G-T01", Vector2(19.7, 0.85), "BUS-T", Vector2(19.4, -0.25), [Vector2(19.7, 0.5), Vector2(19.4, 0.5)])
	_line("c-b", "cable", "power", "B-T01", Vector2(20.95, 1.25), "BUS-T", Vector2(19.45, -0.35), [Vector2(20.95, 0.35), Vector2(19.55, 0.35), Vector2(19.55, -0.35)])
	_line("c-c", "cable", "power", "C-T01", Vector2(19.25, 0.95), "BUS-T", Vector2(19.25, -0.25))
	_line("c-l", "cable", "power", "BUS-T", Vector2(19.2, -1.38), "LAMP-T", Vector2(19.2, -1.42))
	_line("c-p", "cable", "power", "BUS-T", Vector2(19.48, -0.6), "CP-T", Vector2(21.45, 1.05), [Vector2(21.0, -0.6), Vector2(21.0, 0.7), Vector2(21.45, 0.7)])
	_line("r1", "pipe", "none", "CP-T", Vector2(21.7, 1.0), "MAN-T", Vector2(22.55, 0.4), [Vector2(21.7, 0.4)])
	_line("r2", "pipe", "res", "CP-T", Vector2(22.35, 1.2), "MAN-T", Vector2(22.55, 0.85), [Vector2(22.45, 1.2), Vector2(22.45, 0.85)])
	# (over the tank, well away from the pump bay: what it spills fouls nothing the course needs)
	_line("LQ-1", "pipe", "lq1", "LQ-B", Vector2(22.55, -1.55), "TS-RW", Vector2(23.15, -2.1), [Vector2(22.55, -1.95), Vector2(23.15, -1.95)])
	# ---- controls
	w.add_ctrl("PT-02", "port", t1, p(15.55, -2.25), {"medium": "gas", "target": "SC-T"})
	w.add_ctrl("V-02", "valve", t1, p(15.85, -2.25), {"target": "V-02"})
	w.add_ctrl("GAS-T1", "port", t2, p(18.3, -2.25), {"medium": "gas", "target": "TC"})
	w.add_ctrl("K-BT", "switch", bus, p(19.05, -1.15), {"target": "K-BT", "state": true})
	w.add_ctrl("E-T01", "test", bus, p(19.33, -1.15), {"medium": "volt", "target": "bus"})
	w.add_ctrl("E-T02", "discharge", bus, p(19.05, -0.72), {"target": "cap"})
	w.add_ctrl("DR-T", "port", man, p(22.75, 0.62), {"medium": "coolant", "target": "res"})
	w.add_ctrl("DR-L", "port", lqt, p(21.56, -1.35), {"medium": "coolant", "target": "lq"})
	# ---- the one sealed room
	w.add_room("TC", R(15.4, -1.8, 18.6, 1.8))


static func meta() -> Dictionary:
	return {
		"id": "ts1",
		"name": "TS-1 TRAINING SECTION",
		"title": ["TS-1 训练舱段 · 12 m", "TS-1 TRAINING SECTION · 12 m"],
		"length": 12.0,
		"value": {"total": 11500.0, "metal": 4000.0},
		"clamps": [[15.7, 2.2], [18.2, 2.2]],
		"room_names": {"TC": "room_TC"},
		"gas": {
			"rooms": {"TC": 100.2},
			"vessels": {"SC-T": {"V": 0.02, "kpa": 0.0, "dead_leg": "V-02"}},
			"valves": [{"ctrl": "V-02", "a": "TC", "b": "SC-T", "g": 20.0}],
			"value": 300.0,
		},
		"power": {
			"bus": "BUS-T",
			"sources": [
				{"piece": "G-T01", "kind": "gen", "volts": 52.0, "cable": "c-g", "running": false},
				{"piece": "B-T01", "kind": "battery", "volts": 52.0, "local_volts": 52.0, "cable": "c-b", "switch": "K-BT", "charge": 1.0, "drain": 0.0},
				{"piece": "C-T01", "kind": "cap", "volts": 48.0, "cable": "c-c", "charge": 1.0, "discharge": "E-T02"},
			],
			"lamps": {"": "LAMP-T"},
		},
		"fluids": {
			"volumes": {
				"res": {"fluid": "coolant", "amount": 0.03, "full": 0.03, "nets": ["res"], "leak": 0.2, "port": "DR-T", "pump": [0.6, 0.01]},
				"rt": {"fluid": "fuel", "amount": 0.06, "piece": "RT-T", "content": 2.0, "leak": 0.1, "hazard": 0.01},
				"lq": {"fluid": "coolant", "amount": 0.04, "full": 0.04, "piece": "LQ-T", "leak": 0.25, "port": "DR-L", "pump": [0.6, 0.01]},
				"lq1": {"fluid": "coolant", "amount": 0.05, "full": 0.05, "nets": ["lq1"], "leak": 0.6},
			},
			"value": {"coolant": 50.0, "fuel": 0.0},
		},
		"ctrls_cfg": {
			"PT-02": {"rate": 1.0},
			"GAS-T1": {"rate": 1.5},
		},
		"labels": {"G-T01": "MAIN", "RT-T": "RESIDUE"},
		"procedures": {
			"P-002": [
				{"do": "measure", "ctrl": "PT-02", "expect": ["<", 1.0]},
				{"do": "operate", "ctrl": "V-02"},
				{"do": "measure", "ctrl": "PT-02", "expect": [">", 90.0]},
				{"do": "hose", "ctrl": "GAS-T1"},
				{"do": "wait", "until": {"P": ["TC", "<", 5.0]}, "max": 90.0},
				{"do": "free", "piece": "P-002"},
				{"do": "deliver", "piece": "P-002", "zone": "metal"},
			],
			"G-T01": [
				{"do": "operate", "ctrl": "K-BT"},
				{"do": "operate", "ctrl": "E-T02"},
				{"do": "wait", "until": {"charge": ["C-T01", "<", 0.002]}, "max": 30.0},
				{"do": "measure", "ctrl": "E-T01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "G-T01"},
				{"do": "deliver", "piece": "G-T01", "zone": "equip"},
			],
			"CP-T": [
				{"do": "operate", "ctrl": "K-BT"},
				{"do": "operate", "ctrl": "E-T02"},
				{"do": "wait", "until": {"charge": ["C-T01", "<", 0.002]}, "max": 30.0},
				{"do": "hose", "ctrl": "DR-T"},
				{"do": "wait", "until": {"fluid": ["res", "<", 0.01]}, "max": 60.0},
				{"do": "free", "piece": "CP-T"},
				{"do": "deliver", "piece": "CP-T", "zone": "equip"},
			],
			"LQ-T": [
				{"do": "hose", "ctrl": "DR-L"},
				{"do": "wait", "until": {"fluid": ["lq", "<", 0.002]}, "max": 60.0},
				{"do": "free", "piece": "LQ-T"},
				{"do": "deliver", "piece": "LQ-T", "zone": "equip"},
			],
			"EQ-T1": [
				{"do": "free", "piece": "EQ-T1"},
				{"do": "deliver", "piece": "EQ-T1", "zone": "equip"},
			],
			"HZ-T1": [
				{"do": "free", "piece": "HZ-T1"},
				{"do": "deliver", "piece": "HZ-T1", "zone": "hazard"},
			],
			"RT-T": [
				{"do": "free", "piece": "RT-T"},
				{"do": "deliver", "piece": "RT-T", "zone": "hazard"},
			],
		},
		"blueprint": {"hide": ["LAMP-T"]},
		"training": true,
	}
