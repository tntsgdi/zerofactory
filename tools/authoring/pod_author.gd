class_name PodAuthor
# Authoring script for the cargo pod, 20 m, a market ship
# (design/ships/POD_货运吊舱_设计稿.md, structure: design/ships/POD_货运吊舱_结构图.png).
# Not part of the game: tools/ship_export.gd runs it and writes ships/pod.json.
# Metres, x front (0) to stern (20), y down.
#
# Not a hull but an open cage: a small sealed avionics bay F at the front with
# the docking ring, then three cargo cells whose roofs step down towards the
# stern, each roof a motor-driven cover, a floor rail the containers are
# locked to, two propellant spheres aft. Almost no systems: the difficulty is
# the cargo — the covers need power to open, one container is too heavy for
# the 3 t grapple, one carries dangerous goods, the last cell is loose bulk.

const T := 0.25
const F_OUT := [Vector2(0.0, 1.4), Vector2(0.0, -1.6), Vector2(1.0, -3.4), Vector2(4.0, -3.4), Vector2(4.0, 3.3), Vector2(1.0, 3.3)]
const CELLS := [[4.0, 9.2, -3.2], [9.2, 14.4, -2.7], [14.4, 20.0, -2.0]]   # x0, x1, roof top
const RAIL_Y := 3.0                # top of the floor rail (what the cargo stands on)

static var f_in: Array = []
static var w
static var by_tag := {}


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(x0, y0, x1, y1))


static func _mp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


static func _inner(o: Array) -> Array:
	var n := o.size()
	var out: Array = []
	for i in n:
		var a: Vector2 = o[(i - 1 + n) % n]
		var b: Vector2 = o[i]
		var c: Vector2 = o[(i + 1) % n]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		var hit = Geometry2D.line_intersects_line(a + n1 * T, d1, b + n2 * T, d2)
		out.append(hit if hit != null else b + n1 * T)
	return out


static func build(world) -> void:
	w = world
	by_tag = {}
	f_in = _inner(F_OUT)
	_front()
	_cage()
	_cargo()
	_aft()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	f_in = _inner(F_OUT)
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt") -> void:
	if a == null or b == null:
		push_warning("POD joint missing a piece at %s,%s" % [x, y])
		return
	w.add_joint(a, b, type, p(x, y))


static func at(x: float, y: float, kinds: Array = []):
	return w.piece_at(p(x, y), kinds)


static func _equip(tag: String, art: String, r: Rect2, opts: Dictionary):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	return _tagged(w.add_piece(kind, Geom.rect_poly(rr), o))


# ---------------------------------------------------------------- F: the sealed avionics bay and the docking ring

static func _front() -> void:
	var S := {"density": 1.4, "barrier": true, "cut_speed": 240.0}
	var n := F_OUT.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = F_OUT[i]
		var o1: Vector2 = F_OUT[(i + 1) % n]
		var i0: Vector2 = f_in[i]
		var i1: Vector2 = f_in[(i + 1) % n]
		var st: Array = [0.0, 1.0]
		if i == 3:
			st = [0.0, 0.42, 0.72, 1.0]          # the aft wall: a door out into the cage between two plates
		for k in st.size() - 1:
			var a := o0.lerp(o1, st[k])
			var b := o0.lerp(o1, st[k + 1])
			var c := i0.lerp(i1, st[k + 1])
			var d := i0.lerp(i1, st[k])
			var opts := S.duplicate()
			var kind := "hull"
			if i == 3 and k == 1:
				kind = "hatch"
				opts["door"] = true
				opts["tag"] = "DR-F"
				opts["open_dir"] = Vector2(0, -1.9) * Geom.M
			var pc = _tagged(w.add_piece(kind, _mp([a, b, c, d]), opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
			else:
				first = pc
			prev = pc
	w.add_joint(prev, first, "weld", F_OUT[0].lerp(f_in[0], 0.3) * Geom.M)
	w.add_joint(prev, first, "weld", F_OUT[0].lerp(f_in[0], 0.7) * Geom.M)
	# the docking ring on the nose: equipment, a ring of bolts
	var dk = _equip("DOCK-P", "dock", Rect2(-0.7, -1.5, 0.7, 2.8), {"mass": 0.8, "value": 3000.0, "fragile": 0.3, "name_key": "p_dock"})
	for y in [-1.2, -0.4, 0.4, 1.1]:
		_bolt(dk, at(0.12, y, ["hull"]), 0.0, y)
	# inside F: avionics hung from the roof, the switchboard, the battery on the floor
	var top: float = f_in[2].y
	var flo: float = f_in[4].y
	var av = _equip("AV-P", "nav", Rect2(1.3, top, 1.9, 1.4), {"mass": 0.3, "value": 4000.0, "fragile": 0.85, "room": "F", "name_key": "p_avionics"})
	_bolt(av, at(1.6, top - 0.1, ["hull"]), 1.6, top)
	_bolt(av, at(2.9, top - 0.1, ["hull"]), 2.9, top)
	var sw = _equip("SWB-P", "swb", Rect2(3.25, top, 0.45, 1.5), {"mass": 0.12, "value": 600.0, "fragile": 0.4, "room": "F", "name_key": "p_s_swb"})
	_bolt(sw, at(3.5, top - 0.1, ["hull"]), 3.5, top)
	var bt = _equip("BAT-P", "battery", Rect2(1.4, flo - 1.3, 2.0, 1.3), {"mass": 0.4, "value": 2000.0, "fragile": 0.4, "room": "F", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bt, at(1.8, flo + 0.1, ["hull"]), 1.8, flo)
	_bolt(bt, at(3.0, flo + 0.1, ["hull"]), 3.0, flo)
	# the outside panel on F's roof: battery switch, test point, the cover drive
	var pn = _equip("PNL-P", "panel", Rect2(1.5, -3.95, 2.0, 0.55), {"cls": "metal", "dest": "metal", "mass": 0.08, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, at(1.8, -3.3, ["hull"]), 1.8, -3.4)
	_bolt(pn, at(3.2, -3.3, ["hull"]), 3.2, -3.4)


# ---------------------------------------------------------------- the cage: posts, roof beams, motor covers, floor rails

static func _cage() -> void:
	var B := {"density": 1.2, "cut_speed": 190.0}
	var posts := {}
	var xs := [9.2, 14.4, 20.0]
	for i in xs.size():
		var x: float = xs[i]
		var tops: Array = [CELLS[i][2]]
		if i + 1 < CELLS.size():
			tops.append(CELLS[i + 1][2])
		var top: float = tops.min() - 0.25
		posts[x] = _tagged(w.add_piece("strut", R(x - 0.18, top, x + 0.18, RAIL_Y + 0.3), B.merged({"tag": "POST-%d" % (i + 1)})))
	for i in CELLS.size():
		var x0: float = CELLS[i][0]
		var x1: float = CELLS[i][1]
		var top: float = CELLS[i][2]
		var lft = posts.get(x0, null)
		var a0: float = x0 + (0.18 if lft != null else 0.0)
		var a1: float = x1 - 0.18
		# the floor rail
		var rail = _tagged(w.add_piece("rail", R(a0, RAIL_Y, a1, RAIL_Y + 0.3), B.merged({"tag": "RAIL-%d" % (i + 1)})))
		_bolt(rail, lft if lft != null else at(3.9, RAIL_Y + 0.15, ["hull"]), a0, RAIL_Y + 0.15, "weld")
		_bolt(rail, posts[x1], a1, RAIL_Y + 0.15, "weld")
		# roof: two short beams at the ends, the motor cover between them
		var b0 = _tagged(w.add_piece("beam", R(a0, top - 0.25, a0 + 0.5, top + 0.05), B.merged({"tag": "RB-%da" % (i + 1)})))
		var b1 = _tagged(w.add_piece("beam", R(a1 - 0.5, top - 0.25, a1, top + 0.05), B.merged({"tag": "RB-%db" % (i + 1)})))
		_bolt(b0, lft if lft != null else at(3.9, -3.3, ["hull"]), a0, top - 0.1, "weld")
		_bolt(b1, posts[x1], a1, top - 0.1, "weld")
		var cv = _tagged(w.add_piece("hatch", R(a0 + 0.5, top - 0.22, a1 - 0.5, top + 0.02), {"density": 0.9, "barrier": false, "door": true, "tag": "CV-%d" % (i + 1),
			"open_dir": Vector2(0, -2.4) * Geom.M, "cut_speed": 230.0}))
		_bolt(cv, b0, a0 + 0.5, top - 0.1, "weld")
		_bolt(cv, b1, a1 - 0.5, top - 0.1, "weld")
	# dock clamps grip F's floor and the rails
	for cl in [[2.2, 3.3, "CL-01"], [7.0, 3.3, "CL-02"], [12.0, 3.3, "CL-03"], [17.0, 3.3, "CL-04"]]:
		var j = w.add_joint(at(cl[0], cl[1] - 0.1, ["hull", "rail"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# ---------------------------------------------------------------- the cargo: containers locked to the rails, a bulk cell

static func _box(tag: String, x0: float, x1: float, h: float, opts: Dictionary) -> void:
	var r := Rect2(x0, RAIL_Y - h, x1 - x0, h)
	var o := {"mass": 1.5, "value": 6000.0, "fragile": 0.3, "name_key": "p_container"}
	o.merge(opts, true)
	var c = _equip(tag, "cargo", r, o)
	var rail = at((x0 + x1) * 0.5, RAIL_Y + 0.15, ["rail"])
	for i in 4:
		var x := x0 + (x1 - x0) * (0.12 + 0.76 * i / 3.0)
		_bolt(c, rail, x, RAIL_Y, "lock")


static func _cargo() -> void:
	_box("CG-1", 4.5, 6.6, 2.6, {"mass": 1.8, "value": 6500.0})
	_box("CG-2", 6.8, 8.9, 3.4, {"mass": 2.2, "value": 7500.0})
	_box("CG-3", 9.6, 13.0, 4.6, {"mass": 3.8, "value": 11000.0})
	_box("CG-4", 13.05, 14.05, 2.0, {"mass": 0.9, "value": 4000.0, "fragile": 0.6})
	_box("CG-5", 14.8, 17.1, 2.8, {"mass": 1.6, "value": 8000.0, "hazard": "explosive"})
	# the bulk cell: six small crates in two rows, the lower row locked to the rail, the upper to the lower
	var rail = at(18.0, RAIL_Y + 0.15, ["rail"])
	for row in 2:
		for i in 3:
			var x0 := 17.4 + i * 0.75
			var y1 := RAIL_Y - row * 0.72
			var tg := "CG-6%s" % ["abc", "def"][row][i]
			var c = _equip(tg, "cargo", Rect2(x0, y1 - 0.7, 0.68, 0.7), {"mass": 0.12, "value": 500.0, "fragile": 0.4, "name_key": "p_crate"})
			if row == 0:
				_bolt(c, rail, x0 + 0.34, RAIL_Y, "lock")
			else:
				_bolt(c, by_tag["CG-6" + "abc"[i]], x0 + 0.34, y1, "lock")


# ---------------------------------------------------------------- aft: two propellant spheres, two thruster quads

static func _aft() -> void:
	var post = by_tag["POST-3"]
	for i in 2:
		var y0 := -1.5 if i == 0 else 0.2
		var s = _equip("RCS-P%d" % (i + 1), "sphere_tank", Rect2(20.25, y0, 1.3, 1.3), {"mass": 0.2, "value": 600.0, "fragile": 0.3, "hazard": "fuel_tank", "name_key": "p_rcs_t"})
		_bolt(s, post, 20.18, y0 + 0.4)
		_bolt(s, post, 20.18, y0 + 0.9)
		var qy := -2.0 if i == 0 else 2.3
		var q = _equip("RCS-A%d" % (i + 1), "rcs_quad", Rect2(20.25, qy - 0.25, 0.9, 0.5), {"mass": 0.1, "value": 400.0, "fragile": 0.3, "name_key": "p_rcs_q"})
		_bolt(q, post, 20.18, qy)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var top: float = f_in[2].y
	_line("c1", "cable", "power", "BAT-P", Vector2(3.3, 2.1), "SWB-P", Vector2(3.45, top + 1.45), [Vector2(3.45, 2.1)])
	_line("c2", "cable", "power", "SWB-P", Vector2(3.3, top + 0.3), "AV-P", Vector2(3.15, top + 0.3))
	# the cover drive: out through F's roof and along the roof beams to the first cover
	_line("c3", "cable", "power", "SWB-P", Vector2(3.6, top + 0.05), "CV-1", Vector2(5.0, -3.3), [Vector2(3.6, -3.55), Vector2(5.0, -3.55)])
	_line("p1", "pipe", "rcs", "RCS-P1", Vector2(20.9, -0.35), "RCS-A1", Vector2(21.0, -2.1), [Vector2(21.7, -0.35), Vector2(21.7, -2.1)])
	_line("p2", "pipe", "rcs", "RCS-P2", Vector2(20.9, 0.35), "RCS-A2", Vector2(21.0, 2.3), [Vector2(21.7, 0.35), Vector2(21.7, 2.3)])


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	var pn = by_tag["PNL-P"]
	_ctrl("K-P", "switch", pn, Vector2(1.8, -3.7), {"target": "K-P", "state": true})
	_ctrl("E-P01", "test", pn, Vector2(2.3, -3.7), {"medium": "volt", "target": "bus"})
	_ctrl("COVERS", "hatch", pn, Vector2(2.9, -3.7), {"target": "HATCH"})
	_ctrl("GAS-F", "port", at(1.4, 3.2, ["hull"]), Vector2(1.4, 3.45), {"medium": "gas", "target": "F"})
	_ctrl("RCS-1P", "port", by_tag["RCS-P1"], Vector2(21.2, -1.25), {"medium": "fuel", "target": "rcs1"})
	_ctrl("RCS-2P", "port", by_tag["RCS-P2"], Vector2(21.2, 1.25), {"medium": "fuel", "target": "rcs2"})
	var dp = by_tag["DR-F"]
	_ctrl("DR-F", "door", dp, Geom.centroid(dp.poly) / Geom.M, {"target": "DR-F", "state": false})


static func _rooms() -> void:
	var ip := PackedVector2Array()
	for q in f_in:
		ip.append(q * Geom.M)
	w.add_room("F", ip)


static func meta() -> Dictionary:
	return {
		"id": "pod",
		"name": "POD",
		"title": ["货运吊舱 · 20 m", "CARGO POD · 20 m"],
		"contract": "POD",
		"length": 21.6,
		"value": {"total": 51100.0, "metal": 4000.0},
		"clamps": [[2.2, 3.3], [7.0, 3.3], [12.0, 3.3], [17.0, 3.3]],
		"room_names": {"F": "room_pF"},
		"gas": {"rooms": {"F": 60.0}, "vessels": {}, "valves": [], "value": 100.0},
		"power": {
			"bus": "SWB-P",
			"sources": [{"piece": "BAT-P", "kind": "battery", "volts": 28.0, "local_volts": 28.0, "cable": "c1", "switch": "K-P", "charge": 0.8, "drain": 0.0004}],
			"isolated": [],
			"lamps": {},
		},
		"fluids": {
			"volumes": {
				"rcs1": {"fluid": "fuel", "amount": 0.05, "piece": "RCS-P1", "content": 0.4, "leak": 0.1, "port": "RCS-1P", "pump": [0.12, 0.008], "hazard": 0.02},
				"rcs2": {"fluid": "fuel", "amount": 0.05, "piece": "RCS-P2", "content": 0.4, "leak": 0.1, "port": "RCS-2P", "pump": [0.12, 0.008], "hazard": 0.02},
				"rcs_line": {"fluid": "fuel", "amount": 0.005, "nets": ["rcs"], "leak": 0.05, "leak_min": 0.002},
			},
			"joins": [],
			"value": {"fuel": 200.0},
		},
		"ctrls_cfg": {
			"GAS-F": {"rate": 6.0},
			"COVERS": {"doors": ["CV-1", "CV-2", "CV-3"], "cable": "c3"},
		},
		"labels": {"CG-1": "IND. METAL", "CG-2": "IND. METAL", "CG-3": "HEAVY", "CG-4": "PRECISION", "CG-5": "DG", "RCS-P1": "RCS", "RCS-P2": "RCS"},
		"hints": {
			"no_power": ["舱盖电机没电。先接通 K-P，或者接船坞辅助电源。", "No power for the cover drive. Close K-P again, or plug in the dock's aux supply."],
		},
		"market": {
			"class": "CP", "name": ["货运吊舱", "CARGO POD"], "time": 12.0,
			"rooms": {"F": [0.4, 30.0, 80.0]},
			"charge": {"BAT-P": [0.1, 1.0]},
			"fluids": {"rcs1": [0.01, 0.06], "rcs2": [0.01, 0.06]}, "fill": {"rcs_line": "rcs1"},
			"cargo": {"containers": ["CG-1", "CG-2", "CG-3", "CG-4", "CG-5"], "keep": 0.85, "fixed": {"CG-3": "heavy", "CG-5": "dg", "CG-4": "precision"}},
			"knockable": ["AV-P", "DOCK-P", "RCS-A1", "RCS-A2"],
			"drift": ["CG-1", "CG-4", "BAT-P"],
			"section_x": 9.2,
			"slots": {
				"welded_hatch": {"seams": [["CV-1", "RB-1a", 4.5, -3.3], ["CV-2", "RB-2a", 9.88, -2.8], ["CV-3", "RB-3a", 15.08, -2.1]], "evidence": ["CV-1", "CV-2", "CV-3"]},
				"explosive_cargo": {},
				"live_cargo": {"hosts": {"CG-1": "RAIL-1", "CG-2": "RAIL-1", "CG-3": "RAIL-2", "CG-4": "RAIL-2"}, "host_y": 3.15, "room": ""},
				"hidden_damage": {"plates": ["RAIL-1", "RAIL-2", "RAIL-3"]},
			},
		},
		"procedures": {
			"AV-P": [
				{"do": "hose", "ctrl": "GAS-F"},
				{"do": "wait", "until": {"P": ["F", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "DR-F"},
				{"do": "wait", "until": {"open": ["F"]}, "max": 5.0},
				{"do": "free", "piece": "AV-P"},
				{"do": "deliver", "piece": "AV-P", "zone": "equip"},
			],
			"CG-1": [
				{"do": "operate", "ctrl": "COVERS"},
				{"do": "free", "piece": "CG-1"},
				{"do": "deliver", "piece": "CG-1", "zone": "equip"},
			],
		},
		"blueprint": {"hide": ["PNL-P"]},
	}
