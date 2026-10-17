extends SceneTree
# Roadmap 3.5 acceptance: basic work plans. A clean contract on the work tug
# turns the order of what was worked (controls, hoses) and the readings that
# stood then into the tug's plan. On the next tug the plan runs only on fresh
# readings no worse than they were: it waits to be measured, it holds on a
# reading that is worse, it stops for good on a control the ship does not
# have, and a door step always wants the rooms behind it read. A contract with
# an incident writes no plan. The automation key stops it. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/plan_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_plan_career.json"
	SaveGame.path = "user://zp_test_plan_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(job: Dictionary) -> Node:
	Game.contract = job
	Game.start_ship = job.ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _measure(g, key: String) -> void:
	var c = g.world.ctrls.get(key)
	if c != null:
		g.do_measure({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})


func _read_all(g) -> void:
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind in ["port", "test"] and not g.world.room_hidden(c.hidden_room) and g.world.ctrl_alive(c):
			var r = g.sys.readings.get(id)
			if r == null or g.sys.stale(r):
				_measure(g, id)


# runs the plan, measuring whatever it asks for; returns what it paused on
func _run_plan(g, max_frames: int) -> Dictionary:
	var asked := {}
	var f := 0
	while g.plan.running and f < max_frames:
		f += 1
		if g.plan.wait == "plan_measure":
			asked[g.plan.wait_arg] = true
			_measure(g, g.plan.wait_arg)
		elif g.plan.wait == "plan_hidden":
			# the operator opens the room the plan cannot reach
			var c = g.world.ctrls.get(g.plan.wait_arg)
			g.world.reveal(c.hidden_room, g.world.ctrl_world(c))
		elif g.plan.wait == "plan_differs":
			# the story differs because the ship has not got there yet: read it again later
			if f % 30 == 0:
				_measure(g, g.plan.wait_arg)
		await process_frame
	return {"asked": asked, "frames": f}


func _run() -> void:
	print("PLAN: a clean tug writes the plan")
	Career.data = {}
	Career.start_new()
	check(Career.active().get("ship", "") == "tug", "the first contract is the tug")
	var g = _game(Career.active())
	await _frames(2)
	check(g.plan != null and not g.plan.has_plan(), "no plan for the tug yet")
	# a careful operator: every gauge in reach read again as the work goes on
	var bot = Bot.new(g)
	var f := 0
	while not bot.step():
		f += 1
		if f % 20 == 0:
			_read_all(g)
		await process_frame
	await _frames(5)
	var plans: Dictionary = Career.data.get("plans", {})
	var steps: Array = plans.get("tug", [])
	check(g.incidents.is_empty() and steps.size() >= 3, "the tug's plan is on the books: %d steps" % steps.size())
	var with_pre := 0
	for st in steps:
		print("    step ", st.do, " ", st.ctrl, " ", st.pre)
		if not st.pre.is_empty():
			with_pre += 1
	check(with_pre > 0, "%d steps carry the readings that stood then" % with_pre)
	var door_ok := true
	for st in steps:
		var c = g.world.ctrls.get(st.ctrl)
		if c != null and c.kind in ["door", "hatch"]:
			var has_p := false
			for pr in st.pre:
				has_p = has_p or pr.kind == "pressure"
			door_ok = door_ok and has_p
	check(door_ok, "every door step wants a room pressure read")
	g.queue_free()
	await _frames(2)

	print("PLAN: the next tug runs it")
	var job := {"id": "PLAN-2", "ship": "tug", "fee": 0.0, "time": 900.0, "kit": {}}
	g = _game(job)
	await _frames(2)
	check(g.plan.has_plan() and g.plan.steps.size() == steps.size(), "the plan is loaded for the tug")
	check(g.plan.toggle() == "plan_running" and g.plan.running, "the plan key starts it")
	await _frames(int(WorkPlan.STEP_TIME * 60.0) + 10)
	var first_pre: bool = not steps[0].pre.is_empty()
	if first_pre:
		check(g.plan.i == 0 and g.plan.wait == "plan_measure", "nothing measured yet: it waits on step 1 (%s)" % g.plan.wait)
	var res: Dictionary = await _run_plan(g, 60 * 240)
	print("  ran in %d frames, asked to measure %s; stopped at %d on %s %s" % [res.frames, str(res.asked.keys()), g.plan.i, g.plan.wait, g.plan.wait_arg])
	check(g.plan.i == steps.size() and not g.plan.running, "every step done (%d/%d)" % [g.plan.i, steps.size()])
	check(not res.asked.is_empty(), "it asked for readings before acting")
	check(g.incidents.is_empty() and g.losses == 0.0, "no incident, no loss on the plan: %s" % str(g.incidents))
	check(int(g.ops.get("plan", 0)) == steps.size(), "the steps count as the machine's work (%d)" % int(g.ops.get("plan", 0)))
	g.queue_free()
	await _frames(2)

	print("PLAN: a reading worse than the plan's")
	g = _game(job)
	await _frames(2)
	for room in g.world.rooms:
		g.world.reveal(room, Vector2.ZERO)
	_read_all(g)
	# a step whose plan read a point dead or empty, where it reads live or full now
	var k := -1
	for n in g.plan.steps.size():
		for pr in g.plan.steps[n].pre:
			var r = g.sys.readings.get(pr.key)
			if k < 0 and r != null and not WorkPlan.present(pr.kind, float(pr.val)) and WorkPlan.present(pr.kind, float(r.val)):
				k = n
	if k >= 0:
		g.plan.i = k
		g.plan.toggle()
		await _frames(30)
		check(g.plan.running and g.plan.wait == "plan_differs" and g.plan.i == k, "it holds on step %d: %s" % [k + 1, g.plan.wait])
		g.toggle_auto()
		check(not g.plan.running and g.auto_paused, "the automation key stops it")
	else:
		check(false, "no step with a pressure or voltage reading to test")
	g.queue_free()
	await _frames(2)

	print("PLAN: not the ship it was made on")
	g = _game(job)
	await _frames(2)
	var gone: String = g.plan.steps[0].ctrl
	g.world.ctrls.erase(gone)
	g.plan.toggle()
	await _frames(10)
	check(not g.plan.running and g.plan.wait == "plan_changed" and g.plan.wait_arg == gone, "no %s aboard: it stops for good" % gone)
	g.queue_free()
	await _frames(2)

	print("PLAN: an incident writes no plan")
	g = _game(job)
	await _frames(2)
	g.plan.rec = [{"do": "w", "ctrl": "X", "pre": []}]
	g.incidents.append([0.0, "test", ""])
	g.plan.commit()
	check(Career.data.plans.tug.size() == steps.size(), "the old plan stands")
	check(WorkPlan.no_worse("pressure", 3.0, 0.4) and not WorkPlan.no_worse("pressure", 101.0, 0.4) and WorkPlan.no_worse("pressure", 2.0, 9.5)
		and not WorkPlan.no_worse("volts", 230.0, 0.0) and WorkPlan.no_worse("volts", 0.0, 230.0) and WorkPlan.no_worse("field", 1.0, 0.0), "no worse: what was dead or empty is still")
	g.queue_free()
	await _frames(2)
	print("PLAN %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true
