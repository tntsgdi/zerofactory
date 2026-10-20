class_name Md160Author
# Authoring script for MD-160 "Slingshot", a 160 m mass-driver barge (exotic batch
# 06/10, design/ships/MD-160_弹弓_设计稿.md and MD-160_线稿.png, as drawn). Not part
# of the game: tools/ship_export.gd runs it and writes ships/md160.json.
# Metres, x bow (0) to the nozzles (~163), y down.
#
# No hull but the control cabin forward and the power module aft: between them the
# open 122 m acceleration trough, an upper and a lower rail of four sections each on
# their tensioners, posts between them, three 1.5 t flywheels on their bearings with
# a brake caliper over each, two capacitor banks on the upper rail, the 30 m launch
# cradle with its clamps and a cargo box on it.
# What it asks of you (scripts/flywheel.gd): the wheels still turn at 20,000 rpm;
# each comes to rest only braked with its brake cooling on (braked dry its caliper
# burns out), and freed or cut while still turning it tears loose. The rails come
# off their tensioners from the tail to the head, and are cut only once slack. The
# capacitor banks keep their charge with the power off: discharge them from the
# cabin first.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const OUT_C := [Vector2(1.2, -5.0), Vector2(16.8, -5.0), Vector2(18.0, -3.8), Vector2(18.0, 3.8), Vector2(16.8, 5.0), Vector2(1.2, 5.0),
	Vector2(0.0, 3.8), Vector2(0.0, -3.8)]
const OUT_P := [Vector2(149.2, -6.0), Vector2(158.8, -6.0), Vector2(160.0, -4.8), Vector2(160.0, 4.8), Vector2(158.8, 6.0), Vector2(149.2, 6.0),
	Vector2(148.0, 4.8), Vector2(148.0, -4.8)]
const SEC := [18.0, 48.5, 79.0, 109.5, 140.0]
const WHEELS := [40.0, 75.0, 110.0]
const WR := 5.2

static var w
static var by_tag := {}


static func build(world) -> void:
	K.begin(world, "MD160")
	w = world
	by_tag = K.by_tag
	_cabin()
	_rails()
	_wheels()
	_caps()
	_power()
	_cradle()
	_fitout()
	_lines()
	_fit_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "MD160")
	w = world
	_rooms()


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out: Array = []
	for i in n:
		out.append(c + Vector2.from_angle(TAU * (i + 0.5) / n) * r)
	return K.mp(out)


static func _sec(top: bool, x: float) -> String:
	for i in SEC.size() - 1:
		if x >= SEC[i] and x <= SEC[i + 1]:
			return ("RU-%d" if top else "RL-%d") % (i + 1)
	return ""


# equipment against a ring's floor (y1) or ceiling (y0)
static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, opts: Dictionary, on_floor: bool, wall_y: float):
	# a hand's breadth off the wall it is bolted to: freed, it must not start pressed into the hull
	if on_floor:
		y1 -= 0.05
	else:
		y0 += 0.05
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), opts)
	var yb := y1 if on_floor else y0
	for x in [x0 + 0.3, x1 - 0.3]:
		K.bolt(p, K.at(x, wall_y, ["hull"]), x, yb)
	return p


# ---------------------------------------------------------------- the control cabin

static func _cabin() -> void:
	K.ring(OUT_C, T, {0: [0.45, 0.58]}, {"0:1": {"kind": "hatch", "door": true, "tag": "HT-C", "open_dir": Vector2(2.2, 0) * Geom.M, "cut_speed": 200.0}},
		{"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HC")
	E("CON-C", "console", 2.0, 3.0, 6.0, 4.55, {"mass": 0.4, "value": 12000.0, "fragile": 0.5, "room": "C", "mandatory": true, "name_key": "p_driver_console"}, true, 4.75)
	E("AV-C", "nav_rack", 10.6, -4.55, 13.0, -1.5, {"mass": 0.3, "value": 10000.0, "fragile": 0.5, "room": "C", "name_key": "p_avionics"}, false, -4.75)
	E("BAT-C", "battery", 10.0, 2.0, 13.0, 4.55, {"mass": 1.0, "value": 8000.0, "fragile": 0.4, "room": "C", "hazard": "battery", "name_key": "p_battery"}, true, 4.75)
	E("DIST-C", "swb", 13.6, 1.0, 16.4, 4.55, {"mass": 0.5, "value": 6000.0, "fragile": 0.4, "room": "C", "name_key": "p_swb"}, true, 4.75)
	K.lamp("LAMP-C", 4.0, -4.55, "C", K.at(4.0, -4.75, ["hull"]))
	var dk = K.equip("DOCK", "dock", K.rect(-1.2, -1.4, 0.0, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(0.2, -1.0, ["hull"]), 0.0, -1.0)
	K.bolt(dk, K.at(0.2, 1.0, ["hull"]), 0.0, 1.0)


# ---------------------------------------------------------------- the rails and the posts

static func _rails() -> void:
	var S := {"density": 2.0, "barrier": false, "cut_speed": 130.0, "name_key": "p_driver_rail"}
	for i in SEC.size() - 1:
		var x0: float = SEC[i]
		var x1: float = SEC[i + 1]
		var u = K.plate("RU-%d" % (i + 1), K.R(x0, -7.0, x1, -5.9), S, "beam")
		var l = K.plate("RL-%d" % (i + 1), K.R(x0, 5.9, x1, 7.0), S, "beam")
		if i > 0:
			K.bolt(u, by_tag["RU-%d" % i], x0, -6.45, "bolt")
			K.bolt(l, by_tag["RL-%d" % i], x0, 6.45, "bolt")
	# the rails' forward ends on the cabin
	for e in [["PC-U", -7.0, -3.4, "RU-1"], ["PC-L", 3.4, 7.0, "RL-1"]]:
		var pc = K.plate(e[0], K.R(18.0, e[1], 18.6, e[2]), {"density": 1.8, "barrier": false, "cut_speed": 150.0, "name_key": "p_post"}, "strut")
		K.bolt(pc, by_tag[e[3]], 18.3, -6.45 if e[0] == "PC-U" else 6.45, "weld")
		K.bolt(pc, K.at(17.8, -3.5 if e[0] == "PC-U" else 3.5, ["hull"]), 18.0, -3.5 if e[0] == "PC-U" else 3.5, "weld")
	var posts: Array = [24.0, 57.0, 92.0, 117.6]
	for c in WHEELS:
		posts.append(c - WR - 0.4)
		posts.append(c + WR)
	posts.sort()
	var k := 0
	for x in posts:
		k += 1
		var po = K.plate("PO-%d" % k, K.R(x, -5.9, x + 0.4, 5.9), {"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_post"}, "strut")
		K.bolt(po, by_tag[_sec(true, x + 0.2)], x + 0.2, -5.9, "weld")
		K.bolt(po, by_tag[_sec(false, x + 0.2)], x + 0.2, 5.9, "weld")
	# the berth holds the cabin and the power module by their bellies, the lower rail at its middle
	K.clamp(1, 12.0, 5.0, 4.8)
	K.clamp(2, 80.0, 7.0, 6.8, ["beam"])


# ---------------------------------------------------------------- the flywheels and their brakes

static func _wheels() -> void:
	var i := 0
	for c in WHEELS:
		i += 1
		var fw = K.equip("FW-%d" % i, "reel", K.rect(c - WR, -WR, c + WR, WR), {"mass": 1.5, "value": 28000.0, "fragile": 0.3, "name_key": "p_flywheel"}, _circle(Vector2(c, 0.0), WR, 24))
		var xe := sqrt(WR * WR - 1.0)
		var pl = w.piece_at(K.p(c - WR - 0.2, 0.0), ["strut"])
		var pr = w.piece_at(K.p(c + WR + 0.2, 0.0), ["strut"])
		for y in [-1.0, 1.0]:
			K.bolt(fw, pl, c - xe, y, "lock")
			K.bolt(fw, pr, c + xe, y, "lock")
		var br = K.equip("BRK-%d" % i, "brake", K.rect(c - 1.0, -5.9, c + 1.0, -5.25), {"mass": 0.15, "value": 3000.0, "fragile": 0.4, "name_key": "p_wheel_brake"})
		K.bolt(br, by_tag[_sec(true, c - 0.6)], c - 0.6, -5.9)
		K.bolt(br, by_tag[_sec(true, c + 0.6)], c + 0.6, -5.9)


static func _caps() -> void:
	for e in [["CAP-1", 55.0, "RU-2"], ["CAP-2", 95.0, "RU-3"]]:
		var x0: float = e[1]
		var cp = K.equip(e[0], "cap", K.rect(x0, -8.8, x0 + 6.0, -7.0), {"mass": 1.2, "value": 12000.0, "fragile": 0.4, "name_key": "p_cap_bank"})
		K.bolt(cp, by_tag[e[2]], x0 + 0.6, -7.0)
		K.bolt(cp, by_tag[e[2]], x0 + 5.4, -7.0)


# ---------------------------------------------------------------- the launch cradle

static func _cradle() -> void:
	var post = w.piece_at(K.p(117.8, 0.0), ["strut"])
	for e in [["CR-U", -4.2, -3.0], ["CR-L", 3.0, 4.2]]:
		var cr = K.plate(e[0], K.R(118.0, e[1], 148.0, e[2]), {"density": 1.8, "barrier": false, "cut_speed": 140.0, "name_key": "p_cradle_rail"}, "beam")
		K.bolt(cr, post, 118.0, (e[1] + e[2]) * 0.5, "weld")
		K.bolt(cr, K.at(148.2, (e[1] + e[2]) * 0.5, ["hull"]), 148.0, (e[1] + e[2]) * 0.5, "weld")
	var bar = K.equip("CRADLE", "cargo", K.rect(120.0, -3.0, 146.0, -1.6), {"mass": 6.0, "value": 22000.0, "fragile": 0.25, "name_key": "p_launch_cradle"})
	bar.set_meta("segments", [[128.7, -3.0, 128.7, -1.6], [137.3, -3.0, 137.3, -1.6]])
	var k := 0
	for x in [121.0, 127.0, 139.0, 145.0]:
		k += 1
		K.bolt(bar, by_tag["CR-U"], x, -3.0, "lock", "CL-%d" % k)
	var cg = K.equip("CARGO-L", "cargo", K.rect(126.0, -1.6, 138.0, 3.0), {"mass": 4.0, "value": 12000.0, "fragile": 0.3, "name_key": "p_ro_cargo"})
	K.bolt(cg, bar, 128.0, -1.6, "lock")
	K.bolt(cg, bar, 136.0, -1.6, "lock")
	K.bolt(cg, by_tag["CR-L"], 128.0, 3.0, "lock")
	K.bolt(cg, by_tag["CR-L"], 136.0, 3.0, "lock")


# ---------------------------------------------------------------- the power module

static func _power() -> void:
	K.ring(OUT_P, T, {0: [0.1, 0.3]}, {"0:1": {"kind": "hatch", "door": true, "tag": "HT-P", "open_dir": Vector2(1.9, 0) * Geom.M, "cut_speed": 200.0}},
		{"density": 1.6, "barrier": true, "cut_speed": 210.0}, "HP")
	E("GEN-P", "gen", 150.3, 1.5, 154.0, 5.55, {"mass": 2.4, "value": 26000.0, "fragile": 0.35, "room": "P", "name_key": "p_generator"}, true, 5.75)
	E("BAT-P", "battery", 154.3, 2.5, 156.7, 5.55, {"mass": 1.8, "value": 12000.0, "fragile": 0.4, "room": "P", "hazard": "battery", "name_key": "p_battery"}, true, 5.75)
	E("RAD-P", "radiator", 152.0, -5.55, 155.6, -2.0, {"mass": 1.0, "value": 6000.0, "fragile": 0.35, "room": "P", "name_key": "p_radiator"}, false, -5.75)
	for e in [["ENG-1", -4.5, -1.2], ["ENG-2", 1.2, 4.5]]:
		var en = K.equip(e[0], "eng_core", K.rect(156.8, e[1], 159.55, e[2]), {"mass": 2.2, "value": 16000.0, "fragile": 0.3, "room": "P", "name_key": "p_engine"})
		var ym: float = (e[1] + e[2]) * 0.5
		K.bolt(en, K.at(159.8, ym - 0.8, ["hull"]), 159.55, ym - 0.8)
		K.bolt(en, K.at(159.8, ym + 0.8, ["hull"]), 159.55, ym + 0.8)
		var nz = K.equip("NOZ-" + e[0].substr(4), "nozzle", K.rect(160.0, e[1] - 0.3, 163.0, e[2] + 0.3), {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 160.0, "name_key": "p_nozzle"},
			K.mp([Vector2(160.0, e[1] + 0.4), Vector2(163.0, e[1] - 0.3), Vector2(163.0, e[2] + 0.3), Vector2(160.0, e[2] - 0.4)]))
		K.bolt(nz, K.at(159.8, ym, ["hull"]), 160.0, ym)
	K.clamp(3, 154.0, 6.0, 5.8)
	K.lamp("LAMP-P", 156.2, -5.55, "P", K.at(156.2, -5.75, ["hull"]))


# ---------------------------------------------------------------- the fit-out (player 2026-10-19: fill it with what a mass driver carries)

# the free stretches of the trough between its posts (no wheel in them)
const BAYS := [[24.4, 34.4], [45.6, 57.0], [57.4, 69.4], [80.6, 92.0], [92.4, 104.4]]


static func _fitout() -> void:
	# the linear motor: a stator coil under the upper rail and over the lower one in
	# every free stretch (the upper ones fed from the capacitor banks)
	var k := 0
	for b in BAYS:
		k += 1
		var x0: float = b[0] + 0.4
		var x1: float = b[1] - 0.4
		for e in [["U", -5.9, -4.9, true], ["L", 4.9, 5.9, false]]:
			var cl = K.equip("COIL-%s%d" % [e[0], k], "module", K.rect(x0, e[1], x1, e[2]), {"mass": 0.9, "value": 5000.0, "fragile": 0.35, "name_key": "p_stator_coil"})
			var yb: float = e[1] if e[3] else e[2]
			for x in [x0 + 0.5, x1 - 0.5]:
				K.bolt(cl, by_tag[_sec(e[3], x)], x, yb)
	# each wheel: its magnetic bearing controller on its forward post, its brake's
	# cooler beside the caliper
	var i := 0
	for c in WHEELS:
		i += 1
		var po = w.piece_at(K.p(c - WR - 0.2, 0.0), ["strut"])
		var mb = K.equip("MBC-%d" % i, "swb", K.rect(c - WR - 2.0, -3.0, c - WR - 0.4, -1.0), {"mass": 0.2, "value": 6000.0, "fragile": 0.45, "name_key": "p_bearing_ctrl"})
		K.bolt(mb, po, c - WR - 0.4, -2.5)
		K.bolt(mb, po, c - WR - 0.4, -1.5)
		var bc = K.equip("BC-%d" % i, "radiator", K.rect(c + 1.4, -5.9, c + 3.4, -5.0), {"mass": 0.15, "value": 2500.0, "fragile": 0.35, "name_key": "p_brake_cooler"})
		K.bolt(bc, by_tag[_sec(true, c + 1.7)], c + 1.7, -5.9)
		K.bolt(bc, by_tag[_sec(true, c + 3.1)], c + 3.1, -5.9)
	# position sensors on the plain posts, feeder junction boxes under the lower rail
	k = 0
	for px in [24.0, 57.0, 92.0]:
		k += 1
		var po = w.piece_at(K.p(px + 0.2, 0.0), ["strut"])
		var ps = K.equip("POS-%d" % k, "insp", K.rect(px + 0.4, -0.4, px + 1.2, 0.4), {"mass": 0.05, "value": 2500.0, "fragile": 0.6, "name_key": "p_pos_sensor"})
		K.bolt(ps, po, px + 0.4, -0.2)
		K.bolt(ps, po, px + 0.4, 0.2)
	k = 0
	for fx in [28.0, 64.0, 86.0]:
		k += 1
		var fb = K.equip("FEED-%d" % k, "swb", K.rect(fx, 7.0, fx + 2.0, 8.0), {"mass": 0.1, "value": 1800.0, "fragile": 0.4, "name_key": "p_junction"})
		K.bolt(fb, by_tag[_sec(false, fx + 0.3)], fx + 0.3, 7.0)
		K.bolt(fb, by_tag[_sec(false, fx + 1.7)], fx + 1.7, 7.0)
	# the cradle: its pusher plate on the last post, a clamp actuator over each clamp
	var pp = w.piece_at(K.p(117.8, 0.0), ["strut"])
	var pu = K.equip("PUSHER", "panel", K.rect(118.0, -2.8, 119.2, 2.8), {"mass": 0.5, "value": 3000.0, "fragile": 0.25, "name_key": "p_pusher"})
	K.bolt(pu, pp, 118.0, -2.0)
	K.bolt(pu, pp, 118.0, 2.0)
	k = 0
	for x in [121.0, 127.0, 139.0, 145.0]:
		k += 1
		var ca = K.equip("CLA-%d" % k, "panel", K.rect(x - 0.6, -5.2, x + 0.6, -4.2), {"mass": 0.08, "value": 1500.0, "fragile": 0.4, "name_key": "p_clamp_act"})
		K.bolt(ca, by_tag["CR-U"], x - 0.3, -4.2)
		K.bolt(ca, by_tag["CR-U"], x + 0.3, -4.2)
	# the cabin: comms and air under the roof, the launch sequencer on the floor
	E("COMMS-C", "console", 4.8, -4.55, 7.4, -3.0, {"mass": 0.2, "value": 4000.0, "fragile": 0.5, "room": "C", "name_key": "p_comms"}, false, -4.75)
	E("AHU-C", "env", 13.4, -4.55, 16.4, -2.8, {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "C", "name_key": "p_ahu"}, false, -4.75)
	E("SEQ-C", "nav_rack", 7.6, 2.4, 9.6, 4.55, {"mass": 0.3, "value": 8000.0, "fragile": 0.5, "room": "C", "name_key": "p_sequencer"}, true, 4.75)
	# the power module: power conditioning by the hatch, the inverter on the generator,
	# the coolant pump under the radiator
	var pc = K.equip("PCU-P", "swb", K.rect(148.45, -4.4, 149.8, -1.2), {"mass": 0.3, "value": 5000.0, "fragile": 0.4, "room": "P", "name_key": "p_inverter"})
	K.bolt(pc, K.at(148.2, -3.8, ["hull"]), 148.45, -3.8)
	K.bolt(pc, K.at(148.2, -1.8, ["hull"]), 148.45, -1.8)
	var iv = K.equip("INV-P", "cap", K.rect(150.6, 0.0, 153.8, 1.5), {"mass": 0.4, "value": 6000.0, "fragile": 0.4, "room": "P", "name_key": "p_power_board"})
	K.bolt(iv, by_tag["GEN-P"], 151.0, 1.5)
	K.bolt(iv, by_tag["GEN-P"], 153.4, 1.5)
	var cp = K.equip("CPUMP-P", "pump", K.rect(152.4, -2.0, 155.0, -0.6), {"mass": 0.4, "value": 3500.0, "fragile": 0.35, "room": "P", "name_key": "p_coolant_pump"})
	K.bolt(cp, by_tag["RAD-P"], 152.8, -2.0)
	K.bolt(cp, by_tag["RAD-P"], 154.6, -2.0)


static func _fit_lines() -> void:
	# the capacitor banks feed the upper coils
	for e in [["d1", "CAP-1", 55.6, "COIL-U2"], ["d2", "CAP-1", 60.4, "COIL-U3"], ["d4", "CAP-2", 100.4, "COIL-U5"]]:
		K.line(e[0], "cable", "power", e[1], Vector2(e[2], -7.0), e[3], Vector2(e[2], -5.9))
	K.line("d3", "cable", "power", "CAP-2", Vector2(95.2, -7.0), "COIL-U4", Vector2(91.0, -5.9), [Vector2(95.2, -7.2), Vector2(91.0, -7.2)])
	K.line("f1", "cable", "power", "LAMP-C", Vector2(4.2, -4.39), "COMMS-C", Vector2(4.8, -3.4), [Vector2(4.2, -3.4)])
	K.line("f2", "cable", "power", "DIST-C", Vector2(16.0, 1.0), "AHU-C", Vector2(16.0, -2.8))
	K.line("f3", "cable", "power", "CON-C", Vector2(5.6, 3.0), "SEQ-C", Vector2(8.0, 2.4), [Vector2(5.6, 2.0), Vector2(8.0, 2.0)])
	K.line("f4", "cable", "power", "GEN-P", Vector2(150.3, 2.4), "INV-P", Vector2(150.6, 0.6), [Vector2(150.1, 2.4), Vector2(150.1, 0.6)])
	K.line("f5", "cable", "power", "GEN-P", Vector2(150.45, 1.5), "PCU-P", Vector2(149.2, -1.2), [Vector2(150.45, -0.4), Vector2(149.2, -0.4)])
	K.line("f6", "cable", "power", "INV-P", Vector2(153.8, 0.4), "CPUMP-P", Vector2(154.0, -0.6), [Vector2(154.0, 0.4)])

# ---------------------------------------------------------------- lines

static func _lines() -> void:
	K.line("b1", "cable", "power", "BAT-C", Vector2(11.5, 2.0), "DIST-C", Vector2(13.6, 2.4), [Vector2(11.5, 1.6), Vector2(13.6, 1.6)])
	K.line("p1", "cable", "power", "DIST-C", Vector2(14.6, 1.0), "LAMP-C", Vector2(4.0, -4.39), [Vector2(14.6, -0.2), Vector2(4.0, -0.2)])
	K.line("p2", "cable", "power", "DIST-C", Vector2(14.2, 1.0), "CON-C", Vector2(4.0, 3.0), [Vector2(14.2, 0.6), Vector2(4.0, 0.6)])
	K.line("p3", "cable", "power", "DIST-C", Vector2(15.0, 1.0), "AV-C", Vector2(11.8, -1.5), [Vector2(15.0, -0.8), Vector2(11.8, -0.8)])
	K.line("p4", "cable", "power", "BAT-P", Vector2(155.4, 2.5), "GEN-P", Vector2(154.0, 3.0), [Vector2(155.4, 2.2), Vector2(154.15, 2.2), Vector2(154.15, 3.0)])
	# the trunk from the cabin's bus down the lower rail to the power module's lamp (the module itself runs on its own battery)
	K.line("p5", "cable", "power", "DIST-C", Vector2(16.4, 4.0), "LAMP-P", Vector2(156.2, -5.39), [Vector2(17.2, 4.0), Vector2(17.2, 6.45), Vector2(147.6, 6.45), Vector2(147.6, -0.3), Vector2(156.2, -0.3)])
	K.line("p6", "cable", "power", "GEN-P", Vector2(154.0, 1.8), "RAD-P", Vector2(155.3, -2.0), [Vector2(154.15, 1.8), Vector2(154.15, -0.3), Vector2(155.3, -0.3)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	K.ctrl("G-C", "port", K.at(3.0, -4.75, ["hull"]), Vector2(3.0, -5.25), {"medium": "gas", "target": "C"})
	K.ctrl("G-P", "port", K.at(156.0, -5.75, ["hull"]), Vector2(156.0, -6.25), {"medium": "gas", "target": "P"})
	K.door("HT-C", "")
	K.door("HT-P", "")
	K.ctrl("K-C", "switch", by_tag["BAT-C"], Vector2(11.0, 3.0), {"target": "K-C", "state": true, "hidden_room": "C"})
	K.ctrl("E-1", "test", by_tag["DIST-C"], Vector2(15.0, 3.0), {"medium": "volt", "target": "bus", "hidden_room": "C"})
	K.ctrl("DIS-1", "discharge", by_tag["DIST-C"], Vector2(14.2, 2.0), {"target": "CAP-1", "state": false, "hidden_room": "C"})
	K.ctrl("DIS-2", "discharge", by_tag["DIST-C"], Vector2(15.8, 2.0), {"target": "CAP-2", "state": false, "hidden_room": "C"})
	K.ctrl("K-P", "switch", by_tag["BAT-P"], Vector2(154.4, 3.4), {"target": "K-P", "state": true, "hidden_room": "P"})
	K.ctrl("PC-P", "port", by_tag["RAD-P"], Vector2(155.2, -2.4), {"medium": "coolant", "target": "pcool", "hidden_room": "P"})
	var i := 0
	for c in WHEELS:
		i += 1
		K.ctrl("BR-%d" % i, "switch", by_tag["BRK-%d" % i], Vector2(c - 0.5, -5.55), {"target": "BR-%d" % i, "state": false})
		K.ctrl("CV-%d" % i, "switch", by_tag["BRK-%d" % i], Vector2(c + 0.5, -5.55), {"target": "CV-%d" % i, "state": false})
		K.ctrl("RPM-%d" % i, "probe", by_tag["FW-%d" % i], Vector2(c + 2.0, 4.6), {"medium": "rpm", "target": "FW-%d" % i})
	for rl in ["U", "L"]:
		for k in 4:
			var x: float = SEC[k + 1] - 3.0
			K.ctrl("RT-%s%d" % [rl, k + 1], "switch", by_tag["R%s-%d" % [rl, k + 1]], Vector2(x, -6.45 if rl == "U" else 6.45), {"target": "RT-%s%d" % [rl, k + 1], "state": true})
		K.ctrl("T-R%s" % rl, "probe", by_tag["R%s-1" % rl], Vector2(30.0, -6.45 if rl == "U" else 6.45), {"medium": "rail", "target": rl})


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	w.add_room("C", K.mp(K.inner(OUT_C, T)))
	w.add_room("P", K.mp(K.inner(OUT_P, T)))


static func meta() -> Dictionary:
	return {
		"id": "md160",
		"name": "MD-160 SLINGSHOT",
		"title": ["MD-160「弹弓」质量驱动器驳船 · 160 m", "MD-160 SLINGSHOT · MASS-DRIVER BARGE · 160 m"],
		"contract": "MD-160",
		"length": 163.0,
		"value": {"total": 426900.0, "metal": 30000.0},
		"clamps": [[12.0, 5.0], [80.0, 7.0], [154.0, 6.0]],
		"room_names": {"C": "room_mdC", "P": "room_mdP"},
		"gas": {"rooms": {"C": 101.0, "P": 101.0}, "vessels": {}, "valves": [], "value": 1500.0},
		"flywheel": {
			"wheels": {
				"FW-1": {"rpm": 20000.0, "brake": "BR-1", "cool": "CV-1", "caliper": "BRK-1", "near": ["BRK-1", "CAP-1"]},
				"FW-2": {"rpm": 20000.0, "brake": "BR-2", "cool": "CV-2", "caliper": "BRK-2", "near": ["BRK-2", "CAP-1", "CAP-2"]},
				"FW-3": {"rpm": 20000.0, "brake": "BR-3", "cool": "CV-3", "caliper": "BRK-3", "near": ["BRK-3", "CAP-2", "CRADLE"]},
			},
			"safe": 300.0, "decel": 250.0, "burn": 8.0,
			"rails": {
				"U": {"sections": ["RU-1", "RU-2", "RU-3", "RU-4"], "tensioners": ["RT-U4", "RT-U3", "RT-U2", "RT-U1"], "hits": ["CAP-1", "CAP-2", "BRK-1", "BRK-2", "BRK-3", "COIL-U1", "COIL-U2", "COIL-U3", "COIL-U4", "COIL-U5"], "kn": 180.0},
				"L": {"sections": ["RL-1", "RL-2", "RL-3", "RL-4"], "tensioners": ["RT-L4", "RT-L3", "RT-L2", "RT-L1"], "hits": ["CRADLE", "CARGO-L", "FW-1", "FW-2", "FW-3", "COIL-L1", "COIL-L2", "COIL-L3", "COIL-L4", "COIL-L5"], "kn": 180.0},
			},
		},
		"power": {
			"bus": "DIST-C",
			"sources": [
				{"piece": "BAT-C", "kind": "battery", "volts": 400.0, "local_volts": 48.0, "cable": "b1", "switch": "K-C", "charge": 0.9, "drain": 0.0003},
			],
			# the capacitor banks hold their charge with the power off; the power module runs on its own battery
			"isolated": [{"piece": "CAP-1", "volts": 400.0, "charge": 1.0, "kind": "cap", "discharge": "DIS-1"},
				{"piece": "CAP-2", "volts": 400.0, "charge": 1.0, "kind": "cap", "discharge": "DIS-2"},
				{"piece": "BAT-P", "volts": 400.0, "charge": 0.9, "switch": "K-P"}],
			"lamps": {"C": "LAMP-C", "P": "LAMP-P"},
		},
		"fluids": {"volumes": {
			"pcool": {"fluid": "coolant", "amount": 0.25, "piece": "RAD-P", "port": "PC-P", "full": 0.3, "content": 1.0, "leak": 0.2, "pump": [0.2, 0.006]},
		}, "joins": [], "value": {"coolant": 500.0}},
		"ctrls_cfg": {"G-C": {"rate": 24.0}, "G-P": {"rate": 18.0}},
		"labels": {"BAT-C": "BAT", "DIST-C": "BUS", "CAP-1": "CAP 1", "CAP-2": "CAP 2", "FW-1": "FW-1", "FW-2": "FW-2", "FW-3": "FW-3", "BAT-P": "BAT", "GEN-P": "GEN"},
		"hints": {},
		"market": {
			"class": "MD", "name": ["弹弓级质量驱动器驳船", "SLINGSHOT-CLASS MASS-DRIVER BARGE"], "time": 50.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "P": [0.2, 40.0, 101.0]},
			"charge": {"BAT-C": [0.3, 1.0]},
			"knockable": ["CON-C", "AV-C"],
			"drift": [],
			"section_x": 116.0,
			"slots": {"fire_system": {"x": 149.3, "y0": 4.0, "y1": 5.55, "base": ["HP4-0", 5.55], "room": "P", "port": [149.7, 4.07]}},
			"mechanisms": true,
		},
		"procedures": {
			"CON-C": [
				{"do": "hose", "ctrl": "G-C"},
				{"do": "wait", "until": {"P": ["C", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-C"},
				{"do": "wait", "until": {"open": ["C"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-C"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CON-C"},
				{"do": "deliver", "piece": "CON-C", "zone": "equip"},
			],
		},
	}
