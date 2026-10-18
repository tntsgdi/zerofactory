extends SceneTree
# What breaks when the berth runs with no ship in it (2026-10-18). Test files only.
# tools/run_test.sh tests/berth_empty_probe.gd --fixed-fps 60
func _initialize() -> void:
	Career.path = "user://zp_test_berthempty_career.json"
	SaveGame.path = "user://zp_test_berthempty_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _run() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.done = 4
	Career.data.certified = true
	Career.data.money = 41250.0
	Career.save()
	Game.start_ship = "berth"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2(1, 0)}
	root.add_child(g)
	for i in 240:
		await process_frame
	print("EMPTY state %s, pieces %d, drone alive %s at %s, consoles %s" % [g.state, g.world.pieces.size(), g.drone.alive, g.drone.global_position.round(), g.consoles != null])
	quit()
