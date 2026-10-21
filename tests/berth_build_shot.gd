extends SceneTree
# A berth extension built on site (2026-10-20): bought at the terminal over the
# empty berth, it is built when the terminal closes: work zone, cassettes, the
# truss deploying bay by bay, latches and bolts, EB welds, proof pressure and
# load, then the berth re-laid with the mouths rolled out. Checks the berth ends
# up exactly as a fresh load at the new length would lay it, that it is shown
# once, and that a key skips the 200 → 620 m one straight to the end.
# Stills: build_deploy.png, build_weld.png, build_test.png, build_cert.png.
# Test career and saves only.
# tools/run_test.sh tests/berth_build_shot.gd --fixed-fps 60 -- [en]

const Cap = preload("res://tests/cap.gd")
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	Career.path = "user://zp_test_build_career.json"
	SaveGame.path = "user://zp_test_build_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	Game.cine_in_tests = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _berth() -> Node:
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	return g


func _run() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 6
	Career.data.certified = true
	Career.data.money = 2000000.0
	Career.data.seen = {"market": true, "bought": true}
	Career.save()
	var g := _berth()
	await _frames(20)
	check(g.state == "play" and g.build == null, "a berth with nothing new bought just comes up")
	# bought at the terminal over the berth
	var term = load("res://scenes/terminal.tscn").instantiate()
	term.overlay = true
	term.between = true
	root.add_child(term)
	await _frames(2)
	term.buy(["berth88", "facility", 240000.0, "fa_berth", "fa_berth_d", true])
	term.queue_free()
	check(float(Career.data.get("berth_seen", 0.0)) == 50.0 and Career.data.upgrades.has("berth88"), "the purchase remembers the berth was 50 m")
	g._maybe_build()
	check(g.state == "build" and is_equal_approx(Dock.FLOOR_X1, 50.0), "the build starts on the 50 m berth")
	var shots := {"deploy": 0.5, "weld": 0.55, "test": 0.7, "cert": 0.8}
	var taken := {}
	var n := 0
	while g.state == "build" and n < 3000:
		await process_frame
		n += 1
		var b = g.build
		if b == null:
			break
		var key: String = b.steps[b.current()][0]
		if shots.has(key) and not taken.has(key) and b.k(b.current()) >= shots[key]:
			taken[key] = true
			Cap.save(root, "res://tests/out/build_%s.png" % key)
	check(taken.size() == 4, "every stage was seen: %s" % [taken.keys()])
	check(g.state == "play" and g.cam_override == null, "back to the drone after the build")
	check(is_equal_approx(Dock.FLOOR_X1, 88.0), "the berth is 88 m (%.1f)" % Dock.FLOOR_X1)
	var hz: Vector2 = Dock.ZONES.hazard.pos
	var mx: float = Dock.metal_x
	check(float(Career.data.berth_seen) == 88.0, "shown once: the career remembers 88 m")
	# the same berth loaded fresh lays out the same
	g.queue_free()
	await _frames(3)
	var g2 := _berth()
	await _frames(20)
	check(g2.state == "play" and g2.build == null, "loaded again: no second build")
	check(Dock.ZONES.hazard.pos.distance_to(hz) < 0.01 and absf(Dock.metal_x - mx) < 0.01, "the mouths stand where a fresh 88 m berth puts them")
	# three more tiers at once, skipped with a key
	Career.data.upgrades["berth120"] = 1
	Career.data.upgrades["berth200"] = 1
	Career.data.upgrades["berth620"] = 1
	g2._maybe_build()
	check(g2.state == "build" and is_equal_approx(g2.build.x_a, 88.0) and is_equal_approx(g2.build.x_b, 620.0), "88 → 620 m in one build")
	await _frames(240)
	Cap.save(root, "res://tests/out/build_long_deploy.png")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(5)
	check(g2.state == "play" and is_equal_approx(Dock.FLOOR_X1, 620.0), "a key skips to the 620 m berth (%.0f)" % Dock.FLOOR_X1)
	check(absf(Dock.ZONES.hazard.pos.x - (43.6 + 570.0)) < 0.01, "the hazard bay is at the far end (%.1f)" % Dock.ZONES.hazard.pos.x)
	g2.queue_free()
	await _frames(3)
	# bought somewhere else, a contract signed after it: built before the tug brings the ship in
	Career.data.upgrades = {"berth88": 1}
	Career.data["berth_seen"] = 50.0
	Career.ensure_offers(Market.make)
	var offer: Dictionary = Career.data.offers[0].duplicate(true)
	offer.ship = "gr7"
	offer.kit = Career.data.upgrades.duplicate()
	Career.data.active = offer
	Game.contract = offer
	Game.start_ship = "gr7"
	SaveGame.load_requested = false
	var g3: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g3)
	current_scene = g3
	await _frames(10)
	check(g3.state == "build" and not g3.world.visible, "a contract's start: the build first, the ship kept out of sight")
	g3._end_build()
	await _frames(3)
	check(g3.state == "intro" and g3.world.visible and is_equal_approx(Dock.FLOOR_X1, 88.0), "then the tug brings the ship into the 88 m berth")
	g3.queue_free()
	await _frames(3)
	# a solar sail into the long low berth: the boom jacked up, the platform drawn down
	Career.data = Career.fresh()
	Game.contract = {}
	for pass_n in 2:
		Game.start_ship = "sa200"
		var g4: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(g4)
		current_scene = g4
		await _frames(10)
		var b4 = g4.build
		check(g4.state == "build" and b4 != null and b4.idx("lift") >= 0 and b4.idx("drop") >= 0, "SA-200 (pass %d): the berth grows up and down for it" % pass_n)
		if b4 == null:
			break
		check(b4.quick == (pass_n == 1), "pass %d: %s" % [pass_n, "the second time runs fast" if pass_n == 1 else "the first time in full"])
		var seen := {}
		var n2 := 0
		while g4.state == "build" and n2 < 3000:
			await process_frame
			n2 += 1
			if g4.build == null:
				break
			var kn: String = g4.build.key()
			if pass_n == 0 and kn in ["iso", "lift", "drop"] and not seen.has(kn) and g4.build.kk(kn) > 0.55:
				seen[kn] = true
				check(Dock.LIFT >= g4.build.lift_a - 0.01 and Dock.LIFT <= g4.build.lift_b + 0.01, "%s: boom lift %.1f m on its way" % [kn, Dock.LIFT])
				Cap.save(root, "res://tests/out/build_sail_%s.png" % kn)
		check(g4.state == "intro" and Dock.LIFT > 50.0 and Dock.DROP > 50.0, "then the sail comes into a berth %.0f m up, %.0f m down" % [Dock.LIFT, Dock.DROP])
		g4.queue_free()
		await _frames(3)
		Dock.configure(88.0)
	print("berth_build_shot: %d failures" % fails)
	quit(1 if fails > 0 else 0)
