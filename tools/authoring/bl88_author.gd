class_name Bl88Author
# Authoring script for BL-88 "Floating Isle", an 88 m biodome ship (new designs 07/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/bl88.json. Metres, x bow (0) to the stern (88), y down.
#
# Forward D, the dome: sixteen panes of glass in glazing bars over three levels of
# growing (soil beds and fruit trees on the floor, hydroponic racks on the first
# terrace, planters and nest boxes on the second, grow lights under each), the
# ecology console, the irrigation and its nutrient tank, the seed vault. Then W: the
# water ball, a few cubic metres of water floating in a net cage with the fish in it,
# its pump and fish tank on one side, the feeder and the steriliser on the other.
# Aft H, the crew's quarters, where the fry tank is, and M, the machinery (batteries,
# the bus, the water recycler, the electrolyser, the fuel cell, life support).
# What it asks of you (scripts/waterball.gd, scripts/liner.gd's glazing): the ball
# pumped down at its port before the net or its frame is touched; the dome emptied of
# air before a pane comes out.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(0, 3), Vector2(1.5, -3), Vector2(4.5, -8), Vector2(9, -11.5), Vector2(15, -13.3), Vector2(22, -13.9), Vector2(31, -13.9), Vector2(33, -7),
	Vector2(86, -7), Vector2(88, -5), Vector2(88, 5), Vector2(86, 7), Vector2(2, 7), Vector2(0, 5)]
const BH := [33.0, 55.0, 72.0]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 6.5
const DOOR := 3.0
const ROOMS := ["D", "W", "H", "M"]
const DOME_SPLITS := {0: [0.5], 1: [0.5], 2: [0.5], 3: [0.33, 0.67], 4: [0.33, 0.67], 5: [0.25, 0.5, 0.75]}

static var w
static var by_tag := {}
static var n_auto := 0
static var panes: Array = []


static func build(world) -> void:
	K.begin(world, "BL88")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	panes = []
	_hull()
	_inner()
	_dome()
	_ball()
	_quarters()
	_machinery()
	_outside()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 30.0, 7.0, 6.8)
	K.clamp(2, 78.0, 7.0, 6.8)


static func rooms_only(world) -> void:
	K.begin(world, "BL88")
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
			push_warning("BL88 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
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


static func _glass(tag: String) -> Dictionary:
	return {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.3, "value": 3800.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_bl_dome_pane", "tag": tag}


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	# edges: 0-5 the dome's glass, 6 the dome's back, 7 roof, 8 stern upper, 9 stern,
	# 10 stern lower, 11 floor, 12 bow lower, 13 bow foot
	var sp := {
		"9:1": {"kind": "hatch", "door": true, "tag": "HT-M", "open_dir": Vector2(0, 2.2) * Geom.M, "cut_speed": 200.0},
		"11:5": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
	}
	var n := 0
	for e in DOME_SPLITS:
		for k in (DOME_SPLITS[e] as Array).size() + 1:
			n += 1
			var tg := "GL-%d" % n
			sp["%d:%d" % [e, k]] = _glass(tg)
			panes.append(tg)
	var splits := DOME_SPLITS.duplicate()
	splits[6] = [0.5]
	splits[7] = [0.06, 0.12, 0.18, 0.24, 0.3, 0.36, 0.42, 0.48, 0.54, 0.6, 0.66, 0.72, 0.78, 0.84, 0.9, 0.95]
	splits[9] = [0.35, 0.65]
	splits[11] = [0.06, 0.12, 0.18, 0.24, 0.27, 0.29, 0.36, 0.42, 0.48, 0.54, 0.6, 0.66, 0.72, 0.78, 0.84, 0.9, 0.95]
	K.ring(OUT, T, splits, sp, {"density": 1.5, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HB")
	# the panes sit in glazing bars: the wrench undoes them
	for t in panes:
		for j in w.joints_of(by_tag[t]):
			j.type = "bolt"


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
	for r in [[55.25, 71.75, "H"], [72.25, 87.5, "M"]]:
		var a: float = r[0]
		var b: float = r[1] - 2.6
		var dk = K.plate("DK-" + r[2], K.R(a, 0.0, b, 0.25), D, "deck")
		K.bolt(dk, K.at(a - 0.15, 0.12, ["hull"]), a, 0.12, "weld")
	# the dome's two terraces, off the bulkhead behind them, a row of posts at the front
	var t1 = K.plate("TR-1", K.R(10.0, 0.0, 32.75, 0.25), D, "deck")
	K.bolt(t1, K.at(32.9, 0.12, ["hull"]), 32.75, 0.12, "weld")
	var t2 = K.plate("TR-2", K.R(16.0, -7.0, 32.75, -6.75), D, "deck")
	K.bolt(t2, K.at(32.9, -6.88, ["hull"]), 32.75, -6.88, "weld")
	var P := {"density": 1.2, "barrier": false, "cut_speed": 200.0, "name_key": "p_bl_post"}
	for px in [10.0, 21.0]:
		var po = K.plate("", K.R(px, 0.25, px + 0.3, IN), P, "strut")
		K.bolt(po, t1, px + 0.15, 0.25, "weld")
		K.bolt(po, K.at(px + 0.15, IN + 0.25, ["hull"]), px + 0.15, IN, "weld")
	for px in [16.0, 25.0]:
		var po = K.plate("", K.R(px, -6.75, px + 0.3, 0.0), P, "strut")
		K.bolt(po, t2, px + 0.15, -6.75, "weld")
		K.bolt(po, t1, px + 0.15, 0.0, "weld")


# ---------------------------------------------------------------- D, the dome

static func _dome() -> void:
	var soil := {"mass": 0.6, "value": 2600.0, "name_key": "p_bl_soil_bed"}
	var tower := {"mass": 0.7, "value": 6200.0, "fragile": 0.5, "name_key": "p_bl_vertical_farm"}
	_row("D", IN, -1.0, 2.8, 32.5, [["", "plants", 1.2, 5.0, tower], ["POND", "water", 2.4, 1.0, {"mass": 1.0, "value": 5600.0, "name_key": "p_bl_pond"}],
		["", "plants", 1.2, 5.0, tower], ["", "plants", 3.0, 1.0, soil], ["TREE-1", "plants", 2.2, 3.4, {"mass": 0.8, "value": 9000.0, "fragile": 0.5, "name_key": "p_bl_fruit_tree"}],
		["SEED", "vault", 1.4, 1.1, {"mass": 0.5, "value": 32000.0, "name_key": "p_bl_seed_vault"}], ["IRR", "pump", 1.2, 1.2, {"mass": 0.3, "value": 5200.0, "name_key": "p_bl_irrigation"}],
		["NUT", "water", 1.0, 1.8, {"mass": 0.4, "value": 3800.0, "name_key": "p_bl_nutrient_tank"}], ["ECO", "console", 1.2, 1.2, {"mass": 0.15, "value": 11000.0, "fragile": 0.5, "name_key": "p_bl_eco_console"}],
		["TREE-2", "plants", 2.2, 3.4, {"mass": 0.8, "value": 9000.0, "fragile": 0.5, "name_key": "p_bl_fruit_tree"}], ["", "env", 1.4, 2.2, {"mass": 0.45, "value": 8500.0, "name_key": "p_bl_co2_scrubber"}],
		["", "cargo", 0.8, 0.8, {"mass": 0.05, "value": 1800.0, "name_key": "p_bl_beehive"}], ["", "module", 1.6, 1.6, {"mass": 0.5, "value": 4800.0, "name_key": "p_bl_compost"}]],
		[[9.9, 10.4], [20.9, 21.4]])
	# the first terrace: hydroponic racks, the mister, the weather station
	var rack := {"mass": 0.4, "value": 4200.0, "fragile": 0.5, "name_key": "p_bl_hydro_rack"}
	_row("D", 0.0, -1.0, 10.6, 32.5, [["", "plants", 1.2, 5.0, tower], ["", "sensor", 0.5, 0.6, {"mass": 0.02, "value": 1800.0, "name_key": "p_bl_pollinator"}],
		["", "plants", 2.4, 1.8, rack], ["", "plants", 2.4, 1.8, rack], ["", "aux", 0.8, 0.8, {"mass": 0.05, "value": 2200.0, "name_key": "p_bl_mister"}],
		["", "plants", 2.4, 1.8, rack], ["", "sensor", 0.5, 0.6, {"mass": 0.02, "value": 2600.0, "name_key": "p_bl_weather"}], ["", "plants", 2.4, 1.8, rack],
		["", "aux", 0.8, 0.8, {"mass": 0.05, "value": 2400.0, "name_key": "p_bl_humidifier"}], ["", "cabinet", 1.0, 1.6, {"mass": 0.12, "value": 2000.0, "name_key": "p_bl_tool_shed"}]],
		[[15.9, 16.4], [24.9, 25.4]])
	# the second terrace: planters and the nest boxes, the sprinkler line
	_row("D", -7.0, -1.0, 16.6, 32.5, [["", "plants", 2.4, 1.2, {"mass": 0.3, "value": 2400.0, "name_key": "p_bl_planter"}], ["", "cargo", 0.6, 0.6, {"mass": 0.02, "value": 900.0, "name_key": "p_bl_nest_box"}],
		["", "plants", 2.4, 1.2, {"mass": 0.3, "value": 2400.0, "name_key": "p_bl_planter"}], ["", "plants", 2.4, 1.2, {"mass": 0.3, "value": 2400.0, "name_key": "p_bl_planter"}],
		["", "cargo", 0.6, 0.6, {"mass": 0.02, "value": 900.0, "name_key": "p_bl_nest_box"}], ["", "plants", 2.4, 1.2, {"mass": 0.3, "value": 2400.0, "name_key": "p_bl_planter"}]],
		[[24.9, 25.4]])
	# grow lights under each terrace
	var gl := {"mass": 0.04, "value": 1500.0, "name_key": "p_bl_grow_light"}
	_row("D", 0.25, 1.0, 10.6, 32.5, [["", "overhead", 1.8, 0.4, gl], 1.2, ["", "overhead", 1.8, 0.4, gl], 1.2, ["", "overhead", 1.8, 0.4, gl], 1.2,
		["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1400.0, "name_key": "p_bl_sprinkler"}], 1.2, ["", "overhead", 1.8, 0.4, gl]], [[20.9, 21.4]])
	_row("D", -6.75, 1.0, 16.6, 32.5, [["", "overhead", 1.8, 0.4, gl], 1.2, ["", "overhead", 1.8, 0.4, gl], 1.2, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1400.0, "name_key": "p_bl_sprinkler"}],
		1.2, ["", "overhead", 1.8, 0.4, gl]], [[24.9, 25.4]])
	_lamp("LAMP-D", 28.0, 0.25, "D")


# ---------------------------------------------------------------- W, the water ball

static func _ball() -> void:
	var N := {"density": 0.4, "barrier": false, "cut_speed": 260.0, "art": "grating", "name_key": "p_bl_net"}
	var nt = K.plate("NET-T", K.R(38.5, -5.7, 49.5, -5.5), N, "fixture")
	var nb = K.plate("NET-B", K.R(38.5, 5.5, 49.5, 5.7), N, "fixture")
	var nl = K.plate("NET-L", K.R(38.3, -5.7, 38.5, 5.7), N, "fixture")
	var nr = K.plate("NET-R", K.R(49.5, -5.7, 49.7, 5.7), N, "fixture")
	for p in [nt, nb]:
		var y: float = -5.6 if p == nt else 5.6
		K.bolt(p, nl, 38.5, y, "weld")
		K.bolt(p, nr, 49.5, y, "weld")
	var F := {"density": 1.6, "barrier": false, "cut_speed": 180.0, "name_key": "p_bl_net_frame"}
	var fr := [["FR-1", 38.3, -IN, -5.7, nl, -5.7], ["FR-2", 49.3, -IN, -5.7, nr, -5.7], ["FR-3", 38.3, 5.7, IN, nl, 5.7], ["FR-4", 49.3, 5.7, IN, nr, 5.7]]
	for f in fr:
		var st = K.plate(f[0], K.R(f[1], f[2], f[1] + 0.4, f[3]), F, "strut")
		var wy: float = -IN if f[2] == -IN else IN
		K.bolt(st, K.at(f[1] + 0.2, wy + (-0.25 if wy < 0.0 else 0.25), ["hull"]), f[1] + 0.2, wy, "weld")
		K.bolt(st, f[4], f[1] + 0.1 if f[1] < 40.0 else f[1] + 0.3, f[5], "weld")
	# the ball's pump and its fish tank on one side, the feeder and steriliser on the other
	_row("W", IN, -1.0, 33.6, 37.9, [["WP", "pump", 1.4, 1.4, {"mass": 0.4, "value": 7000.0, "name_key": "p_bl_ball_pump"}],
		["FISH-T", "water", 1.6, 1.8, {"mass": 1.2, "value": 40000.0, "fragile": 0.5, "name_key": "p_bl_fish_tank"}], ["", "filter", 0.6, 1.4, {"mass": 0.1, "value": 3200.0, "name_key": "p_bl_oxygenator"}]])
	_row("W", IN, -1.0, 50.0, 54.5, [["FEED", "aux", 1.0, 1.2, {"mass": 0.1, "value": 4800.0, "name_key": "p_bl_feeder"}], ["UV", "panel", 0.6, 1.4, {"mass": 0.06, "value": 3600.0, "name_key": "p_bl_uv"}],
		["", "env", 1.4, 2.0, {"mass": 0.4, "value": 7500.0, "name_key": "p_bl_dehumidifier"}]])
	_row("W", -IN, 1.0, 33.6, 37.9, [["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2200.0, "name_key": "p_bl_water_quality"}], ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}]])
	_row("W", -IN, 1.0, 50.0, 54.5, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 2200.0, "name_key": "p_bl_water_quality"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-W", 36.0, -IN, "W")
	_lamp("LAMP-W2", 52.5, -IN, "W")
	# a camera on the forward bulkhead, a display on the aft one, at eye height in the ball's light
	var cam = E("OBS", "insp", 33.3, -2.4, 34.1, -1.5, "W", {"mass": 0.06, "value": 6800.0, "fragile": 0.6, "name_key": "p_bl_ball_cam"})
	K.bolt(cam, K.at(33.1, -2.0, ["hull"]), 33.25, -2.1)
	K.bolt(cam, K.at(33.1, -1.8, ["hull"]), 33.25, -1.8)
	var scr = E("", "screen", 53.9, -2.6, 54.7, -1.4, "W", {"mass": 0.04, "value": 1800.0, "name_key": "p_bl_fish_display"})
	K.bolt(scr, K.at(54.9, -2.2, ["hull"]), 54.75, -2.2)
	K.bolt(scr, K.at(54.9, -1.8, ["hull"]), 54.75, -1.8)


# ---------------------------------------------------------------- H, the quarters

static func _quarters() -> void:
	_row("H", 0.0, -1.0, 55.7, 69.0, [["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}], ["", "bunk", 2.0, 1.6, {"mass": 0.2, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "desk", 1.4, 0.9, {"mass": 0.08, "value": 800.0, "name_key": "p_ark_desk"}],
		["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}], ["", "cabinet", 1.0, 1.8, {"mass": 0.12, "value": 2800.0, "name_key": "p_bl_herbarium"}],
		["", "plants", 1.6, 1.2, {"mass": 0.2, "value": 1800.0, "name_key": "p_bl_planter"}]])
	_row("H", -IN, 1.0, 55.7, 71.5, [["", "screen", 1.6, 0.9, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_screen"}], 0.6, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 0.6, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]])
	_lamp("LAMP-H", 64.0, -IN, "H")
	_row("H", IN, -1.0, 55.6, 71.6, [["GAL-H", "module", 1.8, 1.2, {"mass": 0.4, "value": 7000.0, "name_key": "p_ark_galley"}], ["", "fridge", 0.9, 1.9, {"mass": 0.15, "value": 1800.0, "name_key": "p_bl_fridge"}],
		["FRY", "biobox", 1.2, 1.0, {"mass": 0.3, "value": 35000.0, "fragile": 0.5, "mandatory": true, "name_key": "p_bl_fry_tank"}],
		["ENV-H", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "table", 1.4, 0.9, {"mass": 0.06, "value": 700.0, "name_key": "p_ark_table"}],
		["", "medcab", 0.8, 1.2, {"mass": 0.08, "value": 3000.0, "name_key": "p_ark_medcab"}], ["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}]], [[61.4, 63.6]])
	_row("H", 0.25, 1.0, 55.7, 69.0, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-H2", 66.0, 0.25, "H")


# ---------------------------------------------------------------- M, the machinery

static func _machinery() -> void:
	_row("M", 0.0, -1.0, 72.7, 84.8, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}], ["WREC", "water", 1.2, 2.0, {"mass": 0.6, "value": 14000.0, "name_key": "p_bl_water_recycler"}],
		["ELEC", "module", 1.6, 1.8, {"mass": 0.7, "value": 16000.0, "name_key": "p_bl_electrolyser"}]])
	_row("M", -IN, 1.0, 72.7, 85.5, [["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}], 0.6, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.6, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.6, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1400.0, "name_key": "p_bl_water_main"}]])
	_lamp("LAMP-M", 80.0, -IN, "M")
	_row("M", IN, -1.0, 72.6, 84.0, [["FC-P", "gen", 1.5, 1.8, {"mass": 1.2, "value": 20000.0, "name_key": "p_fuel_cell"}], ["FUEL-P", "fueltank", 1.0, 1.6, {"mass": 0.5, "value": 3000.0, "name_key": "p_svc_prop"}],
		["MCP-1", "pump", 1.4, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_coolant_pump"}], ["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}],
		["LSS", "env", 1.6, 2.2, {"mass": 0.6, "value": 15000.0, "name_key": "p_bl_life_support"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_row("M", 0.25, 1.0, 72.7, 84.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], 0.6, ["", "gastank", 0.6, 1.6, {"mass": 0.1, "value": 2600.0, "hazard": "gas_tank", "name_key": "p_bl_o2_store"}]])
	_lamp("LAMP-M2", 78.0, 0.25, "M")


static func _outside() -> void:
	for i in 2:
		var x0: float = 74.0 + i * 6.0
		var rp = K.plate("RAD-%d" % (i + 1), K.R(x0, -10.0, x0 + 5.0, -7.0), {"density": 0.5, "barrier": false, "cut_speed": 230.0, "art": "radiator", "name_key": "p_radiator_fin"}, "hull")
		for x in [x0 + 0.8, x0 + 4.2]:
			K.bolt(rp, K.at(x, -6.75, ["hull"]), x, -7.0, "weld")
	var hga = E("HGA", "radar", 62.0, -9.0, 64.4, -7.05, "", {"mass": 0.3, "value": 16000.0, "name_key": "p_ob_hga"})
	K.bolt(hga, K.at(62.6, -6.75, ["hull"]), 62.6, -7.0)
	K.bolt(hga, K.at(63.8, -6.75, ["hull"]), 63.8, -7.0)


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
	_c("p3", "SWB-P", "WREC")
	_c("p4", "SWB-P", "ELEC")
	_c("p5", "SWB-P", "FC-P", [Vector2(_cen("SWB-P").x, 1.0), Vector2(_cen("FC-P").x, 1.0)])
	_c("p6", "SWB-P", "MCP-1", [Vector2(_cen("SWB-P").x, 1.2), Vector2(_cen("MCP-1").x, 1.2)])
	_c("p7", "SWB-P", "LSS", [Vector2(_cen("SWB-P").x, 1.4), Vector2(_cen("LSS").x, 1.4)])
	_c("p8", "SWB-P", "LAMP-M")
	_c("p9", "SWB-P", "ENV-H", [Vector2(73.0, 5.8), Vector2(_cen("ENV-H").x, 5.8)])
	_c("p10", "SWB-P", "LAMP-H", [Vector2(73.0, -5.8), Vector2(64.0, -5.8)])
	_c("p11", "SWB-P", "HGA", [Vector2(73.0, -6.2), Vector2(63.2, -6.2)])
	_c("p12", "SWB-P", "WP", [Vector2(73.0, 4.4), Vector2(_cen("WP").x, 4.4)])
	_c("p13", "WP", "FEED", [Vector2(_cen("WP").x, 6.1), Vector2(_cen("FEED").x, 6.1)])
	_c("p14", "FEED", "UV")
	_c("p15", "WP", "LAMP-W")
	_c("p16", "WP", "OBS")
	_c("p17", "SWB-P", "ECO", [Vector2(73.0, -5.6), Vector2(31.5, -5.6), Vector2(31.5, 4.0), Vector2(_cen("ECO").x, 4.0)])
	_c("p18", "ECO", "IRR")
	_c("p19", "ECO", "LAMP-D")
	# the ball's suction hose into the cage, the irrigation to its nutrient tank
	_p("b1", "ball", "WP", "NET-L", [Vector2(_cen("WP").x, 3.0), Vector2(38.4, 3.0)])
	_p("b2", "ball", "WP", "FISH-T")
	_p("n1", "nutr", "IRR", "NUT")
	_p("w1", "loop", "MCP-1", "FC-P")
	_p("f1", "fuel", "FC-P", "FUEL-P")


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "M"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "M"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "M"})
	K.ctrl("PW", "port", by_tag["WP"], _cen("WP") + Vector2(0, -0.5), {"medium": "water", "target": "ball", "hidden_room": "W"})
	K.ctrl("BALL", "probe", by_tag["WP"], _cen("WP") + Vector2(0.4, -0.5), {"medium": "ball", "target": "ball", "hidden_room": "W"})
	K.ctrl("PN", "port", by_tag["NUT"], _cen("NUT") + Vector2(0, -0.6), {"medium": "water", "target": "nutr", "hidden_room": "D"})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.5), {"medium": "water", "target": "loop", "hidden_room": "M"})
	K.ctrl("PF", "port", by_tag["FUEL-P"], _cen("FUEL-P") + Vector2(0, -0.6), {"medium": "fuel", "target": "fuel", "hidden_room": "M"})
	var gp := {"D": 20.0, "W": 46.0, "H": 58.0, "M": 83.0}
	for r in gp:
		K.ctrl("G-" + r, "port", K.at(gp[r], 6.8, ["hull"]), Vector2(gp[r], 7.2), {"medium": "gas", "target": r})
	K.ctrl("AUX-P", "socket", K.at(68.0, 6.8, ["hull"]), Vector2(68.0, 7.2), {"target": "aux", "state": false})
	for t in ["HT-H", "HT-M"]:
		K.door(t, "")
	K.door("D-0", "W")
	K.door("D-1", "H")
	K.door("D-2", "H")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var cuts := [-1.0, BH[0] - 0.25, BH[0] + 0.25, BH[1] - 0.25, BH[1] + 0.25, BH[2] - 0.25, BH[2] + 0.25, 95.0]
	for i in ROOMS.size():
		var parts := Geometry2D.intersect_polygons(inn, K.R(cuts[i * 2], -20.0, cuts[i * 2 + 1], 8.0))
		if not parts.is_empty():
			w.add_room(ROOMS[i], parts[0])


static func meta() -> Dictionary:
	var vols := {}
	vols["ball"] = {"fluid": "water", "amount": 8.0, "nets": ["ball"], "piece": "WP", "port": "PW", "full": 9.0, "leak": 0.4, "pump": [0.02, 0.02]}
	vols["nutr"] = {"fluid": "water", "amount": 0.3, "nets": ["nutr"], "piece": "NUT", "port": "PN", "full": 0.4, "leak": 0.1, "pump": [0.1, 0.006]}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.3, "nets": ["fuel"], "piece": "FUEL-P", "port": "PF", "full": 0.5, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	var rooms := {}
	var names := {}
	var mrooms := {}
	for r in ROOMS:
		rooms[r] = 101.0
		names[r] = "room_bl" + r
		mrooms[r] = [0.2, 40.0, 101.0]
	var lamps := {"D": "LAMP-D", "W": "LAMP-W", "H": "LAMP-H", "M": "LAMP-M"}
	return {
		"id": "bl88",
		"name": "BL-88 FLOATING ISLE",
		"title": ["BL-88「浮岛」生态穹顶船 · 88 m", "BL-88 FLOATING ISLE · BIODOME SHIP · 88 m"],
		"contract": "BL-88",
		"length": 88.0,
		"value": {"total": VALUE, "metal": 20000.0},
		"clamps": [[30.0, 7.0], [78.0, 7.0]],
		"room_names": names,
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 9000.0},
		"liner": {"pods": {}, "glazings": [{"room": "D", "panes": panes, "kpa": 20.0}]},
		"waterball": {"vol": "ball", "room": "W", "net": ["NET-T", "NET-B", "NET-L", "NET-R"], "frame": ["FR-1", "FR-2", "FR-3", "FR-4"],
			"centre": [44.0, 0.0], "radius": 4.6, "safe": 0.12, "fish": "FISH-T", "soak": 0.5, "short": 0.3},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"water": 9000.0, "fuel": 3000.0}},
		"ctrls_cfg": {"G-D": {"rate": 60.0}, "G-W": {"rate": 34.0}, "G-H": {"rate": 26.0}, "G-M": {"rate": 26.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "WP": "BALL PUMP", "FISH-T": "FISH", "FRY": "FRY", "ECO": "ECO", "SEED": "SEEDS", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "BL", "name": ["浮岛级生态穹顶船", "FLOATING ISLE-CLASS BIODOME SHIP"], "time": 50.0,
			"rooms": mrooms,
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0]},
			"fluids": {},
			"knockable": ["OBS", "ECO"],
			"drift": [],
			"section_x": 44.0,
			"slots": {"fire_system": {"x": FIRE_X, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "M", "port": [FIRE_X + 0.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"FRY": [
				{"do": "hose", "ctrl": "G-H"},
				{"do": "wait", "until": {"P": ["H", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-H"},
				{"do": "wait", "until": {"open": ["H"]}, "max": 20.0},
				{"do": "free", "piece": "FRY"},
				{"do": "deliver", "piece": "FRY", "zone": "equip"},
			],
		},
	}


const VALUE := 578500.0
const FIRE_X := 85.5
const FIRE_BASE := "HB11-0"
