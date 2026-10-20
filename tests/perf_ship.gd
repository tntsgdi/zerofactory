extends SceneTree
# Frame cost of a whole ship as a player sees it: idle up close, the whole ship in
# view, and a laser sweep through the hull. Vsync off, so the wall time is the cost.
# tools/run_test.sh tests/perf_ship.gd -- ship=fx70

const M := 48.0
var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_perfship_career.json"
	SaveGame.path = "user://zp_test_perfship_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# wall ms a frame, the worst frame, and the engine's own split
func _measure(tag: String, n: int) -> void:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	World.prof.clear()
	World.acc_sum = {}
	var sp := 0.0
	var sph := 0.0
	var scpu := 0.0
	var sgpu := 0.0
	var worst := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		sp += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		scpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		sgpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("PERF %-8s wall %.2f ms (worst %.1f)  process %.2f  physics %.2f  render cpu %.2f gpu %.2f  draw calls %d  objects %d" % [tag, wall, worst, sp / n, sph / n, scpu / n, sgpu / n,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	var parts := {}
	for k in World.prof:
		parts[k] = snappedf(World.prof[k] / float(n) / 1000.0, 0.01)
	for k in World.acc_sum:
		parts["acc_" + k] = snappedf(World.acc_sum[k] / float(n) / 1000.0, 0.01)
	if not parts.is_empty():
		print("PERF %-8s parts %s" % [tag, parts])


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var ship_id := "fx70"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			ship_id = a.substr(5)
	Game.contract = {}
	Game.start_ship = ship_id
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	var w := 0
	while str(g.state) == "survey" and w < 60 * 30:
		await process_frame
		w += 1
	await _frames(30)
	print("PERF ship %s pieces %d joints %d" % [ship_id, g.world.pieces.size(), g.world.joints.size()])
	await _measure("idle", 120)
	# the whole ship
	var bb := Rect2()
	var first := true
	for id in g.world.order:
		var p = g.world.pieces[id]
		var r := Geom.bbox(p.poly)
		bb = r if first else bb.merge(r)
		first = false
	g.cam_override = bb.get_center()
	g.zoom_override = clampf(1700.0 / bb.size.x, 0.12, 1.0)
	await _frames(40)
	await _measure("wide", 120)
	if "dock" in OS.get_cmdline_user_args():
		g.dock.visible = false
		await _frames(5)
		await _measure("wide-nodock-vis", 90)
		g.dock.visible = true
		g.dock.set_process(false)
		await _frames(5)
		await _measure("wide-nodock-proc", 90)
		g.dock.set_process(true)
		g.world.visible = false
		await _frames(5)
		await _measure("wide-noworld-vis", 90)
		g.world.visible = true
		await _frames(5)
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	await _frames(10)
	await _measure("revealed", 120)
	if "nodes" in OS.get_cmdline_user_args():
		await _nodes()
	# a laser sweep down through the hull, the camera up close
	g.cam_override = null
	g.zoom_override = -1.0
	var c := bb.get_center()
	g.drone.global_position = c + Vector2(0, -bb.size.y * 0.5 - 2.0 * M)
	g.drone.linear_velocity = Vector2.ZERO
	g.tools.set_tool(2)
	g.bot.aim = c + Vector2(-1.0 * M, -bb.size.y * 0.5)
	await _frames(10)
	g.bot.lmb = true
	var vp := root.get_viewport_rid()
	World.prof.clear()
	World.acc_sum = {}
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	for i in 150:
		var k := i / 150.0
		g.bot.aim = c + Vector2(-1.0 * M + k * 2.0 * M, -bb.size.y * 0.5 + k * 3.0 * M)
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	print("PERF cutting  wall %.2f ms (worst %.1f)" % [(Time.get_ticks_usec() - t0) / 1000.0 / 150.0, worst])
	g.bot.lmb = false
	await _measure("after", 120)
	if "shot" in OS.get_cmdline_user_args():
		preload("res://tests/cap.gd").save(root, "res://tests/out/perf_after.png")
		print("PERF drone ", g.drone.global_position / M, " c ", c / M, " zoom ", g.cam.zoom if "cam" in g else "?")
	if "vis" in OS.get_cmdline_user_args():
		await _vis()
	var all := []
	_all(root, all)
	var census := {}
	for nd in all:
		var k: String = nd.get_script().resource_path.get_file() if nd.get_script() else nd.get_class()
		k += " @" + str(nd.get_parent().get_script().resource_path.get_file() if nd.get_parent() and nd.get_parent().get_script() else "")
		census[k] = census.get(k, 0) + 1
	var ks := census.keys()
	ks.sort_custom(func(a, b): return census[a] > census[b])
	print("PERF nodes %d bodies %d pieces %d" % [all.size(), g.world.bodies.size(), g.world.pieces.size()])
	for k in ks.slice(0, 12):
		print("PERF census %5d %s" % [census[k], k])
	quit()


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _wall(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


# each processing node switched off in turn: what the frame saves
func _nodes() -> void:
	var base: float = await _wall(60)
	var nodes := []
	_all(root, nodes)
	var rows := []
	for nd in nodes:
		var pp: bool = nd.is_physics_processing()
		var p: bool = nd.is_processing()
		if not pp and not p:
			continue
		nd.set_physics_process(false)
		nd.set_process(false)
		await _frames(2)
		var t: float = await _wall(40)
		nd.set_physics_process(pp)
		nd.set_process(p)
		rows.append([base - t, str(nd.get_path()), nd.get_script().resource_path.get_file() if nd.get_script() else nd.get_class()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("PERF base %.2f" % base)
	for r in rows.slice(0, 12):
		print("PERF node %6.2f ms  %s  (%s)" % r)


# each canvas item hidden in turn (down to a few levels): the draw calls and the
# render time it costs
func _vis() -> void:
	var vp := root.get_viewport_rid()
	await _frames(5)
	var dc0: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var rows := []
	var cands := []
	_all(g, cands)
	for nd in cands:
		if not (nd is CanvasItem) or not nd.visible or nd.get_child_count() > 40:
			continue
		var depth := str(g.get_path_to(nd)).count("/")
		if depth > 3:
			continue
		nd.visible = false
		await _frames(3)
		var dc: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		nd.visible = true
		rows.append([dc0 - dc, cpu, str(g.get_path_to(nd)), nd.get_script().resource_path.get_file() if nd.get_script() else nd.get_class()])
	await _frames(3)
	print("PERF vis base draw calls %d cpu %.2f" % [dc0, RenderingServer.viewport_get_measured_render_time_cpu(vp)])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 14):
		print("PERF vis -%5d calls (cpu %.2f)  %s  (%s)" % r)
