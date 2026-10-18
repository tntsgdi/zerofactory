extends SceneTree
# Still of the laser closing on intact equipment (C-01): beam and outline red.
# tools/run_test.sh tests/laser_warn_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = bot
	root.add_child(g)
	await _frames(10)
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].from)
	await _frames(20)
	g.drone.global_position = Vector2(12.4, -1.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.tools.set_tool(2)
	g.zoom_target = 2.2
	g.cam_pos = Vector2(12.4, -0.3) * M
	await _frames(60)
	bot.aim = Vector2(12.4, -0.2) * M
	await _frames(4)
	bot.lmb = true
	bot.aim = Vector2(12.4, 0.5) * M
	for i in 40:
		await process_frame
		if not g.tools.warn.is_empty() and g.tools.warn.get("d", 99.0) < 20.0:
			break
	await _frames(3)
	print("warned: %s, %.0f px from %s" % [not g.tools.warn.is_empty(), g.tools.warn.get("d", -1.0), g.world.pieces.get(g.tools.warn.get("piece", -1)).tag if not g.tools.warn.is_empty() else "-"])
	Cap.save(root, "res://tests/out/laser_warn.png")
	quit()
