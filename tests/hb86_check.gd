extends SceneTree
# HB-86 "Haven Cove"'s air and glass (scripts/atmos.gd, the oxygen in
# scripts/systems.gd): each culture hall starts with its own oxygen fraction and a
# probe reads it; a cut beside a hall still full of oxygen-rich air flashes it over
# (its racks scorched, a loss) and the fire uses the oxygen up; a hall recovered
# through its port first takes the same cut quietly; a door opened between two
# halls mixes their air; the beam working beside a pane of glass crazes it; the
# oxygen survives a save.
# godot --headless --path . --fixed-fps 60 -s tests/hb86_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_hb86_save.json"
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
	Game.start_ship = "hb86"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _mid(g, tag: String) -> Vector2:
	var p = g.world.tag(tag)
	return g.world.frame(p) * Geom.centroid(p.poly)


func _run() -> void:
	print("HB-86: the halls' air")
	var g = _game()
	await _frames(3)
	var s = g.sys
	check(absf(s.o2_frac("U1") - 0.45) < 0.01 and absf(s.o2_frac("U2") - 0.30) < 0.01 and absf(s.o2_frac("U3") - 0.62) < 0.01 and absf(s.o2_frac("C") - 0.21) < 0.01,
		"each hall its own mixture: %.2f / %.2f / %.2f (the cockpit %.2f)" % [s.o2_frac("U1"), s.o2_frac("U2"), s.o2_frac("U3"), s.o2_frac("C")])
	g.do_measure(_ctrl(g, "O2-3"))
	var r: Dictionary = s.readings.get("O2-3", {})
	check(r.get("text", "").begins_with("62"), "the probe in hall three reads it: %s" % r.get("text", "?"))
	# a cut into hall three's deck, the hall still full
	var rk = g.world.tag("CR-3b")
	var c0: float = rk.cond
	var dk = g.world.tag("HDECK")
	g.on_cut_into(dk, Vector2(57.0, 6.1) * Geom.M)
	await _frames(2)
	check(_count(g, "o2_fire") == 1 and rk.cond < c0 - 0.2, "a cut beside hall three: it flashes over, its racks scorched (%.2f -> %.2f)" % [c0, rk.cond])
	check(s.o2_frac("U3") < 0.25, "and the fire used the oxygen up (%.2f)" % s.o2_frac("U3"))
	# hall one recovered through its port first
	g.do_hose(_ctrl(g, "G-U1"))
	var f := 0
	while s.P("U1") > 5.0 and f < 60 * 180:
		f += 1
		await physics_frame
	g.on_cut_into(dk, Vector2(30.0, 6.1) * Geom.M)
	await _frames(2)
	check(s.P("U1") < 5.0 and _count(g, "o2_fire") == 1, "hall one recovered first (%.0f s): the same cut there is quiet" % (f / 60.0))
	# glass: a cut beside a pane crazes it
	var gl = g.world.tag("GL-4")
	g.on_cut_into(g.world.tag("RIB-4"), _mid(g, "RIB-4"))
	await _frames(2)
	check(gl.cond < 0.2 and _count(g, "glass_craze") >= 1, "a cut on the rib beside pane four crazes it (cond %.2f)" % gl.cond)
	var st: Dictionary = g.atmos.save_state()
	check(st.get("o2", {}).has("U2"), "the halls' oxygen is saved")
	g.queue_free()
	await _frames(2)

	print("HB-86: mixing")
	g = _game()
	await _frames(3)
	s = g.sys
	g.do_wrench(_ctrl(g, "DR-23"))
	f = 0
	while f < 60 * 20:
		f += 1
		await physics_frame
	var a: float = s.o2_frac("U2")
	var b: float = s.o2_frac("U3")
	check(a > 0.33 and b < 0.60, "the door between halls two and three open: their air mixes (%.2f / %.2f)" % [a, b])
	g.queue_free()
	await _frames(2)
	print("HB86 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
