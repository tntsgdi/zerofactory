extends SceneTree
# The contract card on a ship with mechanisms of its own: "new on this ship" listed.
# tools/run_test.sh tests/codex_brief_shot.gd -- [ship] [lang]

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var ship := "fx70"
var bot := {"skip_intro": true, "skip_contract": false, "aim": Vector2(500, -260), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		ship = a[0]
	if a.size() > 1:
		Txt.test_zh = a[1] != "en"
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	root.add_child(preload("res://tests/test_window.gd").new())
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 150:
		Cap.save(root, "res://tests/out/codex_brief_%s.png" % ship)
		return true
	return false
