extends SceneTree
# Still of the two hauling drones in their own airframes (H2 core-claw, C tripod)
# next to the operator's (2026-10-17). tools/run_test.sh tests/hauler_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const M := 48.0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1}}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	await _frames(30)
	var at: Vector2 = g.hauler.home()
	g.drone.alive = true
	g.drone.global_position = at + Vector2(3.2 * M, 0.4 * M)
	g.drone.reset_physics_interpolation()
	g.bot.aim = at + Vector2(6 * M, -1 * M)
	g.zoom_override = 2.6
	g.cam_override = at + Vector2(1.6 * M, 0.2 * M)
	await _frames(90)
	print("haulers at %s and %s" % [g.hauler.pos / M, g.hauler2.pos / M])
	Cap.save(root, "res://tests/out/haulers.png")
	quit()
