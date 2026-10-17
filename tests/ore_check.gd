extends SceneTree
# M-14's mechanisms. Loose ore (scripts/ore.gd): the heap stays put behind
# closed gates; an open gate lets it run out into the trough, paid by the
# tonne, and the lumps over it come loose; a gate forced while the hopper is
# still full tears the hopper, the same gate forced once it is half empty does
# not; a bent gate (the gate_jam accident) will not open on its drive and shows
# it to an inspection. The crusher drum (6 t) cut along one of its marked lines
# comes apart into parts that are still whole equipment; cut anywhere else it is
# scrap. The belt (scripts/mech.gd): a tension gauge reads its load; cut while
# its tensioner is in, it springs and wrecks the screen; slacked first, it comes
# out quietly. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/ore_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ore_save.json"
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


func _game(job: Dictionary = {}) -> Node:
	Game.contract = job
	Game.start_ship = "m14"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _c(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _incident(g, kind: String) -> bool:
	for i in g.incidents:
		if i[1] == kind:
			return true
	return false


# a gate torn out: its welds cut, its hydraulic line with them
func _force(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


func _packed(g) -> int:
	var n := 0
	for j in g.world.joints:
		if j.alive and j.type == "pack":
			n += 1
	return n


func _seconds(s: float) -> void:
	Engine.time_scale = 4.0
	await _frames(int(s * 60.0 / 4.0))
	Engine.time_scale = 1.0


func _run() -> void:
	print("ORE: the heap")
	var g = await _game()
	await _frames(3)
	var f0: float = g.ore.fines
	check(f0 > 30.0 and g.ore.value_left() > 25000.0, "the hopper holds %.0f t of fines ($%d)" % [f0, int(g.ore.value_left())])
	await _seconds(5.0)
	check(g.ore.fines == f0, "behind closed gates it stays put")
	var p0: int = _packed(g)
	var m0: float = g.income_metal
	g.do_wrench(_c(g, "GATE-1"))
	await _seconds(12.0)
	check(g.ore.fines < f0 - 4.0 and g.income_metal > m0 + 4000.0, "GATE-1 open: %.0f t out, $%d paid as it runs" % [f0 - g.ore.fines, int(g.income_metal - m0)])
	check(_packed(g) < p0, "the lumps over it come loose (%d of %d still packed)" % [_packed(g), p0])
	g.do_wrench(_c(g, "GATE-2"))
	await _seconds(40.0)
	check(g.ore.fines <= 0.01 and not _incident(g, "hopper_tear"), "both open: the hopper empties, nothing torn")
	g.queue_free()
	await _frames(2)

	print("ORE: a gate forced with the hopper full")
	g = await _game()
	await _frames(3)
	var l0: float = g.losses
	_force(g, "GATE-2")
	await _frames(10)
	var torn := 0
	for jt in ["HT-1", "HT-2", "HT-3", "HT-4"]:
		var alive := false
		for j in g.world.joints:
			if j.alive and j.get_meta("tag", "") == jt:
				alive = true
		if not alive:
			torn += 1
	check(_incident(g, "hopper_tear") and g.losses >= l0 + 8000.0 and torn == 4, "it all goes one way: the hopper's welds tear (%d), $%d" % [torn, int(g.losses - l0)])
	g.queue_free()
	await _frames(2)

	print("ORE: the same gate forced once the hopper is half empty")
	g = await _game()
	await _frames(3)
	g.do_wrench(_c(g, "GATE-1"))
	while g.ore.fines > 0.45 * g.ore.fines0:
		await _seconds(1.0)
	_force(g, "GATE-2")
	await _frames(10)
	check(not _incident(g, "hopper_tear"), "no tear (%.0f t left of %.0f)" % [g.ore.fines, g.ore.fines0])
	g.queue_free()
	await _frames(2)

	print("ORE: a bent gate")
	var job := Market.offer_for(31, {"rep": 30, "done": 6}, 1, "full", "m14")
	job.traps = ["gate_jam"]
	job.dev = true
	g = await _game(job)
	await _frames(3)
	var bent: String = g.ship.variant.targets.gate_jam
	g.do_wrench(_c(g, bent))
	await _frames(3)
	check(not g.world.tag(bent).door_open, "%s will not open on its drive" % bent)
	check(g._inspect_text(g.world.tag(bent)).find(Txt.t("insp_stuck")) >= 0, "and an inspection shows it bent")
	g.queue_free()
	await _frames(2)

	print("ORE: the crusher drum's marked lines")
	g = await _game()
	await _frames(3)
	var dr = g.world.tag("CRUSH-H")
	var v0: float = dr.value
	var sg: Array = dr.get_meta("segments")[0]
	g.cut_kerf(dr, PackedVector2Array([Vector2(sg[0], sg[1]) * Geom.M, Vector2(sg[2], sg[3]) * Geom.M]))
	await _frames(3)
	var parts: Array = []
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and (q.tag == "CRUSH-H" or q.tag.begins_with("CRUSH-H-")):
			parts.append(q)
	var vsum := 0.0
	var all_whole := true
	var heaviest := 0.0
	for q in parts:
		vsum += q.value
		all_whole = all_whole and q.intact
		heaviest = maxf(heaviest, q.mass)
	check(parts.size() == 2 and all_whole and vsum > 0.85 * v0 and not _incident(g, "equip_cut"), "cut along a line: %d whole parts worth $%d of $%d" % [parts.size(), int(vsum), int(v0)])
	var sg2: Array = dr.get_meta("segments")[1]
	var on = g.world.piece_at(Vector2((sg2[0] + sg2[2]) * 0.5, (sg2[1] + sg2[3]) * 0.5) * Geom.M)
	g.cut_kerf(on, PackedVector2Array([Vector2(sg2[0], sg2[1]) * Geom.M, Vector2(sg2[2], sg2[3]) * Geom.M]))
	await _frames(3)
	heaviest = 0.0
	var n := 0
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and q.intact and (q.tag == "CRUSH-H" or q.tag.begins_with("CRUSH-H-")):
			heaviest = maxf(heaviest, q.mass)
			n += 1
	check(n == 3 and heaviest < 3.0, "both lines: three whole parts, the heaviest %.1f t (the 3 t grapple takes it)" % heaviest)
	g.queue_free()
	await _frames(2)
	g = await _game()
	await _frames(3)
	dr = g.world.tag("CRUSH-H")
	var c: Vector2 = g.world.frame(dr) * Geom.centroid(dr.poly)
	g.cut_kerf(dr, PackedVector2Array([c + Vector2(-3, 0) * Geom.M, c + Vector2(3, 0) * Geom.M]))
	await _frames(3)
	check(not g.world.tag("CRUSH-H").intact and _incident(g, "equip_cut"), "cut across its lines instead: scrap")
	g.queue_free()
	await _frames(2)

	print("ORE: the belt under tension")
	g = await _game()
	await _frames(3)
	g.do_measure(_c(g, "TN-1"))
	var r: Dictionary = g.sys.readings.get("TN-1", {})
	check(float(r.get("val", 0.0)) > 30.0 and str(r.get("text", "")).ends_with("kN"), "the gauge reads its load (%s)" % r.get("text", "?"))
	var scr_c: float = g.world.tag("SCR").cond
	for j in g.world.joints:
		if j.alive and j.get_meta("tag", "") == "BELT-A":
			g.world.kill_joint(j)
	await _frames(20)
	check(_incident(g, "preload") and g.world.tag("SCR").cond < scr_c, "cut with the tensioner in: it springs and wrecks the screen (%.0f%%)" % (g.world.tag("SCR").cond * 100.0))
	g.queue_free()
	await _frames(2)
	g = await _game()
	await _frames(3)
	for j in g.world.joints:
		if j.alive and j.get_meta("tag", "") == "TEN-1":
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	g.do_measure(_c(g, "TN-1"))
	check(float(g.sys.readings["TN-1"].val) < 1.0, "the tensioner out: the gauge reads nothing")
	for j in g.world.joints:
		if j.alive and j.get_meta("tag", "") == "BELT-A":
			g.world.kill_joint(j)
	await _frames(20)
	check(not _incident(g, "preload"), "then the belt comes out quietly")
	g.queue_free()
	await _frames(2)
	print("ORE %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
