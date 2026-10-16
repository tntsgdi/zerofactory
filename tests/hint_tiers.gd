extends SceneTree
# Roadmap 1.6 acceptance. The same hands on GR-7 three times — guided,
# standard, hardcore. Each run walks into every known danger once (an
# unverified pressurised wall, a live generator, a full pipe, a hot pipe,
# hauling something still bolted, a fuel tank near the furnace, the laser in
# a propellant cloud, the first gas port) and reads a dead-leg gauge and a
# live test point. Pass: hardcore says nothing at all; guided has a hint for
# every danger; standard only names unresolved systems; the ship, readings
# and books end up the same in all three.
# tools/run_test.sh tests/hint_tiers.gd --fixed-fps 60

const Snap = preload("res://tests/snap_util.gd")
const M := 48.0
const DANGERS := ["p", "volts", "full", "hot", "tied", "haz", "cloud"]
var game
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var tiers := ["guided", "standard", "hardcore"]
var results := {}
var snaps := {}
var finished := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _spawn() -> void:
	if game != null:
		game.queue_free()
		await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	seed(5)


func _ctrl(id: String) -> Dictionary:
	var c = game.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": game.world.ctrl_world(c)}


# park the drone near a point, aim at something, hold it a moment
func _point(at: Vector2, tool: int, frames: int = 30, lmb: bool = false) -> void:
	game.tools.set_tool(tool)
	game.drone.global_position = at + Vector2(-1.5, -1.8) * M
	game.drone.linear_velocity = Vector2.ZERO
	game.drone.reset_physics_interpolation()
	bot.aim = at
	bot.lmb = lmb
	await _frames(frames)
	bot.lmb = false
	await _frames(4)


func _run() -> void:
	for tr in tiers:
		Txt.hint_tier = tr
		await _spawn()
		await _frames(5)
		var w = game.world
		var s = game.sys
		# a dead-leg gauge and a live test point
		game.do_measure(_ctrl("P-C01"))
		game.do_measure(_ctrl("E-D01"))
		# the first gas port
		await _point(w.ctrl_world(w.ctrls["GAS-AB"]), 1)
		# the laser on the roof of the cargo hold (108 kPa, never measured)
		await _point(Vector2(19.6, -3.8) * M, 2)
		# a wrench on the generator while it runs (room D opened for the test)
		w.reveal("D", w.rooms["D"].from)
		await _frames(30)
		var gen = w.tag("G-01")
		var bolt = null
		for j in w.joints_of(gen):
			if j.type == "bolt":
				bolt = j
		await _point(w.joint_world(bolt), 4)
		# a full coolant pipe, then the same pipe hot but drained
		var q1 = w.lines["q1"]
		await _point(w.line_end_world(q1, 0), 4)
		var q3 = w.lines["q3"]
		s.set_fluid("cool", 0.0)
		s.set_fluid("cool_broken", 0.0)
		await _point(w.line_end_world(q3, 0), 4)
		# hauling the control panel while it is still bolted on
		var panel = w.tag("CTRL-D")
		await _point(w.frame(panel) * Geom.centroid(panel.poly), 3, 10)
		bot.aim = w.frame(panel) * Geom.centroid(panel.poly)
		bot.lmb = true
		await _frames(4)
		bot.aim = game.drone.global_position + Vector2(0, -3.0) * M
		await _frames(70)
		bot.lmb = false
		await _frames(6)
		# the propellant tank, freed, held next to the furnace
		var tank = w.tag("T-F01")
		for j in w.joints_of(tank):
			w.kill_joint(j)
		for l in w.lines_of(tank):
			w.kill_line(l)
		await _frames(6)
		var b = tank.body
		var fpos: Vector2 = Dock.zpos("metal") + Vector2(0, -3.5) * M
		b.global_position = fpos
		b.linear_velocity = Vector2.ZERO
		b.reset_physics_interpolation()
		game.tools.set_tool(3)
		game.drone.global_position = fpos + Vector2(-2.0, -1.0) * M
		game.drone.linear_velocity = Vector2.ZERO
		# hold it the way a grab does (the hover rules are tested elsewhere)
		bot.aim = b.global_transform * b.center_of_mass
		bot.lmb = true
		for i in 20:
			game.tools.held_piece = tank
			game.tools.held_body = b
			game.tools.held_local = Geom.centroid(tank.poly)
			b.global_position = fpos
			b.linear_velocity = Vector2.ZERO
			await process_frame
		bot.lmb = false
		await _frames(4)
		b.global_position = fpos + Vector2(6.0, -4.0) * M
		b.linear_velocity = Vector2.ZERO
		# the laser into a propellant cloud
		var cpos := Vector2(36.0, -6.5) * M
		s.clouds.append({"pos": cpos, "r": 1.2 * M, "amount": 0.02, "t": 0.0})
		await _point(cpos + Vector2(0.0, 3.2) * M, 2, 12, true)
		s.clouds = []
		await _frames(10)
		var kinds := {}
		for h in game.assist.history:
			var k: String = h[3].split(":")[0]
			kinds[k] = kinds.get(k, 0) + 1
		var recalls: int = game.assist.history.filter(func(h): return h[2] == "recall").size()
		results[tr] = {"warn": kinds, "recall": recalls, "hints": game.hint_log.size(), "lines": game.assist.history.size()}
		var sn: Dictionary = Snap.snap(game)
		snaps[tr] = sn
		print("%-9s warnings %s  recall cards %d  one-off hints %d" % [tr, kinds, recalls, game.hint_log.size()])
	_report()
	finished = true


func _report() -> void:
	var ok := true
	var g: Dictionary = results.guided
	var st: Dictionary = results.standard
	var hc: Dictionary = results.hardcore
	var missing := []
	for d in DANGERS:
		if not g.warn.has(d):
			missing.append(d)
	if not missing.is_empty():
		print("  guided misses: %s" % ", ".join(missing))
		ok = false
	if not g.warn.has("port"):
		print("  guided never said what the first port reads")
		ok = false
	if st.warn.has("port"):
		print("  standard explained a port (it should only name what is unresolved)")
		ok = false
	if hc.lines != 0 or hc.hints != 0:
		print("  hardcore said something: %d lines, %d hints" % [hc.lines, hc.hints])
		ok = false
	var same_sg: Array = Snap.diff(snaps.guided, snaps.standard)
	var same_gh: Array = Snap.diff(snaps.guided, snaps.hardcore)
	if not same_sg.is_empty() or not same_gh.is_empty():
		print("  the tiers changed the ship: %s" % str((same_sg + same_gh).slice(0, 4)))
		ok = false
	print("TIERS %s  (guided %d dangers named, standard %d systems named, hardcore %d)" % ["PASS" if ok else "FAIL", g.warn.size(), st.warn.size(), hc.lines + hc.hints])
