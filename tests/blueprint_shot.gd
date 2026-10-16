extends SceneTree
# The factory drawing at the closest zoom and at the default zoom: labels must
# stay sharp (they are drawn at screen size, not stretched by the camera).
# tools/run_test.sh tests/blueprint_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
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
	g.blueprint.toggle()
	for z in [2.6, 1.65]:
		g.drone.global_position = Vector2(26.5, -1.0) * 48.0
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		g.zoom_target = z
		g.zoom_now = z
		await _frames(90)
		Cap.save(root, "res://tests/out/blueprint_z%d.png" % int(z * 10))
	quit()
