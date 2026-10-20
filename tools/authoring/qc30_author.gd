class_name Qc30Author
# Authoring script for QC-30 "Quantum", a 30 m quantum-computing ship (new designs
# 01/10, design/ships/02_新设计十艘_设计稿.md). Not part of the game:
# tools/ship_export.gd runs it and writes ships/qc30.json. Metres, x bow (0) to the
# stern (30), y down.
#
# The smallest ship in the fleet and nearly the dearest. Three compartments: C the
# control room (the operators' consoles and the room-temperature electronics above,
# the crew below), Q the quantum room (a dilution refrigerator hanging from its
# isolation table under the roof, five stages down to the mixing chamber with the
# processor under it, inside two magnetic shield panels; the gas handling system,
# pumps and the readout racks on the floor), E the power room (the pulse tube's
# compressor, the chiller, the helium buffers, the battery and the bus).
# What it asks of you (scripts/dilution.gd): the circulation stopped and the 3He/4He
# mixture recovered before the pulse tube stops (else it boils off), the warm-up
# heaters only once the mixing chamber is past 30 K (else the chip cracks), nothing
# of the stack touched under 250 K, and the isolation table locked before anything
# near it is cut. The power: the pulse tube runs on the bus, so killing the bus first
# is the classic mistake.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT := [Vector2(0, -4), Vector2(2, -6), Vector2(28, -6), Vector2(30, -4), Vector2(30, 4), Vector2(28, 6), Vector2(2, 6), Vector2(0, 4)]
const BH := [9.0, 22.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]

static var w
static var by_tag := {}
static var n_auto := 0


static func build(world) -> void:
	K.begin(world, "QC30")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	_hull()
	_inner()
	_control()
	_quantum()
	_power()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 7.5, 6.0, 5.8)
	K.clamp(2, 25.0, 6.0, 5.8)


static func rooms_only(world) -> void:
	K.begin(world, "QC30")
	w = world
	_rooms()


static func _auto(p: String) -> String:
	n_auto += 1
	return "%s%d" % [p, n_auto]


# a piece of equipment: [art, t, $, fragile, name key] at a rectangle
static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, room: String, o: Dictionary):
	var opts := {"fragile": 0.4, "room": room}
	opts.merge(o, true)
	return K.equip(tag if tag != "" else _auto(art.left(4).to_upper() + "-"), art, K.rect(x0, y0, x1, y1), opts)


# a row along a floor (up -1) or under a ceiling (up +1), as on ARK-01
static func _row(room: String, floor_y: float, up: float, x0: float, x1: float, items: Array, keep: Array = []) -> Array:
	var out: Array = []
	var x := x0
	for it in items:
		if it is float or it is int:
			x += float(it)
			continue
		var wd: float = it[2]
		var h: float = it[3]
		for kp in keep:
			if x < float(kp[1]) + 0.2 and x + wd > float(kp[0]) - 0.2:
				x = float(kp[1]) + 0.25
		if x + wd > x1 + 0.001:
			push_warning("QC30 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
			continue
		var ya: float = floor_y + up * 0.05
		var yb: float = floor_y + up * (0.05 + h)
		var p = E(it[0], it[1], x, minf(ya, yb), x + wd, maxf(ya, yb), room, it[4])
		for bx in [x + minf(0.3, wd * 0.25), x + wd - minf(0.3, wd * 0.25)]:
			K.bolt(p, K.at(bx, floor_y - up * 0.15, FLOORK), bx, floor_y)
		out.append(p)
		x += wd + 0.3
	return out


static func _lamp(tag: String, x: float, ceil_y: float, room: String) -> void:
	K.lamp(tag, x, ceil_y, room, K.at(x, ceil_y - 0.15, FLOORK))


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	var glass := {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.12, "value": 2400.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_nose_glass"}
	# edges: 0 bow upper slope, 1 roof, 2 stern upper slope, 3 stern, 4 stern lower slope, 5 floor, 6 bow lower slope, 7 nose
	K.ring(OUT, T, {1: [0.15, 0.27, 0.35, 0.45, 0.62, 0.75, 0.885, 0.946], 3: [0.5], 5: [0.08, 0.14, 0.25, 0.35, 0.5, 0.65, 0.72, 0.84, 0.9077, 0.969], 7: [0.25, 0.75]}, {
		"7:1": glass.merged({"tag": "WIN-C"}),
		"5:9": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(-1.6, 0) * Geom.M, "cut_speed": 200.0},
		"1:7": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(1.6, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HQ")
	for j in w.joints_of(by_tag["WIN-C"]):
		j.type = "bolt"


static func _inner() -> void:
	var B := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	for i in 2:
		var x: float = BH[i]
		var u = K.plate("BH%d-U" % i, K.R(x - 0.22, -5.55, x + 0.22, 1.2), B, "hull")
		var d = K.plate("D-%d" % i, K.R(x - 0.22, 1.2, x + 0.22, 3.8), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -2.4) * Geom.M}, "door")
		var l = K.plate("BH%d-L" % i, K.R(x - 0.22, 3.8, x + 0.22, 5.55), B, "hull")
		K.bolt(u, K.at(x, -5.75, ["hull"]), x, -5.55, "weld")
		K.bolt(l, K.at(x, 5.75, ["hull"]), x, 5.55, "weld")
		K.bolt(u, d, x, 1.2, "weld")
		K.bolt(l, d, x, 3.8, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	# the control room's deck (its stair well forward), the power room's (aft)
	var dc = K.plate("DK-C", K.R(2.6, 0.0, 8.78, 0.25), D, "deck")
	K.bolt(dc, K.at(8.9, 0.12, ["hull"]), 8.78, 0.12, "weld")
	var de = K.plate("DK-E", K.R(22.22, 0.0, 27.4, 0.25), D, "deck")
	K.bolt(de, K.at(22.1, 0.12, ["hull"]), 22.22, 0.12, "weld")


# ---------------------------------------------------------------- C, the control room

static func _control() -> void:
	_row("C", 0.0, -1.0, 2.8, 8.7, [["CON-1", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "name_key": "p_qc_console"}], ["", "seat", 0.7, 1.1, {"mass": 0.05, "value": 900.0, "name_key": "p_ark_chair"}],
		["AWG", "nav_rack", 1.1, 3.4, {"mass": 0.35, "value": 42000.0, "fragile": 0.5, "name_key": "p_qc_awg"}], ["CLK", "aux", 0.7, 0.7, {"mass": 0.05, "value": 9000.0, "fragile": 0.5, "name_key": "p_qc_clock"}],
		["LOG-Q", "blackbox", 0.7, 0.5, {"mass": 0.08, "value": 15000.0, "mandatory": true, "name_key": "p_qc_log"}]])
	_row("C", -5.55, 1.0, 3.6, 8.7, [["", "screen", 1.4, 0.8, {"mass": 0.04, "value": 2600.0, "name_key": "p_ark_screen"}], ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}], ["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-C", 5.2, -5.55, "C")
	_row("C", 5.55, -1.0, 4.65, 8.7, [["", "bunk", 2.0, 1.5, {"mass": 0.18, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["ENV-C", "env", 1.4, 1.6, {"mass": 0.4, "value": 9000.0, "name_key": "p_env_control"}]])
	_row("C", 0.25, 1.0, 3.0, 8.7, [["", "cabinet", 1.2, 0.6, {"mass": 0.08, "value": 1200.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 0.9, {"mass": 0.12, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "locker", 0.8, 0.9, {"mass": 0.08, "value": 900.0, "name_key": "p_locker"}], ["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	K.lamp("LAMP-C2", 6.0, 0.25, "C", by_tag["DK-C"])


# ---------------------------------------------------------------- Q, the quantum room

static func _quantum() -> void:
	# the isolation table under the roof, the stack hung from it stage by stage
	var vit = E("VIT", "insp", 12.4, -5.5, 18.6, -4.9, "Q", {"mass": 0.9, "value": 26000.0, "fragile": 0.3, "name_key": "p_qc_vit"})
	K.bolt(vit, K.at(13.0, -5.75, ["hull"]), 13.0, -5.55)
	K.bolt(vit, K.at(18.0, -5.75, ["hull"]), 18.0, -5.55)
	var ph = E("PT-HEAD", "pump", 19.4, -5.5, 20.4, -4.6, "Q", {"mass": 0.15, "value": 18000.0, "name_key": "p_qc_pt_head"})
	K.bolt(ph, K.at(19.9, -5.75, ["hull"]), 19.9, -5.55)
	var above = vit
	var y := -4.85
	var stages := [["STG-50K", 3.8, 0.5, 15000.0, "p_qc_stage_50k"], ["STG-4K", 3.4, 0.5, 22000.0, "p_qc_stage_4k"], ["STG-STILL", 3.0, 0.45, 26000.0, "p_qc_stage_still"],
		["STG-CP", 2.6, 0.45, 20000.0, "p_qc_stage_cp"], ["STG-MXC", 2.2, 0.5, 42000.0, "p_qc_stage_mxc"]]
	for st in stages:
		var cx := 15.5
		var half: float = st[1] * 0.5
		y += 0.05
		var p = E(st[0], "module", cx - half, y, cx + half, y + st[2], "Q", {"mass": 0.18, "value": st[3], "fragile": 0.5, "name_key": st[4]})
		K.bolt(p, above, cx - half + 0.3, y)
		K.bolt(p, above, cx + half - 0.3, y)
		above = p
		y += st[2]
	var chip = E("QPU", "insp", 15.2, y + 0.05, 15.8, y + 0.45, "Q", {"mass": 0.02, "value": 320000.0, "fragile": 0.8, "mandatory": true, "name_key": "p_qc_qpu"})
	K.bolt(chip, above, 15.5, y)
	# the magnetic shield panels either side of the stack
	for xx in [[11.9, 12.2, "MS-1"], [18.8, 19.1, "MS-2"]]:
		var ms = E(xx[2], "armor", xx[0], -5.5, xx[1], -1.0, "Q", {"mass": 0.25, "value": 7000.0, "fragile": 0.2, "name_key": "p_qc_mag_shield"})
		var mx: float = (xx[0] + xx[1]) * 0.5
		K.bolt(ms, K.at(mx, -5.75, ["hull"]), mx, -5.55)
	# the floor: gas handling, the mixture's tank, the pumps, the cold trap, the readout
	_row("Q", 5.55, -1.0, 9.5, 21.6, [["GHS", "cabinet", 1.8, 2.6, {"mass": 0.6, "value": 32000.0, "name_key": "p_qc_ghs"}], ["MIX-T", "gastank", 0.9, 2.2, {"mass": 0.3, "value": 8000.0, "hazard": "gas_tank", "name_key": "p_qc_mix_tank"}],
		["CIRC-P", "pump", 1.3, 1.2, {"mass": 0.35, "value": 14000.0, "name_key": "p_qc_still_pump"}], ["TURBO", "pump", 0.9, 1.0, {"mass": 0.2, "value": 11000.0, "name_key": "p_qc_turbo"}],
		["TRAP", "cryotank", 0.9, 1.6, {"mass": 0.2, "value": 6000.0, "name_key": "p_qc_cold_trap"}], ["FCTL", "panel", 1.1, 1.4, {"mass": 0.08, "value": 7000.0, "name_key": "p_qc_fridge_ctl"}],
		["RACK-R", "nav_rack", 1.2, 3.2, {"mass": 0.35, "value": 38000.0, "fragile": 0.5, "name_key": "p_qc_readout"}], ["HEMT-B", "panel", 0.8, 1.0, {"mass": 0.05, "value": 9000.0, "name_key": "p_qc_hemt_bias"}],
		["", "suit", 0.6, 1.8, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}]])
	_lamp("LAMP-Q", 10.6, -5.55, "Q")
	_row("Q", -5.55, 1.0, 20.2, 21.7, [["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])


# ---------------------------------------------------------------- E, the power room

static func _power() -> void:
	_row("E", 0.0, -1.0, 22.4, 27.3, [["PTC", "pump", 2.0, 1.8, {"mass": 1.4, "value": 26000.0, "name_key": "p_qc_compressor"}], ["CHL", "freezer", 1.3, 1.6, {"mass": 0.4, "value": 8000.0, "name_key": "p_qc_chiller"}],
		["HE-1", "gastank", 0.8, 2.2, {"mass": 0.25, "value": 3000.0, "hazard": "gas_tank", "name_key": "p_qc_he_buffer"}]])
	_row("E", -5.55, 1.0, 22.6, 27.2, [["HE-2", "gastank", 0.8, 2.0, {"mass": 0.25, "value": 3000.0, "hazard": "gas_tank", "name_key": "p_qc_he_buffer"}], ["", "junction", 0.6, 0.4, {"mass": 0.04, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-E", 24.6, -5.55, "E")
	_row("E", 5.55, -1.0, 22.4, 27.4, [["BAT-E", "battery", 1.6, 1.5, {"mass": 1.0, "value": 9000.0, "hazard": "battery", "name_key": "p_battery"}], ["SWB-E", "swb", 1.1, 2.4, {"mass": 0.4, "value": 6000.0, "name_key": "p_swb"}],
		["CWP", "pump", 1.0, 1.0, {"mass": 0.2, "value": 3500.0, "name_key": "p_coolant_pump"}]])
	K.lamp("LAMP-E2", 24.0, 0.25, "E", by_tag["DK-E"])


# ---------------------------------------------------------------- lines

static func _cen(t: String) -> Vector2:
	return Geom.centroid(by_tag[t].poly) / Geom.M


static func _c(id: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "cable", "power", a, _cen(a), b, _cen(b), via)


static func _p(id: String, net: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "pipe", net, a, _cen(a), b, _cen(b), via)


static func _lines() -> void:
	_c("p1", "BAT-E", "SWB-E")
	_c("p2", "SWB-E", "PTC", [Vector2(23.0, 2.0), Vector2(23.0, -0.6)])
	_c("p3", "SWB-E", "CIRC-P", [Vector2(22.5, 4.4), Vector2(12.4, 4.4)])
	_c("p4", "SWB-E", "GHS", [Vector2(22.5, 4.6), Vector2(10.4, 4.6)])
	_c("p5", "SWB-E", "LAMP-E")
	_c("p6", "SWB-E", "LAMP-Q", [Vector2(22.5, -5.0), Vector2(10.6, -5.0)])
	_c("p7", "SWB-E", "AWG", [Vector2(22.5, 4.8), Vector2(5.0, 4.8), Vector2(5.0, -1.0)])
	_c("p8", "AWG", "CON-1")
	_c("p9", "AWG", "LAMP-C")
	_c("p10", "SWB-E", "RACK-R")
	_c("p11", "SWB-E", "CHL")
	_c("p12", "PTC", "PT-HEAD", [Vector2(21.6, -0.6), Vector2(19.4, -4.4)])
	_c("p13", "SWB-E", "FCTL")
	_c("p14", "SWB-E", "LAMP-C2", [Vector2(22.5, 5.0), Vector2(6.0, 5.0)])
	_c("p15", "SWB-E", "LAMP-E2")
	_c("p16", "SWB-E", "ENV-C", [Vector2(22.5, 5.2), Vector2(4.5, 5.2)])
	# the mixture's circuit: the tank, the gas handling, the still pump, up into the still
	_p("m1", "mix", "MIX-T", "GHS")
	_p("m2", "mix", "GHS", "CIRC-P")
	_p("m3", "mix", "CIRC-P", "STG-STILL", [Vector2(12.6, 0.0), Vector2(14.2, -2.9)])
	_p("m4", "mix", "TRAP", "GHS")
	# the pulse tube's helium, the chiller's water
	_p("h1", "he", "PTC", "HE-1")
	_p("h2", "he", "HE-1", "HE-2")
	_p("w1", "cw", "CHL", "CWP", [Vector2(24.0, 2.5)])
	_p("w2", "cw", "CWP", "PTC", [Vector2(23.0, 2.5)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	var fc = by_tag["FCTL"]
	var c := _cen("FCTL")
	K.ctrl("PT", "switch", fc, c + Vector2(-0.35, -0.4), {"target": "PT", "state": true, "hidden_room": "Q"})
	K.ctrl("CIRC", "switch", fc, c + Vector2(-0.1, -0.4), {"target": "CIRC", "state": true, "hidden_room": "Q"})
	K.ctrl("HEAT", "switch", fc, c + Vector2(0.15, -0.4), {"target": "HEAT", "state": false, "hidden_room": "Q"})
	K.ctrl("VI-LOCK", "switch", fc, c + Vector2(0.4, -0.4), {"target": "VI-LOCK", "state": false, "hidden_room": "Q"})
	K.ctrl("T-MXC", "probe", by_tag["STG-MXC"], _cen("STG-MXC") + Vector2(0.8, 0.0), {"medium": "stage", "target": "STG-MXC", "hidden_room": "Q"})
	K.ctrl("T-STILL", "probe", by_tag["STG-STILL"], _cen("STG-STILL") + Vector2(1.2, 0.0), {"medium": "stage", "target": "STG-STILL", "hidden_room": "Q"})
	K.ctrl("T-4K", "probe", by_tag["STG-4K"], _cen("STG-4K") + Vector2(1.4, 0.0), {"medium": "stage", "target": "STG-4K", "hidden_room": "Q"})
	K.ctrl("G-MIX", "port", by_tag["MIX-T"], _cen("MIX-T") + Vector2(0, -0.9), {"medium": "gas", "target": "MIX", "hidden_room": "Q"})
	K.ctrl("G-HE1", "port", by_tag["HE-1"], _cen("HE-1") + Vector2(0, -0.8), {"medium": "gas", "target": "HE1", "hidden_room": "E"})
	K.ctrl("G-HE2", "port", by_tag["HE-2"], _cen("HE-2") + Vector2(0, 0.7), {"medium": "gas", "target": "HE2", "hidden_room": "E"})
	K.ctrl("PL", "port", by_tag["TRAP"], _cen("TRAP") + Vector2(0, -0.6), {"medium": "coolant", "target": "ln2", "hidden_room": "Q"})
	K.ctrl("PW", "port", by_tag["CWP"], _cen("CWP") + Vector2(0, -0.3), {"medium": "water", "target": "cw", "hidden_room": "E"})
	var sw = by_tag["SWB-E"]
	K.ctrl("K-M", "switch", sw, _cen("SWB-E") + Vector2(-0.3, -0.6), {"target": "K-M", "state": true, "hidden_room": "E"})
	K.ctrl("E-1", "test", sw, _cen("SWB-E") + Vector2(0.3, -0.6), {"medium": "volt", "target": "bus", "hidden_room": "E"})
	# the gas ports on the outside
	K.ctrl("G-C", "port", K.at(0.2, -2.6, ["hull"]), Vector2(-0.2, -2.6), {"medium": "gas", "target": "C"})
	K.ctrl("G-Q", "port", K.at(15.5, 5.8, ["hull"]), Vector2(15.5, 6.2), {"medium": "gas", "target": "Q"})
	K.ctrl("G-E", "port", K.at(29.8, 2.4, ["hull"]), Vector2(30.2, 2.4), {"medium": "gas", "target": "E"})
	K.ctrl("AUX-P", "socket", K.at(20.0, 5.8, ["hull"]), Vector2(20.0, 6.2), {"target": "aux", "state": false})
	for t in ["HT-C", "HT-E"]:
		K.door(t, "")
	K.door("D-0", "C")
	K.door("D-1", "E")


static func _rooms() -> void:
	var fi := K.inner(OUT, T)
	w.add_room("C", K.mp([fi[7], fi[0], Vector2(BH[0] - 0.22, fi[1].y), Vector2(BH[0] - 0.22, fi[6].y), fi[6]]))
	w.add_room("Q", K.mp([Vector2(BH[0] + 0.22, -5.55), Vector2(BH[1] - 0.22, -5.55), Vector2(BH[1] - 0.22, 5.55), Vector2(BH[0] + 0.22, 5.55)]))
	w.add_room("E", K.mp([Vector2(BH[1] + 0.22, fi[2].y), fi[2], fi[3], fi[4], fi[5], Vector2(BH[1] + 0.22, fi[5].y)]))


static func meta() -> Dictionary:
	return {
		"id": "qc30",
		"name": "QC-30 QUANTUM",
		"title": ["QC-30「量子」计算船 · 30 m", "QC-30 QUANTUM · QUANTUM-COMPUTING SHIP · 30 m"],
		"contract": "QC-30",
		"length": 30.0,
		"value": {"total": 900000.0, "metal": 4000.0},
		"clamps": [[7.5, 6.0], [25.0, 6.0]],
		"room_names": {"C": "room_qcC", "Q": "room_qcQ", "E": "room_qcE"},
		"gas": {"rooms": {"C": 101.0, "Q": 101.0, "E": 101.0},
			"vessels": {"MIX": {"V": 0.15, "kpa": 260.0, "piece": "MIX-T", "burst": 200.0},
				"HE1": {"V": 0.12, "kpa": 1500.0, "piece": "HE-1", "burst": 300.0}, "HE2": {"V": 0.12, "kpa": 1500.0, "piece": "HE-2", "burst": 300.0}},
			"valves": [], "value": 78000.0},
		"dilution": {"stages": {"STG-50K": 50.0, "STG-4K": 4.0, "STG-STILL": 0.8, "STG-CP": 0.1, "STG-MXC": 0.012},
			"order": ["STG-50K", "STG-4K", "STG-STILL", "STG-CP", "STG-MXC"], "chip": "QPU", "pt": "PT", "compressor": "PTC", "circ": "CIRC", "heater": "HEAT",
			"mix": "MIX", "mix_safe": 20.0, "warm": 0.33, "heat_k": 4.0, "shock_T": 30.0, "brittle_T": 250.0,
			"isolation": {"lock": "VI-LOCK", "radius": 6.0, "knock": 0.25}},
		"power": {
			"bus": "SWB-E",
			"sources": [
				{"piece": "BAT-E", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.9, "drain": 0.0003},
			],
			"lamps": {"C": "LAMP-C", "Q": "LAMP-Q", "E": "LAMP-E"},
		},
		"fluids": {"volumes": {
			"ln2": {"fluid": "coolant", "amount": 0.08, "piece": "TRAP", "port": "PL", "full": 0.12, "content": 1.0, "leak": 0.1, "pump": [0.05, 0.004]},
			"cw": {"fluid": "water", "amount": 0.1, "nets": ["cw"], "piece": "CWP", "port": "PW", "full": 0.15, "leak": 0.08, "leak_min": 0.004, "pump": [0.06, 0.004]},
			"mixline": {"fluid": "n2", "amount": 0.0, "nets": ["mix"]},
			"heline": {"fluid": "n2", "amount": 0.0, "nets": ["he"]},
		}, "joins": [], "value": {"coolant": 2000.0, "water": 300.0}},
		"ctrls_cfg": {"G-C": {"rate": 14.0}, "G-Q": {"rate": 18.0}, "G-E": {"rate": 14.0}, "G-MIX": {"rate": 0.4}, "G-HE1": {"rate": 0.5}, "G-HE2": {"rate": 0.5}},
		"labels": {"QPU": "QPU", "STG-MXC": "MXC", "STG-CP": "CP", "STG-STILL": "STILL", "STG-4K": "4K", "STG-50K": "50K", "VIT": "ISOLATION", "GHS": "GHS", "MIX-T": "3He/4He",
			"PTC": "PT COMP", "FCTL": "FRIDGE", "BAT-E": "BAT", "SWB-E": "BUS", "AWG": "AWG", "RACK-R": "READOUT", "HE-1": "He", "HE-2": "He"},
		"hints": {},
		"market": {
			"class": "QC", "name": ["量子级计算船", "QUANTUM-CLASS COMPUTING SHIP"], "time": 28.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "Q": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0]},
			"charge": {"BAT-E": [0.4, 1.0]},
			"fluids": {},
			"knockable": ["CON-1", "CLK"],
			"drift": [],
			"section_x": 9.0,
			"slots": {"fire_system": {"x": 26.95, "y0": 5.55 - 1.4, "y1": 5.55, "base": ["HQ5-0", 5.55], "room": "E", "port": [27.35, 5.55 - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"LOG-Q": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 20.0},
				{"do": "free", "piece": "LOG-Q"},
				{"do": "deliver", "piece": "LOG-Q", "zone": "equip"},
			],
			"QPU": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "hose", "ctrl": "G-Q"},
				{"do": "wait", "until": {"P": ["Q", "<", 5.0]}, "max": 200.0},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 20.0},
				{"do": "operate", "ctrl": "D-0"},
				{"do": "wait", "until": {"open": ["Q"]}, "max": 20.0},
				{"do": "operate", "ctrl": "VI-LOCK"},
				{"do": "operate", "ctrl": "CIRC"},
				{"do": "hose", "ctrl": "G-MIX"},
				{"do": "wait", "until": {"P": ["MIX", "<", 15.0]}, "max": 300.0},
				{"do": "operate", "ctrl": "PT"},
				{"do": "wait", "until": {"stage": ["STG-MXC", ">", 30.0]}, "max": 400.0},
				{"do": "operate", "ctrl": "HEAT"},
				{"do": "wait", "until": {"stage": ["STG-MXC", ">", 252.0]}, "max": 400.0},
				{"do": "free", "piece": "QPU"},
				{"do": "deliver", "piece": "QPU", "zone": "equip"},
			],
		},
	}
