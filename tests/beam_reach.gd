extends SceneTree
# Regression (player report 2026-10-17, M-14): "a very long line while cutting".
# The beam is drawn from the drone to its front; the front crawls through
# material but the drone flies, so holding the button while flying away (or
# while the piece drifts off) stretched the beam far past the laser's reach.
# The beam must never be longer than the laser reaches (a little slack for
# one frame's travel).
# tools/run_test.sh tests/beam_reach.gd --fixed-fps 60
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var done := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var c := Vector2(4000, 4000)
	# a thick, slow-cutting block clamped in place
	var poly := PackedVector2Array([c + Vector2(-60, -60), c + Vector2(60, -60), c + Vector2(60, 60), c + Vector2(-60, 60)])
	var blk = g.world.add_piece("hull", poly, {"density": 2.0, "cut_speed": 60.0, "tag": "BR-1"})
	g.world.add_joint(blk, null, "clamp", c + Vector2(-50, -50))
	g.world.rebuild_cols(blk)
	await frames(2)
	g.tools.set_tool(2, true)
	g.drone.global_position = c + Vector2(0, 120)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.bot.aim = c + Vector2(-40, 0)
	g.bot.lmb = true
	await frames(10)
	# keep the button down and fly away fast, the pointer dragged along with the drone
	var reach: float = g.tools.reach(2)
	var worst := 0.0
	for i in 120:
		g.drone.global_position += Vector2(9.0, 4.0)
		g.drone.linear_velocity = Vector2(540, 240)
		g.bot.aim = g.drone.global_position + Vector2(-80, -60)
		await process_frame
		if g.tools.cutting:
			worst = maxf(worst, g.tools.front.distance_to(g.drone.global_position))
	g.bot.lmb = false
	await frames(10)
	var ok := worst <= reach * 1.15
	print("beam longest %.0f px, laser reach %.0f px" % [worst, reach])
	print("BEAM_REACH %s" % ("PASS" if ok else "FAIL"))
	done = true
