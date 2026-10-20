extends SceneTree
# EV-55 "Fire-Eye"'s heat (scripts/thermal.gd): the zones hot at the start; a hot tile
# cut shatters; equipment freed from the hot instrument module is heat-damaged; the
# drone burns by the shield; everything cools, four times faster on the berth's loop;
# cooled, the same work is clean.
# godot --headless --path . --fixed-fps 60 -s tests/ev55_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ev55_save.json"
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


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "ev55"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _free(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


func _run() -> void:
	print("EV-55: straight back from perihelion")
	var g = _game()
	await _frames(3)
	var th = g.thermal
	check(th.active() and th.zone_temp("TILES") > 800.0 and th.zone_temp("I") > 180.0, "tiles %.0f °C, frame %.0f, instruments %.0f, habitat %.0f" % [th.zone_temp("TILES"), th.zone_temp("FRAME"), th.zone_temp("I"), th.zone_temp("H")])
	g.do_measure(_ctrl(g, "T-TILE"))
	check(str(g.sys.readings.get("T-TILE", {}).get("text", "")).begins_with("8"), "the shield's thermometer reads %s" % g.sys.readings.get("T-TILE", {}).get("text", "?"))
	var tl = g.world.tag("TILE-U3")
	g.on_cut_into(tl, g.world.frame(tl) * Geom.centroid(tl.poly))
	await _frames(3)
	check(_has(g, "tile_shatter") and not tl.intact, "a tile cut at 800 °C shatters")
	_free(g, "SPEC-1")
	await _frames(6)
	check(_has(g, "heat_spoil") and g.world.tag("SPEC-1").cond <= 0.5, "a spectrometer taken out of the instrument module at 190 °C is heat-damaged")
	# the drone by the shield
	var hp0: float = g.drone.integrity
	g.drone.global_position = Vector2(4.0, 0.0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(60)
	check(g.drone.integrity < hp0, "the drone by the 800 °C shield is burnt (%.0f -> %.0f)" % [hp0, g.drone.integrity])
	# cooling on its own
	var t0: float = th.zone_temp("TILES")
	await _frames(60 * 30)
	var dn: float = t0 - th.zone_temp("TILES")
	check(dn > 10.0, "on its own the shield cools %.0f °C in 30 s" % dn)
	check(th.save_state().temp.has("TILES"), "the zones' temperatures are saved")
	g.queue_free()
	await _frames(2)

	print("EV-55: on the berth's cooling")
	g = _game()
	await _frames(3)
	th = g.thermal
	g.do_wrench(_ctrl(g, "COOL-S"))
	t0 = th.zone_temp("TILES")
	await _frames(60 * 30)
	var dl: float = t0 - th.zone_temp("TILES")
	check(dl > dn * 2.5, "plugged into the berth's loop it cools %.0f °C in 30 s" % dl)
	var n := 0
	while th.zone_temp("TILES") > 150.0 and n < 60 * 600:
		await _frames(60)
		n += 60
	check(th.unsafe().is_empty(), "every zone under 150 °C after %.0f s" % (n / 60.0 + 30.0))
	tl = g.world.tag("TILE-L2")
	g.on_cut_into(tl, g.world.frame(tl) * Geom.centroid(tl.poly))
	_free(g, "SPEC-2")
	await _frames(6)
	check(not _has(g, "tile_shatter") and not _has(g, "heat_spoil"), "cooled: a tile cut and a spectrometer freed, both whole")
	g.queue_free()
	await _frames(2)
	print("EV55 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
