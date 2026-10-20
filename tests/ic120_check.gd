extends SceneTree
# IC-120 "Iceberg"'s ice (scripts/ice.gd): the ice in blocks, its water counted in what
# the ship is worth; a powered heater melts its blocks one after another into the water
# main, unpowered it doesn't; the water drawn off at the main pays; meltwater left
# standing with the bus live shorts the engine module; a cut on the crack with the
# seats beside it holding splits the ice; a seat let go with the ice still on drops it;
# once the ice is gone the seats let go quietly.
# godot --headless --path . --fixed-fps 60 -s tests/ic120_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ic120_save.json"
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
	Game.start_ship = "ic120"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _gone(g, tag: String) -> bool:
	var p = g.world.tag(tag)
	return p == null or p.gone


func _run() -> void:
	print("IC-120: the ice and the heaters")
	var g = _game()
	await _frames(3)
	var ic = g.ice
	var s = g.sys
	check(ic.active() and ic.blocks_left() == 26, "the ice in %d blocks" % ic.blocks_left())
	check(absf(float(s.fluid0.get("water", 0.0)) - 15.6) < 0.05, "its water counted in what the ship holds (%.1f m³)" % float(s.fluid0.get("water", 0.0)))
	g.do_measure(_ctrl(g, "SG-C"))
	check(str(s.readings.get("SG-C", {}).get("text", "")).begins_with("90"), "the crack's strain gauge reads %s with both seats beside it holding" % s.readings.get("SG-C", {}).get("text", "?"))
	g.do_wrench(_ctrl(g, "HT-3"))
	ic.melt["ICE-3T"] = 0.97
	await _frames(60)
	check(_gone(g, "ICE-3T") and not _gone(g, "ICE-3M") and s.fvol["melt"].amount > 0.01, "the heater melts its first block into the main (%.2f m³)" % s.fvol["melt"].amount)
	var m0: float = ic.melt.get("ICE-3M", 0.0)
	await _frames(30)
	check(ic.melt.get("ICE-3M", 0.0) > m0, "and goes on to the next")
	# the water drawn off pays
	g.do_hose(_ctrl(g, "PW"))
	var n := 0
	while s.fvol["melt"].amount > 0.02 and n < 1200:
		await _frames(10)
		n += 10
	check(s.fluid_value() > 0.0, "the meltwater drawn off at the main pays ($%.0f)" % s.fluid_value())
	# unpowered
	g.do_wrench(_ctrl(g, "K-M"))
	g.do_wrench(_ctrl(g, "K-G"))
	await _frames(4)
	var m1: float = ic.melt.get("ICE-3M", 0.0)
	await _frames(40)
	check(absf(ic.melt.get("ICE-3M", 0.0) - m1) < 0.0001, "with the bus dead the heaters do nothing")
	check(ic.save_state().has("melt"), "the melt is saved")
	g.queue_free()
	await _frames(2)

	print("IC-120: standing meltwater")
	g = _game()
	await _frames(3)
	var c0: float = g.world.tag("GEN-E").cond
	g.sys.fvol["melt"].amount = 3.5
	await _frames(4)
	check(_has(g, "melt_short") and g.world.tag("GEN-E").cond < c0, "3.5 m³ standing with the bus live: it shorts the engine module")
	g.queue_free()
	await _frames(2)

	print("IC-120: the crack, the seats")
	g = _game()
	await _frames(3)
	var b0: float = g.world.tag("ECS-H").cond
	var blk = g.world.tag("ICE-3M")
	g.on_cut_into(blk, g.world.frame(blk) * Geom.centroid(blk.poly))
	await _frames(4)
	check(_has(g, "crack_run") and g.world.tag("ECS-H").cond < b0, "a cut on the crack with the seats holding: the ice splits")
	g.do_wrench(_ctrl(g, "PH-3"))
	await _frames(4)
	check(_has(g, "ice_drop"), "a seat let go with the ice still on: it drops")
	g.queue_free()
	await _frames(2)

	print("IC-120: melted, then the seats")
	g = _game()
	await _frames(3)
	for b in g.ice.melt:
		var p = g.world.tag(b)
		if p != null and not p.gone:
			g.world.remove_piece(p)
	await _frames(4)
	for t in ["PH-1", "PH-2", "PH-3", "PH-4"]:
		g.do_wrench(_ctrl(g, t))
		await _frames(2)
	check(g.ice.blocks_left() == 0 and not _has(g, "ice_drop") and g.ice.unsafe().is_empty(), "the ice gone, the seats let go quietly")
	g.queue_free()
	await _frames(2)
	print("IC120 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
