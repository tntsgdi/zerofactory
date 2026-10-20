class_name Dr150Author
# Authoring script for DR-150 "Derrick", a 150 m deep-space drilling ship (new designs
# 09/10, design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/dr150.json. Metres, x bow (0) to the stern (150), y down.
#
# Amidships a 28 m derrick stands on the drill floor (the roof over D): its crown block,
# the travelling block and the top drive, and hanging from them the drill string - six
# stands above the rotary table, two more and the bottom-hole assembly below it in the
# moonpool, each stand held to the derrick by a guide arm. On the drill floor the
# drawworks, the iron roughneck, the driller's console (the torque bleed, the gauges),
# the slips panel, the pipe rack and the catwalk. D below it: the mud logging and core
# lab over the standpipe and the well-control kit. Forward H, the bridge over the crew's
# quarters; aft M, the mud pumps and tanks, and P, the power (generators, batteries,
# the bus, the engine).
# What it asks of you (scripts/drillstring.gd): the torque bled at the rotary brake and
# the mud let out at the standpipe, every slip set, then the stands broken out from the
# top down.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(0, -5), Vector2(2.5, -7), Vector2(148, -7), Vector2(150, -5), Vector2(150, 5), Vector2(148, 7), Vector2(2.5, 7), Vector2(0, 5)]
const BH := [30.0, 70.0, 100.0, 125.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 6.5
const DOOR := 3.0
const ROOMS := ["H", "D", "M", "P", "W"]
const SX := 49.6          # the string's left side (0.8 wide)
const STAND := 3.5

static var w
static var by_tag := {}
static var n_auto := 0
static var stands: Array = []


static func build(world) -> void:
	K.begin(world, "DR150")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	stands = []
	_hull()
	_inner()
	_derrick()
	_string()
	_drill_floor()
	_drill_room()
	_quarters()
	_mud()
	_power()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 40.0, 7.0, 6.8)
	K.clamp(2, 122.0, 7.0, 6.8)


static func rooms_only(world) -> void:
	K.begin(world, "DR150")
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
			push_warning("DR150 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
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
	# edges: 0 bow upper, 1 roof (the drill floor over D; the rotary table set in it),
	# 2 stern upper, 3 stern, 4 stern lower, 5 keel, 6 bow lower, 7 bow
	var rf: Array = []
	for i in range(1, 30):
		rf.append(i / 30.0)
	# the rotary table: the piece of roof at x 48.6-51.4 (as fractions of the 145.5 m roof)
	var a: float = (48.6 - 2.5) / 145.5
	var b: float = (51.4 - 2.5) / 145.5
	rf = rf.filter(func(f): return f < a - 0.004 or f > b + 0.004)
	rf.append(a)
	rf.append(b)
	rf.sort()
	var rt_i: int = rf.find(a) + 1
	var kl: Array = [0.04, 0.08, 0.12, 0.16, 0.2, 0.24, 0.28, 0.32, 0.36, 0.4, 0.44, 0.48, 0.52, 0.56, 0.6, 0.64, 0.68, 0.72, 0.76, 0.8, 0.84, 0.86, 0.872, 0.9, 0.94, 0.97]
	K.ring(OUT, T, {1: rf, 3: [0.35, 0.65], 5: kl, 7: [0.5]}, {
		"1:%d" % rt_i: {"cls": "equip", "dest": "equip", "art": "module", "tag": "RT", "mass": 2.4, "value": 45000.0, "fragile": 0.3, "cut_speed": 120.0, "name_key": "p_dr_rotary"},
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(0, 2.2) * Geom.M, "cut_speed": 200.0},
		"5:22": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
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
	for r in [[0.5, 29.75, "H"], [70.25, 99.75, "M"], [100.25, 124.75, "P"], [125.25, 149.5, "W"]]:
		var a: float = r[0]
		var b: float = r[1] - 2.6
		var dk = K.plate("DK-" + r[2], K.R(a, 0.0, b, 0.25), D, "deck")
		K.bolt(dk, K.at(a - 0.15, 0.12, ["hull"]), a, 0.12, "weld")
	# the moonpool's two walls down through D, a deck either side of them
	var MP := {"density": 1.4, "barrier": false, "cut_speed": 200.0, "name_key": "p_dr_moonpool"}
	for mx in [47.0, 52.6]:
		var mw = K.plate("MP-%s" % ("L" if mx < 50.0 else "R"), K.R(mx, -IN, mx + 0.4, IN), MP, "fixture")
		K.bolt(mw, K.at(mx + 0.2, -IN - 0.25, ["hull"]), mx + 0.2, -IN, "weld")
		K.bolt(mw, K.at(mx + 0.2, IN + 0.25, ["hull"]), mx + 0.2, IN, "weld")
	var ml = K.plate("DK-DL", K.R(30.25, 0.0, 47.0, 0.25), D, "deck")
	K.bolt(ml, K.at(30.1, 0.12, ["hull"]), 30.25, 0.12, "weld")
	K.bolt(ml, by_tag["MP-L"], 47.0, 0.12, "weld")
	var mr = K.plate("DK-DR", K.R(53.0, 0.0, 69.75, 0.25), D, "deck")
	K.bolt(mr, by_tag["MP-R"], 53.0, 0.12, "weld")
	K.bolt(mr, K.at(69.9, 0.12, ["hull"]), 69.75, 0.12, "weld")


# ---------------------------------------------------------------- the derrick

static func _derrick() -> void:
	var L := {"density": 1.4, "barrier": false, "cut_speed": 170.0, "name_key": "p_dr_derrick"}
	for lx in [45.5, 54.0]:
		var prev = null
		for k in 4:
			var y1: float = -7.0 - k * 7.0
			var lg = K.plate("DL-%s%d" % ["A" if lx < 50.0 else "B", k + 1], K.R(lx, y1 - 7.0, lx + 0.5, y1), L, "beam")
			if prev == null:
				K.bolt(lg, K.at(lx + 0.25, -6.75, ["hull"]), lx + 0.25, -7.0, "weld")
			else:
				K.bolt(lg, prev, lx + 0.25, y1, "weld")
			prev = lg
	# the monkey boards at mid height, the crown platform on top
	var P := {"density": 1.0, "barrier": false, "cut_speed": 220.0, "name_key": "p_dr_platform"}
	var mb1 = K.plate("MB-A", K.R(46.0, -21.15, 49.3, -20.85), P, "fixture")
	K.bolt(mb1, by_tag["DL-A3"], 46.0, -21.0, "weld")
	var mb2 = K.plate("MB-B", K.R(50.7, -21.15, 54.0, -20.85), P, "fixture")
	K.bolt(mb2, by_tag["DL-B3"], 54.0, -21.0, "weld")
	var cp = K.plate("CROWN", K.R(45.5, -35.5, 54.5, -35.0), P, "fixture")
	K.bolt(cp, by_tag["DL-A4"], 45.75, -35.0, "weld")
	K.bolt(cp, by_tag["DL-B4"], 54.25, -35.0, "weld")
	var cb = E("CB", "reel", 48.8, -34.95, 51.2, -33.8, "", {"mass": 1.2, "value": 14000.0, "name_key": "p_dr_crown_block"})
	K.bolt(cb, cp, 49.2, -35.0)
	K.bolt(cb, cp, 50.8, -35.0)
	var tb = E("TB", "hook", 49.4, -33.75, 50.6, -30.45, "", {"mass": 0.9, "value": 12000.0, "name_key": "p_dr_travel_block"})
	K.bolt(tb, cb, 50.0, -33.8, "lock")
	var td = E("TD", "module", 49.0, -30.4, 51.0, -28.15, "", {"mass": 2.2, "value": 65000.0, "fragile": 0.4, "name_key": "p_dr_top_drive"})
	K.bolt(td, tb, 50.0, -30.45)
	# its guide arm off the left leg (it rides a rail there)
	var tg = K.plate("TDG", K.R(46.0, -29.45, 48.95, -29.15), {"density": 1.2, "barrier": false, "cut_speed": 220.0, "name_key": "p_dr_guide"}, "fixture")
	K.bolt(tg, by_tag["DL-A4"], 46.0, -29.3, "weld")
	K.bolt(td, tg, 49.0, -29.3)
	# the lights up the derrick
	for ly in [-14.0, -26.0]:
		var dl = E("", "lamp", 54.5, ly, 55.06, ly + 0.16, "", {"cls": "metal", "dest": "metal", "mass": 0.04, "cut_speed": 260.0, "name_key": "p_dr_derrick_light"})
		K.bolt(dl, K.at(54.25, ly + 0.08, ["beam"]), 54.5, ly + 0.08)


# ---------------------------------------------------------------- the drill string

static func _string() -> void:
	var G := {"density": 1.2, "barrier": false, "cut_speed": 220.0, "name_key": "p_dr_guide"}
	var S := {"mass": 1.4, "value": 9000.0, "fragile": 0.3, "name_key": "p_dr_stand", "cut_speed": 110.0}
	# above the rotary table, J-1 (under the top drive) down to J-6 on the table
	var prev = by_tag["TD"]
	for k in 6:
		var y1: float = -7.05 - (5 - k) * STAND
		var st = E("J-%d" % (k + 1), "pipe", SX, y1 - STAND + 0.05, SX + 0.8, y1, "", S)
		K.bolt(st, prev, SX + 0.4, y1 - STAND + 0.05)
		var gd = K.plate("", K.R(46.0, y1 - 1.9, SX - 0.05, y1 - 1.6), G, "fixture")
		var leg = K.at(45.75, y1 - 1.75, ["beam"])
		K.bolt(gd, leg, 46.0, y1 - 1.75, "weld")
		K.bolt(st, gd, SX, y1 - 1.75)
		stands.append(st.tag)
		prev = st
	K.bolt(prev, by_tag["RT"], SX + 0.4, -7.05)
	# below it in the moonpool: J-7, J-8, and the bottom-hole assembly with its core barrel
	var tops := [-6.45, -2.95]
	prev = by_tag["RT"]
	for k in 2:
		var y0: float = tops[k]
		var st = E("J-%d" % (k + 7), "pipe", SX, y0, SX + 0.8, y0 + STAND - 0.05, "D", S)
		K.bolt(st, prev, SX + 0.4, y0)
		var gd = K.plate("", K.R(47.4, y0 + 1.6, SX - 0.05, y0 + 1.9), G, "fixture")
		K.bolt(gd, by_tag["MP-L"], 47.4, y0 + 1.75, "weld")
		K.bolt(st, gd, SX, y0 + 1.75)
		stands.append(st.tag)
		prev = st
	var bha = E("BHA", "pipe", SX - 0.1, 0.55, SX + 0.9, 4.6, "D", {"mass": 2.0, "value": 72000.0, "fragile": 0.3, "name_key": "p_dr_bha", "cut_speed": 100.0})
	K.bolt(bha, prev, SX + 0.4, 0.55)
	var gd2 = K.plate("", K.R(47.4, 2.4, SX - 0.15, 2.7), G, "fixture")
	K.bolt(gd2, by_tag["MP-L"], 47.4, 2.55, "weld")
	K.bolt(bha, gd2, SX - 0.1, 2.55)
	stands.append("BHA")


# ---------------------------------------------------------------- the drill floor (outside)

static func _drill_floor() -> void:
	var on_roof := func(tag: String, art: String, x0: float, h: float, wd: float, o: Dictionary):
		var p = E(tag, art, x0, -7.0 - h, x0 + wd, -7.05, "", o)
		K.bolt(p, K.at(x0 + minf(0.3, wd * 0.25), -6.75, ["hull"]), x0 + minf(0.3, wd * 0.25), -7.0)
		K.bolt(p, K.at(x0 + wd - minf(0.3, wd * 0.25), -6.75, ["hull"]), x0 + wd - minf(0.3, wd * 0.25), -7.0)
		return p
	on_roof.call("DW", "reel", 37.5, 1.8, 2.6, {"mass": 2.8, "value": 48000.0, "name_key": "p_dr_drawworks"})
	on_roof.call("", "panel", 40.6, 1.2, 0.8, {"mass": 0.06, "value": 5200.0, "name_key": "p_dr_brake_panel"})
	on_roof.call("", "gastank", 41.8, 1.6, 0.6, {"mass": 0.1, "value": 4200.0, "hazard": "gas_tank", "name_key": "p_dr_accumulator"})
	on_roof.call("IR", "arm", 51.6, 2.4, 1.6, {"mass": 1.6, "value": 42000.0, "fragile": 0.4, "name_key": "p_dr_roughneck"})
	on_roof.call("DRL", "console", 56.8, 1.4, 1.4, {"mass": 0.25, "value": 22000.0, "fragile": 0.5, "name_key": "p_dr_driller"})
	on_roof.call("SLP", "panel", 58.6, 1.6, 1.0, {"mass": 0.08, "value": 7200.0, "name_key": "p_dr_slips_panel"})
	on_roof.call("", "seat", 59.9, 1.0, 0.6, {"mass": 0.04, "value": 900.0, "name_key": "p_dr_driller_chair"})
	on_roof.call("PRK", "shelf", 61.0, 1.2, 4.0, {"mass": 2.4, "value": 18000.0, "name_key": "p_dr_pipe_rack"})
	on_roof.call("", "lift", 65.4, 1.4, 1.6, {"mass": 0.8, "value": 11000.0, "name_key": "p_dr_catwalk"})
	on_roof.call("", "insp", 34.0, 1.2, 1.0, {"mass": 0.08, "value": 6400.0, "fragile": 0.5, "name_key": "p_dr_floor_camera"})
	on_roof.call("", "cargo", 67.4, 1.0, 1.4, {"mass": 0.3, "value": 3600.0, "name_key": "p_dr_tongs"})


# ---------------------------------------------------------------- D, the drill room

static func _drill_room() -> void:
	# left of the moonpool: the core lab over the standpipe and well control
	_row("D", 0.0, -1.0, 30.8, 46.8, [["LOG", "console", 1.4, 1.2, {"mass": 0.2, "value": 18000.0, "fragile": 0.5, "name_key": "p_dr_mud_log"}],
		["CORE-A", "insp", 1.6, 1.6, {"mass": 0.3, "value": 30000.0, "fragile": 0.5, "name_key": "p_dr_core_scanner"}],
		["CORE", "biobox", 1.2, 1.0, {"mass": 0.3, "value": 80000.0, "fragile": 0.5, "mandatory": true, "name_key": "p_dr_core_box"}],
		["", "shelf", 2.0, 2.2, {"mass": 0.3, "value": 8000.0, "name_key": "p_dr_core_rack"}], ["", "shelf", 2.0, 2.2, {"mass": 0.3, "value": 8000.0, "name_key": "p_dr_core_rack"}],
		["", "table", 1.4, 0.9, {"mass": 0.08, "value": 1200.0, "name_key": "p_dr_lab_bench"}], ["", "env", 1.2, 2.0, {"mass": 0.3, "value": 6800.0, "name_key": "p_dr_fume_hood"}],
		["", "cabinet", 0.9, 1.8, {"mass": 0.1, "value": 3200.0, "name_key": "p_dr_sample_cab"}]])
	_row("D", -IN, 1.0, 30.8, 46.8, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 1.2, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		1.2, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2400.0, "name_key": "p_dr_gas_detector"}], 1.2, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1800.0, "name_key": "p_dr_mud_line"}]])
	_lamp("LAMP-D", 40.0, -IN, "D")
	_row("D", IN, -1.0, 30.8, 46.8, [["STP", "panel", 1.0, 2.4, {"mass": 0.3, "value": 9000.0, "name_key": "p_dr_standpipe"}], ["", "aux", 1.2, 1.0, {"mass": 0.2, "value": 7400.0, "name_key": "p_dr_choke"}],
		["", "gastank", 0.8, 2.0, {"mass": 0.2, "value": 12000.0, "hazard": "gas_tank", "name_key": "p_dr_bop_accumulator"}], ["", "cargo", 2.0, 1.2, {"mass": 1.2, "value": 20000.0, "name_key": "p_dr_spare_bha"}],
		["", "module", 1.4, 2.0, {"mass": 0.6, "value": 9800.0, "name_key": "p_dr_mud_gas_sep"}], ["", "module", 2.0, 1.6, {"mass": 0.8, "value": 11000.0, "name_key": "p_dr_shaker"}],
		["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_row("D", 0.25, 1.0, 30.8, 46.8, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 1.2, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1800.0, "name_key": "p_dr_mud_line"}],
		1.2, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-D2", 36.0, 0.25, "D")
	# right of it: the pipe-handling stores, the hydraulics
	_row("D", 0.0, -1.0, 53.6, 69.3, [["", "cargo", 1.6, 1.2, {"mass": 0.3, "value": 3400.0, "name_key": "p_dr_thread_dope"}], ["", "lift", 1.4, 1.8, {"mass": 0.5, "value": 7800.0, "name_key": "p_dr_pipe_trolley"}],
		["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}], ["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 2600.0, "name_key": "p_dr_tool_cab"}],
		["ENV-D", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "shelf", 2.0, 2.0, {"mass": 0.4, "value": 5200.0, "name_key": "p_dr_core_rack"}], ["", "cargo", 1.2, 1.0, {"mass": 0.2, "value": 4800.0, "name_key": "p_dr_core_boxes"}]])
	_row("D", -IN, 1.0, 53.6, 69.3, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 1.2, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2400.0, "name_key": "p_dr_gas_detector"}],
		1.2, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.2, ["", "screen", 1.2, 0.7, {"mass": 0.03, "value": 1400.0, "name_key": "p_ark_screen"}]])
	_lamp("LAMP-D3", 62.0, -IN, "D")
	_row("D", IN, -1.0, 53.6, 69.3, [["HPU", "pump", 1.6, 1.6, {"mass": 1.0, "value": 14000.0, "name_key": "p_dr_hpu"}], ["", "reel", 1.6, 1.4, {"mass": 1.2, "value": 6800.0, "name_key": "p_dr_drill_line"}],
		["", "cargo", 2.0, 1.4, {"mass": 1.4, "value": 7600.0, "name_key": "p_dr_casing"}], ["", "cargo", 2.0, 1.4, {"mass": 1.4, "value": 7600.0, "name_key": "p_dr_casing"}],
		["", "gastank", 0.6, 1.6, {"mass": 0.1, "value": 2600.0, "hazard": "gas_tank", "name_key": "p_dr_n2"}], ["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}]])
	_row("D", 0.25, 1.0, 53.6, 69.3, [["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1800.0, "name_key": "p_dr_mud_line"}], 1.2, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])


# ---------------------------------------------------------------- H, forward

static func _quarters() -> void:
	_row("H", 0.0, -1.0, 3.0, 27.0, [["BRG-1", "console", 1.4, 1.2, {"mass": 0.2, "value": 14000.0, "fragile": 0.5, "name_key": "p_dr_bridge"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["NAV", "nav", 1.2, 1.2, {"mass": 0.12, "value": 12000.0, "fragile": 0.5, "name_key": "p_lc_nav"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["COMMS", "nav_rack", 0.9, 2.2, {"mass": 0.3, "value": 14000.0, "name_key": "p_lc_comms"}], ["", "table", 1.6, 0.9, {"mass": 0.08, "value": 1600.0, "name_key": "p_ark_nav_table"}],
		["", "desk", 1.4, 0.9, {"mass": 0.08, "value": 800.0, "name_key": "p_ark_desk"}], ["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 2400.0, "name_key": "p_dr_well_logs"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}]])
	_row("H", -IN, 1.0, 3.5, 29.5, [["", "screen", 2.4, 1.0, {"mass": 0.08, "value": 4800.0, "name_key": "p_dr_well_display"}], 1.0, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]])
	_lamp("LAMP-H", 20.0, -IN, "H")
	_row("H", IN, -1.0, 3.0, 29.5, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["GAL-H", "module", 1.8, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_ark_galley"}], ["", "table", 1.4, 0.9, {"mass": 0.06, "value": 700.0, "name_key": "p_ark_table"}],
		["ENV-H", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "medcab", 0.8, 1.2, {"mass": 0.08, "value": 3000.0, "name_key": "p_ark_medcab"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}]], [[20.9, 23.1]])
	_row("H", 0.25, 1.0, 3.0, 27.0, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-H2", 12.0, 0.25, "H")


# ---------------------------------------------------------------- M, the mud pumps

static func _mud() -> void:
	_row("M", IN, -1.0, 70.7, 99.5, [["MPU-1", "pump", 2.4, 2.2, {"mass": 2.6, "value": 36000.0, "name_key": "p_dr_mud_pump"}], ["MPU-2", "pump", 2.4, 2.2, {"mass": 2.6, "value": 36000.0, "name_key": "p_dr_mud_pump"}],
		["MT-1", "water", 2.2, 3.0, {"mass": 1.2, "value": 8000.0, "name_key": "p_dr_mud_tank"}], ["MT-2", "water", 2.2, 3.0, {"mass": 1.2, "value": 8000.0, "name_key": "p_dr_mud_tank"}],
		["", "cargo", 1.4, 1.4, {"mass": 0.4, "value": 3800.0, "name_key": "p_dr_hopper"}], ["", "module", 1.6, 1.8, {"mass": 0.8, "value": 15000.0, "name_key": "p_dr_centrifuge"}],
		["", "filter", 1.0, 1.8, {"mass": 0.3, "value": 6200.0, "name_key": "p_dr_degasser"}], ["", "filter", 1.0, 1.8, {"mass": 0.3, "value": 5400.0, "name_key": "p_dr_desander"}]])
	_row("M", 0.0, -1.0, 70.7, 97.0, [["MCON", "console", 1.4, 1.2, {"mass": 0.2, "value": 12000.0, "name_key": "p_dr_mud_console"}], ["", "insp", 1.2, 1.2, {"mass": 0.15, "value": 9000.0, "name_key": "p_dr_mud_lab"}],
		["", "cabinet", 1.0, 1.8, {"mass": 0.15, "value": 3400.0, "name_key": "p_dr_chem_store"}], ["", "cabinet", 1.0, 1.8, {"mass": 0.15, "value": 3400.0, "name_key": "p_dr_chem_store"}],
		["", "barrel", 1.0, 1.4, {"mass": 0.4, "value": 1200.0, "name_key": "p_dr_barite"}], ["", "barrel", 1.0, 1.4, {"mass": 0.4, "value": 1200.0, "name_key": "p_dr_barite"}],
		["", "barrel", 1.0, 1.4, {"mass": 0.4, "value": 1200.0, "name_key": "p_dr_barite"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}],
		["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}],
		["", "module", 1.4, 1.6, {"mass": 0.7, "value": 7800.0, "name_key": "p_dr_agitator"}], ["", "module", 1.4, 1.6, {"mass": 0.7, "value": 7800.0, "name_key": "p_dr_agitator"}],
		["", "shelf", 2.0, 2.0, {"mass": 0.6, "value": 3200.0, "name_key": "p_dr_sack_store"}], ["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]])
	_row("M", -IN, 1.0, 70.7, 99.5, [["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1800.0, "name_key": "p_dr_mud_line"}], 1.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}],
		1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2400.0, "name_key": "p_dr_gas_detector"}],
		1.0, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1800.0, "name_key": "p_dr_mud_line"}]])
	_lamp("LAMP-M", 86.0, -IN, "M")
	_row("M", 0.25, 1.0, 70.7, 97.0, [["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1800.0, "name_key": "p_dr_mud_line"}], 1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-M2", 80.0, 0.25, "M")


# ---------------------------------------------------------------- P, the power

static func _power() -> void:
	_row("P", 0.0, -1.0, 100.7, 122.0, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}], ["PDU-P", "swb", 0.9, 2.2, {"mass": 0.3, "value": 6000.0, "name_key": "p_pdu"}],
		["GEN-1", "gen", 2.0, 2.0, {"mass": 2.2, "value": 26000.0, "name_key": "p_dr_generator"}], ["GEN-2", "gen", 2.0, 2.0, {"mass": 2.2, "value": 26000.0, "name_key": "p_dr_generator"}],
		["", "swb", 1.2, 2.4, {"mass": 0.5, "value": 9000.0, "name_key": "p_dr_vfd"}], ["", "panel", 0.8, 1.2, {"mass": 0.05, "value": 3800.0, "name_key": "p_lc_engine_panel"}],
		["ENV-P", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}]])
	_row("P", -IN, 1.0, 101.0, 124.5, [["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}], 1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		1.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 1.0, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1600.0, "name_key": "p_lc_fuel_main"}],
		1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}], 1.0, ["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}]])
	_lamp("LAMP-P", 112.0, -IN, "P")
	_row("P", IN, -1.0, 100.7, 124.5, [["", "pump", 1.6, 1.6, {"mass": 0.9, "value": 12000.0, "name_key": "p_dr_air_compressor"}], ["", "gastank", 0.9, 2.2, {"mass": 0.4, "value": 4200.0, "hazard": "gas_tank", "name_key": "p_dr_air_receiver"}],
		["", "gastank", 0.9, 2.2, {"mass": 0.4, "value": 4200.0, "hazard": "gas_tank", "name_key": "p_dr_air_receiver"}], ["MCP-1", "pump", 1.4, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_coolant_pump"}],
		["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}], ["", "module", 1.8, 2.0, {"mass": 1.2, "value": 16000.0, "name_key": "p_heat_exchanger"}],
		["", "water", 1.2, 2.2, {"mass": 0.6, "value": 5400.0, "name_key": "p_bl_water_recycler"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}],
		["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]])
	_row("P", 0.25, 1.0, 100.7, 122.0, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], 1.0, ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-P2", 118.0, 0.25, "P")
	# W, the machine shop over the engine
	_row("W", 0.0, -1.0, 125.7, 146.8, [["LATHE", "module", 2.2, 1.6, {"mass": 1.6, "value": 24000.0, "name_key": "p_dr_lathe"}], ["MILL", "module", 1.8, 1.8, {"mass": 1.4, "value": 22000.0, "name_key": "p_dr_mill"}],
		["", "aux", 1.0, 1.2, {"mass": 0.2, "value": 5200.0, "name_key": "p_dr_welder"}], ["", "table", 2.0, 0.9, {"mass": 0.15, "value": 1800.0, "name_key": "p_dr_workbench"}],
		["", "shelf", 2.0, 2.0, {"mass": 0.4, "value": 6800.0, "name_key": "p_dr_spares_rack"}], ["BITS", "vault", 1.4, 1.1, {"mass": 0.6, "value": 42000.0, "name_key": "p_dr_bit_store"}],
		["", "shelf", 2.0, 2.0, {"mass": 0.4, "value": 6800.0, "name_key": "p_dr_spares_rack"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}],
		["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 2600.0, "name_key": "p_dr_tool_cab"}], ["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]])
	_row("W", -IN, 1.0, 126.0, 147.0, [["", "hook", 1.2, 1.8, {"mass": 0.4, "value": 6400.0, "name_key": "p_dr_shop_hoist"}], 1.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}],
		1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]])
	_lamp("LAMP-W", 142.0, -IN, "W")
	_row("W", IN, -1.0, 125.7, 140.0, [["ENG-1", "eng_core", 2.6, 3.0, {"mass": 2.8, "value": 62000.0, "fragile": 0.4, "name_key": "p_lc_main_engine"}],
		["FUEL-1", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}], ["FUEL-2", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}],
		["FUEL-3", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}], ["", "pump", 1.2, 1.2, {"mass": 0.4, "value": 6400.0, "name_key": "p_lc_fuel_pump"}],
		["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}]])
	_row("W", 0.25, 1.0, 125.7, 146.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], 1.0, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1600.0, "name_key": "p_lc_fuel_main"}]])
	_lamp("LAMP-W2", 138.0, 0.25, "W")
	for i in 2:
		var y0: float = -4.4 if i == 0 else 1.8
		var nz = E("NOZ-%d" % (i + 1), "nozzle", 150.05, y0, 152.4, y0 + 2.6, "", {"mass": 1.1, "value": 16000.0, "name_key": "p_lc_nozzle"})
		K.bolt(nz, K.at(149.8, y0 + 0.6, ["hull"]), 150.0, y0 + 0.6)
		K.bolt(nz, K.at(149.8, y0 + 2.0, ["hull"]), 150.0, y0 + 2.0)


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
	_c("p5", "SWB-P", "GEN-2")
	_c("p6", "SWB-P", "ENV-P")
	_c("p7", "PDU-P", "ENG-1", [Vector2(_cen("PDU-P").x, 1.0), Vector2(_cen("ENG-1").x, 1.0)])
	_c("p8", "SWB-P", "MCP-1", [Vector2(_cen("SWB-P").x, 1.2), Vector2(_cen("MCP-1").x, 1.2)])
	_c("p9", "SWB-P", "LAMP-P")
	_c("pw1", "PDU-P", "LATHE", [Vector2(_cen("PDU-P").x, -3.4), Vector2(_cen("LATHE").x, -3.4)])
	_c("pw2", "LATHE", "MILL")
	_c("pw3", "LATHE", "LAMP-W", [Vector2(_cen("LATHE").x, -5.6), Vector2(142.0, -5.6)])
	_c("p10", "PDU-P", "MPU-1", [Vector2(101.0, 4.0), Vector2(_cen("MPU-1").x, 4.0)])
	_c("p11", "MPU-1", "MPU-2")
	_c("p12", "PDU-P", "MCON", [Vector2(101.0, -0.8), Vector2(_cen("MCON").x, -0.8)])
	_c("p13", "MCON", "LAMP-M")
	# up onto the drill floor: the drawworks, the roughneck, the top drive, the driller
	_c("p14", "PDU-P", "DW", [Vector2(101.0, -6.2), Vector2(70.0, -6.2), Vector2(70.0, -7.8), Vector2(_cen("DW").x, -7.8)])
	_c("p15", "DW", "IR", [Vector2(_cen("DW").x, -9.4), Vector2(_cen("IR").x, -9.4)])
	_c("p16", "DW", "TD", [Vector2(_cen("DW").x, -9.6), Vector2(45.2, -9.6), Vector2(45.2, -29.3), Vector2(_cen("TD").x, -29.3)])
	_c("p17", "DW", "DRL", [Vector2(_cen("DW").x, -9.8), Vector2(_cen("DRL").x, -9.8)])
	_c("p18", "DRL", "SLP")
	_c("p19", "PDU-P", "HPU", [Vector2(101.0, 5.6), Vector2(_cen("HPU").x, 5.6)])
	_c("p20", "PDU-P", "ENV-D", [Vector2(101.0, -1.2), Vector2(_cen("ENV-D").x, -1.2)])
	_c("p21", "ENV-D", "LAMP-D3")
	_c("p22", "PDU-P", "LOG", [Vector2(101.0, -1.4), Vector2(_cen("LOG").x, -1.4)])
	_c("p23", "LOG", "CORE-A")
	_c("p24", "LOG", "LAMP-D")
	_c("p25", "PDU-P", "BRG-1", [Vector2(101.0, -5.8), Vector2(_cen("BRG-1").x, -5.8)])
	_c("p26", "BRG-1", "NAV")
	_c("p27", "BRG-1", "COMMS")
	_c("p28", "BRG-1", "LAMP-H")
	_c("p29", "PDU-P", "ENV-H", [Vector2(101.0, 5.8), Vector2(_cen("ENV-H").x, 5.8)])
	# the mud: tanks to pumps, pumps to the standpipe, the standpipe up to the top drive
	_p("m1", "mud", "MT-1", "MPU-1")
	_p("m2", "mud", "MT-2", "MPU-2")
	_p("m3", "mud", "MPU-1", "STP", [Vector2(_cen("MPU-1").x, 3.6), Vector2(_cen("STP").x, 3.6)])
	_p("m4", "mud", "MPU-2", "STP", [Vector2(_cen("MPU-2").x, 3.4), Vector2(_cen("STP").x, 3.4)])
	_p("m5", "mud", "STP", "TD", [Vector2(_cen("STP").x, -7.6), Vector2(45.0, -7.6), Vector2(45.0, -28.8), Vector2(_cen("TD").x, -28.8)])
	_p("w1", "loop", "MCP-1", "ENG-1")
	_p("f1", "fuel", "FUEL-1", "ENG-1")
	_p("f2", "fuel", "FUEL-1", "FUEL-2")
	_p("f3", "fuel", "FUEL-2", "FUEL-3")
	_p("f4", "fuel", "FUEL-1", "GEN-1", [Vector2(_cen("FUEL-1").x, 1.6), Vector2(_cen("GEN-1").x, 1.6)])


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "P"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "P"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "P"})
	# the driller's console: the torque bleed and the gauges; the slips panel beside it
	var dc = by_tag["DRL"]
	K.ctrl("TQB", "switch", dc, _cen("DRL") + Vector2(-0.4, -0.3), {"target": "TQB", "state": false})
	K.ctrl("TQ", "probe", dc, _cen("DRL") + Vector2(0.0, -0.3), {"medium": "torque", "target": "string"})
	K.ctrl("MUDP", "probe", dc, _cen("DRL") + Vector2(0.4, -0.3), {"medium": "mudp", "target": "string"})
	var sp = by_tag["SLP"]
	for k in 8:
		K.ctrl("SLIP-%d" % (k + 1), "switch", sp, _cen("SLP") + Vector2(-0.3 + (k % 2) * 0.6, -0.6 + int(k / 2) * 0.35), {"target": "SLIP-%d" % (k + 1), "state": false})
	K.ctrl("PMUD", "port", by_tag["STP"], _cen("STP") + Vector2(0, -0.8), {"medium": "water", "target": "mud", "hidden_room": "D"})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.5), {"medium": "water", "target": "loop", "hidden_room": "P"})
	K.ctrl("PF", "port", by_tag["FUEL-1"], _cen("FUEL-1") + Vector2(0, -0.8), {"medium": "fuel", "target": "fuel", "hidden_room": "W"})
	var gp := {"H": 10.0, "D": 60.0, "M": 85.0, "P": 108.0, "W": 132.0}
	for r in gp:
		K.ctrl("G-" + r, "port", K.at(gp[r], 6.8, ["hull"]), Vector2(gp[r], 7.2), {"medium": "gas", "target": r})
	K.ctrl("AUX-P", "socket", K.at(112.0, 6.8, ["hull"]), Vector2(112.0, 7.2), {"target": "aux", "state": false})
	for t in ["HT-H", "HT-P"]:
		K.door(t, "")
	K.door("D-0", "H")
	K.door("D-1", "M")
	K.door("D-2", "P")
	K.door("D-3", "W")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := [-1.0, BH[0] - 0.25, BH[0] + 0.25, BH[1] - 0.25, BH[1] + 0.25, BH[2] - 0.25, BH[2] + 0.25, BH[3] - 0.25, BH[3] + 0.25, 155.0]
	for i in ROOMS.size():
		var parts := Geometry2D.intersect_polygons(inn, K.R(cuts[i * 2], -8.0, cuts[i * 2 + 1], 8.0))
		if not parts.is_empty():
			w.add_room(ROOMS[i], parts[0])


static func meta() -> Dictionary:
	var vols := {}
	vols["mud"] = {"fluid": "water", "look": "mud", "amount": 2.5, "nets": ["mud"], "piece": "STP", "port": "PMUD", "full": 3.0, "leak": 0.3, "pump": [0.03, 0.02]}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.6, "nets": ["fuel"], "piece": "FUEL-1", "port": "PF", "full": 0.9, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	var rooms := {}
	var names := {}
	var mrooms := {}
	for r in ROOMS:
		rooms[r] = 101.0
		names[r] = "room_dr" + r
		mrooms[r] = [0.2, 40.0, 101.0]
	var lamps := {"H": "LAMP-H", "D": "LAMP-D", "M": "LAMP-M", "P": "LAMP-P", "W": "LAMP-W"}
	var slips: Array = []
	for k in 8:
		slips.append("SLIP-%d" % (k + 1))
	return {
		"id": "dr150",
		"name": "DR-150 DERRICK",
		"title": ["DR-150「钻塔」深空钻探船 · 150 m", "DR-150 DERRICK · DEEP-SPACE DRILLING SHIP · 150 m"],
		"contract": "DR-150",
		"length": 152.4,
		"value": {"total": VALUE, "metal": 32000.0},
		"clamps": [[40.0, 7.0], [122.0, 7.0]],
		"room_names": names,
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 10000.0},
		"drillstring": {"stands": stands, "slips": slips, "bleed": "TQB", "tau": 20.0, "mud": "mud", "mud_safe": 0.05, "kpa": 3200.0,
			"floor": [34.0, -14.0, 70.0, -7.0], "whip": 0.4, "spray": 0.6, "reach": 8.0},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"water": 16000.0, "fuel": 6000.0}},
		"ctrls_cfg": {"G-H": {"rate": 30.0}, "G-D": {"rate": 40.0}, "G-M": {"rate": 30.0}, "G-P": {"rate": 26.0}, "G-W": {"rate": 26.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "DRL": "DRILLER", "SLP": "SLIPS", "STP": "STANDPIPE", "TD": "TOP DRIVE", "RT": "ROTARY", "CORE": "CORES", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "DR", "name": ["钻塔级深空钻探船", "DERRICK-CLASS DRILLING SHIP"], "time": 60.0,
			"rooms": mrooms,
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0]},
			"fluids": {},
			"knockable": ["NAV", "LOG"],
			"drift": [],
			"section_x": 85.0,
			"slots": {"fire_system": {"x": FIRE_X, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "W", "port": [FIRE_X + 0.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"CORE": [
				{"do": "hose", "ctrl": "G-H"},
				{"do": "hose", "ctrl": "G-D"},
				{"do": "wait", "until": {"P": ["H", "<", 5.0]}, "max": 200.0},
				{"do": "wait", "until": {"P": ["D", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-H"},
				{"do": "wait", "until": {"open": ["H"]}, "max": 20.0},
				{"do": "operate", "ctrl": "D-0"},
				{"do": "wait", "until": {"open": ["D"]}, "max": 20.0},
				{"do": "free", "piece": "CORE"},
				{"do": "deliver", "piece": "CORE", "zone": "equip"},
			],
		},
	}


const VALUE := 1554300.0
const FIRE_X := 143.0
const FIRE_BASE := "HD5-1"
