extends SceneTree
# PT-34 in its berth (fleet expansion 2026-10-19): the whole berth in view (taller
# for it: the boom, rail and equipment bays lifted over the bridge and radar, the
# floor, trough, furnace and hazard bay dropped under the belly gun), then the bow
# with the turret, the launch cells and the magazine close up. Test saves only.
# tools/run_test.sh tests/pt34_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
func _initialize() -> void:
	SaveGame.path = "user://zp_test_pt34shot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _run() -> void:
	Game.contract = {}
	Game.start_ship = "pt34"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 30:
		await process_frame
	g.zoom_override = g.zoom_min()
	g.cam_override = Dock.centre() * 48.0
	for i in 60:
		await process_frame
	print("PT34 berth %.0f m, lift %.1f drop %.1f, floor %.1f rail %.1f, zoom_min %.2f" % [Dock.FLOOR_X1, Dock.LIFT, Dock.DROP, Dock.FLOOR_Y, Dock.RAIL_Y, g.zoom_min()])
	Cap.save(root, "res://tests/out/pt34_berth.png")
	g.zoom_override = 0.55
	g.cam_override = Vector2(30.0, -1.0) * 48.0
	for i in 60:
		await process_frame
	Cap.save(root, "res://tests/out/pt34_bow.png")
	quit()
