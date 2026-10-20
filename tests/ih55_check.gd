extends SceneTree
# IH-55 "Puffer"'s soft bags (scripts/softshell.gd): each bag holds 30 kPa; cut
# still inflated it rips and comes down on the spine's equipment; a strap cut with
# its tensioner taut whips; the patch on the aft upper bag cut with the bag still
# inflated rips it; let down at its port a bag folds flat, and with its tensioner
# slack its straps come off quietly.
# godot --headless --path . --fixed-fps 60 -s tests/ih55_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ih55_save.json"
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
	Game.start_ship = "ih55"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _cut(g, tag: String) -> void:
	var p = g.world.tag(tag)
	g.on_cut_into(p, g.world.frame(p) * Geom.centroid(p.poly))
	await _frames(3)


func _height(g, tag: String) -> float:
	return Geom.bbox(g.world.tag(tag).poly).size.y / Geom.M


func _run() -> void:
	print("IH-55: the bags inflated")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "ih55" and g.softshell.active(), "the IH-55 carries its soft bags")
	check(absf(g.sys.P("BAG-1") - 30.0) < 1.0, "a bag holds 30 kPa (%.0f)" % g.sys.P("BAG-1"))
	await _cut(g, "L1")
	check(_count(g, "bag_rip") == 1 and g.world.tag("GAS-P").cond <= 0.5 and _height(g, "L1") < 3.0, "the front upper bag cut inflated: it rips and comes down on the spine's equipment (%.2f)" % g.world.tag("GAS-P").cond)
	await _cut(g, "ST-L22")
	check(_count(g, "strap_whip") == 1, "a strap cut with its tensioner taut whips")
	await _cut(g, "PATCH")
	check(_count(g, "bag_rip") == 2 and g.softshell.ripped.has("L3"), "the patch cut with the aft upper bag still inflated: the bag rips")
	check(g.softshell.save_state().get("ripped", []).has("L1"), "the save keeps the ripped bags")
	g.queue_free()
	await _frames(2)

	print("IH-55: let down first")
	g = _game()
	await _frames(3)
	g.do_hose(_ctrl(g, "BV-4"))
	var f := 0
	while g.sys.P("BAG-4") > 2.5 and f < 60 * 240:
		f += 1
		await process_frame
	await _frames(30)
	check(g.sys.P("BAG-4") < 3.0 and _height(g, "L4") < 3.0, "let down at its port (%.0f s), the aft lower bag folds flat against the spine" % (f / 60.0))
	g.do_wrench(_ctrl(g, "TN-4"))
	await _frames(2)
	for k in [1, 2, 3]:
		await _cut(g, "ST-L4%d" % k)
	check(_count(g, "strap_whip") == 0 and _count(g, "bag_rip") == 0, "its tensioner slack, its straps come off quietly")
	await _cut(g, "L4")
	check(_count(g, "bag_rip") == 0, "and the slack bag cut apart rips nothing")
	g.queue_free()
	await _frames(2)
	print("IH55 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
