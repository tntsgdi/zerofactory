extends SceneTree
# Roadmap 1.8 acceptance: the apprentice assessment. Each of the four problems
# is solved twice — the right way (the ship file's safe procedure, through the
# game's own actions: grade A, nothing to review) and the wrong way (the
# mistake that problem is about: not A, and the first review row names the
# check that was skipped). One more right-way run after pressing Q: B at best.
# tools/run_test.sh tests/exam_bot.gd --fixed-fps 60 [-- shots]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
const EXPECT := {"e07a": "pressure", "e07b": "power", "e07c": "tied_lines", "e07d": "tied_hidden"}
var game
var bot := {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var shots := false
var fails := 0
var finished := false


func _initialize() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	Txt.test_zh = not "en" in OS.get_cmdline_user_args()
	SaveGame.path = "user://zp_exam_test_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1


func _spawn(id: String) -> void:
	if game != null:
		game.queue_free()
		await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = id
	root.add_child(scene)
	game = scene
	Engine.time_scale = 1.0
	await _frames(5)
	# the drone is out and steady
	game.drone.spawn_t = 2.0


func _ctrl(id: String) -> Dictionary:
	var c = game.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": game.world.ctrl_world(c)}


func _cond(until: Dictionary) -> bool:
	var s = game.sys
	for k in until:
		var a: Array = until[k]
		match k:
			"P":
				if not (s.P(a[0]) < a[2]):
					return false
			"charge":
				if not (s.charge(a[0]) < a[2]):
					return false
			"open":
				if game.world.room_hidden(a[0]):
					return false
	return true


# undo every fixing and line, the way the wrench would
func _free(tag: String) -> void:
	var w = game.world
	var p = w.tag(tag)
	for i in 20:
		if p == null or p.gone or p.body != null:
			return
		for j in w.joints_of(p):
			if j.type in ["bolt", "lock", "clamp"]:
				game.do_wrench({"kind": "joint", "joint": j, "pos": w.joint_world(j)})
				break
		for l in w.lines_of(p):
			var end := 0 if l.a == p.id else 1
			game.do_wrench({"kind": "connector", "line": l, "end": end, "pos": w.line_end_world(l, end)})
			break
		await _frames(2)


func _deliver(tag: String, zone: String) -> void:
	var p = game.world.tag(tag)
	if p == null or p.gone or p.body == null:
		return
	game.tools.release_grab(false)
	bot.lmb = false
	var b = p.body
	var mouth: Vector2 = Dock.zpos(zone)
	b.global_position = mouth - b.global_transform.basis_xform(b.center_of_mass)
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0
	b.reset_physics_interpolation()
	for i in 360:
		if p.gone:
			break
		await process_frame


func _procedure() -> void:
	for st in game.ship.procedures["E-07"]:
		match st.do:
			"measure":
				game.do_measure(_ctrl(st.ctrl))
			"operate":
				game.do_wrench(_ctrl(st.ctrl))
			"hose":
				game.do_hose(_ctrl(st.ctrl))
			"wait":
				Engine.time_scale = 4.0
				for i in int(float(st.get("max", 60.0)) * 60.0 / 4.0):
					if _cond(st.until):
						break
					await process_frame
				Engine.time_scale = 1.0
			"free":
				await _free(st.piece)
			"deliver":
				await _deliver(st.piece, st.zone)
		await _frames(3)


# the grapple on something still attached, pulled away until it gives
func _yank(tag: String) -> void:
	var w = game.world
	var p = w.tag(tag)
	var c: Vector2 = w.frame(p) * Geom.centroid(p.poly)
	game.tools.set_tool(3, true)
	game.drone.global_position = c + Vector2(0, -2.2) * M
	game.drone.linear_velocity = Vector2.ZERO
	game.drone.reset_physics_interpolation()
	bot.aim = c + Vector2(0, -6.0) * M
	bot.lmb = true
	await _frames(2)
	game.tools.held_piece = p
	game.tools.held_body = p.body
	game.tools.held_local = Geom.centroid(p.poly)
	for i in 240:
		if p.body != null:
			break
		await process_frame
	await _frames(10)


func _wrong(id: String) -> void:
	var w = game.world
	match id:
		"e07a":
			# open the bay lid without measuring
			await _free("EX-LID")
			await _frames(90)
			await _free("E-07")
		"e07b":
			# unplug E-07 while its own battery still feeds it
			var l = w.lines["c-e"]
			var end := 0 if l.a == w.tag("E-07").id else 1
			game.do_wrench({"kind": "connector", "line": l, "end": end, "pos": w.line_end_world(l, end)})
			await _frames(10)
			await _free("E-07")
		"e07c":
			# the floor bolts, then pull with the pipe and cable still on
			for j in w.joints_of(w.tag("E-07")):
				game.do_wrench({"kind": "joint", "joint": j, "pos": w.joint_world(j)})
			await _frames(4)
			await _yank("E-07")
		"e07d":
			# the bolts it shows, then pull: the latch behind the panel holds
			for j in w.joints_of(w.tag("E-07")):
				if not w.joint_covered(j):
					game.do_wrench({"kind": "joint", "joint": j, "pos": w.joint_world(j)})
			await _frames(4)
			await _yank("E-07")
	await _deliver("E-07", "equip")


func _shot(name: String) -> void:
	if shots:
		await _frames(80)
		Cap.save(root, "res://tests/out/exam_%s%s.png" % [name, "" if Txt.zh else "_en"])


func _run() -> void:
	# the title's "exam" draws one of the four
	var drawn := {}
	for i in 40:
		drawn[Exam.pick()] = true
	_check(drawn.size() == 4, "all four problems can be drawn (%d)" % drawn.size())
	for id in EXPECT:
		# right
		await _spawn(id)
		_check(game.exam != null and game.assist == null and game.story == null, "%s: assessment mode (no contract hints, no story)" % id)
		await _procedure()
		var r: Dictionary = game.exam.result
		_check(not r.is_empty() and r.grade == "A" and r.review.is_empty(), "%s right way: %s, review %s" % [id, r.get("grade", "unfinished"), str(r.get("review", []).map(func(x): return x.step))])
		if id == "e07a":
			await _shot("a_right")
		# wrong
		await _spawn(id)
		await _wrong(id)
		r = game.exam.result
		var first: String = r.review[0].step if not r.is_empty() and not r.review.is_empty() else "none"
		_check(not r.is_empty() and r.grade != "A" and first == EXPECT[id], "%s wrong way: %s, review points at %s (want %s)  %s" % [id, r.get("grade", "unfinished"), first, EXPECT[id], str(game.incidents)])
		if id == "e07d":
			await _shot("d_wrong")
	# a hint costs the A
	await _spawn("e07c")
	game.exam.request_hint()
	await _procedure()
	var rh: Dictionary = game.exam.result
	_check(not rh.is_empty() and rh.grade == "B" and rh.review.any(func(x): return x.step == "hint"), "a hint caps the grade at B (%s)" % rh.get("grade", "unfinished"))
	# giving up: no grade, the review still there, retake or contract offered
	await _spawn("e07a")
	game.exam.abandon()
	_check(game.exam.result.grade == "" and game.state == "ending", "abandoning ends it without a grade")
	print("EXAM %s  (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
