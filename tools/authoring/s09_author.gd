class_name S09Author
# Authoring script for S-09 "Swift", the 26 m maintenance shuttle (approved
# structure: design/S-09_结构图.png). Not part of the game: tools/ship_export.gd
# runs it and writes ships/s09.json. Metres, x bow (0) to stern (26), y down.
#
# Nothing like the Heron's box hull (user spec 2026-10-16, four sections):
#   1 the pressure ball, its shell in arc panels: the upper deck A is the
#     observation and pilot's station; the lower deck B has the co-pilot's seat,
#     the nav terminal and the tool lockers, a ladder well between the decks, and
#     under its floor plates the small life-support module and the recorder;
#   2 the transition neck L: the airlock (inner door to B, the pressure door in
#     its aft wall out to the truss), the small distribution box, the EVA suits,
#     a maintenance glove port, the docking port on top — in by the airlock cycle;
#   3 the open lattice spine (vacuum): chords, posts and diagonals bolted at the
#     nodes; equipment on pallets in the bays (fuel cell, hydrogen, oxygen, the
#     arm's capacitors), two small cargo boxes, the arm's control base; fuel line
#     and cables run in the open; the arm folded on its rail on top, on launch locks;
#   4 the tail: thrust cone and engine, propellant spheres, the brake's own
#     supply, a maintenance spray can, and the forked booms with radiator panels
#     and the twin attitude nozzles.

const C := Vector2(3.2, 0.0)       # the pressure ball's centre
const RO := 3.15                   # its outer radius
const T := 0.3                     # shell thickness
const NECK_TOP := -0.35
const NECK_BOT := 2.35
const NECK_END := 9.4
const ARC_N := 22
const TRUSS_TOP := -0.25           # top of the upper chord
const TRUSS_BOT := 2.05            # bottom of the lower chord
const CH := 0.2                    # chord depth
const NODES := [9.4, 10.925, 12.45, 13.975, 15.5, 17.025, 18.55, 20.075, 21.6]
const FLOOR_Y := 1.85                # the lower deck's floor plates (a grating: not airtight)
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var outer: Array = []
static var inner: Array = []
static var w
static var by_tag := {}


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(x0, y0, x1, y1))


static func _mp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


# the outline, in the order that puts the inside on the right-hand normal:
# neck top (sphere junction → stern), neck end, neck belly back to the ball, round the ball
static func _outline() -> Array:
	var xt := C.x + sqrt(RO * RO - NECK_TOP * NECK_TOP)
	var xb := C.x + sqrt(RO * RO - NECK_BOT * NECK_BOT)
	var out: Array = [Vector2(xt, NECK_TOP), Vector2(NECK_END, NECK_TOP), Vector2(NECK_END, NECK_BOT), Vector2(xb, NECK_BOT)]
	var a0 := atan2(NECK_BOT, xb - C.x)
	var a1 := atan2(NECK_TOP, xt - C.x) + TAU
	for i in range(1, ARC_N):
		var a := lerpf(a0, a1, float(i) / ARC_N)
		out.append(C + Vector2(cos(a), sin(a)) * RO)
	return out


static func _inner_outline(o: Array) -> Array:
	var n := o.size()
	var out: Array = []
	for i in n:
		var a: Vector2 = o[(i - 1 + n) % n]
		var b: Vector2 = o[i]
		var c: Vector2 = o[(i + 1) % n]
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
	outer = _outline()
	inner = _inner_outline(outer)
	_shell()
	_decks()
	_spine()
	_arm()
	_aft()
	_inside()
	_outside()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	outer = _outline()
	inner = _inner_outline(outer)
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt") -> void:
	if a == null or b == null:
		push_warning("S09 joint missing a piece at %s,%s" % [x, y])
		return
	w.add_joint(a, b, type, p(x, y))


static func at(x: float, y: float, kinds: Array = []):
	return w.piece_at(p(x, y), kinds)


# ---------------------------------------------------------------- the pressure shell

static func _shell() -> void:
	var S := {"density": 1.6, "barrier": true, "cut_speed": 230.0}
	var n := outer.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = outer[i]
		var o1: Vector2 = outer[(i + 1) % n]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[(i + 1) % n]
		var stations: Array = [0.0, 1.0]
		if i == 0:
			stations = [0.0, (7.9 - o0.x) / (o1.x - o0.x), 1.0]
		elif i == 1:
			# the aft wall: the pressure door out to the truss between two wall plates
			stations = [0.0, (0.05 - NECK_TOP) / (NECK_BOT - NECK_TOP), (1.8 - NECK_TOP) / (NECK_BOT - NECK_TOP), 1.0]
		elif i == 2:
			stations = [0.0, (o0.x - 7.6) / (o0.x - o1.x), 1.0]
		for k in stations.size() - 1:
			var a := o0.lerp(o1, stations[k])
			var b := o0.lerp(o1, stations[k + 1])
			var c := i0.lerp(i1, stations[k + 1])
			var d := i0.lerp(i1, stations[k])
			var poly := PackedVector2Array([a * Geom.M, b * Geom.M, c * Geom.M, d * Geom.M])
			var opts := S.duplicate()
			var kind := "hull"
			if i == 1:
				opts["density"] = 2.0
				opts["tag"] = ["AFT-T", "HATCH-L", "AFT-B"][k]
				if k == 1:
					kind = "hatch"
					opts["door"] = true
					opts["open_dir"] = Vector2(0, -1.65) * Geom.M
			if i >= 3:
				var mid := ((a + b) * 0.5 - C).angle()
				if mid < 0.0:
					mid += TAU
				if mid > deg_to_rad(196.0) and mid < deg_to_rad(250.0):
					opts["art"] = "window"
			var pc = _tagged(w.add_piece(kind, poly, opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", (a.lerp(d, 0.3)) * Geom.M)
				w.add_joint(prev, pc, "weld", (a.lerp(d, 0.7)) * Geom.M)
			else:
				first = pc
			prev = pc
	w.add_joint(prev, first, "weld", outer[0].lerp(inner[0], 0.3) * Geom.M)
	w.add_joint(prev, first, "weld", outer[0].lerp(inner[0], 0.7) * Geom.M)
	# dock clamps: under the ball and under the neck
	for cl in [[3.2, 3.13, "CL-01"], [8.6, 2.33, "CL-02"]]:
		var j = w.add_joint(at(cl[0], cl[1] - 0.12, ["hull"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# the ball's inner surface at x: [top y, bottom y]
static func ball(x: float) -> Array:
	var r := RO - T
	var dx := x - C.x
	var h := sqrt(maxf(0.0, r * r - dx * dx))
	return [-h, h]


# x where the ball's inner surface crosses height y: [left, right]
static func ball_x(y: float) -> Array:
	var r := RO - T
	var h := sqrt(maxf(0.0, r * r - y * y))
	return [C.x - h, C.x + h]


# ---------------------------------------------------------------- decks, floor plates and doors inside

static func _decks() -> void:
	var D := {"density": 1.2, "barrier": true, "cut_speed": 240.0}
	# the deck between the decks, running on into the neck's roof; the ladder well's hatch in it
	var y0 := NECK_TOP
	var y1 := NECK_TOP + T
	var l0: Array = ball_x(y0)
	var l1: Array = ball_x(y1)
	var dk1 = _tagged(w.add_piece("deck", _mp([Vector2(l0[0], y0), Vector2(4.2, y0), Vector2(4.2, y1), Vector2(l1[0], y1)]), D.merged({"tag": "DK-S1"})))
	var hatch = _tagged(w.add_piece("door", R(4.2, y0, 4.9, y1), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-AB", "open_dir": Vector2(-0.66, 0) * Geom.M, "cut_speed": 240.0}))
	var dk2 = _tagged(w.add_piece("deck", _mp([Vector2(4.9, y0), Vector2(l0[1], y0), Vector2(l1[1], y1), Vector2(4.9, y1)]), D.merged({"tag": "DK-S2"})))
	_bolt(dk1, at(l0[0] - 0.15, -0.2, ["hull"]), l0[0], -0.2, "weld")
	_bolt(dk2, at(l0[1] + 0.12, -0.2, ["hull"]), l0[1], -0.2, "weld")
	_bolt(hatch, dk1, 4.2, -0.2, "weld")
	_bolt(hatch, dk2, 4.9, -0.2, "weld")
	# the lower deck's floor: two grating plates on bolts (the aft one lifts to reach the recorder)
	var f0: Array = ball_x(FLOOR_Y)
	var fl1 = _tagged(w.add_piece("rail", _mp([Vector2(f0[0] + 0.02, FLOOR_Y), Vector2(3.55, FLOOR_Y), Vector2(3.55, FLOOR_Y + 0.18), Vector2(ball_x(FLOOR_Y + 0.18)[0] + 0.02, FLOOR_Y + 0.18)]),
		{"density": 0.8, "cut_speed": 240.0, "tag": "FL-1", "room": "B", "art": "grating", "art_xf": Transform2D(0.0, p(f0[0], FLOOR_Y)), "art_size": p(3.55 - f0[0], 0.18), "name_key": "p_floor"}))
	var fl2 = _tagged(w.add_piece("rail", _mp([Vector2(3.55, FLOOR_Y), Vector2(f0[1] - 0.02, FLOOR_Y), Vector2(ball_x(FLOOR_Y + 0.18)[1] - 0.02, FLOOR_Y + 0.18), Vector2(3.55, FLOOR_Y + 0.18)]),
		{"density": 0.8, "cut_speed": 240.0, "tag": "FL-2", "room": "B", "art": "grating", "art_xf": Transform2D(0.0, p(3.55, FLOOR_Y)), "art_size": p(f0[1] - 3.55, 0.18), "name_key": "p_floor"}))
	_bolt(fl1, at(f0[0] - 0.1, FLOOR_Y + 0.09, ["hull"]), f0[0] + 0.05, FLOOR_Y + 0.09)
	_bolt(fl1, fl2, 3.55, FLOOR_Y + 0.09)
	_bolt(fl2, at(f0[1] - 0.1, NECK_BOT - 0.12, ["hull"]), f0[1] - 0.1, FLOOR_Y + 0.18)
	_bolt(fl2, at(4.6, ball(4.6)[1] + 0.1, ["hull"]), 4.6, FLOOR_Y + 0.18)
	# the inner airlock door: the full height of the neck, between the cabin and the lock
	var dr = _tagged(w.add_piece("door", R(6.1, -0.05, 6.35, 2.05), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-BL", "open_dir": Vector2(0, -1.9) * Geom.M, "cut_speed": 240.0}))
	_bolt(dr, at(6.22, -0.2, ["hull"]), 6.22, -0.05, "weld")
	_bolt(dr, at(6.22, 2.2, ["hull"]), 6.22, 2.05, "weld")


# ---------------------------------------------------------------- the open spine

static func _diag(a: Vector2, b: Vector2, wd: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * wd * 0.5
	return _mp([a + n, b + n, b - n, a - n])


static func _spine() -> void:
	var B := {"density": 1.1, "cut_speed": 160.0}
	var tops: Array = []
	var bots: Array = []
	for k in NODES.size() - 1:
		var x0: float = NODES[k]
		var x1: float = NODES[k + 1]
		var tp = w.add_piece("beam", R(x0, TRUSS_TOP, x1, TRUSS_TOP + CH), B)
		var bt = w.add_piece("beam", R(x0, TRUSS_BOT - CH, x1, TRUSS_BOT), B)
		tops.append(tp)
		bots.append(bt)
		if k == 0:
			_bolt(tp, by_tag["AFT-T"], x0, TRUSS_TOP + CH * 0.5)
			_bolt(bt, by_tag["AFT-B"], x0, TRUSS_BOT - CH * 0.5)
		else:
			_bolt(tops[k - 1], tp, x0, TRUSS_TOP + CH * 0.5)
			_bolt(bots[k - 1], bt, x0, TRUSS_BOT - CH * 0.5)
	var yt := TRUSS_TOP + CH
	var yb := TRUSS_BOT - CH
	for k in range(1, NODES.size()):
		var x: float = NODES[k]
		var post = w.add_piece("strut", R(x - 0.08, yt, x + 0.08, yb), {"density": 1.2, "cut_speed": 220.0})
		_bolt(post, tops[k - 1], x, yt)
		_bolt(post, bots[k - 1], x, yb)
		if k == NODES.size() - 1:
			post.tag = "POST-A"
			_tagged(post)
	# diagonals in the open bays; the bays carrying pallets are braced by them
	for k in [5, 7]:
		var x0: float = NODES[k] + 0.1
		var x1: float = NODES[k + 1] - 0.1
		var a := Vector2(x0, yt + 0.08) if k % 2 == 1 else Vector2(x0, yb - 0.08)
		var b := Vector2(x1, yb - 0.08) if k % 2 == 1 else Vector2(x1, yt + 0.08)
		var dg = w.add_piece("strut", _diag(a, b, 0.12), {"density": 1.2, "cut_speed": 220.0})
		_bolt(dg, tops[k] if a.y < 0.5 else bots[k], a.x, yt if a.y < 0.5 else yb)
		_bolt(dg, tops[k] if b.y < 0.5 else bots[k], b.x, yt if b.y < 0.5 else yb)
	by_tag["_tops"] = tops
	by_tag["_bots"] = bots


static func _equip(tag: String, art: String, r: Rect2, opts: Dictionary, poly: PackedVector2Array = PackedVector2Array()):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	return _tagged(w.add_piece(kind, poly if not poly.is_empty() else Geom.rect_poly(rr), o))


static func _circle(c: Vector2, r: float, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append((c + Vector2(cos(a), sin(a)) * r) * Geom.M)
	return out


# ---------------------------------------------------------------- the arm on its rail

static func _arm() -> void:
	var tops: Array = by_tag["_tops"]
	var rail = _tagged(w.add_piece("rail", R(9.4, -0.5, 20.8, TRUSS_TOP), {"density": 0.9, "cut_speed": 200.0, "tag": "RAIL-D"}))
	for k in NODES.size() - 1:
		_bolt(rail, tops[k], NODES[k] + 0.3, TRUSS_TOP)
	# the arm folded: shoulder block at the stern end, the boom on the rail, the forearm back over it
	var shp := Geometry2D.merge_polygons(R(19.4, -1.45, 20.4, -0.5), R(12.4, -0.85, 19.6, -0.5))[0]
	shp = Geometry2D.merge_polygons(shp, R(12.4, -1.2, 17.2, -0.85))[0]
	shp = Geometry2D.merge_polygons(shp, _mp([Vector2(17.2, -1.18), Vector2(17.85, -1.38), Vector2(17.85, -0.95), Vector2(17.2, -0.87)]))[0]
	var arm = _equip("ARM-01", "arm", Rect2(12.4, -1.45, 8.0, 0.95), {"mass": 1.6, "value": 14000.0, "fragile": 0.35, "mandatory": true, "name_key": "p_s_arm"}, shp)
	for lx in [13.0, 15.4, 17.8, 19.55]:
		_bolt(arm, rail, lx, -0.5, "lock")
	_bolt(arm, rail, 19.7, -0.5)
	_bolt(arm, rail, 20.25, -0.5)


# ---------------------------------------------------------------- the tail

static func _aft() -> void:
	var tops: Array = by_tag["_tops"]
	var bots: Array = by_tag["_bots"]
	var post = by_tag["POST-A"]
	var mid := (TRUSS_TOP + TRUSS_BOT) * 0.5
	var mount = _tagged(w.add_piece("beam", R(22.8, mid - 0.4, 23.0, mid + 0.4), {"density": 1.4, "cut_speed": 160.0, "tag": "MOUNT"}))
	for y in [TRUSS_TOP + 0.1, TRUSS_BOT - 0.1]:
		var st = w.add_piece("strut", _diag(Vector2(21.65, y), Vector2(22.85, mid + (y - mid) * 0.25), 0.16), {"density": 1.2, "cut_speed": 200.0})
		_bolt(st, post, 21.65, y)
		_bolt(st, mount, 22.85, mid + (y - mid) * 0.25)
	var eng := Geometry2D.merge_polygons(R(23.0, mid - 0.55, 24.3, mid + 0.55), _mp([Vector2(24.3, mid - 0.4), Vector2(25.9, mid - 1.0), Vector2(25.9, mid + 1.0), Vector2(24.3, mid + 0.4)]))[0]
	var me = _equip("MAIN-E", "engine_s", Rect2(23.0, mid - 1.0, 2.9, 2.0), {"mass": 1.3, "value": 7000.0, "fragile": 0.3, "name_key": "p_main"}, eng)
	_bolt(me, mount, 23.0, mid - 0.3)
	_bolt(me, mount, 23.0, mid + 0.3)
	# the maintenance spray can, strapped under the engine
	var sp = _equip("SPRAY-T", "fueltank", Rect2(23.15, mid + 0.6, 0.8, 0.32), {"mass": 0.04, "value": 300.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_spray"})
	_bolt(sp, me, 23.4, mid + 0.55)
	_bolt(sp, me, 23.8, mid + 0.55)
	# propellant spheres on brackets off the last post
	for i in 2:
		var cy := TRUSS_TOP - 0.55 if i == 0 else TRUSS_BOT + 0.55
		var tk = _equip("RCS-T%d" % (i + 1), "sphere_tank", Rect2(21.75, cy - 0.5, 1.0, 1.0), {"mass": 0.35, "value": 1200.0, "fragile": 0.35, "hazard": "fuel_tank", "name_key": "p_rcs_t"}, _circle(Vector2(22.25, cy), 0.5))
		var br = w.add_piece("strut", R(21.55, cy, 21.7, TRUSS_TOP) if i == 0 else R(21.55, TRUSS_BOT, 21.7, cy), {"density": 1.2, "cut_speed": 220.0})
		_bolt(br, tk, 21.7, cy)
		_bolt(br, tops[tops.size() - 1] if i == 0 else bots[bots.size() - 1], 21.6, TRUSS_TOP if i == 0 else TRUSS_BOT)
	# the brake's own supply, on the last post (its cable runs forward along the truss to the arm)
	var brk = _equip("BRK-P", "brake", Rect2(21.7, mid + 0.1, 0.36, 0.42), {"mass": 0.06, "value": 600.0, "fragile": 0.4, "name_key": "p_brake"})
	_bolt(brk, post, 21.68, mid + 0.2)
	_bolt(brk, post, 21.68, mid + 0.42)
	# the forked tail: two swept booms off the engine mount, radiator panels, twin attitude nozzles at the tips
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		var root := Vector2(22.95, mid + sg * 0.42)
		var tip := Vector2(25.7, mid + sg * 4.0)
		var boom = _tagged(w.add_piece("beam", _diag(root, tip, 0.32), {"density": 1.1, "cut_speed": 160.0, "tag": "BOOM-%d" % (i + 1)}))
		_bolt(boom, by_tag["MOUNT"], root.x, root.y)
		var d := (tip - root).normalized()
		var n := Vector2(-d.y, d.x) * (-sg)
		var r0 := root + d * 1.3
		var r1 := root + d * 4.0
		var rp := _mp([r0 + n * 0.16, r1 + n * 0.16, r1 + n * 0.62, r0 + n * 0.62])
		var bb := Geom.bbox(rp)
		var rad = _equip("RAD-%d" % (i + 1), "radiator", Rect2(bb.position / Geom.M, bb.size / Geom.M), {"mass": 0.25, "value": 700.0, "fragile": 0.3, "name_key": "p_s_rad"}, rp)
		_bolt(rad, boom, (r0 + n * 0.16).x + d.x * 0.4, (r0 + n * 0.16).y + d.y * 0.4)
		_bolt(rad, boom, (r1 + n * 0.16).x - d.x * 0.4, (r1 + n * 0.16).y - d.y * 0.4)
		var qc := tip + d * 0.12
		var q = _equip("ATT-%d" % (i + 1), "rcs_quad", Rect2(qc.x - 0.45, qc.y - 0.3, 0.9, 0.6), {"mass": 0.2, "value": 900.0, "fragile": 0.4, "name_key": "p_att"})
		_bolt(q, boom, tip.x - d.x * 0.1, tip.y - d.y * 0.1)


# ---------------------------------------------------------------- inside the ball and the neck

static func _seat(tag: String, x0: float, floor_y: float, h: float, host, name_key: String) -> void:
	var r := Rect2(x0, floor_y - h, 0.72, h)
	var st = _equip(tag, "seat", r, {"mass": 0.1, "value": 600.0, "fragile": 0.3, "room": "A" if floor_y < 0.0 else "B", "name_key": name_key})
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	st.poly = sp
	_bolt(st, host, x0 + 0.13, floor_y)
	_bolt(st, host, x0 + 0.59, floor_y)
	_bolt(st, host, x0 + 0.36, floor_y, "lock")


static func _inside() -> void:
	var dk1 = by_tag["DK-S1"]
	var dk2 = by_tag["DK-S2"]
	var deck_top := NECK_TOP
	var deck_bot := NECK_TOP + T
	# A — the upper deck: the observation dome, the pilot's console and seat, the overhead panel
	var con = _equip("CON-S", "console", Rect2(0.75, deck_top - 0.85, 0.95, 0.85), {"mass": 0.3, "value": 1200.0, "fragile": 0.5, "room": "A", "name_key": "p_console"})
	_bolt(con, dk1, 0.95, deck_top)
	_bolt(con, dk1, 1.55, deck_top)
	_seat("SEAT-P", 1.95, deck_top, 1.75, dk1, "p_seat_p")
	var ovh = _equip("OVH-S", "overhead", Rect2(2.55, -2.7, 1.3, 0.26), {"mass": 0.06, "value": 800.0, "fragile": 0.5, "room": "A", "name_key": "p_ovh"})
	_bolt(ovh, at(2.75, ball(2.75)[0] - 0.12, ["hull"]), 2.75, ball(2.75)[0] + 0.02)
	_bolt(ovh, at(3.65, ball(3.65)[0] - 0.12, ["hull"]), 3.65, ball(3.65)[0] + 0.02)
	_lamp("LAMP-SA", 1.5, ball(1.25)[0] + 0.03, "A", at(1.5, ball(1.5)[0] - 0.12, ["hull"]))
	# B — the lower deck: co-pilot's seat, nav terminal, tool lockers, the ladder well
	var fl1 = by_tag["FL-1"]
	var fl2 = by_tag["FL-2"]
	_seat("SEAT-C", 1.3, FLOOR_Y, 1.6, fl1, "p_seat_c")
	var nav = _equip("NAV-S", "nav_rack", Rect2(2.12, FLOOR_Y - 1.3, 0.5, 1.3), {"mass": 0.3, "value": 5000.0, "fragile": 0.85, "room": "B", "name_key": "p_nav"})
	_bolt(nav, fl1, 2.22, FLOOR_Y)
	_bolt(nav, fl1, 2.52, FLOOR_Y)
	for i in 4:
		var lx := 2.75 + i * 0.35
		var lk = _equip("LOCK-%d" % (i + 1), "locker", Rect2(lx, deck_bot, 0.33, 0.8), {"mass": 0.12, "value": 800.0, "fragile": 0.3, "room": "B", "name_key": "p_locker"})
		_bolt(lk, dk1, lx + 0.16, deck_bot)
	var lad = _equip("LADDER", "ladder", Rect2(4.32, deck_bot, 0.46, FLOOR_Y - deck_bot), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "B", "cut_speed": 260.0, "name_key": "p_ladder"})
	_bolt(lad, fl2, 4.4, FLOOR_Y)
	_bolt(lad, fl2, 4.7, FLOOR_Y)
	# under the floor plates: the small life-support module and the recorder (lift FL-2 to reach it)
	var life = _equip("LIFE-S", "env", Rect2(2.15, FLOOR_Y + 0.22, 1.25, 0.5), {"mass": 0.3, "value": 2200.0, "fragile": 0.5, "room": "B", "name_key": "p_life"})
	_bolt(life, fl1, 2.4, FLOOR_Y + 0.18)
	_bolt(life, fl1, 3.15, FLOOR_Y + 0.18)
	var fdr = _equip("FDR-S", "blackbox", Rect2(3.7, FLOOR_Y + 0.25, 0.45, 0.36), {"mass": 0.1, "value": 2000.0, "fragile": 0.2, "room": "B", "mandatory": true, "name_key": "p_blackbox"})
	_bolt(fdr, at(3.92, ball(3.92)[1] + 0.12, ["hull"]), 3.92, FLOOR_Y + 0.61)
	fdr.hidden_by = fl2.id
	# the battery on the neck floor, cabin side of the inner door
	var bat = _equip("PWR-B", "battery", Rect2(5.4, NECK_BOT - T - 0.5, 0.65, 0.5), {"mass": 0.4, "value": 2500.0, "fragile": 0.4, "room": "B", "hazard": "battery", "name_key": "p_s_bat"})
	_bolt(bat, at(5.55, NECK_BOT - 0.12, ["hull"]), 5.55, NECK_BOT - T)
	_bolt(bat, at(5.9, NECK_BOT - 0.12, ["hull"]), 5.9, NECK_BOT - T)
	_lamp("LAMP-SB", 5.4, deck_bot, "B", dk2)
	# L — the transition neck: EVA suits, lamp, the small distribution box, the glove port, the tether reel
	var roof := NECK_TOP + T
	for i in 2:
		var sx := 6.45 + i * 0.55
		var su = _equip("SUIT-%d" % (i + 1), "suit", Rect2(sx, roof + 0.03, 0.5, 1.72), {"mass": 0.12, "value": 3000.0, "fragile": 0.5, "room": "L", "name_key": "p_suit"})
		_bolt(su, at(sx + 0.25, NECK_TOP + 0.12, ["hull"]), sx + 0.25, roof)
	_lamp("LAMP-SL", 7.7, roof, "L", at(7.7, NECK_TOP + 0.12, ["hull"]))
	var swb = _equip("SWB-S", "swb", Rect2(7.95, roof, 0.6, 0.7), {"mass": 0.15, "value": 900.0, "fragile": 0.4, "room": "L", "name_key": "p_s_swb"})
	_bolt(swb, at(8.1, NECK_TOP + 0.12, ["hull"]), 8.1, roof)
	_bolt(swb, at(8.4, NECK_TOP + 0.12, ["hull"]), 8.4, roof)
	var glove = _equip("GLOVE-L", "glove", Rect2(8.65, roof, 0.42, 0.55), {"mass": 0.05, "value": 700.0, "fragile": 0.6, "room": "L", "name_key": "p_glove"})
	_bolt(glove, by_tag["AFT-T"], 9.08, roof + 0.05)
	_bolt(glove, at(8.8, NECK_TOP + 0.12, ["hull"]), 8.8, roof)
	var reel = _equip("REEL-L", "reel", Rect2(8.1, NECK_BOT - T - 0.45, 0.45, 0.45), {"cls": "metal", "dest": "metal", "mass": 0.05, "room": "L", "cut_speed": 260.0, "name_key": "p_reel"})
	_bolt(reel, at(8.3, NECK_BOT - 0.12, ["hull"]), 8.3, NECK_BOT - T)


static func _lamp(tag: String, x: float, top: float, room: String, host) -> void:
	var lp = _equip(tag, "lamp", Rect2(x - 0.15, top, 0.3, 0.12), {"cls": "metal", "dest": "metal", "mass": 0.03, "room": room, "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lp, host, x, top)


# ---------------------------------------------------------------- the spine's bays, the docking port, the forward thrusters

static func _outside() -> void:
	var tops: Array = by_tag["_tops"]
	var bots: Array = by_tag["_bots"]
	var yt := TRUSS_TOP + CH
	var yb := TRUSS_BOT - CH
	# bay 1: the fuel cell; bay 2: hydrogen; bay 3: oxygen — on pallets bolted to the lower chord
	var fc = _equip("FC-01", "gen", Rect2(11.05, yb - 1.45, 1.3, 1.45), {"mass": 1.1, "value": 9000.0, "fragile": 0.35, "hazard": "gen", "name_key": "p_fuelcell", "temp": 70.0})
	_bolt(fc, bots[1], 11.25, yb)
	_bolt(fc, bots[1], 12.15, yb)
	var h2 = _equip("H2-T", "fueltank", Rect2(12.55, yb - 1.15, 1.32, 1.0), {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_h2"})
	_bolt(h2, bots[2], 12.8, yb - 0.15)
	_bolt(h2, bots[2], 13.6, yb - 0.15)
	var o2 = _equip("O2-T", "fueltank", Rect2(14.08, yb - 1.1, 1.32, 0.95), {"mass": 0.3, "value": 1500.0, "fragile": 0.3, "hazard": "gas_tank", "name_key": "p_o2"})
	_bolt(o2, bots[3], 14.3, yb - 0.15)
	_bolt(o2, bots[3], 15.2, yb - 0.15)
	# bay 4: the arm's capacitor bank on the upper chord, a parts crate on the lower
	var cap = _equip("CAP-A", "cap", Rect2(15.75, yt + 0.02, 0.8, 0.85), {"mass": 0.3, "value": 1800.0, "fragile": 0.4, "hazard": "cap", "name_key": "p_s_cap"})
	_bolt(cap, tops[4], 15.95, yt)
	_bolt(cap, tops[4], 16.35, yt)
	var cr1 = _equip("CRATE-1", "cargo", Rect2(15.62, yb - 0.72, 1.25, 0.72), {"mass": 0.25, "value": 1500.0, "fragile": 0.7, "name_key": "p_crate"})
	_bolt(cr1, bots[4], 15.8, yb, "lock")
	_bolt(cr1, bots[4], 16.7, yb, "lock")
	# bay 6: the arm's control base on the upper chord, the second crate below
	var ctl = _equip("ARM-CTL", "swb", Rect2(18.7, yt + 0.02, 0.85, 0.75), {"mass": 0.2, "value": 1500.0, "fragile": 0.45, "name_key": "p_armctl"})
	_bolt(ctl, tops[6], 18.9, yt)
	_bolt(ctl, tops[6], 19.35, yt)
	var cr2 = _equip("CRATE-2", "cargo", Rect2(18.68, yb - 0.72, 1.25, 0.72), {"mass": 0.25, "value": 1500.0, "fragile": 0.7, "name_key": "p_crate"})
	_bolt(cr2, bots[6], 18.85, yb, "lock")
	_bolt(cr2, bots[6], 19.75, yb, "lock")
	# the service panel under the lower chord, bay 5
	var panel = _equip("EXT-S", "panel", Rect2(17.15, TRUSS_BOT, 1.3, 0.42), {"cls": "metal", "dest": "metal", "mass": 0.08, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(panel, bots[5], 17.3, TRUSS_BOT)
	_bolt(panel, bots[5], 18.3, TRUSS_BOT)
	# docking port on top of the neck
	var dock = _equip("DOCK-S", "dock", Rect2(6.9, NECK_TOP - 0.6, 1.6, 0.6), {"mass": 0.3, "value": 2500.0, "fragile": 0.4, "name_key": "p_dock"})
	for x in [7.05, 7.7, 8.35]:
		_bolt(dock, at(x, NECK_TOP + 0.12, ["hull"]), x, NECK_TOP)
	# the forward (auxiliary) thruster quads and the floodlights on the ball
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		var ang := deg_to_rad(-70.0 if i == 0 else 70.0)
		var c := C + Vector2(cos(ang), sin(ang)) * (RO + 0.2)
		var q = _equip("RCS-Q%d" % (i + 1), "rcs_quad", Rect2(c.x - 0.35, c.y - 0.2, 0.7, 0.4), {"mass": 0.15, "value": 500.0, "fragile": 0.4, "name_key": "p_rcs_q"})
		var hc := C + Vector2(cos(ang), sin(ang)) * (RO - 0.12)
		_bolt(q, at(hc.x, hc.y, ["hull"]), c.x, c.y - sg * 0.2)
		var fa := deg_to_rad(-140.0 if i == 0 else 140.0)
		var fc2 := C + Vector2(cos(fa), sin(fa)) * (RO + 0.15)
		var fl = _equip("FL-%d" % (i + 1), "lamp", Rect2(fc2.x - 0.25, fc2.y - 0.15, 0.5, 0.3), {"cls": "metal", "dest": "metal", "mass": 0.03, "cut_speed": 260.0, "name_key": "p_flood"})
		var fh := C + Vector2(cos(fa), sin(fa)) * (RO - 0.12)
		_bolt(fl, at(fh.x, fh.y, ["hull"]), fc2.x, fc2.y - sg * 0.12)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var yt := TRUSS_TOP + CH
	var yb := TRUSS_BOT - CH
	var roof := NECK_TOP + T
	var mid := (TRUSS_TOP + TRUSS_BOT) * 0.5
	# power: fuel cell, battery and capacitor bank into the distribution box in the neck; lamps; the arm's control base
	_line("c1", "cable", "power", "FC-01", Vector2(11.05, yb - 1.2), "SWB-S", Vector2(8.55, roof + 0.3), [Vector2(10.6, yb - 1.2), Vector2(10.6, roof + 0.3)])
	_line("c2", "cable", "power", "PWR-B", Vector2(5.7, NECK_BOT - T - 0.5), "SWB-S", Vector2(7.95, roof + 0.5), [Vector2(5.7, roof + 0.45), Vector2(7.95, roof + 0.45)])
	_line("c3", "cable", "power", "CAP-A", Vector2(15.75, yt + 0.4), "SWB-S", Vector2(8.55, roof + 0.15), [Vector2(15.6, yt + 0.4), Vector2(15.6, yt + 0.1), Vector2(8.6, yt + 0.1)])
	_line("c4", "cable", "power", "SWB-S", Vector2(7.95, roof + 0.1), "LAMP-SL", Vector2(7.85, roof + 0.06), [])
	_line("c5", "cable", "power", "LAMP-SL", Vector2(7.55, roof + 0.06), "LAMP-SB", Vector2(5.55, roof + 0.06), [])
	_line("c6", "cable", "power", "LAMP-SB", Vector2(5.25, roof + 0.06), "LAMP-SA", Vector2(1.5, ball(1.25)[0] + 0.1), [Vector2(5.15, roof + 0.06), Vector2(5.15, NECK_TOP - 0.06), Vector2(4.05, NECK_TOP - 0.06), Vector2(4.05, ball(4.05)[0] + 0.12), Vector2(1.5, ball(4.05)[0] + 0.12)])
	_line("c7", "cable", "power", "SWB-S", Vector2(8.55, roof + 0.55), "ARM-CTL", Vector2(18.7, yt + 0.5), [Vector2(9.2, roof + 0.55), Vector2(9.2, yt + 0.5)])
	_line("c8", "cable", "arm", "ARM-CTL", Vector2(19.55, yt + 0.2), "ARM-01", Vector2(19.9, -0.55), [Vector2(19.9, yt + 0.2)])
	_line("cn", "cable", "nav", "NAV-S", Vector2(2.37, FLOOR_Y - 1.3), "CON-S", Vector2(1.7, NECK_TOP - 0.3), [Vector2(2.37, NECK_TOP - 0.06), Vector2(1.75, NECK_TOP - 0.06)])
	# the brake: its own supply in the tail, its cable forward in the open along the truss
	_line("cb", "cable", "brake", "BRK-P", Vector2(21.7, mid + 0.3), "ARM-01", Vector2(20.3, -0.55), [Vector2(21.5, mid + 0.3), Vector2(21.5, yt + 0.12), Vector2(20.3, yt + 0.12)])
	# gas to the fuel cell; propellant to the engine; the long fuel line forward to the ball's quads, in the open
	_line("g1", "pipe", "gas", "H2-T", Vector2(12.55, yb - 0.65), "FC-01", Vector2(12.35, yb - 0.65), [])
	_line("g2", "pipe", "gas", "O2-T", Vector2(14.3, yb - 1.1), "FC-01", Vector2(12.35, yb - 1.25), [Vector2(14.3, yb - 1.32), Vector2(12.45, yb - 1.32), Vector2(12.45, yb - 1.25)])
	_line("p1", "pipe", "rcs", "RCS-T1", Vector2(22.4, TRUSS_TOP - 0.1), "MAIN-E", Vector2(23.4, mid - 0.55), [Vector2(23.4, TRUSS_TOP - 0.1)])
	_line("p2", "pipe", "rcs", "RCS-T2", Vector2(22.4, TRUSS_BOT + 0.1), "MAIN-E", Vector2(23.4, mid + 0.55), [Vector2(23.4, TRUSS_BOT + 0.1)])
	var q2 := C + Vector2(cos(deg_to_rad(70.0)), sin(deg_to_rad(70.0))) * (RO + 0.2)
	_line("p3", "pipe", "rcs", "RCS-T2", Vector2(21.8, TRUSS_BOT + 0.45), "RCS-Q2", q2 + Vector2(0.3, 0.0), [Vector2(21.4, TRUSS_BOT + 0.12), Vector2(9.6, TRUSS_BOT + 0.12), Vector2(9.6, NECK_BOT + 0.1), Vector2(5.4, NECK_BOT + 0.1), q2 + Vector2(0.6, -0.05)])


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	var yb := TRUSS_BOT - CH
	var mid := (TRUSS_TOP + TRUSS_BOT) * 0.5
	_ctrl("GAS-A", "port", at(2.0, ball(2.0)[0] - 0.15, ["hull"]), Vector2(2.0, -sqrt(RO * RO - 1.44) - 0.05), {"medium": "gas", "target": "A"})
	_ctrl("GAS-B", "port", at(3.6, ball(3.6)[1] + 0.15, ["hull"]), Vector2(3.6, sqrt(RO * RO - 0.16) + 0.05), {"medium": "gas", "target": "B"})
	_ctrl("GAS-L", "port", at(8.9, NECK_TOP + 0.12, ["hull"]), Vector2(8.95, NECK_TOP - 0.05), {"medium": "gas", "target": "L"})
	_ctrl("H2-P", "port", by_tag["H2-T"], Vector2(13.2, yb - 1.1), {"medium": "gas", "target": "H2"})
	_ctrl("O2-P", "port", by_tag["O2-T"], Vector2(14.7, yb - 1.05), {"medium": "gas", "target": "O2"})
	_ctrl("SPRAY-P", "port", by_tag["SPRAY-T"], Vector2(23.9, mid + 0.76), {"medium": "gas", "target": "SP"})
	_ctrl("RCS-1P", "port", by_tag["RCS-T1"], Vector2(22.25, TRUSS_TOP - 0.95), {"medium": "fuel", "target": "rcs1"})
	_ctrl("RCS-2P", "port", by_tag["RCS-T2"], Vector2(22.25, TRUSS_BOT + 0.95), {"medium": "fuel", "target": "rcs2"})
	var pn = by_tag["EXT-S"]
	_ctrl("K-FC", "switch", pn, Vector2(17.35, TRUSS_BOT + 0.22), {"target": "K-FC", "state": true})
	_ctrl("K-B", "switch", pn, Vector2(17.7, TRUSS_BOT + 0.22), {"target": "K-B", "state": true})
	_ctrl("E-S01", "test", pn, Vector2(18.0, TRUSS_BOT + 0.22), {"medium": "volt", "target": "bus"})
	_ctrl("E-CAP", "discharge", pn, Vector2(18.3, TRUSS_BOT + 0.22), {"target": "cap"})
	_ctrl("FC-LOCAL", "stop", by_tag["FC-01"], Vector2(11.25, yb - 1.3), {"target": "G"})
	_ctrl("K-BRK", "switch", by_tag["BRK-P"], Vector2(21.88, mid + 0.22), {"target": "K-BRK", "state": true})
	for d in ["DR-AB", "DR-BL", "HATCH-L"]:
		var dp = by_tag[d]
		var c := Geom.centroid(dp.poly) / Geom.M
		_ctrl(d, "door", dp, c, {"target": d, "state": false})


static func _rooms() -> void:
	var ip := PackedVector2Array()
	for q in inner:
		ip.append(q * Geom.M)
	var a: Array = Geometry2D.intersect_polygons(ip, R(-1.0, -5.0, 6.1, NECK_TOP))
	var b: Array = Geometry2D.intersect_polygons(ip, R(-1.0, NECK_TOP + T, 6.1, 5.0))
	var l: Array = Geometry2D.intersect_polygons(ip, R(6.35, -5.0, 20.0, 5.0))
	w.add_room("A", a[0])
	w.add_room("B", b[0])
	w.add_room("L", l[0])


static func meta() -> Dictionary:
	return {
		"id": "s09",
		"name": "S-09 SWIFT",
		"title": ["S-09「雨燕」维修穿梭机 · 26 m", "S-09 SWIFT · MAINTENANCE SHUTTLE · 26 m"],
		"contract": "S-09",
		"length": 26.0,
		"value": {"total": 77700.0, "metal": 6000.0},
		"clamps": [[3.2, 3.15], [8.6, 2.35]],
		"room_names": {"A": "room_sA", "B": "room_sB", "L": "room_sL"},
		"gas": {
			"rooms": {"A": 101.0, "B": 101.0, "L": 101.0},
			"vessels": {
				"H2": {"V": 0.3, "kpa": 1600.0, "piece": "H2-T", "burst": 200.0},
				"O2": {"V": 0.25, "kpa": 1500.0, "piece": "O2-T", "burst": 200.0},
				"SP": {"V": 0.02, "kpa": 900.0, "piece": "SPRAY-T", "burst": 200.0},
			},
			"valves": [],
			"value": 600.0,
		},
		"power": {
			"bus": "SWB-S",
			"sources": [
				{"piece": "FC-01", "kind": "gen", "volts": 120.0, "cable": "c1", "switch": "K-FC", "running": true, "local": "FC-LOCAL"},
				{"piece": "PWR-B", "kind": "battery", "volts": 28.0, "local_volts": 28.0, "cable": "c2", "switch": "K-B", "charge": 0.9, "drain": 0.0004},
				{"piece": "CAP-A", "kind": "cap", "volts": 300.0, "cable": "c3", "charge": 1.0, "discharge": "E-CAP"},
			],
			"isolated": [{"piece": "NAV-S", "volts": 24.0, "charge": 1.0}, {"piece": "BRK-P", "volts": 48.0, "charge": 1.0, "switch": "K-BRK"}],
			"lamps": {"A": "LAMP-SA", "B": "LAMP-SB", "L": "LAMP-SL"},
		},
		"fluids": {
			"volumes": {
				"rcs1": {"fluid": "fuel", "amount": 0.08, "piece": "RCS-T1", "content": 0.6, "leak": 0.1, "port": "RCS-1P", "pump": [0.12, 0.008], "hazard": 0.02},
				"rcs2": {"fluid": "fuel", "amount": 0.08, "piece": "RCS-T2", "content": 0.6, "leak": 0.1, "port": "RCS-2P", "pump": [0.12, 0.008], "hazard": 0.02},
				"rcs_line": {"fluid": "fuel", "amount": 0.015, "nets": ["rcs"], "leak": 0.05, "leak_min": 0.005},
			},
			"joins": [],
			"value": {"fuel": 400.0},
		},
		"ctrls_cfg": {
			"GAS-A": {"rate": 9.0},
			"GAS-B": {"rate": 9.0},
			"GAS-L": {"rate": 6.0},
			"H2-P": {"rate": 0.2},
			"O2-P": {"rate": 0.2},
			"SPRAY-P": {"rate": 0.2},
			"FC-LOCAL": {"target": "FC-01"},
			"E-CAP": {"target": "CAP-A"},
		},
		"labels": {"H2-T": "H₂", "O2-T": "O₂", "FC-01": "FUEL CELL", "RCS-T1": "RCS", "RCS-T2": "RCS", "SPRAY-T": "SPRAY", "CRATE-1": "SPARES", "CRATE-2": "SPARES"},
		"hints": {},
		# safe ways to take out the named equipment; VALIDATE SHIP has a bot walk each one
		"procedures": {
			"FDR-S": [
				{"do": "hose", "ctrl": "GAS-L"},
				{"do": "wait", "until": {"P": ["L", "<", 5.0]}, "max": 90.0},
				{"do": "operate", "ctrl": "HATCH-L"},
				{"do": "wait", "until": {"open": ["L"]}, "max": 5.0},
				{"do": "hose", "ctrl": "GAS-B"},
				{"do": "hose", "ctrl": "GAS-A"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 120.0},
				{"do": "wait", "until": {"P": ["A", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "DR-BL"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 5.0},
				{"do": "free", "piece": "FL-2"},
				{"do": "deliver", "piece": "FL-2", "zone": "metal"},
				{"do": "free", "piece": "FDR-S"},
				{"do": "deliver", "piece": "FDR-S", "zone": "equip"},
			],
			"ARM-01": [
				{"do": "operate", "ctrl": "K-BRK"},
				{"do": "operate", "ctrl": "K-FC"},
				{"do": "operate", "ctrl": "K-B"},
				{"do": "operate", "ctrl": "E-CAP"},
				{"do": "wait", "until": {"charge": ["CAP-A", "<", 0.002]}, "max": 30.0},
				{"do": "measure", "ctrl": "E-S01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "ARM-01"},
				{"do": "deliver", "piece": "ARM-01", "zone": "equip"},
			],
		},
		"blueprint": {
			"hide": ["LAMP-SA", "LAMP-SB", "LAMP-SL", "FL-1", "FL-2", "FL-3", "FL-4", "EXT-S", "LADDER"],
		},
	}
