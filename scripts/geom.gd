class_name Geom
# Polygon helpers for free cutting. Everything is in pixels; M converts metres.

const M := 48.0


static func m(x: float, y: float) -> Vector2:
	return Vector2(x * M, y * M)


static func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func mrect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(x0 * M, y0 * M, (x1 - x0) * M, (y1 - y0) * M)


static func area(p: PackedVector2Array) -> float:
	var s := 0.0
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


static func centroid(p: PackedVector2Array) -> Vector2:
	var n := p.size()
	if n == 0:
		return Vector2.ZERO
	var cx := 0.0
	var cy := 0.0
	var s := 0.0
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		var c := a.x * b.y - b.x * a.y
		s += c
		cx += (a.x + b.x) * c
		cy += (a.y + b.y) * c
	if absf(s) < 1e-6:
		var avg := Vector2.ZERO
		for q in p:
			avg += q
		return avg / n
	return Vector2(cx, cy) / (3.0 * s)


static func bbox(p: PackedVector2Array) -> Rect2:
	if p.is_empty():
		return Rect2()
	var lo := p[0]
	var hi := p[0]
	for q in p:
		lo = lo.min(q)
		hi = hi.max(q)
	return Rect2(lo, hi - lo)


static func xform(t: Transform2D, p: PackedVector2Array) -> PackedVector2Array:
	return t * p


static func circle(c: Vector2, r: float, n: int = 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(c + Vector2.from_angle(TAU * i / n) * r)
	return out


# The kerf a laser leaves along a path: one or more polygons.
static func stroke(pl: PackedVector2Array, r: float) -> Array:
	if pl.size() == 0:
		return []
	if pl.size() == 1 or (pl.size() == 2 and pl[0].distance_to(pl[1]) < 0.5):
		return [circle(pl[0], r, 10)]
	return Geometry2D.offset_polyline(pl, r, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)


static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func dist_to_polyline(p: Vector2, pl: PackedVector2Array) -> float:
	if pl.size() == 1:
		return p.distance_to(pl[0])
	var best := INF
	for i in pl.size() - 1:
		best = minf(best, dist_to_segment(p, pl[i], pl[i + 1]))
	return best


static func dist_to_boundary(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	var n := poly.size()
	for i in n:
		best = minf(best, dist_to_segment(p, poly[i], poly[(i + 1) % n]))
	return best


static func polyline_hits_polyline(a: PackedVector2Array, b: PackedVector2Array) -> Variant:
	for i in a.size() - 1:
		for j in b.size() - 1:
			var h = Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1])
			if h != null:
				return h
	return null


# Drops vertices that sit within eps of the line through their neighbours.
static func simplify(p: PackedVector2Array, eps: float = 0.45) -> PackedVector2Array:
	var cur := p
	for pass_i in 3:
		var n := cur.size()
		if n <= 4:
			return cur
		var out := PackedVector2Array()
		var changed := false
		var i := 0
		while i < n:
			var a: Vector2 = out[out.size() - 1] if out.size() > 0 else cur[(i - 1 + n) % n]
			var b := cur[i]
			var c := cur[(i + 1) % n]
			if b.distance_to(c) < 0.15 or (dist_to_segment(b, a, c) < eps and out.size() + (n - i) > 4):
				changed = true
				i += 1
				continue
			out.append(b)
			i += 1
		if not changed or out.size() < 3:
			return cur if out.size() < 3 else out
		cur = out
	return cur


static func valid(p: PackedVector2Array) -> bool:
	return p.size() >= 3 and not Geometry2D.triangulate_polygon(p).is_empty()


# Subtract cutters from a polygon and return simple polygons only: holes are
# opened to the nearest side with a hairline slit so every piece stays one
# simple outline.
static func cut(poly: PackedVector2Array, cutters: Array) -> Array:
	var parts: Array = [poly]
	for c in cutters:
		var cb := bbox(c)
		var next: Array = []
		for p in parts:
			if not bbox(p).grow(1.0).intersects(cb):
				next.append(p)
				continue
			next.append_array(Geometry2D.clip_polygons(p, c))
		parts = next
	# nesting depth tells holes (odd) from islands (even)
	var outers: Array = []
	var holes: Array = []
	for i in parts.size():
		var q: PackedVector2Array = parts[i]
		var depth := 0
		for j in parts.size():
			if i != j and Geometry2D.is_point_in_polygon(q[0], parts[j]) and area(parts[j]) > area(q):
				depth += 1
		if depth % 2 == 1:
			holes.append(q)
		else:
			outers.append(q)
	for h in holes:
		var hc := centroid(h)
		var best := -1
		var best_a := INF
		for k in outers.size():
			var o: PackedVector2Array = outers[k]
			if Geometry2D.is_point_in_polygon(h[0], o) and area(o) < best_a:
				best_a = area(o)
				best = k
		if best < 0:
			continue
		var o: PackedVector2Array = outers[best]
		var ob := bbox(o)
		var d := [hc.x - ob.position.x, ob.end.x - hc.x, hc.y - ob.position.y, ob.end.y - hc.y]
		var di := 0
		for k in 4:
			if d[k] < d[di]:
				di = k
		var w := 0.45
		var slit: Rect2
		match di:
			0: slit = Rect2(ob.position.x - 2.0, hc.y - w, hc.x - ob.position.x + 2.0, w * 2.0)
			1: slit = Rect2(hc.x, hc.y - w, ob.end.x - hc.x + 2.0, w * 2.0)
			2: slit = Rect2(hc.x - w, ob.position.y - 2.0, w * 2.0, hc.y - ob.position.y + 2.0)
			_: slit = Rect2(hc.x - w, hc.y, w * 2.0, ob.end.y - hc.y + 2.0)
		outers.remove_at(best)
		var opened: Array = []
		for q in Geometry2D.clip_polygons(o, rect_poly(slit)):
			opened.append_array(Geometry2D.clip_polygons(q, h))
		outers.append_array(opened)
	var out: Array = []
	for q in outers:
		var s := simplify(q)
		out.append(s if valid(s) else q)
	return out
