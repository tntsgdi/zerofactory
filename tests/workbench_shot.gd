extends SceneTree
const Cap = preload("res://tests/cap.gd")
var term: Terminal

func _initialize() -> void:
	_run()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await frames(65)
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/" + name + ".png")

func _run() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	Txt.dev = true
	Txt.cfg_path = "user://zp_test_workbench_shot.cfg"
	Career.path = "user://zp_test_workbench_shot.json"
	Career.data = Career.fresh()
	Career.data.money = 185000.0
	Career.data.done = 5
	Career.data.rep = 9
	Career.data.upgrades = {"skill_drive": 2, "grapple5": 1, "scan_kit": 1}
	root.add_child(preload("res://tests/test_window.gd").new())
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await frames(3)
	var dev: DevPanel
	for child in term.get_children():
		if child is DevPanel: dev = child
	dev.set_open(true)
	var suffix := "_en" if not Txt.zh else "_zh"
	if OS.get_cmdline_user_args().has("small"): suffix += "_720"
	await shot("workbench_actions" + suffix)
	dev.bench.page = 1
	dev.bench.refresh()
	await shot("workbench_growth" + suffix)
	DevPanel.b_ship = "h22"
	DevPanel.b_traps = ["second_source"]
	dev.bench.page = 2
	dev.bench.refresh()
	await shot("workbench_lab" + suffix)
	dev.set_open(false)
	term.queue_free()
	await frames(3)
	quit()
