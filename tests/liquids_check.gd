extends SceneTree
# Liquid adrift in free fall (scripts/liquids.gd): a cut fuel line jets globules; they
# keep their momentum in vacuum, merge when they touch, wet the wall they reach; a
# cryogen boils away fast, water in vacuum freezes into a ball of ice, mud sticks; a
# laser through fuel lights it; BL-88's ball bursts into drifting globules, DR-150's mud
# blows out as globules; three hundred globules stay cheap.
# godot --headless --path . --fixed-fps 60 -s tests/liquids_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_liquids_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _cut_line(g, id: String) -> void:
	var l = g.world.lines[id]
	var pa: Vector2 = g.world.frame(g.world.pieces[l.a]) * l.pa if false else (l.pa + l.pb) * 0.5
	g.world.kill_line(l)
	g.on_line_cut(l, pa)


func _run() -> void:
	print("liquids: a fuel line cut")
	var g = _game("fx70")
	await _frames(3)
	var lq = g.liquids
	check(lq != null and lq.count() == 0, "nothing adrift at the start")
	_cut_line(g, "f1")
	await _frames(90)
	check(lq.count("fuel") > 3 and lq.spilt_total > 0.001, "the cut fuel line jets globules (%d adrift, %.3f m³)" % [lq.count("fuel"), lq.spilt_total])
	var moving: int = lq.blobs.filter(func(b): return int(b.stuck) < 0 and b.vel.length() > 10.0).size()
	var wet: int = lq.blobs.filter(func(b): return int(b.stuck) >= 0).size()
	await _frames(240)
	wet = lq.blobs.filter(func(b): return int(b.stuck) >= 0).size()
	check(moving > 0 and wet > 0, "some still flying, some already wetting what they hit (%d stuck)" % wet)
	g.queue_free()
	await _frames(2)

	print("liquids: what each liquid does")
	g = _game("fx70")
	await _frames(3)
	lq = g.liquids
	var far := Vector2(-40.0, -40.0) * Geom.M       # well clear of the ship and the berth: vacuum
	lq.spill(far, Vector2.ZERO, 0.02, "lhe", 1, 0.0, 0.0, true)
	var v0: float = lq.total_volume("lhe")
	await _frames(120)
	check(v0 > 0.0 and lq.total_volume("lhe") < v0 * 0.65, "liquid helium in vacuum boils away fast (%.4f → %.4f m³ in 2 s)" % [v0, lq.total_volume("lhe")])
	lq.spill(far + Vector2(0, 6) * Geom.M, Vector2.ZERO, 0.02, "water", 1, 0.0, 0.0, true)
	await _frames(60 * 8)
	var wb: Array = lq.blobs.filter(func(b): return b.look == "water")
	check(wb.size() == 1 and wb[0].ice and float(wb[0].vol) > 0.015, "water left in vacuum freezes over into a ball of ice")
	lq.spill(far + Vector2(10, 0) * Geom.M, Vector2.ZERO, 0.004, "fuel", 1, 0.0, 0.0, true)
	lq.spill(far + Vector2(10.05, 0) * Geom.M, Vector2.ZERO, 0.004, "fuel", 1, 0.0, 0.0, true)
	await _frames(45)
	check(lq.count("fuel") == 1 and absf(lq.total_volume("fuel") - 0.008) < 0.0005, "two globules that touch become one (%.4f m³)" % lq.total_volume("fuel"))
	var inc0: int = g.incidents.size()
	g.tools.cutting = true
	g.tools.front = lq.blobs.filter(func(b): return b.look == "fuel")[0].pos
	lq._burn_check()
	g.tools.cutting = false
	check(g.incidents.size() > inc0 and g.incidents.back()[1] == "fire" and lq.total_volume("fuel") < 0.001, "the laser through a fuel globule: it lights")
	g.queue_free()
	await _frames(2)

	print("liquids: a globule meets a wall")
	g = _game("fx70")
	await _frames(3)
	lq = g.liquids
	# thrown down at the C room's floor from just above it
	lq.spill(Vector2(6.0, 4.6) * Geom.M, Vector2.DOWN, 0.003, "water", 1, 0.0, 0.8, true)
	await _frames(150)
	var w2: Array = lq.blobs.filter(func(b): return b.look == "water")
	check(w2.size() == 1 and int(w2[0].stuck) >= 0, "slow onto the floor: it wets it and stays")
	lq.spill(Vector2(9.0, 4.0) * Geom.M, Vector2.DOWN, 0.01, "water", 1, 0.0, 6.0, true)
	await _frames(40)
	check(lq.count("water") >= 3, "fast into it: it splashes apart (%d globules)" % lq.count("water"))
	g.queue_free()
	await _frames(2)

	print("liquids: the modules' spills")
	g = _game("bl88")
	await _frames(3)
	lq = g.liquids
	var net = g.world.tag("NET-T")
	g.on_cut_into(net, Geom.bbox(g.world.world_poly(net)).get_center())
	await _frames(30)
	check(lq.count("water") > 20 and lq.total_volume("water") > 5.0, "BL-88's ball bursts into %d drifting globules (%.1f m³)" % [lq.count("water"), lq.total_volume("water")])
	await _frames(300)
	check(lq.count("water") > 5 and lq.total_volume("water") > 5.0, "and they are still there five seconds on (%d)" % lq.count("water"))
	g.queue_free()
	await _frames(2)
	g = _game("dr150")
	await _frames(3)
	lq = g.liquids
	g.do_wrench({"kind": "ctrl", "ctrl": g.world.ctrls["TQB"], "pos": Vector2.ZERO})
	for k in 8:
		var c = g.world.ctrls["SLIP-%d" % (k + 1)]
		g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
	await _frames(4)
	g.drillstring.torque = 0.0
	var st = g.world.tag("J-1")
	for j in g.world.joints_of(st):
		g.world.kill_joint(j)
	await _frames(20)
	check(lq.count("mud") > 10, "DR-150's mud blows out as %d globules" % lq.count("mud"))
	await _frames(240)
	var stuck_mud: int = lq.blobs.filter(func(b): return b.look == "mud" and int(b.stuck) >= 0).size()
	check(stuck_mud > 0, "and the mud sticks where it lands (%d)" % stuck_mud)
	# cheap: three hundred globules adrift
	for i in 30:
		lq.spill(Vector2(randf_range(-60, -20), randf_range(-60, -20)) * Geom.M, Vector2.ZERO, 0.05, "fuel", 10, TAU, 0.3, true)
	var t0 := Time.get_ticks_usec()
	for i in 30:
		lq._physics_process(1.0 / 60.0)
	var ms: float = (Time.get_ticks_usec() - t0) / 30.0 / 1000.0
	check(lq.count() > 250 and ms < 5.0, "%d globules: %.2f ms a step" % [lq.count(), ms])
	g.queue_free()
	await _frames(2)
	print("LIQUIDS %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
