extends SceneTree
# Still of the equipment bay moved along its ceiling rail past the boom (P.5).
# tools/run_test.sh tests/equip_rail_shot.gd --fixed-fps 60

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
	g.tutorial = null
	g.drone.global_position = Vector2(33.0, -6.5) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.dock.move_equip(33.0)
	g.zoom_target = 1.0
	g.cam_pos = Vector2(28.0, -6.0) * M
	await _frames(150)
	Cap.save(root, "res://tests/out/equip_rail.png")
	quit()
