extends SceneTree
# Real-input checks: the laser warns (red) close to equipment and cuts on into it; the
# wrench unbolts; the grapple strains against locks and tears them; the hatch
# needs its jam cleared. tools/run_test.sh tests/input_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var frame := 0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var steps: Array = []


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	var w = func(): return game.world
	steps = [
		[3, func(): _open_all(); _park(Vector2(12.4, -1.0)); game.tools.set_tool(2); bot.aim = Vector2(12.4, -0.2) * M],
		[5, func(): bot.lmb = true],
		[8, func(): bot.aim = Vector2(12.4, 1.2) * M],
		[30, func(): print("laser warned at C-01: ", not game.tools.warn.is_empty() and game.world.pieces.get(game.tools.warn.piece) == game.world.tag("C-01"))],
		[60, func(): bot.lmb = false; print("one stroke on, C-01 intact: ", game.world.tag("C-01").intact, " (cut into it: scrap)")],
		# wrench the four locks of C-03
		[70, func(): game.tools.set_tool(4); _park(Vector2(20.6, 0.6))],
		[72, func(): _press_joint("C-03", 0)],
		[110, func(): _press_joint("C-03", 1)],
		[150, func(): _press_joint("C-03", 2)],
		[190, func(): _press_joint("C-03", 3)],
		[230, func(): print("C-03 joints left: ", game.world.joints_of(game.world.tag("C-03")).size(), " lines: ", game.world.lines_of(game.world.tag("C-03")).size())],
		# grab it: the power plug (c4) and cooling line (q5) still hold it
		[232, func(): game.tools.set_tool(3); bot.aim = game.world.frame(game.world.tag("C-03")) * Geom.centroid(game.world.tag("C-03").poly)],
		[234, func(): bot.lmb = true],
		[236, func(): bot.aim = Vector2(20.6, -1.5) * M],
		[280, func(): Cap.save(root, "res://tests/out/in_strain.png"); print("strain ", snappedf(game.tools.strain, 0.01))],
		[340, func(): print("after pull C-03 free: ", game.world.tag("C-03").body != null, " cond ", snappedf(game.world.tag("C-03").cond, 0.01)); Cap.save(root, "res://tests/out/in_torn.png")],
		[341, func(): bot.lmb = false],
		# hatch: jammed, then cleared, then opened on the bus
		[350, func(): game.tools.set_tool(4); _park(Vector2(20.0, -5.2)); bot.aim = game.world.ctrl_world(game.world.ctrls["HATCH-SW"])],
		[352, func(): bot.lmb = true],
		[354, func(): bot.lmb = false],
		[400, func(): print("hatch opened while jammed: ", game.world.tag("HATCH-1").door_open); bot.aim = game.world.ctrl_world(game.world.ctrls["HATCH-JAM"])],
		[402, func(): bot.lmb = true],
		[404, func(): bot.lmb = false],
		[470, func(): bot.aim = game.world.ctrl_world(game.world.ctrls["HATCH-SW"])],
		[472, func(): bot.lmb = true],
		[474, func(): bot.lmb = false],
		[520, func(): print("hatch open now: ", game.world.tag("HATCH-1").door_open, "  C pressure ", snappedf(game.sys.P("C"), 0.1)); Cap.save(root, "res://tests/out/in_hatch.png")],
	]


func _open_all() -> void:
	for n in game.world.rooms:
		game.world.reveal(n, game.world.rooms[n].from)


func _park(m: Vector2) -> void:
	game.drone.global_position = m * M
	game.drone.linear_velocity = Vector2.ZERO
	game.drone.reset_physics_interpolation()


func _press_joint(t: String, i: int) -> void:
	var js: Array = game.world.joints_of(game.world.tag(t))
	if i >= js.size():
		js = game.world.joints_of(game.world.tag(t))
	if js.is_empty():
		return
	bot.aim = game.world.joint_world(js[0])
	bot.lmb = true
	await create_timer(0.05).timeout
	bot.lmb = false


func _process(_dt: float) -> bool:
	frame += 1
	for s in steps:
		if s[0] == frame:
			s[1].call()
	return frame > 525
