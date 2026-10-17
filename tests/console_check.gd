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
	check(g.consoles != null and g.hauler != null, "two computers in the berth (and the hauler bought at the terminal is here)")
	g.drone.global_position = Consoles.centre(0) + Vector2(60, 0)
	await _frames(2)
	check(g.consoles.near() == "shop", "the drone at the first: the shop")
	g.open_console("shop")
	await _frames(3)
	var ui = g.console_ui
	check(ui != null and ui.tab == 1 and g.get_tree().paused, "it opens the shop over the berth, play stopped")
	ui.set_tab(0)
	check(ui.tab == 1, "the market page stays shut on site")
	var m0 := float(Career.data.money)
	var up: Array = ui.SHOP.filter(func(it): return it[1] == "upgrade")[0]
	ui.buy(up)
	check(Career.data.upgrades.has(up[0]) and float(Career.data.money) < m0 and not g.has_upgrade(up[0]), "bought there (%s): paid for, counts from the next contract" % up[0])
	ui.close()
	await _frames(3)
	check(g.console_ui == null and not g.get_tree().paused and not g.paused_sim, "closed: play goes on")
	g.drone.global_position = Consoles.centre(1) + Vector2(60, 0)
	await _frames(2)
	g.open_console(g.consoles.near())
	await _frames(3)
	check(g.console_ui != null and g.console_ui.tab == 2, "the second: berth management")
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
