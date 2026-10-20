extends SceneTree
# CV-138 "Wayfarer"'s drones (scripts/drones.gd) and its hangar lift (scripts/mech.gd
# preloads): the main bus dead, the bays' chargers and the drones' own packs are
# still live; a drone reads dead only with its bay's charger switch and its own
# pack isolator both open; unplugging a live lead bites; a drone freed with its
# pack still on it and live wakes and is badly damaged, while one isolated, its
# pack taken off first, comes away whole; the lift's base pivot out with its locks
# in springs it into the recovery drone, and bled and unlocked it comes away quietly.
# godot --headless --path . --fixed-fps 60 -s tests/cv138_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cv138_save.json"
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
	Game.start_ship = "cv138"
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


func _v(g, tag: String) -> float:
	return g.sys.piece_volts(g.world.tag(tag))


func _line(g, id: String):
	return g.world.lines.get(id)


func _unplug(g, id: String) -> void:
	var l = _line(g, id)
	if l != null:
		g.do_wrench({"kind": "connector", "line": l, "end": 1, "pos": g.world.line_end_world(l, 1)})


# every fixing between two pieces, by the wrench
func _unfix(g, a: String, b: String) -> void:
	var pa = g.world.tag(a)
	var pb = g.world.tag(b)
	for j in g.world.joints_of(pa):
		if j.alive and (j.a == pb.id or j.b == pb.id):
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})


func _run() -> void:
	print("CV-138: who is live")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "cv138" and g.drones.active(), "the CV-138 carries its drones")
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(10)
	check(not g.sys.bus_live and _v(g, "DR-1") > 50.0 and _v(g, "CHG-1") > 50.0, "the main battery off, the bays and drones are still live (%.0f V)" % _v(g, "DR-1"))
	g.do_wrench(_ctrl(g, "CH-1"))
	await _frames(10)
	check(_v(g, "DR-1") > 50.0, "its bay's charger off, drone one still reads its own pack (%.0f V)" % _v(g, "DR-1"))
	g.do_wrench(_ctrl(g, "PK-1"))
	await _frames(10)
	check(_v(g, "DR-1") < 1.0 and _v(g, "DR-2") > 50.0, "its pack isolated too: drone one reads dead, drone two doesn't")
	# a live lead pulled: it bites
	await _frames(70)
	var hits := _count(g, "drone_hit")
	_unplug(g, "c2")
	await _frames(2)
	check(_count(g, "drone_hit") > hits, "drone two's charger lead pulled live: it bites")
	g.queue_free()
	await _frames(2)

	print("CV-138: a drone freed live")
	g = _game()
	await _frames(3)
	g.do_wrench(_ctrl(g, "CH-4"))
	await _frames(4)
	g.world.kill_line(_line(g, "c4"))
	_unfix(g, "DR-4", "WDECK")
	await _frames(6)
	var d4 = g.world.tag("DR-4")
	check(d4.body != null and _count(g, "drone_woke") == 1 and d4.cond <= 0.5, "freed with its pack still on and live: drone four wakes, badly damaged (%.2f)" % d4.cond)
	check(g.drones.save_state().get("woke", []).has("DR-4"), "the save keeps which drone woke")
	# the right way for drone five: both off, leads out, pack off first
	g.do_wrench(_ctrl(g, "CH-5"))
	g.do_wrench(_ctrl(g, "PK-5"))
	await _frames(6)
	_unplug(g, "c5")
	_unplug(g, "k5")
	_unfix(g, "DP-5", "DR-5")
	await _frames(4)
	var p5 = g.world.tag("DP-5")
	check(p5.body != null and p5.cond > 0.99, "drone five isolated: its pack comes off whole")
	_unfix(g, "DR-5", "WDECK")
	await _frames(6)
	var d5 = g.world.tag("DR-5")
	check(d5.body != null and d5.cond > 0.99 and _count(g, "drone_woke") == 1, "and the drone itself comes away whole, quietly")
	check(g.sys.dest_of(d5) == "equip", "a whole drone goes to the equipment bay")
	g.queue_free()
	await _frames(2)

	print("CV-138: the hangar lift")
	g = _game()
	await _frames(3)
	check(g.mech.tension("LP") > 40.0, "the gauge on the lift's pivot reads its load (%.0f kN)" % g.mech.tension("LP"))
	var d7 = g.world.tag("DR-7")
	_undo(g, "LP")
	await _frames(4)
	check(_count(g, "preload") == 1 and d7.cond < 0.5, "the pivot out with the locks in: the lift springs into the recovery drone (%.2f)" % d7.cond)
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	g.do_hose(_ctrl(g, "PA-G"))
	var f := 0
	while g.sys.P("ACC-G") > 150.0 and f < 60 * 120:
		f += 1
		await physics_frame
	check(g.sys.P("ACC-G") < 300.0, "the lift accumulator bled through its port (%.0f s)" % (f / 60.0))
	_undo(g, "LL-1")
	_undo(g, "LL-2")
	_undo(g, "LP")
	await _frames(4)
	check(_count(g, "preload") == 0, "bled and unlocked: the pivot comes out quietly")
	g.queue_free()
	await _frames(2)
	print("CV138 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
