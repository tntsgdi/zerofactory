extends SceneTree
# How smooth the frames are (2026-10-18, player: "the UI still isn't smooth
# enough"): uncapped frame times on each terminal page, then a berth with both
# haulers working while the drone flies about. Reported: median, P95, P99, the
# worst frame, and how many frames went over 20 ms (a visible hitch at 60 Hz),
# with the Prof buckets of the worst ones. Test files only.
# tools/run_test.sh tests/smooth_probe.gd

const M := 48.0
var term


func _initialize() -> void:
	Career.path = "user://zp_test_smooth_career.json"
	SaveGame.path = "user://zp_test_smooth_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _sample(what: String, n: int, step: Callable = Callable()) -> void:
	var times: Array = []
	var worst: Array = []
	var last := Time.get_ticks_usec()
	var rcpu := 0.0
	var phys := 0.0
	var proc := 0.0
	var rgpu := 0.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	Prof.reset()
	for i in n:
		if step.is_valid():
			step.call(i)
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
		rgpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		if ms > 20.0:
			worst.append([snappedf(ms, 0.1), i])
		Prof.roll()
	var s := times.duplicate()
	s.sort()
	var over := times.filter(func(x): return x > 20.0).size()
	print("SMOOTH %-22s median %5.1f  p95 %5.1f  p99 %5.1f  max %5.1f ms  hitches>20ms %d/%d %s" % [what, s[s.size() / 2], s[int(s.size() * 0.95)], s[int(s.size() * 0.99)], s[-1], over, n, str(worst.slice(0, 8))])
	var keys: Array = Prof.sum.keys()
	keys.sort_custom(func(a, b): return Prof.sum[a] > Prof.sum[b])
	var top: Array = []
	for k in keys.slice(0, 14):
		top.append("%s %.2f (peak %.1f)" % [k, Prof.sum[k] / 1000.0 / n, Prof.peak[k] / 1000.0])
	print("        process %.2f physics %.2f ms/frame" % [proc / n, phys / n])
	print("        render cpu %.2f gpu %.2f ms/frame; busiest scripts (ms/frame): %s" % [rcpu / n, rgpu / n, ", ".join(top)])


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 41250.0
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.data.upgrades = {"scan_kit": true, "hauler": true, "hauler2": true}
	Career.save()
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(150)
	for p in ([] if "berth" in OS.get_cmdline_user_args() else [[-1, "home"], [0, "contracts"], [1, "equipment"], [4, "supplies"], [5, "route"], [2, "ledger"]]):
		term.set_tab(p[0])
		await _frames(5)
		await _sample("terminal " + str(p[1]), 180, func(i): if i % 20 == 0: term.sel = (term.sel + 1) % maxi(1, term.items().size()))
	term.queue_free()
	await _frames(5)
	# a berth at work: GR-001, both haulers, the drone flying a loop
	Career.data = {}
	Career.start_new()
	Career.data.upgrades = {"hauler": true, "hauler2": true, "berth88": true}
	Career.save()
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	# ship=<id>: that type on its own (no contract), for the heavier hulls
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			Game.contract = {}
			Game.start_ship = a.substr(5)
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	await _sample("berth idle", 240)
	await _sample("berth flying", 600, func(i):
		var a: float = i / 60.0
		g.bot.move = Vector2(cos(a), sin(a * 0.7))
		g.bot.aim = g.drone.global_position + Vector2(cos(a * 2.0), sin(a * 2.0)) * 3.0 * M)
	print("SMOOTH DONE")
	quit()
