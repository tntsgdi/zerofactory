extends SceneTree
# Esc menu -> "return to title" (clicked twice, as a player confirms it) from a
# contract, the training course and the assessment: the scene changes, no
# script errors. The click is handed straight to the HUD's input handler.
# tools/run_test.sh tests/menu_title.gd --fixed-fps 60

var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_menu_test_save.json"
	SaveGame.train_path = "user://zp_menu_test_training.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _click(hud) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	hud._input(ev)


func _run() -> void:
	for id in ["gr7", "ts1", "e07a"]:
		var scene: Node = load("res://scenes/main.tscn").instantiate()
		scene.bot = bot
		scene.ship_id = id
		root.add_child(scene)
		current_scene = scene
		await _frames(20)
		var g = scene
		if id == "ts1":
			# the training hint switch really switches Liang's automatic help off
			g.toggle_hints()
			g.radio.queue = []
			g.radio.now = {}
			g.tutorial.idle_t = 50.0
			g.tutorial._stuck()
			var off_ok: bool = not g.hints_on and g.tutorial.hint_level == 0
			g.toggle_hints()
			g.radio.queue = []
			g.radio.now = {}
			g.tutorial.idle_t = 50.0
			g.tutorial._stuck()
			var on_ok: bool = g.hints_on and g.tutorial.hint_level >= 1
			print(("  ok    " if off_ok and on_ok else "  FAIL  ") + "ts1: hints off -> no automatic help (level %d), on -> help comes" % g.tutorial.hint_level)
			if not (off_ok and on_ok):
				fails += 1
		g.toggle_menu()
		await _frames(5)
		var items: Array = g.hud._menu_items()
		var ti := -1
		for i in items.size():
			if items[i][0] == "title":
				ti = i
		g.hud.menu_hover = ti
		_click(g.hud)
		await _frames(2)
		g.hud.menu_hover = ti
		_click(g.hud)
		await _frames(10)
		var on_title: bool = root.get_children().any(func(n): return n.scene_file_path.ends_with("title.tscn")) or (current_scene != null and current_scene.scene_file_path.ends_with("title.tscn"))
		print(("  ok    " if on_title else "  FAIL  ") + "%s: menu -> title" % id)
		if not on_title:
			fails += 1
		for n in root.get_children():
			if n.scene_file_path.ends_with("title.tscn") or n.scene_file_path.ends_with("main.tscn"):
				n.queue_free()
		await _frames(3)
	for f in ["user://zp_menu_test_save.json", "user://zp_menu_test_training.json"]:
		for ext in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	print("MENU %s  (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
