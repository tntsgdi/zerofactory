extends Control
# Title: GR-7 is drawn line by line, the name settles in. One way in — START —
# opens three save slots: a slot with a career shows its company, funds, loan,
# contracts done and time played and goes back where it was left; an empty
# slot asks for a company name and begins at ARRIVAL, straight on into the
# training course and the first contract. Settings, quit.

var _wiping := false       # the transition out has been asked for
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
# the pointer, eased: the scene leans with it (2026-10-18, player: "more
# animation, and interaction with the mouse")
var ms := Vector2.ZERO
var pointer_override := Vector2.INF   # tests point here instead (the real mouse is never moved)
var par := Vector2.ZERO
var bar_y := Motion.Spring.new(0.0, 420.0, 0.8)
var bar_a := Motion.Spring.new(0.0, 300.0, 0.9)
var item_k: Array = []
var kb_sel := 0
var press_i := -1
var press_t := 0.0
var _last_hover := -1
var tilt: Array = []             # per card: [x, y] springs, the lean toward the pointer
var bay := ""                    # the title ship's bay under the pointer
var bay_rect := Rect2()
var bay_k := Motion.Spring.new(0.0, 300.0, 0.9)
var sfx: Sfx
var glow_tex: Texture2D
var item_pour: Array = []        # the pointer's pour on each menu item, and on "back"
var back_pour: Pour
# the title ship's bays, in its metres: GR-7's rooms, and its drive
const BAYS := [[Rect2(0.2, -4.0, 4.8, 8.0), "room_A"], [Rect2(5.0, -4.0, 5.0, 8.0), "room_B"], [Rect2(10.0, -4.0, 17.0, 8.0), "room_C"],
	[Rect2(27.0, -4.0, 6.0, 4.0), "room_D"], [Rect2(27.0, 0.0, 6.0, 4.0), "room_E"], [Rect2(33.0, -3.1, 8.6, 6.2), "t_bay_drive"]]
const HOLD := Rect2(10.0, -3.55, 17.0, 6.5)


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
		tilt.append([Motion.Spring.new(0.0, 160.0, 0.8), Motion.Spring.new(0.0, 160.0, 0.8)])
	for i in 3:
		item_k.append(Motion.Spring.new(0.0, 360.0, 0.75))
	sfx = Sfx.new()
	add_child(sfx)
	for i in 3:
		item_pour.append(Pour.make(self))
	back_pour = Pour.make(self)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	glow_tex = gt
	ms = get_viewport_rect().size * 0.5
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
	if Txt.anim_level() == 0:
		view_k.snap(1.0)
	sfx.play("switch", Vector2.INF, 0.7)
	slots_t = 0.0
	del_confirm = -1
	slot_sel = 0
	for i in slots.size():
		if not slots[i].is_empty():
			slot_sel = i
			break


func _close_slots() -> void:
	view_k.target = 0.0
	if Txt.anim_level() == 0:
		view_k.snap(0.0)
	sfx.play("switch", Vector2.INF, 0.6)
	_stop_naming()


func _process(dt: float) -> void:
	t += dt
	slots_t += dt
	view_k.step(dt)
	hover = -1
	slot_hover = -1
	del_hover = -1
	var m := get_local_mouse_position() if pointer_override == Vector2.INF else pointer_override
	var lvl := Txt.anim_level()
	ms = ms.lerp(m, 1.0 - exp(-10.0 * dt))
	var half := size * 0.5
	par = ((ms - half) / half).clamp(Vector2(-1, -1), Vector2(1, 1)) if lvl >= 2 else Vector2.ZERO
	if not _in_slots():
		for i in _items().size():
			if _item_rect(i).has_point(m):
				hover = i
				kb_sel = i
	else:
		for i in Career.SLOTS:
			if _slot_rect(i).has_point(m):
				slot_hover = i
			if not slots[i].is_empty() and _del_rect(i).has_point(m):
				del_hover = i
		if _back_rect().has_point(m):
			hover = 99
	# the menu's one highlight glides to the item in hand
	var on_item := hover if hover >= 0 else (kb_sel if t > 2.4 else -1)
	if on_item >= 0 and not _in_slots():
		bar_y.target = _item_rect(on_item).position.y
		if bar_a.x < 0.05:
			bar_y.snap(bar_y.target)
	bar_a.target = 1.0 if on_item >= 0 and not _in_slots() else 0.0
	for i in item_k.size():
		item_k[i].target = 1.0 if i == on_item and not _in_slots() else 0.0
		item_k[i].step(dt)
	if lvl == 0:
		bar_y.snap(bar_y.target)
	bar_y.step(dt)
	bar_a.step(dt)
	if hover != _last_hover and hover >= 0 and hover != 99 and t > 2.2:
		sfx.play("menu", Vector2.INF, 0.35)
	_last_hover = hover
	press_t = maxf(0.0, press_t - dt)
	var busy := leaving >= 0.0 or settings.is_open or naming >= 0
	for i in item_pour.size():
		item_pour[i].place(_menu_rect(i), hover == i and not _in_slots() and not busy and t > 2.4, m)
	back_pour.place(_back_rect(), hover == 99 and _in_slots() and not busy, m)
	# the bay under the pointer, on the title's ship
	var vk0 := clampf(view_k.x, 0.0, 1.0)
	var xf := _ship_xf(vk0)
	var mp: Vector2 = (ms - xf[1]) / float(xf[0])
	var found := ""
	if vk0 < 0.3 and t > 2.2 and leaving < 0.0:
		for b in BAYS:
			if (b[0] as Rect2).has_point(mp):
				found = b[1]
				bay_rect = b[0]
	if found != "":
		bay = found
	bay_k.target = 1.0 if found != "" else 0.0
	bay_k.step(dt)
	for i in Career.SLOTS:
		slot_lift[i].target = 1.0 if (i == slot_hover or (slot_hover < 0 and i == slot_sel and _in_slots())) or i == naming else 0.0
		slot_lift[i].step(dt)
		# the card under the pointer leans toward it
		var r := _slot_rect(i)
		var lean := Vector2.ZERO
		if i == slot_hover and lvl >= 2:
			lean = ((m - r.get_center()) / (r.size * 0.5)).clamp(Vector2(-1, -1), Vector2(1, 1))
		tilt[i][0].target = lean.x
		tilt[i][1].target = lean.y
		tilt[i][0].step(dt)
		tilt[i][1].step(dt)
	if naming >= 0:
		var r := _slot_rect(naming)
		name_edit.position = r.position + Vector2(28, 150 - slot_lift[naming].x * 8.0)
		name_edit.size = Vector2(r.size.x - 56, 46)
	if music != null:
		music_k = Pal.damp(music_k, 0.0 if leaving >= 0.0 else 0.55, 1.5 if leaving < 0.0 else 6.0, dt)
		music.volume_db = linear_to_db(maxf(0.0001, music_k))
	if leaving >= 0.0:
		leaving += dt
		# its own leave plays first, then the transition covers the change
		if leaving > 0.1 and not _wiping:
			_wiping = true
			var tree := get_tree()
			var to := next_scene
			Wipe.go(tree, func():
				if to == "career":
					Game.play_career(tree)
				else:
					tree.change_scene_to_file(to))
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or leaving >= 0.0:
		return
	if t < 2.0:
		t = 2.0
		return
	if not _in_slots():
		if hover >= 0:
			press_i = hover
			press_t = 0.18
			sfx.play("ok", Vector2.INF, 0.5)
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
	if DevPanel.workbench_open and Txt.dev:
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or leaving >= 0.0:
		return
	var k: int = ev.physical_keycode
	if t < 2.0:
		if k in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			t = 2.0
		return
	if not _in_slots():
		match k:
			KEY_UP, KEY_W:
				kb_sel = maxi(0, kb_sel - 1)
				sfx.play("menu", Vector2.INF, 0.35)
			KEY_DOWN, KEY_S:
				kb_sel = mini(_items().size() - 1, kb_sel + 1)
				sfx.play("menu", Vector2.INF, 0.35)
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
				press_i = kb_sel
				press_t = 0.18
				sfx.play("ok", Vector2.INF, 0.5)
				_pick(_items()[kb_sel][0])
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


# the title ship's scale (px per metre) and origin: at rest over the title,
# and dived into, its cargo hold opened out into the frame round the cards
func _ship_xf(vk: float) -> Array:
	var s := size
	var sc0 := s.x * 0.62 / 42.0
	var o0 := Vector2(s.x * 0.5 - 21.0 * sc0 + sin(t * 0.2) * 6.0, s.y * 0.33 + sin(t * 0.33) * 4.0) - par * 14.0
	if Txt.anim_level() < 2:
		# no dive: it draws back and up, as it used to
		var scl := sc0 * (1.0 - 0.25 * vk)
		return [scl, Vector2(s.x * 0.5 - 21.0 * scl, s.y * (0.33 - 0.17 * vk))]
	var e := Pal.ease_io(vk)
	var f := _frame_rect()
	var sc1 := f.size.x / HOLD.size.x
	var o1 := Vector2(f.position.x - HOLD.position.x * sc1, f.get_center().y - (HOLD.position.y + HOLD.size.y * 0.5) * sc1)
	return [lerpf(sc0, sc1, e), o0.lerp(o1, e)]


# the space the cards sit in, which the hold becomes
func _frame_rect() -> Rect2:
	var a := _slot_rect(0)
	var b := _slot_rect(Career.SLOTS - 1)
	var r := Rect2(a.position, b.end - a.position)
	r.position.y += 15.0
	return r.grow_individual(70.0, 0.0, 70.0, 0.0)


func _draw() -> void:
	var s := size
	var vk := clampf(view_k.x, 0.0, 1.0)
	var lvl := Txt.anim_level()
	var dive := Pal.ease_io(vk) if lvl >= 2 else 0.0
	draw_rect(Rect2(Vector2.ZERO, s), Pal.BG)
	# dust: far layers lean least; through the dive it streams out from the middle
	var rush := clampf(absf(view_k.v) * 0.25, 0.0, 1.0) * (1.0 if lvl >= 2 else 0.0)
	var mid := s * 0.5
	for d in dust:
		var p: Vector2 = d[0]
		var depth: float = d[1] / 0.02
		var q := Vector2(fposmod(p.x + t * d[1] * (1.0 + vk * 2.0), 1.0) * s.x, p.y * s.y) - par * (4.0 + 18.0 * depth)
		var da := 0.05 + 0.04 * sin(t + d[2])
		if rush > 0.02:
			var dir := (q - mid).normalized()
			draw_line(q, q + dir * (20.0 + 220.0 * depth) * rush, Pal.ink(da * 3.0 * rush), 1.0, true)
		else:
			draw_circle(q, 1.0, Pal.ink(da))
	# the ship, drawn as one continuous pen
	var xf := _ship_xf(vk)
	var scale: float = xf[0]
	var origin: Vector2 = xf[1]
	var k := Pal.ease_io(clampf(t / 2.2, 0.0, 1.0)) * total_len
	var used := 0.0
	var tip := Vector2.INF
	var dim := 1.0 - 0.6 * vk
	# the pointer's inspection light: the lines it passes over come up
	var light := clampf((t - 2.2) / 0.6, 0.0, 1.0) * (1.0 - vk) * (1.0 if leaving < 0.0 else 0.0)
	var mp := (ms - origin) / scale
	var lr := 3.4
	if light > 0.0:
		draw_texture_rect(glow_tex, Rect2(ms - Vector2(150, 150), Vector2(300, 300)), false, Pal.tint(Pal.AIR, 0.07 * light, 1.0))
	if bay_k.x > 0.01 and light > 0.0:
		var br := Rect2(origin + bay_rect.position * scale, bay_rect.size * scale)
		draw_rect(br, Pal.tint(Pal.AIR, 0.045 * bay_k.x * light, 1.0))
	for si in strokes.size():
		var st: PackedVector2Array = strokes[si]
		# through the dive only the hull and the hold's two bulkheads stay: they become the frame
		var frame_line := si == 0 or si == 2 or si == 3
		var sa := (0.75 if si == 0 else 0.32) * dim
		if not frame_line:
			sa *= 1.0 - dive
		else:
			sa = lerpf(sa, 0.3, dive)
		for i in st.size() - 1:
			var a: Vector2 = st[i]
			var b: Vector2 = st[i + 1]
			var l := a.distance_to(b)
			if used >= k:
				break
			var f := clampf((k - used) / l, 0.0, 1.0)
			var e := a.lerp(b, f)
			if sa > 0.004:
				draw_line(origin + a * scale, origin + e * scale, Pal.ink(sa), 1.6 if si == 0 else 1.0, true)
				if light > 0.0:
					_lit(a, e, mp, lr, origin, scale, light)
			if f < 1.0:
				tip = origin + e * scale
			used += l
	if tip != Vector2.INF:
		draw_circle(tip, 3.0, Pal.heat(1.0, 2.0))
		draw_circle(tip, 8.0, Pal.heat(0.25, 1.4))
	# the bay under the pointer, named beside it
	if bay_k.x > 0.01 and light > 0.0 and bay != "":
		var ba := bay_k.x * light
		var lp := ms + Vector2(26, -34)
		var nm := Txt.t(bay)
		var w := font_b.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_line(ms + Vector2(6, -6), lp + Vector2(-4, 8), Pal.tint(Pal.AIR, 0.6 * ba, 1.2), 1.0, true)
		draw_rect(Rect2(lp + Vector2(-8, -16), Vector2(w + 34, 26)), Color(0.02, 0.022, 0.026, 0.85 * ba))
		draw_rect(Rect2(lp + Vector2(-8, -16), Vector2(2, 26)), Pal.tint(Pal.AIR, ba, 1.3))
		draw_string(font_b, lp + Vector2(4, 2), "◇ " + nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.92 * ba))
	# title: it rises in; through the dive it rushes toward the viewer and fades
	# out of the way early in the dive, so it doesn't cross the ship's lines
	var gone := clampf(1.0 - vk * (2.4 if lvl >= 2 else 1.0), 0.0, 1.0)
	var ta := clampf((t - 1.4) / 0.8, 0.0, 1.0) * gone
	var rise := (1.0 - Pal.ease_out(clampf((t - 1.4) / 0.8, 0.0, 1.0))) * 20.0 - vk * (40.0 if lvl < 2 else 0.0)
	if ta > 0.005:
		var tc := Vector2(s.x * 0.5, s.y * 0.62) - par * 6.0
		draw_set_transform(tc, 0.0, Vector2.ONE * (1.0 + 0.35 * dive))
		var title := Txt.t("t_title")
		var tw := font_l.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		draw_string(font_l, Vector2(-tw * 0.5, rise), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Pal.ink(0.96 * ta))
		var sub := Txt.t("t_sub")
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(-sw * 0.5, 40 + rise), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.45 * ta))
		draw_rect(Rect2(-60 * ta, 56 + rise, 120 * ta, 2), Pal.heat(ta, 1.0))
		draw_set_transform(Vector2.ZERO)
		_menu(s, vk, dive)
	if vk > 0.005:
		_draw_slots(s, vk)
	if leaving >= 0.0:
		_leave(s)


# a stroke's stretch inside the inspection light, brightened toward its middle
func _lit(a: Vector2, b: Vector2, c: Vector2, r: float, origin: Vector2, scale: float, k: float) -> void:
	var d := b - a
	var l2 := d.length_squared()
	if l2 < 0.0001:
		return
	var u := clampf((c - a).dot(d) / l2, 0.0, 1.0)
	if (a + d * u).distance_to(c) > r:
		return
	var n := 6
	var span := r / sqrt(l2)
	var u0 := clampf(u - span, 0.0, 1.0)
	var u1 := clampf(u + span, 0.0, 1.0)
	for q in n:
		var p0 := a + d * lerpf(u0, u1, float(q) / n)
		var p1 := a + d * lerpf(u0, u1, float(q + 1) / n)
		var fall := 1.0 - clampf(((p0 + p1) * 0.5).distance_to(c) / r, 0.0, 1.0)
		if fall > 0.02:
			draw_line(origin + p0 * scale, origin + p1 * scale, Pal.tint(Pal.AIR, 0.9 * fall * k, 1.0 + 0.8 * fall), 1.4 + 0.8 * fall, true)


# a menu item where it's drawn this frame (the parallax, the rise in, the dive)
func _menu_rect(i: int) -> Rect2:
	var vk := clampf(view_k.x, 0.0, 1.0)
	var ia := clampf((t - 2.0 - i * 0.08) / 0.35, 0.0, 1.0)
	var r := _item_rect(i)
	r.position += -par * 4.0
	r.position.y += (1.0 - Pal.ease_out(ia)) * 16.0 + vk * 30.0
	return r


# the title menu: one highlight that glides to the item in hand; the item's
# letters open out a little; pressed, it sinks and springs back
func _menu(s: Vector2, vk: float, dive: float) -> void:
	var items := _items()
	var ma := clampf(1.0 - vk * (2.4 if Txt.anim_level() >= 2 else 1.0), 0.0, 1.0)
	var off := -par * 4.0
	if bar_a.x > 0.01:
		var r0 := _item_rect(0)
		var br := Rect2(r0.position.x + off.x, bar_y.x + off.y + vk * 30.0, r0.size.x, r0.size.y)
		Pal.band(self, br, 0.12 * bar_a.x * ma)
		var uw := 72.0 * bar_a.x
		draw_rect(Rect2(br.get_center().x - uw * 0.5, br.end.y - 2, uw, 2), Pal.heat(bar_a.x * ma, 1.0))
	for i in items.size():
		var ia := clampf((t - 2.0 - i * 0.08) / 0.35, 0.0, 1.0) * ma
		var r := _item_rect(i)
		r.position += off
		r.position.y += (1.0 - Pal.ease_out(ia)) * 16.0 + vk * 30.0
		if i == press_i and press_t > 0.0:
			r.position.y += 3.0 * sin(press_t / 0.18 * PI)
		var hk: float = item_k[i].x
		var txt: String = items[i][1]
		var gap := 3.0 * hk
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + gap * (txt.length() - 1)
		var x := r.get_center().x - w * 0.5
		var col := Pal.ink((0.55 + 0.4 * hk) * ia)
		for ch in txt:
			draw_string(font, Vector2(x, r.position.y + 30), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + gap


func _draw_slots(s: Vector2, vk: float) -> void:
	var lvl := Txt.anim_level()
	# through the dive the cards wait for the hold to open round them
	var delay := 0.3 if lvl >= 2 else 0.0
	var st := slots_t - delay
	var head := Txt.t("t_slots")
	var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var hk := clampf(st / 0.3, 0.0, 1.0) * vk
	draw_string(font, Vector2(s.x * 0.5 - hw * 0.5, _slot_rect(0).position.y - 34 + (1.0 - hk) * 20.0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.45 * hk))
	for i in Career.SLOTS:
		var raw := Motion.stagger(st, i, 0.07, 0.45)
		var e := Pal.ease_out(raw) * vk
		if e < 0.005:
			continue
		var lift: float = slot_lift[i].x
		var r := _slot_rect(i)
		r.position.y += (1.0 - (Pal.back(raw, 1.6) if lvl >= 2 else Pal.ease_out(raw))) * 60.0 - lift * 8.0
		# the lean: the side under the pointer dips, the card comes up a touch
		var tx: float = tilt[i][0].x
		var ty: float = tilt[i][1].x
		var c := r.get_center()
		var scl := 1.0 + 0.015 * lift
		var ax := Vector2(scl, tx * 0.035 * scl)
		var ay := Vector2(ty * 0.03 * scl, scl)
		draw_set_transform_matrix(Transform2D(ax, ay, c - ax * c.x - ay * c.y))
		_card(i, r, e, lift, st, lvl)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_slots_foot(s, vk, st)


func _card(i: int, r: Rect2, e: float, lift: float, st: float, lvl: int) -> void:
	var d: Dictionary = slots[i] if i < slots.size() else {}
	var on := lift
	draw_rect(r, Color(0.03 + 0.012 * on, 0.032 + 0.012 * on, 0.037 + 0.012 * on, 0.94 * e))
	if on > 0.02 and lvl >= 1:
		_sheen(r, ms.x, 0.05 * on * e)
	draw_rect(r, Pal.ink((0.14 + 0.4 * on) * e), false, 1.0)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - on) * 0.5), Vector2(3, r.size.y * on)), Pal.heat(e, 1.1))
	var x := r.position.x + 28
	draw_string(font, Vector2(x, r.position.y + 34), Txt.t("t_slot") % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.4 * e))
	if d.is_empty():
		if naming == i:
			draw_string(font, Vector2(x, r.position.y + 132), Txt.t("t_company"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.45 * e))
			draw_string(font, Vector2(x, r.position.y + 236), Txt.t("t_slot_new_d"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 13, Pal.ink(0.4 * e))
			return
		var c := r.get_center() + Vector2(0, -10)
		var pk := 0.85 + 0.15 * on
		draw_line(c + Vector2(-14, 0) * pk, c + Vector2(14, 0) * pk, Pal.ink((0.35 + 0.5 * on) * e), 1.6, true)
		draw_line(c + Vector2(0, -14) * pk, c + Vector2(0, 14) * pk, Pal.ink((0.35 + 0.5 * on) * e), 1.6, true)
		draw_arc(c, 30.0 + 4.0 * on, 0.0, TAU, 40, Pal.ink((0.12 + 0.3 * on) * e), 1.0, true)
		_center(Txt.t("t_slot_new") if on > 0.5 else Txt.t("t_slot_empty"), Vector2(c.x, c.y + 70), 18, Pal.ink((0.5 + 0.45 * on) * e), font)
		return
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
	var roll := Pal.ease_out(clampf((st - 0.15 - i * 0.07) / 0.8, 0.0, 1.0)) if lvl >= 1 else 1.0
	var secs := int(float(d.get("time", 0.0)) * roll)
	var rows := [
		[Txt.t("t_slot_funds"), Pal.money(float(d.get("money", 0.0)) * roll)],
		[Txt.t("t_slot_loan"), Pal.money(float(d.get("loan", 0.0)) * roll)],
		[Txt.t("t_slot_done"), Txt.t("t_slot_done_n") % int(round(float(d.get("done", 0)) * roll))],
		[Txt.t("t_slot_rep"), Txt.t("rep_" + lv)],
		[Txt.t("t_slot_time"), "%d:%02d" % [secs / 3600, (secs / 60) % 60]],
	]
	for j in rows.size():
		var y := r.position.y + 128 + j * 30
		var re := Pal.ease_out(Motion.stagger(st, i * 3 + j + 2, 0.03, 0.3))
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


func _slots_foot(s: Vector2, vk: float, st: float) -> void:
	# back, and the keys
	var br := _back_rect()
	var ba := vk * clampf((st - 0.25) / 0.3, 0.0, 1.0)
	if hover == 99:
		Pal.band(self, br, 0.12 * ba)
		draw_rect(Rect2(br.get_center().x - 30, br.end.y - 2, 60, 2), Pal.heat(ba, 1.0))
	_center(Txt.t("t_slot_back"), Vector2(br.get_center().x, br.position.y + 27), 17, Pal.ink((0.9 if hover == 99 else 0.5) * ba), font)
	_center(Txt.t("t_slot_keys"), Vector2(s.x * 0.5, s.y - 32), 12, Pal.ink(0.25 * ba), font)


# a soft slanted band of light across a card, where the pointer is
func _sheen(r: Rect2, px: float, a: float) -> void:
	var hw := 70.0
	var slant := r.size.y * 0.35
	var top := px + slant * 0.5
	var bot := px - slant * 0.5
	for side: float in [-1.0, 1.0]:
		var band := PackedVector2Array([Vector2(top, r.position.y - 1), Vector2(top + hw * side, r.position.y - 1), Vector2(bot + hw * side, r.end.y + 1), Vector2(bot, r.end.y + 1)])
		var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		for poly in Geometry2D.intersect_polygons(box, band):
			if poly.size() < 3:
				continue
			var cols := PackedColorArray()
			for p in poly:
				var cx := lerpf(top, bot, (p.y - r.position.y) / r.size.y)
				cols.append(Color(1, 1, 1, a * (1.0 - clampf(absf(p.x - cx) / hw, 0.0, 1.0))))
			draw_polygon(poly, cols)


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
