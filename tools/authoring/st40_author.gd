class_name St40Author
# Authoring script for ST-40 "Hummingbird", a 40 m racing ship (new designs 02/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/st40.json. Metres, x bow (0) to the stern (40), y down.
#
# A wedge of carbon-fibre composite: the pointed nose and the bubble canopy over the
# cockpit P (the anti-g seat, the controls, the race data recorder), the equipment bay
# E (the nitrous oxide tank, two fuel tanks, the race battery and its inverter, the
# telemetry), the motor bay M (the engine, its turbopump and controller, the igniter's
# capacitor), the nozzle hung off the stern; two composite fins.
# What it asks of you (scripts/composite.gd): the airframe's panels are composite.
# Cut one beside a room that still has air and the smoke settles into that room's
# electronics (and fogs the canopy); vent the room first, or undo the panel's bolts.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.35
const OUT := [Vector2(0, 0), Vector2(6, -2.4), Vector2(11, -3.0), Vector2(14, -3.8), Vector2(18, -3.0), Vector2(33, -3.0), Vector2(35, -3.6),
	Vector2(40, -3.6), Vector2(40, 3.0), Vector2(12, 3.0), Vector2(5, 1.6)]
const BH := [15.0, 32.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const FLOOR := 2.65
const TOP := -2.65

static var w
static var by_tag := {}
static var n_auto := 0


static func build(world) -> void:
	K.begin(world, "ST40")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	_hull()
	_inner()
	_cockpit()
	_bay()
	_motor()
	_outside()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 20.0, 3.0, 2.8)
	K.clamp(2, 29.0, 3.0, 2.8)


static func rooms_only(world) -> void:
	K.begin(world, "ST40")
	w = world
	_rooms()


static func _auto(p: String) -> String:
	n_auto += 1
	return "%s%d" % [p, n_auto]


static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, room: String, o: Dictionary):
	var opts := {"fragile": 0.4, "room": room}
	opts.merge(o, true)
	return K.equip(tag if tag != "" else _auto(art.left(4).to_upper() + "-"), art, K.rect(x0, y0, x1, y1), opts)


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
			push_warning("ST40 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
			continue
		var ya: float = floor_y + up * 0.05
		var yb: float = floor_y + up * (0.05 + h)
		var p = E(it[0], it[1], x, minf(ya, yb), x + wd, maxf(ya, yb), room, it[4])
		for bx in [x + minf(0.3, wd * 0.25), x + wd - minf(0.3, wd * 0.25)]:
			K.bolt(p, K.at(bx, floor_y - up * 0.15, FLOORK), bx, floor_y)
		out.append(p)
		x += wd + 0.3
	return out


# ---------------------------------------------------------------- the airframe

static func _hull() -> void:
	var glass := {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.1, "value": 6000.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_st_canopy"}
	# edges: 0 nose up, 1 forebody, 2 canopy front, 3 canopy rear, 4 back, 5 step, 6 motor top,
	# 7 stern, 8 belly, 9 chin, 10 nose low
	K.ring(OUT, T, {1: [0.5], 4: [0.2, 0.33, 0.47, 0.6, 0.73, 0.87], 6: [0.5], 7: [0.3, 0.7], 8: [0.12, 0.2, 0.32, 0.45, 0.55, 0.68, 0.8, 0.9], 9: [0.5]}, {
		"2:0": glass.merged({"tag": "CAN-1"}),
		"3:0": glass.merged({"tag": "CAN-2"}),
		"4:2": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(1.6, 0) * Geom.M, "cut_speed": 120.0, "name_key": "p_st_composite"},
		"9:0": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(-1.6, 0) * Geom.M, "cut_speed": 120.0, "name_key": "p_st_composite"},
	}, {"density": 0.7, "barrier": true, "cut_speed": 120.0, "name_key": "p_st_composite"}, "HC")
	# composite panels are bolted to each other, not welded: the wrench can take them apart
	for id in w.order:
		var p = w.pieces[id]
		if p.tag.begins_with("HC") or p.tag.begins_with("CAN") or p.tag.begins_with("HT-"):
			for j in w.joints_of(p):
				j.type = "bolt"


static func _inner() -> void:
	var B := {"density": 1.2, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	for i in 2:
		var x: float = BH[i]
		var top: float = -3.25 if i == 0 else TOP
		var u = K.plate("BH%d-U" % i, K.R(x - 0.2, top, x + 0.2, 0.6), B, "hull")
		var d = K.plate("D-%d" % i, K.R(x - 0.2, 0.6, x + 0.2, FLOOR), {"density": 1.1, "barrier": true, "cut_speed": 190.0, "door": true,
			"open_dir": Vector2(0, -1.8) * Geom.M}, "door")
		K.bolt(u, K.at(x, top - 0.2, ["hull"]), x, top, "weld")
		K.bolt(u, d, x, 0.6, "weld")
		K.bolt(d, K.at(x, FLOOR + 0.17, ["hull"]), x, FLOOR, "weld")


# ---------------------------------------------------------------- P, the cockpit

static func _cockpit() -> void:
	# the cockpit's floor over the avionics bay, a well forward to get down to it
	var pf = K.plate("DK-P", K.R(9.0, 0.2, 14.8, 0.45), {"density": 0.6, "barrier": false, "cut_speed": 200.0, "name_key": "p_st_floor"}, "deck")
	K.bolt(pf, by_tag["BH0-U"], 14.8, 0.32, "weld")
	_row("P", 0.2, -1.0, 9.2, 14.6, [["CON-P", "console", 1.4, 1.0, {"mass": 0.12, "value": 22000.0, "fragile": 0.5, "name_key": "p_st_controls"}],
		["SEAT-P", "seat", 1.3, 1.6, {"mass": 0.12, "value": 18000.0, "name_key": "p_st_seat"}], ["LS-P", "env", 1.0, 0.9, {"mass": 0.12, "value": 6000.0, "name_key": "p_env_control"}],
		["", "gastank", 0.4, 1.0, {"mass": 0.04, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]])
	var hud = E("HUD", "screen", 9.5, -1.4, 10.3, -0.85, "P", {"mass": 0.03, "value": 8000.0, "fragile": 0.6, "name_key": "p_st_hud"})
	K.bolt(hud, by_tag["CON-P"], 9.9, -0.85)
	# under the floor: the avionics, the race data recorder (the hatch beside them)
	_row("P", FLOOR, -1.0, 12.2, 14.75, [["AV-P", "nav", 0.6, 1.1, {"mass": 0.08, "value": 15000.0, "fragile": 0.5, "name_key": "p_avionics"}],
		["RDR", "blackbox", 0.6, 0.4, {"mass": 0.05, "value": 26000.0, "mandatory": true, "name_key": "p_st_rdr"}], ["", "o2cab", 0.5, 1.0, {"mass": 0.06, "value": 1600.0, "name_key": "p_o2cab"}]])
	_row("P", 0.45, 1.0, 9.4, 14.6, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["", "cabinet", 1.0, 0.6, {"mass": 0.05, "value": 2400.0, "name_key": "p_st_spares"}]])
	K.lamp("LAMP-P", 13.6, -3.1, "P", by_tag["BH0-U"]) if false else _lamp_on_wall()


static func _lamp_on_wall() -> void:
	var l = E("LAMP-P", "lamp", 14.2, -2.9, 14.75, -2.7, "P", {"cls": "metal", "dest": "metal", "mass": 0.04, "cut_speed": 260.0, "name_key": "p_lamp"})
	K.bolt(l, by_tag["BH0-U"], 14.8, -2.8)


# ---------------------------------------------------------------- E, the equipment bay

static func _bay() -> void:
	_row("E", FLOOR, -1.0, 15.5, 31.6, [["OX-1", "gastank", 1.4, 2.6, {"mass": 1.2, "value": 9000.0, "hazard": "gas_tank", "name_key": "p_st_n2o"}],
		["FT-1", "fueltank", 1.6, 1.6, {"mass": 0.8, "value": 5000.0, "name_key": "p_st_fuel"}], ["FT-2", "fueltank", 1.6, 1.6, {"mass": 0.8, "value": 5000.0, "name_key": "p_st_fuel"}],
		["BAT-R", "battery", 1.8, 1.4, {"mass": 1.6, "value": 32000.0, "hazard": "battery", "name_key": "p_st_battery"}], ["INV", "cabinet", 1.2, 1.3, {"mass": 0.3, "value": 16000.0, "name_key": "p_inverter"}],
		["PDU", "swb", 1.0, 2.0, {"mass": 0.3, "value": 7000.0, "name_key": "p_pdu"}], ["CP-1", "pump", 0.9, 0.8, {"mass": 0.12, "value": 3500.0, "name_key": "p_coolant_pump"}],
		["TLM", "nav_rack", 0.8, 1.9, {"mass": 0.15, "value": 21000.0, "fragile": 0.5, "name_key": "p_st_telemetry"}], ["DAQ", "aux", 0.8, 0.8, {"mass": 0.05, "value": 12000.0, "fragile": 0.5, "name_key": "p_st_daq"}]])
	_row("E", TOP, 1.0, 18.4, 31.6, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["CW-1", "radiator", 2.4, 0.5, {"mass": 0.15, "value": 4000.0, "name_key": "p_st_cooler"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.0, ["GYRO", "aux", 0.9, 0.6, {"mass": 0.08, "value": 14000.0, "fragile": 0.5, "name_key": "p_inertial_unit"}],
		["", "screen", 0.8, 0.5, {"mass": 0.03, "value": 1800.0, "name_key": "p_ark_screen"}]], [[22.95, 25.05]])
	K.lamp("LAMP-E", 20.0, TOP, "E", K.at(20.0, TOP - 0.15, ["hull"]))
	# a second rack under the deckhead aft: the race transponder, the onboard camera
	# recorder, the bay's fire bottle, the spare igniter kit
	_row("E", TOP, 1.0, 26.0, 31.6, [["XPDR", "nav", 0.7, 0.8, {"mass": 0.04, "value": 9000.0, "fragile": 0.5, "name_key": "p_st_transponder"}],
		["CAM-R", "blackbox", 0.5, 0.4, {"mass": 0.03, "value": 7000.0, "name_key": "p_st_camera_rec"}], ["", "gastank", 0.4, 1.0, {"mass": 0.04, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}],
		["", "cabinet", 0.8, 0.6, {"mass": 0.05, "value": 2500.0, "name_key": "p_st_spares"}]], [[22.95, 25.05]])


# ---------------------------------------------------------------- M, the motor bay

static func _motor() -> void:
	_row("M", FLOOR, -1.0, 32.5, 39.5, [["ENG", "eng_core", 2.6, 2.4, {"mass": 2.6, "value": 85000.0, "fragile": 0.3, "name_key": "p_engine"}], ["TP", "pump", 1.4, 1.2, {"mass": 0.5, "value": 18000.0, "name_key": "p_st_turbopump"}],
		["ECU", "panel", 0.8, 1.0, {"mass": 0.05, "value": 9000.0, "name_key": "p_st_ecu"}], ["IGN", "cap", 0.6, 0.6, {"mass": 0.05, "value": 3000.0, "hazard": "cap", "name_key": "p_st_igniter"}]])
	_row("M", -3.25, 1.0, 35.4, 39.5, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["", "gastank", 0.4, 1.0, {"mass": 0.04, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]])
	K.lamp("LAMP-M", 36.5, -3.25, "M", K.at(36.5, -3.4, ["hull"]))


# ---------------------------------------------------------------- outside

static func _outside() -> void:
	var nz = E("NOZ", "nozzle", 40.05, -2.6, 43.4, 2.0, "", {"mass": 1.6, "value": 24000.0, "name_key": "p_thrust_chamber"})
	K.bolt(nz, K.at(39.8, -1.8, ["hull"]), 40.0, -1.8)
	K.bolt(nz, K.at(39.8, 1.2, ["hull"]), 40.0, 1.2)
	var ns = E("NOSE-S", "radar", -1.0, -0.4, 0.2, 0.4, "", {"mass": 0.04, "value": 11000.0, "fragile": 0.5, "name_key": "p_st_nose_sensor"})
	K.bolt(ns, K.at(0.4, 0.0, ["hull"]), 0.1, 0.0)
	var F := {"density": 0.6, "barrier": false, "cut_speed": 120.0, "name_key": "p_st_fin"}
	var fu = K.plate("HCF-U", K.mp([Vector2(27.0, -3.0), Vector2(31.0, -3.0), Vector2(33.0, -6.0), Vector2(31.0, -6.0)]), F, "hull")
	K.bolt(fu, K.at(28.0, -2.8, ["hull"]), 28.0, -3.0)
	K.bolt(fu, K.at(30.5, -2.8, ["hull"]), 30.5, -3.0)
	var fl = K.plate("HCF-L", K.mp([Vector2(27.0, 3.0), Vector2(31.0, 3.0), Vector2(33.0, 6.0), Vector2(31.0, 6.0)]), F, "hull")
	K.bolt(fl, K.at(27.4, 2.85, ["hull"]), 27.4, 3.0)
	K.bolt(fl, K.at(30.2, 2.85, ["hull"]), 30.2, 3.0)
	# camera pods on the fins (the broadcast feed)
	for cp in [["CAMP-U", "HCF-U", 30.4, -4.6, -4.0], ["CAMP-L", "HCF-L", 30.4, 4.0, 4.6]]:
		var pod = E(cp[0], "screen", cp[2], cp[3], cp[2] + 0.8, cp[4], "", {"mass": 0.03, "value": 6500.0, "fragile": 0.5, "name_key": "p_st_camera_pod"})
		K.bolt(pod, by_tag[cp[1]], cp[2] + 0.4, (cp[3] + cp[4]) * 0.5)
	for r in [["RCS-1", 37.0, -4.6, -3.6, -3.4], ["RCS-2", 37.0, 3.0, 4.0, 2.85]]:
		var rc = E(r[0], "rcs_quad", r[1], r[2], r[1] + 1.2, r[3], "", {"mass": 0.1, "value": 5000.0, "name_key": "p_rcs"})
		K.bolt(rc, K.at(r[1] + 0.3, r[4], ["hull"]), r[1] + 0.3, -3.6 if r[0] == "RCS-1" else 3.0)
		K.bolt(rc, K.at(r[1] + 0.9, r[4], ["hull"]), r[1] + 0.9, -3.6 if r[0] == "RCS-1" else 3.0)


# ---------------------------------------------------------------- lines and controls

static func _cen(t: String) -> Vector2:
	return Geom.centroid(by_tag[t].poly) / Geom.M


static func _c(id: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "cable", "power", a, _cen(a), b, _cen(b), via)


static func _p(id: String, net: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "pipe", net, a, _cen(a), b, _cen(b), via)


static func _lines() -> void:
	_c("p1", "BAT-R", "PDU")
	_c("p2", "PDU", "INV")
	_c("p3", "INV", "TP", [Vector2(26.0, 1.0), Vector2(34.0, 1.0)])
	_c("p4", "PDU", "TLM")
	_c("p5", "PDU", "AV-P", [Vector2(27.0, 1.2), Vector2(13.2, 1.2)])
	_c("p6", "AV-P", "CON-P")
	_c("p7", "AV-P", "HUD")
	_c("p8", "PDU", "LAMP-E")
	_c("p9", "PDU", "ECU", [Vector2(30.0, -0.4), Vector2(36.0, -0.4)])
	_c("p10", "ECU", "LAMP-M")
	_c("p11", "AV-P", "LAMP-P")
	_c("p12", "PDU", "LS-P", [Vector2(27.0, -1.6), Vector2(14.4, -1.6)])
	_c("p13", "PDU", "DAQ")
	_c("p14", "DAQ", "GYRO")
	_c("p15", "ECU", "IGN")
	_p("f1", "fuel", "FT-1", "TP", [Vector2(19.0, 0.4), Vector2(34.5, 0.4)])
	_p("f2", "fuel", "FT-2", "TP", [Vector2(21.0, 0.2), Vector2(34.6, 0.2)])
	_p("o1", "ox", "OX-1", "TP", [Vector2(16.3, -0.1), Vector2(34.7, -0.1)])
	_p("c1", "cool", "CP-1", "CW-1")
	_p("c2", "cool", "CP-1", "BAT-R")
	_p("c3", "cool", "CP-1", "ENG", [Vector2(26.4, 2.0), Vector2(33.0, 2.0)])


static func _controls() -> void:
	var pd = by_tag["PDU"]
	K.ctrl("K-M", "switch", pd, _cen("PDU") + Vector2(-0.25, -0.5), {"target": "K-M", "state": true, "hidden_room": "E"})
	K.ctrl("E-1", "test", pd, _cen("PDU") + Vector2(0.25, -0.5), {"medium": "volt", "target": "bus", "hidden_room": "E"})
	K.ctrl("DIS-IGN", "discharge", by_tag["ECU"], _cen("ECU") + Vector2(0, -0.2), {"target": "IGN", "state": false, "hidden_room": "M"})
	K.ctrl("G-OX", "port", by_tag["OX-1"], _cen("OX-1") + Vector2(0, -1.0), {"medium": "gas", "target": "OX", "hidden_room": "E"})
	K.ctrl("PF-1", "port", by_tag["FT-1"], _cen("FT-1") + Vector2(0, -0.5), {"medium": "fuel", "target": "ft1", "hidden_room": "E"})
	K.ctrl("PF-2", "port", by_tag["FT-2"], _cen("FT-2") + Vector2(0, -0.5), {"medium": "fuel", "target": "ft2", "hidden_room": "E"})
	K.ctrl("PC", "port", by_tag["CP-1"], _cen("CP-1") + Vector2(0, -0.3), {"medium": "coolant", "target": "cool", "hidden_room": "E"})
	K.ctrl("SM-E", "probe", by_tag["DAQ"], _cen("DAQ") + Vector2(0, -0.2), {"medium": "fume", "target": "E", "hidden_room": "E"})
	K.ctrl("G-P", "port", K.at(9.0, -2.7, ["hull"]), Vector2(9.0, -3.0), {"medium": "gas", "target": "P"})
	K.ctrl("G-E", "port", K.at(26.5, -2.85, ["hull"]), Vector2(26.5, -3.2), {"medium": "gas", "target": "E"})
	K.ctrl("G-M", "port", K.at(37.0, 2.85, ["hull"]), Vector2(38.4, 3.2), {"medium": "gas", "target": "M"})
	K.ctrl("AUX-P", "socket", K.at(24.0, 2.85, ["hull"]), Vector2(24.0, 3.2), {"target": "aux", "state": false})
	for t in ["HT-P", "HT-E"]:
		K.door(t, "")
	K.door("D-0", "P")
	K.door("D-1", "E")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := {"P": [0.0, BH[0] - 0.2], "E": [BH[0] + 0.2, BH[1] - 0.2], "M": [BH[1] + 0.2, 41.0]}
	for n in cuts:
		var r := K.R(cuts[n][0], -6.0, cuts[n][1], 6.0)
		var parts := Geometry2D.intersect_polygons(inn, r)
		if not parts.is_empty():
			w.add_room(n, parts[0])


static func meta() -> Dictionary:
	return {
		"id": "st40",
		"name": "ST-40 HUMMINGBIRD",
		"title": ["ST-40「蜂鸟」竞速艇 · 40 m", "ST-40 HUMMINGBIRD · RACING SHIP · 40 m"],
		"contract": "ST-40",
		"length": 43.4,
		"value": {"total": 456700.0, "metal": 3000.0},
		"clamps": [[20.0, 3.0], [29.0, 3.0]],
		"room_names": {"P": "room_stP", "E": "room_stE", "M": "room_stM"},
		"gas": {"rooms": {"P": 101.0, "E": 101.0, "M": 101.0},
			"vessels": {"OX": {"V": 0.8, "kpa": 4800.0, "piece": "OX-1", "burst": 300.0}}, "valves": [], "value": 9000.0},
		"composite": {"prefixes": ["HC"], "fume": 1.0, "rate": 0.012, "floor": 0.55,
			"electronics": ["console", "nav", "nav_rack", "aux", "screen", "panel", "swb", "cabinet", "env", "blackbox"],
			"fog": {"CAN-1": "P", "CAN-2": "P"}, "fog_at": 1.5},
		"power": {
			"bus": "PDU",
			"sources": [
				{"piece": "BAT-R", "kind": "battery", "volts": 800.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.85, "drain": 0.0003},
			],
			"isolated": [{"piece": "IGN", "kind": "cap", "volts": 400.0, "charge": 0.8, "discharge": "DIS-IGN"}],
			"lamps": {"P": "LAMP-P", "E": "LAMP-E", "M": "LAMP-M"},
		},
		"fluids": {"volumes": {
			"ft1": {"fluid": "fuel", "amount": 0.4, "piece": "FT-1", "port": "PF-1", "full": 0.6, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]},
			"ft2": {"fluid": "fuel", "amount": 0.3, "piece": "FT-2", "port": "PF-2", "full": 0.6, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]},
			"cool": {"fluid": "coolant", "amount": 0.15, "nets": ["cool"], "piece": "CP-1", "port": "PC", "full": 0.2, "leak": 0.1, "leak_min": 0.004, "pump": [0.08, 0.004]},
			"fline": {"fluid": "fuel", "amount": 0.0, "nets": ["fuel"]},
			"oxline": {"fluid": "n2", "amount": 0.0, "nets": ["ox"]},
		}, "joins": [], "value": {"fuel": 6000.0, "coolant": 800.0}},
		"ctrls_cfg": {"G-P": {"rate": 12.0}, "G-E": {"rate": 18.0}, "G-M": {"rate": 14.0}, "G-OX": {"rate": 2.0}},
		"labels": {"BAT-R": "800 V", "PDU": "PDU", "OX-1": "N2O", "FT-1": "FUEL", "FT-2": "FUEL", "ENG": "ENG", "RDR": "RDR", "TLM": "TLM", "IGN": "IGN", "ECU": "ECU", "CON-P": "CTRL"},
		"hints": {},
		"market": {
			"class": "ST", "name": ["蜂鸟级竞速艇", "HUMMINGBIRD-CLASS RACING SHIP"], "time": 24.0,
			"rooms": {"P": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0], "M": [0.2, 40.0, 101.0]},
			"charge": {"BAT-R": [0.4, 1.0]},
			"fluids": {"ft1": [0.1, 0.5], "ft2": [0.1, 0.5]},
			"knockable": ["HUD", "GYRO"],
			"drift": [],
			"section_x": 15.0,
			"slots": {"fire_system": {"x": 39.0, "y0": FLOOR - 1.4, "y1": FLOOR, "base": [FIRE_BASE, FLOOR], "room": "M", "port": [39.4, FLOOR - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"RDR": [
				{"do": "hose", "ctrl": "G-P"},
				{"do": "wait", "until": {"P": ["P", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-P"},
				{"do": "wait", "until": {"open": ["P"]}, "max": 20.0},
				{"do": "free", "piece": "RDR"},
				{"do": "deliver", "piece": "RDR", "zone": "equip"},
			],
		},
	}


const FIRE_BASE := "HC8-0"
