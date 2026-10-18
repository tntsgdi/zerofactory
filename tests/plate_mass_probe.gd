extends SceneTree
# How heavy the ships' plates are against what the grapple tows (probe, 2026-10-18).
# tools/run_test.sh tests/plate_mass_probe.gd --fixed-fps 60
func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()

func _run() -> void:
	for ship in ["tug", "s09", "gr7", "pod", "h22", "m14"]:
		var g: Node = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		g.ship_id = ship
		root.add_child(g)
		for i in 6:
			await process_frame
		var masses: Array = []
		var heavy := 0
		for id in g.world.pieces:
			var p = g.world.pieces[id]
			if p.gone or p.cls != "metal":
				continue
			var m: float = p.mass
			masses.append(m)
			if m > g.grab_max():
				heavy += 1
		masses.sort()
		var n := masses.size()
		print("PLATES %s: %d hull pieces, median %.2f t, 90%% %.2f t, max %.2f t; %d over the %.1f t grapple" % [ship, n, masses[n / 2], masses[int(n * 0.9)], masses[n - 1], heavy, g.grab_max()])
		g.queue_free()
		for i in 4:
			await process_frame
	quit()
