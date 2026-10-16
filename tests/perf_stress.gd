extends SceneTree
# Roadmap 1.2 acceptance: the worst case at once — the laser cutting the roof
# of room A open (explosive decompression), 30 loose pieces drifting about,
# then a haul with the grapple while the room is still venting. Vsync is off,
# so the time between frames is what the frame really costs.
# tools/run_test.sh tests/perf_stress.gd   (add -- prof after tools/prof_wrap.py on)
# Pass: worst frame <= 25 ms, average <= 12 ms.

const M := 48.0
var game
var frame := 0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var last_us := 0
var times := PackedFloat32Array()
var phase_t := {}
var floaters: Array = []
var prof := false
var slow_log: Array = []
var probe
var pend
var pfirst
var split := {"phys": 0.0, "proc": 0.0, "draw": 0.0}
var phys_ms := 0.0
var last_proc := 0
var last_test := 0
var eng := {"phys": 0.0, "proc": 0.0, "rcpu": 0.0, "rgpu": 0.0, "calls": 0.0, "prims": 0.0}


func _initialize() -> void:
	prof = "prof" in OS.get_cmdline_user_args()
	root.add_child(preload("res://tests/test_window.gd").new())
	probe = preload("res://tests/phys_probe.gd").new()
	root.add_child(probe)
	pend = preload("res://tests/proc_probe.gd").new()
	root.add_child(pend)
	pfirst = preload("res://tests/proc_first.gd").new()
	root.add_child(pfirst)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _spawn_floaters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		var c := Vector2(rng.randf_range(4.0, 40.0), rng.randf_range(-11.5, -7.0)) * M
		var w := rng.randf_range(0.5, 1.6) * M
		var h := rng.randf_range(0.18, 0.5) * M
		var a := rng.randf() * TAU
		var poly := PackedVector2Array()
		for q in [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]:
			poly.append(c + (q * 0.5).rotated(a))
		var p = game.world.add_piece("plate", poly, {"density": 0.35})
		floaters.append(p)
		game.world.rebuild_cols(p)
	game.world.dirty_links = true


func _process(_dt: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var ft := (now - last_us) / 1000.0
	last_us = now
	var pms: float = (now - probe.start_us) / 1000.0 if probe._frame == Engine.get_process_frames() else 0.0
	# previous frame: process ended at pend.end_us, then drawing until this frame's physics began
	var draw_ms: float = ((probe.start_us if pms > 0.0 else now) - pend.end_us) / 1000.0
	var proc_ms: float = (pend.end_us - last_proc) / 1000.0
	last_test = last_proc
	last_proc = now
	if frame > 40:
		phys_ms += pms
		split.phys += pms
		split.proc += proc_ms
		split.draw += draw_ms
	if prof:
		if ft > 18.0 and frame > 40:
			var top: Array = Prof.frame.keys()
			top.sort_custom(func(a, b): return Prof.frame[a] > Prof.frame[b])
			var parts := []
			for k in top.slice(0, 5):
				parts.append("%s %.1f" % [k, Prof.frame[k] / 1000.0])
			var vp := root.get_viewport_rid()
			var fxn: int = game.fx.sparks_l.size() + game.fx.mist.size() + game.fx.shards.size() + game.fx.drops.size() + game.fx.slag.size()
			slow_log.append("slow frame %d: %.1f ms  [prev test %.1f nodes %.1f, draw %.1f]  physics %.1f (%d steps)  rcpu %.1f gpu %.1f fx %d calls %d | %s" % [frame, ft, (pfirst.start_us - last_test) / 1000.0, (pend.end_us - pfirst.start_us) / 1000.0, draw_ms, pms, probe.steps, RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vp), fxn, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), ", ".join(parts)])
		Prof.roll()
	if OS.get_environment("ZP_NODRAW") != "" and frame > 40:
		game.world.dirty_draw = false
	if frame == 3:
		game.drone.global_position = Vector2(8.9, -6.0) * M
		game.drone.linear_velocity = Vector2.ZERO
		game.drone.spawn_t = 5.0
		game.tools.set_tool(2)
		bot.aim = Vector2(8.2, -4.5) * M
		_spawn_floaters()
	if frame == 6:
		for b in game.world.bodies:
			b.linear_velocity = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 90.0)
			b.angular_velocity = randf_range(-1.0, 1.0)
	if frame == 12:
		bot.lmb = true
	# 40 frames to settle (shader and font warm-up), then measure everything
	if frame == 40:
		times = PackedFloat32Array()
		Prof.reset()
	if frame > 12 and frame < 260:
		var k := (frame - 12) / 248.0
		bot.aim = (Vector2(8.2, -4.5).lerp(Vector2(8.2, -3.0), clampf(k * 2.0, 0, 1)) if k < 0.5 else Vector2(9.55, -3.0).lerp(Vector2(9.55, -4.5), clampf(k * 2.0 - 1.0, 0, 1))) * M
	if frame == 260:
		bot.lmb = false
	if frame == 262:
		# haul the nearest loose piece while room A is still venting
		game.tools.set_tool(3)
		var best = null
		var bd := INF
		for p in floaters:
			if p.gone or p.body == null:
				continue
			var d: float = p.center_world().distance_to(game.drone.global_position)
			if d < bd:
				bd = d
				best = p
		if best != null:
			var at: Vector2 = best.center_world()
			game.drone.global_position = at + Vector2(0, 2.0 * M)
			game.drone.reset_physics_interpolation()
			bot.aim = at
	if frame == 264:
		bot.lmb = true
	if frame > 264:
		bot.aim = game.drone.global_position + Vector2(3.0 * M, 0)
		bot.move = Vector2(-1, 0.3)
	if frame == 39:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if frame > 40:
		var vp := root.get_viewport_rid()
		eng.phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		eng.proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		eng.rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		eng.rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		eng.calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		eng.prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		times.append(ft)
		var ph := "cut" if frame < 260 else "haul"
		if not phase_t.has(ph):
			phase_t[ph] = PackedFloat32Array()
		phase_t[ph].append(ft)
	if frame == 520:
		_report()
		return true
	return false


func _stats(a: PackedFloat32Array) -> String:
	var s := 0.0
	var mx := 0.0
	var sorted := a.duplicate()
	sorted.sort()
	for v in a:
		s += v
		mx = maxf(mx, v)
	return "avg %.2f ms  p99 %.2f ms  worst %.2f ms  (%d frames)" % [s / maxf(1, a.size()), sorted[int(sorted.size() * 0.99)], mx, a.size()]


func _report() -> void:
	for l in slow_log.slice(0, 30):
		print(l)
	var rooms := []
	for n in game.sys.room_names:
		if n != "":
			rooms.append("%s %.0f" % [n, game.sys.P(n)])
	print("state: bodies %d  pieces %d  held %s  rooms kPa %s" % [game.world.bodies.size(), game.world.pieces.size(), game.tools.held_piece != null, ", ".join(rooms)])
	for ph in phase_t:
		print("%-5s %s" % [ph, _stats(phase_t[ph])])
	print("ALL   " + _stats(times))
	var nf := float(times.size())
	print("split per frame: physics %.2f  process %.2f  draw+present %.2f ms" % [split.phys / nf, split.proc / nf, split.draw / nf])
	print("engine per frame: process %.2f ms  physics %.2f ms  render cpu %.2f ms  gpu %.2f ms  draw calls %.0f  primitives %.0f" % [eng.proc / nf, eng.phys / nf, eng.rcpu / nf, eng.rgpu / nf, eng.calls / nf, eng.prims / nf])
	if prof:
		var n := float(times.size())
		var keys: Array = Prof.sum.keys()
		keys.sort_custom(func(a, b): return Prof.sum[a] > Prof.sum[b])
		for k in keys:
			print("  %-28s avg %.3f ms  peak %.2f ms" % [k, Prof.sum[k] / 1000.0 / n, Prof.peak[k] / 1000.0])
	var sorted := times.duplicate()
	sorted.sort()
	var avg := 0.0
	for v in times:
		avg += v
	avg /= maxf(1, times.size())
	var worst := sorted[sorted.size() - 1]
	print("PERF %s  (worst %.1f <= 25, avg %.1f <= 12)" % ["PASS" if worst <= 25.0 and avg <= 12.0 else "FAIL", worst, avg])
