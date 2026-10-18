extends SceneTree
# P.6 (player 2026-10-17): "I can't see the whole ship". The wheel zooms out
# until the whole berth and the ship are in view, the view settling on the
# berth's middle; the berth map stays on screen while working the ship and
# shows the drone, the mouths and what is hauled. Stills of both.
# tools/run_test.sh tests/zoom_map.gd --fixed-fps 60 -- [m14]
const Cap = preload("res://tests/cap.gd")
const M := 48.0
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


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	if "m14" in OS.get_cmdline_user_args():
		Game.start_ship = "m14"
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.training = false
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].from)
	await frames(30)
	# the map is up, bottom right, and inside the screen
	var mm: Control = g.hud.minimap
	var s: Vector2 = g.hud.size()
	check(mm.visible and Rect2(Vector2.ZERO, s).encloses(Rect2(mm.position, mm.map_size)), "the berth map is on screen (%s at %s)" % [mm.map_size, mm.position])
	# haul a loose piece: the map outlines it
	var c := Vector2(30.0, -6.0) * M
	var poly := PackedVector2Array([c + Vector2(-40, -14), c + Vector2(40, -14), c + Vector2(40, 14), c + Vector2(-40, 14)])
	var p = g.world.add_piece("hull", poly, {"density": 1.0, "tag": "ZM-1"})
	g.world.make_body([p], null)
	g.drone.global_position = c + Vector2(2.0 * M, -0.5 * M)
	g.drone.reset_physics_interpolation()
	g.tools.set_tool(3, true)
	g.tools.held_piece = p
	g.tools.held_body = p.body
	g.tools.held_local = Geom.centroid(p.poly)
	g.bot.lmb = true
	g.bot.aim = c
	await frames(40)
	Cap.save(root, "res://tests/out/minimap_haul.png")
	g.bot.lmb = false
	# wheel all the way out
	for i in 30:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		g._unhandled_input(ev)
	check(is_equal_approx(g.zoom_target, g.zoom_min()), "the wheel goes out to the whole berth (zoom %.2f, fit %.2f)" % [g.zoom_target, g.zoom_min()])
	await frames(150)
	var half: Vector2 = s * 0.5 / g.cam.zoom.x
	var view := Rect2(g.cam.global_position - half, half * 2.0)
	var bb := Rect2()
	var first := true
	for id in g.world.pieces:
		var q = g.world.pieces[id]
		if q.gone or q.body != null:
			continue
		for v in g.world.world_poly(q):
			bb = Rect2(v, Vector2.ZERO) if first else bb.expand(v)
			first = false
	check(view.encloses(bb), "the whole ship is in view (view %s m, ship %s m)" % [Rect2(view.position / M, view.size / M), Rect2(bb.position / M, bb.size / M)])
	Cap.save(root, "res://tests/out/zoom_whole.png")
	print("ZOOM_MAP %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	done = true
