extends SceneTree
# The berth's hauling drones (player 2026-10-18): "two of them go for the same
# thing; sometimes one flies straight through the hull; they should move like
# my drone, with its inertia, keep off the ship and the loose parts, smoothly."
# On the Heron with both haulers and the arm, rooms opened, loose scrap left
# inside the ship and outside it, some of it marked. For a minute of work:
#   no two machines ever after the same body,
#   no hauler (nor what it carries) ever inside the attached ship's walls,
#   no jumps in its speed (it accelerates like a drone, never teleports),
#   and the scrap gets delivered.
# tools/run_test.sh tests/hauler_nav.gd --fixed-fps 60
const M := 48.0
var done := false
var fails := 0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func plate(g: Node, c: Vector2, tag: String):
	var poly := PackedVector2Array([c + Vector2(-26, -12), c + Vector2(26, -12), c + Vector2(26, 12), c + Vector2(-26, 12)])
	var p = g.world.add_piece("hull", poly, {"density": 0.6, "tag": tag})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


func inside_walls(g: Node, at: Vector2) -> String:
	for id in g.world.pieces:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		var bb := Geom.bbox(g.world.world_poly(p))
		if not bb.has_point(at):
			continue
		if Geometry2D.is_point_in_polygon(at, g.world.world_poly(p)):
			return p.tag if p.tag != "" else str(p.id)
	return ""


func _run() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1, "arm": 1}}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].from)
	await frames(10)
	# the drone parked out of the way, up by the bay
	g.drone.global_position = Vector2(-4.0, -12.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	# loose scrap: some over the ship, some beside it, some in the opened cargo hold (C)
	var spots := [Vector2(30.0, -6.0), Vector2(24.0, -7.0), Vector2(36.0, -6.5), Vector2(8.0, 7.6), Vector2(44.0, -2.0)]
	var made: Array = []
	for i in spots.size():
		made.append(plate(g, spots[i] * M, "HN-%d" % i))
	# two marked by the operator
	g.hauler.toggle(made[0].body)
	g.hauler.toggle(made[1].body)
	# and one marked inside a room still shut in by its hull: there is no way in, so
	# it must be left alone, not fetched through the wall
	var shut = null
	for rn in g.world.rooms:
		var rc: Vector2 = Geom.centroid(g.world.rooms[rn].poly)
		if g.world.piece_at(rc) == null and g.nav_grid() != null:
			shut = plate(g, rc, "HN-SHUT")
			break
	if shut != null:
		g.hauler.toggle(shut.body)
	var machines: Array = [g.hauler, g.hauler2]
	var same := 0
	var clipped: Array = []
	var jump := 0.0
	var last_v := {}
	var t := 0.0
	var delivered := 0
	var start_carried: int = g.hauler.carried + g.hauler2.carried
	while t < 60.0:
		await process_frame
		t += 1.0 / 60.0
		# the same body after two machines
		var who := {}
		for h in machines:
			if h.body != null and is_instance_valid(h.body):
				if who.has(h.body):
					same += 1
				who[h.body] = true
		if g.arm != null and g.arm.body != null and is_instance_valid(g.arm.body) and who.has(g.arm.body):
			same += 1
		if int(t * 60.0) % 4 == 0:
			for h in machines:
				var tag := inside_walls(g, h.pos)
				if tag != "" and clipped.size() < 6:
					clipped.append("%s in %s at %s m (%s)" % [h.who, tag, (h.pos / M).snapped(Vector2(0.1, 0.1)), h.state])
				if h.state == "carry" and h.body != null and is_instance_valid(h.body):
					var tag2 := inside_walls(g, h.body.global_transform * h.body.center_of_mass)
					if tag2 != "" and clipped.size() < 6:
						clipped.append("%s's load in %s" % [h.who, tag2])
		for h in machines:
			var v: Vector2 = h.vel
			if last_v.has(h.who):
				jump = maxf(jump, (v - last_v[h.who]).length() * 60.0)
			last_v[h.who] = v
		delivered = made.filter(func(p): return p.gone or p.body == null or not is_instance_valid(p.body) or p.body.capture != null).size()
		if "trace" in OS.get_cmdline_user_args() and int(t * 60.0) % 90 == 0:
			for h in machines:
				print("   t %4.1f %s %-7s pos %s v %4.0f route %d wait %.1f body %s" % [t, h.who, h.state, (h.pos / M).snapped(Vector2(0.1, 0.1)), h.vel.length(), h.route.size(), h.wait_t, h.body.pieces[0].tag if h.body != null and is_instance_valid(h.body) else "-"])
		if delivered >= made.size():
			break
	print("HAULERS: %.0f s, %d of %d delivered (haulers %d, the arm the rest), top acceleration %.0f px/s² (limit %.0f)" % [t, delivered, made.size(), g.hauler.carried + g.hauler2.carried - start_carried, jump, g.hauler.ACCEL])
	check(same == 0, "no two machines after the same body (%d frames)" % same)
	check(clipped.is_empty(), "no hauler nor its load inside the ship's walls %s" % [clipped])
	check(jump <= g.hauler.ACCEL * 1.25, "it accelerates like a drone, no jumps")
	if shut != null:
		var fetched: bool = shut.gone or shut.body == null or not is_instance_valid(shut.body) or shut.body.capture != null
		check(not fetched, "a piece shut in a room with no way in is left alone (not fetched through the hull)")
	check(delivered == made.size(), "all the loose scrap delivered, by the haulers and the arm (%d / %d)" % [delivered, made.size()])
	print("HAULER_NAV %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	done = true
