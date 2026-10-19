extends SceneTree
# Builds a ship alone (GR-7 unless named) and photographs it: tools/run_test.sh tests/ship_shot.gd -- [reveal] [zoom] [cx] [cy] [name] [ship]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var reveal := args.size() > 0 and args[0] == "reveal"
	var zoom := float(args[1]) if args.size() > 1 else 0.85
	var cx := float(args[2]) if args.size() > 2 else 21.0
	var cy := float(args[3]) if args.size() > 3 else 0.0
	var nm := args[4] if args.size() > 4 else "ship"
	root.add_child(preload("res://tests/test_window.gd").new())
	var w := World.new()
	root.add_child(w)
	Ship.build(w, Ship.load_data(args[5] if args.size() > 5 else "gr7"))
	w.finalize()
	if reveal:
		for n in w.rooms:
			w.rooms[n].revealed = true
			w.rooms[n].reveal_t = 1.0
		w.back_layer.queue_redraw()
		w.cover_layer.queue_redraw()
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Vector2(cx, cy) * Geom.M
	root.add_child(cam)
	cam.make_current()
	var free_n := w.bodies.size()
	print("pieces ", w.pieces.size(), " joints ", w.joints.size(), " bodies at start ", free_n, " metal t ", snappedf(w.structural_mass, 0.1), " $/t ", snappedf(w.metal_price, 0.1))
	for b in w.bodies:
		var tags := []
		for p in b.pieces:
			tags.append("%s:%s" % [p.kind, p.tag])
		print("  FREE AT START: ", tags)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var Cap = load("res://tests/cap.gd")
	img = Cap.to_srgb8(img)
	img.save_png("res://tests/out/%s.png" % nm)
	print("saved")
	quit()
