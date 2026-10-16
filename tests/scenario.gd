extends SceneTree
# Scripted play-through pieces with stills: measure, cut the roof of B open,
# watch it blow out, grab the plate and fling it.
# tools/run_test.sh tests/scenario.gd -- <prefix>

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var frame := 0
var prefix := "sc"
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var steps: Array = []
var cut_path: Array = []
var cut_i := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		prefix = a[0]
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	_plan()


func at(m: Vector2) -> Vector2:
	return m * M


func park(m: Vector2) -> void:
	game.drone.global_position = at(m)
	game.drone.linear_velocity = Vector2.ZERO
	game.drone.reset_physics_interpolation()


func ctrl(id: String) -> Vector2:
	return game.world.ctrl_world(game.world.ctrls[id])


func _plan() -> void:
	steps = [
		[5, func(): park(Vector2(3.6, -5.2)); game.tools.set_tool(1); bot.aim = ctrl("GAS-AB")],
		[8, func(): bot.lmb = true],
		[10, func(): bot.lmb = false],
		[50, func(): park(Vector2(11.4, -5.3)); bot.aim = ctrl("P-C01")],
		[53, func(): bot.lmb = true],
		[55, func(): bot.lmb = false],
		[95, func(): shot("1_measure")],
		[100, func(): park(Vector2(8.9, -6.2)); game.tools.set_tool(2); cut_path = _line(Vector2(8.2, -4.5), Vector2(8.2, -3.2), 18) + _line(Vector2(9.55, -3.2), Vector2(9.55, -4.5), 18); cut_i = 0],
		[101, func(): bot.lmb = true],
		[160, func(): shot("2_cutting")],
		[200, func(): bot.lmb = false],
		[204, func(): shot("3_blowout")],
		[240, func(): shot("4_after")],
		[250, func(): _report()],
		[260, func(): game.tools.set_tool(3); park(Vector2(8.9, -6.4)); bot.aim = _free_center()],
		[263, func(): bot.lmb = true],
		[264, func(): bot.aim = at(Vector2(12.0, -7.0))],
		[330, func(): shot("5_grab")],
		[331, func(): bot.move = Vector2(1, 0.3)],
		[380, func(): bot.move = Vector2.ZERO; bot.lmb = false],
		[460, func(): shot("6_thrown"); _report()],
	]


func _line(a: Vector2, b: Vector2, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		out.append(at(a.lerp(b, float(i) / n)))
	return out


func _free_center() -> Vector2:
	for b in game.world.bodies:
		return b.global_transform * b.center_of_mass
	return at(Vector2(8.9, -4.0))


func _report() -> void:
	var s = game.sys
	print("t=%d  P A=%.1f B=%.1f C=%.1f D=%.1f E=%.1f SC=%.1f bodies=%d links=%s" % [frame, s.P("A"), s.P("B"), s.P("C"), s.P("D"), s.P("E"), s.P("SC"), game.world.bodies.size(), str(s.links.map(func(l): return "%s-%s:%d" % [l[0], l[1], int(l[2])]))])
	for n in game.world.rooms:
		print("  room ", n, " revealed=", game.world.rooms[n].revealed)
	for k in s.readings:
		print("  reading ", k, " = ", s.readings[k].text)
	for b in game.world.bodies:
		print("  body m=%.2f pos=%s v=%s pieces=%d" % [b.total_mass(), b.global_position / M, b.linear_velocity / M, b.pieces.size()])


func shot(n: String) -> void:
	Cap.save(root, "res://tests/out/%s_%s.png" % [prefix, n])


func _process(_dt: float) -> bool:
	frame += 1
	if cut_i < cut_path.size() and bot.lmb and game.tools.tool == 2:
		bot.aim = cut_path[cut_i]
		if frame % 2 == 0:
			cut_i += 1
	for s in steps:
		if s[0] == frame:
			s[1].call()
	return frame > 470
