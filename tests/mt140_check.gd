extends SceneTree
# MT-140 "Centipede"'s train (scripts/train.gd): the bus runs through every coupler,
# so with K-3's cable cut the water tank's pump in M5 has no power and draws
# nothing until M6's standby battery is switched on; the bend gauge on K-4 reads
# what hangs aft of it; a K-4 pin undone with the train aft still on springs it,
# and with M6 and M7 taken off first it comes out quietly; a coupler's coolant
# hose cut with its valve open leaks, shut and drained it doesn't.
# godot --headless --path . --fixed-fps 60 -s tests/mt140_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_mt140_save.json"
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
	Game.start_ship = "mt140"
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
	await _frames(3)


func _undo(g, tag: String) -> void:
	var j = g.mech._joint(tag)
	if j != null:
		g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})


func _run() -> void:
	print("MT-140: the bus")
	var g = _game()
	await _frames(70)
	var s = g.sys
	check(g.ship_id == "mt140" and g.train.active(), "the MT-140 is a train")
	check(g.train.powered("t5"), "the water tank's pump in M5 runs on the bus from M1")
	await _cut_line(g, "kc3")
	await _frames(10)
	check(not g.train.powered("t5") and g.train.powered("t2"), "K-3's cable cut: M4 onwards goes dark, M2 still has power")
	g.world.reveal("M5", g.world.rooms["M5"].from)
	var w0: float = s.fluid("t5")
	g.do_hose(_ctrl(g, "PT-5"))
	for i in 300:
		await process_frame
	check(s.fluid("t5") > w0 - 0.01, "the water tank can't be drained without power (%.2f -> %.2f)" % [w0, s.fluid("t5")])
	g.do_wrench(_ctrl(g, "K-6"))
	await _frames(10)
	var w1: float = s.fluid("t5")
	for i in 300:
		await process_frame
	check(g.train.powered("t5") and s.fluid("t5") < w1 - 0.05, "M6's standby battery on: the pump draws again (%.2f -> %.2f)" % [w1, s.fluid("t5")])
	g.queue_free()
	await _frames(2)

	print("MT-140: the jam")
	g = _game()
	await _frames(3)
	var bend: float = g.train.aft_mass()
	check(bend > 120.0, "the bend gauge on K-4 reads %.0f t hanging aft" % bend)
	_undo(g, "K4-1")
	await _frames(20)
	check(_count(g, "train_spring") == 1 and g.world.tag("ENV-4").cond <= 0.5, "a K-4 pin undone with the train aft still on: it springs and tears M4 and M5 (%.2f)" % g.world.tag("ENV-4").cond)
	check(g.train.save_state().get("sprang", false), "the save keeps it")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	# M6 and M7 off first: everything aft of K-5's fore face let go
	var cut := Geom.M * 99.5
	for t in g.train.cfg.jam.aft:
		var p = g.world.tag(str(t))
		if p == null or p.gone:
			continue
		if (g.world.frame(p) * Geom.centroid(p.poly)).x > cut:
			for l in g.world.lines_of(p):
				g.world.kill_line(l)
			for j in g.world.joints_of(p):
				g.world.kill_joint(j)
	await _frames(10)
	check(g.train.aft_mass() < 75.0, "M6 and M7 off: only M5 hangs aft of K-4 (%.0f t)" % g.train.aft_mass())
	for k in 4:
		_undo(g, "K4-%d" % (k + 1))
	await _frames(20)
	check(_count(g, "train_spring") == 0, "and K-4's pins come out quietly")
	g.queue_free()
	await _frames(2)

	print("MT-140: the coolant hoses")
	g = _game()
	await _frames(3)
	s = g.sys
	var lk := _count(g, "leak")
	await _cut_line(g, "kh2")
	check(_count(g, "leak") > lk, "K-2's hose cut with its valve open: coolant sprays")
	g.do_wrench(_ctrl(g, "KV-3"))
	g.do_hose(_ctrl(g, "KB-3"))
	var f := 0
	while s.fluid("hz3") > 0.002 and f < 1200:
		f += 1
		await process_frame
	lk = _count(g, "leak")
	await _cut_line(g, "kh3")
	check(_count(g, "leak") == lk, "K-3's valve shut and its hose drained (%.0f s): cut, it doesn't" % (f / 60.0))
	g.queue_free()
	await _frames(2)
	print("MT140 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
