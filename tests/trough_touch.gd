extends SceneTree
# P.3 (player 2026-10-17): "the conveyor is suction-based, not carry-on-touch".
# Scrap rides the trough the moment any part of it touches the belt, held by
# the grapple or not (the grapple lets go); scrap let go a couple of metres
# above the trough is drawn down into it.
# tools/run_test.sh tests/trough_touch.gd --fixed-fps 60
const M := 48.0
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var done := false
var fails := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


# a loose scrap plate 1.25 m x 0.4 m centred at c (px)
func plate(g: Node, c: Vector2, tag: String):
	var poly := PackedVector2Array([c + Vector2(-30, -10), c + Vector2(30, -10), c + Vector2(30, 10), c + Vector2(-30, 10)])
	var p = g.world.add_piece("hull", poly, {"density": 1.0, "tag": tag})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var lip := Dock.TROUGH_Y * M
	# far from the furnace's own field, so only the trough can take it
	var x := (Dock.TROUGH_X0 + 1.5) * M
	var lowest := -INF
	for id in g.world.pieces:
		var q = g.world.pieces[id]
		if not q.gone:
			for v in g.world.world_poly(q):
				lowest = maxf(lowest, v.y)
	print("TROUGH: ship's lowest point %.1f m, lip %.1f m" % [lowest / M, Dock.TROUGH_Y])
	print("TROUGH: furnace at %.1f m, test plates at %.1f m" % [Dock.metal_x, x / M])

	# 1. resting with its lower edge just over the lip (centre still above)
	var a = plate(g, Vector2(x, lip - 6.0), "TT-1")
	await frames(20)
	check(a.body == null or not is_instance_valid(a.body) or a.body.capture != null or a.gone, "a plate whose edge touches the belt is carried")

	# 2. held by the grapple and dragged onto the belt: the grapple lets go
	var b = plate(g, Vector2(x + 2.5 * M, lip - 40.0), "TT-2")
	await frames(2)
	g.drone.global_position = Vector2(x + 2.5 * M, lip - 3.0 * M)
	g.drone.reset_physics_interpolation()
	g.tools.set_tool(3, true)
	g.tools.held_piece = b
	g.tools.held_body = b.body
	g.tools.held_local = g.world.frame(b).affine_inverse() * (g.world.frame(b) * Geom.centroid(b.poly))
	b.body.linear_velocity = Vector2(0, 120)
	var taken := false
	for i in 90:
		g.bot.aim = b.body.global_position + Vector2(0, 60) if is_instance_valid(b.body) else g.bot.aim
		g.bot.lmb = true
		await process_frame
		if b.gone or b.body == null or not is_instance_valid(b.body) or b.body.capture != null:
			taken = true
			break
	g.bot.lmb = false
	check(taken and g.tools.held_body == null, "a plate the grapple drags onto the belt is carried and the grapple lets go")

	# 3. let go 2 m over the trough, at rest: the suction draws it down
	var c = plate(g, Vector2(x + 5.0 * M, lip - 2.0 * M), "TT-3")
	var sucked := false
	for i in 150:
		await process_frame
		if c.gone or c.body == null or not is_instance_valid(c.body) or c.body.capture != null:
			sucked = true
			break
	check(sucked, "a plate let go 2 m above the trough is drawn in within 2.5 s")

	# 4. over the suction's reach (3.2 m): left alone
	var d = plate(g, Vector2(x, lip - 3.2 * M), "TT-4")
	var y0: float = d.body.global_position.y
	await frames(60)
	if d.body != null and is_instance_valid(d.body):
		print("    TT-4 moved %.2f m, capture %s, v %s" % [(d.body.global_position.y - y0) / M, d.body.capture, d.body.linear_velocity.round()])
	check(not d.gone and d.body != null and is_instance_valid(d.body) and d.body.capture == null and absf(d.body.global_position.y - y0) < 0.5 * M, "a plate 3.2 m above the trough stays put")

	print("TROUGH_TOUCH %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	done = true
