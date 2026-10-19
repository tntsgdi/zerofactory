extends SceneTree
# CL-104 "Frost Store"'s cold chain (scripts/coldchain.gd): the holds start at
# -25 °C and a probe on each reads it; on the ship's own power the chillers and
# the plant hold them; the power off with nothing else, they warm, and a hold past
# -5 °C has thawed (its pallets keep 45 % of their value, for good); with the
# berth's temporary cooling plugged in first, the power can go and the holds stay
# cold; the berth's cooling socket doesn't touch the berth's power; the
# temperatures and the thaw survive a save.
# godot --headless --path . --fixed-fps 60 -s tests/cl104_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cl104_save.json"
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


func _secs(s: float) -> void:
	for i in int(s * 60.0):
		await process_frame


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "cl104"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	print("CL-104: the cold chain")
	var g = _game()
	await _frames(3)
	var cc = g.coldchain
	check(cc.active() and cc.room_temp("K2") <= -24.9, "the holds start at %.0f °C" % cc.room_temp("K2"))
	g.do_measure(_ctrl(g, "T-K2"))
	var r: Dictionary = g.sys.readings.get("T-K2", {})
	check(r.get("text", "").begins_with("-25"), "hold two's probe reads %s" % r.get("text", "?"))
	await _secs(4.0)
	check(cc.room_temp("K1") <= -24.9, "on the ship's own power the chillers hold them")
	g.do_wrench(_ctrl(g, "K-M"))
	await _secs(6.0)
	check(cc.room_temp("K1") > -24.8 and not g.sys.bus_live, "the power off with nothing else: they warm (%.1f °C)" % cc.room_temp("K1"))
	# on to the thaw (warmed most of the way by hand)
	cc.temp["K3"] = -5.2
	await _secs(8.0)
	var p = g.world.tag("PAL-31")
	check(cc.thawed.has("K3") and absf(p.value - 4800.0 * 0.45) < 1.0 and g.incidents.any(func(i): return i[1] == "thaw"),
		"past -5 °C hold three has thawed: a pallet keeps $%.0f of $4800" % p.value)
	check(not cc.thawed.has("K1"), "the others haven't yet")
	var st: Dictionary = cc.save_state()
	check(st.thawed.has("K3") and float(st.temp["K1"]) > -25.0, "the save keeps the temperatures and the thaw")
	g.queue_free()
	await _frames(2)

	print("CL-104: the berth's temporary cooling first")
	g = _game()
	await _frames(3)
	cc = g.coldchain
	g.do_wrench(_ctrl(g, "COLD-X"))
	check(g.world.ctrls["COLD-X"].state and not g.sys.aux, "the cooling socket plugged in (the berth's power socket untouched)")
	g.do_wrench(_ctrl(g, "K-M"))
	await _secs(12.0)
	check(not g.sys.bus_live and cc.room_temp("K1") <= -24.9 and cc.room_temp("K3") <= -24.9, "the power off: the holds stay at %.0f °C" % cc.room_temp("K1"))
	g.queue_free()
	await _frames(2)
	print("CL104 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
