extends SceneTree
# JD-38 "Turtledove"'s lock rails (scripts/rails.gd): the wrench can't undo a box's
# fixings to its rail while the rail is locked; cutting a rail that still carries
# its box wrenches the box with it; with both doors open (on the bus), turning a
# rail's lock off sends its box out along the rail and through the stern door
# whole; turned off with the hold door shut, the box runs into it (a knock); the
# released rails survive a save. Also: the bus reads dead only with the battery's
# own switch open in the machinery room, and the doors then won't move.
# godot --headless --path . --fixed-fps 60 -s tests/jd38_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_jd38_save.json"
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
	Game.start_ship = "jd38"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _box_joint(g, box: String):
	var bx = g.world.tag(box)
	for j in g.world.joints_of(bx):
		if j.alive:
			return j
	return null


func _run() -> void:
	print("JD-38: lock rails")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "jd38" and g.rails.active(), "the JD-38 carries cargo on lock rails")
	var j = _box_joint(g, "BOX-1")
	g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	check(j.alive, "the wrench won't undo a box's fixing to its locked rail")
	# cutting the lower rail with its box still on it
	var b2 = g.world.tag("BOX-2")
	var c0: float = b2.cond
	g.on_cut_into(g.world.tag("RL-L"), g.world.frame(g.world.tag("RL-L")) * Geom.centroid(g.world.tag("RL-L").poly))
	check(b2.cond < c0 - 0.2 and g.incidents.any(func(i): return i[1] == "rail_cut"), "cutting a rail still carrying its box wrenches the box (%.2f -> %.2f)" % [c0, b2.cond])
	# the hold and the cargo lock vented, both doors open on the bus, then the upper rail's lock off
	g.do_hose(_ctrl(g, "G-H"))
	g.do_hose(_ctrl(g, "G-L"))
	var v := 0
	while (g.sys.P("H") > 2.0 or g.sys.P("L") > 2.0) and v < 60 * 120:
		v += 1
		await physics_frame
	check(g.sys.P("H") < 2.0 and g.sys.P("L") < 2.0, "the hold and the cargo lock vented through their ports (%.0f s)" % (v / 60.0))
	g.do_wrench(_ctrl(g, "DR-H"))
	g.do_wrench(_ctrl(g, "DR-ST"))
	await _frames(40)
	check(g.world.tag("DR-H").door_open and g.world.tag("DR-ST").door_open, "the hold door and the stern door open on the bus")
	var b1 = g.world.tag("BOX-1")
	g.do_wrench(_ctrl(g, "LK-U"))
	await _frames(4)
	check(b1.body != null, "the upper rail's lock off: its box comes loose")
	var t := 0
	var cx := func() -> float: return Geom.bbox(b1.body.global_transform * b1.poly).get_center().x / Geom.M if b1.body != null and is_instance_valid(b1.body) else -1.0
	while t < 60 * 30 and cx.call() < 36.0 and cx.call() > 0.0:
		t += 1
		await physics_frame
	var bx: float = cx.call()
	check(bx >= 36.0, "it slides out along the rail through the stern door (%.1f m)" % bx)
	check(b1.cond > 0.97 and not g.incidents.any(func(i): return i[1] == "impact"), "whole (%.2f), no knock on the way" % b1.cond)
	var st: Dictionary = g.rails.save_state()
	check(st.get("released", []).has("U") and not st.released.has("L"), "the save keeps which rail was released: %s" % [st])
	g.queue_free()
	await _frames(2)

	print("JD-38: the hold door shut")
	g = _game()
	await _frames(3)
	b2 = g.world.tag("BOX-2")
	g.do_wrench(_ctrl(g, "LK-L"))
	var f := 0
	while f < 60 * 8 and not g.incidents.any(func(i): return i[1] == "impact"):
		f += 1
		await physics_frame
	check(g.incidents.any(func(i): return i[1] == "impact") and b2.cond < 0.99, "released into the shut hold door, the box knocks into it (cond %.2f)" % b2.cond)
	g.queue_free()
	await _frames(2)

	print("JD-38: the battery")
	g = _game()
	await _frames(3)
	check(g.sys.bus_live, "the bus is live at the start")
	g.do_wrench(_ctrl(g, "K-BAT"))
	await _frames(10)
	check(not g.sys.bus_live, "the battery's own switch kills the bus")
	g.do_wrench(_ctrl(g, "DR-H"))
	await _frames(2)
	check(not g.world.tag("DR-H").door_open, "and the doors won't move without it")
	g.do_wrench(_ctrl(g, "AUX-P"))
	await _frames(5)
	g.do_wrench(_ctrl(g, "DR-H"))
	await _frames(2)
	check(g.world.tag("DR-H").door_open, "the berth's supply on the outside socket runs them again")
	g.queue_free()
	await _frames(2)
	print("JD38 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
