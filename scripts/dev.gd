class_name DevPanel
extends CanvasLayer
# Developer mode, for testing by hand: F12 anywhere turns it on or off (kept
# in the settings). While on, a small panel at the top right lists what the
# F keys do here, and they do it.
#   On site:   F1 x-ray (the ship's true state)   F2 make it safe   F3 free every piece
#              F4 drone can't be hurt   F5 time ×8   F6 open every room   F7 +3 of each consumable
#              F8 end the contract now
#   Terminal:  F1 +$100,000   F2 clear the loan   F3 +5 reputation   F4 every upgrade
#              F5 +3 of each consumable   F6 new offers   F7 a contract with one chosen trap

static var god := false          # the drone takes no damage
static var warp := false         # time ×8 on site
static var xray := false

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
				["F5", "dev_warp", warp], ["F6", "dev_rooms", null], ["F7", "dev_items", null], ["F8", "dev_end", null]]
		"terminal":
			return [["F1", "dev_money", null], ["F2", "dev_loan", null], ["F3", "dev_rep", null], ["F4", "dev_upgrades", null],
				["F5", "dev_items", null], ["F6", "dev_offers", null], ["F7", "dev_trap", null]]
	return []


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var key: int = ev.physical_keycode
	if key == KEY_F12:
		Txt.dev = not Txt.dev
		Txt.save_settings(game != null and game.testing)
		say(Txt.t("dev_on") if Txt.dev else Txt.t("dev_off"))
		get_viewport().set_input_as_handled()
		return
	if not Txt.dev or key < KEY_F1 or key > KEY_F8:
		return
	get_viewport().set_input_as_handled()
	if where == "game":
		_game_key(key - KEY_F1 + 1)
	elif where == "terminal":
		_terminal_key(key - KEY_F1 + 1)


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
		3:
			for j in g.world.joints:
				if j.alive:
					g.world.kill_joint(j)
			for id in g.world.lines:
				g.world.kill_line(g.world.lines[id])
		4:
			god = not god
		5:
			warp = not warp
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
	say(Txt.t(rows()[n - 1][1]))


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
			for id in ["scan_kit", "grapple5", "pump2", "arm", "mouth_rail", "net05", "hauler"]:
				d.upgrades[id] = 1
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
					if d.offers.is_empty():
						d.offers = [o]
					else:
						d.offers[0] = o
					terminal.dealt()
					break
			say(Txt.t("dev_trap") + "：" + tr)
			Career.save()
			return
	Career.save()
	say(Txt.t(rows()[n - 1][1]))


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


func _draw_panel() -> void:
	var s := c.size
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
	var pw := 260.0
	var ph := 40.0 + rs.size() * 22.0
	var x := s.x - 20.0 - pw + (1.0 - Pal.ease_out(k)) * 40.0
	var r2 := Rect2(x, 130.0, pw, ph)
	c.draw_rect(r2, Color(0.02, 0.02, 0.025, 0.82 * k))
	c.draw_rect(Rect2(r2.position, Vector2(3, ph)), Pal.heat(k, 1.2))
	c.draw_string(font_b, r2.position + Vector2(14, 24), "DEV  ·  F12", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.heat(0.9 * k, 1.2))
	for i in rs.size():
		var row: Array = rs[i]
		var y := r2.position.y + 48.0 + i * 22.0
		var on = row[2]
		c.draw_string(font, Vector2(x + 14, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5 * k))
		c.draw_string(font, Vector2(x + 48, y), Txt.t(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.ink((0.95 if on == true else 0.7) * k))
		if on == true:
			c.draw_circle(Vector2(r2.end.x - 16, y - 4), 3.5, Pal.heat(k, 1.4))


# the ship's truth, written where it is: rooms, vessels, sources, trap targets
func _draw_xray() -> void:
	var g := game
	if g == null or g.sys == null:
		return
	var s = g.sys
	var col := Color(1.0, 0.35, 0.55, 0.95)
	var z: float = g.cam_zoom()
	for n in g.world.rooms:
		var r = g.world.rooms[n]
		_xlabel(r.bbox.get_center(), "%s  %.0f kPa" % [n, s.P(n)], col, z, 16)
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
	_xlabel(Vector2(30.0, -6.0) * Geom.M, "BUS %d V  ·  LOOP %d °C  ·  %s" % [int(s.bus_volts()), int(s.loop_T), str(g.ship.get("variant", {}).get("traps", []))], col, z, 15)
	for tr in g.ship.get("variant", {}).get("targets", {}):
		var p5 = g.world.tag(g.ship.variant.targets[tr])
		if p5 != null:
			var pl: PackedVector2Array = g.world.world_poly(p5)
			pl.append(pl[0])
			xray_node.draw_polyline(pl, col, 2.0 / z, true)
	for j in g.world.joints:
		if j.alive and j.type in ["crack", "seam"]:
			xray_node.draw_circle(g.world.joint_world(j), 5.0 / z, col)


func _xlabel(at: Vector2, text: String, col: Color, z: float, size_px: int) -> void:
	xray_node.draw_set_transform(at, 0.0, Vector2.ONE / z)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	xray_node.draw_rect(Rect2(Vector2(-4, -size_px), Vector2(w + 8, size_px * 1.35)), Color(0.05, 0.0, 0.03, 0.75))
	xray_node.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
	xray_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
