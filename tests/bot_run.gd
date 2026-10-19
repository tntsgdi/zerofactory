extends SceneTree
# The salvage bot on one contract: GR-001 as built, or a random contract from a
# seed (seed=N, stars=N), careless or not. Prints the books.
# godot --headless --path . --fixed-fps 60 -s tests/bot_run.gd -- [seed=N] [ship=ID] [careless] [paced] [ledger] [kit=a,b]

const Bot = preload("res://tests/salvage_bot.gd")
var game
var bot
var job := {}
var show_ledger := false
var kit := {}
var paced := false


func _initialize() -> void:
	var careless := false
	var stars := 1
	var seed := -1
	var ship := ""
	for a in OS.get_cmdline_user_args():
		if a == "careless":
			careless = true
		elif a.begins_with("seed="):
			seed = int(a.substr(5))
		elif a.begins_with("ship="):
			ship = a.substr(5)
		elif a.begins_with("stars="):
			stars = int(a.substr(6))
		elif a == "paced":
			paced = true
		elif a == "ledger":
			show_ledger = true
		elif a.begins_with("kit="):
			for id in a.substr(4).split(","):
				kit[id] = 1
	if seed >= 0:
		job = Market.offer_for(seed, {"rep": 20, "done": 1}, stars)
		print("contract ", job)
	Game.contract = job
	if ship != "":
		Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	game = scene
	bot = Bot.new(game, {"careless": careless, "paced": paced})


var _frame := 0


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame % 3600 == 0:
		print("PROGRESS frame %d sim %.0f s phase %s earned %.0f bodies %d" % [_frame, game.sys.time, bot.phase, game.earned(), game.world.bodies.size()])
	if bot.step():
		for n in bot.notes:
			print(n)
		print("BOT ", bot.summary(), "  incidents ", game.incidents)
		if show_ledger:
			for l in game.ledger:
				print("LEDGER ", l)
		return true
	return false
