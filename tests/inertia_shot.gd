extends SceneTree
# Strict inertia (player 2026-10-18): stills of the tug bringing the ship in —
# main burn while it speeds up, retro burns while it slows, retros pulling it
# away — and the tug's acceleration sign at each. Test files only.
# tools/run_test.sh tests/inertia_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var g
var fails := 0

func _initialize() -> void:
	Career.path = "user://zp_test_inertia_career.json"
	SaveGame.path = "user://zp_test_inertia_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": false, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	_run()

func _run() -> void:
	for want in [[1.0, -1, "speeding"], [2.6, 1, "slowing"], [4.0, 1, "leaving"]]:
		while g.state != "intro" or g.state_t < want[0]:
			await process_frame
			if g.state == "play":
				break
		var ax: float = g.dock.tug_accel()
		var ok := signf(ax) == float(want[1])
		if not ok:
			fails += 1
		print("%s tug %s at %.1f s: acceleration %.0f px/s² (%s)" % ["PASS" if ok else "FAIL", want[2], g.state_t, ax, "main burn" if ax < 0 else "retro burn"])
		Cap.save(root, "res://tests/out/tug_%s.png" % want[2])
	print("INERTIA %s" % ("PASS" if fails == 0 else "FAIL"))
	quit()
