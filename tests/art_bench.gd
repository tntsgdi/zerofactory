extends SceneTree
# How long the drone art takes to record, per design (2026-10-18 frame-time work).
# tools/run_test.sh tests/art_bench.gd
const Art = preload("res://scripts/drone_art.gd")
var node: Node2D
var done := false

func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	node = Node2D.new()
	node.draw.connect(_bench)
	root.add_child(node)

func _bench() -> void:
	if done:
		return
	done = true
	for d in ["arrowring", "coreclaw", "tripod"]:
		for tool in [0, 3]:
			var n := 40
			var tot := 0
			for i in n:
				RenderingServer.canvas_item_clear(node.get_canvas_item())
				var t0 := Time.get_ticks_usec()
				Art.draw(node, d, {"heading": i * 0.01, "tool": tool, "open": 0.6, "t": i * 0.016, "thrust": Vector2(0.5, 0.2), "dash": false, "design": d, "base_xf": Transform2D.IDENTITY})
				tot += Time.get_ticks_usec() - t0
			print("ART %s tool %d: %.1f us per draw" % [d, tool, tot / float(n)])

func _process(_dt: float) -> bool:
	return done
