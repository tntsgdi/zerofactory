extends SceneTree
# MD-160 "Slingshot"'s mass driver (scripts/flywheel.gd): the wheels start at
# 20,000 rpm and a probe on each reads it; braked with its cooling on a wheel comes
# down, braked dry its caliper burns out; freed while still turning a wheel tears
# loose into what is beside it; the rails' tensioners come off tail first (one
# ahead of an aft one still on and the rail lurches), and a rail freed while it is
# still tight whips; the capacitor banks keep the upper coils live with the power
# off until they are discharged from the cabin.
# godot --headless --path . --fixed-fps 60 -s tests/md160_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_md160_save.json"
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
	Game.start_ship = "md160"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _lift(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _run() -> void:
	print("MD-160: the wheels")
	var g = _game()
	await _frames(3)
	var fw = g.flywheel
	check(fw.active() and fw.spinning("FW-1") and absf(fw.rpm["FW-1"] - 20000.0) < 10.0, "the wheels start at %.0f rpm" % fw.rpm["FW-1"])
	g.do_measure(_ctrl(g, "RPM-1"))
	check(g.sys.readings.get("RPM-1", {}).get("text", "").begins_with("2"), "the probe on the wheel reads %s" % g.sys.readings.get("RPM-1", {}).get("text", "?"))
	# braked with its cooling on, from just over the safe speed
	fw.rpm["FW-2"] = 420.0
	g.do_wrench(_ctrl(g, "CV-2"))
	g.do_wrench(_ctrl(g, "BR-2"))
	await _frames(90)
	check(not fw.spinning("FW-2") and not fw.burnt.has("FW-2"), "braked with its cooling on it comes down (%.0f rpm), its caliper whole" % fw.rpm["FW-2"])
	# braked dry
	g.do_wrench(_ctrl(g, "BR-1"))
	fw._dry["FW-1"] = fw.cfg.burn - 0.05
	await _frames(20)
	check(fw.burnt.has("FW-1") and g.world.tag("BRK-1").cond <= 0.31 and _has(g, "brake_burn"), "braked dry its caliper burns out (cond %.2f)" % g.world.tag("BRK-1").cond)
	var r0: float = fw.rpm["FW-1"]
	await _frames(30)
	check(fw.rpm["FW-1"] > r0 - 3.0, "a burnt brake no longer slows it (%.0f rpm)" % fw.rpm["FW-1"])
	# freed while still turning
	var cap0: float = g.world.tag("CAP-2").cond
	_lift(g, "FW-3")
	await _frames(6)
	check(fw.loose.has("FW-3") and _has(g, "wheel_loose") and g.world.tag("CAP-2").cond < cap0, "freed at %.0f rpm it tears loose into the capacitor bank beside it" % fw.rpm["FW-3"])
	# a stopped wheel comes out quietly
	_lift(g, "FW-2")
	await _frames(6)
	check(not fw.loose.has("FW-2"), "the stopped wheel comes out quietly")
	var st: Dictionary = fw.save_state()
	check(st.has("rpm") and (st.burnt as Array).has("FW-1") and (st.loose as Array).has("FW-3"), "speeds, burnt brakes and torn wheels are saved")
	g.queue_free()
	await _frames(2)

	print("MD-160: the rails")
	g = _game()
	await _frames(3)
	fw = g.flywheel
	check(fw.rail_pull("U") > 170.0, "the upper rail is held at %.0f kN" % fw.rail_pull("U"))
	g.do_measure(_ctrl(g, "T-RU"))
	check(g.sys.readings.get("T-RU", {}).get("text", "") != "", "its gauge reads %s" % g.sys.readings.get("T-RU", {}).get("text", "?"))
	# the upper rail tail first: no lurch
	for t in ["RT-U4", "RT-U3", "RT-U2", "RT-U1"]:
		g.do_wrench(_ctrl(g, t))
		await _frames(3)
	check(fw.rail_pull("U") <= 0.0 and not _has(g, "rail_lurch"), "let off tail first the upper rail goes slack without a lurch")
	# the lower one head first: it lurches
	g.do_wrench(_ctrl(g, "RT-L1"))
	await _frames(3)
	check(_has(g, "rail_lurch"), "the lower rail's head tensioner off with the rest still on: it lurches")
	# a tight rail freed: it whips
	_lift(g, "RL-2")
	await _frames(6)
	check(_has(g, "rail_whip"), "a section of the still-tight lower rail freed: it whips")
	# a slack rail freed: quietly
	var n_whip: int = g.incidents.filter(func(i): return i[1] == "rail_whip").size()
	_lift(g, "RU-2")
	await _frames(6)
	check(g.incidents.filter(func(i): return i[1] == "rail_whip").size() == n_whip, "a section of the slack upper rail comes away quietly")
	g.queue_free()
	await _frames(2)

	print("MD-160: the capacitor banks")
	g = _game()
	await _frames(3)
	g.do_wrench(_ctrl(g, "K-C"))
	await _frames(4)
	var coil = g.world.tag("COIL-U2")
	check(g.sys.bus_volts() < 1.0 and g.sys.piece_volts(coil) > 300.0, "the bus dead, the upper coils still live off the bank (%.0f V)" % g.sys.piece_volts(coil))
	g.do_wrench(_ctrl(g, "DIS-1"))
	await _frames(240)
	check(g.sys.piece_volts(coil) < 30.0, "discharged from the cabin: the coils go dead (%.0f V)" % g.sys.piece_volts(coil))
	g.queue_free()
	await _frames(2)
	print("MD160 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
