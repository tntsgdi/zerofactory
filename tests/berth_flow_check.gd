extends SceneTree
# Between contracts in the berth (player 2026-10-18: "after a job, don't go back
# to the menu, go back into the berth"). Checks: a settled contract's ship is
# towed out on the tug (pulling: the tug's burns point the right way), the
# empty berth takes over with the drone where it was; its computer opens the
# terminal with every app usable and Esc closes it back to the berth; a
# contract taken there brings the next ship in; a career with nothing signed
# starts in the empty berth. Stills: berth_empty.png, berth_term.png,
# berth_towout.png. Test career only.
# tools/run_test.sh tests/berth_flow_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_berthflow_career.json"
	SaveGame.path = "user://zp_test_berthflow_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scene() -> Node:
	return current_scene


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.certified = true
	Career.data.money = 41250.0
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.save()
	Career.ensure_offers(Market.make)
	var offer: Dictionary = Career.data.offers[0]
	# ---------------------------------------------------------------- a contract ends
	Career.data.active = offer
	Career.save()
	Game.contract = offer
	Game.start_ship = Game.contract.get("ship", "gr7")
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	await _frames(30)
	g.drone.global_position = Vector2(14.0, -6.0) * 48.0
	g.drone.reset_physics_interpolation()
	g.finish_contract(true)
	await _frames(20)
	g.leave()
	check(g.state == "towout", "after the settlement the ship is towed out (state %s)" % g.state)
	await _frames(60)
	var ax: float = g.dock.tug_accel()
	check(ax > 0.0 and g.world.position.x > 0.0, "the tug pulls it away, speeding up (%.0f px/s², hull at %.0f px)" % [ax, g.world.position.x])
	Cap.save(root, "res://tests/out/berth_towout.png")
	var before: Vector2 = g.drone.global_position
	var t := 0
	while (_scene() == g or Wipe.busy()) and t < 600:
		await process_frame
		t += 1
	await _frames(30)
	var b: Node = _scene()
	check(b != g and b.in_berth(), "then the empty berth takes over")
	check(b.state == "play" and b.drone.alive and b.world.pieces.is_empty(), "nothing in it, the drone flying (state %s)" % b.state)
	check(b.drone.global_position.distance_to(before) < 80.0, "the drone carries on from where it was (%.0f px)" % b.drone.global_position.distance_to(before))
	check(b.consoles != null and b.career(), "the berth's computer is there")
	await _frames(30)
	Cap.save(root, "res://tests/out/berth_empty.png")
	# ---------------------------------------------------------------- its computer
	b.open_console("terminal")
	await _frames(20)
	var term = b.console_ui
	check(term != null and term.between and not term._locked(0) and not term._locked(1) and not term._locked(7), "the terminal opens with every app usable")
	term.set_tab(0)
	await _frames(30)
	check(term.tab == 0, "the contracts page opens between jobs")
	Cap.save(root, "res://tests/out/berth_term.png")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_ESCAPE
	term._unhandled_input(ev)
	term._unhandled_input(ev)
	await _frames(5)
	check(b.console_ui == null and not paused, "Esc goes home, then back to the berth (unpaused)")
	# ---------------------------------------------------------------- taking one there
	b.open_console("terminal")
	await _frames(20)
	term = b.console_ui
	term.set_tab(0)
	await _frames(20)
	var want: String = str(term.offers()[0].get("id", ""))
	term.take(0)
	t = 0
	while (_scene() == b or Wipe.busy()) and t < 600:
		await process_frame
		t += 1
	await _frames(10)
	var n: Node = _scene()
	check(n != b and not n.in_berth() and str(n.job.get("id", "")) == want and n.state == "intro" and not paused, "a contract taken there brings its ship in (%s, %s)" % [n.job.get("id", ""), n.state])
	# ---------------------------------------------------------------- the career's way in
	n.queue_free()
	await _frames(4)
	Career.data.active = {}
	Career.save()
	Game.play_career(self)
	await _frames(20)
	check(_scene() != null and _scene().has_method("in_berth") and _scene().in_berth(), "a career with nothing signed starts in the empty berth")
	print("BERTH_FLOW %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
