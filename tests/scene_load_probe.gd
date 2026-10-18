extends SceneTree
# How long each scene change freezes the screen (2026-10-18 transition work):
# loading + building the scene, then its first frames. Test files only.
# tools/run_test.sh tests/scene_load_probe.gd
func _initialize() -> void:
	Career.path = "user://zp_test_loadprobe_career.json"
	SaveGame.path = "user://zp_test_loadprobe_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Career.data = {}
	Career.start_new()
	Career.save()
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	for path in ["res://scenes/title.tscn", "res://scenes/terminal.tscn", "res://scenes/main.tscn"]:
		var t0 := Time.get_ticks_usec()
		var ps: PackedScene = load(path)
		var t1 := Time.get_ticks_usec()
		var n := ps.instantiate()
		var t2 := Time.get_ticks_usec()
		root.add_child(n)
		var t3 := Time.get_ticks_usec()
		var frames: Array = []
		var last := t3
		for i in 6:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append(snappedf((now - last) / 1000.0, 0.1))
			last = now
		print("LOAD %s: load %.1f ms, build %.1f ms, enter tree %.1f ms, first frames %s" % [path.get_file(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, frames])
		n.queue_free()
		for i in 4:
			await process_frame
	quit()
