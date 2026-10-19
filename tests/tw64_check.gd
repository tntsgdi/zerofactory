extends SceneTree
# TW-64 "Bedrock"'s loads, released in the order they run (scripts/mech.gd preloads
# and balance): the tension gauges read the winch and the jaw; a jaw pad's pivot
# taken out while the winch brake still holds the line springs it; with the brake
# pins out, the jaw's accumulator bled and its pin out it comes away quietly; the
# arm's pivots spring while its accumulator is charged and come out quietly once it
# is bled and the locks are out; one engine pod off while the other still hangs and
# the hull support isn't set twists the hull; with the support set, it doesn't.
# godot --headless --path . --fixed-fps 60 -s tests/tw64_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_tw64_save.json"
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
	Game.start_ship = "tw64"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _undo(g, tag: String) -> void:
	var j = g.mech._joint(tag)
	if j != null:
		g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _bleed(g, port: String, vessel: String) -> float:
	g.do_hose(_ctrl(g, port))
	var f := 0
	while g.sys.P(vessel) > 150.0 and f < 60 * 120:
		f += 1
		await physics_frame
	return f / 60.0


func _run() -> void:
	print("TW-64: the winch and the jaw")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "tw64", "the TW-64 is in")
	check(g.mech.tension("WD-AX") > 50.0 and g.mech.tension("JP-U") > 40.0, "the gauges read the winch (%.0f kN) and the jaw (%.0f kN)" % [g.mech.tension("WD-AX"), g.mech.tension("JP-U")])
	# the jaw's upper pad out first, with the winch brake still on: it springs
	_undo(g, "JP-U")
	await _frames(4)
	check(_count(g, "preload") == 1, "the upper pad's pivot out with the winch brake on: it springs")
	# the right way for the lower pad: brake pins out, the accumulator bled, its own pin out
	_undo(g, "WB-1")
	_undo(g, "WB-2")
	await _frames(2)
	check(g.mech.tension("WD-AX") < 1.0, "the brake pins out: the winch gauge reads slack")
	var t := await _bleed(g, "PA-J", "ACC-J")
	check(g.sys.P("ACC-J") < 300.0, "the jaw's accumulator bled through its port (%.0f s)" % t)
	_undo(g, "JL-L")
	_undo(g, "JP-L")
	await _frames(4)
	check(_count(g, "preload") == 1, "the lower pad comes away quietly")
	_undo(g, "WD-AX")
	await _frames(4)
	check(_count(g, "preload") == 1, "and so does the slack winch drum")
	g.queue_free()
	await _frames(2)

	print("TW-64: the arm")
	g = _game()
	await _frames(3)
	_undo(g, "AL-3")
	_undo(g, "AP-3")
	await _frames(4)
	check(_count(g, "preload") == 1, "the claw's pivot out with the arm's accumulator charged: it springs")
	t = await _bleed(g, "PA-A", "ACC-A")
	_undo(g, "AL-2")
	_undo(g, "AP-2")
	_undo(g, "AL-1")
	_undo(g, "AP-1")
	await _frames(4)
	check(_count(g, "preload") == 1, "bled (%.0f s), its locks out, the rest of the arm comes away quietly" % t)
	g.queue_free()
	await _frames(2)

	print("TW-64: the engine pods")
	g = _game()
	await _frames(3)
	var eu = g.world.tag("ENG-U")
	for j in g.world.joints_of(eu):
		g.world.kill_joint(j)
	await _frames(6)
	check(_count(g, "imbalance") == 1 and g.world.tag("PYL-L").cond < 0.6, "the upper pod off alone, unsupported: the hull twists under the lower one")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	g.do_wrench(_ctrl(g, "SUP"))
	eu = g.world.tag("ENG-U")
	for j in g.world.joints_of(eu):
		g.world.kill_joint(j)
	await _frames(6)
	check(_count(g, "imbalance") == 0, "with the hull support set it comes off clean")
	var st: Dictionary = g.mech.save_state()
	check(st.has("twisted"), "the twist is part of the mechanisms' save")
	g.queue_free()
	await _frames(2)
	print("TW64 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
