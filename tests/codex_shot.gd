extends SceneTree
# The first-meeting card and the book, photographed on GR-7 (and the card in the
# training course): tools/run_test.sh tests/codex_shot.gd -- [entry] [ship] [lang]
# Writes tests/out/codex_card_<entry>.png and codex_book_<entry>.png.

const Cap = preload("res://tests/cap.gd")
var game
var frame := 0
var entry := "bolt"
var ship := ""
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(500, -260), "lmb": false, "move": Vector2.ZERO, "codex": true}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		entry = a[0]
	if a.size() > 1 and a[1] != "-":
		ship = a[1]
	if a.size() > 2:
		Txt.test_zh = a[2] != "en"
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	root.add_child(preload("res://tests/test_window.gd").new())
	if ship != "":
		Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 5:
		game.drone.global_position = Vector2(500, -330)
		game.drone.linear_velocity = Vector2.ZERO
	if frame == 60:
		# a few met already, so the book has something in it
		for id in CodexData.E.keys().slice(0, 12):
			Codex.mark(id)
		game.codex.gap_t = 99.0
		game.codex.meet(entry, "test")
	if frame == 110:
		Cap.save(root, "res://tests/out/codex_card_%s.png" % entry)
	if frame == 120:
		game.codex_hud.open_book(entry)
	if frame == 150:
		Cap.save(root, "res://tests/out/codex_book_%s.png" % entry)
		return true
	return false
