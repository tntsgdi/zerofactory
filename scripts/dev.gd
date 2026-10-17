class_name DevPanel
extends CanvasLayer
# Developer mode, for testing by hand: F12 anywhere turns it on or off (kept
# in the settings). While on, a panel at the top right lists what the F keys
# do here; every row can also be clicked.
#   On site:   F1 x-ray (the ship's true state)   F2 make it safe   F3 free every piece
#              F4 drone can't be hurt   F5 time ×1 / ×2 / ×4 / ×8 / ×¼   F6 open every room
#              F7 +3 of each consumable   F8 end the contract now   F9 inspect what the pointer is on
#              F10 this contract again, from the start
#   Terminal:  F1 +$100,000   F2 clear the debt   F3 +5 reputation   F4 every upgrade and facility
#              F5 +3 of each consumable   F6 new offers   F7 a contract with one chosen trap
#              F8 skip the opening contracts (the market opens)   F9 forget the work plans
#   Title:     F1 through training (certified)
# Everywhere: "test contract…" opens the contract builder: ship type, accidents
# (those its file allows), risk stars, scope, goal, upgrades and variant seed,
# checked by the contract validator as it is set. "Start" plays it as a
# sandbox (dev job: nothing is settled into the career, nothing autosaved over
# the career's contract); in the terminal it can also go on the first card.

const TIME_STEPS := [1.0, 2.0, 4.0, 8.0, 0.25]
const SHIPS := ["gr7", "s09", "tug", "pod", "h22"]
const KIT := [["scan_kit", "up_scan"], ["grapple5", "up_grapple"], ["pump2", "up_pump"], ["arm", "fa_arm"],
	["mouth_rail", "fa_rail"], ["net05", "fa_net"], ["hauler", "fa_hauler"]]
const GOALS := ["", "safe", "fast", "valuable"]
const SCOPES := ["full", "section", "rescue"]

static var god := false          # the drone takes no damage
static var time_k := 1.0         # time on site (1 = as it runs)
static var xray := false
static var inspect := false
# the contract builder's settings, kept while the game runs
static var b_ship := "gr7"
static var b_traps: Array = []
static var b_stars := 1
static var b_scope := "full"
static var b_goal := ""
static var b_kit := {}
static var b_seed := 1

var where := "game"              # game | terminal | title
var game: Game
var terminal: Terminal
var c: Control
var font: Font
var font_b: Font
var k := 0.0                     # panel in (0..1)
var toast := ""
var toast_t := 9.0
var trap_i := 0
var t := 0.0
var xray_node: Node2D
var builder := false             # the contract builder is open
var hits: Array = []             # [Rect2, Callable] of what can be clicked, as last drawn
var mouse := Vector2.ZERO
var check_key := ""
var check_res := {}              # the builder's contract as the validator saw it


static func warp_on() -> bool:
	return Txt.dev and time_k != 1.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_panel)
	add_child(c)
	if game != null:
		xray_node = Node2D.new()
		xray_node.z_index = 30
		xray_node.z_as_relative = false
		xray_node.draw.connect(_draw_xray)
		game.add_child(xray_node)


func rows() -> Array:
	match where:
		"game":
			return [["F1", "dev_xray", xray], ["F2", "dev_safe", null], ["F3", "dev_free", null], ["F4", "dev_god", god],
				["F5", "dev_time", time_k != 1.0], ["F6", "dev_rooms", null], ["F7", "dev_items", null], ["F8", "dev_end", null],
				["F9", "dev_inspect", inspect], ["F10", "dev_again", null], ["", "dev_builder", builder]]
		"terminal":
			return [["F1", "dev_money", null], ["F2", "dev_loan", null], ["F3", "dev_rep", null], ["F4", "dev_upgrades", null],
				["F5", "dev_items", null], ["F6", "dev_offers", null], ["F7", "dev_trap", null], ["F8", "dev_opening", null],
				["F9", "dev_plans", null], ["", "dev_builder", builder]]
		"title":
			return [["F1", "dev_certify", null], ["", "dev_builder", builder]]
	return []


func _row_label(row: Array) -> String:
	var s := Txt.t(row[1])
	if row[1] == "dev_time":
		s = s % _time_text()
	return s


func _time_text() -> String:
	return "×¼" if time_k < 1.0 else "×%d" % int(time_k)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var key: int = ev.physical_keycode
	if key == KEY_F12:
		Txt.dev = not Txt.dev
		if not Txt.dev:
			builder = false
		Txt.save_settings(game != null and game.testing)
		say(Txt.t("dev_on") if Txt.dev else Txt.t("dev_off"))
		get_viewport().set_input_as_handled()
		return
	if not Txt.dev:
		return
	if key == KEY_ESCAPE and builder:
		builder = false
		get_viewport().set_input_as_handled()
		return
	if key < KEY_F1 or key > KEY_F10:
		return
	var n := key - KEY_F1 + 1
	if n > rows().size() or rows()[n - 1][0] == "":
		return
	get_viewport().set_input_as_handled()
	run(n)


# clicks on the panel and the builder never reach the game below
func _input(ev: InputEvent) -> void:
	if not Txt.dev:
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# the builder is drawn last, over the rows: it is asked first
		for i in range(hits.size() - 1, -1, -1):
			var h: Array = hits[i]
			if h[0].has_point(ev.position):
				h[1].call()
				get_viewport().set_input_as_handled()
				return
		if builder and _builder_rect().has_point(ev.position):
			get_viewport().set_input_as_handled()


# do what row n stands for (1-based)
func run(n: int) -> void:
	var row: Array = rows()[n - 1]
	if row[1] == "dev_builder":
		builder = not builder
		return
	match where:
		"game":
			_game_key(n)
		"terminal":
			_terminal_key(n)
		"title":
			_title_key(n)


func say(s: String) -> void:
	toast = s
	toast_t = 0.0


# ---------------------------------------------------------------- on site

func _game_key(n: int) -> void:
	var g := game
	var s = g.sys
	match n:
		1:
			xray = not xray
		2:
			for v in s.vols:
				s.vols[v].n = 0.0
			for f in s.fvol:
				s.fvol[f].amount = 0.0
			for tg in s.src:
				s.src[tg].running = false
				s.src[tg].charge = 0.0
			for tg in s.iso:
				s.iso[tg].charge = 0.0
			s.loop_T = 20.0
			s.topology_dirty = true
			if g.mech != null:
				for m in g.mech.mags:
					g.mech.mags[m].k = 0.0
		3:
			for j in g.world.joints:
				if j.alive:
					g.world.kill_joint(j)
			for id in g.world.lines:
				g.world.kill_line(g.world.lines[id])
		4:
			god = not god
		5:
			time_k = TIME_STEPS[(TIME_STEPS.find(time_k) + 1) % TIME_STEPS.size()]
			if g.warp:
				Engine.time_scale = g._warp_k()
			say(Txt.t("dev_time") % _time_text())
			return
		6:
			for r in g.world.rooms:
				g.world.reveal(r, g.world.rooms[r].from)
		7:
			var it: Dictionary = g.job.get("items", {})
			for id in ["repair", "ring", "spare"]:
				it[id] = int(it.get(id, 0)) + 3
			g.job.items = it
		8:
			if g.state == "play":
				g.finish_contract(true)
		9:
			inspect = not inspect
		10:
			# the same contract again from its start (its ship, its accidents, its upgrades)
			if not g.dev_job():
				Game.contract = g.job.duplicate(true)
				Game.start_ship = g.ship_id
			SaveGame.load_requested = false
			say(Txt.t("dev_again"))
			g.restart()
			return
	say(_row_label(rows()[n - 1]))


# ---------------------------------------------------------------- terminal

func _terminal_key(n: int) -> void:
	var d := Career.data
	match n:
		1:
			d.money = float(d.money) + 100000.0
		2:
			d.loan = 0.0
			Career._paid_off()
			terminal._check_milestone()
		3:
			d.rep = int(d.rep) + 5
		4:
			for kv in KIT:
				d.upgrades[kv[0]] = 1
		5:
			for id in ["repair", "ring", "spare", "intel"]:
				d.items[id] = int(d.items.get(id, 0)) + 3
		6:
			d.offers = []
			Career.ensure_offers(Market.make)
			terminal.dealt()
		7:
			# the next trap in the list, alone, on the first card
			var tr: String = Traps.ALL[trap_i % Traps.ALL.size()]
			trap_i += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = int(Time.get_ticks_usec())
			for tries in 20:
				var o := Market.offer(rng, d, 1)
				o.traps = [tr]
				o.erase("_ship")
				if ContractValidator.check(Variant.make(Ship.load_data(o.ship), o)).ok:
					_first_card(o)
					break
			say(Txt.t("dev_trap") + "：" + tr)
			Career.save()
			return
		8:
			# past the work tug and the Swift (and GR-001): the market is open
			d.done = maxi(int(d.done), Career.OPENING.size())
			d.certified = true
			d.market = true
			d.active = {}
			d.offers = []
			Career.ensure_offers(Market.make)
			terminal.dealt()
		9:
			d.plans = {}
	Career.save()
	say(_row_label(rows()[n - 1]))


func _first_card(o: Dictionary) -> void:
	var d := Career.data
	if d.offers.is_empty():
		d.offers = [o]
	else:
		d.offers[0] = o
	terminal.dealt()


# ---------------------------------------------------------------- title

func _title_key(n: int) -> void:
	match n:
		1:
			if Career.usable():
				Career.load_or_new()
				Career.data.certified = true
				Career.save()
	say(_row_label(rows()[n - 1]))


# ---------------------------------------------------------------- the contract builder

# the builder's contract: an offer drawn for the chosen type, then set as asked,
# its variant drawn on until the contract validator passes it (or 20 tries)
static func build(career: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = b_seed
	var o := Market.offer(rng, career, b_stars, {}, b_scope, b_ship)
	o.erase("_ship")
	var allowed: Array = Traps.allowed(Ship.load_data(b_ship))
	o.traps = b_traps.filter(func(tr): return tr in allowed)
	if b_goal != "":
		o.goal = b_goal
	o.kit = b_kit.duplicate()
	o.id = "DEV-%s-%d" % [str(o.reg), b_seed]
	var v := {}
	for i in 20:
		v = ContractValidator.check(Variant.make(Ship.load_data(b_ship), o))
		if v.ok:
			break
		o.variant = int(o.variant) + 1
	return {"offer": o, "ok": v.get("ok", false), "reasons": v.get("reasons", [])}


func _career_for_build() -> Dictionary:
	if where == "terminal" and not Career.data.is_empty():
		return Career.data
	return {"rep": 30, "done": 6}


func _checked() -> Dictionary:
	var key := JSON.stringify([b_ship, b_traps, b_stars, b_scope, b_goal, b_kit, b_seed, where])
	if key != check_key:
		check_key = key
		check_res = build(_career_for_build())
	return check_res


# play it here and now, as a sandbox: nothing goes into the career
func _start() -> void:
	var r := _checked()
	if not r.ok:
		say(Txt.t("dev_b_invalid"))
		return
	var o: Dictionary = r.offer.duplicate(true)
	o.dev = true
	o.dev_from = where
	o.fee = 0.0
	Game.contract = o
	Game.start_ship = b_ship
	SaveGame.load_requested = false
	builder = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _to_card() -> void:
	var r := _checked()
	if not r.ok:
		say(Txt.t("dev_b_invalid"))
		return
	_first_card(r.offer.duplicate(true))
	Career.save()
	say(Txt.t("dev_b_carded"))


func _builder_rect() -> Rect2:
	var s := c.size
	return Rect2(s.x * 0.5 - 330.0, 110.0, 660.0, 470.0)


# ---------------------------------------------------------------- drawing

func _process(dt: float) -> void:
	t += dt
	toast_t += dt
	k = Pal.damp(k, 1.0 if Txt.dev else 0.0, 12.0, dt)
	if k > 0.003 or toast_t < 2.0:
		c.queue_redraw()
	if xray_node != null:
		xray_node.visible = Txt.dev and xray
		if xray_node.visible:
			xray_node.queue_redraw()


func _button(r: Rect2, text: String, on: bool, act: Callable, size_px: int = 13) -> void:
	var over := r.has_point(mouse)
	c.draw_rect(r, Color(0.16, 0.05, 0.06, 0.9) if on else Color(0.06, 0.06, 0.07, 0.9 if over else 0.7))
	c.draw_rect(r, Pal.heat(0.9, 1.2) if on else Pal.ink(0.45 if over else 0.2), false, 1.0)
	c.draw_string(font, Vector2(r.position.x + 8, r.position.y + r.size.y * 0.5 + size_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, size_px, Pal.ink(0.95 if on or over else 0.72))
	hits.append([r, act])


# a row of choices; returns the x after it
func _chips(x: float, y: float, items: Array, w: float = 0.0) -> float:
	for it in items:
		var tw: float = w if w > 0.0 else font.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		_button(Rect2(x, y, tw, 26), it[0], it[1], it[2])
		x += tw + 6.0
	return x


func _draw_panel() -> void:
	var s := c.size
	hits = []
	if toast_t < 2.0:
		var ta := clampf((2.0 - toast_t) / 0.3, 0.0, 1.0) * clampf(toast_t / 0.08, 0.0, 1.0)
		var w := font_b.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28.0
		var r := Rect2(s.x * 0.5 - w * 0.5, 22.0 - (1.0 - ta) * 10.0, w, 30.0)
		c.draw_rect(r, Color(0.1, 0.03, 0.03, 0.88 * ta))
		c.draw_rect(r, Pal.heat(0.8 * ta, 1.0), false, 1.0)
		c.draw_string(font_b, r.position + Vector2(14, 21), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.95 * ta))
	if k < 0.01:
		return
	var rs := rows()
	var pw := 280.0
	var ph := 40.0 + rs.size() * 24.0
	var x := s.x - 20.0 - pw + (1.0 - Pal.ease_out(k)) * 40.0
	var r2 := Rect2(x, _panel_y(), pw, ph)
	c.draw_rect(r2, Color(0.02, 0.02, 0.025, 0.94 * k))
	c.draw_rect(Rect2(r2.position, Vector2(3, ph)), Pal.heat(k, 1.2))
	c.draw_string(font_b, r2.position + Vector2(14, 24), "DEV  ·  F12", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.heat(0.9 * k, 1.2))
	for i in rs.size():
		var row: Array = rs[i]
		var y := r2.position.y + 50.0 + i * 24.0
		var hr := Rect2(x + 6, y - 17, pw - 12, 23)
		var over := hr.has_point(mouse) and k > 0.9
		if over:
			c.draw_rect(hr, Pal.ink(0.07))
		var on = row[2]
		c.draw_string(font, Vector2(x + 14, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * k))
		c.draw_string(font, Vector2(x + 52, y), _row_label(row), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink((0.95 if on == true or over else 0.7) * k))
		if on == true:
			c.draw_circle(Vector2(r2.end.x - 16, y - 4), 3.5, Pal.heat(k, 1.4))
		var n := i + 1
		hits.append([hr, func(): run(n)])
	if where == "game" and inspect and game != null:
		_inspect_card()
	if builder:
		_draw_builder()


# on site the panel sits under the takings and the machines' status
func _panel_y() -> float:
	return 360.0 if where == "game" else 130.0


func _draw_builder() -> void:
	var r := _builder_rect()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.55))
	# rows behind the builder are not clickable through it
	hits = hits.filter(func(h): return not r.intersects(h[0]))
	c.draw_rect(r, Color(0.025, 0.025, 0.03, 1.0))
	c.draw_rect(r, Pal.heat(0.8, 1.1), false, 1.0)
	c.draw_string(font_b, r.position + Vector2(18, 28), Txt.t("dev_b_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.heat(0.95, 1.2))
	_button(Rect2(r.end.x - 34, r.position.y + 8, 26, 26), "×", false, func(): builder = false)
	var x0 := r.position.x + 18.0
	var lx := x0 + 96.0
	var y := r.position.y + 50.0
	var lab := func(key: String, yy: float) -> void:
		c.draw_string(font, Vector2(x0, yy + 18), Txt.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.5))
	# ship type
	lab.call("dev_b_ship", y)
	var ships: Array = []
	for sid in SHIPS:
		if FileAccess.file_exists(Ship.DIR + sid + ".json"):
			var ty: Dictionary = Market.type_of(sid)
			var nm = ty.get("name", [sid, sid])
			var label: String = "%s %s" % [ty.get("class", sid.to_upper()), nm[0] if Txt.zh else nm[1]] if nm is Array else sid
			ships.append([label, b_ship == sid, func():
				b_ship = sid
				b_traps = b_traps.filter(func(tr): return tr in Traps.allowed(Ship.load_data(sid)))])
	_chips(lx, y, ships)
	y += 36.0
	# accidents this type allows
	lab.call("dev_b_traps", y)
	var allowed: Array = Traps.allowed(Ship.load_data(b_ship))
	var tx := lx
	var ty2 := y
	for tr in Traps.ALL + Traps.EXTRA:
		var ok: bool = tr in allowed
		if not ok:
			continue
		var label2 := Txt.t("dt_" + tr)
		var tw := font.get_string_size(label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		if tx + tw > r.end.x - 18.0:
			tx = lx
			ty2 += 32.0
		_button(Rect2(tx, ty2, tw, 26), label2, tr in b_traps, func():
			if tr in b_traps:
				b_traps.erase(tr)
			else:
				b_traps.append(tr))
		tx += tw + 6.0
	y = ty2 + 36.0
	# stars, scope, goal
	lab.call("dev_b_stars", y)
	var st: Array = []
	for n in [1, 2, 3]:
		st.append(["★".repeat(n), b_stars == n, func(): b_stars = n])
	_chips(lx, y, st, 52.0)
	y += 36.0
	lab.call("dev_b_scope", y)
	var sc: Array = []
	for scope in SCOPES:
		sc.append([Txt.t("sc_" + scope), b_scope == scope, func(): b_scope = scope])
	_chips(lx, y, sc)
	y += 36.0
	lab.call("dev_b_goal", y)
	var gl: Array = []
	for goal in GOALS:
		gl.append([Txt.t("goal_" + goal) if goal != "" else Txt.t("dev_b_drawn"), b_goal == goal, func(): b_goal = goal])
	_chips(lx, y, gl)
	y += 36.0
	# upgrades the contract is played with
	lab.call("dev_b_kit", y)
	var kx := lx
	var ky := y
	for kv in KIT:
		var id: String = kv[0]
		var label3 := Txt.t(kv[1])
		var kw := font.get_string_size(label3, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		if kx + kw > r.end.x - 18.0:
			kx = lx
			ky += 32.0
		_button(Rect2(kx, ky, kw, 26), label3, b_kit.has(id), func():
			if b_kit.has(id):
				b_kit.erase(id)
			else:
				b_kit[id] = 1)
		kx += kw + 6.0
	y = ky + 36.0
	# the variant seed
	lab.call("dev_b_seed", y)
	_button(Rect2(lx, y, 30, 26), "◀", false, func(): b_seed = maxi(1, b_seed - 1))
	c.draw_string(font_b, Vector2(lx + 40, y + 18), str(b_seed), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.9))
	_button(Rect2(lx + 110, y, 30, 26), "▶", false, func(): b_seed += 1)
	_button(Rect2(lx + 148, y, 70, 26), Txt.t("dev_b_random"), false, func(): b_seed = randi_range(1, 99999))
	y += 44.0
	# what the validator says, and what it would be worth
	var res := _checked()
	var o: Dictionary = res.offer
	var line: String
	if res.ok:
		line = Txt.t("dev_b_ok") % [o.reg, Pal.money(float(o.value)), float(o.time) / 60.0, ", ".join(o.traps.map(func(tr): return Txt.t("dt_" + tr))) if not o.traps.is_empty() else "—"]
	else:
		line = Txt.t("dev_b_bad") % ", ".join(res.reasons.slice(0, 4))
	c.draw_string(font, Vector2(x0, y + 4), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 13, Pal.ink(0.85) if res.ok else Pal.heat(0.95, 1.2))
	# start (a sandbox), or onto the first card at the terminal
	var by := r.end.y - 46.0
	_button(Rect2(x0, by, 210, 32), Txt.t("dev_b_start"), false, _start, 14)
	if where == "terminal":
		_button(Rect2(x0 + 222, by, 210, 32), Txt.t("dev_b_card"), false, _to_card, 14)
	var note := Txt.t("dev_b_note")
	c.draw_string(font, Vector2(r.end.x - 18 - font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, by + 21), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.4))


# what the pointer is on, the way the ship file and the systems see it
func _inspect_card() -> void:
	var g := game
	var under: Array = g.world.pieces_at(g.aim)
	if under.is_empty():
		return
	var p = under[0]
	var s = g.sys
	var lines: Array = []
	var nm: String = Txt.t(p.name_key) if p.get("name_key") != null and str(p.name_key) != "" else p.kind
	lines.append("%s  ·  %s" % [p.tag if p.tag != "" else "#%d" % p.id, nm])
	lines.append(Txt.t("dev_i_mass") % [p.mass, Pal.money(p.value), int(p.cond * 100.0), Txt.t("dev_i_whole") if p.intact else Txt.t("dev_i_broken")])
	var flags: Array = []
	if p.room != "":
		flags.append(Txt.t("dev_i_room") % p.room)
	if p.hazard != "":
		flags.append(Txt.t("dev_i_hazard") % p.hazard)
	if p.mandatory:
		flags.append(Txt.t("dev_i_named"))
	if p.body != null:
		flags.append(Txt.t("dev_i_loose"))
	flags.append(Txt.t("dev_i_dest") % Txt.t("dev_dest_" + s.dest_of(p)))
	lines.append("  ".join(flags))
	var js := {}
	for j in g.world.joints_of(p):
		js[j.type] = int(js.get(j.type, 0)) + 1
	var jl: Array = []
	for ty in js:
		jl.append("%s ×%d" % [ty, js[ty]])
	var ll: Array = []
	for l in g.world.lines_of(p):
		ll.append("%s(%s)" % [l.id, l.net])
	lines.append(Txt.t("dev_i_held") % [", ".join(jl) if not jl.is_empty() else "—", ", ".join(ll) if not ll.is_empty() else "—"])
	var sys_l: Array = []
	var v: float = s.piece_volts(p)
	if v > 0.0:
		sys_l.append("%d V" % int(v))
	var fv: String = s.fluid_in_piece(p)
	if fv != "":
		sys_l.append("%s %.3f" % [fv, s.fluid(fv)])
	if p.temp > 30.0:
		sys_l.append("%d °C" % int(p.temp))
	if g.mech != null and g.mech.mags.has(p.tag):
		sys_l.append("%.0f mT" % g.mech.field(p.tag))
	if not sys_l.is_empty():
		lines.append("  ".join(sys_l))
	var w := 0.0
	for ln in lines:
		w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var at := mouse + Vector2(22, 18)
	var r := Rect2(at, Vector2(w + 24, 14 + lines.size() * 19))
	if r.end.x > c.size.x - 10:
		r.position.x = mouse.x - r.size.x - 16
	if r.end.y > c.size.y - 10:
		r.position.y = mouse.y - r.size.y - 12
	c.draw_rect(r, Color(0.03, 0.02, 0.03, 0.92))
	c.draw_rect(r, Color(1.0, 0.35, 0.55, 0.8), false, 1.0)
	for i in lines.size():
		c.draw_string(font_b if i == 0 else font, r.position + Vector2(12, 22 + i * 19), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink(0.95 if i == 0 else 0.75))


# the ship's truth, written where it is: rooms, vessels, sources, live cables,
# magnets and preloads, trap targets, the work plan and the berth's machines
func _draw_xray() -> void:
	var g := game
	if g == null or g.sys == null:
		return
	var s = g.sys
	var col := Color(1.0, 0.35, 0.55, 0.95)
	var z: float = g.cam_zoom()
	for n in g.world.rooms:
		var r = g.world.rooms[n]
		var hidden: bool = g.world.room_hidden(n)
		_xlabel(r.bbox.get_center(), "%s  %.0f kPa%s" % [n, s.P(n), "  ·  " + Txt.t("dev_x_sealed") if hidden else ""], col, z, 16)
	for v in s.vessel_cfg:
		var vc: Dictionary = s.vessel_cfg[v]
		var p = g.world.tag(vc.get("piece", ""))
		if p != null:
			_xlabel(g.world.frame(p) * Geom.centroid(p.poly), "%s %.0f kPa" % [v, s.P(v)], col, z, 13)
	for tg in s.src:
		var p2 = g.world.tag(tg)
		if p2 != null:
			var e: Dictionary = s.src[tg]
			_xlabel(g.world.frame(p2) * Geom.centroid(p2.poly) + Vector2(0, 14.0 / z), "%s %s %d%%" % [tg, "RUN" if e.running else "", int(e.charge * 100.0)], col, z, 12)
	for tg in s.iso:
		var p3 = g.world.tag(tg)
		if p3 != null and s.iso_live(tg):
			_xlabel(g.world.frame(p3) * Geom.centroid(p3.poly), "%s %d V" % [tg, int(s.iso[tg].volts)], col, z, 12)
	for f in s.fvol:
		var fv: Dictionary = s.fvol[f]
		var p4 = g.world.tag(fv.get("piece", ""))
		if p4 != null:
			_xlabel(g.world.frame(p4) * Geom.centroid(p4.poly) + Vector2(0, -14.0 / z), "%s %.2f" % [f, fv.amount], col, z, 12)
	# cables that would arc if cut now
	for id in g.world.lines:
		var l = g.world.lines[id]
		if l.alive and l.kind == "cable" and s.line_volts(l) > 30.0:
			var pts: PackedVector2Array = g.world.line_path_world(l)
			if pts.size() >= 2:
				xray_node.draw_polyline(pts, Color(1.0, 0.85, 0.2, 0.75), 2.5 / z, true)
	# magnets and preloaded joints (H-22 and whatever else carries them)
	if g.mech != null:
		for m in g.mech.mags:
			var pm = g.world.tag(m)
			if pm != null and not pm.gone:
				var cm: Vector2 = g.world.frame(pm) * Geom.centroid(pm.poly)
				var f: float = g.mech.field(m)
				if f > 0.0:
					xray_node.draw_arc(cm, float(g.mech.mags[m].r) * Geom.M, 0.0, TAU, 48, Color(col, 0.5), 1.5 / z, true)
				_xlabel(cm + Vector2(0, 16.0 / z), "%s %.0f mT" % [m, f], col, z, 12)
		for l2 in g.mech.loads:
			var pl = g.world.tag(l2.cfg.get("piece", ""))
			if pl != null and not pl.gone:
				var vk: String = l2.cfg.get("vessel", "")
				_xlabel(g.world.frame(pl) * Geom.centroid(pl.poly), "%s %s%s" % [l2.tag, Txt.t("dev_x_fired") if l2.fired else (Txt.t("dev_x_loaded") if l2.alive else "—"),
					"  %s %.0f kPa" % [vk, s.P(vk)] if vk != "" else ""], col, z, 12)
	var traps: Array = g.ship.get("variant", {}).get("traps", [])
	var head := "BUS %d V  ·  LOOP %d °C  ·  %s" % [int(s.bus_volts()), int(s.loop_T), ", ".join(traps.map(func(tr): return Txt.t("dt_" + tr))) if not traps.is_empty() else "—"]
	if g.plan != null and g.plan.has_plan():
		var ps: Array = g.plan.status()
		head += "  ·  %s %s" % [ps[0], ps[1]] if not ps.is_empty() else ""
	var mach: Array = []
	if g.arm != null:
		mach.append("ARM %s" % g.arm.state)
	if g.hauler != null:
		mach.append("HAUL %s" % g.hauler.state)
	for z2 in g.mouths:
		mach.append("%s←%s" % [z2, g.mouths[z2]])
	if not mach.is_empty():
		head += "  ·  " + " ".join(mach)
	_xlabel(Vector2(30.0, -6.0) * Geom.M, head, col, z, 15)
	for tr in g.ship.get("variant", {}).get("targets", {}):
		var p5 = g.world.tag(g.ship.variant.targets[tr])
		if p5 != null:
			var pl5: PackedVector2Array = g.world.world_poly(p5)
			pl5.append(pl5[0])
			xray_node.draw_polyline(pl5, col, 2.0 / z, true)
	for j in g.world.joints:
		if j.alive and j.type in ["crack", "seam"]:
			xray_node.draw_circle(g.world.joint_world(j), 5.0 / z, col)


func _xlabel(at: Vector2, text: String, col: Color, z: float, size_px: int) -> void:
	xray_node.draw_set_transform(at, 0.0, Vector2.ONE / z)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	xray_node.draw_rect(Rect2(Vector2(-4, -size_px), Vector2(w + 8, size_px * 1.35)), Color(0.05, 0.0, 0.03, 0.75))
	xray_node.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
	xray_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
