extends SceneTree
# Regression (player screenshots 2026-10-17, TUG and M-14): "a very long red
# line" from a piece across the berth. A cut that frees part of a piece moves
# that part into a frame of its own (a free body); kerf points kept in the old
# frame — the cut carried on into the freed part, the glow both halves share,
# or a kerf under way on a piece that came loose — were then drawn joined to
# the new frame, a line from the piece to the far side of the berth.
# A bar clamped at its left end is cut through and the beam carries straight
# on into the freed right half; then a loose plate is cut while it drifts.
# Every pending kerf point and every glowing kerf must stay on its own piece.
# tools/run_test.sh tests/kerf_frame.gd --fixed-fps 60
const M := 48.0
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
const NEAR := 30.0            # px: how far a kerf point may sit from its piece's outline
var done := false
var g: Node
var worst := 0.0
var worst_what := ""


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return done


func frames(n: int) -> void:
	for i in n:
		await process_frame


# how far a point (in p's own frame) sits from p's outline, outside it
func off_piece(p, lp: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(lp, p.poly):
		return 0.0
	return Geom.dist_to_boundary(lp, p.poly)


func audit(when: String) -> void:
	var w = g.world
	for id in g.tools.pending:
		var p = w.pieces.get(id)
		if p == null or p.gone:
			continue
		for lp in g.tools.pending[id].pl:
			var d := off_piece(p, lp)
			if d > worst:
				worst = d
				worst_what = "%s: pending kerf on %s, %.0f px off it" % [when, p.tag if p.tag != "" else str(p.id), d]
	for id in w.pieces:
		var p = w.pieces[id]
		if p.gone:
			continue
		for h in p.heat:
			for lp in h[0]:
				var d := off_piece(p, lp)
				if d > worst:
					worst = d
					worst_what = "%s: glow on %s, %.0f px off it" % [when, p.tag if p.tag != "" else str(p.id), d]


func sweep(path: Array, speed: float, label: String) -> void:
	g.tools.set_tool(2, true)
	g.bot.lmb = true
	for k in range(1, path.size()):
		var a: Vector2 = path[k - 1]
		var b: Vector2 = path[k]
		var n := maxi(1, int(a.distance_to(b) / speed * 60.0))
		for i in n + 1:
			g.bot.aim = a.lerp(b, float(i) / n)
			g.drone.global_position = g.bot.aim + Vector2(0, -80)
			g.drone.linear_velocity = Vector2.ZERO
			await process_frame
			audit(label)
	g.bot.lmb = false
	for i in 30:
		await process_frame
		audit(label + " after")


func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = BOT.duplicate()
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var c := Vector2(4000, 4000)
	# 1. a bar clamped at its left end: down through the middle, then on into the right half
	var bar := PackedVector2Array([c + Vector2(-150, -20), c + Vector2(150, -20), c + Vector2(150, 20), c + Vector2(-150, 20)])
	var p = g.world.add_piece("hull", bar, {"density": 1.0, "tag": "KF-1"})
	g.world.add_joint(p, null, "clamp", c + Vector2(-140, 0))
	g.world.rebuild_cols(p)
	await frames(2)
	g.drone.global_position = c + Vector2(0, -110)
	g.drone.reset_physics_interpolation()
	g.bot.aim = c + Vector2(0, -40)
	await frames(2)
	await sweep([c + Vector2(0, -40), c + Vector2(0, 8), c + Vector2(110, 8), c + Vector2(110, 60)], 40.0, "bar")
	var freed := 0
	for id in g.world.pieces:
		var q = g.world.pieces[id]
		if not q.gone and q.body != null and str(q.get_meta("origin", q.tag)) == "KF-1":
			freed += 1
	print("bar: %d freed part(s)" % freed)
	# 2. a loose plate drifting while it is cut across
	var c2 := c + Vector2(0, 400)
	var plate := PackedVector2Array([c2 + Vector2(-90, -40), c2 + Vector2(90, -40), c2 + Vector2(90, 40), c2 + Vector2(-90, 40)])
	var q2 = g.world.add_piece("hull", plate, {"density": 1.0, "tag": "KF-2"})
	g.world.make_body([q2], null)
	q2.body.linear_velocity = Vector2(30, 0)
	await frames(2)
	await sweep([c2 + Vector2(-20, -70), c2 + Vector2(10, 70)], 40.0, "drifting plate")
	print("worst kerf point off its piece: %.0f px%s" % [worst, ("  (" + worst_what + ")") if worst_what != "" else ""])
	print("KERF_FRAME %s" % ("PASS" if worst <= NEAR and freed >= 1 else "FAIL"))
	done = true
