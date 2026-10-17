class_name Med47Author
# Authoring script for MED-47 "Silence", the 82 m hospital ship
# (design/ships/MED-47_缄默_设计稿.md, structure: design/ships/MED-47_结构图.png).
# Not part of the game: tools/ship_export.gd runs it and writes ships/med47.json.
# Metres, x bow (0) to stern (82), y down; the corridor's centre line is y = 0.
#
# A long thin pressurised corridor runs from the bridge B at the bow to the
# life-support block S aft, a pressure door half way (fore K1, aft K2). Off it,
# like the teeth of a comb, twelve medical pods, six above (U1..U6) and six
# below (L1..L6), each on a short neck with its own hatch, its own battery (and
# switch), its own oxygen bottle and air loop: emergency, operating, isolation
# (negative pressure, a filter, a biohazard box) and freezer (-80 °C) rooms.
# What it asks of you: peel it one pod at a time, never trusting the pod
# overview on the bridge; pods that still hold pressure behind a dead corridor;
# a pod's own battery still feeding its equipment after the main power is off;
# biohazard to seal before it moves; the isolation rooms' air to draw through a
# filter, not into the corridor.

const T := 0.4                   # corridor and outer hull plates
const TP := 0.35                 # pod shells
const CY := 1.5                  # corridor: outer walls at ±1.5, inside ±1.1
const KX0 := 9.6
const KX1 := 63.4
const MID := 35.55               # the corridor's pressure door
const PODX := [13.9, 22.56, 31.22, 39.88, 48.54, 57.2]
const PY0 := 2.3                 # pod shell from 2.3 to 6.9 off the centre line
const PY1 := 6.9
const PW := 3.4                  # half width
const PC := 0.6                  # corner chamfer
const NECK := 0.7                # half width of the neck's opening
const TYPES := {"U": ["er", "or", "iso", "frz", "er", "iso"], "L": ["or", "frz", "iso", "er", "or", "frz"]}
const OUTER_B := [Vector2(0.0, -1.2), Vector2(1.6, -3.0), Vector2(9.6, -3.0), Vector2(9.6, 3.0), Vector2(1.6, 3.0), Vector2(0.0, 1.2)]
const OUTER_S := [Vector2(63.4, -5.0), Vector2(76.4, -5.0), Vector2(77.2, -4.2), Vector2(77.2, 4.2), Vector2(76.4, 5.0), Vector2(63.4, 5.0)]
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var w
static var by_tag := {}
static var pods: Array = []      # [{name, x, sg, type, room}]


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
	pods = []
	for side in ["U", "L"]:
		for i in 6:
			var nm: String = "%s%d" % [side, i + 1]
			pods.append({"name": nm, "x": PODX[i], "sg": -1.0 if side == "U" else 1.0, "type": TYPES[side][i], "room": nm})
	_bridge()
	_corridor()
	_life()
	_aft()
	for pd in pods:
		_pod(pd)
	_bridge_inside()
	_corridor_inside()
	_life_inside()
	_lines()
	_controls()
	_rooms()


static func rooms_only(world) -> void:
	w = world
	pods = []
	for side in ["U", "L"]:
		for i in 6:
			var nm: String = "%s%d" % [side, i + 1]
			pods.append({"name": nm, "x": PODX[i], "sg": -1.0 if side == "U" else 1.0, "type": TYPES[side][i], "room": nm})
	_rooms()


static func _tagged(pc):
	if pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func _bolt(a, b, x: float, y: float, type: String = "bolt", tag: String = "") -> void:
	if a == null or b == null:
		push_warning("MED47 joint missing a piece at %s,%s" % [x, y])
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


# a ring of hull plates round an outline; splits: {edge: [fractions]}; specials: {"edge:k": opts}
static func _ring(outer: Array, t: float, splits: Dictionary, specials: Dictionary, base: Dictionary) -> void:
	var inner := _inner(outer, t)
	var n := outer.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = outer[i]
		var o1: Vector2 = outer[(i + 1) % n]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[(i + 1) % n]
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
			else:
				first = pc
			prev = pc
	w.add_joint(prev, first, "weld", outer[0].lerp(inner[0], 0.3) * Geom.M)
	w.add_joint(prev, first, "weld", outer[0].lerp(inner[0], 0.7) * Geom.M)


# ---------------------------------------------------------------- the bridge B (bow)

static func _bridge() -> void:
	var S := {"density": 1.5, "barrier": true, "cut_speed": 230.0}
	# edge 1 is the roof (the docking hatch in it), edge 2 the aft wall (the door into the corridor)
	_ring(OUTER_B, T, {1: [0.3, 0.475], 2: [0.3167, 0.6833]}, {
		"0:0": {"art": "window"}, "5:0": {"art": "window"},
		"1:1": {"kind": "hatch", "door": true, "tag": "HATCH-B", "open_dir": Vector2(1.6, 0) * Geom.M},
		"2:1": {"kind": "door", "door": true, "tag": "DR-B", "open_dir": Vector2(0, -1.9) * Geom.M},
		"1:2": {"tag": "B-ROOF"},
	}, S)
	for cl in [[5.0, 3.0, "CL-01"]]:
		var j = w.add_joint(at(cl[0], cl[1] - 0.15, ["hull"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# ---------------------------------------------------------------- the corridor K1 | K2

static func _corridor() -> void:
	var S := {"density": 1.3, "barrier": true, "cut_speed": 230.0}
	# breaks along each wall: the necks (open), and the mid door's bulkhead
	var xs: Array = [KX0]
	for x in PODX:
		xs.append(x - NECK)
		xs.append(x + NECK)
	xs.append(KX1)
	var n := 0
	for sg in [-1.0, 1.0]:
		var side := "T" if sg < 0 else "B"
		var k := 0
		for i in range(0, xs.size(), 2):
			var x0: float = xs[i]
			var x1: float = xs[i + 1]
			var cuts: Array = [x0, x1]
			if x0 < MID and x1 > MID:
				cuts = [x0, MID, x1]
			for j in cuts.size() - 1:
				k += 1
				var tag := "K%s-%d" % [side, k]
				var pc = _tagged(w.add_piece("hull", R(cuts[j], sg * (CY - T), cuts[j + 1], sg * CY), S.merged({"tag": tag})))
				n += 1
	# the plates meet: welded where they touch (across the mid door's line), and to the bridge and life support
	for sg in [-1.0, 1.0]:
		var y: float = sg * (CY - T * 0.5)
		_bolt(at(MID - 0.05, y, ["hull"]), at(MID + 0.05, y, ["hull"]), MID, y, "weld")
		_bolt(at(KX0 + 0.1, y, ["hull"]), at(KX0 - 0.1, y, ["hull"]), KX0, y, "weld")
	# the pressure door half way (the decontamination lock between the clean and the isolation ends)
	var md = _tagged(w.add_piece("door", R(MID - 0.2, -(CY - T), MID + 0.2, CY - T), {"density": 1.2, "barrier": true, "door": true, "tag": "DR-K",
		"open_dir": Vector2(0, -2.1) * Geom.M, "cut_speed": 240.0}))
	_bolt(md, at(MID - 0.3, -(CY - 0.2), ["hull"]), MID, -(CY - T), "weld")
	_bolt(md, at(MID - 0.3, CY - 0.2, ["hull"]), MID, CY - T, "weld")
	for cl in [[MID, CY, "CL-02"]]:
		var j = w.add_joint(at(cl[0] + 0.3, cl[1] - 0.15, ["hull"]), null, "clamp", p(cl[0], cl[1]))
		j.set_meta("tag", cl[2])


# ---------------------------------------------------------------- the life-support block S (aft)

static func _life() -> void:
	var S := {"density": 1.5, "barrier": true, "cut_speed": 230.0}
	# edge 4 is the floor (a hatch in it), edge 5 the forward wall (the door from the corridor)
	_ring(OUTER_S, T, {4: [0.338, 0.4615], 5: [0.39, 0.61], 0: [0.5]}, {
		"4:1": {"kind": "hatch", "door": true, "tag": "HATCH-S", "open_dir": Vector2(1.6, 0) * Geom.M},
		"5:1": {"kind": "door", "door": true, "tag": "DR-S", "open_dir": Vector2(0, 2.0) * Geom.M},
		"0:0": {"tag": "S-ROOF1"}, "0:1": {"tag": "S-ROOF2"},
	}, S)
	var j = w.add_joint(at(66.0, 4.85, ["hull"]), null, "clamp", p(66.0, 5.0))
	j.set_meta("tag", "CL-03")
	# the corridor's walls weld to its forward wall
	for sg in [-1.0, 1.0]:
		var y: float = sg * (CY - T * 0.5)
		_bolt(at(KX1 - 0.1, y, ["hull"]), at(KX1 + 0.1, y, ["hull"]), KX1, y, "weld")


# ---------------------------------------------------------------- aft: thrusters, the maintenance way

static func _aft() -> void:
	var B := {"density": 1.4, "cut_speed": 160.0}
	var mt = w.add_piece("beam", R(77.2, -1.0, 81.6, -0.7), B)
	var mb = w.add_piece("beam", R(77.2, 0.7, 81.6, 1.0), B)
	var me = w.add_piece("beam", R(81.3, -0.7, 81.6, 0.7), B)
	_bolt(mt, at(77.0, -0.85, ["hull"]), 77.2, -0.85, "weld")
	_bolt(mb, at(77.0, 0.85, ["hull"]), 77.2, 0.85, "weld")
	_bolt(me, mt, 81.45, -0.7, "weld")
	_bolt(me, mb, 81.45, 0.7, "weld")
	for sg in [-1.0, 1.0]:
		var e = _equip("ENG-%d" % (1 if sg < 0 else 2), "engine_s", Rect2(77.2, (-3.8 if sg < 0 else 2.2), 2.4, 1.6), {"mass": 0.9, "value": 5000.0, "fragile": 0.3, "name_key": "p_main"})
		_bolt(e, at(77.0, sg * 2.6, ["hull"]), 77.2, sg * 2.6)
		_bolt(e, at(77.0, sg * 3.4, ["hull"]), 77.2, sg * 3.4)
		var nz = _equip("NOZ-%d" % (1 if sg < 0 else 2), "nozzle", Rect2(79.6, sg * 3.0 - 0.95, 2.2, 1.9), {"cls": "metal", "dest": "metal", "mass": 0.3, "cut_speed": 180.0, "name_key": "p_nozzle"},
			_mp([Vector2(79.6, sg * 3.0 - 0.6), Vector2(81.8, sg * 3.0 - 0.95), Vector2(81.8, sg * 3.0 + 0.95), Vector2(79.6, sg * 3.0 + 0.6)]))
		_bolt(nz, e, 79.6, sg * 3.0 - 0.3)
		_bolt(nz, e, 79.6, sg * 3.0 + 0.3)


# ---------------------------------------------------------------- a medical pod

static func _pod(pd: Dictionary) -> void:
	var xc: float = pd.x
	var s: float = pd.sg
	var nm: String = pd.name
	var room: String = pd.room
	var Y := func(v: float) -> float: return v * s
	var V := func(x: float, y: float) -> Vector2: return Vector2(x, y * s)
	var a := xc - PW
	var b := xc + PW
	var y0 := PY0
	var y1 := PY1
	var c := PC
	var ai := a + TP
	var bi := b - TP
	var y0i := y0 + TP
	var y1i := y1 - TP
	var ci := c - TP * 0.4142
	var O := [V.call(a + c, y0), V.call(xc - NECK, y0), V.call(xc + NECK, y0), V.call(b - c, y0), V.call(b, y0 + c), V.call(b, y1 - c),
		V.call(b - c, y1), V.call(a + c, y1), V.call(a, y1 - c), V.call(a, y0 + c)]
	var I := [V.call(ai + ci, y0i), V.call(xc - NECK, y0i), V.call(xc + NECK, y0i), V.call(bi - ci, y0i), V.call(bi, y0i + ci), V.call(bi, y1i - ci),
		V.call(bi - ci, y1i), V.call(ai + ci, y1i), V.call(ai, y1i - ci), V.call(ai, y0i + ci)]
	var S := {"density": 1.1, "barrier": true, "cut_speed": 200.0}
	var nl = w.add_piece("hull", _mp([O[9], O[0], O[1], I[1], I[0], I[9]]), S)
	var nr = w.add_piece("hull", _mp([O[2], O[3], O[4], I[4], I[3], I[2]]), S)
	var rw = w.add_piece("hull", _mp([O[4], O[5], I[5], I[4]]), S)
	var fw = _tagged(w.add_piece("hull", _mp([O[5], O[6], O[7], O[8], I[8], I[7], I[6], I[5]]), S.merged({"tag": "PW-" + nm})))
	var lw = w.add_piece("hull", _mp([O[8], O[9], I[9], I[8]]), S)
	w.add_joint(lw, nl, "weld", O[9].lerp(I[9], 0.5) * Geom.M)
	w.add_joint(nr, rw, "weld", O[4].lerp(I[4], 0.5) * Geom.M)
	w.add_joint(rw, fw, "weld", O[5].lerp(I[5], 0.5) * Geom.M)
	w.add_joint(fw, lw, "weld", O[8].lerp(I[8], 0.5) * Geom.M)
	# the neck: two walls from the corridor out to the pod, the hatch in the corridor's wall
	var nwl = w.add_piece("hull", _mp([V.call(xc - NECK - 0.3, CY), V.call(xc - NECK, CY), V.call(xc - NECK, y0), V.call(xc - NECK - 0.3, y0)]), S)
	var nwr = w.add_piece("hull", _mp([V.call(xc + NECK, CY), V.call(xc + NECK + 0.3, CY), V.call(xc + NECK + 0.3, y0), V.call(xc + NECK, y0)]), S)
	_bolt(nwl, nl, xc - NECK - 0.15, Y.call(y0 + 0.05), "weld")
	_bolt(nwr, nr, xc + NECK + 0.15, Y.call(y0 + 0.05), "weld")
	var kw_l = at(xc - NECK - 0.15, Y.call(CY - 0.2), ["hull"])
	var kw_r = at(xc + NECK + 0.15, Y.call(CY - 0.2), ["hull"])
	_bolt(nwl, kw_l, xc - NECK - 0.15, Y.call(CY), "weld")
	_bolt(nwr, kw_r, xc + NECK + 0.15, Y.call(CY), "weld")
	var hatch = _tagged(w.add_piece("door", R(xc - NECK, Y.call(CY - T), xc + NECK, Y.call(CY)), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-" + nm,
		"open_dir": Vector2(1.45, 0) * Geom.M, "cut_speed": 230.0}))
	_bolt(hatch, kw_l, xc - NECK, Y.call(CY - T * 0.5), "weld")
	_bolt(hatch, kw_r, xc + NECK, Y.call(CY - T * 0.5), "weld")
	# what every pod has: its own battery (and a switch on the panel by the hatch), oxygen, an air loop
	var pb = _equip("PB-" + nm, "battery", Rect2(ai, minf(Y.call(y1i - 1.2), Y.call(y1i)), 0.8, 1.2), {"mass": 0.1, "value": 800.0, "fragile": 0.4, "room": room, "hazard": "battery", "name_key": "p_pod_bat"})
	_bolt(pb, lw, ai, Y.call(y1i - 0.6))
	_bolt(pb, fw, ai + 0.4, Y.call(y1i))
	var o2 = _equip("O2-" + nm, "gastank", Rect2(bi - 0.6, minf(Y.call(y0i + 0.65), Y.call(y0i + 2.95)), 0.6, 2.3), {"mass": 0.08, "value": 600.0, "fragile": 0.3, "room": room, "hazard": "gas_tank", "name_key": "p_o2bottle"})
	_bolt(o2, rw, bi, Y.call(y0i + 1.2))
	_bolt(o2, rw, bi, Y.call(y0i + 2.4))
	var air = _equip("AIR-" + nm, "env", Rect2(xc + 0.4, minf(Y.call(y1i - 0.6), Y.call(y1i)), 1.6, 0.6), {"mass": 0.15, "value": 1500.0, "fragile": 0.5, "room": room, "name_key": "p_pod_air"})
	_bolt(air, fw, xc + 0.7, Y.call(y1i))
	_bolt(air, fw, xc + 1.7, Y.call(y1i))
	var pn = _equip("PNL-" + nm, "panel", Rect2(xc - 2.1, minf(Y.call(y0i), Y.call(y0i + 0.5)), 1.0, 0.5), {"cls": "metal", "dest": "metal", "mass": 0.03, "room": room, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, nl, xc - 1.6, Y.call(y0i))
	var dev_art := "monitor"
	var dev_key := "p_vent"
	var dev_val := 2500.0
	match pd.type:
		"er":
			dev_key = "p_defib"
			dev_val = 3000.0
		"or":
			dev_key = "p_anes"
			dev_val = 4000.0
		"iso":
			dev_key = "p_vent"
			dev_val = 2500.0
		"frz":
			dev_key = "p_frz_ctrl"
			dev_val = 1500.0
			dev_art = "panel"
	var dev = _equip("DEV-" + nm, dev_art, Rect2(xc + 1.1, minf(Y.call(y0i), Y.call(y0i + 0.7)), 1.0, 0.7), {"mass": 0.08, "value": dev_val, "fragile": 0.6, "room": room, "name_key": dev_key})
	_bolt(dev, nr, xc + 1.6, Y.call(y0i))
	# and what it is for
	match pd.type:
		"er":
			var bed = _equip("BED-" + nm, "bed", Rect2(xc - 1.9, minf(Y.call(y1i - 1.4), Y.call(y1i)), 2.2, 1.4), {"mass": 0.3, "value": 5000.0, "fragile": 0.5, "room": room, "name_key": "p_bed"})
			_bolt(bed, fw, xc - 1.6, Y.call(y1i))
			_bolt(bed, fw, xc - 0.1, Y.call(y1i))
		"or":
			var opt = _equip("OPT-" + nm, "op_table", Rect2(xc - 1.9, minf(Y.call(y1i - 2.1), Y.call(y1i)), 2.2, 2.1), {"mass": 0.6, "value": 12000.0, "fragile": 0.55, "room": room, "name_key": "p_op_table"})
			_bolt(opt, fw, xc - 1.2, Y.call(y1i))
			_bolt(opt, fw, xc - 0.4, Y.call(y1i), "lock")
		"iso":
			var bx = _equip("BIO-" + nm, "biobox", Rect2(xc - 2.1, minf(Y.call(y1i - 0.95), Y.call(y1i)), 0.9, 0.95), {"mass": 0.1, "value": 600.0, "fragile": 0.3, "room": room, "hazard": "bio", "dest": "hazard", "name_key": "p_biobox"})
			_bolt(bx, fw, xc - 1.65, Y.call(y1i), "lock")
			var fl = _equip("FLT-" + nm, "filter", Rect2(xc - 0.9, minf(Y.call(y1i - 0.85), Y.call(y1i)), 1.0, 0.85), {"mass": 0.2, "value": 900.0, "fragile": 0.4, "room": room, "hazard": "bio", "dest": "hazard", "name_key": "p_iso_filter"})
			_bolt(fl, fw, xc - 0.4, Y.call(y1i))
		"frz":
			var fz = _equip("FRZ-" + nm, "freezer", Rect2(xc - 2.0, minf(Y.call(y1i - 2.0), Y.call(y1i)), 2.3, 2.0), {"mass": 0.5, "value": 9000.0, "fragile": 0.4, "room": room, "temp": -80.0, "name_key": "p_freezer"})
			_bolt(fz, fw, xc - 1.6, Y.call(y1i))
			_bolt(fz, fw, xc - 0.1, Y.call(y1i))


# ---------------------------------------------------------------- inside the bridge

static func _bridge_inside() -> void:
	var flo := 3.0 - T
	var top := -3.0 + T
	var con = _equip("CON-B", "console", Rect2(2.4, flo - 1.0, 1.4, 1.0), {"mass": 0.4, "value": 4500.0, "fragile": 0.5, "room": "B", "name_key": "p_console"})
	_bolt(con, at(3.0, 2.8, ["hull"]), 2.7, flo)
	_bolt(con, at(3.6, 2.8, ["hull"]), 3.5, flo)
	var r := Rect2(4.0, flo - 1.75, 0.75, 1.75)
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	var seat = _equip("SEAT-B", "seat", r, {"mass": 0.12, "value": 600.0, "fragile": 0.3, "room": "B", "name_key": "p_seat_p"}, sp)
	_bolt(seat, at(4.2, 2.8, ["hull"]), 4.15, flo)
	_bolt(seat, at(4.6, 2.8, ["hull"]), 4.65, flo, "lock")
	var dsp = _equip("DISP-B", "console", Rect2(5.7, flo - 1.1, 1.8, 1.1), {"mass": 0.35, "value": 5000.0, "fragile": 0.5, "room": "B", "name_key": "p_dispatch"})
	_bolt(dsp, at(6.0, 2.8, ["hull"]), 6.0, flo)
	_bolt(dsp, at(7.2, 2.8, ["hull"]), 7.2, flo)
	# the pod overview: twelve tiles, each what the pod last reported (it may be old news)
	var ovw = _equip("OVW", "screen", Rect2(5.8, top, 2.6, 0.9), {"mass": 0.1, "value": 6000.0, "fragile": 0.7, "room": "B", "mandatory": true, "name_key": "p_pod_overview"})
	_bolt(ovw, at(6.2, -2.8, ["hull"]), 6.2, top)
	_bolt(ovw, at(8.0, -2.8, ["hull"]), 8.0, top)
	var lb = _equip("LAMP-B", "lamp", Rect2(3.0, top, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "B", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(lb, at(3.3, -2.8, ["hull"]), 3.28, top)


# ---------------------------------------------------------------- inside the corridor

static func _corridor_inside() -> void:
	var top := -(CY - T)
	var bot := CY - T
	# lamps under the roof, an emergency cabinet each side of the mid door (oxygen masks, an extinguisher)
	for lp in [["LAMP-K1", 18.2, "K1"], ["LAMP-K2", 53.0, "K2"]]:
		var lx: float = lp[1]
		var l = _equip(lp[0], "lamp", Rect2(lx - 0.28, top, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": lp[2], "cut_speed": 260.0, "name_key": "p_lamp"})
		_bolt(l, at(lx, top - 0.2, ["hull"]), lx, top)
	for ec in [["ECAB-1", 27.0, "K1"], ["ECAB-2", 44.3, "K2"]]:
		var ex: float = ec[1]
		var cb = _equip(ec[0], "locker", Rect2(ex - 0.5, bot - 0.7, 1.0, 0.7), {"mass": 0.12, "value": 900.0, "fragile": 0.3, "room": ec[2], "name_key": "p_emerg_cab"})
		_bolt(cb, at(ex - 0.3, bot + 0.2, ["hull"]), ex - 0.3, bot)
		_bolt(cb, at(ex + 0.3, bot + 0.2, ["hull"]), ex + 0.3, bot)


# ---------------------------------------------------------------- inside life support

static func _life_inside() -> void:
	var top := -5.0 + T
	var bot := 5.0 - T
	var roof := func(x: float): return at(x, -4.8, ["hull"])
	var flo := func(x: float): return at(x, 4.8, ["hull"])
	var ar = _equip("AIR-REGEN", "env", Rect2(64.2, top, 3.4, 2.0), {"mass": 1.6, "value": 14000.0, "fragile": 0.4, "room": "S", "mandatory": true, "name_key": "p_air_regen"})
	_bolt(ar, roof.call(64.8), 64.8, top)
	_bolt(ar, roof.call(67.0), 67.0, top)
	for i in 2:
		var x := 68.0 + i * 1.3
		var wt = _equip("WATER-%d" % (i + 1), "water", Rect2(x, top, 1.1, 2.2), {"mass": 0.6, "value": 2500.0, "fragile": 0.35, "room": "S", "name_key": "p_water_tank"})
		_bolt(wt, roof.call(x + 0.3), x + 0.3, top, "lock")
		_bolt(wt, roof.call(x + 0.8), x + 0.8, top, "lock")
	var pw = _equip("PUMP-W", "pump", Rect2(70.8, top, 0.9, 1.0), {"mass": 0.15, "value": 1500.0, "fragile": 0.4, "room": "S", "name_key": "p_pump"})
	_bolt(pw, roof.call(71.2), 71.2, top)
	var og = _equip("O2-GEN", "cabinet", Rect2(72.0, top, 1.4, 1.5), {"mass": 0.5, "value": 8000.0, "fragile": 0.5, "room": "S", "name_key": "p_o2_gen"})
	_bolt(og, roof.call(72.7), 72.7, top)
	var co = _equip("CO2-S", "filter", Rect2(73.7, top, 1.3, 1.3), {"mass": 0.3, "value": 5000.0, "fragile": 0.45, "room": "S", "name_key": "p_co2"})
	_bolt(co, roof.call(74.3), 74.3, top)
	var sw = _equip("PSWB", "swb", Rect2(75.3, top, 1.3, 2.2), {"mass": 0.3, "value": 1200.0, "fragile": 0.4, "room": "S", "name_key": "p_swb"})
	_bolt(sw, roof.call(75.6), 75.6, top)
	_bolt(sw, roof.call(76.3), 76.3, top)
	# the floor: pharmacy, the medical gas bank, the battery, the backup generator, the biological waste tank
	for i in 3:
		var x := 64.2 + i * 0.95
		var ph = _equip("PHARM-%d" % (i + 1), "locker", Rect2(x, bot - 1.8, 0.85, 1.8), {"mass": 0.3, "value": 4000.0, "fragile": 0.45, "room": "S", "hazard": "chem", "dest": "hazard", "name_key": "p_pharmacy"})
		_bolt(ph, flo.call(x + 0.4), x + 0.4, bot, "lock")
	var mg = _equip("MEDGAS", "gastank", Rect2(67.3, bot - 2.1, 1.6, 2.1), {"mass": 0.6, "value": 5000.0, "fragile": 0.3, "room": "S", "hazard": "gas_tank", "name_key": "p_medgas"})
	_bolt(mg, flo.call(67.6), 67.6, bot)
	_bolt(mg, flo.call(68.6), 68.6, bot)
	var bt = _equip("BAT-S", "battery", Rect2(69.3, bot - 1.5, 1.5, 1.5), {"mass": 0.6, "value": 4000.0, "fragile": 0.4, "room": "S", "hazard": "battery", "name_key": "p_battery"})
	_bolt(bt, flo.call(69.6), 69.6, bot)
	_bolt(bt, flo.call(70.2), 70.2, bot)
	var gn = _equip("GEN-B", "gen", Rect2(72.0, bot - 2.0, 2.4, 2.0), {"mass": 1.4, "value": 10000.0, "fragile": 0.35, "room": "S", "hazard": "gen", "name_key": "p_backup_gen"})
	_bolt(gn, flo.call(72.4), 72.4, bot)
	_bolt(gn, flo.call(74.0), 74.0, bot)
	var bto = _equip("BIO-T", "water", Rect2(74.8, bot - 1.9, 1.5, 1.9), {"mass": 0.8, "value": 600.0, "fragile": 0.3, "room": "S", "hazard": "bio", "dest": "hazard", "name_key": "p_bio_tank"})
	_bolt(bto, flo.call(75.1), 75.1, bot, "lock")
	_bolt(bto, flo.call(76.0), 76.0, bot, "lock")
	var ls = _equip("LAMP-S", "lamp", Rect2(70.0, top, 0.56, 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": "S", "cut_speed": 260.0, "name_key": "p_lamp"})
	_bolt(ls, roof.call(70.3), 70.28, top)
	# the outside panel on the roof: battery and generator switches, a bus test point
	var pn = _equip("PNL-S", "panel", Rect2(68.4, -5.6, 3.0, 0.6), {"cls": "metal", "dest": "metal", "mass": 0.1, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(pn, roof.call(68.9), 68.9, -5.0)
	_bolt(pn, roof.call(70.9), 70.9, -5.0)


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _mp(pts))


static func _lines() -> void:
	var top := -(CY - T)
	# main power: the battery and the generator into the switchboard; out to life support, along the corridor to the bridge
	_line("c1", "cable", "power", "BAT-S", Vector2(70.0, 3.2), "PSWB", Vector2(75.9, -2.6), [Vector2(70.0, 2.4), Vector2(75.9, 2.4)])
	_line("c2", "cable", "power", "GEN-B", Vector2(73.2, 2.8), "PSWB", Vector2(76.2, -2.6), [Vector2(73.2, 2.2), Vector2(76.2, 2.2)])
	_line("c3", "cable", "power", "PSWB", Vector2(75.5, -3.0), "AIR-REGEN", Vector2(67.2, -3.0), [Vector2(75.0, -2.4), Vector2(67.2, -2.4)])
	_line("c4", "cable", "power", "PSWB", Vector2(75.5, -3.4), "O2-GEN", Vector2(72.6, -3.6), [Vector2(75.0, -3.0), Vector2(72.6, -3.0)])
	_line("c5", "cable", "power", "PSWB", Vector2(75.5, -3.8), "CO2-S", Vector2(74.3, -3.6))
	_line("c6", "cable", "power", "PSWB", Vector2(75.6, -4.4), "LAMP-S", Vector2(70.3, top - 3.4), [Vector2(75.0, -4.4), Vector2(70.3, -4.4)])
	_line("c7", "cable", "power", "PSWB", Vector2(75.8, -2.9), "LAMP-K2", Vector2(53.0, top + 0.08), [Vector2(75.8, -1.9), Vector2(63.9, -0.6), Vector2(62.8, top + 0.12), Vector2(53.0, top + 0.12)])
	_line("c8", "cable", "power", "LAMP-K2", Vector2(52.9, top + 0.08), "LAMP-K1", Vector2(18.3, top + 0.08), [Vector2(36.4, top + 0.12), Vector2(34.7, top + 0.12)])
	_line("c9", "cable", "power", "LAMP-K1", Vector2(18.1, top + 0.08), "OVW", Vector2(7.0, -2.0), [Vector2(10.0, top + 0.12), Vector2(9.0, -0.5), Vector2(7.0, -0.5)])
	_line("c10", "cable", "power", "OVW", Vector2(6.4, -2.0), "CON-B", Vector2(3.1, 1.8), [Vector2(4.8, -1.0), Vector2(3.1, 1.0)])
	_line("c11", "cable", "power", "CON-B", Vector2(3.4, 1.8), "DISP-B", Vector2(6.4, 1.7), [Vector2(3.4, 1.3), Vector2(6.4, 1.3)])
	_line("c12", "cable", "power", "OVW", Vector2(6.0, -2.0), "LAMP-B", Vector2(3.28, -2.5), [Vector2(5.0, -2.2)])
	_line("c13", "cable", "power", "PSWB", Vector2(75.6, -2.7), "PUMP-W", Vector2(71.25, -3.8), [Vector2(75.0, -2.2), Vector2(71.25, -2.9)])
	# water: the two tanks into the pump
	_line("w1", "pipe", "water", "WATER-1", Vector2(68.55, -2.6), "PUMP-W", Vector2(71.0, -3.7), [Vector2(68.55, -2.2), Vector2(71.0, -2.2)])
	_line("w2", "pipe", "water", "WATER-2", Vector2(69.85, -2.6), "PUMP-W", Vector2(71.4, -3.7), [Vector2(69.85, -2.3), Vector2(71.4, -2.3)])
	# each pod's own little network: its battery to its air loop, its device, and what the pod is for
	for pd in pods:
		var nm: String = pd.name
		var s: float = pd.sg
		var xc: float = pd.x
		var yb := (PY1 - TP - 0.6) * s
		var ydev := (PY0 + TP + 0.35) * s
		_line("pc-" + nm + "a", "cable", "nav", "PB-" + nm, Vector2(xc - 2.85, yb), "AIR-" + nm, Vector2(xc + 0.9, (PY1 - TP - 0.3) * s), [Vector2(xc - 2.85, (PY1 - TP - 1.5) * s), Vector2(xc + 0.9, (PY1 - TP - 1.5) * s)])
		_line("pc-" + nm + "b", "cable", "nav", "PB-" + nm, Vector2(xc - 2.65, yb), "DEV-" + nm, Vector2(xc + 1.6, ydev), [Vector2(xc - 2.65, (PY0 + TP + 1.0) * s), Vector2(xc + 1.6, (PY0 + TP + 1.0) * s)])
		var main := ""
		match pd.type:
			"er":
				main = "BED-" + nm
			"or":
				main = "OPT-" + nm
			"frz":
				main = "FRZ-" + nm
		if main != "":
			_line("pc-" + nm + "c", "cable", "nav", "PB-" + nm, Vector2(xc - 2.45, yb), main, Vector2(xc - 1.4, (PY1 - TP - 0.5) * s))


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	# from outside: a gas port on every pressurised room
	_ctrl("G-B", "port", by_tag["B-ROOF"], Vector2(7.6, -3.2), {"medium": "gas", "target": "B"})
	_ctrl("G-S", "port", by_tag["S-ROOF2"], Vector2(73.5, -5.2), {"medium": "gas", "target": "S"})
	_ctrl("G-K1", "port", at(26.9, -1.3, ["hull"]), Vector2(26.9, -1.55), {"medium": "gas", "target": "K1"})
	_ctrl("G-K2", "port", at(44.2, -1.3, ["hull"]), Vector2(44.2, -1.55), {"medium": "gas", "target": "K2"})
	var pn = by_tag["PNL-S"]
	_ctrl("K-S", "switch", pn, Vector2(68.9, -5.3), {"target": "K-S", "state": true})
	_ctrl("K-GB", "switch", pn, Vector2(69.6, -5.3), {"target": "K-GB", "state": true})
	_ctrl("E-S01", "test", pn, Vector2(70.4, -5.3), {"medium": "volt", "target": "bus"})
	_ctrl("GB-LOCAL", "stop", by_tag["GEN-B"], Vector2(73.2, 3.2), {"target": "G", "hidden_room": "S"})
	_ctrl("MGP", "port", by_tag["MEDGAS"], Vector2(68.1, 3.1), {"medium": "gas", "target": "MGB", "hidden_room": "S"})
	_ctrl("WP-1", "port", by_tag["WATER-1"], Vector2(68.55, -3.2), {"medium": "coolant", "target": "h2o1", "hidden_room": "S"})
	_ctrl("WP-2", "port", by_tag["WATER-2"], Vector2(69.85, -3.2), {"medium": "coolant", "target": "h2o2", "hidden_room": "S"})
	_ctrl("SL-BT", "seal", by_tag["BIO-T"], Vector2(75.5, 3.6), {"target": "BIO-T", "state": false, "hidden_room": "S"})
	for d in [["HATCH-B", ""], ["DR-B", "B"], ["DR-K", "K1"], ["DR-S", "K2"], ["HATCH-S", ""]]:
		var dp = by_tag[d[0]]
		_ctrl(d[0], "door", dp, Geom.centroid(dp.poly) / Geom.M, {"target": d[0], "state": false, "hidden_room": d[1]})
	for pd in pods:
		var nm: String = pd.name
		var s: float = pd.sg
		var xc: float = pd.x
		var k := "K1" if xc < MID else "K2"
		# outside, on the pod's far wall: its gas port
		_ctrl("G-" + nm, "port", by_tag["PW-" + nm], Vector2(xc + 1.2, (PY1 + 0.15) * s), {"medium": "gas", "target": nm})
		# in the corridor by the hatch: the hatch, a pressure test point on the pod (and on an isolation pod, an air sampler)
		var hp = by_tag["DR-" + nm]
		_ctrl("DR-" + nm, "door", hp, Vector2(xc, (CY - T * 0.5) * s), {"target": "DR-" + nm, "state": false, "hidden_room": k})
		var kw = at(xc + NECK + 0.6, (CY - 0.2) * s, ["hull"])
		_ctrl("P-" + nm, "port", kw, Vector2(xc + NECK + 0.5, (CY - T - 0.12) * s), {"medium": "gas", "target": nm, "hidden_room": k})
		if pd.type == "iso":
			_ctrl("S-" + nm, "test", kw, Vector2(xc + NECK + 1.1, (CY - T - 0.12) * s), {"medium": "bio", "target": nm, "hidden_room": k})
		# inside, on the panel by the hatch: the pod battery's switch and its test point
		var py := (PY0 + TP + 0.25) * s
		_ctrl("K-" + nm, "switch", by_tag["PNL-" + nm], Vector2(xc - 1.85, py), {"target": "K-" + nm, "state": true, "hidden_room": nm})
		_ctrl("E-" + nm, "test", by_tag["PNL-" + nm], Vector2(xc - 1.35, py), {"medium": "volt", "target": "PB-" + nm, "hidden_room": nm})
		_ctrl("O2P-" + nm, "port", by_tag["O2-" + nm], Vector2(xc + PW - TP - 0.3, (PY0 + TP + 0.9) * s), {"medium": "gas", "target": "O2-" + nm, "hidden_room": nm})
		match pd.type:
			"iso":
				_ctrl("SB-" + nm, "seal", by_tag["BIO-" + nm], Vector2(xc - 1.65, (PY1 - TP - 0.5) * s), {"target": "BIO-" + nm, "state": false, "hidden_room": nm})
				_ctrl("SF-" + nm, "seal", by_tag["FLT-" + nm], Vector2(xc - 0.4, (PY1 - TP - 0.45) * s), {"target": "FLT-" + nm, "state": false, "hidden_room": nm})
			"frz":
				_ctrl("FP-" + nm, "port", by_tag["FRZ-" + nm], Vector2(xc - 0.3, (PY1 - TP - 1.7) * s), {"medium": "coolant", "target": "frz-" + nm, "hidden_room": nm})


static func _rooms() -> void:
	w.add_room("B", _mp(_inner(OUTER_B, T)))
	w.add_room("S", _mp(_inner(OUTER_S, T)))
	var ki := CY - T
	w.add_room("K1", _mp([Vector2(KX0, -ki), Vector2(MID - 0.2, -ki), Vector2(MID - 0.2, ki), Vector2(KX0, ki)]))
	w.add_room("K2", _mp([Vector2(MID + 0.2, -ki), Vector2(KX1, -ki), Vector2(KX1, ki), Vector2(MID + 0.2, ki)]))
	for pd in pods:
		var xc: float = pd.x
		var s: float = pd.sg
		var ai := xc - PW + TP
		var bi := xc + PW - TP
		var y0i := PY0 + TP
		var y1i := PY1 - TP
		var ci := PC - TP * 0.4142
		var pts := [Vector2(xc - NECK, CY), Vector2(xc - NECK, y0i), Vector2(ai + ci, y0i), Vector2(ai, y0i + ci), Vector2(ai, y1i - ci), Vector2(ai + ci, y1i),
			Vector2(bi - ci, y1i), Vector2(bi, y1i - ci), Vector2(bi, y0i + ci), Vector2(bi - ci, y0i), Vector2(xc + NECK, y0i), Vector2(xc + NECK, CY)]
		var out: Array = []
		for q in pts:
			out.append(Vector2(q.x, q.y * s))
		w.add_room(pd.name, _mp(out))


static func meta() -> Dictionary:
	var rooms := {"B": 101.0, "K1": 101.0, "K2": 101.0, "S": 101.0}
	var vessels := {"MGB": {"V": 0.06, "kpa": 1800.0, "piece": "MEDGAS", "burst": 200.0}}
	var isolated: Array = []
	var fl_vol := {
		"h2o1": {"fluid": "coolant", "amount": 0.2, "piece": "WATER-1", "content": 1.0, "leak": 0.1, "port": "WP-1", "pump": [0.12, 0.008]},
		"h2o2": {"fluid": "coolant", "amount": 0.2, "piece": "WATER-2", "content": 1.0, "leak": 0.1, "port": "WP-2", "pump": [0.12, 0.008]},
		"h2o_line": {"fluid": "coolant", "amount": 0.012, "nets": ["water"], "leak": 0.05, "leak_min": 0.004},
	}
	var cfg := {"G-B": {"rate": 9.0}, "G-S": {"rate": 9.0}, "G-K1": {"rate": 9.0}, "G-K2": {"rate": 9.0}, "MGP": {"rate": 0.3}, "GB-LOCAL": {"target": "GEN-B"}}
	var labels := {"MEDGAS": "MED GAS", "WATER-1": "H₂O", "WATER-2": "H₂O", "BIO-T": "BIO", "GEN-B": "BACKUP GEN"}
	var room_names := {"B": "room_mB", "K1": "room_mK1", "K2": "room_mK2", "S": "room_mS"}
	var bio_rooms := {}
	var bio_items := {"BIO-T": {"seal": "SL-BT"}}
	var knock: Array = ["CON-B", "DISP-B", "OVW", "AIR-REGEN", "O2-GEN"]
	var drift: Array = ["PHARM-1", "PHARM-2", "WATER-1"]
	var plates: Array = []
	for side in ["U", "L"]:
		for i in 6:
			var nm: String = "%s%d" % [side, i + 1]
			var ty: String = TYPES[side][i]
			rooms[nm] = 92.0 if ty == "iso" else 101.0
			vessels["O2-" + nm] = {"V": 0.012, "kpa": 1500.0, "piece": "O2-" + nm, "burst": 200.0}
			isolated.append({"piece": "PB-" + nm, "volts": 48.0, "charge": 1.0, "switch": "K-" + nm})
			cfg["G-" + nm] = {"rate": 6.0}
			cfg["P-" + nm] = {"rate": 4.0}
			cfg["O2P-" + nm] = {"rate": 0.25}
			labels["O2-" + nm] = "O₂"
			room_names[nm] = "room_m" + ty
			plates.append("PW-" + nm)
			knock.append("DEV-" + nm)
			if ty == "iso":
				bio_rooms[nm] = 1.0
				bio_items["BIO-" + nm] = {"seal": "SB-" + nm}
				bio_items["FLT-" + nm] = {"seal": "SF-" + nm}
			if ty == "frz":
				fl_vol["frz-" + nm] = {"fluid": "coolant", "amount": 0.05, "piece": "FRZ-" + nm, "content": 0.4, "leak": 0.08, "port": "FP-" + nm, "pump": [0.12, 0.008], "hazard": 0.02}
	return {
		"id": "med47",
		"name": "MED-47 SILENCE",
		"title": ["MED-47「缄默」医疗船 · 82 m", "MED-47 SILENCE · HOSPITAL SHIP · 82 m"],
		"contract": "MED-47",
		"length": 82.0,
		"value": {"total": 258000.0, "metal": 22000.0},
		"clamps": [[5.0, 3.0], [MID, CY], [66.0, 5.0]],
		"room_names": room_names,
		"bio": {"rooms": bio_rooms, "items": bio_items},
		"gas": {"rooms": rooms, "vessels": vessels, "valves": [], "value": 1200.0},
		"power": {
			"bus": "PSWB",
			"sources": [
				{"piece": "GEN-B", "kind": "gen", "volts": 230.0, "cable": "c2", "switch": "K-GB", "running": true, "local": "GB-LOCAL"},
				{"piece": "BAT-S", "kind": "battery", "volts": 230.0, "local_volts": 48.0, "cable": "c1", "switch": "K-S", "charge": 0.85, "drain": 0.0004},
			],
			"isolated": isolated,
			"lamps": {"B": "LAMP-B", "K1": "LAMP-K1", "K2": "LAMP-K2", "S": "LAMP-S"},
		},
		"fluids": {"volumes": fl_vol, "joins": [], "value": {"coolant": 500.0}},
		"ctrls_cfg": cfg,
		"labels": labels,
		"hints": {},
		"market": {
			"class": "MED", "name": ["缄默级医疗船", "SILENCE-CLASS HOSPITAL SHIP"], "time": 50.0,
			"rooms": {"K1": [0.25, 0.0, 101.0], "K2": [0.25, 0.0, 101.0], "B": [0.2, 40.0, 101.0], "S": [0.2, 40.0, 101.0]},
			"charge": {"BAT-S": [0.15, 1.0]},
			"fluids": {"h2o1": [0.05, 0.25], "h2o2": [0.05, 0.25]}, "fill": {"h2o_line": "h2o1"},
			"knockable": knock,
			"drift": drift,
			"section_x": MID,
			"slots": {
				"hidden_damage": {"plates": plates},
				"bio_breach": {"rooms": ["U3", "U6", "L3"]},
			},
			"mechanisms": true,
		},
		"procedures": {
			"OVW": [
				{"do": "hose", "ctrl": "G-B"},
				{"do": "wait", "until": {"P": ["B", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HATCH-B"},
				{"do": "wait", "until": {"open": ["B"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-GB"},
				{"do": "operate", "ctrl": "K-S"},
				{"do": "measure", "ctrl": "E-S01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "OVW"},
				{"do": "deliver", "piece": "OVW", "zone": "equip"},
			],
			"AIR-REGEN": [
				{"do": "hose", "ctrl": "G-S"},
				{"do": "wait", "until": {"P": ["S", "<", 5.0]}, "max": 120.0},
				{"do": "operate", "ctrl": "HATCH-S"},
				{"do": "wait", "until": {"open": ["S"]}, "max": 5.0},
				{"do": "operate", "ctrl": "K-GB"},
				{"do": "operate", "ctrl": "K-S"},
				{"do": "measure", "ctrl": "E-S01", "expect": ["<", 1.0]},
				{"do": "free", "piece": "AIR-REGEN"},
				{"do": "deliver", "piece": "AIR-REGEN", "zone": "equip"},
			],
		},
	}
