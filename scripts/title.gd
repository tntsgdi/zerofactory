extends Control
# Title: GR-7 is drawn line by line, the name settles in, and the contract waits.

var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var hover := -1
var leaving := -1.0
var strokes: Array = []   # [PackedVector2Array] in metres
var total_len := 0.0
var dust: Array = []
var music: AudioStreamPlayer
var music_k := 0.0
var settings: SettingsPanel


const HERON := [
	Vector2(0.2, 0.5), Vector2(0.9, -1.6), Vector2(2.4, -3.3), Vector2(4.6, -4.0),
	Vector2(33.0, -4.0), Vector2(33.0, 4.0), Vector2(4.6, 4.0), Vector2(2.4, 3.4), Vector2(0.8, 2.2),
]

func _ready() -> void:
	Txt.load_settings(false)
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	mouse_filter = Control.MOUSE_FILTER_STOP
	# the title drawing: GR-7's silhouette, line by line
	var outer: Array = HERON.duplicate()
	outer.append(HERON[0])
	strokes.append(PackedVector2Array(outer))
	for x in [5.0, 10.0, 27.0]:
		strokes.append(PackedVector2Array([Vector2(x, -3.55), Vector2(x, 2.95)]))
	strokes.append(PackedVector2Array([Vector2(27.0, 0.0), Vector2(33.0, 0.0)]))
	strokes.append(PackedVector2Array([Vector2(4.7, 2.95), Vector2(32.55, 2.95)]))
	strokes.append(PackedVector2Array([Vector2(33.0, -3.1), Vector2(40.6, -3.1)]))
	strokes.append(PackedVector2Array([Vector2(33.0, 3.1), Vector2(40.6, 3.1)]))
	strokes.append(PackedVector2Array([Vector2(38.4, -0.75), Vector2(41.6, -1.5), Vector2(41.6, 1.5), Vector2(38.4, 0.75), Vector2(38.4, -0.75)]))
	strokes.append(PackedVector2Array([Vector2(33.0, -1.1), Vector2(38.4, -1.1), Vector2(38.4, 1.1), Vector2(33.0, 1.1)]))
	for r in [[11.0, 0.75, 13.8, 2.95], [15.7, 1.05, 18.3, 2.95], [19.4, 1.15, 21.8, 2.95], [27.5, -2.1, 29.7, -0.15]]:
		strokes.append(PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[2], r[1]), Vector2(r[2], r[3]), Vector2(r[0], r[3]), Vector2(r[0], r[1])]))
	for s in strokes:
		for i in s.size() - 1:
			total_len += s[i].distance_to(s[i + 1])
	if ResourceLoader.exists("res://assets/music/main.ogg"):
		music = AudioStreamPlayer.new()
		var st: AudioStreamOggVorbis = load("res://assets/music/main.ogg")
		st.loop = true
		music.stream = st
		music.volume_db = -80.0
		music.bus = "Music"
		add_child(music)
		music.play()
	Settings.apply(get_viewport())
	settings = SettingsPanel.new()
	add_child(settings)
	for i in 140:
		dust.append([Vector2(randf(), randf()), randf_range(0.004, 0.02), randf() * TAU])


func _items() -> Array:
	var out: Array = []
	if SaveGame.exists():
		out.append(["continue", Txt.t("t_continue")])
	out.append_array([["new", Txt.t("t_new")], ["train", Txt.t("t_train")], ["settings", Txt.t("m_settings")], ["quit", Txt.t("t_quit")]])
	return out


func _item_rect(i: int) -> Rect2:
	var s := size
	return Rect2(s.x * 0.5 - 200, s.y * 0.72 + i * 52, 400, 44)


func _process(dt: float) -> void:
	t += dt
	hover = -1
	var m := get_local_mouse_position()
	for i in _items().size():
		if _item_rect(i).has_point(m):
			hover = i
	if music != null:
		music_k = Pal.damp(music_k, 0.0 if leaving >= 0.0 else 0.55, 1.5 if leaving < 0.0 else 6.0, dt)
		music.volume_db = linear_to_db(maxf(0.0001, music_k))
	if leaving >= 0.0:
		leaving += dt
		if leaving > 0.6:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if t < 2.0:
			t = 2.0
			return
		if hover >= 0:
			_pick(_items()[hover][0])


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			if t < 2.0:
				t = 2.0
			else:
				_pick(_items()[0][0])


func _pick(id: String) -> void:
	match id:
		"continue":
			if leaving < 0.0:
				Game.start_ship = ""
				SaveGame.load_requested = true
				leaving = 0.0
		"new":
			if leaving < 0.0:
				# a new operator goes through the training course first
				Game.start_ship = "gr7" if Txt.certified else "ts1"
				SaveGame.load_requested = not Txt.certified and SaveGame.exists(SaveGame.train_path)
				leaving = 0.0
		"train":
			if leaving < 0.0:
				Game.start_ship = "ts1"
				SaveGame.load_requested = SaveGame.exists(SaveGame.train_path)
				leaving = 0.0
		"settings":
			settings.open()
		"quit":
			get_tree().quit()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Pal.BG)
	for d in dust:
		var p: Vector2 = d[0]
		var q := Vector2(fposmod(p.x + t * d[1], 1.0) * s.x, p.y * s.y)
		draw_circle(q, 1.0, Pal.ink(0.05 + 0.04 * sin(t + d[2])))
	# the ship, drawn as one continuous pen
	var scale := s.x * 0.62 / 42.0
	var origin := Vector2(s.x * 0.5 - 21.0 * scale + sin(t * 0.2) * 6.0, s.y * 0.33 + sin(t * 0.33) * 4.0)
	var k := Pal.ease_io(clampf(t / 2.2, 0.0, 1.0)) * total_len
	var used := 0.0
	var tip := Vector2.INF
	for st in strokes:
		for i in st.size() - 1:
			var a: Vector2 = st[i]
			var b: Vector2 = st[i + 1]
			var l := a.distance_to(b)
			if used >= k:
				break
			var f := clampf((k - used) / l, 0.0, 1.0)
			var e := a.lerp(b, f)
			draw_line(origin + a * scale, origin + e * scale, Pal.ink(0.75 if st == strokes[0] else 0.32), 1.6 if st == strokes[0] else 1.0, true)
			if f < 1.0:
				tip = origin + e * scale
			used += l
	if tip != Vector2.INF:
		draw_circle(tip, 3.0, Pal.heat(1.0, 2.0))
		draw_circle(tip, 8.0, Pal.heat(0.25, 1.4))
	# title
	var ta := clampf((t - 1.4) / 0.8, 0.0, 1.0)
	var rise := (1.0 - Pal.ease_out(ta)) * 20.0
	var title := Txt.t("t_title")
	var tw := font_l.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
	draw_string(font_l, Vector2(s.x * 0.5 - tw * 0.5, s.y * 0.62 + rise), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Pal.ink(0.96 * ta))
	var sub := Txt.t("t_sub")
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(s.x * 0.5 - sw * 0.5, s.y * 0.62 + 40 + rise), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.45 * ta))
	draw_rect(Rect2(s.x * 0.5 - 60 * ta, s.y * 0.62 + 56, 120 * ta, 2), Pal.heat(ta, 1.0))
	# menu
	var items := _items()
	for i in items.size():
		var ia := clampf((t - 2.0 - i * 0.08) / 0.35, 0.0, 1.0)
		var r := _item_rect(i)
		r.position.y += (1.0 - Pal.ease_out(ia)) * 16.0
		if i == hover:
			Pal.band(self, r, 0.12 * ia)
			draw_rect(Rect2(r.get_center().x - 36, r.end.y - 2, 72, 2), Pal.heat(ia, 1.0))
		var txt: String = items[i][1]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(r.get_center().x - w * 0.5, r.position.y + 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink((0.95 if i == hover else 0.55) * ia))
	var note := Txt.t("t_note")
	draw_string(font, Vector2(40, s.y - 32), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.25))
	if leaving >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(leaving / 0.5, 0.0, 1.0)))
