extends SceneTree
# Roadmap 2.8 acceptance: the engineering archive. On a first Heron from the
# market the operator checks a handful of things by hand — reads a port,
# traces a pipe, inspects one unit, works one switch — and ends the contract.
# The archive must hold exactly those (factory names only, never a trap's
# fitting). On the second Heron the drawing carries "my engineering notes":
# those things and nothing else; its "this ship's accident" row reads "not
# yet verified" — and still does after checking the same port again.
# godot --headless --path . --fixed-fps 60 -s tests/notes_check.gd [-- shot]

const Cap = preload("res://tests/cap.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
const M := 48.0
var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_notes_career.json"
	SaveGame.path = "user://zp_test_notes_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
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


func _contract() -> Node:
	Career.ensure_offers(Market.make)
	Career.accept(0)
	Game.contract = Career.active()
	SaveGame.load_requested = false
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	await _frames(4)
	return scene


func c(g, id: String) -> Dictionary:
	var ct = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": ct, "pos": g.world.ctrl_world(ct)}


func _run() -> void:
	Career.data = {}
	Career.start_new()
	var d := Career.data
	d.active = {}
	d.market = true
	d.done = 1
	d.money = 200000.0
	d.seen = {"market": true}
	Career.save()
	# ---- the first Heron from the market: a few things checked by hand
	var g = await _contract()
	check(not g.blueprint.has_notes(), "the first Heron of the career has no notes")
	g.do_measure(c(g, "P-C01"))
	var q1 = g.world.lines["q1"]
	g.do_measure({"kind": "line", "line": q1, "pos": g.world.line_path_world(q1)[0]})
	var aux = g.world.tag("AUX-1")
	g.do_measure({"kind": "inspect", "piece": aux, "pos": g.world.frame(aux) * Geom.centroid(aux.poly)})
	g.do_wrench(c(g, "K-G"))
	g.verify("pieces", "TK-X1", {"fix": "x"})
	g.verify("ports", "FX-P", "FX")
	g.finish_contract(true)
	await _frames(3)
	var arch: Dictionary = Career.data.archive.get("gr7", {})
	var got := [arch.get("pieces", {}).keys(), arch.get("ports", {}).keys(), arch.get("lines", {}).keys(), arch.get("ctrls", {}).keys()]
	check(str(got) == str([["AUX-1"], ["P-C01"], ["q1"], ["K-G"]]), "the archive holds exactly what was checked: %s" % str(got))
	check(arch.get("ports", {}).get("P-C01", "") == "SC" and str(arch.lines.q1) == str(["CP-E", "G-01"]), "with what was found: P-C01 reads %s, Q1 runs %s" % [arch.ports.get("P-C01"), str(arch.lines.get("q1"))])
	g.queue_free()
	await _frames(2)
	# ---- the second Heron: the notes are on the drawing
	Career.data = {}
	Career.load_or_new()
	var g2 = await _contract()
	g2.blueprint.toggle()
	await _frames(20)
	var bp = g2.blueprint
	var pieces: Array = bp.note_polys.map(func(x): return x[1])
	var runs: Array = bp.note_runs.map(func(x): return x[1])
	var pts: Array = bp.note_points.map(func(x): return x[1])
	check(bp.has_notes() and pieces == ["AUX-1"] and runs == ["Q1"] and pts.size() == 2, "the second Heron's drawing carries the notes: %s %s %s" % [str(pieces), str(runs), str(pts)])
	var rows: Array = bp.notes_rows()
	check(rows[2][0] == Txt.t("nt_now") and rows[2][1] == Txt.t("nt_unverified"), "\"%s\": %s" % [rows[2][0], rows[2][1]])
	# nothing in the notes was not checked by hand
	var never := ["C-01", "C-02", "C-03", "G-01", "BB-01", "TK-X1", "EG-01", "FX-01", "NAV-01"]
	check(not pieces.any(func(x): return x in never), "nothing that was never checked (%s) is in the notes" % ", ".join(never))
	# checking the same port on this ship does not turn the row into a verdict
	g2.do_measure(c(g2, "P-C01"))
	await _frames(2)
	check(bp.notes_rows()[2][1] == Txt.t("nt_unverified"), "after reading P-C01 again here, the accident row still reads %s" % bp.notes_rows()[2][1])
	if OS.get_cmdline_user_args().has("shot"):
		g2.drone.global_position = Vector2(30, -6) * M
		await _frames(40)
		Cap.save(root, "res://tests/out/notes_overlay.png")
	g2.queue_free()
	print("NOTES %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
