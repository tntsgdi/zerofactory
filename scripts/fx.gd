class_name Fx
extends Node2D
# Short-lived marks in world space: sparks, molten slag, rings, shards, gas
# mist, fluid sprays, arcs, glow flashes, value numbers and the slow dust of
# the dock. Pooled in plain arrays, drawn in one pass per layer.

var game: Game
var sparks_l: Array = []   # [pos, vel, t, dur, color, width, len, drag]
var slag: Array = []       # [pos, vel, t, dur, size]
var rings: Array = []      # [pos, r0, r1, t, dur, color, width]
var shards: Array = []     # [pos, a, b, rot, vel, spin, t, dur, color, width]
var mist: Array = []       # [pos, vel, t, dur, r0, r1, color]
var drops: Array = []      # [pos, vel, t, dur, color]
var arcs: Array = []       # [a, b, t, dur, k, seed]
var flashes: Array = []    # [pos, r, t, dur, color]
var numbers: Array = []    # [text, pos, vel, t, dur, size, color]
var motes: Array = []      # [pos, vel, phase, size]
var add_layer: Node2D
var glow_tex: Texture2D
var soft_tex: Texture2D
var num_font: Font
var batch := Batch.new()
var bounds := Rect2(-8 * 48, -15 * 48, 64 * 48, 25 * 48)


func _init() -> void:
	z_index = 5
	z_as_relative = false
	add_layer = Node2D.new()
	add_layer.z_index = 7
	add_layer.z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = m
	add_layer.draw.connect(_draw_add)
	add_child(add_layer)
	glow_tex = make_glow_texture(2.0)
	soft_tex = make_glow_texture(1.0)
	num_font = Fonts.get_font("Medium")
	for i in 160:
		motes.append([Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y)),
			Vector2.from_angle(randf() * TAU) * randf_range(3.0, 9.0), randf() * TAU, randf_range(0.7, 1.6)])


static func make_glow_texture(p: float) -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, pow(a, p)))
	return ImageTexture.create_from_image(img)


func spark(pos: Vector2, vel: Vector2, dur: float, c: Color, w: float = 1.4, l: float = 9.0, drag: float = 4.0) -> void:
	if sparks_l.size() >= 900:
		return
	sparks_l.append([pos, vel, 0.0, dur, c, w, l, drag])


func sparks(pos: Vector2, dir: Vector2, n: int, c: Color, speed: float, dur: float, spread: float = 0.9) -> void:
	for i in n:
		var a := dir.angle() + randf_range(-spread, spread)
		spark(pos, Vector2.from_angle(a) * speed * randf_range(0.35, 1.0), dur * randf_range(0.5, 1.0), c, randf_range(1.0, 2.0), randf_range(5.0, 13.0), randf_range(1.5, 5.0))


func molten(pos: Vector2, vel: Vector2, dur: float = 1.6) -> void:
	if slag.size() >= 400:
		return
	slag.append([pos, vel, 0.0, dur * randf_range(0.6, 1.2), randf_range(1.0, 2.4)])


func ring(pos: Vector2, r0: float, r1: float, dur: float, c: Color, w: float = 1.5) -> void:
	if rings.size() >= 120:
		return
	rings.append([pos, r0, r1, 0.0, dur, c, w])


func shard(pos: Vector2, a: Vector2, b: Vector2, vel: Vector2, spin: float, dur: float, c: Color, w: float = 1.6) -> void:
	if shards.size() >= 260:
		return
	shards.append([pos, a, b, 0.0, vel, spin, 0.0, dur, c, w])


func burst_shards(pos: Vector2, n: int, speed: float, c: Color, size: float = 8.0) -> void:
	for i in n:
		var d := Vector2.from_angle(randf() * TAU)
		var a := Vector2.from_angle(randf() * TAU) * size * randf_range(0.4, 1.0)
		shard(pos, a, -a * randf_range(0.3, 0.8), d * speed * randf_range(0.3, 1.0), randf_range(-8, 8), randf_range(0.6, 1.4), c, randf_range(1.0, 2.0))


func puff(pos: Vector2, vel: Vector2, dur: float, r0: float, r1: float, c: Color) -> void:
	if mist.size() >= 700:
		mist.remove_at(0)
	mist.append([pos, vel, 0.0, dur, r0, r1, c])


func drop(pos: Vector2, vel: Vector2, dur: float, c: Color) -> void:
	if drops.size() >= 600:
		return
	drops.append([pos, vel, 0.0, dur, c])


func arc(a: Vector2, b: Vector2, dur: float, k: float = 1.0) -> void:
	if arcs.size() >= 40:
		return
	arcs.append([a, b, 0.0, dur, k, randi()])


func flash(pos: Vector2, r: float, dur: float, c: Color) -> void:
	if flashes.size() >= 300:
		return
	flashes.append([pos, r, 0.0, dur, c])


func number(pos: Vector2, text: String, c: Color, size: int = 22) -> void:
	if numbers.size() >= 40:
		numbers.remove_at(0)
	numbers.append([text, pos, Vector2(randf_range(-20, 20), -90.0), 0.0, 1.1, size, c])


func push_motes(center: Vector2, radius: float, strength: float) -> void:
	for m in motes:
		var d: Vector2 = m[0] - center
		var l := d.length()
		if l < radius and l > 1.0:
			m[1] += d / l * strength * (1.0 - l / radius)


func step(dt: float) -> void:
	_age(sparks_l, 2, 3, dt)
	for s in sparks_l:
		s[0] += s[1] * dt
		s[1] *= exp(-s[7] * dt)
	_age(slag, 2, 3, dt)
	for s in slag:
		s[0] += s[1] * dt
		s[1] *= exp(-0.6 * dt)
	_age(rings, 3, 4, dt)
	_age(shards, 6, 7, dt)
	for s in shards:
		s[0] += s[4] * dt
		s[4] *= exp(-0.8 * dt)
		s[3] += s[5] * dt
	_age(mist, 2, 3, dt)
	for s in mist:
		s[0] += s[1] * dt
		s[1] *= exp(-1.6 * dt)
	_age(drops, 2, 3, dt)
	for s in drops:
		s[0] += s[1] * dt
		s[1] *= exp(-0.4 * dt)
	_age(arcs, 2, 3, dt)
	_age(numbers, 3, 4, dt)
	for n in numbers:
		n[1] += n[2] * dt
		n[2] *= exp(-3.0 * dt)
	_age(flashes, 2, 3, dt)
	for m in motes:
		m[2] += dt
		m[0] += (m[1] + Vector2(sin(m[2] * 0.31), cos(m[2] * 0.27)) * 3.0) * dt
		m[1] = Pal.damp2(m[1], m[1].normalized() * 6.0, 0.6, dt)
		if not bounds.has_point(m[0]):
			m[0] = Vector2(fposmod(m[0].x - bounds.position.x, bounds.size.x) + bounds.position.x, fposmod(m[0].y - bounds.position.y, bounds.size.y) + bounds.position.y)
	queue_redraw()
	add_layer.queue_redraw()


func _age(arr: Array, ti: int, di: int, dt: float) -> void:
	var i := 0
	while i < arr.size():
		arr[i][ti] += dt
		if arr[i][ti] >= arr[i][di]:
			arr.remove_at(i)
		else:
			i += 1


func _draw() -> void:
	for m in motes:
		var a := 0.06 + 0.04 * sin(m[2] * 0.7 + m[3] * 3.0)
		batch.dot(m[0], m[3] * 1.9, Pal.ink(a))
	batch.flush(self, soft_tex)
	for s in mist:
		var k: float = s[2] / s[3]
		var r: float = lerpf(s[4], s[5], Pal.ease_out(k))
		var c: Color = s[6]
		draw_texture_rect(soft_tex, Rect2(s[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, c.a * (1.0 - k) * (1.0 - k)))
	for s in drops:
		var k2: float = 1.0 - s[2] / s[3]
		var c2: Color = s[4]
		var v: Vector2 = s[1]
		draw_line(s[0], s[0] - v * 0.03, Color(c2.r, c2.g, c2.b, c2.a * k2), 2.0, true)
	for s in shards:
		var k3: float = 1.0 - s[6] / s[7]
		var c3: Color = s[8]
		var tr := Transform2D(s[3], s[0])
		draw_line(tr * s[1], tr * s[2], Color(c3.r, c3.g, c3.b, c3.a * Pal.ease_out(k3 * 1.6)), s[9], true)
	for r in rings:
		var e := Pal.ease_out(r[3] / r[4])
		var c4: Color = r[5]
		var rad := lerpf(r[1], r[2], e)
		draw_arc(r[0], rad, 0.0, TAU, maxi(20, int(rad * 0.5)), Color(c4.r, c4.g, c4.b, c4.a * (1.0 - e)), r[6] * (1.0 - 0.6 * e), true)
	for n in numbers:
		var t: float = n[3]
		var pop := lerpf(1.6, 1.0, Pal.back(t / 0.16, 2.2))
		var a2 := clampf((n[4] - t) / 0.3, 0.0, 1.0)
		var c5: Color = n[6]
		var txt: String = n[0]
		var size: int = n[5]
		var w := num_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_set_transform(n[1], 0.0, Vector2(pop, pop))
		draw_string(num_font, Vector2(-w / 2.0 + 1.5, size * 0.35 + 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * a2))
		draw_string(num_font, Vector2(-w / 2.0, size * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c5.r, c5.g, c5.b, a2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_add() -> void:
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	for s in sparks_l:
		var k: float = 1.0 - s[2] / s[3]
		var v: Vector2 = s[1]
		var dir := v.normalized() if v.length_squared() > 1.0 else Vector2.RIGHT
		var l: float = s[6] * (0.3 + 0.7 * k) + v.length() * 0.014
		var c: Color = s[4]
		segs.append(s[0])
		segs.append(s[0] - dir * l)
		cols.append(Color(c.r, c.g, c.b, c.a * k))
	if segs.size() > 0:
		add_layer.draw_multiline_colors(segs, cols, 1.5)
	for s in slag:
		var k: float = s[2] / s[3]
		# white-hot to orange to a dull ember
		var c := Pal.heat(1.0 - k, 2.6 - 2.0 * k) if k < 0.85 else Color(0.35, 0.1, 0.05, (1.0 - k) * 4.0)
		batch.dot(s[0], s[4] * (1.0 - k * 0.5) * 1.7, c)
	batch.flush(add_layer, soft_tex)
	for a in arcs:
		_draw_arc_bolt(a)
	for fl in flashes:
		var k2: float = 1.0 - fl[2] / fl[3]
		var r: float = fl[1] * (0.6 + 0.4 * Pal.ease_out(fl[2] / fl[3] * 2.0))
		var c2: Color = fl[4]
		add_layer.draw_texture_rect(glow_tex, Rect2(fl[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c2.r, c2.g, c2.b, c2.a * k2 * k2))


func _draw_arc_bolt(a: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = a[5] + int(a[2] * 40.0)
	var p0: Vector2 = a[0]
	var p1: Vector2 = a[1]
	var k: float = 1.0 - a[2] / a[3]
	var n := 9
	var pts := PackedVector2Array()
	var dir := p1 - p0
	var nrm := Vector2(-dir.y, dir.x).normalized()
	for i in n + 1:
		var t := float(i) / n
		var off: float = 0.0 if i == 0 or i == n else rng.randf_range(-1.0, 1.0) * dir.length() * 0.16 * a[4]
		pts.append(p0 + dir * t + nrm * off)
	var c := Pal.tint(Pal.VOLT, k, 2.4)
	add_layer.draw_polyline(pts, Pal.tint(Pal.VOLT, 0.35 * k, 1.4), 7.0, true)
	add_layer.draw_polyline(pts, c, 2.0, true)
	add_layer.draw_polyline(pts, Color(1.6, 1.6, 1.8, k), 0.8, true)
	if rng.randf() < 0.6:
		var bi := rng.randi_range(2, n - 2)
		var bp := pts[bi]
		var be := bp + Vector2.from_angle(rng.randf() * TAU) * dir.length() * 0.3
		add_layer.draw_line(bp, be, c, 1.2, true)
