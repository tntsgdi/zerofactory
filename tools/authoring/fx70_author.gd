class_name Fx70Author
# Authoring script for FX-70 "Fusion Core", a 70 m fusion experiment ship (new designs
# 06/10, design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/fx70.json. Metres, x bow (0) to the stern (70), y down.
#
# A tokamak cut through its axis amidships, in V, a cryostat held at vacuum: the two
# D-shaped sections of the vacuum vessel (their blanket modules, a divertor cassette in
# each floor), round each the four legs of the toroidal field coils (eight coil packs,
# each on its hangers, feet or pedestal), the central solenoid between them; the
# turbopump, a camera and the heating launcher at the bow end, the helium distribution
# box at the stern end with a helium line to each coil pack. Forward C the control room
# (the plasma control rack, the quench protection console with the dump switch) over
# the crew's quarters; aft R the cryoplant (the cold box, the helium dewar, the
# compressors, the dump resistor), and P the power room (batteries, the bus, the magnet
# power supply, two gyrotrons, the fuel cell).
# What it asks of you (scripts/magnets.gd): the dump closed and the cryoplant kept
# running until the coils hold nothing, then the helium recovered, then the power off;
# no coil or coil support touched while it is energised.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(0, -5), Vector2(2.5, -7), Vector2(68, -7), Vector2(70, -5), Vector2(70, 5), Vector2(68, 7), Vector2(2.5, 7), Vector2(0, 5)]
const BH := [14.0, 48.0, 58.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 6.5
const DOOR := 3.0
const ROOMS := ["C", "V", "R", "P"]

static var w
static var by_tag := {}
static var n_auto := 0
static var coils := {}


static func build(world) -> void:
	K.begin(world, "FX70")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	coils = {}
	_hull()
	_inner()
	_machine()
	_vcorners()
	_control()
	_cryo()
	_power()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 24.0, 7.0, 6.8)
	K.clamp(2, 53.0, 7.0, 6.8)


static func rooms_only(world) -> void:
	K.begin(world, "FX70")
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
			push_warning("FX70 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
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
	K.ring(OUT, T, {1: [0.06, 0.12, 0.18, 0.24, 0.3, 0.36, 0.42, 0.48, 0.54, 0.6, 0.66, 0.72, 0.78, 0.84, 0.9, 0.95], 3: [0.35, 0.65],
		5: [0.06, 0.12, 0.18, 0.24, 0.3, 0.36, 0.42, 0.48, 0.54, 0.6, 0.66, 0.72, 0.78, 0.84, 0.92, 0.947], 7: [0.5]}, {
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(0, 2.2) * Geom.M, "cut_speed": 200.0},
		"5:15": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HF")


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
	# each room's deck (V, the cryostat, has none), its well at the aft end
	for r in [[0.5, 13.75, "C"], [48.25, 57.75, "R"], [58.25, 69.5, "P"]]:
		var a: float = r[0]
		var b: float = r[1] - 2.6
		var dk = K.plate("DK-" + r[2], K.R(a, 0.0, b, 0.25), D, "deck")
		K.bolt(dk, K.at(a - 0.15, 0.12, ["hull"]), a, 0.12, "weld")


# ---------------------------------------------------------------- the machine

static func _fx(tag: String, x0: float, y0: float, x1: float, y1: float):
	return K.plate(tag, K.R(x0, y0, x1, y1), {"density": 2.2, "barrier": false, "cut_speed": 150.0, "art": "grav_support", "name_key": "p_fx_coil_support"}, "fixture")


# a coil pack and its supports: "top" hung from the roof on two hangers, "bottom" on
# two feet, "leg" (a vertical leg) on a pedestal
static func _coil(tag: String, kind: String, x0: float, x1: float, nxt: Array) -> void:
	var c
	var fix: Array = []
	match kind:
		"top":
			c = E(tag, "tf_coil", x0, -6.2, x1, -5.0, "V", {"mass": 2.8, "value": 70000.0, "fragile": 0.4, "name_key": "p_fx_tf_coil", "cut_speed": 120.0})
			for hx in [x0 + 1.0, x1 - 1.4]:
				var hg = _fx("%s-H%d" % [tag, fix.size() + 1], hx, -IN, hx + 0.4, -6.2)
				K.bolt(hg, K.at(hx + 0.2, -IN - 0.25, ["hull"]), hx + 0.2, -IN, "weld")
				K.bolt(c, hg, hx + 0.2, -6.2)
				fix.append(hg.tag)
		"bottom":
			c = E(tag, "tf_coil", x0, 5.0, x1, 6.2, "V", {"mass": 2.8, "value": 70000.0, "fragile": 0.4, "name_key": "p_fx_tf_coil", "cut_speed": 120.0})
			for hx in [x0 + 1.0, x1 - 1.4]:
				var ft = _fx("%s-F%d" % [tag, fix.size() + 1], hx, 6.2, hx + 0.4, IN)
				K.bolt(ft, K.at(hx + 0.2, IN + 0.25, ["hull"]), hx + 0.2, IN, "weld")
				K.bolt(c, ft, hx + 0.2, 6.2)
				fix.append(ft.tag)
		"leg":
			c = E(tag, "tf_coil", x0, -3.8, x1, 3.8, "V", {"mass": 2.8, "value": 70000.0, "fragile": 0.4, "name_key": "p_fx_tf_coil", "cut_speed": 120.0})
			var pd = _fx(tag + "-P", x0 + 0.3, 3.8, x1 - 0.3, IN)
			K.bolt(pd, K.at((x0 + x1) * 0.5, IN + 0.25, ["hull"]), (x0 + x1) * 0.5, IN, "weld")
			K.bolt(c, pd, x0 + 0.5, 3.8)
			K.bolt(c, pd, x1 - 0.5, 3.8)
			fix.append(pd.tag)
	coils[tag] = {"next": nxt, "fix": fix, "line": "he-" + tag}


# one D of the vacuum vessel (x0 its outer wall's outside, in its inner wall's inside),
# its blanket modules and its divertor cassette
static func _vessel(h: String, x0: float, x1: float, outer_left: bool) -> void:
	var W := {"density": 1.8, "barrier": false, "cut_speed": 160.0, "art": "vv_wall", "name_key": "p_fx_vessel"}
	var top = K.plate("VW-%s-T" % h, K.R(x0 + 0.6, -4.6, x1 - 0.6, -4.1), W, "beam")
	var bot = K.plate("VW-%s-B" % h, K.R(x0 + 0.6, 4.1, x1 - 0.6, 4.6), W, "beam")
	var wa = K.plate("VW-%s-%s" % [h, "O" if outer_left else "I"], K.R(x0, -4.6, x0 + 0.6, 4.6), W, "beam")
	var wb = K.plate("VW-%s-%s" % [h, "I" if outer_left else "O"], K.R(x1 - 0.6, -4.6, x1, 4.6), W, "beam")
	for p in [top, bot]:
		K.bolt(p, wa, x0 + 0.6, -4.35 if p == top else 4.35, "weld")
		K.bolt(p, wb, x1 - 0.6, -4.35 if p == top else 4.35, "weld")
	# the vessel stands on a strut at its inner wall, beside the coil's inner leg
	var inner_x: float = x1 if outer_left else x0
	var sx: float = inner_x + 0.05 if outer_left else inner_x - 0.5
	var vs = K.plate("VS-" + h, K.R(sx, 4.6, sx + 0.45, IN), {"density": 2.0, "barrier": false, "cut_speed": 160.0, "name_key": "p_fx_vessel_support"}, "strut")
	K.bolt(vs, K.at(sx + 0.22, IN + 0.25, ["hull"]), sx + 0.22, IN, "weld")
	K.bolt(vs, wb if outer_left else wa, inner_x, 4.5, "weld")
	# blanket modules: three under the top, two on each wall; the divertor in the floor
	var B := {"mass": 0.4, "value": 9000.0, "fragile": 0.4, "name_key": "p_fx_blanket"}
	for i in 3:
		var bx: float = x0 + 1.0 + i * 2.6
		var bk = E("BLK-%s%d" % [h, i + 1], "fw_d", bx, -4.1, bx + 2.2, -3.6, "V", B)
		K.bolt(bk, top, bx + 0.4, -4.1)
		K.bolt(bk, top, bx + 1.8, -4.1)
	var n := 4
	for side in [x0 + 0.6, x1 - 1.1]:
		for y0 in [-2.6, 0.4]:
			var bk = E("BLK-%s%d" % [h, n], "fw_r" if side < (x0 + x1) * 0.5 else "fw_l", side, y0, side + 0.5, y0 + 2.2, "V", B)
			var wall = wa if side < (x0 + x1) * 0.5 else wb
			var wx: float = side if side < (x0 + x1) * 0.5 else side + 0.5
			K.bolt(bk, wall, wx, y0 + 0.4)
			K.bolt(bk, wall, wx, y0 + 1.8)
			n += 1
	var dv = E("DIV-" + h, "divertor", x0 + 1.2, 2.6, x1 - 1.2, 4.05, "V", {"mass": 1.8, "value": 48000.0, "fragile": 0.4, "name_key": "p_fx_divertor"})
	K.bolt(dv, bot, x0 + 2.0, 4.1)
	K.bolt(dv, bot, x1 - 2.0, 4.1)


static func _machine() -> void:
	# the left D (bow) round 20.0-28.6, the right D (stern) round 35.4-44.0, the
	# central solenoid between them at 31-33
	_vessel("L", 20.0, 28.6, true)
	_vessel("R", 35.4, 44.0, false)
	_coil("TF-1", "top", 20.0, 28.6, ["TF-2", "TF-4"])
	_coil("TF-2", "leg", 18.0, 19.3, ["TF-1", "TF-3"])
	_coil("TF-3", "bottom", 20.0, 28.6, ["TF-2", "TF-4"])
	_coil("TF-4", "leg", 29.2, 30.5, ["TF-1", "TF-3", "TF-5"])
	_coil("TF-5", "leg", 33.5, 34.8, ["TF-4", "TF-6", "TF-8"])
	_coil("TF-6", "top", 35.4, 44.0, ["TF-5", "TF-7"])
	_coil("TF-7", "leg", 44.7, 46.0, ["TF-6", "TF-8"])
	_coil("TF-8", "bottom", 35.4, 44.0, ["TF-5", "TF-7"])
	# the outer poloidal field coils in the two top corners, each hung on its support
	for pf in [["PF-1", 18.0, 19.8], ["PF-2", 44.2, 46.0]]:
		var hs = _fx(pf[0] + "-H", float(pf[1]) + 0.6, -IN, float(pf[1]) + 1.2, -6.2)
		K.bolt(hs, K.at(float(pf[1]) + 0.9, -IN - 0.25, ["hull"]), float(pf[1]) + 0.9, -IN, "weld")
		var pc = E(pf[0], "tf_coil", pf[1], -6.2, pf[2], -4.6, "V", {"mass": 1.6, "value": 45000.0, "fragile": 0.4, "name_key": "p_fx_pf_coil", "cut_speed": 120.0})
		K.bolt(pc, hs, float(pf[1]) + 0.9, -6.2)
	# the equatorial port plugs through each outer wall
	for pp in [["PP-L", 19.35, 19.95, "VW-L-O", 20.0], ["PP-R", 44.05, 44.65, "VW-R-O", 44.0]]:
		var pl = E(pp[0], "port_plug", pp[1], -1.2, pp[2], 1.2, "V", {"mass": 1.2, "value": 28000.0, "fragile": 0.4, "name_key": "p_fx_port_plug"})
		K.bolt(pl, by_tag[pp[3]], pp[4], -0.6)
		K.bolt(pl, by_tag[pp[3]], pp[4], 0.6)
	# the central solenoid, two modules stacked, hung and stood
	var ch = _fx("CS-H", 31.6, -IN, 32.4, -5.6)
	K.bolt(ch, K.at(32.0, -IN - 0.25, ["hull"]), 32.0, -IN, "weld")
	var cp = _fx("CS-P", 31.6, 5.6, 32.4, IN)
	K.bolt(cp, K.at(32.0, IN + 0.25, ["hull"]), 32.0, IN, "weld")
	var c1 = E("CS-1", "cs_stack", 31.0, -5.6, 33.0, -0.1, "V", {"mass": 2.5, "value": 60000.0, "fragile": 0.4, "name_key": "p_fx_solenoid"})
	var c2 = E("CS-2", "cs_stack", 31.0, 0.1, 33.0, 5.6, "V", {"mass": 2.5, "value": 60000.0, "fragile": 0.4, "name_key": "p_fx_solenoid"})
	K.bolt(c1, ch, 32.0, -5.6)
	K.bolt(c2, cp, 32.0, 5.6)


# the cryostat's two ends: the turbopump, a camera, the heating launcher forward; the
# helium distribution box aft
static func _vcorners() -> void:
	_row("V", IN, -1.0, 14.5, 17.8, [["VAC", "turbo", 1.4, 1.4, {"mass": 0.5, "value": 14000.0, "name_key": "p_fx_turbopump"}],
		["CAM-1", "insp", 1.0, 1.2, {"mass": 0.1, "value": 22000.0, "fragile": 0.6, "name_key": "p_fx_camera"}]])
	_row("V", -IN, 1.0, 14.5, 17.8, [["ECH", "ech", 1.8, 0.8, {"mass": 0.25, "value": 32000.0, "fragile": 0.5, "name_key": "p_fx_launcher"}],
		["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 3500.0, "name_key": "p_fx_bolometer"}]])
	_row("V", IN, -1.0, 46.2, 47.7, [["CDB", "cabinet", 1.3, 2.2, {"mass": 0.5, "value": 18000.0, "name_key": "p_fx_cdb"}]])
	_row("V", -IN, 1.0, 46.2, 47.7, [["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 3500.0, "name_key": "p_fx_bolometer"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	# the diagnostics on the bulkheads at either end, at mid height
	for it in [["MAGD", "nav_rack", 14.3, -3.4, 14.9, -1.6, 14.25, "p_fx_mag_rack", 12000.0], ["IRC", "insp", 14.3, -0.9, 15.1, 0.0, 14.25, "p_fx_ir_camera", 18000.0],
			["NEUT", "sensor", 14.3, 0.6, 14.8, 1.1, 14.25, "p_fx_neutron", 9000.0], ["GINJ", "aux", 46.9, -3.2, 47.7, -2.4, 47.75, "p_fx_gas_injector", 7000.0],
			["PELL", "pellet", 46.5, -1.8, 47.7, -0.4, 47.75, "p_fx_pellet", 21000.0], ["", "sensor", 47.2, 0.4, 47.7, 0.9, 47.75, "p_fx_bolometer", 3500.0]]:
		var dg = E(it[0], it[1], it[2], it[3], it[4], it[5], "V", {"mass": 0.1, "value": it[8], "fragile": 0.5, "name_key": it[7]})
		var wx: float = it[6]
		var my: float = (it[3] + it[5]) * 0.5
		K.bolt(dg, K.at(wx + (-0.1 if wx < 30.0 else 0.1), my, ["hull"]), wx, my - 0.15)
		K.bolt(dg, K.at(wx + (-0.1 if wx < 30.0 else 0.1), my, ["hull"]), wx, my + 0.15)
	# the neutral beam injector on the roof, its duct down to the torus
	var nb = E("NBI", "nbi", 21.0, -9.65, 31.0, -7.05, "", {"mass": 2.8, "value": 90000.0, "fragile": 0.4, "name_key": "p_fx_nbi"})
	for bx in [22.0, 30.0]:
		K.bolt(nb, K.at(bx, -6.75, ["hull"]), bx, -7.0)
	# its lamp on the aft bulkhead, over the distribution box
	var lv = E("LAMP-V", "lamp", 47.19, -5.38, 47.75, -5.22, "V", {"cls": "metal", "dest": "metal", "mass": 0.04, "cut_speed": 260.0, "name_key": "p_lamp"})
	K.bolt(lv, K.at(47.95, -5.3, ["hull"]), 47.75, -5.3)


# ---------------------------------------------------------------- C, the control room

static func _control() -> void:
	_row("C", 0.0, -1.0, 2.0, 11.0, [["PCS", "nav_rack", 1.0, 2.6, {"mass": 0.3, "value": 30000.0, "fragile": 0.5, "mandatory": true, "name_key": "p_fx_pcs"}],
		["OPS-1", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_fx_ops_console"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["QPS-C", "console", 1.4, 1.2, {"mass": 0.2, "value": 16000.0, "fragile": 0.5, "name_key": "p_fx_qps_console"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["OPS-2", "console", 1.2, 1.2, {"mass": 0.15, "value": 12000.0, "fragile": 0.5, "name_key": "p_fx_ops_console"}], ["", "cabinet", 0.9, 1.8, {"mass": 0.12, "value": 2400.0, "name_key": "p_fx_shot_archive"}]])
	_row("C", -IN, 1.0, 3.2, 13.5, [["WALL", "screen", 3.0, 1.2, {"mass": 0.12, "value": 9000.0, "fragile": 0.6, "name_key": "p_fx_plasma_wall"}], 0.6, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2600.0, "name_key": "p_fx_rad_monitor"}]])
	_lamp("LAMP-C", 9.0, -IN, "C")
	_row("C", IN, -1.0, 3.0, 13.6, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["GAL-C", "module", 1.8, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_ark_galley"}],
		["ENV-C", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], 
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]], [[5.8, 7.9]])
	_row("C", 0.25, 1.0, 2.0, 11.0, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		["", "screen", 1.0, 0.7, {"mass": 0.03, "value": 1400.0, "name_key": "p_ark_screen"}], ["", "medcab", 0.8, 1.2, {"mass": 0.08, "value": 3000.0, "name_key": "p_ark_medcab"}]])
	_lamp("LAMP-C2", 4.5, 0.25, "C")


# ---------------------------------------------------------------- R, the cryoplant

static func _cryo() -> void:
	_row("R", 0.0, -1.0, 48.7, 55.0, [["COLDBOX", "coldbox", 2.2, 2.8, {"mass": 2.2, "value": 80000.0, "fragile": 0.4, "name_key": "p_fx_coldbox"}],
		["HE-DEW", "sphere_tank", 1.8, 1.8, {"mass": 0.8, "value": 15000.0, "name_key": "p_fx_dewar"}], ["", "panel", 0.8, 1.2, {"mass": 0.05, "value": 4800.0, "name_key": "p_fx_cryo_panel"}]])
	_row("R", -IN, 1.0, 48.7, 57.5, [["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_fx_he_line"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.6, ["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_fx_he_line"}], 0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_fx_o2_monitor"}]])
	_lamp("LAMP-R", 52.0, -IN, "R")
	_row("R", IN, -1.0, 48.6, 57.6, [["HEC-1", "pump", 1.5, 1.4, {"mass": 0.9, "value": 18000.0, "name_key": "p_fx_he_compressor"}], ["HEC-2", "pump", 1.5, 1.4, {"mass": 0.9, "value": 18000.0, "name_key": "p_fx_he_compressor"}],
		["", "filter", 0.9, 1.6, {"mass": 0.15, "value": 6000.0, "name_key": "p_fx_he_purifier"}], ["QPS", "swb", 1.0, 2.4, {"mass": 0.4, "value": 16000.0, "name_key": "p_fx_qps"}],
		["DUMP-R", "dump_res", 1.6, 1.6, {"mass": 1.4, "value": 12000.0, "name_key": "p_fx_dump_res"}],
		["", "cabinet", 0.8, 1.6, {"mass": 0.12, "value": 5200.0, "name_key": "p_fx_cryo_spares"}]])
	_row("R", 0.25, 1.0, 48.7, 55.0, [["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_fx_he_line"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.6, ["", "gastank", 0.6, 1.6, {"mass": 0.1, "value": 3000.0, "hazard": "gas_tank", "name_key": "p_fx_he_buffer"}]])
	_lamp("LAMP-R2", 54.0, 0.25, "R")


# ---------------------------------------------------------------- P, the power room

static func _power() -> void:
	_row("P", 0.0, -1.0, 58.7, 66.8, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}], ["MPS", "swb", 1.2, 2.6, {"mass": 0.6, "value": 28000.0, "name_key": "p_fx_mps"}]])
	_row("P", -IN, 1.0, 58.7, 67.6, [["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.6, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.6, ["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}]])
	_lamp("LAMP-P", 66.0, -IN, "P")
	_row("P", IN, -1.0, 58.6, 69.3, [["GYR-1", "gyrotron", 1.4, 2.6, {"mass": 1.2, "value": 55000.0, "fragile": 0.5, "name_key": "p_fx_gyrotron"}], ["GYR-2", "gyrotron", 1.4, 2.6, {"mass": 1.2, "value": 55000.0, "fragile": 0.5, "name_key": "p_fx_gyrotron"}],
		["FC-P", "gen", 1.5, 1.8, {"mass": 1.2, "value": 20000.0, "name_key": "p_fuel_cell"}], ["FUEL-P", "fueltank", 1.0, 1.6, {"mass": 0.5, "value": 3000.0, "name_key": "p_svc_prop"}],
		["MCP-1", "pump", 1.4, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_coolant_pump"}],
		["", "cabinet", 1.0, 1.6, {"mass": 0.15, "value": 6400.0, "name_key": "p_fx_spare_leads"}]])
	_row("P", 0.25, 1.0, 58.7, 66.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], 0.6, ["", "toolwall", 1.2, 1.4, {"mass": 0.1, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_lamp("LAMP-P2", 64.0, 0.25, "P")


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
	_c("p3", "SWB-P", "MPS")
	_c("p4", "SWB-P", "COLDBOX", [Vector2(59.0, -0.8), Vector2(_cen("COLDBOX").x, -0.8)])
	_c("p5", "SWB-P", "HEC-1", [Vector2(59.0, 4.4), Vector2(_cen("HEC-1").x, 4.4)])
	_c("p6", "HEC-1", "HEC-2")
	_c("p7", "SWB-P", "QPS", [Vector2(59.0, 4.0), Vector2(_cen("QPS").x, 4.0)])
	_c("p8", "SWB-P", "GYR-1", [Vector2(_cen("SWB-P").x, 1.0), Vector2(_cen("GYR-1").x, 1.0)])
	_c("p9", "GYR-1", "GYR-2")
	_c("p10", "SWB-P", "FC-P", [Vector2(_cen("SWB-P").x, 1.2), Vector2(_cen("FC-P").x, 1.2)])
	_c("p11", "SWB-P", "MCP-1", [Vector2(_cen("SWB-P").x, 1.4), Vector2(_cen("MCP-1").x, 1.4)])
	_c("p12", "SWB-P", "LAMP-P")
	_c("p13", "SWB-P", "PCS", [Vector2(59.0, -5.8), Vector2(_cen("PCS").x, -5.8)])
	_c("p14", "PCS", "OPS-1")
	_c("p15", "PCS", "QPS-C")
	_c("p16", "PCS", "OPS-2")
	_c("p17", "PCS", "LAMP-C")
	_c("p18", "SWB-P", "ENV-C", [Vector2(59.0, 5.8), Vector2(_cen("ENV-C").x, 5.8)])
	_c("p19", "SWB-P", "LAMP-R", [Vector2(59.0, -5.6), Vector2(52.0, -5.6)])
	_c("p20", "SWB-P", "VAC", [Vector2(59.0, 6.0), Vector2(_cen("VAC").x, 6.0)])
	_c("p21", "VAC", "CAM-1")
	_c("p22", "GYR-1", "ECH", [Vector2(_cen("GYR-1").x, -6.0), Vector2(_cen("ECH").x, -6.0)])
	_c("p23", "QPS", "DUMP-R")
	_c("p24", "QPS-C", "QPS", [Vector2(_cen("QPS-C").x, -0.5), Vector2(_cen("QPS").x, -0.5)])
	_c("p25", "SWB-P", "LAMP-V", [Vector2(59.0, -5.4), Vector2(46.9, -5.4)])
	# the helium: compressors to the cold box, the cold box to the dewar and the
	# distribution box, the distribution box to each coil pack
	_p("h1", "he", "HEC-1", "COLDBOX", [Vector2(_cen("HEC-1").x, 2.0), Vector2(_cen("COLDBOX").x, 2.0)])
	_p("h2", "he", "HEC-2", "COLDBOX", [Vector2(_cen("HEC-2").x, 2.2), Vector2(_cen("COLDBOX").x, 2.2)])
	_p("h3", "he", "COLDBOX", "HE-DEW")
	_p("h4", "he", "COLDBOX", "CDB", [Vector2(_cen("COLDBOX").x, -6.0), Vector2(_cen("CDB").x, -6.0)])
	for c in coils:
		var cc: Vector2 = _cen(c)
		_p("he-" + c, "he", "CDB", c, [Vector2(_cen("CDB").x, -6.3 if cc.y < 0.0 else 4.85), Vector2(cc.x, -6.3 if cc.y < 0.0 else 4.85)] if absf(cc.y) > 4.0 else [Vector2(_cen("CDB").x, -4.9), Vector2(cc.x, -4.9)])
	_p("w1", "loop", "MCP-1", "FC-P")
	_p("f1", "fuel", "FC-P", "FUEL-P")


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "P"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "P"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "P"})
	var qc = by_tag["QPS-C"]
	K.ctrl("DUMP", "switch", qc, _cen("QPS-C") + Vector2(-0.4, -0.3), {"target": "DUMP", "state": false, "hidden_room": "C"})
	K.ctrl("FIELD", "probe", qc, _cen("QPS-C") + Vector2(0.0, -0.3), {"medium": "field_pct", "target": "coils", "hidden_room": "C"})
	K.ctrl("COILT", "probe", qc, _cen("QPS-C") + Vector2(0.4, -0.3), {"medium": "coil_temp", "target": "coils", "hidden_room": "C"})
	K.ctrl("PHE", "port", by_tag["HE-DEW"], _cen("HE-DEW") + Vector2(0, -0.7), {"medium": "coolant", "target": "lhe", "hidden_room": "R"})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.5), {"medium": "water", "target": "loop", "hidden_room": "P"})
	K.ctrl("PF", "port", by_tag["FUEL-P"], _cen("FUEL-P") + Vector2(0, -0.6), {"medium": "fuel", "target": "fuel", "hidden_room": "P"})
	var gp := {"C": 10.0, "R": 50.0, "P": 62.0}
	for r in gp:
		K.ctrl("G-" + r, "port", K.at(gp[r], 6.8, ["hull"]), Vector2(gp[r], 7.2), {"medium": "gas", "target": r})
	K.ctrl("AUX-P", "socket", K.at(66.0, 6.8, ["hull"]), Vector2(66.0, 7.2), {"target": "aux", "state": false})
	for t in ["HT-C", "HT-P"]:
		K.door(t, "")
	K.door("D-0", "C")
	K.door("D-1", "R")
	K.door("D-2", "P")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := [-1.0, BH[0] - 0.25, BH[0] + 0.25, BH[1] - 0.25, BH[1] + 0.25, BH[2] - 0.25, BH[2] + 0.25, 75.0]
	for i in ROOMS.size():
		var parts := Geometry2D.intersect_polygons(inn, K.R(cuts[i * 2], -8.0, cuts[i * 2 + 1], 8.0))
		if not parts.is_empty():
			w.add_room(ROOMS[i], parts[0])


static func meta() -> Dictionary:
	var vols := {}
	vols["lhe"] = {"fluid": "coolant", "look": "lhe", "amount": 0.4, "nets": ["he"], "piece": "HE-DEW", "port": "PHE", "full": 0.5, "content": 1.0, "leak": 0.1, "pump": [0.08, 0.006]}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.3, "nets": ["fuel"], "piece": "FUEL-P", "port": "PF", "full": 0.5, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	var rooms := {"C": 101.0, "V": 0.0, "R": 101.0, "P": 101.0}
	var names := {}
	for r in ROOMS:
		names[r] = "room_fx" + r
	var mrooms := {"C": [0.2, 40.0, 101.0], "R": [0.2, 40.0, 101.0], "P": [0.2, 40.0, 101.0]}
	var lamps := {"C": "LAMP-C", "V": "LAMP-V", "R": "LAMP-R", "P": "LAMP-P"}
	return {
		"id": "fx70",
		"name": "FX-70 FUSION CORE",
		"title": ["FX-70「熔核」聚变实验船 · 70 m", "FX-70 FUSION CORE · FUSION EXPERIMENT SHIP · 70 m"],
		"contract": "FX-70",
		"length": 70.0,
		"value": {"total": VALUE, "metal": 20000.0},
		"clamps": [[24.0, 7.0], [53.0, 7.0]],
		"room_names": names,
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 6000.0},
		"supercon": {"coils": coils, "dump": "DUMP", "tau": 35.0, "plant": "COLDBOX", "he": "lhe", "he_min": 0.03, "T0": 4.5, "Tc": 9.0,
			"warm": 0.04, "cool": 0.2, "safe": 0.05, "reach": 6.0, "boil": 0.25},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"coolant": 60000.0, "water": 300.0, "fuel": 3000.0}},
		"ctrls_cfg": {"G-C": {"rate": 24.0}, "G-R": {"rate": 22.0}, "G-P": {"rate": 22.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "QPS-C": "QUENCH", "COLDBOX": "COLD BOX", "HE-DEW": "He", "MPS": "MAGNET PSU", "CDB": "He DIST", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "FX", "name": ["熔核级聚变实验船", "FUSION CORE-CLASS EXPERIMENT SHIP"], "time": 45.0,
			"rooms": mrooms,
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0]},
			"fluids": {},
			"knockable": ["WALL", "OPS-2"],
			"drift": [],
			"section_x": 32.0,
			"slots": {"fire_system": {"x": FIRE_X, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "P", "port": [FIRE_X + 0.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"PCS": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 20.0},
				{"do": "operate", "ctrl": "DUMP"},
				{"do": "wait", "until": {"mod": ["magnets", "field", "<", 5.0]}, "max": 200.0},
				{"do": "hose", "ctrl": "G-P"},
				{"do": "wait", "until": {"P": ["P", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-P"},
				{"do": "wait", "until": {"open": ["P"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-M1"},
				{"do": "operate", "ctrl": "K-M2"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "PCS"},
				{"do": "deliver", "piece": "PCS", "zone": "equip"},
			],
		},
	}


const VALUE := 1923800.0
const FIRE_X := 68.0
const FIRE_BASE := "HF5-0"
