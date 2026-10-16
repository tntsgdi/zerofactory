class_name StoryHud
extends CanvasLayer
# What the story puts on screen: the CONTRACT ACTIVE banner, terminal cards
# (the recorder, the archive), the flight recording (a white waveform across
# the lower third, timestamped subtitles typing in), marks on things you can
# still inspect, and the ending: the recording over the empty berth, the
# chapter stamp and the next contract card.

var game: Game
var c: Control
var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var noise := 0.0               # the waveform bursts into white noise
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
	if game == null or game.story == null:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if game.state == "ending" and game.story.phase in ["recording", "closing", "chapter", "next"]:
			game.story.ending_key(KEY_SPACE)
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if game == null or game.story == null:
		return
	t += dt
	var ln: Array = game.story.rec_line()
	if not ln.is_empty() and ln.size() > 4 and ln[4] == "burst" and game.story.rec.t < 0.05:
		noise = 1.0
	noise = maxf(0.0, noise - dt * 1.2)
	if game.story.phase == "chapter" and game.story.phase_t >= 0.18 and not stamped:
		stamped = true
		game.sfx.play("stamp")
		game.shake(0.35)
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
	var st: Story = game.story
	if st == null or not st.active():
		return
	var s := c.size
	if game.state == "play" and not game.menu_open:
		_marks()
		if st.banner_t >= 0.0:
			_banner(s, st.banner_t)
		if not st.card.is_empty():
			_card(s, st.card)
		if not st.rec.is_empty():
			_recording(s, false)
	elif game.state == "ending":
		match st.phase:
			"recording":
				_recording(s, true)
			"chapter":
				_chapter(s, st.phase_t)
			"next":
				_next_card(s, st.phase_t)


# ---------------------------------------------------------------- in play

# things on board that can still be inspected: a faint diamond while tool 1 is out
func _marks() -> void:
	var st: Story = game.story
	if game.tools.tool != 1:
		return
	var w = game.world
	for tag in st.items:
		var it: Dictionary = st.items[tag]
		var p = w.tag(tag)
		if p == null or p.gone:
			continue
		var wp: Vector2 = w.frame(p) * Geom.centroid(p.poly)
		if w.hidden(wp):
			continue
		var sp: Vector2 = game.hud.to_screen(wp)
		var done: bool = st.found.has(it.id)
		var a := (0.18 if done else 0.4 + 0.25 * sin(t * 2.4 + tag.length()))
		var r := 6.0
		var dia := PackedVector2Array([sp + Vector2(0, -r), sp + Vector2(r, 0), sp + Vector2(0, r), sp + Vector2(-r, 0), sp + Vector2(0, -r)])
		c.draw_polyline(dia, Pal.tint(Pal.AIR, a, 1.1), 1.2, true)
		if st.last_found == it.id and st.last_found_t < 0.6:
			var k := st.last_found_t / 0.6
			c.draw_arc(sp, 8.0 + 40.0 * Pal.ease_out(k), 0.0, TAU, 32, Pal.tint(Pal.AIR, 0.8 * (1.0 - k), 1.3), 1.5, true)


func _banner(s: Vector2, e: float) -> void:
	var rows: Array = game.story.data.get("banner", [])
	if rows.size() < 2:
		return
	var row: Array = rows[0] if Txt.zh else rows[1]
	var a := clampf(e / 0.25, 0.0, 1.0) * clampf((4.0 - e) / 0.5, 0.0, 1.0)
	var y := s.y * 0.2 + (1.0 - Pal.ease_out(clampf(e / 0.25, 0.0, 1.0))) * 12.0
	var w := 560.0
	c.draw_rect(Rect2(s.x * 0.5 - w * 0.5, y - 34, w, 74), Color(0.02, 0.022, 0.026, 0.82 * a))
	c.draw_rect(Rect2(s.x * 0.5 - w * 0.5, y - 34, 3, 74), Pal.heat(a, 1.0))
	_text(row[0], Vector2(s.x * 0.5, y), 24, Pal.ink(0.95 * a), font_b, 0)
	_text(row[1], Vector2(s.x * 0.5, y + 26), 15, Pal.ink(0.6 * a), font, 0)


# the berth terminal: cyan monospace-ish rows, a block cursor
func _card(s: Vector2, cd: Dictionary) -> void:
	var rows: Array = cd.rows
	var e: float = cd.t
	var a := clampf(e / 0.2, 0.0, 1.0) * clampf((cd.dur - e) / 0.4, 0.0, 1.0)
	var w := 520.0
	var h := 26.0 + rows.size() * 26.0
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y * 0.2 - 30, w, h)
	c.draw_rect(r, Color(0.02, 0.03, 0.035, 0.88 * a))
	c.draw_rect(r, Pal.tint(Pal.AIR, 0.35 * a, 1.0), false, 1.0)
	var shown := int(e * 60.0)
	var used := 0
	for i in rows.size():
		var row: String = rows[i]
		var n := clampi(shown - used, 0, row.length())
		used += row.length()
		_text(row.substr(0, n), r.position + Vector2(20, 30 + i * 26), 16 if i == 0 else 14, Pal.tint(Pal.AIR, (0.95 if i == 0 else 0.7) * a, 1.1), font_b if i == 0 else font)
		if n < row.length():
			var cw := font.get_string_size(row.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			c.draw_rect(Rect2(r.position.x + 22 + cw, r.position.y + 16 + i * 26, 8, 16), Pal.tint(Pal.AIR, a * (0.5 + 0.5 * sin(t * 20.0))))
			break


# ---------------------------------------------------------------- the recording

func _recording(s: Vector2, full: bool) -> void:
	var st: Story = game.story
	var rec: Dictionary = st.rec
	if rec.is_empty():
		return
	var y := s.y * 0.72
	if full:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(st.phase_t / 1.0, 0.0, 1.0) * 0.6))
		# the subtitles sit on a darker band
		c.draw_rect(Rect2(0, y - 190, s.x, 300), Color(0, 0, 0, clampf(st.phase_t / 1.0, 0.0, 1.0) * 0.55))
		var ep: Dictionary = st.data.get("epilogue", {})
		var ca := clampf(st.phase_t / 0.6, 0.0, 1.0)
		_text(st.pair(ep.get("card", ["", ""])), Vector2(s.x * 0.5, s.y * 0.2), 18, Pal.tint(Pal.AIR, 0.85 * ca, 1.1), font_b, 0)
		_text(game.txt("st_skip"), Vector2(s.x * 0.5, s.y - 40), 13, Pal.ink(0.3), font, 0)
		# what has been said already, fading upwards
		for k in range(1, 4):
			var j: int = rec.i - k
			if j < 0:
				break
			var old: Array = rec.lines[j]
			var oy := y - 86 - (k - 1) * 30
			_text("[%s]  %s：%s" % [old[0], st.who(old[1]), old[2] if Txt.zh else old[3]], Vector2(s.x * 0.5, oy), 14, Pal.ink(0.32 / k), font, 0)
	var ln: Array = st.rec_line()
	var alarm: bool = not ln.is_empty() and ln[1] == "alarm"
	# the waveform: flat in the gaps, alive while someone speaks
	var x0 := s.x * 0.18
	var x1 := s.x * 0.82
	var pts := PackedVector2Array()
	var amp := (16.0 if st.speaking() else 2.0) + noise * 30.0
	var n := 160
	for i in n + 1:
		var u := float(i) / n
		var env := sin(u * PI)
		var v := sin(u * 47.0 + t * 19.0) * sin(u * 13.0 - t * 7.0) * 0.7 + sin(u * 91.0 + t * 31.0) * 0.3
		if noise > 0.0:
			v = lerpf(v, randf_range(-1.0, 1.0), noise)
		pts.append(Vector2(lerpf(x0, x1, u), y + v * amp * env))
	var wcol := Pal.heat(0.9, 1.3) if alarm else Pal.ink(0.75)
	c.draw_polyline(pts, wcol, 1.4, true)
	if ln.is_empty():
		return
	var said: String = ln[2] if Txt.zh else ln[3]
	var shown := said.substr(0, int(rec.t * Story.TYPE_CPS))
	var name: String = st.who(ln[1]) if full else (st.who("unknown") if ln[1] != "alarm" else st.who("alarm"))
	var a := clampf(rec.t / 0.2, 0.0, 1.0)
	_text("[%s]  %s" % [ln[0], name], Vector2(s.x * 0.5, y + 44), 13, (Pal.heat(0.8 * a, 1.1) if alarm else Pal.ink(0.5 * a)), font, 0)
	_text(shown, Vector2(s.x * 0.5, y + 74), 20, Pal.ink(0.95 * a), font, 0)
	if not full:
		_text("FLIGHT RECORDER · DATA INTEGRITY 67%", Vector2(s.x * 0.5, y - 34), 11, Pal.tint(Pal.AIR, 0.5, 1.0), font, 0)


# ---------------------------------------------------------------- chapter stamp and the next contract

func _chapter(s: Vector2, e: float) -> void:
	var ch: Array = game.story.data.get("epilogue", {}).get("chapter", [])
	if ch.is_empty():
		return
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6 * clampf(e / 0.3, 0.0, 1.0)))
	var k := clampf(e / 0.18, 0.0, 1.0)
	var sc := lerpf(2.2, 1.0, Pal.ease_in(k))
	var a := clampf(e / 0.1, 0.0, 1.0)
	var ctr := Vector2(s.x * 0.5, s.y * 0.45)
	c.draw_set_transform(ctr, deg_to_rad(-10.0), Vector2(sc, sc))
	var col := Pal.ink(0.95 * a)
	c.draw_arc(Vector2.ZERO, 168.0, 0.0, TAU, 96, col, 4.0, true)
	c.draw_arc(Vector2.ZERO, 152.0, 0.0, TAU, 96, Color(col.r, col.g, col.b, col.a * 0.5), 1.5, true)
	var title: String = game.story.pair(ch[0])
	# a long title shrinks to sit inside the ring
	var ts := clampi(int(30.0 * 300.0 / maxf(1.0, font_b.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x)), 18, 30)
	var tw := font_b.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	c.draw_string(font_b, Vector2(-tw * 0.5, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, col)
	var sub: String = ch[1]
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(font, Vector2(-sw * 0.5, 30), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.heat(a, 1.2))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _next_card(s: Vector2, e: float) -> void:
	var nx: Dictionary = game.story.data.get("epilogue", {}).get("next", {})
	if nx.is_empty():
		return
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.88))
	var k := Pal.ease_out(clampf(e / 0.3, 0.0, 1.0))
	var w := 640.0
	var h := 360.0
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y * 0.5 - h * 0.5 + (1.0 - k) * 40.0, w, h)
	c.draw_rect(r, Color(0.03, 0.032, 0.037, k))
	c.draw_rect(r, Pal.ink(0.22 * k), false, 1.0)
	c.draw_rect(Rect2(r.position, Vector2(3, h)), Pal.heat(k, 1.0))
	var x := r.position.x + 44
	_text(nx.get("from", ""), Vector2(x, r.position.y + 44), 12, Pal.tint(Pal.AIR, 0.7 * k, 1.0), font)
	_text(nx.get("id", ""), Vector2(x, r.position.y + 94), 40, Pal.ink(0.95 * k), font_l)
	_text(game.story.pair(nx.get("name", ["", ""])), Vector2(x, r.position.y + 128), 20, Pal.ink(0.75 * k), font_b)
	var rows: Array = nx.get("rows", [])
	for i in rows.size():
		var re := clampf((e - 0.4 - i * 0.25) / 0.2, 0.0, 1.0)
		_text(game.story.pair(rows[i]), Vector2(x, r.position.y + 176 + i * 30), 16, Pal.ink((0.85 if i == rows.size() - 1 else 0.6) * re), font)
	var te := clampf((e - 1.4) / 0.4, 0.0, 1.0)
	if te > 0.0:
		var slam := Pal.back(te, 2.4)
		_text(game.story.pair(nx.get("tbc", ["", ""])), Vector2(r.end.x - 44, r.end.y - 34), int(22 * maxf(slam, 0.05)), Pal.heat(te, 1.2), font_b, 1)
		_text(game.txt("st_to_title"), Vector2(s.x * 0.5, r.end.y + 50), 13, Pal.ink(0.3 + 0.2 * sin(t * 3.0)), font, 0)
