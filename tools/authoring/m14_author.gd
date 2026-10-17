class_name M14Author
# Authoring script for M-14 "Mole", the 58 m mining ship
# (design/ships/M-14_鼹鼠_设计稿.md, structure: design/ships/M-14_结构图.png).
# Not part of the game: tools/ship_export.gd runs it and writes ships/m14.json.
# Metres, x bow (0) to stern (58), y down; the hull's centre line is y = 0.
#
# A wedge of rock-breaking bow with the crusher drum on two arms out front,
# a thick belly, the long hopper amidships, a squat stern of heavy thrust.
# Forward of the hopper the inclined belt carries crushed rock up from the
# screener to the hopper's mouth; the bridge and the crew cabin sit on the
# roof; aft of the hopper, behind a pressure bulkhead, the equipment room
# (hydraulics, the high-load motors, cooling, the high-voltage cabinet).
# What it asks of you: clear the cargo before the ship — open both gates and
# let the heap run out; a belt still under tension (slack it before it is cut);
# a crusher drum too heavy for any grapple, to be cut along its marked lines;
# blasting charges; the magnetic separator on its own supply.

const T := 0.42
const OUTER := [Vector2(4.6, -2.0), Vector2(8.6, -4.6), Vector2(13.2, -5.2), Vector2(50.6, -5.2), Vector2(51.6, -4.2),
	Vector2(51.6, 4.2), Vector2(50.6, 5.0), Vector2(12.6, 5.0), Vector2(4.6, 3.0)]
# the roof in plates; the floor in plates, with the two discharge gates under the hopper
const CUTS := {2: [0.1283, 0.2353, 0.3957, 0.5561, 0.7166, 0.877], 6: [0.121, 0.2263, 0.4, 0.4947, 0.5895, 0.7526, 0.8842], 7: [0.55, 0.8]}
const PLATE_TAGS := {2: ["TOP-1", "TOP-2", "TOP-3", "TOP-4", "TOP-5", "TOP-6", "TOP-7"]}
const OUTER_C := [Vector2(13.2, -5.2), Vector2(13.9, -7.2), Vector2(29.0, -7.2), Vector2(29.0, -5.2)]
const HOP_X0 := 22.6             # the hopper's walls
const HOP_X1 := 41.0
const GATE_X := [28.2, 31.8, 35.4]
const DRUM := Vector2(2.2, 1.4)  # the crusher drum's centre
const DRUM_R := 2.1
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var w
static var by_tag := {}
static var inner: Array = []


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


static func build(world) -> void:
	w = world
	by_tag = {}
	inner = _inner(OUTER, T)
	_hull()
	_cabin()
	_frames()
	_hopper()
	_bow()
	_conveyor()
	_equipment()
	_cabin_inside()
	_aft()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	inner = _inner(OUTER, T)
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt", tag: String = "") -> void:
	if a == null or b == null:
		push_warning("M14 joint missing a piece at %s,%s" % [x, y])
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


static func _ring(outer: Array, t: float, splits: Dictionary, specials: Dictionary, base: Dictionary, close := true) -> void:
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
			if sp.get("skip", false):
				# an opening in the shell: nothing here, nothing welded across it
				prev = null
				continue
			if not sp.is_empty():
				kind = sp.get("kind", "hull")
				opts.merge(sp, true)
				opts.erase("kind")
			var pc = _tagged(w.add_piece(kind, _mp([a, b, c, d]), opts))
			if prev != null:
				var ja = w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
				if sp.has("weld_tag"):
					ja.set_meta("tag", sp.weld_tag)
			if first == null:
				first = pc
			prev = pc
	if close and prev != null:
		w.add_joint(prev, first, "weld", outer[0].lerp(inn[0], 0.3) * Geom.M)
		w.add_joint(prev, first, "weld", outer[0].lerp(inn[0], 0.7) * Geom.M)


# ---------------------------------------------------------------- the hull

static func _hull() -> void:
	var S := {"density": 1.7, "barrier": true, "cut_speed": 220.0}
	var specials := {
		"8:0": {"art": "", "density": 2.6, "cut_speed": 120.0, "tag": "ARMOR-F"},
		"0:0": {"density": 2.4, "cut_speed": 140.0, "tag": "ARMOR-U"},
		"7:0": {"density": 2.4, "cut_speed": 140.0, "tag": "ARMOR-L"},
		"7:1": {"skip": true},
		"7:2": {"density": 2.4, "cut_speed": 140.0},
		"6:3": {"kind": "hatch", "door": true, "tag": "GATE-2", "open_dir": Vector2(-0.0, 1.6) * Geom.M, "density": 1.4},
		"6:4": {"kind": "hatch", "door": true, "tag": "GATE-1", "open_dir": Vector2(0.0, 1.6) * Geom.M, "density": 1.4},
	}
	for k in 7:
		specials["2:%d" % k] = {"tag": PLATE_TAGS[2][k]}
	_ring(OUTER, T, CUTS, specials, S)
	for cl in [[15.0, 5.0, "CL-01"], [25.0, 5.0, "CL-02"], [45.0, 5.0, "CL-03"]]:
		var j = w.add_joint(at(cl[0], cl[1] - 0.15, ["hull"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# the bridge C and the crew cabin Q on the roof, one shell with a door between
static func _cabin() -> void:
	var S := {"density": 1.3, "barrier": true, "cut_speed": 230.0}
	# edge 1 is its roof (a hatch over Q), edge 3 its floor (on the hull's roof)
	_ring(OUTER_C, 0.36, {1: [0.801, 0.894], 3: [0.3, 0.6]}, {
		"0:0": {"art": "window"},
		"1:1": {"kind": "hatch", "door": true, "tag": "HATCH-Q", "open_dir": Vector2(1.4, 0) * Geom.M},
		"1:0": {"tag": "C-ROOF"},
		"1:2": {"tag": "Q-ROOF"},
	}, S)
	for x in [15.0, 20.0, 24.5, 28.0]:
		_bolt(at(x, -5.38, ["hull"]), at(x, -5.0, ["hull"]), x, -5.2, "weld")
	var bh = _tagged(w.add_piece("bulkhead", R(18.3, -6.84, 18.6, -6.0), {"density": 1.2, "barrier": true, "cut_speed": 240.0, "tag": "BH-CQ"}))
	var dr = _tagged(w.add_piece("door", R(18.32, -6.0, 18.58, -5.56), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-CQ", "open_dir": Vector2(0, -0.44) * Geom.M, "cut_speed": 240.0}))
	_bolt(bh, at(18.45, -7.0, ["hull"]), 18.45, -6.84, "weld")
	_bolt(dr, bh, 18.45, -6.0, "weld")
	_bolt(dr, at(18.45, -5.4, ["hull"]), 18.45, -5.56, "weld")


# ---------------------------------------------------------------- frames: the bulkheads between the sections

static func _frames() -> void:
	var top: float = -5.2 + T
	var bot: float = 5.0 - T
	# forward of the hopper: an open frame (both sides are in vacuum)
	var f1 = _tagged(w.add_piece("beam", R(21.6, top, 22.0, bot), {"density": 1.4, "cut_speed": 150.0, "tag": "FR-1"}))
	_bolt(f1, at(21.8, -5.0, ["hull"]), 21.8, top, "weld")
	_bolt(f1, at(21.8, 4.8, ["hull"]), 21.8, bot, "weld")
	# aft of it: the equipment room's pressure bulkhead, with a door
	var bh = _tagged(w.add_piece("bulkhead", R(41.8, top, 42.2, -0.6), {"density": 1.4, "barrier": true, "cut_speed": 250.0, "tag": "BH-E"}))
	var bh2 = _tagged(w.add_piece("bulkhead", R(41.8, 1.4, 42.2, bot), {"density": 1.4, "barrier": true, "cut_speed": 250.0, "tag": "BH-E2"}))
	var dr = _tagged(w.add_piece("door", R(41.82, -0.6, 42.18, 1.4), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-E", "open_dir": Vector2(0, -2.0) * Geom.M, "cut_speed": 240.0}))
	_bolt(bh, at(42.0, -5.0, ["hull"]), 42.0, top, "weld")
	_bolt(bh2, at(42.0, 4.8, ["hull"]), 42.0, bot, "weld")
	_bolt(dr, bh, 42.0, -0.6, "weld")
	_bolt(dr, bh2, 42.0, 1.4, "weld")


# ---------------------------------------------------------------- the hopper: walls, funnel, liners, the ore

static func _hopper() -> void:
	var top: float = -5.2 + T
	var bot: float = 5.0 - T
	var W := {"density": 1.5, "cut_speed": 170.0}
	var wl = _tagged(w.add_piece("beam", R(HOP_X0, top, HOP_X0 + 0.35, 2.4), W.merged({"tag": "HW-L"})))
	var wr = _tagged(w.add_piece("beam", R(HOP_X1 - 0.35, top, HOP_X1, 2.4), W.merged({"tag": "HW-R"})))
	var sl = _tagged(w.add_piece("beam", _mp([Vector2(HOP_X0, 2.4), Vector2(HOP_X0 + 0.35, 2.4), Vector2(GATE_X[0], bot - 0.05), Vector2(GATE_X[0] - 0.45, bot)]), W.merged({"tag": "HS-L"})))
	var sr = _tagged(w.add_piece("beam", _mp([Vector2(HOP_X1 - 0.35, 2.4), Vector2(HOP_X1, 2.4), Vector2(GATE_X[2] + 0.45, bot), Vector2(GATE_X[2], bot - 0.05)]), W.merged({"tag": "HS-R"})))
	_bolt(wl, at(HOP_X0 + 0.2, -5.0, ["hull"]), HOP_X0 + 0.17, top, "weld")
	_bolt(wr, at(HOP_X1 - 0.2, -5.0, ["hull"]), HOP_X1 - 0.17, top, "weld")
	_bolt(sl, wl, HOP_X0 + 0.17, 2.4, "weld", "HT-1")
	_bolt(sr, wr, HOP_X1 - 0.17, 2.4, "weld", "HT-2")
	# the funnel's foot welds to the floor beside each gate: these tear when the load goes one way
	_bolt(sl, at(GATE_X[0] - 0.6, 4.8, ["hull"]), GATE_X[0] - 0.25, bot, "weld", "HT-3")
	_bolt(sr, at(GATE_X[2] + 0.6, 4.8, ["hull"]), GATE_X[2] + 0.25, bot, "weld", "HT-4")
	# wear liners on the inner walls
	for i in 3:
		var y0: float = top + 0.9 + i * 1.6
		var l1 = _equip("LINER-L%d" % (i + 1), "panel", Rect2(HOP_X0 + 0.35, y0, 0.25, 1.4), {"cls": "metal", "dest": "metal", "mass": 0.3, "density": 2.0, "cut_speed": 150.0, "name_key": "p_liner"})
		_bolt(l1, wl, HOP_X0 + 0.35, y0 + 0.7)
		var l2 = _equip("LINER-R%d" % (i + 1), "panel", Rect2(HOP_X1 - 0.6, y0, 0.25, 1.4), {"cls": "metal", "dest": "metal", "mass": 0.3, "density": 2.0, "cut_speed": 150.0, "name_key": "p_liner"})
		_bolt(l2, wr, HOP_X1 - 0.35, y0 + 0.7)
	# weight sensors under the funnel, the level radar in the roof, the dust sprays
	for i in 4:
		var sx: float = [24.0, 26.6, 37.2, 39.8][i]
		var on = at(sx, 4.8, ["hull"])
		var ws = _equip("WS-%d" % (i + 1), "panel", Rect2(sx - 0.25, bot - 0.3, 0.5, 0.3), {"mass": 0.05, "value": 1500.0, "fragile": 0.5, "name_key": "p_weight_sensor"})
		_bolt(ws, on, sx, bot)
	var rad = _equip("RADAR-L", "rcs_quad", Rect2(31.4, top, 0.8, 0.45), {"mass": 0.05, "value": 2500.0, "fragile": 0.7, "name_key": "p_level_radar"})
	_bolt(rad, at(31.8, -5.0, ["hull"]), 31.8, top)
	var spr = _equip("SPRAY-H", "grating", Rect2(24.2, top, 15.0, 0.3), {"mass": 0.2, "value": 2000.0, "fragile": 0.4, "name_key": "p_dust_spray"})
	_bolt(spr, at(25.0, -5.0, ["hull"]), 25.0, top)
	_bolt(spr, at(38.0, -5.0, ["hull"]), 38.0, top)
	# the visible ore: lumps in rows that follow the funnel, each packed against what it rests on
	var rng := RandomNumberGenerator.new()
	rng.seed = 1414
	var placed: Array = []
	var n := 0
	for ry in [4.18, 3.44, 2.7, 1.96, 1.22, 0.48]:
		var y: float = ry
		# the funnel's inside at this height (above 2.4 the straight walls)
		var k0 := clampf((y + 0.35 - 2.4) / (bot - 2.4), 0.0, 1.0)
		var xl: float = lerpf(HOP_X0 + 0.35, GATE_X[0], k0) + 0.15
		var xr: float = lerpf(HOP_X1 - 0.35, GATE_X[2], k0) - 0.15
		if y < 2.4:
			# against the walls; clear of the wear liners where they reach down
			var by_liner: bool = y - 0.4 < 0.72
			xl = HOP_X0 + (0.62 if by_liner else 0.37)
			xr = HOP_X1 - (0.62 if by_liner else 0.37)
		var x := xl
		while true:
			# (small enough that neighbouring rows never overlap: rows 0.74 apart)
			var r := rng.randf_range(0.26, 0.34)
			var cx := x + r
			if cx + r > xr:
				break
			var cy := y + rng.randf_range(-0.02, 0.02)
			var pts: Array = []
			var kk := rng.randi_range(6, 8)
			for i in kk:
				var a := TAU * i / kk + rng.randf_range(-0.2, 0.2)
				pts.append(Vector2(cx, cy) + Vector2.from_angle(a) * r * rng.randf_range(0.82, 1.0))
			# never into the hopper's own walls, funnel, liners or floor: a lump that would
			# overlap them moves along until it is clear (else it is left out)
			var tries := 0
			while _hits_structure(pts) and tries < 12:
				for i in pts.size():
					pts[i] += Vector2(0.05, 0.0)
				cx += 0.05
				tries += 1
			if tries >= 12 or cx + r > xr:
				x = cx + r
				continue
			n += 1
			var ch = _tagged(w.add_piece("ore", _mp(pts), {"cls": "metal", "dest": "metal", "density": 3.4, "cut_speed": 120.0, "tag": "ORE-%d" % n, "name_key": "p_ore"}))
			placed.append([ch, Vector2(cx, cy), r])
			x = cx + r + rng.randf_range(0.03, 0.1)
	for e in placed:
		var c: Vector2 = e[1]
		var r: float = e[2]
		# the lump it rests on: the nearest one below that it (nearly) touches
		var best = null
		var bd := INF
		for f in placed:
			if f[0] == e[0] or f[1].y <= c.y + 0.25:
				continue
			var dd: float = f[1].distance_to(c) - r - float(f[2])
			if dd < bd:
				bd = dd
				best = f
		if best != null and bd < 0.25:
			var dir: Vector2 = (best[1] - c).normalized()
			var jp: Vector2 = c + dir * (r + bd * 0.5)
			_bolt(e[0], best[0], jp.x, jp.y, "pack")
			continue
		# else what it leans on: a gate, the funnel, a wall, in any direction from straight down to the side
		var done := false
		for ang in [PI * 0.5, PI * 0.25, PI * 0.75, 0.0, PI, PI * 0.15, PI * 0.85]:
			var dir2 := Vector2.from_angle(ang)
			for step in 5:
				var q: Vector2 = c + dir2 * (r + 0.04 + step * 0.06)
				var on = at(q.x, q.y, ["hull", "hatch", "beam", "fixture"])
				if on != null:
					# half way between the lump's edge and what it leans on
					var jp2: Vector2 = (c + dir2 * r * 0.85).lerp(q, 0.5)
					_bolt(e[0], on, jp2.x, jp2.y, "pack")
					done = true
					break
			if done:
				break
		if done:
			continue
		# or any lump it touches
		for f in placed:
			if f[0] == e[0]:
				continue
			var dd2: float = f[1].distance_to(c) - r - float(f[2])
			if dd2 < 0.2:
				var jp3: Vector2 = c + (f[1] - c).normalized() * (r + dd2 * 0.5)
				_bolt(e[0], f[0], jp3.x, jp3.y, "pack")
				break


# does a lump's outline (m) overlap anything already built that is not ore?
static func _hits_structure(pts: Array) -> bool:
	var poly := _mp(pts)
	var bb := Geom.bbox(poly).grow(2.0)
	for id in w.order:
		var q = w.pieces[id]
		if q.kind == "ore" or not Geom.bbox(q.poly).intersects(bb):
			continue
		if not Geometry2D.intersect_polygons(poly, q.poly).is_empty():
			return true
	return false


# ---------------------------------------------------------------- the bow: armour, the crusher on its arms

static func _bow() -> void:
	# two arms from the bow wall out to the drum's hub
	var ah := {"density": 1.6, "cut_speed": 120.0}
	var au = _tagged(w.add_piece("beam", _mp([Vector2(3.6, -0.25), Vector2(4.6, -0.25), Vector2(4.6, 0.25), Vector2(3.6, 0.35)]), ah.merged({"tag": "ARM-1"})))
	var al = _tagged(w.add_piece("beam", _mp([Vector2(3.6, 2.45), Vector2(4.6, 2.55), Vector2(4.6, 3.0), Vector2(3.6, 3.0)]), ah.merged({"tag": "ARM-2"})))
	_bolt(au, at(4.8, 0.0, ["hull"]), 4.6, 0.0, "bolt", "PIV-A1")
	_bolt(al, at(4.8, 2.75, ["hull"]), 4.6, 2.75, "bolt", "PIV-A2")
	# the drum: about 6 t, beyond any grapple; marked to be cut in three across its hub
	var pts: Array = []
	for i in 16:
		var a := TAU * i / 16.0
		var rr := DRUM_R * (1.0 if i % 2 == 0 else 0.86)
		pts.append(DRUM + Vector2.from_angle(a) * rr)
	var dr = _equip("CRUSH-H", "reel", Rect2(DRUM.x - DRUM_R, DRUM.y - DRUM_R, DRUM_R * 2, DRUM_R * 2), {"mass": 6.0, "value": 24000.0, "fragile": 0.2, "cut_speed": 90.0, "name_key": "p_crusher"}, _mp(pts))
	dr.set_meta("segments", [[DRUM.x - 0.75, DRUM.y - DRUM_R - 0.2, DRUM.x - 0.75, DRUM.y + DRUM_R + 0.2], [DRUM.x + 0.75, DRUM.y - DRUM_R - 0.2, DRUM.x + 0.75, DRUM.y + DRUM_R + 0.2]])
	_bolt(dr, au, 3.75, 0.05)
	_bolt(dr, al, 3.75, 2.7)
	# behind the armour: the vibration hammer drive, the drum's lube pump, the dust filter
	var vib = _equip("VIB-D", "eng_core", Rect2(5.05, -0.8, 2.6, 1.8), {"mass": 1.2, "value": 9000.0, "fragile": 0.35, "name_key": "p_vib_drive"})
	_bolt(vib, at(4.8, -0.3, ["hull"]), 5.05, -0.3)
	_bolt(vib, at(4.8, 0.5, ["hull"]), 5.05, 0.5)
	var lp = _equip("LUBE-D", "pump", Rect2(5.05, 1.5, 1.5, 1.3), {"mass": 0.2, "value": 2000.0, "fragile": 0.4, "name_key": "p_lube_pump"})
	_bolt(lp, at(4.8, 2.1, ["hull"]), 5.05, 2.1)
	var df = _equip("DUST-F", "filter", Rect2(9.6, -4.3, 2.0, 1.2), {"mass": 0.4, "value": 3000.0, "fragile": 0.4, "hazard": "chem", "dest": "hazard", "name_key": "p_dust_filter"})
	_bolt(df, at(10.0, -4.55, ["hull"]), 10.0, -4.3)
	_bolt(df, at(11.2, -4.62, ["hull"]), 11.2, -4.3)


# ---------------------------------------------------------------- the belt, the screener, the separator, stores

static func _conveyor() -> void:
	var top: float = -5.2 + T
	var bot: float = 5.0 - T
	# the belt's frame: from low by the screener up to the hopper's mouth
	var fr = _tagged(w.add_piece("beam", _mp([Vector2(12.0, 3.4), Vector2(21.2, -3.6), Vector2(21.6, -3.1), Vector2(12.4, 3.9)]), {"density": 1.3, "cut_speed": 160.0, "tag": "CONV-F"}))
	_bolt(fr, at(21.8, -3.3, ["beam"]), 21.6, -3.3, "weld")
	_bolt(fr, at(12.2, 4.7, ["hull"]), 12.2, 3.9, "weld")
	var belt = _equip("BELT", "grating", Rect2(12.0, -4.0, 9.4, 7.6), {"mass": 1.6, "value": 6000.0, "fragile": 0.3, "cut_speed": 160.0, "name_key": "p_belt"},
		_mp([Vector2(11.7, 2.9), Vector2(20.9, -4.1), Vector2(21.2, -3.6), Vector2(12.0, 3.4)]))
	# its head end on the frame, and the tensioner at its foot holding it taut
	_bolt(belt, fr, 20.9, -3.75, "bolt", "BELT-A")
	_bolt(belt, fr, 16.5, -0.2, "lock")
	_bolt(belt, fr, 12.1, 3.1, "bolt", "TEN-1")
	var cm = _equip("CONV-M", "pump", Rect2(14.6, 3.2, 1.4, 1.4), {"mass": 0.6, "value": 5000.0, "fragile": 0.4, "name_key": "p_belt_motor"})
	_bolt(cm, at(15.0, 4.8, ["hull"]), 15.0, bot)
	_bolt(cm, at(15.7, 4.8, ["hull"]), 15.7, bot)
	var scr = _equip("SCR", "cabinet", Rect2(16.6, 2.1, 2.4, 2.48), {"mass": 1.8, "value": 12000.0, "fragile": 0.35, "mandatory": true, "name_key": "p_screener"})
	_bolt(scr, at(17.0, 4.8, ["hull"]), 17.0, bot)
	_bolt(scr, at(18.6, 4.8, ["hull"]), 18.6, bot)
	var mag = _equip("MAG-S", "swb", Rect2(19.0, top, 2.4, 0.8), {"mass": 0.5, "value": 6000.0, "fragile": 0.4, "name_key": "p_mag_sep"})
	_bolt(mag, at(19.6, -5.0, ["hull"]), 19.6, top)
	_bolt(mag, at(20.9, -5.0, ["hull"]), 20.9, top)
	var ch = _equip("CHARGES", "locker", Rect2(16.6, top, 1.1, 1.1), {"mass": 0.15, "value": 4000.0, "fragile": 0.3, "hazard": "explosive", "name_key": "p_charges"})
	_bolt(ch, at(17.1, -5.0, ["hull"]), 17.1, top, "lock")
	var tz = _equip("TEETH", "cargo", Rect2(13.6, top, 2.8, 1.0), {"mass": 0.8, "value": 7000.0, "fragile": 0.2, "name_key": "p_spare_teeth"})
	_bolt(tz, at(14.2, -5.0, ["hull"]), 14.2, top)
	_bolt(tz, at(15.8, -5.0, ["hull"]), 15.8, top)
	var lab = _equip("LAB", "console", Rect2(19.3, 1.6, 2.2, 1.0), {"mass": 0.25, "value": 5000.0, "fragile": 0.6, "name_key": "p_assay"})
	_bolt(lab, by_tag["FR-1"], 21.5, 2.0)
	var smp = _equip("SAMPLES", "locker", Rect2(19.6, 2.8, 1.8, 1.7), {"mass": 0.3, "value": 3000.0, "fragile": 0.4, "name_key": "p_samples"})
	_bolt(smp, at(20.4, 4.8, ["hull"]), 20.4, bot)


# ---------------------------------------------------------------- the equipment room E

static func _equipment() -> void:
	var top: float = -5.2 + T
	var bot: float = 5.0 - T
	var roof := func(x: float): return at(x, -5.0, ["hull"])
	var flo := func(x: float): return at(x, 4.8, ["hull"])
	var hpu = _equip("HPU-M", "pump", Rect2(42.4, top, 1.6, 2.4), {"mass": 2.2, "value": 14000.0, "fragile": 0.35, "room": "E", "name_key": "p_hpu"})
	_bolt(hpu, roof.call(42.8), 42.8, top)
	_bolt(hpu, roof.call(43.6), 43.6, top)
	var m1 = _equip("MOT-1", "eng_core", Rect2(44.3, top, 2.4, 1.9), {"mass": 1.6, "value": 11000.0, "fragile": 0.35, "room": "E", "mandatory": true, "name_key": "p_hl_motor"})
	_bolt(m1, roof.call(44.8), 44.8, top)
	_bolt(m1, roof.call(46.2), 46.2, top)
	var m2 = _equip("MOT-2", "eng_core", Rect2(44.3, bot - 1.9, 2.4, 1.9), {"mass": 1.6, "value": 11000.0, "fragile": 0.35, "room": "E", "name_key": "p_hl_motor"})
	_bolt(m2, flo.call(44.8), 44.8, bot)
	_bolt(m2, flo.call(46.2), 46.2, bot)
	var cool = _equip("COOL-M", "radiator", Rect2(47.0, top, 1.5, 2.6), {"mass": 0.9, "value": 6000.0, "fragile": 0.35, "room": "E", "name_key": "p_radiator"})
	_bolt(cool, roof.call(47.7), 47.7, top)
	var pw = _equip("PWR-M", "swb", Rect2(48.9, top, 1.9, 3.4), {"mass": 0.8, "value": 8000.0, "fragile": 0.4, "room": "E", "name_key": "p_hv_cabinet"})
	_bolt(pw, roof.call(49.3), 49.3, top)
	_bolt(pw, roof.call(50.4), 50.4, top)
	var lube = _equip("LUBE-T", "fueltank", Rect2(42.4, bot - 1.2, 1.7, 1.2), {"mass": 0.3, "value": 1500.0, "fragile": 0.35, "room": "E", "name_key": "p_lube_tank"})
	_bolt(lube, flo.call(42.8), 42.8, bot, "lock")
	_bolt(lube, flo.call(43.7), 43.7, bot, "lock")
	var comp = _equip("COMP", "gastank", Rect2(47.1, bot - 2.2, 1.3, 2.2), {"mass": 0.5, "value": 4000.0, "fragile": 0.3, "room": "E", "hazard": "gas_tank", "name_key": "p_compressor"})
	_bolt(comp, flo.call(47.5), 47.5, bot)
	_bolt(comp, flo.call(48.1), 48.1, bot)
	var bat = _equip("BAT-M", "battery", Rect2(48.9, bot - 1.6, 1.9, 1.6), {"mass": 0.8, "value": 5000.0, "fragile": 0.4, "room": "E", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bat, flo.call(49.3), 49.3, bot)
	_bolt(bat, flo.call(50.4), 50.4, bot)
	var lpe = _equip("LAMP-E", "lamp", Rect2(46.8, top, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "E", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lpe, roof.call(46.9), 46.9, top)
	# the outside panel on the roof over E: battery, the separator's own supply, a test point, a tension gauge lead
	var pn = _equip("PNL-M", "panel", Rect2(43.4, -5.8, 3.4, 0.6), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, roof.call(43.9), 43.9, -5.2)
	_bolt(pn, roof.call(46.3), 46.3, -5.2)


# ---------------------------------------------------------------- the bridge and the crew cabin

static func _cabin_inside() -> void:
	var flo := -5.2 - 0.36
	var top := -7.2 + 0.36
	var con = _equip("CON-C", "console", Rect2(14.4, flo - 0.8, 1.4, 0.8), {"mass": 0.3, "value": 4000.0, "fragile": 0.5, "room": "C", "name_key": "p_console"})
	_bolt(con, at(14.9, -5.3, ["hull"]), 14.9, flo)
	var r := Rect2(16.0, flo - 1.2, 0.6, 1.2)
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	var seat = _equip("SEAT-C", "seat", r, {"mass": 0.12, "value": 600.0, "fragile": 0.3, "room": "C", "name_key": "p_seat_p"}, sp)
	_bolt(seat, at(16.2, -5.3, ["hull"]), 16.15, flo)
	var rack = _equip("RACK-C", "nav_rack", Rect2(17.3, top, 0.8, 1.28), {"mass": 0.2, "value": 4500.0, "fragile": 0.7, "room": "C", "name_key": "p_nav"})
	_bolt(rack, at(17.7, -7.1, ["hull"]), 17.7, top)
	for i in 3:
		var bx := 19.2 + i * 2.2
		var bk = _equip("BUNK-%d" % (i + 1), "bunk", Rect2(bx, top, 2.0, 0.6), {"mass": 0.1, "value": 600.0, "fragile": 0.3, "room": "Q", "name_key": "p_bunk"})
		_bolt(bk, at(bx + 0.4, -7.1, ["hull"]), bx + 0.4, top)
		_bolt(bk, at(bx + 1.6, -7.1, ["hull"]), bx + 1.6, top)
	var lk = _equip("LOCKER-Q", "locker", Rect2(25.9, flo - 1.0, 0.9, 1.0), {"mass": 0.15, "value": 800.0, "fragile": 0.3, "room": "Q", "name_key": "p_locker"})
	_bolt(lk, at(26.3, -5.3, ["hull"]), 26.3, flo)
	var env = _equip("ENV-Q", "env", Rect2(27.0, flo - 0.8, 1.6, 0.8), {"mass": 0.3, "value": 1500.0, "fragile": 0.5, "room": "Q", "name_key": "p_env"})
	_bolt(env, at(27.8, -5.3, ["hull"]), 27.8, flo)
	for i in 2:
		var sx := 19.4 + i * 0.9
		var su = _equip("SUIT-%d" % (i + 1), "suit", Rect2(sx, flo - 1.0, 0.8, 1.0), {"mass": 0.05, "value": 1200.0, "fragile": 0.4, "room": "Q", "name_key": "p_suit"})
		_bolt(su, at(sx + 0.4, -5.3, ["hull"]), sx + 0.4, flo, "lock")
	var lq = _equip("LAMP-Q", "lamp", Rect2(25.2, top, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "Q", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lq, at(25.5, -7.1, ["hull"]), 25.48, top)


# ---------------------------------------------------------------- aft: two heavy thrusters, the stabiliser beams

static func _aft() -> void:
	var tf = _tagged(w.add_piece("beam", R(51.6, -3.9, 52.4, 3.9), {"density": 1.5, "cut_speed": 140.0, "tag": "THRUST"}))
	for y in [-3.0, -1.0, 1.0, 3.0]:
		_bolt(tf, at(51.4, y, ["hull"]), 51.6, y)
	for i in 2:
		var yc: float = [-2.2, 2.2][i]
		var e = _equip("ENG-M%d" % (i + 1), "eng_front", Rect2(52.4, yc - 1.4, 2.6, 2.8), {"mass": 2.6, "value": 11000.0, "fragile": 0.3, "name_key": "p_main"})
		_bolt(e, tf, 52.4, yc - 0.8)
		_bolt(e, tf, 52.4, yc + 0.8, "weld")
		var nz = _equip("NOZ-M%d" % (i + 1), "nozzle", Rect2(55.0, yc - 1.7, 3.0, 3.4), {"cls": "metal", "dest": "metal", "mass": 0.8, "cut_speed": 170.0, "name_key": "p_nozzle"},
			_mp([Vector2(55.0, yc - 1.1), Vector2(58.0, yc - 1.7), Vector2(58.0, yc + 1.7), Vector2(55.0, yc + 1.1)]))
		_bolt(nz, e, 55.0, yc - 0.5)
		_bolt(nz, e, 55.0, yc + 0.5)
	for sg in [-1.0, 1.0]:
		var sb = _tagged(w.add_piece("beam", R(46.0, sg * 5.2, 57.6, sg * 5.7), {"density": 1.3, "cut_speed": 150.0, "tag": "STAB-%s" % ("U" if sg < 0 else "L")}))
		_bolt(sb, at(47.0, sg * 5.0, ["hull"]), 47.0, sg * 5.2)
		_bolt(sb, at(50.0, sg * 5.0, ["hull"]), 50.0, sg * 5.2)
		var q = _equip("RCS-M%d" % (1 if sg < 0 else 2), "rcs_quad", Rect2(56.6, -5.2 if sg < 0 else 4.6, 0.9, 0.6), {"mass": 0.1, "value": 500.0, "fragile": 0.3, "name_key": "p_att"})
		_bolt(q, sb, 57.0, sg * 5.2)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var top: float = -5.2 + T
	# high-voltage power: the battery into the cabinet; out to the motors, forward along the roof to the bow
	_line("c1", "cable", "power", "BAT-M", Vector2(49.8, 3.4), "PWR-M", Vector2(49.8, -1.6), [Vector2(49.8, 2.0)])
	_line("c2", "cable", "power", "PWR-M", Vector2(49.1, -2.0), "MOT-1", Vector2(46.3, -3.4), [Vector2(48.6, -2.0), Vector2(46.3, -2.4)])
	_line("c3", "cable", "power", "PWR-M", Vector2(49.1, -1.6), "MOT-2", Vector2(46.3, 3.0), [Vector2(48.6, -1.1), Vector2(46.3, 1.8)])
	_line("c4", "cable", "power", "PWR-M", Vector2(49.0, -3.6), "HPU-M", Vector2(43.6, -3.5), [Vector2(48.6, -4.5), Vector2(43.6, -4.5)])
	_line("c5", "cable", "power", "PWR-M", Vector2(49.5, -4.4), "LAMP-E", Vector2(46.9, top + 0.08), [Vector2(49.5, -4.65), Vector2(46.9, -4.65)])
	_line("c6", "cable", "power", "PWR-M", Vector2(49.3, -1.6), "CONV-M", Vector2(15.3, 3.7),
		[Vector2(48.6, -1.2), Vector2(42.4, -1.2), Vector2(42.4, -4.6), Vector2(21.4, -4.6), Vector2(21.4, 4.2), Vector2(15.3, 4.2)])
	_line("c7", "cable", "power", "CONV-M", Vector2(15.0, 3.6), "SCR", Vector2(17.2, 3.2), [Vector2(16.1, 3.6)])
	_line("c8", "cable", "power", "PWR-M", Vector2(49.6, -1.5), "VIB-D", Vector2(6.8, 0.0),
		[Vector2(48.6, -1.5), Vector2(42.6, -1.5), Vector2(42.6, -4.7), Vector2(12.0, -4.7), Vector2(8.0, -1.5), Vector2(6.8, -0.3)])
	_line("c9", "cable", "power", "VIB-D", Vector2(5.6, 0.6), "CRUSH-H", Vector2(3.4, 1.4), [Vector2(4.4, 1.2)])
	_line("c10", "cable", "power", "PWR-M", Vector2(49.8, -1.6), "CON-C", Vector2(15.1, -5.9),
		[Vector2(48.6, -0.6), Vector2(42.7, -0.6), Vector2(42.7, -4.75), Vector2(28.6, -4.75), Vector2(28.6, -5.7), Vector2(15.1, -5.7)])
	_line("c11", "cable", "power", "CON-C", Vector2(15.4, -5.9), "LAMP-Q", Vector2(25.48, -6.75), [Vector2(16.8, -6.4), Vector2(25.48, -6.4)])
	_line("c12", "cable", "power", "CON-C", Vector2(14.7, -6.1), "RACK-C", Vector2(17.7, -6.0), [Vector2(14.7, -6.5), Vector2(17.7, -6.5)])
	_line("c13", "cable", "power", "LAMP-Q", Vector2(25.6, -6.75), "ENV-Q", Vector2(27.8, -6.0), [Vector2(27.8, -6.6)])
	# the magnetic separator on its own little supply
	_line("cm", "cable", "nav", "MAG-S", Vector2(20.0, -4.2), "LAB", Vector2(20.4, 1.8), [Vector2(20.0, 1.2)])
	# hydraulics: the power unit into the gate cylinders under the hopper; lube from the tank to the drum's pump
	_line("h1", "pipe", "hyd", "HPU-M", Vector2(43.2, -2.5), "GATE-2", Vector2(34.4, 4.8), [Vector2(43.2, 4.2), Vector2(36.0, 4.2), Vector2(34.4, 4.5)])
	_line("h2", "pipe", "hyd", "HPU-M", Vector2(42.7, -2.5), "GATE-1", Vector2(29.2, 4.8), [Vector2(42.7, 4.05), Vector2(36.0, 4.05), Vector2(29.2, 4.5)])
	_line("l1", "pipe", "lube", "LUBE-T", Vector2(42.6, 3.8), "LUBE-D", Vector2(5.8, 2.0),
		[Vector2(42.6, 4.35), Vector2(36.2, 4.35), Vector2(35.5, 4.45), Vector2(22.4, 4.45), Vector2(12.6, 4.45), Vector2(8.0, 2.6), Vector2(5.8, 2.4)])


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	_ctrl("G-C", "port", by_tag["C-ROOF"], Vector2(15.5, -7.4), {"medium": "gas", "target": "C"})
	_ctrl("G-Q", "port", by_tag["Q-ROOF"], Vector2(28.0, -7.4), {"medium": "gas", "target": "Q"})
	_ctrl("G-E", "port", by_tag["TOP-7"], Vector2(48.0, -5.4), {"medium": "gas", "target": "E"})
	var pn = by_tag["PNL-M"]
	_ctrl("K-M", "switch", pn, Vector2(43.9, -5.5), {"target": "K-M", "state": true})
	_ctrl("K-MAG", "switch", pn, Vector2(44.6, -5.5), {"target": "K-MAG", "state": true})
	_ctrl("E-M01", "test", pn, Vector2(45.3, -5.5), {"medium": "volt", "target": "bus"})
	_ctrl("E-MAG", "test", by_tag["MAG-S"], Vector2(20.6, -4.0), {"medium": "volt", "target": "MAG-S"})
	_ctrl("TN-1", "probe", by_tag["BELT"], Vector2(13.0, 2.4), {"medium": "tension", "target": "BELT-A"})
	_ctrl("HYD-P", "port", by_tag["HPU-M"], Vector2(43.2, -3.8), {"medium": "hydraulic", "target": "hyd", "hidden_room": "E"})
	_ctrl("LUBE-P", "port", by_tag["LUBE-T"], Vector2(43.6, 3.6), {"medium": "hydraulic", "target": "lube", "hidden_room": "E"})
	_ctrl("COOL-P", "port", by_tag["COOL-M"], Vector2(47.7, -2.6), {"medium": "coolant", "target": "cool", "hidden_room": "E"})
	_ctrl("AIR-P", "port", by_tag["COMP"], Vector2(47.7, 2.6), {"medium": "gas", "target": "AIR", "hidden_room": "E"})
	for d in [["HATCH-Q", ""], ["DR-CQ", "Q"], ["DR-E", ""], ["GATE-1", ""], ["GATE-2", ""]]:
		var dp = by_tag[d[0]]
		var c := Geom.centroid(dp.poly) / Geom.M
		if d[0].begins_with("GATE"):
			c += Vector2(0, 0.35)
		_ctrl(d[0], "door", dp, c, {"target": d[0], "state": false, "hidden_room": d[1]})


static func _rooms() -> void:
	var ci := _inner(OUTER_C, 0.36)
	# the bridge forward of the bulkhead, the cabin aft of it
	var y0: float = ci[1].y
	var y1: float = ci[0].y
	w.add_room("C", _mp([ci[0], ci[1], Vector2(18.3, y0), Vector2(18.3, y1)]))
	w.add_room("Q", _mp([Vector2(18.6, y0), ci[2], ci[3], Vector2(18.6, y1)]))
	var ii := _inner(OUTER, T)
	w.add_room("E", _mp([Vector2(42.2, ii[3].y), ii[3], ii[4], ii[5], ii[6], Vector2(42.2, ii[6].y)]))


static func meta() -> Dictionary:
	return {
		"id": "m14",
		"name": "M-14 MOLE",
		"title": ["M-14「鼹鼠」采矿船 · 58 m", "M-14 MOLE · MINING SHIP · 58 m"],
		"contract": "M-14",
		"length": 58.0,
		"value": {"total": 249000.0, "metal": 26000.0},
		"clamps": [[15.0, 5.0], [25.0, 5.0], [45.0, 5.0]],
		"room_names": {"C": "room_kC", "Q": "room_kQ", "E": "room_kE"},
		# the hopper's heap (scripts/ore.gd)
		"ore": {"box": [HOP_X0 + 0.35, -4.4, HOP_X1 - 0.35, 4.5], "fines": 34.0, "price": 900.0, "gates": ["GATE-1", "GATE-2"], "flow": 0.5,
			"tear": ["HT-1", "HT-2", "HT-3", "HT-4"], "pins": "pack"},
		# the belt held taut by its tensioner (scripts/mech.gd)
		"preloads": {"BELT-A": {"pins": ["TEN-1"], "piece": "BELT", "push": [0.7, -0.5], "kn": 38.0, "hits": "SCR"}},
		"gas": {
			"rooms": {"C": 101.0, "Q": 101.0, "E": 95.0},
			"vessels": {"AIR": {"V": 0.08, "kpa": 800.0, "piece": "COMP", "burst": 200.0}},
			"valves": [],
			"value": 400.0,
		},
		"power": {
			"bus": "PWR-M",
			"sources": [{"piece": "BAT-M", "kind": "battery", "volts": 600.0, "local_volts": 48.0, "cable": "c1", "switch": "K-M", "charge": 0.85, "drain": 0.0004}],
			"isolated": [{"piece": "MAG-S", "volts": 48.0, "charge": 1.0, "switch": "K-MAG"}],
			"lamps": {"E": "LAMP-E", "Q": "LAMP-Q"},
		},
		"fluids": {
			"volumes": {
				"hyd": {"fluid": "hydraulic", "amount": 0.22, "piece": "HPU-M", "content": 1.6, "leak": 0.12, "port": "HYD-P", "pump": [0.12, 0.008]},
				"hyd_line": {"fluid": "hydraulic", "amount": 0.016, "nets": ["hyd"], "leak": 0.08, "leak_min": 0.004},
				"lube": {"fluid": "hydraulic", "amount": 0.08, "piece": "LUBE-T", "content": 0.6, "leak": 0.1, "port": "LUBE-P", "pump": [0.12, 0.008]},
				"lube_line": {"fluid": "hydraulic", "amount": 0.012, "nets": ["lube"], "leak": 0.05, "leak_min": 0.004},
				"cool": {"fluid": "coolant", "amount": 0.12, "piece": "COOL-M", "content": 0.8, "leak": 0.1, "port": "COOL-P", "pump": [0.12, 0.008]},
			},
			"joins": [],
			"value": {"hydraulic": 400.0, "coolant": 200.0},
		},
		"ctrls_cfg": {"G-C": {"rate": 9.0}, "G-Q": {"rate": 9.0}, "G-E": {"rate": 9.0}, "AIR-P": {"rate": 0.4}},
		"labels": {"COMP": "AIR", "HPU-M": "HYD", "LUBE-T": "LUBE", "CHARGES": "CHARGES", "CRUSH-H": "6.0 t", "TEETH": "SPARE TEETH"},
		"hints": {},
		"market": {
			"class": "M", "name": ["鼹鼠级采矿船", "MOLE-CLASS MINING SHIP"], "time": 40.0,
			"rooms": {"C": [0.2, 40.0, 101.0], "Q": [0.2, 40.0, 101.0], "E": [0.3, 40.0, 100.0]},
			"vessels": {"AIR": [0.25, 50.0, 200.0, 600.0, 900.0]},
			"charge": {"BAT-M": [0.15, 1.0]},
			"fluids": {"hyd": [0.06, 0.24], "cool": [0.02, 0.12]}, "fill": {"hyd_line": "hyd", "lube_line": "lube"},
			"knockable": ["CON-C", "RACK-C", "SCR", "MAG-S", "LAB", "RADAR-L", "ENV-Q"],
			"drift": ["TEETH", "SAMPLES", "LOCKER-Q"],
			"section_x": 22.0,
			"slots": {
				"hidden_damage": {"plates": ["TOP-6"]},
				"gate_jam": {"gates": ["GATE-1", "GATE-2"]},
			},
			"mechanisms": true,
		},
		"procedures": {
			"SCR": [
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-M01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "SCR"},
				{"do": "deliver", "piece": "SCR", "zone": "equip"},
			],
			"MOT-1": [
				{"do": "hose", "ctrl": "G-E"},
				{"do": "wait", "until": {"P": ["E", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "DR-E"},
				{"do": "wait", "until": {"open": ["E"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-M"},
				{"do": "measure", "ctrl": "E-M01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "MOT-1"},
				{"do": "deliver", "piece": "MOT-1", "zone": "equip"},
			],
		},
	}
