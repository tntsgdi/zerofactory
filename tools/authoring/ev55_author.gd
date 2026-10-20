class_name Ev55Author
# Authoring script for EV-55 "Fire-Eye", a 55 m solar observatory (new designs 03/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/ev55.json. Metres, x bow (0) to the nozzle (~55), y down.
#
# A cone of heat-shield tiles at the bow on its carrier plates and back plate, a truss
# back to the instrument module I (the coronagraph, the spectrometers and detectors
# that looked at the sun, their computer and recorder), the habitat H, the power room E
# with its two radiator wings, the engine aft.
# What it asks of you (scripts/thermal.gd): it came straight back from perihelion. The
# tiles are at 820 °C, the shield's frame at 520, the instrument module at 190; they
# cool zone by zone, four times faster with the berth's cooling plugged into the ship's
# loop. A hot tile shatters when cut or freed, equipment taken out of a hot zone is heat
# damaged, and the drone is burnt where it is hottest.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(12, -3.5), Vector2(13, -4.5), Vector2(50, -4.5), Vector2(52, -3.5), Vector2(52, 3.5), Vector2(50, 4.5), Vector2(13, 4.5), Vector2(12, 3.5)]
const BH := [24.0, 36.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 4.0           # |y| of the hull's inside

static var w
static var by_tag := {}
static var n_auto := 0


static func build(world) -> void:
	K.begin(world, "EV55")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	_hull()
	_inner()
	_shield()
	_instruments()
	_habitat()
	_power()
	_outside()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 20.0, 4.5, 4.3)
	K.clamp(2, 44.0, 4.5, 4.3)


static func rooms_only(world) -> void:
	K.begin(world, "EV55")
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
			push_warning("EV55 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
			continue
		var ya: float = floor_y + up * 0.05
		var yb: float = floor_y + up * (0.05 + h)
		var p = E(it[0], it[1], x, minf(ya, yb), x + wd, maxf(ya, yb), room, it[4])
		for bx in [x + minf(0.3, wd * 0.25), x + wd - minf(0.3, wd * 0.25)]:
			K.bolt(p, K.at(bx, floor_y - up * 0.15, FLOORK), bx, floor_y)
		out.append(p)
		x += wd + 0.3
	return out


static func _lamp(tag: String, x: float, ceil_y: float, room: String, up: float = -1.0) -> void:
	var ya := ceil_y - up * 0.05
	var yb := ceil_y - up * 0.21
	var l = E(tag, "lamp", x - 0.28, minf(ya, yb), x + 0.28, maxf(ya, yb), room, {"cls": "metal", "dest": "metal", "mass": 0.04, "cut_speed": 260.0, "name_key": "p_lamp"})
	K.bolt(l, K.at(x, ceil_y + up * 0.15, FLOORK), x, ceil_y)


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	# edges: 0 bow upper chamfer, 1 roof, 2 stern upper, 3 stern, 4 stern lower, 5 floor, 6 bow lower, 7 front wall
	K.ring(OUT, T, {1: [0.08, 0.2, 0.3, 0.378, 0.432, 0.5, 0.62, 0.72, 0.82, 0.9], 3: [0.5], 5: [0.1, 0.18, 0.28, 0.38, 0.5, 0.62, 0.7, 0.8, 0.92], 7: [0.3, 0.7]}, {
		"1:4": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(1.8, 0) * Geom.M, "cut_speed": 200.0},
		"5:2": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HE")


static func _inner() -> void:
	var B := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	for i in 2:
		var x: float = BH[i]
		var u = K.plate("BH%d-U" % i, K.R(x - 0.25, -IN, x + 0.25, 1.2), B, "hull")
		var d = K.plate("D-%d" % i, K.R(x - 0.25, 1.2, x + 0.25, IN), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -2.6) * Geom.M}, "door")
		K.bolt(u, K.at(x, -IN - 0.25, ["hull"]), x, -IN, "weld")
		K.bolt(u, d, x, 1.2, "weld")
		K.bolt(d, K.at(x, IN + 0.25, ["hull"]), x, IN, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	# the instrument module's deck (a well aft), the power room's (a well forward)
	var di = K.plate("DK-I", K.R(12.6, 0.0, 21.2, 0.25), D, "deck")
	K.bolt(di, K.at(12.25, 0.12, ["hull"]), 12.5, 0.12, "weld")
	var de = K.plate("DK-E", K.R(38.8, 0.0, 51.4, 0.25), D, "deck")
	K.bolt(de, K.at(51.75, 0.12, ["hull"]), 51.5, 0.12, "weld")


# ---------------------------------------------------------------- the heat shield

static func _shield() -> void:
	var bp = K.plate("SHB", K.R(8.0, -9.0, 8.6, 9.0), {"density": 2.0, "barrier": false, "cut_speed": 150.0, "name_key": "p_ev_shield_back"}, "beam")
	var tip := Vector2(0.0, 0.0)
	for side in [-1.0, 1.0]:
		var base := Vector2(8.0, side * 9.0)
		var nm := "U" if side < 0.0 else "L"
		var dir := (base - tip).normalized()
		var nrm: Vector2 = Vector2(-dir.y, dir.x) * (-side)        # into the cone
		if nrm.x < 0.0:
			nrm = -nrm
		var prev_c = null
		for i in 6:
			var a: Vector2 = tip.lerp(base, i / 6.0)
			var b: Vector2 = tip.lerp(base, (i + 1) / 6.0)
			# the tile on the outside, its carrier plate under it
			# a hand's breadth apart from its neighbours and its carrier: freed, it must not
			# start pressed against them
			var a2: Vector2 = a + dir * 0.16
			var b2: Vector2 = b - dir * 0.16
			var tq := [a2, b2, b2 + nrm * 0.42, a2 + nrm * 0.42]
			var cq := [a + nrm * 0.45, b + nrm * 0.45, b + nrm * 0.85, a + nrm * 0.85]
			var tl = K.equip("TILE-%s%d" % [nm, i + 1], "armor", K.rect(minf(a2.x, b2.x), minf(a2.y, b2.y), maxf(a2.x, b2.x), maxf(a2.y, b2.y)),
				{"mass": 0.35, "value": 6500.0, "fragile": 0.5, "name_key": "p_ev_tile", "cut_speed": 90.0}, K.mp(tq))
			var cr = K.plate("CAR-%s%d" % [nm, i + 1], K.mp(cq), {"density": 1.4, "barrier": false, "cut_speed": 160.0, "name_key": "p_ev_carrier"}, "beam")
			var m := a.lerp(b, 0.5)
			K.bolt(tl, cr, m.x - dir.x * 0.4 + nrm.x * 0.45, m.y - dir.y * 0.4 + nrm.y * 0.45)
			K.bolt(tl, cr, m.x + dir.x * 0.4 + nrm.x * 0.45, m.y + dir.y * 0.4 + nrm.y * 0.45)
			if prev_c != null:
				K.bolt(cr, prev_c, a.x + nrm.x * 0.65, a.y + nrm.y * 0.65, "weld")
			prev_c = cr
		K.bolt(prev_c, bp, 8.0, side * 8.4, "weld")
	# the shield's truss back to the instrument module
	for y in [-3.0, 0.0, 3.0]:
		var tr = K.plate("STR-%d" % int(y + 3.0), K.R(8.6, y - 0.3, 12.0, y + 0.3), {"density": 1.8, "barrier": false, "cut_speed": 150.0, "name_key": "p_ev_truss"}, "beam")
		K.bolt(tr, bp, 8.6, y, "weld")
		K.bolt(tr, K.at(12.25, y, ["hull"]), 12.0, y, "weld")
	# what sits behind the shield: its temperature sensors and the sun sensor head
	# (inside the instrument module's front wall, wired out to the shield)
	for t in [["TS-1", -3.6], ["TS-2", 3.0]]:
		var ts = E(t[0], "panel", 12.55, t[1] - 0.4, 13.0, t[1] + 0.4, "I", {"mass": 0.03, "value": 2500.0, "name_key": "p_ev_shield_sensor"})
		K.bolt(ts, K.at(12.25, t[1], ["hull"]), 12.5, t[1])


# ---------------------------------------------------------------- I, the instrument module

static func _instruments() -> void:
	_row("I", 0.0, -1.0, 12.9, 21.0, [["CORO", "nav_rack", 1.6, 3.4, {"mass": 0.9, "value": 64000.0, "fragile": 0.6, "name_key": "p_ev_coronagraph"}],
		["SPEC-1", "insp", 1.4, 1.6, {"mass": 0.4, "value": 38000.0, "fragile": 0.6, "name_key": "p_ev_spectrometer"}], ["SPEC-2", "insp", 1.4, 1.6, {"mass": 0.4, "value": 34000.0, "fragile": 0.6, "name_key": "p_ev_spectrometer"}],
		["PART", "aux", 1.0, 1.0, {"mass": 0.2, "value": 22000.0, "fragile": 0.5, "name_key": "p_ev_particle"}], ["MAGN", "panel", 0.8, 1.2, {"mass": 0.1, "value": 14000.0, "name_key": "p_ev_magnetometer"}]])
	_row("I", -IN, 1.0, 13.4, 23.6, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["THCAM", "insp", 1.0, 0.7, {"mass": 0.08, "value": 18000.0, "fragile": 0.6, "name_key": "p_ev_thermal_cam"}],
		["", "screen", 1.0, 0.6, {"mass": 0.03, "value": 2000.0, "name_key": "p_ark_screen"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-I", 18.0, -IN, "I")
	_row("I", IN, -1.0, 12.9, 23.6, [["ICP", "nav_rack", 1.2, 3.0, {"mass": 0.35, "value": 30000.0, "fragile": 0.5, "name_key": "p_ev_inst_computer"}],
		["DREC", "blackbox", 0.7, 0.5, {"mass": 0.06, "value": 24000.0, "mandatory": true, "name_key": "p_ev_data_recorder"}], ["ICOOL", "pump", 1.2, 1.0, {"mass": 0.25, "value": 6000.0, "name_key": "p_coolant_pump"}],
		["", "cabinet", 1.2, 1.6, {"mass": 0.2, "value": 4500.0, "name_key": "p_ev_calib"}], ["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]])
	_lamp("LAMP-I2", 17.0, 0.25, "I")


# ---------------------------------------------------------------- H, the habitat

static func _habitat() -> void:
	# two levels: the crew's berths above the deck, the galley and the sick bay below
	var dh = K.plate("DK-H", K.R(24.25, 0.0, 33.2, 0.25), {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}, "deck")
	K.bolt(dh, by_tag["BH0-U"], 24.25, 0.12, "weld")
	_row("H", 0.0, -1.0, 24.5, 33.0, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}],
		["", "desk", 1.2, 0.9, {"mass": 0.08, "value": 1400.0, "name_key": "p_ark_desk"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}]])
	_row("H", -IN, 1.0, 24.6, 35.6, [["", "suit", 0.8, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "suit", 0.8, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["", "screen", 1.2, 0.7, {"mass": 0.03, "value": 2000.0, "name_key": "p_ark_screen"}], ["", "shelf", 1.2, 0.5, {"mass": 0.05, "value": 600.0, "name_key": "p_ark_shelf"}]], [[27.0, 29.0]])
	_lamp("LAMP-H", 31.5, -IN, "H")
	_row("H", IN, -1.0, 24.6, 35.6, [["GAL-H", "module", 2.0, 1.2, {"mass": 0.5, "value": 8000.0, "name_key": "p_ark_galley"}], ["", "fridge", 0.9, 1.8, {"mass": 0.25, "value": 3500.0, "name_key": "p_ark_fridge"}],
		["", "table", 1.4, 0.8, {"mass": 0.08, "value": 700.0, "name_key": "p_ark_table"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["ENV-H", "env", 1.6, 1.8, {"mass": 0.5, "value": 12000.0, "name_key": "p_env_control"}], ["MED-H", "op_table", 1.8, 0.9, {"mass": 0.25, "value": 14000.0, "name_key": "p_ark_medbed"}],
		["", "medcab", 0.9, 1.6, {"mass": 0.1, "value": 6000.0, "name_key": "p_ark_medcab"}]])
	_row("H", 0.25, 1.0, 24.6, 33.0, [["", "o2cab", 0.8, 0.9, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}], ["", "cabinet", 1.0, 0.6, {"mass": 0.05, "value": 1200.0, "name_key": "p_svc_cabinet"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["", "screen", 1.0, 0.6, {"mass": 0.03, "value": 2000.0, "name_key": "p_ark_screen"}]])
	_lamp("LAMP-H2", 28.0, 0.25, "H")


# ---------------------------------------------------------------- E, the power room

static func _power() -> void:
	_row("E", 0.0, -1.0, 38.9, 51.2, [["BAT-E", "battery", 2.0, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}], ["SWB-E", "swb", 1.2, 2.6, {"mass": 0.4, "value": 6500.0, "name_key": "p_swb"}],
		["FC-E", "gen", 2.0, 1.8, {"mass": 1.2, "value": 22000.0, "name_key": "p_fuel_cell"}], ["ACC", "gastank", 0.9, 2.0, {"mass": 0.3, "value": 3000.0, "name_key": "p_expansion_tank"}],
		["", "panel", 0.8, 1.0, {"mass": 0.05, "value": 1500.0, "name_key": "p_ark_panel"}], ["", "cabinet", 1.0, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_svc_cabinet"}]])
	_row("E", -IN, 1.0, 36.6, 51.0, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["DCDC-1", "cabinet", 1.2, 0.9, {"mass": 0.12, "value": 7000.0, "name_key": "p_ev_dcdc"}],
		["DCDC-2", "cabinet", 1.2, 0.9, {"mass": 0.12, "value": 7000.0, "name_key": "p_ev_dcdc"}], ["PCU", "panel", 1.0, 1.2, {"mass": 0.08, "value": 9000.0, "name_key": "p_ev_pcu"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["SHUNT", "aux", 0.8, 0.8, {"mass": 0.06, "value": 4000.0, "name_key": "p_ev_shunt"}]])
	_lamp("LAMP-E", 44.0, -IN, "E")
	_row("E", IN, -1.0, 36.6, 51.2, [["PT-E", "fueltank", 2.4, 2.4, {"mass": 1.0, "value": 6000.0, "name_key": "p_svc_prop"}], ["RCP", "pump", 1.4, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_coolant_pump"}],
		["", "filter", 1.0, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}], ["H2O", "water", 1.6, 2.0, {"mass": 0.6, "value": 3000.0, "name_key": "p_ark_water_tank"}],
		["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]], [[39.6, 43.4]])
	_lamp("LAMP-E2", 45.0, 0.25, "E")


# ---------------------------------------------------------------- outside

static func _outside() -> void:
	# the radiator wings off the power room's roof and floor
	for side in [-1.0, 1.0]:
		var nm := "U" if side < 0.0 else "L"
		var y0: float = side * 4.5
		var prev = null
		for i in 2:
			var ya: float = side * (4.5 + 3.4 * i)
			var yb: float = side * (4.5 + 3.4 * (i + 1))
			var rp = K.plate("RAD-%s%d" % [nm, i + 1], K.R(38.5, minf(ya, yb), 48.5, maxf(ya, yb)), {"density": 0.5, "barrier": false, "cut_speed": 230.0, "art": "radiator", "name_key": "p_radiator_fin"}, "hull")
			if prev == null:
				for x in [44.5, 47.5]:
					K.bolt(rp, K.at(x, y0 - side * 0.25, ["hull"]), x, y0, "weld")
			else:
				K.bolt(rp, prev, 43.5, ya, "weld")
			prev = rp
	var nz = E("NOZ", "nozzle", 52.05, -2.4, 55.4, 2.4, "", {"mass": 1.4, "value": 22000.0, "name_key": "p_thrust_chamber"})
	K.bolt(nz, K.at(51.75, -1.6, ["hull"]), 52.0, -1.6)
	K.bolt(nz, K.at(51.75, 1.6, ["hull"]), 52.0, 1.6)
	for r in [["RCS-1", 30.0, -5.5, -4.5, -4.25], ["RCS-2", 30.0, 4.5, 5.5, 4.25]]:
		var rc = E(r[0], "rcs_quad", r[1], r[2], r[1] + 1.2, r[3], "", {"mass": 0.1, "value": 5000.0, "name_key": "p_rcs"})
		K.bolt(rc, K.at(r[1] + 0.3, r[4], ["hull"]), r[1] + 0.3, -4.5 if r[2] < 0 else 4.5)
		K.bolt(rc, K.at(r[1] + 0.9, r[4], ["hull"]), r[1] + 0.9, -4.5 if r[2] < 0 else 4.5)
	var mb = K.plate("MAG-BOOM", K.R(20.0, -10.0, 20.3, -4.5), {"density": 1.0, "barrier": false, "cut_speed": 200.0, "name_key": "p_ev_boom"}, "strut")
	K.bolt(mb, K.at(20.15, -4.25, ["hull"]), 20.15, -4.5, "weld")
	var ms = E("MAG-S", "radar", 19.4, -11.0, 20.9, -10.05, "", {"mass": 0.06, "value": 16000.0, "fragile": 0.2, "name_key": "p_ev_mag_sensor"})
	K.bolt(ms, mb, 20.15, -10.0)


# ---------------------------------------------------------------- lines and controls

static func _cen(t: String) -> Vector2:
	return Geom.centroid(by_tag[t].poly) / Geom.M


static func _c(id: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "cable", "power", a, _cen(a), b, _cen(b), via)


static func _p(id: String, net: String, a: String, b: String, via: Array = []) -> void:
	K.line(id, "pipe", net, a, _cen(a), b, _cen(b), via)


static func _lines() -> void:
	_c("p1", "BAT-E", "SWB-E")
	_c("p2", "SWB-E", "ICP", [Vector2(37.0, 3.0), Vector2(17.0, 3.0)])
	_c("p3", "ICP", "CORO")
	_c("p4", "ICP", "SPEC-1")
	_c("p5", "ICP", "DREC")
	_c("p6", "SWB-E", "ENV-H", [Vector2(37.0, 2.8), Vector2(31.0, 2.8)])
	_c("p7", "SWB-E", "LAMP-E")
	_c("p8", "SWB-E", "LAMP-H", [Vector2(37.0, -3.0), Vector2(29.0, -3.0)])
	_c("p9", "SWB-E", "LAMP-I", [Vector2(37.0, -3.2), Vector2(18.0, -3.2)])
	_c("p10", "SWB-E", "RCP")
	_c("p11", "FC-E", "SWB-E")
	_c("p12", "ICP", "THCAM")
	_c("p13", "ICP", "TS-1", [Vector2(12.6, -2.0), Vector2(9.0, -6.0)])
	_c("p14", "ICP", "MAG-S", [Vector2(20.1, -4.0)])
	_c("p15", "SWB-E", "LAMP-E2")
	_c("p16", "SWB-E", "LAMP-I2", [Vector2(37.0, 0.6), Vector2(17.0, 0.6)])
	# the coolant loop: through the instrument module and the shield's back plate, out to the radiators
	_p("c1", "cool", "RCP", "ICOOL", [Vector2(37.0, 3.6), Vector2(21.0, 3.6)])
	_p("c2", "cool", "ICOOL", "SHB", [Vector2(12.6, 3.4), Vector2(8.3, 3.4)])
	_p("c3", "cool", "RCP", "RAD-L1", [Vector2(41.0, 4.6)])
	_p("c4", "cool", "RCP", "RAD-U1", [Vector2(43.0, -3.8)])
	_p("c5", "cool", "RCP", "ACC")
	_p("f1", "prop", "PT-E", "FC-E")


static func _controls() -> void:
	var sw = by_tag["SWB-E"]
	K.ctrl("K-M", "switch", sw, _cen("SWB-E") + Vector2(-0.3, -0.7), {"target": "K-M", "state": true, "hidden_room": "E"})
	K.ctrl("E-1", "test", sw, _cen("SWB-E") + Vector2(0.3, -0.7), {"medium": "volt", "target": "bus", "hidden_room": "E"})
	K.ctrl("G-I", "port", K.at(12.25, -1.5, ["hull"]), Vector2(11.9, -1.5), {"medium": "gas", "target": "I"})
	K.ctrl("G-H", "port", K.at(30.0, 4.3, ["hull"]), Vector2(30.0, 4.7), {"medium": "gas", "target": "H"})
	K.ctrl("G-E", "port", K.at(51.75, -2.0, ["hull"]), Vector2(52.0, -2.6), {"medium": "gas", "target": "E"})
	K.ctrl("PC", "port", by_tag["ACC"], _cen("ACC") + Vector2(0, -1.1), {"medium": "coolant", "target": "cool", "hidden_room": "E"})
	K.ctrl("PF", "port", by_tag["PT-E"], _cen("PT-E") + Vector2(0, -1.3), {"medium": "fuel", "target": "prop", "hidden_room": "E"})
	K.ctrl("PW", "port", by_tag["H2O"], _cen("H2O") + Vector2(0, -1.1), {"medium": "water", "target": "h2o", "hidden_room": "E"})
	# the berth's cooling into the ship's loop, and the thermometers
	K.ctrl("COOL-S", "socket", K.at(33.0, 4.3, ["hull"]), Vector2(33.0, 4.7), {"target": "cold", "state": false})
	K.ctrl("T-TILE", "probe", by_tag["TS-1"], _cen("TS-1") + Vector2(0.4, 0), {"medium": "zone", "target": "TILES", "hidden_room": "I"})
	K.ctrl("T-FRAME", "probe", by_tag["TS-2"], _cen("TS-2") + Vector2(0.4, 0), {"medium": "zone", "target": "FRAME", "hidden_room": "I"})
	K.ctrl("T-I", "probe", by_tag["THCAM"], _cen("THCAM") + Vector2(0, 0.45), {"medium": "zone", "target": "I", "hidden_room": "I"})
	K.ctrl("AUX-P", "socket", K.at(36.6, 4.3, ["hull"]), Vector2(36.6, 4.7), {"target": "aux", "state": false})
	for t in ["HT-H", "HT-E"]:
		K.door(t, "")
	K.door("D-0", "H")
	K.door("D-1", "H")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := {"I": [0.0, BH[0] - 0.25], "H": [BH[0] + 0.25, BH[1] - 0.25], "E": [BH[1] + 0.25, 60.0]}
	for n in cuts:
		var parts := Geometry2D.intersect_polygons(inn, K.R(cuts[n][0], -6.0, cuts[n][1], 6.0))
		if not parts.is_empty():
			w.add_room(n, parts[0])


static func meta() -> Dictionary:
	return {
		"id": "ev55",
		"name": "EV-55 FIRE-EYE",
		"title": ["EV-55「火眼」恒星观测船 · 55 m", "EV-55 FIRE-EYE · SOLAR OBSERVATORY · 55 m"],
		"contract": "EV-55",
		"length": 55.4,
		"value": {"total": 581600.0, "metal": 12000.0},
		"clamps": [[20.0, 4.5], [44.0, 4.5]],
		"room_names": {"I": "room_evI", "H": "room_evH", "E": "room_evE"},
		"gas": {"rooms": {"I": 101.0, "H": 101.0, "E": 101.0}, "vessels": {}, "valves": [], "value": 5000.0},
		"thermal": {"zones": {
				"TILES": {"T0": 820.0, "rect": [-0.5, -9.6, 8.0, 9.6], "k": 0.0022},
				"FRAME": {"T0": 520.0, "rect": [8.0, -9.6, 12.4, 9.6], "k": 0.0025},
				"I": {"T0": 190.0, "rect": [12.4, -4.6, 24.0, 4.6], "k": 0.003},
				"H": {"T0": 55.0, "rect": [24.0, -4.6, 36.0, 4.6], "k": 0.004}},
			"order": ["TILES", "FRAME", "I", "H"], "ambient": 20.0, "loop": "COOL-S", "loop_k": 4.0, "loop_zones": ["TILES", "FRAME", "I", "H"],
			"tiles": ["TILE-"], "shatter_T": 300.0, "spoil_T": 150.0, "burn_T": 400.0, "burn": 6.0},
		"power": {
			"bus": "SWB-E",
			"sources": [
				{"piece": "BAT-E", "kind": "battery", "volts": 220.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M", "charge": 0.85, "drain": 0.0003},
			],
			"lamps": {"I": "LAMP-I", "H": "LAMP-H", "E": "LAMP-E"},
		},
		"fluids": {"volumes": {
			"cool": {"fluid": "coolant", "amount": 0.3, "nets": ["cool"], "piece": "ACC", "port": "PC", "full": 0.4, "leak": 0.15, "leak_min": 0.004, "pump": [0.12, 0.006]},
			"prop": {"fluid": "fuel", "amount": 0.5, "nets": ["prop"], "piece": "PT-E", "port": "PF", "full": 0.8, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
			"h2o": {"fluid": "water", "amount": 0.4, "piece": "H2O", "port": "PW", "full": 0.6, "content": 1.0, "leak": 0.08, "pump": [0.1, 0.006]},
		}, "joins": [], "value": {"coolant": 3000.0, "fuel": 6000.0, "water": 400.0}},
		"ctrls_cfg": {"G-I": {"rate": 22.0}, "G-H": {"rate": 22.0}, "G-E": {"rate": 26.0}},
		"labels": {"CORO": "CORONAGRAPH", "SPEC-1": "SPEC", "SPEC-2": "SPEC", "ICP": "INST CPU", "DREC": "REC", "BAT-E": "BAT", "SWB-E": "BUS", "FC-E": "FUEL CELL", "SHB": "SHIELD"},
		"hints": {},
		"market": {
			"class": "EV", "name": ["火眼级恒星观测船", "FIRE-EYE-CLASS SOLAR OBSERVATORY"], "time": 30.0,
			"rooms": {"I": [0.2, 40.0, 101.0], "H": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0]},
			"charge": {"BAT-E": [0.4, 1.0]},
			"fluids": {"prop": [0.1, 0.7]},
			"knockable": ["THCAM", "MAGN"],
			"drift": [],
			"section_x": 24.0,
			"slots": {"fire_system": {"x": 49.4, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "E", "port": [49.8, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"DREC": [
				{"do": "operate", "ctrl": "COOL-S"},
				{"do": "hose", "ctrl": "G-H"},
				{"do": "hose", "ctrl": "G-I"},
				{"do": "wait", "until": {"P": ["H", "<", 5.0]}, "max": 200.0},
				{"do": "wait", "until": {"P": ["I", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-H"},
				{"do": "wait", "until": {"open": ["H"]}, "max": 20.0},
				{"do": "hose", "ctrl": "G-E"},
				{"do": "wait", "until": {"P": ["E", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "D-1"},
				{"do": "wait", "until": {"open": ["E"]}, "max": 20.0},
				{"do": "operate", "ctrl": "D-0"},
				{"do": "wait", "until": {"open": ["I"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "wait", "until": {"zone": ["I", "<", 140.0]}, "max": 300.0},
				{"do": "free", "piece": "DREC"},
				{"do": "deliver", "piece": "DREC", "zone": "equip"},
			],
		},
	}


const FIRE_BASE := "HE5-0"
