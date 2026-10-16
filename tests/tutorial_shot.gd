extends SceneTree
# The training course on screen: a few stills while it runs by itself.
# tools/run_test.sh tests/tutorial_shot.gd

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(500, -260), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = "ts1"
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 90:
		Cap.save(root, "res://tests/out/tut_radio.png")
		print("lesson %d step %d line %s" % [game.tutorial.lesson_i, game.tutorial.step_i, game.tutorial.line_now.get("id", "-")])
	if frame == 100:
		game.tools.set_tool(2)
	if frame == 104:
		Cap.save(root, "res://tests/out/tut_locked.png")
	return frame >= 110
