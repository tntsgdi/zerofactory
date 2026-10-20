extends SceneTree
# HG-170 "Gas Sea"'s cryogenic tanks (scripts/boiloff.gd): refrigerated, the pressure
# holds; the power cut, it climbs, tank 2 (torn insulation) vents first and tank 3 (its
# relief valve frozen) bursts; the frozen valve shows on its probe; thawed, drawn off
# while refrigerated, then the power off: nothing vents, nothing bursts.
# godot --headless --path . --fixed-fps 60 -s tests/hg170_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_hg170_save.json"
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
	Engine.time_scale = 8.0
	await _frames(int(s * 60.0 / 8.0))
	Engine.time_scale = 1.0


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "hg170"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _run() -> void:
	print("HG-170: the power cut")
	var g = _game()
	await _frames(3)
	var bo = g.boiloff
	check(bo.active() and bo.refrigerating() and bo.tank_kpa("TK1") > 400.0 and bo.cargo("TK1") > 4.9, "four tanks at %.0f kPa, refrigerated" % bo.tank_kpa("TK1"))
	check(bo.valve_temp("TK3") < -150.0 and bo.valve_temp("TK1") > -60.0, "tank 3's valve probe reads %.0f °C (iced), tank 1's %.0f °C" % [bo.valve_temp("TK3"), bo.valve_temp("TK1")])
	await _secs(60.0)
	check(bo.tank_kpa("TK2") < 420.0 and _count(g, "tank_vent") == 0, "a minute refrigerated: holding, falling (%.0f kPa)" % bo.tank_kpa("TK2"))
	g.do_wrench(_ctrl(g, "K-M1"))
	g.do_wrench(_ctrl(g, "K-M2"))
	await _secs(160.0)
	check(not bo.refrigerating() and bo.vented.has("TK2") and bo.cargo("TK2") < 5.0, "the power off: tank 2 climbs fastest and vents (%.2f m³ left)" % bo.cargo("TK2"))
	var n := 0
	while not bo.burst.has("TK3") and n < 600:
		await _secs(10.0)
		n += 10
	check(bo.burst.has("TK3") and _count(g, "tank_burst") == 1 and bo.cargo("TK3") < 0.01, "tank 3's valve frozen shut: it bursts (%d s later)" % (n + 160))
	check(g.world.tag("RV-3").cond < 1.0 and g.world.tag("LG-3").cond < 1.0 and g.world.tag("TC1-0").body != null, "and wrecks what is on it, its shell blown apart")
	check(bo.save_state().burst.size() == 1, "saved")
	g.queue_free()
	await _frames(2)

	print("HG-170: the right way")
	g = _game()
	await _frames(3)
	bo = g.boiloff
	g.do_wrench(_ctrl(g, "RVH-3"))
	await _secs(25.0)
	check(not bo.frozen("TK3") and bo.valve_temp("TK3") > -60.0, "the heater on: tank 3's valve thaws (%.0f °C)" % bo.valve_temp("TK3"))
	for k in 4:
		g.do_hose(_ctrl(g, "PT-%d" % (k + 1)))
	n = 0
	while bo.unsafe().size() > 0 and n < 600:
		await _secs(10.0)
		n += 10
	check(bo.unsafe().is_empty() and g.incidents.is_empty(), "drawn off refrigerated: all four empty in %d s, nothing vented" % n)
	check(g.sys.fluid_rec.get("coolant", 0.0) > 19.0, "%.1f m³ of cargo recovered" % g.sys.fluid_rec.get("coolant", 0.0))
	g.do_wrench(_ctrl(g, "K-M1"))
	g.do_wrench(_ctrl(g, "K-M2"))
	await _secs(120.0)
	check(g.incidents.is_empty() and bo.burst.is_empty(), "then the power off: nothing left to climb")
	g.queue_free()
	await _frames(2)
	print("HG170 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
