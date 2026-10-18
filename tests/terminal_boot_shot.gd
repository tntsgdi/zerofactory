extends SceneTree
# Stills of the terminal's power-on self-test (P.7, 2026-10-18) at six moments,
# from a test career. tools/run_test.sh tests/terminal_boot_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_boot_career.json"
	SaveGame.path = "user://zp_test_boot_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _run() -> void:
	Career.data = {}
	Career.start_new()
	Career.data.done = 1
	Career.data.money = 41250.0
	Career.data.active = {}
	Career.data.market = true
	Career.data.story_job = Career.opening(1)
	Career.data.offers = []
	Career.data.seen = {"market": true}
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await process_frame
	# the tests' terminal comes up at once; run the self-test from the start
	term.boot_t = 0.0
	term.deal_t = 0.0
	var marks := [0.15, 0.5, 0.8, 1.1, 1.4, 1.95]
	var t := 0.0
	var k := 0
	while k < marks.size():
		await process_frame
		t += 1.0 / 60.0
		if term.boot_t >= marks[k]:
			Cap.save(root, "res://tests/out/tboot_%d.png" % k)
			k += 1
	print("BOOT done at %.2f s" % term.boot_t)
	quit()
