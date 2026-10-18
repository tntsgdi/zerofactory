extends SceneTree
# Stills of the berth's two computers on site and of what they open (2026-10-18,
# for a player's review of the layout): the berth with the computers, the
# terminal opened from the shop computer, the same after clicking the market
# tab, and from the berth computer. Test files only.
# tools/run_test.sh tests/console_shot.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const M := 48.0


func _initialize() -> void:
	Career.path = "user://zp_test_cshot_career.json"
	SaveGame.path = "user://zp_test_cshot_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Career.data = {}
	Career.start_new()
	Career.data.money = 41250.0
	Career.save()
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	var c: Vector2 = g.consoles.centre(0)
	g.drone.alive = true
	g.drone.global_position = c + Vector2(1.2 * M, 0)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.zoom_override = 1.6
	g.cam_override = c + Vector2(4.0 * M, 1.0 * M)
	g.cam_pos = g.cam_override
	await _frames(40)
	Cap.save(root, "res://tests/out/cs_berth.png")
	g.open_console("terminal")
	await _frames(40)
	Cap.save(root, "res://tests/out/cs_home.png")
	var term = g.console_ui
	if term != null:
		# the contracts tile: locked on site, it says why and stays home
		term.sel = 0
		term.act()
		await _frames(12)
		print("chose the contracts tile on site: page %d, message \"%s\"" % [term.tab, term.msg])
		Cap.save(root, "res://tests/out/cs_locked.png")
		term.set_tab(4)
		await _frames(30)
		Cap.save(root, "res://tests/out/cs_supplies.png")
		term.close()
	await _frames(10)
	quit()
