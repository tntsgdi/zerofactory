class_name Terminal
extends Control
# The berth terminal between contracts (full screen): money, loan,
# installment and reputation always along the top; three tabs — the contract
# market (three offer cards), the equipment shop, berth management; "take the
# contract" at the bottom. Keys: 1 2 3 tabs, ← → pick, Enter take/buy, Esc title.

const TABS := ["market", "shop", "berth"]
# what can be bought: [id, kind, price, Txt name key, Txt effect key, phase it works from]
const SHOP := [
	["scan_kit", "upgrade", 24000.0, "up_scan", "up_scan_d"],
	["grapple5", "upgrade", 38000.0, "up_grapple", "up_grapple_d"],
	["pump2", "upgrade", 22000.0, "up_pump", "up_pump_d"],
	["repair", "item", 3000.0, "it_repair", "it_repair_d"],
	["ring", "item", 9000.0, "it_ring", "it_ring_d"],
	["spare", "item", 15000.0, "it_spare", "it_spare_d"],
	["intel", "item", 6000.0, "it_intel", "it_intel_d"],
]
const BERTH := [
	["arm", "facility", 65000.0, "fa_arm", "fa_arm_d", true],
	["drone2", "facility", 200000.0, "fa_drone2", "fa_drone2_d", false],
	["mast", "facility", 80000.0, "fa_mast", "fa_mast_d", false],
	["scanner", "facility", 120000.0, "fa_scan", "fa_scan_d", false],
]

var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var tab := 0
var sel := 0
var hover := -1
var hover_tab := -1
var hover_go := false
var flash := 0.0
var msg := ""
var msg_t := 9.0
var leaving := -1.0
var radio := Radio.new()
var testing := false
var settings: SettingsPanel


func _ready() -> void:
	testing = _is_test()
	if not testing:
		Txt.load_settings(false)
	Career.load_or_new()
	Career.ensure_offers(Market.make)
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.apply(get_viewport())
	settings = SettingsPanel.new()
	settings.testing = testing
	add_child(settings)
	# the first time the market opens
	if not Career.data.get("seen", {}).has("market"):
		var seen: Dictionary = Career.data.get("seen", {})
		seen["market"] = true
		Career.data.seen = seen
		Career.save()
		Copy.say(radio, "T_market_open", "term")
		for k in ["L_market_open_1", "L_market_open_2", "L_market_open_3"]:
			Copy.say(radio, k)
	# a new reputation level since the terminal last opened
	var lv := Career.level()
	var seen_lv: Dictionary = Career.data.get("seen", {})
	if seen_lv.get("level", "trainee") != lv:
		seen_lv["level"] = lv
		Career.data.seen = seen_lv
		Career.save()
		var names := [Txt.S["rep_" + lv][0], Txt.S["rep_" + lv][1]]
		Copy.say(radio, "T_rep_up", "term", names)
		Copy.say(radio, "L_rep_" + lv)


func _is_test() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.find("tests/") >= 0:
			return true
	return false


func offers() -> Array:
	return Career.data.get("offers", [])


func items() -> Array:
	return offers() if tab == 0 else (SHOP if tab == 1 else BERTH)


# ---------------------------------------------------------------- input

func _process(dt: float) -> void:
	t += dt
	msg_t += dt
	flash = maxf(0.0, flash - dt * 3.0)
	radio.step(dt, false)
	var m := get_local_mouse_position()
	hover = -1
	hover_tab = -1
	for i in items().size():
		if _item_rect(i).has_point(m):
			hover = i
	for i in 3:
		if _tab_rect(i).has_point(m):
			hover_tab = i
	hover_go = _go_rect().has_point(m)
	if leaving >= 0.0:
		leaving += dt
		if leaving > 0.5:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if settings.is_open or leaving >= 0.0:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if hover_tab >= 0:
			set_tab(hover_tab)
		elif hover >= 0:
			if sel == hover:
				act()
			sel = hover
		elif hover_go:
			act()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or leaving >= 0.0:
		return
	match ev.physical_keycode:
		KEY_1, KEY_2, KEY_3:
			set_tab(ev.physical_keycode - KEY_1)
		KEY_LEFT, KEY_A, KEY_UP, KEY_W:
			sel = maxi(0, sel - 1)
		KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
			sel = mini(items().size() - 1, sel + 1)
		KEY_ENTER, KEY_SPACE:
			act()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		KEY_O:
			settings.open()


func set_tab(i: int) -> void:
	tab = clampi(i, 0, 2)
	sel = 0


func say(text: String) -> void:
	msg = text
	msg_t = 0.0


# take the selected contract, or buy the selected thing
func act() -> void:
	if tab == 0:
		take(sel)
	else:
		buy(items()[sel] if sel < items().size() else [])


func take(i: int) -> void:
	if i < 0 or i >= offers().size():
		return
	var o: Dictionary = Career.accept(i)
	if o.is_empty():
		return
	Game.start_ship = o.ship
	Game.contract = o
	SaveGame.load_requested = false
	leaving = 0.0


func buy(it: Array) -> void:
	if it.is_empty():
		return
	var id: String = it[0]
	var price: float = it[2]
	var d := Career.data
	if it[1] == "facility" and not it[5]:
		say(Txt.t("tm_later"))
		return
	if it[1] != "item" and d.upgrades.has(id):
		say(Txt.t("tm_owned"))
		return
	if float(d.money) < price:
		say(Txt.t("tm_short") % Pal.money(price - float(d.money)))
		return
	d.money = float(d.money) - price
	if it[1] == "item":
		d.items[id] = int(d.items.get(id, 0)) + 1
	else:
		d.upgrades[id] = 1
	if not d.get("seen", {}).has("bought"):
		d.seen["bought"] = true
		Copy.say(radio, "L_first_upgrade")
	Career.save()
	flash = 1.0
	say(Txt.t("tm_bought") % Txt.t(it[3]))


# ---------------------------------------------------------------- layout

func _tab_rect(i: int) -> Rect2:
	return Rect2(60 + i * 230, 132, 216, 44)


func _item_rect(i: int) -> Rect2:
	var s := size
	if tab == 0:
		var w := (s.x - 120 - 2 * 30) / 3.0
		return Rect2(60 + i * (w + 30), 200, w, s.y - 360)
	return Rect2(60, 200 + i * 78, s.x - 120, 66)


func _go_rect() -> Rect2:
	return Rect2(size.x - 60 - 360, size.y - 130, 360, 64)


func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _wrap(s: String, pos: Vector2, w: float, size_px: int, col: Color, lines: int = 2) -> void:
	draw_multiline_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, w, size_px, lines, col)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var s := size
	var a := clampf(t / 0.35, 0.0, 1.0) * (1.0 - clampf(leaving / 0.4, 0.0, 1.0) if leaving >= 0.0 else 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Pal.BG)
	_top(s, a)
	for i in 3:
		var r := _tab_rect(i)
		var on := tab == i
		if on or hover_tab == i:
			Pal.band(self, r, (0.14 if on else 0.07) * a)
		if on:
			draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), Pal.heat(a, 1.0))
		_text("%d  %s" % [i + 1, Txt.t("tm_tab_" + TABS[i])], r.position + Vector2(16, 29), 17, Pal.ink((0.95 if on else 0.5) * a), font_b if on else font)
	match tab:
		0:
			_market(s, a)
		1:
			_list(SHOP, a)
		2:
			_list(BERTH, a)
	_bottom(s, a)
	_radio(s, a)


func _top(s: Vector2, a: float) -> void:
	var d := Career.data
	_text("BERTH 07  ·  CHARON-DISPATCH", Vector2(60, 56), 13, Pal.ink(0.4 * a), font)
	_text(Txt.t("tm_title"), Vector2(60, 94), 30, Pal.ink(0.92 * a), font_l)
	var cols := [
		[Txt.t("tm_money"), Pal.money(float(d.money)), Pal.ink(0.95 * a)],
		[Txt.t("tm_loan"), Pal.money(float(d.loan)), Pal.heat(0.9 * a, 1.0) if float(d.loan) > 0.0 else Pal.ink(0.95 * a)],
		[Txt.t("tm_due"), Pal.money(minf(Career.INSTALLMENT, float(d.loan)) + snappedf(float(d.loan) * Career.INTEREST, 1.0)), Pal.ink(0.8 * a)],
		[Txt.t("tm_rep"), Txt.t("rep_" + Career.level()), Pal.ink(0.95 * a)],
	]
	for i in cols.size():
		var x := s.x - 60 - (cols.size() - 1 - i) * 250
		_text(cols[i][0], Vector2(x, 56), 13, Pal.ink(0.4 * a), font, 1)
		_text(cols[i][1], Vector2(x, 92), 26, cols[i][2], font_l, 1)
	var nx := Career.to_next()
	if nx > 0:
		_text(Txt.t("tm_rep_next") % nx, Vector2(s.x - 60, 114), 11, Pal.ink(0.35 * a), font, 1)
	draw_line(Vector2(60, 186), Vector2(s.x - 60, 186), Pal.ink(0.12 * a), 1.0)


func _stars(n: int, p: Vector2, a: float) -> void:
	for i in 3:
		var c := p + Vector2(i * 18, 0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := 7.0 if k % 2 == 0 else 3.0
			pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * r)
		if i < n:
			draw_colored_polygon(pts, Pal.heat(0.9 * a, 1.0))
		else:
			pts.append(pts[0])
			draw_polyline(pts, Pal.ink(0.25 * a), 1.0, true)


func _market(s: Vector2, a: float) -> void:
	var os := offers()
	if os.is_empty():
		_text(Txt.t("tm_none"), Vector2(s.x * 0.5, s.y * 0.45), 18, Pal.ink(0.5 * a), font, 0)
		return
	for i in os.size():
		var o: Dictionary = os[i]
		var r := _item_rect(i)
		var on := i == sel
		var k := Pal.ease_out(clampf((t - 0.1 - i * 0.06) / 0.3, 0.0, 1.0)) * a
		r.position.y += (1.0 - k) * 20.0
		draw_rect(r, Color(0.03, 0.032, 0.037, 0.95 * k))
		draw_rect(r, Pal.ink((0.6 if on else (0.3 if hover == i else 0.14)) * k), false, 1.2)
		if on:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.heat(k, 1.0))
		var x := r.position.x + 28
		var y := r.position.y + 44
		var ty: Dictionary = Market.TYPES.get(o.ship, {})
		_text("CONTRACT %s" % o.id, Vector2(x, y), 12, Pal.ink(0.4 * k), font)
		_text(o.reg + "  ·  " + (ty.name[0] if Txt.zh else ty.name[1]), Vector2(x, y + 34), 22, Pal.ink(0.95 * k), font_b)
		_text("%d m" % int(ty.get("length", 0)), Vector2(r.end.x - 28, y + 34), 14, Pal.ink(0.45 * k), font, 1)
		_stars(int(o.stars), Vector2(x + 7, y + 64), k)
		_text(Txt.t("tm_risk"), Vector2(x + 70, y + 69), 12, Pal.ink(0.4 * k), font)
		_text(Txt.t("tm_reason"), Vector2(x, y + 108), 12, Pal.ink(0.4 * k), font)
		_wrap(Copy.slot(o.reason), Vector2(x, y + 132), r.size.x - 56, 15, Pal.ink(0.85 * k))
		var rows := [
			[Txt.t("tm_value"), Pal.money(float(o.value))],
			[Txt.t("tm_fee"), Pal.money(float(o.fee))],
			[Txt.t("tm_time"), "%d min" % int(float(o.time) / 60.0)],
		]
		for j in rows.size():
			var yy := y + 196 + j * 30
			_text(rows[j][0], Vector2(x, yy), 14, Pal.ink(0.5 * k), font)
			_text(rows[j][1], Vector2(r.end.x - 28, yy), 16, Pal.ink(0.92 * k), font_b, 1)
		_text(Txt.t("tm_logs"), Vector2(x, y + 310), 12, Pal.ink(0.4 * k), font)
		var ly := y + 336.0
		for lid in o.logs:
			_text("›", Vector2(x, ly), 14, Pal.tint(Pal.AIR, 0.6 * k, 1.0), font)
			_wrap(Copy.slot(lid), Vector2(x + 16, ly), r.size.x - 72, 14, Pal.tint(Pal.AIR, 0.8 * k, 1.0))
			ly += 46.0
		# the manifest: what the paperwork says is in the hold
		var cy := r.end.y - 96.0
		_text(Txt.t("tm_cargo"), Vector2(x, cy), 12, Pal.ink(0.4 * k), font)
		var parts: Array = []
		for cg in o.get("cargo", []):
			parts.append("%s %s" % [cg[0], cg[1]])
		_wrap("  ·  ".join(parts) if not parts.is_empty() else Txt.t("tm_no_cargo"), Vector2(x, cy + 24), r.size.x - 56, 14, Pal.ink(0.75 * k))
		_text(Txt.t("tm_logs_note"), Vector2(x, r.end.y - 24), 11, Pal.ink(0.3 * k), font)


func _list(list: Array, a: float) -> void:
	var d := Career.data
	for i in list.size():
		var it: Array = list[i]
		var r := _item_rect(i)
		var on := i == sel
		var k := Pal.ease_out(clampf((t - 0.05 - i * 0.04) / 0.25, 0.0, 1.0)) * a
		draw_rect(r, Color(0.03, 0.032, 0.037, 0.92 * k))
		draw_rect(r, Pal.ink((0.55 if on else (0.28 if hover == i else 0.12)) * k), false, 1.0)
		if on:
			draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.heat(k, 1.0))
		var open: bool = it[1] != "facility" or it[5]
		var owned: bool = it[1] != "item" and d.upgrades.has(it[0])
		_text(Txt.t(it[3]), r.position + Vector2(24, 28), 17, Pal.ink((0.95 if open else 0.45) * k), font_b)
		_text(Txt.t(it[4]), r.position + Vector2(24, 52), 13, Pal.ink((0.55 if open else 0.3) * k), font)
		var right: String
		if not open:
			right = Txt.t("tm_later")
		elif owned:
			right = Txt.t("tm_owned")
		elif it[1] == "item":
			right = "%s   ·   %s %d" % [Pal.money(it[2]), Txt.t("tm_stock"), int(d.items.get(it[0], 0))]
		else:
			right = Pal.money(it[2])
		_text(right, Vector2(r.end.x - 24, r.position.y + 40), 18, Pal.ink((0.9 if open and not owned else 0.4) * k), font_b, 1)


func _bottom(s: Vector2, a: float) -> void:
	var r := _go_rect()
	var label: String
	if tab == 0:
		label = Txt.t("tm_take")
		var o: Dictionary = offers()[sel] if sel < offers().size() else {}
		if not o.is_empty() and float(Career.data.money) < float(o.fee):
			_text(Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(Career.data.money)), Vector2(r.position.x - 24, r.position.y + 38), 13, Pal.heat(0.85 * a, 1.0), font, 1)
	else:
		label = Txt.t("tm_buy")
	draw_rect(r, Color(0.05, 0.05, 0.055, 0.95 * a))
	draw_rect(r, Pal.ink((0.8 if hover_go else 0.4) * a), false, 1.4)
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Pal.heat(a * (0.7 + 0.3 * sin(t * 3.0)), 1.1))
	_text(label + "   Enter", r.get_center() + Vector2(0, 8), 20, Pal.ink(0.95 * a), font_b, 0)
	_text(Txt.t("tm_keys"), Vector2(60, s.y - 60), 12, Pal.ink(0.3 * a), font)
	if msg != "" and msg_t < 3.0:
		_text(msg, Vector2(60, s.y - 92), 16, Pal.ink(0.9 * a * clampf((3.0 - msg_t) / 0.4, 0.0, 1.0)), font_b)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.08 * flash))


func _radio(s: Vector2, a: float) -> void:
	var ln: Dictionary = radio.now
	if ln.is_empty():
		return
	var line: Dictionary = ln.line
	var full: String = radio.text(line)
	var shown := full.substr(0, int(ln.t * 30.0))
	var k := clampf(ln.t / 0.2, 0.0, 1.0) * clampf((ln.dur - ln.t) / 0.3, 0.0, 1.0) * a
	var r := Rect2(s.x * 0.5 - 410, s.y - 230, 820, 64)
	draw_rect(r, Color(0.02, 0.022, 0.026, 0.9 * k))
	var term: bool = line.get("who", "liang") == "term"
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.tint(Pal.AIR, k, 1.0) if term else Pal.heat(k, 1.0))
	_text(Txt.t("tut_term") if term else Txt.t("tut_liang"), r.position + Vector2(18, 22), 12, Pal.ink(0.5 * k), font)
	draw_multiline_string(font, r.position + Vector2(90, 30), shown, HORIZONTAL_ALIGNMENT_LEFT, 700, 18, 2, Pal.ink(0.95 * k))
