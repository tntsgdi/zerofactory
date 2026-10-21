extends SceneTree
# A special course on screen: the task list with a first-meeting card under it, then the
# certificate. tools/run_test.sh tests/special_shot.gd --fixed-fps 60 -- [family] [en]

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var family := "energy"
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(900, -300), "lmb": false, "move": Vector2.ZERO, "codex": true}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		family = a[0]
	Txt.test_zh = not a.has("en")
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = "sp_" + family
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	var l := "_en" if not Txt.zh else ""
	if frame == 300:
		game.drone.global_position = Vector2(21.0, -4.0) * 48.0
		game.drone.linear_velocity = Vector2.ZERO
		game.codex.gap_t = 99.0
		var mech: Array = Codex.ship_entries(game.ship_id)
		game.codex.meet(mech[0] if not mech.is_empty() else "bolt", "shot")
	if frame == 380:
		Cap.save(root, "res://tests/out/cx_special_%s%s.png" % [family, l])
		game.tutorial._finish()
	if frame == 380 + 150:
		Cap.save(root, "res://tests/out/cx_special_cert_%s%s.png" % [family, l])
		return true
	return false
