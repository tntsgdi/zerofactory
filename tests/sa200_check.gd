extends SceneTree
# SA-200 "Kite"'s sail (scripts/sail.gd): the drone flies past the film; the tension
# gauges read the stays; the top right panel is torn already; a panel cut while the
# sail is taut tears and the tear runs into its neighbours, and before the sail is
# earthed it discharges into the drone; a stay cut taut snaps, its panels tear and
# its spar whips into the gondola; earthed and slack (the winch let off), a panel
# comes away whole and a stay comes out quietly.
# godot --headless --path . --fixed-fps 60 -s tests/sa200_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_sa200_save.json"
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
	Game.start_ship = "sa200"
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


func _run() -> void:
	print("SA-200: the sail taut")
	var g = _game()
	await _frames(70)
	check(g.ship_id == "sa200" and g.sail.active(), "the SA-200 is a sail")
	check(g.world.static_cols.get(g.world.tag("FM-2").id, []).is_empty(), "the film is no wall to the drone")
	check(g.sail.pull("ST-2") > 10.0, "the tension gauge reads a stay (%.0f kN)" % g.sail.pull("ST-2"))
	check(g.sail.torn.has("FM-9") and not g.sail.torn.has("FM-8"), "the top right panel is torn already")
	await _cut(g, "FM-5")
	check(_count(g, "film_tear") == 1 and g.sail.torn.has("FM-4") and g.sail.torn.has("FM-6"), "a panel cut taut tears, and the tear runs into the panels either side")
	check(_count(g, "static_zap") == 1, "and the sail not yet earthed, it discharges into the drone")
	await _cut(g, "ST-2")
	check(_count(g, "stay_snap") == 1 and g.world.tag("WINCH-1").cond <= 0.5 and g.sail.torn.has("FM-2"), "a stay cut taut snaps: its panels tear, its spar whips into the gondola (%.2f)" % g.world.tag("WINCH-1").cond)
	check(g.sail.save_state().get("snapped", []).has("ST-2"), "the save keeps the snapped stay")
	g.queue_free()
	await _frames(2)

	print("SA-200: earthed and slack")
	g = _game()
	await _frames(70)
	g.do_wrench(_ctrl(g, "GND"))
	g.do_wrench(_ctrl(g, "W-NE"))
	await _frames(3)
	check(g.sail.grounded() and g.sail.pull("ST-7") < 1.0, "earthed, the north-east winch let off: its stays read slack")
	var fm = g.world.tag("FM-7")
	for j in g.world.joints_of(fm):
		if j.alive:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	await _frames(4)
	check((fm.body != null or fm.gone) and not g.sail.torn.has("FM-7") and _count(g, "film_tear") == 0 and _count(g, "static_zap") == 0, "a panel there comes away whole, with no discharge")
	await _cut(g, "ST-7")
	check(_count(g, "stay_snap") == 0, "and a stay there comes out quietly")
	g.queue_free()
	await _frames(2)
	print("SA200 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
