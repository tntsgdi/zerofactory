extends SceneTree
# A close look at what a laser cut leaves (world.gd's kerf edges): a curved kerf
# through a piece of equipment and the plate behind it on ES-112, fresh and cooled.
# tools/run_test.sh tests/cut_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_cutshot_career.json"
	SaveGame.path = "user://zp_test_cutshot_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "es112"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	# the biggest piece of equipment near the middle of the ship, and whatever it stands on
	var best = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.cls != "equip" or p.body != null:
			continue
		var bb := Geom.bbox(p.poly)
		if bb.size.x < 2.0 * Geom.M or bb.size.y < 1.2 * Geom.M:
			continue
		if best == null or bb.get_area() > Geom.bbox(best.poly).get_area():
			best = p
	var bb2 := Geom.bbox(best.poly)
	var c := bb2.get_center()
	# a curved kerf across it, as a hand would sweep the laser
	var pl := PackedVector2Array()
	for k in 13:
		var f: float = k / 12.0
		pl.append(Vector2(bb2.position.x - 20.0 + f * (bb2.size.x + 40.0), c.y - bb2.size.y * 0.35 + sin(f * PI) * bb2.size.y * 0.6))
	g.world.commit_cut(best, pl)
	var pl2 := PackedVector2Array([Vector2(c.x + bb2.size.x * 0.15, bb2.position.y - 20.0), Vector2(c.x - bb2.size.x * 0.1, bb2.end.y + 30.0)])
	for id in g.world.order.duplicate():
		var q = g.world.pieces[id]
		if not q.gone and q.body == null and Geom.bbox(q.poly).grow(4.0).intersects(Rect2(pl2[0], pl2[1] - pl2[0]).abs()):
			g.world.commit_cut(q, pl2)
	g.zoom_override = 1.6
	g.cam_override = c
	for i in 30:
		await process_frame
	Cap.save(root, "res://tests/out/cut_fresh.png")
	for i in 60 * 8:
		await process_frame
	Cap.save(root, "res://tests/out/cut_cooled.png")
	quit()
