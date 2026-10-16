extends SceneTree
# The assessment module's intro (tug right behind the module, its own title)
# and the factory drawing's cost there (it used to rebuild every frame).
# tools/run_test.sh tests/intro_bp_check.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var bot := {"aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "skip_contract": true}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _cost(g, n: int) -> float:
	var t0 := Time.get_ticks_usec()
	await _frames(n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _run() -> void:
	for id in ["e07c", "ts1"]:
		var g: Node = load("res://scenes/main.tscn").instantiate()
		g.bot = bot
		g.ship_id = id
		root.add_child(g)
		await _frames(90)
		Cap.save(root, "res://tests/out/intro_%s.png" % id)
		print("%s tug at %s m, stern %s m" % [id, g.dock.tug_pos() / 48.0, g.dock.stern])
		await _frames(400)
		var off := await _cost(g, 120)
		g.blueprint.toggle()
		await _frames(30)
		var on := await _cost(g, 120)
		print("%s frame: drawing off %.1f ms, on %.1f ms" % [id, off, on])
		g.queue_free()
		await _frames(3)
	quit()
