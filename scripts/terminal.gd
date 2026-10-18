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
# Keys: 1 2 3 4 tabs, ← → pick, ↑ ↓ quantity / amount, Enter take/buy, Esc title.

const TABS := ["market", "shop", "berth", "skills"]
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
	["berth88", "facility", 240000.0, "fa_berth", "fa_berth_d", true],
	["hauler2", "facility", 60000.0, "fa_hauler2", "fa_hauler2_d", true],
	["crane", "facility", 150000.0, "fa_crane", "fa_crane_d", true],
	["port2", "facility", 50000.0, "fa_port2", "fa_port2_d", true],
	["buffer", "facility", 30000.0, "fa_buffer", "fa_buffer_d", true],
	["zones", "facility", 20000.0, "fa_zones", "fa_zones_d", true],
]
# a facility that only makes sense with another one bought first
const REQUIRES := {"hauler2": "hauler"}
# what berth management will offer later, named in one line
const LATER := ["fa_scan"]
const REPAY_STEP := 5000.0

var font: Font
var font_l: Font
var font_b: Font
var font_s: Font
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
# the self-test each time the terminal comes up (P.7, ~2 s; any key or click skips it)
const BOOT_T := 2.0
var boot_t := 0.0
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
# opened on site from one of the berth's two consoles (game.open_console): only the
# shop and berth pages, Esc closes it and play goes on; what is bought there
# counts from the next contract
var overlay := false
var on_close: Callable
var on_skill_changed: Callable
var book: SkillBook
var next_job := {}         # an opening contract still to play: the market shows it, alone
var _wiping := false       # the transition out has been asked for
# a key's travel: the button or rocker last pressed sinks for a moment
var press_t := 0.0
var tab_press := -1
# the console's own sounds: keys, stamps, refusals, the self-test
var sfx: Sfx
var _last_sel := -1
var _boot_said := 0


func _ready() -> void:
	testing = _is_test()
	if not testing:
		Txt.load_settings(false)
	Career.load_or_new()
	Career.ensure_offers(Market.make)
	next_job = Career.active() if not overlay and not Career.data.get("market", false) else {}
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	font_s = Fonts.get_font("SemiBold")
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
	for i in 16:
		hover_k.append(Motion.Spring.new(0.0, 380.0, 0.7))
		sel_k.append(Motion.Spring.new(0.0, 300.0, 0.8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.apply(get_viewport())
	book = SkillBook.new()
	book.visible = tab == 3
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.offset_top = 198
	book.offset_bottom = -70
	book.changed = func():
		if on_skill_changed.is_valid():
			on_skill_changed.call()
	add_child(book)
	settings = SettingsPanel.new()
	settings.testing = testing
	add_child(settings)
	sfx = Sfx.new()
	add_child(sfx)
	# on site (the left computers), with animation off, and under the tests' stills: up at once
	if overlay or Txt.anim_level() == 0 or testing:
		boot_t = BOOT_T
	if overlay:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_tab(maxi(tab, 1))
		say(Txt.t("tm_onsite_note"))
		return
	var dev := DevPanel.new()
	dev.terminal = self
	dev.where = "terminal"
	add_child(dev)
	# the first time the market opens (after the tug), the terminal says so; Liang's
	# lines for it wait for the opening to be through (written for after the Heron)
	var seen: Dictionary = Career.data.get("seen", {})
	if Career.data.get("market", false) and not seen.has("market"):
		seen["market"] = true
		Career.data.seen = seen
		Career.save()
		Copy.say(radio, "T_market_open", "term")
	if Career.data.get("market", false) and not seen.has("market_liang") and Career.story_job().is_empty() and Career.active().is_empty():
		seen["market_liang"] = true
		Career.data.seen = seen
		Career.save()
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


# the first time a debt from a botched job is cleared (at a settlement, or paid off here), once
# straight to ready: the self-test cut short, the cards already dealt
func _skip_boot() -> void:
	boot_t = BOOT_T
	deal_t = maxf(deal_t, 2.0)


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


# what the market shows: the pinned story contract first (when there is one),
# then the offers, three cards in all
func offers() -> Array:
	var os: Array = Career.data.get("offers", [])
	var sj: Dictionary = Career.story_job()
	if sj.is_empty() or overlay:
		return os
	var card := sj.duplicate(true)
	card.story_card = true
	return [card] + os.slice(0, 2)


# a shown card's place in the career's own offers (-1 for the story card)
func _offer_index(i: int) -> int:
	return i - 1 if not Career.story_job().is_empty() and not overlay else i


func items() -> Array:
	return [] if tab == 3 else (offers() if tab == 0 else (SHOP if tab == 1 else BERTH))


# ---------------------------------------------------------------- input

func _process(dt: float) -> void:
	t += dt
	msg_t += dt
	deal_t += dt
	press_t = maxf(0.0, press_t - dt)
	if press_t <= 0.0:
		tab_press = -1
	if sel != _last_sel:
		if _last_sel >= 0 and boot_t >= BOOT_T:
			sfx.play("menu", Vector2.INF, 0.45)
		_last_sel = sel
	# the self-test's two sounds: power on, ready
	if _boot_said == 0 and boot_t > 0.02 and boot_t < BOOT_T:
		_boot_said = 1
		sfx.play("term", Vector2.INF, 0.7)
	elif _boot_said == 1 and boot_t >= 1.5:
		_boot_said = 2
		sfx.play("ok", Vector2.INF, 0.6)
	# the self-test: it only runs once the transition has opened the screen,
	# and the cards are dealt as it brings the content up
	if not Wipe.busy() and boot_t < BOOT_T:
		boot_t += dt
	if boot_t < 0.85:
		deal_t = 0.0
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
	for i in TABS.size():
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
		# the card flies off, then the transition takes it over
		if leaving > 0.36 and not _wiping:
			_wiping = true
			var tree := get_tree()
			Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/main.tscn"))
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if settings.is_open or leaving >= 0.0:
		return
	if boot_t < BOOT_T and ev is InputEventMouseButton and ev.pressed:
		_skip_boot()
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
	if DevPanel.workbench_open and Txt.dev:
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or leaving >= 0.0:
		return
	if boot_t < BOOT_T and not overlay:
		_skip_boot()
		get_viewport().set_input_as_handled()
		return
	if overlay:
		get_viewport().set_input_as_handled()
	if milestone >= 0.0:
		if milestone > 1.5:
			milestone = -1.0
		return
	match ev.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
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
			if overlay:
				close()
			elif not _wiping:
				_wiping = true
				var tree := get_tree()
				Wipe.go(tree, func(): tree.change_scene_to_file("res://scenes/title.tscn"))
		KEY_O:
			settings.open()


# the on-site console closes: back to the berth
func close() -> void:
	Career.save()
	if on_close.is_valid():
		on_close.call()
	queue_free()


func set_tab(i: int) -> void:
	# on site the market is not open: contracts are signed between jobs
	var lo := 1 if overlay else 0
	tab_press = clampi(i, lo, 3)
	press_t = 0.16
	if clampi(i, lo, 3) != tab:
		sfx.play("switch", Vector2.INF, 0.8)
	if clampi(i, lo, 3) != tab:
		deal_t = 0.0
	tab = clampi(i, lo, 3)
	if book != null:
		book.visible = tab == 3
		if tab == 3:
			var goal := Growth.find_track(str(Career.data.get("growth_goal", "")))
			if not goal.is_empty():
				book.selected = goal[0]
			book.refresh()
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
	if tab == 0 and (not offers().is_empty() or not next_job.is_empty()):
		go_x.target = _item_rect(clampi(sel, 0, maxi(0, offers().size() - 1))).position.x
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
	if tab == 3:
		return
	press_t = 0.16
	if tab == 0 and not next_job.is_empty():
		start_next()
	elif tab == 0:
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
	if offers()[i].get("story_card", false):
		# the story contract: played as the opening contract it is
		var a: Dictionary = Career.take_story()
		if a.is_empty():
			return
		Game.contract = a
		Game.start_ship = a.get("ship", "gr7")
		SaveGame.load_requested = false
		sfx.play("stamp", Vector2.INF, 1.0)
		leaving = 0.0
		return
	var o: Dictionary = Career.accept(_offer_index(i))
	if o.is_empty():
		return
	Game.start_ship = o.ship
	Game.contract = o
	Copy.say(radio, "T_contract_signed", "term")
	SaveGame.load_requested = false
	sfx.play("stamp", Vector2.INF, 1.0)
	leaving = 0.0


# the next opening contract: towed in from here, with what the berth owns now
func start_next() -> void:
	if next_job.is_empty() or leaving >= 0.0:
		return
	leave_from = _item_rect(0)
	leave_offer = {}
	var a: Dictionary = Career.sign_active()
	Game.contract = a
	Game.start_ship = a.get("ship", "gr7")
	var saved := SaveGame.read(SaveGame.path) if SaveGame.exists() else {}
	SaveGame.load_requested = not saved.is_empty() and saved.get("job", a).get("id", "") == a.get("id", "")
	sfx.play("stamp", Vector2.INF, 1.0)
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
	if overlay and it[1] in ["training"]:
		_refuse(Txt.t("tm_onsite_no"))
		return
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
	if REQUIRES.has(id) and not d.upgrades.has(REQUIRES[id]):
		_refuse(Txt.t("tm_needs") % Txt.t(_facility_name(REQUIRES[id])))
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
		var seen: Dictionary = d.get("seen", {})
		seen["bought"] = true
		d.seen = seen
		Copy.say(radio, "L_first_upgrade")
	Career.save()
	flash = 1.0
	_buy_fx(sel)
	say(Txt.t("tm_bought") % (Txt.t(it[3]) + (" ×%d" % n if n > 1 else "")))


# it could not be done: the button jolts, the funds flash, and it says why
func _refuse(why: String) -> void:
	shake = 1.0
	sfx.play("deny", Vector2.INF, 0.8)
	money_flash = -1.0
	say(why)


# a purchase: a bright pass along the row, and lights leaving the funds for it
func _buy_fx(i: int) -> void:
	sfx.play("stamp", Vector2.INF, 0.9)
	sweep[i] = 0.0
	var r := _item_rect(i) if tab == 1 else _go_rect()
	for k in 14:
		sparks.append([_money_at() + Vector2(randf_range(-60, 20), randf_range(-8, 8)), Vector2(r.position.x + randf() * r.size.x, r.get_center().y + randf_range(-10, 10)), 0.0, k * 0.025])


# ---------------------------------------------------------------- layout

func _tab_rect(i: int) -> Rect2:
	return Rect2(60 + i * 244, 132, 230, 50)


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


# the facilities in two columns under the training panel
func _facility_rect(j: int) -> Rect2:
	var tr := _training_rect()
	var w := (tr.size.x - 16.0) * 0.5
	return Rect2(tr.position.x + (j % 2) * (w + 16.0), tr.end.y + 52 + (j / 2) * 82, w, 74)


func _facility_name(id: String) -> String:
	for b in BERTH:
		if b[0] == id:
			return b[3]
	return id


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
const DArt = preload("res://scripts/drone_art.gd")


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
	if tab == 3:
		return Rect2(-100, -100, 1, 1)
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
		return Rect2(fr.end.x - 150, fr.position.y + 14, 136, 46)
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
	var lv := clampf(leaving / 0.45, 0.0, 1.0) if leaving >= 0.0 else 0.0
	draw_rect(Rect2(Vector2.ZERO, s), Hmi.BG)
	# the self-test: the power line first, then each part as it comes up
	Hmi.lamp_test = boot_t > 0.55 and boot_t < 0.95
	if boot_t < 0.3:
		var e := Pal.ease_out(clampf(boot_t / 0.28, 0.0, 1.0))
		draw_rect(Rect2(s.x * 0.5 * (1.0 - e), s.y * 0.5 - 1, s.x * e, 2), Pal.heat(1.0, 2.6))
		_self_test(s)
		return
	_backdrop(s, 1.0)
	var ua := 1.0 - Pal.ease_in(lv)
	_top(s, ua)
	_tabs(ua)
	match tab:
		0:
			_market(s, ua)
		1:
			_shop(s, ua)
		2:
			_berth(s, ua)
	_bottom(s, ua * _bk(1.45, 1.8))
	_sparks()
	_radio(s, ua)
	if leaving >= 0.0:
		_leave(s, lv)
	if milestone >= 0.0:
		_milestone(s)
	_self_test(s)
	Hmi.lamp_test = false


# how far one part of the self-test has come (0 dark, 1 up), between two moments of it
func _bk(a0: float, a1: float) -> float:
	return Pal.ease_out(clampf((boot_t - a0) / maxf(a1 - a0, 0.001), 0.0, 1.0))


# the self-test's log, typed in at the lower left while the terminal comes up
func _self_test(s: Vector2) -> void:
	if boot_t >= BOOT_T:
		return
	# typed while the frame comes up, gone as the cards are dealt
	var fade := clampf((1.05 - boot_t) / 0.2, 0.0, 1.0)
	if fade <= 0.0:
		return
	var lines := [Txt.t("tm_st_0"), Txt.t("tm_st_1"), Txt.t("tm_st_2"), Txt.t("tm_st_3"), Txt.t("tm_st_4"), Txt.t("tm_st_5")]
	var y0 := s.y * 0.5 + 40.0 if boot_t < 0.3 else s.y - 300.0
	for i in lines.size():
		var start := 0.05 + i * 0.13
		var n := int(clampf((boot_t - start) / 0.12, 0.0, 1.0) * lines[i].length())
		if n <= 0:
			continue
		var col := Pal.tint(Pal.AIR, 0.9 * fade, 1.4) if i < lines.size() - 1 else Pal.tint(Pal.FLUID, fade, 1.8)
		_text(lines[i].substr(0, n), Vector2(60, y0 + i * 24), 16, col, font_b)


# the room the terminal sits in: a faint dot field drifting, a slow scan, dark corners
# the console the terminal sits in: plate seams, a slow scan
func _backdrop(s: Vector2, a: float) -> void:
	var gx := 0.0
	while gx < s.x:
		draw_line(Vector2(gx, 0), Vector2(gx, s.y), Color(1, 1, 1, 0.018 * a), 1.0)
		gx += 160.0
	var sy := fposmod(t * 70.0, s.y + 200.0) - 100.0
	draw_rect(Rect2(0, sy, s.x, 1), Pal.ink(0.02 * a))


func _tabs(a: float) -> void:
	for i in TABS.size():
		var r := _tab_rect(i)
		var on := tab == i
		var ka := a * _bk(0.55 + i * 0.05, 0.8 + i * 0.05)
		if ka <= 0.0:
			continue
		Hmi.rocker(self, font_s, r, "%d  %s" % [i + 1, Txt.t("tm_tab_" + TABS[i])], on, 1.0 if hover_tab == i else 0.0, ka, 1.0 if tab_press == i else 0.0)


func _top(s: Vector2, a: float) -> void:
	var d := Career.data
	var ka := a * _bk(0.25, 0.6)
	Hmi.raised(self, Rect2(0, 0, s.x, 116), ka, Hmi.HEAD)
	var company: String = str(Career.data.get("company", ""))
	var pr := Rect2(40, 22, 420, 72)
	Hmi.plate(self, font_s, pr, Txt.t("tm_title"), 28, ka)
	_text((company if company != "" else "BERTH 07") + "  ·  CHARON-DISPATCH", Vector2(pr.end.x + 24, 50), 14, Pal.ink(0.6 * ka), font_b)
	Hmi.lamp(self, Vector2(pr.end.x + 32, 76), Hmi.ok_col(), true, ka, 6.0)
	_text(Txt.t("tm_online"), Vector2(pr.end.x + 48, 82), 15, Pal.ink(0.75 * ka), font_b)
	var goal := Growth.find_track(str(d.get("growth_goal", "")))
	if not goal.is_empty():
		var id: String = goal[0]
		var reason := Growth.reason(id)
		var state := reason if reason != "" else Growth.text(["已攒够", "READY TO BUY"])
		_text(Growth.text(["目标：%s · %s · 按 4 查看", "GOAL: %s · %s · 4 TO VIEW"]) % [Growth.text(goal[2]), state], Vector2(pr.end.x + 24, 108), 13, Pal.ink(0.6 * ka), font)
	var loan_c := Pal.heat(1.0, 1.3) if float(d.loan) > 0.0 else Pal.ink(0.98)
	var mc := Pal.ink(0.98).lerp(Pal.ink(1.0, 1.5) if money_flash > 0.0 else Pal.heat(1.0, 1.4), absf(money_flash))
	var cols := [
		[Txt.t("tm_money"), Pal.money(money_roll.shown), mc, Hmi.ok_col()],
		[Txt.t("tm_loan"), Pal.money(loan_roll.shown), loan_c.lerp(Pal.ink(1.0, 1.5), maxf(0.0, -loan_flash)), Hmi.warn_col() if float(d.loan) > 0.0 else Hmi.ok_col()],
		[Txt.t("tm_due"), Pal.money(minf(Career.INSTALLMENT, float(d.loan)) + snappedf(float(d.loan) * Career.INTEREST, 1.0)), Pal.ink(0.9), Hmi.ok_col()],
		[Txt.t("tm_rep"), Txt.t("rep_" + Career.level()), Pal.ink(0.98), Hmi.ok_col()],
	]
	for i in cols.size():
		var r := Rect2(s.x - 40 - (cols.size() - i) * 296 + 16, 18, 280, 80)
		var ck := a * _bk(0.35 + i * 0.08, 0.7 + i * 0.08)
		if ck <= 0.0:
			continue
		Hmi.readout(self, font_s, font_b, r, cols[i][0], cols[i][1], cols[i][2], cols[i][3], ck)
	# reputation: how far to the next level, as a gauge under the level box
	var nx := Career.to_next()
	if nx > 0:
		var lo := 0
		var hi := 0
		for l in Career.LEVELS:
			if int(d.rep) >= int(l[1]):
				lo = int(l[1])
			elif hi == 0:
				hi = int(l[1])
		var pk := clampf(float(int(d.rep) - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
		var gk := a * _bk(0.7, 1.0)
		Hmi.gauge(self, Rect2(s.x - 40 - 296 + 16, 101, 280, 10), pk, Pal.heat(1.0, 1.3), gk, 12)
		_text(Txt.t("tm_rep_next") % nx, Vector2(s.x - 40, 126), 12, Pal.ink(0.5 * gk), font, 1)


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
	if not next_job.is_empty():
		_next_card(s, a)
		return
	var os := offers()
	if os.is_empty():
		_text(Txt.t("tm_none"), Vector2(s.x * 0.5, s.y * 0.45), 18, Pal.ink(0.6 * a), font, 0)
		return
	# what the cards are compared by: the net, and the net per minute of standard time
	var best_net := -1
	var best_rate := -1
	for i in os.size():
		if os[i].get("story_card", false):
			continue
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
		if o.get("story_card", false):
			_story_card(o, r, k, hk, sk)
			continue
		# dealt from below, lifted on hover; the chosen one framed in heat
		r.position.y += (1.0 - k) * 36.0 - hk * 6.0
		Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
		if sk > 0.02:
			draw_rect(r.grow(4.0), Pal.heat(sk * k, 1.4), false, 4.0)
		var x := r.position.x + 28
		var w := r.size.x - 56
		var y := r.position.y
		var row_k := func(n: int) -> float: return Pal.ease_out(clampf((deal_t - 0.15 - i * 0.07 - n * 0.035) / 0.3, 0.0, 1.0)) * a
		var ty: Dictionary = Market.type_of(o.ship)
		var scope: String = o.get("scope", "full")
		# 1 · the plate: what kind of job; its lamp heat for a part job
		var pl := Rect2(r.position.x + 18, y + 18, r.size.x - 36, 46)
		Hmi.plate(self, font_s, pl, Txt.t("sc_" + scope), 21, k)
		Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.warn_col() if scope != "full" else Hmi.ok_col(), true, k, 7.0)
		_text(Txt.t("tm_contract_n") % o.id, Vector2(pl.end.x - 44, pl.get_center().y + 6), 13, Pal.ink(0.5 * k), font, 1)
		_text("%s  ·  %s  ·  %d m" % [o.reg, (ty.name[0] if Txt.zh else ty.name[1]), int(ty.get("length", 0))], Vector2(x, y + 98), 18, Pal.ink(0.9 * row_k.call(0)), font_s)
		# 2 · the screen: the number to choose by, and the ship
		var sc := Rect2(r.position.x + 18, y + 116, r.size.x - 36, 248)
		var hk2: float = row_k.call(1)
		Hmi.screen(self, sc, hk2)
		var net := _net(o)
		var cnt := Pal.ease_out(clampf((deal_t - 0.2 - i * 0.07) / 0.7, 0.0, 1.0))
		_text(Txt.t("tm_net"), sc.position + Vector2(16, 30), 15, Pal.ink(0.6 * hk2), font_b)
		_text(Pal.money(snappedf(net * cnt, 100.0)), sc.position + Vector2(12, 104), 64, Pal.tint(Pal.AIR, hk2, 1.35) if net >= 0.0 else Pal.heat(0.95 * hk2, 1.3), font_l)
		_text(Txt.t("tm_per_min") % Pal.money(snappedf(_rate(o), 10.0)), Vector2(sc.end.x - 16, sc.position.y + 32), 17, Pal.ink(0.9 * hk2), font_s, 1)
		_text(Txt.t("tm_minutes") % int(float(o.time) / 60.0), Vector2(sc.end.x - 16, sc.position.y + 56), 14, Pal.ink(0.6 * hk2), font, 1)
		_thumb(o, Rect2(sc.position.x + 16, sc.position.y + 126, sc.size.x - 32, 108), row_k.call(2))
		# 3 · risk as a three-step gauge, and the best of the three said plainly
		var rk2: float = row_k.call(3)
		_text(Txt.t("tm_risk_h"), Vector2(x, y + 398), 15, Pal.ink(0.6 * rk2), font_b)
		Hmi.gauge(self, Rect2(x + 56, y + 382, 186, 22), float(o.stars) / 3.0, Pal.heat(1.0, 1.3), rk2, 3)
		_text(Txt.t("tm_risk_" + str(int(o.stars))), Vector2(x + 256, y + 399), 15, Pal.ink(0.8 * rk2), font_b)
		var badges: Array = []
		if i == best_net and os.size() > 1:
			badges.append(Txt.t("tm_best_net"))
		if i == best_rate and os.size() > 1:
			badges.append(Txt.t("tm_best_rate"))
		var bx := x + w
		for bdg in badges:
			var bw := font_s.get_string_size(bdg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
			bx -= bw
			draw_rect(Rect2(bx, y + 380, bw, 26), Pal.tint(Pal.FLUID, 0.9 * rk2, 1.0))
			_text(bdg, Vector2(bx + 9, y + 398), 14, Color(0.03, 0.05, 0.03, rk2), font_s)
			bx -= 8.0
		# 4 · what the job is, on the ship
		var task := Market.scope_text(o) if scope != "full" else Txt.t("tm_task_full")
		c_wrap(task, Vector2(x, y + 440), w, 15, Pal.ink(0.88 * row_k.call(3)))
		if Market.goal_text(o) != "":
			_text(Market.goal_text(o), Vector2(x, y + 486), 13, Pal.tint(Pal.FLUID, 0.9 * row_k.call(3), 1.1), font_b)
		# 5 · the money, line by line
		var due := Career.due_for(o)
		var lines := [
			[Txt.t("tm_value"), Pal.money(float(o.value))],
			[Txt.t("tm_fee"), "−" + Pal.money(float(o.fee))],
			[Txt.t("tm_due_c"), "−" + Pal.money(due)],
		]
		for jx in lines.size():
			var yy := y + 516 + jx * 28
			var jk: float = row_k.call(4 + jx)
			_text(lines[jx][0], Vector2(x, yy), 14, Pal.ink(0.6 * jk), font)
			_text(lines[jx][1], Vector2(r.end.x - 28, yy), 16, Pal.ink(0.92 * jk), font_s, 1)
		if float(Career.data.money) < float(o.fee):
			_text(Txt.t("tm_borrow") % Pal.money(float(o.fee) - float(Career.data.money)), Vector2(x, y + 588), 13, Pal.heat(0.9 * k, 1.1), font)
		# 6 · the paperwork: why it was scrapped, what the logs say, what is declared
		var pk: float = row_k.call(8)
		draw_line(Vector2(x, y + 596), Vector2(x + w, y + 596), Color(0, 0, 0, 0.5 * pk), 2.0)
		_text(Txt.t("tm_reason"), Vector2(x, y + 620), 13, Pal.ink(0.55 * pk), font)
		_text(Copy.slot(o.reason), Vector2(x + 96, y + 620), 14, Pal.ink(0.8 * pk), font)
		_text(Txt.t("tm_logs"), Vector2(x, y + 646), 13, Pal.ink(0.55 * pk), font)
		var ly := y + 646.0
		for li in mini(2, o.logs.size()):
			_text("› " + Copy.slot(o.logs[li]), Vector2(x + 96, ly), 14, Pal.tint(Pal.AIR, 0.85 * pk, 1.0), font)
			ly += 22.0
		var parts: Array = []
		for cg in o.get("cargo", []):
			parts.append("%s %s" % [cg[0], Txt.cargo(cg[1])])
		_text(Txt.t("tm_cargo") + "  " + ("  ·  ".join(parts) if not parts.is_empty() else Txt.t("tm_no_cargo")), Vector2(x, ly + 14), 13, Pal.ink(0.7 * pk), font)
		# a survey report bought for this offer: typed in behind a scan line, on its own screen
		if o.has("intel"):
			var it_t := intel_t.get(o.id, 9.0) as float
			var shown := intel_text(o).substr(0, int(it_t * 40.0))
			var ir := Rect2(r.position.x + 18, r.end.y - 70, r.size.x - 36, 52)
			Hmi.screen(self, ir, k)
			_text(Txt.t("tm_intel"), ir.position + Vector2(12, 20), 13, Pal.tint(Pal.AIR, 0.85 * k, 1.0), font)
			_text(shown, ir.position + Vector2(12, 42), 14, Pal.tint(Pal.AIR, 0.95 * k, 1.2), font)
			if it_t < 1.0:
				draw_rect(Rect2(ir.position.x + ir.size.x * it_t, ir.position.y, 2, ir.size.y), Pal.tint(Pal.AIR, (1.0 - it_t) * k, 2.0))
		else:
			_text(Txt.t("tm_logs_note"), Vector2(x, r.end.y - 18), 13, Pal.ink(0.45 * pk), font)



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
		# the ship's own outline: its structure, as the file draws it
		var outline: Array = []
		var y0 := 0.0
		var y1 := 0.0
		for pd in d.pieces:
			if pd.kind in ["hull", "hatch", "keel", "beam", "strut", "rail", "deck", "bulkhead"]:
				var pts := PackedVector2Array()
				for q in pd.poly:
					pts.append(Vector2(q[0], q[1]))
					y0 = minf(y0, q[1])
					y1 = maxf(y1, q[1])
				pts.append(pts[0])
				outline.append(pts)
		thumbs[o.id] = {"marks": marks, "len": float(d.get("length", 42.0)), "outline": outline, "h": maxf(8.0, y1 - y0 + 1.0), "mid": (y0 + y1) * 0.5,
			"sx": Variant.section_x(d)}
	var th: Dictionary = thumbs[o.id]
	var L: float = th.len
	var sc := minf(r.size.x / L, r.size.y / th.h)
	var org := Vector2(r.position.x + (r.size.x - L * sc) * 0.5, r.get_center().y - th.mid * sc)
	var SX: float = th.sx
	var P := func(v: Vector2) -> Vector2: return org + v * sc
	draw_rect(r, Color(0, 0, 0, 0.25 * a))
	# the part the contract buys, shaded
	match o.get("scope", "full"):
		"section":
			var hh: float = th.h * 0.5
			draw_rect(Rect2(P.call(Vector2(SX, th.mid - hh)), Vector2((L - SX) * sc, th.h * sc)), Pal.heat(0.16 * a, 1.0))
			draw_dashed_line(P.call(Vector2(SX, th.mid - hh)), P.call(Vector2(SX, th.mid + hh)), Pal.heat(0.9 * a, 1.2), 1.4, 5.0)
	for pts in th.outline:
		var sp := PackedVector2Array()
		for v in pts:
			sp.append(P.call(v))
		draw_polyline(sp, Pal.ink(0.45 * a), 1.0, true)
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
	# the drawing on its own screen, set in a panel with its plate
	var pr := Rect2(sr.position.x - 8, sr.position.y - 8, sr.size.x + 16, sr.size.y + 16)
	Hmi.raised(self, pr, ka)
	Hmi.screen(self, sr, ka, true)
	_schematic(sr, ka)
	for i in FITTED:
		_callout_box(i, ka)
	# how to read the lamps
	var ly := sr.position.y + 30
	var keys := [[Hmi.ok_col(), Txt.t("tm_lamp_have")], [Hmi.can_col(), Txt.t("tm_lamp_can")], [Hmi.warn_col(), Txt.t("tm_lamp_short")]]
	var lx := sr.get_center().x - 160
	for kk in keys:
		Hmi.lamp(self, Vector2(lx, ly - 5), kk[0], true, ka, 6.0)
		_text(kk[1], Vector2(lx + 16, ly), 14, Pal.ink(0.7 * ka), font_b)
		lx += 120
	# stock: a row of tiles under the drawing
	var g := _grid_rect()
	Hmi.plate(self, font_s, Rect2(g.position.x, g.position.y, 440, 30), Txt.t("tm_items"), 15, ka)
	for i in range(FITTED, SHOP.size()):
		_cell(i, ka)
	_detail(a)


# the drone and the berth in line, each upgrade on the part it changes:
# fitted parts solid, the ones not bought as a faint dashed outline
func _schematic(sr: Rect2, a: float) -> void:
	var d := Career.data
	var c := _drone_c()
	var R := Drone.R * DK
	# the berth: floor, tower, boom (in the right part of the drawing)
	var bx0 := sr.position.x + sr.size.x * 0.52
	var by := sr.position.y + sr.size.y * 0.24
	var fy := sr.end.y - 40.0
	var tx := sr.end.x - 40.0
	draw_line(Vector2(bx0, fy), Vector2(sr.end.x - 16, fy), Pal.tint(Pal.AIR, 0.5 * a), 1.6)
	draw_line(Vector2(tx, fy), Vector2(tx, by - 20), Pal.tint(Pal.AIR, 0.5 * a), 1.6)
	draw_line(Vector2(tx - 12, fy), Vector2(tx - 12, by - 20), Pal.tint(Pal.AIR, 0.3 * a), 1.0)
	draw_line(Vector2(bx0, by), Vector2(tx, by), Pal.tint(Pal.AIR, 0.5 * a), 1.6)
	draw_line(Vector2(bx0, by - 12), Vector2(tx, by - 12), Pal.tint(Pal.AIR, 0.3 * a), 1.0)
	var zx := bx0
	while zx < tx - 12:
		draw_line(Vector2(zx, by), Vector2(zx + 12, by - 12), Pal.tint(Pal.AIR, 0.22 * a), 1.0)
		zx += 24.0
	_text("BERTH 07", Vector2(bx0, by - 22), 14, Pal.tint(Pal.AIR, 0.7 * a), font_b)
	# the hose mast from the floor
	var pa := _anchor(2)
	draw_line(Vector2(pa.x, fy), Vector2(pa.x, pa.y + 14), Pal.tint(Pal.AIR, 0.5 * a), 1.6)
	draw_rect(Rect2(pa + Vector2(-16, -10), Vector2(30, 26)), Pal.tint(Pal.AIR, 0.6 * a), false, 1.4)
	# the drone: the airframe as it flies, drawn four times over in blueprint blue
	var xf := Transform2D(0.0, Vector2(DK, DK), 0.0, c)
	draw_set_transform_matrix(xf)
	DArt.tint = Color(Pal.AIR.r * 1.1 * a, Pal.AIR.g * 1.1 * a, Pal.AIR.b * 1.1 * a)
	DArt.draw(self, "arrowring", {"heading": -0.2, "tool": 1, "open": 1.0, "t": t, "thrust": Vector2.ZERO, "dash": false, "design": "arrowring", "base_xf": xf})
	DArt.tint = Color(1, 1, 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_text("R-02", c + Vector2(-22, R + 40), 18, Pal.tint(Pal.AIR, 0.85 * a, 1.2), font_s)
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
	var col := Pal.tint(Pal.AIR, 0.95 * a, 1.3) if have else Pal.tint(Pal.AIR, 0.4 * a)
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
# an upgrade's plate on the drawing, joined to its part: its lamp says fitted,
# can be had, or short of money
func _callout_box(i: int, a: float) -> void:
	var it: Array = SHOP[i]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x
	var sk: float = sel_k[i].x
	var have: bool = Career.data.upgrades.has(it[0])
	var short: bool = not have and float(Career.data.money) < float(it[2])
	var k := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.05) / 0.3, 0.0, 1.0)) * a
	r.position.x += (1.0 - k) * (-30.0 if r.position.x < size.x * 0.3 else 30.0)
	var p := _anchor(i)
	var edge := Vector2(r.end.x if p.x > r.end.x else r.position.x, r.get_center().y)
	draw_line(edge, p, Pal.tint(Pal.AIR, (0.35 + 0.45 * maxf(hk, sk)) * k), 1.2, true)
	draw_circle(p, 4.0, Pal.heat(k, 1.3) if sk > 0.5 else Pal.tint(Pal.AIR, 0.9 * k, 1.3))
	Hmi.raised(self, r, k, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	if sk > 0.02:
		draw_rect(r.grow(3.0), Pal.heat(sk * k, 1.4), false, 3.0)
	Hmi.lamp(self, r.position + Vector2(22, r.size.y * 0.5), Hmi.ok_col() if have else (Hmi.warn_col() if short else Hmi.can_col()), true, k)
	_text(Txt.t(it[3]), r.position + Vector2(42, 28), 17, Pal.ink(0.96 * k), font_s)
	if have:
		_text(Txt.t("tm_installed"), r.position + Vector2(42, 54), 16, Pal.tint(Pal.FLUID, 0.95 * k, 1.1), font_s)
	else:
		_text(Pal.money(it[2]), r.position + Vector2(42, 54), 16, Pal.ink((0.9 if not short else 0.55) * k), font_s)
	if short:
		_text(Txt.t("tm_short_n") % Pal.money(float(it[2]) - float(Career.data.money)), Vector2(r.end.x - 12, r.position.y + 54), 13, Pal.heat(0.9 * k, 1.2), font_b, 1)


# a consumable: a cell with its mark, how many are in stock, and the price
# a consumable: a tile with its mark, its stock window, the price
func _cell(i: int, a: float) -> void:
	var it: Array = SHOP[i]
	var r := _item_rect(i)
	var hk: float = hover_k[i].x
	var sk: float = sel_k[i].x
	var k := Pal.ease_out(clampf((deal_t - 0.2 - (i - FITTED) * 0.05) / 0.3, 0.0, 1.0)) * a
	r.position.y += (1.0 - k) * 24.0 - hk * 4.0
	Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	if sk > 0.02:
		draw_rect(r.grow(3.0), Pal.heat(sk * k, 1.4), false, 3.0)
	var n := int(Career.data.items.get(it[0], 0))
	_icon(it[0], r.position + Vector2(38, 44), k)
	var sw := Rect2(r.end.x - 86, r.position.y + 14, 72, 52)
	Hmi.screen(self, sw, k)
	_text("×%d" % n, sw.get_center() + Vector2(0, 12), 30, Pal.tint(Pal.AIR, 0.95 * k, 1.4) if n > 0 else Pal.ink(0.35 * k), font_s, 0)
	_text(Txt.t(it[3]), r.position + Vector2(16, r.size.y - 40), 16, Pal.ink(0.95 * k), font_s)
	var afford := float(Career.data.money) >= float(it[2])
	_text(Pal.money(it[2]), r.position + Vector2(16, r.size.y - 14), 15, Pal.ink((0.8 if afford else 0.4) * k), font_b)
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
			# a spare airframe: the drone's own outline
			var pts := PackedVector2Array()
			for v in DArt.ARROW:
				pts.append(p + (v as Vector2) * 0.8)
			pts.append(pts[0])
			draw_polyline(pts, col, 1.8, true)
			draw_circle(p + Vector2(-1.5, 0), 4.0, col)
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
	Hmi.raised(self, r, ka)
	var x := r.position.x + 32
	var w := r.size.x - 64
	var kind := "tm_kind_it" if it[1] == "item" else ("tm_kind_fa" if it[1] == "facility" else "tm_kind_up")
	var pl := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 44)
	Hmi.plate(self, font_s, pl, Txt.t(kind), 18, ka, Pal.tint(Pal.AIR, 0.95, 1.2))
	var have0: bool = it[1] != "item" and Career.data.upgrades.has(id)
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.ok_col() if have0 else (Hmi.warn_col() if float(Career.data.money) < float(it[2]) else Hmi.can_col()), true, ka)
	var y := r.position.y + 62
	_text(Txt.t(it[3]), Vector2(x, y + 56), 36, Pal.ink(0.98 * ka), font_s)
	_wrap(Txt.t(it[4]), Vector2(x, y + 92), w, 16, Pal.ink(0.78 * ka))
	y += 140
	var have: bool = it[1] != "item" and d.upgrades.has(id)
	if it[1] != "item":
		var rows: Array = STATS.get(id, [])
		var grow := Pal.ease_out(clampf((deal_t - 0.3) / 0.6, 0.0, 1.0))
		for row in rows:
			var nv: String = Txt.t(row[1]) if str(row[1]).begins_with("sh_") else row[1]
			var av: String = Txt.t(row[2]) if str(row[2]).begins_with("sh_") else row[2]
			_text(Txt.t(row[0]), Vector2(x, y + 14), 16, Pal.ink(0.7 * ka), font_b)
			_text(nv + "  →  " + av, Vector2(x + w, y + 14), 17, Pal.ink(0.95 * ka), font_s, 1)
			var nowk: float = row[3]
			var aftk: float = row[4]
			if have:
				Hmi.gauge(self, Rect2(x, y + 24, w, 22), aftk, Pal.tint(Pal.FLUID, 1.0, 1.1), ka)
			else:
				Hmi.gauge(self, Rect2(x, y + 24, w, 22), nowk, Pal.ink(0.75), ka, 10, lerpf(nowk, aftk, grow))
			y += 66
		y += 6
		var sc := Rect2(x - 10, y, w + 20, 96)
		Hmi.screen(self, sc, ka)
		_text(Txt.t("tm_strategy"), sc.position + Vector2(14, 26), 14, Pal.ink(0.6 * ka), font)
		_wrap(Txt.t("st_" + id), sc.position + Vector2(14, 56), w - 8, 19, Pal.tint(Pal.AIR, 0.95 * ka, 1.2))
	else:
		var n := int(d.items.get(id, 0))
		_text(Txt.t("tm_stock_n") % n, Vector2(x, y + 4), 18, Pal.ink(0.9 * ka), font_b)
		var how: String = Txt.t("tm_use_auto") if id == "spare" else (Txt.t("tm_use_intel_at") if id == "intel" else Txt.t("tm_use") % USE_KEY[id])
		_text(how, Vector2(x, y + 34), 15, Pal.ink(0.65 * ka), font)
	# the money
	if have:
		Hmi.lamp(self, Vector2(x + 10, r.end.y - 136), Hmi.ok_col(), true, ka, 9.0)
		_text(Txt.t("tm_installed"), Vector2(x + 30, r.end.y - 128), 22, Pal.tint(Pal.FLUID, 0.95 * ka, 1.1), font_s)
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
			Hmi.raised(self, qr, ka, Hmi.PANEL_HI if hv else Hmi.PANEL)
			_text("−" if sgn < 0 else "+", qr.get_center() + Vector2(0, 9), 26, Pal.ink(0.95 * ka), font_s, 0)
		var qw := Rect2(_qty_rect(-1).end.x + 14, _qty_rect(-1).position.y, 74, 48)
		Hmi.screen(self, qw, ka)
		_text(str(qty), qw.get_center() + Vector2(0, 11), 30, Pal.tint(Pal.AIR, 0.95 * ka, 1.3), font_s, 0)
	draw_line(Vector2(x, my - 22), Vector2(x + w, my - 22), Color(0, 0, 0, 0.5 * ka), 2.0)
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
	Hmi.raised(self, fr, k0, Hmi.PANEL.lerp(Hmi.PANEL_HI, sel_k[0].x * 0.6))
	if sel_k[0].x > 0.02:
		draw_rect(fr.grow(4.0), Pal.heat(sel_k[0].x * k0, 1.4), false, 4.0)
	var x := fr.position.x + 36
	var w := fr.size.x - 72
	Hmi.plate(self, font_s, Rect2(fr.position.x + 18, fr.position.y + 18, fr.size.x - 36, 46), Txt.t("tm_fin"), 21, k0)
	Hmi.lamp(self, Vector2(fr.end.x - 40, fr.position.y + 41), Hmi.warn_col() if float(d.loan) > 0.0 else Hmi.ok_col(), true, k0)
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
	var mx := _repay_max()
	var f := amt / mx if mx > 0.0 else 0.0
	Hmi.gauge(self, Rect2(sl.position.x, sl.position.y - 8, sl.size.x, 24), f, Pal.heat(1.0, 1.3), k0, 20)
	var kn := Vector2(sl.position.x + sl.size.x * f, sl.get_center().y)
	var kr := Rect2(kn - Vector2(12, 20), Vector2(24, 40))
	if dragging:
		Hmi.sunk(self, kr, k0, Hmi.PANEL_HI)
	else:
		Hmi.raised(self, kr, k0, Hmi.PANEL_HI)
	draw_line(kn + Vector2(0, -12), kn + Vector2(0, 12), Pal.heat(k0, 1.5), 2.0)
	_text("$0", Vector2(sl.position.x, sl.end.y + 26), 13, Pal.ink(0.45 * k0), font)
	_text(Pal.money(mx), Vector2(sl.end.x, sl.end.y + 26), 13, Pal.ink(0.45 * k0), font, 1)
	# now → after the payment
	var y := sl.end.y + 120
	Hmi.screen(self, Rect2(x - 16, y - 66, w + 32, rows.size() * 36 + 76), k0)
	_text(Txt.t("tm_fin_after"), Vector2(x + w, y - 40), 13, Pal.ink(0.55 * k0), font, 1)
	for i in rows.size():
		var yy := y + i * 36
		var rk := Pal.ease_out(clampf((deal_t - 0.1 - i * 0.04) / 0.3, 0.0, 1.0)) * k0
		_text(rows[i][0], Vector2(x, yy), 16, Pal.ink(0.65 * rk), font)
		var changed: bool = absf(float(rows[i][1]) - float(rows[i][2])) > 0.5
		_text(Pal.money(rows[i][1]), Vector2(x + w - 230, yy), 17, Pal.ink((0.55 if changed else 0.9) * rk), font_b, 1)
		if changed:
			_text("→", Vector2(x + w - 200, yy), 16, Pal.ink(0.45 * rk), font)
			_text(Pal.money(rows[i][2]), Vector2(x + w, yy), 17, Pal.tint(Pal.AIR, 0.95 * rk, 1.3) if i != 4 else Pal.heat(0.95 * rk, 1.2), font_s, 1)
		draw_line(Vector2(x, yy + 12), Vector2(x + w, yy + 12), Pal.ink(0.06 * rk), 1.0)
	if loan <= 0.0:
		Hmi.lamp(self, Vector2(x + 8, fr.end.y - 136), Hmi.ok_col(), true, k0, 8.0)
		_text(Txt.t("tm_paid_off"), Vector2(x + 26, fr.end.y - 130), 18, Pal.tint(Pal.FLUID, 0.95 * k0, 1.1), font_s)
	# training, and what opens later
	var tr := _training_rect()
	var k1 := Pal.ease_out(clampf((deal_t - 0.1) / 0.35, 0.0, 1.0)) * a
	Hmi.raised(self, tr, k1, Hmi.PANEL.lerp(Hmi.PANEL_HI, sel_k[1].x * 0.6))
	if sel_k[1].x > 0.02:
		draw_rect(tr.grow(4.0), Pal.heat(sel_k[1].x * k1, 1.4), false, 4.0)
	Hmi.plate(self, font_s, Rect2(tr.position.x + 18, tr.position.y + 18, tr.size.x - 36, 46), Txt.t("tm_training"), 21, k1)
	Hmi.lamp(self, Vector2(tr.end.x - 40, tr.position.y + 41), Hmi.can_col(), true, k1)
	_wrap(Txt.t("tm_training_d"), tr.position + Vector2(32, 100), tr.size.x - 64, 15, Pal.ink(0.75 * k1))
	# the facilities: bought once, kept
	var d2 := Career.data
	Hmi.plate(self, font_s, Rect2(tr.position.x, tr.end.y + 12, 420, 30), Txt.t("tm_facilities"), 15, k1)
	for j in BERTH.size() - 2:
		var it: Array = BERTH[2 + j]
		var fcr := _facility_rect(j)
		var fk := Pal.ease_out(clampf((deal_t - 0.14 - j * 0.05) / 0.35, 0.0, 1.0)) * a
		var have: bool = d2.upgrades.has(it[0])
		var locked: bool = not have and REQUIRES.has(it[0]) and not d2.upgrades.has(REQUIRES[it[0]])
		Hmi.raised(self, fcr, fk, Hmi.PANEL_LO.lerp(Hmi.PANEL_HI, sel_k[2 + j].x * 0.7))
		if sel_k[2 + j].x > 0.02:
			draw_rect(fcr.grow(3.0), Pal.heat(sel_k[2 + j].x * fk, 1.4), false, 3.0)
		var short2: bool = not have and float(d2.money) < float(it[2])
		Hmi.lamp(self, fcr.position + Vector2(18, 24), Hmi.ok_col() if have else (Hmi.warn_col() if locked or short2 else Hmi.can_col()), true, fk, 6.0)
		_text(Txt.t(it[3]), fcr.position + Vector2(34, 30), 16, Pal.ink(0.96 * fk), font_s)
		# one that needs another bought first says so where its description goes
		if locked:
			_text(Txt.t("tm_needs") % Txt.t(_facility_name(REQUIRES[it[0]])), fcr.position + Vector2(34, 56), 12, Pal.heat(0.85 * fk, 1.2), font_b)
		else:
			_wrap(Txt.t(it[4]), fcr.position + Vector2(34, 52), fcr.size.x - (200.0 if sel == 2 + j else 50.0), 12, Pal.ink(0.65 * fk))
		if sel != 2 + j:
			var tag: String = Txt.t("tm_installed") if have else Pal.money(it[2])
			_text(tag, Vector2(fcr.end.x - 16, fcr.position.y + 30), 15, Pal.tint(Pal.FLUID, 0.95 * fk, 1.1) if have else Pal.ink((0.92 if not short2 and not locked else 0.45) * fk), font_s, 1)
	var lr := Rect2(tr.position.x, _facility_rect(BERTH.size() - 3).end.y + 16, tr.size.x, 80)
	var k2 := Pal.ease_out(clampf((deal_t - 0.16) / 0.35, 0.0, 1.0)) * a
	Hmi.sunk(self, lr, k2)
	_text(Txt.t("tm_later_h"), lr.position + Vector2(24, 32), 14, Pal.ink(0.55 * k2), font_b)
	var names: Array = []
	for n in LATER:
		names.append(Txt.t(n))
	_wrap("  ·  ".join(names), lr.position + Vector2(24, 62), lr.size.x - 48, 15, Pal.ink(0.6 * k2))


# ---------------------------------------------------------------- the button, the keys, the messages

func _bottom(s: Vector2, a: float) -> void:
	if tab == 3:
		return
	var r := _go_rect()
	var label := ""
	var note := ""
	var ok := true
	var d := Career.data
	match tab:
		0:
			label = Txt.t("tm_take") + "   Enter"
			if not next_job.is_empty():
				Hmi.push(self, font_s, _go_rect(), Txt.t("tm_next_go"), true, 1.0 if hover_go else 0.0, a, t, 0.0, "", "ENTER")
				return
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
	Hmi.push(self, font_s, r, label.replace("   Enter", ""), ok, 1.0 if hover_go else 0.0, a, t, shake, note, "ENTER" if label.ends_with("Enter") else "", 1.0 if press_t > 0.0 and tab_press < 0 else 0.0)
	_text(Txt.t("tm_keys_onsite") if overlay else Txt.t("tm_keys"), Vector2(60, s.y - 34), 13, Pal.ink(0.45 * a), font)
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
	Hmi.raised(self, r, 1.0, Hmi.PANEL_HI)
	draw_rect(r.grow(4.0 * (1.0 - g)), Pal.heat(1.0 - g, 1.4), false, 4.0)
	if not leave_offer.is_empty():
		var tw := r.size.x * 0.8
		_thumb(leave_offer, Rect2(r.get_center() - Vector2(tw * 0.5, tw * 0.11), Vector2(tw, tw * 0.22)), clampf(leaving / 0.15, 0.0, 1.0))
	var c := clampf((leaving - 0.52) / 0.24, 0.0, 1.0)
	if c > 0.0:
		var h := s.y * 0.5 * Pal.ease_in(c)
		draw_rect(Rect2(0, 0, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y - h, s.x, h), Color(0, 0, 0, 1))
		draw_rect(Rect2(0, s.y * 0.5 - 1, s.x, 2), Pal.heat(c, 2.0))


# the opening contract waiting in the berth: one card, what it is and that the market opens after
# the pinned story contract among the offers: the opening's next job, taken
# whenever the player likes (its story plays when it is)
func _story_card(o: Dictionary, r: Rect2, k: float, hk: float, sk: float) -> void:
	r.position.y += (1.0 - k) * 36.0 - hk * 6.0
	Hmi.raised(self, r, k, Hmi.PANEL.lerp(Hmi.PANEL_HI, maxf(hk * 0.6, sk)))
	if sk > 0.02:
		draw_rect(r.grow(4.0), Pal.heat(sk * k, 1.4), false, 4.0)
	var x := r.position.x + 28
	var y := r.position.y
	var ty: Dictionary = Market.type_of(str(o.get("ship", "gr7")))
	var d := Ship.load_data(str(o.get("ship", "gr7")))
	var pl := Rect2(r.position.x + 18, y + 18, r.size.x - 36, 46)
	Hmi.plate(self, font_s, pl, Txt.t("tm_next_h"), 21, k, Pal.heat(1.0, 1.3))
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.warn_col(), true, k, 7.0)
	var sc := Rect2(r.position.x + 18, y + 80, r.size.x - 36, 300)
	Hmi.screen(self, sc, k)
	var nm: String = ((ty.name[0] if Txt.zh else ty.name[1]) if not ty.is_empty() else str(d.get("name", "")))
	_text(str(o.get("id", "")), sc.position + Vector2(16, 70), 50, Pal.ink(0.98 * k), font_l)
	_text(nm, sc.position + Vector2(16, 106), 19, Pal.ink(0.82 * k), font_s)
	_thumb(o, Rect2(sc.position.x + 16, sc.position.y + 140, sc.size.x - 32, 140), k)
	var rows := [
		[Txt.t("mf_length"), "%d m" % int(float(d.get("length", 0.0)))],
		[Txt.t("tm_value"), Pal.money(float(d.get("value", {}).get("total", 0.0)))],
		[Txt.t("tm_fee_story"), Pal.money(float(o.get("fee", 0.0)))],
		[Txt.t("tm_minutes_h"), Txt.t("tm_min_n") % int(float(o.get("time", 0.0)) / 60.0) if float(o.get("time", 0.0)) > 0.0 else Txt.t("tm_no_limit")],
	]
	for i in rows.size():
		_text(rows[i][0], Vector2(x, y + 430 + i * 44), 15, Pal.ink(0.6 * k), font)
		_text(rows[i][1], Vector2(r.end.x - 28, y + 430 + i * 44), 20, Pal.ink(0.95 * k), font_s, 1)
	_wrap(Txt.t("tm_next_d"), Vector2(x, y + 620), r.size.x - 56, 15, Pal.heat(0.9 * k, 1.1), 3)


func _next_card(s: Vector2, a: float) -> void:
	var r := _item_rect(0)
	var k := Pal.ease_out(clampf((deal_t - 0.06) / 0.35, 0.0, 1.0)) * a
	if leaving >= 0.0:
		return
	r.position.y += (1.0 - k) * 36.0
	Hmi.raised(self, r, k, Hmi.PANEL_HI)
	draw_rect(r.grow(4.0), Pal.heat(k, 1.4), false, 4.0)
	var x := r.position.x + 28
	var y := r.position.y + 50
	var ty: Dictionary = Market.type_of(str(next_job.get("ship", "gr7")))
	var d := Ship.load_data(str(next_job.get("ship", "gr7")))
	var pl := Rect2(r.position.x + 18, r.position.y + 18, r.size.x - 36, 46)
	Hmi.plate(self, font_s, pl, Txt.t("tm_next_first"), 21, k, Pal.heat(1.0, 1.3))
	Hmi.lamp(self, Vector2(pl.end.x - 22, pl.get_center().y), Hmi.warn_col(), true, k, 7.0)
	y += 50
	var nm: String = ((ty.name[0] if Txt.zh else ty.name[1]) if not ty.is_empty() else str(d.get("name", "")))
	_text(str(next_job.get("id", "")), Vector2(x, y + 44), 30, Pal.ink(0.96 * k), font_l)
	_text(nm, Vector2(x, y + 76), 17, Pal.ink(0.8 * k), font_b)
	var rows := [
		[Txt.t("mf_length"), "%d m" % int(float(d.get("length", 0.0)))],
		[Txt.t("tm_value"), Pal.money(float(d.get("value", {}).get("total", 0.0)))],
		[Txt.t("tm_fee"), Pal.money(float(next_job.get("fee", 0.0)))],
	]
	for i in rows.size():
		_text(rows[i][0], Vector2(x, y + 130 + i * 40), 14, Pal.ink(0.55 * k), font)
		_text(rows[i][1], Vector2(r.end.x - 28, y + 130 + i * 40), 18, Pal.ink(0.92 * k), font_b, 1)
	_wrap(Txt.t("tm_next_first_d"), Vector2(x, y + 270), r.size.x - 56, 15, Pal.ink(0.7 * k), 4)
	# beside it: what the money is for, and what comes later
	var hx := _item_rect(1).position.x
	var hw := _item_rect(2).end.x - hx
	_wrap(Txt.t("tm_next_side"), Vector2(hx, r.position.y + 30), hw, 15, Pal.ink(0.55 * a), 2)
	_outlook(Rect2(hx, r.position.y + 80, hw, r.size.y - 80), a)


# What there is to work for: the next things the money buys (cheapest first,
# with what is still missing), and the ship types that open up later (the
# reputation they need, and the berth extension for the long ones)
func _outlook(r: Rect2, a: float) -> void:
	var d := Career.data
	var money := float(d.money)
	var x := r.position.x
	var colw := (r.size.x - 40.0) * 0.5
	_text(Txt.t("tm_out_buy"), Vector2(x, r.position.y + 10), 15, Pal.ink(0.7 * a), font_b)
	var buy: Array = []
	for it in SHOP + BERTH:
		if it[1] in ["upgrade", "facility"] and not d.upgrades.has(it[0]):
			buy.append(it)
	for row in Growth.TRACKS:
		if Growth.level(d.upgrades, row[0]) < 3:
			buy.append([row[0], "skill", Growth.price(row[0]), Growth.text(row[2])])
	var goal: String = str(d.get("growth_goal", ""))
	buy.sort_custom(func(p, q):
		if p[0] == goal or q[0] == goal:
			return p[0] == goal and q[0] != goal
		return float(p[2]) < float(q[2]))
	var y := r.position.y + 48.0
	for i in mini(buy.size(), 9):
		var it: Array = buy[i]
		var k := Pal.ease_out(clampf((deal_t - 0.2 - i * 0.04) / 0.3, 0.0, 1.0)) * a
		var can: bool = money >= float(it[2]) and (it[1] != "skill" or Growth.reason(it[0]) == "")
		var need := Growth.reason(it[0]) if it[1] == "skill" else ""
		_text(("★ " if it[0] == goal else "") + Txt.t(it[3]), Vector2(x, y), 15, Pal.ink(0.9 * k), font)
		_text(Pal.money(float(it[2])), Vector2(x + colw - 120, y), 15, Pal.ink((0.95 if can else 0.6) * k), font_b, 1)
		_text(Txt.t("tm_out_can") if can else (need if need != "" else Txt.t("tm_out_short") % Pal.money(float(it[2]) - money)), Vector2(x + colw, y), 13, Pal.tint(Pal.FLUID, 0.85 * k, 1.1) if can else Pal.ink(0.45 * k), font, 1)
		y += 34.0
	var x2 := x + colw + 40.0
	_text(Txt.t("tm_out_ships"), Vector2(x2, r.position.y + 10), 15, Pal.ink(0.7 * a), font_b)
	y = r.position.y + 48.0
	var i2 := 0
	for e in Market.POOL:
		var ty: Dictionary = Market.type_of(e[0])
		if ty.is_empty():
			continue
		var k2 := Pal.ease_out(clampf((deal_t - 0.25 - i2 * 0.04) / 0.3, 0.0, 1.0)) * a
		var open: bool = int(d.get("rep", 0)) >= int(e[2]) and Market.fits(e[0], d) and d.get("market", false)
		_text("%s  %s · %d m" % [ty.get("class", ""), ty.name[0] if Txt.zh else ty.name[1], int(float(ty.get("length", 0.0)))], Vector2(x2, y), 15, Pal.ink((0.9 if open else 0.6) * k2), font)
		var need: Array = []
		if int(e[2]) > int(d.get("rep", 0)):
			need.append(Txt.t("tm_out_rep") % int(e[2]))
		if not Market.fits(e[0], d):
			need.append(Txt.t("fa_berth"))
		var note: String = (Txt.t("tm_out_now") if d.get("market", false) else Txt.t("tm_out_open")) if need.is_empty() else "、".join(need)
		_text(note, Vector2(x2, y + 18), 12, Pal.tint(Pal.FLUID, 0.8 * k2, 1.1) if need.is_empty() else Pal.ink(0.45 * k2), font)
		y += 42.0
		i2 += 1


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
