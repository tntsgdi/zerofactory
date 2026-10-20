extends SceneTree
# PS-12 "Dawn"'s escape pods and observation glass (scripts/liner.gd) and its
# service core: a pod whose firing circuit is dead comes off its clamps quietly; one
# left charged fires when a clamp latch is undone, and when its charge is unbolted;
# its arming switch opened first, it comes off whole and its charge goes to the
# hazard bay; a pane freed with the hall still pressurised is blown out, one freed
# after the hall is vented comes away whole; doors open on two levels of the core
# make the levels one room.
# godot --headless --path . --fixed-fps 60 -s tests/ps12_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ps12_save.json"
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
	Game.start_ship = "ps12"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _undo(g, tag: String) -> void:
	var j = g.mech._joint(tag)
	if j != null:
		g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})


# every fixing of a piece, by the wrench
func _unfix_all(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		if j.alive:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})


func _run() -> void:
	print("PS-12: the escape pods")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "ps12" and g.liner.active(), "the PS-12 carries its pods and its glass")
	check(not g.liner.armed("POD-1"), "a pod's firing circuit is dead on an ordinary contract")
	_undo(g, "LC-11")
	_undo(g, "LC-12")
	await _frames(6)
	var p1 = g.world.tag("POD-1")
	check(p1.body != null and p1.cond > 0.99 and _count(g, "pod_fired") == 0, "its clamps undone: pod one comes away whole")
	# a pod left charged
	g.sys.iso["FCAP-2"].charge = 1.0
	await _frames(4)
	check(g.liner.armed("POD-2") and g.sys.piece_volts(g.world.tag("FCAP-2")) > 10.0, "pod two's charge reads live (%.0f V)" % g.sys.piece_volts(g.world.tag("FCAP-2")))
	_undo(g, "LC-21")
	await _frames(6)
	var p2 = g.world.tag("POD-2")
	check(_count(g, "pod_fired") == 1 and p2.body != null and p2.cond <= 0.5, "a clamp latch undone with it live: the bolts fire and the pod is thrown off (%.2f)" % p2.cond)
	check(g.liner.save_state().get("fired", []).has("POD-2"), "the save keeps which pod fired")
	# the right way: its arming switch open first
	g.sys.iso["FCAP-3"].charge = 1.0
	g.do_wrench(_ctrl(g, "ARM-3"))
	await _frames(4)
	check(not g.liner.armed("POD-3"), "pod three's arming switch opened: dead")
	g.world.kill_line(g.world.lines["fc3"])
	_unfix_all(g, "PYRO-3")
	await _frames(4)
	var c3 = g.world.tag("PYRO-3")
	check(c3.body != null and g.sys.dest_of(c3) == "hazard", "its lead pulled and its charge unbolted whole, for the hazard bay")
	_undo(g, "LC-31")
	_undo(g, "LC-32")
	await _frames(6)
	var p3 = g.world.tag("POD-3")
	check(p3.body != null and p3.cond > 0.99 and _count(g, "pod_fired") == 1, "then its clamps: pod three comes away whole")
	# the charge unbolted with the circuit live
	g.sys.iso["FCAP-4"].charge = 1.0
	await _frames(2)
	_unfix_all(g, "PYRO-4")
	await _frames(6)
	check(_count(g, "pod_fired") == 2, "pod four's charge unbolted live: it fires too")
	g.queue_free()
	await _frames(2)

	print("PS-12: the observation glass")
	g = _game()
	await _frames(3)
	_unfix_all(g, "OBS-2")
	await _frames(6)
	var o2 = g.world.tag("OBS-2")
	check(_count(g, "glass_blown") == 1 and not o2.intact, "a pane freed with the hall still under pressure: blown out, shattered")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	g.do_hose(_ctrl(g, "G-O"))
	var t := 0.0
	while g.sys.P("O") > 5.0 and t < 120.0:
		await _secs(1.0)
		t += 1.0
	_unfix_all(g, "OBS-3")
	await _frames(6)
	var o3 = g.world.tag("OBS-3")
	check(o3.body != null and o3.intact and _count(g, "glass_blown") == 0, "the hall vented first (%.0f s): the pane comes away whole" % t)
	g.queue_free()
	await _frames(2)

	print("PS-12: the core links the levels")
	g = _game()
	await _frames(3)
	g.do_wrench(_ctrl(g, "D-UC"))
	g.do_wrench(_ctrl(g, "D-LC"))
	await _frames(30)
	check(g.world.tag("D-UC").door_open and g.world.tag("D-LC").door_open, "the core's doors to the upper cabin and the lower deck open")
	g.do_hose(_ctrl(g, "G-L1"))
	t = 0.0
	while g.sys.P("L1") > 30.0 and t < 120.0:
		await _secs(1.0)
		t += 1.0
	check(g.sys.P("U1") < 40.0 and g.sys.P("C") < 40.0, "venting the lower deck takes the core and the upper cabin with it (%.0f / %.0f kPa)" % [g.sys.P("U1"), g.sys.P("C")])
	g.queue_free()
	await _frames(2)
	print("PS12 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
