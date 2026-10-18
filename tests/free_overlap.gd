extends SceneTree
# Probe: free the TS-1 power-bay equipment one by one (the way the wrench
# does) and watch each freed body for two seconds: how fast it leaves, and
# whether it ends up inside anything (another piece, free or still attached).
# tools/run_test.sh tests/free_overlap.gd --fixed-fps 60 [-- shots]

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var game


func _initialize() -> void:
	SaveGame.train_path = "user://zp_overlap_training.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _overlap(p) -> Array:
	var w = game.world
	var wp: PackedVector2Array = w.world_poly(p)
	var out: Array = []
	for id in w.order:
		var q = w.pieces[id]
		if q == p or q.gone or (q.body != null and q.body == p.body):
			continue
		var a := 0.0
		for poly in Geometry2D.intersect_polygons(wp, w.world_poly(q)):
			a += absf(Geom.area(poly))
		if a > 150.0:
			out.append("%s %.0f px²" % [q.tag if q.tag != "" else q.kind, a])
	return out


func _report_loaded() -> void:
	var w = game.world
	print("lesson %d step %d" % [game.tutorial.lesson_i, game.tutorial.step_i])
	for b in w.bodies:
		var tags: Array = b.pieces.map(func(q): return q.tag if q.tag != "" else q.kind)
		var bad: Array = []
		for q in b.pieces:
			bad.append_array(_overlap(q))
		print("body %s at %s v %.0f spin %.2f  inside: %s" % [tags, b.global_position / M, b.linear_velocity.length(), b.angular_velocity, bad])
	for i in 4:
		await _frames(60)
		for b in w.bodies:
			var bad2: Array = []
			for q in b.pieces:
				bad2.append_array(_overlap(q))
			if not bad2.is_empty():
				print("  t+%ds %s at %s v %.0f: %s" % [i + 1, b.pieces[0].tag, b.global_position / M, b.linear_velocity.length(), bad2])
	game.cam_pos = Vector2(20.0, 0.5) * M
	await _frames(20)
	Cap.save(root, "res://tests/out/free_overlap_user.png")
	quit()


func _all_overlaps() -> Array:
	var w = game.world
	var out: Array = []
	for id in w.order:
		var q = w.pieces[id]
		if q.gone or q.body == null:
			continue
		for o in _overlap(q):
			out.append("%s in %s" % [q.tag if q.tag != "" else q.kind, o])
	return out


# lesson 4 as a player might do it: isolate, then push the freed module about
func _lesson4() -> void:
	var w = game.world
	game.tutorial.process_mode = Node.PROCESS_MODE_INHERIT
	var gen = w.tag("G-T01")
	# 1. the mistake: unplug G-T01 while live -> arc -> the course resets the bay
	for j in w.joints_of(gen):
		w.kill_joint(j)
	var l = w.lines["c-g"]
	game.drone.global_position = w.line_end_world(l, 0) + Vector2(-60, -60)
	game.drone.spawn_t = 3.0
	game.do_wrench({"kind": "connector", "line": l, "end": 0, "pos": w.line_end_world(l, 0)})
	await _frames(20)
	print("after live unplug: G-T01 free %s, incidents %s" % [gen.body != null, game.incidents])
	await _frames(150)
	print("after reset: overlaps %s" % [_all_overlaps()])
	# 2. do it right, then shove the free module into its neighbours and the wall
	for c in ["K-BT", "E-T02"]:
		game.do_wrench({"kind": "ctrl", "ctrl": w.ctrls[c], "pos": w.ctrl_world(w.ctrls[c])})
	await _frames(240)
	gen = w.tag("G-T01")
	for j in w.joints_of(gen):
		w.kill_joint(j)
	for l2 in w.lines_of(gen):
		w.kill_line(l2)
	await _frames(4)
	print("G-T01 free %s" % (gen.body != null))
	for dir in [Vector2(-1, -0.2), Vector2(-1, 0), Vector2(1, 0)]:
		if gen.body == null:
			break
		gen.body.linear_velocity = dir * 260.0
		await _frames(90)
		print("shoved %s: overlaps %s" % [dir, _all_overlaps()])
	# 3. the grapple holding it and hauling it at the bulkhead / the floor
	for aim in [Vector2(16.0, 0.6), Vector2(19.2, 4.0), Vector2(23.5, 1.2)]:
		if gen.body == null:
			break
		game.tools.set_tool(3, true)
		var c: Vector2 = gen.body.global_transform * gen.body.center_of_mass
		game.drone.global_position = c + Vector2(0, -2.0) * M
		game.drone.linear_velocity = Vector2.ZERO
		game.drone.reset_physics_interpolation()
		bot.lmb = true
		game.tools.held_piece = gen
		game.tools.held_body = gen.body
		game.tools.held_local = Geom.centroid(gen.poly)
		var worst := []
		for f in 180:
			bot.aim = aim * M
			await process_frame
			var o2 := _all_overlaps()
			if o2.size() > worst.size():
				worst = o2
		bot.lmb = false
		game.tools.release_grab(false)
		await _frames(30)
		print("hauled toward %s: worst overlaps %s, after release %s" % [aim, worst, _all_overlaps()])
	# 4. fast hits: the light bus and capacitor freed and flung at the bulkhead and the module
	for tag in ["C-T01", "BUS-T"]:
		var q = w.tag(tag)
		for j in w.joints_of(q):
			w.kill_joint(j)
		for l3 in w.lines_of(q):
			w.kill_line(l3)
	await _frames(4)
	var bh = w.tag("TS-BH")
	var q0 := PhysicsRayQueryParameters2D.create(Vector2(19.2, -0.8) * M, Vector2(18.0, -0.8) * M, World.STATIC_LAYER)
	print("TS-BH static cols %s  ray hit %s" % [w.static_cols.get(bh.id, []).size(), game.get_world_2d().direct_space_state.intersect_ray(q0)])
	var bus = w.tag("BUS-T")
	print("bus body origin %s  piece centre %s" % [bus.body.global_position / M, (w.frame(bus) * Geom.centroid(bus.poly)) / M])
	for sp in [600.0, 1200.0, 2400.0]:
		if gen.body != null:
			print("  G-T01 before fling: mask %d ghost %.2f calm %.2f ccd %d pos %.2f m" % [gen.body.collision_mask, gen.body.ghost, gen.body.calm, gen.body.continuous_cd, (gen.body.global_transform * gen.body.center_of_mass).x / M])
		for tag in ["C-T01", "BUS-T"]:
			var q = w.tag(tag)
			if q != null and q.body != null:
				q.body.linear_velocity = Vector2(-sp, -sp * 0.1)
				q.body.angular_velocity = 3.0
		if gen.body != null:
			gen.body.linear_velocity = Vector2(-sp, 0.0)
		var worst2 := []
		for f in 90:
			await process_frame
			if sp == 600.0 and f < 20:
				var bq = w.tag("BUS-T")
				print("  f%d bus x %.2f v %.0f" % [f, (w.frame(bq) * Geom.centroid(bq.poly)).x / M, bq.body.linear_velocity.x])
			var o3 := _all_overlaps()
			if o3.size() > worst2.size():
				worst2 = o3
		var where := []
		for tag in ["C-T01", "BUS-T", "G-T01"]:
			var q = w.tag(tag)
			if q != null:
				where.append("%s x %.1f" % [tag, (w.frame(q) * Geom.centroid(q.poly)).x / M])
		print("flung at %d px/s: worst %s  now %s  %s" % [int(sp), worst2, _all_overlaps(), where])
	game.cam_pos = Vector2(20.0, 0.5) * M
	await _frames(10)
	Cap.save(root, "res://tests/out/free_overlap_l4.png")
	quit()


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = bot
	g.ship_id = "ts1"
	if "user_save" in OS.get_cmdline_user_args():
		# a copy of the player's training save (the original is never touched)
		SaveGame.allow_test = true
		SaveGame.load_requested = true
	root.add_child(g)
	game = g
	await _frames(10)
	if "user_save" in OS.get_cmdline_user_args():
		SaveGame.allow_test = false
		await _report_loaded()
		return
	if "lesson4" in OS.get_cmdline_user_args():
		await _lesson4()
		return
	game.tutorial.process_mode = Node.PROCESS_MODE_DISABLED
	var w = game.world
	for tag in ["C-T01", "G-T01", "B-T01", "BUS-T", "CP-T"]:
		var p = w.tag(tag)
		if not "keep_lines" in OS.get_cmdline_user_args():
			for l in w.lines_of(p):
				w.kill_line(l)
		for j in w.joints_of(p):
			w.kill_joint(j)
		await _frames(2)
		if p.body == null:
			print("%s did not come free" % tag)
			continue
		var b = p.body
		var start: Vector2 = w.frame(p) * Geom.centroid(p.poly)
		await _frames(8)
		var v0: float = b.linear_velocity.length()
		var w0: float = b.angular_velocity
		await _frames(110)
		var moved: float = (w.frame(p) * Geom.centroid(p.poly)).distance_to(start) / M
		print("%-6s  v %.0f px/s  spin %.2f rad/s  moved %.2f m  bodies %d  inside: %s" % [tag, v0, w0, moved, b.pieces.size(), ", ".join(_overlap(p)) if not _overlap(p).is_empty() else "nothing"])
	if "shots" in OS.get_cmdline_user_args():
		game.cam_pos = Vector2(20.0, 0.5) * M
		game.drone.global_position = Vector2(20.0, -3.0) * M
		await _frames(30)
		Cap.save(root, "res://tests/out/free_overlap.png")
	quit()
