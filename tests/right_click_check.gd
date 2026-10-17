extends SceneTree
var fails := 0

func _initialize() -> void:
	_run()

func frames(n: int = 3) -> void:
	for i in n: await process_frame

func check(ok: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])
	if not ok: fails += 1

func mouse(g, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = pressed
	root.push_input(e)

func click(g) -> void:
	mouse(g, true)
	mouse(g, false)

func _run() -> void:
	Career.path = "user://zp_test_right_click_career.json"
	SaveGame.path = "user://zp_test_right_click_contract.json"
	Txt.cfg_path = "user://zp_test_right_click_settings.cfg"
	Txt.dev = false
	Keys.reset()
	check(Keys.codes("mark") == [Keys.RIGHT_MOUSE], "default mark is right mouse, not G")
	var cf := ConfigFile.new()
	cf.set_value("keys", "mark", [KEY_G])
	Keys.load_from(cf)
	check(Keys.codes("mark") == [Keys.RIGHT_MOUSE], "saved old G default migrates")
	cf.set_value("keys", "mark", [KEY_B])
	Keys.load_from(cf)
	check(Keys.codes("mark") == [KEY_B], "custom keyboard binding survives migration")
	Keys.reset()
	Txt.zh = true
	check(Keys.label("mark") == "鼠标右键" and Txt.t("fa_hauler_d").contains("鼠标右键"), "Chinese controls and shop show right mouse")
	Txt.zh = false
	check(Keys.label("mark") == "RMB" and Txt.t("fa_crane_d").contains("RMB"), "English controls and crane description show RMB")
	Game.contract = {}
	Game.start_ship = ""
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "crane": 1}}
	root.add_child(g)
	await frames(4)
	g.auto_paused = true
	var p
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and q.cls == "metal" and q.mass > 0.2 and q.mass < 1.4 and not q.kind in ["door", "hatch"]:
			p = q
			break
	for j in g.world.joints_of(p): g.world.kill_joint(j)
	for l in g.world.lines_of(p): g.world.kill_line(l)
	await frames(4)
	check(p.body != null and p.body.total_mass() <= 1.5, "fixture is a detached load the hauler can carry")
	g.paused_sim = true
	g.aim = g.world.frame(p) * Geom.centroid(p.poly)
	g.bot.aim = g.aim
	click(g)
	check(g.hauler.queue.has(p.body), "native right click marks detached load")
	click(g)
	check(not g.hauler.queue.has(p.body), "second native right click cancels mark")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_G
	e.pressed = true
	root.push_input(e)
	check(g.hauler.queue.is_empty(), "G no longer marks")
	var before: Vector2 = g.cam_pan
	mouse(g, true)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 0)
	root.push_input(motion)
	mouse(g, false)
	check(g.cam_pan != before and g.hauler.queue.is_empty(), "right drag pans without marking")
	g.tools.held_piece = p
	g.tools.held_body = p.body
	click(g)
	check(g.tools.held_piece == null and g.tools.held_body == null and g.hauler.queue.has(p.body), "right click releases grapple before marking")
	g.hauler.queue.clear()
	g.contract_open = true
	click(g)
	check(g.hauler.queue.is_empty(), "contract overlay blocks mark")
	g.contract_open = false
	g.dev_overlay_open = true
	click(g)
	check(g.hauler.queue.is_empty(), "developer overlay blocks mark")
	g.dev_overlay_open = false
	g.hauler = null
	click(g)
	check(g.crane.queue.has(p.body), "right click routes to crane when no hauler is installed")
	g.queue_free()
	await frames()
	print("RIGHT_CLICK %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)
