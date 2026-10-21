extends SceneTree
# Fire by its chemistry (scripts/combustion.gd) and a holed tank's flow (systems.gd):
# a tank still under pressure bursts and throws most of its propellant out with it; a
# kerf through a vented tank seeps, cut through it empties within seconds; fuel in
# vacuum takes no light; in a room with air a spark lights it, the flame runs through
# the spill, the room's oxygen goes and its pressure rises, and it blows up; MMH and
# N₂O₄ light on contact in vacuum with no spark; an arc and the drone's plume light it.
# godot --headless --path . --fixed-fps 60 -s tests/fire_check.gd

const M := 48.0
var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_fire_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_fire_career.json"
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _play(g) -> void:
	await _frames(3)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	# the drone out of the way of everything below
	g.drone.global_position = Vector2(-60.0, -60.0) * M
	g.drone.linear_velocity = Vector2.ZERO


func _done(g) -> void:
	g.queue_free()
	await _frames(2)


func _liquid(g, look: String) -> float:
	return g.liquids.total_volume(look)


func _run() -> void:
	print("fire: a tank under pressure, cut")
	var g = await _game_play("vt80")
	var s = g.sys
	var t1 = g.world.tag("T-1")
	var look: String = g.liquids.look_of(s.fvol["t1"])
	var amt0: float = s.fluid("t1")
	var c: Vector2 = g.world.frame(t1) * Geom.centroid(t1.poly)
	check(s.bursts(t1) and amt0 > 1.0, "T-1 holds %.2f m³ under %.0f kPa" % [amt0, s.P("TU-1")])
	g.cut_kerf(t1, PackedVector2Array([c + Vector2(-1.0, -3.0) * M, c + Vector2(-0.6, -1.0) * M]))
	await _frames(20)
	var out: float = _liquid(g, look)
	check(out > amt0 * 0.5, "it bursts and throws its propellant out with it: %.2f m³ adrift within ⅓ s" % out)
	await _frames(90)
	var stuck: int = g.liquids.blobs.filter(func(b): return int(b.stuck) >= 0).size()
	check(g.liquids.count(look) > 10, "as globules all round (%d of them, %d already on a surface)" % [g.liquids.count(look), stuck])
	# the beam swept through the spill: it is in vacuum, nothing to burn with
	var b0 = g.liquids.blobs.filter(func(b): return b.look == look)[0]
	g.tools.cutting = true
	for i in 30:
		g.tools.front = b0.pos
		await process_frame
	g.tools.cutting = false
	check(g.combustion.burnt_kg == 0.0, "in vacuum the beam through it lights nothing (no oxidiser)")
	await _done(g)

	print("fire: a vented tank, a kerf, then cut through")
	g = await _game_play("vt80")
	s = g.sys
	var t3 = g.world.tag("T-3")
	# its pressurisation shut and its ullage vented (else the nitrogen bank keeps pushing)
	s.set_switch("PV-3", false)
	s.vols["TU-3"].n = 0.0
	look = g.liquids.look_of(s.fvol["t3"])
	var a0: float = s.fluid("t3")
	var c3: Vector2 = g.world.frame(t3) * Geom.centroid(t3.poly)
	var bb3: Rect2 = Geom.bbox(g.world.world_poly(t3))
	g.cut_kerf(t3, PackedVector2Array([Vector2(c3.x, bb3.position.y - 0.4 * M), Vector2(c3.x, bb3.position.y + 1.0 * M)]))
	await _frames(60)
	var seep: float = a0 - s.fluid("t3")
	check(seep > 0.0 and seep < a0 * 0.2, "a kerf into a vented tank: it seeps out under its own vapour pressure (%.3f m³ in 1 s)" % seep)
	g.cut_kerf(t3, PackedVector2Array([Vector2(c3.x + 0.3 * M, bb3.position.y - 0.5 * M), Vector2(c3.x + 0.3 * M, bb3.end.y + 0.5 * M)]))
	await _frames(60 * 3)
	check(s.fluid("t3") < a0 * 0.3, "cut through: it empties within seconds (%.2f → %.2f m³ in 3 s)" % [a0 - seep, s.fluid("t3")])
	await _done(g)

	print("fire: fuel in vacuum, fuel in air")
	g = await _game_play("vt80")
	s = g.sys
	var cb = g.combustion
	var far := Vector2(-40.0, -30.0) * M
	g.liquids.spill(far, Vector2.ZERO, 0.01, "fuel", 3, 0.0, 0.0, true)
	await _frames(5)
	cb.spark(far, 1.0)
	await _frames(30)
	check(cb.burnt_kg == 0.0, "a spark in fuel adrift in vacuum: nothing")
	var room := "P"
	var rp: Vector2 = g.world.rooms[room].bbox.get_center()
	check(g.world.room_at(rp) == room and s.P(room) > 90.0, "room %s holds air (%.0f kPa)" % [room, s.P(room)])
	var o2_0: float = cb.o2_avail(room)
	var p0: float = s.P(room)
	g.liquids.spill(rp, Vector2.ZERO, 0.004, "fuel", 1, 0.0, 0.0, true)
	g.liquids.spill(rp + Vector2(1.0, 0.0) * M, Vector2.ZERO, 0.004, "fuel", 1, 0.0, 0.0, true)
	g.liquids.spill(rp + Vector2(2.0, 0.0) * M, Vector2.ZERO, 0.004, "fuel", 1, 0.0, 0.0, true)
	await _frames(5)
	cb.spark(rp, 0.3)
	await _frames(3)
	check(cb.burning > 0, "a spark in fuel in air: it lights")
	var p_max := p0
	for i in 60 * 4:
		await process_frame
		p_max = maxf(p_max, s.P(room))
	var left := 0.0
	for b in g.liquids.blobs:
		if b.look == "fuel" and g.world.room_at(b.pos) == room:
			left += float(b.vol)
	check(left < 0.012 * 0.5, "the flame ran on through the rest of the spill (%.4f of 0.012 m³ left)" % left)
	check(cb.burnt_kg * 3.4 <= o2_0 * 1.02, "no more burnt than the room's oxygen allows (%.1f kg of fuel for %.1f kg of oxygen)" % [cb.burnt_kg, o2_0])
	check(cb.o2_avail(room) < o2_0 * 0.2, "it used the room's oxygen (%.2f → %.2f kg, %.2f kg of fuel burnt)" % [o2_0, cb.o2_avail(room), cb.burnt_kg])
	check(p_max > p0 * 3.0, "and its hot products raised the room's pressure (%.0f → %.0f kPa at the peak)" % [p0, p_max])
	check(not cb.blasts.is_empty(), "it went up as a blast (%s)" % (("%.1f kg TNT" % cb.blasts[0][1]) if not cb.blasts.is_empty() else "none"))
	await _done(g)

	print("fire: MMH meets N2O4 in vacuum")
	g = await _game_play("vt80")
	cb = g.combustion
	far = Vector2(-40.0, -30.0) * M
	g.liquids.spill(far, Vector2.RIGHT, 0.01, "mmh", 1, 0.0, 0.4, true)
	g.liquids.spill(far + Vector2(1.2, 0.0) * M, Vector2.LEFT, 0.01, "nto", 1, 0.0, 0.4, true)
	await _frames(60 * 3)
	check(cb.burnt_kg > 1.0, "they light on contact, no spark (%.1f kg of MMH burnt)" % cb.burnt_kg)
	check(not cb.blasts.is_empty() and cb.blasts[0][2] == "", "a blast, in vacuum (%s)" % (("%.2f kg TNT" % cb.blasts[0][1]) if not cb.blasts.is_empty() else "none"))
	await _done(g)

	print("fire: VT-80, its MMH tank and its N2O4 tank both cut open")
	g = await _game_play("vt80")
	cb = g.combustion
	s = g.sys
	check(g.liquids.look_of(s.fvol["t1"]) == "mmh" and g.liquids.look_of(s.fvol["t2"]) == "nto", "VT-80 carries MMH (T-1, T-3) and N2O4 (T-2)")
	for tg in ["T-1", "T-2"]:
		var tk = g.world.tag(tg)
		var cc: Vector2 = g.world.frame(tk) * Geom.centroid(tk.poly)
		var side: float = 1.0 if tg == "T-1" else -1.0
		g.cut_kerf(tk, PackedVector2Array([cc + Vector2(6.0 * side, -2.0) * M, cc + Vector2(6.5 * side, 1.0) * M]))
	var w2 := 0
	while cb.blasts.is_empty() and w2 < 60 * 8:
		await process_frame
		w2 += 1
	await _frames(60 * 2)
	var biggest := 0.0
	for bl in cb.blasts:
		biggest = maxf(biggest, float(bl[1]))
	check(not cb.blasts.is_empty(), "the sprays meet in vacuum and light on contact: %d blasts within %.1f s, the biggest %.1f kg TNT, %.0f kg of MMH burnt" % [cb.blasts.size(), w2 / 60.0, biggest, cb.burnt_kg])
	await _done(g)

	print("fire: what else lights it")
	g = await _game_play("vt80")
	cb = g.combustion
	rp = g.world.rooms["P"].bbox.get_center()
	g.liquids.spill(rp, Vector2.ZERO, 0.002, "fuel", 1, 0.0, 0.0, true)
	await _frames(5)
	g._arc(rp + Vector2(0.8, 0.0) * M, 440.0)
	await _frames(3)
	check(cb.burnt_kg > 0.0 or cb.burning > 0, "an electric arc beside it")
	await _done(g)
	g = await _game_play("vt80")
	cb = g.combustion
	rp = g.world.rooms["P"].bbox.get_center()
	g.liquids.spill(rp, Vector2.ZERO, 0.002, "fuel", 1, 0.0, 0.0, true)
	await _frames(5)
	# the drone's down-pointing nozzle firing just above it
	g.drone.global_position = rp - Vector2(0.0, 0.8) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.flame = [0.0, 0.0, 1.0, 0.0]
	await _frames(2)
	check(cb.burnt_kg > 0.0 or cb.burning > 0, "the drone's thruster plume")
	await _done(g)

	print("FIRE %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true


func _game_play(ship: String):
	var g = _game(ship)
	await _play(g)
	return g
