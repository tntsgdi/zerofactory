extends SceneTree
# RO-128 "Long Bridge"'s four lock rails (scripts/rails.gd) and its visor hinge
# (scripts/mech.gd preloads): the wrench can't undo a cargo unit's lock; the
# vehicle deck vented, the visor and the bow seal door open, the front unit's
# rail lock off sends it forward out through the bow whole; a rear unit released
# while the one ahead is still on its rail runs into it; the vehicle deck cut while
# the units are still locked on drops them all; the visor hinge out while its locks
# are in springs the visor, and with the locks out and the accumulator bled it
# comes away quietly.
# godot --headless --path . --fixed-fps 60 -s tests/ro128_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ro128_save.json"
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
	Game.start_ship = "ro128"
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


func _cx(p) -> float:
	if p.body == null or not is_instance_valid(p.body):
		return -999.0
	return Geom.bbox(p.body.global_transform * p.poly).get_center().x / Geom.M


func _open_bow(g) -> float:
	g.do_hose(_ctrl(g, "G-V"))
	var v := 0
	while g.sys.P("V") > 2.0 and v < 60 * 180:
		v += 1
		await physics_frame
	g.do_wrench(_ctrl(g, "VISOR"))
	g.do_wrench(_ctrl(g, "BOWDOOR"))
	await _frames(60)
	return v / 60.0


func _run() -> void:
	print("RO-128: the cargo units")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "ro128" and g.rails.active(), "the RO-128 carries four units on lock rails")
	var c1 = g.world.tag("CARGO-1")
	var j = g.world.joints_of(c1).filter(func(jj): return jj.alive)[0]
	g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	check(j.alive, "the wrench won't undo a unit's fixing to its locked rail")
	var t: float = await _open_bow(g)
	check(g.sys.P("V") < 2.0, "the vehicle deck vented through its port (%.0f s)" % t)
	check(g.world.tag("VISOR").door_open and g.world.tag("BOWDOOR").door_open, "the visor and the bow seal door open on the bus")
	g.do_wrench(_ctrl(g, "LR-1"))
	await _frames(4)
	check(c1.body != null, "the front rail's lock off: its unit comes loose")
	var f := 0
	while f < 60 * 30 and _cx(c1) > 8.0 and _cx(c1) > -900.0:
		f += 1
		await physics_frame
	check(_cx(c1) <= 8.0 and _cx(c1) > -900.0, "it rolls forward out through the bow (%.1f m)" % _cx(c1))
	check(c1.cond > 0.97 and _count(g, "impact") == 0, "whole (%.2f), no knock on the way" % c1.cond)
	var st: Dictionary = g.rails.save_state()
	check(st.get("released", []).has("C1") and not st.released.has("C2"), "the save keeps which rail was released: %s" % [st])
	g.queue_free()
	await _frames(2)

	print("RO-128: out of order")
	g = _game()
	await _frames(3)
	await _open_bow(g)
	var c2 = g.world.tag("CARGO-2")
	g.do_wrench(_ctrl(g, "LR-2"))
	f = 0
	while f < 60 * 12 and _count(g, "impact") == 0:
		f += 1
		await physics_frame
	check(_count(g, "impact") > 0 and (c2.cond < 0.99 or g.world.tag("CARGO-1").cond < 0.99), "the second unit released with the front one still on: it runs into it (%.2f)" % c2.cond)
	g.queue_free()
	await _frames(2)

	print("RO-128: the vehicle deck")
	g = _game()
	await _frames(3)
	var dk = g.world.tag("VDECK")
	g.on_cut_into(dk, g.world.frame(dk) * Geom.centroid(dk.poly))
	await _frames(2)
	var worst := 1.0
	for i in 4:
		worst = minf(worst, g.world.tag("CARGO-%d" % (i + 1)).cond)
	check(_count(g, "cradle_drop") == 4 and worst < 0.5, "the deck cut with the units still locked on: all four drop (worst %.2f)" % worst)
	g.queue_free()
	await _frames(2)

	print("RO-128: the visor hinge")
	g = _game()
	await _frames(3)
	check(g.mech.tension("VH") > 40.0, "the gauge on the hinge reads the visor's load (%.0f kN)" % g.mech.tension("VH"))
	_undo(g, "VH")
	await _frames(4)
	check(_count(g, "preload") == 1, "the hinge out with its locks in: the visor springs")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	_undo(g, "VL-1")
	_undo(g, "VL-2")
	g.do_hose(_ctrl(g, "PA-D"))
	f = 0
	while g.sys.P("ACC-D") > 150.0 and f < 60 * 120:
		f += 1
		await physics_frame
	check(g.sys.P("ACC-D") < 300.0, "the door accumulator bled through its port (%.0f s)" % (f / 60.0))
	_undo(g, "VH")
	await _frames(4)
	check(_count(g, "preload") == 0, "locks out and bled: the hinge comes away quietly")
	g.queue_free()
	await _frames(2)
	print("RO128 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
