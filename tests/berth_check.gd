extends SceneTree
# Roadmap 4.1: the berth extension. The standard berth is laid out exactly as
# before; the extended one reaches 88 m with its far-end fittings moved along.
# The market never offers a ship longer than the standard berth takes until
# the extension is bought, and does once it is. Bought at the terminal, it
# costs its price; a contract taken with it is played in the extended berth,
# one without it in the standard berth. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/berth_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_berth_career.json"
	SaveGame.path = "user://zp_test_berth_save.json"
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


func _game(ship: String, kit: Dictionary) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	return scene


func _types(career: Dictionary, n: int) -> Dictionary:
	var seen := {}
	for m in n:
		for o in Market.make(5000 + m, career):
			seen[o.ship] = int(seen.get(o.ship, 0)) + 1
	return seen


func _run() -> void:
	print("BERTH: the layout")
	Dock.configure(Dock.STANDARD)
	check(Dock.FLOOR_X1 == 50.0 and Dock.BOUNDS == Rect2(-6.8, -15.0, 63.0, 24.0) and Dock.TROUGH_X1 == 40.5 and Dock.ARM_X1 == 27.5
		and Dock.ZONES.hazard.pos == Vector2(43.6, 6.9) and Dock.ZONES.equip.pos == Vector2(14.0, -8.4) and Dock.metal_home == 21.0, "standard: exactly the berth it always was")
	Dock.configure(Dock.EXTENDED)
	check(Dock.FLOOR_X1 == 88.0 and Dock.BOUNDS.end.x > 94.0 and Dock.TROUGH_X1 > 78.0 and Dock.ZONES.hazard.pos.x > 80.0 and Dock.MASTS.size() == 4, "extended: floor, trough and far bay to 88 m, a fourth mast")
	print("BERTH: the market")
	var c := {"rep": 30, "done": 8, "upgrades": {}}
	var t0 := _types(c, 80)
	check(not t0.has("med47") and t0.has("gr7"), "without the extension: no 82 m hospital ship among %d offers" % t0.values().reduce(func(a, b): return a + b, 0))
	c.upgrades = {"berth88": 1}
	var t1 := _types(c, 80)
	check(t1.has("med47"), "with it: MED-47 comes up (%d of the offers)" % int(t1.get("med47", 0)))
	var c2 := {"rep": 4, "done": 3, "upgrades": {"berth88": 1}}
	check(not _types(c2, 60).has("med47"), "and only at reputation 10")
	print("BERTH: bought at the terminal")
	Career.data = {}
	Career.start_new()
	Career.data.active = {}
	Career.data.market = true
	Career.data.seen = {"market": true}
	Career.data.money = 300000.0
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	var it: Array = []
	for b in term.BERTH:
		if b[0] == "berth88":
			it = b
	term.buy(it)
	check(Career.data.upgrades.has("berth88") and absf(float(Career.data.money) - 60000.0) < 1.0, "the extension is bought for $240,000 (left $%d)" % int(Career.data.money))
	term.queue_free()
	await _frames(2)
	print("BERTH: in play")
	var g = _game("gr7", {"berth88": 1})
	await _frames(3)
	check(Dock.floor_end == Dock.EXTENDED and g.arm == null, "a Heron with the extension bought: the extended berth")
	g.queue_free()
	await _frames(2)
	g = _game("gr7", {})
	await _frames(3)
	check(Dock.floor_end == Dock.STANDARD and is_equal_approx(Dock.ZONES.hazard.pos.x, 43.6), "without it: the standard berth again (%.1f m, hazard bay at %.1f)" % [Dock.floor_end, Dock.ZONES.hazard.pos.x])
	g.queue_free()
	await _frames(2)
	print("BERTH %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
