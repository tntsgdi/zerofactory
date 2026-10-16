extends SceneTree
# Starts the real game with a bot and photographs it.
# tools/run_test.sh tests/play_shot.gd -- <name> <frames> [script]

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var name := "play"
var frames := 120
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(500, -260), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		name = a[0]
	if a.size() > 1:
		frames = int(a[1])
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 5:
		game.drone.global_position = Vector2(500, -330)
		game.drone.linear_velocity = Vector2.ZERO
	if frame == frames:
		Cap.save(root, "res://tests/out/%s.png" % name)
		return true
	return false
