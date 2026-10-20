extends SceneTree
# Roadmap 6.3's first step: can the game carry a ship at ARK-01's scale (~600 m,
# ~1,100 pieces, 19 rooms)? Times the start (the ship built, the gas grid and its
# topology), the idle frame, a spine segment vented to space, and 40 pieces knocked
# loose at once. Headless: the simulation's cost, not the drawing's.
# godot --headless --path . --fixed-fps 60 -s tests/ark_perf.gd

var finished := false
var report := {}


func _initialize() -> void:
	SaveGame.path = "user://zp_test_arkperf_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _time(n: int) -> Array:
	var worst := 0.0
	var sum := 0.0
	for i in n:
		var t0 := Time.get_ticks_usec()
		await process_frame
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		sum += dt
		worst = maxf(worst, dt)
	return [sum / n, worst]


func _run() -> void:
	Game.contract = {}
	var ship_id := "arktest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship_id = a.substr(5)
	Game.start_ship = ship_id
	var t0 := Time.get_ticks_usec()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	await _frames(2)
	var g = scene
	report.start_ms = (Time.get_ticks_usec() - t0) / 1000.0
	report.pieces = g.world.order.size()
	report.cells = "%d x %d @ %.2f m" % [g.sys.GW, g.sys.GH, g.sys.CELL]
	report.berth = Dock.FLOOR_X1
	await _frames(30)
	report.idle = await _time(120)
	World.prof.clear()
	# one plate taken off, alone (what a single cut-through costs)
	var one = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		var cc: Vector2 = Geom.centroid(p.poly) / Geom.M
		if p.kind == "hull" and p.barrier and cc.y < -5.0 and cc.y > -6.5 and cc.x > 300.0 and cc.x < 340.0:
			one = p
			break
	var t2 := Time.get_ticks_usec()
	g.world.remove_piece(one)
	report.remove_one_ms = (Time.get_ticks_usec() - t2) / 1000.0
	report.remove_one_frames = await _time(3)
	report.prof_one = World.prof.duplicate()
	World.prof.clear()
	# a spine segment opened to space: its top plates gone
	var t1 := Time.get_ticks_usec()
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.tag.begins_with("HS" if ship_id != "arktest" else "HS5") and p.kind == "hull" and (ship_id == "arktest" or absf(Geom.centroid(p.poly).x / Geom.M - 141.0) < 12.0):
			var c: Vector2 = Geom.centroid(p.poly)
			if c.y < -5.0 * Geom.M:
				g.world.remove_piece(p)
	g.sys.topology_dirty = true
	await _frames(1)
	report.vent_step_ms = (Time.get_ticks_usec() - t1) / 1000.0
	report.venting = await _time(120)
	report.prof_vent = World.prof.duplicate()
	# the gas grid's job runs on a worker in real time; headless frames run faster than
	# that, so wait it out (and time how long a breach takes to register)
	var tj := Time.get_ticks_usec()
	while g.sys.job_id >= 0 or g.sys.topology_dirty:
		await process_frame
	report.breach_register_ms = (Time.get_ticks_usec() - tj) / 1000.0
	await _frames(240)
	report.s5_kpa = g.sys.P("S5")
	report.space_links = g.sys.links.filter(func(l): return l[1] == "space").map(func(l): return l[0])
	# forty pieces knocked loose at once
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.cls == "equip" and not p.gone and p.body == null and p.room in ["S5", "S6"] and n < 40:
			for j in g.world.joints_of(p):
				g.world.kill_joint(j)
			n += 1
	await _frames(2)
	report.loose = n
	report.loose_frames = await _time(120)
	print("ARK PERF ", JSON.stringify(report))
	finished = true
