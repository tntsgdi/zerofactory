extends SceneTree
# Still of the trough's suction while the grapple holds scrap above it (P.3).
# tools/run_test.sh tests/trough_shot.gd --fixed-fps 60

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
	var lip := Dock.TROUGH_Y * M
	var c := Vector2(11.0 * M, lip - 1.6 * M)
	var poly := PackedVector2Array([c + Vector2(-40, -14), c + Vector2(40, -14), c + Vector2(40, 14), c + Vector2(-40, 14)])
	var p = g.world.add_piece("hull", poly, {"density": 1.0, "tag": "TS-1"})
	g.world.make_body([p], null)
	g.drone.global_position = c + Vector2(0, -2.5 * M)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.tools.set_tool(3, true)
	g.tools.held_piece = p
	g.tools.held_body = p.body
	g.tools.held_local = Geom.centroid(p.poly)
	g.zoom_target = 1.4
	g.cam_pos = Vector2(11.0 * M, lip - 2.0 * M)
	bot.lmb = true
	bot.aim = c
	await _frames(50)
	Cap.save(root, "res://tests/out/trough_held.png")
	# let go: the suction draws it down
	bot.lmb = false
	await _frames(14)
	Cap.save(root, "res://tests/out/trough_suck.png")
	quit()
