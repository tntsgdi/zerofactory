extends Control
# Title: GR-7 is drawn line by line, the name settles in. One way in — START —
# opens three save slots: a slot with a career shows its company, funds, loan,
# contracts done and time played and goes back where it was left; an empty
# slot asks for a company name and begins at ARRIVAL, straight on into the
# training course and the first contract. Settings, quit.

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
var next_scene := "res://scenes/main.tscn"
var view_k := Motion.Spring.new(0.0, 160.0, 0.86)   # 0 the title, 1 the slots
var slots: Array = []           # what each slot holds (Career.peek)
var slot_hover := -1
var slot_sel := 0
var slot_lift: Array = []
var slots_t := 0.0
var del_hover := -1
var del_confirm := -1
var naming := -1                # the empty slot being named
var name_edit: LineEdit
var leave_from := Rect2()


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
	var dev := DevPanel.new()
	dev.where = "title"
	add_child(dev)
	for i in 140:
		dust.append([Vector2(randf(), randf()), randf_range(0.004, 0.02), randf() * TAU])
	for i in Career.SLOTS:
		slot_lift.append(Motion.Spring.new(0.0, 260.0, 0.7))
	name_edit = LineEdit.new()
	name_edit.visible = false
	name_edit.max_length = 18
	name_edit.placeholder_text = Txt.t("t_company_ph")
	name_edit.add_theme_font_override("font", font_l)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.add_theme_color_override("font_color", Pal.ink(0.96))
	name_edit.add_theme_color_override("font_placeholder_color", Pal.ink(0.3))
	name_edit.add_theme_color_override("caret_color", Pal.HEAT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Pal.heat(0.9, 1.0)
	sb.border_width_bottom = 2
	sb.content_margin_left = 2
	sb.content_margin_bottom = 6
	for st in ["normal", "focus", "read_only"]:
		name_edit.add_theme_stylebox_override(st, sb)
	name_edit.text_submitted.connect(func(tx: String): _new_slot(naming, tx))
	add_child(name_edit)


func _items() -> Array:
	return [["start", Txt.t("t_start")], ["settings", Txt.t("m_settings")], ["quit", Txt.t("t_quit")]]


func _item_rect(i: int) -> Rect2:
	var s := size
	return Rect2(s.x * 0.5 - 200, s.y * 0.72 + i * 52, 400, 44)


func _slot_rect(i: int) -> Rect2:
	var s := size
	var w := minf(400.0, (s.x - 160.0 - 2 * 32.0) / 3.0)
	var x0 := s.x * 0.5 - (3 * w + 2 * 32.0) * 0.5
	return Rect2(x0 + i * (w + 32.0), s.y * 0.5 - 150.0, w, 330.0)


func _del_rect(i: int) -> Rect2:
	var r := _slot_rect(i)
	return Rect2(r.end.x - 170, r.end.y - 44, 150, 30)


func _back_rect() -> Rect2:
	var s := size
	return Rect2(s.x * 0.5 - 90, _slot_rect(0).end.y + 40, 180, 40)


func _in_slots() -> bool:
	return view_k.target > 0.5


func _open_slots() -> void:
	slots.clear()
	for i in Career.SLOTS:
		slots.append(Career.peek(i + 1))
	view_k.target = 1.0
	slots_t = 0.0
	del_confirm = -1
	slot_sel = 0
	for i in slots.size():
		if not slots[i].is_empty():
			slot_sel = i
			break


func _close_slots() -> void:
	view_k.target = 0.0
	_stop_naming()


func _process(dt: float) -> void:
	t += dt
	slots_t += dt
	view_k.step(dt)
	hover = -1
	slot_hover = -1
	del_hover = -1
	var m := get_local_mouse_position()
	if not _in_slots():
		for i in _items().size():
			if _item_rect(i).has_point(m):
				hover = i
	else:
		for i in Career.SLOTS:
			if _slot_rect(i).has_point(m):
				slot_hover = i
			if not slots[i].is_empty() and _del_rect(i).has_point(m):
				del_hover = i
		if _back_rect().has_point(m):
			hover = 99
	for i in Career.SLOTS:
		slot_lift[i].target = 1.0 if (i == slot_hover or (slot_hover < 0 and i == slot_sel and _in_slots())) or i == naming else 0.0
		slot_lift[i].step(dt)
	if naming >= 0:
		var r := _slot_rect(naming)
		name_edit.position = r.position + Vector2(28, 150 - slot_lift[naming].x * 8.0)
		name_edit.size = Vector2(r.size.x - 56, 46)
	if music != null:
		music_k = Pal.damp(music_k, 0.0 if leaving >= 0.0 else 0.55, 1.5 if leaving < 0.0 else 6.0, dt)
		music.volume_db = linear_to_db(maxf(0.0001, music_k))
	if leaving >= 0.0:
		leaving += dt
		if leaving > 0.7:
			if next_scene == "career":
				Game.play_career(get_tree())
			else:
				get_tree().change_scene_to_file(next_scene)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or leaving >= 0.0:
		return
	if t < 2.0:
		t = 2.0
		return
	if not _in_slots():
		if hover >= 0:
			_pick(_items()[hover][0])
		return
	if hover == 99:
		_close_slots()
	elif del_hover >= 0:
		_delete(del_hover)
	elif slot_hover >= 0:
		slot_sel = slot_hover
		_enter(slot_hover)
	elif naming >= 0:
		_stop_naming()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or leaving >= 0.0:
		return
	var k: int = ev.physical_keycode
	if t < 2.0:
		if k in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			t = 2.0
		return
	if not _in_slots():
		if k in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_pick("start")
		return
	if naming >= 0:
		if k == KEY_ESCAPE:
			_stop_naming()
		return
	match k:
		KEY_ESCAPE, KEY_BACKSPACE:
			_close_slots()
		KEY_1, KEY_2, KEY_3:
			slot_sel = k - KEY_1
			del_confirm = -1
		KEY_LEFT, KEY_A:
			slot_sel = maxi(0, slot_sel - 1)
			del_confirm = -1
		KEY_RIGHT, KEY_D:
			slot_sel = mini(Career.SLOTS - 1, slot_sel + 1)
			del_confirm = -1
		KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
			_enter(slot_sel)
		KEY_DELETE:
			if not slots[slot_sel].is_empty():
				_delete(slot_sel)
	get_viewport().set_input_as_handled()


func _pick(id: String) -> void:
	match id:
		"start":
			_open_slots()
		"settings":
			settings.open()
		"quit":
			get_tree().quit()


func _enter(i: int) -> void:
	del_confirm = -1
	if slots[i].is_empty():
		if naming != i:
			_start_naming(i)
		return
	_stop_naming()
	Career.use_slot(i + 1)
	var d := Career.load_or_new()
	leave_from = _slot_rect(i)
	if not d.get("certified", false):
		# still in training: back into the course where it was left
		Game.start_ship = "ts1"
		SaveGame.load_requested = SaveGame.exists(SaveGame.train_path)
		next_scene = "res://scenes/main.tscn"
	else:
		next_scene = "career"
	leaving = 0.0


func _start_naming(i: int) -> void:
	naming = i
	name_edit.text = ""
	name_edit.visible = true
	name_edit.grab_focus()


func _stop_naming() -> void:
	naming = -1
	name_edit.visible = false
	name_edit.release_focus()


# a new save: ARRIVAL, then the training course, then the first contract
func _new_slot(i: int, company: String) -> void:
	if i < 0 or leaving >= 0.0:
		return
	var nm := company.strip_edges()
	if nm == "":
		nm = Txt.t("t_company_default")
	_stop_naming()
	Career.use_slot(i + 1)
	Career.start_new()
	Career.data.company = nm
	Career.save()
	SaveGame.clear()
	SaveGame.clear(SaveGame.train_path)
	Game.start_ship = "ts1"
	SaveGame.load_requested = false
	next_scene = "res://scenes/main.tscn"
	leave_from = _slot_rect(i)
	leaving = 0.0


func _delete(i: int) -> void:
	if del_confirm != i:
		del_confirm = i
		return
	Career.clear_slot(i + 1)
	slots[i] = {}
	del_confirm = -1


func _draw() -> void:
	var s := size
	var vk := clampf(view_k.x, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Pal.BG)
	for d in dust:
		var p: Vector2 = d[0]
		var q := Vector2(fposmod(p.x + t * d[1] * (1.0 + vk * 2.0), 1.0) * s.x, p.y * s.y)
		draw_circle(q, 1.0, Pal.ink(0.05 + 0.04 * sin(t + d[2])))
	# the ship, drawn as one continuous pen; it draws back and dims behind the slots
	var scale := s.x * 0.62 / 42.0 * (1.0 - 0.25 * vk)
	var origin := Vector2(s.x * 0.5 - 21.0 * scale + sin(t * 0.2) * 6.0, s.y * (0.33 - 0.17 * vk) + sin(t * 0.33) * 4.0)
	var k := Pal.ease_io(clampf(t / 2.2, 0.0, 1.0)) * total_len
	var used := 0.0
	var tip := Vector2.INF
	var dim := 1.0 - 0.6 * vk
	for st in strokes:
		for i in st.size() - 1:
			var a: Vector2 = st[i]
			var b: Vector2 = st[i + 1]
			var l := a.distance_to(b)
			if used >= k:
				break
			var f := clampf((k - used) / l, 0.0, 1.0)
			var e := a.lerp(b, f)
			draw_line(origin + a * scale, origin + e * scale, Pal.ink((0.75 if st == strokes[0] else 0.32) * dim), 1.6 if st == strokes[0] else 1.0, true)
			if f < 1.0:
				tip = origin + e * scale
			used += l
	if tip != Vector2.INF:
		draw_circle(tip, 3.0, Pal.heat(1.0, 2.0))
		draw_circle(tip, 8.0, Pal.heat(0.25, 1.4))
	# title
	var ta := clampf((t - 1.4) / 0.8, 0.0, 1.0) * (1.0 - vk)
	var rise := (1.0 - Pal.ease_out(clampf((t - 1.4) / 0.8, 0.0, 1.0))) * 20.0 - vk * 40.0
	if ta > 0.005:
		var title := Txt.t("t_title")
		var tw := font_l.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		draw_string(font_l, Vector2(s.x * 0.5 - tw * 0.5, s.y * 0.62 + rise), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Pal.ink(0.96 * ta))
		var sub := Txt.t("t_sub")
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(s.x * 0.5 - sw * 0.5, s.y * 0.62 + 40 + rise), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.45 * ta))
		draw_rect(Rect2(s.x * 0.5 - 60 * ta, s.y * 0.62 + 56 + rise, 120 * ta, 2), Pal.heat(ta, 1.0))
		# menu
		var items := _items()
		for i in items.size():
			var ia := clampf((t - 2.0 - i * 0.08) / 0.35, 0.0, 1.0) * (1.0 - vk)
			var r := _item_rect(i)
			r.position.y += (1.0 - Pal.ease_out(ia)) * 16.0 + vk * 30.0
			if i == hover:
				Pal.band(self, r, 0.12 * ia)
				draw_rect(Rect2(r.get_center().x - 36, r.end.y - 2, 72, 2), Pal.heat(ia, 1.0))
			var txt: String = items[i][1]
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, Vector2(r.get_center().x - w * 0.5, r.position.y + 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.ink((0.95 if i == hover else 0.55) * ia))
	if vk > 0.005:
		_draw_slots(s, vk)
	if leaving >= 0.0:
		_leave(s)


func _draw_slots(s: Vector2, vk: float) -> void:
	var head := Txt.t("t_slots")
	var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(s.x * 0.5 - hw * 0.5, _slot_rect(0).position.y - 34 + (1.0 - vk) * 20.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.45 * vk))
	for i in Career.SLOTS:
		var e := Pal.ease_out(Motion.stagger(slots_t, i, 0.07, 0.45)) * vk
		if e < 0.005:
			continue
		var lift: float = slot_lift[i].x
		var r := _slot_rect(i)
		r.position.y += (1.0 - e) * 60.0 - lift * 8.0
		var d: Dictionary = slots[i] if i < slots.size() else {}
		var on := lift
		draw_rect(r, Color(0.03 + 0.012 * on, 0.032 + 0.012 * on, 0.037 + 0.012 * on, 0.94 * e))
		draw_rect(r, Pal.ink((0.14 + 0.4 * on) * e), false, 1.0)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - on) * 0.5), Vector2(3, r.size.y * on)), Pal.heat(e, 1.1))
		var x := r.position.x + 28
		draw_string(font, Vector2(x, r.position.y + 34), Txt.t("t_slot") % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.4 * e))
		if d.is_empty():
			if naming == i:
				draw_string(font, Vector2(x, r.position.y + 132), Txt.t("t_company"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.45 * e))
				draw_string(font, Vector2(x, r.position.y + 236), Txt.t("t_slot_new_d"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 13, Pal.ink(0.4 * e))
				continue
			var c := r.get_center() + Vector2(0, -10)
			var pk := 0.85 + 0.15 * on
			draw_line(c + Vector2(-14, 0) * pk, c + Vector2(14, 0) * pk, Pal.ink((0.35 + 0.5 * on) * e), 1.6, true)
			draw_line(c + Vector2(0, -14) * pk, c + Vector2(0, 14) * pk, Pal.ink((0.35 + 0.5 * on) * e), 1.6, true)
			draw_arc(c, 30.0 + 4.0 * on, 0.0, TAU, 40, Pal.ink((0.12 + 0.3 * on) * e), 1.0, true)
			_center(Txt.t("t_slot_new") if on > 0.5 else Txt.t("t_slot_empty"), Vector2(c.x, c.y + 70), 18, Pal.ink((0.5 + 0.45 * on) * e), font)
			continue
		var status: String
		var act: Dictionary = d.get("active", {})
		if not d.get("certified", true):
			status = Txt.t("t_slot_training")
		elif not act.is_empty():
			status = Txt.t("t_slot_contract") % act.get("id", "")
		else:
			status = Txt.t("t_slot_berth")
		var sw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(r.end.x - 28 - sw, r.position.y + 34), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.AIR, 0.75 * e, 1.0))
		var nm: String = d.get("company", "")
		if nm == "":
			nm = Txt.t("t_company_default")
		draw_string(font_l, Vector2(x, r.position.y + 82), nm, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 30, Pal.ink(0.96 * e))
		var lv := "trainee"
		for l in Career.LEVELS:
			if int(d.get("rep", 0)) >= l[1]:
				lv = l[0]
		var secs := int(float(d.get("time", 0.0)))
		var rows := [
			[Txt.t("t_slot_funds"), Pal.money(float(d.get("money", 0.0)))],
			[Txt.t("t_slot_loan"), Pal.money(float(d.get("loan", 0.0)))],
			[Txt.t("t_slot_done"), Txt.t("t_slot_done_n") % int(d.get("done", 0))],
			[Txt.t("t_slot_rep"), Txt.t("rep_" + lv)],
			[Txt.t("t_slot_time"), "%d:%02d" % [secs / 3600, (secs / 60) % 60]],
		]
		for j in rows.size():
			var y := r.position.y + 128 + j * 30
			var re := Pal.ease_out(Motion.stagger(slots_t, i * 3 + j + 2, 0.03, 0.3))
			draw_string(font, Vector2(x, y), rows[j][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.45 * e * re))
			var vw := font_b.get_string_size(rows[j][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			var loan_col: bool = j == 1 and float(d.get("loan", 0.0)) > 0.0
			draw_string(font_b, Vector2(r.end.x - 28 - vw + (1.0 - re) * 16.0, y), rows[j][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, (Pal.heat(0.85 * e * re, 1.0) if loan_col else Pal.ink(0.9 * e * re)))
		# bottom: continue (on hover) and delete
		var go_a := on * e
		draw_string(font_b, Vector2(x, r.end.y - 22), Txt.t("t_slot_go") + "  →", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.95 * go_a))
		draw_rect(Rect2(x, r.end.y - 14, 60.0 * go_a, 2), Pal.heat(go_a, 1.1))
		var dr := _del_rect(i)
		dr.position.y += r.position.y - _slot_rect(i).position.y
		var dl := Txt.t("t_slot_delete_ok") if del_confirm == i else Txt.t("t_slot_delete")
		var dw := font.get_string_size(dl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var dc: Color = Pal.heat(0.95 * e, 1.2) if del_confirm == i else Pal.ink((0.25 + 0.5 * (1.0 if del_hover == i else 0.0)) * e)
		draw_string(font, Vector2(dr.end.x - dw, dr.position.y + 22), dl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dc)
	# back, and the keys
	var br := _back_rect()
	var ba := vk * clampf((slots_t - 0.25) / 0.3, 0.0, 1.0)
	if hover == 99:
		Pal.band(self, br, 0.12 * ba)
		draw_rect(Rect2(br.get_center().x - 30, br.end.y - 2, 60, 2), Pal.heat(ba, 1.0))
	_center(Txt.t("t_slot_back"), Vector2(br.get_center().x, br.position.y + 27), 17, Pal.ink((0.9 if hover == 99 else 0.5) * ba), font)
	_center(Txt.t("t_slot_keys"), Vector2(s.x * 0.5, s.y - 32), 12, Pal.ink(0.25 * ba), font)


func _center(txt: String, at: Vector2, sz: int, col: Color, f: Font) -> void:
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(f, Vector2(at.x - w * 0.5, at.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


# going in: the chosen card (or the screen) closes to a line of heat
func _leave(s: Vector2) -> void:
	var g := Pal.ease_io(clampf(leaving / 0.4, 0.0, 1.0))
	if leave_from.size != Vector2.ZERO:
		var full := Rect2(Vector2.ZERO, s)
		var r := Rect2(leave_from.position.lerp(full.position, g), leave_from.size.lerp(full.size, g))
		draw_rect(r, Color(0.03, 0.032, 0.037, g))
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.heat(1.0 - g, 1.2))
	else:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, g))
	var c := clampf((leaving - 0.35) / 0.25, 0.0, 1.0)
	if c > 0.0:
		var h := s.y * 0.5 * Pal.ease_in(c)
		draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y * 0.5 - 1, s.x, 2), Pal.heat(c, 2.0))
