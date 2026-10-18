extends SceneTree
# Integration checks use dedicated files, never the player's career/contract.
var fails := 0
var done := false
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}

func _initialize() -> void:
	_run()

func _process(_dt: float) -> bool:
	return done

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		fails += 1

func frames(n: int = 3) -> void:
	for i in n:
		await process_frame

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await frames(1)

func _run() -> void:
	Career.path = "user://zp_test_skillbook_career.json"
	SaveGame.path = "user://zp_test_skillbook_save.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 10000000.0
	Career.data.rep = 30
	Career.data.done = 10
	Career.save()
	check(Growth.TRACKS.size() == 17 and Growth.progress() == 0, "17 routes / 51 volumes; stock equipment is level zero")
	var funds := float(Career.data.money)
	for row in Growth.TRACKS:
		for tier in range(1, 4):
			var cost := Growth.price(row[0])
			check(Growth.buy(row[0]) == "" and Growth.level(Career.data.upgrades, row[0]) == tier, "%s level %d purchased" % [row[0], tier])
			funds -= cost
	check(is_equal_approx(funds, float(Career.data.money)) and funds >= 0.0, "exact incremental prices charged once")
	var snapshot := Career.data.duplicate(true)
	check(Growth.buy("drive") != "" and Career.data == snapshot, "mastered route refuses further charge")
	check(Growth.set_goal("drive"), "savings goal is persisted through the career writer")
	Career.data = {}
	Career.load_or_new()
	check(Growth.progress() == 51 and Career.data.growth_goal == "drive", "all 51 levels and savings goal survive career disk roundtrip")
	Career.data = Career.fresh()
	Career.data.upgrades = {"scan_kit": 1, "grapple5": 1, "pump2": 1}
	check(Growth.progress() == 3 and Growth.price("grapple_mass") == 97500.0, "old purchases credited as volume I; next price is volume II")
	Career.data = Career.fresh()
	Career.data.money = 500000.0
	check(Growth.buy("drive") == "", "first volume available without reputation grind")
	snapshot = Career.data.duplicate(true)
	check(Growth.buy("drive") != "" and Career.data == snapshot, "volume II blocked without completed jobs and reputation")
	Career.data.money = 0.0
	snapshot = Career.data.duplicate(true)
	check(Growth.buy("armor") != "" and Career.data == snapshot, "insufficient funds leaves all career state intact")
	Career.data.money = 500000.0
	var good_path := Career.path
	Career.path = "user://missing_skillbook_directory/career.json"
	snapshot = Career.data.duplicate(true)
	var live_job: Dictionary = Career.active()
	check(Growth.buy("armor") != "" and Career.data == snapshot and live_job == snapshot.active, "failed disk write rolls back funds, level and aliased live job")
	Career.path = good_path
	Career.data = Career.fresh()
	Career.data.money = 10000000.0
	Career.data.done = 10
	Career.data.rep = 30
	Career.sign_active()
	Game.contract = Career.active().duplicate(true)
	Game.start_ship = "tug"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(5)
	g.open_console("shop")
	await frames()
	var term = g.console_ui
	term.set_tab(3)
	await frames()
	check(term.book.visible and paused, "onsite field manual accessible while simulation is paused")
	term.book.selected = "grapple_mass"
	term.book.refresh_detail()
	await frames()
	var purchase_button: Button = term.book.detail.get_children().filter(func(node): return node is Button)[0]
	purchase_button.grab_focus()
	await press_key(KEY_ENTER)
	check(g.grab_max() == 5.0 and g.has_upgrade("grapple5"), "Enter on focused purchase button fits 5 t grapple on current contract immediately")
	await press_key(KEY_ESCAPE)
	await frames()
	check(not paused and g.console_ui == null, "closing manual resumes same dismantling session")
	for row in Growth.TRACKS:
		while Growth.level(Career.data.upgrades, row[0]) < 3:
			Growth.buy(row[0])
	g.fit_skills()
	check(g.grab_max() == 8.0 and g.tools.reach(3) == 9.0 * Geom.M and g.skill_value("haul_speed") == 1.9, "expert grapple has 8 t capacity, 9 m reach and 1.9x haul")
	check(g.tools.reach(1) == 12.0 * Geom.M and g.tools.reach(5) == 9.0 * Geom.M, "meter and hose reach used by actual tool targeting")
	check(g.sys.pump_k() == 3.6, "gas and liquid pump code uses expert throughput")
	g.tools.tool = 4
	g.tools.hover = {"kind": "connector", "pos": g.drone.global_position}
	g.tools._start_job()
	check(is_equal_approx(g.tools.job.dur, 0.4 / 2.2), "real connector job uses quick service duration")
	g.tools.tool = 1
	g.tools._start_job()
	check(is_equal_approx(g.tools.job.dur, 0.12), "real measurement job uses expert probe time")
	g.tools.job = {}
	var cut_losses := []
	for radius in [3.4, g.skill_value("laser_kerf")]:
		var w := World.new()
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 100), Vector2(0, 100)])
		var p = w.add_piece("hull", poly, {})
		w.commit_cut(p, PackedVector2Array([Vector2(100, -10), Vector2(100, 110)]), radius)
		var left := 0.0
		for id in w.pieces:
			left += Geom.area(w.pieces[id].poly)
		cut_losses.append(20000.0 - left)
		w.free()
	check(cut_losses[1] < cut_losses[0] * 0.5, "expert kerf physically removes less than half the metal on same cut")
	var plate = null
	for id in g.world.pieces:
		var p = g.world.pieces[id]
		if p.kind == "hull" and not p.gone:
			plate = p
			break
	if plate != null:
		var at: Vector2 = g.world.frame(plate) * Geom.centroid(plate.poly)
		var speed: Array = g.tools._speed_at(at)
		var kit: Dictionary = g.job.kit.duplicate()
		g.job.kit = {}
		var stock: Array = g.tools._speed_at(at)
		g.job.kit = kit
		check(is_equal_approx(speed[0], stock[0] * 2.0), "actual laser material speed doubles")
	g.drone.alive = true
	g.drone.spawn_t = 5.0
	g.drone.integrity = 100.0
	g.hurt_drone(40.0, Vector2.ZERO, "arc_hit")
	check(is_equal_approx(g.drone.integrity, 92.8), "armour and arc shield combine on real incoming damage: 40 -> 7.2")
	g.drone.integrity = 100.0
	g.hurt_drone(40.0, Vector2.ZERO, "fire_hit")
	check(is_equal_approx(g.drone.integrity, 91.6), "thermal insulation reduces real fire damage: 40 -> 8.4")
	g.drone.integrity = 10.0
	g.job.items = {"repair": 1}
	g.state = "play"
	g.repair_kit()
	check(g.drone.integrity == 100.0 and g.used.get("repair", 0) == 1, "expert repair consumes one kit and restores up to 100 integrity")
	var speeds := []
	var fitted: Dictionary = g.job.kit.duplicate()
	for tier in [0, 3]:
		g.job.kit.skill_drive = tier
		g.drone.global_position = Vector2(600, -900)
		g.drone.linear_velocity = Vector2.ZERO
		g.bot.move = Vector2.RIGHT
		await frames(15)
		speeds.append(g.drone.linear_velocity.length())
	g.job.kit = fitted
	g.bot.move = Vector2.ZERO
	check(speeds[1] > speeds[0] * 1.3, "actual physics flight accelerates faster with expert propulsion")
	SaveGame.save(g)
	var saved := SaveGame.read(SaveGame.path)
	check(Growth.level(saved.get("job", {}).get("kit", {}), "drive") == 3, "contract save contains fitted levels")
	g.queue_free()
	await frames()
	# A stale contract save cannot undo books already persisted in the career.
	saved.job.kit = {}
	SaveGame.write_file(SaveGame.path, saved)
	Game.contract = Career.active().duplicate(true)
	Game.start_ship = "tug"
	SaveGame.load_requested = true
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(5)
	check(g.grab_max() == 8.0 and g.skill_value("drive") == 1.5, "resume reconciles stale contract kit with same career's purchased volumes")
	g.queue_free()
	await frames()
	print("SKILLBOOK %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done = true
	quit(0 if fails == 0 else 1)
