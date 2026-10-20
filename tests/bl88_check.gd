extends SceneTree
# BL-88 "Floating Isle"'s water ball (scripts/waterball.gd) and dome (scripts/liner.gd's
# glazing): the net cut with the ball full, it bursts, soaking the room's electrics
# and losing the fish; pumped down first, the net and its frame come away cleanly; a
# dome pane freed with air in the dome blows out.
# godot --headless --path . --fixed-fps 60 -s tests/bl88_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_bl88_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	Engine.time_scale = 8.0
	await _frames(int(s * 60.0 / 8.0))
	Engine.time_scale = 1.0


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "bl88"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _free(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


func _cond(g, tag: String) -> float:
	return g.world.tag(tag).cond


func _run() -> void:
	print("BL-88: the ball burst")
	var g = _game()
	await _frames(3)
	var wb = g.waterball
	check(wb.active() and wb.held() and g.sys.fluid("ball") > 7.0, "the ball full in its net (%.1f m³)" % g.sys.fluid("ball"))
	var net = g.world.tag("NET-T")
	g.on_cut_into(net, Geom.bbox(g.world.world_poly(net)).get_center())
	await _frames(4)
	check(_count(g, "water_ball_burst") == 1 and g.sys.fluid("ball") < 0.01, "the net cut with the ball full: it bursts, the water lost")
	check(_cond(g, "WP") <= 0.31 and _cond(g, "FEED") <= 0.31 and _cond(g, "ECO") > 0.99, "the room's electrics shorted (bus live), the dome's untouched")
	check(_cond(g, "FISH-T") <= 0.21, "the fish lost (%.2f)" % _cond(g, "FISH-T"))
	check(wb.save_state().burst, "the burst is saved")
	g.queue_free()
	await _frames(2)

	print("BL-88: pumped down first")
	g = _game()
	await _frames(3)
	wb = g.waterball
	g.do_hose(_ctrl(g, "PW"))
	var n := 0
	while wb.held() and n < 60 * 400:
		await _secs(5.0)
		n += 300
	check(not wb.held() and n < 60 * 240, "drawn at its port, the ball is down to %.0f %% in %.0f s" % [wb.level() * 100.0, n / 60.0])
	for t in ["NET-T", "FR-1", "FR-2"]:
		_free(g, t)
	await _frames(6)
	check(_count(g, "water_ball_burst") == 0 and _cond(g, "WP") > 0.99 and _cond(g, "FISH-T") > 0.99, "then the net and its frame come away: nothing soaked, the fish safe")
	check(g.sys.fluid_rec.get("water", 0.0) > 6.0, "and the water is recovered (%.1f m³)" % g.sys.fluid_rec.get("water", 0.0))
	g.queue_free()
	await _frames(2)

	print("BL-88: the dome")
	g = _game()
	await _frames(3)
	_free(g, "GL-8")
	await _frames(6)
	check(g.liner.blown.has("GL-8"), "a dome pane freed with the dome at %.0f kPa: blown out" % g.sys.P("D"))
	g.queue_free()
	await _frames(2)
	print("BL88 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
