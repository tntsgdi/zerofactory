class_name CodexPage
extends Control
# The book (scripts/codex.gd): everything met so far, by kind — structures,
# devices, ship mechanisms, berth systems — each with its progress (devices
# 23/160). Unmet entries are grey silhouettes. The chosen entry: its drawing,
# the three sentences of its card and the working behind them, with numbers.
# "This ship" narrows the list to what the ship in hand carries.
# Opened with I on site (play paused), from the pause menu, the terminal, or
# straight onto a ship's entries from its contract card.
# Keys: ← → kind, ↑ ↓ entry, Tab this ship / everything, Esc or I close.

const LIST_X := 60.0
const LIST_W := 470.0
const ROW_H := 30.0
const DET_X := 590.0

var font: Font
var font_b: Font
var font_l: Font
var cat := 0
var sel := 0
var scroll := 0.0
var ship := ""                # the ship in hand ("" none)
var only_ship := false
var on_close: Callable
var t := 0.0
var hover_row := -1
var hover_tab := -1
var hover_filter := false
var hover_close := false
var det_scroll := 0.0


static func open(host: Node, focus: String = "", ship_id: String = "", closed: Callable = Callable(), ship_only: bool = false) -> CodexPage:
	var layer := CanvasLayer.new()
	layer.layer = 66
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)
	var pg := CodexPage.new()
	pg.ship = ship_id
	pg.on_close = closed
	pg.only_ship = ship_only and ship_id != ""
	layer.add_child(pg)
	pg.focus(focus)
	return pg


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	font_l = Fonts.get_font("Light")
	position = Vector2.ZERO
	size = get_viewport_rect().size


func focus(id: String) -> void:
	if id == "" or not CodexData.E.has(id):
		return
	cat = Codex.CATS.find(CodexData.E[id].cat)
	var l := rows()
	sel = maxi(0, l.find(id))
	if sel < 0 or l.find(id) < 0:
		only_ship = false
		l = rows()
		sel = maxi(0, l.find(id))
	_keep_in_view()


# the entries listed now: met ones first in the book's order, unmet after
func rows() -> Array:
	var all: Array = Codex.ids(Codex.CATS[cat])
	if only_ship and ship != "":
		var mine := _ship_set()
		all = all.filter(func(id): return mine.has(id))
	var met: Array = all.filter(func(id): return Codex.seen(id))
	var unmet: Array = all.filter(func(id): return not Codex.seen(id))
	return met + unmet


# what the ship in hand carries: its mechanisms, its machines, its structures
var _mine := {}
func _ship_set() -> Dictionary:
	if not _mine.is_empty() or ship == "":
		return _mine
	for id in Codex.ship_entries(ship):
		_mine[id] = true
	var d := Ship.load_data(ship)
	for pd in d.get("pieces", []):
		var nk: String = pd.get("name_key", "")
		var art: String = Art.SH.BY_NAME.get(nk, Art.EQ.BY_NAME.get(nk, pd.get("art", "")))
		var id := Codex.device_entry(art)
		if id != "":
			_mine[id] = true
	for id in CodexData.E:
		var e: Dictionary = CodexData.E[id]
		if e.cat in ["struct", "sys"] and e.get("always", false):
			_mine[id] = true
	return _mine


func chosen() -> String:
	var l := rows()
	return l[sel] if sel >= 0 and sel < l.size() else ""


func close() -> void:
	var id := chosen()
	if id != "" and Codex.seen(id):
		Codex.read(id)
	if on_close.is_valid():
		on_close.call()
	get_parent().queue_free()


func _process(dt: float) -> void:
	t += dt
	if size != get_viewport_rect().size:
		position = Vector2.ZERO
		size = get_viewport_rect().size
	var m := get_local_mouse_position()
	hover_row = -1
	var l := rows()
	for i in l.size():
		if _row_rect(i).has_point(m) and _list_rect().has_point(m):
			hover_row = i
	hover_tab = -1
	for i in Codex.CATS.size():
		if _tab_rect(i).has_point(m):
			hover_tab = i
	hover_filter = ship != "" and _filter_rect().has_point(m)
	hover_close = _close_rect().has_point(m)
	queue_redraw()


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var handled := true
	if ev is InputEventKey and ev.pressed:
		match ev.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_LEFT, KEY_A:
				_set_cat(cat - 1)
			KEY_RIGHT, KEY_D:
				_set_cat(cat + 1)
			KEY_UP, KEY_W:
				_pick(sel - 1)
			KEY_DOWN, KEY_S:
				_pick(sel + 1)
			KEY_PAGEUP:
				_pick(sel - 10)
			KEY_PAGEDOWN:
				_pick(sel + 10)
			KEY_TAB:
				if ship != "":
					only_ship = not only_ship
					sel = 0
					scroll = 0.0
			_:
				if Keys.pressed(ev, "codex"):
					close()
	elif ev is InputEventMouseButton and ev.pressed:
		var m := get_local_mouse_position()
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				if hover_close:
					close()
				elif hover_tab >= 0:
					_set_cat(hover_tab)
				elif hover_filter:
					only_ship = not only_ship
					sel = 0
					scroll = 0.0
				elif hover_row >= 0:
					_pick(hover_row)
			MOUSE_BUTTON_WHEEL_UP:
				if _list_rect().has_point(m):
					scroll = maxf(0.0, scroll - ROW_H * 3.0)
				else:
					det_scroll = maxf(0.0, det_scroll - 40.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if _list_rect().has_point(m):
					scroll = minf(_max_scroll(), scroll + ROW_H * 3.0)
				else:
					det_scroll += 40.0
			MOUSE_BUTTON_RIGHT:
				close()
	elif ev is InputEventMouseMotion:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _set_cat(i: int) -> void:
	cat = posmod(i, Codex.CATS.size())
	sel = 0
	scroll = 0.0
	det_scroll = 0.0


func _pick(i: int) -> void:
	var id := chosen()
	if id != "" and Codex.seen(id):
		Codex.read(id)
	var n := rows().size()
	if n == 0:
		return
	sel = clampi(i, 0, n - 1)
	det_scroll = 0.0
	_keep_in_view()


func _keep_in_view() -> void:
	var lr := _list_rect()
	var y := sel * ROW_H
	if y < scroll:
		scroll = y
	elif y + ROW_H > scroll + lr.size.y:
		scroll = y + ROW_H - lr.size.y
	scroll = clampf(scroll, 0.0, _max_scroll())


func _max_scroll() -> float:
	return maxf(0.0, rows().size() * ROW_H - _list_rect().size.y)


# ---------------------------------------------------------------- layout

func _list_rect() -> Rect2:
	return Rect2(LIST_X, 190.0, LIST_W, size.y - 190.0 - 70.0)


func _row_rect(i: int) -> Rect2:
	var lr := _list_rect()
	return Rect2(lr.position.x, lr.position.y + i * ROW_H - scroll, lr.size.x, ROW_H - 2.0)


func _tab_rect(i: int) -> Rect2:
	return Rect2(LIST_X + i * 236.0, 112.0, 226.0, 46.0)


func _filter_rect() -> Rect2:
	return Rect2(size.x - 400.0, 112.0, 330.0, 46.0)


func _close_rect() -> Rect2:
	return Rect2(size.x - 70.0, 36.0, 34.0, 34.0)


# ---------------------------------------------------------------- draw

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.021, 0.025, 1.0))
	UI.text(self, font_l, Txt.t("cxu_book"), Vector2(LIST_X, 78), 34, Pal.ink(0.95))
	UI.text(self, font, Txt.t("cxu_book_sub"), Vector2(LIST_X + 4, 100), 13, Pal.ink(0.45))
	# close
	var cr := _close_rect()
	var ca := 0.9 if hover_close else 0.45
	draw_line(cr.position + Vector2(9, 9), cr.end - Vector2(9, 9), Pal.ink(ca), 2.0, true)
	draw_line(Vector2(cr.end.x - 9, cr.position.y + 9), Vector2(cr.position.x + 9, cr.end.y - 9), Pal.ink(ca), 2.0, true)
	# kinds, each with its progress
	for i in Codex.CATS.size():
		var r := _tab_rect(i)
		var on := i == cat
		var n := Codex.count(Codex.CATS[i])
		draw_rect(r, Color(0.07, 0.074, 0.084, 1.0) if on else (Color(0.05, 0.053, 0.06, 1.0) if hover_tab == i else Color(0, 0, 0, 0)))
		draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Pal.heat(1.0, 1.1) if on else Pal.ink(0.12))
		UI.text(self, font_b, Txt.t("cxu_cat_" + Codex.CATS[i]), r.position + Vector2(14, 30), 18, Pal.ink(0.95 if on else 0.6))
		UI.text(self, font, "%d / %d" % [n.x, n.y], Vector2(r.end.x - 12, r.position.y + 30), 14, Pal.ink(0.75 if on else 0.4), 1)
	# this ship / everything
	if ship != "":
		var fr := _filter_rect()
		draw_rect(fr, Color(0.07, 0.074, 0.084, 1.0) if only_ship or hover_filter else Color(0, 0, 0, 0))
		draw_rect(fr, Pal.ink(0.25), false, 1.0)
		var box := Rect2(fr.position + Vector2(14, 15), Vector2(16, 16))
		draw_rect(box, Pal.ink(0.7), false, 1.5)
		if only_ship:
			draw_rect(box.grow(-4), Pal.heat(1.0, 1.1))
		UI.text(self, font, Txt.t("cxu_ship_only") % _ship_name(), fr.position + Vector2(42, 29), 15, Pal.ink(0.85))
	_list()
	_detail()
	UI.text(self, font, Txt.t("cxu_keys") % Keys.label("codex"), Vector2(LIST_X, s.y - 30), 13, Pal.ink(0.4))


func _ship_name() -> String:
	var d := Ship.load_data(ship)
	var tt = d.get("title", null)
	if tt is Array and tt.size() == 2:
		return str(tt[0] if Txt.zh else tt[1]).split(" · ")[0]
	return Codex.code(ship)


func _list() -> void:
	var lr := _list_rect()
	var l := rows()
	draw_rect(lr, Color(0.03, 0.032, 0.037, 1.0))
	if l.is_empty():
		UI.text(self, font, Txt.t("cxu_empty"), lr.position + Vector2(16, 30), 15, Pal.ink(0.4))
		return
	for i in l.size():
		var r := _row_rect(i)
		if r.end.y < lr.position.y or r.position.y > lr.end.y:
			continue
		var id: String = l[i]
		var met := Codex.seen(id)
		var on := i == sel
		if on:
			draw_rect(r, Color(0.09, 0.094, 0.105, 1.0))
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.heat(1.0, 1.1))
		elif i == hover_row:
			draw_rect(r, Color(0.06, 0.063, 0.07, 1.0))
		if met:
			UI.text(self, font, Codex.title(id), r.position + Vector2(16, 20), 15, Pal.ink(0.95 if on else 0.75))
			if Codex.is_new(id):
				draw_circle(Vector2(r.end.x - 18, r.position.y + 14), 4.0, Pal.heat(1.0, 1.2))
		else:
			UI.text(self, font, Txt.t("cxu_unmet"), r.position + Vector2(16, 20), 15, Pal.ink(0.25))
	# the scroll bar
	var total := l.size() * ROW_H
	if total > lr.size.y:
		var hh := lr.size.y * lr.size.y / total
		var yy := lr.position.y + (lr.size.y - hh) * (scroll / maxf(1.0, total - lr.size.y))
		draw_rect(Rect2(lr.end.x - 3, yy, 3, hh), Pal.ink(0.3))


func _detail() -> void:
	var id := chosen()
	var x := DET_X
	var w := size.x - DET_X - 70.0
	var top := 190.0
	draw_rect(Rect2(x - 20, top, w + 40, size.y - top - 70.0), Color(0.03, 0.032, 0.037, 1.0))
	if id == "":
		return
	var e: Dictionary = CodexData.E[id]
	var art_box := Rect2(x, top + 24, 420, 300)
	if not Codex.seen(id):
		draw_rect(art_box, Color(0.045, 0.047, 0.053, 1.0))
		draw_rect(art_box, Pal.ink(0.12), false, 1.0)
		UI.text(self, font_l, "?", art_box.get_center() + Vector2(0, 26), 72, Pal.ink(0.15), 0)
		UI.text(self, font_b, Txt.t("cxu_unmet"), Vector2(x + 460, top + 70), 26, Pal.ink(0.4))
		UI.text(self, font, Txt.t("cxu_unmet_d"), Vector2(x + 460, top + 110), 15, Pal.ink(0.35))
		return
	CodexHud.draw_art(self, id, art_box, font, 1.0)
	var tx := x + 460.0
	var tw := w - 460.0
	UI.text(self, font, Txt.t("cxu_cat_" + str(e.cat)) + (("  ·  " + Txt.t("cxu_cls_" + str(e.cls))) if e.has("cls") else ""), Vector2(tx, top + 48), 13, Pal.ink(0.5))
	UI.text(self, font_b, Codex.title(id), Vector2(tx, top + 86), 30, Pal.ink(0.97))
	var y := top + 120.0
	for part in ["a", "b", "c"]:
		var col: Color = Pal.heat(0.95, 1.1) if part == "b" else (Pal.tint(Pal.FLUID, 0.95, 1.0) if part == "c" else Pal.ink(0.55))
		UI.text(self, font, Txt.t("cxu_" + part), Vector2(tx, y + 16), 13, col)
		y += _para(Codex.line(id, part), Vector2(tx + 60, y), tw - 60, 16, Pal.ink(0.92), 23.0) + 12.0
	# the working
	var wy := maxf(y, top + 350.0) + 14.0 - det_scroll
	draw_rect(Rect2(x, wy - 18, w, 1), Pal.ink(0.15))
	UI.text(self, font, Txt.t("cxu_x"), Vector2(x, wy + 6), 13, Pal.ink(0.5))
	_para(Codex.line(id, "x"), Vector2(x, wy + 18), w, 16, Pal.ink(0.82), 25.0)
	# which ships carry it
	var where: Array = e.get("ships", [])
	if not where.is_empty():
		var names: Array = []
		for sid in where:
			names.append(Codex.code(str(sid)))
		UI.text(self, font, Txt.t("cxu_ships") % ", ".join(names), Vector2(x, size.y - 92), 13, Pal.ink(0.45))


func _para(text: String, pos: Vector2, width: float, size_px: int, col: Color, lh: float) -> float:
	var tl := TextParagraph.new()
	tl.add_string(text, font, size_px)
	tl.width = width
	tl.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var y := pos.y
	for i in tl.get_line_count():
		tl.draw_line(get_canvas_item(), Vector2(pos.x, y), i, col)
		y += lh
	return y - pos.y
