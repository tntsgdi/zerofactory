extends SceneTree
# Biological contamination (scripts/bio.gd, Systems.bio), on MED-47. An
# isolation pod starts with dirty air and the corridor clean; the pod's air
# sampler reads it. Its negative pressure keeps the corridor clean when its
# hatch opens. A biohazard box moved unsealed spills (incident, clean-up
# charged); sealed first, it moves cleanly. A pod whose negative pressure has
# failed blows its air into the corridor when the hatch opens: what is in the
# corridor is marked down. Drawn off through the recovery hose (its filter)
# first, the same pod opens without harm. Seals and spills survive a save.
# Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/bio_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_bio_save.json"
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
	Game.start_ship = "med47"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _c(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _free(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


func _incident(g, kind: String) -> bool:
	for i in g.incidents:
		if i[1] == kind:
			return true
	return false


# the isolation pod U3 with its negative pressure gone: above the corridor, dirtier
func _breach(g) -> void:
	var s = g.sys
	s.vols["U3"].n = 115.0 * s.vols["U3"].V
	s.bio["U3"] = 3.5 * s.vols["U3"].V


func _open_hatch(g, id: String) -> void:
	g.do_wrench(_c(g, id))
	await _frames(240)


func _run() -> void:
	print("BIO: as it comes in")
	var g = await _game()
	await _frames(3)
	check(Dock.floor_end == Dock.EXTENDED, "an 82 m ship gets the extended berth (%.0f m)" % Dock.floor_end)
	check(absf(g.sys.bio_index("U3") - 1.0) < 0.01 and g.sys.bio_index("K1") == 0.0 and g.sys.bio_index("U1") == 0.0, "U3's air is dirty (%.2f), the corridor and the other pods clean" % g.sys.bio_index("U3"))
	check(g.sys.P("U3") < g.sys.P("K1") - 5.0, "U3 is held below the corridor (%.0f / %.0f kPa)" % [g.sys.P("U3"), g.sys.P("K1")])
	g.do_measure(_c(g, "S-U3"))
	var r: Dictionary = g.sys.readings.get("S-U3", {})
	check(r.get("kind", "") == "bio" and absf(float(r.get("val", 0.0)) - 1.0) < 0.05, "the air sampler by U3's hatch reads it (%s)" % r.get("text", "?"))
	await _open_hatch(g, "DR-U3")
	check(g.world.tag("DR-U3").door_open and g.sys.bio_index("K1") < 0.02 and not g.world.tag("ECAB-1").contam, "its hatch opened: air flows in, the corridor stays clean (K1 %.3f)" % g.sys.bio_index("K1"))
	# a box moved unsealed
	var l0: float = g.losses
	var i0: float = g.sys.bio_index("U3")
	_free(g, "BIO-U3")
	await _frames(5)
	check(_incident(g, "bio") and g.losses > l0 and g.bio.spilt.has("BIO-U3") and g.sys.bio_index("U3") + g.sys.bio_index("K1") * g.sys.vols["K1"].V / g.sys.vols["U3"].V > i0 + 1.0,
		"BIO-U3 freed unsealed: it spills (incident, $%d)" % int(g.losses - l0))
	g.queue_free()
	await _frames(2)

	print("BIO: sealed first")
	g = await _game()
	await _frames(3)
	g.world.reveal("U3", g.world.rooms.U3.from)
	g.do_wrench(_c(g, "SB-U3"))
	check(g.bio.is_sealed("BIO-U3") and g.world.ctrls["SB-U3"].state, "SB-U3 seals the box")
	_free(g, "BIO-U3")
	await _frames(5)
	check(not _incident(g, "bio") and g.losses == 0.0, "sealed, it comes away clean")
	SaveGame.save(g)
	g.queue_free()
	await _frames(2)
	SaveGame.load_requested = true
	g = await _game()
	await _frames(3)
	check(g.bio.is_sealed("BIO-U3"), "the seal survives a save")
	g.queue_free()
	await _frames(2)
	SaveGame.clear()

	print("BIO: a pod that lost its negative pressure")
	g = await _game()
	await _frames(3)
	_breach(g)
	await _open_hatch(g, "DR-U3")
	await _frames(120)
	check(g.sys.bio_index("K1") > Bio.THRESHOLD and g.world.tag("ECAB-1").contam and _incident(g, "bio_spread"),
		"its hatch opened: its air blows into the corridor (K1 %.2f), the corridor's equipment is marked down" % g.sys.bio_index("K1"))
	g.queue_free()
	await _frames(2)

	print("BIO: the same pod drawn off through the hose first")
	g = await _game()
	await _frames(3)
	_breach(g)
	g.do_hose(_c(g, "G-U3"))
	var f := 0
	while g.sys.P("U3") > 2.0 and f < 60 * 120:
		f += 1
		await process_frame
	check(g.sys.P("U3") <= 2.0 and g.sys.bio_vented < 0.01, "U3 drawn down to %.1f kPa through the filter (nothing vented)" % g.sys.P("U3"))
	await _open_hatch(g, "DR-U3")
	await _frames(120)
	check(g.sys.bio_index("K1") < Bio.THRESHOLD and not g.world.tag("ECAB-1").contam and not _incident(g, "bio_spread"), "then its hatch opens without harm (K1 %.3f)" % g.sys.bio_index("K1"))
	g.queue_free()
	await _frames(2)
	print("BIO %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
