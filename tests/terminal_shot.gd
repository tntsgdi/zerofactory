extends SceneTree
# Stills of the berth terminal (three tabs) and a market contract's card, from
# a test career. tools/run_test.sh tests/terminal_shot.gd --fixed-fps 60 -- [en]

const Cap = preload("res://tests/cap.gd")
var frame := 0
var term
var game


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	Career.path = "user://zp_test_shot_career.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 3
	Career.data.money = 41250.0
	Career.data.loan = 36000.0
	Career.data.in_debt = true
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	root.add_child(preload("res://tests/test_window.gd").new())
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)


func _process(_dt: float) -> bool:
	frame += 1
	var l := "_en" if not Txt.zh else ""
	match frame:
		40:
			Cap.save(root, "res://tests/out/term_home%s.png" % l)
			term.set_tab(0)
		70:
			Cap.save(root, "res://tests/out/term_market%s.png" % l)
			term.set_tab(1)
		100:
			Cap.save(root, "res://tests/out/term_shop%s.png" % l)
			term.set_tab(4)
		130:
			Cap.save(root, "res://tests/out/term_supplies%s.png" % l)
			term.set_tab(5)
		160:
			Cap.save(root, "res://tests/out/term_route%s.png" % l)
			term.set_tab(2)
		190:
			Cap.save(root, "res://tests/out/term_berth%s.png" % l)
			Game.contract = term.offers()[1]
			term.queue_free()
			game = load("res://scenes/main.tscn").instantiate()
			game.bot = {"skip_intro": true, "aim": Vector2(900, -300), "lmb": false, "move": Vector2.ZERO}
			root.add_child(game)
		240:
			Cap.save(root, "res://tests/out/term_card%s.png" % l)
			return true
	return false
