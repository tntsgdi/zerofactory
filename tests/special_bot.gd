extends SceneTree
# The special courses (design/新手教程与图鉴定案.md): a bot takes one course through
# the real controls, reading each step's done-condition to know what to do — a reading
# means measure there, a switch means throw it, "free" means unbolt and unplug, a
# delivery means haul it to the mouth its kind goes to, a mechanism's state means wait.
# With "chaos" it makes each lesson's dangerous move twice first (the interlock stops
# the first, the second goes wrong, the props come back) and then does it right.
# Pass: the course finishes, the family is certified, the first pass paid its bonus.
# tools/run_test.sh tests/special_bot.gd --fixed-fps 60 -- <family> [chaos]
# (headless works too)

const M := 48.0
var game
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "dash": false, "brake": false, "warp": false}
var family := "energy"
var chaos := false
var finished := false
var frame := 0
var log_lines: Array = []
var resets := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		family = a[0]
	chaos = a.has("chaos")
	Codex.mem = {"seen": {}, "new": {}, "certs": {}}
	root.add_child(preload("res://tests/test_window.gd").new())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	scene.ship_id = "sp_" + family
	root.add_child(scene)
	game = scene
	_run()


func _process(_dt: float) -> bool:
	frame += 1
	if frame > 60 * 60 * 15:
		_say("TIMEOUT at lesson %d step %s" % [game.tutorial.lesson_i, game.tutorial.step().get("id", "")])
		_report()
		return true
	return finished


func _say(s: String) -> void:
	var l := "[%6.1f s] %s" % [frame / 60.0, s]
	log_lines.append(l)
	print(l)


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


func _m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * M


func _center(p) -> Vector2:
	return game.world.frame(p) * Geom.centroid(p.poly)


func _ctrl_pos(id: String) -> Vector2:
	return game.world.ctrl_world(game.world.ctrls[id])


# over the rig, then down: the rig is open above
func _fly(to: Vector2, tol: float = 0.6, max_s: float = 25.0, lane_m: float = -4.0) -> void:
	var d = game.drone
	var lane := lane_m * M
	if absf(d.global_position.x - to.x) > 2.0 * M:
		if d.global_position.y > lane:
			await _fly_direct(Vector2(d.global_position.x, lane), 1.0, max_s)
		await _fly_direct(Vector2(to.x, lane), 1.0, max_s)
	await _fly_direct(to, tol, max_s)


func _fly_direct(to: Vector2, tol: float, max_s: float) -> void:
	var f := 0
	while f < max_s * 60.0:
		var d = game.drone
		var off: Vector2 = to - d.global_position
		if off.length() < tol * M and d.linear_velocity.length() < 60.0:
			break
		var toward: float = d.linear_velocity.dot(off.normalized())
		var stop_d := toward * toward / (2.0 * 760.0) if toward > 0.0 else 0.0
		bot.move = off.normalized() if stop_d < off.length() - tol * M * 0.5 else Vector2.ZERO
		await process_frame
		f += 1
	bot.move = Vector2.ZERO


func _tool(n: int) -> void:
	game.tools.set_tool(n)
	await _frames(6)


func _click(at: Vector2) -> void:
	bot.aim = at
	await _frames(4)
	bot.lmb = true
	await _frames(2)
	bot.lmb = false
	await _frames(2)
	await _until(func(): return game.tools.job.is_empty(), 6.0)
	await _frames(6)


# stand off the control on the open side of the piece it is on (above, or beside it)
func _at_ctrl(id: String, tool: int) -> void:
	await _tool(tool)
	var c = game.world.ctrls[id]
	var cp: Vector2 = _ctrl_pos(id)
	var dir := Vector2(0, -1)
	var host = game.world.pieces.get(c.piece) if c.piece != null else null
	if host != null:
		var bb: Rect2 = Geom.bbox(host.poly)
		var hc: Vector2 = game.world.frame(host) * bb.get_center()
		var off: Vector2 = cp - hc
		# a control on a side face: stand out to that side; on top (or low down): above it
		if absf(off.x) > bb.size.x * 0.35:
			dir = Vector2(signf(off.x), -0.4).normalized()
		elif off.y > 0.0:
			dir = Vector2(1.0 if off.x >= 0.0 else -1.0, -0.3).normalized()
	await _fly(cp + dir * 1.6 * M, 0.6)
	await _click(cp)


# the welds holding a piece, cut across with the laser (both passes along their line)
func _cut_welds(p) -> void:
	var ws: Array = []
	for j in game.world.joints_of(p):
		if j.type == "weld":
			ws.append(game.world.joint_world(j))
	if ws.is_empty():
		return
	var a: Vector2 = ws[0]
	var b: Vector2 = ws[ws.size() - 1]
	var dir: Vector2 = (b - a).normalized() if ws.size() > 1 else Vector2.DOWN
	a -= dir * 0.25 * M
	b += dir * 0.25 * M
	await _tool(2)
	await _fly((a + b) * 0.5 + _m(1.4, -1.2), 0.8)
	for pass_i in 3:
		bot.aim = a
		await _frames(4)
		bot.lmb = true
		var n := int(a.distance_to(b) / (30.0 / 60.0))
		for k in n:
			bot.aim = a.lerp(b, float(k + 1) / n)
			await process_frame
		bot.lmb = false
		await _frames(10)
		if game.world.joints_of(p).filter(func(j): return j.type == "weld").is_empty():
			return


func _free(tag: String) -> bool:
	for attempt in 4:
		var p = game.world.tag(tag)
		if p == null or p.body != null:
			return true
		if game.tutorial.tool_allowed(2) and not game.world.joints_of(p).filter(func(j): return j.type == "weld").is_empty():
			await _cut_welds(p)
		await _tool(4)
		for j in game.world.joints_of(p).filter(func(j): return j.type in ["bolt", "lock"]):
			var jp: Vector2 = game.world.joint_world(j)
			await _fly(jp + _m(0, -1.8), 1.2)
			await _click(jp)
		for l in game.world.lines_of(p):
			var end := 0 if l.a == p.id else 1
			var lp: Vector2 = game.world.line_end_world(l, end)
			await _fly(lp + _m(0, -1.8), 1.2)
			await _click(lp)
		await _frames(20)
	var p2 = game.world.tag(tag)
	return p2 == null or p2.body != null


# a point on the piece that is only the piece (it may have drifted into something)
func _grip(p) -> Vector2:
	var c := _center(p)
	var l: Array = game.world.pieces_at(c)
	if not l.is_empty() and l[0] == p:
		return c
	var wp: PackedVector2Array = game.world.world_poly(p)
	for k in [0.5, 0.75, 0.3]:
		for q in wp:
			var at: Vector2 = c.lerp(q, k)
			var l2: Array = game.world.pieces_at(at)
			if not l2.is_empty() and l2[0] == p:
				return at
	return c


# exit: metres the load is first taken out by (from under an overhang), before the lane;
# lane: the height it is carried across at (above a rig taller than the usual one)
func _haul(tag: String, zone: String, max_s: float = 60.0, exit: Vector2 = Vector2.ZERO, lane: float = -4.0) -> bool:
	var p = game.world.tag(tag)
	if p == null:
		return true
	if zone == "any":
		zone = game.sys.dest_of(p)
	await _tool(3)
	await _fly(_center(p) + (_m(1.6, 0.0) if exit != Vector2.ZERO else _m(0, -2.4)), 1.0, 25.0, lane)
	bot.aim = _grip(p)
	await _frames(4)
	bot.lmb = true
	await _frames(10)
	var mouth: Vector2 = Dock.zpos(zone)
	var stand: Vector2 = mouth + Dock.ZONES[zone].face * 3.6 * M
	var route: Array = [Vector2(game.drone.global_position.x, lane * M), Vector2(stand.x, lane * M), stand]
	if exit != Vector2.ZERO:
		var out: Vector2 = game.drone.global_position + exit * M
		route = [out, Vector2(out.x, lane * M), Vector2(stand.x, lane * M), stand]
	var f := 0
	while not p.gone and f < max_s * 60.0:
		var d = game.drone
		if route.size() > 1 and d.global_position.distance_to(route[0]) < 0.8 * M:
			route.pop_front()
		var off: Vector2 = route[0] - d.global_position
		var tw: float = d.linear_velocity.dot(off.normalized())
		bot.move = off.normalized() if (tw * tw / 600.0 < off.length() and off.length() > 0.3 * M) else Vector2.ZERO
		bot.aim = mouth if route.size() == 1 else d.global_position + (route[0] - d.global_position).normalized() * 3.0 * M
		if game.tools.held_piece == null and not p.gone:
			bot.lmb = false
			await _frames(3)
			# back in from the side it is taken out by (the near side may be behind the rig)
			var side: Vector2 = exit.normalized() if exit != Vector2.ZERO else (d.global_position - _center(p)).normalized()
			await _fly(_center(p) + side * 2.2 * M, 1.0, 25.0, lane)
			bot.aim = _grip(p)
			await _frames(3)
			bot.lmb = true
		await process_frame
		f += 1
		if f % 90 == 0 and OS.get_cmdline_user_args().has("trace"):
			_say("  %s at %s, drone %s, held %s, route %d" % [tag, _center(p) / M, d.global_position / M, game.tools.held_piece != null, route.size()])
	bot.lmb = false
	bot.move = Vector2.ZERO
	await _frames(20)
	if not p.gone:
		_say("haul %s to %s failed: piece at %s (%.2f t, free %s), drone at %s, held %s" % [tag, zone, _center(p) / M, game.world.group_mass(p), p.body != null, game.drone.global_position / M, game.tools.held_piece != null])
	return p.gone


func _cut_line(id: String) -> void:
	var l = game.world.lines[id]
	var pts: PackedVector2Array = game.world.line_path_world(l)
	var a: Vector2 = pts[0].lerp(pts[1], 0.5)
	var dir: Vector2 = (pts[1] - pts[0]).normalized().orthogonal()
	await _tool(2)
	await _fly(a + _m(-1.0, -2.0), 0.8)
	bot.aim = a - dir * 0.4 * M
	await _frames(4)
	bot.lmb = true
	for k in 60:
		bot.aim = (a - dir * 0.4 * M).lerp(a + dir * 0.4 * M, k / 59.0)
		await process_frame
	bot.lmb = false
	await _frames(10)


# ---------------------------------------------------------------- one step, by what it waits for

func _do(st: Dictionary) -> void:
	var dn: Dictionary = st.done
	for k in dn:
		var a = dn[k]
		match k:
			"reading", "reading_after":
				await _at_ctrl(str(a[0]), 1)
			"switch":
				if game.sys.on(str(a[0])) != bool(a[1]):
					await _at_ctrl(str(a[0]), 4)
			"hose":
				await _at_ctrl(str(a), 5)
			"joint_gone":
				for j in game.world.joints:
					if j.alive and j.get_meta("tag", "") == str(a):
						var jp: Vector2 = game.world.joint_world(j)
						await _tool(4)
						await _fly(jp + _m(0, -1.8), 1.2)
						await _click(jp)
						break
			"door":
				var dc = game.world.ctrls.get(str(a[0]))
				if dc != null and bool(dc.state) != bool(a[1]):
					await _at_ctrl(str(a[0]), 4)
			"no_hose":
				if game.sys.hoses.has(str(a)):
					await _at_ctrl(str(a), 5)
			"all":
				for sub in a:
					await _do({"done": sub, "target": st.get("target", {}), "tools": st.get("tools", []), "warp": st.get("warp", false)})
			"free":
				await _free(str(a))
			"recovered":
				var ex: Array = st.get("exit", [])
				_say("%s delivered %s" % [a[0], await _haul(str(a[0]), str(a[1]), 60.0, Vector2(ex[0], ex[1]) if ex.size() == 2 else Vector2.ZERO, float(st.get("lane", -4.0)))])
			"liquid_seen":
				await _cut_line(str(st.target.line))
			"mod", "mod_safe", "fluid", "P", "step_t", "charge", "lines_done":
				# a wait on a port the step points at: put the hose on it first
				var tg: Dictionary = st.get("target", {})
				var tl: Array = st.get("tools", []).map(func(x): return int(x))
				var tc = game.world.ctrls.get(str(tg.get("ctrl", "")))
				if tc != null and tc.kind in ["switch", "valve"] and 4 in tl and not game.sys.on(str(tc.id)):
					await _at_ctrl(str(tc.id), 4)
				elif tc != null and tc.kind == "port" and 5 in tl and not game.sys.hoses.has(str(tc.id)):
					await _at_ctrl(str(tc.id), 5)
				bot.warp = st.get("warp", false)
				await _until(func(): return game.tutorial._check(dn), 90.0)
				bot.warp = false
			_:
				_say("no way to do %s" % k)


# the lesson's dangerous move, twice: the interlock stops the first, the second goes wrong
func _mistake(l: Dictionary) -> void:
	var g: Dictionary = l.get("guard", {})
	var pcs: Array = g.get("pieces", [])
	if pcs.is_empty():
		return
	var before: int = game.incidents.size()
	for i in 2:
		await _free(str(pcs[0]))
		await _frames(30)
	var went: bool = game.incidents.size() > before
	await _until(func(): return game.tutorial.reset_at < 0.0, 6.0)
	await _frames(40)
	resets += 1
	_say("mistake in %s: %s" % [l.id, "went wrong, reset" if went else "nothing happened"])


func _run() -> void:
	await _frames(20)
	var tut = game.tutorial
	while not tut.done:
		var li: int = tut.lesson_i
		var l: Dictionary = tut.lesson()
		var erred := false
		while tut.lesson_i == li and not tut.done:
			var st: Dictionary = tut.step()
			var sid: String = st.get("id", "")
			# the mistake, as soon as a step hands over the wrench (before it is safe)
			if chaos and not erred and li > 0 and 4 in st.get("tools", []).map(func(x): return int(x)) and not tut._check(l.get("guard", {}).get("until", {"x": 1})):
				erred = true
				await _mistake(l)
				continue
			if OS.get_cmdline_user_args().has("steps"):
				_say("step %s/%s" % [l.id, sid])
			await _do(st)
			await _until(func(): return tut.step().get("id", "") != sid or tut.lesson_i != li or tut.done, 20.0)
			if tut.step().get("id", "") == sid and tut.lesson_i == li and not tut.done:
				_say("stuck at %s/%s" % [l.id, sid])
				_report()
				finished = true
				return
		_say("lesson %s done" % l.id)
	await _frames(120)
	_report()
	finished = true


func _report() -> void:
	var cls := Codex.class_of_course(game.ship_id)
	# (knocks from the bot's own clumsy hauling don't count; the mechanisms' accidents do)
	var accidents: Array = game.incidents.filter(func(e): return not e[1] in ["interlock", "impact", "drone_hit"])
	var ok: bool = game.tutorial.done and Codex.certified(cls) and game.tutorial.bonus == Codex.BONUS and (chaos or accidents.is_empty())
	print("SPECIAL %s %s  (%.1f min, certified %s, bonus %s, incidents %s%s)" % [family, "PASS" if ok else "FAIL", frame / 3600.0, Codex.certified(cls), game.tutorial.bonus,
		str(game.incidents.map(func(e): return e[1])), ", resets %d" % resets if chaos else ""])
