extends SceneTree
# Stills for the consumable tiles and the readied breaching ring: snapped to a
# keel next to the pointer, then with nothing near. Writes tests/out/ring_*.png.
# Test files only.
# godot --path . --fixed-fps 60 -s tests/ring_shot.gd

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var frame := 0
var g


func _initialize() -> void:
	Txt.zh = true
	Career.path = "user://zp_test_ringshot_career.json"
	SaveGame.path = "user://zp_test_ringshot_save.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Career.data = {}
	Career.start_new()
	Career.save()
	root.add_child(preload("res://tests/test_window.gd").new())
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO,
		"items": {"repair": 2, "ring": 3, "spare": 1}}
	root.add_child(g)


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		40:
			g.drone.global_position = Vector2(14.0, 5.5) * M
			g.cam_override = Vector2(14.0, 4.5) * M
			g.zoom_override = 1.2
			g.bot.aim = Vector2(14.6, 4.1) * M
		60:
			g.arm_ring(true)
		120:
			Cap.save(root, "res://tests/out/ring_armed.png")
			g.bot.aim = Vector2(14.0, 30.0) * M
		150:
			Cap.save(root, "res://tests/out/ring_none.png")
			print("armed=%s aim=%s" % [g.ring_armed, g.ring_aim])
			return true
	return false
