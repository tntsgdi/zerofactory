extends SceneTree
# Stills of developer mode: the contract builder at the terminal, and on site
# the x-ray with the inspect card (H-22). Writes tests/out/dev_*.png.
# tools/run_test.sh tests/dev_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var frame := 0
var term
var game


func _initialize() -> void:
	Txt.zh = true
	Career.path = "user://zp_test_devshot_career.json"
	SaveGame.path = "user://zp_test_devshot_save.json"
	Txt.cfg_path = "user://zp_test_devshot.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 41250.0
	Career.data.seen = {"market": true}
	Txt.dev = true
	DevPanel.b_ship = "h22"
	DevPanel.b_traps = ["second_source"]
	DevPanel.b_kit = {"arm": 1}
	root.add_child(preload("res://tests/test_window.gd").new())
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)


func _dev(n: Node) -> DevPanel:
	for ch in n.get_children():
		if ch is DevPanel:
			return ch
	return null


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		20:
			_dev(term).set_open(true)
			_dev(term).bench.page = 2
			_dev(term).bench.refresh()
		60:
			Cap.save(root, "res://tests/out/dev_builder.png")
			var o: Dictionary = DevPanel.build(Career.data).offer
			o.dev = true
			Game.contract = o
			Game.start_ship = "h22"
			term.queue_free()
			game = load("res://scenes/main.tscn").instantiate()
			game.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(1.0, -4.9) * 48.0, "lmb": false, "move": Vector2.ZERO}
			root.add_child(game)
		70:
			DevPanel.xray = true
			DevPanel.inspect = true
			var d := _dev(game)
			d.mouse = Vector2(760, 360)
		130:
			Cap.save(root, "res://tests/out/dev_xray.png")
			Txt.dev = false
			return true
	return false
