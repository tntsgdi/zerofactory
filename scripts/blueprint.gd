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
var t := 0.0
var x0 := -2.0 * 48.0     # drawn extent (px), from the ship's own size
var x1 := 46.0 * 48.0
var y_top := -4.0 * 48.0


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
	for id in w.lines:
		var l = w.lines[id]
		runs.append([l.path, l.id.to_upper(), l.kind])
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
	w.free()


func toggle() -> void:
	on = not on
	game.sfx.play("blueprint_on" if on else "blueprint_off")


func _process(dt: float) -> void:
	t += dt
	var was := k
	k = Pal.damp(k, 1.0 if on else 0.0, 10.0, dt)
	if absf(k - was) > 0.001 or k > 0.01:
		queue_redraw()
	if rooms.is_empty() and game != null and game.world != null:
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


func _draw() -> void:
	if k < 0.01:
		return
	var z: float = game.cam_zoom()
	var lw := 1.1 / z
	var a := k
	var col := Color(0.62, 0.86, 1.0, 0.75 * a)
	var dim := Color(0.62, 0.86, 1.0, 0.35 * a)
	# sweep: the drawing draws itself from bow to stern
	var sweep := x0 + Pal.ease_out(k) * (x1 - x0)
	draw_rect(Rect2(x0, -6.0 * 48.0, minf(sweep - x0, x1 - x0), 12.0 * 48.0), Color(0.02, 0.03, 0.05, 0.55 * a))
	for r in rooms:
		_dpoly(r[0], col, lw * 1.3)
		draw_string(font, r[2], game.txt(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(14.0 / z * 1.2), col)
	for e in equip:
		if Geom.bbox(e[0]).position.x > sweep:
			continue
		_dpoly(e[0], dim, lw)
		draw_string(font, Geom.bbox(e[0]).position + Vector2(3, -3), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.0 / z * 1.2), dim)
	for r in runs:
		var path: PackedVector2Array = r[0]
		if path.is_empty() or path[0].x > sweep:
			continue
		_dpath(path, Color(0.62, 0.86, 1.0, (0.55 if r[2] == "pipe" else 0.4) * a), lw * (1.6 if r[2] == "pipe" else 1.0))
		if r[1] != "":
			draw_string(font, path[path.size() / 2] + Vector2(3, -3), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(9.0 / z * 1.2), dim)
	for p in points:
		var pos: Vector2 = p[0]
		if pos.x > sweep:
			continue
		var s := 5.0 / z
		match p[2]:
			"valve":
				draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, 0), pos + Vector2(0, s), pos + Vector2(-s, 0)]), col)
			"port", "test", "discharge", "socket":
				draw_arc(pos, s, 0.0, TAU, 14, col, lw * 1.4, true)
			"clamp":
				draw_rect(Rect2(pos - Vector2(s, 0), Vector2(s * 2, s)), dim, false, lw)
			_:
				draw_rect(Rect2(pos - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), col, false, lw)
		if p[1] != "":
			draw_string(font, pos + Vector2(7.0 / z, -6.0 / z), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 / z * 1.2), col)
	draw_string(font, Vector2(x0 + 2.0 * 48.0, y_top - 1.2 * 48.0), game.ship.get("name", "") + "  ·  " + game.txt("blueprint"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15.0 / z * 1.2), col)
