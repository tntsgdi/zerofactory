extends SceneTree
# ST-40 "Hummingbird"'s composite airframe (scripts/composite.gd): a panel cut beside a
# room with air fills it with smoke, which spoils its electronics and, thick enough,
# fogs the canopy; vented first, or unbolted, nothing.
# godot --headless --path . --fixed-fps 60 -s tests/st40_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_st40_save.json"
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
	Game.start_ship = "st40"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _cut(g, at: Vector2) -> void:
	var p = g.world.piece_at(at * Geom.M, ["hull"])
	g.on_cut_into(p, at * Geom.M)


func _run() -> void:
	print("ST-40: cut with air in")
	var g = _game()
	await _frames(3)
	var c = g.composite
	check(c.active() and c.is_composite(g.world.piece_at(Vector2(25.0, 2.85) * Geom.M, ["hull"])), "the belly is a composite panel")
	var tlm = g.world.tag("TLM")
	var v0: float = tlm.cond
	_cut(g, Vector2(25.0, 2.85))
	await _frames(60 * 10)
	check(_has(g, "composite_fumes") and c.level("E") > 0.5, "a belly panel cut under the bay with air in it: smoke in E (%.0f ppm)" % (c.level("E") * 1000.0))
	check(tlm.cond < v0 and tlm.cond >= 0.55, "the bay's electronics are spoilt by it (telemetry at %.0f %%)" % (tlm.cond * 100.0))
	var seat = g.world.tag("SEAT-P")
	check(seat.cond > 0.99, "a seat is no electronics: untouched")
	g.do_measure(_ctrl(g, "SM-E"))
	check(str(g.sys.readings.get("SM-E", {}).get("text", "")) != "", "the smoke meter reads %s" % g.sys.readings.get("SM-E", {}).get("text", "?"))
	# the cockpit: thick smoke fogs the canopy
	_cut(g, Vector2(9.0, -2.6))
	_cut(g, Vector2(7.0, -2.35))
	await _frames(30)
	check(g.world.tag("CAN-1").cond < 0.6, "two cuts beside the cockpit: the canopy fogs")
	# venting takes the smoke out with the air
	g.do_hose(_ctrl(g, "G-E"))
	var n := 0
	while g.sys.P("E") > 2.0 and n < 6000:
		await _frames(30)
		n += 30
	check(c.level("E") < 0.05, "E vented: the smoke goes with the air")
	check(c.save_state().smoke.has("P"), "the smoke is saved")
	g.queue_free()
	await _frames(2)

	print("ST-40: vented first, or unbolted")
	g = _game()
	await _frames(3)
	c = g.composite
	g.do_hose(_ctrl(g, "G-E"))
	n = 0
	while g.sys.P("E") > 2.0 and n < 6000:
		await _frames(30)
		n += 30
	tlm = g.world.tag("TLM")
	_cut(g, Vector2(25.0, 2.85))
	await _frames(120)
	check(not _has(g, "composite_fumes") and tlm.cond > 0.99, "cut with E empty: no smoke")
	var fin = g.world.tag("HCF-U")
	for j in g.world.joints_of(fin):
		g.world.kill_joint(j)
	await _frames(10)
	check(fin.body != null and not _has(g, "composite_fumes"), "a fin unbolted comes off clean")
	g.queue_free()
	await _frames(2)
	print("ST40 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
