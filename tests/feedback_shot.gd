extends SceneTree
# Stills for the user's feedback of 2026-10-17: the briefing card with the ship's
# manifest, the berth's two computers with the drone at one, the shop opened from
# it on site, and the terminal with an opening contract waiting. Writes
# tests/out/fb_*.png. Test files only.
# xvfb-run ... godot --path . --resolution 1920x1080 --rendering-driver opengl3 --fixed-fps 60 -s tests/feedback_shot.gd

const Cap = preload("res://tests/cap.gd")
var frame := 0
var g
var term


func _initialize() -> void:
	Txt.zh = true
	Career.path = "user://zp_test_fbshot_career.json"
	SaveGame.path = "user://zp_test_fbshot_save.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Career.data = {}
	Career.start_new()
	Career.data.money = 80000.0
	Career.save()
	root.add_child(preload("res://tests/test_window.gd").new())
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		5:
			g.open_contract()
		60:
			Cap.save(root, "res://tests/out/fb_briefing.png")
			g.close_contract()
		70:
			g.drone.global_position = Consoles.centre(0) + Vector2(70, 10)
			g.cam_override = Vector2(-2.0, 2.0) * Geom.M
			g.zoom_override = 1.2
		110:
			Cap.save(root, "res://tests/out/fb_consoles.png")
			g.open_console("shop")
		160:
			Cap.save(root, "res://tests/out/fb_console_shop.png")
			g.console_ui.close()
			g.queue_free()
		170:
			term = load("res://scenes/terminal.tscn").instantiate()
			root.add_child(term)
		230:
			Cap.save(root, "res://tests/out/fb_next_job.png")
			return true
	return false
