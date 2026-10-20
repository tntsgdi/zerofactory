class_name Ob90Author
# Authoring script for OB-90 "Sky-Eye", a 90 m telescope ship (new designs 05/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/ob90.json. Metres, x bow (0) to the stern (90), y down.
#
# Forward, open to space: the baffle tube (two walls with their vanes), the secondary
# mirror on its spider at the mouth, and at the back of the tube the primary mirror,
# eighteen segments in a column (nine a half, round a central hole), each on its
# actuator, the actuators on the backplane, the backplane braced to the hull; a
# roll-down dust cover on a motor under the baffle's top wall. Aft, the pressure hull:
# I the instrument module (the aft optics, the cameras and spectrograph over the mirror
# control cabinet, the wavefront computer, the recorder, the spare segments), C the
# control room over the crew's quarters, P the power room (batteries, the bus, the
# reaction wheels, the fuel cell); the cryo radiators on the roof over I, the antenna
# over P.
# What it asks of you (scripts/optics.gd): the actuators locked ring by ring while the
# cabinet still has power, the segments off from the outer ring in, and no cutting near
# the mirror unless the cover is down.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(33, -4.5), Vector2(34.5, -6), Vector2(88, -6), Vector2(90, -4), Vector2(90, 4), Vector2(88, 6), Vector2(34.5, 6), Vector2(33, 4.5)]
const BH := [56.0, 72.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 5.5
const DOOR := 2.5
const ROOMS := ["I", "C", "P"]
const CY := -1.5          # the mirror's axis
const PITCH := 0.9
const SEG_H := 0.8

static var w
static var by_tag := {}
static var n_auto := 0
static var segs := {}


static func build(world) -> void:
	K.begin(world, "OB90")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	segs = {}
	_hull()
	_inner()
	_mirror()
	_baffle()
	_instruments()
	_control()
	_power()
	_roof()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 42.0, 6.0, 5.8)
	K.clamp(2, 80.0, 6.0, 5.8)


static func rooms_only(world) -> void:
	K.begin(world, "OB90")
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
			push_warning("OB90 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
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
	K.ring(OUT, T, {1: [0.08, 0.16, 0.24, 0.32, 0.4, 0.48, 0.56, 0.64, 0.72, 0.8, 0.88, 0.94], 3: [0.35, 0.65],
		5: [0.06, 0.12, 0.2, 0.28, 0.36, 0.44, 0.4755, 0.52, 0.6, 0.68, 0.76, 0.84, 0.92], 7: [0.2, 0.4, 0.6, 0.8]}, {
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(0, 2.2) * Geom.M, "cut_speed": 200.0},
		"5:6": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HO")


static func _inner() -> void:
	var B := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	for i in BH.size():
		var x: float = BH[i]
		var u = K.plate("BH%d-U" % i, K.R(x - 0.25, -IN, x + 0.25, DOOR), B, "hull")
		var d = K.plate("D-%d" % i, K.R(x - 0.25, DOOR, x + 0.25, IN), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -2.8) * Geom.M}, "door")
		K.bolt(u, K.at(x, -IN - 0.25, ["hull"]), x, -IN, "weld")
		K.bolt(u, d, x, DOOR, "weld")
		K.bolt(d, K.at(x, IN + 0.25, ["hull"]), x, IN, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	# each room's deck, its well at the aft end
	for r in [[33.5, 55.75, "I"], [56.25, 71.75, "C"], [72.25, 89.5, "P"]]:
		var a: float = r[0]
		var b: float = r[1] - 2.6
		var dk = K.plate("DK-" + r[2], K.R(a, 0.0, b, 0.25), D, "deck")
		K.bolt(dk, K.at(a - 0.15, 0.12, ["hull"]), a, 0.12, "weld")


# ---------------------------------------------------------------- the primary mirror

# segment i (1 next to the hole .. 9 at the rim) of the upper or lower half: [y0, y1]
static func seg_y(half: String, i: int) -> Array:
	if half == "U":
		var y1: float = CY - 0.5 - (i - 1) * PITCH
		return [y1 - SEG_H, y1]
	var y0: float = CY + 0.5 + (i - 1) * PITCH
	return [y0, y0 + SEG_H]


static func _mirror() -> void:
	var BP := {"density": 1.4, "barrier": false, "cut_speed": 190.0, "name_key": "p_ob_backplane"}
	# the backplane, three pieces a half, round the hole
	var bands := {"U": [[-10.4, -7.6], [-7.6, -4.8], [-4.8, -2.0]], "L": [[-1.0, 1.8], [1.8, 4.6], [4.6, 7.3]]}
	for h in bands:
		var prev = null
		for k in 3:
			var bp = K.plate("BP-%s%d" % [h, k + 1], K.R(29.8, bands[h][k][0], 31.0, bands[h][k][1]), BP, "beam")
			if prev != null:
				K.bolt(bp, prev, 30.4, bands[h][k][0], "weld")
			prev = bp
	# struts back to the bow wall, clear of the light path through the hole
	var S := {"density": 1.6, "barrier": false, "cut_speed": 170.0, "name_key": "p_ob_strut"}
	for y in [-4.0, -2.8, 0.4, 2.6, 4.0]:
		var st = K.plate("STR%d" % int(y * 10.0), K.R(31.0, y - 0.2, 33.0, y + 0.2), S, "strut")
		K.bolt(st, K.at(30.4, y, ["beam"]), 31.0, y, "weld")
		K.bolt(st, K.at(33.25, y, ["hull"]), 33.0, y, "weld")
	# the top of the backplane braced to the roof
	var br = K.plate("BRC-U", K.mp([Vector2(31.0, -10.2), Vector2(36.4, -6.05), Vector2(35.6, -6.05), Vector2(31.0, -9.5)]), S, "strut")
	K.bolt(br, by_tag["BP-U1"], 31.0, -9.85, "weld")
	K.bolt(br, K.at(36.0, -5.75, ["hull"]), 36.0, -6.0, "weld")
	# and the bottom of it to the keel
	var bl = K.plate("BRC-L", K.mp([Vector2(31.0, 6.6), Vector2(31.0, 7.2), Vector2(36.4, 6.05), Vector2(35.6, 6.05)]), S, "strut")
	K.bolt(bl, by_tag["BP-L3"], 31.0, 6.9, "weld")
	K.bolt(bl, K.at(36.0, 5.75, ["hull"]), 36.0, 6.0, "weld")
	# the segments, each on its actuator, the actuators on the backplane
	for h in ["U", "L"]:
		for i in range(1, 10):
			var yy: Array = seg_y(h, i)
			var yc: float = (yy[0] + yy[1]) * 0.5
			var ring := int((i - 1) / 3) + 1
			var sg = E("PM-%s%d" % [h, i], "mirror", 28.4, yy[0], 29.0, yy[1], "", {"mass": 0.22, "value": 38000.0, "fragile": 0.7, "name_key": "p_ob_segment"})
			var ac = E("PA-%s%d" % [h, i], "aux", 29.1, yc - 0.18, 29.7, yc + 0.18, "", {"mass": 0.03, "value": 2400.0, "name_key": "p_ob_actuator"})
			K.bolt(sg, ac, 29.05, yc - 0.2)
			K.bolt(sg, ac, 29.05, yc + 0.2)
			K.bolt(ac, K.at(30.4, yc, ["beam"]), 29.75, yc)
			segs["PM-%s%d" % [h, i]] = {"ring": ring, "half": h, "act": "PA-%s%d" % [h, i]}


# ---------------------------------------------------------------- the baffle and the secondary

static func _baffle() -> void:
	var F := {"density": 0.8, "barrier": false, "cut_speed": 220.0, "name_key": "p_ob_baffle"}
	var V := {"density": 0.6, "barrier": false, "cut_speed": 240.0, "name_key": "p_ob_vane"}
	var xs := [1.0, 8.5, 16.0, 23.5, 31.0]
	for h in ["U", "L"]:
		var y0: float = -10.9 if h == "U" else 7.3
		var y1: float = -10.4 if h == "U" else 7.8
		var inner_y: float = y1 if h == "U" else y0
		var prev = null
		for k in 4:
			var bf = K.plate("BF-%s%d" % [h, k + 1], K.R(xs[k], y0, xs[k + 1], y1), F, "beam")
			if prev != null:
				K.bolt(bf, prev, xs[k], (y0 + y1) * 0.5, "weld")
			prev = bf
		K.bolt(prev, by_tag["BP-%s" % ("U1" if h == "U" else "L3")], 30.4, inner_y, "weld")
		# the vanes that stop stray light, and the lip at the mouth
		for vx in [4.0, 10.5, 17.0, 22.5]:
			var k2 := 0
			while xs[k2 + 1] < vx:
				k2 += 1
			var vy0: float = inner_y if h == "U" else inner_y - 0.9
			var vn = K.plate("", K.R(vx, vy0, vx + 0.15, vy0 + 0.9), V, "fixture")
			K.bolt(vn, by_tag["BF-%s%d" % [h, k2 + 1]], vx + 0.07, inner_y, "weld")
		var lp = K.plate("LIP-" + h, K.R(0.6, -11.1, 1.0, -9.9) if h == "U" else K.R(0.6, 6.8, 1.0, 8.0), V, "fixture")
		K.bolt(lp, by_tag["BF-%s1" % h], 1.0, (y0 + y1) * 0.5, "weld")
	# what lines the tube: insulation blankets, the heaters that keep the walls from
	# frosting, the stray-light monitors and the contamination witness plates
	var keep := [[3.8, 4.35], [10.3, 10.85], [16.8, 17.35], [22.3, 22.85], [5.2, 6.0]]
	for h in ["U", "L"]:
		var n := 1 if h == "U" else 2
		_row("", -10.4 if h == "U" else 7.3, 1.0 if h == "U" else -1.0, 1.4, 27.2, [["", "insul", 2.0, 0.25, {"mass": 0.03, "value": 1200.0, "name_key": "p_ob_mli"}],
			["SLM-%d" % n, "sensor", 0.5, 0.4, {"mass": 0.02, "value": 4500.0, "fragile": 0.5, "name_key": "p_ob_straylight"}], ["", "insul", 2.0, 0.25, {"mass": 0.03, "value": 1200.0, "name_key": "p_ob_mli"}],
			["", "panel", 0.6, 0.3, {"mass": 0.02, "value": 900.0, "name_key": "p_ob_baffle_heater"}], ["", "insul", 2.0, 0.25, {"mass": 0.03, "value": 1200.0, "name_key": "p_ob_mli"}],
			["WIT-%d" % n, "sensor", 0.5, 0.3, {"mass": 0.01, "value": 2000.0, "fragile": 0.6, "name_key": "p_ob_witness"}], ["", "insul", 2.0, 0.25, {"mass": 0.03, "value": 1200.0, "name_key": "p_ob_mli"}],
			["", "panel", 0.6, 0.3, {"mass": 0.02, "value": 900.0, "name_key": "p_ob_baffle_heater"}], ["", "insul", 2.0, 0.25, {"mass": 0.03, "value": 1200.0, "name_key": "p_ob_mli"}],
			["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_ob_particle_counter"}], ["", "insul", 2.0, 0.25, {"mass": 0.03, "value": 1200.0, "name_key": "p_ob_mli"}]], keep)
	# the spider and the secondary mirror on its hexapod
	var S := {"density": 1.2, "barrier": false, "cut_speed": 190.0, "name_key": "p_ob_spider"}
	var su = K.plate("SPD-U", K.R(5.4, -10.4, 5.8, -2.65), S, "strut")
	K.bolt(su, by_tag["BF-U1"], 5.6, -10.4, "weld")
	var sl = K.plate("SPD-L", K.R(5.4, -0.35, 5.8, 7.3), S, "strut")
	K.bolt(sl, by_tag["BF-L1"], 5.6, 7.3, "weld")
	var hx = E("SMH", "aux", 5.0, -2.65, 6.4, -0.35, "", {"mass": 0.12, "value": 26000.0, "fragile": 0.5, "name_key": "p_ob_hexapod"})
	K.bolt(hx, su, 5.6, -2.65)
	K.bolt(hx, sl, 5.6, -0.35)
	var sm = E("SM", "mirror", 6.45, -2.4, 6.85, -0.6, "", {"mass": 0.06, "value": 120000.0, "fragile": 0.7, "name_key": "p_ob_secondary"})
	K.bolt(sm, hx, 6.42, -2.0)
	K.bolt(sm, hx, 6.42, -1.0)
	# the dust cover's roller under the top wall, just in front of the segments
	var rl = E("ROLL", "reel", 27.5, -10.38, 28.3, -9.82, "", {"mass": 0.08, "value": 6000.0, "name_key": "p_ob_cover_roller"})
	K.bolt(rl, by_tag["BF-U4"], 27.9, -10.4)


# ---------------------------------------------------------------- I, the instrument module

static func _instruments() -> void:
	# upper level: the aft optics bench on the axis, the instruments it feeds
	_row("I", 0.0, -1.0, 34.0, 53.0, [["AOS", "module", 2.4, 2.2, {"mass": 0.5, "value": 64000.0, "fragile": 0.6, "name_key": "p_ob_aft_optics"}],
		["FSM", "glass", 0.8, 1.2, {"mass": 0.05, "value": 28000.0, "fragile": 0.7, "name_key": "p_ob_fsm"}],
		["NIRC", "insp", 1.6, 1.8, {"mass": 0.3, "value": 85000.0, "fragile": 0.5, "name_key": "p_ob_nircam"}],
		["SPEC", "module", 2.0, 1.6, {"mass": 0.4, "value": 72000.0, "fragile": 0.5, "name_key": "p_ob_spectro"}],
		["FGS", "nav", 1.2, 1.2, {"mass": 0.12, "value": 36000.0, "fragile": 0.5, "name_key": "p_ob_fgs"}],
		["CRYO", "pump", 1.4, 1.4, {"mass": 0.45, "value": 22000.0, "name_key": "p_ob_cryocooler"}],
		["ICE", "nav_rack", 1.0, 2.6, {"mass": 0.3, "value": 18000.0, "name_key": "p_ob_ice"}],
		["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 3500.0, "name_key": "p_ob_cleansuit"}],
		["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_row("I", -IN, 1.0, 36.0, 55.5, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.6,
		["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_ob_cryo_line"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_ob_particle_counter"}], 0.6, ["", "screen", 1.2, 0.7, {"mass": 0.03, "value": 1400.0, "name_key": "p_ark_screen"}],
		0.6, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.6, ["", "pipe", 2.0, 0.4, {"mass": 0.06, "value": 2600.0, "name_key": "p_ob_cryo_line"}],
		0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-I", 44.0, -IN, "I")
	# lower level: the mirror's control cabinet and wavefront computer, the recorder,
	# the spare segments in their crates, the calibration and cleaning kit
	_row("I", IN, -1.0, 35.8, 55.5, [["MCC", "swb", 1.4, 2.6, {"mass": 0.4, "value": 24000.0, "name_key": "p_ob_mcc"}],
		["WFS", "nav_rack", 1.2, 2.8, {"mass": 0.35, "value": 30000.0, "fragile": 0.5, "name_key": "p_ob_wfs"}],
		["SSR", "blackbox", 0.9, 0.7, {"mass": 0.05, "value": 40000.0, "fragile": 0.4, "mandatory": true, "name_key": "p_ob_ssr"}],
		["SPARE-1", "cargo", 1.6, 1.2, {"mass": 0.4, "value": 30000.0, "fragile": 0.5, "name_key": "p_ob_spare_seg"}],
		["SPARE-2", "cargo", 1.6, 1.2, {"mass": 0.4, "value": 30000.0, "fragile": 0.5, "name_key": "p_ob_spare_seg"}],
		["CAL", "cabinet", 1.0, 1.8, {"mass": 0.15, "value": 9000.0, "name_key": "p_ob_cal"}],
		["GLV", "glove", 1.8, 1.6, {"mass": 0.3, "value": 12000.0, "name_key": "p_ob_glovebox"}],
		["", "filter", 0.9, 1.6, {"mass": 0.12, "value": 2800.0, "name_key": "p_ob_hepa"}],
		["", "env", 1.4, 2.2, {"mass": 0.4, "value": 8000.0, "name_key": "p_ob_cleanair"}],
		["JIG", "lift", 1.4, 2.0, {"mass": 0.3, "value": 7500.0, "name_key": "p_ob_seg_jig"}],
		["CTG", "module", 2.0, 2.2, {"mass": 0.6, "value": 26000.0, "fragile": 0.5, "name_key": "p_ob_recoater"}],
		["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]])
	_row("I", 0.25, 1.0, 34.0, 53.0, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.8,
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 0.8, ["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}],
		0.8, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_ob_particle_counter"}], 0.8, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}]])
	_lamp("LAMP-I2", 46.0, 0.25, "I")


# ---------------------------------------------------------------- C, the control room

static func _control() -> void:
	_row("C", 0.0, -1.0, 56.8, 69.0, [["OPS-1", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_ob_ops_console"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["OPS-2", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_ob_ops_console"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["SCHED", "console", 1.2, 1.2, {"mass": 0.15, "value": 9000.0, "name_key": "p_ob_sched"}], ["", "desk", 1.4, 0.9, {"mass": 0.08, "value": 800.0, "name_key": "p_ark_desk"}],
		["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 2200.0, "name_key": "p_ob_plate_archive"}], ["", "table", 1.4, 0.9, {"mass": 0.06, "value": 700.0, "name_key": "p_ark_table"}]])
	_row("C", -IN, 1.0, 56.8, 71.5, [["WALL", "screen", 3.0, 1.2, {"mass": 0.12, "value": 9000.0, "fragile": 0.6, "name_key": "p_ob_skywall"}], 0.6, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]])
	_lamp("LAMP-C", 64.0, -IN, "C")
	_row("C", IN, -1.0, 56.6, 71.6, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["GAL-C", "module", 1.8, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_ark_galley"}],
		["ENV-C", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "medcab", 0.8, 1.2, {"mass": 0.08, "value": 3000.0, "name_key": "p_ark_medcab"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]], [[62.4, 64.7]])
	_row("C", 0.25, 1.0, 56.8, 69.0, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-C2", 66.0, 0.25, "C")


# ---------------------------------------------------------------- P, the power room

static func _power() -> void:
	_row("P", 0.0, -1.0, 72.8, 86.6, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}], ["PCU", "panel", 0.8, 1.2, {"mass": 0.06, "value": 4200.0, "name_key": "p_ob_pcu"}],
		["FC-P", "gen", 1.5, 1.8, {"mass": 1.2, "value": 20000.0, "name_key": "p_fuel_cell"}],
		["PDU-P", "swb", 0.9, 2.2, {"mass": 0.3, "value": 6000.0, "name_key": "p_pdu"}], ["", "cabinet", 1.0, 1.6, {"mass": 0.2, "value": 4800.0, "name_key": "p_ob_spare_cells"}],
		["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_row("P", -IN, 1.0, 72.8, 89.2, [["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.6, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.6, ["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}]])
	_lamp("LAMP-P", 78.0, -IN, "P")
	_row("P", IN, -1.0, 72.8, 89.2, [["RW-1", "drum", 1.2, 1.2, {"mass": 0.6, "value": 16000.0, "name_key": "p_ob_wheel"}], ["RW-2", "drum", 1.2, 1.2, {"mass": 0.6, "value": 16000.0, "name_key": "p_ob_wheel"}],
		["RW-3", "drum", 1.2, 1.2, {"mass": 0.6, "value": 16000.0, "name_key": "p_ob_wheel"}], ["MCP-1", "pump", 1.5, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_coolant_pump"}],
		["FUEL-P", "fueltank", 1.0, 1.6, {"mass": 0.5, "value": 3000.0, "name_key": "p_svc_prop"}], ["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}],
		["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_lamp("LAMP-P2", 80.0, 0.25, "P")


# ---------------------------------------------------------------- outside

static func _roof() -> void:
	for i in 2:
		var x0: float = 39.0 + i * 8.0
		var rp = K.plate("RAD-%d" % (i + 1), K.R(x0, -9.0, x0 + 6.5, -6.0), {"density": 0.5, "barrier": false, "cut_speed": 230.0, "art": "radiator", "name_key": "p_ob_cryo_radiator"}, "hull")
		for x in [x0 + 1.0, x0 + 5.5]:
			K.bolt(rp, K.at(x, -5.75, ["hull"]), x, -6.0, "weld")
	var hga = E("HGA", "radar", 80.0, -8.1, 82.4, -6.05, "", {"mass": 0.3, "value": 18000.0, "name_key": "p_ob_hga"})
	K.bolt(hga, K.at(80.6, -5.75, ["hull"]), 80.6, -6.0)
	K.bolt(hga, K.at(81.8, -5.75, ["hull"]), 81.8, -6.0)
	for i in 2:
		var sx: float = 60.0 + i * 4.0
		var st = E("ST-%d" % (i + 1), "sensor", sx, -6.6, sx + 0.6, -6.05, "", {"mass": 0.03, "value": 9000.0, "fragile": 0.5, "name_key": "p_star_tracker"})
		K.bolt(st, K.at(sx + 0.3, -5.75, ["hull"]), sx + 0.3, -6.0)


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
	_c("p3", "SWB-P", "FC-P")
	_c("p4", "SWB-P", "MCP-1")
	_c("p5", "SWB-P", "PCU")
	_c("p6", "SWB-P", "ICE", [Vector2(73.5, -0.6), Vector2(_cen("ICE").x, -0.6)])
	for t in ["AOS", "FSM", "NIRC", "SPEC", "FGS", "LAMP-I"]:
		_c("i" + t, "ICE", t, [Vector2(_cen("ICE").x, -2.9), Vector2(_cen(t).x, -2.9)])
	_c("iSSR", "ICE", "SSR", [Vector2(_cen("ICE").x, 0.6), Vector2(_cen("SSR").x, 0.6)])
	_c("p7", "SWB-P", "CRYO", [Vector2(73.5, -3.0), Vector2(_cen("CRYO").x, -3.0)])
	_c("p8", "SWB-P", "MCC", [Vector2(73.5, 4.6), Vector2(_cen("MCC").x, 4.6)])
	_c("m1", "MCC", "WFS")
	_c("m2", "MCC", "ROLL", [Vector2(32.2, 4.0), Vector2(32.2, -11.2), Vector2(27.9, -11.2)])
	_c("m3", "MCC", "SMH", [Vector2(32.2, 4.0), Vector2(32.2, -11.3), Vector2(5.6, -11.3)])
	# the actuators' two harnesses, out along each half of the backplane
	for h in ["U", "L"]:
		var prev := "MCC"
		for i in range(1, 10):
			var a := "PA-%s%d" % [h, i]
			if prev == "MCC":
				_c("h%s%d" % [h, i], "MCC", a, [Vector2(32.2, 4.0), Vector2(31.2, _cen(a).y)])
			else:
				_c("h%s%d" % [h, i], prev, a)
			prev = a
	_c("p9", "SWB-P", "OPS-1", [Vector2(73.5, -1.6), Vector2(_cen("OPS-1").x, -1.6)])
	_c("p10", "OPS-1", "OPS-2")
	_c("p11", "OPS-1", "SCHED")
	_c("p12", "OPS-1", "LAMP-C")
	_c("p13", "SWB-P", "ENV-C", [Vector2(73.5, 4.4), Vector2(_cen("ENV-C").x, 4.4)])
	_c("p14", "SWB-P", "LAMP-P")
	_c("p15", "SWB-P", "HGA", [Vector2(76.0, -5.0), Vector2(81.2, -5.0)])
	_c("p16", "SWB-P", "ST-1", [Vector2(74.0, -4.8), Vector2(60.3, -4.8)])
	_c("p17", "ST-1", "ST-2")
	# the cryocooler's loop to the camera and out to the radiators; the power room's water
	_p("c1", "cryo", "CRYO", "NIRC")
	_p("c2", "cryo", "CRYO", "RAD-1", [Vector2(_cen("CRYO").x, -4.9), Vector2(42.0, -4.9)])
	_p("c3", "cryo", "RAD-1", "RAD-2")
	_p("w1", "loop", "MCP-1", "FC-P")
	_p("f1", "fuel", "FC-P", "FUEL-P")


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "P"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "P"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "P"})
	var mc = by_tag["MCC"]
	for r in 3:
		K.ctrl("LK-%d" % (r + 1), "switch", mc, _cen("MCC") + Vector2(-0.45 + r * 0.3, -0.9), {"target": "LK-%d" % (r + 1), "state": false, "hidden_room": "I"})
	K.ctrl("CVR", "switch", mc, _cen("MCC") + Vector2(0.45, -0.9), {"target": "CVR", "state": false, "hidden_room": "I"})
	K.ctrl("E-M", "test", mc, _cen("MCC") + Vector2(-0.3, 0.2), {"medium": "volt", "target": "MCC", "hidden_room": "I"})
	K.ctrl("OPT", "probe", mc, _cen("MCC") + Vector2(0.3, 0.2), {"medium": "optics", "target": "mirror", "hidden_room": "I"})
	K.ctrl("PC", "port", by_tag["CRYO"], _cen("CRYO") + Vector2(0, -0.5), {"medium": "coolant", "target": "cryo", "hidden_room": "I"})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.5), {"medium": "water", "target": "loop", "hidden_room": "P"})
	K.ctrl("PF", "port", by_tag["FUEL-P"], _cen("FUEL-P") + Vector2(0, -0.6), {"medium": "fuel", "target": "fuel", "hidden_room": "P"})
	var gp := {"I": 46.0, "C": 59.0, "P": 84.0}
	for r in gp:
		K.ctrl("G-" + r, "port", K.at(gp[r], 5.8, ["hull"]), Vector2(gp[r], 6.2), {"medium": "gas", "target": r})
	K.ctrl("AUX-P", "socket", K.at(68.0, 5.8, ["hull"]), Vector2(68.0, 6.2), {"target": "aux", "state": false})
	for t in ["HT-C", "HT-P"]:
		K.door(t, "")
	# both bulkhead doors worked from the control room, the side the floor hatch opens into
	for i in BH.size():
		K.door("D-%d" % i, "C")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := [0.0, BH[0] - 0.25, BH[0] + 0.25, BH[1] - 0.25, BH[1] + 0.25, 95.0]
	for i in ROOMS.size():
		var parts := Geometry2D.intersect_polygons(inn, K.R(cuts[i * 2], -8.0, cuts[i * 2 + 1], 8.0))
		if not parts.is_empty():
			w.add_room(ROOMS[i], parts[0])


static func meta() -> Dictionary:
	var vols := {}
	vols["cryo"] = {"fluid": "coolant", "amount": 0.2, "nets": ["cryo"], "piece": "CRYO", "port": "PC", "full": 0.3, "content": 1.0, "leak": 0.1, "pump": [0.08, 0.006]}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.3, "nets": ["fuel"], "piece": "FUEL-P", "port": "PF", "full": 0.5, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	var rooms := {}
	var names := {}
	var mrooms := {}
	for r in ROOMS:
		rooms[r] = 101.0
		names[r] = "room_ob" + r
		mrooms[r] = [0.2, 40.0, 101.0]
	var lamps := {"I": "LAMP-I", "C": "LAMP-C", "P": "LAMP-P"}
	return {
		"id": "ob90",
		"name": "OB-90 SKY-EYE",
		"title": ["OB-90「天眼」望远镜船 · 90 m", "OB-90 SKY-EYE · TELESCOPE SHIP · 90 m"],
		"contract": "OB-90",
		"length": 90.0,
		"value": {"total": VALUE, "metal": 20000.0},
		"clamps": [[42.0, 6.0], [80.0, 6.0]],
		"room_names": names,
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 6000.0},
		"optics": {"segments": segs, "locks": {"1": "LK-1", "2": "LK-2", "3": "LK-3"}, "mcc": "MCC", "radius": 12.0, "dust": 0.05, "dust_min": 0.35,
			"cover": {"roller": "ROLL", "switch": "CVR", "len": 17.2, "time": 12.0}},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"coolant": 14000.0, "water": 300.0, "fuel": 3000.0}},
		"ctrls_cfg": {"G-I": {"rate": 34.0}, "G-C": {"rate": 26.0}, "G-P": {"rate": 26.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "MCC": "MIRROR", "ROLL": "COVER", "SM": "M2", "SSR": "SSR", "CRYO": "CRYO", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "OB", "name": ["天眼级望远镜船", "SKY-EYE-CLASS TELESCOPE SHIP"], "time": 48.0,
			"rooms": mrooms,
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0]},
			"fluids": {},
			"knockable": ["WALL", "OPS-2"],
			"drift": [],
			"section_x": 60.0,
			"slots": {"fire_system": {"x": FIRE_X, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "P", "port": [FIRE_X + 0.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"SSR": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "hose", "ctrl": "G-I"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 200.0},
				{"do": "wait", "until": {"P": ["I", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 20.0},
				{"do": "operate", "ctrl": "D-0"},
				{"do": "wait", "until": {"open": ["I"]}, "max": 20.0},
				{"do": "hose", "ctrl": "G-P"},
				{"do": "wait", "until": {"P": ["P", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "D-1"},
				{"do": "wait", "until": {"open": ["P"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-M1"},
				{"do": "operate", "ctrl": "K-M2"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "SSR"},
				{"do": "deliver", "piece": "SSR", "zone": "equip"},
			],
		},
	}


const VALUE := 1801800.0
const FIRE_X := 86.0
const FIRE_BASE := "HO5-0"
