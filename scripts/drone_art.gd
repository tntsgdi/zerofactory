extends RefCounted
# The drone's airframe, drawn procedurally (2026-10-17 redesign, three concept
# directions for the player to choose from). Everything is drawn in the drone's
# own frame, x pointing where it looks, so one call serves the game and the
# concept sheet (tests/drone_concepts.gd).
#   st: {"heading": float, "tool": int 1-5, "open": 0..1 (the tool's transform),
#        "t": float (s), "thrust": Vector2 (world, the commanded push),
#        "dash": bool}

const INK := Color(0.95, 0.96, 1.0)
const HULL := Color(0.07, 0.074, 0.084)
const HULL_HI := Color(0.11, 0.115, 0.13)
# the line colour of whatever is drawn next (the berth's hauling drones are
# drawn in air-blue to tell them from the operator's): set, draw, set back
static var tint := Color(1, 1, 1)


static func ink(a: float, k: float = 1.0) -> Color:
	return Color(INK.r * k * tint.r, INK.g * k * tint.g, INK.b * k * tint.b, a)


# a closed outline drawn on up to frac (0..1) of its length from its first point
static func outline_part(ci: CanvasItem, poly: PackedVector2Array, col: Color, w: float, frac: float) -> void:
	if frac >= 0.999:
		outline(ci, poly, col, w)
		return
	var pts := poly.duplicate()
	pts.append(poly[0])
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var left := total * clampf(frac, 0.0, 1.0)
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg:
			out.append(pts[i].lerp(pts[i + 1], left / maxf(seg, 0.001)))
			break
		out.append(pts[i + 1])
		left -= seg
	if out.size() >= 2:
		ci.draw_polyline(out, col, w, true)
		# the pen: a bright point where the line is being drawn
		ci.draw_circle(out[out.size() - 1], w * 0.9, Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, col.a))


static func heat(a: float, k: float = 1.0) -> Color:
	return Pal.heat(a, k)


static func air(a: float, k: float = 1.0) -> Color:
	return Pal.tint(Pal.AIR, a, k)


static func tool_col(tool: int, a: float, k: float = 1.0) -> Color:
	match tool:
		0: return ink(a * 0.8, minf(k, 1.15))
		2: return heat(a, k)
		1: return air(a, k)
		5: return Pal.tint(Pal.FLUID, a, k)
	return ink(a, k)


static func rot(pts: Array, a: float, s: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append((p as Vector2).rotated(a) * s)
	return out


static func outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, w: float) -> void:
	var c := poly.duplicate()
	c.append(poly[0])
	ci.draw_polyline(c, col, w, true)


static func draw(ci: CanvasItem, design: String, st: Dictionary) -> void:
	match design:
		"gimbal": _gimbal(ci, st)
		"wedge": _wedge(ci, st)
		"tripod": _tripod(ci, st)
		"arrowring": _arrowring(ci, st)
		"coreclaw": _coreclaw(ci, st)


# ------------------------------------------------------------ shared parts

# an iris of n blades: open 0 (a pin-hole) to 1 (wide), lit in the tool's colour
static func iris(ci: CanvasItem, c: Vector2, r: float, open: float, n: int, spin: float, col: Color) -> void:
	ci.draw_circle(c, r, Color(0.025, 0.026, 0.03))
	var hole := r * (0.2 + 0.32 * open)
	for i in n:
		var a0 := spin + TAU * i / n
		var a1 := a0 + TAU / n
		var p0 := c + Vector2.from_angle(a0) * r
		var p1 := c + Vector2.from_angle(a1) * r
		var p2 := c + Vector2.from_angle(a1 + 0.6) * hole
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color(0.09, 0.095, 0.108))
		ci.draw_line(p1, p2, ink(0.35), 0.8, true)
	ci.draw_circle(c, hole, col)
	ci.draw_arc(c, r, 0.0, TAU, 24, ink(0.7), 1.0, true)


# a thruster's flame along d (unit, in the drone's frame), f 0..1
static func flame(ci: CanvasItem, base: Vector2, d: Vector2, f: float, w: float, t: float, dash: bool) -> void:
	if f < 0.04:
		return
	var n := Vector2(-d.y, d.x)
	var flick := 0.85 + 0.15 * sin(t * 61.0 + base.x)
	var ln := (8.0 + 16.0 * f) * flick * (1.6 if dash else 1.0)
	ci.draw_colored_polygon(PackedVector2Array([base + n * w, base + d * ln, base - n * w]), heat(0.55 * f, 1.8))
	ci.draw_colored_polygon(PackedVector2Array([base + n * w * 0.45, base + d * ln * 0.55, base - n * w * 0.45]), Color(1.8, 1.4, 1.0, 0.85 * f))


# the tool's head at the front (x forward), opened by o
static func tool_head(ci: CanvasItem, nose: Vector2, tool: int, o: float, t: float) -> void:
	var e := Pal.ease_io(clampf(o, 0.0, 1.0))
	match tool:
		2:
			# laser: an emitter barrel slides out, cooling fins glow, the lens burns
			var tip := nose + Vector2(10.0 * e, 0)
			ci.draw_rect(Rect2(nose + Vector2(-2, -2.6), Vector2(tip.x - nose.x + 2, 5.2)), HULL_HI)
			ci.draw_line(nose + Vector2(-2, -2.6), tip + Vector2(0, -2.6), ink(0.85), 1.0, true)
			ci.draw_line(nose + Vector2(-2, 2.6), tip + Vector2(0, 2.6), ink(0.85), 1.0, true)
			for i in 3:
				var fx := nose.x + 1.5 + i * 3.0 * e
				ci.draw_line(Vector2(fx, nose.y - 2.6 - 3.0 * e), Vector2(fx, nose.y + 2.6 + 3.0 * e), heat(0.35 + 0.4 * e, 1.0 + 1.2 * e), 1.0)
			ci.draw_circle(tip, 2.2, heat(0.9 * e, 2.6))
		3:
			# grapple: two coil rings spin up ahead of the nose
			for i in 2:
				var r := 5.0 + i * 3.5
				var sp := t * (5.0 if i == 0 else -3.5)
				for k in 4:
					var a0 := sp + TAU * k / 4.0
					ci.draw_arc(nose + Vector2(3.0 + 4.0 * e, 0), r * (0.6 + 0.4 * e), a0, a0 + 0.9, 6, ink(0.4 + 0.5 * e, 1.0 + 0.6 * e), 1.2, true)
			ci.draw_circle(nose + Vector2(3.0 + 4.0 * e, 0), 1.6, ink(0.9, 1.8))
		1:
			# meter: a dish swings up and sweeps a scan arc
			var dc := nose + Vector2(3.0 * e, 0)
			ci.draw_arc(dc, 5.0, -1.2, 1.2, 10, ink(0.85), 1.4, true)
			var sw := fposmod(t * 1.4, 1.0)
			ci.draw_arc(dc, 6.0 + 16.0 * sw * e, -0.6, 0.6, 12, air(0.7 * (1.0 - sw) * e, 1.6), 1.2, true)
			ci.draw_circle(dc, 1.5, air(0.95, 1.8))
		4:
			# wrench: a two-joint manipulator unfolds forward with a socket
			var sh := nose + Vector2(-4, 0)
			var el := sh + Vector2.from_angle(-1.6 + 1.2 * e) * 7.0
			var hd := el + Vector2.from_angle(-0.2 * (1.0 - e)) * 8.0 * (0.4 + 0.6 * e)
			ci.draw_line(sh, el, ink(0.85), 2.0, true)
			ci.draw_line(el, hd, ink(0.85), 1.6, true)
			ci.draw_circle(el, 1.6, HULL_HI)
			ci.draw_arc(el, 1.6, 0.0, TAU, 8, ink(0.8), 0.8, true)
			ci.draw_arc(hd, 2.2, 0.0, TAU, 8, ink(0.95, 1.4), 1.0, true)
		5:
			# recovery: a port irises open and a hose coupling peeks out
			var pc := nose + Vector2(1.0, 0)
			ci.draw_arc(pc, 4.0, 0.0, TAU, 16, Pal.tint(Pal.FLUID, 0.85), 1.2, true)
			ci.draw_circle(pc, 2.6 * e, Pal.tint(Pal.FLUID, 0.8, 1.6))


# ------------------------------------------------------------ A · GIMBAL

# a round core in a turning ring frame; four nacelles on struts swing to
# push the way the drone is told to go
static func _gimbal(ci: CanvasItem, st: Dictionary) -> void:
	var h: float = st.heading
	var t: float = st.t
	var th: Vector2 = st.get("thrust", Vector2.ZERO)
	var push := th.length()
	var away := (-th).angle() if push > 0.05 else h + PI
	# struts and nacelles (X layout, turned with the heading)
	for k in 4:
		var a := h + PI / 4.0 + k * PI / 2.0
		var root := Vector2.from_angle(a) * 9.0
		var pod := Vector2.from_angle(a) * 19.0
		ci.draw_line(root, pod, ink(0.55), 2.2, true)
		ci.draw_circle(pod, 2.2, HULL_HI)
		# the nacelle swivels toward the push
		var na := lerp_angle(a, away, 0.75) if push > 0.05 else a
		var nd := Vector2.from_angle(na)
		var nn := Vector2(-nd.y, nd.x)
		var cap := PackedVector2Array([pod - nd * 5 + nn * 3.4, pod + nd * 4 + nn * 2.6, pod + nd * 4 - nn * 2.6, pod - nd * 5 - nn * 3.4])
		ci.draw_colored_polygon(cap, HULL)
		outline(ci, cap, ink(0.9), 1.2)
		var f := clampf(push * maxf(0.0, nd.dot(Vector2.from_angle(away))) * 1.2, 0.0, 1.0)
		flame(ci, pod + nd * 4.5, nd, f, 2.4, t + k, st.get("dash", false))
	# the ring: four arcs turning slowly, seams lit in sequence
	var spin := t * 0.6
	for k in 4:
		var a0 := spin + k * PI / 2.0 + 0.2
		ci.draw_arc(Vector2.ZERO, 13.5, a0, a0 + PI / 2.0 - 0.4, 12, ink(0.8), 2.0, true)
		var lit := 0.5 + 0.5 * sin(t * 3.0 - k * 1.57)
		ci.draw_circle(Vector2.from_angle(a0 - 0.2) * 13.5, 1.1, tool_col(st.tool, 0.3 + 0.6 * lit, 1.0 + lit))
	# the core and its iris looking ahead
	ci.draw_circle(Vector2.ZERO, 10.0, HULL)
	ci.draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 28, ink(0.95), 1.6, true)
	var fw := Vector2.from_angle(h)
	iris(ci, fw * 2.5, 5.5, st.open, 6, t * 0.4, tool_col(st.tool, 0.95, 1.35))
	_tool_at(ci, st, fw * 10.0, h)


# ------------------------------------------------------------ B · WEDGE

# an arrowhead hull pointing where it looks, arms folded along the flanks,
# twin mains at the back and small trim jets at the nose
const WEDGE := [Vector2(24, 0), Vector2(4, -9), Vector2(-9, -16), Vector2(-16, -12), Vector2(-12, 0), Vector2(-16, 12), Vector2(-9, 16), Vector2(4, 9)]


static func _wedge(ci: CanvasItem, st: Dictionary) -> void:
	var h: float = st.heading
	var t: float = st.t
	var th: Vector2 = st.get("thrust", Vector2.ZERO)
	var lth := th.rotated(-h)             # the push in the drone's frame
	var hull := rot(WEDGE, h)
	# flank arms, stowed inside the hull: they swing out with the wrench
	var arm_o: float = Pal.ease_io(clampf(st.open, 0.0, 1.0)) if st.tool == 4 else 0.0
	if arm_o > 0.01:
		for s: float in [-1.0, 1.0]:
			var sh := Vector2(-2, 8 * s)
			var el := Vector2(lerpf(-2.0, 10.0, arm_o), lerpf(9.0, 17.0, arm_o) * s)
			var hd := Vector2(lerpf(4.0, 26.0, arm_o), lerpf(7.0, 9.0, arm_o) * s)
			ci.draw_line(sh.rotated(h), el.rotated(h), ink(0.8), 2.2, true)
			ci.draw_line(el.rotated(h), hd.rotated(h), ink(0.8), 1.6, true)
			ci.draw_circle(el.rotated(h), 1.6, HULL_HI)
			ci.draw_arc(el.rotated(h), 1.6, 0.0, TAU, 8, ink(0.8), 0.8, true)
			ci.draw_arc(hd.rotated(h), 2.0, 0.0, TAU, 8, ink(0.95, 1.4), 1.0, true)
	ci.draw_colored_polygon(hull, HULL)
	# a lighter top plate, seams
	ci.draw_colored_polygon(rot([Vector2(19, 0), Vector2(4, -6), Vector2(-6, -9), Vector2(-6, 9), Vector2(4, 6)], h), HULL_HI)
	outline(ci, hull, ink(0.95), 1.6)
	var seam_lit := 0.5 + 0.5 * sin(t * 2.4)
	ci.draw_polyline(rot([Vector2(4, -9), Vector2(-3, 0), Vector2(4, 9)], h), ink(0.35), 1.0, true)
	ci.draw_line(Vector2(-6, -9).rotated(h), Vector2(-6, 9).rotated(h), tool_col(st.tool, 0.25 + 0.35 * seam_lit, 1.0 + seam_lit * 0.6), 1.0, true)
	# twin mains at the back corners
	for s: float in [-1.0, 1.0]:
		var m := Vector2(-14, 8 * s)
		var nz := rot([m + Vector2(2, -2.6), m + Vector2(-3, -3.2), m + Vector2(-3, 3.2), m + Vector2(2, 2.6)], h)
		ci.draw_colored_polygon(nz, HULL_HI)
		outline(ci, nz, ink(0.85), 1.0)
		var f := clampf(lth.x, 0.0, 1.0)
		flame(ci, (m + Vector2(-3, 0)).rotated(h), Vector2.LEFT.rotated(h), f, 2.6, t + s, st.get("dash", false))
	# trim jets: braking at the nose, sideways at the flanks
	flame(ci, Vector2(10, 0).rotated(h) + Vector2(0, 0), Vector2.RIGHT.rotated(h), clampf(-lth.x, 0.0, 1.0) * 0.7, 1.4, t, false)
	for s: float in [-1.0, 1.0]:
		var side := Vector2(-2, 16.5 * s)
		flame(ci, side.rotated(h), Vector2(0, s).rotated(h), clampf(-lth.y * s, 0.0, 1.0) * 0.7, 1.4, t + s * 3.0, false)
	# the eye: a slit sensor that widens with the tool
	var e: float = Pal.ease_io(clampf(st.open, 0.0, 1.0))
	var eye_c := Vector2(12, 0).rotated(h)
	var n := Vector2(0, 1).rotated(h)
	ci.draw_line(eye_c - n * (1.6 + 2.0 * e), eye_c + n * (1.6 + 2.0 * e), tool_col(st.tool, 0.95, 1.4), 1.6, true)
	_tool_at(ci, st, Vector2(23, 0).rotated(h), h)


# ------------------------------------------------------------ C · TRIPOD

# a hex core with three jointed claws that flex as it flies; trim jets ride
# on the elbows
static func _tripod(ci: CanvasItem, st: Dictionary) -> void:
	var h: float = st.heading
	var t: float = st.t
	var th: Vector2 = st.get("thrust", Vector2.ZERO)
	var push := th.length()
	for k in 3:
		var a := h + PI + (k - 1) * 2.0 * PI / 3.0     # one claw trails, two reach forward
		var flex: float = 0.18 * sin(t * 2.0 + k * 2.1) + (0.25 if st.tool == 4 and k != 1 else 0.0) * st.open
		var sh := Vector2.from_angle(a) * 10.0
		var el := sh + Vector2.from_angle(a + 0.45 + flex) * 10.0
		var tip := el + Vector2.from_angle(a - 0.35 - flex) * 8.0
		ci.draw_line(sh, el, ink(0.8), 2.6, true)
		ci.draw_line(el, tip, ink(0.8), 1.8, true)
		for s: float in [-1.0, 1.0]:
			ci.draw_line(tip, tip + Vector2.from_angle(a + s * (0.5 + 0.4 * flex)) * 3.5, ink(0.9), 1.2, true)
		ci.draw_circle(sh, 2.2, HULL_HI)
		ci.draw_arc(sh, 2.2, 0.0, TAU, 10, ink(0.8), 0.9, true)
		ci.draw_circle(el, 1.8, HULL_HI)
		ci.draw_arc(el, 1.8, 0.0, TAU, 10, ink(0.8), 0.9, true)
		# the elbow jet pushes opposite the way it points, when that helps
		var jd := Vector2.from_angle(a + 0.45)
		var f := clampf(push * maxf(0.0, -jd.dot(th.normalized() if push > 0.05 else Vector2.ZERO)) * 1.3, 0.0, 1.0)
		flame(ci, el + jd * 2.0, jd, f, 1.8, t + k, st.get("dash", false))
	# the hex core
	var hexp := PackedVector2Array()
	for i in 6:
		hexp.append(Vector2.from_angle(h + TAU * i / 6.0 + PI / 6.0) * 12.0)
	ci.draw_colored_polygon(hexp, HULL)
	outline(ci, hexp, ink(0.95), 1.6)
	for i in 6:
		var lit := 0.5 + 0.5 * sin(t * 3.0 - i * 1.05)
		ci.draw_circle(hexp[i] * 0.78, 0.9, tool_col(st.tool, 0.25 + 0.6 * lit, 1.0 + lit))
	var fw := Vector2.from_angle(h)
	iris(ci, fw * 1.5, 6.0, st.open, 6, -t * 0.3, tool_col(st.tool, 0.95, 1.35))
	_tool_at(ci, st, fw * 12.0, h)


# ------------------------------------------------------------ shared: ring core, claw, pod

static func ring_core(ci: CanvasItem, c: Vector2, st: Dictionary, r_core: float, r_ring: float) -> void:
	var t: float = st.t
	ci.draw_circle(c, r_ring + 1.5, HULL)
	var spin := t * 0.6 + float(st.get("spin", 0.0))
	for k in 4:
		var a0 := spin + k * PI / 2.0 + 0.2
		ci.draw_arc(c, r_ring, a0, a0 + PI / 2.0 - 0.4, 12, ink(0.8), 1.8, true)
		var lit := 0.5 + 0.5 * sin(t * 3.0 - k * 1.57)
		ci.draw_circle(c + Vector2.from_angle(a0 - 0.2) * r_ring, 1.0, tool_col(st.tool, 0.3 + 0.6 * lit, 1.0 + lit * 0.8))
	ci.draw_circle(c, r_core, HULL_HI)
	ci.draw_arc(c, r_core, 0.0, TAU, 24, ink(0.95), 1.4, true)
	iris(ci, c + Vector2.from_angle(st.heading) * 1.5, r_core * 0.62, st.open, 6, t * 0.4, tool_col(st.tool, 0.95, 1.35))


# a jointed claw from sh, reaching along a (radians), bent by flex; reach 0..1
static func claw(ci: CanvasItem, sh: Vector2, a: float, flex: float, reach: float, side: float) -> Vector2:
	var l1 := 7.0 + 3.0 * reach
	var l2 := 6.0 + 3.0 * reach
	var el := sh + Vector2.from_angle(a + side * (0.7 - 0.5 * reach) + flex) * l1
	var tip := el + Vector2.from_angle(a - side * (0.5 - 0.4 * reach) - flex) * l2
	ci.draw_line(sh, el, ink(0.8), 2.2, true)
	ci.draw_line(el, tip, ink(0.8), 1.6, true)
	var spread := 0.35 + 0.35 * reach
	for s: float in [-1.0, 1.0]:
		ci.draw_line(tip, tip + Vector2.from_angle(a + s * spread) * 3.2, ink(0.9), 1.1, true)
	ci.draw_circle(sh, 1.9, HULL_HI)
	ci.draw_arc(sh, 1.9, 0.0, TAU, 10, ink(0.8), 0.9, true)
	ci.draw_circle(el, 1.5, HULL_HI)
	ci.draw_arc(el, 1.5, 0.0, TAU, 10, ink(0.8), 0.9, true)
	return el


# a nacelle at a point that swivels to blow along d (unit); f 0..1 its flame
static func pod(ci: CanvasItem, at: Vector2, d: Vector2, f: float, st: Dictionary, big: float = 1.0) -> void:
	var n := Vector2(-d.y, d.x)
	var cap := PackedVector2Array([at - d * 4.5 * big + n * 3.0 * big, at + d * 3.5 * big + n * 2.4 * big, at + d * 3.5 * big - n * 2.4 * big, at - d * 4.5 * big - n * 3.0 * big])
	ci.draw_colored_polygon(cap, HULL)
	outline(ci, cap, ink(0.9), 1.1)
	flame(ci, at + d * 4.0 * big, d, f, 2.2 * big, st.t + at.x, st.get("dash", false))


# a claw that rides beside the nose like a mandible (x forward, side +-1),
# reaching ahead of it by reach 0..1, the pincer opening as it reaches
static func mandible(ci: CanvasItem, h: float, sh: Vector2, side: float, reach: float, flex: float) -> void:
	var a1 := side * (0.42 - 0.22 * reach) + flex
	var a2 := -side * (0.18 - 0.12 * reach) - flex * 0.5
	var el := sh + Vector2.from_angle(a1) * (8.0 + 2.0 * reach)
	var tip := el + Vector2.from_angle(a2) * (7.0 + 5.0 * reach)
	var open := 0.25 + 0.45 * reach
	var p1 := tip + Vector2.from_angle(a2 + side * open) * 3.4
	var p2 := tip + Vector2.from_angle(a2 - side * (0.9 + open)) * 3.0
	ci.draw_line(sh.rotated(h), el.rotated(h), ink(0.85), 2.4, true)
	ci.draw_line(el.rotated(h), tip.rotated(h), ink(0.85), 1.8, true)
	ci.draw_line(tip.rotated(h), p1.rotated(h), ink(0.95), 1.3, true)
	ci.draw_line(tip.rotated(h), p2.rotated(h), ink(0.95), 1.3, true)
	for j in [sh, el]:
		ci.draw_circle((j as Vector2).rotated(h), 1.7, HULL_HI)
		ci.draw_arc((j as Vector2).rotated(h), 1.7, 0.0, TAU, 10, ink(0.85), 0.9, true)


# how far the claws reach: out with the grapple and the wrench, in otherwise
static func claw_reach(st: Dictionary) -> float:
	return Pal.ease_io(clampf(st.open, 0.0, 1.0)) if st.tool in [3, 4] else 0.0


# ------------------------------------------------------------ H1 · ARROW-RING

# an arrowhead chassis carrying the ring core; twin mains at the wing tips,
# a swivel pod on each wing for side push and braking, two claws under the nose
const ARROW := [Vector2(28, 0), Vector2(12, -7), Vector2(0, -17), Vector2(-14, -20), Vector2(-10, -8), Vector2(-10, 8), Vector2(-14, 20), Vector2(0, 17), Vector2(12, 7)]


static func _arrowring(ci: CanvasItem, st: Dictionary) -> void:
	var h: float = st.heading
	var t: float = st.t
	var th: Vector2 = st.get("thrust", Vector2.ZERO)
	var lth := th.rotated(-h)
	var rc := claw_reach(st)
	# booting (its launch): the outline draws on like a blueprint, then the
	# fill, the ring spinning down from fast, the parts unfolding last
	var boot: float = st.get("boot", 1.0)
	if boot < 1.0:
		var b1 := clampf(boot / 0.55, 0.0, 1.0)
		var b2 := clampf((boot - 0.45) / 0.55, 0.0, 1.0)
		var hull0 := rot(ARROW, h)
		ci.draw_colored_polygon(hull0, Color(HULL.r, HULL.g, HULL.b, b2))
		outline_part(ci, hull0, ink(0.95, 1.0 + 0.8 * (1.0 - b2)), 1.6, b1)
		if b2 > 0.0:
			var st2 := st.duplicate()
			st2.open = minf(float(st.open), b2)
			st2.spin = (1.0 - b2) * (1.0 - b2) * 14.0
			ring_core(ci, Vector2(-2, 0).rotated(h), st2, 6.0 * (0.5 + 0.5 * b2), 8.8 * (0.6 + 0.4 * b2))
		return
	# swivel pods on struts off the wings: they push sideways and brake
	for s: float in [-1.0, 1.0]:
		var root := Vector2(-4, 15 * s)
		var at := Vector2(-4, 22 * s)
		ci.draw_line(root.rotated(h), at.rotated(h), ink(0.55), 2.0, true)
		var side := clampf(-lth.y * s, 0.0, 1.0)
		var brake := clampf(-lth.x, 0.0, 1.0)
		var d := Vector2(0, s) * side + Vector2(1, 0) * brake
		d = d.normalized() if d.length() > 0.05 else Vector2(0, s)
		pod(ci, at.rotated(h), d.rotated(h), clampf(maxf(side, brake), 0.0, 1.0), st, 0.9)
	var hull := rot(ARROW, h)
	ci.draw_colored_polygon(hull, HULL)
	outline(ci, hull, ink(0.95), 1.6)
	ci.draw_colored_polygon(rot([Vector2(22, 0), Vector2(10, -5), Vector2(-2, -12), Vector2(-2, 12), Vector2(10, 5)], h), HULL_HI)
	ci.draw_polyline(rot([Vector2(12, -7), Vector2(20, 0), Vector2(12, 7)], h), ink(0.3), 1.0, true)
	# twin mains at the wing tips
	for s: float in [-1.0, 1.0]:
		var m := Vector2(-12, 14 * s)
		var nz := rot([m + Vector2(2, -2.4), m + Vector2(-3, -3.0), m + Vector2(-3, 3.0), m + Vector2(2, 2.4)], h)
		ci.draw_colored_polygon(nz, HULL_HI)
		outline(ci, nz, ink(0.85), 1.0)
		flame(ci, (m + Vector2(-3, 0)).rotated(h), Vector2.LEFT.rotated(h), clampf(lth.x, 0.0, 1.0), 2.6, t + s, st.get("dash", false))
	ring_core(ci, Vector2(-2, 0).rotated(h), st, 6.0, 8.8)
	for s: float in [-1.0, 1.0]:
		mandible(ci, h, Vector2(12, 6.5 * s), s, rc, 0.06 * sin(t * 2.0 + s) * s)
	_tool_at(ci, st, Vector2(28, 0).rotated(h), h)


# where H1 blows (in the drone's frame turned to the heading): [point, direction, strength]
static func arrowring_jets(st: Dictionary) -> Array:
	var h: float = st.heading
	var lth: Vector2 = (st.get("thrust", Vector2.ZERO) as Vector2).rotated(-h)
	var out: Array = []
	for s: float in [-1.0, 1.0]:
		out.append([Vector2(-15, 14 * s).rotated(h), Vector2.LEFT.rotated(h), clampf(lth.x, 0.0, 1.0)])
		var side := clampf(-lth.y * s, 0.0, 1.0)
		var brake := clampf(-lth.x, 0.0, 1.0)
		var d := Vector2(0, s) * side + Vector2(1, 0) * brake
		d = d.normalized() if d.length() > 0.05 else Vector2(0, s)
		out.append([(Vector2(-4, 22 * s) + d * 4.0).rotated(h), d.rotated(h), maxf(side, brake) * 0.9])
	return out


# ------------------------------------------------------------ H2 · CORE-CLAW

# the ring core at the middle with an arrow cowl over its nose; two swivel
# nacelles at the back are the mains; two claws reach out at the sides
static func _coreclaw(ci: CanvasItem, st: Dictionary) -> void:
	var h: float = st.heading
	var t: float = st.t
	var th: Vector2 = st.get("thrust", Vector2.ZERO)
	var push := th.length()
	var away := (-th).angle() if push > 0.05 else h + PI
	var rc := claw_reach(st)
	# rear nacelles on struts: the mains, swivelling to push the way it is told
	for s: float in [-1.0, 1.0]:
		var a := h + PI + s * 0.62
		var root := Vector2.from_angle(a) * 11.0
		var at := Vector2.from_angle(a) * 20.0
		ci.draw_line(root, at, ink(0.55), 2.4, true)
		var na := lerp_angle(a, away, 0.8) if push > 0.05 else a
		var nd := Vector2.from_angle(na)
		var f := clampf(push * maxf(0.0, nd.dot(Vector2.from_angle(away))) * 1.2, 0.0, 1.0)
		pod(ci, at, nd, f, st, 1.15)
	# the arrow hood the core sits in
	var hood := rot([Vector2(27, 0), Vector2(8, -12), Vector2(-6, -13), Vector2(-2, 0), Vector2(-6, 13), Vector2(8, 12)], h)
	ci.draw_colored_polygon(hood, HULL)
	outline(ci, hood, ink(0.95), 1.5)
	ci.draw_polyline(rot([Vector2(12, -8), Vector2(21, 0), Vector2(12, 8)], h), ink(0.3), 1.0, true)
	ring_core(ci, Vector2(1, 0).rotated(h), st, 6.5, 9.5)
	for s: float in [-1.0, 1.0]:
		mandible(ci, h, Vector2(13, 7.5 * s), s, rc, 0.06 * sin(t * 2.0 + s) * s)
	_tool_at(ci, st, Vector2(27, 0).rotated(h), h)


# the tool head drawn turned to the heading at a point
static func _tool_at(ci: CanvasItem, st: Dictionary, at: Vector2, h: float) -> void:
	if st.tool == 4 and st.get("design", "") == "wedge":
		return
	var xf := Transform2D(h, at)
	ci.draw_set_transform_matrix(st.get("base_xf", Transform2D.IDENTITY) * xf)
	tool_head(ci, Vector2.ZERO, st.tool, st.open, st.t)
	ci.draw_set_transform_matrix(st.get("base_xf", Transform2D.IDENTITY))
