extends SceneTree
# The terminal with the special courses (design/新手教程与图鉴定案.md): an offer on a
# family never trained for (the button says the course comes first, the card names
# what is new aboard), the training page (base course, seven courses, the codex),
# the codex over the terminal. tools/run_test.sh tests/codex_term_shot.gd --fixed-fps 60 -- [en]

const Cap = preload("res://tests/cap.gd")
var frame := 0
var term


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	Career.path = "user://zp_test_codex_term.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 6
	Career.data.money = 141250.0
	Career.data.rep = 20
	Career.data.seen = {"market": true}
	Career.data.certs_checked = true
	Career.data.certs = {"cryo": "full", "load": "auto"}
	Career.data.codex = {"seen": {}, "new": {}}
	for id in CodexData.E.keys().slice(0, 60):
		Career.data.codex.seen[id] = true
	root.add_child(preload("res://tests/test_window.gd").new())
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)


func _process(_dt: float) -> bool:
	frame += 1
	var l := "_en" if not Txt.zh else ""
	match frame:
		40:
			term.set_tab(0)
		50:
			# the first offer: a fusion ship, never trained for
			var os: Array = term.offers()
			if not os.is_empty():
				os[0].ship = "fx70"
			term.sel = 0
		90:
			Cap.save(root, "res://tests/out/cx_term_offer%s.png" % l)
			term.set_tab(7)
		130:
			term.sel = 1
		150:
			Cap.save(root, "res://tests/out/cx_term_training%s.png" % l)
			term.sel = 8
			term.act()
		190:
			Cap.save(root, "res://tests/out/cx_term_codex%s.png" % l)
			return true
	return false
