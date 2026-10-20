extends SceneTree
# ES-112 "Iron Oath"'s vault doors (scripts/vault.gd): with the main breaker open
# the bus test point outside reads dead, but the locks' backup supply keeps the
# lock solenoids (and, back through them, what is on the bus) live; the vault
# door won't open and the release lever won't move against a live lock; the
# backup supply off too, the lever moves and the door swings with no power of its
# own; the other vault stays shut until its own lever is thrown.
# godot --headless --path . --fixed-fps 60 -s tests/es112_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_es112_save.json"
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
	Game.start_ship = "es112"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _v(g, tag: String) -> float:
	return g.sys.piece_volts(g.world.tag(tag))


func _run() -> void:
	print("ES-112: the vault doors")
	var g = _game()
	await _frames(3)
	check(g.vault.active(), "the ES-112 has its vaults")
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(10)
	check(not g.sys.bus_live, "the main breaker open: the bus test point reads dead")
	check(_v(g, "LS-1") > 100.0 and _v(g, "LS-2") > 100.0, "but both lock solenoids are live off the backup supply (%.0f V)" % _v(g, "LS-1"))
	check(_v(g, "CUSTODY") > 100.0, "and it feeds back into the bus through them: the custody register is live (%.0f V)" % _v(g, "CUSTODY"))
	g.do_wrench(_ctrl(g, "VD-1"))
	await _frames(2)
	check(not g.world.tag("VD-1").door_open, "vault one's door won't open against its live lock")
	g.do_wrench(_ctrl(g, "MR-1"))
	await _frames(2)
	check(not g.world.ctrls["MR-1"].state, "nor will its release lever move")
	g.do_wrench(_ctrl(g, "K-LB"))
	await _frames(10)
	check(_v(g, "LS-1") < 1.0 and _v(g, "CUSTODY") < 1.0, "the backup supply off: the locks and the bus read dead")
	g.do_wrench(_ctrl(g, "VD-1"))
	await _frames(2)
	check(not g.world.tag("VD-1").door_open, "the door still holds on its mechanical lock")
	g.do_wrench(_ctrl(g, "MR-1"))
	await _frames(2)
	g.do_wrench(_ctrl(g, "VD-1"))
	await _frames(2)
	check(g.world.ctrls["MR-1"].state and g.world.tag("VD-1").door_open and not (g.sys.bus_live or g.sys.aux), "its lever thrown, vault one's door swings open with no power at all")
	g.do_wrench(_ctrl(g, "VD-2"))
	await _frames(2)
	check(not g.world.tag("VD-2").door_open, "vault two stays shut until its own lever is thrown")
	g.queue_free()
	await _frames(2)
	print("ES112 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
