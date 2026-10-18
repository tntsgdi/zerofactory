extends SceneTree
# Roadmap 4.4: the berth's professional equipment. Bought at the terminal (the
# second hauler only once there is a first), laid out so all of them fit. On
# site: two haulers work one list of marks at the same time; the heavy crane
# lifts an emptied 7 t cryogenic tank whole into the equipment bay (paid as a
# whole tank); the second equipment bay over the far end takes and pays as the
# first; the buffer platform holds what is let go on it, and the haulers leave
# it there; a keep-out zone stops a hauler going in until it is cleared.
# Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/berth_equip_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_equip_career.json"
	SaveGame.path = "user://zp_test_equip_save.json"
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
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


func _seconds(s: float) -> void:
	Engine.time_scale = 4.0
	await _frames(int(s * 60.0 / 4.0))
	Engine.time_scale = 1.0


func _game(ship: String, kit: Dictionary) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	return scene


# the k-th plain piece of metal light enough for a hauler
func _plate(g, k: int):
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and p.cls == "metal" and not p.kind in ["door", "hatch"] and p.mass > 0.2 and p.mass < 1.4 and g.world.lines_of(p).is_empty():
			if n == k:
				return p
			n += 1
	return null


# a piece cut loose: every fixing and line off, a body of its own
func _free(g, what):
	var p = g.world.tag(what) if what is String else what
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)
	await _frames(3)
	return p.body


func _put(b, at: Vector2) -> void:
	b.global_position = at - b.global_transform.basis_xform(b.center_of_mass)
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0


func _ledger_has(g, tag: String) -> Array:
	for l in g.ledger:
		if str(l[0]).find(tag) >= 0:
			return l
	return []


func _run() -> void:
	print("EQUIP: the terminal")
	Career.data = {}
	Career.start_new()
	Career.data.active = {}
	Career.data.market = true
	Career.data.seen = {"market": true}
	Career.data.money = 400000.0
	Career.save()
	var term: Node = load("res://scenes/terminal.tscn").instantiate()
	root.add_child(term)
	await _frames(3)
	var items := {}
	for b in term.BERTH:
		items[b[0]] = b
	term.buy(items.hauler2)
	check(not Career.data.upgrades.has("hauler2") and absf(float(Career.data.money) - 400000.0) < 1.0, "a second hauler is refused before the first")
	term.buy(items.hauler)
	term.buy(items.hauler2)
	check(Career.data.upgrades.has("hauler2") and absf(float(Career.data.money) - (400000.0 - 45000.0 - 60000.0)) < 1.0, "with the first bought, the second ($%d left)" % int(Career.data.money))
	for id in ["crane", "port2", "buffer", "zones"]:
		term.buy(items[id])
	check(["crane", "port2", "buffer", "zones"].all(func(id): return Career.data.upgrades.has(id)), "crane, second equipment bay, buffer platform, work zones all bought ($%d left)" % int(Career.data.money))
	term.tab = 1
	var last: Rect2 = term._facility_rect(term.BERTH.size() - 3)
	var all_in := true
	for j in term.BERTH.size() - 2:
		var r: Rect2 = term._facility_rect(j)
		all_in = all_in and r.end.x <= term.size.x - 40 and r.end.y <= term.size.y - 110
	check(all_in, "all %d facilities fit on the equipment page (the last ends at %d of %d px)" % [term.BERTH.size() - 2, int(last.end.y), int(term.size.y)])
	term.queue_free()
	await _frames(2)

	print("EQUIP: two haulers, one list")
	var g = _game("gr7", {"hauler": 1, "hauler2": 1})
	await _frames(3)
	check(g.hauler != null and g.hauler2 != null and g.hauler2.queue == g.hauler.queue, "both aboard, sharing the marks")
	var b1 = await _free(g, _plate(g, 3))
	var b2 = await _free(g, _plate(g, 9))
	_put(b1, Vector2(12.0, -6.0) * Geom.M)
	_put(b2, Vector2(30.0, -6.0) * Geom.M)
	for b in [b1, b2]:
		b.set_meta("arm_drop", -99.0)
		g.hauler.toggle(b)
	var both := false
	for i in 400:
		await process_frame
		if g.hauler.body != null and g.hauler2.body != null and g.hauler.body != g.hauler2.body:
			both = true
	await _seconds(30.0)
	check(both and g.hauler.carried + g.hauler2.carried >= 2, "both at work at once, %d + %d loads delivered" % [g.hauler.carried, g.hauler2.carried])
	g.queue_free()
	await _frames(2)

	print("EQUIP: the heavy crane")
	g = _game("fr26", {"crane": 1, "berth88": 1})
	await _frames(3)
	g.sys.set_fluid("lng1", 0.0)
	g.sys.vols["TV1"].n = 0.0
	var tk = await _free(g, "T-1")
	var m: float = tk.total_mass()
	check(m > g.grab_max() and m <= Crane.MAX_T, "an emptied tank, %.1f t: beyond the grapple" % m)
	var key: String = g.crane.toggle(tk)
	var k := 0
	while _ledger_has(g, "T-1").is_empty() and k < 120:
		await _seconds(1.0)
		k += 1
	var l: Array = _ledger_has(g, "T-1")
	check(not l.is_empty() and l[1] == "equip" and float(l[2]) > 20000.0 and key == "crane_marked", "the crane lifts it whole into the equipment bay in %d s ($%d)" % [k, int(float(l[2])) if not l.is_empty() else 0])
	g.queue_free()
	await _frames(2)

	print("EQUIP: the second equipment bay")
	g = _game("fr26", {"port2": 1, "berth88": 1})
	await _frames(3)
	check(Dock.ZONES.has("equip2") and Dock.ZONES.equip2.pos.x > 70.0, "over the far end (at %.0f m)" % float(Dock.ZONES.get("equip2", {}).get("pos", Vector2.ZERO).x))
	var e1 = await _free(g, "ENG-1")
	var ie: float = g.income_equip
	_put(e1, Dock.zpos("equip2") - Dock.ZONES.equip2.face * 1.0 * Geom.M)
	await _seconds(3.0)
	l = _ledger_has(g, "ENG-1")
	check(not l.is_empty() and l[1] == "equip" and g.income_equip > ie + 5000.0, "takes and pays whole equipment as the first does ($%d)" % int(g.income_equip - ie))
	check(Dock.nearest("equip", Vector2(70.0, 0.0) * Geom.M) == "equip2" and Dock.nearest("equip", Vector2(10.0, 0.0) * Geom.M) == "equip", "the machines make for the nearer of the two")
	g.queue_free()
	await _frames(2)

	print("EQUIP: the buffer platform")
	g = _game("gr7", {"hauler": 1, "buffer": 1})
	await _frames(3)
	g.auto_paused = true          # (the machines held while it is put there)
	var sb = await _free(g, _plate(g, 3))
	_put(sb, (Dock.BUFFER.get_center()) * Geom.M)
	sb.linear_velocity = Vector2(120.0, 40.0)
	await _seconds(4.0)
	check(g.dock.in_buffer(sb) and sb.linear_velocity.length() < 5.0, "let go on it, it stays put (%.1f px/s, at %s)" % [sb.linear_velocity.length(), str(((sb.global_transform * sb.center_of_mass) / Geom.M).snapped(Vector2(0.1, 0.1)))])
	g.auto_paused = false
	await _seconds(4.0)
	check(not g.hauler.auto_takes(sb) and g.dock.in_buffer(sb) and g.hauler.body != sb, "and the hauler leaves it there unless it is marked")
	g.queue_free()
	await _frames(2)

	print("EQUIP: a keep-out zone")
	g = _game("gr7", {"hauler": 1, "zones": 1})
	await _frames(3)
	var kb = await _free(g, _plate(g, 9))
	var at := Vector2(30.0, -6.0) * Geom.M
	_put(kb, at)
	kb.set_meta("arm_drop", -99.0)
	check(g.toggle_keepout(at) == "keepout_on" and g.keepout.size() == 1, "a zone set round it")
	g.hauler.toggle(kb)
	await _seconds(8.0)
	var outside := true
	for r in g.keepout:
		outside = outside and not r.has_point(g.hauler.pos)
	check(outside and g.hauler.carried == 0, "the hauler waits at its edge (%.0f m away)" % (g.hauler.pos.distance_to(at) / Geom.M))
	check(g.toggle_keepout(at) == "keepout_off" and g.keepout.is_empty(), "cleared again")
	await _seconds(20.0)
	check(g.hauler.carried >= 1, "and then it fetches it")
	g.queue_free()
	await _frames(2)
	print("EQUIP %s" % ("PASS" if fails == 0 else "FAIL"))
	finished = true
