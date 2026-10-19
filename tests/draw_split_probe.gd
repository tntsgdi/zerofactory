extends SceneTree
# Which part of the berth makes the draw calls (2026-10-18 performance work).
# tools/run_test.sh tests/draw_split_probe.gd -- ship=med47
const M := 48.0
func _initialize() -> void:
	Career.path = "user://zp_test_split_career.json"
	SaveGame.path = "user://zp_test_split_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _calls(n: int) -> Array:
	var c := 0.0
	var o := 0.0
	var t := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		c += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		o += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		t += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
	return [c / n, o / n, t / n]

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	Career.data = Career.fresh()
	Career.data.upgrades = {"berth88": true, "hauler": true, "hauler2": true}
	Game.contract = {}
	Game.start_ship = "med47"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			Game.start_ship = a.substr(5)
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 90:
		await process_frame
	g.drone.alive = true
	if "whole" in OS.get_cmdline_user_args():
		g.zoom_override = g.zoom_min()
		g.cam_override = Vector2(42.0 * 48.0, -1.0 * 48.0)
		for i in 60:
			await process_frame
		var all0: Array = await _calls(20)
		print("WHOLE all: calls %.0f objects %.0f render %.2f ms" % all0)
		for part in ["fill", "line", "art"]:
			g.world._pass_roots[part].visible = false
			var r: Array = await _calls(12)
			g.world._pass_roots[part].visible = true
			print("WHOLE without %s: calls %.0f objects %.0f render %.2f ms" % [part, r[0], r[1], r[2]])
		quit()
		return
	var base: Array = await _calls(30)
	print("SPLIT all: calls %.0f objects %.0f render %.2f ms" % base)
	var parts := {"world": g.world, "dock": g.dock, "hud": g.hud, "fx": g.fx, "drone": g.drone, "tools": g.tools, "blueprint": g.blueprint}
	for c in g.get_children():
		if c is CanvasItem and not c in parts.values():
			parts[c.get_class() + ":" + str(c.name)] = c
	for k in parts:
		var n = parts[k]
		if n == null or not (n is CanvasItem or n is CanvasLayer):
			continue
		n.visible = false
		var r: Array = await _calls(12)
		n.visible = true
		print("SPLIT without %-28s calls %5.0f (-%4.0f) objects %6.0f (-%5.0f) render %.2f ms" % [k, r[0], base[0] - r[0], r[1], base[1] - r[1], r[2]])
	# inside the world: its layers
	for c in g.world.get_children():
		if c is CanvasItem:
			c.visible = false
			var r: Array = await _calls(12)
			c.visible = true
			print("SPLIT   world/%-24s calls -%4.0f objects -%5.0f" % [str(c.name), base[0] - r[0], base[1] - r[1]])
	for c in g.dock.get_children():
		if c is CanvasItem:
			c.visible = false
			var r: Array = await _calls(12)
			c.visible = true
			print("SPLIT   dock/%-24s calls -%4.0f objects -%5.0f" % [str(c.name), base[0] - r[0], base[1] - r[1]])
	quit()
