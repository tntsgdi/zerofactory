extends SceneTree
# QC-30 "Quantum"'s dilution refrigerator (scripts/dilution.gd): cold at the start; the
# pulse tube stopped with the mixture still in boils it off; the bus killed first does
# the same; done in order (circulation off, mixture drawn, pulse tube off) it warms
# quietly; the heaters too early crack the chip, the stack touched cold cracks it, a cut
# near it with the isolation table floating shakes it.
# godot --headless --path . --fixed-fps 60 -s tests/qc30_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_qc30_save.json"
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
	Game.start_ship = "qc30"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _op(g, id: String) -> void:
	g.do_wrench(_ctrl(g, id))


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _drain_mix(g) -> void:
	g.do_hose(_ctrl(g, "G-MIX"))
	var n := 0
	while g.dilution.mix_in() and n < 3000:
		await _frames(10)
		n += 10


func _run() -> void:
	print("QC-30: the fridge as it came in")
	var g = _game()
	await _frames(3)
	var d = g.dilution
	check(d.active() and d.mxc_temp() < 0.02 and d.running(), "the mixing chamber at %.3f K, the pulse tube running" % d.mxc_temp())
	g.do_measure(_ctrl(g, "T-MXC"))
	check(str(g.sys.readings.get("T-MXC", {}).get("text", "")).begins_with("0.01"), "the cryogenic thermometer reads %s" % g.sys.readings.get("T-MXC", {}).get("text", "?"))
	# the classic mistake: the power off first
	_op(g, "K-M")
	await _frames(10)
	check(not d.running() and _has(g, "mix_boil") and not d.mix_in(), "the bus killed first: the pulse tube stops, the mixture boils off")
	check(g.world.tag("STG-STILL").cond < 1.0, "the still is damaged by it")
	g.queue_free()
	await _frames(2)

	print("QC-30: in order")
	g = _game()
	await _frames(3)
	d = g.dilution
	_op(g, "VI-LOCK")
	_op(g, "CIRC")
	await _drain_mix(g)
	check(not d.mix_in(), "circulation stopped, the mixture drawn off (%.0f kPa)" % g.sys.P("MIX"))
	_op(g, "PT")
	await _frames(60 * 20)
	check(not _has(g, "mix_boil") and d.mxc_temp() > 1.0, "the pulse tube off with the mixture in: it warms quietly (%.1f K after 20 s)" % d.mxc_temp())
	var n := 0
	while d.mxc_temp() < 35.0 and n < 60 * 200:
		await _frames(30)
		n += 30
	_op(g, "HEAT")
	n = 0
	while d.mxc_temp() < 252.0 and n < 60 * 200:
		await _frames(30)
		n += 30
	check(d.mxc_temp() >= 250.0 and d.cracked == "", "heaters on past 30 K: warm in %.0f s more, the chip whole" % (n / 60.0))
	var chip = g.world.tag("QPU")
	for j in g.world.joints_of(chip):
		g.world.kill_joint(j)
	await _frames(4)
	check(chip.intact and chip.cond > 0.99 and d.cracked == "", "the chip comes out warm and whole")
	check(d.save_state().temp.has("STG-MXC"), "the stages' temperatures are saved")
	g.queue_free()
	await _frames(2)

	print("QC-30: the heaters too early, the stack cold, a cut nearby")
	g = _game()
	await _frames(3)
	d = g.dilution
	_op(g, "HEAT")
	await _frames(4)
	check(_has(g, "qpu_shock"), "the heaters on at 12 mK: the chip cracks")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	d = g.dilution
	var st = g.world.tag("STG-CP")
	for j in g.world.joints_of(st):
		g.world.kill_joint(j)
	await _frames(4)
	check(_has(g, "qpu_brittle"), "the cold plate freed at millikelvin: the chip cracks")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	var ms = g.world.tag("MS-1")
	g.on_cut_into(ms, g.world.frame(ms) * Geom.centroid(ms.poly))
	await _frames(3)
	check(_has(g, "qpu_vibration"), "a cut by the stack with the isolation table floating shakes the chip")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	_op(g, "VI-LOCK")
	ms = g.world.tag("MS-2")
	g.on_cut_into(ms, g.world.frame(ms) * Geom.centroid(ms.poly))
	await _frames(3)
	check(not _has(g, "qpu_vibration"), "locked, the same cut leaves it be")
	g.queue_free()
	await _frames(2)
	print("QC30 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
