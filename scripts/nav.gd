extends RefCounted
# Where the berth's machines can fly (player 2026-10-18: "the haulers fly
# straight through the hull"). The attached ship's walls are laid on a grid of
# CELL; every free cell knows how far it is from the nearest wall, so a path
# can keep the clearance a drone needs — more with a load hanging under it.
# Paths come from Godot's AStarGrid2D, then are pulled straight where the
# clearance allows. Rebuilt when the ship changes (pieces cut away, a hatch
# opened), not every frame.

const CELL := 12.0                 # px (a quarter of a metre)
const EMPTY_CLEAR := 26.0          # px from a wall for a drone flying empty
const LOAD_CLEAR := 44.0           # ... and with a load under it
const REBUILD_EVERY := 0.6         # s between checks that the ship changed
const REBUILD_GAP := 2.0           # s at least between two rebuilds (each costs a few tens of ms)

var game
var origin := Vector2.ZERO         # px: the grid's top left
var w := 0
var h := 0
var wall := PackedByteArray()      # 1 = a wall in this cell
var dist := PackedFloat32Array()   # px to the nearest wall
var grids := {}                    # clearance (px) -> AStarGrid2D
var _sig := []
var _check_t := 99.0
var dirty := true
var _built_at := -99.0


func _init(g) -> void:
	game = g


func step(dt: float) -> void:
	_check_t += dt
	if _check_t < REBUILD_EVERY:
		return
	_check_t = 0.0
	var wd = game.world
	var gone := 0
	for id in wd.pieces:
		if wd.pieces[id].gone or wd.pieces[id].body != null:
			gone += 1
	var sig := [wd.pieces.size(), gone, Dock.FLOOR_X1]
	if sig != _sig:
		_sig = sig
		dirty = true


# rebuilt only when a path is asked for, and not more often than REBUILD_GAP
func _fresh() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if dirty and (w == 0 or now - _built_at >= REBUILD_GAP):
		dirty = false
		_built_at = now
		_build()


func ready() -> bool:
	return w > 0


func _build() -> void:
	var M := Geom.M
	var b := Rect2(Dock.BOUNDS.position * M, Dock.BOUNDS.size * M)
	origin = b.position
	w = int(ceil(b.size.x / CELL))
	h = int(ceil(b.size.y / CELL))
	wall = PackedByteArray()
	wall.resize(w * h)
	wall.fill(0)
	# the ship's walls as they stand, a hair thicker so a thin plate never falls
	# between two cell centres
	var thick := CELL * 0.75
	var wd = game.world
	for id in wd.order:
		var p = wd.pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		var poly: PackedVector2Array = wd.world_poly(p)
		var grown: Array = Geometry2D.offset_polygon(poly, thick, Geometry2D.JOIN_MITER)
		var bb := Geom.bbox(poly).grow(thick)
		var x0 := clampi(int((bb.position.x - origin.x) / CELL), 0, w - 1)
		var x1 := clampi(int((bb.end.x - origin.x) / CELL), 0, w - 1)
		var y0 := clampi(int((bb.position.y - origin.y) / CELL), 0, h - 1)
		var y1 := clampi(int((bb.end.y - origin.y) / CELL), 0, h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i := y * w + x
				if wall[i] == 1:
					continue
				var c := origin + Vector2(x + 0.5, y + 0.5) * CELL
				for gp in grown:
					if Geometry2D.is_point_in_polygon(c, gp):
						wall[i] = 1
						break
	# the berth's own floor and boom are walls too
	for x in w:
		for y in h:
			var c := origin + Vector2(x + 0.5, y + 0.5) * CELL
			if c.y > (Dock.FLOOR_Y - 0.1) * M or c.y < (Dock.RAIL_Y + 0.2) * M and c.x < Dock.ARM_X1 * M and c.y > (Dock.RAIL_Y - 0.8) * M:
				wall[y * w + x] = 1
	_distances()
	grids.clear()


# a chamfer distance transform: how far each cell is from the nearest wall (px)
func _distances() -> void:
	dist = PackedFloat32Array()
	dist.resize(w * h)
	var far := 1.0e9
	for i in w * h:
		dist[i] = 0.0 if wall[i] == 1 else far
	var a := CELL
	var d := CELL * 1.4142
	for y in h:
		for x in w:
			var i := y * w + x
			var v := dist[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, dist[i - 1] + a)
			if y > 0:
				v = minf(v, dist[i - w] + a)
				if x > 0:
					v = minf(v, dist[i - w - 1] + d)
				if x < w - 1:
					v = minf(v, dist[i - w + 1] + d)
			dist[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := dist[i]
			if v == 0.0:
				continue
			if x < w - 1:
				v = minf(v, dist[i + 1] + a)
			if y < h - 1:
				v = minf(v, dist[i + w] + a)
				if x < w - 1:
					v = minf(v, dist[i + w + 1] + d)
				if x > 0:
					v = minf(v, dist[i + w - 1] + d)
			dist[i] = v


func _grid(clear: float) -> AStarGrid2D:
	if grids.has(clear):
		return grids[clear]
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, w, h)
	g.cell_size = Vector2(CELL, CELL)
	g.offset = origin + Vector2(CELL, CELL) * 0.5
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	for y in h:
		for x in w:
			if dist[y * w + x] < clear:
				g.set_point_solid(Vector2i(x, y), true)
	grids[clear] = g
	return g


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x - origin.x) / CELL), 0, w - 1), clampi(int((p.y - origin.y) / CELL), 0, h - 1))


func clearance_at(p: Vector2) -> float:
	if not ready():
		return 9999.0
	var c := cell_of(p)
	return dist[c.y * w + c.x]


# the nearest cell to p that is open at this clearance (p itself when it is)
func _open_near(g: AStarGrid2D, p: Vector2) -> Vector2i:
	var c := cell_of(p)
	if not g.is_point_solid(c):
		return c
	for r in range(1, 40):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or g.is_point_solid(q):
					continue
				var dd := float(dx * dx + dy * dy)
				if dd < bd:
					bd = dd
					best = q
		if best.x >= 0:
			return best
	return c


# a way from a to b keeping `clear` from every wall: waypoints in px, the last
# one b itself (the final reach may be closer to a wall than the path keeps);
# empty when there is no way at all
func path(a: Vector2, b: Vector2, clear: float) -> PackedVector2Array:
	_fresh()
	if not ready():
		return PackedVector2Array([b])
	var g := _grid(clear)
	var ca := _open_near(g, a)
	var cb := _open_near(g, b)
	if ca == cb:
		return PackedVector2Array([b])
	var ids := g.get_id_path(ca, cb)
	if ids.is_empty():
		# no way at this clearance: try the drone's own size before giving up
		if clear > EMPTY_CLEAR:
			return path(a, b, EMPTY_CLEAR)
		return PackedVector2Array()
	# pulled straight: from each point, the farthest later point in clear sight
	var pts := PackedVector2Array()
	for id in ids:
		pts.append(origin + (Vector2(id) + Vector2(0.5, 0.5)) * CELL)
	var out := PackedVector2Array()
	var i := 0
	var cur := a
	while i < pts.size() - 1:
		# reach on along the path while the straight line stays clear
		var j := i + 1
		while j + 1 < pts.size():
			var nj := mini(j + 3, pts.size() - 1)
			if not sight(cur, pts[nj], clear * 0.8):
				break
			j = nj
		out.append(pts[j])
		cur = pts[j]
		i = j
	if out.is_empty() or out[out.size() - 1].distance_to(b) > 1.0:
		out.append(b)
	return out


# a straight line from a to b that stays `clear` from every wall
func sight(a: Vector2, b: Vector2, clear: float) -> bool:
	if not ready():
		return true
	var n := int(ceil(a.distance_to(b) / CELL))
	for k in range(1, n):
		var q := a.lerp(b, float(k) / n)
		if clearance_at(q) < clear:
			return false
	return true
