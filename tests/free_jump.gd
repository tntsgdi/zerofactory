extends SceneTree
# Probe (player report 2026-10-17): "after undoing the fixings a piece sometimes
# shoots off for a moment — a stutter, or it ends up inside something". Every
# piece that is held only by fixings and lines is freed one at a time (the way
# the wrench does it) on several ships; for half a second after it comes free
# we record its top speed, its biggest jump in one frame, and how often the
# tunnel check had to put a body back.
# tools/run_test.sh tests/free_jump.gd --fixed-fps 60 -- [ship ...]
const M := 48.0
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var done := false
var rows: Array = []


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _probe(id: String) -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = bot.duplicate()
	g.ship_id = id
	root.add_child(g)
	await frames(10)
	var w = g.world
	for n in w.rooms:
		w.reveal(n, w.rooms[n].from)
	await frames(20)
	# gas out of every room, so freeing a plate is not a blowout
	for n in g.sys.vols:
		g.sys.vols[n].n = 0.0
	var tried := 0
	for pid in w.order.duplicate():
		if tried >= 40:
			break
		var p = w.pieces.get(pid)
		if p == null or p.gone or p.body != null:
			continue
		var js: Array = w.joints_of(p)
		if js.is_empty() or js.any(func(j): return not j.type in ["bolt", "lock", "clamp"]):
			continue
		tried += 1
		var g0: int = FreeBody.guard_hits
		if "trace" in OS.get_cmdline_user_args() and p.tag in ["ENG-F", "CON-S"]:
			print("  %s before: bbox %s m, joints %s" % [p.tag, Geom.bbox(w.world_poly(p)).position / M, js.map(func(j): return j.type)])
			var qp := PhysicsPointQueryParameters2D.new()
			qp.position = w.frame(p) * Geom.centroid(p.poly)
			qp.collision_mask = 0xFFFF
			var hits: Array = g.get_world_2d().direct_space_state.intersect_point(qp, 16)
			print("    colliders at centre: %s" % [hits.map(func(h): return "%s(layer %d)" % [h.collider.name, h.collider.collision_layer])])
			print("    frame %s  centroid(local) %s m  centroid(world) %s m  poly pts %d  area %.0f  door %s" % [w.frame(p), Geom.centroid(p.poly) / M, (w.frame(p) * Geom.centroid(p.poly)) / M, p.poly.size(), Geom.area(p.poly), p.door])
		for j in js:
			w.kill_joint(j)
		if "trace" in OS.get_cmdline_user_args() and p.tag in ["ENG-F", "CON-S"]:
			w.piece_freed.connect(func(b): print("    at piece_freed: pos %s m  pieces %s" % [b.global_position / M, b.pieces.map(func(q): return q.tag)]), CONNECT_ONE_SHOT)
		for l in w.lines_of(p):
			w.kill_line(l)
		if "trace" in OS.get_cmdline_user_args() and p.tag in ["ENG-F", "CON-S"]:
			for f in 3:
				print("    t%d body %s pos %s m meta %s capture %s" % [f, p.body != null, (p.body.global_position / M) if p.body != null else Vector2.ZERO, p.body.get_meta_list() if p.body != null else [], p.body.capture if p.body != null else null])
				if f == 2:
					var machines := []
					for n in g.get_children():
						var sn: String = n.get_script().get_global_name() if n.get_script() != null else ""
						if sn in ["Arm", "Crane", "Hauler", "Mech"]:
							machines.append("%s at %s m" % [sn, (n.global_position / M) if n is Node2D else Vector2.ZERO])
					print("    machines: %s" % [machines])
				await process_frame
				await get_root().get_tree().physics_frame
		await frames(2)
		if p.body == null or p.gone:
			continue
		var b = p.body
		var last: Vector2 = b.global_position
		var trace: bool = "trace" in OS.get_cmdline_user_args() and p.tag in ["ENG-F", "CON-S"]
		if trace:
			print("  %s freed: calm %.2f mass %.2f pieces %d  body at %s m  com %s m" % [p.tag, b.calm, b.mass, b.pieces.size(), b.global_position / M, (b.global_transform * b.center_of_mass) / M])
		var vmax := 0.0
		var jump := 0.0
		for f in 30:
			await process_frame
			if not is_instance_valid(b) or p.gone:
				break
			vmax = maxf(vmax, b.linear_velocity.length())
			if trace and f < 8:
				print("    f%d v %s w %.2f contacts %d pos %s" % [f, b.linear_velocity.round(), b.angular_velocity, b.get_contact_count(), (b.global_position / M).snapped(Vector2(0.01, 0.01))])
			jump = maxf(jump, b.global_position.distance_to(last))
			last = b.global_position
		rows.append([id, p.tag if p.tag != "" else p.kind, vmax, jump, FreeBody.guard_hits - g0])
		# out of the way of the next one
		if is_instance_valid(b) and not p.gone:
			w.remove_body(b)
		await frames(2)
	g.queue_free()
	await frames(4)


func _run() -> void:
	var ships: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return a != "trace")
	if ships.is_empty():
		ships = ["gr7", "m14", "s09"]
	for id in ships:
		await _probe(id)
	rows.sort_custom(func(a, b): return a[2] > b[2])
	print("freed %d pieces; fastest first:" % rows.size())
	for r in rows.slice(0, 12):
		print("  %-5s %-10s  top speed %4.0f px/s  biggest jump %5.1f px/frame  put back %d" % r)
	var bad := rows.filter(func(r): return r[2] > 150.0 or r[3] > 6.0)
	for r in rows.filter(func(r): return r[4] > 0 or r[3] > 6.0):
		print("  ! %-5s %-10s  top speed %4.0f px/s  biggest jump %5.1f px/frame  put back %d" % r)
	var guards: int = rows.reduce(func(acc, r): return acc + r[4], 0)
	print("FREE_JUMP  %d of %d freed pieces jumped (over 150 px/s or 6 px in a frame); tunnel check fired %d times" % [bad.size(), rows.size(), guards])
	done = true
