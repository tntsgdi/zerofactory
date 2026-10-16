extends SceneTree
# The salvage bot on one contract: GR-001 as built, or a random contract from a
# seed (seed=N, stars=N), careless or not. Prints the books.
# godot --headless --path . --fixed-fps 60 -s tests/bot_run.gd -- [seed=N] [careless]

const Bot = preload("res://tests/salvage_bot.gd")
var game
var bot
var job := {}


func _initialize() -> void:
	var careless := false
	for a in OS.get_cmdline_user_args():
		if a == "careless":
			careless = true
		elif a.begins_with("seed="):
			pass
	Game.contract = job
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	game = scene
	bot = Bot.new(game, {"careless": careless})


func _process(_dt: float) -> bool:
	if bot.step():
		for n in bot.notes:
			print(n)
		print("BOT ", bot.summary(), "  incidents ", game.incidents)
		return true
	return false
