extends SceneTree
# Save mid-contract (after a real cut and a blowout), reload into a fresh game,
# compare. tools/run_test.sh tests/save_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
const M := 48.0
var game
var frame := 0
var stage := 0
var before := {}
var bot := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}


func _initialize() -> void:
	SaveGame.path = "user://zp_test_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_spawn()


func _spawn() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene


func _snap() -> Dictionary:
	var w = game.world
	var n := 0
	var area := 0.0
	for id in w.order:
		var p = w.pieces[id]
		if not p.gone:
			n += 1
			area += Geom.area(p.poly)
	var alive := 0
	for j in w.joints:
		if j.alive:
			alive += 1
	return {"pieces": n, "area": snappedf(area, 1.0), "joints": alive, "bodies": w.bodies.size(), "B": snappedf(game.sys.P("B"), 0.1), "C": snappedf(game.sys.P("C"), 0.1), "readings": game.sys.readings.size(), "revealed": w.rooms["B"].revealed}


func _process(_dt: float) -> bool:
	frame += 1
	match frame:
		5:
			var w = game.world
			game.do_measure({"kind": "ctrl", "ctrl": w.ctrls["P-C01"], "pos": w.ctrl_world(w.ctrls["P-C01"])})
			var roof = w.piece_at(Vector2(9.0, -3.8) * M, ["hull"])
			w.commit_cut(roof, PackedVector2Array([Vector2(8.3, -4.3) * M, Vector2(8.3, -3.4) * M]))
			w.commit_cut(roof, PackedVector2Array([Vector2(9.4, -4.3) * M, Vector2(9.4, -3.4) * M]))
		90:
			before = _snap()
			SaveGame.save(game)
			print("saved: ", before)
			game.queue_free()
		95:
			SaveGame.load_requested = true
			_spawn()
		110:
			var after := _snap()
			print("loaded: ", after)
			for k in ["pieces", "joints", "bodies", "readings", "revealed"]:
				print("  ", k, " ", "OK" if before[k] == after[k] else "MISMATCH %s vs %s" % [before[k], after[k]])
			print("  area ", "OK" if absf(before.area - after.area) < 5.0 else "MISMATCH")
			print("  pressure B ", before.B, " -> ", after.B, "  C ", before.C, " -> ", after.C)
			Cap.save(root, "res://tests/out/save_loaded.png")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path + ".bak"))
			return true
	return false
