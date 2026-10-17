class_name FR26Author
# Authoring script for FR-26 "Frostline", the 72 m cryogenic carrier
# (design/ships/FR-26_霜线_设计稿.md, structure: design/ships/FR-26_结构图.png).
# Not part of the game: tools/ship_export.gd runs it and writes ships/fr26.json.
# Metres, x bow (0) to stern (72), y down; the keel's underside is y = -3.0.
#
# Three big cylindrical tanks in a row hang under a box keel; forward of them
# a pressurised shell (the control cabin B and the machinery room F behind a
# bulkhead), aft of them another (the aft machinery room A), then the
# thrusters. On the keel, over the tanks, the cargo deck: the crew cabin Q,
# the boil-off compressors, the reliquefaction cold box, the nitrogen
# generator, the fuel cell with its hydrogen and oxygen tanks, the vent mast.
# Each tank is an inner tank (cargo at -163 °C, its vapour at about 220 kPa)
# inside a vacuum jacket; its relief valve, temperature sensor, cargo port and
# vapour port sit on the jacket's top.
# What it asks of you: temperature as a state (scripts/cryo.gd) — power off
# and the cargo warms, slowly; heat makes pressure. Draw the cargo off, then
# its vapour, before a tank is opened; a tank still under its vapour bursts
# when cut. An empty tank is about 7 t: cut along its marked lines.

const T := 0.4
const OUTER_F := [Vector2(0.6, -1.2), Vector2(3.4, -3.0), Vector2(15.0, -3.0), Vector2(15.0, 4.2), Vector2(4.0, 4.2), Vector2(0.6, 2.2)]
const OUTER_A := [Vector2(60.0, -3.0), Vector2(66.8, -3.0), Vector2(66.8, 4.2), Vector2(60.0, 4.2)]
const OUTER_Q := [Vector2(16.0, -3.6), Vector2(16.0, -6.4), Vector2(16.6, -7.0), Vector2(27.4, -7.0), Vector2(28.0, -6.4), Vector2(28.0, -3.6)]
const TQ := 0.35
const BH_X := 7.4                # the bulkhead between B and F (to 7.8)
const KEEL := [7.6, 15.4, 30.0, 44.6, 59.6, 66.8]   # the keel's sections
const KY0 := -3.6
const KY1 := -3.0
const TANKS := [[15.8, 29.0], [30.6, 43.8], [45.4, 58.6]]
const JY0 := -2.4                # the jackets' outside
const JY1 := 4.8
const JC := 1.8                  # their corner chamfer
const TJ := 0.3                  # jacket shell
const GAP := 0.7                 # jacket outside to inner tank outside
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var w
static var by_tag := {}


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(minf(x0, x1), minf(y0, y1), maxf(x0, x1), maxf(y0, y1)))


static func _mp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


static func _inner(outer: Array, t: float) -> Array:
	var n := outer.size()
	var out: Array = []
	for i in n:
		var a: Vector2 = outer[(i - 1 + n) % n]
		var b: Vector2 = outer[i]
		var c: Vector2 = outer[(i + 1) % n]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		var hit = Geometry2D.line_intersects_line(a + n1 * t, d1, b + n2 * t, d2)
		out.append(hit if hit != null else b + n1 * t)
	return out


# a tank's jacket outline: a long octagon
static func _jacket(i: int) -> Array:
	var x0: float = TANKS[i][0]
	var x1: float = TANKS[i][1]
	return [Vector2(x0 + JC, JY0), Vector2(x1 - JC, JY0), Vector2(x1, JY0 + JC), Vector2(x1, JY1 - JC), Vector2(x1 - JC, JY1),
		Vector2(x0 + JC, JY1), Vector2(x0, JY1 - JC), Vector2(x0, JY0 + JC)]


static func build(world) -> void:
	w = world
	by_tag = {}
	_hull()
	_keel()
	_tanks()
	_cabin()
	_fore_inside()
	_deck()
	_aft_inside()
	_thrust()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt", tag: String = "") -> void:
	if a == null or b == null:
		push_warning("FR26 joint missing a piece at %s,%s" % [x, y])
		return
	var j = w.add_joint(a, b, type, p(x, y))
	if tag != "":
		j.set_meta("tag", tag)


static func at(x: float, y: float, kinds: Array = []):
	return w.piece_at(p(x, y), kinds)


static func _equip(tag: String, art: String, r: Rect2, opts: Dictionary, poly = null):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	return _tagged(w.add_piece(kind, poly if poly != null else Geom.rect_poly(rr), o))


static func _ring(outer: Array, t: float, splits: Dictionary, specials: Dictionary, base: Dictionary) -> void:
	var inn := _inner(outer, t)
	var n := outer.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = outer[i]
		var o1: Vector2 = outer[(i + 1) % n]
		var i0: Vector2 = inn[i]
		var i1: Vector2 = inn[(i + 1) % n]
		var st: Array = [0.0]
		st.append_array(splits.get(i, []))
		st.append(1.0)
		for k in st.size() - 1:
			var a := o0.lerp(o1, st[k])
			var b := o0.lerp(o1, st[k + 1])
			var c := i0.lerp(i1, st[k + 1])
			var d := i0.lerp(i1, st[k])
			var opts: Dictionary = base.duplicate()
			var kind := "hull"
			var sp: Dictionary = specials.get("%d:%d" % [i, k], {})
			if not sp.is_empty():
				kind = sp.get("kind", "hull")
				opts.merge(sp, true)
				opts.erase("kind")
			var pc = _tagged(w.add_piece(kind, _mp([a, b, c, d]), opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
			if first == null:
				first = pc
			prev = pc
	if prev != null:
		w.add_joint(prev, first, "weld", outer[0].lerp(inn[0], 0.3) * Geom.M)
		w.add_joint(prev, first, "weld", outer[0].lerp(inn[0], 0.7) * Geom.M)


# ---------------------------------------------------------------- the two pressure shells

static func _hull() -> void:
	var S := {"density": 1.5, "barrier": true, "cut_speed": 220.0}
	# forward: edge 1 the roof (under the keel from 7.6), edge 3 the floor, edge 4 the chin
	_ring(OUTER_F, T, {1: [0.362], 3: [0.14, 0.3, 0.65], 4: [0.3, 0.7]}, {
		"0:0": {"art": "window"},
		"1:0": {"tag": "ROOF-B"},
		"1:1": {"tag": "ROOF-F"},
		"3:0": {"tag": "FLOOR-F"},
		"3:1": {"kind": "hatch", "door": true, "tag": "HATCH-F", "open_dir": Vector2(0.0, 1.2) * Geom.M},
		"4:1": {"kind": "hatch", "door": true, "tag": "HATCH-B", "open_dir": Vector2(-0.7, 1.1) * Geom.M},
	}, S)
	var top := -3.0 + T
	var bot := 4.2 - T
	var bh = _tagged(w.add_piece("bulkhead", R(BH_X, top, BH_X + 0.4, 0.6), {"density": 1.2, "barrier": true, "cut_speed": 240.0, "tag": "BH-BF"}))
	var bh2 = _tagged(w.add_piece("bulkhead", R(BH_X, 2.6, BH_X + 0.4, bot), {"density": 1.2, "barrier": true, "cut_speed": 240.0, "tag": "BH-BF2"}))
	var dr = _tagged(w.add_piece("door", R(BH_X + 0.02, 0.6, BH_X + 0.38, 2.6), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-BF", "open_dir": Vector2(0, -2.0) * Geom.M, "cut_speed": 240.0}))
	_bolt(bh, at(BH_X + 0.2, -2.8, ["hull"]), BH_X + 0.2, top, "weld")
	_bolt(bh2, at(BH_X + 0.2, 4.0, ["hull"]), BH_X + 0.2, bot, "weld")
	_bolt(dr, bh, BH_X + 0.2, 0.6, "weld")
	_bolt(dr, bh2, BH_X + 0.2, 2.6, "weld")
	# aft: edge 0 the roof (under the keel), edge 2 the floor with its hatch
	_ring(OUTER_A, T, {2: [0.12, 0.35]}, {
		"0:0": {"tag": "ROOF-A"},
		"1:0": {"tag": "WALL-A"},
		"2:1": {"kind": "hatch", "door": true, "tag": "HATCH-A", "open_dir": Vector2(0.0, 1.2) * Geom.M},
		"2:2": {"tag": "FLOOR-A"},
	}, S)
	var cl = w.add_joint(at(5.0, 4.0, ["hull"]), null, "clamp", p(5.0, 4.2))
	cl.set_meta("tag", "CL-01")
	var cl2 = w.add_joint(at(66.4, 4.0, ["hull"]), null, "clamp", p(66.4, 4.2))
	cl2.set_meta("tag", "CL-05")


# ---------------------------------------------------------------- the box keel the tanks hang from

static func _keel() -> void:
	var prev = null
	for i in KEEL.size() - 1:
		var k = _tagged(w.add_piece("keel", R(KEEL[i], KY0, KEEL[i + 1], KY1), {"density": 1.5, "cut_speed": 150.0, "tag": "KEEL-%d" % (i + 1)}))
		if prev != null:
			_bolt(prev, k, KEEL[i], -3.45, "weld")
			_bolt(prev, k, KEEL[i], -3.15, "weld")
		prev = k
	# on the two shells' roofs
	for x in [9.0, 13.0]:
		_bolt(at(x, -3.3, ["keel"]), at(x, -2.8, ["hull"]), x, KY1, "weld")
	for x in [61.0, 65.0]:
		_bolt(at(x, -3.3, ["keel"]), at(x, -2.8, ["hull"]), x, KY1, "weld")


# ---------------------------------------------------------------- the three tanks

static func _tanks() -> void:
	for i in 3:
		var n := i + 1
		var x0: float = TANKS[i][0]
		var x1: float = TANKS[i][1]
		var xm := (x0 + x1) * 0.5
		var O := _jacket(i)
		# the jacket: three plates on top and three below; it holds the vacuum
		_ring(O, TJ, {0: [0.3333, 0.6667], 4: [0.3333, 0.6667]}, {
			"0:0": {"tag": "JK%d-1" % n}, "0:1": {"tag": "JK%d-2" % n}, "0:2": {"tag": "JK%d-3" % n},
			"4:1": {"tag": "JK%d-B" % n},
		}, {"density": 1.1, "barrier": true, "cut_speed": 210.0})
		# two hangers from the keel, locked to it and welded to the jacket
		for k in 2:
			var hx: float = x0 + 3.0 if k == 0 else x1 - 3.0
			var hg = _tagged(w.add_piece("strut", R(hx - 0.25, KY1, hx + 0.25, JY0), {"density": 1.3, "cut_speed": 160.0, "tag": "HG%d-%d" % [n, k + 1], "name_key": "p_hanger"}))
			_bolt(hg, at(hx, -3.3, ["keel"]), hx, KY1, "lock")
			_bolt(hg, at(hx, JY0 + 0.15, ["hull"]), hx, JY0, "weld")
		# the inner tank: about 7 t empty, marked to be cut in three
		var tp := _inner(O, GAP)
		var tank = _equip("T-%d" % n, "cryotank", Rect2(x0 + GAP, JY0 + GAP, x1 - x0 - 2.0 * GAP, JY1 - JY0 - 2.0 * GAP),
			{"mass": 7.0, "value": 22000.0, "fragile": 0.15, "cut_speed": 100.0, "room": "J%d" % n, "name_key": "p_cryo_tank"}, _mp(tp))
		var tw := x1 - x0 - 2.0 * GAP
		var sx0 := x0 + GAP + tw / 3.0
		var sx1 := x0 + GAP + tw * 2.0 / 3.0
		tank.set_meta("segments", [[sx0, JY0 + GAP - 0.2, sx0, JY1 - GAP + 0.2], [sx1, JY0 + GAP - 0.2, sx1, JY1 - GAP + 0.2]])
		# keyed supports: two under it, one over it, welded to the jacket, bolted to the tank
		for kx in [x0 + 3.5, x1 - 3.5]:
			var key = w.add_piece("fixture", R(kx - 0.3, JY1 - GAP, kx + 0.3, JY1 - TJ), {"cls": "metal", "dest": "metal", "density": 1.6, "cut_speed": 160.0})
			_bolt(key, at(kx, JY1 - 0.15, ["hull"]), kx, JY1 - TJ, "weld")
			_bolt(key, tank, kx, JY1 - GAP)
		var kt = w.add_piece("fixture", R(xm - 0.3, JY0 + TJ, xm + 0.3, JY0 + GAP), {"cls": "metal", "dest": "metal", "density": 1.6, "cut_speed": 160.0})
		_bolt(kt, at(xm, JY0 + 0.15, ["hull"]), xm, JY0 + TJ, "weld")
		_bolt(kt, tank, xm, JY0 + GAP)
		# on the jacket's top: the relief valve, the temperature sensor; on its side the level gauge
		var psv = _equip("PSV-%d" % n, "pump", Rect2(x0 + 5.3, -2.9, 0.5, 0.5), {"mass": 0.05, "value": 2000.0, "fragile": 0.5, "name_key": "p_psv"})
		_bolt(psv, at(x0 + 5.55, JY0 + 0.15, ["hull"]), x0 + 5.55, JY0)
		var tt = _equip("TT-%d" % n, "panel", Rect2(x0 + 6.8, -2.8, 0.4, 0.4), {"mass": 0.02, "value": 500.0, "fragile": 0.6, "name_key": "p_tank_temp"})
		_bolt(tt, at(x0 + 7.0, JY0 + 0.15, ["hull"]), x0 + 7.0, JY0)
		var lg = _equip("LG-%d" % n, "panel", Rect2(x1, 0.4, 0.3, 1.8), {"mass": 0.03, "value": 800.0, "fragile": 0.5, "name_key": "p_level"})
		_bolt(lg, at(x1 - 0.15, 1.3, ["hull"]), x1, 1.3)
	for k in 3:
		var cx: float = (TANKS[k][0] + TANKS[k][1]) * 0.5
		var cl = w.add_joint(at(cx, JY1 - 0.15, ["hull"]), null, "clamp", p(cx, JY1))
		cl.set_meta("tag", "CL-0%d" % (k + 2))


# ---------------------------------------------------------------- the crew cabin on the keel

static func _cabin() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 230.0}
	# edge 0 its forward wall (the hatch), edge 2 the roof, edge 5 the floor on the keel
	_ring(OUTER_Q, TQ, {0: [0.3, 0.75], 5: [0.5]}, {
		"0:1": {"kind": "hatch", "door": true, "tag": "HATCH-Q", "open_dir": Vector2(0.0, -1.4) * Geom.M},
		"2:0": {"tag": "Q-ROOF"},
	}, S)
	for x in [17.0, 21.0, 25.0, 27.4]:
		_bolt(at(x, -3.78, ["hull"]), at(x, -3.3, ["keel"]), x, KY0, "weld")
	var flo := -3.6 - TQ
	var top := -7.0 + TQ
	for i in 3:
		var bx := 17.0 + i * 2.3
		var bk = _equip("BUNK-%d" % (i + 1), "bunk", Rect2(bx, top, 2.1, 0.6), {"mass": 0.1, "value": 600.0, "fragile": 0.3, "room": "Q", "name_key": "p_bunk"})
		_bolt(bk, at(bx + 0.4, -6.85, ["hull"]), bx + 0.4, top)
		_bolt(bk, at(bx + 1.7, -6.85, ["hull"]), bx + 1.7, top)
	var tb = _equip("TABLE-Q", "module", Rect2(18.0, flo - 0.8, 1.6, 0.8), {"mass": 0.08, "value": 400.0, "fragile": 0.3, "room": "Q", "name_key": "p_table"})
	_bolt(tb, at(18.8, -3.75, ["hull"]), 18.8, flo)
	var su = _equip("SUIT-1", "suit", Rect2(20.4, flo - 1.0, 0.8, 1.0), {"mass": 0.05, "value": 1200.0, "fragile": 0.4, "room": "Q", "name_key": "p_suit"})
	_bolt(su, at(20.8, -3.75, ["hull"]), 20.8, flo, "lock")
	var lk = _equip("LOCKER-Q", "locker", Rect2(23.4, flo - 1.0, 0.9, 1.0), {"mass": 0.15, "value": 800.0, "fragile": 0.3, "room": "Q", "name_key": "p_locker"})
	_bolt(lk, at(23.8, -3.75, ["hull"]), 23.8, flo)
	var env = _equip("ENV-Q", "env", Rect2(25.6, flo - 0.8, 1.6, 0.8), {"mass": 0.3, "value": 1500.0, "fragile": 0.5, "room": "Q", "name_key": "p_env"})
	_bolt(env, at(26.4, -3.75, ["hull"]), 26.4, flo)
	var lq = _equip("LAMP-Q", "lamp", Rect2(24.6, top, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "Q", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lq, at(24.9, -6.85, ["hull"]), 24.88, top)


# ---------------------------------------------------------------- B and F

static func _fore_inside() -> void:
	var top := -3.0 + T
	var bot := 4.2 - T
	var roof := func(x: float): return at(x, -2.8, ["hull"])
	var flo := func(x: float): return at(x, 4.0, ["hull"])
	# the control cabin
	var con = _equip("CON-B", "console", Rect2(4.2, bot - 0.9, 1.2, 0.9), {"mass": 0.3, "value": 4000.0, "fragile": 0.5, "room": "B", "name_key": "p_console"})
	_bolt(con, flo.call(4.8), 4.8, bot)
	var r := Rect2(5.7, bot - 1.2, 0.6, 1.2)
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	var seat = _equip("SEAT-B", "seat", r, {"mass": 0.12, "value": 600.0, "fragile": 0.3, "room": "B", "name_key": "p_seat_p"}, sp)
	_bolt(seat, flo.call(5.9), 5.85, bot)
	var rack = _equip("RACK-B", "nav_rack", Rect2(3.9, top, 0.8, 1.2), {"mass": 0.2, "value": 4500.0, "fragile": 0.7, "room": "B", "name_key": "p_nav"})
	_bolt(rack, roof.call(4.3), 4.3, top)
	var pt = _equip("PANEL-T", "screen", Rect2(5.4, top, 1.8, 0.9), {"mass": 0.2, "value": 4000.0, "fragile": 0.6, "room": "B", "name_key": "p_temp_panel"})
	_bolt(pt, roof.call(5.8), 5.8, top)
	_bolt(pt, roof.call(6.9), 6.9, top)
	var cm = _equip("CARGO-MON", "monitor", Rect2(6.5, -0.4, 0.9, 1.0), {"mass": 0.15, "value": 3000.0, "fragile": 0.6, "room": "B", "name_key": "p_cargo_mon"})
	_bolt(cm, by_tag["BH-BF"], BH_X, 0.1)
	var lb = _equip("LAMP-B", "lamp", Rect2(4.8, top, 0.5, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "B", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lb, roof.call(5.05), 5.05, top)
	# the machinery room
	var ch = _equip("CHILLER-1", "pump", Rect2(8.0, top, 2.6, 2.2), {"mass": 1.8, "value": 16000.0, "fragile": 0.35, "room": "F", "mandatory": true, "name_key": "p_chiller"})
	_bolt(ch, roof.call(8.5), 8.5, top)
	_bolt(ch, roof.call(10.1), 10.1, top)
	var vb = _equip("VBOX", "swb", Rect2(11.0, top, 1.6, 1.8), {"mass": 0.6, "value": 7000.0, "fragile": 0.4, "room": "F", "name_key": "p_valve_box"})
	_bolt(vb, roof.call(11.4), 11.4, top)
	_bolt(vb, roof.call(12.2), 12.2, top)
	var pw = _equip("PWR-F", "cabinet", Rect2(13.0, top, 1.5, 2.6), {"mass": 0.5, "value": 5000.0, "fragile": 0.4, "room": "F", "name_key": "p_hv_cabinet"})
	_bolt(pw, roof.call(13.4), 13.4, top)
	_bolt(pw, roof.call(14.2), 14.2, top)
	var lf = _equip("LAMP-F", "lamp", Rect2(12.65, top, 0.3, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.03, "room": "F", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lf, roof.call(12.8), 12.8, top)
	var hx = _equip("HX", "radiator", Rect2(8.0, bot - 2.2, 3.0, 2.2), {"mass": 0.9, "value": 6000.0, "fragile": 0.35, "room": "F", "name_key": "p_hx"})
	_bolt(hx, flo.call(8.6), 8.6, bot)
	_bolt(hx, flo.call(10.4), 10.4, bot, "weld")
	# the radiator fins over and under it
	var f1 = _equip("RAD-F1", "radiator", Rect2(8.4, -6.6, 5.4, 3.0), {"mass": 0.8, "value": 3000.0, "fragile": 0.3, "name_key": "p_fin"},
		_mp([Vector2(8.4, KY0), Vector2(9.0, -6.6), Vector2(13.2, -6.6), Vector2(13.8, KY0)]))
	_bolt(f1, at(9.4, -3.3, ["keel"]), 9.4, KY0)
	_bolt(f1, at(12.8, -3.3, ["keel"]), 12.8, KY0)
	var f2 = _equip("RAD-F2", "radiator", Rect2(8.2, 4.2, 2.8, 2.4), {"mass": 0.6, "value": 3000.0, "fragile": 0.3, "name_key": "p_fin"},
		_mp([Vector2(8.2, 4.2), Vector2(11.0, 4.2), Vector2(10.6, 6.6), Vector2(8.6, 6.6)]))
	_bolt(f2, flo.call(8.7), 8.7, 4.2)
	_bolt(f2, flo.call(10.5), 10.5, 4.2)


# ---------------------------------------------------------------- the cargo deck on the keel

static func _deck() -> void:
	var keel := func(x: float): return at(x, -3.3, ["keel"])
	var b1 = _equip("BOG-1", "pump", Rect2(30.6, -5.6, 2.2, 2.0), {"mass": 1.0, "value": 8000.0, "fragile": 0.35, "name_key": "p_bog"})
	_bolt(b1, keel.call(31.0), 31.0, KY0)
	_bolt(b1, keel.call(32.4), 32.4, KY0)
	var b2 = _equip("BOG-2", "pump", Rect2(33.2, -5.6, 2.2, 2.0), {"mass": 1.0, "value": 8000.0, "fragile": 0.35, "name_key": "p_bog"})
	_bolt(b2, keel.call(33.6), 33.6, KY0)
	_bolt(b2, keel.call(35.0), 35.0, KY0)
	var rq = _equip("RELIQ", "cabinet", Rect2(36.0, -6.4, 2.4, 2.8), {"mass": 1.4, "value": 14000.0, "fragile": 0.35, "mandatory": true, "name_key": "p_reliq"})
	_bolt(rq, keel.call(36.4), 36.4, KY0)
	_bolt(rq, keel.call(38.0), 38.0, KY0)
	var n2 = _equip("N2-GEN", "module", Rect2(39.0, -5.4, 1.8, 1.8), {"mass": 0.6, "value": 5000.0, "fragile": 0.4, "name_key": "p_n2gen"})
	_bolt(n2, keel.call(39.4), 39.4, KY0)
	_bolt(n2, keel.call(40.4), 40.4, KY0)
	var gd = _equip("GASDET", "monitor", Rect2(41.6, -4.4, 0.6, 0.8), {"mass": 0.05, "value": 1500.0, "fragile": 0.6, "name_key": "p_gas_det"})
	_bolt(gd, keel.call(41.9), 41.9, KY0)
	var fc = _equip("FC-1", "gen", Rect2(43.2, -5.8, 3.0, 2.2), {"mass": 1.2, "value": 12000.0, "fragile": 0.35, "hazard": "gen", "name_key": "p_fuelcell"})
	_bolt(fc, keel.call(43.7), 43.7, KY0)
	_bolt(fc, keel.call(45.7), 45.7, KY0)
	var h2 = _equip("H2-T", "gastank", Rect2(46.8, -6.4, 1.0, 2.8), {"mass": 0.4, "value": 2500.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_h2"})
	_bolt(h2, keel.call(47.3), 47.3, KY0, "lock")
	var o2 = _equip("O2-T", "gastank", Rect2(48.1, -6.4, 1.0, 2.8), {"mass": 0.4, "value": 2500.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_o2"})
	_bolt(o2, keel.call(48.6), 48.6, KY0, "lock")
	var vm = _tagged(w.add_piece("beam", R(51.0, -8.6, 51.4, KY0), {"density": 1.2, "cut_speed": 180.0, "tag": "VENT-M", "name_key": "p_vent_mast"}))
	_bolt(vm, keel.call(51.2), 51.2, KY0, "weld")
	var pn = _equip("PNL-D", "panel", Rect2(53.0, -4.2, 3.6, 0.6), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, keel.call(53.5), 53.5, KY0)
	_bolt(pn, keel.call(56.1), 56.1, KY0)
	var f1 = _equip("RAD-A1", "radiator", Rect2(59.8, -6.6, 5.4, 3.0), {"mass": 0.8, "value": 3000.0, "fragile": 0.3, "name_key": "p_fin"},
		_mp([Vector2(59.8, KY0), Vector2(60.4, -6.6), Vector2(64.6, -6.6), Vector2(65.2, KY0)]))
	_bolt(f1, keel.call(60.8), 60.8, KY0)
	_bolt(f1, keel.call(64.2), 64.2, KY0)


# ---------------------------------------------------------------- A

static func _aft_inside() -> void:
	var top := -3.0 + T
	var bot := 4.2 - T
	var roof := func(x: float): return at(x, -2.8, ["hull"])
	var flo := func(x: float): return at(x, 4.0, ["hull"])
	var ch = _equip("CHILLER-2", "pump", Rect2(60.4, top, 2.6, 2.2), {"mass": 1.8, "value": 16000.0, "fragile": 0.35, "room": "A", "name_key": "p_chiller"})
	_bolt(ch, roof.call(60.9), 60.9, top)
	_bolt(ch, roof.call(62.5), 62.5, top)
	var la = _equip("LAMP-A", "lamp", Rect2(63.05, top, 0.3, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.03, "room": "A", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(la, roof.call(63.2), 63.2, top)
	var pd = _equip("PDB-A", "swb", Rect2(63.5, top, 1.4, 2.2), {"mass": 0.5, "value": 4000.0, "fragile": 0.4, "room": "A", "name_key": "p_swb"})
	_bolt(pd, roof.call(63.9), 63.9, top)
	_bolt(pd, roof.call(64.6), 64.6, top)
	var cp = _equip("COOL-A", "pump", Rect2(65.1, top, 1.2, 1.4), {"mass": 0.3, "value": 2500.0, "fragile": 0.4, "room": "A", "name_key": "p_pump"})
	_bolt(cp, roof.call(65.7), 65.7, top)
	var ht = _equip("HEATER", "grating", Rect2(60.4, bot - 1.8, 2.0, 1.8), {"mass": 0.4, "value": 3000.0, "fragile": 0.35, "room": "A", "name_key": "p_heater"})
	_bolt(ht, flo.call(60.8), 60.8, bot)
	_bolt(ht, flo.call(62.0), 62.0, bot)
	var bat = _equip("BAT-A", "battery", Rect2(62.6, bot - 1.6, 1.6, 1.6), {"mass": 0.8, "value": 5000.0, "fragile": 0.4, "room": "A", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bat, flo.call(63.0), 63.0, bot)
	_bolt(bat, flo.call(63.8), 63.8, bot)
	var fv = _equip("FROST-V", "panel", Rect2(65.9, 0.4, 0.5, 0.8), {"mass": 0.1, "value": 800.0, "fragile": 0.4, "room": "A", "name_key": "p_frost_vent"})
	_bolt(fv, by_tag["WALL-A"], 66.4, 0.8)
	var f2 = _equip("RAD-A2", "radiator", Rect2(60.4, 4.2, 3.2, 2.4), {"mass": 0.6, "value": 3000.0, "fragile": 0.3, "name_key": "p_fin"},
		_mp([Vector2(60.4, 4.2), Vector2(63.6, 4.2), Vector2(63.2, 6.6), Vector2(60.8, 6.6)]))
	_bolt(f2, flo.call(60.9), 60.9, 4.2)
	_bolt(f2, flo.call(63.1), 63.1, 4.2)


# ---------------------------------------------------------------- the thrusters

static func _thrust() -> void:
	var tf = _tagged(w.add_piece("beam", R(66.8, -2.6, 67.4, 3.8), {"density": 1.4, "cut_speed": 150.0, "tag": "THRUST"}))
	for y in [-1.8, 0.0, 1.8, 3.2]:
		_bolt(tf, by_tag["WALL-A"], 66.8, y)
	for i in 2:
		var yc: float = [-1.3, 2.5][i]
		var e = _equip("ENG-%d" % (i + 1), "eng_front", Rect2(67.4, yc - 1.1, 2.0, 2.2), {"mass": 1.2, "value": 6000.0, "fragile": 0.3, "name_key": "p_main"})
		_bolt(e, tf, 67.4, yc - 0.6)
		_bolt(e, tf, 67.4, yc + 0.6, "weld")
		var nz = _equip("NOZ-%d" % (i + 1), "nozzle", Rect2(69.4, yc - 1.3, 2.6, 2.6), {"cls": "metal", "dest": "metal", "mass": 0.5, "cut_speed": 170.0, "name_key": "p_nozzle"},
			_mp([Vector2(69.4, yc - 0.8), Vector2(72.0, yc - 1.3), Vector2(72.0, yc + 1.3), Vector2(69.4, yc + 0.8)]))
		_bolt(nz, e, 69.4, yc - 0.4)
		_bolt(nz, e, 69.4, yc + 0.4)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var dk := -3.8                # cables along the deck, over the keel
	# the bus is the forward switchboard: the fuel cell and the aft battery feed it
	_line("c1", "cable", "power", "FC-1", Vector2(43.6, -4.0), "PWR-F", Vector2(13.6, -1.0), [Vector2(43.0, dk), Vector2(15.2, dk), Vector2(14.8, -1.0)])
	_line("c2", "cable", "power", "BAT-A", Vector2(63.4, 2.4), "PWR-F", Vector2(13.9, -1.4),
		[Vector2(63.4, 2.0), Vector2(59.8, 2.0), Vector2(59.8, -2.15), Vector2(15.25, -2.15), Vector2(15.25, -1.4)])
	_line("c3", "cable", "power", "PWR-F", Vector2(13.9, -1.6), "PDB-A", Vector2(63.8, -1.6),
		[Vector2(15.2, -1.6), Vector2(15.2, -2.05), Vector2(59.7, -2.05), Vector2(59.7, -3.3), Vector2(63.3, -3.3), Vector2(63.3, -1.6)])
	_line("c4", "cable", "power", "PDB-A", Vector2(63.7, -1.2), "CHILLER-2", Vector2(62.6, -1.2))
	_line("c5", "cable", "power", "PDB-A", Vector2(64.7, -1.4), "COOL-A", Vector2(65.4, -1.6), [Vector2(65.0, -1.4)])
	_line("c6", "cable", "power", "PDB-A", Vector2(64.0, -2.3), "LAMP-A", Vector2(63.2, -2.5), [Vector2(63.6, -2.3)])
	_line("c7", "cable", "power", "PWR-F", Vector2(13.2, -1.2), "CHILLER-1", Vector2(10.2, -1.2))
	_line("c8", "cable", "power", "PWR-F", Vector2(13.2, -2.2), "VBOX", Vector2(12.4, -2.0))
	_line("c9", "cable", "power", "PWR-F", Vector2(13.3, -2.4), "LAMP-F", Vector2(12.8, -2.5))
	_line("c10", "cable", "power", "PWR-F", Vector2(13.4, -0.4), "PANEL-T", Vector2(6.6, -2.0), [Vector2(12.0, -0.2), Vector2(7.6, -0.2), Vector2(7.6, -1.5), Vector2(6.6, -1.6)])
	_line("c11", "cable", "power", "PANEL-T", Vector2(6.9, -1.9), "CARGO-MON", Vector2(6.9, 0.0))
	_line("c12", "cable", "power", "PANEL-T", Vector2(5.6, -1.9), "CON-B", Vector2(4.6, 3.2), [Vector2(5.0, -1.5), Vector2(4.6, 2.8)])
	_line("c13", "cable", "power", "CON-B", Vector2(4.4, 3.2), "RACK-B", Vector2(4.3, -1.6))
	_line("c14", "cable", "power", "RACK-B", Vector2(4.5, -2.2), "LAMP-B", Vector2(5.0, -2.5), [Vector2(4.9, -2.2)])
	_line("c15", "cable", "power", "PWR-F", Vector2(13.8, -1.8), "RELIQ", Vector2(36.8, -4.2), [Vector2(15.1, -1.8), Vector2(15.1, -3.9), Vector2(36.8, -3.9)])
	_line("c16", "cable", "power", "RELIQ", Vector2(36.2, -4.6), "BOG-2", Vector2(35.0, -4.6))
	_line("c17", "cable", "power", "BOG-2", Vector2(33.4, -4.6), "BOG-1", Vector2(32.6, -4.6))
	_line("c18", "cable", "power", "RELIQ", Vector2(38.2, -4.6), "N2-GEN", Vector2(39.3, -4.6))
	_line("c19", "cable", "power", "N2-GEN", Vector2(40.6, -4.0), "GASDET", Vector2(41.8, -4.0))
	_line("c20", "cable", "power", "PWR-F", Vector2(14.0, -2.4), "ENV-Q", Vector2(26.0, -4.4), [Vector2(14.9, -2.4), Vector2(14.9, -4.0), Vector2(26.0, -4.0)])
	_line("c21", "cable", "power", "ENV-Q", Vector2(26.6, -4.6), "LAMP-Q", Vector2(24.88, -6.5), [Vector2(26.6, -6.2), Vector2(24.88, -6.2)])
	# the coolant loops: the forward chiller through the heat exchanger, the aft one through its pump
	_line("h1", "pipe", "cool", "CHILLER-1", Vector2(9.0, -0.6), "HX", Vector2(9.0, 1.8))
	_line("h2", "pipe", "cool2", "CHILLER-2", Vector2(62.0, -0.6), "COOL-A", Vector2(65.6, -1.4), [Vector2(62.0, -0.2), Vector2(65.6, -0.2)])
	# the relief valves' vent lines up to the mast; the insulated manifold between the tanks
	for i in 3:
		var n := i + 1
		var x0: float = TANKS[i][0]
		_line("v%d" % n, "pipe", "vent", "PSV-%d" % n, Vector2(x0 + 5.55, -2.8), "VENT-M", Vector2(51.2, -4.0),
			[Vector2(x0 + 5.55, -3.75), Vector2(50.6, -3.75), Vector2(50.6, -4.0)])
	_line("m1", "pipe", "lngm", "T-1", Vector2(27.6, 2.0), "T-2", Vector2(32.0, 2.0), [Vector2(27.6, 3.4), Vector2(32.0, 3.4)])
	_line("m2", "pipe", "lngm", "T-2", Vector2(42.4, 2.0), "T-3", Vector2(46.8, 2.0), [Vector2(42.4, 3.4), Vector2(46.8, 3.4)])


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	_ctrl("G-B", "port", by_tag["ROOF-B"], Vector2(4.4, -2.8), {"medium": "gas", "target": "B"})
	_ctrl("G-F", "port", by_tag["FLOOR-F"], Vector2(14.2, 4.0), {"medium": "gas", "target": "F"})
	_ctrl("G-Q", "port", by_tag["Q-ROOF"], Vector2(20.0, -6.83), {"medium": "gas", "target": "Q"})
	_ctrl("G-A", "port", by_tag["FLOOR-A"], Vector2(64.1, 4.0), {"medium": "gas", "target": "A"})
	var pn = by_tag["PNL-D"]
	_ctrl("K-FC", "switch", pn, Vector2(53.4, -3.9), {"target": "K-FC", "state": true})
	_ctrl("K-BA", "switch", pn, Vector2(54.1, -3.9), {"target": "K-BA", "state": true})
	_ctrl("K-HT", "switch", pn, Vector2(54.8, -3.9), {"target": "K-HT", "state": false})
	_ctrl("E-D01", "test", pn, Vector2(55.5, -3.9), {"medium": "volt", "target": "bus"})
	_ctrl("E-HT", "test", pn, Vector2(56.2, -3.9), {"medium": "volt", "target": "HEATER"})
	_ctrl("H2P", "port", by_tag["H2-T"], Vector2(47.3, -5.0), {"medium": "gas", "target": "H2"})
	_ctrl("O2P", "port", by_tag["O2-T"], Vector2(48.6, -5.0), {"medium": "gas", "target": "O2"})
	_ctrl("RF-1", "port", by_tag["CHILLER-1"], Vector2(9.3, -1.0), {"medium": "coolant", "target": "ref1", "hidden_room": "F"})
	_ctrl("RF-2", "port", by_tag["CHILLER-2"], Vector2(61.7, -1.0), {"medium": "coolant", "target": "ref2", "hidden_room": "A"})
	for i in 3:
		var n := i + 1
		var x0: float = TANKS[i][0]
		_ctrl("JP-%d" % n, "port", by_tag["JK%d-1" % n], Vector2(x0 + 4.2, -2.25), {"medium": "gas", "target": "J%d" % n})
		_ctrl("LP-%d" % n, "port", by_tag["JK%d-3" % n], Vector2(x0 + 8.6, -2.25), {"medium": "lng", "target": "lng%d" % n})
		_ctrl("VP-%d" % n, "port", by_tag["JK%d-3" % n], Vector2(x0 + 9.3, -2.25), {"medium": "gas", "target": "TV%d" % n})
		_ctrl("TT-%d" % n, "probe", by_tag["TT-%d" % n], Vector2(x0 + 7.0, -2.6), {"medium": "cryo", "target": "T-%d" % n})
	for d in [["HATCH-B", ""], ["HATCH-F", ""], ["DR-BF", "B"], ["HATCH-Q", ""], ["HATCH-A", ""]]:
		var dp = by_tag[d[0]]
		var c := Geom.centroid(dp.poly) / Geom.M
		_ctrl(d[0], "door", dp, c, {"target": d[0], "state": false, "hidden_room": d[1]})


static func _rooms() -> void:
	var fi := _inner(OUTER_F, T)
	w.add_room("B", _mp([fi[5], fi[0], fi[1], Vector2(BH_X, fi[1].y), Vector2(BH_X, fi[4].y), fi[4]]))
	w.add_room("F", _mp([Vector2(BH_X + 0.4, fi[2].y), fi[2], fi[3], Vector2(BH_X + 0.4, fi[3].y)]))
	w.add_room("A", _mp(_inner(OUTER_A, T)))
	w.add_room("Q", _mp(_inner(OUTER_Q, TQ)))
	for i in 3:
		w.add_room("J%d" % (i + 1), _mp(_inner(_jacket(i), TJ)))


static func meta() -> Dictionary:
	var rooms := {"B": 101.0, "F": 101.0, "Q": 101.0, "A": 98.0}
	var vessels := {
		"H2": {"V": 0.05, "kpa": 900.0, "piece": "H2-T", "burst": 200.0},
		"O2": {"V": 0.05, "kpa": 900.0, "piece": "O2-T", "burst": 200.0},
	}
	var vols := {
		"ref1": {"fluid": "coolant", "amount": 0.06, "piece": "CHILLER-1", "content": 0.5, "leak": 0.08, "port": "RF-1", "pump": [0.12, 0.008]},
		"ref2": {"fluid": "coolant", "amount": 0.06, "piece": "CHILLER-2", "content": 0.5, "leak": 0.08, "port": "RF-2", "pump": [0.12, 0.008]},
		"lngm": {"fluid": "lng", "amount": 0.012, "nets": ["lngm"], "leak": 0.05, "leak_min": 0.004},
		"cool_line": {"fluid": "coolant", "amount": 0.012, "nets": ["cool", "cool2"], "leak": 0.05, "leak_min": 0.004},
		# the vent lines up to the mast run dry until a relief valve lifts
		"vent": {"fluid": "lng", "amount": 0.0, "nets": ["vent"], "leak": 0.05, "leak_min": 0.004},
	}
	var tanks := {}
	var labels := {"H2-T": "H₂", "O2-T": "O₂", "HEATER": "HEATER", "FC-1": "FC", "RELIQ": "RELIQ", "N2-GEN": "N₂"}
	var cfg := {"G-B": {"rate": 9.0}, "G-F": {"rate": 9.0}, "G-Q": {"rate": 9.0}, "G-A": {"rate": 9.0}, "H2P": {"rate": 0.3}, "O2P": {"rate": 0.3}}
	for i in 3:
		var n := i + 1
		rooms["J%d" % n] = 0.0
		vessels["TV%d" % n] = {"V": 0.4, "kpa": 220.0, "piece": "T-%d" % n, "burst": 200.0}
		vols["lng%d" % n] = {"fluid": "lng", "amount": 1.0, "piece": "T-%d" % n, "content": 2.6, "leak": 0.06, "port": "LP-%d" % n, "pump": [0.04, 0.01], "hazard": 0.02}
		tanks["T-%d" % n] = {"liquid": "lng%d" % n, "vessel": "TV%d" % n, "jacket": "J%d" % n, "T0": -163.0, "kpa0": 220.0,
			"psv": "PSV-%d" % n, "psv_kpa": 300.0, "burst_kpa": 360.0}
		labels["T-%d" % n] = "T-%d  LNG" % n
		cfg["VP-%d" % n] = {"rate": 0.5}
		cfg["JP-%d" % n] = {"rate": 20.0}
	return {
		"id": "fr26",
		"name": "FR-26 FROSTLINE",
		"title": ["FR-26「霜线」低温运输船 · 72 m", "FR-26 FROSTLINE · CRYOGENIC CARRIER · 72 m"],
		"contract": "FR-26",
		"length": 72.0,
		"value": {"total": 313000.0, "metal": 24000.0},
		"clamps": [[5.0, 4.2], [22.4, JY1], [37.2, JY1], [52.0, JY1], [66.4, 4.2]],
		"room_names": {"B": "room_fB", "F": "room_fF", "Q": "room_fQ", "A": "room_fA", "J1": "room_fJ", "J2": "room_fJ", "J3": "room_fJ"},
		# the cargo's temperature (scripts/cryo.gd)
		"cryo": {"tanks": tanks, "chillers": ["CHILLER-1", "CHILLER-2"], "heater": {"piece": "HEATER", "tank": "T-3"}},
		"gas": {"rooms": rooms, "vessels": vessels, "valves": [], "value": 900.0},
		"power": {
			"bus": "PWR-F",
			"sources": [
				{"piece": "FC-1", "kind": "gen", "volts": 400.0, "cable": "c1", "switch": "K-FC", "running": true},
				{"piece": "BAT-A", "kind": "battery", "volts": 400.0, "local_volts": 48.0, "cable": "c2", "switch": "K-BA", "charge": 0.85, "drain": 0.0004},
			],
			# the anti-freeze heater on its own little supply: off, unless someone left it on
			"isolated": [{"piece": "HEATER", "volts": 48.0, "charge": 1.0, "switch": "K-HT"}],
			"lamps": {"B": "LAMP-B", "F": "LAMP-F", "Q": "LAMP-Q", "A": "LAMP-A"},
		},
		"fluids": {"volumes": vols, "joins": [], "value": {"lng": 48000.0, "coolant": 300.0}},
		"ctrls_cfg": cfg,
		"labels": labels,
		"hints": {},
		"market": {
			"class": "FR", "name": ["霜线级低温运输船", "FROSTLINE-CLASS CRYOGENIC CARRIER"], "time": 45.0,
			"rooms": {"B": [0.2, 40.0, 101.0], "F": [0.25, 40.0, 101.0], "Q": [0.2, 40.0, 101.0], "A": [0.3, 40.0, 100.0]},
			"vessels": {"H2": [0.25, 50.0, 200.0, 600.0, 900.0], "O2": [0.25, 50.0, 200.0, 600.0, 900.0]},
			"charge": {"BAT-A": [0.15, 1.0]},
			"fluids": {"lng1": [0.55, 1.0], "lng2": [0.55, 1.0], "lng3": [0.55, 1.0]},
			"knockable": ["CON-B", "RACK-B", "PANEL-T", "CARGO-MON", "VBOX", "GASDET", "ENV-Q", "N2-GEN"],
			"drift": ["LOCKER-Q", "TABLE-Q", "SUIT-1"],
			"section_x": 29.8,
			"slots": {
				"psv_stuck": {"tanks": ["T-1", "T-2", "T-3"]},
				"heater_live": {"switch": "K-HT"},
				"jacket_loss": {"tanks": ["T-1", "T-2", "T-3"]},
			},
			"mechanisms": true,
		},
		"procedures": {
			"CHILLER-1": [
				{"do": "hose", "ctrl": "G-F"},
				{"do": "wait", "until": {"P": ["F", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HATCH-F"},
				{"do": "wait", "until": {"open": ["F"]}, "max": 5.0},
				{"do": "hose", "ctrl": "RF-1"},
				{"do": "wait", "until": {"fluid": ["ref1", "<", 0.02]}, "max": 120.0},
				{"do": "operate", "ctrl": "K-FC"},
				{"do": "operate", "ctrl": "K-BA"},
				{"do": "measure", "ctrl": "E-D01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "CHILLER-1"},
				{"do": "deliver", "piece": "CHILLER-1", "zone": "equip"},
			],
			"RELIQ": [
				{"do": "operate", "ctrl": "K-FC"},
				{"do": "operate", "ctrl": "K-BA"},
				{"do": "measure", "ctrl": "E-D01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "RELIQ"},
				{"do": "deliver", "piece": "RELIQ", "zone": "equip"},
			],
		},
	}
