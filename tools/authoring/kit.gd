class_name AuthorKit
# What every ship's authoring script builds with (fleet expansion 2026-10-19: some
# thirty ships to come, each with the same rings, plates, equipment, fixings,
# lamps, lines and controls). Metres in, pixels out; y down. A script calls
# begin(world) first; by_tag then holds every tagged piece it has made.
#   const K = preload("res://tools/authoring/kit.gd")
#   K.begin(world)
#   var pc = K.equip("PUMP", "pump", K.rect(10, -2, 11.4, -0.8), {"mass": 0.4, "value": 2000.0, "room": "A"})
#   K.bolt(pc, K.at(10.7, -0.6, ["hull"]), 10.7, -0.8)

const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]

static var w
static var by_tag := {}
static var who := "SHIP"          # names the script in its warnings


static func begin(world, name: String = "SHIP") -> void:
	w = world
	by_tag = {}
	who = name


# ---------------------------------------------------------------- geometry

static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(minf(x0, x1), minf(y0, y1), maxf(x0, x1), maxf(y0, y1)))


static func mp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


static func rect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(minf(x0, x1), minf(y0, y1), absf(x1 - x0), absf(y1 - y0))


# an outline moved t inwards (each edge offset, the corners where they meet)
static func inner(outer: Array, t: float) -> Array:
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


# ---------------------------------------------------------------- pieces and fixings

static func tagged(pc):
	if pc != null and pc.tag != "":
		by_tag[pc.tag] = pc
	return pc


static func bolt(a, b, x: float, y: float, type: String = "bolt", tag: String = "") -> void:
	if a == null or b == null:
		push_warning("%s joint missing a piece at %s,%s" % [who, x, y])
		return
	var j = w.add_joint(a, b, type, p(x, y))
	if tag != "":
		j.set_meta("tag", tag)


static func at(x: float, y: float, kinds: Array = []):
	return w.piece_at(p(x, y), kinds)


# a piece of equipment (or a fixture, cls "metal"): its art fills r unless a poly is given
static func equip(tag: String, art: String, r: Rect2, opts: Dictionary, poly = null):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var o := {"art": art, "art_xf": Transform2D(0.0, rr.position), "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	return tagged(w.add_piece(kind, poly if poly != null else Geom.rect_poly(rr), o))


# structure: a plate, a bulkhead, a deck, a rib... (art, if any, fills its bounds)
static func plate(tag: String, r: PackedVector2Array, opts: Dictionary, kind: String = "hull"):
	var o := {"density": 1.4, "barrier": true, "cut_speed": 220.0, "tag": tag}
	o.merge(opts, true)
	if o.get("art", "") != "" and o.art != "window" and not o.has("art_size"):
		var bb := Geom.bbox(r)
		o.art_xf = Transform2D(0.0, bb.position)
		o.art_size = bb.size
	return tagged(w.add_piece(kind, r, o))


# a ring of plates round an outline, t thick, each welded to the next.
# splits {edge: [fractions]} cut an edge into plates; specials {"edge:k": opts}
# change one (kind "hatch"/"door", a tag, art...); base is every plate's opts.
# Plates are tagged by the specials, or prefix + "edge-k" when a prefix is given.
static func ring(outer: Array, t: float, splits: Dictionary, specials: Dictionary, base: Dictionary, prefix: String = "") -> void:
	var inn := inner(outer, t)
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
			if prefix != "":
				opts.tag = "%s%d-%d" % [prefix, i, k]
			var kind := "hull"
			var sp: Dictionary = specials.get("%d:%d" % [i, k], {})
			if not sp.is_empty():
				kind = sp.get("kind", "hull")
				opts.merge(sp, true)
				opts.erase("kind")
				if kind != "hull":
					opts.erase("name_key")
			var q := mp([a, b, c, d])
			if opts.get("art", "") != "" and opts.art != "window":
				var bb := Geom.bbox(q)
				opts.art_xf = Transform2D(0.0, bb.position)
				opts.art_size = bb.size
			var pc = tagged(w.add_piece(kind, q, opts))
			if prev != null:
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.3) * Geom.M)
				w.add_joint(prev, pc, "weld", a.lerp(d, 0.7) * Geom.M)
			if first == null:
				first = pc
			prev = pc
	if prev != null:
		w.add_joint(prev, first, "weld", outer[0].lerp(inn[0], 0.3) * Geom.M)
		w.add_joint(prev, first, "weld", outer[0].lerp(inn[0], 0.7) * Geom.M)


# a couch: the piece is its outline (r: x, the top, width, height in m)
static func seat(tag: String, r: Rect2, opts: Dictionary):
	var sp := PackedVector2Array()
	for q in SEAT_SHAPE:
		sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
	var o := {"mass": 0.15, "value": 2000.0, "fragile": 0.3, "name_key": "p_seat"}
	o.merge(opts, true)
	return equip(tag, "seat", r, o, sp)


# a ceiling lamp centred on x under y (its room's light), bolted to on
static func lamp(tag: String, x: float, y: float, room: String, on) -> void:
	var l = equip(tag, "lamp", rect(x - 0.28, y, x + 0.28, y + 0.16), {"cls": "metal", "dest": "metal", "mass": 0.04, "room": room, "cut_speed": 260.0, "name_key": "p_lamp"})
	bolt(l, on, x, y)


# a clamp to the berth at (x, y), on the hull piece found at (x, probe_y)
static func clamp(n: int, x: float, y: float, probe_y: float) -> void:
	var j = w.add_joint(at(x, probe_y, ["hull"]), null, "clamp", p(x, y))
	if j == null:
		push_warning("%s clamp CL-%02d finds no hull at %s,%s" % [who, n, x, probe_y])
		return
	j.set_meta("tag", "CL-%02d" % n)


# ---------------------------------------------------------------- lines and controls

static func line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	if not by_tag.has(a) or not by_tag.has(b):
		push_warning("%s line %s: no %s" % [who, id, a if not by_tag.has(a) else b])
		return
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, mp(pts))


static func ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	if piece == null:
		push_warning("%s control %s has no piece" % [who, id])
		return
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


# a door or hatch's control at its middle (hidden in room until that is open, "" outside)
static func door(tag: String, room: String = "") -> void:
	var dp = by_tag[tag]
	ctrl(tag, "door", dp, Geom.centroid(dp.poly) / Geom.M, {"target": tag, "state": false, "hidden_room": room})
