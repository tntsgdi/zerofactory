class_name ExamHud
extends CanvasLayer
# The assessment on screen: the brief top left (APPRENTICE ASSESSMENT, the
# goal, what is known, Q for a hint and how many were used), and the result:
# the grade stamp, the accident review rows, retake / first contract.

var game: Game
var c: Control
var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var stamped := false


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_ui)
	add_child(c)


func _input(ev: InputEvent) -> void:
	var ex: Exam = game.exam if game != null else null
	if ex == null or ex.result.is_empty() or ex.result_t < 1.0:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := c.get_local_mouse_position()
		for i in 2:
			if _button(c.size, i).has_point(m):
				get_viewport().set_input_as_handled()
				game.exam_choice(i)
				return


func _process(dt: float) -> void:
	if game == null or game.exam == null:
		return
	t += dt
	var ex: Exam = game.exam
	if not ex.result.is_empty() and ex.result_t >= 0.35 and not stamped:
		stamped = true
		game.sfx.play("stamp")
		game.shake(0.3)
	c.queue_redraw()


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	c.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _draw_ui() -> void:
	var ex: Exam = game.exam
	if ex == null:
		return
	var s := c.size
	if game.state == "play" and not game.menu_open:
		_brief(ex)
	elif not ex.result.is_empty():
		_result(s, ex)


func _brief(ex: Exam) -> void:
	var x := 40.0
	var y := 46.0
	_text("APPRENTICE ASSESSMENT", Vector2(x, y), 13, Pal.heat(0.85, 1.1), font_b)
	_text(game.txt("ex_goal"), Vector2(x, y + 28), 18, Pal.ink(0.92), font_b)
	_text(game.txt("ex_known"), Vector2(x, y + 54), 14, Pal.ink(0.5), font)
	_text(game.txt("ex_q"), Vector2(x, y + 84), 13, Pal.ink(0.35), font)
	if ex.hints > 0:
		_text(game.txt("ex_hints") % ex.hints, Vector2(x, y + 106), 13, Pal.heat(0.8, 1.0), font)


func _button(s: Vector2, i: int) -> Rect2:
	return Rect2(s.x * 0.5 - 330 + i * 340, s.y - 120, 320, 60)


func _result(s: Vector2, ex: Exam) -> void:
	var e: float = ex.result_t
	var a := clampf(e / 0.4, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.72 * a))
	var gr: String = ex.result.grade
	var cx := s.x * 0.5
	var y := s.y * 0.16
	_text("APPRENTICE ASSESSMENT", Vector2(cx, y), 14, Pal.ink(0.5 * a), font_b, 0)
	_text(game.txt("ex_done") if gr != "" else game.txt("ex_incomplete"), Vector2(cx, y + 32), 20, Pal.ink(0.85 * a), font, 0)
	# the stamp
	var k := clampf((e - 0.2) / 0.15, 0.0, 1.0)
	if e > 0.2:
		var sc := lerpf(2.2, 1.0, Pal.ease_in(k))
		var col := Pal.ink(0.95 * k) if gr == "A" else (Pal.heat(0.95 * k, 1.2) if gr == "" or gr == "C" else Pal.ink(0.8 * k))
		c.draw_set_transform(Vector2(cx, y + 160), deg_to_rad(-10.0), Vector2(sc, sc))
		c.draw_arc(Vector2.ZERO, 86.0, 0.0, TAU, 64, col, 4.0, true)
		c.draw_arc(Vector2.ZERO, 74.0, 0.0, TAU, 64, Color(col.r, col.g, col.b, col.a * 0.5), 1.5, true)
		var big: String = gr if gr != "" else "—"
		var bw := font_l.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
		c.draw_string(font_l, Vector2(-bw * 0.5, 28), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, col)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text(game.txt("ex_g_" + (gr if gr != "" else "none")), Vector2(cx, y + 290), 15, Pal.ink(0.6 * a), font, 0)
	# the review: what went wrong, when, and which judgement was off
	var rows: Array = ex.result.review
	var ry := y + 340.0
	var re := clampf((e - 0.7) / 0.3, 0.0, 1.0)
	if gr != "A" and re > 0.0:
		_text(game.txt("ex_review"), Vector2(cx - 380, ry), 13, Pal.ink(0.45 * re), font)
		if rows.is_empty():
			_text(game.txt("ex_clean"), Vector2(cx - 380, ry + 30), 15, Pal.ink(0.7 * re), font)
		for i in mini(rows.size(), 4):
			var r: Dictionary = rows[i]
			var yy := ry + 30 + i * 62
			var stamp := "T+%s" % _clock(r.t) if r.t >= 0.0 else "  ·  "
			var what: String = game.txt(r.what)
			if what.find("%s") >= 0:
				what = what % r.detail
			_text(stamp, Vector2(cx - 380, yy), 13, Pal.heat(0.8 * re, 1.0), font_b)
			_text(what, Vector2(cx - 300, yy), 16, Pal.ink(0.92 * re), font_b)
			_text(game.txt(r.why), Vector2(cx - 300, yy + 24), 13, Pal.ink(0.55 * re), font)
	if e > 1.0:
		var m := c.get_local_mouse_position()
		for i in 2:
			var b := _button(s, i)
			var hot := b.has_point(m)
			c.draw_rect(b, Color(0.03, 0.032, 0.037, 0.92))
			c.draw_rect(b, Pal.ink(0.6 if hot else 0.22), false, 1.2)
			_text(str(i + 1), b.position + Vector2(18, 39), 22, Pal.heat(0.9, 1.1), font_l)
			_text(game.txt("ex_retake") if i == 0 else game.txt("tut_contract"), b.position + Vector2(48, 38), 16, Pal.ink(0.9))


func _clock(sec: float) -> String:
	var m := int(sec) / 60
	return "%02d:%02d" % [m, int(sec) % 60]
