class_name Game
extends Node2D
# Contract #001: the dock, the ship, the drone and everything that happens
# between them. Holds the camera, routes input, reacts to every event the
# systems raise (cuts, arcs, leaks, blowouts, recoveries) and keeps the books.

const CONTRACT_FEE := 9000.0
const DRONE_FEE := 2000.0
const CAM_ZOOM := 1.65
const SHIP_CENTER := Vector2(21.0 * 48.0, 0.0)

var world: World
var sys: Systems
var dock: Dock
var fx: Fx
var drone: Drone
var tools: Tools
var hud: Hud
var blueprint: Blueprint
var sfx: Sfx
var cam: Camera2D
var bot = null               # tests drive the game through this dict
var ship_id := "gr7"         # which ship file this contract is about
var ship: Dictionary = {}
var testing := false

var state := "intro"         # intro play ending
var state_t := 0.0
var paused_sim := false
var menu_open := false
var contract_open := false

# camera
var cam_pos := Vector2.ZERO
var cam_vel := Vector2.ZERO
var zoom_target := CAM_ZOOM
var zoom_now := 0.62
var trauma := 0.0
var punch := Vector2.ZERO
var cam_override = null      # Vector2 world point (intro / ending)
var zoom_override := -1.0

# input edges
var prev_lmb := false
var prev_keys := {}
var aim := Vector2.ZERO

# economy
var income_equip := 0.0
var income_metal := 0.0
var income_hazard := 0.0
var losses := 0.0
var loss_lines: Array = []   # [text_key, amount]
var mandatory_ok := {}     # tag -> recovered intact into the equipment bay
var incidents: Array = []  # [playtime, kind, detail]: what went wrong and when (the accident review reads it)
var _mand: Array = []
var _mand_zh := -1
var feed: Array = []         # [text, amount, t] recent income lines for the HUD
var drone_respawn := -1.0
var hurt_cd := {}
var hints_seen := {}
var hints_on := true
var messages: Array = []     # [key, world pos, t, text]
var reveal_count := 0
var ship_offset := 60.0 * 48.0
var ended := false
var slowmo := 0.0
var hitstop_t := 0.0
var playtime := 0.0
var ledger: Array = []        # [label, zone, value]
var autosave_t := 0.0
var best := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	testing = _is_test()
	Txt.load_settings(testing)
	hints_on = Txt.hints
	fx = Fx.new()
	fx.game = self
	var bg := Backdrop.new()
	bg.game = self
	add_child(bg)
	world = World.new()
	world.game = self
	dock = Dock.new()
	dock.game = self
	dock.world = world
	add_child(dock)
	add_child(world)
	var data := {}
	if SaveGame.load_requested and (not testing or SaveGame.allow_test):
		data = SaveGame.read()
	SaveGame.load_requested = false
	if not data.is_empty():
		ship_id = data.get("ship", "gr7")
	ship = Ship.load_data(ship_id)
	dock.set_ship(ship)
	if not data.is_empty() and SaveGame.apply(self, data):
		Ship.rooms(world, ship)
	else:
		data = {}
		Ship.build(world, ship)
	sys = Systems.new()
	add_child(sys)
	world.finalize(float(ship.get("value", {}).get("metal", 12000.0)))
	sys.setup(self, world, ship)
	world.piece_freed.connect(on_body_freed)
	add_child(fx)
	blueprint = Blueprint.new()
	blueprint.game = self
	add_child(blueprint)
	drone = Drone.new()
	drone.game = self
	drone.assist = Txt.assist if bot == null else bot.get("assist", true)
	drone.alive = false
	add_child(drone)
	drone.global_position = Dock.BAY * Geom.M + Vector2(-40, 0)
	tools = Tools.new()
	tools.game = self
	tools.world = world
	tools.sys = sys
	tools.drone = drone
	add_child(tools)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 10
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lv in 7:
		env.set_glow_level(lv, [0.0, 1.0, 1.0, 0.8, 0.55, 0.3, 0.0][lv])
	we.environment = env
	add_child(we)
	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)
	cam.make_current()
	sfx = Sfx.new()
	sfx.game = self
	add_child(sfx)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	for n in [dock, world, sys, fx, blueprint, drone, tools]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.position.x = ship_offset
	cam_pos = Vector2(21.0 * 48.0, -0.5 * 48.0)
	zoom_now = 0.62
	state = "intro"
	state_t = 0.0
	if not data.is_empty():
		SaveGame.apply_late(self, data)
		if SaveGame.recovered:
			hud.show_hint(txt("save_recovered"))
		world.position.x = 0.0
		state = "play"
		drone.alive = true
		drone.spawn_t = 0.0
		cam_pos = drone.global_position
		zoom_now = CAM_ZOOM
	elif bot != null and bot.get("skip_intro", false):
		_end_intro()


func _is_test() -> bool:
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.begins_with("res://tests/") or a.find("tests/") >= 0:
			return true
	return bot != null


func txt(key: String) -> String:
	return Txt.t(key)


# the contract's named items: [tag, name text], in ship-file order
func mandatory_items() -> Array:
	if _mand_zh == int(Txt.zh):
		return _mand
	_mand = []
	_mand_zh = int(Txt.zh)
	for pd in ship.get("pieces", []):
		if pd.get("mandatory", false):
			_mand.append([pd.get("tag", ""), txt(pd.get("name_key", ""))])
	return _mand


func all_mandatory_ok() -> bool:
	for it in mandatory_items():
		if not mandatory_ok.get(it[0], false):
			return false
	return true


func room_name(room: String) -> String:
	return txt(Ship.room_name_key(ship, room))


func cam_zoom() -> float:
	return zoom_now


# ---------------------------------------------------------------- frame

func _process(dt: float) -> void:
	var rdt := dt / maxf(Engine.time_scale, 0.01)
	state_t += rdt
	if state == "play" and not menu_open:
		playtime += dt
		autosave_t += rdt
		if autosave_t > 25.0:
			autosave_t = 0.0
			SaveGame.save(self)
	_read_input()
	match state:
		"intro":
			_intro(rdt)
		"play":
			if not menu_open and not contract_open:
				tools.aim = aim
				tools.step(dt)
			_drone_upkeep(dt)
		"ending":
			_ending(rdt)
	fx.step(dt)
	_age_messages(rdt)
	if hitstop_t > 0.0:
		hitstop_t -= rdt
		Engine.time_scale = 0.05 if hitstop_t > 0.0 else (0.28 if slowmo > 0.0 else 1.0)
	elif slowmo > 0.0:
		slowmo -= rdt
		Engine.time_scale = 0.28 if slowmo > 0.0 else 1.0


func _physics_process(dt: float) -> void:
	_camera(dt / maxf(Engine.time_scale, 0.01))
	if state == "play" and not menu_open:
		tools.physics_step(dt)
		_bodies_upkeep(dt)


func _read_input() -> void:
	var mpos := get_global_mouse_position()
	var b: Dictionary = bot if bot != null else {}
	aim = b.get("aim", mpos)
	var lmb: bool = b.get("lmb", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var blocked: bool = menu_open or contract_open or (bot == null and hud.pointer_over_ui())
	if blocked:
		lmb = false
	tools.lmb_pressed = lmb and not prev_lmb
	tools.lmb = lmb
	prev_lmb = lmb
	var mv := Vector2.ZERO
	if b.has("move"):
		mv = b.move
	elif not menu_open and not contract_open:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			mv.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			mv.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			mv.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			mv.y += 1
	drone.input.move = mv if state == "play" else Vector2.ZERO
	drone.input.dash = b.get("dash", Input.is_physical_key_pressed(KEY_SHIFT)) and state == "play"
	drone.input.brake = b.get("brake", Input.is_physical_key_pressed(KEY_SPACE)) and state == "play"
	drone.aim = aim


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if state == "intro":
			if k in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
				_end_intro()
			return
		if state == "ending":
			hud.ending_key(k)
			return
		if k == KEY_ESCAPE:
			if contract_open:
				close_contract()
			else:
				toggle_menu()
			return
		if menu_open:
			return
		if contract_open:
			if k in [KEY_SPACE, KEY_ENTER]:
				close_contract()
			return
		match k:
			KEY_1: tools.set_tool(1)
			KEY_2: tools.set_tool(2)
			KEY_3: tools.set_tool(3)
			KEY_4: tools.set_tool(4)
			KEY_5: tools.set_tool(5)
			KEY_TAB: blueprint.toggle()
			KEY_F:
				drone.assist = not drone.assist
				Txt.assist = drone.assist
				Txt.save_settings(testing)
				say("assist_on" if drone.assist else "assist_off", drone.global_position + Vector2(0, -44))
				sfx.play("switch")
			KEY_C: open_contract()
			KEY_H:
				hints_on = not hints_on
				Txt.hints = hints_on
				Txt.save_settings(testing)
	elif ev is InputEventMouseButton and ev.pressed:
		if state == "intro":
			_end_intro()
			return
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target * 1.1, 0.85, 2.6)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target / 1.1, 0.85, 2.6)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and state == "play":
			if tools.held_piece != null:
				tools.release_grab(true)
			tools.job = {}


func toggle_menu() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	paused_sim = menu_open
	hud.menu_changed()
	sfx.play("menu")


func open_contract() -> void:
	contract_open = true
	hud.contract_changed()


func close_contract() -> void:
	contract_open = false
	hud.contract_changed()
	sfx.play("ok")
	hint("start")


# ---------------------------------------------------------------- camera

func _camera(dt: float) -> void:
	var target := cam_pos
	if cam_override != null:
		target = cam_override
	elif drone != null and (drone.alive or state == "play"):
		var dp: Vector2 = drone.global_position
		var lead := drone.linear_velocity * 0.22
		var look: Vector2 = (aim - dp).limit_length(380.0) * 0.18
		target = dp + lead + look
		if tools.held_piece != null and not tools.held_piece.gone:
			target = target.lerp(tools.grab_point(), 0.18)
	# a critically damped follow: soft, never laggy
	var k := 38.0
	var c := 2.0 * sqrt(k)
	var n := maxi(1, ceili(dt / (1.0 / 240.0)))
	var h := dt / n
	for i in n:
		cam_vel += ((target - cam_pos) * k - cam_vel * c) * h
		cam_pos += cam_vel * h
	var zt := zoom_override if zoom_override > 0.0 else zoom_target
	if state == "play" and drone.alive:
		zt *= lerpf(1.0, 0.86, clampf(drone.linear_velocity.length() / 700.0, 0.0, 1.0))
	zoom_now = Pal.damp(zoom_now, zt, 4.0 if zoom_override > 0.0 else 6.0, dt)
	trauma = maxf(0.0, trauma - dt * 1.6)
	punch = Pal.damp2(punch, Vector2.ZERO, 12.0, dt)
	var sh := trauma * trauma
	var tt := Time.get_ticks_msec() / 1000.0
	var off := Vector2(sin(tt * 47.0) + sin(tt * 31.0) * 0.5, cos(tt * 41.0) + sin(tt * 23.0) * 0.5) * 14.0 * sh
	cam.position = cam_pos + off + punch
	cam.zoom = Vector2(zoom_now, zoom_now)
	cam.rotation = sin(tt * 37.0) * 0.006 * sh


# a few frames of near-freeze that sell an impact
func hitstop(sec: float) -> void:
	if state != "play" or bot != null:
		return
	hitstop_t = maxf(hitstop_t, sec)


func shake(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	trauma = minf(1.0, trauma + amount)
	punch += dir * 12.0 * amount


# ---------------------------------------------------------------- intro & ending

func _intro(dt: float) -> void:
	var t := state_t
	# the tug pushes GR-7 into the dock
	var k := Pal.ease_io(clampf(t / 3.4, 0.0, 1.0))
	world.position.x = ship_offset * (1.0 - k)
	cam_override = Vector2(21.0 * 48.0 + world.position.x * 0.35, -0.5 * 48.0)
	zoom_override = 0.62
	for i in dock.clamps.size():
		var on := clampf((t - 3.5 - i * 0.22) / 0.3, 0.0, 1.0)
		dock.clamp_t[i] = 1.0 - Pal.ease_out(on)
		if on > 0.0 and not dock.has_meta("cl%d" % i):
			dock.set_meta("cl%d" % i, true)
			var p: Vector2 = dock.clamps[i] * 48.0
			fx.flash(p, 60.0, 0.35, Pal.ink(0.8, 1.6))
			fx.sparks(p, Vector2.UP, 10, Pal.heat(1.0, 2.0), 260.0, 0.35, 1.2)
			shake(0.15)
			sfx.play("clamp")
	if t > 4.7 and not drone.alive:
		_launch_drone()
	if t > 5.0:
		cam_override = null
		zoom_override = -1.0
	if t > 6.2:
		_end_intro()


func _end_intro() -> void:
	if state != "intro":
		return
	world.position.x = 0.0
	for i in dock.clamps.size():
		dock.clamp_t[i] = 0.0
	if not drone.alive:
		_launch_drone()
	cam_override = null
	zoom_override = -1.0
	state = "play"
	state_t = 0.0
	if bot == null or not bot.get("skip_contract", false):
		open_contract()


func _launch_drone() -> void:
	drone.alive = true
	drone.integrity = 100.0
	drone.spawn_t = 0.0
	drone.global_position = Dock.BAY * Geom.M + Vector2(-30, 0)
	drone.reset_physics_interpolation()
	drone.linear_velocity = Vector2(520, 0)
	fx.flash(drone.global_position, 50.0, 0.3, Pal.heat(0.6, 1.8))
	fx.ring(drone.global_position, 10.0, 60.0, 0.4, Pal.ink(0.6))
	sfx.play("launch")


func finish_contract(early: bool) -> void:
	if ended:
		return
	ended = true
	state = "ending"
	state_t = 0.0
	tools.release_grab(false)
	if tools.cutting:
		tools._finish_cut()
	if not early:
		slowmo = 0.5
	cam_override = Vector2(21.0 * 48.0, -0.2 * 48.0)
	zoom_override = 0.6
	hud.start_ending(early)
	sfx.play("end")
	if not testing:
		SaveGame.clear()
		best = SaveGame.record_best(recovery_rate(), net(), playtime, hud.grade())


func _ending(_dt: float) -> void:
	pass


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func to_title() -> void:
	if state == "play":
		SaveGame.save(self)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# ---------------------------------------------------------------- economy

func earned() -> float:
	return income_equip + income_metal + income_hazard + sys.gas_value() + sys.fluid_value()


func recovery_rate() -> float:
	return earned() / float(ship.get("value", {}).get("total", 120000.0))


func net() -> float:
	return earned() - losses - CONTRACT_FEE


func incident(kind: String, detail: String = "") -> void:
	incidents.append([snappedf(playtime, 0.1), kind, detail])


func lose(key: String, amount: float, at: Vector2) -> void:
	losses += amount
	loss_lines.append([key, amount])
	fx.number(at, "−" + Pal.money(amount).trim_prefix("$"), Pal.heat(1.0, 1.4), 22)
	feed.push_front([txt(key), -amount, 0.0])
	hud.pop_credits(-amount)


func gain(kind: String, amount: float, at: Vector2, label: String) -> void:
	match kind:
		"equip": income_equip += amount
		"metal": income_metal += amount
		"hazard": income_hazard += amount
	fx.number(at, "+" + Pal.money(amount), Pal.ink(1.0, 1.5), 26 if amount > 3000 else 20)
	feed.push_front([label, amount, 0.0])
	hud.fly_credits(at, amount)


func piece_value(p, zone: String) -> float:
	var scrap: float = p.mass * world.metal_price
	var dest: String = sys.dest_of(p)
	var v := 0.0
	if p.cls == "equip" and p.intact:
		var full: float = p.value * clampf(p.cond, 0.0, 1.0)
		match zone:
			"equip": v = full if dest == "equip" else full * 0.4
			"metal": v = scrap
			"hazard": v = full * 0.4 if dest == "hazard" else full * 0.3
	else:
		v = scrap * (0.5 if zone == "hazard" else (1.0 if zone == "metal" else 0.8))
	if p.contam:
		v *= 0.75
	return v


func judge(b, zone: String) -> Dictionary:
	var total := 0.0
	var metal_m := 0.0
	var all_m := 0.0
	var hazard := false
	var equip_intact := false
	for p in b.pieces:
		all_m += p.mass
		var d: String = sys.dest_of(p)
		if d == "hazard":
			hazard = true
		if p.cls != "equip" or not p.intact:
			metal_m += p.mass
		else:
			equip_intact = true
		total += piece_value(p, zone)
	match zone:
		"equip":
			if hazard:
				return {"ok": false, "reason": "rej_hazard"}
			if not equip_intact:
				return {"ok": false, "reason": "rej_scrap"}
			if metal_m > all_m * 0.2:
				return {"ok": false, "reason": "rej_mixed"}
		"hazard":
			if equip_intact and not hazard:
				return {"ok": false, "reason": "rej_not_hazard"}
	return {"ok": true, "value": total, "hazard": hazard, "equip": equip_intact}


func on_reject(b, zone: String, verdict: Dictionary) -> void:
	say(verdict.reason, Dock.zpos(zone) - Dock.ZONES[zone].face * 20.0)
	sfx.play("reject")
	fx.flash(Dock.zpos(zone), 80.0, 0.3, Pal.heat(0.5, 1.4))


func on_swallow_start(b, zone: String) -> void:
	sfx.play("swallow_" + zone)


func on_swallowed(b, zone: String) -> void:
	var at: Vector2 = Dock.zpos(zone) - Dock.ZONES[zone].face * 30.0
	var names: Array = []
	var v := 0.0
	var boom := false
	for p in b.pieces:
		v += piece_value(p, zone)
		if p.tag != "" and p.cls == "equip":
			names.append(p.tag)
		if zone == "equip" and p.intact and p.cls == "equip" and p.mandatory:
			mandatory_ok[p.tag] = true
		if zone == "metal" and sys.dest_of(p) == "hazard":
			boom = true
		# whatever it held goes with it
		var fv: String = sys.fluid_in_piece(p)
		if fv != "":
			sys.set_fluid(fv, 0.0)
		if sys.src.has(p.tag) and sys.src[p.tag].kind == "cap":
			sys.drain_source(p.tag)
	var label := ", ".join(names) if not names.is_empty() else txt("scrap_metal")
	ledger.append([label, zone, v])
	if zone == "metal" and b.pieces.any(func(p): return p.cls == "equip" and p.intact):
		say("equip_as_scrap", at)
	gain("equip" if zone == "equip" else ("hazard" if zone == "hazard" else "metal"), v, at, label)
	var col := Pal.heat(1.0, 2.2) if zone == "metal" else (Pal.tint(Pal.FLUID, 0.9, 1.4) if zone == "hazard" else Pal.ink(0.9, 1.5))
	fx.flash(Dock.zpos(zone), 140.0, 0.5, col)
	fx.ring(Dock.zpos(zone), 20.0, 140.0, 0.5, col, 2.0)
	fx.sparks(Dock.zpos(zone), -Dock.ZONES[zone].face, 30, col, 480.0, 0.55, 0.9)
	var face: Vector2 = Dock.ZONES[zone].face
	match zone:
		"metal":
			for i in 46:
				fx.molten(Dock.zpos(zone) + Vector2(randf_range(-80, 80), 0), (-face * randf_range(160, 520)).rotated(randf_range(-0.5, 0.5)), randf_range(1.2, 2.4))
			fx.flash(Dock.zpos(zone) - face * 40.0, 320.0, 0.8, Pal.heat(0.7, 3.0))
		"equip":
			for i in 3:
				fx.ring(Dock.zpos(zone) - face * 30.0, 10.0 + i * 20.0, 150.0 + i * 50.0, 0.5 + i * 0.15, Pal.ink(0.7, 1.8), 1.6)
		"hazard":
			for i in 24:
				fx.puff(Dock.zpos(zone), (-face * 200.0).rotated(randf_range(-1.2, 1.2)), 0.9, 8.0, 40.0, Pal.tint(Pal.FLUID, 0.12))
	hitstop(0.04)
	shake(0.12 + minf(0.25, b.total_mass() * 0.06))
	sfx.play("eat_" + zone)
	if boom:
		_furnace_boom()
	world.remove_body(b)
	_check_done()


func _furnace_boom() -> void:
	incident("furnace")
	var p := Dock.zpos("metal")
	fx.flash(p, 260.0, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(p, 20.0, 300.0, 0.6, Pal.heat(0.9, 2.0), 3.0)
	fx.burst_shards(p, 24, 600.0, Pal.heat(0.9, 1.6), 12.0)
	shake(0.7)
	sfx.play("boom")
	lose("loss_furnace", 3000.0, p + Vector2(0, -60))


func on_debris_in(value: float, at: Vector2) -> void:
	income_metal += value
	hud.fly_credits(at, value)
	sfx.play("net")
	_check_done()


func _check_done() -> void:
	if state != "play":
		return
	for id in world.order:
		if not world.pieces[id].gone:
			return
	if not dock.debris.is_empty() or not dock.swallowing.is_empty():
		await get_tree().create_timer(0.8).timeout
	finish_contract(false)


# ---------------------------------------------------------------- bodies

func on_body_freed(b) -> void:
	var m: float = b.total_mass()
	var all_metal := true
	for p in b.pieces:
		if p.cls == "equip":
			all_metal = false
	if all_metal and m < 0.1:
		# tiny cut-offs go straight to the debris net
		var vel: Vector2 = (b.global_position - SHIP_CENTER).normalized() * randf_range(60, 140)
		for p in b.pieces:
			dock.add_debris(world.world_poly(p), vel, p.mass * world.metal_price)
		world.remove_body(b)
		sfx.play("debris")
		return
	# a gentle shove away from the hull so it reads as free
	var away: Vector2 = (b.global_position - SHIP_CENTER).normalized()
	b.linear_velocity += away * 10.0
	b.angular_velocity += randf_range(-0.05, 0.05)
	sfx.play("free", b.global_position, clampf(m / 2.0, 0.3, 1.0))
	# the last kerf flashes white-hot along its length and sheds sparks
	var now := Time.get_ticks_msec() / 1000.0
	var lit := 0
	for p in b.pieces:
		for h in p.heat:
			if now - h[1] > 0.6:
				continue
			var pl: PackedVector2Array = b.global_transform * (h[0] as PackedVector2Array)
			for i in range(0, pl.size(), 3):
				fx.sparks(pl[i], Vector2.from_angle(randf() * TAU), 2, Pal.heat(1.0, 3.2), 260.0, 0.45, PI)
				if randf() < 0.4:
					fx.molten(pl[i], Vector2.from_angle(randf() * TAU) * randf_range(30, 110), 1.8)
				lit += 1
	var com: Vector2 = b.global_transform * b.center_of_mass
	fx.flash(com, 70.0 + 60.0 * minf(m, 2.0), 0.35, Pal.heat(0.55, 2.4))
	fx.ring(com, 10.0, 90.0 + 40.0 * minf(m, 2.0), 0.45, Pal.ink(0.5, 1.6), 1.6)
	fx.burst_shards(com, 6 + int(m * 4), 160.0, Pal.ink(0.7), 6.0)
	shake(0.1 + minf(0.25, m * 0.06), away)
	if m > 0.5:
		hitstop(0.045 + minf(0.05, m * 0.015))
	fx.puff(com, Vector2.ZERO, 0.9, 14.0, 80.0, Pal.ink(0.05))
	hint("free_body")


func _bodies_upkeep(dt: float) -> void:
	for b in world.bodies:
		if not is_instance_valid(b) or b.capture != null:
			continue
		b.age += dt
		var dv: float = b.hit_imp / maxf(b.mass, 0.05)
		if dv > 55.0 and b.age > 0.4:
			_impact(b, dv)
		b.hit_imp = 0.0


func _impact(b, dv: float) -> void:
	var at: Vector2 = b.hit_pos
	var k := clampf((dv - 55.0) / 260.0, 0.0, 1.0)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 3 + int(k * 10), Pal.ink(0.8, 1.4), 200.0 + 200.0 * k, 0.3, 1.4)
	sfx.play("clank", at, 0.3 + 0.7 * k)
	var lost := 0.0
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			var before: float = p.cond
			p.cond = maxf(0.0, p.cond - p.fragile * k * 0.5)
			lost += (before - p.cond) * p.value
	if lost > 150.0:
		incident("impact", "%d" % int(lost))
		fx.number(at + Vector2(0, -20), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
		say("impact_damage", at)
		hint("impact")
	if k > 0.3:
		shake(k * 0.2)


# ---------------------------------------------------------------- drone

func _drone_upkeep(dt: float) -> void:
	if not drone.alive:
		if drone_respawn > 0.0:
			drone_respawn -= dt
			if drone_respawn <= 0.0:
				_launch_drone()
		return
	var pull := dock.field_pull(drone.global_position)
	if pull != Vector2.ZERO:
		drone.external += pull * drone.mass * 3.0
		hint("field")
	var bay := Dock.BAY * Geom.M
	if drone.global_position.distance_to(bay) < 2.6 * Geom.M and drone.integrity < 100.0:
		drone.integrity = minf(100.0, drone.integrity + dt * 55.0)
		if randf() < 0.3:
			fx.sparks(drone.global_position, Vector2.UP, 1, Pal.ink(0.6, 1.2), 60.0, 0.3)


func hurt_drone(amount: float, from: Vector2, key: String, cd_key: String = "", cd: float = 1.0) -> void:
	if not drone.alive or drone.spawn_t < 1.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if cd_key != "" and now - hurt_cd.get(cd_key, -99.0) < cd:
		return
	if cd_key != "":
		hurt_cd[cd_key] = now
	incident("drone_hit", key)
	drone.hurt(amount, from)
	shake(0.25 + amount / 100.0, (drone.global_position - from).normalized())
	sfx.play("hurt")
	say(key, drone.global_position + Vector2(0, -40))
	hud.hurt_flash(amount)


func on_drone_impact(pos: Vector2, dv: float) -> void:
	if dv > 175.0:
		hurt_drone(10.0, pos, "hit_hard", "impact", 0.7)
	fx.sparks(pos, (drone.global_position - pos).normalized(), 6, Pal.ink(0.8, 1.3), 220.0, 0.3, 1.0)


func on_drone_destroyed() -> void:
	incident("drone_lost")
	var p := drone.global_position
	fx.flash(p, 200.0, 0.6, Pal.heat(1.0, 2.6))
	fx.ring(p, 10.0, 180.0, 0.6, Pal.heat(0.9, 1.8), 2.4)
	fx.burst_shards(p, 18, 380.0, Pal.ink(0.9), 9.0)
	fx.sparks(p, Vector2.UP, 30, Pal.heat(1.0, 2.2), 420.0, 0.6, PI)
	shake(0.8)
	sfx.play("boom")
	tools.release_grab(false)
	if tools.cutting:
		tools._finish_cut()
	lose("loss_drone", DRONE_FEE, p + Vector2(0, -50))
	drone_respawn = 2.0
	drone.linear_velocity = Vector2.ZERO
	hint("drone_lost")


# ---------------------------------------------------------------- tool events

func on_laser_blocked(p, pos: Vector2) -> void:
	say("confirm_cut", pos, Txt.piece_name(p))
	sfx.play("warn")
	hint("equip_cut")


func on_cut_into(p, pos: Vector2) -> void:
	if p.cls != "equip":
		return
	var was_value: float = p.value * p.cond
	var volts: float = sys.piece_volts(p)
	var fv: String = sys.fluid_in_piece(p)
	if sys.bursts(p):
		_burst(p, pos)
	elif fv != "" and sys.fluid(fv) > 0.02:
		_leak(sys.fvol[fv].fluid, fv, pos, p)
	if volts > 30.0:
		_arc(pos, volts, p)
		# the arc empties whatever stored it
		sys.drain_source(p.tag)
	elif volts > 0.0:
		fx.sparks(pos, Vector2.UP, 8, Pal.tint(Pal.VOLT, 1.0, 2.0), 160.0, 0.3, PI)
		sfx.play("zap_small")
	if was_value > 200.0:
		incident("equip_cut", p.tag)
		fx.number(pos + Vector2(0, -30), "−" + Pal.money(was_value).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
		say("equip_ruined", pos, Txt.piece_name(p))
	# one touch of the beam and it is scrap
	if p.intact:
		p.intact = false
		world.redraw_all()


func _arc(pos: Vector2, volts: float, p = null) -> void:
	incident("arc", "%d V%s" % [int(volts), (" " + p.tag) if p != null and p.tag != "" else ""])
	var k := clampf(volts / 400.0, 0.3, 1.0)
	for i in 3 + int(k * 3):
		fx.arc(pos, pos + Vector2.from_angle(randf() * TAU) * randf_range(40, 120) * k, randf_range(0.18, 0.35), k)
	if drone.alive and drone.global_position.distance_to(pos) < 3.0 * 48.0:
		fx.arc(pos, drone.global_position, 0.3, 1.0)
		hurt_drone(40.0 * k, pos, "arc_hit", "arc", 0.6)
	fx.flash(pos, 220.0 * k, 0.4, Pal.tint(Pal.VOLT, 1.0, 2.4))
	fx.sparks(pos, Vector2.from_angle(randf() * TAU), 24, Pal.tint(Pal.VOLT, 1.0, 2.2), 420.0, 0.4, PI)
	hud.white_flash(0.35 * k)
	shake(0.35 * k)
	hitstop(0.06 * k)
	sfx.play("arc")
	hint("arc")


func _burst(p, pos: Vector2) -> void:
	incident("burst", p.tag)
	var v: String = sys.tank_vol(p)
	sys.gas_lost += sys.vols[v].n
	sys.vols[v].n = 0.0
	var c := world.frame(p) * Geom.centroid(p.poly)
	fx.flash(c, 240.0, 0.5, Pal.ink(1.0, 2.0))
	fx.ring(c, 10.0, 220.0, 0.5, Pal.ink(0.9), 3.0)
	for i in 40:
		var d := Vector2.from_angle(randf() * TAU)
		fx.puff(c, d * randf_range(200, 600), randf_range(0.5, 1.1), 6.0, 40.0, Pal.tint(Pal.AIR, 0.12))
	fx.burst_shards(c, 14, 420.0, Pal.ink(0.8), 8.0)
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < 4.0 * 48.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 260.0 * (1.0 - d2.length() / 192.0))
	if drone.alive and drone.global_position.distance_to(c) < 3.0 * 48.0:
		hurt_drone(25.0, c, "burst_hit", "burst", 0.5)
	for q in _equip_near(c, 1.6 * 48.0):
		if q != p:
			q.cond = maxf(0.0, q.cond - 0.2 * q.fragile)
	shake(0.6)
	hud.white_flash(0.25)
	hitstop(0.07)
	sfx.play("burst")
	hint("burst")


func _equip_near(c: Vector2, r: float) -> Array:
	var out: Array = []
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.cls != "equip" or not q.intact:
			continue
		if (world.frame(q) * Geom.centroid(q.poly)).distance_to(c) < r:
			out.append(q)
	return out


func _leak(fluid: String, src: String, at: Vector2, piece = null) -> void:
	incident("leak", src)
	var lk := {"pos": at, "dir": Vector2.from_angle(randf() * TAU), "fluid": fluid, "rate": 1.0, "src": src, "t": 0.0, "piece": piece, "local": Vector2.ZERO}
	if piece != null:
		lk.local = world.frame(piece).affine_inverse() * at
		lk.dir = (at - world.frame(piece) * Geom.centroid(piece.poly)).normalized()
	sys.leaks.append(lk)
	sfx.play("leak")
	say("leak_" + fluid, at)
	hint("leak_" + fluid)


func leak_pos(lk: Dictionary) -> Vector2:
	if lk.piece != null and not lk.piece.gone:
		return world.frame(lk.piece) * lk.local
	return lk.pos


func on_line_cut(l, at: Vector2) -> void:
	if l.kind == "cable":
		var volts: float = sys.line_volts(l) if l.id != "" else 0.0
		# line_volts reads alive lines; it has just been cut, so ask about the source side
		volts = _cut_cable_volts(l)
		if volts > 30.0:
			_arc(at, volts)
		elif volts > 0.0:
			fx.sparks(at, Vector2.UP, 10, Pal.tint(Pal.VOLT, 1.0, 2.0), 160.0, 0.3, PI)
			sfx.play("zap_small")
		else:
			fx.sparks(at, Vector2.UP, 4, Pal.ink(0.8, 1.3), 120.0, 0.2, PI)
		say("cable_cut", at, l.id.to_upper())
		return
	var vk: String = sys.fluid_of_net(l.net)
	if vk != "":
		var v: Dictionary = sys.fvol[vk]
		if sys.fluid_behind(vk) > float(v.get("leak_min", 0.02)):
			_leak(v.fluid, vk, at)
			if v.fluid != "fuel":
				# hot coolant scalds and fouls what it lands on
				if sys.line_temp(l) > 60.0 and drone.alive and drone.global_position.distance_to(at) < 2.5 * 48.0:
					hurt_drone(25.0, at, "scald", "scald", 1.0)
				for q in _equip_near(at, 2.0 * 48.0):
					q.contam = true
				world.redraw_all()
	elif l.net == "gas":
		for i in 10:
			fx.puff(at, Vector2.from_angle(randf() * TAU) * 120.0, 0.6, 4.0, 22.0, Pal.tint(Pal.AIR, 0.1))
		sfx.play("hiss")
	fx.sparks(at, Vector2.UP, 3, Pal.ink(0.7, 1.2), 100.0, 0.2, PI)


func _cut_cable_volts(l) -> float:
	var was: bool = l.alive
	l.alive = true
	var v: float = sys.line_volts(l)
	l.alive = was
	return v


func on_ignite(cl: Dictionary, pos: Vector2) -> void:
	incident("fire")
	sys.clouds.erase(cl)
	var c: Vector2 = cl.pos
	fx.flash(c, cl.r * 2.2, 0.7, Pal.heat(1.0, 3.0))
	fx.ring(c, 10.0, cl.r * 1.6, 0.6, Pal.heat(0.9, 2.2), 3.0)
	for i in 50:
		var d := Vector2.from_angle(randf() * TAU)
		fx.puff(c + d * randf() * cl.r * 0.5, d * randf_range(80, 320), randf_range(0.4, 0.9), 8.0, 50.0, Pal.heat(0.25, 1.8))
	fx.sparks(c, Vector2.UP, 40, Pal.heat(1.0, 2.4), 500.0, 0.6, PI)
	if drone.alive and drone.global_position.distance_to(c) < cl.r + 1.5 * 48.0:
		hurt_drone(25.0, c, "fire_hit", "fire", 1.0)
	for q in _equip_near(c, cl.r + 48.0):
		q.cond = maxf(0.0, q.cond - 0.3)
	for b in world.bodies:
		var d2: Vector2 = b.global_position - c
		if d2.length() < cl.r * 2.0:
			b.apply_central_impulse(d2.normalized() * b.mass * 200.0)
	shake(0.7)
	hud.white_flash(0.3)
	sfx.play("ignite")
	lose("loss_fire", 1500.0, c + Vector2(0, -60))
	hint("fire")


func on_kerf(p, res: Dictionary) -> void:
	for j in res.killed:
		var jp: Vector2 = world.joint_world(j)
		fx.sparks(jp, Vector2.from_angle(randf() * TAU), 4, Pal.heat(1.0, 2.0), 160.0, 0.25, PI)
	for l in res.lines:
		on_line_cut(l, world.frame(p) * Geom.centroid(p.poly))
	if res.split > 1:
		sfx.play("crack", world.frame(p) * Geom.centroid(p.poly), 0.8)


func on_grab(p) -> void:
	if p.body == null:
		var fixed := 0
		for j in world.joints_of(p):
			if j.type in ["bolt", "weld", "clamp"]:
				fixed += 1
		if fixed > 0:
			say("still_fixed", aim, str(fixed))
			hint("fixings")
		elif world.group_mass(p) > Tools.GRAB_MAX_T:
			say("too_heavy", aim, "%.1f" % world.group_mass(p))
	elif p.body.total_mass() > Tools.GRAB_MAX_T:
		say("too_heavy", aim, "%.1f" % p.body.total_mass())
		hint("heavy")


func on_tear(p, weak: Array, lines_held: Array, at: Vector2) -> void:
	incident("torn", p.tag)
	var dmg := 0.0
	for j in weak:
		world.kill_joint(j)
		dmg += 0.12
	for l in lines_held:
		var volts := _cut_cable_volts(l) if l.kind == "cable" else 0.0
		world.kill_line(l, world.line_end_world(l, 0 if l.a == p.id else 1))
		dmg += 0.15
		if volts > 30.0:
			_arc(at, volts * 0.5)
		elif l.kind == "pipe":
			on_line_cut(l, at)
	if p.cls == "equip" and p.intact:
		var before: float = p.cond
		p.cond = maxf(0.0, p.cond - dmg * (0.5 + p.fragile))
		var lost: float = (before - p.cond) * p.value
		if lost > 50.0:
			fx.number(at + Vector2(0, -24), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 18)
	fx.sparks(at, Vector2.from_angle(randf() * TAU), 14, Pal.ink(0.9, 1.4), 300.0, 0.35, PI)
	shake(0.25)
	sfx.play("snap")
	say("torn_free", at)
	hint("torn")


# ---------------------------------------------------------------- measure / wrench / hose

func do_measure(tg: Dictionary) -> void:
	match tg.kind:
		"ctrl":
			var c = tg.ctrl
			if c.kind == "discharge":
				sys.measure(c.id, "volts", c.id, "inst_volts", {"ctrl": c, "volts_fn": _ctrl_volts_fn(c)})
			else:
				match c.medium:
					"gas":
						sys.measure(c.id, "pressure", c.id, "inst_pressure", {"ctrl": c, "vol": c.target})
						if sys.dead_leg_closed(c):
							hint("dead_leg")
					"volt":
						sys.measure(c.id, "volts", c.id, "inst_volts", {"ctrl": c, "volts_fn": _ctrl_volts_fn(c)})
						if sys.remote_sent and sys.bus_live:
							hint("not_off")
					_:
						if sys.fluid_at_port(c.id) != "":
							sys.measure(c.id, "fluid", c.id, "inst_fluid", {"ctrl": c, "fluid_fn": func(): return sys.port_level(c.id)})
						if sys.is_heat_port(c.id):
							sys.measure(c.id + "/T", "temp", c.id, "inst_temp", {"ctrl": c, "temp_fn": func(): return sys.loop_T})
		"line":
			var l = tg.line
			if l.kind == "cable":
				sys.measure("L:" + l.id, "volts", l.id.to_upper(), "inst_volts", {"anchor_pos": tg.pos, "volts_fn": func(): return sys.line_volts(l)})
			else:
				sys.measure("L:" + l.id, "temp", l.id.to_upper(), "inst_temp", {"anchor_pos": tg.pos, "temp_fn": func(): return sys.line_temp(l)})
		"inspect", "piece":
			var p = tg.piece
			var key := "P:%d" % p.id
			var local: Vector2 = world.frame(p).affine_inverse() * tg.pos
			var label: String = p.tag if p.tag != "" else Txt.piece_name(p)
			sys.measure(key, "temp", label, "inst_inspect", {"piece": p, "local": local, "inspect": _inspect_text(p), "temp_fn": func(): return p.temp})
			if sys.electric_piece(p):
				sys.measure(key + "/V", "volts", label, "inst_volts", {"piece": p, "local": local + Vector2(0, 16), "volts_fn": func(): return sys.piece_volts(p)})
	sfx.play("measure")
	fx.ring(tg.pos, 4.0, 26.0, 0.35, Pal.ink(0.8, 1.3), 1.4)
	hint("measured")


func restore_reading(rd: Dictionary) -> void:
	var key: String = rd.key
	var extra := {}
	if key.begins_with("L:"):
		var l = world.lines.get(key.substr(2))
		if l == null:
			return
		extra = {"anchor_pos": world.line_path_world(l)[0]}
		if rd.kind == "volts":
			extra.volts_fn = func(): return sys.line_volts(l)
		else:
			extra.temp_fn = func(): return sys.line_temp(l)
	elif key.begins_with("P:"):
		var pid := int(key.substr(2).split("/")[0])
		var p = world.pieces.get(pid)
		if p == null or p.gone:
			return
		extra = {"piece": p, "local": Geom.centroid(p.poly)}
		if rd.kind == "volts":
			extra.local += Vector2(0, 16)
			extra.volts_fn = func(): return sys.piece_volts(p)
		else:
			extra.inspect = _inspect_text(p)
			extra.temp_fn = func(): return p.temp
	else:
		var cid: String = key.split("/")[0]
		var c = world.ctrls.get(cid)
		if c == null:
			return
		extra = {"ctrl": c, "vol": rd.vol}
		match rd.kind:
			"volts":
				extra.volts_fn = _ctrl_volts_fn(c)
			"fluid":
				extra.fluid_fn = func(): return sys.port_level(c.id)
			"temp":
				extra.temp_fn = func(): return sys.loop_T
	var r := {"key": key, "kind": rd.kind, "at": rd.at, "inst": rd.inst, "t": rd.t, "val": rd.val, "text": rd.text, "ver": int(rd.ver), "vk": ""}
	r.merge(extra, true)
	sys.readings[key] = r


# What a volt probe on this control shows: a discharge plug reads its
# capacitor's own cable, a test point reads the bus.
func _ctrl_volts_fn(c) -> Callable:
	if c.kind == "discharge":
		var cap_tag: String = sys.discharge_source(c.id)
		var l3 = world.lines.get(sys.src[cap_tag].cable) if cap_tag != "" else null
		return func(): return sys.line_volts(l3) if l3 != null and l3.alive else 0.0
	return func(): return sys.bus_volts()


func _inspect_text(p) -> String:
	var counts := {}
	for j in world.joints_of(p):
		counts[j.type] = counts.get(j.type, 0) + 1
	var nl := world.lines_of(p).size()
	var parts: Array = ["%.2f t" % world.group_mass(p)]
	for k in ["bolt", "weld", "lock", "clamp"]:
		if counts.has(k):
			parts.append("%d %s" % [counts[k], txt("j_" + k)])
	if nl > 0:
		parts.append("%d %s" % [nl, txt("j_line")])
	if parts.size() == 1 and p.body == null:
		parts.append(txt("j_none"))
	return " · ".join(parts)


func do_wrench(tg: Dictionary) -> void:
	match tg.kind:
		"joint":
			var j = tg.joint
			var p: Vector2 = world.joint_world(j)
			world.kill_joint(j)
			fx.shard(p, Vector2(-3, 0), Vector2(3, 0), Vector2.from_angle(randf() * TAU) * 120.0, randf_range(-12, 12), 0.7, Pal.ink(0.9), 2.0)
			fx.ring(p, 3.0, 18.0, 0.3, Pal.ink(0.7, 1.2))
			sfx.play("unbolt" if j.type != "clamp" else "clamp_off")
			if j.type == "clamp":
				shake(0.2)
				say("clamp_off", p, j.get_meta("tag", ""))
		"connector":
			var l = tg.line
			if l.kind == "pipe":
				var amt: float = sys.line_fluid(l)
				if amt > 0.02:
					say("pipe_full", tg.pos)
					sfx.play("deny")
					hint("pipe_full")
					return
				if sys.line_temp(l) > 60.0:
					say("pipe_hot", tg.pos, str(int(sys.line_temp(l))))
					sfx.play("deny")
					hint("pipe_hot")
					return
			else:
				var volts := _cut_cable_volts(l)
				if volts > 30.0:
					fx.arc(tg.pos, tg.pos + Vector2.from_angle(randf() * TAU) * 30.0, 0.25, 0.6)
					fx.flash(tg.pos, 80.0, 0.25, Pal.tint(Pal.VOLT, 1.0, 2.0))
					hurt_drone(15.0, tg.pos, "live_unplug", "unplug", 0.5)
			world.kill_line(l, tg.pos)
			sfx.play("unplug")
			fx.sparks(tg.pos, Vector2.UP, 4, Pal.ink(0.8, 1.2), 90.0, 0.2, PI)
		"ctrl":
			_operate(tg.ctrl, tg.pos)


func _operate(c, at: Vector2) -> void:
	match c.kind:
		"valve":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("valve_open" if c.state else "valve_closed", at, c.id)
			sfx.play("valve")
		"switch":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("sw_on" if c.state else "sw_off", at, c.id)
			sfx.play("switch")
		"remote":
			# a remote stop may or may not reach the machine: the ship file says
			sys.remote_sent = true
			c.state = true
			var rt: String = Ship.ctrl_cfg(ship, c.id).get("target", "")
			if sys.src.has(rt) and sys.src[rt].get("remote_works", true):
				sys.stop_source(rt)
			say("remote_sent", at)
			sfx.play("switch")
			hint("remote")
		"stop":
			var st: String = Ship.ctrl_cfg(ship, c.id).get("target", "")
			if sys.running(st):
				sys.stop_source(st)
				say("gen_stopped", at)
				sfx.play("gen_down")
				shake(0.15)
		"socket":
			sys.aux = not sys.aux
			c.state = sys.aux
			sys.set_switch(c.id, sys.aux)
			say("aux_on" if sys.aux else "aux_off", at)
			sfx.play("plug")
		"discharge":
			c.state = not c.state
			sys.set_switch(c.id, c.state)
			say("discharge_on" if c.state else "discharge_off", at)
			sfx.play("plug")
		"door":
			if not (sys.bus_live or sys.aux):
				say("no_power", at)
				sfx.play("deny")
				hint("no_power")
				return
			var dp = world.tag(c.target)
			if dp == null:
				return
			dp.door_open = not dp.door_open
			c.state = dp.door_open
			sfx.play("door")
		"jam":
			if c.state:
				return
			c.state = true
			say("jam_cleared", at)
			sfx.play("unjam")
			fx.sparks(at, Vector2.UP, 12, Pal.ink(0.9, 1.4), 200.0, 0.3, 1.2)
		"hatch":
			var hc := Ship.ctrl_cfg(ship, c.id)
			var jam = world.ctrls.get(hc.get("jam", ""))
			if jam != null and not jam.state:
				say("hatch_jammed", at)
				sfx.play("deny")
				hint("hatch_jam")
				return
			var feed = world.lines.get(hc.get("cable", ""))
			var powered: bool = (sys.bus_live and (feed == null or feed.alive)) or sys.aux
			if not powered:
				say("no_power", at)
				sfx.play("deny")
				hint("no_power")
				return
			for t in hc.get("doors", []):
				var hp = world.tag(t)
				if hp != null and hp.body == null:
					hp.door_open = not hp.door_open
			sfx.play("hatch")
			shake(0.2)


func do_hose(tg: Dictionary) -> void:
	var c = tg.ctrl
	if sys.hoses.has(c.id):
		sys.hoses.erase(c.id)
		dock.hose_detach(c.id)
		say("hose_off", tg.pos, c.id)
		sfx.play("unplug")
		return
	var mode := tools.hose_mode if c.medium == "gas" else "recover"
	if sys.dead_leg_closed(c):
		hint("dead_leg_hose")
	sys.hoses[c.id] = {"mode": mode, "t": 0.0}
	dock.hose_attach(c.id, tg.pos)
	say("hose_on_" + mode, tg.pos, c.id)
	sfx.play("hose_on")
	hint("hose")


# ---------------------------------------------------------------- gas & room events

func on_reveal(room: String, from: Vector2) -> void:
	reveal_count += 1
	if state == "play":
		sfx.play("reveal", from)
		say("room_open", from, room_name(room))


func on_blowout(room: String, pos: Vector2, dir: Vector2, p0: float) -> void:
	incident("blowout", room)
	shake(0.55, dir)
	hitstop(0.06)
	fx.flash(pos, 260.0, 0.6, Pal.tint(Pal.AIR, 0.6, 1.8))
	fx.ring(pos, 10.0, 260.0, 0.6, Pal.tint(Pal.AIR, 0.7, 1.5), 3.0)
	for i in 40:
		var d := dir.rotated(randf_range(-0.5, 0.5))
		fx.spark(pos, d * randf_range(500, 1100), randf_range(0.3, 0.7), Pal.tint(Pal.AIR, 0.8, 1.6), 1.4, 16.0, 1.2)
	fx.burst_shards(pos, 12, 500.0, Pal.ink(0.8), 7.0)
	hud.white_flash(0.12)
	sfx.play("blowout", pos)
	say("blowout", pos, room_name(room))
	var k := clampf(p0 / 108.0, 0.2, 1.2)
	var lost := 0.0
	for id in world.order:
		var q = world.pieces[id]
		if q.gone or q.room != room or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		q.cond = maxf(0.0, q.cond - q.fragile * 0.45 * k)
		lost += (before - q.cond) * q.value
	if lost > 100.0:
		fx.number(pos + Vector2(0, -40), "−" + Pal.money(lost).trim_prefix("$"), Pal.heat(0.9, 1.3), 20)
	for b in world.bodies:
		var d: Vector2 = pos - b.global_position
		if world.room_at(b.global_position) == room or d.length() < 4.0 * 48.0:
			b.apply_central_impulse((d.normalized() + dir) * b.mass * 180.0 * k)
	hint("blowout")


func on_jet(room: String, pos: Vector2, dir: Vector2, p: float, g: float) -> void:
	var strength := clampf(p / 100.0, 0.0, 1.2) * clampf(g / 8.0, 0.1, 1.5)
	if strength < 0.01:
		return
	var n := int(strength * 6.0) + (1 if randf() < strength * 6.0 - int(strength * 6.0) else 0)
	for i in n:
		var d := dir.rotated(randf_range(-0.35, 0.35))
		fx.puff(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), d * randf_range(260, 620) * (0.5 + strength), randf_range(0.35, 0.8), 3.0, 18.0 + 30.0 * strength, Pal.tint(Pal.AIR, 0.09 + 0.06 * strength))
	if randf() < strength:
		fx.spark(pos, dir.rotated(randf_range(-0.3, 0.3)) * 500.0, 0.25, Pal.tint(Pal.AIR, 0.6, 1.2), 1.0, 8.0, 2.0)
	sfx.jet(strength)
	# the stream shoves what is in it
	for b in world.bodies:
		var rel: Vector2 = b.global_position - pos
		if rel.length() < 3.5 * 48.0 and rel.dot(dir) > -20.0:
			b.apply_central_force(dir * b.mass * 600.0 * strength)
		elif world.room_at(b.global_position) == room and rel.length() < 6.0 * 48.0:
			b.apply_central_force(-rel.normalized() * b.mass * 300.0 * strength)
	if drone.alive:
		var rd := drone.global_position - pos
		if rd.length() < 3.0 * 48.0 and rd.normalized().dot(dir) > 0.4:
			drone.external += dir * drone.mass * 900.0 * strength
			if strength > 0.5 and rd.length() < 1.6 * 48.0:
				hurt_drone(25.0, pos, "jet_hit", "jet", 1.5)


func on_discharge_refused(ctrl_id: String) -> void:
	var c = world.ctrls.get(ctrl_id)
	if c != null:
		c.state = false
		say("discharge_refused", world.ctrl_world(c))
	sfx.play("deny")
	hint("discharge_refused")


# ---------------------------------------------------------------- messages & hints

func say(key: String, at: Vector2, arg: String = "") -> void:
	var text := txt(key)
	if text.find("%s") >= 0:
		text = text % arg
	for m in messages:
		if m[3] == text and m[2] < 1.2:
			m[2] = 0.0
			m[1] = at
			return
	messages.append([key, at, 0.0, text])
	while messages.size() > 6:
		messages.remove_at(0)


func _age_messages(dt: float) -> void:
	for m in messages:
		m[2] += dt
	messages = messages.filter(func(m): return m[2] < 2.6)
	for f in feed:
		f[2] += dt
	feed = feed.filter(func(f): return f[2] < 5.0)
	while feed.size() > 5:
		feed.pop_back()


func hint(key: String) -> void:
	if not hints_on or hints_seen.has(key):
		return
	if Txt.has("hint_" + key):
		hints_seen[key] = true
		hud.show_hint(txt("hint_" + key))
