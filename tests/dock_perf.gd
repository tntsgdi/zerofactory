extends SceneTree
# What the berth costs a frame with the whole ship in view, layer by layer: each of
# the dock's drawing layers hidden in turn (and its redraw stopped), the frame
# timed. Test saves only.
# tools/run_test.sh tests/dock_perf.gd -- [ship=fx70]

var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_dockperf_career.json"
	SaveGame.path = "user://zp_test_dockperf_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wall(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


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
	await _frames(40)
	var r: Rect2 = g.focus_rect()
	g.cam_override = r.get_center()
	g.zoom_override = clampf(1700.0 / r.size.x, 0.12, 1.0)
	await _frames(40)
	await _wall(90)
	var base := await _wall(90)
	print("DOCKPERF all %.2f ms (zoom %.2f)" % [base, g.zoom_override])
	var d = g.dock
	var layers := {"static": d.static_node, "furnace": d.furnace_node, "ships": d.ships, "add": d.add_node, "overlay": d.overlay_node, "clamps": d.clamp_node}
	for k in layers:
		layers[k].visible = false
		await _frames(5)
		print("DOCKPERF without %-8s %.2f ms" % [k, await _wall(60)])
		layers[k].visible = true
	for id in d.mouth_nodes:
		d.mouth_nodes[id].visible = false
	await _frames(5)
	print("DOCKPERF without mouths   %.2f ms" % (await _wall(60)))
	for id in d.mouth_nodes:
		d.mouth_nodes[id].visible = true
	d.self_modulate.a = 0.0
	d.set_process(false)
	await _frames(5)
	print("DOCKPERF dock not processing %.2f ms" % (await _wall(60)))
	d.set_process(true)
	d.visible = false
	await _frames(5)
	print("DOCKPERF no dock at all %.2f ms" % (await _wall(60)))
	d.visible = true
	# up close at the furnace, where the plant is drawn in full every frame
	g.cam_override = Vector2(d.furnace_x, Dock.FLOOR_Y + 4.0) * 48.0
	g.zoom_override = 1.3
	await _frames(60)
	d.prof_draw = [0, 0, 0, 0]
	print("DOCKPERF furnace close %.2f ms" % (await _wall(90)))
	var pf: Array = d.prof_draw
	print("DOCKPERF plant draw: smelter %.2f ms, line %.2f ms, flush %.2f ms a frame" % [pf[0] / 1000.0 / maxf(1, pf[3]), pf[1] / 1000.0 / maxf(1, pf[3]), pf[2] / 1000.0 / maxf(1, pf[3])])
	d.visible = false
	await _frames(5)
	print("DOCKPERF furnace close, no dock %.2f ms" % (await _wall(60)))
	quit(0)
