extends SceneTree
# The 200 m berth, empty, the whole of it in view; and the equipment page with
# the two new extensions (fleet expansion 2026-10-19). Test career only.
# tools/run_test.sh tests/berth200_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Career.path = "user://zp_test_b200_career.json"
	SaveGame.path = "user://zp_test_b200_save.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _run() -> void:
	Career.data = Career.fresh()
	Career.data.active = {}
	Career.data.market = true
	Career.data.certified = true
	Career.data.money = 900000.0
	Career.data.upgrades = {"berth88": true, "berth120": true, "berth200": true}
	Career.save()
	Game.contract = {}
	Game.start_ship = "berth"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 30:
		await process_frame
	g.zoom_override = g.zoom_min()
	g.cam_override = Dock.centre() * 48.0
	for i in 60:
		await process_frame
	print("BERTH200 floor %.0f m, zoom_min %.2f" % [Dock.FLOOR_X1, g.zoom_min()])
	Cap.save(root, "res://tests/out/berth200.png")
	g.open_console("terminal")
	await process_frame
	g.console_ui.set_tab(1)
	for i in 40:
		await process_frame
	Cap.save(root, "res://tests/out/berth200_equip.png")
	quit()
