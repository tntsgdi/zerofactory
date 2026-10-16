extends SceneTree
# V2 2.4 acceptance: taking apart three Herons in a row, an operator who only
# repeats the order that made GR-001 safe does not get through them all
# without an accident; the bot that reads each ship's own systems does.
# 1. GR-001 with the reading bot: its safe-making order is recorded.
# 2. Three market Herons (a new career's first three offers, one after the
#    other), each played twice: the remembered order done blindly (waiting as
#    long as it took on GR-001), then the reading bot.
# godot --headless --path . --fixed-fps 60 -s tests/memory_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var finished := false
var fails := 0


func _initialize() -> void:
	SaveGame.path = "user://zp_test_memory_save.json"
	Career.path = "user://zp_test_memory_career.json"
	_run()


func _process(_dt: float) -> bool:
	return finished


func _play(job: Dictionary, opts: Dictionary) -> Dictionary:
	Game.contract = job
	SaveGame.load_requested = false
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	var bot = Bot.new(scene, opts)
	bot.timeout = 60000
	while not bot.step():
		await process_frame
	for k in 3:
		await process_frame
	var out := {"incidents": scene.incidents.duplicate(true), "losses": scene.losses, "rec": bot.rec.duplicate(true), "safe_at": bot.safe_at, "net": scene.net()}
	scene.queue_free()
	for k in 3:
		await process_frame
	return out


func _kinds(incs: Array) -> String:
	var k: Array = []
	for i in incs:
		k.append(str(i[1]))
	return ", ".join(k)


func _run() -> void:
	print("MEMORY: GR-001, the order that makes it safe")
	var first: Dictionary = await _play({}, {})
	print("  %d steps, safe after %.0f s sim, incidents %d: %s" % [first.rec.size(), first.safe_at, first.incidents.size(), str(first.rec)])
	var career := Career.fresh()
	career.done = 1
	var blind_bad := 0
	var read_bad := 0
	for k in 3:
		var o: Dictionary = Market.make(100 + k, career)[0]
		o.erase("_ship")
		var blind: Dictionary = await _play(o.duplicate(true), {"replay": first.rec.duplicate(true), "replay_wait": first.safe_at})
		var read: Dictionary = await _play(o.duplicate(true), {})
		var bad: bool = not blind.incidents.is_empty() or blind.losses > 0.0
		blind_bad += 1 if bad else 0
		read_bad += 0 if read.incidents.is_empty() else 1
		print("  %s  traps %s" % [o.id, str(o.traps)])
		print("    remembered order: %d incidents (%s), losses $%d, net $%d" % [blind.incidents.size(), _kinds(blind.incidents), int(blind.losses), int(blind.net)])
		print("    reading the ship: %d incidents (%s), losses $%d, net $%d" % [read.incidents.size(), _kinds(read.incidents), int(read.losses), int(read.net)])
		career.done = int(career.done) + 1
	var ok := blind_bad >= 1 and read_bad == 0
	print("  remembered order went wrong on %d of 3; reading each ship went wrong on %d of 3" % [blind_bad, read_bad])
	print("MEMORY %s" % ("PASS" if ok else "FAIL"))
	finished = true
