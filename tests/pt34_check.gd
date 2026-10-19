extends SceneTree
# PT-34 "Falcon"'s own mechanisms (scripts/munitions.gd, the isolated capacitors in
# scripts/systems.gd, the thrust-vector rams in scripts/mech.gd, armour in world.gd).
# The beam working near a round heats it until it cooks off, and a blast sets the
# live rounds round it off one after another; the magazine's flood valve wets every
# round in it (safe under the beam, worth nothing, and no chain through them); a
# loose round knocked hard goes off, one a recovery mouth is braking does not.
# The weapon capacitors keep the weapons' panel live with grid A off and only their
# own discharge point bleeds them. A ram's live control line cut with its lock off
# jerks it (incident, loss); locked, it comes away quietly. Armour plates say so on
# inspection. The munitions state survives a save.
# godot --headless --path . --fixed-fps 60 -s tests/pt34_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_pt34_save.json"
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
	Game.start_ship = "pt34"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _c(g, tag: String) -> Vector2:
	var p = g.world.tag(tag)
	return g.world.frame(p) * Geom.centroid(p.poly)


func _blasts(g) -> Array:
	return g.incidents.filter(func(i): return i[1] == "blast").map(func(i): return i[2])


func _run() -> void:
	var g = _game()
	await _frames(3)
	var mu = g.munitions
	print("PT-34: munitions")
	check(g.ship_id == "pt34" and mu.active(), "the PT-34 carries live munitions")
	# the magazine flooded: every round in it wet
	g.do_wrench(_ctrl(g, "FLV"))
	var sh = g.world.tag("SH-207")
	var wet_n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.room == "MAG" and p.hazard == "explosive" and mu.wet.has(p.id):
			wet_n += 1
	check(wet_n == 39 and sh.value == 0.0, "the flood valve wets all 39 rounds in the magazine, worth nothing now (%d)" % wet_n)
	for i in 120:
		mu.heat(_c(g, "SH-207"), 1.0 / 60.0 * 4.0)
	check(not mu._pending(sh.id) and sh.temp <= 20.0, "a wet round doesn't heat under the beam")
	check(g._inspect_text(sh).contains(Txt.t("j_wet")), "inspection says it is wet")
	g.on_cut_into(sh, _c(g, "SH-207"))
	await _frames(2)
	check(_blasts(g).is_empty(), "nor goes off when it is cut into")
	# the beam near a live missile: it heats and cooks off, and its neighbours follow
	var ms = g.world.tag("MSL-3")
	var t := 0.0
	while not mu._pending(ms.id) and t < 12.0:
		mu.heat(_c(g, "MSL-3") + Vector2(0.4, 0) * Geom.M, 1.0 / 60.0)
		t += 1.0 / 60.0
	check(mu._pending(ms.id) and t > 3.0 and t < 8.0, "a missile under the beam cooks off after %.1f s" % t)
	g.do_measure(_ctrl(g, "MT-H"))
	await _frames(90)
	var bl := _blasts(g)
	check(bl.has("MSL-3") and bl.has("MSL-2") and bl.has("MSL-4"), "and sets off the cells beside it: %s" % [bl])
	check(not bl.any(func(x): return str(x).begins_with("SH-")), "the wet magazine doesn't follow")
	check(not g.world.tag("MSL-3").intact, "the round is spent")
	# a loose round knocked hard
	var dr = g.world.tag("DRUM-1")
	for j in g.world.joints_of(dr):
		g.world.kill_joint(j)
	await _frames(3)
	check(dr.body != null, "a close-in drum comes loose")
	var before := _blasts(g).size()
	if dr.body != null:
		dr.body.capture = "hazard"
		dr.body.linear_velocity = Vector2(600, 0)
		await physics_frame
		dr.body.linear_velocity = Vector2.ZERO
		await _frames(30)
		check(_blasts(g).size() == before, "braked by a recovery mouth's catch, it stays quiet")
		dr.body.capture = null
		dr.body.linear_velocity = Vector2(600, 0)
		await physics_frame
		await physics_frame
		dr.body.linear_velocity = Vector2.ZERO
		await _frames(30)
		check(_blasts(g).has("DRUM-1"), "knocked to a stop from 12 m/s, it goes off")
	# save and load: what is wet and spent stays so
	var st: Dictionary = mu.save_state()
	check(st.get("flooded", []).has("MAG") and st.get("wet", []).size() >= 39, "the save keeps the flooded magazine")
	g.queue_free()
	await _frames(2)

	print("PT-34: capacitors, rams, armour")
	g = _game()
	await _frames(3)
	var s = g.sys
	g.do_wrench(_ctrl(g, "K-A"))
	await _frames(10)
	check(not s.bus_live, "the outside panel's breaker kills grid A")
	check(s.piece_volts(g.world.tag("WDIST")) > 500.0, "the weapons' panel stays live off its capacitors (%.0f V)" % s.piece_volts(g.world.tag("WDIST")))
	check(s.piece_volts(g.world.tag("DIST-B")) > 300.0, "and grid B runs on (%.0f V)" % s.piece_volts(g.world.tag("DIST-B")))
	g.do_wrench(_ctrl(g, "WD-1"))
	g.do_wrench(_ctrl(g, "WD-2"))
	var f := 0
	while (s.iso["WCAP-1"].charge > 0.01 or s.iso["WCAP-2"].charge > 0.01) and f < 60 * 20:
		f += 1
		await process_frame
	await _frames(5)
	check(s.piece_volts(g.world.tag("WDIST")) < 1.0, "bled at their own discharge points they read dead (%.1f s)" % (f / 60.0))
	# the rams: ct1 cut live and unlocked, ct2 locked first
	g.world.kill_line(g.world.lines["ct1"])
	await _frames(20)
	var acts: Array = g.incidents.filter(func(i): return i[1] == "actuator")
	check(acts.size() == 1, "ram 1's live line cut with its lock off: the ram jerks (%s)" % [acts])
	g.do_wrench(_ctrl(g, "LK-T2"))
	await _frames(2)
	g.world.kill_line(g.world.lines["ct2"])
	await _frames(20)
	acts = g.incidents.filter(func(i): return i[1] == "actuator")
	check(acts.size() == 1, "ram 2 locked first comes away quietly")
	# armour
	var ar = g.world.tag("AR3-5")
	check(g._inspect_text(ar).contains(Txt.t("j_armor")) or g._inspect_text(ar).contains(Txt.t("j_armor_fix").split("%")[0]), "an armour plate says so when inspected")
	check(ar.cut_speed < 60.0, "armour cuts slowly (%.0f against hull plate's 220)" % ar.cut_speed)
	for hf in ["HF-1", "HF-2"]:
		var hj = null
		for j in g.world.joints:
			if j.get_meta("tag", "") == hf:
				hj = j
		var cover = null
		for c in g.world._cover_list():
			if c.id != hj.a and c.id != hj.b and Geometry2D.is_point_in_polygon(g.world.joint_world(hj), c.poly):
				cover = c
		check(hj != null and g.world.joint_covered(hj) and cover != null, "%s is hidden under the next armour plate (%s)" % [hf, cover.tag if cover != null else "?"])
		if cover != null:
			check(g.world.fixings_behind(cover) >= 1, "which knows it hides %d fixing(s)" % g.world.fixings_behind(cover))
	g.queue_free()
	await _frames(2)
	print("PT34 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
