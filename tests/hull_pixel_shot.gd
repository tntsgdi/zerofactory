extends SceneTree
# One still of a hull at a fixed view, for comparing its drawing before and after a change.
# tools/run_test.sh tests/hull_pixel_shot.gd --fixed-fps 60 -- ship=med47 out=name
const Cap = preload("res://tests/cap.gd")
func _initialize() -> void:
	Career.path = "user://zp_test_hullpx_career.json"
	SaveGame.path = "user://zp_test_hullpx_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _run() -> void:
	var ship := "med47"
	var out := "hull"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="): ship = a.substr(5)
		if a.begins_with("out="): out = a.substr(4)
	Career.data = Career.fresh()
	Career.data.upgrades = {"berth88": true}
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 30:
		await process_frame
	g.drone.alive = false
	g.zoom_override = 0.55
	g.cam_override = Vector2(42.0 * 48.0, -1.0 * 48.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			g.zoom_override = float(a.substr(5))
		if a.begins_with("at="):
			var xy := a.substr(3).split(",")
			g.cam_override = Vector2(float(xy[0]), float(xy[1])) * 48.0
	if "open" in OS.get_cmdline_user_args():
		for n in g.world.rooms:
			g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	for i in 90:
		await process_frame
	Cap.save(root, "res://tests/out/%s.png" % out)
	quit()
