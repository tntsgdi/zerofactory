extends SceneTree
# The pointer's pour on the terminal's push button and the title menu
# (2026-10-18): stills a few frames after the pointer comes onto them, and
# after it leaves. The pointer is a stand-in: the real mouse is never moved.
# tools/run_test.sh tests/pour_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")

func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_pour_career.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 41250.0
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(150)
	term.set_tab(0)
	await _frames(40)
	var r: Rect2 = term._go_rect()
	term.pointer_override = r.position + Vector2(40, r.size.y * 0.5)
	await _frames(6)
	Cap.save(root, "res://tests/out/pour_go_06.png")
	await _frames(30)
	Cap.save(root, "res://tests/out/pour_go_36.png")
	term.pointer_override = Vector2(960, 600)
	await _frames(10)
	Cap.save(root, "res://tests/out/pour_go_out.png")
	term.queue_free()
	await _frames(4)
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _frames(200)
	var mr: Rect2 = title._menu_rect(1)
	title.pointer_override = mr.position + Vector2(mr.size.x * 0.3, mr.size.y * 0.5)
	await _frames(12)
	Cap.save(root, "res://tests/out/pour_title.png")
	quit()
