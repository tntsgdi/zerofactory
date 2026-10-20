extends SceneTree
# LC-140 "Shell Mountain"'s courier in its hold (scripts/nested.gd): a bow-side cradle
# lock let go first, the courier lurches into the bow door; its hull cut, it is no
# longer whole; the winch refuses while it is unsafe; made safe, the locks off from the
# stern, the bow door up, it goes out whole and is paid as one.
# godot --headless --path . --fixed-fps 60 -s tests/lc140_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_lc140_save.json"
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
	Game.start_ship = "lc140"
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
	print("LC-140: the locks out of order")
	var g = _game()
	await _frames(3)
	var ns = g.nested
	check(ns.active() and not ns.out and ns.whole and ["battery", "fuel", "air", "locks", "door"].all(func(k): return ns.blockers().has(k)), "the courier aboard, unsafe: %s" % str(ns.blockers()))
	var c0: float = g.world.tag("SC-CON").cond
	g.do_wrench(_ctrl(g, "CL-4"))
	await _frames(4)
	check(_count(g, "nested_lurch") == 1 and ns.lurched and g.world.tag("SC-CON").cond < c0, "the bow lock let go first: it lurches into the door, its fittings knocked")
	check(ns.bonus_now() < float(ns.cfg.bonus) * 0.6, "and half its premium gone ($%.0f)" % ns.bonus_now())
	g.queue_free()
	await _frames(2)

	print("LC-140: its hull cut")
	g = _game()
	await _frames(3)
	ns = g.nested
	var hp = g.world.tag("SS2-0")
	g.on_cut_into(hp, Geom.bbox(g.world.world_poly(hp)).get_center())
	await _frames(2)
	check(_count(g, "nested_cut") == 1 and not ns.whole and ns.bonus_now() == 0.0, "a cut through its roof: no longer whole, no premium")
	g.queue_free()
	await _frames(2)

	print("LC-140: the right way")
	g = _game()
	await _frames(3)
	ns = g.nested
	g.do_wrench(_ctrl(g, "WINCH"))
	await _frames(4)
	check(not ns.out and g.messages.any(func(m): return m[0] == "nested_not_ready"), "the winch thrown too early: it refuses, and says why")
	g.do_wrench(_ctrl(g, "WINCH"))
	g.do_wrench(_ctrl(g, "SK"))
	g.do_hose(_ctrl(g, "PSF"))
	g.do_hose(_ctrl(g, "G-S"))
	g.do_hose(_ctrl(g, "G-H"))
	var n := 0
	while not ns.hazards().is_empty() or g.sys.P("H") > 5.0:
		await _secs(5.0)
		n += 5
		if n > 600:
			break
	check(ns.hazards().is_empty() and g.sys.P("H") < 5.0, "its battery off, fuel and air drawn, the hold emptied (%d s)" % n)
	for l in ["CL-1", "CL-2", "CL-3", "CL-4"]:
		g.do_wrench(_ctrl(g, l))
		await _frames(2)
	check(_count(g, "nested_lurch") == 0 and ns.locks_held().is_empty(), "the locks off from the stern forward: no lurch")
	g.do_wrench(_ctrl(g, "BOW"))
	n = 0
	while not ns.door_open() and n < 600:
		await _frames(10)
		n += 10
	check(ns.door_open(), "the bow door lifts")
	var earned0: float = g.income_equip
	g.do_wrench(_ctrl(g, "WINCH"))
	await _frames(4)
	var paid: float = g.income_equip - earned0
	var con = g.world.tag("SC-CON")
	check(ns.out and (con == null or con.gone), "the winch: out it goes")
	check(paid > float(ns.cfg.bonus) and g.incidents.is_empty(), "paid as one, whole: $%.0f (premium $%.0f), no incident" % [paid, float(ns.cfg.bonus)])
	check(ns.save_state().out and g.world.tag("SAD-1") != null and not g.world.tag("SAD-1").gone, "saved as out; the cradle stays aboard")
	g.queue_free()
	await _frames(2)
	print("LC140 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
