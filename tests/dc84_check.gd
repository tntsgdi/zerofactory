extends SceneTree
# DC-84 "Deep Mind"'s immersion tanks and custody (scripts/immersion.gd): a rack lifted
# out of a full tank spills and shorts its neighbours; drained first, it comes out
# whole; a drive taken without its custody latch is a fined breach, latched it is not.
# godot --headless --path . --fixed-fps 60 -s tests/dc84_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_dc84_save.json"
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
	Game.start_ship = "dc84"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _free(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


func _run() -> void:
	print("DC-84: the tanks")
	var g = _game()
	await _frames(3)
	var im = g.immersion
	check(im.active() and im.full("RA-2") and g.sys.fluid("tkA2") > 0.3, "rack A-2 stands in a full tank (%.2f)" % g.sys.fluid("tkA2"))
	var v1: float = g.world.tag("RA-1").cond
	_free(g, "RA-2")
	await _frames(6)
	check(_has(g, "immersion_spill") and g.sys.fluid("tkA2") < 0.01, "lifted out full: the fluid spills")
	check(g.world.tag("RA-1").cond < v1 and g.world.tag("RA-3").cond < 1.0, "the racks beside it short")
	check(g.world.tag("RA-5").cond > 0.99, "the rack on the deck above is untouched")
	# drained first
	g.do_hose(_ctrl(g, "PTA-5"))
	var n := 0
	while im.full("RA-5") and n < 6000:
		await _frames(10)
		n += 10
	var v4: float = g.world.tag("RA-4").cond
	_free(g, "RA-5")
	await _frames(6)
	check(not im.full("RA-5") and g.world.tag("RA-4").cond >= v4 and g.world.tag("RA-5").cond > 0.99, "drained at its port first, rack A-5 comes out whole, its neighbours too")
	check(g.sys.fluid_value() > 0.0, "and the drained fluid pays ($%.0f)" % g.sys.fluid_value())
	check(im.save_state().spilt.has("RA-2"), "the spill is saved")
	g.queue_free()
	await _frames(2)

	print("DC-84: custody")
	g = _game()
	await _frames(3)
	im = g.immersion
	var l0: float = g.losses
	_free(g, "DRV-1")
	await _frames(6)
	check(_has(g, "custody_breach") and g.losses > l0, "a drive taken unlatched: a breach of custody, fined ($%.0f)" % (g.losses - l0))
	g.do_wrench(_ctrl(g, "CUST-2"))
	await _frames(2)
	var l1: float = g.losses
	_free(g, "DRV-2")
	await _frames(6)
	check(g.losses == l1 and g.world.tag("DRV-2").cond > 0.99, "latched into custody first: no breach")
	check(im.unsafe().any(func(u): return u.begins_with("drive DRV-3")), "the drives still loose are listed as unsafe")
	g.queue_free()
	await _frames(2)
	print("DC84 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
