extends SceneTree
# Stills of the berth itself: the whole dock in view, then close-ups of the
# three recovery mouths, the trough and the drone bay.
# tools/run_test.sh tests/dock_shot.gd -- [en]

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
const SHOTS := [["dock_wide", Vector2(21, 1), 0.62], ["dock_furnace", Vector2(21, 6.0), 1.5], ["dock_equip", Vector2(14, -7.0), 1.5], ["dock_hazard", Vector2(42, 5.5), 1.5], ["dock_bay", Vector2(-3, -5.0), 1.5]]


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	root.add_child(preload("res://tests/test_window.gd").new())
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(21 * 48, 0), "lmb": false, "move": Vector2.ZERO}
	root.add_child(game)


func _process(_dt: float) -> bool:
	frame += 1
	var i := (frame - 60) / 50
	if frame >= 60 and i < SHOTS.size():
		var sh: Array = SHOTS[i]
		game.cam_override = sh[1] * 48.0
		game.zoom_override = sh[2]
		game.drone.global_position = sh[1] * 48.0 + Vector2(0, -2.5 * 48)
		game.drone.linear_velocity = Vector2.ZERO
		if (frame - 60) % 50 == 49:
			Cap.save(root, "res://tests/out/%s.png" % sh[0])
	return frame >= 60 + SHOTS.size() * 50
