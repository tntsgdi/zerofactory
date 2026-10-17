extends SceneTree
# Developer mode (scripts/dev.gd). The contract builder makes a contract the
# validator passes for every ship type, with the accidents, scope, goal and
# upgrades asked for. A test contract played to its end settles nothing into
# the career and writes no save over the career's contract. On site the F keys
# do what the panel says (make safe, time steps, inspect, x-ray, this contract
# again) and a focused native action card does the same. At the terminal: every upgrade
# and facility, the opening skipped (market open), work plans forgotten, the
# builder's contract onto the first card. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/dev_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_dev_career.json"
	SaveGame.path = "user://zp_test_dev_save.json"
	Txt.cfg_path = "user://zp_test_dev_settings.cfg"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path, Txt.cfg_path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _dev_of(node: Node) -> DevPanel:
	for ch in node.get_children():
		if ch is DevPanel:
			return ch
	return null


func _click(dev: DevPanel, label_key: String) -> bool:
	dev.set_open(true)
	dev.bench.page = 0
	dev.bench.refresh()
	await _frames(3)
	if not dev.bench.buttons.has(label_key):
		return false
	var button: Button = dev.bench.buttons[label_key]
	button.grab_focus()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	root.push_input(ev)
	await _frames(1)
	ev = ev.duplicate()
	ev.pressed = false
	root.push_input(ev)
	await _frames(1)
	dev.set_open(false)
	return true


func _run() -> void:
	Txt.dev = true
	print("DEV: the contract builder on every ship type")
	for sid in DevPanel.SHIPS:
		DevPanel.b_ship = sid
		var allowed: Array = Traps.allowed(Ship.load_data(sid))
		DevPanel.b_traps = allowed.slice(0, 2)
		DevPanel.b_stars = 2
		DevPanel.b_scope = "full"
		DevPanel.b_goal = "safe"
		DevPanel.b_kit = {"arm": 1, "pump2": 1}
		DevPanel.b_seed = 7
		var r := DevPanel.build({"rep": 30, "done": 6})
		var o: Dictionary = r.offer
		check(r.ok and o.ship == sid and str(o.traps) == str(DevPanel.b_traps) and o.goal == "safe" and o.kit.has("arm") and int(o.stars) == 2,
			"%s: %s, %s, ★★, safe, arm + pump (%s)" % [sid, o.get("reg", "?"), str(o.traps), "valid" if r.ok else str(r.reasons)])
	DevPanel.b_ship = "s09"
	DevPanel.b_scope = "section"
	DevPanel.b_traps = ["hidden_tank", "wrong_valve"]
	var rs := DevPanel.build({"rep": 30, "done": 6})
	check(rs.ok and rs.offer.scope == "section" and rs.offer.traps == ["hidden_tank"], "an accident the type has no slot for is left off (%s)" % str(rs.offer.traps))

	print("DEV: a test contract settles nothing into the career")
	Career.data = {}
	Career.start_new()
	var before := JSON.stringify(Career.data)
	DevPanel.b_ship = "tug"
	DevPanel.b_scope = "full"
	DevPanel.b_traps = ["fire_system"]
	DevPanel.b_kit = {}
	var job: Dictionary = DevPanel.build(Career.data).offer.duplicate(true)
	job.dev = true
	job.fee = 0.0
	Game.contract = job
	Game.start_ship = "tug"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	check(g.dev_job() and not g.career() and g.ship_id == "tug" and g.ship.get("variant", {}).get("traps", []) == ["fire_system"], "the tug comes in with its fire system, as a test contract")
	var dev := _dev_of(g)
	check(dev != null and dev.where == "game", "the developer panel is on site")
	# ---- the F keys, by their rows
	DevPanel.time_k = 1.0
	dev.run(5)
	check(DevPanel.time_k == 2.0 and DevPanel.warp_on(), "F5: time ×2")
	for i in 4:
		dev.run(5)
	check(DevPanel.time_k == 1.0 and not DevPanel.warp_on(), "F5 again and again: ×4, ×8, ×¼, back to ×1")
	dev.run(9)
	check(DevPanel.inspect, "F9: the inspect card is on")
	var p = g.world.tag("ENG-T")
	g.aim = g.world.frame(p) * Geom.centroid(p.poly)
	dev.mouse = Vector2(400, 300)
	dev.run(1)
	await _frames(3)
	check(DevPanel.xray and dev.xray_node.visible, "F1: x-ray drawn")
	SaveGame.save(g)
	check(not FileAccess.file_exists(SaveGame.path), "a test contract writes no save over the career's")
	var clicked: bool = await _click(dev, "dev_safe")
	await _frames(2)
	check(clicked and not g.sys.bus_live and g.sys.P("A") < 1.0, "a click on 'make it safe': bus dead, rooms empty")
	dev.run(1)
	dev.run(9)
	var bot = Bot.new(g)
	while not bot.step():
		await process_frame
	await _frames(5)
	check(bot.summary().ended, "the bot takes the tug apart")
	check(g.career_result.is_empty() and JSON.stringify(Career.data) == before, "nothing settled: the career is as it was")
	g.queue_free()
	await _frames(2)

	print("DEV: the terminal")
	Career.data = {}
	Career.start_new()
	Career.data.money = 1000.0
	Career.data.plans = {"tug": [{"do": "w", "ctrl": "K-T", "pre": []}]}
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	var td := _dev_of(term)
	check(td != null and td.where == "terminal", "the developer panel is at the terminal")
	td.run(4)
	var all_up := true
	for kv in DevPanel.KIT:
		all_up = all_up and Career.data.upgrades.has(kv[0])
	check(all_up, "F4: every upgrade and facility")
	td.run(8)
	check(Career.data.market and int(Career.data.done) >= Career.OPENING.size() and Career.active().is_empty() and term.next_job.is_empty() and term.offers().size() == 3, "F8: opening card removed; market open with three offers")
	td.run(9)
	check(Career.data.plans.is_empty(), "F9: the work plans forgotten")
	DevPanel.b_ship = "h22"
	DevPanel.b_traps = ["second_source"]
	DevPanel.b_scope = "full"
	td._to_card()
	check(term.offers()[0].ship == "h22" and term.offers()[0].traps == ["second_source"] and not term.offers()[0].get("dev", false), "the builder's H-22 is on the first card, as a real contract")
	td.set_open(true)
	td.bench.page = 2
	td.bench.refresh()
	await _frames(3)
	check(td.bench.buttons.has("start_sandbox") and td.bench.buttons.has("ship_h22"), "the new contract lab exposes hull cards and a start button")
	term.queue_free()
	await _frames(2)
	Txt.dev = false
	print("DEV %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
