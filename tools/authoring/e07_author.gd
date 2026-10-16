class_name E07Author
# Authoring script for the apprentice assessment: a 6 m auxiliary equipment
# module rolled into the berth, with one piece of equipment to recover whole,
# E-07, and one of four problems (tools/ship_export.gd -- e07a|e07b|e07c|e07d):
#   a  pressure  E-07 sits in a small sealed bay that still holds 100 kPa
#   b  power     E-07 hangs off its own battery and capacitor
#   c  lines     a pipe and a cable still run from E-07 to the module
#   d  hidden    a latch behind the inspection panel IP-E7
# Metres, y down; the module sits at x 18–24. The frame is the rig: it stays.

static var w
static var by_tag := {}
static var variant := "a"


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
	# ---- the module frame (rig)
	var fl = _piece("hull", [18.0, 1.4, 24.0, 1.8], SH.merged({"tag": "EX-FL"}), true)
	var lw = _piece("hull", [18.0, -0.6, 18.3, 1.4], SH.merged({"tag": "EX-LW"}), true)
	var rw = _piece("hull", [23.7, -0.6, 24.0, 1.4], SH.merged({"tag": "EX-RW"}), true)
	_j(lw, fl, "weld", 18.15, 1.42)
	_j(rw, fl, "weld", 23.85, 1.42)
	_j(fl, null, "clamp", 18.6, 1.75, "CL-01")
	_j(fl, null, "clamp", 23.4, 1.75, "CL-02")
	# ---- E-07 on two floor bolts
	var e7 = _equip("E-07", "aux", [20.2, 0.4, 21.8, 1.4], {"mass": 0.8, "value": 3000.0, "fragile": 0.4, "name_key": "p_e07", "mandatory": true})
	_j(e7, fl, "bolt", 20.4, 1.38)
	_j(e7, fl, "bolt", 21.6, 1.38)
	match variant:
		"a":
			# a sealed bay around it; the lid is bolted to the bay walls
			var c1 = _piece("bulkhead", [19.8, -0.3, 20.0, 1.4], SH.merged({"tag": "EX-C1"}), true)
			var c2 = _piece("bulkhead", [22.0, -0.3, 22.2, 1.4], SH.merged({"tag": "EX-C2"}), true)
			_j(c1, fl, "weld", 19.9, 1.42)
			_j(c2, fl, "weld", 22.1, 1.42)
			var lid = _piece("hull", [19.8, -0.5, 22.2, -0.3], {"density": 1.0, "barrier": true, "cut_speed": 230.0, "tag": "EX-LID", "name_key": "p_e07_lid", "mass": 0.24})
			_j(lid, c1, "bolt", 19.9, -0.33)
			_j(lid, c2, "bolt", 22.1, -0.33)
			e7.room = "EX"
			w.add_ctrl("PT-E7", "port", c1, p(19.75, 0.6), {"medium": "gas", "target": "EX"})
			w.add_ctrl("GAS-E7", "port", c2, p(22.25, 0.6), {"medium": "gas", "target": "EX"})
			w.add_room("EX", R(20.0, -0.3, 22.0, 1.4))
		"b":
			# its own battery and capacitor through a junction box on the wall
			var jb = _equip("JB-E7", "swb", [18.35, -0.5, 18.95, 0.5], {"mass": 0.2, "value": 300.0, "fragile": 0.4, "name_key": "p_e07_jb"})
			_j(jb, lw, "bolt", 18.36, -0.4)
			_j(jb, lw, "bolt", 18.36, 0.4)
			var bat = _equip("B-E7", "battery", [18.4, 0.8, 18.9, 1.4], {"mass": 0.25, "value": 500.0, "fragile": 0.4, "hazard": "battery", "name_key": "p_ts_battery"})
			_j(bat, fl, "bolt", 18.5, 1.38)
			_j(bat, fl, "bolt", 18.8, 1.38)
			var cap = _equip("C-E7", "cap", [19.0, 0.9, 19.4, 1.4], {"mass": 0.15, "value": 300.0, "fragile": 0.4, "hazard": "cap", "name_key": "p_ts_cap"})
			_j(cap, fl, "bolt", 19.1, 1.38)
			_j(cap, fl, "bolt", 19.3, 1.38)
			_line("c-b", "cable", "power", "B-E7", Vector2(18.65, 0.85), "JB-E7", Vector2(18.65, 0.45))
			_line("c-c", "cable", "power", "C-E7", Vector2(19.2, 0.95), "JB-E7", Vector2(18.9, 0.3), [Vector2(19.2, 0.3)])
			_line("c-e", "cable", "power", "E-07", Vector2(20.3, 0.45), "JB-E7", Vector2(18.92, 0.0), [Vector2(20.3, 0.0)])
			w.add_ctrl("K-E7", "switch", jb, p(18.5, -0.3), {"target": "K-E7", "state": true})
			w.add_ctrl("E-E7", "test", jb, p(18.8, -0.3), {"medium": "volt", "target": "bus"})
			w.add_ctrl("E-E7D", "discharge", jb, p(18.5, 0.2), {"target": "cap"})
		"c":
			# a pipe to the manifold and a cable to the wall socket, both still on
			var sk = _equip("SK-E7", "module", [18.3, 0.2, 18.5, 0.8], {"cls": "metal", "dest": "metal", "mass": 0.05, "cut_speed": 240.0, "name_key": "p_e07_socket"})
			sk.set_meta("rig", true)
			_j(sk, lw, "weld", 18.32, 0.5)
			var man = _equip("MAN-E7", "module", [23.25, 0.2, 23.7, 1.0], {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 240.0, "name_key": "p_ts_manifold"})
			man.set_meta("rig", true)
			_j(man, rw, "weld", 23.68, 0.6)
			_line("p-e", "pipe", "none", "E-07", Vector2(21.75, 0.55), "MAN-E7", Vector2(23.25, 0.6), [Vector2(22.6, 0.55), Vector2(22.6, 0.6)])
			_line("c-x", "cable", "power", "E-07", Vector2(20.25, 0.55), "SK-E7", Vector2(18.5, 0.5), [Vector2(19.4, 0.55), Vector2(19.4, 0.5)])
		"d":
			# a bracket on the right; a latch between it and E-07 sits behind
			# the inspection panel, which is bolted to the bracket
			var br = _piece("bracket", [21.8, 0.6, 22.1, 1.4], {"density": 0.8, "cut_speed": 220.0, "tag": "BR-E7", "name_key": "p_e07_bracket"}, true)
			_j(br, fl, "weld", 21.95, 1.42)
			_j(e7, br, "lock", 21.76, 0.9)
			var ip = _equip("IP-E7", "cover", [21.55, 0.6, 21.97, 1.2], {"cls": "metal", "dest": "metal", "mass": 0.12, "density": 0.4, "cut_speed": 260.0, "name_key": "p_e07_panel"})
			_j(ip, br, "bolt", 21.9, 0.66)
			_j(ip, br, "bolt", 21.9, 1.14)


static func meta() -> Dictionary:
	var d := {
		"id": "e07" + variant,
		"name": "E-07 AUX MODULE",
		"title": ["E-07 辅助设备舱 · 6 m", "E-07 AUX MODULE · 6 m"],
		"length": 6.0,
		"value": {"total": {"a": 3700.0, "b": 4700.0, "c": 3600.0, "d": 3600.0}[variant], "metal": 600.0},
		"clamps": [[18.6, 1.8], [23.4, 1.8]],
		"labels": {"E-07": "AUX"},
		"room_names": {},
		"ctrls_cfg": {},
		"blueprint": {"hide": ["IP-E7"]},
		"exam": {"target": "E-07", "problem": {"a": "pressure", "b": "power", "c": "lines", "d": "hidden"}[variant]},
	}
	match variant:
		"a":
			d.room_names = {"EX": "room_EX"}
			d.gas = {"rooms": {"EX": 100.0}, "vessels": {}, "valves": [], "value": 100.0}
			d.ctrls_cfg = {"PT-E7": {"rate": 1.0}, "GAS-E7": {"rate": 1.6}}
			d.exam.hint = ["先确认 E-07 那间小舱里还有没有气。", "First find out whether E-07's little bay still holds gas."]
			d.procedures = {"E-07": [
				{"do": "measure", "ctrl": "PT-E7", "expect": [">", 90.0]},
				{"do": "hose", "ctrl": "GAS-E7"},
				{"do": "wait", "until": {"P": ["EX", "<", 5.0]}, "max": 90.0},
				{"do": "free", "piece": "EX-LID"},
				{"do": "deliver", "piece": "EX-LID", "zone": "metal"},
				{"do": "wait", "until": {"open": ["EX"]}, "max": 5.0},
				{"do": "free", "piece": "E-07"},
				{"do": "deliver", "piece": "E-07", "zone": "equip"},
			]}
		"b":
			d.power = {
				"bus": "JB-E7",
				"sources": [
					{"piece": "B-E7", "kind": "battery", "volts": 48.0, "local_volts": 48.0, "cable": "c-b", "switch": "K-E7", "charge": 1.0, "drain": 0.0},
					{"piece": "C-E7", "kind": "cap", "volts": 46.0, "cable": "c-c", "charge": 1.0, "discharge": "E-E7D"},
				],
				"lamps": {},
			}
			d.exam.hint = ["测一下 E-E7。设备自己可能还带着电。", "Measure at E-E7. The unit may carry its own power."]
			d.procedures = {"E-07": [
				{"do": "operate", "ctrl": "K-E7"},
				{"do": "operate", "ctrl": "E-E7D"},
				{"do": "wait", "until": {"charge": ["C-E7", "<", 0.002]}, "max": 30.0},
				{"do": "measure", "ctrl": "E-E7", "expect": ["<", 1.0]},
				{"do": "free", "piece": "E-07"},
				{"do": "deliver", "piece": "E-07", "zone": "equip"},
			]}
		"c":
			d.exam.hint = ["拖之前，看看还有什么线连着它。", "Before you pull, look at what still runs to it."]
			d.procedures = {"E-07": [
				{"do": "free", "piece": "E-07"},
				{"do": "deliver", "piece": "E-07", "zone": "equip"},
			]}
		"d":
			d.exam.hint = ["用测量工具看看它有几处固定，再数数你看得见几颗。", "Inspect it: count the fixings it reports, then the ones you can see."]
			d.procedures = {"E-07": [
				{"do": "free", "piece": "IP-E7"},
				{"do": "deliver", "piece": "IP-E7", "zone": "metal"},
				{"do": "free", "piece": "E-07"},
				{"do": "deliver", "piece": "E-07", "zone": "equip"},
			]}
	return d
