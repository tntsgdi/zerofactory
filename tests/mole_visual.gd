extends SceneTree
class ReferenceHeap extends Node2D:
	var cfg := {}
	var fines := 34.0
	var fines0 := 34.0
	var stream: Array = []
	func setup(_game, ship: Dictionary) -> void:
		cfg = ship.ore
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		# the heap: shaded to its level inside the hopper, once anyone can see in
		var b: Array = cfg.get("box", [0, 0, 0, 0])
		if fines > 0.0:
			var top: float = lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0))
			var r := Rect2(Vector2(b[0], top) * Geom.M, Vector2(b[2] - b[0], b[3] - top) * Geom.M)
			draw_rect(r, Color(0.32, 0.26, 0.2, 0.35))
			var k := 0
			var x: float = r.position.x + 6.0
			while x < r.end.x - 6.0:
				var y: float = r.position.y + 4.0 + float((k * 37) % 23)
				while y < r.end.y - 4.0:
					draw_circle(Vector2(x + float((k * 13) % 9), y), 1.6, Color(0.55, 0.45, 0.35, 0.5))
					y += 14.0
					k += 1
				x += 12.0
		for s in stream:
			draw_circle(s[0], 2.0, Color(0.6, 0.5, 0.38, 0.8 * (1.0 - s[2] / 0.9)))

var fails := 0
var output := ProjectSettings.globalize_path("res://proofs")
func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()
func _run() -> void:
	var ship := Ship.load_data("m14")
	var nodes := []
	var views := []
	for script in [ReferenceHeap, Ore]:
		var vp := SubViewport.new()
		vp.size = Vector2i(1024, 640)
		vp.world_2d = World2D.new()
		vp.use_hdr_2d = true
		vp.msaa_2d = Viewport.MSAA_2X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var n = script.new()
		vp.add_child(n)
		var fake = {"world": null, "state": "intro", "paused_sim": true}
		n.setup(fake, ship)
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.set_process(false)
		n.set_physics_process(false)
		n.stream = [[Vector2(29, 5) * Geom.M, Vector2.ZERO, 0.3], [Vector2(32, 4) * Geom.M, Vector2.ZERO, 0.5]]
		nodes.append(n)
		views.append(vp)
	await process_frame
	await process_frame
	for fill in [34.0, 17.0, 0.1, 0.0]:
		for zoom in [0.6, 1.1, 2.6]:
			for i in 2:
				nodes[i].fines = fill
				nodes[i]._process(0.0)
				views[i].canvas_transform = Transform2D(Vector2.RIGHT * zoom, Vector2.DOWN * zoom, Vector2(512,320) - Vector2(31.8,0) * Geom.M * zoom)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var a: Image = views[0].get_texture().get_image()
			var b: Image = views[1].get_texture().get_image()
			a.convert(Image.FORMAT_RGBA8)
			b.convert(Image.FORMAT_RGBA8)
			var da := a.get_data()
			var db := b.get_data()
			var changed := 0
			var max_diff := 0
			var sum_diff := 0
			for j in da.size():
				var d: int = absi(int(da[j]) - int(db[j]))
				if d > 0: changed += 1
				max_diff = maxi(max_diff, d)
				sum_diff += d
			print("VISUAL fill=", fill, " zoom=", zoom, " changed_channels=", changed, " max_diff=", max_diff, " mean_diff=", float(sum_diff) / da.size())
			# Permit only subpixel edge rounding, never reduced density or missing details.
			if max_diff > 1 or float(sum_diff) / da.size() > 0.02: fails += 1
			if fill == 34.0 and zoom == 1.1:
				a.save_png(output + "/mole-ore-before.png")
				b.save_png(output + "/mole-ore-after.png")
	for vp in views: vp.queue_free()
	await process_frame
	print("MOLE_VISUAL ", "PASS" if fails == 0 else "FAIL", " failures=", fails)
	quit(0 if fails == 0 else 1)
