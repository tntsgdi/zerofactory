class_name Hud
extends CanvasLayer
# Screen-space layer: contract panel, income, toolbar, drone status, cursor
# labels, measurement tags, messages, hints, the contract card, the pause
# menu and the settlement. Everything moves on springs and real time.

var game: Game
var c: Control
var fadd: Control
var font: Font
var font_l: Font
var font_b: Font
var t := 0.0
var rate_roll := Motion.Roller.new(0.0, 6.0)
var credit_roll := Motion.Roller.new(0.0, 7.0)
var credit_pop := 0.0
var slot_y: Array = []
var slot_glow: Array = []
var hint_text := ""
var hint_t := 99.0
var flash := 0.0
var hurt := 0.0
var flyers: Array = []     # [from, to, t, amount]
var card_k := Motion.Spring.new(0.0, 170.0, 0.82)
var card_t := 0.0
var menu_k := Motion.Spring.new(0.0, 220.0, 0.85)
var menu_hover := -1
var menu_confirm := -1
var ending := false
var end_t := 0.0
var end_early := false
var end_rows: Array = []
var must_k := [0.0, 0.0]
var tag_birth := {}
var tool_names_k := 0.0
# motion on site: the HUD slides in from the edges once the drone is out,
# the tool marker springs between slots, bars leave a trail when they move
var in_t := 0.0
var sel_x := Motion.Spring.new(0.0, 340.0, 0.7)
var tool_pulse := 9.0
var integ_ghost := 100.0
var integ_hold := 0.0
var integ_prev := 100.0
var integ_roll := Motion.Roller.new(100.0, 9.0)
var spd_roll := Motion.Roller.new(0.0, 8.0)
var rate_lo := 0.0
var rate_sweep := 9.0
var rate_last := 0.0
var mark_pop := [9.0, 9.0, 9.0]
var must_t := {}
var bursts: Array = []      # [screen pos, age]
var cur := Motion.Spring2.new(Vector2.ZERO, 900.0, 0.9)
var cur_key := ""
var cur_t := 0.0
var stock_last := {}
var stock_pop := 9.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_l = Fonts.get_font("Light")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_hud)
	add_child(c)
	fadd = Control.new()
	fadd.set_anchors_preset(Control.PRESET_FULL_RECT)
	fadd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fadd.material = m
	fadd.draw.connect(_draw_add)
	add_child(fadd)
	for i in 5:
		slot_y.append(Motion.Spring.new(0.0, 300.0, 0.6))
		slot_glow.append(0.0)


func size() -> Vector2:
	return c.size


func to_screen(w: Vector2) -> Vector2:
	return game.get_viewport().get_canvas_transform() * w


func pointer_over_ui() -> bool:
	var m := c.get_local_mouse_position()
	return _toolbar_rect().has_point(m)


func _toolbar_rect() -> Rect2:
	var s := size()
	var w := 5 * 132.0 + 4 * 10.0
	return Rect2(s.x * 0.5 - w * 0.5, s.y - 112.0, w, 92.0)


func menu_changed() -> void:
	menu_k.target = 1.0 if game.menu_open else 0.0
	menu_confirm = -1


func contract_changed() -> void:
	card_k.target = 1.0 if game.contract_open else 0.0
	if game.contract_open:
		card_t = 0.0


func show_hint(text: String) -> void:
	hint_text = text
	hint_t = 0.0


func white_flash(a: float) -> void:
	flash = maxf(flash, a)


func hurt_flash(amount: float) -> void:
	hurt = maxf(hurt, clampf(amount / 40.0, 0.3, 1.0))


func pop_credits(_amount: float) -> void:
	credit_pop = 1.0


func fly_credits(world_at: Vector2, amount: float) -> void:
	var from := to_screen(world_at)
	var s := size()
	flyers.append([from, Vector2(s.x - 70.0, 76.0), 0.0, amount])


func start_ending(early: bool) -> void:
	ending = true
	end_t = 0.0
	end_early = early
	var g = game
	end_rows = [
		["e_equip", g.income_equip],
		["e_metal", g.income_metal + g.income_hazard],
		["e_fluid", g.sys.gas_value() + g.sys.fluid_value() if g.scope() == "full" else 0.0],
		["e_loss", -g.losses],
		["e_fee_paid" if g.job.get("fee_paid", false) else "e_fee", -g.fee],
	]
	if g.standard_time() > 0.0:
		end_rows.append(["e_bonus", g.bonus()])


# the career's books after this contract: [label key, amount, kind]
func career_rows() -> Array:
	var r: Dictionary = game.career_result
	if r.is_empty():
		return []
	var out: Array = [["e_inst", -float(r.installment), "money"], ["e_interest", -float(r.interest), "money"]]
	if float(r.short) > 0.5:
		out.append(["e_short", float(r.short), "note"])
	var used: Dictionary = r.get("used", {})
	if not used.is_empty():
		var parts: Array = []
		for k in used:
			parts.append("%s ×%d" % [game.txt("it_" + k), int(used[k])])
		out.append(["e_used", ", ".join(parts), "text"])
	out.append(["e_loan_left", float(r.loan), "plain"])
	out.append(["e_funds", float(r.money), "plain"])
	return out


func ending_key(k: int) -> void:
	if end_t < 1.0:
		end_t = 9.0
		return
	if game.career():
		# settled with the career: no second go at the same contract
		if game.story == null or not game.story.wants_epilogue():
			game.leave()
		return
	if k == KEY_R:
		game.restart()
	elif k == KEY_M or k == KEY_ESCAPE:
		game.to_title()


func _input(ev: InputEvent) -> void:
	if game == null:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if game.contract_open and card_t > 0.35:
			var cr := _card_rect(size())
			for ti in 3:
				if _tier_rect(cr, ti).has_point(c.get_local_mouse_position()):
					game.set_tier(Txt.TIERS[ti])
					get_viewport().set_input_as_handled()
					return
			game.close_contract()
			get_viewport().set_input_as_handled()
			return
		if game.menu_open:
			get_viewport().set_input_as_handled()
			_menu_click()
			return
		if ending:
			if end_t < 4.0:
				end_t = 9.0
			elif game.story != null and game.story.phase == "settle":
				game.story.ending_key(KEY_SPACE)
			get_viewport().set_input_as_handled()
			return
		if game.state == "play" and _toolbar_rect().has_point(c.get_local_mouse_position()):
			var i := int((c.get_local_mouse_position().x - _toolbar_rect().position.x) / 142.0)
			game.tools.set_tool(clampi(i + 1, 1, 5))
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if game == null:
		return
	t += dt
	hint_t += dt
	flash = maxf(0.0, flash - dt * 2.5)
	hurt = maxf(0.0, hurt - dt * 1.8)
	credit_pop = maxf(0.0, credit_pop - dt * 3.0)
	card_t += dt
	card_k.step(dt)
	menu_k.step(dt)
	if ending:
		end_t += dt
	if game.state == "play":
		in_t += dt
	elif game.state == "intro":
		in_t = 0.0
	var rt: float = game.recovery_rate() * 100.0
	if rt > rate_last + 0.05:
		rate_sweep = 0.0
		for i in 3:
			if rate_last < [70.0, 80.0, 92.0][i] and rt >= [70.0, 80.0, 92.0][i]:
				mark_pop[i] = 0.0
	rate_last = rt
	rate_sweep += dt
	for i in 3:
		mark_pop[i] += dt
	rate_roll.set_to(rt)
	rate_roll.step(dt)
	# the fresh gain glows, then the trail catches up
	rate_lo = rate_roll.shown if rate_roll.shown < rate_lo else Pal.damp(rate_lo, rate_roll.shown, 1.6, dt)
	_motion_drone(dt)
	credit_roll.set_to(game.earned() - game.losses)
	credit_roll.step(dt)
	var mp := c.get_local_mouse_position()
	var tb := _toolbar_rect()
	if absf(sel_x.target - (game.tools.tool - 1)) > 0.01:
		tool_pulse = 0.0
	sel_x.target = game.tools.tool - 1
	sel_x.step(dt)
	tool_pulse += dt
	for i in 5:
		var on: bool = game.tools.tool == i + 1
		var over := Rect2(tb.position.x + i * 142.0, tb.position.y + 14.0, 132.0, 70.0).has_point(mp)
		slot_y[i].target = -12.0 if on else (-5.0 if over else 0.0)
		slot_y[i].step(dt)
		slot_glow[i] = Pal.damp(slot_glow[i], 1.0 if on else 0.0, 14.0, dt)
	var items: Array = game.mandatory_items()
	must_k.resize(items.size())
	for i in items.size():
		var mk = must_k[i] if must_k[i] != null else 0.0
		var ok: bool = game.mandatory_ok.get(items[i][0], false)
		if ok and not must_t.has(i):
			must_t[i] = t
		elif not ok:
			must_t.erase(i)
		must_k[i] = Pal.damp(mk, 1.0 if ok else 0.0, 8.0, dt)
	for f in flyers:
		f[2] += dt
	var landed := flyers.filter(func(f): return f[2] >= 0.6)
	if not landed.is_empty():
		credit_pop = 1.0
		for f in landed:
			bursts.append([f[1], 0.0])
	for b in bursts:
		b[1] += dt
	bursts = bursts.filter(func(b): return b[1] < 0.45)
	flyers = flyers.filter(func(f): return f[2] < 0.6)
	if game.menu_open:
		_menu_hover()
	cur_t += dt
	cur.target = mp
	cur.step(dt)
	c.queue_redraw()
	fadd.queue_redraw()


func _motion_drone(dt: float) -> void:
	var d = game.drone
	var integ: float = d.integrity if d.alive else 0.0
	if integ < integ_prev - 0.01:
		integ_hold = 0.0
	integ_prev = integ
	integ_hold += dt
	if integ >= integ_ghost:
		integ_ghost = integ
	elif integ_hold > 0.4:
		integ_ghost = Pal.damp(integ_ghost, integ, 5.0, dt)
	integ_roll.set_to(integ)
	integ_roll.step(dt)
	spd_roll.set_to(d.linear_velocity.length() / Geom.M if d.alive else 0.0)
	spd_roll.step(dt)
	stock_pop += dt
	if game.career():
		for id in ["repair", "ring", "spare"]:
			var n: int = game.stock(id)
			if stock_last.has(id) and stock_last[id] != n:
				stock_pop = 0.0
			stock_last[id] = n


# 0 → 1 as the HUD piece `i` comes in after the launch
func _in(i: int) -> float:
	return Pal.ease_out(Motion.stagger(in_t, i, 0.07, 0.55))


# ---------------------------------------------------------------- drawing helpers

func _text(s: String, pos: Vector2, size_px: int, col: Color, f: Font = null, align: int = -1, width: float = -1.0) -> void:
	var fo := f if f != null else font
	var x := pos.x
	if align == 0:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5
	elif align == 1:
		x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	c.draw_string(fo, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, col)


func _tw(s: String, size_px: int, f: Font = null) -> float:
	return (f if f != null else font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x


func _panel(r: Rect2, a: float = 0.82) -> void:
	c.draw_rect(r, Color(0.03, 0.032, 0.037, a))
	c.draw_rect(r, Pal.ink(0.16 * a / 0.82), false, 1.0)


# ---------------------------------------------------------------- main draw

func _draw_hud() -> void:
	if game == null:
		return
	var s := size()
	var g = game
	if g.state == "intro":
		_intro_overlay(s)
		return
	if not ending and g.state != "ending":
		_world_tags()
		_messages()
		_cursor_label()
		if not g.training and g.exam == null:
			c.draw_set_transform(Vector2(-(1.0 - _in(0)) * 420.0, 0.0))
			_contract_panel()
			c.draw_set_transform(Vector2.ZERO)
		_overweight()
		if g.warp:
			_warp(s)
		c.draw_set_transform(Vector2((1.0 - _in(1)) * 380.0, 0.0))
		_credits(s)
		c.draw_set_transform(Vector2.ZERO)
		_toolbar(s)
		c.draw_set_transform(Vector2(0.0, (1.0 - _in(2)) * 140.0))
		_drone_status(s)
		c.draw_set_transform(Vector2.ZERO)
		_hint(s)
		_radio_box(s)
		_text(g.txt("keys"), Vector2(s.x * 0.5, s.y - 10.0), 12, Pal.ink(0.22), font, 0)
	# hurt vignette
	if hurt > 0.0:
		var e := hurt * hurt
		for i in 6:
			var w := 6.0 + i * 10.0
			var a := 0.1 * e * (1.0 - i / 6.0)
			c.draw_rect(Rect2(0, 0, s.x, w), Pal.heat(a))
			c.draw_rect(Rect2(0, s.y - w, s.x, w), Pal.heat(a))
			c.draw_rect(Rect2(0, 0, w, s.y), Pal.heat(a))
			c.draw_rect(Rect2(s.x - w, 0, w, s.y), Pal.heat(a))
	if g.contract_open or card_k.x > 0.01:
		_contract_card(s)
	if menu_k.x > 0.01:
		_menu(s)
	if ending:
		if g.story == null or g.story.phase in ["", "settle"]:
			_settlement(s)
		_radio_box(s)
	elif g.exam != null and g.state == "ending":
		_radio_box(s)
	if flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash * flash * 0.8))


# Liang on the radio (name, waveform, words typing in) or the berth terminal
# (cyan, block cursor), bottom centre above the toolbar
const RADIO_W := 700.0


func _radio_box(s: Vector2) -> void:
	var rd: Radio = game.radio
	var ln: Dictionary = rd.now
	if ln.is_empty():
		return
	var line: Dictionary = ln.line
	var term: bool = line.get("who", "liang") == "term"
	var full: String = rd.text(line)
	var lt: float = ln.t
	var a := clampf(lt / 0.2, 0.0, 1.0) * clampf((ln.dur - lt) / 0.3, 0.0, 1.0)
	var shown := full.substr(0, int(lt * 30.0))
	var w := 820.0
	# a long line wraps to two; the box grows upwards
	var two := _tw(full, 18) > RADIO_W
	var h := 92.0 if two else 64.0
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y - 146.0 - h + (1.0 - Pal.ease_out(clampf(lt / 0.25, 0.0, 1.0))) * 14.0, w, h)
	c.draw_rect(r, Color(0.02, 0.022, 0.026, 0.86 * a))
	c.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), (Pal.tint(Pal.AIR, a, 1.0) if term else Pal.heat(a, 1.0)))
	_text(game.txt("tut_term") if term else game.txt("tut_liang"), r.position + Vector2(18, 22), 12, Pal.ink(0.5 * a), font)
	# the voice as a little waveform while the words come in
	var typing := shown.length() < full.length()
	for i in 14:
		var hgt := 2.0 + (8.0 * absf(sin(t * 17.0 + i * 1.7)) * absf(sin(t * 5.3 + i)) if typing else 1.0)
		c.draw_rect(Rect2(r.position.x + 18 + i * 4.0, r.position.y + 44 - hgt * 0.5, 2, hgt), Pal.ink(0.35 * a))
	var col := Pal.tint(Pal.AIR, 0.95 * a, 1.1) if term else Pal.ink(0.95 * a)
	if two:
		c.draw_multiline_string(font, r.position + Vector2(90, 40), shown, HORIZONTAL_ALIGNMENT_LEFT, RADIO_W, 18, 2, col)
		return
	_text(shown, r.position + Vector2(90, 44), 18, col, font)
	if term and typing:
		var cw := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		c.draw_rect(Rect2(r.position.x + 92 + cw, r.position.y + 30, 9, 16), Pal.tint(Pal.AIR, a * (0.5 + 0.5 * sin(t * 20.0))))


# time warp: chevrons stream across, the factor in the middle
func _warp(s: Vector2) -> void:
	var cx := s.x * 0.5
	for i in 6:
		var ph := fmod(t * 1.6 + i / 6.0, 1.0)
		var a := sin(ph * PI) * 0.8
		for side in [-1.0, 1.0]:
			var x: float = cx + side * (34.0 + ph * 70.0)
			var p := Vector2(x, 34.0)
			c.draw_polyline(PackedVector2Array([p + Vector2(-4, -6), p + Vector2(3, 0), p + Vector2(-4, 6)]), Pal.heat(a, 1.2), 1.6, true)
	_text("×%d" % int(Game.WARP), Vector2(cx, 40), 16, Pal.heat(0.95, 1.3), font_b, 0)


# the grapple refuses a load over its rating, and says so in numbers
func _overweight() -> void:
	var tl = game.tools
	if not tl.overweight or tl.held_piece == null:
		return
	var m: float = tl.held_body.total_mass() if tl.held_body != null and is_instance_valid(tl.held_body) else game.world.group_mass(tl.held_piece)
	var p := to_screen(tl.grab_point()) + Vector2(24, -46)
	var rows := ["TARGET MASS: %.1f t" % m, "RATED CAPACITY: %.1f t" % game.grab_max(), "OPERATION REFUSED"]
	_panel(Rect2(p - Vector2(10, 18), Vector2(230, 70)), 0.86)
	for i in 3:
		_text(rows[i], p + Vector2(0, i * 20), 13, Pal.heat(0.95, 1.2) if i == 2 else Pal.ink(0.85), font_b if i == 2 else font)


func _intro_overlay(s: Vector2) -> void:
	var k := clampf(game.state_t / 0.6, 0.0, 1.0) * clampf((6.0 - game.state_t) / 0.6, 0.0, 1.0)
	# what is coming in: the ship file's own title
	var g = game
	var head: String = g.txt("tut_course") if g.training else ("APPRENTICE ASSESSMENT" if g.exam != null else (g.txt("contract") + " " + g.ship.get("contract", "")).strip_edges())
	var ttl: Array = g.ship.get("title", [])
	_text(head, Vector2(70, s.y - 120), 16, Pal.ink(0.5 * k), font)
	_text((ttl[0] if Txt.zh else ttl[1]) if ttl.size() == 2 else g.ship.get("name", ""), Vector2(70, s.y - 86), 30, Pal.ink(0.9 * k), font_l)
	_text("ESC / SPACE", Vector2(s.x - 70, s.y - 60), 12, Pal.ink(0.3 * k), font, 1)
	# letterbox bars slide away as the drone launches
	var bar := 70.0 * clampf((5.2 - game.state_t) / 0.6, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, s.x, bar), Color(0, 0, 0, 1))
	c.draw_rect(Rect2(0, s.y - bar, s.x, bar), Color(0, 0, 0, 1))


func _contract_panel() -> void:
	var g = game
	var x := 40.0
	var y := 46.0
	_text(g.txt("contract") + " " + g.ship.get("contract", ""), Vector2(x, y), 13, Pal.ink(0.45), font)
	if g.scope() != "full":
		_text(g.txt("sc_" + g.scope()), Vector2(x + 300, y), 13, Pal.heat(0.95, 1.2), font_b, 1)
	_text(g.ship.get("name", ""), Vector2(x, y + 24), 20, Pal.ink(0.92), font_b)
	# mandatory items
	var items: Array = g.mandatory_items()
	for i in items.size():
		var yy := y + 56 + i * 24
		var k: float = must_k[i] if i < must_k.size() else 0.0
		var dc := Vector2(x + 7, yy - 5)
		var dia := PackedVector2Array([dc + Vector2(0, -6), dc + Vector2(6, 0), dc + Vector2(0, 6), dc + Vector2(-6, 0)])
		if k > 0.02:
			var sc := 1.0 + 0.6 * (1.0 - k) * k * 4.0
			var d2 := PackedVector2Array()
			for q in dia:
				d2.append(dc + (q - dc) * sc)
			c.draw_colored_polygon(d2, Pal.ink(0.95 * k))
		var cl := dia.duplicate()
		cl.append(dia[0])
		c.draw_polyline(cl, Pal.ink(0.7), 1.2, true)
		if must_t.has(i) and t - must_t[i] < 0.7:
			var e := Pal.ease_out((t - must_t[i]) / 0.7)
			c.draw_arc(dc, 6.0 + 22.0 * e, 0.0, TAU, 24, Pal.ink(0.8 * (1.0 - e), 1.3), 1.5, true)
			Pal.band(c, Rect2(x + 18, yy - 17, 300.0 * e, 22), 0.12 * (1.0 - e))
		_text(items[i][1] + "  " + items[i][0], Vector2(x + 22, yy), 14, Pal.ink(0.55 + 0.4 * k), font)
	# recovery bar (below however many items the contract asks for)
	var by := maxf(y + 120, y + 56 + items.size() * 24 + 18)
	_text(g.txt("rate"), Vector2(x, by), 13, Pal.ink(0.45), font)
	var pct: float = rate_roll.shown
	_text("%.1f%%" % pct, Vector2(x + 300, by + 2), 22, Pal.ink(0.95), font_l, 1)
	var bw := 300.0
	var br := Rect2(x, by + 12, bw, 4)
	c.draw_rect(br, Pal.ink(0.1))
	var fill := bw * clampf(pct / 100.0, 0.0, 1.0)
	var lo := bw * clampf(rate_lo / 100.0, 0.0, 1.0)
	c.draw_rect(Rect2(br.position, Vector2(lo, 4)), Pal.ink(0.85))
	if fill - lo > 0.5:
		# the gain still glowing hot
		c.draw_rect(Rect2(br.position + Vector2(lo, 0), Vector2(fill - lo, 4)), Pal.heat(1.0, 1.4))
	if rate_sweep < 0.6 and fill > 4.0:
		var sx := fill * Pal.ease_out(rate_sweep / 0.6)
		for j in 6:
			c.draw_rect(Rect2(br.position.x + maxf(0.0, sx - j * 5.0 - 5.0), by + 11, 5, 6), Pal.ink(0.35 * (1.0 - j / 6.0) * (1.0 - rate_sweep / 0.6), 1.5))
	if fill > 1.0:
		c.draw_rect(Rect2(br.position.x + fill - 1.5, by + 10, 3, 8), Pal.ink(0.9, 1.3))
	for mi in 3:
		var mark: float = [70.0, 80.0, 92.0][mi]
		var mx: float = x + bw * mark / 100.0
		var pe := clampf(mark_pop[mi] / 0.6, 0.0, 1.0)
		var grow := 6.0 * (1.0 - Pal.ease_out(pe))
		c.draw_line(Vector2(mx, by + 9 - grow), Vector2(mx, by + 19 + grow), Pal.ink(0.5 if pct < mark else 0.9) if pe >= 1.0 else Pal.heat(1.0, 1.4), 1.0 + grow * 0.3)
		if pe < 1.0:
			c.draw_arc(Vector2(mx, by + 14), 4.0 + 18.0 * Pal.ease_out(pe), 0.0, TAU, 24, Pal.heat(0.8 * (1.0 - pe), 1.3), 1.4, true)
	_text(g.txt("target") + " 70% · 80% · 92%", Vector2(x, by + 36), 12, Pal.ink(0.3), font)
	if g.story != null and not g.story.items.is_empty():
		_text(g.txt("st_found") % [g.story.found_count(), g.story.items.size()], Vector2(x + 300, by + 36), 12, Pal.tint(Pal.AIR, 0.55, 1.0), font, 1)
	elif g.time_limit() > 0.0:
		# a hard stop: the clock runs down, and burns in the last minute
		var left := maxf(0.0, g.time_limit() - g.playtime)
		var hot := left < 60.0
		_text(g.txt("sc_left") + " " + _clock(left), Vector2(x + 300, by + 36), 13 if hot else 12, Pal.heat(0.7 + 0.3 * sin(t * 8.0), 1.3) if hot else Pal.ink(0.55), font_b if hot else font, 1)
	elif g.standard_time() > 0.0:
		# the clock against the standard time: past it, the time bonus starts to shrink
		var late: bool = g.playtime > g.standard_time()
		_text(_clock(g.playtime) + " / " + _clock(g.standard_time()), Vector2(x + 300, by + 36), 12, Pal.heat(0.8, 1.0) if late else Pal.ink(0.45), font, 1)
	var ry := by + 70
	if g.scope() != "full":
		c.draw_rect(Rect2(x - 8, by + 48, 316, 42), Color(0.03, 0.032, 0.037, 0.8))
		c.draw_rect(Rect2(x - 8, by + 48, 2, 42), Pal.heat(0.9, 1.1))
		c.draw_multiline_string(font, Vector2(x, by + 64), Market.scope_text(g.job), HORIZONTAL_ALIGNMENT_LEFT, 300, 12, 2, Pal.ink(0.75))
		ry += 36
	_recall(x, ry)


# training recall cards slide in, then fold into the notes under the contract
func _recall(x: float, y: float) -> void:
	var asst = game.assist
	if asst == null:
		return
	var yy := y
	for cd in asst.cards:
		var e: float = cd[2]
		var k := Pal.ease_out(clampf(e / 0.25, 0.0, 1.0)) * clampf((Assist.CARD_T - e) / 0.4, 0.0, 1.0)
		var r := Rect2(x - (1.0 - k) * 40.0, yy, 300, 46)
		c.draw_rect(r, Color(0.03, 0.032, 0.037, 0.9 * k))
		c.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Pal.tint(Pal.AIR, k, 1.0))
		_text(game.txt("rc_title") + " · " + game.txt("rc_l") % cd[0], r.position + Vector2(14, 18), 12, Pal.tint(Pal.AIR, 0.9 * k, 1.1), font)
		_text(game.txt(cd[1]), r.position + Vector2(14, 37), 15, Pal.ink(0.92 * k), font_b)
		yy += 54
	if asst.notes.is_empty():
		return
	_text(game.txt("notes"), Vector2(x, yy + 10), 12, Pal.ink(0.35), font)
	for i in asst.notes.size():
		var n: Array = asst.notes[i]
		_text("%s  ·  %s" % [game.txt(n[1]), game.txt("rc_l") % n[0]], Vector2(x, yy + 30 + i * 18), 12, Pal.ink(0.5), font)


func _credits(s: Vector2) -> void:
	var g = game
	var x := s.x - 40.0
	_text(g.txt("income"), Vector2(x, 46), 13, Pal.ink(0.45), font, 1)
	var v: float = credit_roll.shown
	var sc := 1.0 + 0.18 * credit_pop * credit_pop
	var txt := Pal.money(v)
	var sz := int(34 * sc)
	_text(txt, Vector2(x, 88), sz, Pal.ink(0.95), font_l, 1)
	var y := 120.0
	for i in g.feed.size():
		var f: Array = g.feed[i]
		var age: float = f[2]
		var slide := 1.0 - Pal.back(clampf(age / 0.35, 0.0, 1.0), 1.4)
		var a: float = clampf((5.0 - age) / 0.8, 0.0, 1.0) * (1.0 - i * 0.14)
		var col := Pal.ink(0.75 * a) if f[1] >= 0 else Pal.heat(0.9 * a, 1.2)
		var amt: String = ("+" if f[1] >= 0 else "") + Pal.money(f[1])
		_text(amt, Vector2(x + slide * 120.0, y + i * 22), 15, col, font_b, 1)
		_text(str(f[0]), Vector2(x - 120 + slide * 120.0, y + i * 22), 13, Pal.ink(0.4 * a), font, 1)


func _toolbar(s: Vector2) -> void:
	var g = game
	var r := _toolbar_rect()
	for i in 5:
		var sx := r.position.x + i * 142.0
		var oy: float = slot_y[i].x + (1.0 - Pal.ease_out(Motion.stagger(in_t, 3 + i, 0.05, 0.5))) * 150.0
		var rect := Rect2(sx, r.position.y + 14.0 + oy, 132.0, 70.0)
		var on: float = slot_glow[i]
		c.draw_rect(rect, Color(0.035, 0.037, 0.042, 0.88))
		c.draw_rect(rect, Pal.ink(0.14 + 0.5 * on), false, 1.0)
		if on > 0.5 and tool_pulse < 0.45:
			var e := Pal.ease_out(tool_pulse / 0.45)
			c.draw_rect(rect.grow(2.0 + 9.0 * e), Pal.heat(0.7 * (1.0 - e), 1.3), false, 1.5)
		_text(str(i + 1), rect.position + Vector2(10, 22), 14, Pal.ink(0.35 + 0.5 * on), font_b)
		var pop := 1.0
		if on > 0.5 and tool_pulse < 0.35:
			pop = 1.0 + 0.35 * sin(clampf(tool_pulse / 0.35, 0.0, 1.0) * PI)
		c.draw_set_transform(rect.position + Vector2(rect.size.x - 30, 26), 0.0, Vector2.ONE * pop)
		_tool_icon(i + 1, Vector2.ZERO, on)
		c.draw_set_transform(Vector2.ZERO)
		_text(g.txt("tool_%d" % (i + 1)), rect.position + Vector2(10, 56), 15, Pal.ink(0.5 + 0.45 * on), font)
		if i == 4:
			var mode: String = g.txt("mode_" + g.tools.hose_mode)
			_text(mode, rect.position + Vector2(rect.size.x - 10, 56), 11, Pal.ink(0.4 + 0.3 * on) if g.tools.hose_mode == "recover" else Pal.heat(0.8, 1.0), font, 1)
	# one marker for the tool in hand: it springs from slot to slot and stretches as it goes
	var sel := clampi(int(round(sel_x.x)), 0, 4)
	var mw := 132.0 + minf(90.0, absf(sel_x.v) * 14.0)
	var mx := r.position.x + sel_x.x * 142.0 + 66.0
	var my: float = r.position.y + 14.0 + 70.0 - 3.0 + slot_y[sel].x + (1.0 - Pal.ease_out(Motion.stagger(in_t, 3 + sel, 0.05, 0.5))) * 150.0
	c.draw_rect(Rect2(mx - mw * 0.5, my, mw, 3), Pal.heat(1.0, 1.0))


func _tool_icon(n: int, p: Vector2, on: float) -> void:
	var col := Pal.ink(0.4 + 0.55 * on)
	match n:
		1:
			c.draw_polyline(PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0), p + Vector2(0, -9)]), col, 1.4, true)
			c.draw_circle(p, 2.0, col)
		2:
			c.draw_line(p + Vector2(-10, 8), p + Vector2(10, -8), Pal.heat(0.4 + 0.6 * on, 1.0 + on), 2.0, true)
			c.draw_circle(p + Vector2(10, -8), 2.5, col)
		3:
			c.draw_arc(p, 9.0, 0.5, PI - 0.5, 12, col, 2.0, true)
			c.draw_arc(p, 9.0, PI + 0.5, TAU - 0.5, 12, col, 2.0, true)
		4:
			c.draw_arc(p, 6.0, 0.0, TAU, 16, col, 1.6, true)
			for k in 6:
				var a := TAU * k / 6.0 + t * on * 0.6
				c.draw_line(p + Vector2.from_angle(a) * 6.0, p + Vector2.from_angle(a) * 10.0, col, 2.0)
		5:
			c.draw_arc(p, 9.0, 0.0, TAU, 20, col, 1.4, true)
			c.draw_arc(p, 4.0, 0.0, TAU, 12, col, 1.2, true)


func _drone_status(s: Vector2) -> void:
	var g = game
	var d = g.drone
	var x := 40.0
	var y := s.y - 70.0
	_text("R-02", Vector2(x, y), 18, Pal.ink(0.9), font_b)
	var integ: float = d.integrity if d.alive else 0.0
	var bw := 180.0
	# a hit shakes the bar; the lost part hangs on in heat, then drains
	var sh := Vector2(sin(t * 71.0), cos(t * 53.0)) * 3.0 * hurt * hurt
	var bx := x + 60 + sh.x
	var byy := y - 10 + sh.y
	c.draw_rect(Rect2(bx, byy, bw, 6), Pal.ink(0.1))
	if integ_ghost > integ + 0.1:
		c.draw_rect(Rect2(bx + bw * integ / 100.0, byy, bw * (integ_ghost - integ) / 100.0, 6), Pal.heat(0.85, 1.3))
	var low: bool = integ <= 35.0 and d.alive
	var col := Pal.ink(0.85) if not low else Pal.heat(0.75 + 0.25 * sin(t * 7.0), 1.2)
	c.draw_rect(Rect2(bx, byy, bw * integ / 100.0, 6), col)
	if low:
		c.draw_rect(Rect2(bx - 3, byy - 3, bw + 6, 12), Pal.heat(0.35 + 0.3 * sin(t * 7.0), 1.2), false, 1.0)
	_text(g.txt("integrity") + "  %d%%" % int(round(integ_roll.shown)), Vector2(x + 60, y + 16), 12, Pal.ink(0.4), font)
	d.assist_k = Pal.damp(d.assist_k, 1.0 if d.assist else 0.0, 14.0, get_process_delta_time())
	var sw := Rect2(x + 60 + bw + 26, y - 14, 34, 14)
	c.draw_rect(sw, Pal.ink(0.08 + 0.1 * d.assist_k))
	c.draw_rect(sw, Pal.ink(0.35 + 0.4 * d.assist_k), false, 1.0)
	c.draw_rect(Rect2(sw.position + Vector2(2 + 18 * d.assist_k, 2), Vector2(12, 10)), Pal.ink(0.5 + 0.45 * d.assist_k) if d.assist else Pal.ink(0.35))
	_text("F " + game.txt("assist"), Vector2(sw.end.x + 8, y - 2), 12, Pal.ink(0.4 + 0.4 * d.assist_k), font)
	_text("%.1f m/s" % spd_roll.shown, Vector2(x + 60 + bw, y + 16), 12, Pal.ink(0.55), font, 1)
	if not d.alive:
		_text("R-02 …", Vector2(x, y - 30), 14, Pal.heat(0.9, 1.2), font)
	# consumables in hand for this contract
	if g.career():
		var parts: Array = []
		for it in [["repair", "6"], ["ring", "7"], ["spare", ""]]:
			var n: int = g.stock(it[0])
			if n > 0:
				parts.append(("%s %s ×%d" % [it[1], g.txt("it_" + it[0]), n]).strip_edges())
		if not parts.is_empty():
			var sp := clampf(stock_pop / 0.6, 0.0, 1.0)
			_text("   ·   ".join(parts), Vector2(x, y - 34 - 4.0 * sin(sp * PI)), 12, Pal.ink(0.5) if sp >= 1.0 else Pal.heat(0.6 + 0.4 * (1.0 - sp), 1.2), font)


func _hint(s: Vector2) -> void:
	if hint_text == "" or hint_t > 9.0:
		return
	var a := clampf(hint_t / 0.3, 0.0, 1.0) * clampf((9.0 - hint_t) / 0.6, 0.0, 1.0)
	var w := minf(980.0, _tw(hint_text, 16) + 60.0)
	var lines := 1
	if _tw(hint_text, 16) > 920.0:
		lines = 2
	# above Liang's radio box while he is talking
	var lift := 0.0
	if not game.radio.now.is_empty():
		lift = 104.0 if _tw(game.radio.text(game.radio.now.line), 18) > RADIO_W else 76.0
	var r := Rect2(s.x * 0.5 - w * 0.5, s.y - 160.0 - lift - lines * 22.0 - (1.0 - Pal.ease_out(a)) * 10.0, w, 18.0 + lines * 22.0)
	var ow := w * (Pal.ease_out(clampf(hint_t / 0.24, 0.0, 1.0)) if hint_t < 1.0 else 1.0)
	var ta := a * clampf((hint_t - 0.1) / 0.2, 0.0, 1.0)
	var ro := Rect2(s.x * 0.5 - ow * 0.5, r.position.y, ow, r.size.y)
	c.draw_rect(ro, Color(0.03, 0.032, 0.037, 0.85 * a))
	c.draw_rect(Rect2(ro.position, Vector2(3, ro.size.y)), Pal.heat(a, 1.0))
	c.draw_multiline_string(font, r.position + Vector2(22, 26 + (1.0 - ta) * 4.0), hint_text, HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 16, lines, Pal.ink(0.88 * ta))


# readings: tags anchored on the ship
func _world_tags() -> void:
	var g = game
	var w = g.world
	var mouse := c.get_local_mouse_position()
	var hovered = null
	var rects: Array = []
	for key in g.sys.readings:
		var r: Dictionary = g.sys.readings[key]
		var anchor := Vector2.INF
		if r.has("ctrl"):
			if not w.ctrl_alive(r.ctrl):
				continue
			anchor = w.ctrl_world(r.ctrl)
		elif r.has("piece"):
			if r.piece.gone:
				continue
			anchor = w.frame(r.piece) * r.local
		elif r.has("anchor_pos"):
			anchor = r.anchor_pos
		if anchor == Vector2.INF:
			continue
		var sp := to_screen(anchor)
		if not Rect2(Vector2(-200, -200), size() + Vector2(400, 400)).has_point(sp):
			continue
		if not tag_birth.has(key) or tag_birth[key][0] != r.t:
			tag_birth[key] = [r.t, t]
		var age: float = t - tag_birth[key][1]
		var stale: bool = g.sys.stale(r)
		var label: String = r.at
		var val: String = r.text
		if age < 0.45 and not stale:
			# digits tumble before they settle
			var sc := ""
			for ch in val:
				sc += str(randi() % 10) if ch >= "0" and ch <= "9" else ch
			val = sc
		if r.has("inspect"):
			val = r.inspect + "  ·  " + r.text
			# a story piece: the tag opens into a small card
			if g.story != null:
				var it = g.story.item_for(r.piece)
				if it != null and g.story.found.has(it.id):
					rects.append(_story_card(sp, it, val, age))
					continue
		var off := Vector2(16, -26)
		if key.ends_with("/T") or key.ends_with("/V"):
			off = Vector2(16, -6)
		var pos := sp + off
		for prev in rects:
			if prev.intersects(Rect2(pos - Vector2(0, 16), Vector2(160, 22))):
				pos.y = prev.position.y - 10.0
		var tw := _tw(label, 12) + _tw(val, 15, font_b) + 30.0
		var rect := Rect2(pos - Vector2(0, 16), Vector2(tw, 22))
		rects.append(rect)
		var pop := Pal.back(clampf(age / 0.25, 0.0, 1.0), 2.0)
		var a := 1.0 if not stale else 0.5
		c.draw_line(sp, pos + Vector2(0, 6), Pal.ink(0.3 * a), 1.0, true)
		c.draw_circle(sp, 2.5, Pal.ink(0.8 * a))
		var rr := Rect2(rect.position, Vector2(rect.size.x * pop, rect.size.y))
		c.draw_rect(rr, Color(0.03, 0.032, 0.037, 0.88))
		c.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), _kind_col(r.kind, a))
		if pop > 0.6:
			_text(label, pos + Vector2(8, 0), 12, Pal.ink(0.45 * a), font)
			var vcol := Pal.ink(0.95 * a) if not stale else Pal.ink(0.4)
			var vx := pos.x + 16 + _tw(label, 12)
			_text(val, Vector2(vx, pos.y + 1), 15, vcol, font_b)
			if stale:
				c.draw_line(Vector2(vx - 2, pos.y - 5), Vector2(vx + _tw(val, 15, font_b) + 2, pos.y - 5), Pal.ink(0.5), 1.0)
		if rect.has_point(mouse):
			hovered = [r, rect, stale]
	if hovered != null:
		var r: Dictionary = hovered[0]
		var rect: Rect2 = hovered[1]
		var lines := [
			"%s  %s" % [game.txt("read_by"), game.txt(r.inst)],
			"%s  %s" % [game.txt("read_at"), r.at],
			"%s  T+%s" % [game.txt("read_time"), _clock(r.t)],
		]
		if hovered[2]:
			lines.append(game.txt("stale"))
		var box := Rect2(rect.position + Vector2(0, 26), Vector2(260, 22 * lines.size() + 10))
		_panel(box, 0.92)
		for i in lines.size():
			_text(lines[i], box.position + Vector2(10, 22 + i * 22), 13, Pal.ink(0.7) if i < 3 else Pal.heat(0.9, 1.0), font)


func _story_card(sp: Vector2, it: Dictionary, info: String, age: float) -> Rect2:
	var st: Story = game.story
	var body: String = st.pair(it.text)
	var w := 340.0
	var bh: float = font_b.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 15).y
	var pos := sp + Vector2(18, -40 - bh)
	var r := Rect2(pos, Vector2(w, bh + 56))
	var pop := Pal.back(clampf(age / 0.25, 0.0, 1.0), 2.0)
	c.draw_line(sp, pos + Vector2(0, r.size.y), Pal.tint(Pal.AIR, 0.4, 1.0), 1.0, true)
	c.draw_circle(sp, 2.5, Pal.tint(Pal.AIR, 0.9, 1.1))
	var rr := Rect2(r.position, Vector2(r.size.x * pop, r.size.y))
	c.draw_rect(rr, Color(0.03, 0.032, 0.037, 0.92))
	c.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), Pal.tint(Pal.AIR, 0.9, 1.1))
	if pop > 0.6:
		_text(st.pair(it.title), pos + Vector2(14, 18), 12, Pal.tint(Pal.AIR, 0.75, 1.0), font)
		c.draw_multiline_string(font_b, pos + Vector2(14, 40), body, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 15, -1, Pal.ink(0.95))
		_text(info, pos + Vector2(14, r.size.y - 8), 11, Pal.ink(0.35), font)
	return r


func _clock(sec: float) -> String:
	return "%02d:%02d" % [int(sec) / 60, int(sec) % 60]


func _kind_col(kind: String, a: float) -> Color:
	match kind:
		"pressure": return Pal.tint(Pal.AIR, a)
		"volts": return Pal.tint(Pal.VOLT, a)
		"fluid", "temp": return Pal.tint(Pal.FLUID, a)
	return Pal.ink(0.6 * a)


func _messages() -> void:
	for m in game.messages:
		var age: float = m[2]
		var sp := to_screen(m[1])
		var a := clampf(age / 0.12, 0.0, 1.0) * clampf((2.6 - age) / 0.5, 0.0, 1.0)
		var y := sp.y - 30.0 - Pal.ease_out(age / 2.6) * 26.0
		var txt: String = m[3]
		var w := _tw(txt, 15)
		c.draw_rect(Rect2(sp.x - w * 0.5 - 8, y - 17, w + 16, 24), Color(0.02, 0.022, 0.026, 0.7 * a))
		_text(txt, Vector2(sp.x, y), 15, Pal.ink(0.95 * a), font, 0)


func _cursor_label() -> void:
	var g = game
	var h: Dictionary = g.tools.hover
	var mp := c.get_local_mouse_position()
	if g.tools.tool == 2 or h.is_empty():
		cur_key = ""
		return
	var name := ""
	var act := ""
	match h.kind:
		"ctrl":
			name = h.ctrl.id
			act = _ctrl_action(h.ctrl)
		"joint":
			name = h.label if h.label != "" else g.txt("j_" + h.joint.type)
			act = g.txt({"bolt": "act_unbolt", "lock": "act_unlock", "clamp": "act_clamp"}[h.joint.type])
		"connector":
			name = h.label
			act = g.txt("act_unplug")
		"line":
			name = h.label
			act = g.txt("act_measure")
		"piece", "inspect":
			name = Txt.piece_name(h.piece)
			var m: float = g.world.group_mass(h.piece)
			act = ("%.2f t" % m) if g.tools.tool == 3 else g.txt("act_inspect")
			if not h.piece.scope:
				act += "  ·  " + g.txt("sc_out")
	if not h.ok:
		act = g.txt(h.reason)
	if name != cur_key:
		if cur_key == "":
			cur.snap(mp)
		cur_key = name
		cur_t = 0.0
	var la := clampf(cur_t / 0.12, 0.0, 1.0)
	var pos := cur.x + Vector2(22, 30 + (1.0 - Pal.ease_out(la)) * 6.0)
	var w := maxf(_tw(name, 14), _tw(act, 13)) + 20.0
	c.draw_rect(Rect2(pos - Vector2(8, 16), Vector2(w, 42)), Color(0.02, 0.022, 0.026, 0.82 * la))
	c.draw_rect(Rect2(pos - Vector2(8, 16), Vector2(2, 42 * Pal.ease_out(la))), Pal.ink(0.4 * la))
	_text(name, pos, 14, Pal.ink(0.95 * la), font_b)
	var heavy: bool = g.tools.tool == 3 and h.kind == "piece" and g.world.group_mass(h.piece) > g.grab_max()
	_text(act, pos + Vector2(0, 19), 13, Pal.heat(0.9 * la, 1.1) if (not h.ok or heavy) else Pal.ink(0.55 * la), font)


func _ctrl_action(ctrl) -> String:
	var g = game
	match g.tools.tool:
		1: return g.txt("act_measure")
		5: return g.txt("act_hose_off") if g.sys.hoses.has(ctrl.id) else g.txt("act_hose_on")
	match ctrl.kind:
		"valve": return g.txt("act_valve_close") if ctrl.state else g.txt("act_valve_open")
		"switch": return g.txt("act_switch_off") if ctrl.state else g.txt("act_switch_on")
		"remote": return g.txt("act_remote")
		"stop": return g.txt("act_stop")
		"socket": return g.txt("act_socket")
		"discharge": return g.txt("act_discharge")
		"door": return g.txt("act_door")
		"hatch": return g.txt("act_hatch")
		"jam": return g.txt("act_jam")
	return ""


# ---------------------------------------------------------------- contract card

func _card_rect(s: Vector2) -> Rect2:
	var k: float = clampf(card_k.x, 0.0, 1.2)
	return Rect2(s.x * 0.5 - 450.0, s.y * 0.5 - 340.0 + (1.0 - k) * 60.0, 900.0, 680.0)


func _tier_rect(r: Rect2, i: int) -> Rect2:
	return Rect2(r.position.x + 48 + i * 270.0, r.end.y - 92.0, 256.0, 52.0)


func _contract_card(s: Vector2) -> void:
	var k: float = clampf(card_k.x, 0.0, 1.2)
	var a := clampf(k, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55 * a))
	var w := 900.0
	var r := _card_rect(s)
	_panel(r, 0.95 * a)
	c.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Pal.heat(a, 1.0))
	var g = game
	var x := r.position.x + 48
	var y := r.position.y + 58
	var rows: Array = _offer_rows() if g.job.has("reg") else []
	if rows.is_empty():
		rows.append(["h", g.txt("c_title"), 14])
		rows.append(["t", g.txt("ship"), 30])
		rows.append(["gap", "", 12])
		rows.append(["h", g.txt("c_req"), 13])
		for i in range(1, 5):
			rows.append(["li", g.txt("c_req%d" % i), 16])
		rows.append(["gap", "", 10])
		rows.append(["h", g.txt("c_log"), 13])
		for i in range(1, 6):
			rows.append(["kv", g.txt("c_log%d" % i), g.txt("c_log%dv" % i)])
		rows.append(["gap", "", 10])
		rows.append(["p", g.txt("c_brief"), 15])
		rows.append(["p", g.txt("c_drawing"), 15])
		rows.append(["gap", "", 6])
		rows.append(["h", g.txt("c_fee"), 13])
	var i := 0
	for row in rows:
		var rk := Motion.stagger(card_t, i, 0.03, 0.3)
		var ra := a * rk
		var dx := (1.0 - Pal.ease_out(rk)) * 24.0
		match row[0]:
			"h":
				_text(row[1], Vector2(x + dx, y), row[2], Pal.ink(0.45 * ra), font)
				y += 26
			"t":
				_text(row[1], Vector2(x + dx, y + 8), row[2], Pal.ink(0.95 * ra), font_l)
				y += 40
			"li":
				c.draw_circle(Vector2(x + 6 + dx, y - 5), 2.0, Pal.ink(0.7 * ra))
				_text(row[1], Vector2(x + 20 + dx, y), row[2], Pal.ink(0.85 * ra), font)
				y += 25
			"kv":
				_text(row[1], Vector2(x + 20 + dx, y), 15, Pal.ink(0.55 * ra), font)
				_text(row[2], Vector2(x + 300 + dx, y), 15, Pal.ink(0.9 * ra), font_b)
				y += 24
			"p":
				c.draw_multiline_string(font, Vector2(x + dx, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, w - 100, row[2], 3, Pal.ink(0.75 * ra))
				y += 48
			"gap":
				y += row[2]
		i += 1
	# the hint tier: chosen here, the same ship in all three
	var ty := r.end.y - 104.0
	_text(g.txt("tier_label") + "  ·  1 / 2 / 3", Vector2(x, ty), 13, Pal.ink(0.45 * a), font)
	var m := c.get_local_mouse_position()
	for ti in 3:
		var tid: String = Txt.TIERS[ti]
		var br := _tier_rect(r, ti)
		var on: bool = Txt.hint_tier == tid
		c.draw_rect(br, Color(0.04, 0.042, 0.048, 0.9 * a))
		c.draw_rect(br, Pal.ink((0.7 if on else (0.35 if br.has_point(m) else 0.16)) * a), false, 1.2)
		if on:
			c.draw_rect(Rect2(br.position.x, br.end.y - 2, br.size.x, 2), Pal.heat(a, 1.0))
		_text(str(ti + 1) + "  " + g.txt("tier_" + tid), br.position + Vector2(14, 22), 15, Pal.ink((0.95 if on else 0.6) * a), font_b if on else font)
		_text(g.txt("tier_desc_" + tid), br.position + Vector2(14, 42), 11, Pal.ink(0.4 * a), font)
	_text(g.txt("tier_rule"), Vector2(x, r.end.y - 22), 12, Pal.ink(0.3 * a), font)
	var pulse := 0.6 + 0.4 * sin(t * 3.0)
	_text(g.txt("c_start"), Vector2(r.end.x - 48, r.end.y - 22), 16, Pal.ink(pulse * a), font_b, 1)


# a contract from the market: its card is the offer the player took
func _offer_rows() -> Array:
	var g = game
	var o: Dictionary = g.job
	var ty: Dictionary = Market.TYPES.get(o.get("ship", ""), {})
	var rows: Array = []
	rows.append(["h", g.txt("c_title_n") % o.get("id", ""), 14])
	rows.append(["t", "%s  ·  %s · %d m" % [o.get("reg", ""), (ty.name[0] if Txt.zh else ty.name[1]) if not ty.is_empty() else "", int(ty.get("length", 0))], 30])
	rows.append(["gap", "", 12])
	rows.append(["h", g.txt("c_req"), 13])
	rows.append(["li", g.txt("c_req1"), 16])
	rows.append(["li", g.txt("c_req2"), 16])
	rows.append(["li", g.txt("c_req3_n") % Pal.money(float(o.get("value", 0.0))), 16])
	rows.append(["li", g.txt("c_req4"), 16])
	rows.append(["gap", "", 10])
	rows.append(["h", g.txt("tm_reason"), 13])
	rows.append(["p", Copy.slot(o.get("reason", "")), 15])
	rows.append(["h", g.txt("c_log_n"), 13])
	for lid in o.get("logs", []):
		rows.append(["li", Copy.slot(lid), 16])
	rows.append(["gap", "", 6])
	rows.append(["p", g.txt("c_drawing"), 15])
	if o.get("scope", "full") != "full":
		rows.append(["h", g.txt("sc_" + o.scope), 13])
		rows.append(["p", Market.scope_text(o), 15])
	rows.append(["h", g.txt("c_fee_n") % [Pal.money(float(o.get("fee", 0.0))), int(float(o.get("time", 0.0)) / 60.0)], 13])
	return rows


# ---------------------------------------------------------------- pause menu

func _menu_items() -> Array:
	var g = game
	if g.exam != null:
		return [
			["resume", g.txt("m_resume")],
			["abandon", g.txt("m_abandon") if menu_confirm != 1 else g.txt("m_confirm")],
			["settings", g.txt("m_settings")],
			["title", g.txt("m_title") if menu_confirm != 4 else g.txt("m_confirm")],
		]
	if g.training:
		return [
			["resume", g.txt("m_resume")],
			["skip", g.txt("m_skip") if menu_confirm != 1 else g.txt("m_confirm")],
			["settings", g.txt("m_settings")],
			["hints", g.txt("m_hints") if g.hints_on else g.txt("m_hints_off")],
			["title", g.txt("m_title") if menu_confirm != 4 else g.txt("m_confirm")],
		]
	return [
		["resume", g.txt("m_resume")],
		["end", g.txt("m_end") if menu_confirm != 1 else g.txt("m_confirm")],
		["settings", g.txt("m_settings")],
		["hints", g.txt("m_tier") % g.txt("tier_" + Txt.hint_tier)],
		["title", g.txt("m_title") if menu_confirm != 4 else g.txt("m_confirm")],
	]


func _menu_rect(i: int) -> Rect2:
	var s := size()
	return Rect2(s.x * 0.5 - 220, s.y * 0.5 - 120 + i * 58, 440, 48)


func _menu_hover() -> void:
	var m := c.get_local_mouse_position()
	menu_hover = -1
	for i in 5:
		if _menu_rect(i).has_point(m):
			menu_hover = i


func _menu_click() -> void:
	if menu_hover < 0:
		return
	var id: String = _menu_items()[menu_hover][0]
	game.sfx.play("ok")
	match id:
		"resume":
			game.toggle_menu()
		"end":
			if menu_confirm == 1:
				game.toggle_menu()
				game.finish_contract(true)
			else:
				menu_confirm = 1
		"abandon":
			if menu_confirm == 1:
				game.toggle_menu()
				game.exam.abandon()
			else:
				menu_confirm = 1
		"skip":
			if menu_confirm == 1:
				game.toggle_menu()
				game.skip_training()
			else:
				menu_confirm = 1
		"settings":
			game.settings_panel.open()
		"hints":
			if game.training:
				game.toggle_hints()
			else:
				game.cycle_tier()
		"title":
			if menu_confirm == 4:
				game.to_title()
			else:
				menu_confirm = 4


func _menu(s: Vector2) -> void:
	var k: float = clampf(menu_k.x, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6 * k))
	_text(game.txt("m_paused"), Vector2(s.x * 0.5, s.y * 0.5 - 170), 30, Pal.ink(0.9 * k), font_l, 0)
	var items := _menu_items()
	for i in items.size():
		var r := _menu_rect(i)
		var rk := Motion.stagger(menu_k.x * 0.6, i, 0.04, 0.2)
		r.position.y += (1.0 - rk) * 20.0
		if i == menu_hover:
			Pal.band(c, r, 0.12 * k)
			c.draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 40, r.end.y - 2, 80, 2), Pal.heat(k, 1.0))
		_text(items[i][1], Vector2(r.get_center().x, r.position.y + 32), 20, Pal.ink((0.95 if i == menu_hover else 0.6) * k * rk), font, 0)
	if menu_confirm == 1 and not game.training and game.exam == null:
		_text(game.txt("end_warn"), Vector2(s.x * 0.5, _menu_rect(items.size()).position.y + 24), 14, Pal.heat(0.85 * k, 1.0), font, 0)


# ---------------------------------------------------------------- settlement

func _settlement(s: Vector2) -> void:
	var g = game
	var e := end_t - (0.2 if end_early else 1.6)
	if e < 0.0:
		return
	var a := clampf(e / 0.5, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.62 * a))
	var cx := s.x * 0.5
	var y := s.y * 0.5 - 300.0
	# the sheet the books are written on: it rises into place
	var pk := Pal.ease_out(clampf(e / 0.45, 0.0, 1.0))
	var sheet := Rect2(cx - 330, y - 50 + (1.0 - pk) * 40.0, 660, (850.0 if not career_rows().is_empty() else 720.0))
	c.draw_rect(sheet, Color(0.022, 0.024, 0.029, 0.98 * pk))
	c.draw_rect(sheet, Pal.ink(0.1 * pk), false, 1.0)
	c.draw_rect(Rect2(sheet.position, Vector2(sheet.size.x * pk, 2)), Pal.heat(pk, 1.2))
	_text(g.txt("e_done") if not end_early else g.txt("e_early"), Vector2(cx, y), 20, Pal.ink(0.7 * a), font, 0)
	_text(g.txt("e_contract") + " " + g.ship.get("contract", "") + " · " + (g.txt("e_must_ok") if g.all_mandatory_ok() else g.txt("e_must_no")), Vector2(cx, y + 30), 14, Pal.ink(0.45 * a), font, 0)
	# the big number rolls up
	var rk := clampf((e - 0.3) / 1.1, 0.0, 1.0)
	var pct: float = g.recovery_rate() * 100.0 * Pal.ease_out(rk)
	var slam := Pal.back(clampf((e - 0.3) / 0.3, 0.0, 1.0), 2.6)
	_text("%.1f%%" % pct, Vector2(cx, y + 130), int(96 * slam) if slam > 0.05 else 1, Pal.ink(0.98 * a), font_l, 0)
	_text(g.txt("e_rate"), Vector2(cx, y + 166), 15, Pal.ink(0.5 * a), font, 0)
	var ry := y + 220.0
	for i in end_rows.size():
		var re := e - 1.5 - i * 0.32
		if re < 0.0:
			break
		var rs := Pal.back(clampf(re / 0.22, 0.0, 1.0), 2.2)
		var row: Array = end_rows[i]
		var v: float = row[1]
		var col := Pal.ink(0.9) if v >= 0 else Pal.heat(0.95, 1.1)
		var dy := (1.0 - rs) * -18.0
		_text(g.txt(row[0]), Vector2(cx - 260, ry + i * 34 + dy), 17, Pal.ink(0.55 * clampf(re / 0.15, 0.0, 1.0)), font)
		_text(("+" if v > 0.5 else "") + Pal.money(v), Vector2(cx + 260, ry + i * 34 + dy), int(20 * (0.7 + 0.3 * rs)), col, font_b, 1)
	var ne := e - 1.5 - end_rows.size() * 0.32 - 0.3
	if ne > 0.0:
		var ns := Pal.back(clampf(ne / 0.3, 0.0, 1.0), 2.4)
		var ny := ry + end_rows.size() * 34 + 30
		c.draw_line(Vector2(cx - 260, ny - 28), Vector2(cx + 260, ny - 28), Pal.ink(0.25), 1.0)
		_text(g.txt("e_net"), Vector2(cx - 260, ny + 10), 18, Pal.ink(0.7), font)
		_text(Pal.money((g.net() + g.bonus()) * Pal.ease_out(clampf(ne / 0.8, 0.0, 1.0))), Vector2(cx + 260, ny + 14), int(44 * ns) if ns > 0.05 else 1, Pal.ink(0.98), font_l, 1)
		var tl: String = g.txt("e_time") + "  " + _clock(g.playtime)
		if g.standard_time() > 0.0:
			tl += "  /  " + g.txt("e_standard") + "  " + _clock(g.standard_time())
		_text(tl, Vector2(cx - 260, ny + 46), 14, Pal.ink(0.4), font)
		var crows := career_rows()
		for i in crows.size():
			var ce := ne - 0.6 - i * 0.18
			if ce < 0.0:
				break
			var ca := clampf(ce / 0.2, 0.0, 1.0)
			var cy := ny + 92 + i * 30
			var row: Array = crows[i]
			_text(g.txt(row[0]), Vector2(cx - 260, cy), 15, Pal.ink(0.5 * ca), font)
			if row[2] == "text":
				_text(str(row[1]), Vector2(cx + 260, cy), 15, Pal.ink(0.85 * ca), font, 1)
				continue
			var v: float = row[1]
			var vt := Pal.money(v) if row[2] != "note" else "+" + Pal.money(v)
			var col := Pal.heat(0.9 * ca, 1.1) if (row[2] == "money" and v < -0.5) or row[2] == "note" else Pal.ink(0.85 * ca)
			_text(vt, Vector2(cx + 260, cy), 17, col, font_b, 1)
	var te := e - 1.8
	var traps: Array = g.job.get("traps", [])
	if te > 0.0 and not traps.is_empty():
		_trap_rows(traps, Vector2(cx + 380, ry + 10), te)
	var ge := ne - 0.9
	if ge > 0.0:
		_stamp(Vector2(cx + 330, y + 100), ge)
		var pulse := 0.5 + 0.4 * sin(t * 3.0)
		var go: String = g.txt("st_go_on") if g.story != null and g.story.wants_epilogue() else g.txt("e_to_terminal" if g.career() else "e_again")
		_text(go, Vector2(cx, s.y - 80), 16, Pal.ink(pulse), font_b, 0)


# the contract's signature traps: avoided or not, and the review note where one bit
func _trap_rows(traps: Array, at: Vector2, e: float) -> void:
	var a := clampf(e / 0.3, 0.0, 1.0)
	var card := Rect2(at + Vector2(-24, -36 + (1.0 - Pal.ease_out(a)) * 20.0), Vector2(528, 60 + traps.size() * 78))
	c.draw_rect(card, Color(0.022, 0.024, 0.029, 0.98 * a))
	c.draw_rect(card, Pal.ink(0.1 * a), false, 1.0)
	c.draw_rect(Rect2(card.position, Vector2(3, card.size.y * a)), Pal.heat(a, 1.1))
	_text(game.txt("e_traps"), at, 15, Pal.ink(0.5 * a), font)
	var yy := at.y + 34.0
	for i in traps.size():
		var ra := clampf((e - 0.2 - i * 0.2) / 0.2, 0.0, 1.0)
		var t: String = traps[i]
		var hit := Traps.bit(t, game.incidents)
		_text(Copy.slot("N_" + t), Vector2(at.x, yy), 17, Pal.ink(0.9 * ra), font_b)
		_text(game.txt("e_trap_hit" if hit else "e_trap_ok"), Vector2(at.x + 480, yy), 15, Pal.heat(0.9 * ra, 1.1) if hit else Pal.ink(0.6 * ra), font, 1)
		yy += 26.0
		if hit:
			c.draw_multiline_string(font, Vector2(at.x, yy), Copy.slot("V_" + t), HORIZONTAL_ALIGNMENT_LEFT, 480, 13, 2, Pal.ink(0.6 * ra))
			yy += 40.0
		yy += 8.0


func grade() -> int:
	var g = game
	var r: float = g.recovery_rate()
	if not g.all_mandatory_ok() or r < 0.7:
		return 0
	if r >= 0.92:
		return 3
	if r >= 0.8:
		return 2
	return 1


func _stamp(p: Vector2, e: float) -> void:
	var gr := grade()
	var k := Pal.back(clampf(e / 0.25, 0.0, 1.0), 3.0)
	var sc := lerpf(2.2, 1.0, clampf(e / 0.2, 0.0, 1.0))
	var a := clampf(e / 0.12, 0.0, 1.0)
	var col := Pal.heat(a, 1.2) if gr == 0 else Pal.ink(a)
	var r := 74.0 * sc
	c.draw_set_transform(p, -0.18, Vector2.ONE)
	c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, col, 3.0, true)
	c.draw_arc(Vector2.ZERO, r - 8, 0.0, TAU, 48, Color(col.r, col.g, col.b, col.a * 0.5), 1.0, true)
	var txt := game.txt("grade_%d" % gr)
	var w := _tw(txt, int(28 * sc), font_b)
	c.draw_string(font_b, Vector2(-w * 0.5, 10 * sc), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * sc), col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e < 0.3 and k > 0.0:
		game.shake(0.02)


func _draw_add() -> void:
	if game == null:
		return
	var tex: Texture2D = game.fx.glow_tex
	for f in flyers:
		for j in 5:
			var k: float = maxf(0.0, f[2] / 0.6 - j * 0.035)
			var e := Pal.ease_in(k)
			var p: Vector2 = (f[0] as Vector2).lerp(f[1], e) + Vector2(0, -sin(k * PI) * 80.0)
			var r := (10.0 + 6.0 * (1.0 - k)) * (1.0 - j * 0.17)
			fadd.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Pal.ink(0.9 * (1.0 - j * 0.2), 1.6))
	for b in bursts:
		var e := Pal.ease_out(b[1] / 0.45)
		fadd.draw_arc(b[0], 6.0 + 30.0 * e, 0.0, TAU, 32, Pal.ink(0.6 * (1.0 - e), 1.5), 2.0, true)
	if credit_pop > 0.0:
		var s := size()
		fadd.draw_texture_rect(tex, Rect2(Vector2(s.x - 260, 40), Vector2(240, 70)), false, Pal.ink(0.12 * credit_pop, 1.4))
