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
	["repay", "loan", 20000.0, "tm_repay", "tm_repay_d", true],
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
var milestone := -1.0      # the loan-paid-off moment on screen (seconds), -1 when not
# motion: everything on springs and rollers, stepped once a frame
var tab_x := Motion.Spring.new(0.0, 320.0, 0.82)    # the tab underline slides
var tab_w := Motion.Spring.new(216.0, 320.0, 0.82)
var hover_k: Array = []    # per card / row: 0..1 lift
var sel_k: Array = []      # per card / row: 0..1 chosen
var deal_t := 0.0          # since the cards were dealt (re-dealt on every tab)
var money_roll := Motion.Roller.new(0.0, 9.0)
var loan_roll := Motion.Roller.new(0.0, 9.0)
var money_flash := 0.0     # >0 up (ink), <0 down (heat)
var loan_flash := 0.0
var sparks: Array = []     # [from, to, t, delay] little lights flying to the funds
var sweep := {}            # row index -> t: a bright pass across a row that was bought
var leave_from := Rect2()  # the card that grows into the screen when a contract is taken
var dust: Array = []
var intel_t := {}          # offer id -> seconds since its survey report came in


func _ready() -> void:
	testing = _is_test()
	if not testing:
		Txt.load_settings(false)
	Career.load_or_new()
	Career.ensure_offers(Market.make)
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	money_roll.shown = float(Career.data.money)
	money_roll.set_to(float(Career.data.money))
	loan_roll.shown = float(Career.data.loan)
	loan_roll.set_to(float(Career.data.loan))
	for i in 90:
		dust.append([Vector2(randf(), randf()), randf_range(0.002, 0.012), randf() * TAU, randf_range(0.6, 1.6)])
	for i in 8:
		hover_k.append(Motion.Spring.new(0.0, 380.0, 0.7))
		sel_k.append(Motion.Spring.new(0.0, 300.0, 0.8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.apply(get_viewport())
	settings = SettingsPanel.new()
	settings.testing = testing
	add_child(settings)
	var dev := DevPanel.new()
	dev.terminal = self
	dev.where = "terminal"
	add_child(dev)
	# the first time the market opens
	if not Career.data.get("seen", {}).has("market"):
		var seen: Dictionary = Career.data.get("seen", {})
		seen["market"] = true
		Career.data.seen = seen
		Career.save()
		Copy.say(radio, "T_market_open", "term")
		for k in ["L_market_open_1", "L_market_open_2", "L_market_open_3"]:
			Copy.say(radio, k)
	_check_milestone()
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


# the loan is gone (at a settlement, or paid off here): BERTH 07 is yours, once
func _check_milestone() -> void:
	var seen: Dictionary = Career.data.get("seen", {})
	if not Career.data.get("paid_off", false) or seen.has("paid_off"):
		return
	seen["paid_off"] = true
	Career.data.seen = seen
	Career.save()
	milestone = 0.0
	Copy.say(radio, "T_loan_paid", "term")
	for k in ["L_loan_paid_1", "L_loan_paid_2", "L_loan_paid_3"]:
		Copy.say(radio, k)


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
	deal_t += dt
	if milestone >= 0.0:
		milestone += dt
	_step_motion(dt)
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
		if leaving > 0.55:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if settings.is_open or leaving >= 0.0:
		return
	if ev is InputEventMouseButton and ev.pressed and milestone >= 0.0:
		if milestone > 1.5:
			milestone = -1.0
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
	if milestone >= 0.0:
		if milestone > 1.5:
			milestone = -1.0
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
		KEY_I:
			if tab == 0:
				use_intel(sel)
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		KEY_O:
			settings.open()


func set_tab(i: int) -> void:
	if clampi(i, 0, 2) != tab:
		deal_t = 0.0
	tab = clampi(i, 0, 2)
	sel = 0


# new cards on the table: they come in again
func dealt() -> void:
	deal_t = 0.0
	sel = 0


func _step_motion(dt: float) -> void:
	var tr := _tab_rect(tab)
	tab_x.target = tr.position.x
	tab_w.target = tr.size.x
	tab_x.step(dt)
	tab_w.step(dt)
	var n := items().size()
	for i in hover_k.size():
		hover_k[i].target = 1.0 if i == hover and i < n and leaving < 0.0 else 0.0
		sel_k[i].target = 1.0 if i == sel and i < n else 0.0
		hover_k[i].step(dt)
		sel_k[i].step(dt)
	var m := float(Career.data.money)
	var l := float(Career.data.loan)
	if absf(m - money_roll.target) > 0.5:
		money_flash = 1.0 if m > money_roll.target else -1.0
	if absf(l - loan_roll.target) > 0.5:
		loan_flash = -1.0 if l < loan_roll.target else 1.0
	money_roll.set_to(m)
	loan_roll.set_to(l)
	money_roll.step(dt)
	loan_roll.step(dt)
	money_flash = move_toward(money_flash, 0.0, dt * 1.6)
	loan_flash = move_toward(loan_flash, 0.0, dt * 1.6)
	for sp in sparks:
		sp[2] += dt
	sparks = sparks.filter(func(sp): return sp[2] < sp[3] + 0.7)
	for k in intel_t.keys():
		intel_t[k] += dt
	for k in sweep.keys():
		sweep[k] += dt
		if sweep[k] > 0.8:
			sweep.erase(k)


# where the funds figure sits (the sparks fly there)
func _money_at() -> Vector2:
	return Vector2(size.x - 60 - 3 * 250 - 60, 84)


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
	leave_from = _item_rect(i)
	var o: Dictionary = Career.accept(i)
	if o.is_empty():
		return
	Game.start_ship = o.ship
	Game.contract = o
	Copy.say(radio, "T_contract_signed", "term")
	SaveGame.load_requested = false
	leaving = 0.0


# a survey report on an offer: one hidden condition, read out before signing
func use_intel(i: int) -> void:
	if i < 0 or i >= offers().size():
		return
	var o: Dictionary = offers()[i]
	var d := Career.data
	if o.has("intel"):
		return
	if int(d.items.get("intel", 0)) <= 0:
		say(Txt.t("item_none") % Txt.t("it_intel"))
		return
	var ship := Variant.make(Ship.load_data(o.ship), o)
	var traps: Array = o.get("traps", [])
	o.intel = Traps.intel(ship, traps[0]) if not traps.is_empty() else ["in_none", []]
	d.items.intel = int(d.items.intel) - 1
	Career.save()
	intel_t[o.id] = 0.0
	flash = 1.0


func intel_text(o: Dictionary) -> String:
	var it: Array = o.get("intel", [])
	if it.is_empty():
		return ""
	var s := Txt.t(it[0])
	var args: Array = it[1]
	return s % args if not args.is_empty() else s


func buy(it: Array) -> void:
	if it.is_empty():
		return
	var id: String = it[0]
	var price: float = it[2]
	var d := Career.data
	if it[1] == "loan":
		var paid := Career.repay(price)
		if paid <= 0.0:
			say(Txt.t("tm_owned") if float(d.loan) <= 0.0 else Txt.t("tm_short") % Pal.money(price))
			return
		flash = 1.0
		_buy_fx(sel)
		say(Txt.t("tm_repaid") % [Pal.money(paid), Pal.money(float(d.loan))])
		_check_milestone()
		return
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
	var desk: Dictionary = d.get("desk", {})
	desk["buy"] = int(desk.get("buy", 0)) + 1
	d.desk = desk
	if it[1] == "item":
		d.items[id] = int(d.items.get(id, 0)) + 1
	else:
		d.upgrades[id] = 1
	if not d.get("seen", {}).has("bought"):
		d.seen["bought"] = true
		Copy.say(radio, "L_first_upgrade")
	Career.save()
	flash = 1.0
	_buy_fx(sel)
	say(Txt.t("tm_bought") % Txt.t(it[3]))


# a purchase: a bright pass along the row, and lights leaving the funds for it
func _buy_fx(i: int) -> void:
	sweep[i] = 0.0
	var r := _item_rect(i)
	for k in 14:
		sparks.append([_money_at() + Vector2(randf_range(-60, 20), randf_range(-8, 8)), Vector2(r.end.x - 40 - randf() * 220, r.get_center().y + randf_range(-10, 10)), 0.0, k * 0.025])


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
	var a := clampf(t / 0.35, 0.0, 1.0)
	var lv := clampf(leaving / 0.45, 0.0, 1.0) if leaving >= 0.0 else 0.0
	draw_rect(Rect2(Vector2.ZERO, s), Pal.BG)
	_backdrop(s, a)
	var ua := a * (1.0 - Pal.ease_in(lv))
	_top(s, ua)
	_tabs(ua)
	match tab:
		0:
			_market(s, ua)
		1:
			_list(SHOP, ua)
		2:
			_list(BERTH, ua)
	_bottom(s, ua)
	_sparks()
	_radio(s, ua)
	if leaving >= 0.0:
		_leave(s, lv)
	if milestone >= 0.0:
		_milestone(s)


# the room the terminal sits in: a faint dot field drifting, a slow scan, dark corners
func _backdrop(s: Vector2, a: float) -> void:
	for d in dust:
		var p: Vector2 = d[0]
		var q := Vector2(fposmod(p.x + t * d[1], 1.0) * s.x, p.y * s.y)
		draw_rect(Rect2(q, Vector2(d[3], d[3])), Pal.ink((0.035 + 0.03 * sin(t * 0.7 + d[2])) * a))
	var sy := fposmod(t * 70.0, s.y + 200.0) - 100.0
	draw_rect(Rect2(0, sy, s.x, 1), Pal.ink(0.025 * a))
	draw_rect(Rect2(0, sy - 40, s.x, 40), Pal.ink(0.008 * a))
	for i in 4:
		var w := 30.0 + i * 30.0
		draw_rect(Rect2(0, 0, w, s.y), Color(0, 0, 0, 0.05 * a))
		draw_rect(Rect2(s.x - w, 0, w, s.y), Color(0, 0, 0, 0.05 * a))


func _tabs(a: float) -> void:
	for i in 3:
		var r := _tab_rect(i)
		var on := tab == i
		if hover_tab == i and not on:
			Pal.band(self, r, 0.06 * a)
		_text("%d  %s" % [i + 1, Txt.t("tm_tab_" + TABS[i])], r.position + Vector2(16, 29), 17, Pal.ink((0.95 if on else (0.7 if hover_tab == i else 0.45)) * a), font_b if on else font)
	# the underline and its glow slide to the open tab on a spring
	var ux: float = tab_x.x
	var uw: float = tab_w.x
	Pal.band(self, Rect2(ux, 132, uw, 44), 0.12 * a)
	draw_rect(Rect2(ux, 174, uw, 2), Pal.heat(a, 1.1))
	draw_rect(Rect2(ux + uw * 0.25, 176, uw * 0.5, 1), Pal.heat(0.4 * a, 1.6))


func _top(s: Vector2, a: float) -> void:
	var d := Career.data
	_text("BERTH 07  ·  CHARON-DISPATCH", Vector2(60, 56), 13, Pal.ink(0.4 * a), font)
	_text(Txt.t("tm_title"), Vector2(60, 94), 30, Pal.ink(0.92 * a), font_l)
	var loan_c := Pal.heat(0.9 * a, 1.0) if float(d.loan) > 0.0 else Pal.ink(0.95 * a)
	var mc := Pal.ink(0.95 * a).lerp(Pal.ink(1.0 * a, 1.5) if money_flash > 0.0 else Pal.heat(a, 1.4), absf(money_flash))
	var cols := [
		[Txt.t("tm_money"), Pal.money(money_roll.shown), mc, money_flash],
		[Txt.t("tm_loan"), Pal.money(loan_roll.shown), loan_c.lerp(Pal.ink(a, 1.5), maxf(0.0, -loan_flash)), loan_flash],
		[Txt.t("tm_due"), Pal.money(minf(Career.INSTALLMENT, float(d.loan)) + snappedf(float(d.loan) * Career.INTEREST, 1.0)), Pal.ink(0.8 * a), 0.0],
		[Txt.t("tm_rep"), Txt.t("rep_" + Career.level()), Pal.ink(0.95 * a), 0.0],
	]
	for i in cols.size():
		var x := s.x - 60 - (cols.size() - 1 - i) * 250
		var ck := Pal.ease_out(clampf((t - 0.05 - i * 0.05) / 0.35, 0.0, 1.0))
		var f: float = absf(cols[i][3])
		_text(cols[i][0], Vector2(x, 56), 13, Pal.ink(0.4 * a * ck), font, 1)
		_text(cols[i][1], Vector2(x, 92 - f * 3.0 + (1.0 - ck) * 10.0), 26, cols[i][2], font_l, 1)
		if f > 0.0:
			draw_rect(Rect2(x - 160, 100, 160 * f, 1), Pal.ink(0.5 * f * a, 1.4) if cols[i][3] > 0.0 else Pal.heat(0.6 * f * a, 1.4))
	# reputation: how far to the next level, as a thin bar under the level name
	var nx := Career.to_next()
	var lvx := s.x - 60
	if nx > 0:
		_text(Txt.t("tm_rep_next") % nx, Vector2(lvx, 120), 11, Pal.ink(0.35 * a), font, 1)
		var lo := 0
		var hi := 0
		for l in Career.LEVELS:
			if int(d.rep) >= int(l[1]):
				lo = int(l[1])
			elif hi == 0:
				hi = int(l[1])
		var pk := clampf(float(int(d.rep) - lo) / maxf(1.0, hi - lo), 0.0, 1.0) * Pal.ease_out(clampf((t - 0.3) / 0.6, 0.0, 1.0))
		draw_rect(Rect2(lvx - 120, 101, 120, 2), Pal.ink(0.1 * a))
		draw_rect(Rect2(lvx - 120, 101, 120 * pk, 2), Pal.heat(0.8 * a, 1.2))
	var lw := (s.x - 120) * Pal.ease_out(clampf(t / 0.6, 0.0, 1.0))
	draw_line(Vector2(60, 186), Vector2(60 + lw, 186), Pal.ink(0.12 * a), 1.0)


# risk stars pop in one after another
func _stars(n: int, p: Vector2, a: float, delay: float) -> void:
	for i in 3:
		var c := p + Vector2(i * 18, 0)
		var pk := Pal.back(clampf((deal_t - delay - i * 0.08) / 0.25, 0.0, 1.0), 3.0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := (7.0 if k % 2 == 0 else 3.0) * (pk if i < n else 1.0)
			pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5 + (1.0 - pk) * 0.8) * r)
		if i < n:
			if pk > 0.02:
				draw_colored_polygon(pts, Pal.heat(0.9 * a, 1.0 + 0.6 * (1.0 - clampf((deal_t - delay - i * 0.08 - 0.25) / 0.4, 0.0, 1.0))))
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
		var hk: float = hover_k[i].x
		var sk: float = sel_k[i].x
		var k := Pal.ease_out(clampf((deal_t - 0.06 - i * 0.07) / 0.35, 0.0, 1.0)) * a
		if leaving >= 0.0 and on:
			continue
		# dealt from below, lifted on hover
		r.position.y += (1.0 - k) * 36.0 - hk * 6.0
		var shade := Rect2(r.position + Vector2(0, 10 + hk * 6.0), r.size)
		draw_rect(shade, Color(0, 0, 0, (0.25 + 0.2 * hk) * k))
		draw_rect(r, Color(0.03 + 0.012 * sk, 0.032 + 0.012 * sk, 0.037 + 0.012 * sk, 0.96 * k))
		draw_rect(r, Pal.ink((0.14 + 0.16 * hk + 0.4 * sk) * k), false, 1.2)
		# the chosen card: a hot edge that runs in, and a glow along the top
		draw_rect(Rect2(r.position, Vector2(3, r.size.y * sk)), Pal.heat(k, 1.1))
		Pal.band(self, Rect2(r.position, Vector2(r.size.x, 40)), 0.06 * sk * k)
		var x := r.position.x + 28
		var y := r.position.y + 44
		var ty: Dictionary = Market.TYPES.get(o.ship, {})
		var row_k := func(n: int) -> float: return Pal.ease_out(clampf((deal_t - 0.15 - i * 0.07 - n * 0.035) / 0.3, 0.0, 1.0)) * a
		_text("CONTRACT %s" % o.id, Vector2(x, y), 12, Pal.ink(0.4 * k), font)
		_text(o.reg + "  ·  " + (ty.name[0] if Txt.zh else ty.name[1]), Vector2(x + (1.0 - row_k.call(0)) * 14.0, y + 34), 22, Pal.ink(0.95 * row_k.call(0)), font_b)
		_text("%d m" % int(ty.get("length", 0)), Vector2(r.end.x - 28, y + 34), 14, Pal.ink(0.45 * k), font, 1)
		_stars(int(o.stars), Vector2(x + 7, y + 64), k, 0.25 + i * 0.07)
		_text(Txt.t("tm_risk"), Vector2(x + 70, y + 69), 12, Pal.ink(0.4 * k), font)
		_text(Txt.t("tm_reason"), Vector2(x, y + 108), 12, Pal.ink(0.4 * row_k.call(2)), font)
		_wrap(Copy.slot(o.reason), Vector2(x, y + 132), r.size.x - 56, 15, Pal.ink(0.85 * row_k.call(2)))
		# figures count up as the card lands
		var cnt := Pal.ease_out(clampf((deal_t - 0.2 - i * 0.07) / 0.7, 0.0, 1.0))
		var rows := [
			[Txt.t("tm_value"), Pal.money(snappedf(float(o.value) * cnt, 100.0))],
			[Txt.t("tm_fee"), Pal.money(snappedf(float(o.fee) * cnt, 100.0))],
			[Txt.t("tm_time"), "%d min" % int(float(o.time) / 60.0)],
		]
		for j in rows.size():
			var yy := y + 196 + j * 30
			var jk: float = row_k.call(3 + j)
			_text(rows[j][0], Vector2(x, yy), 14, Pal.ink(0.5 * jk), font)
			_text(rows[j][1], Vector2(r.end.x - 28, yy), 16, Pal.ink(0.92 * jk), font_b, 1)
			draw_line(Vector2(x, yy + 9), Vector2(x + (r.size.x - 56) * jk, yy + 9), Pal.ink(0.05 * jk), 1.0)
		_text(Txt.t("tm_logs"), Vector2(x, y + 310), 12, Pal.ink(0.4 * row_k.call(6)), font)
		var ly := y + 336.0
		for li in o.logs.size():
			var lk: float = row_k.call(7 + li)
			_text("›", Vector2(x + (1.0 - lk) * 10.0, ly), 14, Pal.tint(Pal.AIR, 0.6 * lk, 1.0), font)
			_wrap(Copy.slot(o.logs[li]), Vector2(x + 16 + (1.0 - lk) * 10.0, ly), r.size.x - 72, 14, Pal.tint(Pal.AIR, 0.8 * lk, 1.0))
			ly += 46.0
		# a survey report bought for this offer: typed in behind a scan line
		if o.has("intel"):
			var it_t := intel_t.get(o.id, 9.0) as float
			var full := intel_text(o)
			var shown := full.substr(0, int(it_t * 40.0))
			_text(Txt.t("tm_intel"), Vector2(x, r.end.y - 150), 12, Pal.tint(Pal.AIR, 0.7 * k, 1.0), font)
			_wrap(shown, Vector2(x, r.end.y - 126), r.size.x - 56, 14, Pal.tint(Pal.AIR, 0.95 * k, 1.0))
			if it_t < 1.0:
				var sx := r.position.x + r.size.x * it_t
				draw_rect(Rect2(sx, r.end.y - 160, 2, 60), Pal.tint(Pal.AIR, (1.0 - it_t) * k, 2.0))
		# the manifest: what the paperwork says is in the hold
		var cy := r.end.y - 96.0
		var mk: float = row_k.call(10)
		_text(Txt.t("tm_cargo"), Vector2(x, cy), 12, Pal.ink(0.4 * mk), font)
		var parts: Array = []
		for cg in o.get("cargo", []):
			parts.append("%s %s" % [cg[0], cg[1]])
		_wrap("  ·  ".join(parts) if not parts.is_empty() else Txt.t("tm_no_cargo"), Vector2(x, cy + 24), r.size.x - 56, 14, Pal.ink(0.75 * mk))
		_text(Txt.t("tm_logs_note"), Vector2(x, r.end.y - 24), 11, Pal.ink(0.3 * mk), font)


func _list(list: Array, a: float) -> void:
	var d := Career.data
	for i in list.size():
		var it: Array = list[i]
		var r := _item_rect(i)
		var hk: float = hover_k[i].x
		var sk: float = sel_k[i].x
		var k := Pal.ease_out(clampf((deal_t - 0.04 - i * 0.045) / 0.3, 0.0, 1.0)) * a
		r.position.x += (1.0 - k) * 40.0 + hk * 6.0
		draw_rect(r, Color(0.03 + 0.01 * sk, 0.032 + 0.01 * sk, 0.037 + 0.01 * sk, 0.92 * k))
		draw_rect(r, Pal.ink((0.12 + 0.14 * hk + 0.35 * sk) * k), false, 1.0)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - sk) * 0.5), Vector2(3, r.size.y * sk)), Pal.heat(k, 1.1))
		var open: bool = it[1] != "facility" or it[5]
		var owned: bool = (it[1] in ["upgrade", "facility"] and d.upgrades.has(it[0])) or (it[1] == "loan" and float(d.loan) <= 0.0)
		_text(Txt.t(it[3]), r.position + Vector2(24, 28), 17, Pal.ink((0.95 if open else 0.45) * k), font_b)
		_text(Txt.t(it[4]), r.position + Vector2(24, 52), 13, Pal.ink((0.55 if open else 0.3) * k), font)
		var right: String
		if not open:
			right = Txt.t("tm_later")
		elif owned:
			right = "✓  " + Txt.t("tm_owned")
		elif it[1] == "item":
			right = "%s   ·   %s %d" % [Pal.money(it[2]), Txt.t("tm_stock"), int(d.items.get(it[0], 0))]
		elif it[1] == "loan":
			right = "%s   ·   %s %s" % [Pal.money(minf(it[2], float(d.loan))), Txt.t("tm_loan"), Pal.money(float(d.loan))]
		else:
			right = Pal.money(it[2])
		_text(right, Vector2(r.end.x - 24, r.position.y + 40), 18, Pal.ink((0.9 if open and not owned else 0.4) * k), font_b, 1)
		# just bought: a bright pass along the row
		if sweep.has(i):
			var sw: float = sweep[i]
			var sx := r.position.x + r.size.x * Pal.ease_out(clampf(sw / 0.5, 0.0, 1.0))
			var fade := 1.0 - clampf((sw - 0.3) / 0.5, 0.0, 1.0)
			draw_rect(Rect2(r.position.x, r.position.y, sx - r.position.x, r.size.y), Color(1, 1, 1, 0.05 * fade))
			draw_rect(Rect2(sx - 2, r.position.y, 2, r.size.y), Pal.heat(fade, 2.0))


func _bottom(s: Vector2, a: float) -> void:
	var r := _go_rect()
	var label: String
	if tab == 0:
		label = Txt.t("tm_take")
		var o: Dictionary = offers()[sel] if sel < offers().size() else {}
		if not o.is_empty() and not o.has("intel") and int(Career.data.items.get("intel", 0)) > 0:
			_text(Txt.t("tm_use_intel") % int(Career.data.items.intel), Vector2(60, r.position.y + 38), 13, Pal.tint(Pal.AIR, 0.8 * a, 1.0), font)
		if not o.is_empty() and float(Career.data.money) < float(o.fee):
			_text(Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(Career.data.money)), Vector2(r.position.x - 24, r.position.y + 38), 13, Pal.heat(0.85 * a, 1.0), font, 1)
	else:
		label = Txt.t("tm_buy")
	var gk := 1.0 if hover_go else 0.0
	var bk := Pal.back(clampf((t - 0.3) / 0.35, 0.0, 1.0), 2.0)
	r = Rect2(r.position + Vector2(0, (1.0 - bk) * 20.0), r.size)
	draw_rect(r, Color(0.05 + 0.03 * gk, 0.05 + 0.03 * gk, 0.055 + 0.03 * gk, 0.95 * a))
	draw_rect(r, Pal.ink((0.8 if hover_go else 0.4) * a), false, 1.4)
	# a heat line that breathes, and a light that runs along it
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Pal.heat(a * (0.7 + 0.3 * sin(t * 3.0)), 1.1))
	var run := fposmod(t * 0.6, 1.0)
	draw_rect(Rect2(r.position.x + r.size.x * run - 30, r.end.y - 3, 60, 3), Pal.heat(0.6 * a, 2.2))
	_text(label + "   Enter", r.get_center() + Vector2(0, 8), 20, Pal.ink(0.95 * a), font_b, 0)
	_text(Txt.t("tm_keys"), Vector2(60, s.y - 60), 12, Pal.ink(0.3 * a), font)
	if msg != "" and msg_t < 3.0:
		var mk := clampf((3.0 - msg_t) / 0.4, 0.0, 1.0) * Pal.ease_out(clampf(msg_t / 0.2, 0.0, 1.0))
		_text(msg, Vector2(60 + (1.0 - Pal.ease_out(clampf(msg_t / 0.25, 0.0, 1.0))) * 20.0, s.y - 92), 16, Pal.ink(0.9 * a * mk), font_b)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.05 * flash))


# lights leaving the funds for what was just bought
func _sparks() -> void:
	for sp in sparks:
		var e: float = clampf((sp[2] - sp[3]) / 0.55, 0.0, 1.0)
		if e <= 0.0:
			continue
		var p: Vector2 = (sp[0] as Vector2).lerp(sp[1], Pal.ease_io(e)) + Vector2(0, -sin(e * PI) * 60.0)
		draw_circle(p, 2.2 * (1.0 - e * 0.6), Pal.heat(1.0 - e * 0.5, 2.0))


# taking a contract: the chosen card grows to fill the screen, then a line closes it
func _leave(s: Vector2, lv: float) -> void:
	var g := Pal.ease_io(clampf(leaving / 0.35, 0.0, 1.0))
	var full := Rect2(Vector2.ZERO, s)
	var r := Rect2(leave_from.position.lerp(full.position, g), leave_from.size.lerp(full.size, g))
	draw_rect(r, Color(0.03, 0.032, 0.037, 1.0))
	draw_rect(r, Pal.ink(0.6 * (1.0 - g)), false, 1.2)
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.heat(1.0 - g, 1.2))
	var c := clampf((leaving - 0.3) / 0.2, 0.0, 1.0)
	if c > 0.0:
		var h := s.y * 0.5 * Pal.ease_in(c)
		draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y * 0.5 - 1, s.x, 2), Pal.heat(c, 2.0))


# the loan paid off: the berth's name stamped across the terminal
func _milestone(s: Vector2) -> void:
	var e := milestone
	var a := clampf(e / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.82 * a))
	var k := Pal.back(clampf((e - 0.3) / 0.35, 0.0, 1.0), 2.4)
	if k > 0.02:
		_text("BERTH 07", Vector2(s.x * 0.5, s.y * 0.42), int(120 * k), Pal.ink(0.96), font_l, 0)
	var sa := clampf((e - 0.8) / 0.4, 0.0, 1.0)
	draw_rect(Rect2(s.x * 0.5 - 140 * sa, s.y * 0.42 + 30, 280 * sa, 3), Pal.heat(sa, 1.4))
	_text(Txt.t("tm_paid_off"), Vector2(s.x * 0.5, s.y * 0.42 + 76), 22, Pal.ink(0.8 * sa), font_b, 0)
	_text(Txt.t("tm_paid_off_d") % int(Career.data.get("paid_off_at", 0)), Vector2(s.x * 0.5, s.y * 0.42 + 110), 14, Pal.ink(0.45 * sa), font, 0)
	if e > 1.5:
		_text(Txt.t("tm_any_key"), Vector2(s.x * 0.5, s.y - 80), 14, Pal.ink(0.3 + 0.2 * sin(t * 3.0)), font, 0)
	if e < 0.5:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.25 * (1.0 - e / 0.5)))


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
