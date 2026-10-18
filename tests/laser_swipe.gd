extends SceneTree
# Regression: a quick flick across a bar must still cut it.
# The beam crawls through material (cut_speed) and flies through air, so on a
# fast swipe it always trails the pointer. Releasing the button used to drop the
# stroke where the beam had got to, which left the bar whole ("one swipe did not
# cut it"). The stroke now runs on to where the button came up.
var fails := 0
var done := false
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}

func _initialize() -> void:
	_run()

func _process(_dt: float) -> bool:
	return done

func check(ok: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		fails += 1

func frames(n: int = 3) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	Career.path = "user://zp_test_swipe_career.json"
	SaveGame.path = "user://zp_test_swipe_save.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	Career.data.money = 100000.0
	Career.sign_active()
	Game.contract = Career.active().duplicate(true)
	Game.start_ship = "tug"
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(6)
	g.tutorial = null
	g.tools.tool = 2

	# an isolated bar in empty space, so nothing else can absorb the stroke
	var c := Vector2(4000, 4000)
	var poly := PackedVector2Array([
		c + Vector2(-30, -9), c + Vector2(30, -9), c + Vector2(30, 9), c + Vector2(-30, 9)
	])
	var bar = g.world.add_piece("hull", poly, {})
	g.drone.alive = true
	g.drone.global_position = c + Vector2(0, 70)
	g.drone.linear_velocity = Vector2.ZERO
	var a: Vector2 = c + Vector2(-62, 0)
	var b: Vector2 = c + Vector2(62, 0)
	check(not g.world.hidden(a) and not g.world.hidden(b), "test bar sits in clear space")

	var before: int = g.world.pieces.size()
	# one held frame at the entry side, one frame of travel, then the button is
	# released long before the beam can cross the bar
	g.bot.aim = a
	g.bot.lmb = true
	await frames(1)
	g.bot.aim = b
	await frames(1)
	var lag: float = g.tools.front.distance_to(b)
	g.bot.lmb = false
	await frames(2)
	check(g.tools.tail_on, "the beam keeps travelling after the button comes up")
	check(lag > 40.0, "the beam is still %.0f px behind the pointer at release (the old stroke ended here)" % lag)
	await frames(45)
	check(not g.tools.tail_on, "the tail ends on its own")
	var after: int = g.world.pieces.size()
	check(after > before, "one flick severs the bar (%d -> %d pieces)" % [before, after])
	check(bar.gone or not bar.intact or after > before, "the bar itself came apart")

	# a stroke that never reaches the material must not cut anything
	var before2: int = g.world.pieces.size()
	g.bot.aim = a + Vector2(-80, 0)
	g.bot.lmb = true
	await frames(1)
	g.bot.aim = a + Vector2(-40, 0)
	await frames(1)
	g.bot.lmb = false
	await frames(40)
	check(g.world.pieces.size() == before2, "a flick through empty space cuts nothing")

	g.queue_free()
	await frames()
	print("LASER SWIPE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done = true
	quit(0 if fails == 0 else 1)
