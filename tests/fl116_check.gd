extends SceneTree
# FL-116 "Tide"'s look-alike media (scripts/media.gd): the branches cross, so a
# manifold port's number isn't its tank's; each port's sample point reads what
# comes out there; drawn off with the other branches' valves still open, a branch
# comes out mixed (worth nothing, charged for); with them shut it comes out clean;
# the manifold freed while a branch still holds its medium spills them; the state
# survives a save.
# godot --headless --path . --fixed-fps 60 -s tests/fl116_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_fl116_save.json"
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
	Game.start_ship = "fl116"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _read(g, id: String) -> String:
	g.do_measure(_ctrl(g, id))
	return g.sys.readings.get(id, {}).get("text", "?")


func _run() -> void:
	print("FL-116: the media")
	var g = _game()
	await _frames(3)
	var s1 := _read(g, "SP-1")
	var s2 := _read(g, "SP-2")
	check(s2.begins_with(Txt.t("med_solvent")) and s1.begins_with(Txt.t("med_glycol")), "the ports aren't their tanks: port 2 reads %s, port 1 reads %s" % [s2, s1])
	# drawn off with every valve open: mixed
	g.do_hose(_ctrl(g, "MP-2"))
	for i in 60 * 6:
		await physics_frame
	check(g.media.mixed > 0.05 and g.incidents.any(func(i): return i[1] == "media_mixed"), "port 2 drawn off with the other branches open: it comes out mixed (%.2f m³)" % g.media.mixed)
	check(float(g.sys.fluid_rec.get("solvent", 0.0)) < 0.01, "and none of it counts as solvent (%.3f)" % float(g.sys.fluid_rec.get("solvent", 0.0)))
	check(g.media.save_state().mixed > 0.05, "the save keeps what was spoilt")
	g.queue_free()
	await _frames(2)

	print("FL-116: branch by branch")
	g = _game()
	await _frames(3)
	g.do_wrench(_ctrl(g, "V-2"))
	g.do_wrench(_ctrl(g, "V-3"))
	await _frames(2)
	g.do_hose(_ctrl(g, "MP-2"))
	for i in 60 * 6:
		await physics_frame
	check(g.media.mixed < 0.001 and float(g.sys.fluid_rec.get("solvent", 0.0)) > 0.05, "the other two valves shut first: port 2's solvent comes out clean (%.2f m³)" % float(g.sys.fluid_rec.get("solvent", 0.0)))
	# the manifold out with the other branches still full
	var mf = g.world.tag("MANIFOLD")
	for l in g.world.lines_of(mf):
		g.world.kill_line(l)
	for j in g.world.joints_of(mf):
		g.world.kill_joint(j)
	await _frames(4)
	check(g.media.spilt and g.incidents.any(func(i): return i[1] == "manifold_spill"), "the manifold unplugged and freed with branches still full: they spill through it")
	g.queue_free()
	await _frames(2)
	print("FL116 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
