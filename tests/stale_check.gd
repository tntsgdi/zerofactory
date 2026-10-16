extends SceneTree
# V2 2.7 / rule B: a record goes void once what it describes has changed.
#   readings: a dead-leg pressure after its valve opens, the bus volts after a
#   switch, a room pressure after it is vented, all turn stale;
#   engineering notes from an earlier ship: a piece that lost a fixing, a line
#   that was cut and a control that was operated are marked "changed: check
#   again"; the others stay as they were.
# godot --headless --path . --fixed-fps 60 -s tests/stale_check.gd

const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var finished := false
var fails := 0
var g


func _initialize() -> void:
	SaveGame.path = "user://zp_test_stale_save.json"
	Career.path = "user://zp_test_stale_career.json"
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


func c(id: String) -> Dictionary:
	var ct = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": ct, "pos": g.world.ctrl_world(ct)}


func _run() -> void:
	var o := Market.offer_for(7, {"rep": 0, "done": 1}, 1)
	o.traps = []
	o.notes = {"pieces": {"AUX-1": {"fix": "1.10 t · 2"}, "C-01": {"fix": "2.40 t · 4"}},
		"lines": {"q1": ["CP-E", "G-01"], "q2": ["G-01", "ENG-F"]}, "ctrls": {"K-G": "switch", "K-B": "switch"}, "ships": 1}
	Game.contract = o
	SaveGame.load_requested = false
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	g = scene
	await _frames(10)
	var s = g.sys
	print("STALE: readings")
	g.do_measure(c("P-C01"))
	var r1: Dictionary = s.readings["P-C01"]
	check(not s.stale(r1), "P-C01 just read: %s" % r1.text)
	g.do_wrench(c("V-C01"))
	await _frames(30)
	check(s.stale(r1), "after V-C01 opened, the P-C01 reading is stale")
	g.do_measure(c("E-D01"))
	var r2: Dictionary = s.readings["E-D01"]
	check(not s.stale(r2), "E-D01 just read: %s" % r2.text)
	g.do_wrench(c("K-G"))
	await _frames(10)
	check(s.stale(r2), "after K-G opened, the bus reading is stale")
	g.do_measure(c("GAS-AB"))
	var r3: Dictionary = s.readings["GAS-AB"]
	check(not s.stale(r3), "room A just read: %s" % r3.text)
	g.do_hose(c("GAS-AB"))
	Engine.time_scale = 8.0
	await _frames(400)
	Engine.time_scale = 1.0
	check(s.stale(r3), "after venting, the room A reading is stale (now %.0f kPa)" % s.P("A"))
	print("STALE: engineering notes")
	var bp = g.blueprint
	for j in g.world.joints_of(g.world.tag("AUX-1")):
		g.world.kill_joint(j)
	var q1 = g.world.lines["q1"]
	g.world.kill_line(q1)
	g.on_line_cut(q1, g.world.line_end_world(q1, 0))
	await _frames(5)
	check(bp.note_void("p:AUX-1"), "AUX-1 unbolted: its note is void")
	check(not bp.note_void("p:C-01"), "C-01 untouched: its note stands")
	check(bp.note_void("l:q1"), "q1 cut: its note is void")
	check(not bp.note_void("l:q2"), "q2 untouched: its note stands")
	check(bp.note_void("c:K-G"), "K-G operated: its note is void")
	check(not bp.note_void("c:K-B"), "K-B untouched: its note stands")
	check(bp.notes_rows()[2][1] == g.txt("nt_unverified"), "this ship's accident state is still unverified")
	print("STALE %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
