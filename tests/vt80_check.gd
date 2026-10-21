extends SceneTree
# VT-80 "Long Whale"'s propellant network (scripts/tanknet.gd): the tanks' level
# probes read each tank; two cross valves open, their tanks' levels even out
# through the manifold; the main pump draws nothing without power; all open and
# drawn pressurised, the propellant goes and no tank buckles, but left drawing a
# dry manifold the pump runs dry; a tank vented with its pressurisation shut and
# then drawn buckles; a tank cut under pressure bursts; a branch keeps its residue
# once its valve is shut (cut, it leaks) until its low-point drain has it; a cross
# valve that leaks shut keeps feeding its branch.
# godot --headless --path . --fixed-fps 60 -s tests/vt80_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_vt80_save.json"
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
		await physics_frame


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "vt80"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _cut_line(g, id: String) -> void:
	var l = g.world.lines[id]
	var at: Vector2 = g.world.line_end_world(l, 0)
	g.world.kill_line(l, at)
	g.on_line_cut(l, at)


func _run() -> void:
	print("VT-80: the cross-connected tanks")
	var g = _game()
	await _frames(3)
	var s = g.sys
	check(g.ship_id == "vt80" and g.tanknet.active(), "the VT-80 carries its propellant network")
	check(absf(s.port_level("L-1") - 0.35) < 0.02 and absf(s.port_level("L-3") - 0.6) < 0.02, "the level probes read each tank (%.2f, %.2f)" % [s.port_level("L-1"), s.port_level("L-3")])
	g.do_wrench(_ctrl(g, "XV-1"))
	g.do_wrench(_ctrl(g, "XV-3"))
	await _secs(20.0)
	var l1: float = s.port_level("L-1")
	var l3: float = s.port_level("L-3")
	check(absf(l1 - l3) < 0.05 and l1 > 0.4, "two cross valves open: the two tanks' levels even out through the manifold (%.2f, %.2f)" % [l1, l3])
	check(s.fluid("xm") > 0.35, "and the manifold runs full (%.2f)" % s.fluid("xm"))
	# no power, no pumping
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(10)
	g.world.reveal("P", g.world.rooms["P"].from)
	var f0: float = g.tanknet.fuel_left()
	g.do_hose(_ctrl(g, "PR"))
	await _secs(6.0)
	check(g.tanknet.fuel_left() > f0 - 0.01, "the bus off, the main pump draws nothing (%.2f -> %.2f)" % [f0, g.tanknet.fuel_left()])
	g.queue_free()
	await _frames(2)

	print("VT-80: drawn the right way, then left running")
	g = _game()
	await _frames(3)
	s = g.sys
	for n in ["1", "2", "3"]:
		g.do_wrench(_ctrl(g, "XV-" + n))
	g.world.reveal("P", g.world.rooms["P"].from)
	g.do_hose(_ctrl(g, "PR"))
	# the oxidiser tank is off the fuel manifold: drawn at its own drain
	g.do_hose(_ctrl(g, "LD-2"))
	var t := 0.0
	var held := func() -> float: return s.fluid("t1") + s.fluid("t2") + s.fluid("t3") + s.fluid("xm")
	while held.call() > 0.03 and t < 400.0:
		await _secs(1.0)
		t += 1.0
	check(held.call() <= 0.03, "every cross valve open, pressurised: the fuel tanks and the manifold drawn at the pump, the oxidiser at its own drain (%.0f s)" % t)
	check(_count(g, "tank_buckled") == 0, "and no tank buckles")
	await _secs(24.0)
	check(_count(g, "pump_dry") == 1 and g.world.tag("PUMP-M").cond <= 0.5, "left drawing a dry manifold: the main pump runs dry (%.2f)" % g.world.tag("PUMP-M").cond)
	g.queue_free()
	await _frames(2)

	print("VT-80: vented first")
	g = _game()
	await _frames(3)
	s = g.sys
	g.do_wrench(_ctrl(g, "PV-1"))
	g.do_hose(_ctrl(g, "TV-1"))
	t = 0.0
	while s.P("TU-1") > 10.0 and t < 200.0:
		await _secs(1.0)
		t += 1.0
	check(s.P("TU-1") < 10.0, "its pressurisation shut, tank one's ullage vented (%.0f s)" % t)
	g.do_wrench(_ctrl(g, "XV-1"))
	g.world.reveal("P", g.world.rooms["P"].from)
	g.do_hose(_ctrl(g, "PR"))
	await _secs(15.0)
	var t1 = g.world.tag("T-1")
	check(_count(g, "tank_buckled") == 1 and t1.cond <= 0.45, "then drawn: it pulls a vacuum and buckles (%.2f)" % t1.cond)
	check(g.tanknet.save_state().get("buckled", []).has("T-1"), "the save keeps which tank buckled")
	# a tank cut under pressure
	var t2 = g.world.tag("T-2")
	g.on_cut_into(t2, g.world.frame(t2) * Geom.centroid(t2.poly))
	await _frames(4)
	check(_count(g, "burst") > 0, "tank two cut with its ullage still under pressure: it bursts")
	g.queue_free()
	await _frames(2)

	print("VT-80: the branches")
	g = _game()
	await _frames(3)
	s = g.sys
	check(s.fluid("b2") > 0.015, "a branch holds its residue with its valve shut (%.3f)" % s.fluid("b2"))
	var lk0 := _count(g, "leak")
	_cut_line(g, "b2")
	await _frames(4)
	check(_count(g, "leak") > lk0, "cut, it leaks")
	g.do_hose(_ctrl(g, "LD-3"))
	t = 0.0
	while s.fluid("b3") > 0.002 and t < 60.0:
		await _secs(1.0)
		t += 1.0
	lk0 = _count(g, "leak")
	_cut_line(g, "b3")
	await _frames(4)
	check(_count(g, "leak") == lk0, "branch three drawn at its low-point drain first (%.0f s): cut, it doesn't" % t)
	g.queue_free()
	await _frames(2)

	print("VT-80: a cross valve that leaks shut")
	g = _game()
	await _frames(3)
	s = g.sys
	for jn in g.ship.fluids.joins:
		if jn.b == "b1":
			jn.stuck = true
	g.tanknet.cfg.tanks["T-1"].leak = 0.05
	g.do_hose(_ctrl(g, "LD-1"))
	await _secs(20.0)
	check(s.fluid("t1") < 1.4 - 0.05, "its valve reads shut, and tank one still drains through it (%.2f)" % s.fluid("t1"))
	g.do_hose(_ctrl(g, "LD-1"))
	await _frames(4)
	lk0 = _count(g, "leak")
	_cut_line(g, "b1")
	await _frames(4)
	check(_count(g, "leak") > lk0, "its branch cut with the valve shut: it leaks all the same")
	g.queue_free()
	await _frames(2)
	print("VT80 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
