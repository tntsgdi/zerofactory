extends SceneTree
# The ARK stress ship in the 620 m berth: the whole berth in view, a close look at the
# floor lamps and belt (drawn only where the camera looks), and the same spot after a
# plate is taken off and a bolt killed there (only the strips nearby redraw).
# tools/run_test.sh tests/ark_shot.gd --fixed-fps 60 -- [ship]
const Cap = preload("res://tests/cap.gd")
func _initialize() -> void:
	Career.path = "user://zp_test_arkshot_career.json"
	SaveGame.path = "user://zp_test_arkshot_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Game.contract = {}
	Game.start_ship = args[0] if args.size() > 0 else "arktest"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 30:
		await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	for i in 60:
		await process_frame
	g.zoom_override = 1800.0 / ((Dock.FLOOR_X1 + 20.0) * Geom.M)
	g.cam_override = Dock.centre() * 48.0
	for i in 150:
		await process_frame
	Cap.save(root, "res://tests/out/ark_whole.png")
	var M := Geom.M
	var at := Vector2(Dock.FLOOR_X1 * 0.5, 2.0)
	g.zoom_override = 0.55
	g.cam_override = at * M
	for i in 40:
		await process_frame
	Cap.save(root, "res://tests/out/ark_close.png")
	# take off what's nearest the view's centre, and kill a bolt beside it
	var best = null
	var bd := INF
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.kind != "hull":
			continue
		var d: float = Geom.centroid(p.poly).distance_to(at * M)
		if d < bd:
			bd = d
			best = p
	if best != null:
		for j in g.world.joints_of(best):
			if j.alive and j.type == "bolt":
				g.world.kill_joint(j)
				break
		g.world.remove_piece(best)
	for i in 90:
		await process_frame
	Cap.save(root, "res://tests/out/ark_close_cut.png")
	print("ARK SHOT done (removed %s)" % (best.tag if best != null else "-"))
	quit()
