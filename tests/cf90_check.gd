extends SceneTree
# CF-90 "Hive"'s container wall (scripts/boxbeam.gd): the strain gauges read their
# bays; a container's twist locks come off with the wrench and it comes away
# whole; the bays nearest the berth's hold emptied while the bays beyond them are
# still full: the wall kinks and what is beyond is damaged; the bays taken from
# the ends inwards: no kink; a container taken from under others lets the stack
# above sag; a pretension rod cut with its turnbuckle tight whips loose, and with
# it slackened comes away quietly; the habitat container cut under pressure bursts.
# godot --headless --path . --fixed-fps 60 -s tests/cf90_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cf90_save.json"
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
	Game.start_ship = "cf90"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


# off with every fixing (the twist locks), as a careful hand would
func _off(g, tag: String) -> void:
	var p = g.world.tag(tag)
	for j in g.world.joints_of(p):
		if j.alive:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	await _frames(3)


func _bay_off(g, b: int) -> void:
	for t in g.boxbeam.cfg.bays[b]:
		await _off(g, str(t))


func _run() -> void:
	print("CF-90: the wall")
	var g = _game()
	await _frames(3)
	check(g.ship_id == "cf90" and g.boxbeam.active(), "the CF-90 is a container wall")
	var s2: float = g.boxbeam.strain("SG-2")
	check(s2 > 30.0 and s2 < 80.0, "the gauge under bay three reads its bending (%.0f %%)" % s2)
	await _off(g, "C11")
	var c11 = g.world.tag("C11")
	check(c11.body != null and c11.cond > 0.99, "its twist locks undone: the top container of bay one comes away whole")
	# bay three emptied with bays one and two still on
	for t in ["C31", "C32", "C33"]:
		await _off(g, t)
	await _frames(20)
	check(_count(g, "beam_kink") == 0 and g.boxbeam.strain("SG-2") > 90.0, "bay three nearly empty: its gauge climbs to %.0f %%" % g.boxbeam.strain("SG-2"))
	await _off(g, "C34")
	await _frames(20)
	var c12 = g.world.tag("C12")
	check(_count(g, "beam_kink") == 1 and c12.cond <= 0.5, "emptied with the bays beyond still full: the wall kinks, bay one's are damaged (%.2f)" % c12.cond)
	check(g.boxbeam.save_state().get("kinked", []).has("fwd"), "the save keeps the kink")
	g.queue_free()
	await _frames(2)

	print("CF-90: from the ends inwards")
	g = _game()
	await _frames(3)
	for b in [6, 5, 4]:
		await _bay_off(g, b)
	await _frames(20)
	check(_count(g, "beam_kink") == 0 and _count(g, "stack_sag") == 0, "the aft bays taken from the stern inwards, each from the top: no kink, no sag")
	# a container from under others
	await _off(g, "C23")
	await _frames(4)
	check(_count(g, "stack_sag") == 1 and g.world.tag("C21").cond <= 0.6, "a container taken from under two others: the stack above sags (%.2f)" % g.world.tag("C21").cond)
	g.queue_free()
	await _frames(2)

	print("CF-90: the rods and the habitat")
	g = _game()
	await _frames(3)
	check(g.boxbeam.rod_pull("TR-3") > 50.0, "the tension probe reads the top rod (%.0f kN)" % g.boxbeam.rod_pull("TR-3"))
	var tr = g.world.tag("TR-3")
	g.on_cut_into(tr, g.world.frame(tr) * Geom.centroid(tr.poly))
	await _frames(4)
	check(_count(g, "rod_snap") == 1 and g.world.tag("CR-T").cond <= 0.6, "cut with its turnbuckle tight: it whips loose into the trolley (%.2f)" % g.world.tag("CR-T").cond)
	g.do_wrench(_ctrl(g, "TB-4"))
	await _frames(2)
	check(g.boxbeam.rod_pull("TR-4") < 1.0, "the other's turnbuckle slackened: it reads slack")
	var t4 = g.world.tag("TR-4")
	g.on_cut_into(t4, g.world.frame(t4) * Geom.centroid(t4.poly))
	await _frames(4)
	check(_count(g, "rod_snap") == 1, "and cut, it comes apart quietly")
	var hb = g.world.tag("C41")
	g.on_cut_into(hb, g.world.frame(hb) * Geom.centroid(hb.poly))
	await _frames(4)
	check(_count(g, "burst") > 0, "the habitat container cut with its 60 kPa still in it: it bursts")
	g.queue_free()
	await _frames(2)
	print("CF90 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
