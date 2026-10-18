extends SceneTree
# Taking a contract (2026-10-18): the terminal folds into a hairline through
# the chosen card and the berth opens out of the line. Stills along the way,
# and how long the screen was held still. Test career only.
# tools/run_test.sh tests/fold_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")

func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_fold_career.json"
	SaveGame.path = "user://zp_test_fold_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.money = 41250.0
	Career.data.rep = 7
	Career.data.seen = {"market": true}
	Career.save()
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var term = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	current_scene = term
	await _frames(150)
	term.set_tab(0)
	await _frames(40)
	term.sel = 1
	await _frames(10)
	term.act()
	var shots := [8, 14, 20, 26, 34, 42, 52]
	var f := 0
	var phases := []
	while f < 60:
		await process_frame
		f += 1
		if Wipe.current != null and is_instance_valid(Wipe.current):
			phases.append(Wipe.current.phase)
		if f in shots:
			Cap.save(root, "res://tests/out/fold_%02d.png" % f)
	var seen := []
	for p in phases:
		if seen.is_empty() or seen[-1] != p:
			seen.append(p)
	print("FOLD phases %s, now on %s" % [seen, current_scene.scene_file_path if current_scene != null else "?"])
	quit()
