extends SceneTree
# SV-122 "Watchtower"'s instrument cradle (scripts/rails.gd sets with "hangs"):
# an instrument's fixings to the cradle are its damping lock's, which the wrench
# can't undo; its lock released, it comes off whole; the main beam cut while the
# other instruments are still locked on drops the cradle and bangs them (badly
# damaged) and not the one already off; the instruments run on their own
# uninterruptible supply, live with the bus dead until its own switch is opened.
# godot --headless --path . --fixed-fps 60 -s tests/sv122_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_sv122_save.json"
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
	Game.start_ship = "sv122"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _v(g, tag: String) -> float:
	return g.sys.piece_volts(g.world.tag(tag))


func _run() -> void:
	print("SV-122: the cradle")
	var g = _game()
	await _frames(3)
	var o1 = g.world.tag("OPT-1")
	var j = g.world.joints_of(o1)[0]
	g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	check(j.alive, "the wrench won't undo an instrument's fixing while its damping lock is on")
	g.do_wrench(_ctrl(g, "DL-1"))
	await _frames(2)
	check(g.world.joints_of(o1).filter(func(jj): return jj.alive).is_empty(), "its damping lock released: instrument one's fixings to the cradle are off")
	for l in g.world.lines_of(o1):
		g.world.kill_line(l)
	await _frames(4)
	check(o1.body != null and o1.cond > 0.99, "unplugged, it comes off whole")
	var mb = g.world.tag("MB-T")
	g.on_cut_into(mb, g.world.frame(mb) * Geom.centroid(mb.poly))
	await _frames(2)
	var o2 = g.world.tag("OPT-2")
	var o3 = g.world.tag("OPT-3")
	check(g.incidents.any(func(i): return i[1] == "cradle_drop") and o2.cond < 0.5 and o3.cond < 0.5, "the main beam cut with two still locked on: the cradle drops, they are badly damaged (%.2f, %.2f)" % [o2.cond, o3.cond])
	check(o1.cond > 0.99, "the one already off isn't touched")
	g.queue_free()
	await _frames(2)

	print("SV-122: the instruments' own supply")
	g = _game()
	await _frames(3)
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(10)
	check(not g.sys.bus_live and _v(g, "OPT-2") > 100.0, "the bus dead, the instruments still live off their own supply (%.0f V)" % _v(g, "OPT-2"))
	check(_v(g, "SURVEY") < 1.0, "and nothing of it reaches the bus: the survey core reads dead")
	g.do_wrench(_ctrl(g, "K-UPS"))
	await _frames(10)
	check(_v(g, "OPT-2") < 1.0, "its own switch opened aft: dead")
	g.queue_free()
	await _frames(2)
	print("SV122 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
