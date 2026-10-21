class_name CodexHud
extends CanvasLayer
# The card for something met for the first time (scripts/codex.gd): under the
# contract panel (under the task list in training), the thing's own drawing on
# the left, three sentences on the right — what it is, why it is dangerous,
# what to do. Never pauses; I opens the book on it, a click on the card too,
# the cross (or Backspace) puts it away. The mouse on the card holds it.

const W := 520.0
const ART_W := 118.0
const TXT_W := 362.0
const FS := 14
const LINE_H := 19.0

var game: Game
var c: Control
var font: Font
var font_b: Font
var k := 0.0                  # slide in / out
var shown := ""               # the entry being drawn (stays while sliding out)
var page = null               # the book, while open
var rect := Rect2()
var brief_rect := Rect2()     # the contract card's "new on this ship" block


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_card)
	add_child(c)


func _process(dt: float) -> void:
	if game == null or game.codex == null:
		return
	var cx: Codex = game.codex
	if cx.card != "":
		shown = cx.card
	var want := 1.0 if cx.card != "" and game.state == "play" and not game.menu_open and page == null else 0.0
	k = Pal.damp(k, want, 12.0 if want > 0.5 else 16.0, dt)
	if k < 0.01 and cx.card == "":
		shown = ""
	cx.held = cx.card != "" and rect.has_point(c.get_local_mouse_position()) and k > 0.5
	c.queue_redraw()


func _input(ev: InputEvent) -> void:
	if game == null or game.codex == null or page != null:
		return
	if game.state != "play" or game.settings_panel.visible:
		return
	if Keys.pressed(ev, "codex") and not game.menu_open:
		if game.contract_open:
			open_brief()
		else:
			open_book(game.codex.card if game.codex.card != "" else game.codex.last)
		get_viewport().set_input_as_handled()
		return
	if game.codex.card == "" or k < 0.5:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_BACKSPACE:
		game.codex.dismiss()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and rect.has_point(c.get_local_mouse_position()):
		if _close_rect().has_point(c.get_local_mouse_position()):
			game.codex.dismiss()
		else:
			open_book(game.codex.card)
		get_viewport().set_input_as_handled()


# the book on this ship's own mechanisms (from the contract card)
func open_brief() -> void:
	var l := Codex.ship_entries(game.ship_id)
	open_book(l[0] if not l.is_empty() else "", "", not l.is_empty())


# the book over the game, play paused while it is open
func open_book(focus: String = "", filter_ship: String = "", ship_only: bool = false) -> void:
	if page != null:
		return
	var was_paused := get_tree().paused
	get_tree().paused = true
	if game.codex.card != "" and focus == game.codex.card:
		game.codex.dismiss()
	page = CodexPage.open(game, focus, filter_ship if filter_ship != "" else game.ship_id, func():
		page = null
		get_tree().paused = was_paused and game.menu_open, ship_only)
	game.sfx.play("menu")


# on the contract card: the ship's own mechanisms, named, and where to read about them
func draw_brief(ci: CanvasItem, at: Vector2, w: float, a: float) -> void:
	var l := Codex.ship_entries(game.ship_id)
	if l.is_empty():
		brief_rect = Rect2()
		return
	var y := at.y
	UI.text(ci, font, Txt.t("cxu_brief"), Vector2(at.x, y), 13, Pal.heat(0.85 * a, 1.0))
	y += 26.0
	var shown_n := mini(l.size(), 4)
	for i in shown_n:
		ci.draw_rect(Rect2(at.x + 3, y - 9, 6, 6), Pal.heat(0.8 * a, 1.1))
		UI.text(ci, font, Codex.title(l[i]), Vector2(at.x + 20, y), 16, Pal.ink(0.9 * a))
		y += 24.0
	if l.size() > shown_n:
		UI.text(ci, font, "+%d" % (l.size() - shown_n), Vector2(at.x + 20, y), 14, Pal.ink(0.5 * a))
		y += 22.0
	UI.text(ci, font, Txt.t("cxu_brief_more") % Keys.label("codex"), Vector2(at.x, y + 4), 13, Pal.ink(0.5 * a))
	brief_rect = Rect2(at - Vector2(8, 22), Vector2(w, y + 14.0 - at.y + 22.0))
	if brief_rect.has_point(ci.get_local_mouse_position()):
		ci.draw_rect(brief_rect, Pal.ink(0.2 * a), false, 1.0)


func _anchor() -> Vector2:
	var y := 300.0
	if game.training:
		y = 300.0
	elif game.hud != null:
		var r: Rect2 = game.hud._contract_rect()
		y = r.end.y + 18.0
		if game.assist != null:
			y += game.assist.cards.size() * 54.0 + (30.0 + game.assist.notes.size() * 18.0 if not game.assist.notes.is_empty() else 0.0)
	return Vector2(22.0, y)


func _close_rect() -> Rect2:
	return Rect2(rect.end.x - 30.0, rect.position.y + 6.0, 24.0, 24.0)


# ---------------------------------------------------------------- drawing

static func wrap_lines(f: Font, text: String, width: float, size_px: int) -> int:
	var tl := TextParagraph.new()
	tl.add_string(text, f, size_px)
	tl.width = width
	tl.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return tl.get_line_count()


func _para(text: String, pos: Vector2, width: float, size_px: int, col: Color, f: Font = null) -> float:
	var fo := f if f != null else font
	var tl := TextParagraph.new()
	tl.add_string(text, fo, size_px)
	tl.width = width
	tl.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var y := pos.y
	for i in tl.get_line_count():
		tl.draw_line(c.get_canvas_item(), Vector2(pos.x, y), i, col)
		y += LINE_H
	return y - pos.y


# the width of the "what / danger / do" labels in front of the sentences
static func label_w() -> float:
	return 44.0 if Txt.zh else 62.0


func card_height(id: String) -> float:
	var h := 64.0
	for part in ["a", "b", "c"]:
		h += wrap_lines(font, Codex.line(id, part), TXT_W - label_w(), FS) * LINE_H + 8.0
	return maxf(h + 30.0, 64.0 + ART_W * 0.8 + 30.0)


func _draw_card() -> void:
	if shown == "" or k < 0.01:
		return
	var id := shown
	var e: Dictionary = CodexData.E.get(id, {})
	var a := clampf(k, 0.0, 1.0)
	var ease := Pal.ease_out(a)
	var p := _anchor() + Vector2((1.0 - ease) * -60.0, 0.0)
	var h := card_height(id)
	rect = Rect2(p, Vector2(W, h))
	c.draw_rect(rect, Color(0.025, 0.027, 0.032, 0.93 * a))
	c.draw_rect(rect, Pal.ink(0.22 * a), false, 1.0)
	var acc := Pal.tint(Pal.AIR, a, 1.1) if e.get("cat", "") != "mech" else Pal.heat(a, 1.05)
	c.draw_rect(Rect2(p, Vector2(3, h)), acc)
	# the head: kind · first met, the name
	var cat_l: String = Txt.t("cxu_cat_" + str(e.get("cat", "device"))) + " · " + Txt.t("cxu_first")
	UI.text(c, font, cat_l, p + Vector2(18, 22), 12, Pal.tint(acc, 0.85 * a, 1.0))
	UI.text(c, font_b, Codex.title(id), p + Vector2(18, 48), 19, Pal.ink(0.97 * a))
	# the close cross
	var cr := _close_rect()
	var hot := cr.has_point(c.get_local_mouse_position())
	c.draw_line(cr.position + Vector2(7, 7), cr.end - Vector2(7, 7), Pal.ink((0.8 if hot else 0.4) * a), 1.5, true)
	c.draw_line(Vector2(cr.end.x - 7, cr.position.y + 7), Vector2(cr.position.x + 7, cr.end.y - 7), Pal.ink((0.8 if hot else 0.4) * a), 1.5, true)
	# the drawing
	var box := Rect2(p + Vector2(18, 66), Vector2(ART_W - 10.0, ART_W * 0.8))
	draw_art(c, id, box, font, a)
	# the three sentences
	var x := p.x + 18.0 + ART_W + 8.0
	var y := p.y + 74.0
	for part in ["a", "b", "c"]:
		var lab: String = Txt.t("cxu_" + part)
		var col: Color = Pal.heat(0.9 * a, 1.1) if part == "b" else (Pal.tint(Pal.FLUID, 0.9 * a, 1.0) if part == "c" else Pal.ink(0.55 * a))
		UI.text(c, font, lab, Vector2(x, y + 1), 12, col)
		y += _para(Codex.line(id, part), Vector2(x + label_w(), y - 14.0), TXT_W - label_w(), FS, Pal.ink(0.9 * a)) + 8.0
	# the foot: I opens the book; the time it has left
	var foot := Txt.t("cxu_more") % Keys.label("codex")
	UI.text(c, font, foot, Vector2(p.x + 18, rect.end.y - 12), 12, Pal.ink(0.45 * a))
	if game.codex.card == id:
		var left := 1.0 - clampf(game.codex.card_t / Codex.SHOW_T, 0.0, 1.0)
		c.draw_rect(Rect2(p.x + 3, rect.end.y - 2, (W - 3) * left, 2), Pal.ink(0.25 * a))


# an entry's own drawing in a box (the line art the game draws the thing with, and
# its marks); a structure or system without one gets its plain mark
static func draw_art(ci: CanvasItem, id: String, box: Rect2, f: Font, a: float = 1.0) -> void:
	var e: Dictionary = CodexData.E.get(id, {})
	var art := Codex.draw_art(id)
	var sz: Array = e.get("size", [])
	var aspect: float = float(sz[0]) / float(sz[1]) if sz.size() == 2 else 1.4
	var w := box.size.x
	var h := w / aspect
	if h > box.size.y:
		h = box.size.y
		w = h * aspect
	var r := Rect2(box.position + (box.size - Vector2(w, h)) * 0.5, Vector2(w, h))
	if art == "":
		CodexHud._glyph(ci, str(e.get("glyph", e.get("cat", ""))), r, a)
		return
	ci.draw_rect(r, Color(0.05, 0.053, 0.06, a))
	ci.draw_rect(r, Pal.ink(0.75 * a), false, 1.2)
	ci.draw_set_transform(r.position, 0.0, Vector2.ONE)
	Art.draw(ci, art, r.size, null, f)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in e.get("marks", []):
		var at := r.position + Vector2(float(m[0]) * r.size.x, float(m[1]) * r.size.y)
		ci.draw_circle(at, 2.5, Pal.heat(a, 1.2))
		var to := Vector2(at.x, r.end.y + 10.0)
		ci.draw_line(at, to, Pal.heat(0.6 * a, 1.0), 1.0, true)


# a structure, a line or a system drawn as its own small sign
static func _glyph(ci: CanvasItem, g: String, r: Rect2, a: float) -> void:
	var cen := r.get_center()
	var s: float = minf(r.size.x, r.size.y)
	var col := Pal.ink(0.75 * a)
	ci.draw_rect(r, Color(0.05, 0.053, 0.06, a))
	match g:
		"bolt":
			ci.draw_circle(cen, s * 0.22, Color(0, 0, 0, 0))
			ci.draw_arc(cen, s * 0.22, 0, TAU, 7, col, 1.5, true)
			ci.draw_arc(cen, s * 0.1, 0, TAU, 16, col, 1.2, true)
		"lock":
			ci.draw_rect(Rect2(cen - Vector2(s * 0.18, s * 0.05), Vector2(s * 0.36, s * 0.28)), col, false, 1.5)
			ci.draw_arc(cen - Vector2(0, s * 0.05), s * 0.12, PI, TAU, 12, col, 1.5, true)
		"clamp":
			ci.draw_line(cen + Vector2(-s * 0.3, s * 0.2), cen + Vector2(s * 0.3, s * 0.2), col, 2.0, true)
			ci.draw_line(cen + Vector2(-s * 0.2, s * 0.2), cen + Vector2(-s * 0.1, -s * 0.15), col, 1.5, true)
			ci.draw_line(cen + Vector2(s * 0.2, s * 0.2), cen + Vector2(s * 0.1, -s * 0.15), col, 1.5, true)
		"weld":
			for i in 5:
				ci.draw_arc(cen + Vector2((i - 2) * s * 0.1, 0), s * 0.06, 0, PI, 8, col, 1.2, true)
		"cable":
			ci.draw_polyline(PackedVector2Array([cen + Vector2(-s * 0.4, s * 0.1), cen + Vector2(-s * 0.1, -s * 0.1), cen + Vector2(s * 0.2, s * 0.1), cen + Vector2(s * 0.4, -s * 0.05)]), Pal.tint(Pal.VOLT, 0.85 * a, 1.0), 2.0, true)
		"pipe":
			ci.draw_line(cen + Vector2(-s * 0.4, -s * 0.06), cen + Vector2(s * 0.4, -s * 0.06), Pal.tint(Pal.FLUID, 0.85 * a, 1.0), 1.5, true)
			ci.draw_line(cen + Vector2(-s * 0.4, s * 0.06), cen + Vector2(s * 0.4, s * 0.06), Pal.tint(Pal.FLUID, 0.85 * a, 1.0), 1.5, true)
		"gas":
			for i in 3:
				ci.draw_arc(cen, s * (0.1 + i * 0.1), 0, TAU, 24, Pal.tint(Pal.AIR, (0.8 - i * 0.2) * a, 1.0), 1.2, true)
		"drop":
			ci.draw_circle(cen, s * 0.18, Pal.tint(Pal.FLUID, 0.25 * a, 1.0))
			ci.draw_arc(cen, s * 0.18, 0, TAU, 24, Pal.tint(Pal.FLUID, 0.9 * a, 1.0), 1.4, true)
			ci.draw_circle(cen + Vector2(s * 0.3, -s * 0.2), s * 0.06, Pal.tint(Pal.FLUID, 0.7 * a, 1.0))
		"bolt_volt":
			ci.draw_polyline(PackedVector2Array([cen + Vector2(s * 0.05, -s * 0.35), cen + Vector2(-s * 0.12, s * 0.02), cen + Vector2(s * 0.08, s * 0.02), cen + Vector2(-s * 0.05, s * 0.35)]), Pal.tint(Pal.VOLT, 0.9 * a, 1.0), 2.0, true)
		"heat":
			for i in 3:
				var x0 := cen.x + (i - 1) * s * 0.18
				ci.draw_polyline(PackedVector2Array([Vector2(x0, cen.y + s * 0.3), Vector2(x0 + s * 0.05, cen.y), Vector2(x0 - s * 0.05, cen.y - s * 0.15), Vector2(x0, cen.y - s * 0.3)]), Pal.heat(0.8 * a, 1.1), 1.5, true)
		"cut":
			ci.draw_line(cen + Vector2(0, -s * 0.38), cen + Vector2(0, s * 0.38), Pal.heat(0.5 * a, 1.0), 1.0, true)
			for i in 6:
				var yy := cen.y - s * 0.35 + i * s * 0.14
				ci.draw_line(Vector2(cen.x - s * 0.06, yy), Vector2(cen.x + s * 0.06, yy), Pal.heat(0.8 * a, 1.0), 1.2, true)
		"hull":
			# a plate: its outline, the rivet rows along both edges
			var pr := Rect2(cen - Vector2(s * 0.4, s * 0.12), Vector2(s * 0.8, s * 0.24))
			ci.draw_rect(pr, col, false, 1.4)
			for i in 6:
				var x := pr.position.x + pr.size.x * (i + 0.5) / 6.0
				ci.draw_circle(Vector2(x, pr.position.y + 4), 1.3, col)
				ci.draw_circle(Vector2(x, pr.end.y - 4), 1.3, col)
		"frame":
			# a truss: two chords and their diagonals
			var y0 := cen.y - s * 0.15
			var y1 := cen.y + s * 0.15
			ci.draw_line(Vector2(cen.x - s * 0.4, y0), Vector2(cen.x + s * 0.4, y0), col, 1.6, true)
			ci.draw_line(Vector2(cen.x - s * 0.4, y1), Vector2(cen.x + s * 0.4, y1), col, 1.6, true)
			for i in 4:
				var x0 := cen.x - s * 0.4 + i * s * 0.2
				ci.draw_line(Vector2(x0, y1), Vector2(x0 + s * 0.2, y0), col, 1.1, true)
		"film":
			for i in 3:
				var yy := cen.y - s * 0.2 + i * s * 0.2
				ci.draw_polyline(PackedVector2Array([Vector2(cen.x - s * 0.4, yy), Vector2(cen.x - s * 0.1, yy - s * 0.05), Vector2(cen.x + s * 0.2, yy + s * 0.04), Vector2(cen.x + s * 0.4, yy)]), Pal.ink((0.6 - i * 0.12) * a), 1.0, true)
		"door":
			ci.draw_rect(Rect2(cen - Vector2(s * 0.18, s * 0.32), Vector2(s * 0.36, s * 0.64)), col, false, 1.5)
			ci.draw_line(cen + Vector2(s * 0.1, -s * 0.04), cen + Vector2(s * 0.1, s * 0.06), col, 2.0, true)
			ci.draw_line(cen + Vector2(0, -s * 0.42), cen + Vector2(0, -s * 0.36), Pal.heat(0.8 * a, 1.0), 2.0, true)
		"valve":
			# the bow-tie of a valve on its line, the handwheel above
			ci.draw_line(cen + Vector2(-s * 0.42, 0), cen + Vector2(-s * 0.16, 0), col, 1.4, true)
			ci.draw_line(cen + Vector2(s * 0.16, 0), cen + Vector2(s * 0.42, 0), col, 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.16, -s * 0.1), cen, cen + Vector2(-s * 0.16, s * 0.1)]), col)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(s * 0.16, -s * 0.1), cen, cen + Vector2(s * 0.16, s * 0.1)]), col)
			ci.draw_line(cen, cen + Vector2(0, -s * 0.22), col, 1.2, true)
			ci.draw_arc(cen + Vector2(0, -s * 0.26), s * 0.08, 0, TAU, 16, col, 1.2, true)
		"switch":
			ci.draw_rect(Rect2(cen - Vector2(s * 0.14, s * 0.22), Vector2(s * 0.28, s * 0.44)), col, false, 1.4)
			ci.draw_line(cen, cen + Vector2(s * 0.08, -s * 0.18), Pal.heat(0.85 * a, 1.0), 2.4, true)
			ci.draw_circle(cen, 2.0, col)
		"probe":
			ci.draw_arc(cen + Vector2(0, s * 0.08), s * 0.26, PI * 1.15, TAU - PI * 0.15, 24, col, 1.4, true)
			ci.draw_line(cen + Vector2(0, s * 0.08), cen + Vector2(s * 0.14, -s * 0.12), Pal.heat(0.85 * a, 1.0), 1.6, true)
			ci.draw_circle(cen + Vector2(0, s * 0.08), 2.0, col)
		"socket":
			ci.draw_arc(cen, s * 0.22, 0, TAU, 28, col, 1.4, true)
			ci.draw_line(cen + Vector2(-s * 0.07, -s * 0.06), cen + Vector2(-s * 0.07, s * 0.06), col, 2.0, true)
			ci.draw_line(cen + Vector2(s * 0.07, -s * 0.06), cen + Vector2(s * 0.07, s * 0.06), col, 2.0, true)
		"ice":
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.3, s * 0.2), cen + Vector2(-s * 0.2, -s * 0.25), cen + Vector2(s * 0.15, -s * 0.3), cen + Vector2(s * 0.35, s * 0.05), cen + Vector2(s * 0.1, s * 0.3)]), Pal.tint(Pal.AIR, 0.18 * a, 1.0))
			ci.draw_polyline(PackedVector2Array([cen + Vector2(-s * 0.3, s * 0.2), cen + Vector2(-s * 0.2, -s * 0.25), cen + Vector2(s * 0.15, -s * 0.3), cen + Vector2(s * 0.35, s * 0.05), cen + Vector2(s * 0.1, s * 0.3), cen + Vector2(-s * 0.3, s * 0.2)]), Pal.tint(Pal.AIR, 0.85 * a, 1.0), 1.3, true)
			ci.draw_line(cen + Vector2(-s * 0.05, -s * 0.2), cen + Vector2(s * 0.05, s * 0.15), Pal.ink(0.6 * a), 1.0, true)
		"clock":
			ci.draw_arc(cen, s * 0.28, 0, TAU, 32, col, 1.4, true)
			ci.draw_line(cen, cen + Vector2(0, -s * 0.2), col, 1.6, true)
			ci.draw_line(cen, cen + Vector2(s * 0.14, s * 0.04), col, 1.6, true)
		"free":
			# a piece drifting, its motion lines
			ci.draw_rect(Rect2(cen - Vector2(s * 0.08, s * 0.12), Vector2(s * 0.3, s * 0.22)), col, false, 1.4)
			for i in 3:
				var yy := cen.y - s * 0.07 + i * s * 0.07
				ci.draw_line(Vector2(cen.x - s * 0.4, yy), Vector2(cen.x - s * 0.15, yy), Pal.ink((0.6 - i * 0.15) * a), 1.0, true)
		"furnace":
			ci.draw_rect(Rect2(cen - Vector2(s * 0.22, s * 0.18), Vector2(s * 0.44, s * 0.36)), col, false, 1.4)
			ci.draw_rect(Rect2(cen + Vector2(-s * 0.14, s * 0.02), Vector2(s * 0.28, s * 0.1)), Pal.heat(0.8 * a, 1.3))
			ci.draw_line(cen + Vector2(-s * 0.3, -s * 0.3), cen + Vector2(s * 0.3, -s * 0.3), col, 1.0, true)
		"mouth":
			ci.draw_polyline(PackedVector2Array([cen + Vector2(-s * 0.36, -s * 0.2), cen + Vector2(-s * 0.16, s * 0.18), cen + Vector2(s * 0.16, s * 0.18), cen + Vector2(s * 0.36, -s * 0.2)]), col, 1.6, true)
			ci.draw_line(cen + Vector2(0, -s * 0.34), cen + Vector2(0, -s * 0.02), Pal.tint(Pal.FLUID, 0.85 * a, 1.0), 1.6, true)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.06, -s * 0.08), cen + Vector2(s * 0.06, -s * 0.08), cen + Vector2(0, 0)]), Pal.tint(Pal.FLUID, 0.85 * a, 1.0))
		"field":
			for i in 3:
				ci.draw_arc(cen + Vector2(s * 0.4, 0), s * (0.2 + i * 0.12), PI * 0.7, PI * 1.3, 14, Pal.tint(Pal.AIR, (0.8 - i * 0.2) * a, 1.0), 1.2, true)
			ci.draw_line(cen + Vector2(-s * 0.35, 0), cen + Vector2(s * 0.05, 0), col, 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.4, 0), cen + Vector2(-s * 0.3, -s * 0.06), cen + Vector2(-s * 0.3, s * 0.06)]), col)
		"plan":
			ci.draw_rect(Rect2(cen - Vector2(s * 0.34, s * 0.22), Vector2(s * 0.68, s * 0.44)), Pal.tint(Pal.AIR, 0.7 * a, 1.0), false, 1.2)
			ci.draw_line(cen + Vector2(-s * 0.2, -s * 0.22), cen + Vector2(-s * 0.2, s * 0.22), Pal.tint(Pal.AIR, 0.4 * a, 1.0), 1.0, true)
			ci.draw_line(cen + Vector2(-s * 0.34, 0), cen + Vector2(s * 0.34, 0), Pal.tint(Pal.AIR, 0.4 * a, 1.0), 1.0, true)
			ci.draw_line(cen + Vector2(s * 0.08, -s * 0.22), cen + Vector2(s * 0.08, s * 0.22), Pal.tint(Pal.AIR, 0.4 * a, 1.0), 1.0, true)
		_:
			ci.draw_rect(r.grow(-s * 0.25), col, false, 1.2)
	ci.draw_rect(r, Pal.ink(0.3 * a), false, 1.0)
