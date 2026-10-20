extends SceneTree
# Every named piece of equipment art at a spread of sizes on one sheet, so a redraw
# can be judged small, tall, wide and huge at once (2026-10-20 equipment-art rework).
# tools/run_test.sh tests/art_gallery.gd -- <art,art,...> [zoom] [name] [sizes]
# sizes: "w x h; w x h; ..." in metres (default: a small, tall, wide, large and long one)

const SIZES := [Vector2(0.6, 0.6), Vector2(1.4, 1.0), Vector2(0.9, 2.2), Vector2(3.6, 1.2), Vector2(4.5, 3.0), Vector2(10.0, 2.6)]
var node: Node2D
var arts: PackedStringArray
var sizes: Array = SIZES.duplicate()
var font: Font


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	arts = a[0].split(",") if a.size() > 0 else PackedStringArray(["pump"])
	var zoom := float(a[1]) if a.size() > 1 else 1.0
	var nm: String = a[2] if a.size() > 2 else "gallery"
	if a.size() > 3:
		sizes = []
		for s in a[3].split(";"):
			var xy := s.split("x")
			sizes.append(Vector2(float(xy[0]), float(xy[1])))
	root.add_child(preload("res://tests/test_window.gd").new())
	font = Fonts.get_font("Regular")
	node = Node2D.new()
	node.draw.connect(_paint)
	root.add_child(node)
	var wsum := 0.0
	var hmax := 0.0
	for s in sizes:
		wsum += s.x + 0.6
		hmax = maxf(hmax, s.y)
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Vector2(wsum * 0.5, arts.size() * (hmax + 0.9) * 0.5) * Geom.M
	root.add_child(cam)
	await process_frame
	cam.make_current()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img = load("res://tests/cap.gd").to_srgb8(img)
	img.save_png("res://tests/out/%s.png" % nm)
	print("saved ", nm)
	quit()


func _paint() -> void:
	var hmax := 0.0
	for s in sizes:
		hmax = maxf(hmax, s.y)
	var y := 0.4 * Geom.M
	for art in arts:
		var x := 0.3 * Geom.M
		node.draw_string(font, Vector2(x, y - 6), art, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.6))
		for s in sizes:
			var sz: Vector2 = s * Geom.M
			var p := Model.Piece.new()
			p.tag = "PMP-02"
			p.label = "O₂"
			p.kind = "equip"
			p.cls = "equip"
			p.poly = PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)])
			var at := Vector2(x, y)
			node.draw_rect(Rect2(at, sz), Color(0.052, 0.055, 0.063))
			node.draw_rect(Rect2(at, sz), Pal.ink(0.9), false, 1.3)
			node.draw_set_transform(at)
			Art.draw(node, art, sz, p, font)
			node.draw_set_transform(Vector2.ZERO)
			x += sz.x + 0.6 * Geom.M
		y += (hmax + 0.9) * Geom.M
	node.draw_rect(Rect2(-4000, -4000, 1, 1), Color(0, 0, 0, 0))
