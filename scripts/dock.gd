class_name Dock
extends Node2D
# The vacuum dock around the ship: girders, the four clamp arms, the three
# recovery mouths (equipment bay, metal furnace, hazard bay), the debris net,
# the drone bay and the hose masts. Recovery mouths pull in whatever drifts
# close, judge it, and either swallow it or spit it back out.

const ZONES := {
	"equip": {"pos": Vector2(14.0, -8.4), "face": Vector2(0, 1), "w": 4.2},
	"metal": {"pos": Vector2(21.0, 7.7), "face": Vector2(0, -1), "w": 4.6},
	"hazard": {"pos": Vector2(43.6, 6.9), "face": Vector2(0, -1), "w": 3.2},
}
const NET := Vector2(2.8, 8.3)
const BAY := Vector2(-5.0, -6.0)
const MASTS := [Vector2(5.0, -10.0), Vector2(23.0, -10.0), Vector2(38.0, 6.6)]
const CLAMPS := [7.0, 15.8, 23.4, 28.6]
# semi-open berth: a floor platform, a tower on the left with an arm reaching
# over the ship; the top and the right are open to space, held only by a
# tractor field that eases strays back in
const FLOOR_Y := 9.0
const FLOOR_X1 := 50.0
const TOWER_X := -7.4
const ARM_X1 := 27.5
const BOUNDS := Rect2(-6.8, -15.0, 63.0, 24.0)
const FIELD := 3.4
const CATCH := 1.3

var game: Game
var world: World
var zone_state := {}       # id -> {"glow": float, "busy": float, "reject": float, "eat": float}
var swallowing: Array = [] # [body, zone, t, start_pos, start_rot]
var debris: Array = []     # [pos, vel, t, poly, rot, spin, value, trail]
var hoses := {}            # port id -> {"pts": [], "prev": [], "mast": Vector2, "t": float}
var clamp_t := [0.0, 0.0, 0.0, 0.0]
var field_glow: Array = []  # [point on the field edge, strength]
var bounds_body: StaticBody2D
var font: Font
var add_node: Node2D
var static_node: Node2D
var clamp_node: Node2D
var _zh := Txt.zh
var _clamp_drawn: Array = []
var _was_busy := true
var t := 0.0


func _init() -> void:
	z_index = -1
	z_as_relative = false
	font = Fonts.get_font("Regular")
	for k in ZONES:
		zone_state[k] = {"glow": 0.0, "busy": 0.0, "reject": 0.0, "eat": 0.0}
	bounds_body = StaticBody2D.new()
	bounds_body.collision_layer = 4
	bounds_body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	bounds_body.physics_material_override = pm
	add_child(bounds_body)
	var M := Geom.M
	var segs := [[Vector2(TOWER_X, FLOOR_Y) * M, Vector2(FLOOR_X1, FLOOR_Y) * M], [Vector2(TOWER_X + 0.6, -12.6) * M, Vector2(TOWER_X + 0.6, FLOOR_Y) * M], [Vector2(TOWER_X, -10.0) * M, Vector2(ARM_X1, -10.0) * M]]
	for s in segs:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = s[0]
		sh.b = s[1]
		cs.shape = sh
		bounds_body.add_child(cs)
	add_node = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_node.material = m
	add_node.z_index = 8
	add_node.z_as_relative = false
	add_node.draw.connect(_draw_add)
	add_child(add_node)
	# the berth itself never changes: drawn once, under everything that moves
	static_node = Node2D.new()
	static_node.show_behind_parent = true
	static_node.draw.connect(_draw_static)
	add_child(static_node)
	clamp_node = Node2D.new()
	clamp_node.show_behind_parent = true
	clamp_node.draw.connect(_draw_clamps)
	add_child(clamp_node)


static func zpos(id: String) -> Vector2:
	return ZONES[id].pos * Geom.M


static func inside(id: String) -> Vector2:
	return (ZONES[id].pos - ZONES[id].face * 1.1) * Geom.M


# ---------------------------------------------------------------- per frame

func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim:
		return
	for b in world.bodies.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			continue
		b.rejected_t = maxf(0.0, b.rejected_t - dt)
		var com: Vector2 = b.global_transform * b.center_of_mass
		# the tractor field eases strays back in over the open edges
		var pull := field_pull(com)
		if pull != Vector2.ZERO:
			b.apply_central_force(pull * b.mass)
			b.linear_velocity *= exp(-0.8 * dt)
		for id in ZONES:
			var zp := zpos(id)
			var d := zp - com
			var dist := d.length()
			if dist > FIELD * Geom.M or b.rejected_t > 0.0:
				continue
			zone_state[id].glow = 1.0
			var k := 1.0 - dist / (FIELD * Geom.M)
			b.apply_central_force(d.normalized() * b.mass * (220.0 * k + 40.0))
			b.linear_velocity *= exp(-1.6 * k * dt)
			if dist < CATCH * Geom.M:
				var verdict: Dictionary = game.judge(b, id)
				if verdict.ok:
					_start_swallow(b, id)
				else:
					b.rejected_t = 2.2
					zone_state[id].reject = 1.0
					b.apply_central_impulse(-ZONES[id].face * b.mass * 380.0 + Vector2(randf_range(-60, 60), 0) * b.mass)
					game.on_reject(b, id, verdict)
				break


func _process(dt: float) -> void:
	t += dt
	for id in zone_state:
		var z: Dictionary = zone_state[id]
		z.glow = maxf(0.0, z.glow - dt * 2.0)
		z.reject = maxf(0.0, z.reject - dt * 1.6)
		z.eat = maxf(0.0, z.eat - dt * 1.4)
	_step_swallow(dt)
	_step_debris(dt)
	_step_hoses(dt)
	for g in field_glow:
		g[1] -= dt * 2.5
	field_glow = field_glow.filter(func(g): return g[1] > 0.0)
	for i in 4:
		var alive := false
		for j in world.joints:
			if j.alive and j.type == "clamp" and absf(j.pos.x / Geom.M - CLAMPS[i]) < 0.3:
				alive = true
		clamp_t[i] = move_toward(clamp_t[i], 0.0 if alive else 1.0, dt / 0.8)
	if Txt.zh != _zh:
		_zh = Txt.zh
		static_node.queue_redraw()
		queue_redraw()
	# the moving parts only redraw while something moves
	var busy := not hoses.is_empty() or not debris.is_empty() or game.state == "intro"
	for id in zone_state:
		var z: Dictionary = zone_state[id]
		if z.glow > 0.0 or z.reject > 0.0 or z.eat > 0.0:
			busy = true
	if clamp_t != _clamp_drawn:
		_clamp_drawn = clamp_t.duplicate()
		clamp_node.queue_redraw()
	if busy or _was_busy:
		queue_redraw()
	_was_busy = busy
	add_node.queue_redraw()


# acceleration the field gives at a point (zero well inside the berth)
func field_pull(p: Vector2) -> Vector2:
	var M := Geom.M
	var inner := Rect2((BOUNDS.position + Vector2(0.0, 2.0)) * M, (BOUNDS.size - Vector2(2.5, 2.0)) * M)
	if inner.has_point(p):
		return Vector2.ZERO
	var c := inner.get_center()
	var q := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	var depth := p.distance_to(q)
	if field_glow.size() < 40:
		field_glow.append([q, 1.0])
	return (q - p).normalized() * (60.0 + depth * 1.6) + (c - p).normalized() * 10.0


func _start_swallow(b, id: String) -> void:
	b.capture = id
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.set_deferred("freeze", true)
	b.collision_layer = 0
	b.collision_mask = 0
	if game.tools.held_body == b:
		game.tools.release_grab(false)
	swallowing.append([b, id, 0.0, b.global_position, b.rotation])
	zone_state[id].busy = 1.0
	game.on_swallow_start(b, id)


func _step_swallow(dt: float) -> void:
	var done: Array = []
	for s in swallowing:
		var b = s[0]
		if not is_instance_valid(b):
			done.append(s)
			continue
		s[2] += dt
		var k: float = clampf(s[2] / 0.55, 0.0, 1.0)
		var e := Pal.ease_in(k)
		var tgt := inside(s[1])
		var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
		b.global_position = (s[3] as Vector2).lerp(tgt - com_off, e)
		b.rotation = s[4] + e * 0.9 * (1.0 if int(s[3].x) % 2 == 0 else -1.0)
		b.view.scale = Vector2.ONE * lerpf(1.0, 0.25, e)
		b.view.position = b.center_of_mass * (1.0 - b.view.scale.x)
		b.heat_view.scale = b.view.scale
		b.heat_view.position = b.view.position
		var zid: String = s[1]
		if randf() < 0.6:
			var mouth := zpos(zid)
			var col := Pal.heat(0.9, 2.0) if zid == "metal" else (Pal.tint(Pal.FLUID, 0.8, 1.4) if zid == "hazard" else Pal.ink(0.8, 1.4))
			game.fx.sparks(mouth + Vector2(randf_range(-40, 40), 0), -ZONES[zid].face, 2, col, 200.0, 0.35, 0.5)
		if k >= 1.0:
			done.append(s)
			zone_state[zid].eat = 1.0
			game.on_swallowed(b, zid)
	for s in done:
		swallowing.erase(s)


# Small cut-offs: no physics, they are blown along the dock floor into the net.
func add_debris(poly_world: PackedVector2Array, vel: Vector2, value: float) -> void:
	var c := Geom.centroid(poly_world)
	var local := PackedVector2Array()
	for q in poly_world:
		local.append(q - c)
	debris.append([c, vel, 0.0, local, 0.0, randf_range(-5, 5), value, []])


func _step_debris(dt: float) -> void:
	var net := NET * Geom.M
	var arrived: Array = []
	for d in debris:
		d[2] += dt
		var to: Vector2 = net - d[0]
		var steer := 0.0 if d[2] < 0.45 else clampf((d[2] - 0.45) * 2.0, 0.0, 1.0)
		var want: Vector2 = to.normalized() * minf(900.0, 260.0 + d[2] * 300.0)
		d[1] = (d[1] as Vector2).lerp(want, steer * (1.0 - exp(-4.0 * dt)))
		d[0] += d[1] * dt
		d[4] += d[5] * dt
		var tr: Array = d[7]
		tr.push_front(d[0])
		while tr.size() > 10:
			tr.pop_back()
		if to.length() < 40.0 and d[2] > 0.5:
			arrived.append(d)
	for d in arrived:
		debris.erase(d)
		game.fx.flash(net, 30.0, 0.25, Pal.ink(0.4, 1.2))
		game.on_debris_in(d[6], net)


# ---------------------------------------------------------------- hoses

func hose_attach(port_id: String, port_pos: Vector2) -> void:
	var best: Vector2 = MASTS[0] * Geom.M
	for m in MASTS:
		if (m * Geom.M).distance_to(port_pos) < best.distance_to(port_pos):
			best = m * Geom.M
	var n := 22
	var pts: Array = []
	for i in n:
		pts.append(best)
	hoses[port_id] = {"pts": pts, "prev": pts.duplicate(), "mast": best, "t": 0.0}


func hose_detach(port_id: String) -> void:
	hoses.erase(port_id)


func _step_hoses(dt: float) -> void:
	for id in hoses:
		var h: Dictionary = hoses[id]
		h.t += dt
		var c = world.ctrls.get(id)
		if c == null:
			continue
		var end: Vector2 = world.ctrl_world(c)
		var pts: Array = h.pts
		var prev: Array = h.prev
		var n := pts.size()
		var reach := Pal.ease_out(h.t / 0.45)
		var tip: Vector2 = (h.mast as Vector2).lerp(end, reach)
		var seg := maxf(6.0, (h.mast as Vector2).distance_to(end) * 1.12 / (n - 1))
		for i in range(1, n - 1):
			var p: Vector2 = pts[i]
			var v: Vector2 = (p - prev[i]) * 0.94
			prev[i] = p
			pts[i] = p + v + Vector2(0, 30.0) * dt * dt
		pts[0] = h.mast
		pts[n - 1] = tip
		for it in 6:
			for i in n - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var d := b - a
				var l := d.length()
				if l < 0.001:
					continue
				var diff := (l - seg) / l * 0.5
				if i > 0:
					pts[i] = a + d * diff
				if i + 1 < n - 1:
					pts[i + 1] = b - d * diff
			pts[0] = h.mast
			pts[n - 1] = tip


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	# recovery mouths
	for id in ZONES:
		_mouth(id)
	# hoses
	for id in hoses:
		var pts := PackedVector2Array(hoses[id].pts)
		draw_polyline(pts, Pal.ink(0.55), 3.4, true)
		draw_polyline(pts, Color(0.05, 0.05, 0.06), 1.4, true)
	# the tug that brings GR-7 in
	var tug := tug_pos()
	if tug != Vector2.INF:
		_tug(tug)
	# debris on its way to the net
	for d in debris:
		var tr := Transform2D(d[4], d[0])
		var poly: PackedVector2Array = tr * (d[3] as PackedVector2Array)
		if Geom.valid(poly):
			draw_colored_polygon(poly, Color(0.09, 0.093, 0.1))
		var cl := poly.duplicate()
		if cl.size() > 0:
			cl.append(poly[0])
			draw_polyline(cl, Pal.ink(0.6), 1.0, true)


func _draw_static() -> void:
	var ci := static_node
	var M := Geom.M
	# the berth: floor platform with legs into the dark, the tower, the arm
	_truss(Rect2(TOWER_X * M, FLOOR_Y * M, (FLOOR_X1 - TOWER_X) * M, 0.6 * M))
	for lx in [-2.0, 10.0, 22.0, 34.0, 46.0]:
		var l0 := Vector2(lx * M, (FLOOR_Y + 0.6) * M)
		ci.draw_line(l0, l0 + Vector2(-0.8 * M, 5.0 * M), Pal.ink(0.18), 1.4)
		ci.draw_line(l0 + Vector2(0.6 * M, 0), l0 + Vector2(1.4 * M, 5.0 * M), Pal.ink(0.18), 1.4)
	_truss_v(Rect2(TOWER_X * M, -12.6 * M, 0.6 * M, (FLOOR_Y + 12.6) * M))
	_truss(Rect2(TOWER_X * M, -10.6 * M, (ARM_X1 - TOWER_X) * M, 0.6 * M))
	ci.draw_line(Vector2(TOWER_X + 0.6, -6.0) * M, Vector2(TOWER_X + 6.0, -10.0) * M, Pal.ink(0.22), 2.0)
	ci.draw_rect(Rect2((ARM_X1 - 0.3) * M, -10.8 * M, 0.5 * M, 1.0 * M), Color(0.07, 0.073, 0.082))
	ci.draw_rect(Rect2((ARM_X1 - 0.3) * M, -10.8 * M, 0.5 * M, 1.0 * M), Pal.ink(0.5), false, 1.2)
	ci.draw_rect(Rect2((FLOOR_X1 - 0.2) * M, (FLOOR_Y - 0.3) * M, 0.5 * M, 1.2 * M), Color(0.07, 0.073, 0.082))
	ci.draw_rect(Rect2((FLOOR_X1 - 0.2) * M, (FLOOR_Y - 0.3) * M, 0.5 * M, 1.2 * M), Pal.ink(0.5), false, 1.2)
	ci.draw_string(font, Vector2(TOWER_X + 0.9, -11.4) * M, "BERTH 07  ·  SALVAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(0.32))
	# dock floor markings under the ship
	for x in range(0, 44, 3):
		ci.draw_line(Vector2(x * M, 8.85 * M), Vector2((x + 1.4) * M, 8.85 * M), Pal.ink(0.1), 2.0)
	# debris net
	var nc := NET * M
	var net_pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI * 1.1, PI * 1.9, i / 12.0)
		net_pts.append(nc + Vector2(cos(a) * 70.0, -sin(a) * 26.0 + 30.0))
	ci.draw_polyline(net_pts, Pal.ink(0.5), 1.4, true)
	for i in range(0, 13, 2):
		ci.draw_line(net_pts[i], nc + Vector2(0, 34), Pal.ink(0.14), 1.0)
	ci.draw_string(font, nc + Vector2(-48, 62), game.txt("net"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.35))
	# drone bay
	var bc := BAY * M
	ci.draw_rect(Rect2(bc + Vector2(-90, -40), Vector2(90, 80)), Color(0.06, 0.063, 0.072))
	ci.draw_polyline(PackedVector2Array([bc + Vector2(0, -40), bc + Vector2(-90, -40), bc + Vector2(-90, 40), bc + Vector2(0, 40)]), Pal.ink(0.6), 1.6, true)
	for i in 3:
		ci.draw_line(bc + Vector2(-80 + i * 26, -40), bc + Vector2(-80 + i * 26, 40), Pal.ink(0.1), 1.0)
	ci.draw_string(font, bc + Vector2(-86, -50), "R-02  BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.4))
	# hose masts (two on the arm, one on a pylon from the floor)
	var pyl: Vector2 = MASTS[2] * M
	_truss_v(Rect2(pyl.x - 0.25 * M, pyl.y, 0.5 * M, FLOOR_Y * M - pyl.y))
	for m in MASTS:
		var mp: Vector2 = m * M
		ci.draw_rect(Rect2(mp + Vector2(-10, -14), Vector2(20, 18)), Color(0.07, 0.073, 0.082))
		ci.draw_rect(Rect2(mp + Vector2(-10, -14), Vector2(20, 18)), Pal.ink(0.5), false, 1.2)


func _draw_clamps() -> void:
	var M := Geom.M
	var ink := Pal.ink(0.32)
	for i in 4:
		var x: float = CLAMPS[i] * M
		var k: float = Pal.ease_io(clamp_t[i])
		var top := lerpf(4.0 * M, 7.6 * M, k)
		clamp_node.draw_rect(Rect2(x - 7, top + 10, 14, 9.0 * M - top - 10), Color(0.07, 0.073, 0.082))
		clamp_node.draw_rect(Rect2(x - 7, top + 10, 14, 9.0 * M - top - 10), ink, false, 1.2)
		for yy in range(int(top + 22), int(9.0 * M), 18):
			clamp_node.draw_line(Vector2(x - 7, yy), Vector2(x + 7, yy + 9), Pal.ink(0.12), 1.0)
		var open := k * 9.0
		clamp_node.draw_polyline(PackedVector2Array([Vector2(x - 16 - open, top + 2), Vector2(x - 16 - open, top + 12), Vector2(x + 16 + open, top + 12), Vector2(x + 16 + open, top + 2)]), Pal.ink(0.75), 2.0, true)
		clamp_node.draw_string(font, Vector2(x + 12, 8.6 * M), "CL-0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.ink(0.3))


func tug_pos() -> Vector2:
	if game == null or game.state != "intro":
		return Vector2.INF
	var tt: float = game.state_t
	var x: float = world.position.x + 42.0 * Geom.M
	if tt > 3.4:
		x += pow(tt - 3.4, 2.0) * 900.0
	return Vector2(x, 0.0)


func _tug(p: Vector2) -> void:
	var M := Geom.M
	var hull := PackedVector2Array([p + Vector2(0.2 * M, -0.9 * M), p + Vector2(4.6 * M, -1.3 * M), p + Vector2(6.0 * M, -0.6 * M), p + Vector2(6.0 * M, 0.6 * M), p + Vector2(4.6 * M, 1.3 * M), p + Vector2(0.2 * M, 0.9 * M)])
	draw_colored_polygon(hull, Color(0.07, 0.073, 0.082))
	var cl := hull.duplicate()
	cl.append(hull[0])
	draw_polyline(cl, Pal.ink(0.8), 1.4, true)
	draw_line(p + Vector2(0.0, -0.7 * M), p + Vector2(0.0, 0.7 * M), Pal.ink(0.9), 3.0)
	draw_rect(Rect2(p + Vector2(2.0 * M, -0.5 * M), Vector2(1.6 * M, 1.0 * M)), Pal.ink(0.3), false, 1.0)
	draw_string(font, p + Vector2(2.1 * M, -0.6 * M), "TUG-04", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.5))


func _mouth(id: String) -> void:
	var M := Geom.M
	var z: Dictionary = ZONES[id]
	var st: Dictionary = zone_state[id]
	var c: Vector2 = z.pos * M
	var f: Vector2 = z.face
	var side := Vector2(-f.y, f.x)
	var hw: float = z.w * 0.5 * M
	var depth := 1.6 * M
	var bite: float = st.eat * 10.0
	var body_poly := PackedVector2Array([c + side * (hw + 18), c + side * (hw + 18) - f * depth, c - side * (hw + 18) - f * depth, c - side * (hw + 18)])
	draw_colored_polygon(body_poly, Color(0.06, 0.063, 0.072))
	var col := Pal.ink(0.75)
	if st.reject > 0.0:
		col = col.lerp(Pal.heat(1.0, 1.4), st.reject)
	# jaws
	var jaw_l := PackedVector2Array([c + side * (hw + 18), c + side * (hw - bite) + f * 10.0, c + side * (hw - 14 - bite) + f * 4.0])
	var jaw_r := PackedVector2Array([c - side * (hw + 18), c - side * (hw - bite) + f * 10.0, c - side * (hw - 14 - bite) + f * 4.0])
	draw_polyline(jaw_l, col, 2.4, true)
	draw_polyline(jaw_r, col, 2.4, true)
	draw_line(c + side * (hw + 18), c + side * (hw + 18) - f * depth, Pal.ink(0.4), 1.2)
	draw_line(c - side * (hw + 18), c - side * (hw + 18) - f * depth, Pal.ink(0.4), 1.2)
	draw_line(c + side * (hw + 18) - f * depth, c - side * (hw + 18) - f * depth, Pal.ink(0.4), 1.2)
	# throat
	for i in 4:
		var y := -f * (14.0 + i * 16.0)
		draw_line(c + side * (hw - 6 - i * 10) + y, c - side * (hw - 6 - i * 10) + y, Pal.ink(0.1 + 0.05 * st.glow), 1.0)
	var label: String = game.txt("zone_" + id)
	var lp := c - f * (depth * 0.5) + Vector2(hw + 34.0, 6.0)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.62))
	draw_line(lp + Vector2(-8, -16), lp + Vector2(-8, 4), Pal.heat(0.8, 1.0) if id == "metal" else Pal.ink(0.4), 2.0)
	# the catch field, faintly, while something is near
	if st.glow > 0.01:
		draw_arc(c, FIELD * M, 0.0, TAU, 64, Pal.ink(0.06 * st.glow), 1.0, true)


func _truss(r: Rect2) -> void:
	static_node.draw_rect(r, Color(0.055, 0.058, 0.066))
	static_node.draw_line(r.position, Vector2(r.end.x, r.position.y), Pal.ink(0.32), 1.2)
	static_node.draw_line(Vector2(r.position.x, r.end.y), r.end, Pal.ink(0.32), 1.2)
	var x := r.position.x
	var k := 0
	while x < r.end.x:
		var nx := minf(x + r.size.y, r.end.x)
		if k % 2 == 0:
			static_node.draw_line(Vector2(x, r.position.y), Vector2(nx, r.end.y), Pal.ink(0.12), 1.0)
		else:
			static_node.draw_line(Vector2(x, r.end.y), Vector2(nx, r.position.y), Pal.ink(0.12), 1.0)
		x = nx
		k += 1


func _truss_v(r: Rect2) -> void:
	static_node.draw_rect(r, Color(0.055, 0.058, 0.066))
	static_node.draw_line(r.position, Vector2(r.position.x, r.end.y), Pal.ink(0.32), 1.2)
	static_node.draw_line(Vector2(r.end.x, r.position.y), r.end, Pal.ink(0.32), 1.2)
	var y := r.position.y
	var k := 0
	while y < r.end.y:
		var ny := minf(y + r.size.x, r.end.y)
		if k % 2 == 0:
			static_node.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, ny), Pal.ink(0.12), 1.0)
		else:
			static_node.draw_line(Vector2(r.end.x, y), Vector2(r.position.x, ny), Pal.ink(0.12), 1.0)
		y = ny
		k += 1


func _draw_add() -> void:
	var tex: Texture2D = game.fx.glow_tex
	var M := Geom.M
	# beacons on the open ends of the arm and the platform, and the field corners
	var blink := 0.5 + 0.5 * sin(t * 2.4)
	for bp in [Vector2(ARM_X1, -10.3), Vector2(FLOOR_X1, FLOOR_Y + 0.3)]:
		add_node.draw_texture_rect(tex, Rect2(bp * M - Vector2(18, 18), Vector2(36, 36)), false, Pal.heat(0.25 + 0.6 * blink, 1.8))
		add_node.draw_circle(bp * M, 2.5, Pal.heat(0.6 + 0.4 * blink, 2.0))
	var fr := Rect2((BOUNDS.position + Vector2(0.0, 2.0)) * M, (BOUNDS.size - Vector2(2.5, 2.0)) * M)
	var fb := 0.5 + 0.5 * sin(t * 1.3 + 1.0)
	for cp in [fr.position, Vector2(fr.end.x, fr.position.y), Vector2(fr.end.x, fr.end.y)]:
		add_node.draw_texture_rect(tex, Rect2(cp - Vector2(12, 12), Vector2(24, 24)), false, Pal.ink(0.12 + 0.2 * fb, 1.3))
	# the field lights up where something leans on it
	for g in field_glow:
		var a: float = g[1]
		add_node.draw_texture_rect(tex, Rect2(g[0] - Vector2(60, 60), Vector2(120, 120)), false, Pal.tint(Pal.AIR, 0.18 * a, 1.2))
	for id in ZONES:
		var st: Dictionary = zone_state[id]
		var c := zpos(id)
		var f: Vector2 = ZONES[id].face
		var throat := c - f * 1.0 * Geom.M
		var col := Pal.heat(1.0, 1.6) if id == "metal" else (Pal.tint(Pal.FLUID, 1.0, 1.2) if id == "hazard" else Pal.ink(1.0, 1.2))
		var base := 0.16 if id == "metal" else 0.06
		var a: float = base + 0.25 * st.glow + 0.7 * st.eat
		var r: float = 70.0 + 50.0 * st.eat
		add_node.draw_texture_rect(tex, Rect2(throat - Vector2(r * 1.6, r), Vector2(r * 3.2, r * 2.0)), false, Color(col.r, col.g, col.b, a))
		if id == "metal":
			# the furnace always breathes
			var br := 0.08 + 0.05 * sin(t * 2.1)
			add_node.draw_texture_rect(tex, Rect2(throat - Vector2(90, 40), Vector2(180, 80)), false, Pal.heat(br, 1.4))
	var tug := tug_pos()
	if tug != Vector2.INF and game.state_t < 3.4:
		var fl := 0.8 + 0.2 * sin(t * 50.0)
		var base := tug + Vector2(6.0 * Geom.M, 0)
		add_node.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -16), base + Vector2(90 * fl, 0), base + Vector2(0, 16)]), Pal.heat(0.6, 1.8))
		add_node.draw_texture_rect(tex, Rect2(base - Vector2(40, 40), Vector2(80, 80)), false, Pal.heat(0.5, 1.6))
	for d in debris:
		var tr: Array = d[7]
		if tr.size() >= 2:
			add_node.draw_polyline(PackedVector2Array(tr), Pal.ink(0.25, 1.2), 2.0, true)
