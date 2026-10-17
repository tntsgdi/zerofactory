extends SceneTree
# The H-22's mechanisms (scripts/mech.gd): the tow heads' residual field and
# the preloaded tow arms. The degauss control refuses while the coil supply
# is live and clears both heads once it is dead; a field probe reads it; a
# drone close to a live head is pulled in and knocked; the state survives a
# save. A pivot taken out with a locking pin still in, or with the
# accumulator still charged, springs the arm (incident, loss); with the pins
# out and the accumulator bled it comes out quietly.
# godot --headless --path . --fixed-fps 60 -s tests/mech_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_mech_save.json"
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
	Game.start_ship = "h22"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _joint(g, tag: String):
	for j in g.world.joints:
		if j.alive and j.get_meta("tag", "") == tag:
			return j
	return null


func _run() -> void:
	print("MECH: the tow heads")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "h22" and g.mech.mags.size() == 2, "the H-22 carries two magnet heads")
	check(absf(g.mech.field("TH-U") - 62.0) < 0.1 and absf(g.mech.field("TH-L") - 58.0) < 0.1, "residual field 62 / 58 mT")
	g.do_measure(_ctrl(g, "M-THU"))
	var r: Dictionary = g.sys.readings.get("M-THU", {})
	check(r.get("kind", "") == "field" and absf(float(r.get("val", 0.0)) - 62.0) < 0.5, "the probe reads the field (%s)" % r.get("text", "?"))
	g.do_wrench(_ctrl(g, "DEGAUSS"))
	check(g.mech.field("TH-U") > 50.0, "degauss refused while the coils are fed")
	g.do_wrench(_ctrl(g, "K-H"))
	g.do_wrench(_ctrl(g, "E-CAP"))
	var f := 0
	while g.sys.charge("CAP-H") > 0.002 and f < 60 * 40:
		f += 1
		await process_frame
	g.do_wrench(_ctrl(g, "DEGAUSS"))
	check(g.mech.field("TH-U") == 0.0 and g.mech.field("TH-L") == 0.0, "with the supply dead both heads are cleared")
	check(g.sys.stale(g.sys.readings["M-THU"]), "and the old probe reading has gone stale")
	SaveGame.save(g)
	var saved: Dictionary = g.mech.save_state()
	g.queue_free()
	await _frames(2)
	SaveGame.load_requested = true
	g = _game()
	await _frames(3)
	check(JSON.stringify(g.mech.save_state()) == JSON.stringify(saved) and g.mech.field("TH-U") == 0.0, "the degaussed heads come back degaussed from a save")
	g.queue_free()
	await _frames(2)
	SaveGame.clear()

	print("MECH: a live head pulls the drone")
	g = _game()
	await _frames(3)
	var th = g.world.tag("TH-U")
	var c: Vector2 = g.world.frame(th) * Geom.centroid(th.poly)
	await _frames(200)
	g.drone.global_position = c + Vector2(0, -2.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	var d0: float = g.drone.global_position.distance_to(c)
	await _frames(20)
	check(g.drone.global_position.distance_to(c) < d0 - 4.0, "the drone drifts in (%.2f → %.2f m)" % [d0 / Geom.M, g.drone.global_position.distance_to(c) / Geom.M])
	await _frames(180)
	var hit := false
	for i in g.incidents:
		hit = hit or i[1] == "magnet"
	check(hit, "and is knocked against the head: %s" % str(g.incidents))
	g.queue_free()
	await _frames(2)

	print("MECH: the preloaded arms")
	for case in [["pins in", false, false, true], ["pins out, accumulator charged", true, false, true], ["pins out, accumulator bled", true, true, false]]:
		g = _game()
		await _frames(3)
		if case[1]:
			for t in ["PIN-U1", "PIN-U2"]:
				g.world.kill_joint(_joint(g, t))
		if case[2]:
			g.sys.vols["ACC"].n = 50.0 * g.sys.vols["ACC"].V
		await _frames(2)
		var l0: float = g.losses
		g.world.kill_joint(_joint(g, "PIV-U"))
		await _frames(30)
		var fired := false
		for i in g.incidents:
			fired = fired or (i[1] == "preload" and i[2] == "PIV-U")
		check(fired == case[3] and (g.losses > l0) == case[3], "%s: the arm %s" % [case[0], "springs ($%d)" % int(g.losses - l0) if fired else "comes out quietly"])
		g.queue_free()
		await _frames(2)
	print("MECH %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
