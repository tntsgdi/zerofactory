class_name World
extends Node2D
# The ship as structure: pieces, joints, cables and pipes, rooms. Owns the
# static collision of everything still clamped to the dock, turns any group
# that loses its last connection into a FreeBody, and applies laser kerfs.

signal piece_freed(body)

const KERF := 3.4
const BOLT_RING := [Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071)]

var game: Game
var pieces := {}
var order: Array = []          # piece ids in draw order
var joints: Array = []
var lines := {}
var ctrls := {}
var rooms := {}
var next_id := 1
var next_joint := 1
var static_body: StaticBody2D
var static_cols := {}
var bodies_node: Node2D
var back_layer: Node2D
var line_layer: Node2D
var piece_layer: Node2D
var cover_layer: Node2D
var heat_layer: Node2D
var light_layer: Node2D
var dirty_links := false
var dirty_cols := {}
var dirty_draw := false
var dirty_back := false
var metal_price := 120.0
var structural_mass := 0.0
var bodies: Array = []
var anim_doors := false
var font: Font
static var prof := {}


static var acc_sum := {}
static var acc_n := {}


static func acc(key: String, t0: int) -> void:
	acc_sum[key] = acc_sum.get(key, 0) + Time.get_ticks_usec() - t0
	acc_n[key] = acc_n.get(key, 0) + 1


static func _p(key: String, t0: int) -> void:
	var d := Time.get_ticks_usec() - t0
	prof[key] = maxi(prof.get(key, 0), d)


func _init() -> void:
	font = Fonts.get_font("Regular")
	static_body = StaticBody2D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)
	back_layer = _layer(0, false, _draw_back)
	light_layer = _layer(0, true, _draw_light)
	line_layer = _layer(1, false, _draw_lines)
	piece_layer = _layer(1, false, _draw_pieces)
	cover_layer = _layer(2, false, _draw_cover)
	bodies_node = Node2D.new()
	add_child(bodies_node)
	heat_layer = _layer(4, true, _draw_heat_static)


func _layer(z: int, additive: bool, fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.z_as_relative = false
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	n.draw.connect(fn)
	add_child(n)
	return n


# ---------------------------------------------------------------- building

func add_piece(kind: String, poly: PackedVector2Array, opts: Dictionary = {}):
	var p := Model.Piece.new()
	p.id = next_id
	next_id += 1
	p.kind = kind
	p.poly = poly
	for k in opts:
		if k in p:
			p.set(k, opts[k])
	if not opts.has("mass"):
		p.mass = Geom.area(poly) / (Geom.M * Geom.M) * p.density
	if p.kind in ["hull", "hatch", "bulkhead", "door", "deck", "keel"]:
		p.barrier = true
	pieces[p.id] = p
	order.append(p.id)
	return p


func add_joint(a, b, type: String, pos: Vector2):
	if a == null:
		return null
	var j := Model.Joint.new()
	j.id = next_joint
	next_joint += 1
	j.a = a.id
	j.b = b.id if b != null else Model.ANCHOR
	j.type = type
	j.pos = pos
	joints.append(j)
	return j


func add_line(id: String, kind: String, net: String, a, pa: Vector2, b, pb: Vector2, path: PackedVector2Array) -> void:
	var l := Model.Line.new()
	l.id = id
	l.kind = kind
	l.net = net
	l.a = a.id
	l.b = b.id
	l.pa = pa
	l.pb = pb
	l.path = path
	lines[id] = l


func add_ctrl(id: String, kind: String, piece, pos: Vector2, opts: Dictionary = {}) -> void:
	var c := Model.Ctrl.new()
	c.id = id
	c.kind = kind
	c.piece = piece.id if piece != null else 0
	c.pos = pos
	for k in opts:
		if k in c:
			c.set(k, opts[k])
	ctrls[id] = c


func add_room(name: String, poly: PackedVector2Array) -> void:
	rooms[name] = {"name": name, "poly": poly, "revealed": false, "reveal_t": 0.0, "from": Geom.centroid(poly), "lit": false, "bbox": Geom.bbox(poly)}


# metal_value: what the whole structure fetches as scrap (the ship file says)
func finalize(metal_value: float = 12000.0) -> void:
	structural_mass = 0.0
	for id in order:
		var p = pieces[id]
		if p.cls == "metal":
			structural_mass += p.mass
	metal_price = metal_value / maxf(1.0, structural_mass)
	for id in order:
		rebuild_cols(pieces[id])
	for n in rooms:
		rooms[n].shell0 = _room_shell(rooms[n])
	relink()
	redraw_all(true)


# how much of the structure around a room is still there (back wall fades with it)
func _room_shell(r) -> float:
	var s := 0.0
	var bb: Rect2 = r.bbox.grow(30.0)
	for id in order:
		var p = pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		var pb := Geom.bbox(p.poly)
		if pb.intersects(bb):
			s += Geom.area(p.poly)
	return s


func tag(t: String):
	for id in order:
		var p = pieces[id]
		if p.tag == t and not p.gone:
			return p
	return null


# ---------------------------------------------------------------- queries

func frame(p) -> Transform2D:
	return p.body.global_transform if p.body != null else Transform2D.IDENTITY


func door_offset(p) -> Vector2:
	return p.open_dir * Pal.ease_io(p.open_t) if p.door else Vector2.ZERO


func world_poly(p) -> PackedVector2Array:
	var poly: PackedVector2Array = p.poly
	if p.door and p.open_t > 0.0:
		poly = Transform2D(0.0, door_offset(p)) * poly
	return frame(p) * poly


func piece_contains(p, wpos: Vector2) -> bool:
	var lp: Vector2 = frame(p).affine_inverse() * wpos - door_offset(p)
	if not Geom.bbox(p.poly).grow(1.0).has_point(lp):
		return false
	return Geometry2D.is_point_in_polygon(lp, p.poly)


func piece_at(wpos: Vector2, kinds: Array = [], free_ok: bool = true):
	for i in range(order.size() - 1, -1, -1):
		var p = pieces[order[i]]
		if p.gone:
			continue
		if not kinds.is_empty() and not p.kind in kinds:
			continue
		if not free_ok and p.body != null:
			continue
		if p.door and p.door_open:
			continue
		if piece_contains(p, wpos):
			return p
	return null


# Pieces under a point, top first. Free bodies draw above attached structure.
func pieces_at(wpos: Vector2) -> Array:
	var out: Array = []
	for i in range(order.size() - 1, -1, -1):
		var p = pieces[order[i]]
		if p.gone or (p.door and p.door_open):
			continue
		if piece_contains(p, wpos):
			out.append(p)
	out.sort_custom(func(a, b): return (a.body != null) and (b.body == null))
	return out


func joints_of(p) -> Array:
	var out: Array = []
	for j in joints:
		if j.alive and (j.a == p.id or j.b == p.id):
			out.append(j)
	return out


func lines_of(p) -> Array:
	var out: Array = []
	for id in lines:
		var l = lines[id]
		if l.alive and (l.a == p.id or l.b == p.id):
			out.append(l)
	return out


func joint_world(j) -> Vector2:
	var p = pieces.get(j.a)
	return frame(p) * j.pos if p != null else j.pos


func line_end_world(l, end: int) -> Vector2:
	var p = pieces.get(l.a if end == 0 else l.b)
	if p == null:
		return Vector2.ZERO
	return frame(p) * (l.pa if end == 0 else l.pb)


func line_path_world(l) -> PackedVector2Array:
	var pa = pieces.get(l.a)
	var pb = pieces.get(l.b)
	if pa != null and pb != null and pa.body == null and pb.body == null:
		return l.path
	var a := line_end_world(l, 0)
	var b := line_end_world(l, 1)
	var mid := (a + b) * 0.5 + Vector2(0, a.distance_to(b) * 0.08)
	return PackedVector2Array([a, mid, b])


func ctrl_world(c) -> Vector2:
	var p = pieces.get(c.piece)
	if p == null:
		return c.pos
	return frame(p) * c.pos


func ctrl_alive(c) -> bool:
	var p = pieces.get(c.piece)
	return p != null and not p.gone


func room_at(wpos: Vector2) -> String:
	for n in rooms:
		var r = rooms[n]
		if r.bbox.has_point(wpos) and Geometry2D.is_point_in_polygon(wpos, r.poly):
			return n
	return ""


# True for a real room that nobody has opened yet ("" and "F" are never hidden).
func room_hidden(name: String) -> bool:
	return name != "" and rooms.has(name) and not rooms[name].revealed


# A point is hidden when it lies inside a room nobody has opened yet.
func hidden(wpos: Vector2) -> bool:
	var r := room_at(wpos)
	return r != "" and not rooms[r].revealed


func content_mass(p) -> float:
	if game != null and game.sys != null:
		return game.sys.content_mass(p)
	return 0.0


func group_mass(p) -> float:
	if p.body != null:
		return p.body.total_mass()
	# attached: the mass that would come away if this piece's own fixings were undone
	return p.mass + content_mass(p)


# ---------------------------------------------------------------- connectivity

func relink() -> void:
	var t0 := Time.get_ticks_usec()
	_relink()
	_p("relink", t0)


func _relink() -> void:
	dirty_links = false
	var parent := {}
	for id in pieces:
		if not pieces[id].gone:
			parent[id] = id
	parent[Model.ANCHOR] = Model.ANCHOR
	var find := func(x):
		var r = x
		while parent[r] != r:
			r = parent[r]
		var y = x
		while parent[y] != r:
			var nx = parent[y]
			parent[y] = r
			y = nx
		return r
	var unite := func(a, b):
		if not parent.has(a) or not parent.has(b):
			return
		var ra = find.call(a)
		var rb = find.call(b)
		if ra != rb:
			parent[ra] = rb
	for j in joints:
		if j.alive:
			if not parent.has(j.a) or (j.b != Model.ANCHOR and not parent.has(j.b)):
				j.alive = false
				continue
			unite.call(j.a, j.b)
	for id in lines:
		var l = lines[id]
		if l.alive:
			if not parent.has(l.a) or not parent.has(l.b):
				l.alive = false
				continue
			unite.call(l.a, l.b)
	var anchor_root = find.call(Model.ANCHOR)
	var comps := {}
	for id in parent:
		if id == Model.ANCHOR:
			continue
		var r = find.call(id)
		if not comps.has(r):
			comps[r] = []
		comps[r].append(pieces[id])
	# attached pieces that are no longer anchored float off
	for r in comps:
		if r == anchor_root:
			continue
		var comp: Array = comps[r]
		var att: Array = comp.filter(func(p): return p.body == null)
		if not att.is_empty():
			make_body(att, null)
	# bodies that fell apart
	for b in bodies.duplicate():
		if not is_instance_valid(b):
			continue
		var groups := {}
		for p in b.pieces:
			var r = find.call(p.id)
			if not groups.has(r):
				groups[r] = []
			groups[r].append(p)
		if groups.size() <= 1:
			continue
		var keys := groups.keys()
		keys.sort_custom(func(x, y): return _mass_of(groups[x]) > _mass_of(groups[y]))
		for k in range(1, keys.size()):
			make_body(groups[keys[k]], b)
		b.refresh()


func _mass_of(arr: Array) -> float:
	var s := 0.0
	for p in arr:
		s += p.mass
	return s


func make_body(group: Array, from_body):
	var m := 0.0
	var com := Vector2.ZERO
	for p in group:
		var pm: float = maxf(0.01, p.mass)
		m += pm
		com += frame(p) * Geom.centroid(p.poly) * pm
	com /= maxf(m, 0.0001)
	var b := FreeBody.new()
	b.world = self
	bodies_node.add_child(b)
	b.global_position = com
	b.reset_physics_interpolation()
	var to_local := b.global_transform.affine_inverse()
	for p in group:
		var old := frame(p)
		var t := to_local * old
		_reframe(p, t)
		if p.body != null:
			p.body.drop_piece(p)
		elif static_cols.has(p.id):
			for c in static_cols[p.id]:
				c.queue_free()
			static_cols.erase(p.id)
		p.body = b
		b.pieces.append(p)
	if from_body != null and is_instance_valid(from_body):
		var r: Vector2 = com - from_body.global_position
		b.linear_velocity = from_body.linear_velocity + Vector2(-r.y, r.x) * from_body.angular_velocity
		b.angular_velocity = from_body.angular_velocity
		if from_body.pieces.is_empty():
			_kill_body(from_body)
	for p in group:
		b.rebuild_cols(p)
	b.refresh()
	bodies.append(b)
	redraw_all(true)
	piece_freed.emit(b)
	return b


# Move a piece's own data into a new frame (t maps old frame -> new frame).
func _reframe(p, t: Transform2D) -> void:
	p.poly = t * p.poly
	p.art_xf = t * p.art_xf
	for h in p.heat:
		h[0] = t * h[0]
	for j in joints:
		if j.a == p.id:
			j.pos = t * j.pos
	for id in lines:
		var l = lines[id]
		if l.a == p.id:
			l.pa = t * l.pa
		if l.b == p.id:
			l.pb = t * l.pb
	for id in ctrls:
		var c = ctrls[id]
		if c.piece == p.id:
			c.pos = t * c.pos
	p.open_dir = t.basis_xform(p.open_dir)


func _kill_body(b) -> void:
	bodies.erase(b)
	if is_instance_valid(b):
		b.queue_free()


# The piece leaves the game (recovered, or burnt away).
func remove_piece(p) -> void:
	if p.gone:
		return
	p.gone = true
	for j in joints:
		if j.alive and (j.a == p.id or j.b == p.id):
			j.alive = false
	for id in lines:
		var l = lines[id]
		if l.alive and (l.a == p.id or l.b == p.id):
			l.alive = false
	if p.body != null and is_instance_valid(p.body):
		var b = p.body
		b.drop_piece(p)
		if b.pieces.is_empty():
			_kill_body(b)
		else:
			b.refresh()
	elif static_cols.has(p.id):
		for c in static_cols[p.id]:
			c.queue_free()
		static_cols.erase(p.id)
	p.body = null
	dirty_links = true
	redraw_all(true)


func remove_body(b) -> void:
	for p in b.pieces.duplicate():
		remove_piece(p)
	_kill_body(b)


func kill_joint(j) -> void:
	if not j.alive:
		return
	j.alive = false
	dirty_links = true
	redraw_all()


func kill_line(l, at: Vector2 = Vector2.INF) -> void:
	if not l.alive:
		return
	l.alive = false
	l.cut_at = at
	dirty_links = true
	redraw_all()


# ---------------------------------------------------------------- collision

func rebuild_cols(p) -> void:
	if p.body != null:
		p.body.rebuild_cols(p)
		return
	if static_cols.has(p.id):
		for c in static_cols[p.id]:
			c.queue_free()
	static_cols.erase(p.id)
	if p.gone or (p.door and p.open_t > 0.5):
		return
	var poly := Geom.simplify(p.poly, 1.4)
	if not Geom.valid(poly):
		poly = p.poly
	if Geom.area(poly) < 20.0 or not Geom.valid(poly):
		return
	var c := CollisionPolygon2D.new()
	c.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	c.polygon = poly
	static_body.add_child(c)
	static_cols[p.id] = [c]


func _physics_process(_dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	if not dirty_cols.is_empty():
		for id in dirty_cols:
			var p = pieces.get(id)
			if p != null:
				rebuild_cols(p)
		dirty_cols.clear()
		_p("cols", t0)
	if dirty_links:
		relink()


func _process(dt: float) -> void:
	var moving := false
	for id in order:
		var p = pieces[id]
		if not p.door:
			continue
		var tgt := 1.0 if p.door_open else 0.0
		if not is_equal_approx(p.open_t, tgt):
			var was: float = p.open_t
			p.open_t = move_toward(p.open_t, tgt, dt / 0.55)
			moving = true
			if (was <= 0.5) != (p.open_t <= 0.5):
				dirty_cols[p.id] = true
				if game != null and game.sys != null:
					game.sys.topology_dirty = true
	if moving:
		piece_layer.queue_redraw()
		for b in bodies:
			b.view.queue_redraw()
	var animating := false
	for n in rooms:
		var r = rooms[n]
		if r.revealed and r.reveal_t < 1.0:
			r.reveal_t = minf(1.0, r.reveal_t + dt / 0.75)
			animating = true
			if r.reveal_t >= 1.0:
				back_layer.queue_redraw()
	if animating:
		cover_layer.queue_redraw()
	var hot := false
	for id in order:
		var p = pieces[id]
		if p.heat.is_empty():
			continue
		var now := Time.get_ticks_msec() / 1000.0
		p.heat = p.heat.filter(func(h): return now - h[1] < 3.2)
		if p.body == null:
			hot = true
	if hot or heat_layer.get_meta("was_hot", false):
		heat_layer.queue_redraw()
	heat_layer.set_meta("was_hot", hot)
	if dirty_back:
		dirty_back = false
		back_layer.queue_redraw()
	if dirty_draw:
		dirty_draw = false
		piece_layer.queue_redraw()
		line_layer.queue_redraw()
		light_layer.queue_redraw()
		for b in bodies:
			if is_instance_valid(b):
				b.view.queue_redraw()


# back = the room backs too (their wall fades with the structure around them)
func redraw_all(back: bool = false) -> void:
	dirty_draw = true
	if back:
		dirty_back = true


func reveal(room: String, from: Vector2) -> void:
	var r = rooms.get(room)
	if r == null or r.revealed:
		return
	r.revealed = true
	r.reveal_t = 0.0
	r.from = from
	cover_layer.queue_redraw()
	back_layer.queue_redraw()
	if game != null:
		game.on_reveal(room, from)


# ---------------------------------------------------------------- cutting

# Apply a kerf (a polyline in the piece's frame) to one piece. Returns what
# happened so the caller can react (split, joints cut, lines cut).
func commit_cut(p, pl: PackedVector2Array, r: float = KERF) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var out := _commit_cut(p, pl, r)
	_p("commit", t0)
	return out


func _commit_cut(p, pl: PackedVector2Array, r: float = KERF) -> Dictionary:
	var res := {"split": 0, "killed": [], "new": [], "lines": [], "gone": false}
	if p.gone or pl.is_empty():
		return res
	var cutters := Geom.stroke(pl, r)
	var parts: Array = Geom.cut(p.poly, cutters)
	parts = parts.filter(func(q): return Geom.area(q) >= 8.0)
	parts.sort_custom(func(a, b): return Geom.area(a) > Geom.area(b))
	var now := Time.get_ticks_msec() / 1000.0
	# fixings the kerf passes over are gone
	for j in joints:
		if j.alive and (j.a == p.id or j.b == p.id):
			var jp: Vector2 = j.pos if j.a == p.id else _pos_in(j, p)
			if Geom.dist_to_polyline(jp, pl) <= r + 3.0:
				j.alive = false
				res.killed.append(j)
	if p.cls == "equip" and p.intact:
		p.intact = false
	if parts.is_empty():
		res.gone = true
		remove_piece(p)
		return res
	var old_area := Geom.area(p.poly)
	var old_mass: float = p.mass
	p.poly = parts[0]
	var keep_heat: Array = p.heat.duplicate()
	keep_heat.append([pl, now])
	var all_parts: Array = [p]
	for i in range(1, parts.size()):
		var q = add_piece(p.kind, parts[i], {})
		for prop in ["density", "cls", "value", "cond", "intact", "fragile", "contam", "cut_speed", "room", "barrier", "temp", "dest", "body", "hazard"]:
			q.set(prop, p.get(prop))
		q.value = 0.0
		q.intact = false
		q.hazard = ""
		q.tag = ""
		q.name_key = p.name_key if p.cls == "equip" else ""
		q.art = ""
		if p.body != null:
			p.body.pieces.append(q)
		# draw it right after its parent
		order.erase(q.id)
		order.insert(order.find(p.id) + 1, q.id)
		all_parts.append(q)
		res.new.append(q)
	if parts.size() > 1:
		p.art = ""
		res.split = parts.size()
	for q in all_parts:
		var a := Geom.area(q.poly)
		if q.cls == "metal":
			q.mass = a / (Geom.M * Geom.M) * q.density
		else:
			q.mass = old_mass * a / maxf(old_area, 1.0)
		q.heat = keep_heat.filter(func(h): return Geom.dist_to_boundary(_heat_mid(h[0]), q.poly) < r + 6.0)
	# hand each fixing, line end and control to whichever part now holds it
	for j in joints:
		if not j.alive:
			continue
		if j.a == p.id:
			var to = _part_for(all_parts, j.pos)
			if to == null:
				j.alive = false
				res.killed.append(j)
			else:
				j.a = to.id
		elif j.b == p.id:
			var jp := _pos_in(j, p)
			var to = _part_for(all_parts, jp)
			if to == null:
				j.alive = false
				res.killed.append(j)
			else:
				j.b = to.id
	for id in lines:
		var l = lines[id]
		if not l.alive:
			continue
		if l.a == p.id:
			var to = _part_for(all_parts, l.pa)
			if to == null:
				l.alive = false
				res.lines.append(l)
			else:
				l.a = to.id
		if l.b == p.id:
			var to = _part_for(all_parts, l.pb)
			if to == null:
				l.alive = false
				res.lines.append(l)
			else:
				l.b = to.id
	for id in ctrls:
		var c = ctrls[id]
		if c.piece == p.id:
			var to = _part_for(all_parts, c.pos, 14.0)
			c.piece = to.id if to != null else 0
	for q in all_parts:
		dirty_cols[q.id] = true
	if p.body != null:
		p.body.refresh()
	dirty_links = true
	if p.barrier and game != null and game.sys != null:
		game.sys.topology_dirty = true
	redraw_all()
	return res


func _heat_mid(pl: PackedVector2Array) -> Vector2:
	return pl[pl.size() / 2]


# joint positions are kept in piece a's frame; give it in piece p's frame
func _pos_in(j, p) -> Vector2:
	var pa = pieces.get(j.a)
	if pa == null:
		return j.pos
	return frame(p).affine_inverse() * (frame(pa) * j.pos)


func _part_for(parts: Array, pos: Vector2, tol: float = 7.0):
	for q in parts:
		if Geometry2D.is_point_in_polygon(pos, q.poly):
			return q
	var best = null
	var bd := tol
	for q in parts:
		var d := Geom.dist_to_boundary(pos, q.poly)
		if d < bd:
			bd = d
			best = q
	return best


# Cables and pipes the kerf crosses (world polyline).
func cut_lines(wpl: PackedVector2Array, r: float = KERF) -> Array:
	var hit: Array = []
	for id in lines:
		var l = lines[id]
		if not l.alive:
			continue
		var path := line_path_world(l)
		var at = Geom.polyline_hits_polyline(wpl, path)
		if at == null:
			for q in wpl:
				if Geom.dist_to_polyline(q, path) <= r:
					at = q
					break
		if at != null:
			kill_line(l, at)
			hit.append([l, at])
	return hit


# Used while building: carve a region out of every piece it touches.
func cut_region(poly: PackedVector2Array, _events: bool) -> void:
	var bb := Geom.bbox(poly)
	for id in order.duplicate():
		var p = pieces[id]
		if p.gone or not Geom.bbox(p.poly).intersects(bb):
			continue
		var parts: Array = Geom.cut(p.poly, [poly])
		parts = parts.filter(func(q): return Geom.area(q) >= 8.0)
		if parts.is_empty():
			p.gone = true
			continue
		parts.sort_custom(func(a, b): return Geom.area(a) > Geom.area(b))
		p.poly = parts[0]
		p.mass = Geom.area(p.poly) / (Geom.M * Geom.M) * p.density
		for i in range(1, parts.size()):
			var q = add_piece(p.kind, parts[i], {"density": p.density, "barrier": p.barrier, "cut_speed": p.cut_speed})
			for j in joints:
				if j.a == p.id and Geometry2D.is_point_in_polygon(j.pos, q.poly):
					j.a = q.id
				elif j.b == p.id and Geometry2D.is_point_in_polygon(j.pos, q.poly):
					j.b = q.id
			# neighbours along the seams keep it in place
			_weld_touching(q)
		for j in joints:
			if (j.a == p.id or j.b == p.id) and Geometry2D.is_point_in_polygon(j.pos, poly):
				j.alive = false


func _weld_touching(q) -> void:
	for id in order:
		var o = pieces[id]
		if o == q or o.gone or o.kind != q.kind:
			continue
		for v in q.poly:
			if Geom.dist_to_boundary(v, o.poly) < 1.5:
				add_joint(q, o, "weld", v)
				return


# ---------------------------------------------------------------- drawing

func _style(p) -> Array:
	var fill := Pal.PLATE
	var line_c := Pal.ink(0.82)
	match p.kind:
		"hull", "hatch":
			fill = Color(0.088, 0.092, 0.103)
		"keel", "beam":
			fill = Color(0.075, 0.078, 0.088)
		"bulkhead", "deck", "door":
			fill = Color(0.07, 0.073, 0.082)
			line_c = Pal.ink(0.66)
		"rib", "rail", "strut":
			fill = Color(0.064, 0.067, 0.076)
			line_c = Pal.ink(0.55)
		"equip":
			fill = Color(0.052, 0.055, 0.063)
			line_c = Pal.ink(0.9)
		"fixture":
			fill = Color(0.06, 0.063, 0.072)
			line_c = Pal.ink(0.62)
	if p.cls == "equip" and not p.intact:
		fill = Color(0.045, 0.045, 0.05)
		line_c = Pal.ink(0.42)
	if p.contam:
		line_c = line_c.lerp(Pal.tint(Pal.FLUID, line_c.a), 0.55)
	return [fill, line_c]


func draw_piece(ci: CanvasItem, p) -> void:
	draw_pieces(ci, [p])


# Every piece of a group in a handful of draw calls: one triangle array for
# all the fills, one line batch for all the outlines, then the equipment art.
func draw_pieces(ci: CanvasItem, list: Array) -> void:
	var fp := PackedVector2Array()
	var fc := PackedColorArray()
	var fi := PackedInt32Array()
	var segs := PackedVector2Array()
	var sc := PackedColorArray()
	var arts: Array = []
	for p in list:
		if p.gone:
			continue
		var off := door_offset(p)
		var poly: PackedVector2Array = p.poly
		if off != Vector2.ZERO:
			poly = Transform2D(0.0, off) * poly
		var st := _style(p)
		var tri := _tri_cached(p)
		if not tri.is_empty():
			var base := fp.size()
			fp.append_array(poly)
			var cs := PackedColorArray()
			cs.resize(poly.size())
			cs.fill(st[0])
			fc.append_array(cs)
			for k in tri:
				fi.append(base + k)
		var n := poly.size()
		for i in n:
			segs.append(poly[i])
			segs.append(poly[(i + 1) % n])
			sc.append(st[1])
		if p.art != "" or (p.cls == "equip" and not p.intact):
			arts.append([p, poly, off])
	if not fi.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), fi, fp, fc)
	if not segs.is_empty():
		ci.draw_multiline_colors(segs, sc, 1.3)
	for a in arts:
		var p = a[0]
		if p.art != "":
			var xf: Transform2D = Transform2D(0.0, a[2]) * p.art_xf
			ci.draw_set_transform_matrix(xf)
			Art.draw(ci, p.art, p.art_size, p, font)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			_scars(ci, a[1])


# triangulating every outline on every redraw is the expensive part: remember
# the triangles until the outline changes (the same array object is kept, so
# an identity check is enough)
func _tri_cached(p) -> PackedInt32Array:
	var sig: int = hash(p.poly)
	if p.tri_sig == sig:
		return p.tri
	p.tri_sig = sig
	p.tri = Geometry2D.triangulate_polygon(p.poly) if p.poly.size() >= 3 else PackedInt32Array()
	return p.tri


func _scars(ci: CanvasItem, poly: PackedVector2Array) -> void:
	var bb := Geom.bbox(poly)
	var c := bb.get_center()
	var s := 9.0
	var pl := PackedVector2Array()
	var y := bb.position.y + s
	while y < bb.end.y:
		pl.append(Vector2(bb.position.x - 4, y))
		pl.append(Vector2(bb.end.x + 4, y + bb.size.x * 0.35))
		y += s
	if pl.size() >= 2:
		for seg in Geometry2D.intersect_polyline_with_polygon(pl, poly):
			ci.draw_polyline(seg, Pal.ink(0.12), 1.0)
	ci.draw_circle(c, 1.5, Pal.ink(0.25))


func draw_joints_of(ci: CanvasItem, list: Array) -> void:
	var ids := {}
	for p in list:
		ids[p.id] = p
	var dots := PackedVector2Array()
	var rects: Array = []
	var welds := PackedVector2Array()
	for j in joints:
		if not j.alive or not ids.has(j.a):
			continue
		var pa = ids[j.a]
		var pos: Vector2 = j.pos + door_offset(pa)
		if pa.room != "" and rooms.has(pa.room) and not rooms[pa.room].revealed and pa.body == null:
			continue
		match j.type:
			"bolt":
				dots.append(pos)
			"lock":
				rects.append(pos)
			"weld":
				welds.append(pos - Vector2(1.6, 0))
				welds.append(pos + Vector2(1.6, 0))
	if not welds.is_empty():
		ci.draw_multiline(welds, Pal.ink(0.25), 1.0)
	if not dots.is_empty():
		# bolt heads: an ink disc with a dark centre, all in one triangle array
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for c in dots:
			for ring in 2:
				var r := 2.6 if ring == 0 else 1.1
				var col := Pal.ink(0.75) if ring == 0 else Pal.BG
				var b0 := pts.size()
				pts.append(c)
				cols.append(col)
				for i in 8:
					pts.append(c + BOLT_RING[i] * r)
					cols.append(col)
				for i in 8:
					idx.append(b0)
					idx.append(b0 + 1 + i)
					idx.append(b0 + 1 + (i + 1) % 8)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
	for pos in rects:
		ci.draw_rect(Rect2(pos - Vector2(3.2, 2.4), Vector2(6.4, 4.8)), Pal.ink(0.8), false, 1.2)
		ci.draw_rect(Rect2(pos - Vector2(1.2, 1.0), Vector2(2.4, 2.0)), Pal.ink(0.8))


func _draw_pieces() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_pieces_inner()
	_p("draw_static", t0)


func _draw_pieces_inner() -> void:
	var list: Array = []
	for id in order:
		var p = pieces[id]
		if p.gone or p.body != null:
			continue
		list.append(p)
	draw_pieces(piece_layer, list)
	draw_joints_of(piece_layer, list)


func _draw_back() -> void:
	for n in rooms:
		var r = rooms[n]
		var poly: PackedVector2Array = r.poly
		var k := 1.0
		if r.has("shell0") and r.shell0 > 0.0:
			k = clampf(_room_shell(r) / r.shell0, 0.0, 1.0)
			k = pow(k, 0.6)
		if k < 0.02:
			continue
		var base := Color(0.058, 0.061, 0.07) if r.revealed else Color(0.03, 0.031, 0.035)
		back_layer.draw_colored_polygon(poly, Color(base.r, base.g, base.b, k))
		if not r.revealed:
			continue
		if not r.has("grid"):
			r.grid = _room_grid(r)
		if r.grid[0].size() >= 2:
			back_layer.draw_multiline(r.grid[0], Pal.ink(0.045 * k), 1.0)
		if r.grid[1].size() >= 2:
			back_layer.draw_multiline(r.grid[1], Pal.ink(0.03 * k), 1.0)


# the panel seams on a room's back wall never move: clip them once
func _room_grid(r) -> Array:
	var poly: PackedVector2Array = r.poly
	var bb: Rect2 = r.bbox
	var vs := PackedVector2Array()
	var hs := PackedVector2Array()
	var x := bb.position.x + 30.0
	while x < bb.end.x:
		var pl := PackedVector2Array([Vector2(x, bb.position.y - 2), Vector2(x, bb.end.y + 2)])
		for seg in Geometry2D.intersect_polyline_with_polygon(pl, poly):
			for i in seg.size() - 1:
				vs.append(seg[i])
				vs.append(seg[i + 1])
		x += Geom.M * 1.2
	var y := bb.position.y + Geom.M * 1.6
	while y < bb.end.y:
		var pl := PackedVector2Array([Vector2(bb.position.x - 2, y), Vector2(bb.end.x + 2, y)])
		for seg in Geometry2D.intersect_polyline_with_polygon(pl, poly):
			for i in seg.size() - 1:
				hs.append(seg[i])
				hs.append(seg[i + 1])
		y += Geom.M * 1.6
	return [vs, hs]


func _draw_light() -> void:
	if game == null or game.sys == null:
		return
	var lamps: Dictionary = game.ship.get("power", {}).get("lamps", {})
	for n in lamps:
		var lamp = tag(lamps[n])
		if lamp == null or lamp.body != null:
			continue
		if rooms.has(n):
			if not rooms[n].revealed or not rooms[n].lit:
				continue
		elif not lamp.get_meta("lit", false):
			continue
		var c := frame(lamp) * Geom.centroid(lamp.poly)
		var tex: Texture2D = game.fx.glow_tex
		var rad := Geom.M * 3.2
		light_layer.draw_texture_rect(tex, Rect2(c - Vector2(rad, rad * 0.6), Vector2(rad * 2.0, rad * 2.2)), false, Color(1.0, 0.93, 0.82, 0.07))
		light_layer.draw_texture_rect(tex, Rect2(c - Vector2(22, 10), Vector2(44, 26)), false, Color(1.0, 0.95, 0.85, 0.35))


func _draw_cover() -> void:
	for n in rooms:
		var r = rooms[n]
		if r.revealed and r.reveal_t >= 1.0:
			continue
		var poly: PackedVector2Array = r.poly
		var cover_c := Color(0.026, 0.027, 0.031)
		if not r.revealed:
			cover_layer.draw_colored_polygon(poly, cover_c)
			_hatch(cover_layer, poly, r.bbox)
			continue
		var k := Pal.ease_out(r.reveal_t)
		var far := 0.0
		for q in poly:
			far = maxf(far, q.distance_to(r.from))
		var rad := far * k + 2.0
		var hole := Geom.circle(r.from, rad, 40)
		for q in Geometry2D.clip_polygons(poly, hole):
			if Geom.valid(q):
				cover_layer.draw_colored_polygon(q, Color(cover_c.r, cover_c.g, cover_c.b, 1.0 - k * 0.35))
		var ring := PackedVector2Array(hole)
		ring.append(hole[0])
		for seg in Geometry2D.intersect_polyline_with_polygon(ring, poly):
			cover_layer.draw_polyline(seg, Pal.ink(0.7 * (1.0 - k)), 2.0, true)


func _hatch(ci: CanvasItem, poly: PackedVector2Array, bb: Rect2) -> void:
	var pl := PackedVector2Array()
	var s := 22.0
	var x := bb.position.x - bb.size.y
	while x < bb.end.x:
		var seg := PackedVector2Array([Vector2(x, bb.end.y), Vector2(x + bb.size.y, bb.position.y)])
		for q in Geometry2D.intersect_polyline_with_polygon(seg, poly):
			ci.draw_polyline(q, Pal.ink(0.022), 1.0)
		x += s


func _draw_lines() -> void:
	for id in lines:
		var l = lines[id]
		var pa = pieces.get(l.a)
		var pb = pieces.get(l.b)
		if pa == null or pb == null or pa.body != null or pb.body != null:
			continue
		var room := room_at(l.path[l.path.size() / 2])
		if room != "" and not rooms[room].revealed and not l.net in ["fuel"]:
			continue
		if l.alive:
			_draw_line_path(line_layer, l, l.path, 1.0)
		else:
			# a cut line hangs as two stubs
			var cut: Vector2 = l.cut_at if l.cut_at != Vector2.INF else l.path[l.path.size() / 2]
			var a_side := PackedVector2Array()
			var b_side := PackedVector2Array()
			var passed := false
			for i in l.path.size():
				var q: Vector2 = l.path[i]
				if not passed:
					a_side.append(q)
					if i + 1 < l.path.size() and Geom.dist_to_segment(cut, q, l.path[i + 1]) < 6.0:
						a_side.append(cut + (q - cut).limit_length(5.0))
						b_side.append(cut + (l.path[i + 1] - cut).limit_length(5.0))
						passed = true
				else:
					b_side.append(q)
			if a_side.size() >= 2 and pieces[l.a] != null and not pieces[l.a].gone:
				_draw_line_path(line_layer, l, a_side, 0.5)
			if b_side.size() >= 2 and pieces[l.b] != null and not pieces[l.b].gone:
				_draw_line_path(line_layer, l, b_side, 0.5)


func _draw_line_path(ci: CanvasItem, l, path: PackedVector2Array, a: float) -> void:
	if l.kind == "cable":
		ci.draw_polyline(path, Pal.ink(0.38 * a), 1.6, true)
	else:
		ci.draw_polyline(path, Pal.ink(0.5 * a), 4.2, true)
		ci.draw_polyline(path, Color(0.05, 0.053, 0.06, 1.0), 2.0, true)


# kerf edges glow, then cool: white-hot -> orange -> dull red -> gone
func draw_heat(ci: CanvasItem, p) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for h in p.heat:
		var age: float = now - h[1]
		var k := clampf(1.0 - age / 3.0, 0.0, 1.0)
		if k <= 0.0:
			continue
		var pl: PackedVector2Array = h[0]
		var hot := k * k
		if pl.size() < 2:
			if pl.size() == 1:
				ci.draw_circle(pl[0], KERF * 1.3, Pal.heat(0.55 * k, 1.0 + 2.2 * hot))
			continue
		ci.draw_polyline(pl, Pal.heat(0.55 * k, 1.0 + 2.2 * hot), KERF * 2.6)
		ci.draw_polyline(pl, Pal.heat(0.9 * hot, 1.6 + 2.5 * hot), 1.6)


func _draw_heat_static() -> void:
	for id in order:
		var p = pieces[id]
		if not p.gone and p.body == null and not p.heat.is_empty():
			draw_heat(heat_layer, p)
