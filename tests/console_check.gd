extends SceneTree
# The user's feedback of 2026-10-17. After every contract the career comes back to
# the berth terminal, the opening ones too: an opening contract still to play
# waits there on the market page as the one card, and starts from there with
# what the berth owns by then. On site, the berth's two computers open the shop
# and berth-management pages over the berth (play stops; Esc closes; what is
# bought counts from the next contract). One hint level for every contract, and
# the briefing card carries the ship's manifest. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/console_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_console_career.json"
	SaveGame.path = "user://zp_test_console_save.json"
	for f in [Career.path, SaveGame.path]:
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


func _run() -> void:
	print("CONSOLE: the terminal between opening contracts")
	Career.data = {}
	Career.start_new()
	Career.data.money = 120000.0
	Career.save()
	check(Career.active().get("id", "") == "TUG-001" and not Career.data.get("market", false), "a new career: the work tug in hand, the market not open")
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	check(term.next_job.get("id", "") == "TUG-001" and term.tab == 0, "the terminal shows it as the next job, on the market page")
	term.buy(term.BERTH.filter(func(b): return b[0] == "hauler")[0])
	check(Career.data.upgrades.has("hauler"), "bought before it starts: the basic hauler")
	term.act()
	await _frames(2)
	check(Game.contract.get("id", "") == "TUG-001" and Game.contract.get("kit", {}).has("hauler") and term.leaving >= 0.0, "started from there, it goes to work with the hauler")
	term.queue_free()
	await _frames(2)

	print("CONSOLE: the berth's computers on site")
	Game.contract = Career.active()
	Game.start_ship = Game.contract.ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(5)
	check(g.consoles != null and g.hauler != null and Consoles.SPOTS.size() == 1, "one computer in the berth (and the hauler bought at the terminal is here)")
	g.drone.global_position = Consoles.centre(0) + Vector2(60, 0)
	await _frames(2)
	check(g.consoles.near() == "terminal", "the drone at it: the berth terminal")
	g.open_console(g.consoles.near())
	await _frames(3)
	var ui = g.console_ui
	check(ui != null and ui.tab == ui.HOME and g.get_tree().paused, "it opens the terminal's home screen over the berth, play stopped")
	ui.set_tab(0)
	check(ui.tab == ui.HOME and ui.msg != "", "the contracts are locked on site and it says why (\"%s\")" % ui.msg)
	ui.set_tab(1)
	check(ui.tab == ui.HOME, "so is the equipment")
	var m0 := float(Career.data.money)
	var up: Array = ui.SHOP.filter(func(it): return it[1] == "upgrade")[0]
	ui.buy(up)
	check(not Career.data.upgrades.has(up[0]) and float(Career.data.money) == m0, "nothing for later is sold on site (%s refused)" % up[0])
	ui.set_tab(4)
	var ring0: int = g.stock("ring")
	ui.buy(ui.SHOP.filter(func(it): return it[0] == "ring")[0])
	check(ui.tab == 4 and g.stock("ring") == ring0 + 1 and float(Career.data.money) < m0, "a consumable bought on site goes straight into this job's stock (%d → %d)" % [ring0, g.stock("ring")])
	ui.close()
	await _frames(3)
	check(g.console_ui == null and not g.get_tree().paused and not g.paused_sim, "closed: play goes on")
	# the terminal key opens the same thing from anywhere
	g.drone.global_position = Vector2(30.0, -6.0) * 48.0
	await _frames(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_B
	ev.physical_keycode = KEY_B
	ev.pressed = true
	g._unhandled_input(ev)
	await _frames(3)
	check(g.console_ui != null and g.console_ui.tab == g.console_ui.HOME, "the terminal key opens it away from the computer")
	g.console_ui.close()
	await _frames(2)

	print("CONSOLE: one briefing for every contract")
	check(Txt.hint_tier == "standard", "one hint level")
	g.open_contract()
	await _frames(30)
	check(g.contract_open, "the briefing card, with the ship's manifest, draws")
	g.queue_free()
	await _frames(2)
	print("CONSOLE %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
