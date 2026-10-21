extends SceneTree
# The survey pass after a contract is signed (2026-10-20): the camera flies the
# hull bow to stern, pulls back until the whole ship is in view and measures it,
# then hands the view back to the drone. A type's second contract gets the short
# look; any key skips it. Stills per ship: survey_<id>_pass.png, _hold.png.
# Test saves only.
# tools/run_test.sh tests/survey_shot.gd -- [ship ids...]   (default gr7 cv138 ark01)

const Cap = preload("res://tests/cap.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	Career.path = "user://zp_test_survey_career.json"
	SaveGame.path = "user://zp_test_survey_save.json"
	Game.cine_in_tests = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if a != "en":
			ids.append(a)
	if ids.is_empty():
		ids = ["gr7", "cv138", "ark01"]
	for id in ids:
		Game.contract = {}
		Game.start_ship = id
		var g: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
		current_scene = g
		await _frames(20)
		# a tall ship: the berth grows for it first
		if g.state == "build":
			g._end_build()
		g._end_intro()
		await _frames(5)
		check(g.contract_open, "%s: the contract card is up" % id)
		g.close_contract()
		check(g.state == "survey" and g.survey.full, "%s: signing it starts the full survey" % id)
		var sv: Dictionary = g.survey
		var shot_pass := false
		var shot_hold := false
		var n := 0
		while g.state == "survey" and n < 2400:
			await process_frame
			n += 1
			var ph: Array = g.survey_phase()
			if not shot_pass and ph[0] == "pass" and ph[1] > 0.45:
				shot_pass = true
				Cap.save(root, "res://tests/out/survey_%s_pass.png" % id)
			if not shot_hold and ph[0] == "hold" and ph[1] > 0.7:
				shot_hold = true
				# the whole hull on screen
				var xf: Transform2D = g.get_viewport().get_canvas_transform()
				var vs: Vector2 = g.get_viewport().get_visible_rect().size
				var a: Vector2 = xf * Vector2(sv.x0, sv.y0)
				var b: Vector2 = xf * Vector2(sv.x1, sv.y1)
				check(a.x > 0.0 and a.y > 70.0 and b.x < vs.x and b.y < vs.y - 70.0, "%s: the whole ship in view at the hold (%.0f,%.0f)-(%.0f,%.0f)" % [id, a.x, a.y, b.x, b.y])
				Cap.save(root, "res://tests/out/survey_%s_hold.png" % id)
		check(shot_pass and shot_hold, "%s: the pass and the measured hold were seen" % id)
		check(g.state == "play" and g.cam_override == null, "%s: back to the drone after %.1f s" % [id, sv.t_end])
		# the second contract of the type: the short look, and a key skips it
		g._start_survey()
		check(g.state == "survey" and not g.survey.full, "%s: second time the short look" % id)
		await _frames(30)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		ev.pressed = true
		Input.parse_input_event(ev)
		await _frames(3)
		check(g.state == "play", "%s: a key skips it" % id)
		g.queue_free()
		await _frames(5)
	print("survey_shot: %d failures" % fails)
	quit(1 if fails > 0 else 0)
