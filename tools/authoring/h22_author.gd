class_name H22Author
# Authoring script for H-22 "Double Hook", the 38 m engineering tug
# (design/ships/H-22_双钩_设计稿.md, structure: design/ships/H-22_结构图.png).
# Not part of the game: tools/ship_export.gd runs it and writes ships/h22.json.
# Metres, x bow (0) to stern (37.6), y down.
#
# The work is outside the hull: a heavy H-frame at the bow carries two tow arms
# (a fixed sleeve on a pivot, a telescopic inner section, a magnetic tow head at
# the tip) driven by exposed hydraulic cylinders. Behind the frame a short thick
# hull: the control cabin C over the hydraulic bay Y, the power room P aft, then
# three short wide nozzles on a thrust frame.
# What it asks of you: an arm locked under load (pins in, accumulator charged:
# cut its pivot and it springs), tow heads that stay magnetised until degaussed
# with their coil supply dead, hydraulic oil and stored pressure, parts too heavy
# for the 3 t grapple.

const T := 0.42
const OUTER := [Vector2(16.0, 3.0), Vector2(16.0, -3.0), Vector2(17.2, -4.25), Vector2(29.8, -4.25), Vector2(31.0, -3.0),
	Vector2(31.0, 3.0), Vector2(29.8, 4.25), Vector2(17.2, 4.25)]
const CUTS := {2: [0.24, 0.47, 0.74], 4: [0.5], 6: [0.33, 0.62, 0.81, 0.937]}
const PLATE_TAGS := {2: ["TOP-1", "TOP-2", "TOP-3", "TOP-4"]}
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var inner: Array = []
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


static func _inner_outline() -> Array:
	var n := OUTER.size()
	var out: Array = []
	for i in n:
		var a: Vector2 = OUTER[(i - 1 + n) % n]
		var b: Vector2 = OUTER[i]
		var c: Vector2 = OUTER[(i + 1) % n]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var n1 := Vector2(-d1.y, d1.x)
		var n2 := Vector2(-d2.y, d2.x)
		var hit = Geometry2D.line_intersects_line(a + n1 * T, d1, b + n2 * T, d2)
		out.append(hit if hit != null else b + n1 * T)
	return out


static func build(world) -> void:
	w = world
	by_tag = {}
	inner = _inner_outline()
	_hull()
	_frame()
	_arms()
	_inside()
	_aft()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	inner = _inner_outline()
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt", tag: String = "") -> void:
	if a == null or b == null:
		push_warning("H22 joint missing a piece at %s,%s" % [x, y])
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


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	var S := {"density": 1.6, "barrier": true, "cut_speed": 230.0}
	var n := OUTER.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = OUTER[i]
		var o1: Vector2 = OUTER[(i + 1) % n]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[(i + 1) % n]
		var st: Array = [0.0]
		st.append_array(CUTS.get(i, []))
		st.append(1.0)
		for k in st.size() - 1:
			var a := o0.lerp(o1, st[k])
			var b := o0.lerp(o1, st[k + 1])
			var c := i0.lerp(i1, st[k + 1])
			var d := i0.lerp(i1, st[k])
			var opts := S.duplicate()
			if i == 1:
				opts["art"] = "window"                     # the forward windows over the H-frame
			if PLATE_TAGS.has(i):
				opts["tag"] = PLATE_TAGS[i][k]
			var kind := "hull"
			if i == 6 and k == 3:
				kind = "hatch"                              # the hydraulic bay's floor hatch
				opts["door"] = true
				opts["tag"] = "HATCH-Y"
				opts["open_dir"] = Vector2(1.5, 0) * Geom.M
			var pc = _tagged(w.add_piece(kind, _mp([a, b, c, d]), opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
			else:
				first = pc
			prev = pc
	w.add_joint(prev, first, "weld", OUTER[0].lerp(inner[0], 0.3) * Geom.M)
	w.add_joint(prev, first, "weld", OUTER[0].lerp(inner[0], 0.7) * Geom.M)
	for cl in [[21.0, 4.25, "CL-01"], [27.0, 4.25, "CL-02"]]:
		var j = w.add_joint(at(cl[0], cl[1] - 0.15, ["hull"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# ---------------------------------------------------------------- the H-frame: two posts, a crossbar, gussets

static func _frame() -> void:
	var B := {"density": 1.5, "cut_speed": 110.0}
	var ff = _tagged(w.add_piece("beam", R(12.8, -6.35, 13.85, 6.35), B.merged({"tag": "FRAME-F"})))
	var fr = _tagged(w.add_piece("beam", R(15.0, -5.2, 16.0, 5.2), B.merged({"tag": "FRAME-R"})))
	var fx = _tagged(w.add_piece("beam", R(13.85, -0.75, 15.0, 0.75), B.merged({"tag": "FRAME-X"})))
	for y in [-0.5, 0.0, 0.5]:
		_bolt(fx, ff, 13.85, y)
		_bolt(fx, fr, 15.0, y)
	for sg in [-1.0, 1.0]:
		var g1 = w.add_piece("strut", _mp([Vector2(13.85, sg * 0.75), Vector2(15.0, sg * 0.75), Vector2(15.0, sg * 2.0)]), B)
		var g2 = w.add_piece("strut", _mp([Vector2(13.85, sg * 4.6), Vector2(15.0, sg * 4.6), Vector2(13.85, sg * 5.6)]), B)
		_bolt(g1, ff, 13.85, sg * 0.8, "weld")
		_bolt(g1, fr, 15.0, sg * 1.2, "weld")
		_bolt(g2, ff, 13.85, sg * 5.0, "weld")
		_bolt(g2, fr, 15.0, sg * 4.65, "weld")
	# the rear post bolts to the hull's forward wall
	for y in [-2.4, -1.2, 1.2, 2.4]:
		_bolt(fr, at(16.2, y, ["hull"]), 16.0, y)


# ---------------------------------------------------------------- the tow arms

static func _arms() -> void:
	var ff = by_tag["FRAME-F"]
	for sg in [-1.0, 1.0]:
		var u := "U" if sg < 0 else "L"
		var Y := func(y: float) -> float: return y * sg
		# the fixed sleeve on its pivot: locked to the frame by two pins, held by the cylinder
		var arm = _equip("ARM-" + u, "cover", Rect2(6.6, minf(Y.call(5.65), Y.call(4.35)), 6.2, 1.3), {"mass": 2.6, "value": 4000.0, "fragile": 0.2, "name_key": "p_tow_arm", "cut_speed": 110.0})
		# the telescopic inner section and the tow head at its tip
		var tel = _equip("TEL-" + u, "cover", Rect2(2.3, minf(Y.call(5.38), Y.call(4.62)), 4.3, 0.76), {"mass": 1.1, "value": 2000.0, "fragile": 0.2, "name_key": "p_tow_tel", "cut_speed": 120.0})
		_bolt(tel, arm, 6.6, Y.call(4.8))
		_bolt(tel, arm, 6.6, Y.call(5.2))
		var hp: Array = []
		for q in [[2.3, 5.9], [1.0, 6.25], [0.1, 5.7], [0.0, 4.1], [0.55, 3.55], [1.35, 3.75], [1.4, 4.25], [1.0, 4.55], [1.0, 5.2], [2.3, 5.25]]:
			hp.append(Vector2(q[0], Y.call(q[1])))
		var hbox := Rect2(0.0, minf(Y.call(6.25), Y.call(3.55)), 2.3, 2.7)
		var th = _equip("TH-" + u, "hook", hbox, {"mass": 2.2, "value": 16000.0, "fragile": 0.3, "name_key": "p_tow_head"}, _mp(hp))
		_bolt(th, tel, 2.3, Y.call(5.0))
		_bolt(th, tel, 2.3, Y.call(5.2))
		var ts = _equip("TS-%d" % (1 if sg < 0 else 2), "panel", Rect2(2.5, minf(Y.call(5.62), Y.call(5.38)), 0.55, 0.24), {"mass": 0.04, "value": 2500.0, "fragile": 0.7, "name_key": "p_tension"})
		_bolt(ts, tel, 2.75, Y.call(5.38))
		# the pins first (they come out before the pivot does), then the pivot itself
		_bolt(arm, ff, 12.8, Y.call(4.55), "lock", "PIN-%s1" % u)
		_bolt(arm, ff, 12.8, Y.call(5.45), "lock", "PIN-%s2" % u)
		_bolt(arm, ff, 12.8, Y.call(5.0), "bolt", "PIV-" + u)
		# the drive cylinder: from the frame to the sleeve, out in the open
		var a := Vector2(13.6, Y.call(2.6))
		var b := Vector2(10.4, Y.call(4.32))
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x) * 0.16
		var cy = _equip("CYL-" + u, "", Rect2(10.4, minf(a.y, b.y), 3.2, absf(b.y - a.y)), {"mass": 0.6, "value": 3500.0, "fragile": 0.4, "name_key": "p_cylinder"},
			_mp([a + dir * 0.25 + nrm, b - dir * 0.05 + nrm, b - dir * 0.05 - nrm, a + dir * 0.25 - nrm]))
		_bolt(cy, ff, 13.45, Y.call(2.68))
		_bolt(cy, arm, 10.55, Y.call(4.35))


# ---------------------------------------------------------------- inside: cabin C, hydraulic bay Y, power room P

static func _inside() -> void:
	var dk = _tagged(w.add_piece("deck", R(16.45, -0.45, 18.2, -0.15), {"density": 1.2, "barrier": true, "cut_speed": 240.0, "tag": "DK-1"}))
	var dk2 = _tagged(w.add_piece("deck", R(19.1, -0.45, 23.0, -0.15), {"density": 1.2, "barrier": true, "cut_speed": 240.0, "tag": "DK-2"}))
	var hatch = _tagged(w.add_piece("door", R(18.2, -0.45, 19.1, -0.15), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-CY", "open_dir": Vector2(0.85, 0) * Geom.M, "cut_speed": 240.0}))
	_bolt(dk, at(16.3, -0.3, ["hull"]), 16.45, -0.3, "weld")
	_bolt(hatch, dk, 18.2, -0.3, "weld")
	_bolt(hatch, dk2, 19.1, -0.3, "weld")
	var bh = _tagged(w.add_piece("bulkhead", R(23.0, -3.83, 23.3, 1.0), {"density": 1.2, "barrier": true, "cut_speed": 260.0, "tag": "BH-P"}))
	var bdr = _tagged(w.add_piece("door", R(23.02, 1.0, 23.28, 3.83), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-P", "open_dir": Vector2(0, -2.6) * Geom.M, "cut_speed": 240.0}))
	_bolt(bh, at(23.15, -4.0, ["hull"]), 23.15, -3.83, "weld")
	_bolt(bdr, bh, 23.15, 1.0, "weld")
	_bolt(dk2, bh, 23.0, -0.3, "weld")
	var top := -3.83
	var flo := -0.45
	# C: the tow operations console, the seat, load monitoring, the emergency cut-off, life support
	var con = _equip("CON-H", "console", Rect2(16.75, flo - 1.0, 1.25, 1.0), {"mass": 0.4, "value": 4000.0, "fragile": 0.5, "room": "C", "name_key": "p_tow_console"})
	_bolt(con, dk, 17.0, flo)
	_bolt(con, dk, 17.8, flo)
	var r := Rect2(18.25, flo - 1.75, 0.75, 1.75)
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	var seat = _equip("SEAT-H", "seat", r, {"mass": 0.12, "value": 600.0, "fragile": 0.3, "room": "C", "name_key": "p_seat_p"}, sp)
	_bolt(seat, dk, 18.4, flo)
	_bolt(seat, dk, 18.9, flo, "lock")
	var lmu = _equip("LMU", "nav_rack", Rect2(20.0, flo - 2.15, 0.75, 2.15), {"mass": 0.25, "value": 6000.0, "fragile": 0.8, "room": "C", "name_key": "p_load_mon"})
	_bolt(lmu, dk2, 20.2, flo)
	_bolt(lmu, dk2, 20.55, flo)
	var esd = _equip("ESD", "panel", Rect2(21.0, top + 0.05, 0.8, 0.9), {"mass": 0.15, "value": 2000.0, "fragile": 0.4, "room": "C", "name_key": "p_esd"})
	_bolt(esd, at(21.4, -4.0, ["hull"]), 21.4, top)
	var env = _equip("ENV-H", "env", Rect2(21.95, flo - 0.8, 0.95, 0.8), {"mass": 0.3, "value": 1500.0, "fragile": 0.5, "room": "C", "name_key": "p_env"})
	_bolt(env, dk2, 22.2, flo)
	_bolt(env, dk2, 22.7, flo)
	var ovh = _equip("OVH-H", "overhead", Rect2(17.8, top + 0.02, 1.9, 0.3), {"mass": 0.06, "value": 800.0, "fragile": 0.5, "room": "C", "name_key": "p_ovh"})
	_bolt(ovh, at(18.7, -4.0, ["hull"]), 18.7, top)
	# Y: the hydraulic power unit (oil), the accumulator (charged), the arm valve block
	var bot := 3.83
	var hpu = _equip("HPU", "pump", Rect2(16.9, bot - 1.45, 1.9, 1.45), {"mass": 1.1, "value": 9000.0, "fragile": 0.35, "room": "Y", "name_key": "p_hpu"})
	_bolt(hpu, at(17.3, 4.0, ["hull"]), 17.3, bot)
	_bolt(hpu, at(17.9, 4.0, ["hull"]), 17.9, bot)
	var acc = _equip("ACC", "gastank", Rect2(19.1, bot - 2.8, 0.85, 2.8), {"mass": 0.5, "value": 3000.0, "fragile": 0.3, "room": "Y", "hazard": "gas_tank", "name_key": "p_accumulator"})
	_bolt(acc, at(19.7, 4.0, ["hull"]), 19.7, bot)
	_bolt(acc, at(19.9, 4.0, ["hull"]), 19.9, bot)
	var vb = _equip("VALVES", "swb", Rect2(20.3, bot - 1.05, 2.2, 1.05), {"mass": 0.4, "value": 3500.0, "fragile": 0.4, "room": "Y", "name_key": "p_valve_block"})
	_bolt(vb, at(20.6, 4.0, ["hull"]), 20.6, bot)
	_bolt(vb, at(22.2, 4.0, ["hull"]), 22.2, bot)
	# P: battery, capacitor bank, the coil supply cabinet (HV), cooling, the main switchboard
	var bat = _equip("BAT-H", "battery", Rect2(23.6, top, 1.7, 2.3), {"mass": 0.9, "value": 5000.0, "fragile": 0.4, "room": "P", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bat, at(24.0, -4.0, ["hull"]), 24.0, top)
	_bolt(bat, at(25.0, -4.0, ["hull"]), 25.0, top)
	var cap = _equip("CAP-H", "cap", Rect2(25.5, top, 1.0, 2.3), {"mass": 0.5, "value": 3000.0, "fragile": 0.4, "room": "P", "hazard": "cap", "name_key": "p_cap"})
	_bolt(cap, at(26.0, -4.0, ["hull"]), 26.0, top)
	var coil = _equip("COIL-PWR", "swb", Rect2(26.8, top, 2.2, 3.0), {"mass": 1.0, "value": 8000.0, "fragile": 0.4, "room": "P", "name_key": "p_coil_pwr"})
	_bolt(coil, at(27.3, -4.0, ["hull"]), 27.3, top)
	_bolt(coil, at(28.5, -4.0, ["hull"]), 28.5, top)
	var cool = _equip("COOL-H", "radiator", Rect2(23.6, bot - 2.4, 2.6, 2.4), {"mass": 0.8, "value": 5000.0, "fragile": 0.35, "room": "P", "name_key": "p_radiator"})
	_bolt(cool, at(24.0, 4.0, ["hull"]), 24.0, bot)
	_bolt(cool, at(25.8, 4.0, ["hull"]), 25.8, bot)
	var cp = _equip("CP-H", "pump", Rect2(26.6, bot - 1.7, 1.3, 1.7), {"mass": 0.4, "value": 2500.0, "fragile": 0.4, "room": "P", "name_key": "p_pump"})
	_bolt(cp, at(27.2, 4.0, ["hull"]), 27.2, bot)
	var swb = _equip("SWB-H", "swb", Rect2(28.2, bot - 2.9, 1.8, 2.9), {"mass": 0.45, "value": 900.0, "fragile": 0.4, "room": "P", "name_key": "p_swb"})
	_bolt(swb, at(28.6, 4.0, ["hull"]), 28.6, bot)
	_bolt(swb, at(29.6, 4.0, ["hull"]), 29.6, bot)
	for lp in [["LAMP-C", 20.5, "C", top], ["LAMP-P", 29.3, "P", top]]:
		var lx: float = lp[1]
		var l = _equip(lp[0], "lamp", Rect2(lx - 0.28, lp[3], 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": lp[2], "cut_speed": 260.0, "name_key": "p_lamp"})
		_bolt(l, at(lx, -4.0, ["hull"]), lx, lp[3])
	# the outside panel on the roof over P: battery switch, test point, capacitor bleed, degauss
	var pn = _equip("PNL-H", "panel", Rect2(24.5, -4.85, 3.4, 0.6), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, at(25.0, -4.0, ["hull"]), 25.0, -4.25)
	_bolt(pn, at(27.4, -4.0, ["hull"]), 27.4, -4.25)


# ---------------------------------------------------------------- aft: thrust frame, three nozzles, propellant, stabilisers

static func _aft() -> void:
	var tf = _tagged(w.add_piece("beam", R(31.0, -3.0, 32.0, 3.0), {"density": 1.4, "cut_speed": 150.0, "tag": "THRUST"}))
	for y in [-2.4, -0.8, 0.8, 2.4]:
		_bolt(tf, at(30.8, y, ["hull"]), 31.0, y)
	for i in 3:
		var yc: float = [-2.15, 0.0, 2.15][i]
		var e = _equip("MAIN-H%d" % (i + 1), "eng_front", Rect2(32.0, yc - 0.85, 1.6, 1.7), {"mass": 1.4, "value": 6000.0, "fragile": 0.3, "name_key": "p_main"})
		_bolt(e, tf, 32.0, yc - 0.5)
		_bolt(e, tf, 32.0, yc + 0.5)
		var nz = _equip("NOZ-H%d" % (i + 1), "nozzle", Rect2(33.6, yc - 1.05, 2.8, 2.1), {"cls": "metal", "dest": "metal", "mass": 0.6, "cut_speed": 180.0, "name_key": "p_nozzle"},
			_mp([Vector2(33.6, yc - 0.7), Vector2(36.4, yc - 1.05), Vector2(36.4, yc + 1.05), Vector2(33.6, yc + 0.7)]))
		_bolt(nz, e, 33.6, yc - 0.4)
		_bolt(nz, e, 33.6, yc + 0.4)
	for sg in [-1.0, 1.0]:
		var sb = _tagged(w.add_piece("beam", R(29.0, sg * 4.25, 37.6, sg * 4.85), {"density": 1.3, "cut_speed": 150.0, "tag": "STAB-%s" % ("U" if sg < 0 else "L")}))
		_bolt(sb, at(29.5, sg * 4.1, ["hull"]), 29.5, sg * 4.25)
		_bolt(sb, at(30.5, sg * 3.5, ["hull"]), 30.6, sg * 4.25)
		var fin = w.add_piece("strut", _mp([Vector2(35.6, sg * 4.85), Vector2(37.6, sg * 4.85), Vector2(37.0, sg * 6.0), Vector2(35.9, sg * 6.0)]), {"density": 1.2, "cut_speed": 200.0})
		_bolt(fin, sb, 36.0, sg * 4.85, "weld")
		_bolt(fin, sb, 37.2, sg * 4.85, "weld")
		var pt = _equip("PROP-%d" % (1 if sg < 0 else 2), "fueltank", Rect2(32.1, 3.2 if sg > 0 else -4.05, 2.8, 0.85), {"mass": 0.4, "value": 1500.0, "fragile": 0.35, "hazard": "fuel_tank", "name_key": "p_fueltank"})
		_bolt(pt, sb, 32.6, sg * 4.25, "lock")
		_bolt(pt, sb, 34.4, sg * 4.25, "lock")
		var q = _equip("RCS-H%d" % (1 if sg < 0 else 2), "rcs_quad", Rect2(36.9, -4.25 if sg < 0 else 3.65, 0.9, 0.6), {"mass": 0.1, "value": 500.0, "fragile": 0.3, "name_key": "p_att"})
		_bolt(q, sb, 37.3, sg * 4.25)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var top := -3.83
	# power: battery and capacitors into the switchboard; the coil supply; out along each arm to its head
	_line("c1", "cable", "power", "BAT-H", Vector2(25.2, -1.7), "SWB-H", Vector2(28.4, 1.2), [Vector2(25.2, -1.3), Vector2(28.4, -1.3)])
	_line("c2", "cable", "power", "CAP-H", Vector2(26.0, -1.6), "SWB-H", Vector2(28.8, 1.2), [Vector2(26.0, -1.1), Vector2(28.8, -1.1)])
	_line("c3", "cable", "power", "SWB-H", Vector2(29.6, 1.0), "COIL-PWR", Vector2(28.8, -0.9), [Vector2(29.6, -0.7), Vector2(28.8, -0.7)])
	_line("c4", "cable", "power", "COIL-PWR", Vector2(27.0, -1.0), "TH-U", Vector2(1.8, -5.5), [Vector2(26.6, -1.0), Vector2(26.6, -2.4), Vector2(23.4, -2.4), Vector2(23.4, -4.4), Vector2(16.3, -4.4), Vector2(14.6, -3.0), Vector2(13.9, -4.2), Vector2(7.0, -4.2), Vector2(2.3, -5.5)])
	_line("c5", "cable", "power", "COIL-PWR", Vector2(27.2, -1.0), "TH-L", Vector2(1.8, 5.5), [Vector2(27.2, -0.6), Vector2(23.5, -0.6), Vector2(23.5, 4.45), Vector2(16.3, 4.45), Vector2(14.6, 3.0), Vector2(13.9, 4.2), Vector2(7.0, 4.2), Vector2(2.3, 5.5)])
	_line("c6", "cable", "power", "SWB-H", Vector2(28.4, 1.0), "CON-H", Vector2(17.6, -1.2), [Vector2(28.0, 0.9), Vector2(23.5, 0.9), Vector2(23.5, -0.3), Vector2(17.6, -0.6)])
	_line("c7", "cable", "power", "SWB-H", Vector2(29.0, 1.0), "LAMP-P", Vector2(29.3, top + 0.08), [Vector2(29.0, -2.0), Vector2(29.3, -2.0)])
	_line("c8", "cable", "power", "LAMP-P", Vector2(29.1, top + 0.08), "LAMP-C", Vector2(20.6, top + 0.08), [Vector2(23.4, top + 0.08)])
	_line("c9", "cable", "power", "SWB-H", Vector2(28.8, 1.0), "HPU", Vector2(18.6, 3.0), [Vector2(28.8, 3.9), Vector2(23.4, 3.9), Vector2(18.6, 3.9)])
	# the load monitor reads the upper tension sensor on its own 24 V supply, apart from the main bus
	_line("cn", "cable", "nav", "LMU", Vector2(20.2, -1.0), "TS-1", Vector2(2.75, -5.5), [Vector2(20.2, -3.5), Vector2(16.3, -4.3), Vector2(14.6, -2.9), Vector2(13.9, -4.0), Vector2(7.0, -4.0), Vector2(3.2, -5.45)])
	# hydraulics: the power unit and the accumulator into the valve block; one run out to each cylinder
	_line("h1", "pipe", "hyd", "HPU", Vector2(18.75, 3.0), "ACC", Vector2(19.15, 3.0))
	_line("h2", "pipe", "hyd", "ACC", Vector2(19.9, 3.3), "VALVES", Vector2(20.35, 3.3))
	_line("h3", "pipe", "hyd", "VALVES", Vector2(21.0, 2.8), "CYL-U", Vector2(13.4, -2.8), [Vector2(21.0, 0.3), Vector2(16.3, 0.3), Vector2(16.0, -0.6), Vector2(13.6, -2.6)])
	_line("h4", "pipe", "hyd", "VALVES", Vector2(21.4, 2.8), "CYL-L", Vector2(13.4, 2.8), [Vector2(21.4, 0.6), Vector2(16.3, 0.6), Vector2(16.0, 0.6), Vector2(13.6, 2.6)])
	# propellant to the nozzles
	_line("p1", "pipe", "fuel", "PROP-1", Vector2(33.0, -3.25), "MAIN-H1", Vector2(33.0, -2.9))
	_line("p2", "pipe", "fuel", "PROP-2", Vector2(33.0, 3.25), "MAIN-H3", Vector2(33.0, 2.9))


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	_ctrl("GAS-C", "port", at(19.5, -4.1, ["hull"]), Vector2(19.5, -4.4), {"medium": "gas", "target": "C"})
	_ctrl("GAS-Y", "port", at(20.0, 4.1, ["hull"]), Vector2(20.0, 4.4), {"medium": "gas", "target": "Y"})
	_ctrl("GAS-P", "port", at(28.0, -4.1, ["hull"]), Vector2(28.4, -4.4), {"medium": "gas", "target": "P"})
	var pn = by_tag["PNL-H"]
	_ctrl("K-H", "switch", pn, Vector2(24.9, -4.55), {"target": "K-H", "state": true})
	_ctrl("E-H01", "test", pn, Vector2(25.6, -4.55), {"medium": "volt", "target": "bus"})
	_ctrl("E-CAP", "discharge", pn, Vector2(26.3, -4.55), {"target": "cap"})
	_ctrl("DEGAUSS", "degauss", pn, Vector2(27.2, -4.55), {"target": "TH"})
	_ctrl("ACC-P", "port", by_tag["ACC"], Vector2(19.5, 1.2), {"medium": "gas", "target": "ACC", "hidden_room": "Y"})
	_ctrl("HYD-P", "port", by_tag["HPU"], Vector2(17.2, 2.6), {"medium": "hydraulic", "target": "hyd", "hidden_room": "Y"})
	_ctrl("PROP-1P", "port", by_tag["PROP-1"], Vector2(34.6, -3.62), {"medium": "fuel", "target": "prop1"})
	_ctrl("PROP-2P", "port", by_tag["PROP-2"], Vector2(34.6, 3.62), {"medium": "fuel", "target": "prop2"})
	for u in ["U", "L"]:
		var th = by_tag["TH-" + u]
		var c := Geom.centroid(th.poly) / Geom.M
		_ctrl("M-TH" + u, "probe", th, Vector2(0.6, -4.3 if u == "U" else 4.3), {"medium": "mag", "target": "TH-" + u})
	for d in ["DR-CY", "DR-P", "HATCH-Y"]:
		var dp = by_tag[d]
		# the deck hatch is worked from the cabin above it
		_ctrl(d, "door", dp, Geom.centroid(dp.poly) / Geom.M, {"target": d, "state": false, "hidden_room": "C" if d == "DR-CY" else ""})


static func _rooms() -> void:
	w.add_room("C", _mp([Vector2(16.42, -2.82), Vector2(17.4, -3.83), Vector2(23.0, -3.83), Vector2(23.0, -0.45), Vector2(16.42, -0.45)]))
	w.add_room("Y", _mp([Vector2(16.42, -0.15), Vector2(23.0, -0.15), Vector2(23.0, 3.83), Vector2(17.4, 3.83), Vector2(16.42, 2.82)]))
	w.add_room("P", _mp([Vector2(23.3, -3.83), Vector2(29.6, -3.83), Vector2(30.58, -2.82), Vector2(30.58, 2.82), Vector2(29.6, 3.83), Vector2(23.3, 3.83)]))


static func meta() -> Dictionary:
	return {
		"id": "h22",
		"name": "H-22 DOUBLE HOOK",
		"title": ["H-22「双钩」工程拖船 · 38 m", "H-22 DOUBLE HOOK · ENGINEERING TUG · 38 m"],
		"contract": "H-22",
		"length": 37.6,
		"value": {"total": 140000.0, "metal": 9000.0},
		"clamps": [[21.0, 4.25], [27.0, 4.25]],
		# the residual field on each tow head, and the arm pivots held under load (scripts/mech.gd)
		"magnets": {"TH-U": {"r": 2.6, "mT": 62.0}, "TH-L": {"r": 2.6, "mT": 58.0}},
		"preloads": {
			"PIV-U": {"pins": ["PIN-U1", "PIN-U2"], "vessel": "ACC", "kpa": 300.0, "piece": "ARM-U", "push": [-0.8, -0.6]},
			"PIV-L": {"pins": ["PIN-L1", "PIN-L2"], "vessel": "ACC", "kpa": 300.0, "piece": "ARM-L", "push": [-0.8, 0.6]},
		},
		"room_names": {"C": "room_hC", "Y": "room_hY", "P": "room_hP"},
		"gas": {
			"rooms": {"C": 101.0, "Y": 90.0, "P": 95.0},
			"vessels": {"ACC": {"V": 0.08, "kpa": 1800.0, "piece": "ACC", "burst": 200.0}},
			"valves": [],
			"value": 500.0,
		},
		"power": {
			"bus": "SWB-H",
			"sources": [
				{"piece": "BAT-H", "kind": "battery", "volts": 400.0, "local_volts": 48.0, "cable": "c1", "switch": "K-H", "charge": 0.9, "drain": 0.0004},
				{"piece": "CAP-H", "kind": "cap", "volts": 380.0, "cable": "c2", "charge": 1.0, "discharge": "E-CAP"},
			],
			"isolated": [{"piece": "LMU", "volts": 24.0, "charge": 1.0}],
			"lamps": {"C": "LAMP-C", "P": "LAMP-P"},
		},
		"fluids": {
			"volumes": {
				"hyd": {"fluid": "hydraulic", "amount": 0.18, "piece": "HPU", "content": 1.4, "leak": 0.12, "port": "HYD-P", "pump": [0.12, 0.008]},
				"hyd_line": {"fluid": "hydraulic", "amount": 0.018, "nets": ["hyd"], "leak": 0.08, "leak_min": 0.004},
				"prop1": {"fluid": "fuel", "amount": 0.08, "piece": "PROP-1", "content": 0.6, "leak": 0.1, "port": "PROP-1P", "pump": [0.12, 0.008], "hazard": 0.02},
				"prop2": {"fluid": "fuel", "amount": 0.08, "piece": "PROP-2", "content": 0.6, "leak": 0.1, "port": "PROP-2P", "pump": [0.12, 0.008], "hazard": 0.02},
				"fuel_line": {"fluid": "fuel", "amount": 0.01, "nets": ["fuel"], "leak": 0.05, "leak_min": 0.004},
			},
			"joins": [],
			"value": {"hydraulic": 300.0, "fuel": 300.0},
		},
		"ctrls_cfg": {
			"GAS-C": {"rate": 9.0},
			"GAS-Y": {"rate": 9.0},
			"GAS-P": {"rate": 9.0},
			"ACC-P": {"rate": 0.4},
			"E-CAP": {"target": "CAP-H"},
			"DEGAUSS": {"magnets": ["TH-U", "TH-L"], "supply": "COIL-PWR"},
		},
		"labels": {"ACC": "ACC", "HPU": "HYD", "PROP-1": "PROP", "PROP-2": "PROP", "COIL-PWR": "COIL PWR", "TH-U": "TH-U", "TH-L": "TH-L"},
		"hints": {},
		"market": {
			"class": "H", "name": ["双钩级工程拖船", "DOUBLE-HOOK ENGINEERING TUG"], "time": 25.0,
			"rooms": {"C": [0.25, 60.0, 101.0], "Y": [0.3, 50.0, 100.0], "P": [0.3, 50.0, 100.0]},
			"vessels": {"ACC": [0.25, 50.0, 250.0, 1400.0, 2200.0]},
			"charge": {"BAT-H": [0.15, 1.0], "CAP-H": [0.4, 1.0]},
			"fluids": {"hyd": [0.06, 0.2], "prop1": [0.01, 0.1], "prop2": [0.01, 0.1]}, "fill": {"hyd_line": "hyd", "fuel_line": "prop1"},
			"knockable": ["CON-H", "LMU", "ENV-H", "COOL-H", "MAIN-H1", "MAIN-H2", "MAIN-H3", "TS-1", "TS-2"],
			"drift": ["ENV-H", "CP-H", "VALVES", "HPU"],
			"section_x": 16.0,
			"slots": {
				"fire_system": {"x": 21.9, "y0": -0.15, "y1": 1.45, "base": ["DK-2", -0.15], "room": "Y", "port": [22.3, 1.3]},
				"second_source": {"at": [26.6, 0.2], "size": [1.6, 1.93], "base": [["CP-H", 27.0, 2.13], ["SWB-H", 28.2, 1.2]], "room": "P",
					"bus": "SWB-H", "path": [[28.0, 0.8], [28.4, 0.8]], "switch_at": [26.9, 0.5], "proc": "TH-U", "test": "E-H01", "volts": 230.0},
				"hidden_damage": {"plates": ["TOP-1", "TOP-2", "TOP-3", "TOP-4"]},
			},
			"mechanisms": true,
		},
		"procedures": {
			"TH-U": [
				{"do": "operate", "ctrl": "K-H"},
				{"do": "operate", "ctrl": "E-CAP"},
				{"do": "wait", "until": {"charge": ["CAP-H", "<", 0.002]}, "max": 30.0},
				{"do": "measure", "ctrl": "E-H01", "expect": ["<", 1.0]},
				{"do": "operate", "ctrl": "DEGAUSS"},
				{"do": "measure", "ctrl": "M-THU", "expect": ["<", 2.0]},
				{"do": "free", "piece": "TH-U"},
				{"do": "deliver", "piece": "TH-U", "zone": "equip"},
			],
			"ARM-U": [
				{"do": "hose", "ctrl": "GAS-Y"},
				{"do": "wait", "until": {"P": ["Y", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HATCH-Y"},
				{"do": "wait", "until": {"open": ["Y"]}, "max": 5.0},
				{"do": "hose", "ctrl": "ACC-P"},
				{"do": "wait", "until": {"P": ["ACC", "<", 120.0]}, "max": 240.0},
				{"do": "free", "piece": "ARM-U"},
				{"do": "deliver", "piece": "ARM-U", "zone": "equip"},
			],
		},
		"blueprint": {"hide": ["LAMP-C", "LAMP-P", "PNL-H"]},
	}
