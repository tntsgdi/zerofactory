extends SceneTree
# Native all-hull timing. --fixed-fps 60 makes the before/after simulation identical.
var g
var records: Array = []
var ships := ["tug", "s09", "pod", "gr7", "h22", "m14", "med47", "fr26", "ts1", "e07a", "e07b", "e07c", "e07d"]
func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func sample(id: String, phase: String, ready_ms: float) -> void:
	await frames(45)
	Prof.reset()
	var times: Array = []
	var calls := 0.0
	var rcpu := 0.0
	var rgpu := 0.0
	var last := Time.get_ticks_usec()
	for i in 50:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		Prof.roll()
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
		rgpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	times.sort()
	var avg := 0.0
	for v in times: avg += v
	var buckets: Array = []
	var keys: Array = Prof.sum.keys()
	keys.sort_custom(func(a,b): return Prof.sum[a] > Prof.sum[b])
	for key in keys.slice(0,8): buckets.append([key, Prof.sum[key] / 50000.0])
	var row := {"ship":id,"phase":phase,"avg_ms":avg / times.size(),"p95_ms":times[47],"max_ms":times[-1],"ready_ms":ready_ms,"pieces":g.world.pieces.size(),"bodies":g.world.bodies.size(),"draw_calls":calls/50.0,"render_cpu_ms":rcpu/50.0,"render_gpu_ms":rgpu/50.0,"buckets":buckets}
	records.append(row)
	print("FLEET ",JSON.stringify(row))
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	Txt.cfg_path = "user://zp_test_fleet_settings.cfg"
	Career.path = "user://zp_test_fleet_career.json"
	SaveGame.path = "user://zp_test_fleet_contract.json"
	Txt.quality = "high"
	Txt.dev = false
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): ships = Array(args)
	for id in ships:
		seed(20261017)
		Game.contract = {}
		Game.start_ship = id
		var begin := Time.get_ticks_usec()
		g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
		root.add_child(g)
		var ready_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var length: float = g.ship.get("length",42.0)
		g.cam_override = Vector2(length * 0.4,0) * Geom.M
		g.zoom_override = 1.1
		await sample(id,"close",ready_ms)
		g.cam_override = Vector2(length * .5,0) * Geom.M
		g.zoom_override = minf(.8, root.size.x / ((length+10.0)*Geom.M))
		for n in g.world.rooms: g.world.reveal(n,g.world.rooms[n].from)
		g.blueprint.toggle()
		await sample(id,"blueprint",ready_ms)
		g.blueprint.toggle()
		var loose := 0
		for pid in g.world.order.duplicate():
			var p = g.world.pieces[pid]
			if p.gone or p.body != null or p.mass > 3.0 or p.mass < .1 or p.get_meta("rig",false) or p.door or p.cls != "metal": continue
			for j in g.world.joints_of(p): g.world.kill_joint(j)
			for l in g.world.lines_of(p): g.world.kill_line(l)
			loose += 1
			if loose >= 12: break
		await sample(id,"loose_parts",ready_ms)
		g.queue_free()
		await frames(4)
		Engine.time_scale = 1.0
	print("FLEET_COMPLETE ",records.size())
	quit()
