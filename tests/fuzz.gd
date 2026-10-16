extends SceneTree
# Random hands on every tool all over the ship, to shake out script errors.
# tools/run_test.sh tests/fuzz.gd --fixed-fps 60 -- [seed] [frames]

const M := 48.0
var game
var frame := 0
var rng := RandomNumberGenerator.new()
var frames := 3000
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "dash": false, "brake": false}
var target := Vector2.ZERO


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	rng.seed = int(a[0]) if a.size() > 0 else 1
	if a.size() > 1:
		frames = int(a[1])
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	var off := OS.get_environment("ZP_OFF")
	if off != "":
		await process_frame
		for c in game.get_children():
			if c.get_class() == "Node2D" and c.get_script() != null and c.get_script().get_global_name() == off:
				c.process_mode = Node.PROCESS_MODE_DISABLED
				c.visible = false
				print("disabled ", off)
	Engine.time_scale = float(OS.get_environment("ZP_TS")) if OS.get_environment("ZP_TS") != "" else 2.0


var last_us := 0
var slow := 0


func _process(_dt: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ft := (now - last_us) / 1000.0
	last_us = now
	if frame > 5 and ft > 60.0 and slow < 25:
		slow += 1
		var pend := []
		for id in game.tools.pending:
			pend.append(game.tools.pending[id].pl.size())
		var maxv := 0
		for id in game.world.order:
			maxv = maxi(maxv, game.world.pieces[id].poly.size())
		print("SLOW %.0f ms frame %d tool %d cutting %s pending %s maxverts %d bodies %d hoses %d prof %s" % [ft, frame, game.tools.tool, game.tools.cutting, pend, maxv, game.world.bodies.size(), game.sys.hoses.size(), World.prof])
	if frame % 90 == 1:
		# hop the drone somewhere around the ship and pick a tool
		var side := rng.randi_range(0, 3)
		var p := Vector2(rng.randf_range(0, 34), rng.randf_range(-6.4, -4.7)) * M
		if side == 1:
			p = Vector2(rng.randf_range(0, 34), rng.randf_range(4.7, 6.4)) * M
		elif side == 2:
			p = Vector2(rng.randf_range(33.5, 44), rng.randf_range(-5, 5)) * M
		elif side == 3:
			# inside an opened room
			var names := ["A", "B", "C", "D", "E"]
			var n: String = names[rng.randi() % 5]
			game.world.reveal(n, game.world.rooms[n].from)
			p = game.world.rooms[n].from
		game.drone.global_position = p
		game.drone.linear_velocity = Vector2.ZERO
		game.drone.reset_physics_interpolation()
		game.tools.set_tool(rng.randi_range(1, 5))
		if rng.randf() < 0.3:
			for n in game.world.rooms:
				if rng.randf() < 0.5:
					game.world.reveal(n, game.world.rooms[n].from)
	if frame % 12 == 0:
		target = game.drone.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 190)
	bot.aim = bot.aim.lerp(target, 0.2)
	if frame % 7 == 0:
		bot.lmb = rng.randf() < 0.6
	if frame % 30 == 0:
		bot.move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) if rng.randf() < 0.5 else Vector2.ZERO
		bot.dash = rng.randf() < 0.2
		bot.brake = rng.randf() < 0.2
	if frame % 400 == 0:
		print("frame ", frame, " pieces ", game.world.pieces.size(), " bodies ", game.world.bodies.size(), " earned ", int(game.earned()), " drone ", int(game.drone.integrity))
		game.blueprint.toggle()
	return frame >= frames
