class_name TutorialHud
extends CanvasLayer
# What the training course puts on screen: the task list (top left), the
# radio line (bottom centre, above the toolbar), the target marker, the
# lesson-1 flight course in the world, the A/B question, locks on the tools
# the lesson has not opened yet, and the certificate at the end.
# Everything enters in under 0.25 s and finishes in under 0.6 s.

var game: Game
var c: Control
var fadd: Control
var world_layer: Node2D
var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var row_shift := 0.0            # the task list slides up as a step completes
var tick_t := 9.0               # the tick drawing itself on the step just done
var last_step := ""
var done_text := ""
var choice_k := 0.0
var lock_shake := 0.0
var stamp_t := -1.0


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_ui)
	add_child(c)
	fadd = Control.new()
	fadd.set_anchors_preset(Control.PRESET_FULL_RECT)
	fadd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fadd.material = m
	fadd.draw.connect(_draw_glow)
	add_child(fadd)
	# the rings live in the world, glowing
	world_layer = Node2D.new()
	world_layer.z_index = 9
	world_layer.z_as_relative = false
	var m2 := CanvasItemMaterial.new()
	m2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	world_layer.material = m2
	world_layer.draw.connect(_draw_world)
	game.add_child(world_layer)
	game.tutorial.step_changed.connect(_on_step)
	game.tutorial.finished.connect(func(): stamp_t = 0.0)


func _on_step() -> void:
	var tut := game.tutorial
	if last_step != "":
		tick_t = 0.0
		row_shift = 1.0
	last_step = tut.step().get("id", "")


func _input(ev: InputEvent) -> void:
	if game == null or game.tutorial == null:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := c.get_local_mouse_position()
		if game.tutorial.choice_open():
			for i in 2:
				if _choice_rect(i).has_point(m):
					game.tutorial.pick("a" if i == 0 else "b")
					get_viewport().set_input_as_handled()
					return
		if game.tutorial.done and stamp_t > 1.2:
			# a special course: one way on (the next course, the contract, the terminal)
			if game.tutorial.special() != "":
				if _go_rect().has_point(m):
					get_viewport().set_input_as_handled()
					game.after_special()
				return
			for i in 2:
				if _choice_rect(i).has_point(m):
					get_viewport().set_input_as_handled()
					game.after_training("exam" if i == 0 else "contract")
					return


func _process(dt: float) -> void:
	if game == null or game.tutorial == null:
		return
	t += dt
	tick_t += dt
	row_shift = Pal.damp(row_shift, 0.0, 9.0, dt)
	choice_k = Pal.damp(choice_k, 1.0 if game.tutorial.choice_open() else 0.0, 14.0, dt)
	if game.tools.denied_t < 0.05:
		lock_shake = 1.0
	lock_shake = maxf(0.0, lock_shake - dt * 3.0)
	if stamp_t >= 0.0:
		var was := stamp_t
		stamp_t += dt
		if was < 0.18 and stamp_t >= 0.18:
			game.sfx.play("stamp")
			game.shake(0.35)
	c.queue_redraw()
	fadd.queue_redraw()
	world_layer.queue_redraw()


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	c.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


# ---------------------------------------------------------------- draw

func _draw_ui() -> void:
	if game.state != "play" or game.hud.ending:
		return
	var s := c.size
	_task_list()
	_marker(s)
	_tool_locks()
	if choice_k > 0.01:
		_choice(s, choice_k)
	if stamp_t >= 0.0:
		_certificate(s)


func _task_list() -> void:
	var tut := game.tutorial
	var x := 40.0
	var y := 46.0
	var sp: String = tut.special()
	_text(game.txt("tut_course") if sp == "" else Txt.t("cxu_sp_course") % Txt.t("cxu_cls_" + sp).split(" · ")[-1], Vector2(x, y), 13, Pal.ink(0.45))
	var ls: Array = tut.lessons()
	var li: int = mini(tut.lesson_i, ls.size() - 1)
	var l: Dictionary = ls[li] if li >= 0 else {}
	var head: String = game.txt("tut_lesson") % li + "  " + tut.text(l.get("title", "")) if li > 0 else tut.text(l.get("title", ""))
	_text(head, Vector2(x, y + 26), 22, Pal.ink(0.94), font_b)
	# lessons as a row of marks
	for i in range(1, ls.size()):
		var mx := x + (i - 1) * 22.0
		var my := y + 44.0
		var col := Pal.ink(0.9) if i < tut.lesson_i else (Pal.heat(1.0, 1.2) if i == tut.lesson_i else Pal.ink(0.2))
		c.draw_rect(Rect2(mx, my, 14, 3), col)
	if tut.done:
		_text(game.txt("tut_done"), Vector2(x, y + 80), 16, Pal.ink(0.8))
		return
	var mode: String = game.txt("tut_lockstep") if tut.lockstep() else game.txt("tut_goal")
	_text(mode, Vector2(x + (ls.size() - 1) * 22.0 + 6.0, y + 49), 11, Pal.ink(0.35))
	var steps: Array = l.get("steps", [])
	var si: int = tut.step_i
	var ry := y + 112.0 + row_shift * 26.0
	# the step just done, ticked and fading; the current one; the next one
	if si > 0 and tut.lockstep():
		var prev: Dictionary = steps[si - 1]
		var a := 0.35 * clampf(1.0 - (tick_t - 0.6) / 0.5, 0.4, 1.0)
		_tick(Vector2(x + 6, ry - 34), clampf(tick_t / 0.25, 0.0, 1.0), a + 0.3)
		_text(tut.text(prev.text), Vector2(x + 22, ry - 28), 14, Pal.ink(a))
	if si < steps.size():
		var cur: Dictionary = steps[si]
		var pop := Pal.back(clampf((1.0 - row_shift) * 1.2, 0.0, 1.0), 1.8)
		c.draw_rect(Rect2(x, ry - 16, 3, 22), Pal.heat(1.0, 1.0))
		_text(tut.text(cur.text), Vector2(x + 14 + (1.0 - pop) * 10.0, ry), 17, Pal.ink(0.96 * pop + 0.04))
		if tut.lockstep() and si + 1 < steps.size():
			_text(tut.text(steps[si + 1].text), Vector2(x + 14, ry + 28), 13, Pal.ink(0.28))
	if tut.hint_level >= 1:
		_text(game.txt("tut_q"), Vector2(x, ry + 60), 12, Pal.ink(0.4 + 0.2 * sin(t * 3.0)))


func _tick(p: Vector2, k: float, a: float) -> void:
	var pts := [p + Vector2(0, 6), p + Vector2(4, 10), p + Vector2(11, 1)]
	if k <= 0.0:
		return
	var l1 := clampf(k * 2.0, 0.0, 1.0)
	c.draw_line(pts[0], pts[0].lerp(pts[1], l1), Pal.ink(a), 2.0, true)
	if k > 0.5:
		c.draw_line(pts[1], pts[1].lerp(pts[2], (k - 0.5) * 2.0), Pal.ink(a), 2.0, true)


func _marker(s: Vector2) -> void:
	var tut := game.tutorial
	if tut.done:
		return
	var wp := tut.target_pos()
	if wp == Vector2.INF:
		return
	var sp: Vector2 = game.hud.to_screen(wp)
	var inside := Rect2(Vector2(40, 40), s - Vector2(80, 80)).has_point(sp)
	var strong := tut.hint_level >= 2
	if inside:
		var period := 1.2 if not strong else 0.6
		var ph := fposmod(t, period) / period
		var rr := lerpf(10.0, 46.0 if not strong else 70.0, Pal.ease_out(ph))
		c.draw_arc(sp, rr, 0.0, TAU, 40, Pal.heat((1.0 - ph) * (0.9 if strong else 0.6), 1.2), 2.0, true)
		c.draw_arc(sp, 7.0, 0.0, TAU, 20, Pal.heat(0.9, 1.3), 1.6, true)
		return
	# off screen: an arrow on the edge with the distance
	var ctr := s * 0.5
	var dir := (sp - ctr).normalized()
	var edge := ctr + dir * minf(absf((s.x * 0.5 - 60) / maxf(absf(dir.x), 0.001)), absf((s.y * 0.5 - 60) / maxf(absf(dir.y), 0.001)))
	var n := dir.orthogonal()
	c.draw_colored_polygon(PackedVector2Array([edge + dir * 14.0, edge - dir * 6.0 + n * 9.0, edge - dir * 6.0 - n * 9.0]), Pal.heat(0.9, 1.2))
	var dm: float = game.drone.global_position.distance_to(wp) / Geom.M
	_text("%d m" % int(round(dm)), edge - dir * 30.0 + Vector2(0, 5), 13, Pal.ink(0.8), font, 0)


func _tool_locks() -> void:
	var tut := game.tutorial
	if tut.done:
		return
	var tr: Rect2 = game.hud._toolbar_rect()
	for i in 5:
		if tut.tool_allowed(i + 1):
			continue
		var r := Rect2(tr.position.x + i * 142.0, tr.position.y, 132.0, tr.size.y)
		if game.tools.denied_slot == i + 1:
			r.position.x += sin(t * 70.0) * 6.0 * lock_shake
		c.draw_rect(r, Color(0.02, 0.02, 0.025, 0.72))
		var lc := r.get_center() + Vector2(0, -4)
		c.draw_rect(Rect2(lc - Vector2(7, 2), Vector2(14, 11)), Pal.ink(0.45), false, 1.4)
		c.draw_arc(lc + Vector2(0, -3), 5.0, PI, TAU, 10, Pal.ink(0.45), 1.4, true)


func _go_rect() -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 200, s.y * 0.66, 400, 64)


func _choice_rect(i: int) -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 330 + i * 340, s.y * 0.5 + 10, 320, 64)


func _choice(s: Vector2, k: float) -> void:
	var tut := game.tutorial
	var ch: Dictionary = tut.step().get("choice", {})
	if ch.is_empty():
		return
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35 * k))
	_text(game.radio.text(game.radio.lines.get(tut.step().get("in", [""])[0], {})), Vector2(s.x * 0.5, s.y * 0.5 - 40 + (1.0 - k) * 12.0), 22, Pal.ink(0.95 * k), font_l, 0)
	var m := c.get_local_mouse_position()
	for i in 2:
		var r := _choice_rect(i)
		r.position.y += (1.0 - Pal.back(k, 2.0)) * 20.0
		var hot := r.has_point(m)
		c.draw_rect(r, Color(0.03, 0.032, 0.037, 0.92 * k))
		c.draw_rect(r, Pal.ink((0.6 if hot else 0.22) * k), false, 1.2)
		if hot:
			c.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), Pal.heat(k, 1.0))
		_text(str(i + 1), r.position + Vector2(18, 39), 22, Pal.heat(0.9 * k, 1.1), font_l)
		_text(tut.text(ch.a if i == 0 else ch.b), r.position + Vector2(48, 38), 16, Pal.ink(0.9 * k))


func _certificate(s: Vector2) -> void:
	var e := stamp_t
	var k := clampf(e / 0.18, 0.0, 1.0)
	var sc := lerpf(2.2, 1.0, Pal.ease_in(k))
	var a := clampf(e / 0.1, 0.0, 1.0)
	var ctr := Vector2(s.x * 0.5, s.y * 0.42)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.45 * clampf(e / 0.4, 0.0, 1.0)))
	c.draw_set_transform(ctr, deg_to_rad(-10.0), Vector2(sc, sc))
	var col := Pal.heat(0.95 * a, 1.2) if Txt.cert_kind != "skipped" else Pal.ink(0.7 * a)
	c.draw_arc(Vector2.ZERO, 118.0, 0.0, TAU, 72, col, 4.0, true)
	c.draw_arc(Vector2.ZERO, 104.0, 0.0, TAU, 72, col, 1.5, true)
	var sp: String = game.tutorial.special()
	var title: String = game.txt("tut_cert") if sp == "" else Txt.t("cxu_stamp_" + sp)
	var tw := font_b.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(font_b, Vector2(-tw * 0.5, -6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	var sub := "BERTH 07  ·  OP-7" if sp == "" else Txt.t("cxu_sp_cert")
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_string(font, Vector2(-sw * 0.5, 26), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e > 1.2 and sp != "":
		# one button: on to what is waiting; the bonus, the first time
		var b0 := clampf((e - 1.2) / 0.3, 0.0, 1.0)
		if game.tutorial.bonus > 0.0:
			_text(Txt.t("cxu_sp_paid") % Pal.money(game.tutorial.bonus), Vector2(s.x * 0.5, s.y * 0.62), 18, Pal.tint(Pal.FLUID, 0.95 * b0, 1.1), font_b, 0)
		var gr := _go_rect()
		gr.position.y += (1.0 - Pal.back(b0, 2.0)) * 20.0
		var hot0 := gr.has_point(c.get_local_mouse_position())
		c.draw_rect(gr, Color(0.03, 0.032, 0.037, 0.92 * b0))
		c.draw_rect(gr, Pal.ink((0.6 if hot0 else 0.22) * b0), false, 1.2)
		var nxt := "cxu_sp_next" if not Game.course_chain.is_empty() else ("cxu_sp_to_contract" if Game.course_then == "contract" else "cxu_sp_back")
		_text(Txt.t(nxt), gr.get_center() + Vector2(0, 6), 17, Pal.ink(0.92 * b0), font_b, 0)
		return
	if e > 1.2:
		var b := clampf((e - 1.2) / 0.3, 0.0, 1.0)
		var m := c.get_local_mouse_position()
		for i in 2:
			var r := _choice_rect(i)
			r.position.y = s.y * 0.66 + (1.0 - Pal.back(b, 2.0)) * 20.0
			var hot := r.has_point(m)
			c.draw_rect(r, Color(0.03, 0.032, 0.037, 0.92 * b))
			c.draw_rect(r, Pal.ink((0.6 if hot else 0.22) * b), false, 1.2)
			_text(str(i + 1), r.position + Vector2(18, 39), 22, Pal.heat(0.9 * b, 1.1), font_l)
			_text(game.txt("tut_exam") if i == 0 else game.txt("tut_contract"), r.position + Vector2(48, 38), 16, Pal.ink(0.9 * b))


func _draw_glow() -> void:
	pass


# ---------------------------------------------------------------- the flight course, in the world

func _draw_world() -> void:
	var tut := game.tutorial
	if tut == null or game.state != "play" or tut.lesson_i > 1:
		return
	var z: float = game.cam_zoom()
	for i in range(tut.rings_done, tut.rings.size()):
		var r: Array = tut.rings[i]
		var a := 0.9 if i == tut.rings_done else 0.3
		var rot := t * 0.6 + i
		for k in 3:
			var a0 := rot + k * TAU / 3.0
			world_layer.draw_arc(r[0], r[1], a0, a0 + TAU / 3.0 - 0.25, 24, Pal.ink(a, 1.6), 2.0 / z + 1.0, true)
		world_layer.draw_arc(r[0], r[1] * 0.7, 0.0, TAU, 32, Pal.ink(a * 0.2, 1.2), 1.0, true)
	if not tut.long_ring.is_empty() and not tut.dash_done:
		var a1: Vector2 = tut.long_ring[0]
		var b1: Vector2 = tut.long_ring[1]
		var rr: float = tut.long_ring[2]
		var on := tut.rings_done >= tut.rings.size()
		var al := 0.9 if on else 0.25
		var n := Vector2(0, rr)
		world_layer.draw_line(a1 - n, b1 - n, Pal.ink(al, 1.5), 2.0, true)
		world_layer.draw_line(a1 + n, b1 + n, Pal.ink(al, 1.5), 2.0, true)
		for i in 6:
			var u := fposmod(t * 0.8 + i / 6.0, 1.0)
			var p := a1.lerp(b1, u)
			world_layer.draw_line(p - n * 0.6, p + n * 0.6, Pal.ink(al * 0.35 * (1.0 - absf(u - 0.5) * 2.0), 1.4), 1.0)
	if tut.stop_box.size != Vector2.ZERO and tut.step().get("id", "") == "stop":
		var bx: Rect2 = tut.stop_box
		var fill := clampf(tut.box_t, 0.0, 1.0)
		world_layer.draw_rect(bx, Pal.ink(0.6, 1.4), false, 1.6)
		world_layer.draw_rect(Rect2(bx.position, Vector2(bx.size.x * fill, 3)), Pal.heat(0.9, 1.6))
