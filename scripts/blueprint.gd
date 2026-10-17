class_name Blueprint
extends Node2D
# The manufacturer's drawing, laid over the ship with Tab: rooms, ports,
# valves, pipe and cable runs and where the equipment was designed to sit.
# It is the original design, not the ship as it is now (the ship file's
# blueprint section moves things back to where they were drawn).

var game: Game
var on := false
var k := 0.0
var rooms: Array = []     # [poly, label key, label pos]
var equip: Array = []     # [poly, tag]
var runs: Array = []      # [path, label, kind]
var points: Array = []    # [pos, label, kind]
var font: Font
var snapped := false
var t := 0.0
var x0 := -2.0 * 48.0     # drawn extent (px), from the ship's own size
var x1 := 46.0 * 48.0
var y_top := -4.0 * 48.0
# "my engineering notes": what earlier ships of this type showed the operator's own hands
var notes: Dictionary = {}
var start_fix := {}         # tag -> fixings each noted piece had when the contract began
var note_polys: Array = []   # [poly, tag, info]
var note_runs: Array = []    # [path, id]
var note_points: Array = []  # [pos, text]
var notes_said := false


func _init() -> void:
	z_index = 8
	z_as_relative = false
	font = Fonts.get_font("Regular")


func snapshot() -> void:
	# always the factory ship, whatever state the real one is in
	var d: Dictionary = game.ship
	var bp: Dictionary = d.get("blueprint", {})
	var w := World.new()
	Ship.build(w, d)
	for n in w.rooms:
		var r = w.rooms[n]
		rooms.append([r.poly, Ship.room_name_key(d, n), r.bbox.position + Vector2(10, 22)])
	var bb := Rect2()
	var first := true
	for id in w.order:
		var p = w.pieces[id]
		var pb := Geom.bbox(p.poly)
		bb = pb if first else bb.merge(pb)
		first = false
		if p.cls == "equip" or p.kind == "fixture":
			if p.tag in bp.get("hide", []):
				continue
			var poly: PackedVector2Array = p.poly
			var design: Dictionary = bp.get("design", {})
			if design.has(p.tag):
				var r4: Array = design[p.tag]
				poly = Geom.rect_poly(Geom.mrect(r4[0], r4[1], r4[2], r4[3]))
			equip.append([poly, p.tag])
	x0 = bb.position.x - 2.0 * 48.0
	x1 = bb.end.x + 2.0 * 48.0
	y_top = bb.position.y
	var drawn_lines: Dictionary = bp.get("lines", {})
	for id in w.lines:
		var l = w.lines[id]
		var path: PackedVector2Array = l.path
		# a run that was changed after the drawing: the drawing shows where it was meant to go
		if drawn_lines.has(id):
			path = PackedVector2Array()
			for q in drawn_lines[id]:
				path.append(Geom.m(q[0], q[1]))
		runs.append([path, l.id.to_upper(), l.kind])
	for id in w.ctrls:
		var c = w.ctrls[id]
		points.append([w.ctrl_world(c), c.id, c.kind])
	# extra runs the drawing shows (stubs that are not lines of their own)
	for run in bp.get("runs", []):
		var pts := PackedVector2Array()
		for q in run:
			pts.append(Geom.m(q[0], q[1]))
		runs.append([pts, "", "pipe"])
	# the designed clamps
	for c in game.dock.clamps:
		points.append([c * 48.0, "", "clamp"])
	# my engineering notes, laid on the factory layout
	notes = game.notes()
	for tg in notes.get("pieces", {}):
		var p = w.tag(tg)
		if p != null:
			note_polys.append([p.poly, tg, notes.pieces[tg]])
		var live = game.world.tag(tg)
		if live != null:
			start_fix[tg] = game.world.joints_of(live).size()
	for id in notes.get("lines", {}):
		if w.lines.has(id):
			var l = w.lines[id]
			var path: PackedVector2Array = l.path
			if bp.get("lines", {}).has(id):
				path = PackedVector2Array()
				for q in bp.lines[id]:
					path.append(Geom.m(q[0], q[1]))
			note_runs.append([path, id.to_upper(), notes.lines[id]])
	for id in notes.get("ports", {}):
		if w.ctrls.has(id):
			note_points.append([w.ctrl_world(w.ctrls[id]), "✓ %s → %s" % [id, notes.ports[id]], id])
	for id in notes.get("ctrls", {}):
		if w.ctrls.has(id) and not notes.get("ports", {}).has(id):
			note_points.append([w.ctrl_world(w.ctrls[id]), "✓ " + id, id])
	w.free()


func toggle() -> void:
	on = not on
	game.sfx.play("blueprint_on" if on else "blueprint_off")
	if on and has_notes() and not notes_said:
		notes_said = true
		Copy.say(game.radio, "L_notes_first")


# has the thing a note is about changed on this ship since the contract began?
#   a piece: lost a fixing, been cut, or come loose; a line: cut; a control: operated
func note_void(key: String) -> bool:
	if game.changed.has(key):
		return true
	if key.begins_with("p:"):
		var p = game.world.tag(key.substr(2))
		if p == null or p.gone:
			return true
		return game.world.joints_of(p).size() < int(start_fix.get(key.substr(2), 0)) or not p.intact or not p.heat.is_empty() or p.body != null
	return false


func has_notes() -> bool:
	return not (notes.get("pieces", {}).is_empty() and notes.get("ports", {}).is_empty() and notes.get("lines", {}).is_empty() and notes.get("ctrls", {}).is_empty())


# the notes panel rows: [label, value]; the state of this ship's accident is never in the notes
func notes_rows() -> Array:
	var n := 0
	for k in ["pieces", "ports", "lines", "ctrls"]:
		n += notes.get(k, {}).size()
	return [[game.txt("nt_checked"), str(n)], [game.txt("nt_ships"), str(int(notes.get("ships", 0)))], [game.txt("nt_now"), game.txt("nt_unverified")]]


func _process(dt: float) -> void:
	t += dt
	var was := k
	k = Pal.damp(k, 1.0 if on else 0.0, 10.0, dt)
	if absf(k - was) > 0.001 or k > 0.01:
		queue_redraw()
	# once: a ship with no rooms (the assessment module) left this empty and
	# the drawing was rebuilt every frame
	if not snapped and game != null and game.world != null:
		snapped = true
		snapshot()


func _dash(a: Vector2, b: Vector2, c: Color, w: float, seg: float = 7.0) -> void:
	var l := a.distance_to(b)
	if l < 0.5:
		return
	var n := maxi(1, int(l / seg))
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), c, w)


func _dpoly(poly: PackedVector2Array, c: Color, w: float) -> void:
	for i in poly.size():
		_dash(poly[i], poly[(i + 1) % poly.size()], c, w)


func _dpath(path: PackedVector2Array, c: Color, w: float) -> void:
	for i in path.size() - 1:
		_dash(path[i], path[i + 1], c, w, 5.0)


# Labels are drawn at their size on screen, whatever the zoom: rasterised at
# native pixels and never stretched by the camera (stretching made them blur),
# on a dark backing so they read over the hull lines.
var _z := 1.0
var _placed: Array = []      # label rects this frame, in screen-scale units


# a point label: the first of a few spots beside the point that is still free
func _point_label(at: Vector2, text: String, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 6.0
	var base := at * _z
	for off in [Vector2(8, -7), Vector2(8, 19), Vector2(8, -25), Vector2(8, 37), Vector2(-w - 8, -7), Vector2(-w - 8, 19)]:
		var r := Rect2(base + off + Vector2(-3, -14), Vector2(w, 18))
		if not _placed.any(func(q): return q.intersects(r)):
			_placed.append(r)
			_label(at, text, 14, col, off)
			return
	_label(at, text, 14, col, Vector2(8, -7))


func _label(at: Vector2, text: String, size_px: int, col: Color, off: Vector2 = Vector2(4, -4)) -> void:
	if text == "":
		return
	draw_set_transform(at, 0.0, Vector2.ONE / _z)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_rect(Rect2(off + Vector2(-3, -size_px * 0.95), Vector2(w + 6, size_px * 1.25)), Color(0.02, 0.03, 0.05, 0.72 * k))
	draw_string(font, off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if k < 0.01:
		return
	var z: float = game.cam_zoom()
	_z = z
	_placed = []
	var lw := 1.1 / z
	var a := k
	var col := Color(0.62, 0.86, 1.0, 0.75 * a)
	var dim := Color(0.62, 0.86, 1.0, 0.35 * a)
	# sweep: the drawing draws itself from bow to stern
	var sweep := x0 + Pal.ease_out(k) * (x1 - x0)
	draw_rect(Rect2(x0, -6.0 * 48.0, minf(sweep - x0, x1 - x0), 12.0 * 48.0), Color(0.02, 0.03, 0.05, 0.55 * a))
	for r in rooms:
		_dpoly(r[0], col, lw * 1.3)
		_label(r[2], game.txt(r[1]), 17, col, Vector2.ZERO)
	for e in equip:
		if Geom.bbox(e[0]).position.x > sweep:
			continue
		_dpoly(e[0], dim, lw)
		_label(Geom.bbox(e[0]).position, e[1], 13, Color(0.62, 0.86, 1.0, 0.6 * a))
	for r in runs:
		var path: PackedVector2Array = r[0]
		if path.is_empty() or path[0].x > sweep:
			continue
		_dpath(path, Color(0.62, 0.86, 1.0, (0.55 if r[2] == "pipe" else 0.4) * a), lw * (1.6 if r[2] == "pipe" else 1.0))
		if r[1] != "":
			_label(path[path.size() / 2], r[1], 12, Color(0.62, 0.86, 1.0, 0.55 * a))
	for p in points:
		var pos: Vector2 = p[0]
		if pos.x > sweep:
			continue
		var s := 5.0 / z
		match p[2]:
			"valve":
				draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, 0), pos + Vector2(0, s), pos + Vector2(-s, 0)]), col)
			"port", "test", "discharge", "socket", "probe", "degauss", "seal":
				draw_arc(pos, s, 0.0, TAU, 14, col, lw * 1.4, true)
			"clamp":
				draw_rect(Rect2(pos - Vector2(s, 0), Vector2(s * 2, s)), dim, false, lw)
			_:
				draw_rect(Rect2(pos - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), col, false, lw)
		if p[1] != "":
			_point_label(pos, p[1], Color(0.62, 0.86, 1.0, 0.9 * a))
	_label(Vector2(x0 + 2.0 * 48.0, y_top - 1.2 * 48.0), game.ship.get("name", "") + "  ·  " + game.txt("blueprint"), 18, col, Vector2.ZERO)
	if has_notes():
		_draw_notes(lw, a)


# what my own hands checked on earlier ships of the type: solid, warm, ticked
func _draw_notes(lw: float, a: float) -> void:
	var nc := Color(1.0, 0.78, 0.45, 0.85 * a)
	# a note on something that has changed on this ship since the contract began is void
	var vc := Color(nc.r, nc.g, nc.b, nc.a * 0.35)
	var void_s: String = "  · " + game.txt("nt_void")
	for np in note_polys:
		var poly: PackedVector2Array = np[0]
		var cl := poly.duplicate()
		cl.append(poly[0])
		var dead := note_void("p:" + np[1])
		draw_polyline(cl, vc if dead else nc, lw * 1.6, true)
		var info = np[2]
		var txt: String = "✓ " + np[1]
		if info is Dictionary and info.has("fix"):
			txt += "  " + str(info.fix)
		_label(Geom.bbox(poly).end + Vector2(2, 0), txt + (void_s if dead else ""), 12, vc if dead else nc)
	for r in note_runs:
		var dead2 := note_void("l:" + r[1].to_lower())
		draw_polyline(r[0], vc if dead2 else nc, lw * 2.2, true)
		var ends = r[2]
		var txt2: String = "✓ " + r[1]
		if ends is Array and ends.size() == 2:
			txt2 += "  %s → %s" % [ends[0], ends[1]]
		_label(r[0][r[0].size() / 2], txt2 + (void_s if dead2 else ""), 12, vc if dead2 else nc, Vector2(4, 14))
	for p in note_points:
		var dead3 := note_void("c:" + p[2])
		_point_label(p[0], p[1] + (void_s if dead3 else ""), vc if dead3 else nc)
	# the panel: how much is in the notes, and that none of it is about this ship's accident
	var rows := notes_rows()
	var at := Vector2(x0 + 2.0 * 48.0, y_top - 4.8 * 48.0)
	_label(at, game.txt("nt_title"), 16, nc, Vector2.ZERO)
	for i in rows.size():
		_label(at + Vector2(0, (i + 1) * 0.5 * 48.0), "%s  %s" % rows[i], 13, nc if i < 2 else Pal.heat(0.9 * a, 1.2), Vector2.ZERO)
