extends SceneTree
# Which node's frame costs what on a big ship: each node's processing switched off in
# turn and the idle frame timed again (the difference is roughly its share).
# godot --headless --path . --fixed-fps 60 -s tests/ark_prof.gd -- ship=arktest

var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_arkprof_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _time(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _run() -> void:
	Game.contract = {}
	var ship_id := "arktest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship_id = a.substr(5)
	Game.start_ship = ship_id
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	await _frames(40)
	var base := await _time(90)
	print("PROF base %.2f ms" % base)
	print("PROF bodies %d joints %d" % [scene.world.bodies.size(), scene.world.joints.size()])
	for half in ["physics", "process"]:
		var dk = scene.dock
		if half == "physics":
			dk.set_physics_process(false)
		else:
			dk.set_process(false)
		await _frames(2)
		print("PROF dock %s off: %.2f ms" % [half, await _time(60)])
		dk.set_physics_process(true)
		dk.set_process(true)
	var nodes := []
	_all(scene, nodes)
	var rows := []
	for nd in nodes:
		var pp: bool = nd.is_physics_processing()
		var p: bool = nd.is_processing()
		if not pp and not p:
			continue
		nd.set_physics_process(false)
		nd.set_process(false)
		await _frames(2)
		var t := await _time(60)
		nd.set_physics_process(pp)
		nd.set_process(p)
		rows.append([base - t, str(scene.get_path_to(nd)), nd.get_script().resource_path.get_file() if nd.get_script() else nd.get_class()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 14):
		print("PROF %6.2f ms  %s  (%s)" % r)
	finished = true
