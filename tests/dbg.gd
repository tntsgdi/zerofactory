extends SceneTree
func _initialize() -> void:
	var w := World.new()
	root.add_child(w)
	Ship.build(w, Ship.load_data("gr7"))
	w.finalize()
	for t in ["AUX-1", "T-F01", "AUX-2"]:
		var p = w.tag(t)
		var s := []
		for j in w.joints_of(p):
			var o = w.pieces.get(j.b if j.a == p.id else j.a)
			s.append("%s->%s:%s@%s" % [j.type, o.kind if o else "ANCHOR", o.tag if o else "", j.pos / 48.0])
		print(t, " ", s)
		for l in w.lines_of(p):
			print("   line ", l.id)
	quit()
