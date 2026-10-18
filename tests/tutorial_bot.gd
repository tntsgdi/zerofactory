extends SceneTree
# Roadmap 1.5 acceptance. A bot takes the training course through the real
# controls — it flies the drone, picks tools, aims and clicks, holds the
# grapple, sweeps the laser — at a human pace: it reads every radio line to
# the end and thinks for a moment before each action. Every frame is 1/60 s
# of player time, so the frame count is how long a newcomer would take.
# With "chaos" it also makes one mistake per lesson and times the recovery.
# tools/run_test.sh tests/tutorial_bot.gd --fixed-fps 60 -- [chaos] [fast]
# (headless works too: --headless, no pictures.)
# Pass: all six lessons done in 15–20 min; each mistake recovered in <= 2 s.

const Cap = preload("res://tests/cap.gd")
const M := 48.0
const THINK := 1.8           # s a newcomer pauses before each action
var game
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "dash": false, "brake": false, "warp": false}
var frame := 0
var finished := false
var chaos := false
var think := THINK
var lesson_frames := {}
var lesson_start := 0
var last_lesson := -1
var lines_log: Array = []
var recover: Array = []      # [lesson, mistake, seconds]
var no_warp := false
var shots := false
var shot_done := {}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	chaos = a.has("chaos")
	shots = a.has("shots")
	if a.has("fast"):
		think = 0.3
	# a first-timer: slower to decide, and sits out the pumping in real time
	if a.has("newcomer"):
		think = 3.0
		no_warp = true
	SaveGame.train_path = "user://zp_test_training.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = "ts1"
	root.add_child(scene)
	game = scene
	_run()


func _process(_dt: float) -> bool:
	frame += 1
	var li: int = game.tutorial.lesson_i
	if li != last_lesson:
		if last_lesson >= 0:
			lesson_frames[last_lesson] = frame - lesson_start
		lesson_start = frame
		last_lesson = li
	if shots:
		var sid: String = game.tutorial.step().get("id", "")
		var want := {"rings": 200, "ask": 50, "isolate": 30, "frame": 400}
		if want.has(sid) and not shot_done.has(sid):
			shot_done[sid] = frame + int(want[sid])
		for k in shot_done:
			if typeof(shot_done[k]) == TYPE_INT and frame == shot_done[k]:
				Cap.save(root, "res://tests/out/tut_%s.png" % k)
				shot_done[k] = true
		if game.tutorial.done and not shot_done.has("cert") and game.get_node_or_null("TutorialHud") == null:
			for ch in game.get_children():
				if ch is TutorialHud and ch.stamp_t > 2.0:
					Cap.save(root, "res://tests/out/tut_cert.png")
					shot_done["cert"] = true
	if "watch" in OS.get_cmdline_user_args() and frame % 600 == 0:
		_say("watch: lesson %d step %d (%s) drone %s v %.0f alive %s" % [li, game.tutorial.step_i, game.tutorial.step().get("id", ""), (game.drone.global_position / 48.0).snapped(Vector2(0.1, 0.1)), game.drone.linear_velocity.length(), game.drone.alive])
	if frame > 60 * 60 * 30:
		_say("TIMEOUT in lesson %d step %d (%s)" % [li, game.tutorial.step_i, game.tutorial.step().get("id", "")])
		_report()
		return true
	return finished


func _say(s: String) -> void:
	var line := "[%6.1f s] %s" % [frame / 60.0, s]
	lines_log.append(line)
	print(line)


# ---------------------------------------------------------------- primitives

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_s: float = 60.0) -> bool:
	var f := 0
	while not cond.call():
		await process_frame
		f += 1
		if f > max_s * 60.0:
			return false
	return true


# a newcomer reads what Liang says, then thinks a moment
func _think() -> void:
	await _until(func(): return game.tutorial.lines_idle(), 40.0)
	await _frames(int(think * 60.0))


func _step_is(id: String) -> bool:
	return game.tutorial.step().get("id", "") == id


func _wait_step(id: String, max_s: float = 30.0) -> void:
	await _until(func(): return not _step_is(id), max_s)


func _m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * M


# TS-1 sits in the middle of the berth: go round it, not through it
const BLOCK := Rect2(14.4 * M, -2.6 * M, 13.0 * M, 5.2 * M)


func _route(from: Vector2, to: Vector2) -> Array:
	# down in one of the open bays: straight up and out first
	if BLOCK.has_point(from) and not BLOCK.has_point(to):
		var up := Vector2(from.x, BLOCK.position.y - 1.0 * M)
		return [up] + _route(up, to)
	# into an open bay: from above, straight down
	if BLOCK.has_point(to) and not BLOCK.has_point(from):
		var over := Vector2(to.x, BLOCK.position.y - 1.0 * M)
		return _route(from, over) + [to]
	var crosses := (from.y < BLOCK.end.y and to.y > BLOCK.end.y) or (from.y > BLOCK.end.y and to.y < BLOCK.end.y) or (from.y > BLOCK.position.y and from.y < BLOCK.end.y and to.y > BLOCK.position.y and to.y < BLOCK.end.y and absf(to.x - from.x) > 2.0 * M)
	if not crosses:
		return [to]
	var left := absf(from.x - BLOCK.position.x) + absf(to.x - BLOCK.position.x) < absf(from.x - BLOCK.end.x) + absf(to.x - BLOCK.end.x)
	var side := BLOCK.position.x - 1.0 * M if left else BLOCK.end.x + 1.0 * M
	return [Vector2(side, from.y), Vector2(side, to.y), to]


# fly the drone to a point (px) with WASD-like input, flight assist on
func _fly(to: Vector2, tol: float = 0.4, dash: bool = false, max_s: float = 25.0) -> void:
	var route := _route(game.drone.global_position, to)
	while route.size() > 1:
		await _fly_direct(route.pop_front(), 0.8, false, max_s)
	await _fly_direct(to, tol, dash, max_s)


func _fly_direct(to: Vector2, tol: float = 0.4, dash: bool = false, max_s: float = 25.0) -> void:
	var f := 0
	while f < max_s * 60.0:
		var d = game.drone
		var off: Vector2 = to - d.global_position
		if off.length() < tol * M and d.linear_velocity.length() < 60.0:
			break
		# keys are on or off: let go once flight assist needs the rest of the way to stop
		var v: float = d.linear_velocity.length()
		var toward: float = d.linear_velocity.dot(off.normalized())
		var stop_d := toward * toward / (2.0 * 760.0) if toward > 0.0 else 0.0
		bot.move = off.normalized() if stop_d < off.length() - tol * M * 0.5 else Vector2.ZERO
		bot.dash = dash and off.length() > 1.5 * M
		if f % 120 == 0 and OS.get_cmdline_user_args().has("debug"):
			_say("fly to %s: at %s v %.0f move %s state %s paused %s alive %s" % [to / M, d.global_position / M, v, bot.move, game.state, paused, d.alive])
		await process_frame
		f += 1
	bot.move = Vector2.ZERO
	bot.dash = false


# Shift + D held all the way through the long ring, then let go
func _dash_through(lr: Array) -> void:
	var f := 0
	while game.drone.global_position.x < lr[1].x + 0.5 * M and f < 600:
		var off: Vector2 = Vector2(lr[1].x + M, lr[1].y) - game.drone.global_position
		bot.move = Vector2(1.0, clampf(off.y / M, -0.6, 0.6)).normalized()
		bot.dash = true
		await process_frame
		f += 1
	bot.move = Vector2.ZERO
	bot.dash = false
	await _frames(40)


func _tool(n: int) -> void:
	game.tools.set_tool(n)
	await _frames(6)


# aim at a point and click once; wait for the tool's job to finish
func _click(at: Vector2) -> void:
	bot.aim = at
	await _frames(4)
	bot.lmb = true
	await _frames(2)
	bot.lmb = false
	await _frames(2)
	await _until(func(): return game.tools.job.is_empty(), 5.0)
	await _frames(6)


func _piece(tag: String):
	return game.world.tag(tag)


func _center(p) -> Vector2:
	return game.world.frame(p) * Geom.centroid(p.poly)


func _ctrl_pos(id: String) -> Vector2:
	return game.world.ctrl_world(game.world.ctrls[id])


# take every bolt / lock out of a piece (or only those matching y_sel), standing near it
func _unbolt_all(tag: String, keep: int = 0, stand: Vector2 = Vector2.INF, only: Callable = Callable()) -> void:
	var p = _piece(tag)
	var tries := {}
	while p != null and not p.gone:
		var js: Array = game.world.joints_of(p).filter(func(j): return j.type in ["bolt", "lock"] and (not only.is_valid() or only.call(game.world.joint_world(j))))
		if js.size() <= keep:
			return
		var j = js[0]
		tries[j] = tries.get(j, 0) + 1
		if tries[j] > 3:
			_say("cannot undo a %s on %s at %s" % [j.type, tag, game.world.joint_world(j) / M])
			return
		var jp: Vector2 = game.world.joint_world(j)
		await _fly(stand if stand != Vector2.INF else jp + _m(0, -2.0), 1.0 if stand != Vector2.INF else 1.6)
		await _click(jp)
		await _frames(int(think * 30.0))


func _unplug_all(tag: String) -> void:
	var p = _piece(tag)
	for l in game.world.lines_of(p):
		var end := 0 if l.a == p.id else 1
		var lp: Vector2 = game.world.line_end_world(l, end)
		await _fly(lp + _m(0, -2.0), 1.6)
		await _click(lp)


# bolts and connectors until it floats free (a few tries, saying why not)
func _free(tag: String) -> bool:
	for attempt in 3:
		var p = _piece(tag)
		if p == null or p.body != null:
			return true
		await _tool(4)
		await _unbolt_all(tag, 0)
		await _unplug_all(tag)
		await _frames(20)
	var p2 = _piece(tag)
	if p2 != null and p2.body == null:
		var held := []
		for j in game.world.joints_of(p2):
			held.append("%s@%s" % [j.type, game.world.joint_world(j) / M])
		for l in game.world.lines_of(p2):
			held.append(l.id)
		_say("%s will not come free: %s (last message %s, drone %s)" % [tag, ", ".join(held), game.messages.back()[0] if not game.messages.is_empty() else "-", game.drone.global_position / M])
		return false
	return true


# hold the grapple on a piece and haul it into a recovery mouth
func _haul(tag: String, zone: String, max_s: float = 60.0) -> bool:
	var p = _piece(tag)
	if p == null:
		return true
	await _tool(3)
	var c := _center(p)
	# come at it from the open side: from above, unless it hangs under the section
	await _fly(c + _m(0, 2.6) if c.y > BLOCK.end.y else c + _m(0, -2.6), 1.0)
	bot.aim = _center(p)
	await _frames(4)
	bot.lmb = true
	await _frames(10)
	var mouth: Vector2 = Dock.zpos(zone)
	var face: Vector2 = Dock.ZONES[zone].face
	var stand: Vector2 = mouth + face * 3.6 * M
	var route := _route(game.drone.global_position, stand)
	# a load down in the section comes straight up and out first
	if BLOCK.grow(-0.2 * M).has_point(_center(p)):
		var lift := Vector2(game.drone.global_position.x, BLOCK.position.y - 2.2 * M)
		route = [lift] + _route(lift, stand)
	var f := 0
	while not p.gone and f < max_s * 60.0:
		var d = game.drone
		if route.size() > 1 and d.global_position.distance_to(route[0]) < 0.8 * M:
			route.pop_front()
		var off: Vector2 = route[0] - d.global_position
		var tw: float = d.linear_velocity.dot(off.normalized())
		bot.move = off.normalized() if (tw * tw / 600.0 < off.length() and off.length() > 0.3 * M) else Vector2.ZERO
		# the load goes where the beam points: lead it along the route, into the mouth at the end
		bot.aim = mouth if route.size() == 1 else d.global_position + (route[0] - d.global_position).normalized() * 3.0 * M
		if f % 120 == 0 and OS.get_cmdline_user_args().has("debug"):
			_say("haul %s: drone %s piece %s held %s route %s strain %.2f over %s" % [tag, d.global_position / M, _center(p) / M, game.tools.held_piece != null, route.map(func(q): return q / M), game.tools.strain, game.tools.overweight])
		if game.tools.held_piece == null and not p.gone:
			# lost the hold: grab again
			bot.lmb = false
			await _frames(3)
			var pc := _center(p)
			await _fly(pc + (d.global_position - pc).normalized() * 2.2 * M, 1.0)
			bot.aim = _center(p)
			await _frames(3)
			bot.lmb = true
		await process_frame
		f += 1
	bot.lmb = false
	bot.move = Vector2.ZERO
	await _frames(20)
	return p.gone


# sweep the laser along a world path (px), holding the button
func _cut(path: Array, speed_px: float = 70.0) -> void:
	await _tool(2)
	var first: Vector2 = path[0]
	await _fly(first + _m(-1.0, -2.5), 0.8)
	bot.aim = first
	await _frames(4)
	bot.lmb = true
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var n := maxi(1, int(a.distance_to(b) / (speed_px / 60.0)))
		for k in n:
			bot.aim = a.lerp(b, float(k + 1) / n)
			await process_frame
	await _frames(30)
	bot.lmb = false
	await _frames(10)


# the welds joining two pieces mark where to cut; follow them while the pieces drift
func _weld_line(a, b) -> Array:
	var ws: Array = []
	for j in game.world.joints_of(a):
		if j.b == b.id or j.a == b.id:
			ws.append(game.world.joint_world(j))
	if ws.is_empty():
		return []
	# the seam runs across the beam: along its own short side
	var dir: Vector2 = game.world.frame(a).basis_xform(Vector2(0, 1)).normalized()
	ws.sort_custom(func(p, q): return p.dot(dir) < q.dot(dir))
	# a beam on the seam itself is in neither piece: run just inside the first one
	var n: Vector2 = dir.orthogonal()
	if n.dot(_center(a) - ws[0]) < 0.0:
		n = -n
	var sh: Vector2 = n * 0.08 * M
	return [ws[0] - dir * 0.5 * M + sh, ws[ws.size() - 1] + dir * 0.5 * M + sh]


func _cut_welds(ta: String, tb: String) -> void:
	await _tool(2)
	for attempt in 3:
		var a = _piece(ta)
		var b = _piece(tb)
		if a == null or b == null or _weld_line(a, b).is_empty():
			return
		var ln: Array = _weld_line(a, b)
		var mid: Vector2 = (ln[0] + ln[1]) * 0.5
		await _fly(mid + _m(-1.2, -2.6), 0.8)
		ln = _weld_line(a, b)
		if ln.is_empty():
			return
		bot.aim = ln[0]
		await _frames(3)
		bot.lmb = true
		var n := 90
		for k in n:
			ln = _weld_line(a, b)
			if ln.is_empty():
				break
			bot.aim = (ln[0] as Vector2).lerp(ln[1], float(k + 1) / n)
			await process_frame
		await _frames(20)
		bot.lmb = false
		await _frames(20)
		if OS.get_cmdline_user_args().has("debug"):
			var left := 0
			for j in game.world.joints_of(a):
				if j.b == b.id or j.a == b.id:
					left += 1
			_say("weld cut %d: %d welds left, drone %s line %s tool %d" % [attempt, left, game.drone.global_position / M, [ln[0] / M, ln[1] / M] if not ln.is_empty() else [], game.tools.tool])


func _mark(l: int) -> void:
	_say("lesson %d done" % l)


# ---------------------------------------------------------------- the course

func _run() -> void:
	await _frames(10)
	var tut = game.tutorial
	# TUT_00: listen
	await _until(func(): return tut.lesson_i >= 1, 90.0)
	_mark(0)
	await _lesson1()
	await _lesson2()
	await _lesson3()
	await _lesson4()
	await _lesson5()
	await _lesson6()
	await _frames(240)
	_report()
	finished = true


func _lesson1() -> void:
	var tut = game.tutorial
	await _think()
	for i in tut.rings.size():
		await _fly(tut.rings[i][0], 0.5)
	await _think()
	var lr: Array = tut.long_ring
	await _fly(lr[0] - _m(1.5, 0), 0.5)
	await _dash_through(lr)
	if chaos:
		# mistake: slam into the dock at full dash and lose the drone
		var t0 := frame
		game.hurt_drone(500.0, game.drone.global_position, "hit_hard")
		await _until(func(): return game.drone.alive and game.drone.spawn_t > 0.2, 10.0)
		recover.append([1, "drone destroyed", (frame - t0) / 60.0])
		await _fly(lr[1] + _m(1.0, 0), 0.6)
		if not tut.dash_done:
			await _fly(lr[0] - _m(1.5, 0), 0.5)
			await _dash_through(lr)
	await _think()
	await _fly(tut.stop_box.get_center(), 0.3)
	bot.brake = true
	await _until(func(): return not _step_is("stop"), 6.0)
	if _step_is("stop"):
		_say("stuck at stop: drone %s v %.0f box %s box_t %.2f" % [game.drone.global_position / M, game.drone.linear_velocity.length(), tut.stop_box, tut.box_t])
	bot.brake = false
	await _think()
	game.drone.assist = false
	await _frames(60)
	game.drone.assist = true
	await _think()
	await _tool(1)
	var cov = _piece("P-001")
	await _fly(_center(cov) + _m(-2.2, -0.6), 0.8)
	await _click(_center(cov))
	if _step_is("find"):
		_say("find: tool %d hover %s readings %s drone %s aim %s at %s vis %s allowed %s contract %s" % [game.tools.tool, game.tools.hover.get("kind", "-"), game.sys.readings.keys(), game.drone.global_position / M, game.tools.aim / M, game.world.pieces_at(game.tools.aim).map(func(q): return q.tag), game.tools._visible(game.tools.aim), game.tutorial.tool_allowed(1), game.contract_open])
	await _think()
	game.blueprint.toggle()
	await _frames(int(3.0 * 60))
	game.blueprint.toggle()
	await _until(func(): return tut.lesson_i >= 2, 20.0)
	_mark(1)


func _lesson2() -> void:
	var tut = game.tutorial
	await _think()
	await _tool(4)
	await _unbolt_all("P-001", 1)
	await _think()
	if chaos:
		# mistake: the last bolt out with nothing holding the plate (it drifts; it is not reset)
		var t0 := frame
		await _unbolt_all("P-001", 0)
		await _until(func(): return _piece("P-001").body != null, 5.0)
		recover.append([2, "plate let go (drifts, field brings it back)", (frame - t0) / 60.0])
	else:
		await _tool(3)
		var cov = _piece("P-001")
		await _fly(_center(cov) + _m(-2.2, 0.2), 0.8)
		bot.aim = _center(cov)
		await _frames(4)
		bot.lmb = true
		await _frames(20)
		# keep the hold, wrench the last bolt
		game.tools.set_tool(4)
		await _frames(6)
		bot.lmb = false
		var js: Array = game.world.joints_of(cov)
		if not js.is_empty():
			await _click(game.world.joint_world(js[0]))
		await _until(func(): return cov.body != null, 5.0)
		game.tools.set_tool(3)
		await _frames(6)
	await _think()
	await _haul("P-001", "metal")
	await _until(func(): return tut.lesson_i >= 3, 20.0)
	_mark(2)


func _lesson3() -> void:
	var tut = game.tutorial
	await _think()
	await _tool(1)
	await _fly(_ctrl_pos("PT-02") + _m(0, -1.6), 0.6)
	await _click(_ctrl_pos("PT-02"))
	await _think()
	tut.pick("b")
	await _think()
	game.blueprint.toggle()
	await _frames(int(4.0 * 60))
	game.blueprint.toggle()
	await _think()
	await _tool(4)
	if chaos:
		# mistake: unbolt the shell plate of a bay that was never verified
		var t0 := frame
		await _fly(_center(_piece("P-002")) + _m(0, -2.0), 1.0)
		await _unbolt_all("P-002", 0)          # first bolt: interlock; then it goes
		await _until(func(): return game.incidents.any(func(e): return e[1] == "blowout"), 8.0)
		var tb := frame
		await _until(func(): return _piece("P-002") != null and _piece("P-002").body == null and game.sys.P("TC") > 90.0, 6.0)
		recover.append([3, "plate off a full bay (blowout)", (frame - tb) / 60.0])
		var pp = _piece("P-002")
		_say("after reset: P-002 %s attached %s TC %.1f kPa links %s incidents %s" % [pp != null, pp != null and pp.body == null, game.sys.P("TC"), game.sys.links, game.incidents])
		await _think()
		await _tool(1)
		await _fly(_ctrl_pos("PT-02") + _m(0, -1.6), 0.6)
		await _click(_ctrl_pos("PT-02"))
		await _tool(4)
	await _fly(_ctrl_pos("V-02") + _m(0, -1.6), 0.6)
	await _click(_ctrl_pos("V-02"))
	await _think()
	await _tool(1)
	await _click(_ctrl_pos("PT-02"))
	await _think()
	await _tool(5)
	await _fly(_ctrl_pos("GAS-T1") + _m(0, -1.6), 0.6)
	await _click(_ctrl_pos("GAS-T1"))
	await _think()
	bot.warp = not no_warp
	await _until(func(): return game.sys.P("TC") < 5.0, 120.0)
	bot.warp = false
	await _think()
	await _tool(4)
	await _unbolt_all("P-002", 0)
	await _haul("P-002", "metal")
	await _until(func(): return tut.lesson_i >= 4, 30.0)
	_mark(3)


func _lesson4() -> void:
	var tut = game.tutorial
	await _think()
	await _tool(1)
	await _fly(_ctrl_pos("E-T01") + _m(0.6, -1.2), 0.6)
	await _click(_ctrl_pos("E-T01"))
	await _think()
	await _tool(4)
	if chaos:
		# mistake: unplug a live cable
		var t0 := frame
		var l = game.world.lines["c-b"]
		await _click(game.world.line_end_world(l, 0))      # interlock stops the first
		await _click(game.world.line_end_world(l, 0))      # the second bites
		var tb := frame
		await _until(func(): return game.world.lines["c-b"].alive and game.world.tag("B-T01") != null, 6.0)
		recover.append([4, "live cable unplugged", (frame - tb) / 60.0])
		await _think()
	await _click(_ctrl_pos("K-BT"))
	await _think()
	await _tool(1)
	await _click(_ctrl_pos("E-T01"))
	await _think()
	await _tool(4)
	await _click(_ctrl_pos("E-T02"))
	await _until(func(): return game.sys.charge("C-T01") < 0.002, 20.0)
	await _think()
	await _tool(1)
	await _click(_ctrl_pos("E-T01"))
	await _think()
	await _free("G-T01")
	await _think()
	await _haul("G-T01", "equip")
	await _until(func(): return tut.lesson_i >= 5, 30.0)
	_mark(4)


func _lesson5() -> void:
	var tut = game.tutorial
	await _think()
	await _think()
	if chaos:
		# mistake: drag the pump while it is still connected
		var t0 := frame
		await _tool(3)
		var pp = _piece("CP-T")
		await _fly(_center(pp) + _m(0, -2.4), 0.8)
		bot.aim = _center(pp) + _m(0, -3.0)
		await _frames(4)
		bot.lmb = true
		await _frames(90)
		bot.lmb = false
		recover.append([5, "pulled a connected pump (nothing to reset)", 0.0])
		await _think()
	await _tool(5)
	await _fly(_ctrl_pos("DR-T") + _m(-0.6, -1.6), 0.6)
	await _click(_ctrl_pos("DR-T"))
	bot.warp = not no_warp
	await _until(func(): return game.sys.fluid("res") < 0.005, 40.0)
	bot.warp = false
	await _think()
	await _free("CP-T")
	await _think()
	await _haul("CP-T", "equip")
	await _until(func(): return tut.lesson_i >= 6, 30.0)
	_mark(5)


func _lesson6() -> void:
	var tut = game.tutorial
	await _think()
	# 1. the struts' top bolts, from above; then the armour comes off at the wall weld
	await _tool(4)
	for st in ["ST-1", "ST-2"]:
		await _unbolt_all(st, 0, _m(26.0, -3.1), func(q): return q.y < 0.0)
	await _think()
	await _cut([_m(23.5, -2.6), _m(23.5, -1.4)])
	_say("armour free %s" % (_piece("ARM-T") != null and _piece("ARM-T").body != null))
	_say("armour delivered %s" % await _haul("ARM-T", "metal"))
	await _think()
	# 2. the frame is open on top now: struts and the tank come out upwards
	await _tool(4)
	for st in ["ST-1", "ST-2"]:
		await _unbolt_all(st, 0, _m(26.0, -1.0))
		_say("%s delivered %s" % [st, await _haul(st, "metal")])
		await _tool(4)
	await _unbolt_all("RT-T", 0, _m(26.0, -0.6))
	if chaos:
		# mistake: residue tank into the furnace
		await _haul("RT-T", "metal")
		await _until(func(): return game.incidents.any(func(e): return e[1] == "furnace"), 6.0)
		var tb := frame
		await _until(func(): return _piece("RT-T") != null, 6.0)
		recover.append([6, "residue tank into the furnace", (frame - tb) / 60.0])
		await _think()
		await _tool(4)
		await _unbolt_all("RT-T", 0, _m(26.0, -0.6))
	_say("tank delivered %s" % await _haul("RT-T", "hazard"))
	await _think()
	# 3. the beam: off the wall, too heavy whole, split at the reinforced joint
	await _tool(4)
	await _unbolt_all("BM-1", 0, _m(24.6, -0.6))
	await _think()
	await _tool(3)
	var bm = _piece("BM-1")
	if bm != null and bm.body != null:
		await _fly(_center(bm) + _m(0, -2.4), 1.0)
		bot.aim = _center(bm)
		await _frames(4)
		bot.lmb = true
		await _frames(60)
		_say("grapple on the whole beam: overweight %s" % game.tools.overweight)
		bot.lmb = false
		await _frames(10)
	await _think()
	# cut across where the two modules meet (in the beam's own frame)
	await _cut_welds("BM-1", "BM-2")
	_say("beam split: BM-1 free %s, BM-2 free %s, same body %s" % [_piece("BM-1") != null and _piece("BM-1").body != null, _piece("BM-2") != null and _piece("BM-2").body != null, _piece("BM-1") != null and _piece("BM-2") != null and _piece("BM-1").body == _piece("BM-2").body])
	_say("BM-1 delivered %s" % await _haul("BM-1", "metal"))
	_say("BM-2 delivered %s" % await _haul("BM-2", "metal"))
	# whatever got away the first time: go and get it (a player would too)
	for round in 3:
		if tut.done:
			break
		await _frames(30)
		for tg in ["ST-1", "ST-2", "ARM-T", "RT-T", "BM-1", "BM-2"]:
			for q in tut._pieces_of(tg):
				if q.body == null and q.mass < 0.15:
					continue
				if q.body == null:
					await _free(tg)
				if q.tag == tg:
					_say("again: %s delivered %s" % [tg, await _haul(tg, "hazard" if tg == "RT-T" else "metal")])
	await _until(func(): return tut.done, 30.0)
	if not tut.done:
		var left := []
		for tg in ["ARM-T", "BM-1", "BM-2", "RT-T", "ST-1", "ST-2"]:
			for q in tut._pieces_of(tg):
				left.append("%s%s@%s%s" % [tg, "" if q.tag == tg else "(part)", _center(q) / M, " free" if q.body != null else " fixed"])
		_say("frame not clear: %s" % ", ".join(left))
	_mark(6)


# ---------------------------------------------------------------- report

func _report() -> void:
	if last_lesson >= 0 and not lesson_frames.has(last_lesson):
		lesson_frames[last_lesson] = frame - lesson_start
	var total := 0.0
	for l in lesson_frames:
		var s: float = lesson_frames[l] / 60.0
		total += s
		print("  lesson %d: %4.1f min" % [l, s / 60.0])
	print("course time %.1f min (human pace: %.1f s thought per action)  certified %s  hints asked %d" % [total / 60.0, think, game.tutorial.done, int(game.tutorial.flags.get("HINTS", 0))])
	var ok: bool = game.tutorial.done and total / 60.0 >= 15.0 and total / 60.0 <= 20.0
	if chaos:
		var worst := 0.0
		for r in recover:
			print("  mistake in lesson %d: %s — back in %.1f s" % r)
			worst = maxf(worst, r[2])
		ok = game.tutorial.done and worst <= 2.0 and recover.size() >= 6
		print("CHAOS %s (worst recovery %.1f s, %d mistakes)" % ["PASS" if ok else "FAIL", worst, recover.size()])
	else:
		var mins := total / 60.0
		print("TUTORIAL %s  (all six lessons, certified)  time %.1f min vs target 15–20: %s" % ["PASS" if game.tutorial.done else "FAIL", mins, "in range" if ok else ("SHORTER" if mins < 15.0 else "LONGER")])
	# roadmap 2.9: the course's share of repetitive hand work, for the growth curve
	var sh: Dictionary = Game.op_share(game.ops)
	print("OPLOG tutorial: %d hand-work, %d decisions → %.0f%% repetitive  %s" % [sh.manual, sh.decision, sh.share * 100.0, str(game.ops)])
	if not chaos:
		var f := FileAccess.open(ProjectSettings.globalize_path("res://tests/out/oplog_tutorial.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"ops": game.ops, "share": sh}))
		f.close()
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.train_path + ext))
