extends SceneTree
# CH-110 "Bookend"'s clamped cargo (scripts/sandwich.gd): the cargo holds 60 kPa and
# a clamp let go before it is vented springs it; the load cells read the beams, beam 2
# (cracked) high; the clamps let go crosswise leave it quiet, one side first twists it
# and breaks beam 2; beam 2 out with a clamp beside it still holding tears the upper
# hull; a clamp freed while still holding springs its jaws.
# godot --headless --path . --fixed-fps 60 -s tests/ch110_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ch110_save.json"
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


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "ch110"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _lift(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _read(g, id: String) -> String:
	g.do_measure(_ctrl(g, id))
	return str(g.sys.readings.get(id, {}).get("text", ""))


func _run() -> void:
	print("CH-110: the cargo still pressurised")
	var g = _game()
	await _frames(3)
	var sw = g.sandwich
	check(sw.active() and sw.cargo_kpa() > 55.0, "the cargo holds %.0f kPa" % sw.cargo_kpa())
	check(_read(g, "LC-2").begins_with("192") and _read(g, "LC-3").begins_with("120"), "the load cells: beam 2 reads %s (cracked, overloaded), beam 3 %s" % [_read(g, "LC-2"), _read(g, "LC-3")])
	var c0: float = g.world.tag("LIFE-C").cond
	g.do_wrench(_ctrl(g, "HC-U1"))
	await _frames(4)
	check(_has(g, "cargo_spring") and g.world.tag("LIFE-C").cond < c0, "a clamp let go at %.0f kPa: the cargo springs" % sw.cargo_kpa())
	g.queue_free()
	await _frames(2)

	print("CH-110: vented, crosswise")
	g = _game()
	await _frames(3)
	sw = g.sandwich
	g.do_hose(_ctrl(g, "G-C1"))
	g.do_hose(_ctrl(g, "G-C2"))
	var n := 0
	while sw.cargo_kpa() > 5.0 and n < 6000:
		await _frames(10)
		n += 10
	check(sw.cargo_kpa() <= 5.0, "the cargo vented through its ports (%.1f kPa)" % sw.cargo_kpa())
	for t in sw.cfg.order:
		g.do_wrench(_ctrl(g, str(t)))
		await _frames(3)
	check(not _has(g, "cargo_spring") and not _has(g, "cargo_twist") and sw.unsafe().is_empty(), "let go crosswise, a pair at a time: quiet, and nothing holds")
	check(_read(g, "LC-2").begins_with("0"), "beam 2 unloaded: %s" % _read(g, "LC-2"))
	_lift(g, "BM2-2")
	await _frames(6)
	check(not _has(g, "hull_torn"), "beam 2 out with its clamps off: the hull stays whole")
	_lift(g, "CU-2")
	await _frames(6)
	check(not _has(g, "clamp_spring"), "a clamp let go comes out quietly")
	check(sw.save_state().has("twisted"), "what happened is saved")
	g.queue_free()
	await _frames(2)

	print("CH-110: one side first")
	g = _game()
	await _frames(3)
	sw = g.sandwich
	g.do_hose(_ctrl(g, "G-C1"))
	g.do_hose(_ctrl(g, "G-C2"))
	n = 0
	while sw.cargo_kpa() > 5.0 and n < 6000:
		await _frames(10)
		n += 10
	var b0: float = g.world.tag("BUNK-1A").cond
	g.do_wrench(_ctrl(g, "HC-U2"))
	await _frames(3)
	g.do_wrench(_ctrl(g, "HC-U3"))
	await _frames(3)
	check(_has(g, "cargo_twist") and g.world.tag("BUNK-1A").cond < b0 and _read(g, "LC-2").begins_with("0"), "two over it let go before any under it: the cargo twists, beam 2 breaks")
	g.queue_free()
	await _frames(2)

	print("CH-110: beam 2 out too early, a clamp freed holding")
	g = _game()
	await _frames(3)
	var m0: float = g.world.tag("MESS-U").cond
	_lift(g, "BM2-3")
	await _frames(6)
	check(_has(g, "hull_torn") and g.world.tag("MESS-U").cond < m0, "beam 2 out with the clamps beside it holding: the upper hull tears")
	_lift(g, "CL-3")
	await _frames(6)
	check(_has(g, "clamp_spring") and g.world.tag("CL-3").cond <= 0.41, "a clamp freed still holding: its jaws spring")
	g.queue_free()
	await _frames(2)
	print("CH110 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
