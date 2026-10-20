extends SceneTree
# NR-95 "Hearth"'s reactor (scripts/reactor.gd with scripts/furnace.gd): the dose
# probes read the core's field, the crew module sits in the shadow of the shield,
# the shelter and the tank; a drone hovering near the core soaks up its dose and
# faults; the shield lifted off and hung in front of the core puts a point behind
# it in shadow; the decay heat comes off only while the coolant pump has power; a
# petal folded hot deforms; the core lifted with its drums unlocked lets them slip;
# cut, the core contaminates the ship; cooled, locked and freed it goes whole to
# the hazard bay.
# godot --headless --path . --fixed-fps 60 -s tests/nr95_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_nr95_save.json"
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


func _secs(s: float) -> void:
	for i in int(s * 60.0):
		await process_frame


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "nr95"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _free(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)
	for j in g.world.joints_of(p):
		if j.alive:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	await _frames(4)


func _m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * Geom.M


func _run() -> void:
	print("NR-95: the field")
	var g = _game()
	await _frames(70)
	var r = g.reactor
	check(g.ship_id == "nr95" and r.active(), "the NR-95 carries its reactor")
	var d2: float = r.probe(g.world.ctrls["D-2"])
	check(d2 > 30.0, "the probe by the reactor reads %.0f mSv/h" % d2)
	check(r.rate_at(_m(8.0, 0.0)) < 1.0, "the crew module sits in the shadow (%.2f mSv/h)" % r.rate_at(_m(8.0, 0.0)))
	var open_pt := _m(67.1, -12.0)
	var r0: float = r.rate_at(open_pt)
	check(r0 > 10.0, "above the reactor, in the open: %.0f mSv/h" % r0)
	# the drone hovering by the core
	g.drone.global_position = _m(67.1, -7.0)
	var t := 0.0
	while _count(g, "dose_fault") == 0 and t < 120.0:
		await _secs(1.0)
		t += 1.0
	check(_count(g, "dose_fault") == 1, "a drone hovering by the core faults after %.0f s" % t)
	g.drone.global_position = _m(-10.0, -10.0)
	# the shield lifted off and hung over the core
	await _free(g, "SHIELD")
	var sd = g.world.tag("SHIELD")
	check(sd.body != null, "its eight bolts out, the shield comes off its mounts")
	sd.body.freeze = true
	sd.body.global_position += _m(67.1, -9.0) - g.world.frame(sd) * Geom.centroid(sd.poly)
	sd.body.global_rotation = PI / 2.0
	await _frames(4)
	check(r.rate_at(open_pt) < r0 * 0.05, "hung over the core, it puts the point above in its shadow (%.2f mSv/h)" % r.rate_at(open_pt))
	g.queue_free()
	await _frames(2)

	print("NR-95: the decay heat")
	g = _game()
	await _frames(3)
	var t0: float = g.furnace.T
	await _secs(20.0)
	var cooled: float = t0 - g.furnace.T
	check(t0 > 300.0 and cooled > 20.0, "the coolant pump on the bus takes the heat off (%.0f -> %.0f °C)" % [t0, g.furnace.T])
	await _free(g, "RAD-2")
	check(_count(g, "petal_hot") == 1 and g.world.tag("RAD-2").cond <= 0.5, "a petal folded with the core still hot deforms")
	g.do_wrench(_ctrl(g, "K-H"))
	await _frames(4)
	var ta: float = g.furnace.T
	await _secs(20.0)
	check(ta - g.furnace.T < 5.0, "the battery off, the pump stops and the core barely cools (%.0f -> %.0f °C)" % [ta, g.furnace.T])
	g.queue_free()
	await _frames(2)

	print("NR-95: the core")
	g = _game()
	await _frames(3)
	g.furnace.T = 40.0
	await _free(g, "CORE")
	check(_count(g, "drum_slip") == 1, "the core lifted with its drums unlocked: they slip")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	var cr = g.world.tag("CORE")
	g.on_cut_into(cr, g.world.frame(cr) * Geom.centroid(cr.poly))
	await _frames(3)
	check(_count(g, "core_breach") == 1 and g.reactor.rate_at(_m(8.0, 0.0)) > 2.0, "cut, the core contaminates the ship: the crew module is no longer in shadow (%.0f mSv/h)" % g.reactor.rate_at(_m(8.0, 0.0)))
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	g.furnace.T = 40.0
	for i in 4:
		g.do_wrench(_ctrl(g, "DL-%d" % (i + 1)))
	await _frames(2)
	await _free(g, "CORE")
	cr = g.world.tag("CORE")
	check(cr.body != null and cr.cond > 0.99 and _count(g, "drum_slip") == 0 and g.sys.dest_of(cr) == "hazard", "cooled, its drums locked: the core comes out whole, for the hazard bay")
	check(g.reactor.save_state().has("dose"), "the save keeps the drone's dose")
	g.queue_free()
	await _frames(2)
	print("NR95 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
