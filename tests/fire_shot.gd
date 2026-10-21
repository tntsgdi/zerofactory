extends SceneTree
# Stills of fire (scripts/combustion.gd): VT-80's MMH and N₂O₄ tanks cut open together
# (the sprays meeting in vacuum), and a fuel spill lit in its pump room's air.
# tools/run_test.sh tests/fire_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const M := 48.0


func _initialize() -> void:
	Career.path = "user://zp_test_fireshot_career.json"
	SaveGame.path = "user://zp_test_fireshot_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "vt80"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	var w := 0
	while str(g.state) != "play" and w < 60 * 30:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(-60.0, -60.0) * M
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	return g


func _run() -> void:
	var g = await _game()
	var t1 = g.world.tag("T-1")
	var t2 = g.world.tag("T-2")
	var c1: Vector2 = g.world.frame(t1) * Geom.centroid(t1.poly)
	var c2: Vector2 = g.world.frame(t2) * Geom.centroid(t2.poly)
	g.cam_override = (c1 + c2) * 0.5 + Vector2(0, 2.0 * M)
	g.zoom_override = 0.55
	await _frames(40)
	Cap.save(root, "res://tests/out/fire_0_before.png")
	g.cut_kerf(t1, PackedVector2Array([c1 + Vector2(6.0, -2.0) * M, c1 + Vector2(6.5, 1.0) * M]))
	g.cut_kerf(t2, PackedVector2Array([c2 + Vector2(-6.0, -2.0) * M, c2 + Vector2(-6.5, 1.0) * M]))
	await _frames(14)
	Cap.save(root, "res://tests/out/fire_1_spray.png")
	var w := 0
	while g.combustion.burning == 0 and w < 240:
		await process_frame
		w += 1
	await _frames(4)
	Cap.save(root, "res://tests/out/fire_2_hyper.png")
	await _frames(60 * 3)
	Cap.save(root, "res://tests/out/fire_3_after.png")
	g.queue_free()
	await _frames(3)
	g = await _game()
	var rp: Vector2 = g.world.rooms["P"].bbox.get_center()
	g.cam_override = rp
	g.zoom_override = 1.1
	for i in 5:
		g.liquids.spill(rp + Vector2(i * 0.9 - 1.8, randf_range(-0.5, 0.5)) * M, Vector2.from_angle(randf() * TAU), 0.003, "fuel", 1, 0.0, 0.15, false)
	await _frames(40)
	Cap.save(root, "res://tests/out/fire_4_spill_air.png")
	g.combustion.spark(rp + Vector2(-1.8, 0) * M, 0.4)
	await _frames(10)
	Cap.save(root, "res://tests/out/fire_5_lit_air.png")
	await _frames(20)
	Cap.save(root, "res://tests/out/fire_6_blast_air.png")
	quit()
