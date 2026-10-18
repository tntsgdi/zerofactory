extends SceneTree
# Stills of the new airframe in the game (UI animation, 2026-10-17): the launch
# draw-on at four moments, then each of the five tools after its transform.
# tools/run_test.sh tests/drone_shot.gd --fixed-fps 60  (then the crops are tiled)

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
	var at := Vector2(28.0, -7.0) * M
	g.drone.alive = true
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.zoom_override = 3.0
	g.cam_override = at
	bot.aim = at + Vector2(200, -60)
	await _frames(40)
	g.drone.spawn_t = 0.0
	var marks := [0.25, 0.5, 0.8, 1.5]
	var k := 0
	var t := 0.0
	while k < marks.size():
		await process_frame
		t += 1.0 / 60.0
		g.drone.global_position = at
		if t >= marks[k]:
			Cap.save(root, "res://tests/out/dr_boot_%d.png" % k)
			k += 1
	for tool in [1, 2, 3, 4, 5]:
		g.tools.set_tool(tool, true)
		await _frames(24)
		g.drone.global_position = at
		Cap.save(root, "res://tests/out/dr_tool_%d.png" % tool)
	# flat out to the right
	bot.move = Vector2(1, 0)
	bot.dash = true
	await _frames(20)
	g.cam_override = g.drone.global_position
	await _frames(2)
	Cap.save(root, "res://tests/out/dr_dash.png")
	quit()
