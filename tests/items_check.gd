extends SceneTree
# Roadmap 2.7 acceptance: each consumable can be bought, can be used, and
# shows in the settlement or the save. On test files: buy one of each at the
# terminal; read a survey report on an offer (the card shows a true hidden
# condition, stock drops); take the contract; on site use a repair kit (+50
# integrity), fire a breaching ring through a keel (it splits at once, no
# accident), lose the drone with a spare in stock (no charge); save and load
# half way (what was used stays used); settle (stock drops by what was used,
# the settlement lists it).
# godot --headless --path . --fixed-fps 60 -s tests/items_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
const M := 48.0
var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_items_career.json"
	SaveGame.path = "user://zp_test_items_save.json"
	SaveGame.allow_test = true
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


func _game(load_it: bool) -> Node:
	Game.contract = Career.active()
	SaveGame.load_requested = load_it
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	await _frames(3)
	return scene


func _run() -> void:
	Career.data = {}
	Career.start_new()
	var d := Career.data
	d.active = {}
	d.market = true
	d.done = 1
	d.money = 80000.0
	d.seen = {"market": true}
	# a fixed market: the career seed is random (randi), so each run drew other offers
	d.seed = 41
	Career.save()
	# ---- the terminal: buy one of each, read a survey report
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	var before := float(d.money)
	for id in ["repair", "ring", "spare", "intel"]:
		for it in term.SHOP:
			if it[0] == id:
				term.buy(it)
	var cost := 3000.0 + 9000.0 + 15000.0 + 6000.0
	check(absf(float(d.money) - (before - cost)) < 1.0 and d.items.repair == 1 and d.items.ring == 1 and d.items.spare == 1 and d.items.intel == 1, "bought one of each for %s" % Pal.money(cost))
	# the market has several ship types now: the first card is made a Heron (the ring goes into its keel),
	# one without the live-cargo trap (its live feed is hosted on the keel: cutting the keel unpowered
	# first is an arc, as it should be, and this is about the ring, not that trap)
	var o0: Dictionary = term.offers()[0]
	if o0.ship != "gr7" or "live_cargo" in o0.get("traps", []):
		for seed in range(900, 1100):
			var h := Market.offer_for(seed, Career.data, 1, "full", "gr7")
			if "live_cargo" in h.get("traps", []):
				continue
			if ContractValidator.check(Variant.make(Ship.load_data("gr7"), h)).ok:
				Career.data.offers[0] = h
				term.dealt()
				break
	term.use_intel(0)
	var o: Dictionary = term.offers()[0]
	var text: String = term.intel_text(o)
	check(o.has("intel") and text != "" and int(d.items.intel) == 0, "survey report on offer %s (%s): \"%s\"" % [o.id, str(o.traps), text])
	# the report tells the truth about the ship that will come in
	var ship := Variant.make(Ship.load_data(o.ship), o)
	var truth := Traps.intel(ship, o.traps[0])
	check(str(truth) == str(o.intel), "and it is the truth about that ship (%s)" % str(truth))
	Career.data = {}
	Career.load_or_new()
	check(Career.data.offers.any(func(x): return x.has("intel")), "the report stays on the card through a reload")
	term.take(0)
	term.queue_free()
	await _frames(2)
	check(Career.active().get("items", {}).get("repair", 0) == 1, "the contract is signed with the stock in hand")
	# ---- on site
	var g = await _game(false)
	g.drone.integrity = 30.0
	g.repair_kit()
	check(absf(g.drone.integrity - 80.0) < 0.1 and g.stock("repair") == 0, "repair kit: integrity 30 → %d, none left" % int(g.drone.integrity))
	var keel = g.world.tag("K2")
	var parts_before: int = g.world.order.size()
	g.aim = Vector2(14.0, 3.25) * M
	g.drone.global_position = Vector2(14.0, 5.5) * M
	g.breaching_ring()
	await _frames(3)
	check(g.world.order.size() > parts_before and g.stock("ring") == 0 and g.incidents.is_empty(), "breaching ring: K2 cut through in one go (%d → %d pieces), no accident (rings left %d, incidents %s)" % [parts_before, g.world.order.size(), g.stock("ring"), g.incidents])
	var losses0: float = g.losses
	g.drone.hurt(200.0, g.drone.global_position)
	await _frames(3)
	check(g.losses == losses0 and g.stock("spare") == 0, "drone lost with a spare in stock: no charge")
	# save and load: used stays used
	SaveGame.save(g)
	var used_before: Dictionary = g.used.duplicate()
	g.queue_free()
	await _frames(2)
	Career.data = {}
	Career.load_or_new()
	var g2 = await _game(true)
	check(str(g2.used) == str(used_before) and g2.stock("repair") == 0, "the save keeps what was used: %s" % str(g2.used))
	# settle
	var bot = Bot.new(g2)
	while not bot.step():
		await process_frame
	await _frames(3)
	var r: Dictionary = g2.career_result
	check(int(Career.data.items.get("repair", 0)) == 0 and int(Career.data.items.get("ring", 0)) == 0 and int(Career.data.items.get("spare", 0)) == 0, "settled: stock down by what was used")
	check(g2.hud.career_rows().any(func(x): return x[0] == "e_used"), "the settlement lists it: %s" % str(g2.hud.career_rows().filter(func(x): return x[0] == "e_used")))
	g2.queue_free()
	print("ITEMS %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
