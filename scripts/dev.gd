class_name DevPanel
extends CanvasLayer
# Developer workbench: F12 opens/closes the modal card surface. Debug switches
# remain active when collapsed; Disable Dev restores normal switches. Original
# F-key shortcuts remain available while developer mode is enabled.
#   On site:   F1 x-ray (the ship's true state)   F2 make it safe   F3 free every piece
#              F4 drone can't be hurt   F5 time ×1 / ×2 / ×4 / ×8 / ×¼   F6 open every room
#              F7 +3 of each consumable   F8 end the contract now   F9 inspect what the pointer is on
#              F10 this contract again, from the start
#              auto sort (no key): every loose piece flies to its own mouth by
#              itself, through the wreck: whole equipment to the equipment
#              bay, hazards to the hazard bay, keels, decks and scrap to the furnace
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
const SHIPS := ["gr7", "s09", "tug", "pod", "h22", "m14", "med47", "fr26"]
const KIT := [["scan_kit", "up_scan"], ["grapple5", "up_grapple"], ["pump2", "up_pump"], ["arm", "fa_arm"],
	["mouth_rail", "fa_rail"], ["net05", "fa_net"], ["hauler", "fa_hauler"],
	["berth88", "fa_berth"], ["hauler2", "fa_hauler2"], ["crane", "fa_crane"], ["port2", "fa_port2"], ["buffer", "fa_buffer"], ["zones", "fa_zones"]]
const GOALS := ["", "safe", "fast", "valuable"]
const SCOPES := ["full", "section", "rescue"]

static var workbench_open := false

static var god := false          # the drone takes no damage
static var time_k := 1.0         # time on site (1 = as it runs)
static var xray := false
static var inspect := false
static var sort_on := false      # loose pieces fly to their mouths by themselves
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
var bench: DevWorkbench
var pause_owned := false
var previous_tree_pause := false
var previous_sim_pause := false
var check_key := ""
var check_res := {}              # the builder's contract as the validator saw it


static func warp_on() -> bool:
	return Txt.dev and time_k != 1.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_panel)
	add_child(c)
	bench = DevWorkbench.new()
	bench.dev = self
	add_child(bench)
	bench.visible = false
	workbench_open = false
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
				["F9", "dev_inspect", inspect], ["F10", "dev_again", null], ["", "dev_builder", builder], ["", "dev_sort", sort_on]]
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
	_handle_key(ev)


func _handle_key(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var key: int = ev.physical_keycode
	if key == KEY_F12:
		if not Txt.dev:
			Txt.dev = true
			Txt.save_settings(game != null and game.testing)
		set_open(not workbench_open)
		get_viewport().set_input_as_handled()
		return
	if not Txt.dev:
		return
	if key == KEY_ESCAPE and workbench_open:
		set_open(false)
		get_viewport().set_input_as_handled()
		return
	if key >= KEY_F1 and key <= KEY_F10:
		var n := key - KEY_F1 + 1
		if n <= rows().size() and rows()[n - 1][0] != "":
			get_viewport().set_input_as_handled()
			run(n)


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
	_handle_key(ev)
	if Txt.dev and not workbench_open and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(c.size.x - 350, 18, 330, 36).has_point(ev.position):
			set_open(true)
			get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	workbench_open = open and Txt.dev
	if game != null and workbench_open and not pause_owned:
		previous_tree_pause = get_tree().paused
		previous_sim_pause = game.paused_sim
		pause_owned = true
		game.dev_overlay_open = true
		game.paused_sim = true
		if game.tools.cutting:
			game.tools._finish_cut()
		game.tools.lmb = false
		game.tools.lmb_pressed = false
		game.prev_lmb = false
		get_tree().paused = true
	elif not workbench_open:
		_release_pause()
	if bench != null:
		bench.visible = workbench_open
		if workbench_open:
			bench.refresh()


func _release_pause() -> void:
	if pause_owned and is_instance_valid(game):
		game.dev_overlay_open = false
		game.paused_sim = previous_sim_pause
		get_tree().paused = previous_tree_pause
	pause_owned = false


func _exit_tree() -> void:
	_release_pause()
	workbench_open = false


func disable() -> void:
	set_open(false)
	Txt.dev = false
	god = false
	xray = false
	inspect = false
	time_k = 1.0
	Engine.time_scale = 1.0
	Txt.save_settings(game != null and game.testing)


# do what row n stands for (1-based)
func run(n: int) -> void:
	var row: Array = rows()[n - 1]
	if row[1] == "dev_builder":
		builder = not builder
		set_open(true)
		bench.page = 2
		bench.refresh()
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
	if bench != null and bench.visible:
		bench.refresh()


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
		12:
			sort_on = not sort_on
			if not sort_on:
				_sort_release_all()
		10:
			# the same contract again from its start (its ship, its accidents, its upgrades)
			if not g.dev_job():
				Game.contract = g.job.duplicate(true)
				Game.start_ship = g.ship_id
			SaveGame.load_requested = false
			say(Txt.t("dev_again"))
			set_open(false)
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
			for track in Growth.TRACKS:
				_set_skill(d.upgrades, track[0], 3)
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
			terminal.next_job = {}
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
	terminal.thumbs.clear()
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
	if game != null and not game.dev_job():
		SaveGame.save(game)
	var o: Dictionary = r.offer.duplicate(true)
	o.dev = true
	o.dev_from = where
	o.fee = 0.0
	Game.contract = o
	Game.start_ship = b_ship
	SaveGame.load_requested = false
	builder = false
	set_open(false)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _to_card() -> void:
	if not Career.active().is_empty():
		say(Growth.text(["先完成当前合同，或在作业控制中跳过开局合同", "Finish the current job, or skip opening jobs in Operations"]))
		return
	var r := _checked()
	if not r.ok:
		say(Txt.t("dev_b_invalid"))
		return
	_first_card(r.offer.duplicate(true))
	Career.save()
	say(Txt.t("dev_b_carded"))


# ---------------------------------------------------------------- workbench actions

static func _set_skill(kit: Dictionary, id: String, level: int) -> void:
	kit["skill_" + id] = clampi(level, 0, 3)
	if Growth.LEGACY.has(id):
		if level > 0:
			kit[Growth.LEGACY[id]] = 1
		else:
			kit.erase(Growth.LEGACY[id])


func tune_skills(level: int, persistent: bool, only: String = "") -> bool:
	if not Txt.dev:
		return false
	var ids: Array = [only] if only != "" else Growth.TRACKS.map(func(row): return row[0])
	if only != "" and Growth.find_track(only).is_empty():
		return false
	if persistent:
		if Career.data.is_empty() or not Career.usable():
			say(Growth.text(["请先选择生涯存档", "Select a career save first"]))
			return false
		var before: Dictionary = Career.data
		Career.data = before.duplicate(true)
		for id in ids:
			_set_skill(Career.data.upgrades, id, level)
		var active: Dictionary = Career.active()
		if not active.is_empty():
			var kit: Dictionary = active.get("kit", {}).duplicate()
			for id in ids:
				_set_skill(kit, id, level)
			active.kit = kit
		if not Career.save():
			Career.data = before
			say(Growth.text(["保存失败，等级未更改", "Save failed; levels were not changed"]))
			return false
		if game != null:
			game.fit_skills()
	else:
		if game == null:
			return false
		var kit: Dictionary = game.job.get("kit", {}).duplicate()
		for id in ids:
			_set_skill(kit, id, level)
		game.job.kit = kit
	if game != null:
		game.drone.queue_redraw()
	say(Growth.text(["技能装配已更新", "Skill loadout updated"]))
	return true


func adjust_funds(amount: float, rep: int = 0) -> bool:
	if not Txt.dev or Career.data.is_empty() or not Career.usable():
		return false
	var before: Dictionary = Career.data
	Career.data = before.duplicate(true)
	Career.data.money = maxf(0.0, float(Career.data.money) + amount)
	Career.data.rep = maxi(0, int(Career.data.rep) + rep)
	if not Career.save():
		Career.data = before
		say(Growth.text(["保存失败，资金未更改", "Save failed; funds were not changed"]))
		return false
	say(Growth.text(["生涯资金 / 声望已更新", "Career funds / reputation updated"]))
	return true


func restore_drone(home: bool = false) -> void:
	if game == null:
		return
	if not game.drone.alive or home:
		game._launch_drone()
	game.drone.integrity = 100.0
	game.drone.alive = true
	game.drone.linear_velocity = Vector2.ZERO
	game.drone.external = Vector2.ZERO
	game.drone_respawn = -1.0
	game.drone.queue_redraw()
	say(Growth.text(["无人机已恢复", "Drone restored"]))


# ---------------------------------------------------------------- auto sort

const SORT_SPEED := 9.0 * Geom.M      # px/s cruising
const SORT_ACC := 14.0 * Geom.M       # px/s² it speeds up and slows down by
const SORT_AT_ONCE := 8               # this many on their way at a time (the mouths swallow one by one)


# the mouth a loose body belongs in (as the hauler sorts): hazards, scrap, whole equipment
func _sort_zone(b) -> String:
	for p in b.pieces:
		if game.sys.dest_of(p) == "hazard":
			return "hazard"
	if game.dock.is_scrap(b):
		return "metal"
	return "equip"


func _sort_ghost(b, on: bool) -> void:
	if on and not b.has_meta("sort_layer"):
		b.set_meta("sort_layer", b.collision_layer)
		b.set_meta("sort_mask", b.collision_mask)
		b.collision_layer = 0
		b.collision_mask = 0
	elif not on and b.has_meta("sort_layer"):
		if b.capture == null:
			b.collision_layer = b.get_meta("sort_layer")
			b.collision_mask = b.get_meta("sort_mask")
		b.remove_meta("sort_layer")
		b.remove_meta("sort_mask")


func _sort_release_all() -> void:
	if game == null:
		return
	for b in game.world.bodies:
		if is_instance_valid(b):
			_sort_ghost(b, false)


func _physics_process(dt: float) -> void:
	if not sort_on or not Txt.dev or game == null or game.state != "play" or game.paused_sim or get_tree().paused:
		return
	var free: Array = []
	for b in game.world.bodies:
		if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty():
			continue
		if b.has_meta("sort_layer") and b.rejected_t > 0.0:
			# the mouth turned it away: it goes back to being an ordinary piece
			_sort_ghost(b, false)
			b.set_meta("sort_skip", true)
		if b.get_meta("sort_skip", false) or game.tools.held_body == b or b.get_meta("arm", false):
			continue
		var z := Dock.nearest(_sort_zone(b), b.global_transform * b.center_of_mass)
		var to: Vector2 = Dock.zpos(z) - Dock.ZONES[z].face * 0.5 * Geom.M
		var com: Vector2 = b.global_transform * b.center_of_mass
		free.append([b, to, com.distance_to(to) - (1e6 if b.has_meta("sort_layer") else 0.0)])
	# the ones already on their way first, then the nearest
	free.sort_custom(func(x, y): return x[2] < y[2])
	for i in mini(SORT_AT_ONCE, free.size()):
		var b = free[i][0]
		var to: Vector2 = free[i][1]
		_sort_ghost(b, true)
		var com: Vector2 = b.global_transform * b.center_of_mass
		var d := to - com
		# cruise, then brake into the mouth so it arrives slowly enough to be caught
		var want := d.normalized() * minf(SORT_SPEED, sqrt(2.0 * SORT_ACC * d.length()) * 0.9)
		b.linear_velocity = b.linear_velocity.move_toward(want, SORT_ACC * dt)
		b.angular_velocity *= exp(-3.0 * dt)


# A compact status badge stays on site; the old shortcut list is gone.
func _process(dt: float) -> void:
	t += dt
	toast_t += dt
	if bench != null and bench.visible != (Txt.dev and workbench_open):
		set_open(workbench_open and Txt.dev)
	c.queue_redraw()
	if xray_node != null:
		xray_node.visible = Txt.dev and xray
		if xray_node.visible:
			xray_node.queue_redraw()


func _draw_panel() -> void:
	hits = []
	if Txt.dev and not workbench_open:
		# over a terminal its readouts own the top right: the badge goes to the bottom
		var term_open := not c.get_tree().get_nodes_in_group("terminal").is_empty()
		var r := Rect2(c.size.x - 350, c.size.y - 54 if term_open else 18, 330, 36)
		c.draw_rect(r, Color(0.025, 0.03, 0.035, 0.94))
		c.draw_rect(Rect2(r.position, Vector2(3, 36)), Pal.heat(0.9))
		c.draw_string(font_b, r.position + Vector2(12, 24), Growth.text(["DEV 在线 · F12 工作台", "DEV ACTIVE · F12 WORKBENCH"]), HORIZONTAL_ALIGNMENT_LEFT, 310, 15, Pal.ink(0.9))
	if Txt.dev and inspect and game != null and not workbench_open:
		_inspect_card()
	if toast_t < 2.5 and not workbench_open:
		c.draw_string(font_b, Vector2(40, c.size.y - 45), toast, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 80, 17, Pal.ink(0.9))


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
	if g.hauler2 != null:
		mach.append("HAUL2 %s" % g.hauler2.state)
	if g.crane != null:
		mach.append("CRANE %s" % g.crane.state)
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
