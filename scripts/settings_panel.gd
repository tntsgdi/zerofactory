class_name SettingsPanel
extends CanvasLayer
# Settings, from the title and from the pause menu: three volumes, picture
# quality, language. Arrow keys or the mouse (left half of a row turns it
# down, right half up); every change is applied and saved at once.

signal closed

const ROWS := ["vol_master", "vol_music", "vol_sfx", "quality", "window", "calm", "lang", "context", "keys_row", "back"]

var testing := false
var is_open := false
var k := 0.0
var sel := 0
var hover := -1
var c: Control
var font: Font
var font_l: Font
var font_b: Font
var keys_open := false     # the key list instead of the settings
var ksel := 0
var waiting := false       # the next key press goes to Keys.ORDER[ksel]


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
	keys_open = false
	waiting = false
	sel = 0


func close() -> void:
	if not is_open:
		return
	is_open = false
	closed.emit()


func _row_rect(i: int) -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 300, s.y * 0.5 - 300 + i * 56, 600, 48)


func _key_rect(i: int) -> Rect2:
	var s := c.size
	var col := i % 2
	var row := i / 2
	return Rect2(s.x * 0.5 - 610 + col * 620, s.y * 0.5 - 330 + row * 50, 600, 42)


func _keys_input(ev: InputEvent) -> void:
	var n := Keys.ORDER.size() + 1
	if waiting:
		if ev is InputEventKey and ev.pressed and not ev.echo:
			if ev.physical_keycode != KEY_ESCAPE:
				Keys.bind(Keys.ORDER[ksel], ev.physical_keycode)
				Txt.save_settings(testing)
			waiting = false
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				keys_open = false
			KEY_UP, KEY_W:
				ksel = (ksel + n - 2) % n
			KEY_DOWN, KEY_S:
				ksel = (ksel + 2) % n
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				ksel = ksel ^ 1 if ksel < Keys.ORDER.size() - 1 or ksel % 2 == 1 else ksel
			KEY_ENTER, KEY_SPACE:
				_key_pick(ksel)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var m := c.get_local_mouse_position()
		for i in n:
			if _key_rect(i).has_point(m):
				ksel = i
				_key_pick(i)
	get_viewport().set_input_as_handled()


func _key_pick(i: int) -> void:
	if i >= Keys.ORDER.size():
		Keys.reset()
		Txt.save_settings(testing)
	else:
		waiting = true


func _input(ev: InputEvent) -> void:
	if not is_open:
		return
	if keys_open:
		_keys_input(ev)
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
				elif ROWS[sel] == "keys_row":
					keys_open = true
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
					elif ROWS[i] == "keys_row":
						keys_open = true
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
		"context":
			Txt.context = not Txt.context
		"window":
			Txt.fullscreen = not Txt.fullscreen
		"calm":
			Txt.calm = not Txt.calm
		"keys_row":
			keys_open = true
			return
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
		"context":
			return Txt.t("s_on") if Txt.context else Txt.t("s_off")
		"window":
			return Txt.t("s_win_full") if Txt.fullscreen else Txt.t("s_win_window")
		"calm":
			return Txt.t("s_off") if Txt.calm else Txt.t("s_on")
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
	if keys_open:
		_draw_keys(s)
		return
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
		if row == "keys_row":
			_text(Txt.t("s_keys_row"), r.position + Vector2(20, 32), 18, Pal.ink((0.95 if on else 0.65) * k), font)
			_text("→", Vector2(r.end.x - 30, r.position.y + 32), 18, Pal.ink(0.6 * k), font, 0)
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


# the key list: every action, its key; Enter (or a click) waits for the new one
func _draw_keys(s: Vector2) -> void:
	_text(Txt.t("s_keys_row"), Vector2(s.x * 0.5, s.y * 0.5 - 380), 30, Pal.ink(0.9 * k), font_l, 0)
	for i in Keys.ORDER.size() + 1:
		var r := _key_rect(i)
		var on := i == ksel
		UI.panel(c, r, k, 1.0 if on else 0.0)
		if i == Keys.ORDER.size():
			_text(Txt.t("s_reset"), r.position + Vector2(20, 28), 16, Pal.ink((0.95 if on else 0.6) * k), font)
			continue
		var a: String = Keys.ORDER[i]
		_text(Txt.t("key_" + a), r.position + Vector2(20, 28), 16, Pal.ink((0.95 if on else 0.7) * k), font)
		var v := Txt.t("s_press") if on and waiting else Keys.label(a)
		_text(v, Vector2(r.end.x - 20, r.position.y + 28), 16, Pal.heat(0.95 * k, 1.2) if on and waiting else Pal.ink(0.95 * k), font_b, 1)
	_text(Txt.t("s_keys_help"), Vector2(s.x * 0.5, _key_rect(Keys.ORDER.size() + 2).position.y + 30), 13, Pal.ink(0.5 * k), font, 0)
