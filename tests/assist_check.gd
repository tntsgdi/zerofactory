extends SceneTree
# Flight assist: release stops the drone, steering kills side drift; off = pure inertia.
const M := 48.0
var game
var frame := 0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(0, -400), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	var d = game.drone
	match frame:
		3:
			d.global_position = Vector2(10, -7) * M
			d.linear_velocity = Vector2.ZERO
			d.spawn_t = 5.0
			bot.move = Vector2(1, 0)
		60:
			print("assist on: speed after 1 s of thrust %.1f m/s" % (d.linear_velocity.length() / M))
			bot.move = Vector2(0, -1)
		90:
			print("  steering up: vx %.1f vy %.1f m/s (side drift should be gone)" % [d.linear_velocity.x / M, d.linear_velocity.y / M])
			bot.move = Vector2.ZERO
		120:
			print("  0.5 s after release: %.2f m/s" % (d.linear_velocity.length() / M))
			d.assist = false
			bot.move = Vector2(1, 0)
		150:
			bot.move = Vector2.ZERO
		210:
			print("assist off: 1 s after release still %.1f m/s" % (d.linear_velocity.length() / M))
			return true
	return false
