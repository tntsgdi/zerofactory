extends SceneTree
# FX-70 "Fusion Core"'s superconducting magnets (scripts/magnets.gd): the power cut with
# the coils energised, the cryoplant stops, the coils warm and quench, the quench
# spreads; a coil support cut while energised quenches its coil; dumped first with the
# cooling on, the helium recovered after, the coils come out whole.
# godot --headless --path . --fixed-fps 60 -s tests/fx70_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_fx70_save.json"
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


# sim seconds, quickly: the physics runs eight steps a frame
func _secs(s: float) -> void:
	Engine.time_scale = 8.0
	await _frames(int(s * 60.0 / 8.0))
	Engine.time_scale = 1.0


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "fx70"
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
	print("FX-70: the cooling lost")
	var g = _game()
	await _frames(3)
	var mg = g.magnets
	check(mg.active() and mg.energy.size() == 8 and mg.field() > 99.0 and mg.max_temp() < 5.0 and mg.unsafe().size() == 8, "eight coil packs at full field, %.1f K" % mg.max_temp())
	var he0: float = g.sys.fluid("lhe")
	g.do_wrench(_ctrl(g, "K-M1"))
	g.do_wrench(_ctrl(g, "K-M2"))
	await _secs(60.0)
	check(_count(g, "magnet_quench") == 0 and mg.max_temp() > 6.0, "the power off, the cryoplant stops: the coils warm (%.1f K after a minute)" % mg.max_temp())
	await _secs(70.0)
	check(_count(g, "magnet_quench") >= 2 and _cond(g, "TF-1") <= 0.26, "past 9 K, still energised: they quench (%d)" % _count(g, "magnet_quench"))
	check(_cond(g, "BLK-L1") < 1.0 or _cond(g, "DIV-L") < 1.0, "what is near a quenching coil is damaged (blanket %.2f, divertor %.2f)" % [_cond(g, "BLK-L1"), _cond(g, "DIV-L")])
	check(g.sys.fluid("lhe") < he0 * 0.9, "helium boiled off (%.2f of %.2f)" % [g.sys.fluid("lhe"), he0])
	check(mg.save_state().quenched.size() >= 2, "the quenches are saved")
	g.queue_free()
	await _frames(2)

	print("FX-70: a support cut")
	g = _game()
	await _frames(3)
	mg = g.magnets
	var sp = g.world.tag("TF-2-P")
	g.on_cut_into(sp, Geom.bbox(g.world.world_poly(sp)).get_center())
	await _frames(4)
	check(mg.quenched.has("TF-2") and not mg.quenched.has("TF-1"), "TF-2's pedestal cut, energised: TF-2 quenches")
	await _secs(1.5)
	check(mg.quenched.has("TF-1") and mg.quenched.has("TF-3") and not mg.quenched.has("TF-6"), "a moment later the coils beside it go too, not the far ones")
	g.queue_free()
	await _frames(2)

	print("FX-70: the right way")
	g = _game()
	await _frames(3)
	mg = g.magnets
	g.do_wrench(_ctrl(g, "DUMP"))
	await _secs(110.0)
	check(mg.field() < 5.0 and mg.max_temp() < 5.0 and g.incidents.is_empty(), "the dump closed, the cooling on: down to %.1f %% in 110 s, still %.1f K" % [mg.field(), mg.max_temp()])
	check(mg.unsafe().is_empty(), "nothing energised")
	g.do_hose(_ctrl(g, "PHE"))
	await _secs(90.0)
	g.do_wrench(_ctrl(g, "K-M1"))
	g.do_wrench(_ctrl(g, "K-M2"))
	await _secs(30.0)
	check(g.sys.fluid("lhe") < 0.05 and mg.max_temp() > 5.0 and g.incidents.is_empty(), "helium drawn off, power off: the coils warm (%.1f K), harmlessly" % mg.max_temp())
	for t in ["TF-1-H1", "TF-1-H2", "TF-2-P"]:
		_free(g, t)
	await _frames(6)
	check(g.incidents.is_empty() and _cond(g, "TF-1") > 0.99 and _cond(g, "TF-2") > 0.99, "and their supports come away with the coils whole")
	g.queue_free()
	await _frames(2)
	print("FX70 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
