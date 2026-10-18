extends SceneTree
var fails := 0
var counts := {"blueprint":0,"mouth":0,"belt":0,"light":0}
func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",message])
	if not ok: fails += 1
func _run() -> void:
	Txt.cfg_path = "user://zp_test_render_cache.cfg"
	Career.path = "user://zp_test_render_cache_career.json"
	SaveGame.path = "user://zp_test_render_cache_contract.json"
	Game.contract = {}
	Game.start_ship = "gr7"
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"mouth_rail":1}}
	root.add_child(g)
	await frames(5)
	g.drone.freeze = true
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_override = Vector2(21,0)*Geom.M
	g.zoom_override = .8
	g.zoom_now = .8
	g.blueprint.draw.connect(func(): counts.blueprint += 1)
	for node in g.dock.mouth_nodes.values(): node.draw.connect(func(): counts.mouth += 1)
	g.dock.draw.connect(func(): counts.belt += 1)
	g.dock.add_node.draw.connect(func(): counts.light += 1)
	await frames(30)
	var before: Dictionary = counts.duplicate()
	await frames(20)
	check(counts.mouth == before.mouth,"idle mouths reuse commands")
	check(counts.belt >= before.belt+19 and counts.light >= before.light+19,"belt and lamp animation keep rendering every frame")
	g.blueprint.toggle()
	await frames(150)
	var bp: int = counts.blueprint
	await frames(20)
	check(counts.blueprint == bp,"settled blueprint reuses commands")
	g.zoom_override = .65
	await frames(4)
	check(counts.blueprint > bp,"zoom refreshes native-size blueprint labels")
	before = counts.duplicate()
	Txt.zh = not Txt.zh
	await frames(3)
	check(counts.blueprint > before.blueprint and counts.mouth > before.mouth,"language refreshes blueprint and mouth signs")
	g.blueprint.note_points.append([Vector2.ZERO,"checked control","CACHE-TEST"])
	g.blueprint.notes = {"ctrls":{"CACHE-TEST":true}}
	await frames(3)
	bp = counts.blueprint
	g.changed["c:CACHE-TEST"] = true
	await frames(3)
	check(counts.blueprint > bp and g.blueprint.note_void("c:CACHE-TEST"),"changed engineering notes invalidate cached drawing")
	var mc: int = counts.mouth
	g.dock.zone_state.metal.glow = .9
	await frames(10)
	check(counts.mouth >= mc+9,"active mouth lamps preserve full animation")
	g.dock.move_mouth(18.0)
	var mx: float = Dock.metal_x
	mc = counts.mouth
	await frames(6)
	check(Dock.metal_x != mx and counts.mouth > mc,"rail movement refreshes the furnace position")
	g.blueprint.toggle()
	await frames(120)
	bp = counts.blueprint
	await frames(15)
	check(g.blueprint.k < .01 and counts.blueprint == bp,"closing clears blueprint and stops redraws")
	# The early callback restores an invalid published solver result before consumers.
	var b := FreeBody.new()
	b.world = g.world
	b._safe_transform = Transform2D(.2,Vector2(700,100))
	b._has_safe_transform = true
	root.add_child(b)
	b.global_transform = Transform2D(0.0,Vector2(NAN,NAN))
	b._physics_process(0.0)
	check(b.global_position == Vector2(700,100) and b.linear_velocity == Vector2.ZERO,"invalid physics pose recovers to last valid position")
	var pose := b.global_transform
	b.linear_velocity = Vector2(10,20)
	b._physics_process(0.0)
	check(b.global_transform == pose and b.linear_velocity == Vector2(10,20),"normal finite physics state stays unchanged")
	b.queue_free()
	g.queue_free()
	await frames(3)
	print("RENDER_CACHE ","PASS" if fails==0 else "FAIL"," failures=",fails)
	quit(0 if fails==0 else 1)
