class_name Hg170Author
# Authoring script for HG-170 "Gas Sea", a 170 m gas-giant harvester (new designs 10/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/hg170.json. Metres, x bow (0) to the stern (170), y down.
#
# The intake scoop flares out over the bow (its vanes, the first compressor stage on the
# throat, the flow sensors); behind it the forward hull, B (the bridge, the assay lab,
# the crew's quarters). Then the open tank bay: four cryogenic spheres slung between a
# top and a bottom truss, each with its relief valve on top (and a pressure gauge and a
# temperature probe on that), its drain port underneath, a refrigeration line from aft.
# Tank 2's insulation is torn; tank 3's relief valve is frozen shut, with a heater to
# thaw it. Aft, C the cryoplant (two cryocoolers, the helium compressors, the heat
# exchanger, the cryo console) and P the power (batteries, the bus, the generators,
# the engine).
# What it asks of you (scripts/boiloff.gd): keep the cryocoolers running and draw the
# cargo off, thaw tank 3's valve, and cut the power last.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT_F := [Vector2(30, -5), Vector2(32, -7), Vector2(64, -7), Vector2(64, 7), Vector2(32, 7), Vector2(30, 5)]
const OUT_A := [Vector2(130, -7), Vector2(168, -7), Vector2(170, -5), Vector2(170, 5), Vector2(168, 7), Vector2(130, 7)]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 6.5
const DOOR := 3.0
const BHX := 150.0
const CX := [73.0, 89.0, 105.0, 121.0]
const R := 6.0
const TP := ["TA", "TB", "TC", "TD"]

static var w
static var by_tag := {}
static var n_auto := 0


static func build(world) -> void:
	K.begin(world, "HG170")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	_hulls()
	_scoop()
	_trusses()
	_tanks()
	_bridge()
	_cryo()
	_power()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 40.0, 7.0, 6.8)
	K.clamp(2, 140.0, 7.0, 6.8)


static func rooms_only(world) -> void:
	K.begin(world, "HG170")
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
			push_warning("HG170 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
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


# ---------------------------------------------------------------- the two hulls

static func _hulls() -> void:
	var H := {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}
	# forward: edges 0 bow upper, 1 roof, 2 aft wall (onto the tank bay), 3 keel, 4 bow lower, 5 bow
	K.ring(OUT_F, T, {1: [0.2, 0.4, 0.6, 0.8], 2: [0.25, 0.5, 0.75], 3: [0.2, 0.4, 0.5, 0.56, 0.8], 5: [0.5]}, {
		"3:3": {"kind": "hatch", "door": true, "tag": "HT-B", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
	}, H, "HF")
	# aft: edges 0 roof, 1 stern upper, 2 stern, 3 stern lower, 4 keel, 5 forward wall (onto the tank bay)
	K.ring(OUT_A, T, {0: [0.2, 0.4, 0.6, 0.8], 2: [0.35, 0.65], 4: [0.2, 0.4, 0.6, 0.8], 5: [0.25, 0.5, 0.75]}, {
		"2:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(0, 2.2) * Geom.M, "cut_speed": 200.0},
	}, H, "HA")
	var B := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	var u = K.plate("BH0-U", K.R(BHX - 0.25, -IN, BHX + 0.25, DOOR), B, "hull")
	var d = K.plate("D-0", K.R(BHX - 0.25, DOOR, BHX + 0.25, IN), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -3.2) * Geom.M}, "door")
	K.bolt(u, K.at(BHX, -IN - 0.25, ["hull"]), BHX, -IN, "weld")
	K.bolt(u, d, BHX, DOOR, "weld")
	K.bolt(d, K.at(BHX, IN + 0.25, ["hull"]), BHX, IN, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	for r in [[30.5, 63.5, "B"], [130.5, 149.75, "C"], [150.25, 169.5, "P"]]:
		var a: float = r[0]
		var b: float = r[1] - 2.6
		var dk = K.plate("DK-" + r[2], K.R(a, 0.0, b, 0.25), D, "deck")
		K.bolt(dk, K.at(a - 0.15, 0.12, ["hull"]), a, 0.12, "weld")


# ---------------------------------------------------------------- the intake scoop

static func _scoop() -> void:
	var S := {"density": 1.2, "barrier": false, "cut_speed": 190.0, "name_key": "p_hg_scoop"}
	# the upper lip from the mouth (2, -17) down to the forward roof, three plates
	var a := Vector2(2.0, -17.0)
	var b := Vector2(32.0, -7.5)
	var nrm: Vector2 = (b - a).normalized().orthogonal() * -0.5
	var prev = null
	for k in 3:
		var p0: Vector2 = a.lerp(b, k / 3.0)
		var p1: Vector2 = a.lerp(b, (k + 1) / 3.0)
		var pl = K.plate("SC-U%d" % (k + 1), K.mp([p0, p1, p1 + nrm, p0 + nrm]), S, "beam")
		if prev != null:
			K.bolt(pl, prev, p0.x, p0.y + nrm.y * 0.5, "weld")
		prev = pl
	K.bolt(prev, K.at(32.3, -6.8, ["hull"]), 32.0, -7.05, "weld")
	var lo = null
	for k in 3:
		var x0: float = 2.0 + k * 10.0
		var pl = K.plate("SC-L%d" % (k + 1), K.R(x0, 7.0, x0 + 10.0, 7.5), S, "beam")
		if lo != null:
			K.bolt(pl, lo, x0, 7.25, "weld")
		lo = pl
	K.bolt(lo, K.at(32.5, 6.75, ["hull"]), 32.0, 7.0, "weld")
	# the lips, the guide vanes across the mouth, struts from the vanes to the lips
	var V := {"density": 0.8, "barrier": false, "cut_speed": 220.0, "name_key": "p_hg_vane"}
	var lp = K.plate("SC-LIP", K.R(1.6, -17.6, 2.4, -15.8), V, "fixture")
	K.bolt(lp, by_tag["SC-U1"], 2.2, -16.8, "weld")
	var lp2 = K.plate("SC-LIP2", K.R(1.6, 6.4, 2.4, 7.5), V, "fixture")
	K.bolt(lp2, by_tag["SC-L1"], 2.2, 7.1, "weld")
	for i in 3:
		var vx: float = 9.0 + i * 7.0
		var ytop: float = a.lerp(b, (vx - a.x) / (b.x - a.x)).y + 0.5
		var vn = K.plate("VANE-%d" % (i + 1), K.R(vx, ytop, vx + 0.3, 7.0), V, "fixture")
		K.bolt(vn, by_tag["SC-U%d" % mini(3, int((vx - 2.0) / 10.0) + 1)], vx + 0.15, ytop, "weld")
		K.bolt(vn, by_tag["SC-L%d" % mini(3, int((vx - 2.0) / 10.0) + 1)], vx + 0.15, 7.0, "weld")
	# the first compressor stage on the throat, the flow sensors, a camera, the ionisation grid
	var ic = E("INT-C", "module", 27.4, -2.2, 29.95, 2.2, "", {"mass": 2.8, "value": 48000.0, "fragile": 0.4, "name_key": "p_hg_intake_comp"})
	K.bolt(ic, K.at(30.25, -1.5, ["hull"]), 29.95, -1.5)
	K.bolt(ic, K.at(30.25, 1.5, ["hull"]), 29.95, 1.5)
	for i in 2:
		var sx: float = 12.0 + i * 10.0
		var sy: float = a.lerp(b, (sx - a.x) / (b.x - a.x)).y + 0.5
		var fs = E("FS-%d" % (i + 1), "sensor", sx, sy, sx + 0.6, sy + 0.5, "", {"mass": 0.03, "value": 6200.0, "fragile": 0.5, "name_key": "p_hg_flow_sensor"})
		K.bolt(fs, by_tag["SC-U%d" % (i + 2)], sx + 0.3, sy)
	var cam = E("SC-CAM", "insp", 24.0, 5.95, 25.0, 6.95, "", {"mass": 0.06, "value": 5400.0, "fragile": 0.5, "name_key": "p_hg_scoop_camera"})
	K.bolt(cam, by_tag["SC-L3"], 24.5, 7.0)
	var ion = E("ION", "aux", 27.4, 3.0, 29.95, 4.4, "", {"mass": 0.4, "value": 16000.0, "fragile": 0.5, "name_key": "p_hg_ioniser"})
	K.bolt(ion, K.at(30.25, 3.7, ["hull"]), 29.95, 3.7)


# ---------------------------------------------------------------- the tank bay

static func _trusses() -> void:
	var B := {"density": 1.6, "barrier": false, "cut_speed": 170.0, "name_key": "p_hg_truss"}
	for side in ["T", "B"]:
		var y0: float = -7.0 if side == "T" else 6.4
		var prev = null
		for k in 6:
			var x0: float = 64.0 + k * 11.0
			var tr = K.plate("TR-%s%d" % [side, k + 1], K.R(x0, y0, x0 + 11.0, y0 + 0.6), B, "beam")
			if prev == null:
				K.bolt(tr, K.at(63.8, y0 + 0.3, ["hull"]), 64.0, y0 + 0.3, "weld")
			else:
				K.bolt(tr, prev, x0, y0 + 0.3, "weld")
			prev = tr
		K.bolt(prev, K.at(130.2, y0 + 0.3, ["hull"]), 130.0, y0 + 0.3, "weld")
	# diagonal bracing between the tanks, top truss to bottom
	for k in 3:
		var mx: float = (CX[k] + CX[k + 1]) * 0.5
		var br = K.plate("", K.mp([Vector2(mx - 0.25, -6.4), Vector2(mx + 0.25, -6.4), Vector2(mx + 0.25, 6.4), Vector2(mx - 0.25, 6.4)]), B, "strut")
		K.bolt(br, K.at(mx, -6.7, ["beam"]), mx, -6.4, "weld")
		K.bolt(br, K.at(mx, 6.7, ["beam"]), mx, 6.4, "weld")


static func _octagon(cx: float) -> Array:
	var pts: Array = []
	for i in 8:
		var a: float = deg_to_rad(-157.5 + i * 45.0)
		pts.append(Vector2(cx + R * cos(a), R * sin(a)))
	return pts


static func _tanks() -> void:
	var SH := {"density": 1.1, "barrier": true, "cut_speed": 180.0, "name_key": "p_hg_tank_shell"}
	var SP := {"density": 1.6, "barrier": false, "cut_speed": 170.0, "name_key": "p_hg_tank_support"}
	var top_y: float = -R * sin(deg_to_rad(67.5))
	for k in 4:
		var cx: float = CX[k]
		var p: String = TP[k]
		K.ring(_octagon(cx), 0.4, {}, {}, SH, p)
		var ts = K.plate("SUP-%dT" % (k + 1), K.R(cx - 0.3, -6.4, cx + 0.3, top_y), SP, "strut")
		K.bolt(ts, K.at(cx, -6.7, ["beam"]), cx, -6.4, "weld")
		K.bolt(ts, by_tag[p + "1-0"], cx, top_y, "weld")
		var bs = K.plate("SUP-%dB" % (k + 1), K.R(cx - 0.3, -top_y, cx + 0.3, 6.4), SP, "strut")
		K.bolt(bs, K.at(cx, 6.7, ["beam"]), cx, 6.4, "weld")
		K.bolt(bs, by_tag[p + "5-0"], cx, -top_y, "weld")
		# its relief valve on top, between the shell and the truss
		var rv = E("RV-%d" % (k + 1), "aux", cx + 1.0, top_y - 0.8, cx + 1.8, top_y - 0.03, "", {"mass": 0.06, "value": 5600.0, "fragile": 0.5, "name_key": "p_hg_relief"})
		K.bolt(rv, by_tag[p + "1-0"], cx + 1.4, top_y)
		# the insulation jackets either side
		for sx in [-1.0, 1.0]:
			var ex: float = cx + sx * (R * cos(deg_to_rad(22.5)) + 0.28)
			var ins = E("", "insul", ex - 0.25, -1.8, ex + 0.25, 1.8, "", {"mass": 0.05, "value": 1400.0, "name_key": "p_hg_tank_mli"})
			K.bolt(ins, by_tag[p + ("3-0" if sx > 0.0 else "7-0")], ex - sx * 0.25, 0.0)
		# the level gauge and the instrument box under it
		var lg = E("LG-%d" % (k + 1), "panel", cx - 2.2, -top_y + 0.03, cx - 1.6, -top_y + 0.8, "", {"mass": 0.03, "value": 2800.0, "name_key": "p_hg_level_gauge"})
		K.bolt(lg, by_tag[p + "5-0"], cx - 1.9, -top_y)


# ---------------------------------------------------------------- B, forward

static func _bridge() -> void:
	_row("B", 0.0, -1.0, 32.5, 60.8, [["HELM", "console", 1.6, 1.2, {"mass": 0.25, "value": 16000.0, "fragile": 0.5, "name_key": "p_lc_helm"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["NAV", "nav", 1.2, 1.2, {"mass": 0.12, "value": 12000.0, "fragile": 0.5, "name_key": "p_lc_nav"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["HARV", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_hg_harvest_console"}], ["COMMS", "nav_rack", 0.9, 2.2, {"mass": 0.3, "value": 14000.0, "name_key": "p_lc_comms"}],
		["", "table", 1.6, 0.9, {"mass": 0.08, "value": 1600.0, "name_key": "p_ark_nav_table"}], ["GC", "insp", 1.4, 1.6, {"mass": 0.3, "value": 26000.0, "fragile": 0.5, "name_key": "p_hg_chromatograph"}],
		["", "module", 1.6, 1.4, {"mass": 0.4, "value": 18000.0, "fragile": 0.5, "name_key": "p_hg_mass_spec"}], ["", "env", 1.2, 2.0, {"mass": 0.3, "value": 6800.0, "name_key": "p_dr_fume_hood"}],
		["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 2800.0, "name_key": "p_hg_sample_cyl"}], ["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		# the aft end of B: the first of the gas processing, off the intake
		["", "module", 1.8, 2.4, {"mass": 1.2, "value": 22000.0, "name_key": "p_hg_separator"}], ["", "module", 1.6, 2.0, {"mass": 0.9, "value": 26000.0, "name_key": "p_hg_ortho_para"}],
		["", "filter", 0.9, 1.8, {"mass": 0.2, "value": 5400.0, "name_key": "p_hg_filter_bank"}]])
	_row("B", -IN, 1.0, 33.5, 63.0, [["", "screen", 2.4, 1.0, {"mass": 0.08, "value": 4800.0, "name_key": "p_hg_atmos_display"}], 1.0, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}],
		1.0, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}], 1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2400.0, "name_key": "p_dr_gas_detector"}]])
	_lamp("LAMP-B", 48.0, -IN, "B")
	_row("B", IN, -1.0, 32.5, 63.5, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["GAL-B", "module", 1.8, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_ark_galley"}], ["", "table", 1.4, 0.9, {"mass": 0.06, "value": 700.0, "name_key": "p_ark_table"}],
		["ASSAY", "biobox", 1.2, 1.0, {"mass": 0.3, "value": 45000.0, "fragile": 0.5, "mandatory": true, "name_key": "p_hg_assay_case"}],
		["ENV-B", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "medcab", 0.8, 1.2, {"mass": 0.08, "value": 3000.0, "name_key": "p_ark_medcab"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["", "fridge", 0.9, 1.9, {"mass": 0.15, "value": 1800.0, "name_key": "p_bl_fridge"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}],
		["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}],
		["", "pump", 1.6, 1.6, {"mass": 0.9, "value": 16000.0, "name_key": "p_hg_sample_comp"}], ["", "module", 1.8, 2.2, {"mass": 1.1, "value": 19000.0, "name_key": "p_hg_precooler"}],
		["", "pump", 1.2, 1.2, {"mass": 0.4, "value": 5400.0, "name_key": "p_hg_transfer_pump"}], ["", "panel", 0.8, 1.4, {"mass": 0.05, "value": 4200.0, "name_key": "p_hg_process_panel"}]], [[45.9, 48.2]])
	_row("B", 0.25, 1.0, 32.5, 60.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], ["", "screen", 1.0, 0.7, {"mass": 0.03, "value": 1400.0, "name_key": "p_ark_screen"}]])
	_lamp("LAMP-B2", 40.0, 0.25, "B")


# ---------------------------------------------------------------- C and P, aft

static func _cryo() -> void:
	_row("C", 0.0, -1.0, 131.0, 146.8, [["CRY-1", "module", 2.2, 2.6, {"mass": 2.4, "value": 40000.0, "fragile": 0.4, "name_key": "p_hg_cryocooler"}],
		["CRY-2", "module", 2.2, 2.6, {"mass": 2.4, "value": 40000.0, "fragile": 0.4, "name_key": "p_hg_cryocooler"}],
		["CCON", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_hg_cryo_console"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["CDM", "panel", 1.0, 2.0, {"mass": 0.3, "value": 9600.0, "name_key": "p_hg_cryo_manifold"}], ["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 4200.0, "name_key": "p_fx_cryo_spares"}],
		["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}],
		# the twin turboexpander skid that does the liquefier's real cooling (2026-10-20:
		# a hydrogen liquefier without its expansion turbines was missing its heart)
		["TX", "turboexpander", 2.4, 1.6, {"mass": 1.3, "value": 36000.0, "fragile": 0.5, "name_key": "p_hg_turboexpander"}]])
	_row("C", -IN, 1.0, 131.0, 149.5, [["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_fx_he_line"}], 1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		1.0, ["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_fx_he_line"}], 1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_fx_o2_monitor"}]])
	_lamp("LAMP-C", 140.0, -IN, "C")
	_row("C", IN, -1.0, 131.0, 149.5, [["HEC-1", "pump", 1.5, 1.4, {"mass": 0.9, "value": 18000.0, "name_key": "p_fx_he_compressor"}], ["HEC-2", "pump", 1.5, 1.4, {"mass": 0.9, "value": 18000.0, "name_key": "p_fx_he_compressor"}],
		["", "module", 1.8, 2.0, {"mass": 1.2, "value": 16000.0, "name_key": "p_heat_exchanger"}], ["", "filter", 0.9, 1.6, {"mass": 0.15, "value": 6000.0, "name_key": "p_fx_he_purifier"}],
		["", "gastank", 0.6, 1.6, {"mass": 0.1, "value": 3000.0, "hazard": "gas_tank", "name_key": "p_fx_he_buffer"}], ["", "gastank", 0.6, 1.6, {"mass": 0.1, "value": 3000.0, "hazard": "gas_tank", "name_key": "p_fx_he_buffer"}],
		["", "env", 1.4, 2.0, {"mass": 0.4, "value": 8000.0, "name_key": "p_env_control"}], ["", "pump", 1.2, 1.2, {"mass": 0.4, "value": 5400.0, "name_key": "p_hg_transfer_pump"}]])
	_row("C", 0.25, 1.0, 131.0, 146.8, [["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_fx_he_line"}], 1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-C2", 144.0, 0.25, "C")
	# the cryoplant's radiators on the aft roof
	for i in 2:
		var x0: float = 132.0 + i * 8.0
		var rp = K.plate("RAD-%d" % (i + 1), K.R(x0, -10.5, x0 + 6.5, -7.0), {"density": 0.5, "barrier": false, "cut_speed": 230.0, "art": "radiator", "name_key": "p_radiator_fin"}, "hull")
		for x in [x0 + 1.0, x0 + 5.5]:
			K.bolt(rp, K.at(x, -6.75, ["hull"]), x, -7.0, "weld")


static func _power() -> void:
	_row("P", 0.0, -1.0, 150.7, 166.8, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}], ["PDU-P", "swb", 0.9, 2.2, {"mass": 0.3, "value": 6000.0, "name_key": "p_pdu"}],
		["GEN-1", "gen", 2.0, 2.0, {"mass": 2.2, "value": 26000.0, "name_key": "p_dr_generator"}], ["", "panel", 0.8, 1.2, {"mass": 0.05, "value": 3800.0, "name_key": "p_lc_engine_panel"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_row("P", -IN, 1.0, 151.0, 167.0, [["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}], 1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		1.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 1.0, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1600.0, "name_key": "p_lc_fuel_main"}]])
	_lamp("LAMP-P", 160.0, -IN, "P")
	_row("P", IN, -1.0, 150.7, 166.0, [["ENG-1", "eng_core", 2.6, 3.0, {"mass": 2.8, "value": 62000.0, "fragile": 0.4, "name_key": "p_lc_main_engine"}],
		["FUEL-1", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}], ["FUEL-2", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}],
		["MCP-1", "pump", 1.4, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_coolant_pump"}], ["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}],
		["", "pump", 1.2, 1.2, {"mass": 0.4, "value": 6400.0, "name_key": "p_lc_fuel_pump"}]])
	_row("P", 0.25, 1.0, 150.7, 166.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], 1.0, ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}]])
	_lamp("LAMP-P2", 158.0, 0.25, "P")
	for i in 2:
		var y0: float = -4.4 if i == 0 else 1.8
		var nz = E("NOZ-%d" % (i + 1), "nozzle", 170.05, y0, 172.4, y0 + 2.6, "", {"mass": 1.1, "value": 16000.0, "name_key": "p_lc_nozzle"})
		K.bolt(nz, K.at(169.8, y0 + 0.6, ["hull"]), 170.0, y0 + 0.6)
		K.bolt(nz, K.at(169.8, y0 + 2.0, ["hull"]), 170.0, y0 + 2.0)


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
	_c("p3", "SWB-P", "PDU-P")
	_c("p4", "SWB-P", "GEN-1")
	_c("p5", "PDU-P", "ENG-1", [Vector2(_cen("PDU-P").x, 1.0), Vector2(_cen("ENG-1").x, 1.0)])
	_c("p6", "SWB-P", "MCP-1", [Vector2(_cen("SWB-P").x, 1.2), Vector2(_cen("MCP-1").x, 1.2)])
	_c("p7", "SWB-P", "LAMP-P")
	_c("p8", "PDU-P", "CRY-1", [Vector2(151.0, -0.8), Vector2(_cen("CRY-1").x, -0.8)])
	_c("p9", "CRY-1", "CRY-2")
	_c("p10", "PDU-P", "HEC-1", [Vector2(151.0, 4.4), Vector2(_cen("HEC-1").x, 4.4)])
	_c("p11", "HEC-1", "HEC-2")
	_c("p12", "PDU-P", "CCON", [Vector2(151.0, -1.0), Vector2(_cen("CCON").x, -1.0)])
	_c("p13", "CCON", "LAMP-C")
	# forward along the top truss: the bridge, the scoop, the valve heater on tank 3
	_c("p14", "PDU-P", "HELM", [Vector2(151.0, -6.0), Vector2(130.5, -6.0), Vector2(130.5, -7.4), Vector2(63.5, -7.4), Vector2(63.5, -5.8), Vector2(_cen("HELM").x, -5.8)])
	_c("p15", "HELM", "NAV")
	_c("p16", "HELM", "HARV")
	_c("p17", "HELM", "COMMS")
	_c("p18", "HELM", "LAMP-B")
	_c("p19", "HARV", "INT-C", [Vector2(_cen("HARV").x, -3.2), Vector2(31.0, -3.2)])
	_c("p20", "INT-C", "ION")
	_c("p21", "HARV", "GC")
	_c("p22", "HELM", "ENV-B", [Vector2(_cen("HELM").x, 4.4), Vector2(_cen("ENV-B").x, 4.4)])
	_c("p23", "CCON", "RV-3", [Vector2(_cen("CCON").x, -6.2), Vector2(130.3, -6.2), Vector2(130.3, -7.6), Vector2(_cen("RV-3").x, -7.6)])
	# the refrigeration out to each tank, the transfer to the compressors
	for k in 4:
		var cx: float = CX[k]
		_p("cr%d" % (k + 1), "cryo", "CDM", TP[k] + "3-0", [Vector2(_cen("CDM").x, -6.3), Vector2(130.4, -6.3), Vector2(130.4, -7.8), Vector2(cx + 4.2, -7.8), Vector2(cx + 4.2, -3.0)])
	# each tank's level gauge on its own liquid
	for k in 4:
		_p("tl%d" % (k + 1), "t%d" % (k + 1), TP[k] + "5-0", "LG-%d" % (k + 1))
	_p("h1", "he", "HEC-1", "CRY-1", [Vector2(_cen("HEC-1").x, 2.0), Vector2(_cen("CRY-1").x, 2.0)])
	_p("h2", "he", "HEC-2", "CRY-2", [Vector2(_cen("HEC-2").x, 2.2), Vector2(_cen("CRY-2").x, 2.2)])
	_p("h3", "he", "CRY-1", "CDM")
	_p("w1", "loop", "MCP-1", "ENG-1")
	_p("f1", "fuel", "FUEL-1", "ENG-1")
	_p("f2", "fuel", "FUEL-1", "FUEL-2")
	_p("f3", "fuel", "FUEL-1", "GEN-1", [Vector2(_cen("FUEL-1").x, 1.6), Vector2(_cen("GEN-1").x, 1.6)])


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "P"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "P"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "P"})
	var bottom_y: float = R * sin(deg_to_rad(67.5))
	for k in 4:
		var cx: float = CX[k]
		var rv = by_tag["RV-%d" % (k + 1)]
		K.ctrl("PG-%d" % (k + 1), "probe", rv, _cen("RV-%d" % (k + 1)) + Vector2(-0.25, 0.0), {"medium": "tank_kpa", "target": "TK%d" % (k + 1)})
		K.ctrl("TV-%d" % (k + 1), "probe", rv, _cen("RV-%d" % (k + 1)) + Vector2(0.25, 0.0), {"medium": "valve_temp", "target": "TK%d" % (k + 1)})
		K.ctrl("PT-%d" % (k + 1), "port", by_tag[TP[k] + "5-0"], Vector2(cx + 1.4, bottom_y + 0.2), {"medium": "coolant", "target": "t%d" % (k + 1)})
	K.ctrl("RVH-3", "switch", by_tag["RV-3"], _cen("RV-3") + Vector2(0.0, -0.25), {"target": "RVH-3", "state": false})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.5), {"medium": "water", "target": "loop", "hidden_room": "P"})
	K.ctrl("PF", "port", by_tag["FUEL-1"], _cen("FUEL-1") + Vector2(0, -0.8), {"medium": "fuel", "target": "fuel", "hidden_room": "P"})
	var gp := {"B": 56.0, "C": 136.0, "P": 162.0}
	for r in gp:
		K.ctrl("G-" + r, "port", K.at(gp[r], 6.8, ["hull"]), Vector2(gp[r], 7.2), {"medium": "gas", "target": r})
	K.ctrl("AUX-P", "socket", K.at(156.0, 6.8, ["hull"]), Vector2(156.0, 7.2), {"target": "aux", "state": false})
	for t in ["HT-B", "HT-P"]:
		K.door(t, "")
	K.door("D-0", "P")


static func _rooms() -> void:
	var fi := K.mp(K.inner(OUT_F, T))
	w.add_room("B", fi)
	var ai := K.mp(K.inner(OUT_A, T))
	var parts := Geometry2D.intersect_polygons(ai, K.R(120.0, -8.0, BHX - 0.25, 8.0))
	if not parts.is_empty():
		w.add_room("C", parts[0])
	parts = Geometry2D.intersect_polygons(ai, K.R(BHX + 0.25, -8.0, 175.0, 8.0))
	if not parts.is_empty():
		w.add_room("P", parts[0])


static func meta() -> Dictionary:
	var vols := {}
	var tanks := {}
	for k in 4:
		var vk := "t%d" % (k + 1)
		vols[vk] = {"fluid": "coolant", "look": "lh2", "amount": 5.0, "nets": [vk], "piece": TP[k] + "5-0", "port": "PT-%d" % (k + 1), "full": 6.0, "content": 1.0, "leak": 0.3, "pump": [0.02, 0.02]}
		tanks["TK%d" % (k + 1)] = {"vol": vk, "valve": "RV-%d" % (k + 1), "line": "cr%d" % (k + 1), "rate": 2.4 if k == 1 else 0.8, "frozen": k == 2,
			"heater": "RVH-3" if k == 2 else "", "centre": [CX[k], 0.0], "look": "lh2",
			"shell": range(8).map(func(i): return "%s%d-0" % [TP[k], i])}
	# the refrigeration's own lines hold no cargo
	vols["cryo_lines"] = {"fluid": "n2", "amount": 0.0, "nets": ["cryo"]}
	vols["he_lines"] = {"fluid": "n2", "amount": 0.0, "nets": ["he"]}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.6, "nets": ["fuel"], "piece": "FUEL-1", "port": "PF", "full": 0.9, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	var names := {"B": "room_hgB", "C": "room_hgC", "P": "room_hgP"}
	var lamps := {"B": "LAMP-B", "C": "LAMP-C", "P": "LAMP-P"}
	return {
		"id": "hg170",
		"name": "HG-170 GAS SEA",
		"title": ["HG-170「气海」气巨星采气船 · 170 m", "HG-170 GAS SEA · GAS-GIANT HARVESTER · 170 m"],
		"contract": "HG-170",
		"length": 172.4,
		"value": {"total": VALUE, "metal": 34000.0},
		"clamps": [[40.0, 7.0], [140.0, 7.0]],
		"room_names": names,
		"gas": {"rooms": {"B": 101.0, "C": 101.0, "P": 101.0}, "vessels": {}, "valves": [], "value": 8000.0},
		"boiloff": {"tanks": tanks, "plant": ["CRY-1", "CRY-2"], "P0": 420.0, "floor": 300.0, "relief": 600.0, "reseat": 560.0, "burst": 820.0,
			"cool": 0.6, "draw": 1.5, "vent": 0.004, "thaw": 20.0, "reach": 14.0, "radius": 5.1},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"coolant": 600000.0, "water": 300.0, "fuel": 6000.0}},
		"ctrls_cfg": {"G-B": {"rate": 34.0}, "G-C": {"rate": 26.0}, "G-P": {"rate": 26.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "CRY-1": "CRYO 1", "CRY-2": "CRYO 2", "CCON": "CRYO", "RV-1": "TANK 1", "RV-2": "TANK 2", "RV-3": "TANK 3", "RV-4": "TANK 4", "ASSAY": "ASSAY", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "HG", "name": ["气海级气巨星采气船", "GAS SEA-CLASS HARVESTER"], "time": 60.0,
			"rooms": {"B": [0.2, 40.0, 101.0], "C": [0.2, 40.0, 101.0], "P": [0.2, 40.0, 101.0]},
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0]},
			"fluids": {},
			"knockable": ["NAV", "HARV"],
			"drift": [],
			"section_x": 97.0,
			"slots": {"fire_system": {"x": FIRE_X, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "P", "port": [FIRE_X + 0.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"ASSAY": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 20.0},
				{"do": "free", "piece": "ASSAY"},
				{"do": "deliver", "piece": "ASSAY", "zone": "equip"},
			],
		},
	}


const VALUE := 1526200.0
const FIRE_X := 166.0
const FIRE_BASE := "HA4-0"
