extends SceneTree
# Stills of the berth from above (the overview key): standard, and extended
# (roadmap 4.1) with a Heron in it, or any ship (ship=<id>). Writes tests/out/berth_*.png.
# tools/run_test.sh tests/berth_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var frame := 0
var game
var shots := [["standard", {}, "gr7"], ["extended", {"berth88": 1}, "gr7"]]
var i := 0


func _initialize() -> void:
	Txt.zh = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			shots = [[a.substr(5), {}, a.substr(5)]]
	SaveGame.path = "user://zp_test_berthshot_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_next()


func _next() -> void:
	Game.contract = {}
	Game.start_ship = shots[i][2]
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": shots[i][1]}
	root.add_child(game)
	frame = 0


func _process(_dt: float) -> bool:
	frame += 1
	if frame >= 5:
		# what the overview key shows (the key itself is the player's, not the bot's)
		var vs: Vector2 = game.get_viewport().get_visible_rect().size
		game.cam_override = Dock.centre() * Geom.M
		game.zoom_override = minf(vs.x / ((Dock.FLOOR_X1 - Dock.TOWER_X + 3.0) * Geom.M), vs.y / (26.0 * Geom.M))
	if frame == 90:
		Cap.save(root, "res://tests/out/berth_%s.png" % shots[i][0])
		game.queue_free()
		i += 1
		if i >= shots.size():
			return true
		_next()
	return false
