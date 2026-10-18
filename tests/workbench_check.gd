extends SceneTree
var fails := 0

func _initialize() -> void:
	_run()

func frames(n: int = 3) -> void:
	for i in n: await process_frame

func check(ok: bool, text: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", text])
	if not ok: fails += 1

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e)
	await frames(1)
	e = e.duplicate()
	e.pressed = false
	root.push_input(e)
	await frames(1)

func click(button: Button) -> void:
	button.grab_focus()
	await key(KEY_ENTER)

func _run() -> void:
	Career.path = "user://zp_test_workbench_career.json"
	SaveGame.path = "user://zp_test_workbench_contract.json"
	Txt.cfg_path = "user://zp_test_workbench_settings.cfg"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 1000.0
	Career.sign_active()
	Txt.dev = false
	Game.contract = Career.active()
	Game.start_ship = "tug"
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(6)
	var dev: DevPanel
	for child in g.get_children():
		if child is DevPanel: dev = child
	await key(KEY_F12)
	check(Txt.dev and DevPanel.workbench_open and dev.bench.visible, "F12 opens the new workbench")
	check(paused and g.paused_sim and g.dev_overlay_open, "workbench owns a simulation pause")
	var sim := g.sys.time
	var elapsed := g.playtime
	await frames(20)
	check(g.sys.time == sim and g.playtime == elapsed and not g.tools.cutting, "physics and contract clock stay still; no background cutting")
	await click(dev.bench.buttons.restore)
	check(g.drone.integrity == 100.0 and g.drone.alive, "native restore card restores the drone")
	await click(dev.bench.buttons.page_1)
	check(dev.bench.page == 1, "native page button opens progression cards")
	await click(dev.bench.buttons.skill_grapple_mass_3)
	check(g.grab_max() == 8.0 and Growth.level(Career.data.upgrades, "grapple_mass") == 0, "current-job level III gives 8 t without changing owned career level")
	await click(dev.bench.buttons.skill_grapple_mass_0)
	check(g.grab_max() == 3.0 and not g.has_upgrade("grapple5"), "stock reset removes legacy alias and restores real 3 t limit")
	await click(dev.bench.buttons.career_scope)
	await click(dev.bench.buttons.preset_3)
	check(Growth.progress() == 48 and g.grab_max() == 8.0, "permanent expert preset unlocks all 48 levels and fits this career job")
	await click(dev.bench.buttons.preset_0)
	check(Growth.progress() == 0 and g.grab_max() == 3.0, "permanent stock preset downgrades aliases as well as levels")
	await click(dev.bench.buttons.add_funds)
	check(Career.data.money == 101000.0, "adjustable funds card changes career cash")
	await click(dev.bench.buttons.add_rep)
	check(Career.data.rep == 5, "reputation control changes career reputation")
	var snapshot := Career.data.duplicate(true)
	var kit: Dictionary = g.job.kit.duplicate(true)
	var path := Career.path
	Career.path = "user://missing_workbench_directory/career.json"
	check(not dev.tune_skills(3, true) and Career.data == snapshot and g.job.kit == kit, "failed permanent save does not change career or live loadout")
	check(not dev.adjust_funds(1000) and Career.data == snapshot, "failed money save rolls back")
	Career.path = path
	await key(KEY_ESCAPE)
	check(not DevPanel.workbench_open and not paused and not g.paused_sim and not g.dev_overlay_open, "Escape closes workbench and resumes original simulation")
	await frames(5)
	check(g.sys.time > sim, "simulation really advances after close")
	g.toggle_menu()
	await key(KEY_F12)
	await key(KEY_ESCAPE)
	check(paused and g.menu_open and g.paused_sim, "closing workbench preserves an existing pause menu")
	g.toggle_menu()
	await key(KEY_F12)
	await click(dev.bench.buttons.page_0)
	await click(dev.bench.buttons.dev_god)
	check(DevPanel.god, "native card toggles invulnerability")
	await click(dev.bench.buttons.disable)
	check(not Txt.dev and not DevPanel.god and not DevPanel.xray and DevPanel.time_k == 1.0 and not paused, "disable exits dev mode and restores normal switches and pause")
	check(not dev.tune_skills(3, true), "disabled developer mode rejects mutations")
	g.queue_free()
	await frames()
	Txt.dev = true
	var term: Terminal = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await frames()
	for child in term.get_children():
		if child is DevPanel: dev = child
	dev.run(4)
	check(Growth.progress() == 48, "legacy F4 shortcut now grants all skillbook levels")
	dev.set_open(true)
	await click(dev.bench.buttons.page_2)
	DevPanel.b_ship = "h22"
	DevPanel.b_kit = {"skill_grapple_mass": 3, "grapple5": 1}
	dev.bench.refresh()
	var built := DevPanel.build(Career.data)
	check(built.ok and Growth.value(built.offer.kit, "grapple_mass") == 8.0, "contract builder carries advanced skill loadout")
	check(dev.bench.buttons.start_sandbox.get_parent() == dev.bench.lab_bar, "lab start action remains outside scrolling content")
	var offers_before: Array = Career.data.offers.duplicate(true)
	dev._to_card()
	check(dev.bench.buttons.to_offer.disabled and Career.data.offers == offers_before, "an active career job blocks an unreachable market offer")
	await key(KEY_ESCAPE)
	term.queue_free()
	await frames()
	check(not DevPanel.workbench_open and not paused, "scene disposal leaves no modal pause behind")
	print("WORKBENCH %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)
