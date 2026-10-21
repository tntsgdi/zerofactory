extends SceneTree
# Where the recovered goods go (2026-10-20): whole equipment rides the bay's lift,
# the boom shuttle and the tunnel into the freighter over the boom, each in a rack
# slot with its outline, tag and value; hazards go down the sealed tube into the
# barge's shielded hold, made safe; ingots come down the lift into its ingot hold.
# Also the equipment bay's works and the debris net's load cell, dump gate and
# baler. Stills: recovery_freighter.png, recovery_barge.png, recovery_bay.png,
# recovery_net.png. Test saves only.
# tools/run_test.sh tests/recovery_shot.gd -- [en]

const Cap = preload("res://tests/cap.gd")
const Smelter_PITCH := 0.72
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = not OS.get_cmdline_user_args().has("en")
	Txt.zh = Txt.test_zh
	SaveGame.path = "user://zp_test_recovery_save.json"
	Career.path = "user://zp_test_recovery_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# a stand-in for a body the mouth took: real pieces of the ship, as they lie
func _body(p) -> Dictionary:
	var c := Geom.centroid(p.poly)
	return {"pieces": [p], "global_transform": Transform2D.IDENTITY, "center_of_mass": c}


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "cv138"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	await _frames(30)
	var d = g.dock
	var sh = d.ships
	var eq: Array = []
	var hz: Array = []
	for p in g.world.pieces.values():
		if p.cls == "equip" and p.tag != "" and p.hazard == "" and eq.size() < 9:
			eq.append(p)
		elif p.hazard != "" and hz.size() < 4:
			hz.append(p)
	for i in eq.size():
		sh.add_equip(_body(eq[i]), 4000.0 + i * 1500.0, 8.0 + i * 2.0)
	for p in hz:
		sh.add_hazard(_body(p), 1200.0)
	# the casting line runs on: what was on it goes down the ingot lift
	d.smelter.line_goal += Smelter_PITCH * 10.0
	await _frames(90)
	# the camera on the shuttle run and the tunnel
	g.cam_override = Vector2(sh.tunnel_x() + 6.0, Dock.RAIL_Y - 5.0) * 48.0
	g.zoom_override = 0.75
	await _frames(400)
	check(sh.equip.size() == eq.size() and sh.shuttles.is_empty(), "every item went up into the freighter (%d / %d)" % [sh.equip.size(), eq.size()])
	check(sh.hazard.size() == hz.size(), "every hazard went down into the shielded hold (%d)" % sh.hazard.size())
	Cap.save(root, "res://tests/out/recovery_freighter.png")
	var br: Rect2 = sh.barge_rect()
	g.cam_override = (br.get_center() + Vector2(0, -3.0)) * 48.0
	g.zoom_override = 0.62
	await _frames(60)
	check(d.smelter.shipped >= 1, "ingots came down the lift (%d)" % d.smelter.shipped)
	Cap.save(root, "res://tests/out/recovery_barge.png")
	# the equipment bay taking something: airbags, clamp, scan arch, lift
	var bay := Dock.zpos("equip") / 48.0
	d.zone_state["equip"].eat = 1.0
	d.zone_state["equip"].busy = 1.0
	g.cam_override = (bay + Vector2(0, -0.5)) * 48.0
	g.zoom_override = 1.6
	await _frames(100)
	d.zone_state["equip"].eat = 1.0
	await _frames(2)
	Cap.save(root, "res://tests/out/recovery_bay.png")
	# the debris net past its load: gate, baler, bale on its belt
	d.net_load = 0.07
	g.cam_override = (Dock.NET + Vector2(1.0, 0.6)) * 48.0
	g.zoom_override = 1.6
	await _frames(100)
	check(d.net_dump >= 0.0, "the net started its dump at %.2f t" % 0.07)
	Cap.save(root, "res://tests/out/recovery_net.png")
	await _frames(200)
	check(d.net_bales == 1 and d.net_load == 0.0, "one bale made, the net emptied")
	# towed out: both ships cast off
	g.state = "towout"
	g.state_t = 0.0
	await _frames(60)
	check(sh.leave > 0.05, "they cast off when the hull is towed out (%.2f)" % sh.leave)
	print("recovery_shot: %d failures" % fails)
	quit(1 if fails > 0 else 0)
