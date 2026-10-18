extends SceneTree
# The ganged service head: one wrench pass takes the fixings of the same unit
# that sit next to the one under the pointer.
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
	Career.path = "user://zp_test_multi_career.json"
	SaveGame.path = "user://zp_test_multi_save.json"
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

	# a plate with four bolts on it, plus a neighbour plate that must stay alone
	var c := Vector2(5000, 5000)
	var plate = g.world.add_piece("hull", PackedVector2Array([
		c + Vector2(-60, -40), c + Vector2(60, -40), c + Vector2(60, 40), c + Vector2(-60, 40)
	]), {})
	var far = g.world.add_piece("hull", PackedVector2Array([
		Vector2(5400, 5400), Vector2(5460, 5400), Vector2(5460, 5460), Vector2(5400, 5460)
	]), {})
	var bolts: Array = []
	for off in [Vector2(-14, -10), Vector2(14, -10), Vector2(-14, 10), Vector2(14, 10)]:
		bolts.append(g.world.add_joint(plate, null, "bolt", c + off))
	var lone = g.world.add_joint(far, null, "bolt", Vector2(5430, 5430))
	var weld = g.world.add_joint(plate, null, "weld", c + Vector2(0, 26))
	check(bolts.size() == 4 and lone != null and weld != null, "test plate and fixings built")

	# stand next to the plate, otherwise the job is dropped as out of range
	g.drone.alive = true
	g.drone.global_position = c + Vector2(0, 60)
	g.drone.linear_velocity = Vector2.ZERO
	var p0: Vector2 = g.world.joint_world(bolts[0])
	var nearest = null
	var nd := INF
	for j in [bolts[1], bolts[2], bolts[3]]:
		var d: float = g.world.joint_world(j).distance_to(p0)
		if d < nd:
			nd = d
			nearest = j

	var t = g.tools
	t.tool = 4
	t.hover = {"kind": "joint", "joint": bolts[0], "pos": g.world.joint_world(bolts[0]), "d": 0.0, "label": ""}

	# stock tool: one fixing at a time
	g.job.kit = {}
	check(t._joint_batch(bolts[0]).is_empty(), "stock wrench takes one fixing")
	t._start_job()
	check(t.job.get("extra", []).size() == 0, "stock wrench job carries no extra fixings")
	t.job = {}

	# volume I .. III
	var want := {1: 1, 2: 2, 3: 3}
	for tier in [1, 2, 3]:
		g.job.kit = {"skill_wrench_multi": tier}
		var batch: Array = t._joint_batch(bolts[0])
		var names := batch.map(func(e): return e.joint.id)
		check(batch.size() == want[tier], "volume %d takes %d extra fixings (got %d)" % [tier, want[tier], batch.size()])
		check(not names.has(lone.id), "volume %d leaves the other plate alone" % tier)
		check(not names.has(weld.id), "volume %d never grabs a weld" % tier)
		check(names.has(nearest.id), "volume %d starts with the nearest fixing" % tier)
		t._start_job()
		var base: float = 0.55
		var expect: float = base * (1.0 + 0.28 * want[tier])
		check(is_equal_approx(t.job.dur, expect), "volume %d takes %.2fs for the pass" % [tier, expect])
		t.job = {}

	# a full pass really removes them all
	g.job.kit = {"skill_wrench_multi": 3}
	t._start_job()
	var alive_before := 0
	for j in [bolts[0], bolts[1], bolts[2], bolts[3]]:
		if j.alive:
			alive_before += 1
	t._step_job(10.0)
	var alive_after := 0
	for j in [bolts[0], bolts[1], bolts[2], bolts[3]]:
		if j.alive:
			alive_after += 1
	check(alive_before == 4 and alive_after == 0, "one pass removes all four fixings (%d -> %d alive)" % [alive_before, alive_after])
	check(lone.alive and weld.alive, "the other plate and the weld are untouched")

	g.queue_free()
	await frames()
	print("WRENCH MULTI %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	done = true
	quit(0 if fails == 0 else 1)
