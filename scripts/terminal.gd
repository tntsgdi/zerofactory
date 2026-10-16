class_name Terminal
extends Control
# The berth terminal between contracts (full screen): money, loan,
# installment and reputation always along the top; three tabs — the contract
# market (three offer cards, "take" under the chosen one), the equipment shop
# (the drone and the berth drawn in line, each upgrade on the part it
# replaces; consumables in a grid; the chosen thing's detail and its buy
# button on the right, with what is left after and what the next contract
# fee would borrow), berth management (the loan with a repay slider,
# training replay, what opens later in one line).
# Keys: 1 2 3 tabs, ← → pick, ↑ ↓ quantity / amount, Enter take/buy, Esc title.

const TABS := ["market", "shop", "berth"]
# what can be bought: [id, kind, price, Txt name key, Txt effect key]
# the first four are fitted (drawn on the drone and the berth), the rest are stock
const SHOP := [
	["scan_kit", "upgrade", 24000.0, "up_scan", "up_scan_d"],
	["grapple5", "upgrade", 38000.0, "up_grapple", "up_grapple_d"],
	["pump2", "upgrade", 22000.0, "up_pump", "up_pump_d"],
	["arm", "facility", 65000.0, "fa_arm", "fa_arm_d"],
	["repair", "item", 3000.0, "it_repair", "it_repair_d"],
	["ring", "item", 9000.0, "it_ring", "it_ring_d"],
	["spare", "item", 15000.0, "it_spare", "it_spare_d"],
	["intel", "item", 6000.0, "it_intel", "it_intel_d"],
]
const FITTED := 4
# now → after, per upgrade: [label key, now, after, now 0..1, after 0..1] ("sh_" values are Txt keys)
const STATS := {
	"scan_kit": [["sh_cond", "sh_none", "sh_shown", 0.0, 1.0], ["sh_hidden", "sh_unseen", "sh_found", 0.0, 1.0]],
	"grapple5": [["sh_grab", "3 t", "5 t", 0.6, 1.0]],
	"pump2": [["sh_gas", "1×", "2×", 0.5, 1.0], ["sh_fluid", "1×", "2×", 0.5, 1.0]],
	"arm": [["sh_auto", "sh_none", "≤ 1 t", 0.0, 0.5]],
}
const USE_KEY := {"repair": "6", "ring": "7", "spare": "", "intel": "I"}
const BERTH := [
	["repay", "loan", 20000.0, "tm_repay", "tm_repay_d", true],
	["training", "training", 0.0, "tm_training", "tm_training_d", true],
	["mouth_rail", "facility", 30000.0, "fa_rail", "fa_rail_d", true],
	["net05", "facility", 18000.0, "fa_net", "fa_net_d", true],
	["hauler", "facility", 45000.0, "fa_hauler", "fa_hauler_d", true],
]
# what berth management will offer later, named in one line
const LATER := ["fa_drone2", "fa_mast", "fa_scan"]
const REPAY_STEP := 5000.0

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
var qty := 1               # how many of a consumable
var repay_amt := 20000.0   # the repay slider
var dragging := false
var shake := 0.0           # the button jolts when it could not act
var install := {}          # upgrade id -> seconds since it was fitted (the part goes on)
var go_x := Motion.Spring.new(0.0, 300.0, 0.8)   # the take button follows the chosen card
var hover_minus := false
var hover_plus := false
var thumbs := {}           # offer id -> what its cross-section shows (worked out once)
var leave_offer := {}      # the offer being taken (it leaves the market as it is signed)


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
	# back from a settlement: the figures roll from what they were before it
	var rf: Dictionary = Career.data.get("roll_from", {})
	if not rf.is_empty():
		money_roll.shown = float(rf.get("money", Career.data.money))
		loan_roll.shown = float(rf.get("loan", Career.data.loan))
		money_roll.speed = 2.2
		loan_roll.speed = 2.2
		money_flash = 1.0 if float(Career.data.money) >= money_roll.shown else -1.0
		loan_flash = -1.0
		Career.data.erase("roll_from")
		Career.save()
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
	hover_minus = _has_qty() and _qty_rect(-1).has_point(m)
	hover_plus = _has_qty() and _qty_rect(1).has_point(m)
	if dragging:
		_slide_to(m.x)
	shake = maxf(0.0, shake - dt * 2.2)
	for k in install.keys():
		install[k] += dt
		if install[k] > 1.6:
			install.erase(k)
	if leaving >= 0.0:
		leaving += dt
		if leaving > 0.78:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if settings.is_open or leaving >= 0.0:
		return
	if ev is InputEventMouseButton and ev.pressed and milestone >= 0.0:
		if milestone > 1.5:
			milestone = -1.0
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		dragging = false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if hover_tab >= 0:
			set_tab(hover_tab)
		elif hover_go:
			act()
		elif hover_minus:
			_bump(-1)
		elif hover_plus:
			_bump(1)
		elif tab == 2 and _slider_rect().grow(12.0).has_point(ev.position):
			sel = 0
			dragging = true
			_slide_to(ev.position.x)
		elif hover >= 0:
			# a second click on a market card takes it; elsewhere a click only chooses
			if sel == hover and tab == 0:
				act()
			if sel != hover:
				qty = 1
			sel = hover


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
		KEY_LEFT, KEY_A:
			sel = maxi(0, sel - 1)
			qty = 1
		KEY_RIGHT, KEY_D:
			sel = mini(items().size() - 1, sel + 1)
			qty = 1
		KEY_UP, KEY_W, KEY_EQUAL, KEY_KP_ADD:
			_bump(1)
		KEY_DOWN, KEY_S, KEY_MINUS, KEY_KP_SUBTRACT:
			_bump(-1)
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
	qty = 1
	repay_amt = _repay_default()


# ↑ ↓: how many of a consumable, or how much to repay
func _bump(d: int) -> void:
	if _has_qty():
		qty = clampi(qty + d, 1, 9)
	elif tab == 2 and sel == 0:
		repay_amt = clampf(snappedf(repay_amt + d * REPAY_STEP, REPAY_STEP), 0.0, _repay_max())


func _has_qty() -> bool:
	return tab == 1 and sel >= FITTED and sel < SHOP.size()


func _repay_max() -> float:
	return maxf(0.0, minf(float(Career.data.money), float(Career.data.loan)))


func _repay_default() -> float:
	return minf(20000.0, _repay_max())


func _slide_to(x: float) -> void:
	var r := _slider_rect()
	var k := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	var mx := _repay_max()
	repay_amt = mx if k > 0.995 else minf(mx, snappedf(mx * k, REPAY_STEP))


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
	if tab == 0 and not offers().is_empty():
		go_x.target = _item_rect(clampi(sel, 0, offers().size() - 1)).position.x
		if go_x.x == 0.0:
			go_x.snap(go_x.target)
	go_x.step(dt)
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
	elif tab == 1:
		buy(SHOP[sel] if sel < SHOP.size() else [], qty if _has_qty() else 1)
	else:
		buy(BERTH[sel] if sel < BERTH.size() else [])


func take(i: int) -> void:
	if i < 0 or i >= offers().size():
		return
	leave_from = _item_rect(i)
	leave_offer = offers()[i].duplicate(true)
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


func buy(it: Array, n: int = 1) -> void:
	if it.is_empty():
		return
	var id: String = it[0]
	var price: float = it[2] * n
	var d := Career.data
	if it[1] == "training":
		# back to TS-1; finishing or leaving the course comes back here
		leave_from = _item_rect(sel)
		Game.start_ship = "ts1"
		Game.contract = {}
		SaveGame.load_requested = SaveGame.exists(SaveGame.train_path)
		leaving = 0.0
		return
	if it[1] == "loan":
		var paid := Career.repay(repay_amt if repay_amt > 0.0 else it[2])
		if paid <= 0.0:
			_refuse(Txt.t("tm_owned") if float(d.loan) <= 0.0 else Txt.t("tm_short") % Pal.money(repay_amt))
			return
		flash = 1.0
		_buy_fx(sel)
		say(Txt.t("tm_repaid") % [Pal.money(paid), Pal.money(float(d.loan))])
		repay_amt = minf(repay_amt, _repay_max())
		_check_milestone()
		return
	if it[1] != "item" and d.upgrades.has(id):
		_refuse(Txt.t("tm_owned"))
		return
	if float(d.money) < price:
		_refuse(Txt.t("tm_short") % Pal.money(price - float(d.money)))
		return
	d.money = float(d.money) - price
	var desk: Dictionary = d.get("desk", {})
	desk["buy"] = int(desk.get("buy", 0)) + n
	d.desk = desk
	if it[1] == "item":
		d.items[id] = int(d.items.get(id, 0)) + n
	else:
		d.upgrades[id] = 1
		install[id] = 0.0
	if not d.get("seen", {}).has("bought"):
		d.seen["bought"] = true
		Copy.say(radio, "L_first_upgrade")
	Career.save()
	flash = 1.0
	_buy_fx(sel)
	say(Txt.t("tm_bought") % (Txt.t(it[3]) + (" ×%d" % n if n > 1 else "")))


# it could not be done: the button jolts, the funds flash, and it says why
func _refuse(why: String) -> void:
	shake = 1.0
	money_flash = -1.0
	say(why)


# a purchase: a bright pass along the row, and lights leaving the funds for it
func _buy_fx(i: int) -> void:
	sweep[i] = 0.0
	var r := _item_rect(i) if tab == 1 else _go_rect()
	for k in 14:
		sparks.append([_money_at() + Vector2(randf_range(-60, 20), randf_range(-8, 8)), Vector2(r.position.x + randf() * r.size.x, r.get_center().y + randf_range(-10, 10)), 0.0, k * 0.025])


# ---------------------------------------------------------------- layout

func _tab_rect(i: int) -> Rect2:
	return Rect2(60 + i * 230, 132, 216, 44)


func _item_rect(i: int) -> Rect2:
	var s := size
	match tab:
		0:
			var w := (s.x - 120 - 2 * 30) / 3.0
			return Rect2(60 + i * (w + 30), 200, w, s.y - 336)
		1:
			if i < FITTED:
				return _callout(i)
			var g := _grid_rect()
			var cw := (g.size.x - 3 * 16.0) / 4.0
			return Rect2(g.position.x + (i - FITTED) * (cw + 16.0), g.position.y + 36, cw, g.size.y - 36)
	if i >= 2:
		return _facility_rect(i - 2)
	return _finance_rect() if i == 0 else _training_rect()


func _facility_rect(j: int) -> Rect2:
	var tr := _training_rect()
	return Rect2(tr.position.x, tr.end.y + 52 + j * 106, tr.size.x, 94)


# the shop: the drawing on the left (upgrades called out on it), stock below it, detail on the right
func _left_rect() -> Rect2:
	return Rect2(60, 200, size.x * 0.58 - 60, size.y - 336)


func _schematic_rect() -> Rect2:
	var l := _left_rect()
	return Rect2(l.position, Vector2(l.size.x, l.size.y - 196))


func _grid_rect() -> Rect2:
	var l := _left_rect()
	return Rect2(l.position.x, l.end.y - 176, l.size.x, 176)


func _detail_rect() -> Rect2:
	var x := size.x * 0.58 + 30
	return Rect2(x, 200, size.x - 60 - x, size.y - 336)


# where each upgrade is called out on the drawing: a label box, joined to its part
func _callout(i: int) -> Rect2:
	var r := _schematic_rect()
	var w := 270.0
	var h := 66.0
	match i:
		0: return Rect2(r.position.x + 24, r.position.y + 24, w, h)
		1: return Rect2(r.position.x + 24, r.end.y - h - 24, w, h)
		2: return Rect2(r.end.x - w - 24, r.end.y - h - 24, w, h)
	return Rect2(r.end.x - w - 24, r.position.y + 24, w, h)


# the drone sits left of centre, the berth's boom and hose mast to its right
func _drone_c() -> Vector2:
	var r := _schematic_rect()
	return r.position + Vector2(r.size.x * 0.34, r.size.y * 0.54)


const DK := 4.0      # the drone drawn at four times its size on site


func _anchor(i: int) -> Vector2:
	var r := _schematic_rect()
	var c := _drone_c()
	match i:
		0: return c + Vector2(0, -Drone.R * DK - 40)
		1: return c + Vector2(-13.0 * DK, 13.0 * DK) * 0.72
		2: return Vector2(r.position.x + r.size.x * 0.8, r.position.y + r.size.y * 0.5)
	return Vector2(r.position.x + r.size.x * 0.72, r.position.y + r.size.y * 0.3)


func _finance_rect() -> Rect2:
	return Rect2(60, 200, size.x * 0.58 - 60, size.y - 336)


func _training_rect() -> Rect2:
	var x := size.x * 0.58 + 30
	return Rect2(x, 200, size.x - 60 - x, 220)


func _slider_rect() -> Rect2:
	var f := _finance_rect()
	return Rect2(f.position.x + 36, f.position.y + 150, f.size.x - 72, 8)


func _qty_rect(d: int) -> Rect2:
	var r := _detail_rect()
	return Rect2(r.position.x + 32 + (0.0 if d < 0 else 150.0), r.end.y - 176, 48, 48)


func _go_rect() -> Rect2:
	var s := size
	match tab:
		0:
			var w := (s.x - 120 - 2 * 30) / 3.0
			return Rect2(go_x.x, s.y - 122, w, 62)
		1:
			var r := _detail_rect()
			return Rect2(r.position.x + 32, r.end.y - 100, r.size.x - 64, 68)
	if sel >= 2:
		var fr := _facility_rect(sel - 2)
		return Rect2(fr.end.x - 250, fr.position.y + 18, 226, 58)
	var f := _finance_rect() if sel == 0 else _training_rect()
	return Rect2(f.position.x + 36, f.end.y - 100, f.size.x - 72, 68)


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
			_shop(s, ua)
		2:
			_berth(s, ua)
	_bottom(s, ua)
	_sparks()
	_radio(s, ua)
	if leaving >= 0.0:
		_leave(s, lv)
	if milestone >= 0.0:
		_milestone(s)
	if t < 0.6:
		var e := Pal.ease_out(clampf((t - 0.05) / 0.5, 0.0, 1.0))
		var h := s.y * 0.5 * (1.0 - e)
		draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		var la := 1.0 - clampf((t - 0.15) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(0, h - 1, s.x, 2), Pal.heat(la, 2.0))
		draw_rect(Rect2(0, s.y - h - 1, s.x, 2), Pal.heat(la, 2.0))


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
	var company: String = str(Career.data.get("company", ""))
	_text((company if company != "" else "BERTH 07") + "  ·  CHARON-DISPATCH", Vector2(60, 56), 13, Pal.ink(0.55 * a), font)
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
		_text(Txt.t("tm_none"), Vector2(s.x * 0.5, s.y * 0.45), 18, Pal.ink(0.6 * a), font, 0)
		return
	# what the cards are compared by: the net, and the net per minute of standard time
	var best_net := -1
	var best_rate := -1
	for i in os.size():
		if best_net < 0 or _net(os[i]) > _net(os[best_net]):
			best_net = i
		if best_rate < 0 or _rate(os[i]) > _rate(os[best_rate]):
			best_rate = i
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
		draw_rect(Rect2(r.position + Vector2(0, 10 + hk * 6.0), r.size), Color(0, 0, 0, (0.25 + 0.2 * hk) * k))
		UI.panel(self, r, k, sk)
		var x := r.position.x + 28
		var w := r.size.x - 56
		var y := r.position.y
		var row_k := func(n: int) -> float: return Pal.ease_out(clampf((deal_t - 0.15 - i * 0.07 - n * 0.035) / 0.3, 0.0, 1.0)) * a
		var ty: Dictionary = Market.TYPES.get(o.ship, {})
		var scope: String = o.get("scope", "full")
		# 1 · what kind of job, how risky, which ship
		var sct := Txt.t("sc_" + scope)
		var cw := font_b.get_string_size(sct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
		var chip := Rect2(x, y + 22, cw, 30)
		var ccol: Color = Pal.HEAT if scope != "full" else Pal.INK
		draw_rect(chip, Color(ccol.r, ccol.g, ccol.b, (0.18 if scope != "full" else 0.08) * k))
		draw_rect(chip, Color(ccol.r, ccol.g, ccol.b, 0.7 * k), false, 1.2)
		_text(sct, chip.get_center() + Vector2(0, 6), 16, Pal.ink(0.98 * k), font_b, 0)
		_stars(int(o.stars), Vector2(chip.end.x + 22, y + 37), k, 0.25 + i * 0.07)
		_text(Txt.t("tm_risk_" + str(int(o.stars))), Vector2(chip.end.x + 80, y + 43), 15, Pal.ink(0.75 * k), font)
		_text(Txt.t("tm_contract_n") % o.id, Vector2(r.end.x - 28, y + 43), 13, Pal.ink(0.5 * k), font, 1)
		_text("%s  ·  %s  ·  %d m" % [o.reg, (ty.name[0] if Txt.zh else ty.name[1]), int(ty.get("length", 0))], Vector2(x, y + 82), 17, Pal.ink(0.85 * row_k.call(0)), font_b)
		# 2 · the number to choose by
		var net := _net(o)
		var cnt := Pal.ease_out(clampf((deal_t - 0.2 - i * 0.07) / 0.7, 0.0, 1.0))
		var hk2: float = row_k.call(1)
		_text(Txt.t("tm_net"), Vector2(x, y + 122), 14, Pal.ink(0.6 * hk2), font)
		_text(Pal.money(snappedf(net * cnt, 100.0)), Vector2(x, y + 172), 46, Pal.ink(0.98 * hk2) if net >= 0.0 else Pal.heat(0.95 * hk2, 1.2), font_l)
		_text(Txt.t("tm_per_min") % Pal.money(snappedf(_rate(o), 10.0)), Vector2(r.end.x - 28, y + 146), 17, Pal.ink(0.9 * hk2), font_b, 1)
		_text(Txt.t("tm_minutes") % int(float(o.time) / 60.0), Vector2(r.end.x - 28, y + 172), 15, Pal.ink(0.6 * hk2), font, 1)
		# the best of the three, said plainly
		var badges: Array = []
		if i == best_net and os.size() > 1:
			badges.append(Txt.t("tm_best_net"))
		if i == best_rate and os.size() > 1:
			badges.append(Txt.t("tm_best_rate"))
		var bx := x
		for bdg in badges:
			var bw := font_b.get_string_size(bdg, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
			draw_rect(Rect2(bx, y + 186, bw, 22), Pal.tint(Pal.FLUID, 0.16 * hk2, 1.0))
			_text(bdg, Vector2(bx + 8, y + 202), 13, Pal.tint(Pal.FLUID, 0.95 * hk2, 1.1), font_b)
			bx += bw + 8.0
		# 3 · what the job is, on the ship
		_thumb(o, Rect2(x, y + 222, w, 92), row_k.call(2))
		var task := Market.scope_text(o) if scope != "full" else Txt.t("tm_task_full")
		c_wrap(task, Vector2(x, y + 340), w, 15, Pal.ink(0.88 * row_k.call(3)))
		# 4 · the money, line by line
		var due := Career.due_for(o)
		var lines := [
			[Txt.t("tm_value"), Pal.money(float(o.value))],
			[Txt.t("tm_fee"), "−" + Pal.money(float(o.fee))],
			[Txt.t("tm_due_c"), "−" + Pal.money(due)],
		]
		for j in lines.size():
			var yy := y + 400 + j * 26
			var jk: float = row_k.call(4 + j)
			_text(lines[j][0], Vector2(x, yy), 14, Pal.ink(0.6 * jk), font)
			_text(lines[j][1], Vector2(r.end.x - 28, yy), 15, Pal.ink(0.85 * jk), font_b, 1)
		if float(Career.data.money) < float(o.fee):
			_text(Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(Career.data.money)), Vector2(x, y + 478), 13, Pal.heat(0.9 * k, 1.1), font)
		# 5 · the paperwork: why it was scrapped, what the logs say, what is declared
		var pk: float = row_k.call(8)
		draw_line(Vector2(x, y + 496), Vector2(x + w, y + 496), Pal.ink(0.1 * pk), 1.0)
		_text(Txt.t("tm_reason"), Vector2(x, y + 522), 13, Pal.ink(0.55 * pk), font)
		_text(Copy.slot(o.reason), Vector2(x + 96, y + 522), 14, Pal.ink(0.8 * pk), font)
		_text(Txt.t("tm_logs"), Vector2(x, y + 550), 13, Pal.ink(0.55 * pk), font)
		var ly := y + 550.0
		for li in o.logs.size():
			_text("› " + Copy.slot(o.logs[li]), Vector2(x + 96, ly), 14, Pal.tint(Pal.AIR, 0.85 * pk, 1.0), font)
			ly += 22.0
		var parts: Array = []
		for cg in o.get("cargo", []):
			parts.append("%s %s" % [cg[0], Txt.cargo(cg[1])])
		_text(Txt.t("tm_cargo"), Vector2(x, ly + 12), 13, Pal.ink(0.55 * pk), font)
		c_wrap("  ·  ".join(parts) if not parts.is_empty() else Txt.t("tm_no_cargo"), Vector2(x, ly + 34), w, 14, Pal.ink(0.8 * pk))
		# a survey report bought for this offer: typed in behind a scan line
		if o.has("intel"):
			var it_t := intel_t.get(o.id, 9.0) as float
			var shown := intel_text(o).substr(0, int(it_t * 40.0))
			var ir := Rect2(x - 10, r.end.y - 64, w + 20, 48)
			draw_rect(ir, Pal.tint(Pal.AIR, 0.08 * k, 1.0))
			_text(Txt.t("tm_intel"), ir.position + Vector2(10, 20), 13, Pal.tint(Pal.AIR, 0.85 * k, 1.0), font)
			_text(shown, ir.position + Vector2(10, 40), 14, Pal.tint(Pal.AIR, 0.95 * k, 1.0), font)
			if it_t < 1.0:
				draw_rect(Rect2(ir.position.x + ir.size.x * it_t, ir.position.y, 2, ir.size.y), Pal.tint(Pal.AIR, (1.0 - it_t) * k, 2.0))
		else:
			_text(Txt.t("tm_logs_note"), Vector2(x, r.end.y - 20), 13, Pal.ink(0.45 * pk), font)


func _net(o: Dictionary) -> float:
	return float(o.value) - float(o.fee) - Career.due_for(o)


func _rate(o: Dictionary) -> float:
	return _net(o) / maxf(1.0, float(o.time) / 60.0)


func c_wrap(s: String, pos: Vector2, w: float, size_px: int, col: Color) -> void:
	draw_multiline_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, w, size_px, 2, col)


# a cross-section of the ship on the card: only what the paperwork mentions —
# the declared containers, the named pieces of a rescue, the part a contract buys
func _thumb(o: Dictionary, r: Rect2, a: float) -> void:
	if not thumbs.has(o.id):
		var d := Variant.make(Ship.load_data(o.ship), o)
		var marks: Array = []
		var want: Array = []
		for cg in o.get("cargo", []):
			want.append(cg[0])
		for tg in o.get("scope_tags", []):
			want.append(tg)
		for pd in d.pieces:
			if pd.get("tag", "") in want:
				marks.append([Variant._cx(pd), _cy(pd), pd.tag, pd.tag in o.get("scope_tags", [])])
		thumbs[o.id] = {"marks": marks, "len": float(d.get("length", 42.0))}
	var th: Dictionary = thumbs[o.id]
	var L: float = th.len
	var sc := minf(r.size.x / L, r.size.y / 9.0)
	var org := Vector2(r.position.x + (r.size.x - L * sc) * 0.5, r.get_center().y)
	var P := func(v: Vector2) -> Vector2: return org + v * sc
	draw_rect(r, Color(0, 0, 0, 0.25 * a))
	# the part the contract buys, shaded
	match o.get("scope", "full"):
		"section":
			draw_rect(Rect2(P.call(Vector2(Variant.AFT_X, -4.0)), Vector2((L - Variant.AFT_X) * sc, 8.0 * sc)), Pal.heat(0.16 * a, 1.0))
			draw_dashed_line(P.call(Vector2(Variant.AFT_X, -4.4)), P.call(Vector2(Variant.AFT_X, 4.4)), Pal.heat(0.9 * a, 1.2), 1.4, 5.0)
	var hull := PackedVector2Array()
	for v in [Vector2(0.2, 0.5), Vector2(0.9, -1.6), Vector2(2.4, -3.3), Vector2(4.6, -4.0), Vector2(33.0, -4.0), Vector2(33.0, -3.1), Vector2(40.6, -3.1), Vector2(40.6, 3.1), Vector2(33.0, 3.1), Vector2(33.0, 4.0), Vector2(4.6, 4.0), Vector2(2.4, 3.4), Vector2(0.8, 2.2), Vector2(0.2, 0.5)]:
		hull.append(P.call(v))
	draw_polyline(hull, Pal.ink(0.6 * a), 1.2, true)
	for bx in [5.0, 10.0, 27.0]:
		draw_line(P.call(Vector2(bx, -3.6)), P.call(Vector2(bx, 3.0)), Pal.ink(0.25 * a), 1.0)
	for m in th.marks:
		var p: Vector2 = P.call(Vector2(m[0], m[1]))
		var hot: bool = m[3]
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Pal.heat(0.9 * a, 1.2) if hot else Pal.tint(Pal.AIR, 0.85 * a, 1.0), false, 1.4)
		_text(m[2], p + Vector2(-14, -10), 12, Pal.heat(0.85 * a, 1.1) if hot else Pal.tint(Pal.AIR, 0.75 * a, 1.0), font)


func _cy(pd: Dictionary) -> float:
	var yv := 0.0
	for q in pd.poly:
		yv += float(q[1])
	return yv / maxf(1.0, pd.poly.size())


# ---------------------------------------------------------------- the shop

func _shop(_s: Vector2, a: float) -> void:
	var sr := _schematic_rect()
	var ka := Pal.ease_out(clampf(deal_t / 0.4, 0.0, 1.0)) * a
	UI.panel(self, sr, ka)
	_schematic(sr, ka)
	for i in FITTED:
		_callout_box(i, ka)
	# how to read the drawing
	var lg := Txt.t("tm_legend")
	_text(lg, Vector2(sr.get_center().x, sr.end.y - 14), 13, Pal.ink(0.55 * ka), font, 0)
	# stock: a row of cells under the drawing
	var g := _grid_rect()
	_text(Txt.t("tm_items"), g.position + Vector2(0, 22), 15, Pal.ink(0.6 * ka), font_b)
	for i in range(FITTED, SHOP.size()):
		_cell(i, ka)
	_detail(a)


# the drone and the berth in line, each upgrade on the part it changes:
# fitted parts solid, the ones not bought as a faint dashed outline
func _schematic(sr: Rect2, a: float) -> void:
	var d := Career.data
	var c := _drone_c()
	var R := Drone.R * DK
	# grid paper
	var gx := sr.position.x + 20.0
	while gx < sr.end.x - 10.0:
		draw_line(Vector2(gx, sr.position.y + 10), Vector2(gx, sr.end.y - 10), Pal.ink(0.025 * a), 1.0)
		gx += 40.0
	var gy := sr.position.y + 20.0
	while gy < sr.end.y - 10.0:
		draw_line(Vector2(sr.position.x + 10, gy), Vector2(sr.end.x - 10, gy), Pal.ink(0.025 * a), 1.0)
		gy += 40.0
	# the berth: floor, tower, boom (in the right part of the drawing)
	var bx0 := sr.position.x + sr.size.x * 0.52
	var by := sr.position.y + sr.size.y * 0.24
	var fy := sr.end.y - 40.0
	var tx := sr.end.x - 40.0
	draw_line(Vector2(bx0, fy), Vector2(sr.end.x - 16, fy), Pal.ink(0.35 * a), 1.6)
	draw_line(Vector2(tx, fy), Vector2(tx, by - 20), Pal.ink(0.35 * a), 1.6)
	draw_line(Vector2(tx - 12, fy), Vector2(tx - 12, by - 20), Pal.ink(0.2 * a), 1.0)
	draw_line(Vector2(bx0, by), Vector2(tx, by), Pal.ink(0.35 * a), 1.6)
	draw_line(Vector2(bx0, by - 12), Vector2(tx, by - 12), Pal.ink(0.2 * a), 1.0)
	var zx := bx0
	while zx < tx - 12:
		draw_line(Vector2(zx, by), Vector2(zx + 12, by - 12), Pal.ink(0.15 * a), 1.0)
		zx += 24.0
	_text("BERTH 07", Vector2(bx0, by - 22), 13, Pal.ink(0.4 * a), font)
	# the hose mast from the floor
	var pa := _anchor(2)
	draw_line(Vector2(pa.x, fy), Vector2(pa.x, pa.y + 14), Pal.ink(0.35 * a), 1.6)
	draw_rect(Rect2(pa + Vector2(-16, -10), Vector2(30, 26)), Pal.ink(0.5 * a), false, 1.4)
	# the drone
	var hexp := PackedVector2Array()
	for i in 8:
		hexp.append(c + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * R)
	draw_colored_polygon(hexp, Color(0.06, 0.064, 0.072, a))
	var cl := hexp.duplicate()
	cl.append(hexp[0])
	draw_polyline(cl, Pal.ink(0.85 * a), 2.0, true)
	for dv in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var pc: Vector2 = c + dv * (R - 4.0)
		var tg := Vector2(-dv.y, dv.x)
		draw_line(pc + tg * 20.0, pc - tg * 20.0, Pal.ink(0.7 * a), 6.0)
	draw_circle(c, 8.5 * DK, Color(0.03, 0.03, 0.035, a))
	draw_arc(c, 8.5 * DK, 0.0, TAU, 40, Pal.ink(0.55 * a), 1.4, true)
	draw_circle(c + Vector2(3.5, 0) * DK, 3.4 * DK, Pal.ink(0.9 * a))
	_text("R-02", c + Vector2(-20, R + 36), 15, Pal.ink(0.6 * a), font_b)
	# the four fitted upgrades
	for i in FITTED:
		var id: String = SHOP[i][0]
		var have: bool = d.upgrades.has(id)
		var it: float = install.get(id, -1.0)
		var k := 1.0
		var off := Vector2.ZERO
		if it >= 0.0:
			# being fitted: it comes down onto its mount and settles
			var e := Pal.back(clampf((it - 0.15) / 0.5, 0.0, 1.0), 2.2)
			off = Vector2(0, -46.0 * (1.0 - e))
			k = clampf((it - 0.15) / 0.2, 0.0, 1.0)
			if it > 0.55 and it < 1.3:
				var re := Pal.ease_out((it - 0.55) / 0.75)
				draw_arc(_anchor(i), 14.0 + 70.0 * re, 0.0, TAU, 40, Pal.heat((1.0 - re) * a, 2.0), 2.0, true)
		_part(i, have, k * a, off)
		# the chosen one breathes
		if i == sel:
			var p := _anchor(i)
			draw_arc(p, 22.0 + 3.0 * sin(t * 4.0), 0.0, TAU, 32, Pal.heat(0.75 * a, 1.3), 1.6, true)


func _part(i: int, have: bool, a: float, off: Vector2) -> void:
	var col := Pal.ink(0.95 * a) if have else Pal.ink(0.35 * a)
	var w := 2.0 if have else 1.2
	var c := _drone_c()
	match i:
		0:
			# the inspection head: a dish on a mast above the drone
			var top := c + Vector2(0, -Drone.R * DK) + off
			_line(top, top + Vector2(0, -28), col, w, have)
			_arc(top + Vector2(0, -32), 20.0, PI * 1.1, PI * 1.9, col, w, have)
			draw_circle(top + Vector2(0, -44), 5.0, Pal.tint(Pal.AIR, (0.9 if have else 0.3) * a, 1.3))
		1:
			# the tractor emitter: a heavy ring round the lens and two coil blocks
			var cc := c + off
			_arc(cc, 12.5 * DK, 0.0, TAU, col, w + 1.0, have)
			for sd in [-1.0, 1.0]:
				var q: Vector2 = cc + Vector2.from_angle(PI * 0.75 + sd * 0.9) * 13.0 * DK
				_rect(Rect2(q - Vector2(12, 12), Vector2(24, 24)), col, w, have)
		2:
			# the high-flow pump: a second, bigger housing with an impeller ring
			var p := _anchor(2) + Vector2(30, 0) + off
			_rect(Rect2(p + Vector2(-6, -18), Vector2(44, 44)), col, w, have)
			_arc(p + Vector2(16, 4), 14.0, 0.0, TAU, col, w, have)
		3:
			# the recovery arm: a trolley on the boom, a cable and a claw
			var p2 := _anchor(3) + off
			_rect(Rect2(p2 + Vector2(-40, -14), Vector2(80, 26)), col, w, have)
			_line(p2 + Vector2(0, 12), p2 + Vector2(0, 110), col, w, have)
			for sd in [-1.0, 1.0]:
				_line(p2 + Vector2(0, 110), p2 + Vector2(sd * 16, 128), col, w, have)
				_line(p2 + Vector2(sd * 16, 128), p2 + Vector2(sd * 8, 144), col, w, have)


func _line(a0: Vector2, b0: Vector2, col: Color, w: float, solid: bool) -> void:
	if solid:
		draw_line(a0, b0, col, w, true)
	else:
		draw_dashed_line(a0, b0, col, w, 6.0)


func _arc(c: Vector2, r: float, from: float, to: float, col: Color, w: float, solid: bool) -> void:
	if solid:
		draw_arc(c, r, from, to, 40, col, w, true)
		return
	var n := maxi(6, int(r * absf(to - from) / 10.0))
	for i in n:
		if i % 2 == 0:
			draw_arc(c, r, lerpf(from, to, float(i) / n), lerpf(from, to, float(i + 1) / n), 4, col, w, true)


func _rect(r: Rect2, col: Color, w: float, solid: bool) -> void:
	if solid:
		draw_rect(r, col, false, w)
		return
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(p[i], p[(i + 1) % 4], col, w, 6.0)


# an upgrade's label on the drawing, joined to its part
func _callout_box(i: int, a: float) -> void:
	var it: Array = SHOP[i]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x
	var sk: float = sel_k[i].x
	var have: bool = Career.data.upgrades.has(it[0])
	var k := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.05) / 0.3, 0.0, 1.0)) * a
	r.position.x += (1.0 - k) * (-30.0 if r.position.x < size.x * 0.3 else 30.0)
	var p := _anchor(i)
	var edge := Vector2(r.end.x if p.x > r.end.x else r.position.x, r.get_center().y)
	draw_line(edge, p, Pal.ink((0.25 + 0.45 * maxf(hk, sk)) * k), 1.0, true)
	draw_circle(p, 4.0, Pal.heat(k, 1.3) if sk > 0.5 else Pal.ink(0.7 * k))
	UI.panel(self, r, k, sk)
	_text(Txt.t(it[3]), r.position + Vector2(18, 28), 16, Pal.ink(0.95 * k), font_b)
	var right: String
	var col := Pal.ink(0.75 * k)
	if have:
		right = "✓ " + Txt.t("tm_installed")
		col = Pal.tint(Pal.FLUID, 0.85 * k, 1.1)
	else:
		right = Pal.money(it[2])
		if float(Career.data.money) < float(it[2]):
			col = Pal.ink(0.4 * k)
	_text(right, r.position + Vector2(18, 52), 15, col, font_b)
	if not have and float(Career.data.money) < float(it[2]):
		_text(Txt.t("tm_short_n") % Pal.money(float(it[2]) - float(Career.data.money)), Vector2(r.end.x - 14, r.position.y + 52), 13, Pal.heat(0.75 * k, 1.0), font, 1)


# a consumable: a cell with its mark, how many are in stock, and the price
func _cell(i: int, a: float) -> void:
	var it: Array = SHOP[i]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x
	var sk: float = sel_k[i].x
	var k := Pal.ease_out(clampf((deal_t - 0.2 - (i - FITTED) * 0.05) / 0.3, 0.0, 1.0)) * a
	r.position.y += (1.0 - k) * 24.0 - hk * 4.0
	UI.panel(self, r, k, sk)
	var n := int(Career.data.items.get(it[0], 0))
	_icon(it[0], r.position + Vector2(36, 42), k)
	_text("×%d" % n, Vector2(r.end.x - 16, r.position.y + 50), 28, Pal.ink((0.95 if n > 0 else 0.35) * k), font_l, 1)
	_text(Txt.t(it[3]), r.position + Vector2(16, r.size.y - 44), 15, Pal.ink(0.9 * k), font_b)
	var afford := float(Career.data.money) >= float(it[2])
	_text(Pal.money(it[2]), r.position + Vector2(16, r.size.y - 18), 14, Pal.ink((0.7 if afford else 0.35) * k), font)
	if sweep.has(i):
		_sweep(r, sweep[i])


func _icon(id: String, p: Vector2, a: float) -> void:
	var col := Pal.ink(0.85 * a)
	match id:
		"repair":
			draw_rect(Rect2(p + Vector2(-16, -5), Vector2(32, 10)), col, false, 1.6)
			draw_rect(Rect2(p + Vector2(-5, -16), Vector2(10, 32)), col, false, 1.6)
		"ring":
			draw_arc(p, 15.0, 0.0, TAU, 32, col, 1.8, true)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				draw_line(p + d * 15.0, p + d * 21.0, Pal.heat(0.9 * a, 1.2), 2.0)
		"spare":
			var pts := PackedVector2Array()
			for k in 9:
				pts.append(p + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * 17.0)
			draw_polyline(pts, col, 1.8, true)
			draw_circle(p, 5.0, col)
		"intel":
			draw_rect(Rect2(p + Vector2(-13, -18), Vector2(26, 36)), col, false, 1.6)
			for k in 4:
				draw_line(p + Vector2(-8, -10 + k * 7), p + Vector2(8 - (k % 2) * 6, -10 + k * 7), Pal.tint(Pal.AIR, 0.9 * a, 1.1), 1.4)


func _sweep(r: Rect2, sw: float) -> void:
	var sx := r.position.x + r.size.x * Pal.ease_out(clampf(sw / 0.5, 0.0, 1.0))
	var fade := 1.0 - clampf((sw - 0.3) / 0.5, 0.0, 1.0)
	draw_rect(Rect2(r.position.x, r.position.y, sx - r.position.x, r.size.y), Color(1, 1, 1, 0.05 * fade))
	draw_rect(Rect2(sx - 2, r.position.y, 2, r.size.y), Pal.heat(fade, 2.0))


# the chosen thing: what it changes, now → after, how you would play differently,
# and the money: price, what is left after, and what the next contract fee would borrow
func _detail(a: float) -> void:
	var r := _detail_rect()
	if sel < 0 or sel >= SHOP.size():
		return
	var it: Array = SHOP[sel]
	var id: String = it[0]
	var d := Career.data
	var ka := Pal.ease_out(clampf((deal_t - 0.12) / 0.35, 0.0, 1.0)) * a
	UI.panel(self, r, ka, 1.0)
	var x := r.position.x + 32
	var w := r.size.x - 64
	var y := r.position.y + 40
	var kind := "tm_kind_it" if it[1] == "item" else ("tm_kind_fa" if it[1] == "facility" else "tm_kind_up")
	_text(Txt.t(kind), Vector2(x, y), 14, Pal.tint(Pal.AIR, 0.85 * ka, 1.0), font)
	_text(Txt.t(it[3]), Vector2(x, y + 42), 30, Pal.ink(0.96 * ka), font_l)
	_wrap(Txt.t(it[4]), Vector2(x, y + 78), w, 16, Pal.ink(0.75 * ka))
	y += 126
	var have: bool = it[1] != "item" and d.upgrades.has(id)
	if it[1] != "item":
		var rows: Array = STATS.get(id, [])
		var grow := Pal.ease_out(clampf((deal_t - 0.3) / 0.6, 0.0, 1.0))
		for row in rows:
			var nv: String = Txt.t(row[1]) if str(row[1]).begins_with("sh_") else row[1]
			var av: String = Txt.t(row[2]) if str(row[2]).begins_with("sh_") else row[2]
			UI.compare(self, font, Rect2(x, y, w, 36), Txt.t(row[0]), nv, av, row[3], row[4] if not have else row[4], ka, 1.0 if have else grow)
			y += 50
		y += 10
		_text(Txt.t("tm_strategy"), Vector2(x, y + 4), 14, Pal.ink(0.55 * ka), font)
		_wrap(Txt.t("st_" + id), Vector2(x, y + 30), w, 18, Pal.ink(0.95 * ka))
	else:
		var n := int(d.items.get(id, 0))
		_text(Txt.t("tm_stock_n") % n, Vector2(x, y + 4), 18, Pal.ink(0.9 * ka), font_b)
		var how: String = Txt.t("tm_use_auto") if id == "spare" else (Txt.t("tm_use_intel_at") if id == "intel" else Txt.t("tm_use") % USE_KEY[id])
		_text(how, Vector2(x, y + 34), 15, Pal.ink(0.65 * ka), font)
	# the money
	if have:
		_text("✓ " + Txt.t("tm_installed"), Vector2(x, r.end.y - 130), 20, Pal.tint(Pal.FLUID, 0.9 * ka, 1.1), font_b)
		return
	var n2 := qty if it[1] == "item" else 1
	var price: float = float(it[2]) * n2
	var after := float(d.money) - price
	var my := r.end.y - (300.0 if it[1] == "item" else 236.0)
	if it[1] == "item":
		_text(Txt.t("tm_qty"), Vector2(x, r.end.y - 186), 14, Pal.ink(0.55 * ka), font)
		for sgn in [-1, 1]:
			var qr := _qty_rect(sgn)
			var hv: bool = hover_minus if sgn < 0 else hover_plus
			UI.panel(self, qr, ka, 1.0 if hv else 0.0)
			_text("−" if sgn < 0 else "+", qr.get_center() + Vector2(0, 9), 24, Pal.ink(0.9 * ka), font_b, 0)
		_text(str(qty), Vector2(_qty_rect(-1).end.x + 51, r.end.y - 142), 26, Pal.ink(0.95 * ka), font_b, 0)
	draw_line(Vector2(x, my - 22), Vector2(x + w, my - 22), Pal.ink(0.1 * ka), 1.0)
	_text(Txt.t("tm_price"), Vector2(x, my), 15, Pal.ink(0.6 * ka), font)
	_text(Pal.money(price), Vector2(x + w, my), 18, Pal.ink(0.95 * ka), font_b, 1)
	_text(Txt.t("tm_after"), Vector2(x, my + 30), 15, Pal.ink(0.6 * ka), font)
	_text(Pal.money(after), Vector2(x + w, my + 30), 18, (Pal.heat(0.95 * ka, 1.2) if after < 0.0 else Pal.ink(0.95 * ka)), font_b, 1)
	if after >= 0.0:
		var fee := _cheapest_fee()
		if fee > 0.0:
			if after < fee:
				_wrap(Txt.t("tm_next_fee") % [Pal.money(fee), Pal.money(fee - after)], Vector2(x, my + 58), w, 14, Pal.heat(0.9 * ka, 1.1))
			else:
				_text(Txt.t("tm_next_ok") % Pal.money(fee), Vector2(x, my + 60), 14, Pal.ink(0.5 * ka), font)


func _cheapest_fee() -> float:
	var f := 0.0
	for o in offers():
		if f == 0.0 or float(o.fee) < f:
			f = float(o.fee)
	return f


# ---------------------------------------------------------------- berth management

func _berth(s: Vector2, a: float) -> void:
	var d := Career.data
	var fr := _finance_rect()
	var k0 := Pal.ease_out(clampf((deal_t - 0.04) / 0.35, 0.0, 1.0)) * a
	UI.panel(self, fr, k0, sel_k[0].x)
	var x := fr.position.x + 36
	var w := fr.size.x - 72
	_text(Txt.t("tm_fin"), Vector2(x, fr.position.y + 50), 26, Pal.ink(0.95 * k0), font_l)
	var loan := float(d.loan)
	var amt := minf(repay_amt, _repay_max())
	var loan2 := loan - amt
	var rows := [
		[Txt.t("tm_fin_loan"), loan, loan2],
		[Txt.t("tm_fin_inst"), minf(Career.INSTALLMENT, loan), minf(Career.INSTALLMENT, loan2)],
		[Txt.t("tm_fin_int"), snappedf(loan * Career.INTEREST, 1.0), snappedf(loan2 * Career.INTEREST, 1.0)],
		[Txt.t("tm_fin_due"), minf(Career.INSTALLMENT, loan) + snappedf(loan * Career.INTEREST, 1.0), minf(Career.INSTALLMENT, loan2) + snappedf(loan2 * Career.INTEREST, 1.0)],
		[Txt.t("tm_fin_funds"), float(d.money), float(d.money) - amt],
	]
	# the slider: how much to pay now
	var sl := _slider_rect()
	_text(Txt.t("tm_fin_amt"), Vector2(x, sl.position.y - 26), 15, Pal.ink(0.6 * k0), font)
	_text(Pal.money(amt), Vector2(sl.end.x, sl.position.y - 22), 26, Pal.ink(0.96 * k0), font_b, 1)
	draw_rect(sl, Pal.ink(0.1 * k0))
	var mx := _repay_max()
	var f := amt / mx if mx > 0.0 else 0.0
	draw_rect(Rect2(sl.position, Vector2(sl.size.x * f, sl.size.y)), Pal.heat(0.9 * k0, 1.1))
	var kn := Vector2(sl.position.x + sl.size.x * f, sl.get_center().y)
	draw_circle(kn, 11.0 if dragging else 9.0, Pal.ink(0.95 * k0))
	draw_circle(kn, 4.0, Pal.heat(k0, 1.3))
	_text("$0", Vector2(sl.position.x, sl.end.y + 26), 13, Pal.ink(0.45 * k0), font)
	_text(Pal.money(mx), Vector2(sl.end.x, sl.end.y + 26), 13, Pal.ink(0.45 * k0), font, 1)
	# now → after the payment
	var y := sl.end.y + 120
	_text(Txt.t("tm_fin_after"), Vector2(x + w, y - 40), 13, Pal.ink(0.5 * k0), font, 1)
	for i in rows.size():
		var yy := y + i * 36
		var rk := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.04) / 0.3, 0.0, 1.0)) * k0
		_text(rows[i][0], Vector2(x, yy), 16, Pal.ink(0.65 * rk), font)
		var changed: bool = absf(float(rows[i][1]) - float(rows[i][2])) > 0.5
		_text(Pal.money(rows[i][1]), Vector2(x + w - 230, yy), 17, Pal.ink((0.55 if changed else 0.9) * rk), font_b, 1)
		if changed:
			_text("→", Vector2(x + w - 200, yy), 16, Pal.ink(0.45 * rk), font)
			_text(Pal.money(rows[i][2]), Vector2(x + w, yy), 17, Pal.ink(0.95 * rk) if i != 4 else Pal.heat(0.9 * rk, 1.1), font_b, 1)
		draw_line(Vector2(x, yy + 12), Vector2(x + w, yy + 12), Pal.ink(0.05 * rk), 1.0)
	if loan <= 0.0:
		_text(Txt.t("tm_paid_off"), Vector2(x, fr.end.y - 130), 18, Pal.tint(Pal.FLUID, 0.9 * k0, 1.1), font_b)
	# training, and what opens later
	var tr := _training_rect()
	var k1 := Pal.ease_out(clampf((deal_t - 0.1) / 0.35, 0.0, 1.0)) * a
	UI.panel(self, tr, k1, sel_k[1].x)
	_text(Txt.t("tm_training"), tr.position + Vector2(32, 50), 24, Pal.ink(0.95 * k1), font_l)
	_wrap(Txt.t("tm_training_d"), tr.position + Vector2(32, 84), tr.size.x - 64, 15, Pal.ink(0.65 * k1))
	# the facilities: bought once, kept
	var d2 := Career.data
	_text(Txt.t("tm_facilities"), Vector2(tr.position.x, tr.end.y + 36), 15, Pal.ink(0.6 * k1), font_b)
	for j in 3:
		var it: Array = BERTH[2 + j]
		var fcr := _facility_rect(j)
		var fk := Pal.ease_out(clampf((deal_t - 0.14 - j * 0.05) / 0.35, 0.0, 1.0)) * a
		UI.panel(self, fcr, fk, sel_k[2 + j].x)
		_text(Txt.t(it[3]), fcr.position + Vector2(24, 34), 17, Pal.ink(0.95 * fk), font_b)
		_text(Txt.t(it[4]), fcr.position + Vector2(24, 62), 13, Pal.ink(0.6 * fk), font)
		if sel != 2 + j:
			var have: bool = d2.upgrades.has(it[0])
			_text("✓ " + Txt.t("tm_installed") if have else Pal.money(it[2]), Vector2(fcr.end.x - 24, fcr.position.y + 52), 17, Pal.tint(Pal.FLUID, 0.85 * fk, 1.1) if have else Pal.ink((0.9 if float(d2.money) >= float(it[2]) else 0.45) * fk), font_b, 1)
	var lr := Rect2(tr.position.x, _facility_rect(2).end.y + 20, tr.size.x, 96)
	var k2 := Pal.ease_out(clampf((deal_t - 0.16) / 0.35, 0.0, 1.0)) * a
	UI.panel(self, lr, k2 * 0.6)
	_text(Txt.t("tm_later_h"), lr.position + Vector2(32, 40), 14, Pal.ink(0.5 * k2), font)
	var names: Array = []
	for n in LATER:
		names.append(Txt.t(n))
	_wrap("  ·  ".join(names), lr.position + Vector2(32, 72), lr.size.x - 64, 15, Pal.ink(0.5 * k2))


# ---------------------------------------------------------------- the button, the keys, the messages

func _bottom(s: Vector2, a: float) -> void:
	var r := _go_rect()
	var label := ""
	var note := ""
	var ok := true
	var d := Career.data
	match tab:
		0:
			label = Txt.t("tm_take") + "   Enter"
			var o: Dictionary = offers()[sel] if sel < offers().size() else {}
			if o.is_empty():
				return
			if not o.has("intel") and int(d.items.get("intel", 0)) > 0:
				_text(Txt.t("tm_use_intel") % int(d.items.intel), Vector2(60, s.y - 84), 14, Pal.tint(Pal.AIR, 0.85 * a, 1.0), font)
			if float(d.money) < float(o.fee):
				note = Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(d.money))
		1:
			var it: Array = SHOP[sel] if sel < SHOP.size() else []
			if it.is_empty():
				return
			var price: float = float(it[2]) * (qty if it[1] == "item" else 1)
			if it[1] != "item" and d.upgrades.has(it[0]):
				label = "✓ " + Txt.t("tm_installed")
				ok = false
			elif float(d.money) < price:
				label = Txt.t("tm_buy_n") % Pal.money(price)
				note = Txt.t("tm_short_n") % Pal.money(price - float(d.money))
				ok = false
			else:
				label = Txt.t("tm_buy_n") % Pal.money(price) + "   Enter"
		_:
			if sel == 0:
				var amt := minf(repay_amt, _repay_max())
				ok = amt > 0.0
				label = Txt.t("tm_repay_n") % Pal.money(amt) + ("   Enter" if ok else "")
				if not ok:
					note = Txt.t("tm_repay_none")
			elif sel == 1:
				label = Txt.t("tm_training_btn") + "   Enter"
			else:
				var fit: Array = BERTH[sel]
				if d.upgrades.has(fit[0]):
					label = "✓ " + Txt.t("tm_installed")
					ok = false
				elif float(d.money) < float(fit[2]):
					label = Pal.money(fit[2])
					note = Txt.t("tm_short_n") % Pal.money(float(fit[2]) - float(d.money))
					ok = false
				else:
					label = Txt.t("tm_buy_n") % Pal.money(fit[2])
	var bk := Pal.back(clampf((t - 0.3) / 0.35, 0.0, 1.0), 2.0)
	r = Rect2(r.position + Vector2(0, (1.0 - bk) * 20.0), r.size)
	UI.button(self, font_b, r, label, 1.0 if hover_go else 0.0, ok, a, t, shake, note)
	_text(Txt.t("tm_keys"), Vector2(60, s.y - 34), 13, Pal.ink(0.45 * a), font)
	if msg != "" and msg_t < 3.0:
		var mk := clampf((3.0 - msg_t) / 0.4, 0.0, 1.0) * Pal.ease_out(clampf(msg_t / 0.2, 0.0, 1.0))
		_text(msg, Vector2(60 + (1.0 - Pal.ease_out(clampf(msg_t / 0.25, 0.0, 1.0))) * 20.0, s.y - 60), 17, Pal.ink(0.95 * a * mk), font_b)
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
	var g := Pal.ease_io(clampf(leaving / 0.4, 0.0, 1.0))
	var full := Rect2(Vector2.ZERO, s)
	var r := Rect2(leave_from.position.lerp(full.position, g), leave_from.size.lerp(full.size, g))
	draw_rect(r, Color(0.03, 0.032, 0.037, 1.0))
	draw_rect(r, Pal.ink(0.6 * (1.0 - g)), false, 1.2)
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.heat(1.0 - g, 1.2))
	if not leave_offer.is_empty():
		var tw := r.size.x * 0.8
		_thumb(leave_offer, Rect2(r.get_center() - Vector2(tw * 0.5, tw * 0.11), Vector2(tw, tw * 0.22)), clampf(leaving / 0.15, 0.0, 1.0))
	var c := clampf((leaving - 0.52) / 0.24, 0.0, 1.0)
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
