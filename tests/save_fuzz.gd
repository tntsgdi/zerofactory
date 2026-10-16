extends SceneTree
# Roadmap 1.3 acceptance. Random hands work the ship (like fuzz.gd); at 10
# random moments the game is saved, thrown away and loaded into a fresh game,
# and every piece, joint, line, control, room, system value, accident, reading
# and book entry is compared. Then the main save is damaged on purpose and the
# game must come back from the .bak file.
# tools/run_test.sh tests/save_fuzz.gd --fixed-fps 60 -- [seed]

const M := 48.0
const Snap = preload("res://tests/snap_util.gd")
var game
var frame := 0
var rng := RandomNumberGenerator.new()
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "dash": false, "brake": false}
var target := Vector2.ZERO
var moments: Array = []
var pending := {}          # snapshot taken at save time, waiting for the load
var wait := 0
var fails := 0
var checks := 0
var stage := "fuzz"
var snap_x := {}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	rng.seed = int(a[0]) if a.size() > 0 else 11
	SaveGame.path = "user://zp_test_fuzz_save.json"
	SaveGame.allow_test = true
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ext))
	# migration: a v1 save gains the v2 fields, a save from the future is refused
	var m1 := SaveGame.migrate({"version": 1, "world": {}, "sys": {"VC01": true, "cap": 0.5}, "game": {"bb": true}})
	var m_ok: bool = int(m1.get("version", 0)) == SaveGame.VERSION and m1.sys.has("leaks") and m1.game.has("debris") and m1.sys.switch["V-C01"] and m1.sys.src["CAP-01"].charge == 0.5 and m1.game.must["BB-01"] and m1.ship == "gr7" and SaveGame.migrate({"version": 99, "world": {}, "sys": {}, "game": {}}).is_empty()
	print("migration v1 -> v%d: %s" % [SaveGame.VERSION, "OK" if m_ok else "FAIL"])
	if not m_ok:
		fails += 1
	for i in 10:
		moments.append(rng.randi_range(60, 2400))
	moments.sort()
	root.add_child(preload("res://tests/test_window.gd").new())
	_spawn(false)


func _spawn(load_it: bool) -> void:
	SaveGame.load_requested = load_it
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _snap() -> Dictionary:
	return Snap.snap(game)


func _compare(a: Dictionary, b: Dictionary, label: String) -> int:
	var bad: Array = Snap.diff(a, b)
	checks += 1
	if bad.is_empty():
		print("%s: OK  (%d pieces, %d joints, %d readings, %d leaks, %d free bodies)" % [label, a.pieces.size(), a.joints.size(), a.readings.size(), a.leaks, game.world.bodies.size()])
		return 0
	print("%s: %d MISMATCHES" % [label, bad.size()])
	for l in bad.slice(0, 12):
		print("   ", l)
	return 1


func _hands() -> void:
	if frame % 90 == 1:
		var side := rng.randi_range(0, 3)
		var p := Vector2(rng.randf_range(0, 34), rng.randf_range(-6.4, -4.7)) * M
		if side == 1:
			p = Vector2(rng.randf_range(0, 34), rng.randf_range(4.7, 6.4)) * M
		elif side == 2:
			p = Vector2(rng.randf_range(33.5, 44), rng.randf_range(-5, 5)) * M
		elif side == 3:
			var names := ["A", "B", "C", "D", "E"]
			var n: String = names[rng.randi() % 5]
			game.world.reveal(n, game.world.rooms[n].from)
			p = game.world.rooms[n].from
		game.drone.global_position = p
		game.drone.linear_velocity = Vector2.ZERO
		game.drone.reset_physics_interpolation()
		game.tools.set_tool(rng.randi_range(1, 5))
	if frame % 12 == 0:
		target = game.drone.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 190)
	bot.aim = bot.aim.lerp(target, 0.2)
	if frame % 7 == 0:
		bot.lmb = rng.randf() < 0.6
	if frame % 30 == 0:
		bot.move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) if rng.randf() < 0.5 else Vector2.ZERO


# things random hands rarely manage: readings, a hose, a leak, a blowout
func _events() -> void:
	var w = game.world
	match frame:
		40:
			for id in ["P-C01", "GAS-AB", "E-D01"]:
				var c = w.ctrls.get(id)
				if c != null and w.ctrl_alive(c):
					if c.hidden_room != "":
						w.reveal(c.hidden_room, w.ctrl_world(c))
					game.do_measure({"kind": "ctrl", "ctrl": c, "pos": w.ctrl_world(c)})
		130:
			var c2 = w.ctrls.get("GAS-AB")
			if c2 != null and w.ctrl_alive(c2):
				game.do_hose({"kind": "ctrl", "ctrl": c2, "pos": w.ctrl_world(c2)})
		400:
			var tank = w.tag("T-F01")
			if tank != null and not tank.gone:
				game._leak("fuel", "fuel_tank", tank.center_world(), tank)
			var pump = w.tag("CP-E")
			if pump != null and not pump.gone:
				game._leak("coolant", "cool", pump.center_world(), pump)


func _process(_dt: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		if wait == 0:
			match stage:
				"loaded":
					stage = "fuzz"
				"recover":
					_finish()
					return true
		return false
	if stage == "fuzz":
		_events()
		_hands()
		if game.state == "ending":
			# the bot finished the ship: nothing more to save
			moments = []
		if not moments.is_empty() and frame >= moments[0]:
			moments.pop_front()
			_save_and_reload()
		elif moments.is_empty() and stage == "fuzz":
			_damage_test()
	return false


func _save_and_reload() -> void:
	bot.lmb = false
	if game.tools.cutting:
		game.tools._finish_cut()
	SaveGame.save(game)
	pending = _snap()
	game.queue_free()
	game = null
	_spawn(true)
	# the loaded game has run _ready and nothing else: compare before any sim step
	fails += _compare(pending, _snap(), "moment %d (frame %d)" % [checks + 1, frame])
	stage = "loaded"
	wait = 2


func _damage_test() -> void:
	bot.lmb = false
	if game.tools.cutting:
		game.tools._finish_cut()
	SaveGame.save(game)
	snap_x = _snap()
	# a newer save that then gets torn in half on disk
	SaveGame.save(game)
	var f := FileAccess.open(SaveGame.path, FileAccess.READ_WRITE)
	var n := f.get_length()
	f.seek(n / 2)
	f.store_string("\u0000\u0000garbage")
	f.close()
	game.queue_free()
	game = null
	_spawn(true)
	var ok := SaveGame.recovered
	fails += _compare(snap_x, _snap(), "damaged save -> backup")
	print("recovered flag: ", ok)
	if not ok:
		fails += 1
	stage = "recover"
	wait = 30


func _finish() -> void:
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ext))
	print("SAVE %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
