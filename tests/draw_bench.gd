extends SceneTree
# What a frame costs to show the same 60k segments drawn each way (drawn once,
# then only shown): which of the canvas calls keep their geometry and which
# are worked through again every frame.
# tools/run_test.sh tests/draw_bench.gd

const N := 60000


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in N:
		var a := Vector2(randf() * 1900.0, randf() * 1060.0)
		pts.append(a)
		pts.append(a + Vector2.from_angle(randf() * TAU) * 12.0)
		cols.append(Color(1, 1, 1, 0.4))
	var tri := PackedVector2Array()
	var tc := PackedColorArray()
	for i in N:
		var a: Vector2 = pts[i * 2]
		var b: Vector2 = pts[i * 2 + 1]
		var n: Vector2 = (b - a).normalized().orthogonal() * 0.5
		for q in [a - n, a + n, b + n, a - n, b + n, b - n]:
			tri.append(q)
			tc.append(Color(1, 1, 1, 0.4))
	var ways := {
		"multiline aa w1": func(ci: Node2D): ci.draw_multiline_colors(pts, cols, 1.0, true),
		"multiline w1": func(ci: Node2D): ci.draw_multiline_colors(pts, cols, 1.0, false),
		"multiline w-1": func(ci: Node2D): ci.draw_multiline_colors(pts, cols, -1.0, false),
		"triangles": func(ci: Node2D): RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), tri, tc),
	}
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for k in ways:
		var n := Node2D.new()
		n.draw.connect(func(): ways[k].call(n))
		root.add_child(n)
		for i in 10:
			await process_frame
		var cpu := 0.0
		var t0 := Time.get_ticks_usec()
		for i in 60:
			await process_frame
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		print("BENCH %-16s wall %.2f ms  render cpu %.2f ms  objects %d  calls %d" % [k, (Time.get_ticks_usec() - t0) / 60000.0, cpu / 60.0, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		n.queue_free()
		await process_frame
	quit()
