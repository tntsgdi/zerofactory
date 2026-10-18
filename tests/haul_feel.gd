extends SceneTree
# P.4 probe (player 2026-10-17): "hauling sways all the time; heavy loads have
# so much inertia they can't stop". A bar is grabbed off its centre and hauled
# 10 m with the drone flying flat out, then let go with the drone braking.
# Reported per load: haul time over 10 m, sway (the most it turned, its top
# spin), and how far it drifted on after it was let go.
# tools/run_test.sh tests/haul_feel.gd --fixed-fps 60 -- [kit=haul_speed:n]
const M := 48.0
var done := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _haul(mass: float, kit: Dictionary) -> Dictionary:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	g.ship_id = "pod"
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	# open space over the far half of the berth, clear of the little pod
	var c := Vector2(24.0, -6.0) * M
	var poly := PackedVector2Array([c + Vector2(-72, -12), c + Vector2(72, -12), c + Vector2(72, 12), c + Vector2(-72, 12)])
	var p = g.world.add_piece("hull", poly, {"density": mass / (144.0 * 24.0 / (M * M)), "tag": "HF"})
	g.world.make_body([p], null)
	var b = p.body
	b.linear_velocity = Vector2.ZERO
	g.drone.global_position = c + Vector2(2.2 * M, -0.4 * M)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.tools.set_tool(3, true)
	await frames(2)
	# grabbed near one end, the way a player catches a long piece
	var grab := c + Vector2(-50, 0)
	g.tools.held_piece = p
	g.tools.held_body = b
	g.tools.held_local = g.world.frame(p).affine_inverse() * grab
	g.bot.lmb = true
	var x0: float = (b.global_transform * b.center_of_mass).x
	var a0: float = b.rotation
	var turn := 0.0
	var spin := 0.0
	var t := 0.0
	var vmax := 0.0
	# fly right flat out, the load trailing behind and a little below
	while (b.global_transform * b.center_of_mass).x < x0 + 10.0 * M and t < 12.0:
		g.bot.move = Vector2(1, 0)
		g.bot.aim = g.drone.global_position + Vector2(-2.0 * M, 0.4 * M)
		await process_frame
		t += 1.0 / 60.0
		if t > 0.6:
			turn = maxf(turn, absf(angle_difference(a0, b.rotation)))
			spin = maxf(spin, absf(b.angular_velocity))
		vmax = maxf(vmax, b.linear_velocity.length())
		if "frames" in OS.get_cmdline_user_args() and int(t * 60) % 12 == 0 and mass < 1.0:
			print("   t %.1f drone %s v %s | load %s v %s w %.2f | tow %.2f force %.2f contacts %d" % [t, (g.drone.global_position / M).snapped(Vector2(0.1, 0.1)), g.drone.linear_velocity.round(), ((b.global_transform * b.center_of_mass) / M).snapped(Vector2(0.1, 0.1)), b.linear_velocity.round(), b.angular_velocity, g.drone.tow_k, g.tools.tether_force, b.get_contact_count()])
	var v_rel: float = b.linear_velocity.length()
	if "trace" in OS.get_cmdline_user_args():
		var bb := Rect2()
		var first := true
		for id in g.world.pieces:
			var q = g.world.pieces[id]
			if q.gone or q == p:
				continue
			for v in g.world.world_poly(q):
				bb = Rect2(v, Vector2.ZERO) if first else bb.expand(v)
				first = false
		print("  ship %s m; load at %s m, drone at %s m, contacts %d" % [Rect2(bb.position / M, bb.size / M), (b.global_transform * b.center_of_mass) / M, g.drone.global_position / M, b.get_contact_count()])
	# let go and brake
	g.bot.lmb = false
	g.bot.move = Vector2.ZERO
	var at: Vector2 = b.global_transform * b.center_of_mass
	await frames(120)
	var drift: float = (b.global_transform * b.center_of_mass).distance_to(at) if is_instance_valid(b) else -1.0
	var r := {"mass": b.total_mass() if is_instance_valid(b) else mass, "t": t, "turn": rad_to_deg(turn), "spin": spin, "vmax": vmax, "v_rel": v_rel, "drift": drift / M}
	g.queue_free()
	await frames(4)
	return r


# the drone holds still and the aim is swung across: the load is flung
func _flick(kit: Dictionary) -> float:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var c := Vector2(30.0, -6.0) * M
	var poly := PackedVector2Array([c + Vector2(-30, -12), c + Vector2(30, -12), c + Vector2(30, 12), c + Vector2(-30, 12)])
	var p = g.world.add_piece("hull", poly, {"density": 1.0, "tag": "HF"})
	g.world.make_body([p], null)
	var b = p.body
	g.drone.global_position = c + Vector2(2.5 * M, 0)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.tools.set_tool(3, true)
	await frames(2)
	g.tools.held_piece = p
	g.tools.held_body = b
	g.tools.held_local = Geom.centroid(p.poly)
	g.bot.lmb = true
	g.bot.hold = true
	var d0: Vector2 = g.drone.global_position
	g.bot.aim = d0 + Vector2(-2.5 * M, 0)
	await frames(30)
	var best := 0.0
	for i in 40:
		var a := -PI + PI * minf(1.0, i / 10.0)
		g.bot.aim = d0 + Vector2(cos(a), sin(a)) * 3.0 * M
		await process_frame
		var rel: float = (b.linear_velocity - g.drone.linear_velocity).length()
		if rel > best:
			best = rel
		elif rel < best * 0.9 and best > 300.0:
			break
	g.bot.lmb = false
	var at: Vector2 = b.global_position
	await frames(60)
	var drift: float = b.global_position.distance_to(at) / M
	print("FLICK swung to %.0f px/s past the drone, flew on %.1f m in 1 s" % [best, drift])
	g.queue_free()
	await frames(4)
	return drift


func _run() -> void:
	var kit := {"skill_grapple_mass": 3}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("kit="):
			var kv: PackedStringArray = a.substr(4).split(":")
			kit["skill_" + kv[0]] = int(kv[1])
	for m in [0.8, 2.5, 6.0]:
		var r: Dictionary = await _haul(m, kit)
		print("HAUL %.1f t: 10 m in %.1f s (top %.0f px/s), turned %3.0f deg, top spin %.2f rad/s, let go at %.0f px/s and drifted %.1f m" % [r.mass, r.t, r.vmax, r.turn, r.spin, r.v_rel, r.drift])
	await _flick(kit)
	done = true
