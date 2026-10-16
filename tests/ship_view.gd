extends SceneTree
# A ship from its file, every room opened, photographed wide and close.
# tools/run_test.sh tests/ship_view.gd -- <ship id> [cx cy zoom]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var frame := 0
var id := "ts1"
var view := Vector3(21.0, 0.0, 1.6)
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2(500, -260), "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		id = a[0]
	if a.size() > 3:
		view = Vector3(float(a[1]), float(a[2]), float(a[3]))
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = id
	root.add_child(scene)
	game = scene


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 3:
		for n in game.world.rooms:
			game.world.reveal(n, game.world.rooms[n].from)
		game.drone.global_position = Vector2(view.x - 3.0, view.y - 4.0) * M
		game.drone.linear_velocity = Vector2.ZERO
		game.cam_override = Vector2(view.x, view.y) * M
		game.zoom_override = view.z
	if frame == 80:
		Cap.save(root, "res://tests/out/ship_%s.png" % id)
		print("bodies at rest: %d  rooms %s  bus %s  lamp lit %s" % [game.world.bodies.size(), game.world.rooms.keys(), game.sys.bus_live, game.world.tag("LAMP-T").get_meta("lit", false) if game.world.tag("LAMP-T") != null else "-"])
		return true
	return false
