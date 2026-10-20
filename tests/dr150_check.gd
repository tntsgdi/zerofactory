extends SceneTree
# DR-150 "Derrick"'s drill string (scripts/drillstring.gd): a stand broken out with
# torque on whips and smashes the drill floor; with the mud in, it blows out; a stand
# from the middle first, the ones above drop; the slips under it open, the string below
# drops; torque bled, mud let out, slips set, top down: every stand whole.
# godot --headless --path . --fixed-fps 60 -s tests/dr150_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_dr150_save.json"
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
	Game.start_ship = "dr150"
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


func _slips(g) -> void:
	for k in 8:
		g.do_wrench(_ctrl(g, "SLIP-%d" % (k + 1)))
	await _frames(2)


func _bleed(g) -> void:
	g.do_wrench(_ctrl(g, "TQB"))
	await _secs(120.0)


func _drain(g) -> void:
	g.do_hose(_ctrl(g, "PMUD"))
	var n := 0
	while g.drillstring.mud_level() > 0.04 and n < 400:
		await _secs(5.0)
		n += 5


func _run() -> void:
	print("DR-150: torque on")
	var g = _game()
	await _frames(3)
	var ds = g.drillstring
	check(ds.active() and ds.torque_pct() > 99.0 and ds.mud_kpa() > 3000.0 and ds.unsafe().size() == 10, "torque %.0f %%, mud %.0f kPa, eight slips open" % [ds.torque_pct(), ds.mud_kpa()])
	await _slips(g)
	await _drain(g)
	var dw: float = _cond(g, "DW")
	_free(g, "J-1")
	await _frames(4)
	check(_count(g, "drill_whip") == 1 and _cond(g, "J-1") <= 0.21 and (_cond(g, "DW") < dw or _cond(g, "DRL") < 1.0), "J-1 broken out with the torque on: it whips, the drill floor is smashed")
	check(_count(g, "mud_blowout") == 0 and _count(g, "drill_drop") == 0, "nothing else: the mud was out, the slips set")
	g.queue_free()
	await _frames(2)

	print("DR-150: the mud in")
	g = _game()
	await _frames(3)
	ds = g.drillstring
	await _slips(g)
	await _bleed(g)
	check(ds.torque_pct() < 5.0, "the torque bled at the rotary brake (%.1f %%)" % ds.torque_pct())
	_free(g, "J-1")
	await _frames(4)
	check(_count(g, "mud_blowout") == 1 and g.sys.fluid("mud") < 0.01 and _cond(g, "TD") < 1.0, "J-1 broken out with the mud in: it blows out, the top drive fouled")
	g.queue_free()
	await _frames(2)

	print("DR-150: out of order, slips open")
	g = _game()
	await _frames(3)
	ds = g.drillstring
	await _slips(g)
	await _bleed(g)
	await _drain(g)
	_free(g, "J-3")
	await _frames(4)
	check(_count(g, "drill_drop") == 1 and _cond(g, "J-1") <= 0.31 and _cond(g, "J-2") <= 0.31 and _cond(g, "J-4") > 0.99, "J-3 out from under J-1 and J-2: they drop, the rest stands")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	ds = g.drillstring
	await _bleed(g)
	await _drain(g)
	_free(g, "J-1")
	await _frames(4)
	check(_count(g, "drill_drop") == 1 and _cond(g, "J-2") <= 0.31 and _cond(g, "BHA") <= 0.31, "the slips under J-1 open: the string below goes down the hole")
	g.queue_free()
	await _frames(2)

	print("DR-150: the right way")
	g = _game()
	await _frames(3)
	ds = g.drillstring
	await _slips(g)
	await _bleed(g)
	await _drain(g)
	check(ds.unsafe().is_empty() and g.sys.fluid_rec.get("water", 0.0) > 2.0, "bled, drained (%.1f m³ of mud recovered), slips set" % g.sys.fluid_rec.get("water", 0.0))
	for t in ds.cfg.stands:
		_free(g, str(t))
		await _frames(3)
	var whole: int = ds.cfg.stands.filter(func(t): return _cond(g, str(t)) > 0.99).size()
	check(whole == 9 and g.incidents.is_empty(), "from the top down: all %d stands whole, no incident" % whole)
	check(ds.save_state().torque < 0.05, "saved")
	g.queue_free()
	await _frames(2)
	print("DR150 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
