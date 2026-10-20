class_name Dc84Author
# Authoring script for DC-84 "Deep Mind", an 84 m data-centre ship (new designs 04/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/dc84.json. Metres, x bow (0) to the stern (84), y down.
#
# A long box: C the control room (the operators' consoles over the crew's quarters),
# the two machine halls A and B (two levels each, three immersion tanks a level: a
# basin of dielectric fluid with a rack standing in it, the coolant distribution and
# the power distribution between), N the network and storage room (four storage arrays
# with their drives, the core switch, the firewall, the transport case), P the power
# room (two battery banks and the bus, the main coolant pumps, the heat exchanger, a
# fuel cell); the dry coolers and their radiators on the roof over the halls.
# What it asks of you (scripts/immersion.gd): each tank drained at its port before its
# rack comes out (else it spills and shorts the racks beside it), and each drive latched
# into custody at its array before it goes (else a breach, fined).

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(0, -5), Vector2(2, -7), Vector2(82, -7), Vector2(84, -5), Vector2(84, 5), Vector2(82, 7), Vector2(2, 7), Vector2(0, 5)]
const BH := [12.0, 40.0, 68.0, 76.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 6.5
const DOOR := 3.0
const ROOMS := ["C", "A", "B", "N", "P"]

static var w
static var by_tag := {}
static var n_auto := 0
static var tanks := {}
static var drives := {}


static func build(world) -> void:
	K.begin(world, "DC84")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	tanks = {}
	drives = {}
	_hull()
	_inner()
	_control()
	_hall("A", 12.25)
	_hall("B", 40.25)
	_storage()
	_power()
	_roof()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 26.0, 7.0, 6.8)
	K.clamp(2, 60.0, 7.0, 6.8)


static func rooms_only(world) -> void:
	K.begin(world, "DC84")
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
			push_warning("DC84 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
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
	var l = E(tag, "lamp", x - 0.28, ceil_y + 0.05, x + 0.28, ceil_y + 0.21, room, {"cls": "metal", "dest": "metal", "mass": 0.04, "cut_speed": 260.0, "name_key": "p_lamp"})
	K.bolt(l, K.at(x, ceil_y - 0.15, FLOORK), x, ceil_y)


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	# edges: 0 bow upper, 1 roof, 2 stern upper, 3 stern, 4 stern lower, 5 floor, 6 bow lower, 7 bow
	K.ring(OUT, T, {1: [0.05, 0.12, 0.2, 0.28, 0.36, 0.44, 0.52, 0.6, 0.68, 0.76, 0.84, 0.885, 0.95, 0.975], 3: [0.35, 0.65],
		5: [0.04, 0.09, 0.16, 0.24, 0.32, 0.4, 0.48, 0.56, 0.64, 0.72, 0.8, 0.88, 0.9525, 0.975], 7: [0.5]}, {
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(0, 2.2) * Geom.M, "cut_speed": 200.0},
		"5:13": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HD")


static func _inner() -> void:
	var B := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	for i in BH.size():
		var x: float = BH[i]
		var u = K.plate("BH%d-U" % i, K.R(x - 0.25, -IN, x + 0.25, DOOR), B, "hull")
		var d = K.plate("D-%d" % i, K.R(x - 0.25, DOOR, x + 0.25, IN), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -3.2) * Geom.M}, "door")
		K.bolt(u, K.at(x, -IN - 0.25, ["hull"]), x, -IN, "weld")
		K.bolt(u, d, x, DOOR, "weld")
		K.bolt(d, K.at(x, IN + 0.25, ["hull"]), x, IN, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	# each room's deck, its well at the aft end
	for r in [[0.6, 11.75, "C"], [12.25, 39.75, "A"], [40.25, 67.75, "B"], [68.25, 75.75, "N"], [76.25, 83.4, "P"]]:
		var a: float = r[0]
		var b: float = r[1] - 2.6
		var dk = K.plate("DK-" + r[2], K.R(a, 0.0, b, 0.25), D, "deck")
		K.bolt(dk, K.at(a - 0.15, 0.12, ["hull"]), a, 0.12, "weld")


# ---------------------------------------------------------------- C, the control room

static func _control() -> void:
	_row("C", 0.0, -1.0, 2.6, 9.0, [["NOC-1", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_dc_noc"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["NOC-2", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_dc_noc"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["SEC", "console", 1.2, 1.2, {"mass": 0.15, "value": 9000.0, "name_key": "p_sec_console"}]])
	_row("C", -IN, 1.0, 2.6, 11.5, [["WALL", "screen", 3.0, 1.2, {"mass": 0.12, "value": 9000.0, "fragile": 0.6, "name_key": "p_dc_wall_screen"}], ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-C", 8.0, -IN, "C")
	_row("C", IN, -1.0, 1.6, 11.6, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["GAL-C", "module", 1.8, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_ark_galley"}],
		["ENV-C", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]], [[4.0, 5.8]])
	_row("C", 0.25, 1.0, 1.4, 8.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-C2", 6.0, 0.25, "C")


# ---------------------------------------------------------------- the machine halls

# an immersion tank: a basin (bottom and two walls) with the rack standing in its fluid
static func _tank(hall: String, n: int, x0: float, floor_y: float) -> String:
	var F := {"density": 1.0, "barrier": false, "cut_speed": 200.0, "name_key": "p_dc_basin"}
	var tag := "R%s-%d" % [hall, n]
	var bt = K.plate("TB%s-%d" % [hall, n], K.R(x0, floor_y - 0.3, x0 + 3.2, floor_y - 0.02), F, "fixture")
	K.bolt(bt, K.at(x0 + 0.4, floor_y + 0.12, FLOORK), x0 + 0.4, floor_y)
	K.bolt(bt, K.at(x0 + 2.8, floor_y + 0.12, FLOORK), x0 + 2.8, floor_y)
	for wx in [x0, x0 + 2.9]:
		var wl = K.plate("", K.R(wx, floor_y - 3.0, wx + 0.3, floor_y - 0.3), F, "fixture")
		K.bolt(wl, bt, wx + 0.15, floor_y - 0.3)
	var rk = E(tag, "nav_rack", x0 + 0.45, floor_y - 2.9, x0 + 2.75, floor_y - 0.32, hall, {"mass": 1.6, "value": 45000.0, "fragile": 0.5, "name_key": "p_dc_rack"})
	K.bolt(rk, bt, x0 + 0.9, floor_y - 0.3)
	K.bolt(rk, bt, x0 + 2.3, floor_y - 0.3)
	tanks[tag] = {"vol": "tk%s%d" % [hall, n], "port": "PT%s-%d" % [hall, n], "basin": "TB%s-%d" % [hall, n]}
	return tag


static func _hall(h: String, x0: float) -> void:
	var lv := 0
	for floor_y in [IN, 0.0]:
		lv += 1
		var racks: Array = []
		for i in 3:
			racks.append(_tank(h, i + 1 + (lv - 1) * 3, x0 + 0.6 + i * 4.8, floor_y))
		for i in racks.size():
			var row: Array = []
			if i > 0:
				row.append(racks[i - 1])
			if i < racks.size() - 1:
				row.append(racks[i + 1])
			tanks[racks[i]].row = row
		var keep: Array = [[x0 + 24.9, x0 + 27.5]] if floor_y == 0.0 else []
		_row(h, floor_y, -1.0, x0 + 15.2, x0 + 27.3, [["CDU-%s%d" % [h, lv], "pump", 1.6, 1.6, {"mass": 0.6, "value": 14000.0, "name_key": "p_dc_cdu"}],
			["PDU-%s%d" % [h, lv], "swb", 0.9, 2.2, {"mass": 0.3, "value": 6000.0, "name_key": "p_pdu"}], ["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}],
			["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}], ["", "cabinet", 1.0, 1.8, {"mass": 0.15, "value": 3200.0, "name_key": "p_dc_spares"}],
			["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}], 0.2,
			# the hall's own air handler for what the tanks do not take, and the rack lift
			["CRAH-%s%d" % [h, lv], "env", 1.4, 2.6, {"mass": 0.45, "value": 9500.0, "name_key": "p_dc_crah"}], ["", "lift", 1.2, 1.8, {"mass": 0.25, "value": 4200.0, "name_key": "p_dc_rack_lift"}]], keep)
		if floor_y == IN:
			# the lower level has the room past the ladder: spare drives and the leak panel
			_row(h, floor_y, -1.0, x0 + 24.9, x0 + 27.3, [["", "shelf", 1.2, 1.6, {"mass": 0.12, "value": 3800.0, "name_key": "p_dc_spare_shelf"}],
				["", "panel", 0.6, 1.0, {"mass": 0.04, "value": 2600.0, "name_key": "p_dc_leak_panel"}]])
		var ceil_y: float = 0.25 if floor_y == IN else -IN
		# under the ceiling: the coolant manifolds over the tanks, the cable trays, the
		# smoke sampling heads, the junctions and a status display over the aisle
		_row(h, ceil_y, 1.0, x0 + 0.8, x0 + 27.0, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 0.8,
			["", "pipe", 1.8, 0.4, {"mass": 0.06, "value": 2200.0, "name_key": "p_dc_manifold"}], 0.6, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_dc_tray"}],
			0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_dc_vesda"}], 0.8, ["", "pipe", 1.8, 0.4, {"mass": 0.06, "value": 2200.0, "name_key": "p_dc_manifold"}],
			0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 0.6, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_dc_tray"}],
			0.6, ["", "pipe", 1.8, 0.4, {"mass": 0.06, "value": 2200.0, "name_key": "p_dc_manifold"}], 0.6, ["", "screen", 1.0, 0.6, {"mass": 0.03, "value": 1400.0, "name_key": "p_monitor_panel"}],
			0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}], 0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_dc_vesda"}]],
			[[x0 + 24.9, x0 + 27.5]] if ceil_y == -IN else [])
		_lamp("LAMP-%s%d" % [h, lv], x0 + 9.0, ceil_y, h)


# ---------------------------------------------------------------- N, network and storage

static func _storage() -> void:
	# four storage arrays, two a level, each with its two drives on the side
	var lv := 0
	for floor_y in [IN, 0.0]:
		lv += 1
		for i in 2:
			var ax: float = 68.6 + i * 2.4
			var n := (lv - 1) * 2 + i + 1
			var ar = E("SA-%d" % n, "nav_rack", ax, floor_y - 3.2, ax + 1.4, floor_y - 0.05, "N", {"mass": 0.7, "value": 26000.0, "fragile": 0.5, "name_key": "p_dc_array"})
			K.bolt(ar, K.at(ax + 0.3, floor_y + 0.15, FLOORK), ax + 0.3, floor_y)
			K.bolt(ar, K.at(ax + 1.1, floor_y + 0.15, FLOORK), ax + 1.1, floor_y)
			for k in 2:
				var dn := (n - 1) * 2 + k + 1
				var dy: float = floor_y - 0.4 - k * 0.6
				var dr = E("DRV-%d" % dn, "blackbox", ax + 1.45, dy - 0.3, ax + 1.95, dy, "N", {"mass": 0.02, "value": 15000.0, "fragile": 0.5, "name_key": "p_dc_drive"})
				K.bolt(dr, ar, ax + 1.4, dy - 0.15)
				drives["DRV-%d" % dn] = "CUST-%d" % dn
	# the core switch and the storage's own UPS on the lower floor aft
	_row("N", IN, -1.0, 73.4, 75.7, [["CORE-SW", "nav_rack", 1.2, 3.0, {"mass": 0.4, "value": 22000.0, "fragile": 0.5, "name_key": "p_dc_core_switch"}],
		["UPS-N", "battery", 0.8, 1.2, {"mass": 0.5, "value": 6000.0, "hazard": "battery", "name_key": "p_ups"}]])
	# the firewall under the roof, the transport case under the deck
	_row("N", -IN, 1.0, 68.6, 75.6, [["FW", "aux", 1.1, 0.8, {"mass": 0.1, "value": 12000.0, "fragile": 0.5, "name_key": "p_dc_firewall"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_dc_tray"}], ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]])
	_row("N", 0.25, 1.0, 68.6, 73.0, [["DCASE", "vault", 1.4, 1.1, {"mass": 0.3, "value": 9000.0, "mandatory": true, "name_key": "p_dc_case"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-N", 71.0, -IN, "N")
	_lamp("LAMP-N2", 72.2, 0.25, "N")


# ---------------------------------------------------------------- P, the power room

static func _power() -> void:
	_row("P", 0.0, -1.0, 76.6, 80.8, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}], ["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}]])
	_row("P", -IN, 1.0, 76.6, 81.8, [["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		["FUEL-P", "fueltank", 1.0, 1.6, {"mass": 0.5, "value": 3000.0, "name_key": "p_svc_prop"}]])
	_lamp("LAMP-P", 77.0, -IN, "P")
	_row("P", IN, -1.0, 76.6, 81.9, [["MCP-1", "pump", 1.5, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_dc_main_pump"}], ["HXP", "module", 1.6, 2.0, {"mass": 1.6, "value": 18000.0, "name_key": "p_heat_exchanger"}],
		["FC-P", "gen", 1.5, 1.8, {"mass": 1.2, "value": 20000.0, "name_key": "p_fuel_cell"}]])
	_lamp("LAMP-P2", 79.0, 0.25, "P")


# ---------------------------------------------------------------- the roof's dry coolers

static func _roof() -> void:
	for i in 2:
		var x0: float = 46.0 + i * 10.0
		var rp = K.plate("RAD-%d" % (i + 1), K.R(x0, -11.0, x0 + 8.0, -7.0), {"density": 0.5, "barrier": false, "cut_speed": 230.0, "art": "radiator", "name_key": "p_radiator_fin"}, "hull")
		for x in [x0 + 1.0, x0 + 7.0]:
			K.bolt(rp, K.at(x, -6.75, ["hull"]), x, -7.0, "weld")
	for i in 3:
		var fx: float = 20.0 + i * 6.0
		var fan = E("FAN-%d" % (i + 1), "pump", fx, -8.6, fx + 1.8, -7.05, "", {"mass": 0.5, "value": 6000.0, "name_key": "p_dc_dry_cooler"})
		K.bolt(fan, K.at(fx + 0.4, -6.75, ["hull"]), fx + 0.4, -7.0)
		K.bolt(fan, K.at(fx + 1.4, -6.75, ["hull"]), fx + 1.4, -7.0)


# ---------------------------------------------------------------- lines and controls

static func _cen(t: String) -> Vector2:
	return Geom.centroid(by_tag[t].poly) / Geom.M


static func _c(id: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "cable", "power", a, _cen(a), b, _cen(b), via)


static func _p(id: String, net: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "pipe", net, a, _cen(a), b, _cen(b), via)


static func _lines() -> void:
	_c("p1", "BAT-1", "SWB-P")
	_c("p2", "BAT-2", "SWB-P")
	_c("p3", "SWB-P", "MCP-1")
	_c("p4", "SWB-P", "FC-P")
	_c("p5", "SWB-P", "CORE-SW", [Vector2(77.0, -0.6), Vector2(75.0, -0.6)])
	_c("p6", "UPS-N", "SA-1")
	_c("p7", "SA-1", "SA-2")
	_c("p8", "SA-2", "SA-3")
	_c("p9", "SA-3", "SA-4")
	_c("p10", "CORE-SW", "FW")
	for h in ["A", "B"]:
		for lv in [1, 2]:
			var feed_y: float = 1.2 if lv == 1 else -4.8
			_c("pd%s%d" % [h, lv], "SWB-P", "PDU-%s%d" % [h, lv], [Vector2(76.5, feed_y), Vector2(_cen("PDU-%s%d" % [h, lv]).x, feed_y)])
			_c("pc%s%d" % [h, lv], "PDU-%s%d" % [h, lv], "CDU-%s%d" % [h, lv])
			for i in 3:
				var rk := "R%s-%d" % [h, i + 1 + (lv - 1) * 3]
				_c("pr%s" % rk, "PDU-%s%d" % [h, lv], rk, [Vector2(_cen(rk).x, feed_y)])
			_c("pl%s%d" % [h, lv], "PDU-%s%d" % [h, lv], "LAMP-%s%d" % [h, lv])
	_c("p11", "SWB-P", "NOC-1", [Vector2(76.5, -5.6), Vector2(6.0, -5.6)])
	_c("p12", "NOC-1", "NOC-2")
	_c("p13", "NOC-1", "LAMP-C")
	_c("p14", "SWB-P", "ENV-C", [Vector2(76.5, 5.8), Vector2(6.0, 5.8)])
	_c("p15", "SWB-P", "LAMP-P")
	_c("p16", "CORE-SW", "LAMP-N")
	_c("p17", "SWB-P", "FAN-1", [Vector2(77.0, -6.2), Vector2(21.0, -6.2)])
	# the tanks' fluid, each basin to its hall's coolant distribution; the main loop
	for t in tanks:
		var hl: String = t.substr(1, 1)
		var lv: int = 1 if int(t.substr(3)) <= 3 else 2
		_p("f%s" % t, "dielectric", tanks[t].basin, "CDU-%s%d" % [hl, lv])
	_p("m1", "loop", "MCP-1", "HXP")
	_p("m2", "loop", "HXP", "CDU-B1", [Vector2(70.0, 5.0), Vector2(56.0, 5.0)])
	_p("m3", "loop", "CDU-B1", "CDU-A1", [Vector2(50.0, 5.2), Vector2(28.0, 5.2)])
	_p("m4", "loop", "HXP", "RAD-1", [Vector2(78.0, -6.0), Vector2(50.0, -6.0)])
	_p("m5", "fuel", "FC-P", "FUEL-P")


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "P"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "P"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "P"})
	K.ctrl("K-UPS", "switch", by_tag["UPS-N"], _cen("UPS-N") + Vector2(-0.3, -0.2), {"target": "K-UPS", "state": true, "hidden_room": "N"})
	K.ctrl("E-N", "test", by_tag["SA-1"], _cen("SA-1") + Vector2(0, -1.2), {"medium": "volt", "target": "SA-1", "hidden_room": "N"})
	for d in drives:
		var dp = by_tag[d]
		K.ctrl(drives[d], "switch", dp, Geom.centroid(dp.poly) / Geom.M + Vector2(0.2, 0.0), {"target": drives[d], "state": false, "hidden_room": "N"})
	for t in tanks:
		var hl: String = t.substr(1, 1)
		var bt = by_tag[tanks[t].basin]
		K.ctrl(tanks[t].port, "port", bt, Geom.centroid(bt.poly) / Geom.M + Vector2(1.45, 0.0), {"medium": "coolant", "target": tanks[t].vol, "hidden_room": hl})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.8), {"medium": "water", "target": "loop", "hidden_room": "P"})
	K.ctrl("PF", "port", by_tag["FUEL-P"], _cen("FUEL-P") + Vector2(0, -0.9), {"medium": "fuel", "target": "fuel", "hidden_room": "P"})
	var gp := {"C": 6.0, "A": 26.0, "B": 54.0, "N": 72.0, "P": 80.0}
	for r in gp:
		K.ctrl("G-" + r, "port", K.at(gp[r], 6.8, ["hull"]), Vector2(gp[r], 7.2), {"medium": "gas", "target": r})
	K.ctrl("AUX-P", "socket", K.at(64.0, 6.8, ["hull"]), Vector2(64.0, 7.2), {"target": "aux", "state": false})
	for t in ["HT-C", "HT-P"]:
		K.door(t, "")
	for i in BH.size():
		K.door("D-%d" % i, ROOMS[i])


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := [0.0, BH[0] - 0.25, BH[0] + 0.25, BH[1] - 0.25, BH[1] + 0.25, BH[2] - 0.25, BH[2] + 0.25, BH[3] - 0.25, BH[3] + 0.25, 90.0]
	for i in ROOMS.size():
		var parts := Geometry2D.intersect_polygons(inn, K.R(cuts[i * 2], -8.0, cuts[i * 2 + 1], 8.0))
		if not parts.is_empty():
			w.add_room(ROOMS[i], parts[0])


static func meta() -> Dictionary:
	var vols := {}
	var tk := {}
	var cfg_ctrls := {}
	for t in tanks:
		vols[tanks[t].vol] = {"fluid": "coolant", "amount": 0.35, "piece": tanks[t].basin, "port": tanks[t].port, "full": 0.4, "content": 1.0, "leak": 0.1, "pump": [0.08, 0.006]}
		tk[t] = {"vol": tanks[t].vol, "row": tanks[t].row}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.3, "nets": ["fuel"], "piece": "FUEL-P", "port": "PF", "full": 0.5, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	vols["dline"] = {"fluid": "n2", "amount": 0.0, "nets": ["dielectric"]}
	var rooms := {}
	var names := {}
	var mrooms := {}
	for r in ROOMS:
		rooms[r] = 101.0
		names[r] = "room_dc" + r
		mrooms[r] = [0.2, 40.0, 101.0]
	var lamps := {"C": "LAMP-C", "A": "LAMP-A1", "B": "LAMP-B1", "N": "LAMP-N", "P": "LAMP-P"}
	return {
		"id": "dc84",
		"name": "DC-84 DEEP MIND",
		"title": ["DC-84「深算」数据中心船 · 84 m", "DC-84 DEEP MIND · DATA-CENTRE SHIP · 84 m"],
		"contract": "DC-84",
		"length": 84.0,
		"value": {"total": 1319200.0, "metal": 20000.0},
		"clamps": [[26.0, 7.0], [60.0, 7.0]],
		"room_names": names,
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 8000.0},
		"immersion": {"tanks": tk, "min": 0.02, "drives": drives, "fine": 20000.0},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [{"piece": "UPS-N", "volts": 220.0, "charge": 0.8, "switch": "K-UPS"}],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"coolant": 48000.0, "water": 300.0, "fuel": 3000.0}},
		"ctrls_cfg": {"G-C": {"rate": 22.0}, "G-A": {"rate": 40.0}, "G-B": {"rate": 40.0}, "G-N": {"rate": 18.0}, "G-P": {"rate": 18.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "CORE-SW": "CORE", "FW": "FW", "DCASE": "CUSTODY", "UPS-N": "UPS", "HXP": "HX", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "DC", "name": ["深算级数据中心船", "DEEP MIND-CLASS DATA-CENTRE SHIP"], "time": 42.0,
			"rooms": mrooms,
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0], "UPS-N": [0.3, 1.0]},
			"fluids": {},
			"knockable": ["WALL", "NOC-2"],
			"drift": [],
			"section_x": 40.0,
			"slots": {"fire_system": {"x": 54.0, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "B", "port": [54.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"DCASE": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "hose", "ctrl": "G-A"},
				{"do": "hose", "ctrl": "G-B"},
				{"do": "hose", "ctrl": "G-N"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 300.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 20.0},
				{"do": "wait", "until": {"P": ["A", "<", 5.0]}, "max": 300.0},
				{"do": "operate", "ctrl": "D-0"},
				{"do": "wait", "until": {"open": ["A"]}, "max": 20.0},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 300.0},
				{"do": "operate", "ctrl": "D-1"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 20.0},
				{"do": "wait", "until": {"P": ["N", "<", 5.0]}, "max": 300.0},
				{"do": "operate", "ctrl": "D-2"},
				{"do": "wait", "until": {"open": ["N"]}, "max": 20.0},
				{"do": "free", "piece": "DCASE"},
				{"do": "deliver", "piece": "DCASE", "zone": "equip"},
			],
		},
	}


const FIRE_BASE := "HD5-5"
