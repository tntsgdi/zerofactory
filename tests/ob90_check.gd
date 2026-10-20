extends SceneTree
# OB-90 "Sky-Eye"'s primary mirror (scripts/optics.gd): a cut by the mirror dusts the
# segments near it, not with the cover down; an actuator lock needs the cabinet's
# power; a segment freed unlocked drops and cracks; an inner segment first chips the
# ones outside it; locked and from the rim in, every segment comes off whole.
# godot --headless --path . --fixed-fps 60 -s tests/ob90_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ob90_save.json"
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
	Game.start_ship = "ob90"
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


func _cut(g, tag: String) -> void:
	var p = g.world.tag(tag)
	g.on_cut_into(p, Geom.bbox(g.world.world_poly(p)).get_center())


func _cond(g, tag: String) -> float:
	return g.world.tag(tag).cond


func _lock_all(g) -> void:
	for r in 3:
		g.do_wrench(_ctrl(g, "LK-%d" % (r + 1)))
	await _frames(4)


func _run() -> void:
	print("OB-90: dust")
	var g = _game()
	await _frames(3)
	var op = g.optics
	check(op.active() and op.cfg.segments.size() == 18 and op.reflect() > 99.0 and op.unsafe().size() == 3, "18 segments on the mirror, %.0f %% reflectance, three rings unlocked" % op.reflect())
	_cut(g, "SPD-U")
	await _frames(2)
	check(_count(g, "mirror_dust") == 0, "a cut at the mouth of the tube, 23 m off: no dust")
	_cut(g, "STR-28")
	await _frames(2)
	var dusty: int = op.cfg.segments.keys().filter(func(t): return _cond(g, t) < 0.99).size()
	check(_count(g, "mirror_dust") == 1 and dusty >= 10 and _cond(g, "PM-U1") < 0.97, "a cut through a backplane strut: dust on %d segments (U1 %.2f)" % [dusty, _cond(g, "PM-U1")])
	g.do_wrench(_ctrl(g, "CVR"))
	var n := 0
	while op.cover < 1.0 and n < 60 * 20:
		await _frames(10)
		n += 10
	check(op.cover >= 1.0 and n < 60 * 14, "the cover runs down in %.1f s" % (n / 60.0))
	var u1: float = _cond(g, "PM-U1")
	var l9: float = _cond(g, "PM-L9")
	await _frames(30)
	_cut(g, "STR4")
	await _frames(2)
	check(_count(g, "mirror_dust") == 1 and _cond(g, "PM-U1") == u1 and _cond(g, "PM-L9") == l9, "cover down, another strut cut: no more dust")
	check(op.save_state().cover >= 1.0 and op.save_state().dusted == 1, "the cover and the dust are saved")
	g.queue_free()
	await _frames(2)

	print("OB-90: the locks")
	g = _game()
	await _frames(3)
	op = g.optics
	g.do_wrench(_ctrl(g, "K-M1"))
	g.do_wrench(_ctrl(g, "K-M2"))
	await _frames(30)
	g.do_wrench(_ctrl(g, "LK-3"))
	await _frames(10)
	check(not op.ring_locked(3) and g.messages.any(func(m): return m[0] == "mirror_lock_dead"), "power off first: ring 3's lock won't latch, and says why")
	g.do_wrench(_ctrl(g, "K-M1"))
	await _frames(30)
	check(op.ring_locked(3), "the battery back on: the switch still thrown, the lock latches")
	_free(g, "PM-U4")
	await _frames(6)
	check(_count(g, "mirror_drop") == 1 and _cond(g, "PM-U4") <= 0.16, "ring 2 unlocked, a segment taken off: it drops and cracks (%.2f)" % _cond(g, "PM-U4"))
	check(_count(g, "mirror_unsupported") == 1 and _cond(g, "PM-U7") <= 0.41 and _cond(g, "PM-U9") <= 0.41 and _cond(g, "PM-L7") > 0.99,
		"ring 3 still on outside it: the outer segments of that half chip, the lower half is untouched")
	g.queue_free()
	await _frames(2)

	print("OB-90: the right way")
	g = _game()
	await _frames(3)
	op = g.optics
	await _lock_all(g)
	check(op.unsafe().is_empty(), "all three rings locked")
	for h in ["U", "L"]:
		for i in range(9, 0, -1):
			_free(g, "PM-%s%d" % [h, i])
			await _frames(3)
	var whole: int = op.cfg.segments.keys().filter(func(t): return _cond(g, t) > 0.99).size()
	check(whole == 18 and g.incidents.is_empty(), "locked, from the rim in: all %d segments whole, no incident" % whole)
	g.queue_free()
	await _frames(2)
	print("OB90 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
