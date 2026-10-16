extends SceneTree
# Stills of "why it went wrong": a required piece lost on site (the banner,
# the crossed-out checklist), the radio log (L), and the settlement's
# "where the money went" card beside the books. Test files only.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 60 -s tests/review_shot.gd -- [en]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var finished := false
var l := ""


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	l = "" if Txt.zh else "_en"
	Career.path = "user://zp_test_review_career.json"
	SaveGame.path = "user://zp_test_review_save.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(20, -2) * M, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(5)
	g.drone.global_position = Vector2(20, -6.5) * M
	await _frames(30)
	# a required piece gone, Liang talking, the log open
	var must: Array = g.mandatory_items()
	var lost_p = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.mandatory and p.tag == must[0][0]:
			lost_p = p
	g.mandatory_gone(lost_p, "dv_cut")
	for i in 4:
		g.radio.history.append(["……", "liang" if i % 2 == 0 else "term"])
	g.hud.show_log = true
	await _frames(40)
	Cap.save(root, "res://tests/out/rv_alert%s.png" % l)
	g.hud.show_log = false
	# the books: value knocked off, losses, the piece that was lost
	g.note_loss("dv_cut", "C-02", 4200.0)
	g.note_loss("dv_impact", "AUX-1", 1300.0)
	g.note_loss("dv_impact", "G-01", 900.0)
	g.note_loss("dv_contam", "CP-E", 2600.0)
	g.lose("loss_fire", 1800.0, g.drone.global_position)
	g.playtime = 1250.0
	g.finish_contract(true)
	g.hud.end_t = 9.0
	await _frames(80)
	Cap.save(root, "res://tests/out/rv_settlement%s.png" % l)
	g.queue_free()
	finished = true
