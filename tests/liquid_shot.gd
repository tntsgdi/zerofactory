extends SceneTree
# Close looks at liquid adrift (scripts/liquids.gd), in the game's own view: BL-88's
# ball just burst, a fuel line cut on FX-70, DR-150's mud blowout, liquid hydrogen
# spitting from HG-170's relief valve and boiling.
# tools/run_test.sh tests/liquid_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_liqshot_career.json"
	SaveGame.path = "user://zp_test_liqshot_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	# the survey flight over a newly arrived ship holds the camera: let it finish
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	return g


func _look(g, at: Vector2, zoom: float, wait: int, name: String) -> void:
	g.zoom_override = zoom
	g.cam_override = at * Geom.M
	for i in wait:
		await process_frame
	Cap.save(root, "res://tests/out/%s.png" % name)


func _run() -> void:
	var g = await _game("bl88")
	var net = g.world.tag("NET-T")
	g.on_cut_into(net, Geom.bbox(g.world.world_poly(net)).get_center())
	await _look(g, Vector2(44.0, 0.0), 1.1, 70, "liq_ball")
	await _look(g, Vector2(44.0, 0.0), 1.1, 300, "liq_ball_later")
	g.queue_free()
	await process_frame

	g = await _game("fx70")
	var l = g.world.lines["f1"]
	g.world.kill_line(l)
	g.on_line_cut(l, (l.pa + l.pb) * 0.5)
	var c: Vector2 = (l.pa + l.pb) * 0.5 / Geom.M
	await _look(g, c, 2.2, 40, "liq_fuel_jet")
	await _look(g, c, 2.2, 160, "liq_fuel")
	g.queue_free()
	await process_frame

	g = await _game("dr150")
	g.drillstring.torque = 0.0
	for k in 8:
		g.sys.switch["SLIP-%d" % (k + 1)] = true
	var st = g.world.tag("J-1")
	for j in g.world.joints_of(st):
		g.world.kill_joint(j)
	await _look(g, Vector2(50.0, -22.0), 0.8, 50, "liq_mud")
	g.queue_free()
	await process_frame

	g = await _game("hg170")
	var rv = g.world.tag("RV-2")
	var at: Vector2 = g.world.frame(rv) * Geom.centroid(rv.poly)
	# the camera there first (it eases in), then the valve spits
	g.zoom_override = 1.8
	g.cam_override = at + Vector2(0.0, -0.6) * Geom.M
	for i in 50:
		await process_frame
	for i in 5:
		g.liquids.spill(at, Vector2(1.0 if i % 2 == 0 else -1.0, -0.2), 0.02, "lh2", 4, 0.9, 2.0, false)
		for k in 6:
			await process_frame
	print("SHOT lh2 globules ", g.liquids.count())
	Cap.save(root, "res://tests/out/liq_lh2.png")
	quit()
