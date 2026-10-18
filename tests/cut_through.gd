extends SceneTree
# Regression (player report 2026-10-17): "cut straight across and it still did
# not come apart". A stroke that crosses a piece from outside to outside must
# split it, at every kerf the field manual can give (3.4 → 1.5 px), across a
# bar or on a slant, slow or flicked, and across two plates welded side by side
# (each plate is cut; the seam weld under the kerf goes too).
# tools/run_test.sh tests/cut_through.gd --fixed-fps 60
var fails := 0
var cases := 0
var done := false
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
var g


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int = 3) -> void:
	for i in n:
		await process_frame


var serial := 0
var DEBUG := false


# parts the stroke left of these pieces (the originals and whatever came off them)
func parts_of(tags: Array) -> int:
	var n := 0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone:
			continue
		if tags.has(p.tag) or tags.has(str(p.get_meta("origin", ""))):
			n += 1
	return n


func sweep(a: Vector2, b: Vector2, speed: float) -> void:
	g.tools.set_tool(2, true)
	g.drone.global_position = (a + b) * 0.5 + Vector2(0, 80)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.bot.aim = a
	g.bot.lmb = true
	await frames(2)
	var n := maxi(1, int(a.distance_to(b) / speed * 60.0))
	for i in n + 1:
		g.bot.aim = a.lerp(b, float(i) / n)
		g.drone.global_position = g.bot.aim + Vector2(0, 80)
		await process_frame
		if DEBUG and (i % 6 == 0 or n < 30):
			var pend := []
			for id in g.tools.pending:
				pend.append("%d:%dpts%s" % [id, g.tools.pending[id].pl.size(), "A" if g.tools.pending[id].anch else ""])
			print("  i%d aim %s front %s mat %s cutting %s pend %s cuts %d" % [i, g.bot.aim - Vector2(4000, 4000), g.tools.front - Vector2(4000, 4000), g.tools.in_material, g.tools.cutting, pend, g.tools.stroke_cuts])
	g.bot.lmb = false
	await frames(50)


func case(label: String, polys: Array, a: Vector2, b: Vector2, speed: float, weld: bool = false) -> void:
	var ids: Array = []
	var made: Array = []
	for poly in polys:
		serial += 1
		var tg := "CT-%d" % serial
		var p = g.world.add_piece("hull", poly, {"density": 1.0, "tag": tg})
		made.append(p)
		ids.append(tg)
	# held like hull plating: each piece clamped to the berth at its far end from the stroke
	for p in made:
		var bb := Geom.bbox(p.poly)
		var far := Vector2(bb.position.x + 4.0, bb.position.y + 4.0)
		if absf(a.y - bb.position.y) < absf(a.y - bb.end.y):
			far.y = bb.end.y - 4.0
		g.world.add_joint(p, null, "clamp", far)
	if weld and made.size() == 2:
		var mid: Vector2 = (Geom.centroid(made[0].poly) + Geom.centroid(made[1].poly)) * 0.5
		g.world.add_joint(made[0], made[1], "weld", mid)
	for p in made:
		g.world.rebuild_cols(p)
	await frames(2)
	await sweep(a, b, speed)
	var got := parts_of(ids)
	var want := polys.size() * 2
	cases += 1
	var ok := got >= want
	if not ok:
		fails += 1
		print("[FAIL] %s: %d parts, want %d" % [label, got, want])
	if DEBUG:
		print("  -> %d parts" % got)
		return
	for p in made:
		g.world.remove_piece(p)
	for id in g.world.order.duplicate():
		var q = g.world.pieces.get(id)
		if q != null and not q.gone and ids.has(str(q.get_meta("origin", ""))):
			g.world.remove_piece(q)
	await frames(2)


func _run() -> void:
	var s: Node = load("res://scenes/main.tscn").instantiate()
	s.bot = BOT.duplicate()
	root.add_child(s)
	g = s
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var c := Vector2(4000, 4000)
	if "seam" in OS.get_cmdline_user_args():
		DEBUG = true
		g.bot.kit = {"skill_laser_kerf": 2}
		var l1 := PackedVector2Array([c + Vector2(-40, -18), c + Vector2(0, -18), c + Vector2(0, 18), c + Vector2(-40, 18)])
		var r1 := PackedVector2Array([c + Vector2(0, -18), c + Vector2(40, -18), c + Vector2(40, 18), c + Vector2(0, 18)])
		await case("debug seam 2.1 fast", [l1, r1], c + Vector2(-70, 2), c + Vector2(70, 2), 400.0, true)
		for id in g.world.order:
			var p = g.world.pieces[id]
			if not p.gone and (p.tag.begins_with("CT-") or str(p.get_meta("origin", "")).begins_with("CT-")):
				print("  part %s origin %s body %s bbox %s" % [p.tag, p.get_meta("origin", ""), p.body != null, Geom.bbox(p.poly)])
		done = true
		return
	if "one" in OS.get_cmdline_user_args():
		DEBUG = true
		var bar1 := PackedVector2Array([c + Vector2(-9, -40), c + Vector2(9, -40), c + Vector2(9, 40), c + Vector2(-9, 40)])
		await case("debug bar 3.4 slow", [bar1], c + Vector2(-40, 3), c + Vector2(40, 3), 90.0)
		done = true
		return
	for lv in 4:
		g.bot.kit = {"skill_laser_kerf": lv}
		var k: float = g.skill_value("laser_kerf")
		for sp in [90.0, 400.0]:
			var tag := "kerf %.1f px, %d px/s" % [k, int(sp)]
			# a vertical bar, cut straight across
			var bar := PackedVector2Array([c + Vector2(-9, -40), c + Vector2(9, -40), c + Vector2(9, 40), c + Vector2(-9, 40)])
			await case(tag + ", across a bar", [bar], c + Vector2(-40, 3), c + Vector2(40, 3), sp)
			# a wide plate, on a slant
			var plate := PackedVector2Array([c + Vector2(-30, -20), c + Vector2(30, -20), c + Vector2(30, 20), c + Vector2(-30, 20)])
			await case(tag + ", slant across a plate", [plate], c + Vector2(-60, -35), c + Vector2(60, 30), sp)
			# two plates welded edge to edge, cut across both in one stroke
			var left := PackedVector2Array([c + Vector2(-40, -18), c + Vector2(0, -18), c + Vector2(0, 18), c + Vector2(-40, 18)])
			var right := PackedVector2Array([c + Vector2(0, -18), c + Vector2(40, -18), c + Vector2(40, 18), c + Vector2(0, 18)])
			await case(tag + ", across a welded seam", [left, right], c + Vector2(-70, 2), c + Vector2(70, 2), sp, true)
	print("CUT_THROUGH %s  (%d / %d cases severed)" % ["PASS" if fails == 0 else "FAIL", cases - fails, cases])
	done = true
