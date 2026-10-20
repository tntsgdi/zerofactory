extends SceneTree
# TB-180 "Binary"'s tether (scripts/tether.gd): the pair starts at 2 rpm and the brake's
# gauges read its turn and the tether's pull; braked with its cooling on it stops,
# braked dry its rollers slip for good and then only the B pod's RCS stops it (on the
# B pod's own power and propellant); the tether parted while the pair still turns
# throws both pods; stopped but still pulling, a cut parts the whole worn tether;
# stopped and slack, it comes apart quietly.
# godot --headless --path . --fixed-fps 60 -s tests/tb180_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_tb180_save.json"
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
	Game.start_ship = "tb180"
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


func _read(g, id: String) -> String:
	g.do_measure(_ctrl(g, id))
	return str(g.sys.readings.get(id, {}).get("text", ""))


func _run() -> void:
	print("TB-180: the turn and the brake")
	var g = _game()
	await _frames(3)
	var tt = g.tether
	check(tt.active() and tt.spinning() and absf(tt.rpm - 2.0) < 0.01, "the pair starts at %.2f rpm" % tt.rpm)
	check(_read(g, "RPM-T").begins_with("2"), "the brake's tachometer reads %s" % _read(g, "RPM-T"))
	check(absf(tt.pull() - 48.0) < 0.5 and _read(g, "T-TH").begins_with("48"), "the tether pulls %s (spin and the tensioner)" % _read(g, "T-TH"))
	check(_read(g, "W-TH").begins_with("5"), "the worn segment's strands: %s" % _read(g, "W-TH"))
	tt.rpm = 0.14
	g.do_wrench(_ctrl(g, "BRK-C"))
	g.do_wrench(_ctrl(g, "BRK"))
	await _frames(150)
	check(not tt.spinning() and not tt.slipped and tt.heat < 1.0, "braked with its cooling on it stops (%.3f rpm), cool (%.0f °C)" % [tt.rpm, tt.temp()])
	g.do_wrench(_ctrl(g, "TEN"))
	await _frames(3)
	check(tt.pull() <= 2.0, "stopped and the tensioner off: slack (%.1f kN)" % tt.pull())
	_lift(g, "TH-6")
	await _frames(6)
	check(not _has(g, "pods_thrown") and not _has(g, "tb_parted") and not _has(g, "tether_whip"), "stopped and slack the tether comes apart quietly")
	check(tt.save_state().has("rpm") and tt.save_state().has("slipped"), "the turn, the heat and the slip are saved")
	g.queue_free()
	await _frames(2)

	print("TB-180: braked dry, then the RCS")
	g = _game()
	await _frames(3)
	tt = g.tether
	g.do_wrench(_ctrl(g, "BRK"))
	tt.heat = tt.cfg.brake.slip - 0.05
	await _frames(20)
	check(tt.slipped and _has(g, "brake_slip") and g.world.tag("ROL-U1").cond <= 0.51, "braked dry its rollers slip (cond %.2f)" % g.world.tag("ROL-U1").cond)
	var r0: float = tt.rpm
	await _frames(40)
	check(tt.rpm > r0 - 0.001, "slipped, the brake no longer slows it (%.3f rpm)" % tt.rpm)
	var f0: float = g.sys.fvol["pb1"].amount + g.sys.fvol["pb2"].amount
	g.do_wrench(_ctrl(g, "RCS-B"))
	await _frames(60)
	var f1: float = g.sys.fvol["pb1"].amount + g.sys.fvol["pb2"].amount
	check(tt.rpm < r0 - 0.005 and f1 < f0, "the B pod's RCS slows it (%.3f rpm), burning propellant" % tt.rpm)
	g.do_wrench(_ctrl(g, "K-B"))
	await _frames(4)
	var r1: float = tt.rpm
	await _frames(40)
	check(tt.rpm > r1 - 0.0005, "with the B pod's battery off the RCS does nothing")
	g.queue_free()
	await _frames(2)

	print("TB-180: parted while it turns")
	g = _game()
	await _frames(3)
	var c0: float = g.world.tag("CON-A").cond
	_lift(g, "TH-2")
	await _frames(6)
	check(_has(g, "pods_thrown") and g.world.tag("CON-A").cond <= 0.51 and g.world.tag("TANK-1").cond <= 0.51 and c0 > 0.9, "a segment freed at 2 rpm: both pods are thrown (what they carry knocked)")
	g.queue_free()
	await _frames(2)

	print("TB-180: stopped but still pulling")
	g = _game()
	await _frames(3)
	g.tether.rpm = 0.0
	_lift(g, "TH-6")
	await _frames(6)
	check(_has(g, "tb_parted") and g.world.tag("TH-1").cond <= 0.21, "cut with the tensioner still on: the worn tether parts end to end")
	g.queue_free()
	await _frames(2)
	print("TB180 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
