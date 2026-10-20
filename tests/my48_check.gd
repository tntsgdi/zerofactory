extends SceneTree
# MY-48 "Dewdrop"'s one volume (scripts/atmos.gd, the jammed vent in game.do_hose): the
# whole cabin is 60 kPa of 32 % oxygen and its probe reads it; the vent's hose won't go
# on while the valve is jammed; a cut into the hull with the cabin still full flashes it
# over; the valve freed from outside, the cabin drawn down, the same cut is quiet; the
# bus stays live on the fuel cell with the battery off; a cut beside the window band
# crazes its pane.
# godot --headless --path . --fixed-fps 60 -s tests/my48_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_my48_save.json"
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
	Game.start_ship = "my48"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _run() -> void:
	print("MY-48: the one volume")
	var g = _game()
	await _frames(3)
	var s = g.sys
	check(absf(s.P("S") - 60.0) < 2.0 and absf(s.o2_frac("S") - 0.32) < 0.01, "the cabin: %.0f kPa, %.0f %% oxygen" % [s.P("S"), s.o2_frac("S") * 100.0])
	g.do_measure(_ctrl(g, "O2-S"))
	check(str(s.readings.get("O2-S", {}).get("text", "")).begins_with("32"), "the oxygen probe reads %s" % s.readings.get("O2-S", {}).get("text", "?"))
	g.do_hose(_ctrl(g, "G-S"))
	check(not s.hoses.has("G-S"), "the vent valve jammed: no hose goes on")
	# a cut into the hull with the cabin still full
	var hp = g.world.tag("HY13-0")
	var bed = g.world.tag("BED")
	var c0: float = bed.cond
	g.on_cut_into(hp, Vector2(27.0, 5.3) * Geom.M)
	await _frames(4)
	check(_count(g, "o2_fire") == 1 and bed.cond < c0, "a cut into the hull at 60 kPa of 32 %% oxygen: the cabin flashes over (bed %.2f -> %.2f)" % [c0, bed.cond])
	g.queue_free()
	await _frames(2)

	print("MY-48: freed and drawn down")
	g = _game()
	await _frames(3)
	s = g.sys
	g.do_wrench(_ctrl(g, "VENT-JAM"))
	g.do_hose(_ctrl(g, "G-S"))
	check(s.hoses.has("G-S"), "the valve freed from outside: the hose goes on")
	var n := 0
	while s.P("S") > 5.0 and n < 9000:
		await _frames(10)
		n += 10
	check(s.P("S") <= 5.0, "the cabin drawn down through it (%.0f s, %.1f kPa)" % [n / 60.0, s.P("S")])
	g.on_cut_into(g.world.tag("HY13-0"), Vector2(27.0, 5.3) * Geom.M)
	await _frames(4)
	check(_count(g, "o2_fire") == 0, "the same cut now is quiet")
	# two supplies
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(4)
	check(s.bus_volts() > 100.0, "the battery off at the panel, the fuel cell keeps the bus live (%.0f V)" % s.bus_volts())
	g.do_wrench(_ctrl(g, "K-FC"))
	await _frames(4)
	check(s.bus_volts() < 1.0, "and its own switch off: dead")
	# the window band
	var gl = g.world.tag("GL-3")
	var roofp = g.world.piece_at(Vector2(22.6, -6.65) * Geom.M, ["hull"])
	g.on_cut_into(roofp, Vector2(22.6, -6.65) * Geom.M)
	await _frames(4)
	check(gl.cond < 0.3, "a cut in the roof by the window band crazes its pane (%.2f)" % gl.cond)
	g.queue_free()
	await _frames(2)
	print("MY48 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
