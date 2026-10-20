extends SceneTree
# ARK-01 "Voyager": the rings still turning (scripts/rings.gd), the tail's weight on the
# spine's chords (scripts/spine.gd), the working days (scripts/workday.gd), and the five
# supplies that are not quite isolated from each other (the slip rings are breakers).
# godot --headless --path . --fixed-fps 60 -s tests/ark01_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ark01_save.json"
	SaveGame.allow_test = true
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


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "ark01"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _op(g, id: String) -> void:
	g.do_wrench(_ctrl(g, id))


func _has(g, kind: String) -> bool:
	return g.incidents.any(func(i): return i[1] == kind)


func _volts(g, tag: String) -> float:
	return g.sys.piece_volts(g.world.tag(tag))


func _free(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


# the ring's loads off: its battery and its slip ring
func _ring_dead(g, r: String) -> void:
	_op(g, "K-R" + r)
	_op(g, "SR-" + r)


func _run() -> void:
	print("ARK-01: the rings")
	var g = _game()
	await _frames(3)
	var rg = g.rings
	check(rg.turning("A") and rg.turning("B") and absf(rg.rpm["A"] - 3.0) < 0.01, "both rings come in turning (A %.1f, B %.1f rpm)" % [rg.rpm["A"], rg.rpm["B"]])
	g.do_measure(_ctrl(g, "RPM-A"))
	check(str(g.sys.readings.get("RPM-A", {}).get("text", "")).begins_with("3"), "the hub's tachometer reads %s" % g.sys.readings.get("RPM-A", {}).get("text", "?"))
	var ta = g.world.tag("HT-TAU")
	_op(g, "HT-TAU")
	await _frames(2)
	check(not ta.door_open, "the transfer airlock stays shut while the ring turns")
	# the loads still live: the brakes drive back into the ring bus, and the slip ring burns
	check(rg.loads_live("A"), "ring A's loads are live at the start (its battery and the slip ring)")
	_op(g, "BRK-A1")
	var r0: float = rg.rpm["A"]
	await _frames(60 * 9)
	check(absf(rg.rpm["A"] - r0) < 0.001 and _has(g, "slip_arc"), "braked with its loads live: no slowing, the slip ring arcs")
	g.queue_free()
	await _frames(2)

	print("ARK-01: despinning")
	g = _game()
	await _frames(3)
	rg = g.rings
	_ring_dead(g, "A")
	_ring_dead(g, "B")
	await _frames(3)
	check(not rg.loads_live("A") and not rg.loads_live("B"), "both rings' loads off (batteries out, slip rings open)")
	for i in 4:
		_op(g, "BRK-A%d" % (i + 1))
		_op(g, "BRK-B%d" % (i + 1))
	_op(g, "BCOOL-A")
	_op(g, "BCOOL-B")
	await _frames(60 * 4)
	check(rg.rpm["A"] < 3.0 - 0.1 and rg.rpm["B"] < 2.9 - 0.05, "the brakes slow them (A %.2f, B %.2f rpm)" % [rg.rpm["A"], rg.rpm["B"]])
	check(rg.cap_charge("A") > 0.05, "braking charges the brake capacitor (%.0f %%)" % (rg.cap_charge("A") * 100.0))
	# the capacitor fills: no more braking until it is dumped
	g.sys.iso["BCAP-A"].charge = 1.0
	var r1: float = rg.rpm["A"]
	await _frames(60)
	check(absf(rg.rpm["A"] - r1) < 0.001, "with its capacitor full the brakes take nothing off")
	_op(g, "BDUMP-A")
	await _frames(60 * 3)
	check(rg.cap_charge("A") < 0.5 and rg.rpm["A"] < r1, "dumped, the braking goes on (%.0f %%)" % (rg.cap_charge("A") * 100.0))
	check(not _has(g, "ring_twist"), "both braked together: no twist so far")
	# locked still turning: the bearing seizes
	_op(g, "LOCK-B")
	await _frames(3)
	check(_has(g, "bearing_seized") and rg.rpm["B"] == 0.0, "ring B's bearing locked while it turned: it seized")
	g.queue_free()
	await _frames(2)

	print("ARK-01: one ring braked alone")
	g = _game()
	await _frames(3)
	rg = g.rings
	_ring_dead(g, "A")
	await _frames(2)
	for i in 4:
		_op(g, "BRK-A%d" % (i + 1))
	_op(g, "BCOOL-A")
	_op(g, "BDUMP-A")
	await _frames(60 * 70)
	check(_has(g, "ring_twist"), "ring A braked with B still turning: the hull twists, the berth's clamps overload")
	check(rg.rpm["A"] <= 0.05, "ring A came to rest (%.2f rpm)" % rg.rpm["A"])
	_op(g, "LOCK-A")
	await _frames(3)
	check(rg.locked.has("A") and not _has(g, "bearing_seized"), "locked at rest: the bearing holds quietly")
	_op(g, "HT-TAU")
	await _frames(40)
	check(g.world.tag("HT-TAU").door_open, "the transfer airlock opens once ring A is locked")
	# something cut free of the ring still turning (B): it is thrown off
	_free(g, "LS-B")
	await _frames(3)
	check(_has(g, "ring_fling"), "a piece freed off ring B as it turns is thrown off")
	g.queue_free()
	await _frames(2)

	print("ARK-01: the greenhouse doors")
	g = _game()
	await _frames(3)
	_op(g, "HT-SBU1R")
	await _frames(30)
	check(_has(g, "ring_shock") and not g.world.tag("GL-U1").intact, "a spoke door opened with the farm at 100 kPa: the glass cracks")
	g.queue_free()
	await _frames(2)

	print("ARK-01: the spine")
	g = _game()
	await _frames(3)
	var sp = g.spine
	g.do_measure(_ctrl(g, "SS-5"))
	var txt: String = str(g.sys.readings.get("SS-5", {}).get("text", ""))
	check(absf(sp.stress("L5") - 1.0 / 1.4) < 0.02, "segment L5's chords carry %.0f %% of what they take (gauge %s)" % [sp.stress("L5") * 100.0, txt])
	var ct = g.world.tag("CT-5")
	g.on_cut_into(ct, g.world.frame(ct) * Geom.centroid(ct.poly))
	await _frames(3)
	check(_has(g, "spine_tear") and sp.torn.has("L5"), "a chord of L5 cut with the tail still on: the spine tears")
	g.queue_free()
	await _frames(2)
	g = _game()
	await _frames(3)
	sp = g.spine
	# the tail lightened first
	for h in sp.hung:
		if sp.weight_aft(269.0) < float(sp.cfg.cap) * 0.9:
			break
		var q = h[1]
		if not q.gone:
			g.world.remove_piece(q)
	await _frames(40)
	var ct6 = g.world.tag("CT-6")
	g.on_cut_into(ct6, g.world.frame(ct6) * Geom.centroid(ct6.poly))
	await _frames(40)
	check(not _has(g, "spine_tear"), "with the tail lightened first, a chord of L6 comes out quietly (%.0f t aft, a chord takes %.0f t)" % [sp.weight_aft(269.0), float(sp.cfg.cap)])
	check(sp.save_state().cut.has("CT-6"), "the cut chord is saved")
	g.queue_free()
	await _frames(2)

	print("ARK-01: power and the working day")
	g = _game()
	await _frames(3)
	check(_volts(g, "L5-D") > 1.0, "the trunk is severed at L6, yet L5 reads %.0f V (fed back from the rings through the slip rings)" % _volts(g, "L5-D"))
	_ring_dead(g, "A")
	_ring_dead(g, "B")
	await _frames(3)
	check(_volts(g, "L5-D") < 1.0 and _volts(g, "L1-LD") > 1.0, "the rings cut off: the forward trunk is dead (%.0f V), the lower harness still on L6's backup (%.0f V)" % [_volts(g, "L5-D"), _volts(g, "L1-LD")])
	_op(g, "K-L6")
	await _frames(3)
	check(_volts(g, "L1-LD") < 1.0, "L6's backup battery off: the lower harness goes dead")
	_op(g, "DIS-DC")
	await _frames(3)
	check(not g.world.ctrls["DIS-DC"].state, "the distribution centre's capacitor can't be bled with the aux grid still on")
	_op(g, "K-AUX")
	await _frames(2)
	_op(g, "DIS-DC")
	await _frames(400)
	check(not g.sys.bus_live, "the aux grid off and the capacitor bled: the main bus is dead")
	# the cold store warms with ring B's power gone, unless the berth's cooling is plugged in
	var t0: float = g.coldchain.room_temp("CS")
	await _frames(300)
	check(g.coldchain.room_temp("CS") > t0, "with ring B dead the cold store warms (%.1f -> %.1f °C)" % [t0, g.coldchain.room_temp("CS")])
	# the next day
	var wd = g.workday
	var fee0: float = g.fee
	check(wd.active() and wd.day == 1, "the job starts on day 1 of %d" % wd.planned())
	g.playtime = wd.day_len() + 1.0
	await _frames(3)
	check(wd.day == 2 and absf(g.fee - fee0 - 15000.0) < 1.0, "a working day ends: day 2, the day's running cost booked ($%.0f)" % (g.fee - fee0))
	check(FileAccess.file_exists(SaveGame.path), "and the whole state saved")
	g.queue_free()
	await _frames(2)
	print("ARK01 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
