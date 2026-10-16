extends SceneTree
# Title, contract card, pause menu, blueprint: tools/run_test.sh tests/ui_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var frame := 0
var title
var game
var bot := {"skip_intro": true, "aim": Vector2(900, -300), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		40:
			Cap.save(root, "res://tests/out/ui_title_draw.png")
		170:
			Cap.save(root, "res://tests/out/ui_title.png")
			title.queue_free()
			game = load("res://scenes/main.tscn").instantiate()
			game.bot = bot
			root.add_child(game)
		200:
			Cap.save(root, "res://tests/out/ui_contract.png")
			game.close_contract()
			game.drone.global_position = Vector2(14 * 48, -5.5 * 48)
		240:
			game.blueprint.toggle()
		290:
			Cap.save(root, "res://tests/out/ui_blueprint.png")
			game.blueprint.toggle()
			game.toggle_menu()
		320:
			Cap.save(root, "res://tests/out/ui_menu.png")
			return true
	return false
