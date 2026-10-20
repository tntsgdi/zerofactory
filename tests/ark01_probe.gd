extends SceneTree
# A look at what the ARK-01 authoring script put at a few points (debugging its plates).
# godot --headless --path . -s tests/ark01_probe.gd -- x,y x,y ...


func _initialize() -> void:
	var w = World.new()
	root.add_child(w)
	load("res://tools/authoring/ark01_author.gd").build(w)
	for a in OS.get_cmdline_user_args():
		var xy := a.split(",")
		var pt := Vector2(float(xy[0]), float(xy[1])) * Geom.M
		var hits: Array = []
		for id in w.order:
			var p = w.pieces[id]
			if p.gone:
				continue
			var bb := Geom.bbox(p.poly).grow(0.6 * Geom.M)
			if bb.has_point(pt):
				var b2 := Geom.bbox(p.poly)
				hits.append("%s[%s] x %.2f..%.2f y %.2f..%.2f" % [p.tag, p.kind, b2.position.x / Geom.M, b2.end.x / Geom.M, b2.position.y / Geom.M, b2.end.y / Geom.M])
		print("PROBE ", a, ": ", " | ".join(hits))
	quit()
