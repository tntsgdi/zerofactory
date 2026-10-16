extends SceneTree
# Stills of the phase-two screens, from test files: the market with a survey
# report on a card, the loan-paid-off moment, a market contract's settlement
# (career books, signature traps), the drawing with "my engineering notes",
# and a berth with all four first upgrades fitted (arm on the boom, pump
# housings, the drone's emitter and inspection head).
# tools/run_test.sh tests/phase2_shots.gd --fixed-fps 60 -- [en]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var finished := false
var l := ""


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	l = "" if Txt.zh else "_en"
	Career.path = "user://zp_test_shots_career.json"
	SaveGame.path = "user://zp_test_shots_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Career.data = Career.fresh()
	var d := Career.data
	d.active = {}
	d.market = true
	d.done = 6
	d.money = 61500.0
	d.loan = 18000.0
	d.rep = 17
	d.items = {"intel": 2, "repair": 1}
	d.upgrades = {"arm": 1, "grapple5": 1, "pump2": 1, "scan_kit": 1}
	d.seen = {"market": true, "level": "senior"}
	d.archive = {"gr7": {"pieces": {"AUX-1": {"fix": "1.10 t · 2 螺栓"}, "C-01": {"fix": "2.40 t · 4 锁扣", "to": "equip"}}, "ports": {"P-C01": "SC", "GAS-D": "D"}, "lines": {"q1": ["CP-E", "G-01"]}, "ctrls": {"K-G": "switch"}, "ships": 2}}
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(5)
	term.use_intel(1)
	term.sel = 1
	await _frames(50)
	Cap.save(root, "res://tests/out/p2_market%s.png" % l)
	# pay the rest off: the milestone
	term.set_tab(2)
	term.buy(term.BERTH[0])
	await _frames(70)
	Cap.save(root, "res://tests/out/p2_paid_off%s.png" % l)
	term.milestone = -1.0
	term.take(1)
	term.queue_free()
	await _frames(2)
	# on site with every upgrade: the berth and the drone
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(23, -7) * M, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(5)
	g.drone.global_position = Vector2(22, -7.5) * M
	g.cam_pos = Vector2(21, -6) * M
	g.zoom_target = 1.0
	await _frames(60)
	Cap.save(root, "res://tests/out/p2_upgrades%s.png" % l)
	g.blueprint.toggle()
	g.drone.global_position = Vector2(14, -7.0) * M
	await _frames(50)
	Cap.save(root, "res://tests/out/p2_notes%s.png" % l)
	g.blueprint.toggle()
	# a settlement: one trap caught out, one avoided
	g.incidents.append([10.0, "motor", "HATCH-SW"])
	g.playtime = 1250.0
	g.finish_contract(true)
	g.hud.end_t = 9.0
	await _frames(60)
	Cap.save(root, "res://tests/out/p2_settlement%s.png" % l)
	g.queue_free()
	finished = true
