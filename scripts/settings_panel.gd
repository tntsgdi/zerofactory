class_name SettingsPanel
extends CanvasLayer
# Settings, from the title and from the pause menu: three volumes, picture
# quality, language. Arrow keys or the mouse (left half of a row turns it
# down, right half up); every change is applied and saved at once.

signal closed

const ROWS := ["vol_master", "vol_music", "vol_sfx", "quality", "lang", "back"]

var testing := false
var is_open := false
var k := 0.0
var sel := 0
var hover := -1
var c: Control
var font: Font
var font_l: Font
var font_b: Font


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_ui)
	add_child(c)


func open() -> void:
	is_open = true
	sel = 0


func close() -> void:
	if not is_open:
		return
	is_open = false
	closed.emit()


func _row_rect(i: int) -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 300, s.y * 0.5 - 170 + i * 58, 600, 48)


func _input(ev: InputEvent) -> void:
	if not is_open:
		return
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_UP, KEY_W:
				sel = (sel + ROWS.size() - 1) % ROWS.size()
			KEY_DOWN, KEY_S:
				sel = (sel + 1) % ROWS.size()
			KEY_LEFT, KEY_A:
				change(ROWS[sel], -1)
			KEY_RIGHT, KEY_D:
				change(ROWS[sel], 1)
			KEY_ENTER, KEY_SPACE:
				if ROWS[sel] == "back":
					close()
				else:
					change(ROWS[sel], 1)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var m := c.get_local_mouse_position()
			for i in ROWS.size():
				var r := _row_rect(i)
				if r.has_point(m):
					sel = i
					if ROWS[i] == "back":
						close()
					else:
						change(ROWS[i], -1 if m.x < r.get_center().x else 1)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func change(row: String, dir: int) -> void:
	match row:
		"vol_master":
			Txt.vol_master = clampf(snappedf(Txt.vol_master + dir * 0.1, 0.1), 0.0, 1.0)
		"vol_music":
			Txt.vol_music = clampf(snappedf(Txt.vol_music + dir * 0.1, 0.1), 0.0, 1.0)
		"vol_sfx":
			Txt.vol_sfx = clampf(snappedf(Txt.vol_sfx + dir * 0.1, 0.1), 0.0, 1.0)
		"quality":
			Txt.quality = "low" if Txt.quality == "high" else "high"
		"lang":
			Txt.zh = not Txt.zh
	Txt.save_settings(testing)
	Settings.apply(get_viewport())


func value(row: String) -> String:
	match row:
		"vol_master":
			return "%d%%" % roundi(Txt.vol_master * 100.0)
		"vol_music":
			return "%d%%" % roundi(Txt.vol_music * 100.0)
		"vol_sfx":
			return "%d%%" % roundi(Txt.vol_sfx * 100.0)
		"quality":
			return Txt.t("s_q_" + Txt.quality)
		"lang":
			return "中文" if Txt.zh else "ENGLISH"
	return ""


func _process(dt: float) -> void:
	k = Pal.damp(k, 1.0 if is_open else 0.0, 14.0, dt)
	hover = -1
	if is_open:
		var m := c.get_local_mouse_position()
		for i in ROWS.size():
			if _row_rect(i).has_point(m):
				hover = i
	if k > 0.005 or is_open:
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
	if k < 0.005:
		return
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.82 * k))
	_text(Txt.t("s_title"), Vector2(s.x * 0.5, s.y * 0.5 - 210), 30, Pal.ink(0.9 * k), font_l, 0)
	for i in ROWS.size():
		var row: String = ROWS[i]
		var r := _row_rect(i)
		r.position.y += (1.0 - Motion.stagger(k * 0.6, i, 0.04, 0.2)) * 16.0
		var on := i == sel or i == hover
		if on:
			Pal.band(c, r, 0.12 * k)
			c.draw_rect(Rect2(r.position.x, r.end.y - 2, 3, 2), Pal.heat(k, 1.0))
		if row == "back":
			_text(Txt.t("s_back"), Vector2(r.get_center().x, r.position.y + 32), 20, Pal.ink((0.95 if on else 0.6) * k), font, 0)
			continue
		_text(Txt.t("s_" + row), r.position + Vector2(20, 32), 18, Pal.ink((0.95 if on else 0.65) * k), font)
		var v := value(row)
		_text("◂", Vector2(r.end.x - 190, r.position.y + 32), 18, Pal.ink(0.4 * k), font, 0)
		_text(v, Vector2(r.end.x - 110, r.position.y + 32), 18, Pal.ink(0.95 * k), font_b, 0)
		_text("▸", Vector2(r.end.x - 30, r.position.y + 32), 18, Pal.ink(0.4 * k), font, 0)
		if row.begins_with("vol_"):
			var f: float = {"vol_master": Txt.vol_master, "vol_music": Txt.vol_music, "vol_sfx": Txt.vol_sfx}[row]
			var br := Rect2(r.position.x + 20, r.end.y - 9, 300, 3)
			c.draw_rect(br, Pal.ink(0.12 * k))
			c.draw_rect(Rect2(br.position, Vector2(br.size.x * f, 3)), Pal.ink(0.8 * k))
	_text(Txt.t("s_keys"), Vector2(s.x * 0.5, _row_rect(ROWS.size()).position.y + 30), 13, Pal.ink(0.35 * k), font, 0)
