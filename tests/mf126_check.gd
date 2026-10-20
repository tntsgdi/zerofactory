extends SceneTree
# MF-126 "Molten Ridge"'s furnace (scripts/furnace.gd): the core starts at 760 °C
# and a probe on the shell reads it; with the heat-exchange pumps running on the
# bus it cools; the main breaker opened while it is over 350 °C cracks it (40 % of
# its value left); the cooling loop drained while it is hot does the same; under
# 350 °C the power can go, but lifted out over 150 °C it cracks as it leaves its
# cradle; cooled, it comes out whole. The feed ram springs if its pivot comes out
# while it is still pinned and charged.
# godot --headless --path . --fixed-fps 60 -s tests/mf126_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_mf126_save.json"
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
	Game.start_ship = "mf126"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _lift(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)


func _run() -> void:
	print("MF-126: the core")
	var g = _game()
	await _frames(3)
	var fz = g.furnace
	check(fz.active() and absf(fz.core_temp() - 760.0) < 2.0, "the core starts at %.0f °C" % fz.core_temp())
	g.do_measure(_ctrl(g, "T-CORE"))
	check(g.sys.readings.get("T-CORE", {}).get("text", "").begins_with("7"), "the probe on the shell reads %s" % g.sys.readings.get("T-CORE", {}).get("text", "?"))
	var t0: float = fz.core_temp()
	await _frames(120)
	check(fz.cooling() and fz.core_temp() < t0 - 4.0, "on the bus its heat exchange cools it (%.0f °C)" % fz.core_temp())
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(4)
	var core = g.world.tag("CORE")
	check(fz.cracked and absf(core.value - 32000.0 * 0.4) < 1.0, "the main breaker opened over 350 °C: the core cracks ($%.0f left)" % core.value)
	g.queue_free()
	await _frames(2)

	print("MF-126: the loop drained hot")
	g = _game()
	await _frames(3)
	g.sys.fvol["loop"].amount = 0.3
	await _frames(4)
	check(g.furnace.cracked, "the cooling loop drained with the core at %.0f °C: it cracks" % g.furnace.core_temp())
	g.queue_free()
	await _frames(2)

	print("MF-126: under 350, over 150")
	g = _game()
	await _frames(3)
	g.furnace.T = 300.0
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(4)
	check(not g.furnace.cracked, "at 300 °C the power can go without a crack")
	_lift(g, "CORE")
	await _frames(4)
	check(g.furnace.cracked and g.incidents.any(func(i): return i[1] == "core_cracked" and i[2] == "core_lifted_hot"), "but lifted out over 150 °C it cracks")
	g.queue_free()
	await _frames(2)

	print("MF-126: cooled")
	g = _game()
	await _frames(3)
	g.furnace.T = 140.0
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(2)
	_lift(g, "CORE")
	await _frames(4)
	check(not g.furnace.cracked and g.world.tag("CORE").value > 31999.0, "cooled under 150 °C it comes out whole")
	check(g.furnace.save_state().has("T"), "the core's temperature is saved")
	var j = g.mech._joint("FR-P")
	g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	await _frames(4)
	check(g.incidents.any(func(i): return i[1] == "preload"), "the feed ram's pivot out while pinned and charged: it springs")
	g.queue_free()
	await _frames(2)
	print("MF126 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
