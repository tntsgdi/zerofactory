extends SceneTree
# How long a whole ship's equipment art takes to record (2026-10-20 art rework: the
# richer drawings must not slow a redraw of ARK-01's two thousand pieces).
# tools/run_test.sh tests/art_perf.gd -- [ship]
var node: Node2D
var w: World
var done := false


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var id: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "ark01"
	w = World.new()
	root.add_child(w)
	Ship.build(w, Ship.load_data(id))
	w.finalize()
	node = Node2D.new()
	node.draw.connect(_bench)
	root.add_child(node)


func _bench() -> void:
	if done:
		return
	done = true
	var list: Array = w.pieces.values()
	var n_art := 0
	for p in list:
		if p.art != "":
			n_art += 1
	var best := 1e9
	var first := 0.0
	for i in 5:
		RenderingServer.canvas_item_clear(node.get_canvas_item())
		var t0 := Time.get_ticks_usec()
		w.draw_pieces(node, list, "art")
		if i == 0:
			first = Time.get_ticks_usec() - t0
		else:
			best = minf(best, Time.get_ticks_usec() - t0)
	print("ART_PERF %d pieces with art: first draw %.1f ms, redraw %.1f ms" % [n_art, first / 1000.0, best / 1000.0])


func _process(_dt: float) -> bool:
	return done
