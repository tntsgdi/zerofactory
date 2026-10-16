extends SceneTree
# Whole-dock stills: tools/run_test.sh tests/wide_shot.gd -- <name> <zoom> <cx> <cy> [reveal] [intro_frames]

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var args: PackedStringArray
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(900, -400), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	root.add_child(preload("res://tests/test_window.gd").new())
	if args.size() > 5:
		bot.skip_intro = false
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	var shot_at := 40 if args.size() <= 5 else int(args[5])
	if frame == 3 and args.size() > 4 and args[4] == "reveal":
		for n in game.world.rooms:
			game.world.reveal(n, game.world.rooms[n].from)
	if args.size() <= 5 and frame > 2:
		game.cam_override = Vector2(float(args[2]), float(args[3])) * 48.0
		game.zoom_override = float(args[1])
		game.zoom_now = float(args[1])
		game.cam_pos = game.cam_override
	if frame == shot_at:
		Cap.save(root, "res://tests/out/%s.png" % args[0])
		return true
	return false
