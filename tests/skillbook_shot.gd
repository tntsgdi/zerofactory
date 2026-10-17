extends SceneTree
const Cap = preload("res://tests/cap.gd")
var term: Terminal
var suffix := ""

func _initialize() -> void:
	_run()

func wait_frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(file: String) -> void:
	await wait_frames(70)
	await RenderingServer.frame_post_draw
	Cap.save(root, "res://proofs/" + file + suffix + ".png")

func _run() -> void:
	Career.path = "user://zp_test_skillbook_shot.json"
	suffix = "_720" if OS.get_cmdline_user_args().has("small") else ""
	Career.data = Career.fresh()
	Career.data.money = 41250.0
	Career.data.done = 3
	Career.data.rep = 7
	Career.data.upgrades = {"scan_kit": 1, "pump2": 1, "skill_drive": 1}
	Career.data.growth_goal = "drive"
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	root.add_child(preload("res://tests/test_window.gd").new())
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await wait_frames(5)
	term.set_tab(3)
	await wait_frames(5)
	await shot("skillbook_" + ("zh" if Txt.zh else "en"))
	term.book.selected = "grapple_mass"
	term.book.refresh_detail()
	await shot("skillbook_grapple_" + ("zh" if Txt.zh else "en"))
	term.set_tab(0)
	await shot("growth_goal_" + ("zh" if Txt.zh else "en"))
	term.queue_free()
	await wait_frames(3)
	quit()
