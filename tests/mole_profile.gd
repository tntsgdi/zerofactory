extends SceneTree
var g
var frame := 0
var times: Array = []
var last_us := 0
var samples := 0
var phase := "close"
func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.quality = "high"
	Txt.dev = false
	Txt.cfg_path = "user://zp_test_mole_settings.cfg"
	Career.path = "user://zp_test_mole_career.json"
	SaveGame.path = "user://zp_test_mole_contract.json"
	Game.contract = {}
	Game.start_ship = "m14"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(23, -2) * Geom.M, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	g.cam_override = Vector2(20, 0) * Geom.M
	g.zoom_override = 1.1
func report() -> void:
	times.sort()
	var total := 0.0
	for v in times: total += v
	print("MOLE ", phase, " frames=", times.size(), " avg_ms=", total / times.size(), " p95_ms=", times[int(times.size() * .95)], " peak_ms=", times[-1], " pieces=", g.world.pieces.size())
	var keys: Array = Prof.sum.keys()
	keys.sort_custom(func(a,b): return Prof.sum[a] > Prof.sum[b])
	for key in keys.slice(0, 18): print("BUCKET ", key, " avg_ms=", Prof.sum[key] / 1000.0 / samples, " peak_ms=", Prof.peak[key] / 1000.0)
func _process(_dt: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	if frame in [45, 145, 245]:
		Prof.reset()
		times = []
		samples = 0
	if (frame > 45 and frame <= 125) or (frame > 145 and frame <= 225) or (frame > 245 and frame <= 325):
		times.append((now - last_us) / 1000.0)
		samples += 1
		Prof.roll()
	if frame == 125:
		report()
		phase = "wide"
		g.cam_override = Vector2(29, 0) * Geom.M
		g.zoom_override = .6
		for n in g.world.rooms: g.world.reveal(n, g.world.rooms[n].from)
	if frame == 225:
		report()
		phase = "draining"
		for id in ["GATE-1", "GATE-2"]:
			var c = g.world.ctrls[id]
			g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
		print("DRAIN open=", g.world.tag("GATE-1").door_open, ",", g.world.tag("GATE-2").door_open)
	if frame == 325:
		report()
		print("DRAIN fines_remaining=", g.ore.fines, " stream=", g.ore.stream.size(), " paid=", g.ore.paid)
		g.queue_free()
		quit()
	last_us = now
	return false
