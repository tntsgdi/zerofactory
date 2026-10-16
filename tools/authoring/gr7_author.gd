class_name GR7Author
# Authoring script for GR-7 "Grey Heron", the 42 m freighter. It is not part
# of the game: tools/ship_export.gd runs it and writes ships/gr7.json, which is
# what the game builds from. Units are metres (converted with Geom.M); x runs
# bow (0) to stern (42), y is down. meta() holds everything that is not
# geometry: the systems, the contract and the factory drawing.
#
# Sections: A cockpit 0–5, B quarters 5–10, C cargo hold 10–27, D power room
# 27–33 upper, E maintenance bay 27–33 lower, F propulsion 33–42 (open truss).

const T := 0.45   # hull plate thickness
const OUTER := [
	Vector2(0.2, 0.5), Vector2(0.9, -1.6), Vector2(2.4, -3.3), Vector2(4.6, -4.0),
	Vector2(33.0, -4.0), Vector2(33.0, 4.0), Vector2(4.6, 4.0), Vector2(2.4, 3.4), Vector2(0.8, 2.2),
]
# where each outer edge is cut into plates (fractions along the edge come from these x / y stations)
const TOP_STATIONS := [4.6, 7.8, 10.0, 12.7, 15.4, 18.4, 21.4, 24.2, 27.0, 30.0, 33.0]
const BOT_STATIONS := [33.0, 30.0, 27.0, 24.2, 21.0, 17.8, 14.6, 11.4, 8.0, 4.6]
const STERN_STATIONS := [-4.0, -1.4, 0.6, 4.0]

static var inner: Array = []
const SEAT_SHAPE := [Vector2(0.02, 1.0), Vector2(0.98, 1.0), Vector2(0.98, 0.92), Vector2(0.6, 0.92), Vector2(0.6, 0.75), Vector2(0.78, 0.72),
	Vector2(1.0, 0.18), Vector2(1.0, 0.02), Vector2(0.86, 0.0), Vector2(0.82, 0.15), Vector2(0.6, 0.63), Vector2(0.02, 0.64),
	Vector2(0.02, 0.75), Vector2(0.38, 0.75), Vector2(0.38, 0.92), Vector2(0.02, 0.92)]
static var w
static var by_tag := {}


static func p(x: float, y: float) -> Vector2:
	return Vector2(x * Geom.M, y * Geom.M)


static func R(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return Geom.rect_poly(Geom.mrect(x0, y0, x1, y1))


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


# y of the inner bottom surface at x (the floor a thing stands on), metres
static func floor_at(x: float) -> float:
	if x >= 4.7 and x <= 32.55:
		return 2.95
	var best := 99.0
	var n := inner.size()
	for i in n:
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[(i + 1) % n]
		if a.y < 0.0 and b.y < 0.0:
			continue
		if (x - a.x) * (x - b.x) <= 0.0 and absf(b.x - a.x) > 1e-4:
			var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
			if y > 0.0:
				best = minf(best, y)
	return best


static func ceil_at(x: float) -> float:
	var best := -99.0
	var n := inner.size()
	for i in n:
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[(i + 1) % n]
		if a.y > 0.0 or b.y > 0.0:
			continue
		if (x - a.x) * (x - b.x) <= 0.0 and absf(b.x - a.x) > 1e-4:
			best = maxf(best, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best


static func sit(x0: float, x1: float, h: float, fl: float = INF) -> Rect2:
	var y1 := fl if fl != INF else minf(floor_at(x0), floor_at(x1))
	return Rect2(x0, y1 - h, x1 - x0, h)


static func build(world) -> void:
	w = world
	by_tag = {}
	inner = _inner_outline()
	_hull()
	_interior()
	_equipment()
	_propulsion()
	_lines()
	_controls()
	_rooms()


# rooms only (a saved contract brings its own pieces)
static func rooms_only(world) -> void:
	w = world
	inner = _inner_outline()
	_rooms()


static func _tagged(pc) -> void:
	if pc.tag != "":
		by_tag[pc.tag] = pc


static func _hull() -> void:
	var n := OUTER.size()
	var prev = null
	var first = null
	for i in n:
		var o0: Vector2 = OUTER[i]
		var o1: Vector2 = OUTER[(i + 1) % n]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[(i + 1) % n]
		var stations: Array = [0.0, 1.0]
		if i == 3:
			stations = []
			for x in TOP_STATIONS:
				stations.append((x - o0.x) / (o1.x - o0.x))
		elif i == 5:
			stations = []
			for x in BOT_STATIONS:
				stations.append((x - o0.x) / (o1.x - o0.x))
		elif i == 4:
			stations = []
			for y in STERN_STATIONS:
				stations.append((y - o0.y) / (o1.y - o0.y))
		for k in stations.size() - 1:
			var s0: float = stations[k]
			var s1: float = stations[k + 1]
			var a := o0.lerp(o1, s0)
			var b := o0.lerp(o1, s1)
			var c := i0.lerp(i1, s1)
			var d := i0.lerp(i1, s0)
			var poly := PackedVector2Array([a * Geom.M, b * Geom.M, c * Geom.M, d * Geom.M])
			var opts := {"density": 1.6, "barrier": true, "cut_speed": 230.0}
			var kind := "hull"
			if i == 1:
				opts["art"] = "window"
			if i == 3 and (is_equal_approx(a.x, 15.4) or is_equal_approx(a.x, 18.4)):
				kind = "hatch"
				opts["door"] = true
				opts["tag"] = "HATCH-1" if is_equal_approx(a.x, 15.4) else "HATCH-2"
				opts["open_dir"] = Vector2(0, -0.62) * Geom.M if is_equal_approx(a.x, 15.4) else Vector2(0, -0.62) * Geom.M
			var pc = w.add_piece(kind, poly, opts)
			_tagged(pc)
			if prev != null:
				_weld_edge(prev, pc, a, d)
			else:
				first = pc
			prev = pc
	_weld_edge(prev, first, OUTER[0], inner[0])
	# the breach in the stern wall, low down: E has been open to space since the accident
	var breach := PackedVector2Array()
	var pts := [Vector2(32.3, 1.02), Vector2(32.75, 0.94), Vector2(33.3, 1.08), Vector2(33.35, 1.94), Vector2(32.85, 1.86), Vector2(32.6, 2.02), Vector2(32.3, 1.9)]
	for q in pts:
		breach.append(q * Geom.M)
	w.cut_region(breach, false)
	# four dock clamps grip the bottom plating
	for i in 4:
		var x: float = [7.0, 15.8, 23.4, 28.6][i]
		var j = w.add_joint(hull_at(x, 3.8), null, "clamp", p(x, 3.86))
		j.set_meta("tag", "CL-0%d" % (i + 1))


static func _weld_edge(pa, pb, outer_pt: Vector2, inner_pt: Vector2) -> void:
	w.add_joint(pa, pb, "weld", outer_pt.lerp(inner_pt, 0.3) * Geom.M)
	w.add_joint(pa, pb, "weld", outer_pt.lerp(inner_pt, 0.7) * Geom.M)


static func hull_at(x: float, y: float):
	return w.piece_at(p(x, y), ["hull", "hatch"])


static func _bolt(a, b, x: float, y: float, type: String = "bolt") -> void:
	if a == null or b == null:
		push_warning("GR7 bolt missing piece at %s,%s" % [x, y])
		return
	w.add_joint(a, b, type, p(x, y))


static func _interior() -> void:
	var S := {"density": 1.2, "barrier": true, "cut_speed": 260.0}
	# keel: the floor every room stands on, four heavy segments
	var keel_x := [4.7, 10.0, 18.6, 27.0, 32.55]
	var keels: Array = []
	for i in 4:
		var k = w.add_piece("keel", R(keel_x[i], 2.95, keel_x[i + 1], 3.55), {"density": 1.1, "barrier": true, "cut_speed": 120.0, "tag": "K%d" % (i + 1)})
		_tagged(k)
		keels.append(k)
		if i > 0:
			_bolt(keels[i - 1], k, keel_x[i], 3.1, "weld")
			_bolt(keels[i - 1], k, keel_x[i], 3.4, "weld")
		var x: float = keel_x[i] + 0.6
		while x < keel_x[i + 1] - 0.3:
			_bolt(k, hull_at(x, 3.75), x, 3.56)
			x += 2.1
	# bulkheads with doors (doors first, so the wall draws over a door slid open into it)
	_bulkhead(5.0, [[-3.55, 0.75], [0.75, 2.95, "DR-AB", true]], "A", "B")
	_bulkhead(10.0, [[-3.55, 0.75], [0.75, 2.95, "DR-BC", false]], "B", "C")
	_bulkhead(27.0, [[-3.55, -2.6], [-2.6, -0.6, "DR-CD", false], [-0.6, 0.7], [0.7, 2.7, "DR-CE", false], [2.7, 2.95]], "C", "DE")
	# deck between D (above) and E (below), with a hatch
	var hatch = w.add_piece("door", R(29.2, -0.13, 30.4, 0.13), {"density": 1.0, "barrier": true, "door": true, "tag": "DR-DE", "open_dir": Vector2(1.15, 0) * Geom.M, "cut_speed": 240.0})
	_tagged(hatch)
	var dk1 = w.add_piece("deck", R(27.15, -0.15, 29.2, 0.15), S)
	var dk2 = w.add_piece("deck", R(30.4, -0.15, 32.55, 0.15), S)
	dk1.tag = "DK-1"
	dk2.tag = "DK-2"
	_tagged(dk1)
	_tagged(dk2)
	_bolt(dk1, w.piece_at(p(27.05, 0.0), ["bulkhead"]), 27.15, 0.0, "weld")
	_bolt(dk2, hull_at(32.8, 0.3), 32.55, 0.0, "weld")
	_bolt(hatch, dk1, 29.2, 0.0, "weld")
	_bolt(hatch, dk2, 30.4, 0.0, "weld")
	# the wall pieces between the C-D and C-E doors are framed into the wall above and below
	var mid = w.piece_at(p(27.0, 0.0), ["bulkhead"])
	_bolt(mid, w.piece_at(p(27.0, -3.0), ["bulkhead"]), 27.13, -0.6, "weld")
	_bolt(mid, w.piece_at(p(27.0, 2.8), ["bulkhead"]), 27.13, 0.7, "weld")
	_bolt(by_tag["K4"], hull_at(32.8, 3.2), 32.55, 3.25, "weld")
	# cargo hold: crane rail under the roof, three ribs from rail to keel
	var rail = w.add_piece("rail", R(10.15, -3.55, 26.85, -3.25), {"density": 0.9, "cut_speed": 200.0, "tag": "RAIL-C", "room": "C"})
	_tagged(rail)
	_bolt(rail, w.piece_at(p(10.0, -3.0), ["bulkhead"]), 10.15, -3.4)
	_bolt(rail, w.piece_at(p(27.0, -3.0), ["bulkhead"]), 26.85, -3.4)
	for x in [11.4, 16.9, 22.4, 25.8]:
		_bolt(rail, hull_at(x, -3.8), x, -3.55)
	for x in [14.55, 18.85, 23.2]:
		var r = w.add_piece("rib", R(x - 0.1, -3.25, x + 0.1, 2.95), {"density": 1.2, "cut_speed": 240.0, "room": "C"})
		_bolt(r, rail, x, -3.25)
		_bolt(r, keels[1] if x < 18.6 else keels[2], x, 2.95)


static func _bulkhead(x: float, spans: Array, left: String, right: String) -> void:
	var made: Array = []
	for s in spans:
		var y0: float = s[0]
		var y1: float = s[1]
		if s.size() > 2:
			var d = w.add_piece("door", R(x - 0.12, y0, x + 0.12, y1), {"density": 1.0, "barrier": true, "door": true, "tag": s[2], "open_dir": Vector2(0, -(y1 - y0) + 0.08) * Geom.M, "cut_speed": 240.0})
			d.door_open = s[3]
			d.open_t = 1.0 if s[3] else 0.0
			_tagged(d)
			made.append(d)
	var walls: Array = []
	for s in spans:
		if s.size() > 2:
			continue
		var bh = w.add_piece("bulkhead", R(x - 0.15, s[0], x + 0.15, s[1]), {"density": 1.2, "barrier": true, "cut_speed": 260.0})
		walls.append(bh)
		if is_equal_approx(s[0], -3.55):
			_bolt(bh, hull_at(x, -3.8), x, -3.55, "weld")
		if is_equal_approx(s[1], 2.95):
			_bolt(bh, w.piece_at(p(x, 3.2), ["keel"]), x, 2.95, "weld")
	for d in made:
		var dy: float = Geom.bbox(d.poly).position.y / Geom.M
		var above = w.piece_at(p(x, dy - 0.1), ["bulkhead"])
		if above != null:
			_bolt(d, above, x, dy, "weld")


static func _equip(tag: String, art: String, r: Rect2, opts: Dictionary, rot: float = 0.0, pivot: Vector2 = Vector2.INF):
	var rr := Rect2(r.position * Geom.M, r.size * Geom.M)
	var poly := Geom.rect_poly(rr)
	var xf := Transform2D(0.0, rr.position)
	if rot != 0.0:
		var pv := pivot * Geom.M if pivot != Vector2.INF else rr.get_center()
		var t := Transform2D(0.0, pv) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -pv)
		poly = t * poly
		xf = t * xf
	var o := {"art": art, "art_xf": xf, "art_size": rr.size, "tag": tag, "cls": "equip", "dest": "equip", "cut_speed": 140.0}
	o.merge(opts, true)
	var kind := "equip" if o.get("cls", "equip") == "equip" else "fixture"
	var pc = w.add_piece(kind, poly, o)
	_tagged(pc)
	return pc


static func _sit_bolts(pc, r: Rect2, floor_piece, type: String = "bolt", n: int = 2) -> void:
	var xs: Array = []
	if n == 2:
		xs = [r.position.x + r.size.x * 0.18, r.end.x - r.size.x * 0.18]
	else:
		for i in n:
			xs.append(r.position.x + r.size.x * (0.1 + 0.8 * i / float(n - 1)))
	for x in xs:
		if floor_piece != null:
			_bolt(pc, floor_piece, x, r.end.y, type)
			continue
		var hit := _below(x, r.end.y)
		_bolt(pc, hit[0], x, hit[1], type)


# the first floor piece under (x, y): [piece, y of the fixing]
static func _below(x: float, y: float) -> Array:
	var d := 0.04
	while d < 1.2:
		var fp = w.piece_at(p(x, y + d), ["keel", "hull", "deck", "door"])
		if fp != null:
			return [fp, y + d - 0.04]
		d += 0.04
	return [null, y]


static func _equipment() -> void:
	# A — cockpit
	var r := sit(1.25, 2.3, 0.85)
	var con = _equip("CON-A", "console", r, {"mass": 0.35, "value": 1000.0, "fragile": 0.5, "room": "A", "name_key": "p_console"})
	# the bow floor slopes away under the console: its pedestal follows it down
	var fl0 := floor_at(1.25)
	var fl1 := floor_at(2.3)
	con.poly = PackedVector2Array([p(1.25, r.position.y), p(2.3, r.position.y), p(2.3, fl1 - 0.02), p(1.25, fl0 - 0.02)])
	for x in [1.44, 2.11]:
		var hit := _below(x, lerpf(fl0, fl1, (x - 1.25) / 1.05) - 0.06)
		_bolt(con, hit[0], x, hit[1])
	# the nav computer in a rack on the aft wall; the floor behind the console is the crew's
	var aft_wall = w.piece_at(p(5.0, -1.0), ["bulkhead"])
	r = Rect2(4.2, -1.75, 0.62, 1.4)
	var nav = _equip("NAV-01", "nav_rack", r, {"mass": 0.45, "value": 6000.0, "fragile": 0.85, "room": "A", "name_key": "p_nav"})
	_bolt(nav, aft_wall, 4.82, -1.5)
	_bolt(nav, aft_wall, 4.82, -0.55)
	# pilot and co-pilot seats on their floor rails: two bolts and a track lock each
	for i in 2:
		var x0 := 2.4 + i * 0.76
		r = sit(x0, x0 + 0.74, 2.05)
		var st = _equip("SEAT-P" if i == 0 else "SEAT-C", "seat", r, {"mass": 0.12, "value": 600.0, "fragile": 0.3, "room": "A", "name_key": "p_seat_p" if i == 0 else "p_seat_c"})
		# the outline of a crash couch in profile, facing the bow: rail, pedestal, pan, reclined back
		var sp := PackedVector2Array()
		for q in SEAT_SHAPE:
			sp.append(p(r.position.x + q.x * r.size.x, r.position.y + q.y * r.size.y))
		st.poly = sp
		_sit_bolts(st, r, null)
		var hit := _below(x0 + 0.37, r.end.y)
		_bolt(st, hit[0], x0 + 0.37, hit[1], "lock")
	# the overhead switch panel, hung along the sloping ceiling
	var ceil0 := ceil_at(3.45)
	var ceil1 := ceil_at(4.45)
	var ang := atan2(ceil1 - ceil0, 1.0)
	var ovh = _equip("OVH-A", "overhead", Rect2(3.45, ceil0 + 0.04, 1.0, 0.28), {"mass": 0.08, "value": 900.0, "fragile": 0.5, "room": "A", "name_key": "p_ovh"}, ang, Vector2(3.45, ceil0 + 0.04))
	for t in [0.15, 0.85]:
		var bx: float = 3.45 + t * cos(ang)
		var by: float = ceil0 + 0.04 + t * sin(ang)
		_bolt(ovh, w.piece_at(p(bx, by - 0.2), ["hull"]), bx, by)
	# emergency oxygen: a small charged bottle in a cabinet on the aft wall
	r = Rect2(4.27, -2.75, 0.55, 0.8)
	var em = _equip("EM-A", "o2cab", r, {"mass": 0.1, "value": 400.0, "fragile": 0.3, "room": "A", "hazard": "gas_tank", "name_key": "p_o2cab"})
	_bolt(em, aft_wall, 4.82, -2.55)
	_bolt(em, aft_wall, 4.82, -2.15)
	r = sit(4.0, 4.48, 0.42)
	var bb = _equip("BB-01", "blackbox", r, {"mass": 0.12, "value": 2000.0, "fragile": 0.2, "room": "A", "mandatory": true, "name_key": "p_blackbox"})
	_sit_bolts(bb, r, null)
	var rc := sit(3.92, 4.62, 0.62)
	var cov = _equip("COV-A", "cover", rc, {"cls": "metal", "dest": "metal", "density": 0.6, "room": "A", "cut_speed": 260.0, "name_key": "p_cover"})
	cov.mass = Geom.area(cov.poly) / (Geom.M * Geom.M) * 0.6
	for x in [3.98, 4.56]:
		var hit := _below(x, rc.end.y)
		_bolt(cov, hit[0], x, hit[1])
	bb.hidden_by = cov.id
	_lamp("LAMP-A", 3.0, "A")
	# B — crew quarters
	for i in 2:
		var x0 := 5.45 + i * 1.0
		r = sit(x0, x0 + 0.8, 1.9)
		var tk = _equip("TK-B%d" % (i + 1), "gastank", r, {"mass": 0.35, "value": 2500.0, "fragile": 0.3, "room": "B", "hazard": "gas_tank", "name_key": "p_gastank"})
		_sit_bolts(tk, r, null)
		_bolt(tk, w.piece_at(p(5.0, -2.0), ["bulkhead"]) if i == 0 else by_tag["TK-B1"], x0 + (0.0 if i == 0 else -0.1), r.position.y + 0.3)
	r = sit(7.9, 9.5, 1.25)
	var env = _equip("ENV-B", "env", r, {"mass": 0.5, "value": 1200.0, "fragile": 0.5, "room": "B", "name_key": "p_env"})
	_sit_bolts(env, r, null)
	r = Rect2(6.1, -2.2, 3.6, 0.42)
	var bunk = _equip("BUNK-B", "bunk", r, {"cls": "metal", "dest": "metal", "mass": 0.3, "room": "B", "cut_speed": 260.0, "name_key": "p_bunk"})
	_bolt(bunk, w.piece_at(p(10.0, -2.0), ["bulkhead"]), 9.7, -2.0)
	_bolt(bunk, hull_at(6.6, -3.8), 6.6, -2.2)
	_lamp("LAMP-B", 7.5, "B")
	# C — cargo hold: three containers on locks; C-02 has slipped and tilted
	r = sit(11.0, 13.8, 2.2)
	var c1 = _equip("C-01", "cargo", r, {"mass": 2.4, "value": 6000.0, "fragile": 0.15, "room": "C", "name_key": "p_cargo1"})
	_sit_bolts(c1, r, null, "lock", 4)
	r = sit(15.7, 18.3, 1.9)
	var c2 = _equip("C-02", "cargo", r, {"mass": 1.7, "value": 11000.0, "fragile": 0.9, "room": "C", "name_key": "p_cargo2"}, deg_to_rad(5.0), Vector2(18.3, 2.95))
	_bolt(c2, w.piece_at(p(17.9, 3.1), ["keel"]), 17.9, 2.94, "lock")
	_bolt(c2, w.piece_at(p(17.2, 3.1), ["keel"]), 17.25, 2.9, "lock")
	r = sit(19.4, 21.8, 1.8)
	var c3 = _equip("C-03", "cargo", r, {"mass": 1.2, "value": 7000.0, "fragile": 0.6, "room": "C", "name_key": "p_cargo3"})
	_sit_bolts(c3, r, null, "lock", 4)
	for i in 2:
		var hx := 11.9 + i * 8.3
		r = Rect2(hx, -3.25, 0.6, 0.7)
		var hk = _equip("HOOK-%d" % (i + 1), "hook", r, {"cls": "metal", "dest": "metal", "mass": 0.4, "room": "C", "cut_speed": 220.0, "name_key": "p_hook"})
		_bolt(hk, by_tag["RAIL-C"], hx + 0.3, -3.25)
	_lamp("LAMP-C", 17.6, "C", -3.25)
	# D — power room on the deck
	r = sit(27.5, 29.7, 1.95, -0.15)
	var gen = _equip("G-01", "gen", r, {"mass": 2.8, "value": 16000.0, "fragile": 0.35, "room": "D", "mandatory": true, "hazard": "gen", "name_key": "p_gen", "temp": 96.0})
	for x in [27.7, 28.3, 28.9, 29.5]:
		_bolt(gen, w.piece_at(p(x, 0.0), ["deck", "door"]), x, -0.15)
	r = sit(29.95, 30.85, 0.8, -0.15)
	var bat = _equip("B-01", "battery", r, {"mass": 0.6, "value": 2000.0, "fragile": 0.4, "room": "D", "hazard": "battery", "name_key": "p_battery"})
	_sit_bolts(bat, r, w.piece_at(p(30.6, 0.0), ["deck", "door"]))
	r = sit(31.0, 31.6, 1.1, -0.15)
	var cap = _equip("CAP-01", "cap", r, {"mass": 0.35, "value": 1500.0, "fragile": 0.4, "room": "D", "hazard": "cap", "name_key": "p_cap"})
	_sit_bolts(cap, r, by_tag["DK-2"])
	r = Rect2(31.85, -2.75, 0.65, 2.0)
	var swb = _equip("SWB", "swb", r, {"mass": 0.45, "value": 900.0, "fragile": 0.4, "room": "D", "name_key": "p_swb"})
	_bolt(swb, hull_at(32.8, -2.4), 32.5, -2.4)
	_bolt(swb, hull_at(32.8, -1.0), 32.5, -1.0)
	_lamp("LAMP-D", 29.0, "D")
	# E — maintenance bay
	r = sit(27.45, 28.45, 0.9)
	var pump = _equip("CP-E", "pump", r, {"mass": 0.55, "value": 4000.0, "fragile": 0.4, "room": "E", "name_key": "p_pump", "temp": 120.0})
	_sit_bolts(pump, r, null)
	r = sit(28.8, 29.8, 1.3)
	var cab = _equip("TCAB", "cabinet", r, {"cls": "metal", "dest": "metal", "mass": 0.4, "room": "E", "cut_speed": 240.0, "name_key": "p_cabinet"})
	_sit_bolts(cab, r, null)
	r = sit(30.6, 32.3, 1.15)
	var rad = _equip("RAD", "radiator", r, {"mass": 0.5, "value": 600.0, "fragile": 0.3, "room": "E", "name_key": "p_radiator", "temp": 120.0}, deg_to_rad(-4.0), Vector2(30.6, 2.95))
	_bolt(rad, by_tag["K4"], 31.9, 2.95)
	r = Rect2(31.65, 0.15, 0.6, 0.42)
	var rm = _equip("RM-E", "module", r, {"mass": 0.15, "value": 800.0, "fragile": 0.6, "room": "E", "name_key": "p_module"})
	_bolt(rm, by_tag["DK-2"], 31.95, 0.15)


static func _lamp(tag: String, x: float, room: String, y: float = INF) -> void:
	var top := ceil_at(x) if y == INF else y
	var r := Rect2(x - 0.28, top, 0.56, 0.16)
	var lp = _equip(tag, "lamp", r, {"cls": "metal", "dest": "metal", "mass": 0.04, "room": room, "cut_speed": 260.0, "name_key": "p_lamp"})
	var host = w.piece_at(p(x, top - 0.12), ["hull", "rail"])
	_bolt(lp, host, x, top)


static func _propulsion() -> void:
	var stern = func(y: float): return hull_at(32.8, y)
	var bt = w.add_piece("beam", R(33.0, -3.3, 40.6, -2.9), {"density": 1.1, "cut_speed": 150.0, "tag": "BEAM-T", "room": "F"})
	var bb = w.add_piece("beam", R(33.0, 2.9, 40.6, 3.3), {"density": 1.1, "cut_speed": 150.0, "tag": "BEAM-B", "room": "F"})
	_tagged(bt)
	_tagged(bb)
	_bolt(bt, stern.call(-3.1), 33.0, -3.1)
	_bolt(bb, stern.call(3.1), 33.0, 3.1)
	var r := Rect2(33.0, -1.1, 1.8, 2.2)
	var ef = _equip("ENG-F", "eng_front", r, {"mass": 1.6, "value": 5000.0, "fragile": 0.3, "room": "F", "name_key": "p_engf", "temp": 70.0})
	_bolt(ef, stern.call(-0.6), 33.0, -0.6)
	_bolt(ef, stern.call(0.4), 33.0, 0.4)
	r = Rect2(34.8, -0.9, 3.6, 1.8)
	var core = _equip("ENG-C", "eng_core", r, {"mass": 2.6, "value": 11000.0, "fragile": 0.3, "room": "F", "name_key": "p_engc"})
	_bolt(core, ef, 34.8, -0.5)
	_bolt(core, ef, 34.8, 0.5)
	for side in [-1, 1]:
		var y0 := -1.25 if side < 0 else 0.9
		r = Rect2(34.8, y0, 3.6, 0.35)
		var sh = _equip("SHROUD-T" if side < 0 else "SHROUD-B", "shroud", r, {"cls": "metal", "dest": "metal", "mass": 1.0, "room": "F", "cut_speed": 170.0, "name_key": "p_shroud"})
		var ey := -0.9 if side < 0 else 0.9
		_bolt(sh, core, 35.5, ey)
		_bolt(sh, core, 37.7, ey)
		var sy0 := -2.9 if side < 0 else 1.25
		var sy1 := -1.25 if side < 0 else 2.9
		var st = w.add_piece("strut", R(34.95, sy0, 35.2, sy1), {"density": 1.2, "cut_speed": 220.0, "room": "F"})
		_bolt(st, bt if side < 0 else bb, 35.07, -2.9 if side < 0 else 2.9)
		_bolt(st, sh, 35.07, -1.25 if side < 0 else 1.25)
	var noz := PackedVector2Array([p(38.4, -0.75), p(41.6, -1.5), p(41.6, 1.5), p(38.4, 0.75)])
	var nz = w.add_piece("equip", noz, {"art": "nozzle", "art_xf": Transform2D(0.0, p(38.4, -1.5)), "art_size": p(3.2, 3.0), "tag": "ENG-N", "cls": "equip", "dest": "equip", "mass": 1.4, "value": 5000.0, "fragile": 0.25, "room": "F", "cut_speed": 140.0, "name_key": "p_engn"})
	_tagged(nz)
	_bolt(nz, core, 38.4, -0.45)
	_bolt(nz, core, 38.4, 0.45)
	for side in [-1, 1]:
		var top := -2.9 if side < 0 else 1.0
		var bot := -1.0 if side < 0 else 2.9
		var st = w.add_piece("strut", R(39.5, top, 39.75, bot), {"density": 1.2, "cut_speed": 220.0, "room": "F"})
		_bolt(st, bt if side < 0 else bb, 39.62, -2.9 if side < 0 else 2.9)
		_bolt(st, nz, 39.62, -1.03 if side < 0 else 1.03)
	for side in [-1, 1]:
		r = Rect2(37.0, -4.0, 2.8, 0.7) if side < 0 else Rect2(37.0, 3.3, 2.8, 0.7)
		var ax = _equip("AUX-1" if side < 0 else "AUX-2", "aux", r, {"mass": 1.1, "value": 6500.0, "fragile": 0.3, "room": "F", "name_key": "p_aux"})
		var by := -3.3 if side < 0 else 3.3
		_bolt(ax, bt if side < 0 else bb, 37.5, by)
		_bolt(ax, bt if side < 0 else bb, 39.3, by)
	r = Rect2(35.6, -2.85, 3.0, 1.5)
	var tank = _equip("T-F01", "fueltank", r, {"mass": 1.5, "value": 6500.0, "fragile": 0.35, "room": "F", "hazard": "fuel_tank", "name_key": "p_fueltank"})
	_bolt(tank, bt, 36.2, -2.9)
	_bolt(tank, bt, 38.0, -2.9)
	r = Rect2(38.72, -2.7, 0.32, 1.25)
	var guard = _equip("GUARD-F", "guard", r, {"cls": "metal", "dest": "metal", "mass": 0.18, "room": "F", "cut_speed": 240.0, "name_key": "p_guard"}, deg_to_rad(11.0))
	_bolt(guard, bt, 38.85, -2.9)
	_bolt(guard, tank, 38.6, -1.6)


static func _path(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q * Geom.M)
	return out


static func _line(id: String, kind: String, net: String, a: String, pa: Vector2, b: String, pb: Vector2, via: Array = []) -> void:
	var pts: Array = [pa]
	pts.append_array(via)
	pts.append(pb)
	w.add_line(id, kind, net, by_tag[a], pa * Geom.M, by_tag[b], pb * Geom.M, _path(pts))


static func _lines() -> void:
	# electric: generator, battery and capacitor into the switchboard; the bus out to the hold
	_line("c1", "cable", "power", "G-01", Vector2(29.7, -1.2), "SWB", Vector2(31.85, -1.0), [Vector2(30.1, -1.2), Vector2(30.1, -1.5), Vector2(31.6, -1.5)])
	_line("c2", "cable", "power", "B-01", Vector2(30.4, -0.95), "SWB", Vector2(31.85, -1.4), [Vector2(30.4, -1.7), Vector2(31.6, -1.7)])
	_line("c3", "cable", "power", "CAP-01", Vector2(31.3, -1.25), "SWB", Vector2(31.85, -1.8), [Vector2(31.3, -1.9)])
	_line("c4", "cable", "power", "SWB", Vector2(31.9, -2.6), "C-03", Vector2(21.6, 1.3), [Vector2(31.5, -2.85), Vector2(27.6, -2.85), Vector2(26.6, -2.85), Vector2(22.6, -2.85), Vector2(22.6, 1.3)])
	_line("c5", "cable", "power", "SWB", Vector2(32.2, -2.75), "LAMP-D", Vector2(29.0, -3.39), [Vector2(32.2, -3.05), Vector2(29.0, -3.05)])
	_line("c6", "cable", "power", "SWB", Vector2(32.0, -2.75), "LAMP-C", Vector2(17.6, -3.09), [Vector2(32.0, -3.0), Vector2(27.6, -3.0), Vector2(26.5, -3.12), Vector2(17.6, -3.12)])
	_line("c7", "cable", "power", "LAMP-C", Vector2(17.4, -3.12), "LAMP-B", Vector2(7.5, -3.4), [Vector2(10.6, -3.12), Vector2(10.3, -2.95), Vector2(7.5, -2.95)])
	_line("c8", "cable", "power", "LAMP-B", Vector2(7.3, -3.4), "LAMP-A", Vector2(3.0, -2.87), [Vector2(7.3, -2.9), Vector2(4.6, -2.9), Vector2(3.0, -2.7)])
	_line("c9", "cable", "power", "SWB", Vector2(32.1, -2.75), "HATCH-2", Vector2(21.0, -3.6), [Vector2(32.1, -2.95), Vector2(27.6, -2.95), Vector2(26.7, -3.05), Vector2(21.0, -3.05)])
	_line("cn", "cable", "nav", "NAV-01", Vector2(4.25, -0.4), "CON-A", Vector2(2.3, 2.6), [Vector2(4.1, -0.3), Vector2(4.1, 2.45), Vector2(2.4, 2.45)])
	# coolant loop: pump -> generator -> engine -> radiator -> (broken) -> pump
	_line("q1", "pipe", "coolant", "CP-E", Vector2(28.0, 2.05), "G-01", Vector2(28.0, -0.4), [Vector2(28.0, 1.4), Vector2(28.95, 1.4), Vector2(28.95, 0.0), Vector2(28.95, -0.4)])
	_line("q2", "pipe", "coolant", "G-01", Vector2(29.7, -0.5), "ENG-F", Vector2(34.2, -1.1), [Vector2(30.0, -0.5), Vector2(30.0, -0.35), Vector2(32.4, -0.35), Vector2(33.6, -1.25), Vector2(34.2, -1.25)])
	_line("q3", "pipe", "coolant", "ENG-F", Vector2(34.2, 1.1), "RAD", Vector2(32.35, 2.2), [Vector2(34.2, 1.4), Vector2(33.6, 1.4), Vector2(32.9, 1.5), Vector2(32.4, 1.5)])
	_line("q4", "pipe", "coolant_broken", "RAD", Vector2(30.62, 2.5), "CP-E", Vector2(28.45, 2.5), [Vector2(30.0, 2.5), Vector2(29.95, 2.75), Vector2(28.6, 2.75)])
	_line("q5", "pipe", "none", "C-03", Vector2(21.8, 2.3), "K3", Vector2(22.4, 2.95), [Vector2(22.2, 2.3)])
	_line("p1", "pipe", "fuel", "T-F01", Vector2(35.6, -2.1), "ENG-F", Vector2(34.4, -1.1), [Vector2(35.2, -2.1), Vector2(35.2, -1.6), Vector2(34.4, -1.6)])
	_line("g1", "pipe", "gas", "TK-B1", Vector2(5.85, 1.05), "ENV-B", Vector2(7.9, 2.1), [Vector2(5.85, 0.7), Vector2(7.5, 0.7), Vector2(7.5, 2.1)])
	_line("g2", "pipe", "gas", "TK-B2", Vector2(6.85, 1.05), "ENV-B", Vector2(7.9, 2.4), [Vector2(6.85, 0.85), Vector2(7.35, 0.85), Vector2(7.35, 2.4)])


static func _ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	w.add_ctrl(id, kind, piece, pos * Geom.M, opts)


static func _controls() -> void:
	# outside, on the hull: ports, valves, the power panel, the hatch
	_ctrl("GAS-AB", "port", hull_at(3.9, -3.6), Vector2(3.95, -3.75), {"medium": "gas", "target": "A"})
	_ctrl("P-C01", "port", hull_at(11.2, -3.8), Vector2(11.2, -4.0), {"medium": "gas", "target": "SC"})
	_ctrl("V-C01", "valve", hull_at(11.9, -3.8), Vector2(11.85, -4.0), {"target": "SC-C"})
	_ctrl("HATCH-JAM", "jam", hull_at(18.2, -3.8), Vector2(18.4, -4.0), {"target": "HATCH"})
	_ctrl("HATCH-SW", "hatch", hull_at(22.0, -3.8), Vector2(22.2, -4.0), {"target": "HATCH"})
	_ctrl("GAS-D", "port", hull_at(28.0, -3.8), Vector2(28.0, -4.0), {"medium": "gas", "target": "D"})
	var panel = _equip("CTRL-D", "panel", Rect2(29.25, -4.55, 2.1, 0.55), {"cls": "metal", "dest": "metal", "mass": 0.12, "cut_speed": 240.0, "name_key": "p_panel"})
	_bolt(panel, hull_at(29.6, -3.8), 29.6, -4.0)
	_bolt(panel, hull_at(30.9, -3.8), 30.9, -4.0)
	_ctrl("K-G", "switch", panel, Vector2(29.55, -4.28), {"target": "K-G", "state": true})
	_ctrl("K-B", "switch", panel, Vector2(29.95, -4.28), {"target": "K-B", "state": true})
	_ctrl("G-STOP", "remote", panel, Vector2(30.35, -4.28), {"target": "G"})
	_ctrl("E-D01", "test", panel, Vector2(30.75, -4.28), {"medium": "volt", "target": "bus"})
	_ctrl("E-D02", "discharge", panel, Vector2(31.1, -4.28), {"target": "cap"})
	_ctrl("PWR-EXT", "socket", hull_at(32.2, -3.8), Vector2(32.25, -4.0), {"target": "aux"})
	# inside
	_ctrl("G-LOCAL", "stop", by_tag["G-01"], Vector2(28.15, -1.62), {"target": "G", "hidden_room": "D"})
	_ctrl("TK-B1", "port", by_tag["TK-B1"], Vector2(5.85, 1.12), {"medium": "gas", "target": "T1", "hidden_room": "B"})
	_ctrl("TK-B2", "port", by_tag["TK-B2"], Vector2(6.85, 1.12), {"medium": "gas", "target": "T2", "hidden_room": "B"})
	_ctrl("EM-A", "port", by_tag["EM-A"], Vector2(4.4, -2.0), {"medium": "gas", "target": "T3", "hidden_room": "A"})
	_ctrl("COOL-E", "port", by_tag["CP-E"], Vector2(27.7, 2.25), {"medium": "coolant", "target": "loop", "hidden_room": "E"})
	_ctrl("V-E1", "valve", by_tag["K4"], Vector2(28.75, 2.85), {"target": "V-E1", "state": true, "hidden_room": "E"})
	_ctrl("V-E2", "valve", by_tag["K4"], Vector2(30.25, 2.85), {"target": "V-E2", "state": true, "hidden_room": "E"})
	_ctrl("V-F01", "valve", by_tag["T-F01"], Vector2(35.75, -2.1), {"target": "V-F01", "state": true})
	_ctrl("FUEL-F", "port", by_tag["T-F01"], Vector2(38.5, -2.1), {"medium": "fuel", "target": "fuel"})
	for d in ["DR-AB", "DR-BC", "DR-CD", "DR-CE", "DR-DE"]:
		var dp = by_tag[d]
		var c := Geom.centroid(dp.poly) / Geom.M
		_ctrl(d, "door", dp, c, {"target": d, "state": dp.door_open})


static func _rooms() -> void:
	var ip := PackedVector2Array()
	for q in inner:
		ip.append(q * Geom.M)
	var a_cut: Array = Geometry2D.intersect_polygons(ip, R(-1.0, -5.0, 4.85, 5.0))
	w.add_room("A", a_cut[0] if a_cut.size() > 0 else R(0.6, -2.0, 4.85, 3.0))
	w.add_room("B", R(5.15, -3.55, 9.85, 2.95))
	w.add_room("C", R(10.15, -3.55, 26.85, 2.95))
	w.add_room("D", R(27.15, -3.55, 32.55, -0.15))
	w.add_room("E", R(27.15, 0.15, 32.55, 2.95))
	# the line between P-C01 and V-C01 is a tiny volume of its own


# Systems, contract and drawing data for ships/gr7.json.
# Chapter one, as data: what Liang says when the Heron comes in, the seven
# things on board that tell what happened, the flight recorder (a fragment on
# recovery, the whole recording at the end), the graded send-off, and the
# next contract card. Story reads this; no ship names in the game code.
static func story() -> Dictionary:
	return {
		"contract": "GR-001",
		"title": ["GR-7「灰鹭号」中型货运船 · 42 m", "GR-7 GREY HERON · MEDIUM FREIGHTER · 42 m"],
		"arrive": [
			["好了，真家伙来了。", "Right. Here's the real thing."],
			["灰鹭级货船，四十二米。前些天出了点事故，船主决定直接报废。", "Heron-class freighter, forty-two metres. Had an accident a few days back; the owner's scrapping her."],
			["送过来的资料不全，尾部肯定有问题，别的还不好说。", "The paperwork's incomplete. The stern's definitely bad. The rest, who knows."],
		],
		"start": [
			["这单不像训练舱那么简单。", "This one's not like the training rig."],
			["里面还有没有气，哪里通着电，管道里剩下什么，都得自己查。", "Gas, power, whatever's left in the pipes — you check all of it yourself."],
			["我会在无线电里待着。有问题可以问，但怎么拆还是你决定。", "I'll stay on the radio. Ask if you need to. How you take her apart is your call."],
			["开始吧。", "Go on, then."],
		],
		"banner": [["CONTRACT GR-001 — ACTIVE", "目标：开始现场检查"], ["CONTRACT GR-001 — ACTIVE", "OBJECTIVE: BEGIN SITE SURVEY"]],
		# a word from Liang when the ship contradicts its own records (not in hardcore)
		"lines": {
			"fake_off": {"zh": "记录说停了。记录是人写的。", "en": "The log says stopped. People write logs.", "hint": true},
		},
		"inspect": [
			{"id": "note", "piece": "CON-A", "room": "A", "title": ["控制台上的便签", "NOTE ON THE CONSOLE"],
				"text": ["「别急着记事故，先记发生了什么。——I. M.」", "\"Don't log the accident yet. Log what happened. —I. M.\""]},
			{"id": "nav", "piece": "NAV-01", "room": "A", "title": ["导航电脑 NAV-01", "NAV COMPUTER NAV-01"],
				"text": ["「最后航线：坐标 …… 未命名。预计到达：取消。」", "\"LAST ROUTE: COORDINATES ... UNNAMED. ETA: CANCELLED.\""]},
			{"id": "postcard", "piece": "BUNK-B", "room": "B", "title": ["铺位上的明信片", "POSTCARD ON THE BUNK"],
				"text": ["「回家前最后一单。——路」", "\"Last job before home. —Lu\""]},
			{"id": "seal", "piece": "C-02", "room": "C", "title": ["C-02 的封签", "SEAL ON C-02"],
				"text": ["「CHARON · KX-0 · 不得开封。」", "\"CHARON · KX-0 · DO NOT OPEN.\""]},
			{"id": "manifest", "piece": "C-03", "room": "C", "title": ["货单（钳在 C-03 门上）", "MANIFEST (CLIPPED TO C-03)"],
				"text": ["「C-02：精密机械」被划掉，重写为「KX-0」。", "\"C-02: PRECISION MACHINERY\" struck out, rewritten as \"KX-0\"."]},
			{"id": "steps", "piece": "G-01", "room": "D", "title": ["G-01 上的手写步骤", "HANDWRITTEN STEPS ON G-01"],
				"text": ["「1 断 K-G · 2 断 K-B · 3 主控停机 失败→本地手柄 · 4 放电容。——韩」", "\"1 OPEN K-G · 2 OPEN K-B · 3 REMOTE STOP failed → LOCAL HANDLE · 4 BLEED CAP. —Han\""]},
			{"id": "scratch", "piece": "TCAB", "room": "E", "title": ["工具柜上的划痕", "SCRATCH ON THE TOOL CABINET"],
				"text": ["一道新鲜的金属划痕，从工具柜一路划到舱门。", "A fresh scratch in the metal, from the tool cabinet all the way to the door."]},
		],
		"who": {
			"unknown": ["未知船员", "UNKNOWN CREW"],
			"han": ["韩彻", "HAN CHE"],
			"moran": ["莫兰", "MORAN"],
			"lu": ["小路（远处）", "LU (DISTANT)"],
			"alarm": ["警报", "ALARM"],
		},
		"recorder": {
			"piece": "BB-01",
			"card": ["FLIGHT RECORDER RECOVERED", "DATA INTEGRITY: 67%", "ARCHIVED TRANSMISSION AVAILABLE"],
			"before": [
				["黑匣子到了？", "The recorder's in?"],
				["行，这东西合同里专门点名要回收。顺手看看有没有完整的数据记录。", "Good — the contract names it. Let's see if there's anything left on it."],
			],
			"fragment": [
				["T−00:46", "unknown", "……主推进系统已经关闭。", "...Main propulsion is shut down."],
				["T−00:45", "unknown", "等一下，为什么控制台还显示有推力？", "Wait — why does the console still show thrust?"],
				["T−00:45", "unknown", "确认一下尾部传感器……", "Check the aft sensors..."],
			],
			"after": [
				["奇怪。事故报告上说的是冷却系统故障。", "Odd. The accident report says cooling failure."],
				["可能是当时的记录乱了，先存档吧。这不是咱们这份合同要查的事。", "Probably the log got scrambled. File it. Not what this contract's about."],
			],
			"clue": {"id": "gr7_fdr", "title": ["灰鹭号飞行记录异常", "GREY HERON: FLIGHT RECORD ANOMALY"]},
		},
		"epilogue": {
			"card": ["解密完成 · DATA INTEGRITY 100%", "DECRYPTED · DATA INTEGRITY 100%"],
			"recording": [
				["T−00:52", "han", "冷却回路压力掉了。E 舱在漏。", "Coolant loop pressure's dropping. E is leaking."],
				["T−00:47", "moran", "推进停机。所有人到 B 舱。", "Shut down propulsion. Everyone to B."],
				["T−00:46", "han", "……主推进系统已经关闭。", "...Main propulsion is shut down."],
				["T−00:45", "han", "等一下，为什么控制台还显示有推力？", "Wait — why does the console still show thrust?"],
				["T−00:45", "han", "确认一下尾部传感器……", "Check the aft sensors..."],
				["T−00:40", "han", "主电源说停了。……我不信，母线还有四百伏。", "Main power says it's stopped. ...I don't buy it. The bus still has four hundred volts."],
				["T−00:33", "moran", "韩彻，回来。", "Han, come back."],
				["T−00:30", "han", "给我两分钟。我去拉本地手柄。", "Give me two minutes. I'm going for the local handle."],
				["T−00:18", "alarm", "维修舱失压。", "MAINTENANCE BAY DECOMPRESSION.", "burst"],
				["T−00:14", "moran", "……韩彻？", "...Han?"],
				["T−00:09", "han", "没事，门关上了。手柄卡住了，停不了。", "I'm fine, the door held. The handle's jammed. It won't stop."],
				["T−00:05", "han", "让下一个人来吧。告诉他——别信面板。", "Let the next one do it. Tell them — don't trust the panel."],
				["T−00:02", "moran", "全员撤离。记录：主电源未确认断开。", "All hands, abandon ship. Log: main power not confirmed isolated."],
				["T+00:00", "lu", "韩工出来了！", "Han's out!"],
			],
			"grade": {
				"3": [["第一次接正式合同就做到这个程度，挺少见的。", "That's rare, for a first real contract."], ["老板看了应该高兴。就是别指望他给你涨工资。", "The boss'll be pleased. Don't expect a raise."]],
				"2": [["还行。大件都收回来了，损失也不算大。", "Not bad. The big pieces came back, and the losses weren't much."], ["以后熟练了，速度还能提上来。", "You'll get faster with practice."]],
				"1": [["今天赔掉的东西不少。", "We lost a fair bit today."], ["好在船坞还在，设备也还在。先看看事故记录，下次别再犯同样的问题。", "Still, the berth's here and so's the kit. Read the incident log. Don't do the same thing twice."]],
			},
			"echo": ["他说别信面板。你没信。", "He said don't trust the panel. You didn't."],
			"echo_arc": ["他说别信面板。下次记住。", "He said don't trust the panel. Remember that next time."],
			"closing": [
				["行，第一天算是干完了。", "Right. That's day one."],
				["市场上还有几份单子。接下来拆哪艘，你自己挑。", "There are a few jobs on the market. Which one's next is up to you."],
			],
			"terminal": [["合同市场已开放。", "CONTRACT MARKET OPEN."], ["设备采购权限已开放。", "EQUIPMENT PURCHASING ENABLED."], ["公司生涯记录已更新。", "CAREER RECORD UPDATED."]],
			"chapter": [["第一章 — 废弃船坞", "CHAPTER ONE — THE SCRAP BERTH"], "FIRST SHIFT COMPLETED"],
			"next": {
				"id": "#002 GR-9",
				"name": ["白鹭号", "WHITE EGRET"],
				"rows": [["灰鹭号的姐妹船", "Sister ship of the Grey Heron"], ["失联 41 天后被拖回", "Towed in after 41 days missing"], ["货单：KX-0，同批次。", "Manifest: KX-0, same batch."]],
				"from": "CHARON-DISPATCH",
				"tbc": ["未完待续 · 零压拆船厂", "TO BE CONTINUED · ZERO PRESSURE"],
			},
		},
	}


static func meta() -> Dictionary:
	return {
		"id": "gr7",
		"name": "GR-7 GREY HERON",
		"contract": "GR-001",
		"length": 42.0,
		"value": {"total": 122500.0, "metal": 12000.0},
		"clamps": [[7.0, 4.0], [15.8, 4.0], [23.4, 4.0], [28.6, 4.0]],
		"room_names": {"A": "room_A", "B": "room_B", "C": "room_C", "D": "room_D", "E": "room_E"},
		"gas": {
			"rooms": {"A": 92.0, "B": 92.0, "C": 108.0, "D": 72.0, "E": 0.0},
			"vessels": {
				"SC": {"V": 0.05, "kpa": 0.0, "dead_leg": "V-C01"},
				"T1": {"V": 0.6, "kpa": 1820.0, "piece": "TK-B1", "burst": 200.0},
				"T2": {"V": 0.6, "kpa": 1760.0, "piece": "TK-B2", "burst": 200.0},
				"T3": {"V": 0.04, "kpa": 1500.0, "piece": "EM-A", "burst": 200.0},
			},
			"valves": [{"ctrl": "V-C01", "a": "C", "b": "SC", "g": 20.0}],
			"value": 1200.0,
		},
		"power": {
			"bus": "SWB",
			"sources": [
				{"piece": "G-01", "kind": "gen", "volts": 400.0, "cable": "c1", "switch": "K-G", "running": true, "remote": "G-STOP", "remote_works": false, "local": "G-LOCAL"},
				{"piece": "B-01", "kind": "battery", "volts": 396.0, "local_volts": 52.0, "cable": "c2", "switch": "K-B", "charge": 0.84, "drain": 0.0004},
				{"piece": "CAP-01", "kind": "cap", "volts": 380.0, "cable": "c3", "charge": 1.0, "discharge": "E-D02"},
			],
			"isolated": [{"piece": "NAV-01", "volts": 24.0, "charge": 1.0}],
			"lamps": {"A": "LAMP-A", "B": "LAMP-B", "C": "LAMP-C", "D": "LAMP-D"},
			"aux": "PWR-EXT",
		},
		"fluids": {
			"volumes": {
				"cool": {"fluid": "coolant", "amount": 0.25, "full": 0.25, "nets": ["coolant"], "leak": 0.2, "port": "COOL-E", "pump": [0.22, 0.006]},
				"cool_broken": {"fluid": "coolant", "amount": 0.06, "nets": ["coolant_broken"], "leak": 0.2, "drip": 0.0016},
				"fuel": {"fluid": "fuel", "amount": 0.35, "piece": "T-F01", "content": 2.6, "leak": 0.1, "port": "FUEL-F", "pump": [0.12, 0.008], "hazard": 0.02},
				"fuel_line": {"fluid": "fuel", "amount": 0.04, "nets": ["fuel"], "leak": 0.05, "leak_min": 0.005},
			},
			"joins": [
				{"valves": ["V-E1", "V-E2"], "a": "cool", "b": "cool_broken", "mode": "share", "share": 0.25 / 0.31},
				{"valves": ["V-F01"], "a": "fuel", "b": "fuel_line", "mode": "fill", "cap": 0.04, "pump_through": 0.02, "leak_through": 0.06},
			],
			"value": {"fuel": 900.0, "coolant": 400.0},
			"heat": {"source": "G-01", "hot": 138.0, "cold": 20.0, "tau_on": 8.0, "tau_off": 13.0, "nets": ["coolant", "coolant_broken"],
				"ports": ["COOL-E"], "pieces": {"CP-E": 1.0, "RAD": 1.0, "ENG-F": 0.5}, "source_extra": 12.0},
		},
		"ctrls_cfg": {
			"GAS-AB": {"rate": 9.0},
			"P-C01": {"rate": 3.0},
			"GAS-D": {"rate": 6.0},
			"TK-B1": {"rate": 0.2},
			"TK-B2": {"rate": 0.2},
			"EM-A": {"rate": 0.2},
			"FUEL-F": {"blocked_by": "GUARD-F"},
			"HATCH-SW": {"doors": ["HATCH-1", "HATCH-2"], "jam": "HATCH-JAM", "cable": "c9"},
			"G-STOP": {"target": "G-01"},
			"G-LOCAL": {"target": "G-01"},
			"E-D02": {"target": "CAP-01"},
		},
		"labels": {"TK-B1": "O₂", "TK-B2": "N₂", "EM-A": "O₂", "C-01": "IND. METAL", "C-02": "PRECISION", "C-03": "ELECTRONIC", "G-01": "FUEL CELL", "T-F01": "PROP"},
		# hints that name this ship's own fittings (the generic ones live in Txt)
		"hints": {
			"dead_leg": ["读数来自测压口实际连通的那一段。按 Tab 看图纸：P-C01 和货舱之间还有一个阀门 V-C01。", "A gauge reads whatever its port is connected to. Press Tab: there is a valve, V-C01, between P-C01 and the hold."],
			"dead_leg_hose": ["V-C01 关着，软管只能抽到阀门外侧那一小段空管。", "With V-C01 shut the hose only reaches the empty stub outside the valve."],
			"remote": ["指令已发出。它真的停了吗？用测量工具去 E-D01 验证。", "Command sent. Did it actually stop? Verify at E-D01."],
			"no_power": ["舱门电机没电。船坞辅助电源 PWR-EXT 在 D 舱顶部外侧。", "No power for the door motors. Dock aux socket PWR-EXT is on the roof above D."],
			"hatch_jam": ["货舱门变形卡住了，先用 4 解除卡滞（HATCH-JAM）。", "The hatch is bent and jammed — clear HATCH-JAM with tool 4 first."],
			"discharge_refused": ["发电机或蓄电池还在给母线供电，先断开 K-G 和 K-B。", "The generator or battery still feeds the bus — open K-G and K-B first."],
		},
		# safe ways to take out the key equipment; VALIDATE SHIP has a bot walk each one
		"procedures": {
			"G-01": [
				{"do": "hose", "ctrl": "GAS-D"},
				{"do": "wait", "until": {"P": ["D", "<", 5.0]}, "max": 90.0},
				{"do": "operate", "ctrl": "K-G"},
				{"do": "operate", "ctrl": "K-B"},
				{"do": "operate", "ctrl": "E-D02"},
				{"do": "wait", "until": {"charge": ["CAP-01", "<", 0.002]}, "max": 30.0},
				{"do": "measure", "ctrl": "E-D01", "expect": ["<", 1.0]},
				{"do": "cut", "at": [28.6, -3.8], "kerf": [[28.2, -4.3], [28.2, -3.4]]},
				{"do": "cut", "at": [28.6, -3.8], "kerf": [[29.0, -4.3], [29.0, -3.4]]},
				{"do": "wait", "until": {"open": ["D"]}, "max": 5.0},
				{"do": "operate", "ctrl": "G-LOCAL"},
				{"do": "hose", "ctrl": "COOL-E"},
				{"do": "wait", "until": {"fluid": ["cool", "<", 0.02], "T": ["<", 60.0]}, "max": 240.0},
				{"do": "free", "piece": "G-01"},
				{"do": "deliver", "piece": "G-01", "zone": "equip"},
			],
			"BB-01": [
				{"do": "hose", "ctrl": "GAS-AB"},
				{"do": "wait", "until": {"P": ["A", "<", 5.0]}, "max": 120.0},
				{"do": "cut", "at": [3.6, -3.4], "kerf": [[3.2, -3.75], [3.2, -2.9]]},
				{"do": "cut", "at": [3.6, -3.4], "kerf": [[4.0, -4.0], [4.0, -3.15]]},
				{"do": "wait", "until": {"open": ["A"]}, "max": 5.0},
				{"do": "free", "piece": "COV-A"},
				{"do": "deliver", "piece": "COV-A", "zone": "metal"},
				{"do": "free", "piece": "BB-01"},
				{"do": "deliver", "piece": "BB-01", "zone": "equip"},
			],
		},
		"story": story(),
		"blueprint": {
			"hide": ["LAMP-A", "LAMP-B", "LAMP-C", "LAMP-D", "CTRL-D", "COV-A", "GUARD-F"],
			"design": {"C-02": [15.0, 1.05, 17.6, 2.95], "RAD": [30.6, 1.8, 32.3, 2.95]},
			"runs": [[[11.2, -4.0], [11.2, -4.18], [11.85, -4.18], [11.85, -3.4]]],
		},
	}
