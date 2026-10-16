extends SceneTree
# Frame cost while cutting the roof open, the blowout and a full wide view.
# tools/run_test.sh tests/perf.gd

const M := 48.0
var game
var frame := 0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var acc := {}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _sample(tag: String) -> void:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	if not acc.has(tag + "_gpu"):
		acc[tag + "_gpu"] = [0.0, 0.0, 0, 0.0]
	acc[tag + "_gpu"][0] += gpu
	acc[tag + "_gpu"][1] += cpu
	acc[tag + "_gpu"][2] += 1
	acc[tag + "_gpu"][3] = maxf(acc[tag + "_gpu"][3], gpu)
	var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if not acc.has(tag):
		acc[tag] = [0.0, 0.0, 0, 0.0]
	acc[tag][0] += p
	acc[tag][1] += ph
	acc[tag][2] += 1
	acc[tag][3] = maxf(acc[tag][3], p + ph)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 3:
		game.drone.global_position = Vector2(8.9, -6.0) * M
		game.drone.linear_velocity = Vector2.ZERO
		game.drone.spawn_t = 5.0
		game.tools.set_tool(2)
		bot.aim = Vector2(8.2, -4.5) * M
	if frame == 10:
		bot.lmb = true
	if frame > 10 and frame < 120:
		var t0 := Time.get_ticks_usec()
		var k := (frame - 10) / 110.0
		bot.aim = (Vector2(8.2, -4.5).lerp(Vector2(8.2, -3.0), clampf(k * 2.0, 0, 1)) if k < 0.5 else Vector2(9.55, -3.0).lerp(Vector2(9.55, -4.5), clampf(k * 2.0 - 1.0, 0, 1))) * M
		_sample("cutting")
		if frame == 20:
			World.acc_sum = {}
			World.acc_n = {}
		if frame == 119:
			var out := []
			for kk in World.acc_sum:
				out.append("%s %.2f" % [kk, World.acc_sum[kk] / 1000.0 / 99.0])
			print("per-frame ms during cutting: ", ", ".join(out))
			World.acc_sum = {}
			World.acc_n = {}
	if frame == 60:
		print("dbg cutting=", game.tools.cutting, " front=", game.tools.front / M, " aim=", bot.aim / M, " drone=", game.drone.global_position / M, " pend=", game.tools.pending.size(), " state=", game.state, " lmb=", game.tools.lmb)
	if frame == 120:
		bot.lmb = false
	if frame > 120 and frame < 220:
		_sample("blowout")
		if frame == 219:
			var out2 := []
			for kk in World.acc_sum:
				out2.append("%s %.2f" % [kk, World.acc_sum[kk] / 1000.0 / 99.0])
			print("per-frame ms during blowout: ", ", ".join(out2))
	if frame == 230:
		game.cam_override = Vector2(21, 0) * M
		game.zoom_override = 0.6
		for n in game.world.rooms:
			game.world.reveal(n, game.world.rooms[n].from)
	if frame > 260 and frame < 330:
		_sample("wide")
	if frame == 330:
		for k in acc:
			var a: Array = acc[k]
			pass
		print("prof ", World.prof, "  bodies ", game.world.bodies.size(), "  pieces ", game.world.pieces.size())
		for k in acc:
			var a: Array = acc[k]
			print("%-8s process %.2f ms  physics %.2f ms  worst %.1f ms  fps %d" % [k, a[0] / a[2], a[1] / a[2], a[3], Engine.get_frames_per_second()])
		return true
	return false
