extends SceneTree
# Roadmap 3.4 acceptance: basic logistics automation. GR-001 taken apart by
# the careful (paced) bot twice, without the berth's machines and with the
# recovery arm and the hauler: with them the drone's own hauls of plain scrap
# fall by half or more, and every piece of whole equipment still reaches the
# equipment mouth (neither machine takes one unasked). With machines on hand
# the bot, like a player, cuts scrap too heavy for them down to their size.
# The automation key stops the arm at once and it lets go of what it holds;
# the arm and the hauler take turns over a mouth.
# godot --headless --path . --fixed-fps 60 -s tests/logistics_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
var fails := 0
var finished := false


func _initialize() -> void:
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


func _game(kit: Dictionary) -> Node:
	Game.contract = {}
	Game.start_ship = ""
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	return scene


func _play(kit: Dictionary, pause_at: int = -1) -> Dictionary:
	var g = _game(kit)
	await _frames(2)
	var bot = Bot.new(g, {"paced": true})
	var f := 0
	var paused := {}
	while not bot.step():
		f += 1
		# the automation key while the arm carries: it lets go and stands by
		if pause_at > 0 and paused.is_empty() and f > pause_at and g.arm != null and g.arm.state == "carry":
			var held = g.arm.body
			g.toggle_auto()
			await _frames(3)
			paused = {"idle": g.arm.state == "idle" and g.arm.body == null, "let_go": is_instance_valid(held) and not held.get_meta("arm", false) and not held.freeze}
			var c0: int = g.arm.carried
			await _frames(240)
			paused.stays = g.arm.state == "idle" and g.arm.carried == c0
			g.toggle_auto()
		await process_frame
	await _frames(5)
	var equip := {}
	for l in g.ledger:
		if l[1] == "equip":
			for nm in str(l[0]).split(", "):
				equip[nm] = true
	print("    scrap the drone hauled itself (t): ", bot.scrap_masses)
	var out := {"sum": bot.summary(), "equip": equip, "paused": paused, "income_equip": g.income_equip if "income_equip" in g else 0.0}
	g.queue_free()
	await _frames(2)
	return out


func _run() -> void:
	print("LOGISTICS: GR-001 by hand")
	var a: Dictionary = await _play({})
	print("  ", a.sum)
	print("LOGISTICS: GR-001 with the recovery arm and the hauler")
	var b: Dictionary = await _play({"arm": 1, "hauler": 1}, 600)
	print("  ", b.sum)
	check(a.sum.ended and b.sum.ended and a.sum.incidents == 0 and b.sum.incidents == 0, "both taken apart safely")
	check(a.sum.scrap_hauls > 0 and b.sum.scrap_hauls <= a.sum.scrap_hauls * 0.5, "the drone's own hauls of plain scrap: %d by hand, %d with the machines (≤ 50%%)" % [a.sum.scrap_hauls, b.sum.scrap_hauls])
	check(b.sum.arm > 0 and b.sum.hauler > 0, "the arm took %d loads, the hauler %d unasked" % [b.sum.arm, b.sum.hauler])
	var missing: Array = []
	for k in a.equip:
		if not b.equip.has(k):
			missing.append(k)
	check(missing.is_empty(), "every piece of whole equipment reached the equipment mouth with the machines too (%d / %d, missing %s)" % [b.equip.size(), a.equip.size(), str(missing)])
	check(float(b.sum.rate) >= float(a.sum.rate) - 0.01, "recovery %.1f%% by hand, %.1f%% with the machines" % [a.sum.rate * 100.0, b.sum.rate * 100.0])
	var p: Dictionary = b.paused
	check(not p.is_empty() and p.idle and p.let_go, "the automation key: the arm lets go and stands by (%s)" % str(p))
	check(not p.is_empty() and p.stays, "and takes nothing while stopped")
	# one machine over a mouth at a time
	var g = _game({"arm": 1, "hauler": 1})
	await _frames(2)
	check(g.mouth_take("metal", "arm") and not g.mouth_take("metal", "hauler") and g.mouth_take("equip", "hauler"), "the furnace mouth is the arm's while it drops; the hauler takes another")
	g.mouth_release("metal", "arm")
	check(g.mouth_take("metal", "hauler"), "and the furnace is free again once the arm let go")
	g.queue_free()
	await _frames(2)
	print("LOGISTICS %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
