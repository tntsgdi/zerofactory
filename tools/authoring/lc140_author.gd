class_name Lc140Author
# Authoring script for LC-140 "Shell Mountain", a 140 m ship carrier (new designs 08/10,
# design/ships/02_新设计十艘_设计稿.md). Not part of the game: tools/ship_export.gd
# runs it and writes ships/lc140.json. Metres, x bow (0) to the stern (140), y down.
#
# The hold H runs the length of the ship behind a bow door that lifts clear; on a
# four-saddle cradle in its forward half stands a damaged 30 m courier, a ship of its
# own (its cabin S over its machinery deck: the cockpit, the bunk, its battery on its
# own circuit, its fuel tank, its engine). Behind it, a mezzanine of cargo. Over the
# bow the bridge B (the helm, the manifest), aft the engine room E (batteries, the
# bus, two main engines, the fuel). The winch that draws the courier out hangs under
# the bridge deck; the cradle's locks and the winch switch are on a panel beside it.
# What it asks of you (scripts/nested.gd): the courier made safe (its battery off, its
# fuel drawn, its cabin emptied), the locks let go from the stern forward, the bow door
# lifted, and the winch: out it slides whole, paid as one. Cut its hull and it is
# only parts.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.5
const OUT := [Vector2(0, -7.5), Vector2(0.5, -8), Vector2(6, -8), Vector2(7, -14), Vector2(27, -14), Vector2(28, -8), Vector2(110, -8), Vector2(112, -9),
	Vector2(136, -9), Vector2(140, -6), Vector2(140, 6), Vector2(136, 8), Vector2(1, 8), Vector2(0, 7.5)]
const SOUT := [Vector2(30, 1), Vector2(32.5, -3), Vector2(36, -4.5), Vector2(55, -4.5), Vector2(60, -2), Vector2(60, 4), Vector2(57.5, 5.5), Vector2(33, 5.5), Vector2(30, 3.5)]
const FLOORK := ["hull", "deck", "beam", "strut", "fixture"]
const IN := 7.5
const DOOR := 4.0
const BHX := 110.0
const SADDLES := [55.0, 48.0, 41.0, 34.0]      # stern first, as the locks go

static var w
static var by_tag := {}
static var n_auto := 0
static var mine: Array = []
static var hull_s: Array = []


static func build(world) -> void:
	K.begin(world, "LC140")
	w = world
	by_tag = K.by_tag
	n_auto = 0
	mine = []
	hull_s = []
	_hull()
	_inner()
	_bridge()
	_courier()
	_hold()
	_engines()
	_lines()
	_controls()
	_rooms()
	K.clamp(1, 70.0, 8.0, 7.8)
	K.clamp(2, 122.0, 8.0, 7.8)


static func rooms_only(world) -> void:
	K.begin(world, "LC140")
	w = world
	_rooms()


static func _auto(p: String) -> String:
	n_auto += 1
	return "%s%d" % [p, n_auto]


static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, room: String, o: Dictionary):
	var opts := {"fragile": 0.4, "room": room}
	opts.merge(o, true)
	var p = K.equip(tag if tag != "" else _auto(art.left(4).to_upper() + "-"), art, K.rect(x0, y0, x1, y1), opts)
	if room == "S":
		mine.append(p.tag)
	return p


static func _row(room: String, floor_y: float, up: float, x0: float, x1: float, items: Array, keep: Array = [], floork: Array = FLOORK) -> Array:
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
			push_warning("LC140 row %s: %s does not fit (%.1f + %.1f > %.1f)" % [room, it[0], x, wd, x1])
			continue
		var ya: float = floor_y + up * 0.05
		var yb: float = floor_y + up * (0.05 + h)
		var p = E(it[0], it[1], x, minf(ya, yb), x + wd, maxf(ya, yb), room, it[4])
		for bx in [x + minf(0.3, wd * 0.25), x + wd - minf(0.3, wd * 0.25)]:
			K.bolt(p, K.at(bx, floor_y - up * 0.15, floork), bx, floor_y)
		out.append(p)
		x += wd + 0.3
	return out


static func _lamp(tag: String, x: float, ceil_y: float, room: String, floork: Array = FLOORK) -> void:
	var l = E(tag, "lamp", x - 0.28, ceil_y + 0.05, x + 0.28, ceil_y + 0.21, room, {"cls": "metal", "dest": "metal", "mass": 0.04, "cut_speed": 260.0, "name_key": "p_lamp"})
	K.bolt(l, K.at(x, ceil_y - 0.15, floork), x, ceil_y)


static func _glass(tag: String) -> Dictionary:
	return {"cls": "equip", "dest": "equip", "art": "glass", "mass": 0.25, "value": 3200.0, "fragile": 0.6, "density": 0.8, "cut_speed": 260.0, "name_key": "p_lc_bridge_window", "tag": tag}


# ---------------------------------------------------------------- the carrier's hull

static func _hull() -> void:
	# edges: 0 bow chamfer, 1 fore roof, 2 bridge front (its windows), 3 bridge roof, 4 bridge
	# back, 5 hold roof, 6 the step up, 7 engine roof, 8 stern upper, 9 stern, 10 stern
	# lower, 11 keel, 12 bow foot, 13 the bow (its door)
	var fl: Array = [0.04, 0.08, 0.12, 0.16, 0.2, 0.23, 0.2433, 0.28, 0.32, 0.36, 0.4, 0.44, 0.48, 0.52, 0.56, 0.6, 0.64, 0.68, 0.72, 0.76, 0.8, 0.84, 0.88, 0.92, 0.96]
	var rf: Array = [0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95]
	K.ring(OUT, T, {2: [0.33, 0.67], 3: [0.25, 0.33, 0.75], 5: rf, 7: [0.2, 0.4, 0.6, 0.8], 9: [0.35, 0.65], 11: fl, 13: [0.067, 0.933]}, {
		"2:0": _glass("WIN-1"), "2:1": _glass("WIN-2"), "2:2": _glass("WIN-3"),
		"3:1": {"kind": "hatch", "door": true, "tag": "HT-B", "open_dir": Vector2(1.8, 0) * Geom.M, "cut_speed": 200.0},
		"9:1": {"kind": "hatch", "door": true, "tag": "HT-E", "open_dir": Vector2(0, 2.4) * Geom.M, "cut_speed": 200.0},
		"11:6": {"kind": "hatch", "door": true, "tag": "HT-H", "open_dir": Vector2(-1.8, 0) * Geom.M, "cut_speed": 200.0},
		"13:1": {"kind": "hatch", "door": true, "tag": "BOW", "open_dir": Vector2(0, -14.0) * Geom.M, "cut_speed": 160.0, "name_key": "p_lc_bow_door"},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0, "name_key": "p_hull"}, "HL")
	for t in ["WIN-1", "WIN-2", "WIN-3"]:
		for j in w.joints_of(by_tag[t]):
			j.type = "bolt"


static func _inner() -> void:
	# the bridge's deck over the hold (it holds the bridge's air)
	var bd = K.plate("BDK", K.R(6.6, -8.25, 27.4, -7.75), {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_lc_bridge_deck"}, "hull")
	K.bolt(bd, K.at(6.3, -8.0, ["hull"]), 6.6, -8.0, "weld")
	K.bolt(bd, K.at(27.7, -8.0, ["hull"]), 27.4, -8.0, "weld")
	# the engine room's bulkhead, its door low down
	var B := {"density": 1.4, "barrier": true, "cut_speed": 200.0, "name_key": "p_bulkhead"}
	var u = K.plate("BH0-U", K.R(BHX - 0.25, -IN, BHX + 0.25, DOOR), B, "hull")
	var d = K.plate("D-0", K.R(BHX - 0.25, DOOR, BHX + 0.25, IN), {"density": 1.3, "barrier": true, "cut_speed": 190.0, "door": true, "open_dir": Vector2(0, -3.2) * Geom.M}, "door")
	K.bolt(u, K.at(BHX, -IN - 0.25, ["hull"]), BHX, -IN, "weld")
	K.bolt(u, d, BHX, DOOR, "weld")
	K.bolt(d, K.at(BHX, IN + 0.25, ["hull"]), BHX, IN, "weld")
	var D := {"density": 0.9, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}
	var dk = K.plate("DK-E", K.R(110.25, 0.0, 133.0, 0.25), D, "deck")
	K.bolt(dk, K.at(110.1, 0.12, ["hull"]), 110.25, 0.12, "weld")
	# the hold's cargo mezzanine on its posts
	var mz = K.plate("MZ", K.R(64.0, 0.0, 107.0, 0.25), D, "deck")
	for px in [64.0, 80.0, 96.0, 106.7]:
		var po = K.plate("", K.R(px, 0.25, px + 0.3, IN), {"density": 1.2, "barrier": false, "cut_speed": 200.0, "name_key": "p_lc_post"}, "strut")
		K.bolt(po, mz, px + 0.15, 0.25, "weld")
		K.bolt(po, K.at(px + 0.15, IN + 0.25, ["hull"]), px + 0.15, IN, "weld")


# ---------------------------------------------------------------- B, the bridge

static func _bridge() -> void:
	var bf := ["hull"]
	_row("B", -8.25, -1.0, 9.0, 27.0, [["HELM", "console", 1.6, 1.2, {"mass": 0.25, "value": 16000.0, "fragile": 0.5, "name_key": "p_lc_helm"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["NAV", "nav", 1.2, 1.2, {"mass": 0.12, "value": 12000.0, "fragile": 0.5, "name_key": "p_lc_nav"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 600.0, "name_key": "p_ark_chair"}],
		["CARGO-C", "console", 1.4, 1.2, {"mass": 0.2, "value": 11000.0, "fragile": 0.5, "name_key": "p_lc_cargo_console"}], ["", "table", 1.6, 0.9, {"mass": 0.08, "value": 1600.0, "name_key": "p_ark_nav_table"}],
		["MANIFEST", "cabinet", 1.0, 1.6, {"mass": 0.2, "value": 9000.0, "mandatory": true, "name_key": "p_manifest"}], ["COMMS", "nav_rack", 0.9, 2.2, {"mass": 0.3, "value": 14000.0, "name_key": "p_lc_comms"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}]], [], bf)
	_row("B", -13.5, 1.0, 9.5, 26.5, [["", "screen", 1.6, 0.9, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_screen"}], 0.8, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1800.0, "name_key": "p_ark_overhead"}],
		0.8, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 4.0, ["", "screen", 1.6, 0.9, {"mass": 0.04, "value": 1800.0, "name_key": "p_lc_hold_monitor"}],
		0.8, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]], [[11.8, 13.8]], bf)
	_lamp("LAMP-B", 18.0, -13.5, "B", bf)


# ---------------------------------------------------------------- the courier on its cradle

static func _courier() -> void:
	# the cradle's saddles first, on the hold floor
	var SD := {"density": 2.0, "barrier": false, "cut_speed": 160.0, "name_key": "p_lc_saddle"}
	for i in SADDLES.size():
		var sx: float = SADDLES[i]
		var sd = K.plate("SAD-%d" % (i + 1), K.R(sx, 5.5, sx + 2.0, IN), SD, "fixture")
		K.bolt(sd, K.at(sx + 0.5, IN + 0.25, ["hull"]), sx + 0.5, IN, "weld")
		K.bolt(sd, K.at(sx + 1.5, IN + 0.25, ["hull"]), sx + 1.5, IN, "weld")
	# its hull, a ship's own: edges 0 nose low, 1 nose high, 2 roof, 3 stern high, 4 stern,
	# 5 stern low, 6 keel, 7 forefoot, 8 nose
	var before: Array = K.by_tag.keys()
	K.ring(SOUT, 0.4, {2: [0.25, 0.4, 0.5, 0.75], 4: [0.5], 6: [0.2, 0.4, 0.6, 0.8]}, {
		"2:2": {"kind": "hatch", "door": true, "tag": "HT-S", "open_dir": Vector2(1.6, 0) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.2, "barrier": true, "cut_speed": 200.0, "name_key": "p_lc_courier_hull"}, "SS")
	for t in K.by_tag.keys():
		if not before.has(t):
			hull_s.append(t)
			mine.append(t)
	# on the saddles, through its keel
	for sx in SADDLES:
		K.bolt(K.at(sx + 1.0, 5.3, ["hull"]), by_tag["SAD-%d" % (SADDLES.find(sx) + 1)], sx + 1.0, 5.5)
	# its machinery deck
	var sdk = K.plate("SDK", K.R(30.7, 0.6, 59.6, 0.85), {"density": 0.8, "barrier": false, "cut_speed": 230.0, "name_key": "p_deck"}, "deck")
	K.bolt(sdk, K.at(30.45, 0.72, ["hull"]), 30.7, 0.72, "weld")
	K.bolt(sdk, K.at(59.8, 0.72, ["hull"]), 59.6, 0.72, "weld")
	mine.append("SDK")
	var sf := ["hull", "deck"]
	# upper: the cockpit, then the cabin
	_row("S", 0.6, -1.0, 33.2, 58.5, [["SC-CON", "console", 1.4, 1.2, {"mass": 0.15, "value": 16000.0, "fragile": 0.5, "name_key": "p_lc_courier_console"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 900.0, "name_key": "p_ark_chair"}],
		["SNAV", "nav", 1.2, 1.2, {"mass": 0.1, "value": 9000.0, "fragile": 0.5, "name_key": "p_lc_courier_nav"}], ["", "seat", 0.6, 1.0, {"mass": 0.04, "value": 900.0, "name_key": "p_ark_chair"}],
		["SLS", "env", 1.4, 1.8, {"mass": 0.4, "value": 8000.0, "name_key": "p_env_control"}], ["", "bunk", 2.0, 1.4, {"mass": 0.15, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["SGAL", "module", 1.4, 1.1, {"mass": 0.2, "value": 3200.0, "name_key": "p_ark_galley"}],
		["", "o2cab", 0.7, 1.0, {"mass": 0.08, "value": 2200.0, "name_key": "p_o2cab"}], ["", "suit", 0.7, 1.9, {"mass": 0.1, "value": 5000.0, "name_key": "p_suit"}],
		["", "cabinet", 1.0, 1.6, {"mass": 0.1, "value": 2600.0, "name_key": "p_lc_courier_mail"}]], [], sf)
	_row("S", -4.1, 1.0, 37.0, 54.5, [["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 1.0, ["", "overhead", 1.2, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}],
		1.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}], 1.0, ["", "screen", 1.0, 0.6, {"mass": 0.03, "value": 1400.0, "name_key": "p_ark_screen"}]], [[43.4, 45.7]], sf)
	_lamp("S-LAMP", 47.0, -4.1, "S", sf)
	# lower: its battery, its fuel and engine, the cargo it was carrying
	_row("S", 5.1, -1.0, 34.0, 58.0, [["S-BAT", "battery", 1.4, 1.2, {"mass": 0.9, "value": 8000.0, "hazard": "battery", "name_key": "p_lc_courier_battery"}],
		["", "cargo", 1.6, 1.2, {"mass": 0.4, "value": 12000.0, "name_key": "p_lc_courier_cargo"}], ["", "cargo", 1.6, 1.2, {"mass": 0.4, "value": 12000.0, "name_key": "p_lc_courier_cargo"}],
		["", "pump", 1.0, 1.0, {"mass": 0.2, "value": 3000.0, "name_key": "p_coolant_pump"}], ["S-FUEL", "fueltank", 1.0, 1.6, {"mass": 0.4, "value": 2500.0, "name_key": "p_svc_prop"}],
		["", "toolwall", 1.0, 1.6, {"mass": 0.1, "value": 1800.0, "name_key": "p_tool_wall"}], 1.0,
		["S-ENG", "engine_s", 2.6, 2.4, {"mass": 2.2, "value": 38000.0, "fragile": 0.4, "name_key": "p_lc_courier_engine"}]], [], sf)
	_row("S", 0.85, 1.0, 34.0, 58.0, [["", "cabinet", 1.0, 0.6, {"mass": 0.05, "value": 1500.0, "name_key": "p_svc_cabinet"}], 1.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		1.0, ["", "pipe", 1.6, 0.4, {"mass": 0.04, "value": 1200.0, "name_key": "p_lc_courier_line"}]], [], sf)
	_lamp("S-LAMP2", 42.0, 0.85, "S", sf)


# ---------------------------------------------------------------- H, the hold

static func _hold() -> void:
	var crate := {"mass": 1.6, "value": 9000.0, "name_key": "p_lc_crate"}
	var small := {"mass": 0.8, "value": 6000.0, "name_key": "p_lc_crate_small"}
	# forward of the courier, low on the floor (its way out stays clear): tie-downs and lashing gear
	_row("H", IN, -1.0, 2.0, 29.5, [["", "reel", 1.0, 0.8, {"mass": 0.15, "value": 2400.0, "name_key": "p_lc_tiedown"}], 3.0, ["", "cargo", 1.2, 1.0, {"mass": 0.2, "value": 1800.0, "name_key": "p_lc_lashing"}],
		3.0, ["", "reel", 1.0, 0.8, {"mass": 0.15, "value": 2400.0, "name_key": "p_lc_tiedown"}], 3.0, ["", "cargo", 1.2, 1.0, {"mass": 0.2, "value": 1800.0, "name_key": "p_lc_lashing"}],
		3.0, ["", "reel", 1.0, 0.8, {"mass": 0.15, "value": 2400.0, "name_key": "p_lc_tiedown"}]], [[19.5, 21.5]])
	# the cradle panel beside the courier's stern
	_row("H", IN, -1.0, 61.0, 63.6, [["CRD-P", "panel", 0.9, 1.4, {"mass": 0.08, "value": 6800.0, "name_key": "p_lc_cradle_panel"}], ["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]])
	# the cargo: crates on the floor and on the mezzanine, the lights under it
	_row("H", IN, -1.0, 64.5, 109.4, [["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate],
		["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate],
		["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "cargo", 2.4, 2.2, crate], ["", "lift", 1.4, 2.0, {"mass": 0.6, "value": 8800.0, "name_key": "p_lc_forklift"}]],
		[[79.9, 80.4], [95.9, 96.4], [103.1, 105.0], [106.6, 107.1]])
	_row("H", 0.0, -1.0, 64.6, 106.6, [["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small],
		["", "barrel", 1.0, 1.4, {"mass": 0.3, "value": 1800.0, "name_key": "p_lc_drum"}], ["", "barrel", 1.0, 1.4, {"mass": 0.3, "value": 1800.0, "name_key": "p_lc_drum"}],
		["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small],
		["", "barrel", 1.0, 1.4, {"mass": 0.3, "value": 1800.0, "name_key": "p_lc_drum"}], ["", "cargo", 2.0, 1.8, small], ["", "cargo", 2.0, 1.8, small]])
	_row("H", 0.25, 1.0, 64.6, 106.6, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}], 4.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}],
		4.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_lc_cargo_scanner"}], 4.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}],
		4.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}]])
	# under the hold's roof: the winch (under the bridge deck), lights and cameras along it
	var wc = E("WCH", "reel", 9.0, -7.75 + 0.05, 11.4, -6.45, "H", {"mass": 0.9, "value": 14000.0, "name_key": "p_lc_winch"})
	K.bolt(wc, by_tag["BDK"], 9.4, -7.75)
	K.bolt(wc, by_tag["BDK"], 11.0, -7.75)
	_row("H", -IN, 1.0, 29.0, 109.0, [["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}], 5.0, ["", "insp", 0.8, 0.7, {"mass": 0.05, "value": 4800.0, "name_key": "p_lc_hold_camera"}],
		5.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}], 5.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}],
		5.0, ["", "insp", 0.8, 0.7, {"mass": 0.05, "value": 4800.0, "name_key": "p_lc_hold_camera"}], 5.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}],
		5.0, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}], 5.0, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1500.0, "name_key": "p_lc_hold_light"}],
		5.0, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1800.0, "name_key": "p_lc_cargo_scanner"}]])
	# the hold's two overhead cranes over the cargo, parked high
	for cx in [72.0, 90.0]:
		var cr = E("", "hook", cx, -7.45, cx + 1.4, -4.6, "H", {"mass": 0.8, "value": 15000.0, "name_key": "p_lc_hold_crane"})
		K.bolt(cr, K.at(cx + 0.3, -7.75, ["hull"]), cx + 0.3, -7.5)
		K.bolt(cr, K.at(cx + 1.1, -7.75, ["hull"]), cx + 1.1, -7.5)
	_lamp("LAMP-H", 20.0, -7.75, "H", ["hull"])
	_lamp("LAMP-H2", 86.0, 0.25, "H")


# ---------------------------------------------------------------- E, the engine room

static func _engines() -> void:
	_row("E", 0.0, -1.0, 110.7, 132.8, [["BAT-1", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["BAT-2", "battery", 1.8, 1.6, {"mass": 1.4, "value": 12000.0, "hazard": "battery", "name_key": "p_battery"}],
		["SWB-P", "swb", 1.2, 2.6, {"mass": 0.4, "value": 7000.0, "name_key": "p_swb"}], ["PDU-E", "swb", 0.9, 2.2, {"mass": 0.3, "value": 6000.0, "name_key": "p_pdu"}],
		["GEN-1", "gen", 1.8, 1.8, {"mass": 1.4, "value": 22000.0, "name_key": "p_fuel_cell"}], ["", "panel", 0.8, 1.2, {"mass": 0.05, "value": 3800.0, "name_key": "p_lc_engine_panel"}],
		["ENV-E", "env", 1.6, 1.8, {"mass": 0.5, "value": 11000.0, "name_key": "p_env_control"}], ["", "bunk", 2.0, 1.4, {"mass": 0.15, "value": 1500.0, "name_key": "p_crew_bunk"}],
		["", "locker", 0.8, 1.8, {"mass": 0.1, "value": 900.0, "name_key": "p_locker"}], ["", "toolwall", 1.2, 2.0, {"mass": 0.12, "value": 2400.0, "name_key": "p_tool_wall"}]])
	_row("E", -8.5, 1.0, 112.6, 135.5, [["", "panel", 0.8, 0.8, {"mass": 0.05, "value": 3200.0, "name_key": "p_ev_dcdc"}], 0.8, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}],
		0.8, ["", "overhead", 1.6, 0.4, {"mass": 0.04, "value": 1600.0, "name_key": "p_ark_overhead"}], 0.8, ["", "pipe", 2.0, 0.4, {"mass": 0.05, "value": 1600.0, "name_key": "p_lc_fuel_main"}],
		0.8, ["", "sensor", 0.5, 0.4, {"mass": 0.02, "value": 1200.0, "name_key": "p_ark_sensor_node"}]])
	_lamp("LAMP-E", 122.0, -8.5, "E")
	_row("E", IN, -1.0, 110.7, 134.8, [["ENG-1", "eng_core", 2.6, 3.0, {"mass": 2.8, "value": 62000.0, "fragile": 0.4, "name_key": "p_lc_main_engine"}],
		["ENG-2", "eng_core", 2.6, 3.0, {"mass": 2.8, "value": 62000.0, "fragile": 0.4, "name_key": "p_lc_main_engine"}],
		["FUEL-1", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}], ["FUEL-2", "fueltank", 1.2, 2.0, {"mass": 0.6, "value": 3400.0, "name_key": "p_svc_prop"}],
		["MCP-1", "pump", 1.4, 1.4, {"mass": 0.6, "value": 9000.0, "name_key": "p_coolant_pump"}], ["", "filter", 0.9, 1.4, {"mass": 0.15, "value": 2500.0, "name_key": "p_ark_filter"}],
		["", "pump", 1.2, 1.2, {"mass": 0.4, "value": 6400.0, "name_key": "p_lc_fuel_pump"}], ["", "gastank", 0.5, 1.4, {"mass": 0.08, "value": 900.0, "hazard": "gas_tank", "name_key": "p_ark_fire_bottle"}]])
	_row("E", 0.25, 1.0, 110.7, 132.8, [["", "cabinet", 1.2, 0.6, {"mass": 0.06, "value": 1500.0, "name_key": "p_svc_cabinet"}], 0.8, ["", "o2cab", 0.7, 1.0, {"mass": 0.1, "value": 2200.0, "name_key": "p_o2cab"}],
		0.8, ["", "junction", 0.6, 0.4, {"mass": 0.03, "value": 600.0, "name_key": "p_junction"}]])
	_lamp("LAMP-E2", 126.0, 0.25, "E")
	# the main nozzles on the stern, clear of its hatch
	for i in 2:
		var y0: float = -5.2 if i == 0 else 2.4
		var nz = E("NOZ-%d" % (i + 1), "nozzle", 140.05, y0, 142.6, y0 + 2.8, "", {"mass": 1.2, "value": 18000.0, "name_key": "p_lc_nozzle"})
		K.bolt(nz, K.at(139.8, y0 + 0.6, ["hull"]), 140.0, y0 + 0.6)
		K.bolt(nz, K.at(139.8, y0 + 2.2, ["hull"]), 140.0, y0 + 2.2)


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
	_c("p3", "SWB-P", "PDU-E")
	_c("p4", "SWB-P", "GEN-1")
	_c("p5", "SWB-P", "ENV-E")
	_c("p6", "SWB-P", "MCP-1", [Vector2(_cen("SWB-P").x, 1.0), Vector2(_cen("MCP-1").x, 1.0)])
	_c("p7", "PDU-E", "ENG-1", [Vector2(_cen("PDU-E").x, 1.2), Vector2(_cen("ENG-1").x, 1.2)])
	_c("p8", "PDU-E", "ENG-2", [Vector2(_cen("PDU-E").x, 1.4), Vector2(_cen("ENG-2").x, 1.4)])
	_c("p9", "SWB-P", "LAMP-E")
	# forward along the hold's roof: the winch, the cradle panel, the hold's lights, the bridge
	_c("p10", "SWB-P", "WCH", [Vector2(111.0, -7.0), Vector2(10.2, -7.0)])
	_c("p11", "SWB-P", "CRD-P", [Vector2(111.0, 5.0), Vector2(62.4, 5.0)])
	_c("p12", "SWB-P", "LAMP-H", [Vector2(111.0, -6.8), Vector2(20.0, -6.8)])
	_c("p13", "SWB-P", "LAMP-H2", [Vector2(111.0, 0.9), Vector2(86.0, 0.9)])
	_c("p14", "SWB-P", "HELM", [Vector2(111.0, -7.2), Vector2(26.0, -7.2), Vector2(26.0, -9.2), Vector2(_cen("HELM").x, -9.2)])
	_c("p15", "HELM", "NAV")
	_c("p16", "HELM", "CARGO-C")
	_c("p17", "HELM", "COMMS")
	_c("p18", "HELM", "LAMP-B")
	# the courier's own circuit off its own battery
	_c("s1", "S-BAT", "SC-CON", [Vector2(_cen("S-BAT").x, -0.4), Vector2(_cen("SC-CON").x, -0.4)])
	_c("s2", "SC-CON", "SNAV")
	_c("s3", "SC-CON", "S-LAMP")
	_c("s4", "S-BAT", "SLS", [Vector2(_cen("S-BAT").x, -0.2), Vector2(_cen("SLS").x, -0.2)])
	_c("s5", "S-BAT", "S-LAMP2")
	_p("sf1", "sfuel", "S-FUEL", "S-ENG")
	_p("w1", "loop", "MCP-1", "GEN-1", [Vector2(_cen("MCP-1").x, 0.8), Vector2(_cen("GEN-1").x, 0.8)])
	_p("f1", "fuel", "FUEL-1", "ENG-1")
	_p("f2", "fuel", "FUEL-2", "ENG-2")
	_p("f3", "fuel", "FUEL-1", "FUEL-2")
	_p("f4", "fuel", "FUEL-1", "GEN-1", [Vector2(_cen("FUEL-1").x, 1.6), Vector2(_cen("GEN-1").x, 1.6)])


static func _controls() -> void:
	var sw = by_tag["SWB-P"]
	K.ctrl("K-M1", "switch", sw, _cen("SWB-P") + Vector2(-0.3, -0.8), {"target": "K-M1", "state": true, "hidden_room": "E"})
	K.ctrl("K-M2", "switch", sw, _cen("SWB-P") + Vector2(0.0, -0.8), {"target": "K-M2", "state": true, "hidden_room": "E"})
	K.ctrl("E-1", "test", sw, _cen("SWB-P") + Vector2(0.3, -0.8), {"medium": "volt", "target": "bus", "hidden_room": "E"})
	# the cradle panel: four locks (stern first) and the winch
	var cp = by_tag["CRD-P"]
	for i in 4:
		K.ctrl("CL-%d" % (i + 1), "switch", cp, _cen("CRD-P") + Vector2(-0.3 + (i % 2) * 0.6, -0.5 + int(i / 2) * 0.35), {"target": "CL-%d" % (i + 1), "state": true, "hidden_room": "H"})
	K.ctrl("WINCH", "switch", cp, _cen("CRD-P") + Vector2(0.0, 0.3), {"target": "WINCH", "state": false, "hidden_room": "H"})
	# the courier: its battery switch inside, its air and fuel ports outside its keel
	K.ctrl("SK", "switch", by_tag["S-BAT"], _cen("S-BAT") + Vector2(0.3, -0.3), {"target": "SK", "state": true, "hidden_room": "S"})
	K.ctrl("G-S", "port", K.at(45.0, 5.3, ["hull"]), Vector2(45.0, 5.75), {"medium": "gas", "target": "S", "hidden_room": "H"})
	K.ctrl("PSF", "port", K.at(51.8, 5.3, ["hull"]), Vector2(51.8, 5.75), {"medium": "fuel", "target": "sfuel", "hidden_room": "H"})
	K.ctrl("PL", "port", by_tag["MCP-1"], _cen("MCP-1") + Vector2(0, -0.5), {"medium": "water", "target": "loop", "hidden_room": "E"})
	K.ctrl("PF", "port", by_tag["FUEL-1"], _cen("FUEL-1") + Vector2(0, -0.8), {"medium": "fuel", "target": "fuel", "hidden_room": "E"})
	K.ctrl("G-H", "port", K.at(24.0, 7.8, ["hull"]), Vector2(24.0, 8.2), {"medium": "gas", "target": "H"})
	K.ctrl("G-E", "port", K.at(126.0, 7.8, ["hull"]), Vector2(126.0, 8.2), {"medium": "gas", "target": "E"})
	K.ctrl("G-B", "port", K.at(27.3, -11.0, ["hull"]), Vector2(27.65, -11.0), {"medium": "gas", "target": "B"})
	K.ctrl("AUX-P", "socket", K.at(100.0, 7.8, ["hull"]), Vector2(100.0, 8.2), {"target": "aux", "state": false})
	for t in ["HT-B", "HT-E", "HT-H", "BOW"]:
		K.door(t, "")
	K.door("HT-S", "H")
	K.door("D-0", "E")


static func _rooms() -> void:
	var inn := K.mp(K.inner(OUT, T))
	var parts := Geometry2D.intersect_polygons(inn, K.R(5.0, -20.0, 29.0, -8.25))
	if not parts.is_empty():
		w.add_room("B", parts[0])
	parts = Geometry2D.intersect_polygons(inn, K.R(-1.0, -7.75, BHX - 0.25, 9.0))
	if not parts.is_empty():
		w.add_room("H", parts[0])
	parts = Geometry2D.intersect_polygons(inn, K.R(BHX + 0.25, -12.0, 141.0, 9.0))
	if not parts.is_empty():
		w.add_room("E", parts[0])
	w.add_room("S", K.mp(K.inner(SOUT, 0.4)))


static func meta() -> Dictionary:
	var vols := {}
	vols["sfuel"] = {"fluid": "fuel", "amount": 0.25, "nets": ["sfuel"], "piece": "S-FUEL", "port": "PSF", "full": 0.4, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	vols["loop"] = {"fluid": "water", "amount": 0.25, "nets": ["loop"], "piece": "MCP-1", "port": "PL", "full": 0.3, "leak": 0.1, "leak_min": 0.004, "pump": [0.1, 0.006]}
	vols["fuel"] = {"fluid": "fuel", "amount": 0.5, "nets": ["fuel"], "piece": "FUEL-1", "port": "PF", "full": 0.8, "content": 1.0, "leak": 0.12, "pump": [0.1, 0.008]}
	var names := {"B": "room_lcB", "H": "room_lcH", "E": "room_lcE", "S": "room_lcS"}
	# (the courier's lamps run off its own battery, not the bus)
	var lamps := {"B": "LAMP-B", "H": "LAMP-H", "E": "LAMP-E"}
	return {
		"id": "lc140",
		"name": "LC-140 SHELL MOUNTAIN",
		"title": ["LC-140「壳山」载舰运输船 · 140 m", "LC-140 SHELL MOUNTAIN · SHIP CARRIER · 140 m"],
		"contract": "LC-140",
		"length": 142.6,
		"value": {"total": VALUE, "metal": 30000.0, "bonus": BONUS},
		"clamps": [[70.0, 8.0], [122.0, 8.0]],
		"room_names": names,
		"gas": {"rooms": {"B": 101.0, "H": 101.0, "E": 101.0, "S": 62.0}, "vessels": {}, "valves": [], "value": 12000.0},
		"liner": {"pods": {}, "glazings": [{"room": "B", "panes": ["WIN-1", "WIN-2", "WIN-3"], "kpa": 20.0}]},
		"nested": {"pieces": mine, "hull": hull_s, "room": "S", "hold": "H", "battery": "SK", "fuel": "sfuel", "locks": ["CL-1", "CL-2", "CL-3", "CL-4"],
			"door": "BOW", "door_ctrl": "BOW", "winch": "WINCH", "winch_piece": "WCH", "bonus": BONUS, "lurch_keep": 0.5, "lurch_dent": 0.5,
			"exit": [-64.0, 0.0], "time": 12.0},
		"power": {
			"bus": "SWB-P",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p1", "switch": "K-M1", "charge": 0.85, "drain": 0.0003},
				{"piece": "BAT-2", "kind": "battery", "volts": 440.0, "local_volts": 48.0, "cable": "p2", "switch": "K-M2", "charge": 0.8, "drain": 0.0003},
			],
			"isolated": [{"piece": "S-BAT", "volts": 28.0, "charge": 0.7, "switch": "SK"}],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"water": 300.0, "fuel": 6000.0}},
		"ctrls_cfg": {"G-H": {"rate": 70.0}, "G-E": {"rate": 34.0}, "G-B": {"rate": 22.0}, "G-S": {"rate": 18.0}},
		"labels": {"SWB-P": "BUS", "BAT-1": "BAT 1", "BAT-2": "BAT 2", "CRD-P": "CRADLE", "WCH": "WINCH", "S-BAT": "BAT", "SC-CON": "COURIER", "MANIFEST": "MANIFEST", "MCP-1": "PUMP"},
		"hints": {},
		"market": {
			"class": "LC", "name": ["壳山级载舰运输船", "SHELL MOUNTAIN-CLASS SHIP CARRIER"], "time": 60.0,
			"rooms": {"B": [0.2, 40.0, 101.0], "H": [0.2, 40.0, 101.0], "E": [0.2, 40.0, 101.0], "S": [0.3, 20.0, 80.0]},
			"charge": {"BAT-1": [0.4, 1.0], "BAT-2": [0.4, 1.0], "S-BAT": [0.3, 0.9]},
			"fluids": {},
			"knockable": ["NAV", "CARGO-C"],
			"drift": [],
			"section_x": 85.0,
			"slots": {"fire_system": {"x": FIRE_X, "y0": IN - 1.4, "y1": IN, "base": [FIRE_BASE, IN], "room": "H", "port": [FIRE_X + 0.4, IN - 1.33]}},
			"mechanisms": true,
		},
		"procedures": {
			"MANIFEST": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 200.0},
				{"do": "operate", "ctrl": "HT-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 20.0},
				{"do": "free", "piece": "MANIFEST"},
				{"do": "deliver", "piece": "MANIFEST", "zone": "equip"},
			],
		},
	}


const BONUS := 900000.0
const VALUE := 1722300.0
const FIRE_X := 18.0
const FIRE_BASE := "HL11-22"
