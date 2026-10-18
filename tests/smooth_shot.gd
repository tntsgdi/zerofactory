extends SceneTree
# Stills in the middle of the terminal's motion (2026-10-18): a page switch
# (home → route) at 3, 8 and 20 frames, and the selection frame gliding across
# the home tiles at 2, 5 and 12 frames. Test career only.
# tools/run_test.sh tests/smooth_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var term


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_smoothshot_career.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 41250.0
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.data.upgrades = {"scan_kit": true, "hauler": true}
	root.add_child(preload("res://tests/test_window.gd").new())
	term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(150)
	term.set_tab(5)
	for f in [3, 8, 20]:
		await _frames(f - (0 if f == 3 else (3 if f == 8 else 8)))
		Cap.save(root, "res://tests/out/sw_route_%02d.png" % f)
	term.set_tab(-1)
	await _frames(40)
	term.sel = 0
	await _frames(20)
	term.sel = 6
	for f in [2, 5, 12]:
		await _frames(f - (0 if f == 2 else (2 if f == 5 else 5)))
		Cap.save(root, "res://tests/out/sw_focus_%02d.png" % f)
	quit()
