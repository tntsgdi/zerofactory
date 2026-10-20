class_name Mt140Author
# Authoring script for MT-140 "Centipede", a 140 m modular train (exotic batch
# 05/10, design/ships/MT-140_蜈蚣_设计稿.md and MT-140_线稿.png, as drawn). Not part
# of the game: tools/ship_export.gd runs it and writes ships/mt140.json.
# Metres, x bow (0) to the nozzles (~141), y down; the train aft of coupler K-4 is
# bent 8 degrees about K-4's aft face (the drawing).
#
# Seven 18 m modules on six 2 m couplers: M1 the locomotive (cockpit, battery,
# avionics, the bus's distribution), M2 the liquid tank and its pump, M3 eight cargo
# boxes on twist locks, M4 the living module, M5 the water tank and its pump, M6
# the machinery (generator, its standby battery, power board, the coolant
# radiator), M7 propulsion (two propellant tanks, two engines). Every coupler: four
# lock pins, the bus cable through it, the coolant hose with its valve and drain.
# What it asks of you (scripts/train.gd): the bus runs from M1 through every coupler,
# and each tank's pump draws only with power, so drain the tanks before the bus is
# broken (or switch on M6's standby battery). K-4 is jammed and carries the bend:
# take the train apart from its tail (or strip what is aft) before K-4 lets go.

const K = preload("res://tools/authoring/kit.gd")
const T := 0.45
const PIVOT := Vector2(80.0, 0.0)
const BEND := 8.0

static var w
static var by_tag := {}
static var aft: Array = []


static func build(world) -> void:
	K.begin(world, "MT140")
	w = world
	by_tag = K.by_tag
	aft = []
	for i in 7:
		_module(i)
	for i in 6:
		_coupler(i + 1)
	_m1()
	_m2()
	_m3()
	_m4()
	_m5()
	_m6()
	_m7()
	_fitout()
	_lines()
	_fit_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	K.begin(world, "MT140")
	w = world
	_rooms()


# the bend: everything aft of K-4's aft face turns about it
static func X(v: Vector2) -> Vector2:
	if v.x >= PIVOT.x - 0.001:
		return PIVOT + (v - PIVOT).rotated(deg_to_rad(BEND))
	return v


static func XA(pts: Array) -> Array:
	var out: Array = []
	for q in pts:
		out.append(X(q))
	return out


static func _x0(i: int) -> float:
	return 20.0 * i


static func _out(i: int) -> Array:
	var x0 := _x0(i)
	var x1 := x0 + 18.0
	if i == 0:
		return [Vector2(1.6, -5.0), Vector2(x1, -5.0), Vector2(x1, 5.0), Vector2(1.6, 5.0), Vector2(0.0, 3.4), Vector2(0.0, -3.4)]
	return [Vector2(x0, -5.0), Vector2(x1, -5.0), Vector2(x1, 5.0), Vector2(x0, 5.0)]


static func _keep(p):
	if p != null and p.get_meta("aft", false) == false and aft_on:
		aft.append(p.tag)
		p.set_meta("aft", true)
	return p


static var aft_on := false


# equipment standing in a module (local, straight coordinates), its art turned with the bend
static func E(tag: String, art: String, x0: float, y0: float, x1: float, y1: float, opts: Dictionary, on_floor := true, base = null):
	var pts := [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
	var bent: bool = x0 >= PIVOT.x
	var o := opts.duplicate()
	if bent:
		o.art_xf = Transform2D(deg_to_rad(BEND), X(Vector2(x0, y0)) * Geom.M)
		o.art_size = Vector2(x1 - x0, y1 - y0) * Geom.M
	var p = K.equip(tag, art, K.rect(x0, y0, x1, y1), o, K.mp(XA(pts)) if bent else null)
	_keep(p)
	var yb := y1 if on_floor else y0
	var yh := 4.75 if on_floor else -4.75
	for x in [x0 + 0.3, x1 - 0.3]:
		var a := X(Vector2(x, yb))
		if base != null:
			K.bolt(p, base, a.x, a.y)
		else:
			var h := X(Vector2(x, yh))
			K.bolt(p, K.at(h.x, h.y, ["hull"]), a.x, a.y)
	return p


# ---------------------------------------------------------------- the modules' shells

static func _module(i: int) -> void:
	aft_on = i >= 4
	var out := XA(_out(i))
	K.ring(out, T, {0: [0.55, 0.62]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HT-%d" % (i + 1), "open_dir": (X(Vector2(_x0(i) + 2.0, -5.0)) - X(Vector2(_x0(i), -5.0))) * Geom.M, "cut_speed": 200.0},
	}, {"density": 1.6, "barrier": true, "cut_speed": 210.0}, "H%d" % i)
	if aft_on:
		for t in by_tag.keys():
			if str(t).begins_with("H%d" % i) or t == "HT-%d" % (i + 1):
				_keep(by_tag[t])
	var lx := _x0(i) + 4.0
	var lp := X(Vector2(lx, -4.55))
	var la := X(Vector2(lx, -4.75))
	K.lamp("LAMP-%d" % (i + 1), lp.x, lp.y, "M%d" % (i + 1), K.at(la.x, la.y, ["hull"]))
	if aft_on:
		_keep(by_tag["LAMP-%d" % (i + 1)])


# ---------------------------------------------------------------- the couplers

static func _coupler(n: int) -> void:
	var x1 := _x0(n - 1) + 18.0
	aft_on = n >= 5
	var pts := XA([Vector2(x1, -1.4), Vector2(x1 + 2.0, -1.4), Vector2(x1 + 2.0, 1.4), Vector2(x1, 1.4)])
	var c = K.plate("K-%d" % n, K.mp(pts), {"cls": "equip", "dest": "equip", "mass": 0.8, "value": 4000.0, "fragile": 0.3, "density": 1.6, "barrier": false,
		"cut_speed": 150.0, "art": "", "name_key": "p_coupler"}, "keel")
	_keep(c)
	var k := 0
	for e in [[x1, -0.9, n - 1, 1], [x1, 0.9, n - 1, 1], [x1 + 2.0, -0.9, n, 3], [x1 + 2.0, 0.9, n, 3]]:
		k += 1
		var a := X(Vector2(e[0], e[1]))
		var inside := X(Vector2(e[0] + (-0.2 if e[3] == 1 else 0.2), e[1]))
		K.bolt(c, K.at(inside.x, inside.y, ["hull"]), a.x, a.y, "lock", "K%d-%d" % [n, k])


# ---------------------------------------------------------------- M1, the locomotive

static func _m1() -> void:
	var st = K.seat("SEAT-1", Rect2(2.4, 3.05, 0.8, 1.5), {"room": "M1", "name_key": "p_seat_pilot"})
	K.bolt(st, K.at(2.6, 4.75, ["hull"]), 2.6, 4.55)
	K.bolt(st, K.at(3.0, 4.75, ["hull"]), 3.0, 4.55, "lock")
	E("CON-1", "console", 3.6, 3.0, 6.8, 4.55, {"mass": 0.4, "value": 9000.0, "fragile": 0.5, "room": "M1", "mandatory": true, "name_key": "p_train_console"})
	E("AV-1", "nav_rack", 7.2, 1.5, 9.4, 4.55, {"mass": 0.3, "value": 9000.0, "fragile": 0.5, "room": "M1", "name_key": "p_avionics"})
	E("BAT-1", "battery", 10.0, 2.0, 13.0, 4.55, {"mass": 1.0, "value": 8000.0, "fragile": 0.4, "room": "M1", "hazard": "battery", "name_key": "p_battery"})
	E("DIST-1", "swb", 14.0, 1.0, 17.0, 4.55, {"mass": 0.5, "value": 6000.0, "fragile": 0.4, "room": "M1", "name_key": "p_train_bus"})
	var dk = K.equip("DOCK", "dock", K.rect(-1.2, -1.4, 0.0, 1.4), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "name_key": "p_dock_ring"})
	K.bolt(dk, K.at(0.2, -1.0, ["hull"]), 0.0, -1.0)
	K.bolt(dk, K.at(0.2, 1.0, ["hull"]), 0.0, 1.0)


static func _m2() -> void:
	_saddled("T-2", "fueltank", 21.0, 33.0, {"mass": 9.0, "value": 16000.0, "fragile": 0.25, "room": "M2", "hazard": "fuel_tank", "name_key": "p_liquid_tank"})
	E("P-2", "pump", 33.6, 2.0, 36.6, 4.55, {"mass": 0.6, "value": 6000.0, "fragile": 0.35, "room": "M2", "name_key": "p_tank_pump"})
	E("JB-2", "swb", 34.0, -4.55, 37.0, -2.4, {"mass": 0.2, "value": 1500.0, "fragile": 0.4, "room": "M2", "name_key": "p_junction"}, false)


# a tank standing on two saddles
static func _saddled(tag: String, art: String, x0: float, x1: float, opts: Dictionary) -> void:
	var bent: bool = x0 >= PIVOT.x
	var o := opts.duplicate()
	var pts := [Vector2(x0, -3.4), Vector2(x1, -3.4), Vector2(x1, 3.6), Vector2(x0, 3.6)]
	if bent:
		o.art_xf = Transform2D(deg_to_rad(BEND), X(Vector2(x0, -3.4)) * Geom.M)
		o.art_size = Vector2(x1 - x0, 7.0) * Geom.M
	var tk = K.equip(tag, art, K.rect(x0, -3.4, x1, 3.6), o, K.mp(XA(pts)) if bent else null)
	_keep(tk)
	var third := (x1 - x0) / 3.0
	var s1 := XA([Vector2(x0 + third, -3.4), Vector2(x0 + third, 3.6)])
	var s2 := XA([Vector2(x1 - third, -3.4), Vector2(x1 - third, 3.6)])
	tk.set_meta("segments", [[s1[0].x, s1[0].y, s1[1].x, s1[1].y], [s2[0].x, s2[0].y, s2[1].x, s2[1].y]])
	var k := 0
	for sx in [x0 + 1.5, x1 - 2.5]:
		k += 1
		var sd = K.plate("%s-S%d" % [tag, k], K.mp(XA([Vector2(sx, 3.6), Vector2(sx + 1.0, 3.6), Vector2(sx + 1.0, 4.55), Vector2(sx, 4.55)])),
			{"density": 1.6, "barrier": false, "cut_speed": 150.0, "name_key": "p_saddle"}, "strut")
		_keep(sd)
		var f := X(Vector2(sx + 0.5, 4.55))
		var h := X(Vector2(sx + 0.5, 4.75))
		K.bolt(sd, K.at(h.x, h.y, ["hull"]), f.x, f.y, "weld")
		var t1 := X(Vector2(sx + 0.2, 3.6))
		var t2 := X(Vector2(sx + 0.8, 3.6))
		K.bolt(tk, sd, t1.x, t1.y, "lock")
		K.bolt(tk, sd, t2.x, t2.y, "lock")


# ---------------------------------------------------------------- M3, the cargo boxes

static func _m3() -> void:
	var k := 0
	for row in 2:
		var y0 := -4.4 if row == 0 else 0.05
		var y1 := -0.05 if row == 0 else 4.4
		for c in 4:
			k += 1
			var x0 := 40.6 + c * 4.0
			var bx = K.equip("C-%d" % k, "cargo", K.rect(x0, y0, x0 + 3.8, y1), {"mass": 2.8, "value": 6000.0, "fragile": 0.3, "room": "M3", "name_key": "p_cargo_box"})
			if row == 0:
				K.bolt(bx, K.at(x0 + 0.5, -4.75, ["hull"]), x0 + 0.5, y0, "lock")
				K.bolt(bx, K.at(x0 + 3.3, -4.75, ["hull"]), x0 + 3.3, y0, "lock")
			else:
				K.bolt(bx, K.at(x0 + 0.5, 4.75, ["hull"]), x0 + 0.5, y1, "lock")
				K.bolt(bx, K.at(x0 + 3.3, 4.75, ["hull"]), x0 + 3.3, y1, "lock")
				K.bolt(bx, by_tag["C-%d" % (k - 4)], x0 + 0.5, 0.0, "lock")
				K.bolt(bx, by_tag["C-%d" % (k - 4)], x0 + 3.3, 0.0, "lock")
	var jb = K.equip("JB-3", "swb", K.rect(56.6, -1.2, 57.55, 1.2), {"mass": 0.2, "value": 1500.0, "fragile": 0.4, "room": "M3", "name_key": "p_junction"})
	K.bolt(jb, K.at(57.75, -0.6, ["hull"]), 57.55, -0.6)
	K.bolt(jb, K.at(57.75, 0.6, ["hull"]), 57.55, 0.6)


# ---------------------------------------------------------------- M4, living

static func _m4() -> void:
	var lo = E("BUNK-4A", "bunk", 61.0, 3.0, 65.2, 4.55, {"mass": 0.3, "value": 1200.0, "fragile": 0.3, "room": "M4", "name_key": "p_bunk"})
	var hi = K.equip("BUNK-4B", "bunk", K.rect(61.0, 1.2, 65.2, 2.8), {"mass": 0.3, "value": 1200.0, "fragile": 0.3, "room": "M4", "name_key": "p_bunk"})
	K.bolt(hi, lo, 61.5, 2.8)
	K.bolt(hi, lo, 64.7, 2.8)
	E("TABLE-4", "cabinet", 66.4, 3.2, 69.4, 4.55, {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "M4", "name_key": "p_crew_mess"})
	E("ENV-4", "env", 70.0, 1.6, 73.5, 4.55, {"mass": 1.0, "value": 9000.0, "fragile": 0.4, "room": "M4", "name_key": "p_env_control"})
	E("JB-4", "swb", 74.0, -4.55, 77.0, -2.4, {"mass": 0.2, "value": 1500.0, "fragile": 0.4, "room": "M4", "name_key": "p_junction"}, false)


# ---------------------------------------------------------------- M5, the water tank (bent)

static func _m5() -> void:
	aft_on = true
	_saddled("T-5", "water", 81.0, 93.0, {"mass": 9.0, "value": 12000.0, "fragile": 0.25, "room": "M5", "name_key": "p_water_tank"})
	E("P-5", "pump", 93.6, 2.0, 96.6, 4.55, {"mass": 0.6, "value": 6000.0, "fragile": 0.35, "room": "M5", "name_key": "p_tank_pump"})
	E("JB-5", "swb", 94.0, -4.55, 97.0, -2.4, {"mass": 0.2, "value": 1500.0, "fragile": 0.4, "room": "M5", "name_key": "p_junction"}, false)


# ---------------------------------------------------------------- M6, machinery

static func _m6() -> void:
	E("GEN-6", "gen", 101.0, 1.0, 105.0, 4.55, {"mass": 1.6, "value": 14000.0, "fragile": 0.35, "room": "M6", "name_key": "p_generator"})
	E("BAT-6", "battery", 105.6, 2.0, 108.6, 4.55, {"mass": 1.0, "value": 9000.0, "fragile": 0.4, "room": "M6", "hazard": "battery", "name_key": "p_standby_battery"})
	E("PWR-6", "swb", 109.0, 1.0, 111.6, 4.55, {"mass": 0.6, "value": 8000.0, "fragile": 0.4, "room": "M6", "name_key": "p_power_board"})
	E("RAD-6", "radiator", 112.4, -3.0, 117.0, 4.55, {"mass": 1.0, "value": 7000.0, "fragile": 0.35, "room": "M6", "name_key": "p_radiator"})


# ---------------------------------------------------------------- M7, propulsion

static func _m7() -> void:
	E("PT-7A", "fueltank", 121.0, -4.0, 127.0, -0.6, {"mass": 1.5, "value": 3000.0, "fragile": 0.3, "room": "M7", "hazard": "fuel_tank", "name_key": "p_svc_prop"}, false)
	E("PT-7B", "fueltank", 121.0, 0.6, 127.0, 4.0, {"mass": 1.5, "value": 3000.0, "fragile": 0.3, "room": "M7", "hazard": "fuel_tank", "name_key": "p_svc_prop"})
	E("JB-7", "swb", 127.6, -4.55, 129.6, -3.0, {"mass": 0.15, "value": 1200.0, "fragile": 0.4, "room": "M7", "name_key": "p_junction"}, false)
	for e in [["ENG-A", -4.0, -0.6], ["ENG-B", 0.6, 4.0]]:
		var y0: float = e[1]
		var y1: float = e[2]
		var en = E(e[0], "eng_core", 131.0, y0, 137.55, y1, {"mass": 1.6, "value": 9000.0, "fragile": 0.3, "room": "M7", "name_key": "p_engine"}, e[0] == "ENG-B")
		var nz_pts := XA([Vector2(138.0, y0 + 0.5), Vector2(141.5, y0 - 0.2), Vector2(141.5, y1 + 0.2), Vector2(138.0, y1 - 0.5)])
		var bb := Geom.bbox(K.mp(nz_pts))
		var nz = K.equip("NOZ-" + e[0].substr(4), "nozzle", Rect2(bb.position / Geom.M, bb.size / Geom.M),
			{"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 160.0, "name_key": "p_nozzle"}, K.mp(nz_pts))
		_keep(nz)
		for yy in [y0 + 0.9, y1 - 0.9]:
			var a := X(Vector2(138.0, yy))
			var h := X(Vector2(137.8, yy))
			K.bolt(nz, K.at(h.x, h.y, ["hull"]), a.x, a.y)


# ---------------------------------------------------------------- the fit-out (player 2026-10-19: fill each car with what it carries)

static func _fitout() -> void:
	aft_on = false
	# M1, the locomotive: comms, navigation and the cab's air under the roof
	E("COMMS-1", "console", 5.0, -4.55, 7.4, -3.0, {"mass": 0.2, "value": 4000.0, "fragile": 0.5, "room": "M1", "name_key": "p_comms"}, false)
	E("NAV-1", "nav", 7.8, -4.55, 10.2, -2.6, {"mass": 0.25, "value": 6000.0, "fragile": 0.5, "room": "M1", "name_key": "p_nav"}, false)
	E("AHU-1", "env", 12.2, -4.55, 15.2, -2.8, {"mass": 0.3, "value": 4000.0, "fragile": 0.4, "room": "M1", "name_key": "p_ahu"}, false)
	# M2: the tank's level gauge over it, the flow meter on its pump
	E("LVL-2", "insp", 26.0, -4.55, 27.6, -3.95, {"mass": 0.05, "value": 3000.0, "fragile": 0.55, "room": "M2", "name_key": "p_level"}, false)
	E("FLOW-2", "panel", 33.6, 0.6, 34.8, 2.0, {"mass": 0.08, "value": 3500.0, "fragile": 0.45, "room": "M2", "name_key": "p_flow_meter"}, true, by_tag["P-2"])
	# M4, living: lockers, the galley and the medical cabinet under the roof, the washroom unit
	E("LOCKER-4", "locker", 61.0, -4.55, 63.4, -1.0, {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "room": "M4", "name_key": "p_locker"}, false)
	E("GALLEY-4", "cabinet", 65.0, -4.55, 69.4, -2.0, {"mass": 0.5, "value": 4500.0, "fragile": 0.35, "room": "M4", "name_key": "p_galley"}, false)
	E("MED-4", "cabinet", 71.6, -4.55, 73.8, -2.2, {"mass": 0.2, "value": 5000.0, "fragile": 0.45, "room": "M4", "name_key": "p_pharmacy"}, false)
	E("WASH-4", "water", 74.2, 2.6, 77.4, 4.55, {"mass": 0.4, "value": 2500.0, "fragile": 0.3, "room": "M4", "name_key": "p_sanitation"})
	# M5 (bent): as M2
	aft_on = true
	E("LVL-5", "insp", 86.0, -4.55, 87.6, -4.1, {"mass": 0.05, "value": 3000.0, "fragile": 0.55, "room": "M5", "name_key": "p_level"}, false)
	E("FLOW-5", "panel", 93.6, 0.6, 94.8, 2.0, {"mass": 0.08, "value": 3500.0, "fragile": 0.45, "room": "M5", "name_key": "p_flow_meter"}, true, by_tag["P-5"])
	# M6, machinery: the exhaust silencer, the engine control cabinet and the lube tank under the roof
	E("EXH-6", "pump", 100.6, -4.55, 103.4, -2.0, {"mass": 0.6, "value": 3000.0, "fragile": 0.3, "room": "M6", "name_key": "p_vent"}, false)
	E("CTRL-6", "swb", 104.8, -4.55, 108.0, -2.4, {"mass": 0.4, "value": 7000.0, "fragile": 0.4, "room": "M6", "name_key": "p_process_cabinet"}, false)
	E("LUBE-6", "gastank", 108.4, -4.55, 109.8, -1.0, {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "room": "M6", "name_key": "p_lube_tank"}, false)
	# M7: the foam station by the engines
	E("FOAM-7", "gastank", 127.8, 2.8, 130.4, 4.55, {"mass": 0.3, "value": 2000.0, "fragile": 0.3, "room": "M7", "name_key": "p_foam"})


static func _fit_lines() -> void:
	var L := func(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []):
		K.line(id, kind, net, a, X(pa), b, X(pb), XA(via))
	L.call("f1", "cable", "power", "LAMP-1", Vector2(4.2, -4.39), "COMMS-1", Vector2(5.0, -3.3), [Vector2(4.2, -3.3)])
	L.call("f2", "cable", "power", "COMMS-1", Vector2(7.4, -3.3), "NAV-1", Vector2(7.8, -3.3))
	L.call("f3", "cable", "power", "NAV-1", Vector2(10.2, -3.3), "AHU-1", Vector2(12.2, -3.3))
	L.call("f4", "cable", "power", "LAMP-2", Vector2(24.2, -4.39), "LVL-2", Vector2(26.0, -4.2), [Vector2(24.2, -4.2)])
	L.call("f5", "cable", "power", "JB-2", Vector2(34.4, -2.4), "FLOW-2", Vector2(34.2, 0.6), [Vector2(34.4, 0.2), Vector2(34.2, 0.2)])
	L.call("f6", "cable", "power", "JB-4", Vector2(74.0, -3.0), "MED-4", Vector2(73.8, -3.0))
	L.call("f7", "cable", "power", "MED-4", Vector2(71.6, -3.0), "GALLEY-4", Vector2(69.4, -3.0))
	L.call("f8", "cable", "power", "ENV-4", Vector2(73.5, 3.0), "WASH-4", Vector2(74.2, 3.0))
	L.call("f9", "cable", "power", "LAMP-5", Vector2(84.2, -4.39), "LVL-5", Vector2(86.0, -4.3), [Vector2(84.2, -4.3)])
	L.call("f10", "cable", "power", "JB-5", Vector2(94.4, -2.4), "FLOW-5", Vector2(94.2, 0.6), [Vector2(94.4, 0.2), Vector2(94.2, 0.2)])
	L.call("f11", "cable", "power", "PWR-6", Vector2(109.4, 1.0), "CTRL-6", Vector2(107.0, -2.4), [Vector2(109.4, -0.4), Vector2(107.0, -0.4)])

# ---------------------------------------------------------------- lines

static func _lines() -> void:
	var L := func(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []):
		K.line(id, kind, net, a, X(pa), b, X(pb), XA(via))
	L.call("b1", "cable", "power", "BAT-1", Vector2(11.5, 2.0), "DIST-1", Vector2(14.0, 2.4), [Vector2(11.5, 1.6), Vector2(14.0, 1.6)])
	L.call("p1", "cable", "power", "DIST-1", Vector2(15.0, 1.0), "LAMP-1", Vector2(4.0, -4.39), [Vector2(15.0, -3.6), Vector2(4.0, -3.6)])
	L.call("p2", "cable", "power", "DIST-1", Vector2(14.4, 1.0), "CON-1", Vector2(5.0, 3.0), [Vector2(14.4, 0.6), Vector2(5.0, 0.6)])
	L.call("p3", "cable", "power", "DIST-1", Vector2(14.2, 1.0), "AV-1", Vector2(8.2, 1.5), [Vector2(14.2, 0.9), Vector2(8.2, 0.9)])
	# the bus through every coupler, junction box to junction box
	var jb := ["DIST-1", "JB-2", "JB-3", "JB-4", "JB-5", "PWR-6", "JB-7"]
	var at := {"DIST-1": Vector2(17.0, 1.4), "JB-2": [Vector2(34.0, -3.4), Vector2(37.0, -3.4)], "JB-3": [Vector2(56.6, 0.0), Vector2(57.55, 0.0)],
		"JB-4": [Vector2(74.0, -3.4), Vector2(77.0, -3.4)], "JB-5": [Vector2(94.0, -3.4), Vector2(97.0, -3.4)], "PWR-6": [Vector2(109.0, 2.0), Vector2(111.6, 2.0)], "JB-7": Vector2(127.6, -3.8)}
	for n in range(1, 7):
		var x1 := 20.0 * (n - 1) + 18.0
		var fa = at[jb[n - 1]]
		var pa: Vector2 = fa if fa is Vector2 else fa[1]
		var fb = at[jb[n]]
		var pb: Vector2 = fb if fb is Vector2 else fb[0]
		L.call("kc%d" % n, "cable", "power", jb[n - 1], pa, jb[n], pb, [Vector2(pa.x, -0.4), Vector2(x1 + 1.0, -0.4), Vector2(pb.x, -0.4)])
	L.call("p4", "cable", "power", "JB-2", Vector2(35.5, -2.4), "P-2", Vector2(35.0, 2.0), [Vector2(35.5, 1.6), Vector2(35.0, 1.6)])
	L.call("p5", "cable", "power", "JB-2", Vector2(36.0, -2.4), "LAMP-2", Vector2(24.0, -4.39), [Vector2(36.0, -2.0), Vector2(33.4, -2.0), Vector2(33.4, -3.8), Vector2(24.0, -3.8)])
	L.call("p6", "cable", "power", "JB-3", Vector2(57.0, -1.2), "LAMP-3", Vector2(44.0, -4.39), [Vector2(57.0, -4.42), Vector2(44.0, -4.42)])
	L.call("p7", "cable", "power", "JB-4", Vector2(75.0, -2.4), "ENV-4", Vector2(71.5, 1.6), [Vector2(75.0, 1.0), Vector2(71.5, 1.0)])
	L.call("p8", "cable", "power", "JB-4", Vector2(76.0, -4.55), "LAMP-4", Vector2(64.0, -4.39), [Vector2(76.0, -4.42), Vector2(64.0, -4.42)])
	L.call("p9", "cable", "power", "JB-5", Vector2(95.5, -2.4), "P-5", Vector2(95.0, 2.0), [Vector2(95.5, 1.6), Vector2(95.0, 1.6)])
	L.call("p10", "cable", "power", "JB-5", Vector2(96.0, -2.4), "LAMP-5", Vector2(84.0, -4.39), [Vector2(96.0, -2.0), Vector2(93.4, -2.0), Vector2(93.4, -3.9), Vector2(84.0, -3.9)])
	L.call("p11", "cable", "power", "PWR-6", Vector2(110.0, 1.0), "LAMP-6", Vector2(104.0, -4.39), [Vector2(110.0, -1.6), Vector2(104.0, -1.6)])
	L.call("p12", "cable", "power", "PWR-6", Vector2(109.0, 3.0), "BAT-6", Vector2(108.6, 3.0))
	L.call("p13", "cable", "power", "PWR-6", Vector2(110.5, 1.0), "GEN-6", Vector2(104.0, 1.0), [Vector2(110.5, 0.6), Vector2(104.0, 0.6)])
	L.call("p14", "cable", "power", "JB-7", Vector2(128.6, -3.0), "ENG-A", Vector2(132.0, -2.0), [Vector2(128.6, -2.0)])
	L.call("p15", "cable", "power", "JB-7", Vector2(127.8, -3.0), "LAMP-7", Vector2(124.0, -4.39), [Vector2(127.8, -4.3), Vector2(124.0, -4.3)])
	# the coolant hose through every coupler, from the radiator
	for n in range(1, 7):
		var x1 := 20.0 * (n - 1) + 18.0
		L.call("kh%d" % n, "pipe", "kh%d" % n, "K-%d" % n, Vector2(x1 + 0.4, 0.8), "H%d3-0" % n, Vector2(x1 + 2.2, 0.8), [Vector2(x1 + 2.2, 0.8)])


# ---------------------------------------------------------------- controls

static func _controls() -> void:
	for i in 7:
		var gp := X(Vector2(_x0(i) + 6.5, -4.75))
		var go := X(Vector2(_x0(i) + 6.5, -5.25))
		K.ctrl("G-%d" % (i + 1), "port", K.at(gp.x, gp.y, ["hull"]), go, {"medium": "gas", "target": "M%d" % (i + 1)})
		K.door("HT-%d" % (i + 1), "")
	K.ctrl("K-1", "switch", by_tag["BAT-1"], Vector2(11.0, 3.0), {"target": "K-1", "state": true, "hidden_room": "M1"})
	K.ctrl("E-1", "test", by_tag["DIST-1"], Vector2(15.5, 3.0), {"medium": "volt", "target": "bus", "hidden_room": "M1"})
	K.ctrl("K-6", "switch", by_tag["BAT-6"], X(Vector2(106.4, 3.0)), {"target": "K-6", "state": false, "hidden_room": "M6"})
	K.ctrl("PT-2", "port", by_tag["P-2"], Vector2(34.4, 2.4), {"medium": "fuel", "target": "t2", "hidden_room": "M2"})
	K.ctrl("PT-5", "port", by_tag["P-5"], X(Vector2(94.4, 2.4)), {"medium": "water", "target": "t5", "hidden_room": "M5"})
	K.ctrl("PC-6", "port", by_tag["RAD-6"], X(Vector2(114.0, -2.6)), {"medium": "coolant", "target": "cool", "hidden_room": "M6"})
	K.ctrl("PP-7A", "port", by_tag["PT-7A"], X(Vector2(122.0, -3.6)), {"medium": "fuel", "target": "p7a", "hidden_room": "M7"})
	K.ctrl("PP-7B", "port", by_tag["PT-7B"], X(Vector2(122.0, 1.0)), {"medium": "fuel", "target": "p7b", "hidden_room": "M7"})
	for n in range(1, 7):
		var x1 := 20.0 * (n - 1) + 18.0
		K.ctrl("KV-%d" % n, "valve", by_tag["K-%d" % n], X(Vector2(x1 + 1.0, -0.8)), {"target": "KV-%d" % n, "state": true})
		K.ctrl("KB-%d" % n, "port", by_tag["K-%d" % n], X(Vector2(x1 + 1.0, 0.9)), {"medium": "coolant", "target": "hz%d" % n})
	K.ctrl("T-K4", "probe", by_tag["K-4"], Vector2(79.0, 0.0), {"medium": "bend", "target": "K-4"})
	# the berth holds M2 and M6 by their bellies
	K.clamp(1, 29.0, 5.0, 4.8)
	var c2 := X(Vector2(109.0, 5.0))
	var p2 := X(Vector2(109.0, 4.8))
	w.add_joint(K.at(p2.x, p2.y, ["hull"]), null, "clamp", c2 * Geom.M).set_meta("tag", "CL-02")


# ---------------------------------------------------------------- rooms

static func _rooms() -> void:
	for i in 7:
		w.add_room("M%d" % (i + 1), K.mp(K.inner(XA(_out(i)), T)))


static func meta() -> Dictionary:
	var vols := {
		"t2": {"fluid": "fuel", "amount": 0.8, "piece": "T-2", "port": "PT-2", "full": 1.0, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
		"t5": {"fluid": "water", "amount": 0.9, "piece": "T-5", "port": "PT-5", "full": 1.0, "content": 1.0, "leak": 0.12, "pump": [0.12, 0.008]},
		"cool": {"fluid": "coolant", "amount": 0.3, "piece": "RAD-6", "port": "PC-6", "full": 0.3, "content": 1.0, "leak": 0.2, "pump": [0.2, 0.006]},
		"p7a": {"fluid": "fuel", "amount": 0.2, "piece": "PT-7A", "port": "PP-7A", "full": 0.3, "content": 1.0, "leak": 0.1, "pump": [0.12, 0.008]},
		"p7b": {"fluid": "fuel", "amount": 0.2, "piece": "PT-7B", "port": "PP-7B", "full": 0.3, "content": 1.0, "leak": 0.1, "pump": [0.12, 0.008]},
	}
	var joins: Array = []
	var rooms := {}
	var mrooms := {}
	var names := {}
	var lamps := {}
	for n in range(1, 7):
		vols["hz%d" % n] = {"fluid": "coolant", "amount": 0.02, "nets": ["kh%d" % n], "port": "KB-%d" % n, "full": 0.02, "leak": 0.06, "leak_min": 0.004}
		joins.append({"a": "cool", "b": "hz%d" % n, "valves": ["KV-%d" % n], "mode": "fill", "cap": 0.02, "leak_through": 0.05})
	for i in 7:
		rooms["M%d" % (i + 1)] = 101.0
		mrooms["M%d" % (i + 1)] = [0.2, 40.0, 101.0]
		names["M%d" % (i + 1)] = "room_mt%d" % (i + 1)
		lamps["M%d" % (i + 1)] = "LAMP-%d" % (i + 1)
	return {
		"id": "mt140",
		"name": "MT-140 CENTIPEDE",
		"title": ["MT-140「蜈蚣」模块列车 · 140 m", "MT-140 CENTIPEDE · MODULAR TRAIN · 140 m"],
		"contract": "MT-140",
		"length": 142.0,
		"value": {"total": 344100.0, "metal": 40000.0},
		"clamps": [[29.0, 5.0], [X(Vector2(109.0, 5.0)).x, X(Vector2(109.0, 5.0)).y]],
		"room_names": names,
		"gas": {"rooms": rooms, "vessels": {}, "valves": [], "value": 5000.0},
		"train": {"jam": {"coupler": "K-4", "pins": ["K4-1", "K4-2", "K4-3", "K4-4"], "aft": aft.duplicate(), "keep": 75.0,
			"hits": ["ENV-4", "TABLE-4", "JB-4", "T-5", "P-5", "JB-5"]}, "pumps": {"t2": "P-2", "t5": "P-5"}},
		"power": {
			"bus": "DIST-1",
			"sources": [
				{"piece": "BAT-1", "kind": "battery", "volts": 400.0, "local_volts": 48.0, "cable": "b1", "switch": "K-1", "charge": 0.9, "drain": 0.0003},
			],
			# M6's standby battery: off, for power downstream once the bus is broken
			"isolated": [{"piece": "BAT-6", "volts": 400.0, "charge": 0.8, "switch": "K-6"}],
			"lamps": lamps,
		},
		"fluids": {"volumes": vols, "joins": joins, "value": {"fuel": 9000.0, "water": 2000.0, "coolant": 1500.0}},
		"ctrls_cfg": {"G-1": {"rate": 30.0}, "G-2": {"rate": 30.0}, "G-3": {"rate": 30.0}, "G-4": {"rate": 30.0}, "G-5": {"rate": 30.0}, "G-6": {"rate": 30.0}, "G-7": {"rate": 30.0}},
		"labels": {"BAT-1": "BAT", "DIST-1": "BUS", "BAT-6": "STBY BAT", "T-2": "T2", "T-5": "H2O", "K-1": "K1", "K-2": "K2", "K-3": "K3", "K-4": "K4", "K-5": "K5", "K-6": "K6"},
		"hints": {},
		"market": {
			"class": "MT", "name": ["蜈蚣级模块列车", "CENTIPEDE-CLASS MODULAR TRAIN"], "time": 49.0,
			"rooms": mrooms,
			"charge": {"BAT-1": [0.3, 1.0]},
			"fluids": {"t2": [0.2, 0.8], "t5": [0.2, 0.9]},
			"knockable": ["CON-1", "ENV-4"],
			"drift": [],
			"section_x": 79.0,
			"slots": {"fire_system": {"x": 65.35, "y0": 2.8, "y1": 4.55, "base": ["H32-0", 4.55], "room": "M4", "port": [65.75, 2.87]}},
			"mechanisms": true,
		},
		"procedures": {
			"CON-1": [
				{"do": "hose", "ctrl": "G-1"},
				{"do": "wait", "until": {"P": ["M1", "<", 5.0]}, "max": 150.0},
				{"do": "operate", "ctrl": "HT-1"},
				{"do": "wait", "until": {"open": ["M1"]}, "max": 20.0},
				{"do": "operate", "ctrl": "K-1"},
				{"do": "measure", "ctrl": "E-1", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CON-1"},
				{"do": "deliver", "piece": "CON-1", "zone": "equip"},
			],
		},
	}
