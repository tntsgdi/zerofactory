extends SceneTree
# Same views before and after a rendering change: a wide shot of the berth and
# a close shot of room D's structure, all rooms opened, a few pieces adrift.
# tools/run_test.sh tests/compare_shot.gd -- <prefix>

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var frame := 0
var prefix := "cmp"
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(500, -260), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		prefix = a[0]
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 3:
		seed(3)
		for n in game.world.rooms:
			game.world.reveal(n, game.world.rooms[n].from)
		game.drone.global_position = Vector2(14, -7) * M
		game.drone.linear_velocity = Vector2.ZERO
		game.cam_override = Vector2(21, 0) * M
		game.zoom_override = 0.62
	if frame == 90:
		Cap.save(root, "res://tests/out/%s_wide.png" % prefix)
		game.cam_override = Vector2(25, 0.5) * M
		game.zoom_override = 2.2
	if frame == 170:
		Cap.save(root, "res://tests/out/%s_close.png" % prefix)
		return true
	return false
