class_name Dock
extends Node2D
# The vacuum dock around the ship: girders, the four clamp arms, the three
# recovery mouths (equipment bay, metal furnace, hazard bay), the debris net,
# the drone bay and the hose masts. Recovery mouths pull in whatever drifts
# close, judge it, and either swallow it or spit it back out.

const BASE_ZONES := {
	"equip": {"pos": Vector2(14.0, -8.4), "face": Vector2(0, 1), "w": 4.2},
	"metal": {"pos": Vector2(21.0, 7.7), "face": Vector2(0, -1), "w": 4.6},
	"hazard": {"pos": Vector2(43.6, 6.9), "face": Vector2(0, -1), "w": 3.2},
}
const NET := Vector2(2.8, 8.3)
const BAY := Vector2(-5.0, -6.0)
# The berth's length (roadmap 4.1): the standard berth's floor ends at 50 m;
# the extension (a career purchase) takes it to EXTENDED. Everything along
# the berth follows its end: the hazard bay and the far mast stay at the far
# end, the trough runs on to it, the equipment bay and the furnace move to the
# middle third, the boom reaches further. Set once per contract (configure).
const STANDARD := 50.0
const EXTENDED := 88.0
static var floor_end := STANDARD
static var ZONES := BASE_ZONES.duplicate(true)
static var MASTS: Array = [Vector2(5.0, -10.0), Vector2(23.0, -10.0), Vector2(38.0, 6.6)]
# semi-open berth: a floor platform, a tower on the left with an arm reaching
# over the ship; the top and the right are open to space, held only by a
# tractor field that eases strays back in
const FLOOR_Y := 9.0
static var FLOOR_X1 := 50.0
const TOWER_X := -7.4
static var ARM_X1 := 27.5
static var BOUNDS := Rect2(-6.8, -15.0, 63.0, 24.0)
const FIELD := 3.4
const CATCH := 1.3
# the furnace reaches further for scrap that has been let go (aim and throw):
# whole equipment, hazards and whatever the grapple still holds only feel the
# small field. Along the bottom of the berth runs a scrap trough: scrap that
# drops into it rides a conveyor to the furnace (design/体验打磨定案.md §6)
const SCRAP_FIELD := 7.0
const TROUGH_Y := 8.2               # m: the trough's lip; below it a body is in the trough
const TROUGH_X0 := 5.5
static var TROUGH_X1 := 40.5        # stops short of the hazard mouth
const CONVEY := 7.0                 # m/s along the trough
const RAIL_SPEED := 4.0             # m/s: the movable furnace mouth along its rail
static var metal_x := 21.0          # where the furnace mouth sits (it moves only with the rail upgrade)
static var metal_home := 21.0       # where it sits at the start
var mouth_target := 21.0


# lay the berth out for a floor ending at x (m): STANDARD or EXTENDED
static func configure(x: float) -> void:
	floor_end = x
	var d := x - STANDARD
	FLOOR_X1 = x
	BOUNDS = Rect2(-6.8, -15.0, 63.0 + d, 24.0)
	TROUGH_X1 = 40.5 + d
	ARM_X1 = 27.5 + d * 0.6
	ZONES = BASE_ZONES.duplicate(true)
	ZONES.hazard.pos.x += d
	ZONES.equip.pos.x += d * 0.45
	ZONES.metal.pos.x += d * 0.45
	metal_home = ZONES.metal.pos.x
	MASTS = [Vector2(5.0, -10.0), Vector2(23.0 + d * 0.45, -10.0), Vector2(38.0 + d, 6.6)]
	if d > 0.0:
		MASTS.append(Vector2(23.0 + d * 1.1, -10.0))


# the middle of the berth, where the overview looks
static func centre() -> Vector2:
	return Vector2((TOWER_X + FLOOR_X1) * 0.5, -2.0)

var game: Game
var world: World
var zone_state := {}       # id -> {"glow": float, "busy": float, "reject": float, "eat": float}
var swallowing: Array = [] # [body, zone, t, start_pos, start_rot]
var conveying: Array = []  # bodies riding the trough to the furnace
var debris: Array = []     # [pos, vel, t, poly, rot, spin, value, trail]
var hoses := {}            # port id -> {"pts": [], "prev": [], "mast": Vector2, "t": float}
var clamps: Array = []     # Vector2 in metres: where each dock clamp grips the ship (from the ship file)
var clamp_t: Array = []
var field_glow: Array = []  # [point on the field edge, strength]
var bounds_body: StaticBody2D
var font: Font
var font_b: Font
var add_node: Node2D
var static_node: Node2D
var clamp_node: Node2D
var _zh := Txt.zh
var _clamp_drawn: Array = []
var _was_busy := true
var t := 0.0


func _init() -> void:
	metal_x = metal_home
	mouth_target = metal_home
	z_index = -1
	z_as_relative = false
	font = Fonts.get_font("Regular")
	font_b = Fonts.get_font("Medium")
	for k in ZONES:
		zone_state[k] = {"glow": 0.0, "busy": 0.0, "reject": 0.0, "eat": 0.0}
	bounds_body = StaticBody2D.new()
	bounds_body.collision_layer = 4
	bounds_body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	bounds_body.physics_material_override = pm
	add_child(bounds_body)
	_bounds()
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


var stern := Vector2(42.0, 0.0)   # m: where the tug pushes, the ship's aft end


# the floor, the tower and the boom as walls (the berth's length set by configure)
func _bounds() -> void:
	for ch in bounds_body.get_children():
		ch.queue_free()
	var M := Geom.M
	var segs := [[Vector2(TOWER_X, FLOOR_Y) * M, Vector2(FLOOR_X1, FLOOR_Y) * M], [Vector2(TOWER_X + 0.6, -12.6) * M, Vector2(TOWER_X + 0.6, FLOOR_Y) * M], [Vector2(TOWER_X, -10.0) * M, Vector2(ARM_X1, -10.0) * M]]
	for s in segs:
		var cs := CollisionShape2D.new()
		var sh := SegmentShape2D.new()
		sh.a = s[0]
		sh.b = s[1]
		cs.shape = sh
		bounds_body.add_child(cs)


func set_ship(ship: Dictionary) -> void:
	# the berth as configured for this contract
	metal_x = metal_home
	mouth_target = metal_home
	_bounds()
	if static_node != null:
		static_node.queue_redraw()
	# the tug sits right behind whatever ship this is
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for pd in ship.get("pieces", []):
		for q in pd.get("poly", []):
			x1 = maxf(x1, q[0])
			y0 = minf(y0, q[1])
			y1 = maxf(y1, q[1])
	if x1 > -INF:
		stern = Vector2(x1 + 0.4, (y0 + y1) * 0.5)
	clamps = []
	clamp_t = []
	for c in ship.get("clamps", []):
		clamps.append(Vector2(c[0], c[1]))
		clamp_t.append(0.0)
	_clamp_drawn = []


static func zpos(id: String) -> Vector2:
	if id == "metal":
		return Vector2(metal_x, ZONES.metal.pos.y) * Geom.M
	return ZONES[id].pos * Geom.M


static func inside(id: String) -> Vector2:
	return zpos(id) - ZONES[id].face * 1.1 * Geom.M


# the rail upgrade: the furnace mouth runs along the trough to under x (m)
func move_mouth(x: float) -> void:
	mouth_target = clampf(x, TROUGH_X0 + 2.5, TROUGH_X1 - 2.5)


# ---------------------------------------------------------------- per frame

func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim:
		return
	for b in world.bodies.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			continue
		b.rejected_t = maxf(0.0, b.rejected_t - dt)
		var com: Vector2 = b.global_transform * b.center_of_mass
		var held: bool = game.tools.held_body == b
		var scrap := is_scrap(b)
		# into the trough: scrap rides it to the furnace; anything else is lifted back out
		if not held and in_trough(com):
			if scrap:
				_start_convey(b)
				continue
			if b.rejected_t <= 0.0:
				b.rejected_t = 1.5
				b.apply_central_impulse(Vector2(0, -260.0) * b.mass)
				game.say("trough_only_scrap", com)
		# the tractor field eases strays back in over the open edges
		var pull := field_pull(com)
		if pull != Vector2.ZERO:
			b.apply_central_force(pull * b.mass)
			b.linear_velocity *= exp(-0.8 * dt)
		for id in ZONES:
			var zp := zpos(id)
			var d := zp - com
			var dist := d.length()
			var reach := SCRAP_FIELD if id == "metal" and scrap and not held else FIELD
			if dist > reach * Geom.M or b.rejected_t > 0.0:
				continue
			zone_state[id].glow = 1.0
			var k := 1.0 - dist / (reach * Geom.M)
			# scrap let go near the furnace is drawn in hard: a throw in its general direction is enough
			var pullk := 2.6 if id == "metal" and scrap and not held else 1.0
			b.apply_central_force(d.normalized() * b.mass * (220.0 * k + 40.0) * pullk)
			b.linear_velocity *= exp(-1.6 * k * dt * pullk)
			var catch_r: float = (CATCH * 1.5 if id == "metal" and scrap else CATCH)
			if dist < catch_r * Geom.M:
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
	if absf(metal_x - mouth_target) > 0.001:
		metal_x = move_toward(metal_x, mouth_target, RAIL_SPEED * dt)
		zone_state["metal"].glow = 1.0
	for id in zone_state:
		var z: Dictionary = zone_state[id]
		z.glow = maxf(0.0, z.glow - dt * 2.0)
		z.reject = maxf(0.0, z.reject - dt * 1.6)
		z.eat = maxf(0.0, z.eat - dt * 1.4)
	_step_convey(dt)
	_step_swallow(dt)
	_step_debris(dt)
	_step_hoses(dt)
	for g in field_glow:
		g[1] -= dt * 2.5
	field_glow = field_glow.filter(func(g): return g[1] > 0.0)
	for i in clamps.size():
		var alive := false
		for j in world.joints:
			if j.alive and j.type == "clamp" and absf(j.pos.x / Geom.M - clamps[i].x) < 0.3:
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
	# the mouths' lamps and the trough's belt keep moving
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


# scrap: nothing whole to save and nothing dangerous in it
func is_scrap(b) -> bool:
	for p in b.pieces:
		if p.cls == "equip" and p.intact:
			return false
		if game.sys.dest_of(p) == "hazard":
			return false
	return true


static func in_trough(com: Vector2) -> bool:
	var x := com.x / Geom.M
	return com.y > TROUGH_Y * Geom.M and x > TROUGH_X0 and x < TROUGH_X1


# the point on the trough straight below p (where to push scrap down to)
static func trough_below(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x / Geom.M, TROUGH_X0 + 0.5, TROUGH_X1 - 0.5), TROUGH_Y + 0.3) * Geom.M


func _start_convey(b) -> void:
	b.capture = "trough"
	b.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	b.set_deferred("freeze", true)
	b.collision_layer = 0
	b.collision_mask = 0
	conveying.append(b)
	game.sfx.play("clank", b.global_position, 0.6)


func _step_convey(dt: float) -> void:
	var M := Geom.M
	var mouth := zpos("metal")
	for b in conveying.duplicate():
		if not is_instance_valid(b):
			conveying.erase(b)
			continue
		var com_off: Vector2 = b.global_transform.basis_xform(b.center_of_mass)
		var com: Vector2 = b.global_position + com_off
		var lane := (TROUGH_Y + 0.45) * M
		var nx := move_toward(com.x, mouth.x, CONVEY * M * dt)
		var ny := move_toward(com.y, lane, CONVEY * M * dt)
		b.global_position = Vector2(nx, ny) - com_off
		b.rotation = lerp_angle(b.rotation, 0.0, 1.0 - exp(-3.0 * dt))
		if absf(nx - mouth.x) < 0.4 * M:
			conveying.erase(b)
			swallowing.append([b, "metal", 0.0, b.global_position, b.rotation])
			b.capture = "metal"
			zone_state["metal"].busy = 1.0
			game.on_swallow_start(b, "metal")


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
	_trough_live()
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
	# the berth's back wall: a dark bay behind the ship, ribbed, its number painted big
	var wall := PackedVector2Array([Vector2(TOWER_X + 0.6, -10.0) * M, Vector2(ARM_X1, -10.0) * M, Vector2(ARM_X1 + 4.0, -5.0) * M,
		Vector2(FLOOR_X1 - 6.0, -5.0) * M, Vector2(FLOOR_X1 - 2.0, FLOOR_Y) * M, Vector2(TOWER_X + 0.6, FLOOR_Y) * M])
	ci.draw_colored_polygon(wall, Color(0.015, 0.017, 0.021, 0.92))
	var wx := TOWER_X + 6.0
	while wx < FLOOR_X1 - 6.0:
		var top := -10.0 if wx <= ARM_X1 else (-5.0 if wx >= ARM_X1 + 4.0 else lerpf(-10.0, -5.0, (wx - ARM_X1) / 4.0))
		ci.draw_rect(Rect2(Vector2(wx - 0.18, top) * M, Vector2(0.36 * M, (FLOOR_Y - top) * M)), Color(0.017, 0.019, 0.024))
		ci.draw_line(Vector2(wx - 0.18, top) * M, Vector2(wx - 0.18, FLOOR_Y) * M, Pal.ink(0.07), 1.0)
		wx += 6.0
	for sy in [-5.0, 2.0]:
		ci.draw_line(Vector2(TOWER_X + 0.6, sy) * M, Vector2(FLOOR_X1 - 6.0 + (sy + 5.0) / 14.0 * 4.0, sy) * M, Pal.ink(0.05), 1.0)
	# a strip of small lit ports high on the wall
	var px := TOWER_X + 2.0
	while px < ARM_X1 - 1.0:
		ci.draw_rect(Rect2(Vector2(px, -9.3) * M, Vector2(0.2 * M, 0.2 * M)), Pal.ink(0.07))
		px += 1.2
	var wcl := wall.duplicate()
	wcl.append(wall[0])
	ci.draw_polyline(wcl, Pal.ink(0.16), 1.2, true)
	ci.draw_string(font_b, Vector2(TOWER_X + 1.2, 2.6) * M, "07", HORIZONTAL_ALIGNMENT_LEFT, -1, int(4.4 * M), Pal.ink(0.035))
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

	# the scrap trough along the floor, into the furnace
	var tl := Vector2(TROUGH_X0, TROUGH_Y) * M
	var tr := Vector2(TROUGH_X1, TROUGH_Y) * M
	var th := (FLOOR_Y - TROUGH_Y) * M
	ci.draw_rect(Rect2(tl, Vector2(tr.x - tl.x, th)), Color(0.03, 0.032, 0.036))
	ci.draw_rect(Rect2(tl + Vector2(0, th - 5), Vector2(tr.x - tl.x, 5)), Color(0.06, 0.063, 0.07))
	ci.draw_line(tl - Vector2(0, 2), tr - Vector2(0, 2), Pal.ink(0.55), 2.0)
	ci.draw_line(tl + Vector2(0, 3), tr + Vector2(0, 3), Pal.ink(0.14), 1.0)
	for e in [tl, tr]:
		ci.draw_line(e - Vector2(0, 6), e + Vector2(0, th), Pal.ink(0.55), 2.0)
	# its sign at the left end
	var sr := Rect2(tl + Vector2(1.7 * M, -44), Vector2(206, 30))
	ci.draw_rect(sr, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(sr.position, Vector2(4, sr.size.y)), Pal.heat(0.9, 1.1))
	ci.draw_string(font_b, sr.position + Vector2(14, 21), game.txt("trough"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.9))
	# the open ends: striped, so the edge of the berth reads at a glance
	_stripes(Rect2((FLOOR_X1 - 2.2) * M, FLOOR_Y * M + 3, 2.0 * M, 0.6 * M - 6))
	_stripes(Rect2((ARM_X1 - 2.0) * M, -10.6 * M + 3, 1.6 * M, 0.6 * M - 6))
	# the berth's own plate on the tower: its number, and whose it is
	var pr := Rect2((TOWER_X + 0.9) * M, 5.0 * M, 8.0 * M, 1.4 * M)
	ci.draw_rect(pr, Color(0.035, 0.037, 0.042, 0.96))
	ci.draw_rect(Rect2(pr.position, Vector2(5, pr.size.y)), Pal.heat(0.9, 1.1))
	ci.draw_rect(pr, Pal.ink(0.25), false, 1.0)
	ci.draw_string(font_b, pr.position + Vector2(18, 40), "BERTH 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(0.92))
	var company: String = str(Career.data.get("company", "")) if game != null and game.career() else ""
	ci.draw_string(font, pr.position + Vector2(190, 40), (company + "  ·  " if company != "" and company != "BERTH 07" else "") + "SALVAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.55))
	# debris net
	var nc := NET * M
	var net_pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 1.05, PI * 1.95, i / 16.0)
		net_pts.append(nc + Vector2(cos(a) * 78.0, -sin(a) * 30.0 + 30.0))
	ci.draw_colored_polygon(net_pts, Color(0.04, 0.042, 0.048))
	for i in range(1, 16):
		ci.draw_line(net_pts[i], nc + Vector2((i - 8) * 3.0, 58), Pal.ink(0.12), 1.0)
	for ring in [0.4, 0.7]:
		var rp := PackedVector2Array()
		for q in net_pts:
			rp.append(nc + Vector2(0, 30) + (q - nc - Vector2(0, 30)) * ring)
		ci.draw_polyline(rp, Pal.ink(0.12), 1.0, true)
	ci.draw_polyline(net_pts, Pal.ink(0.7), 2.4, true)
	for e in [net_pts[0], net_pts[16]]:
		ci.draw_circle(e, 4.0, Pal.ink(0.7))
	var cap := 0.5 if game != null and game.has_upgrade("net05") else 0.1
	var nr := Rect2(nc + Vector2(-98, -42), Vector2(196, 30))
	ci.draw_rect(nr, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(nr.position, Vector2(4, nr.size.y)), Pal.ink(0.8))
	ci.draw_string(font_b, nr.position + Vector2(14, 21), game.txt("net") + "  ≤ %.1f t" % cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.9))
	# drone bay
	var bc := BAY * M
	var hr := Rect2(bc + Vector2(-100, -48), Vector2(100, 96))
	ci.draw_rect(hr, Color(0.05, 0.053, 0.06))
	ci.draw_polyline(PackedVector2Array([bc + Vector2(0, -48), bc + Vector2(-100, -48), bc + Vector2(-100, 48), bc + Vector2(0, 48)]), Pal.ink(0.7), 2.0, true)
	# the launch pad: an octagon outline with landing marks
	var pc := bc + Vector2(-46, 0)
	var oct := PackedVector2Array()
	for i in 9:
		oct.append(pc + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * 30.0)
	ci.draw_polyline(oct, Pal.ink(0.3), 1.4, true)
	for i in 4:
		var d := Vector2.from_angle(TAU * i / 4.0)
		ci.draw_line(pc + d * 34.0, pc + d * 42.0, Pal.ink(0.4), 2.0)
	# the door rails at the open side
	ci.draw_line(bc + Vector2(0, -48), bc + Vector2(0, -36), Pal.ink(0.7), 3.0)
	ci.draw_line(bc + Vector2(0, 48), bc + Vector2(0, 36), Pal.ink(0.7), 3.0)
	var br := Rect2(bc + Vector2(-100, -86), Vector2(160, 30))
	ci.draw_rect(br, Color(0.035, 0.037, 0.042, 0.94))
	ci.draw_rect(Rect2(br.position, Vector2(4, br.size.y)), Pal.tint(Pal.AIR, 0.9, 1.1))
	ci.draw_string(font_b, br.position + Vector2(14, 21), game.txt("dk_bay"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.9))
	# hose masts (two on the arm, one on a pylon from the floor)
	var pyl: Vector2 = MASTS[2] * M
	_truss_v(Rect2(pyl.x - 0.25 * M, pyl.y, 0.5 * M, FLOOR_Y * M - pyl.y))
	var pump2: bool = game != null and game.has_upgrade("pump2")
	for m in MASTS:
		var mp: Vector2 = m * M
		ci.draw_rect(Rect2(mp + Vector2(-14, -16), Vector2(28, 22)), Color(0.06, 0.063, 0.07))
		ci.draw_rect(Rect2(mp + Vector2(-14, -16), Vector2(28, 22)), Pal.ink(0.6), false, 1.4)
		# the hose reel
		ci.draw_arc(mp + Vector2(0, -5), 7.0, 0.0, TAU, 16, Pal.ink(0.55), 1.4, true)
		for sp in 3:
			ci.draw_line(mp + Vector2(0, -5), mp + Vector2(0, -5) + Vector2.from_angle(TAU * sp / 3.0) * 7.0, Pal.ink(0.35), 1.0)
		ci.draw_string(font, mp + Vector2(18, 0), game.txt("dk_mast"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.45))
		if pump2:
			# the high-flow pump: a second, bigger housing with an impeller ring
			ci.draw_rect(Rect2(mp + Vector2(12, -18), Vector2(22, 22)), Color(0.07, 0.073, 0.082))
			ci.draw_rect(Rect2(mp + Vector2(12, -18), Vector2(22, 22)), Pal.ink(0.6), false, 1.4)
			ci.draw_arc(mp + Vector2(23, -7), 7.0, 0.0, TAU, 16, Pal.ink(0.55), 1.2, true)
			ci.draw_line(mp + Vector2(10, -6), mp + Vector2(12, -6), Pal.ink(0.5), 2.0)


func _draw_clamps() -> void:
	var M := Geom.M
	var ink := Pal.ink(0.32)
	for i in clamps.size():
		var x: float = clamps[i].x * M
		var k: float = Pal.ease_io(clamp_t[i])
		var top := lerpf(clamps[i].y * M, 7.6 * M, k)
		clamp_node.draw_rect(Rect2(x - 7, top + 10, 14, 9.0 * M - top - 10), Color(0.07, 0.073, 0.082))
		clamp_node.draw_rect(Rect2(x - 7, top + 10, 14, 9.0 * M - top - 10), ink, false, 1.2)
		for yy in range(int(top + 22), int(9.0 * M), 18):
			clamp_node.draw_line(Vector2(x - 7, yy), Vector2(x + 7, yy + 9), Pal.ink(0.12), 1.0)
		var open := k * 9.0
		clamp_node.draw_polyline(PackedVector2Array([Vector2(x - 16 - open, top + 2), Vector2(x - 16 - open, top + 12), Vector2(x + 16 + open, top + 12), Vector2(x + 16 + open, top + 2)]), Pal.ink(0.75), 2.0, true)
		clamp_node.draw_string(font, Vector2(x + 12, top + 34), "CL-0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.4))


func tug_pos() -> Vector2:
	if game == null or game.state != "intro":
		return Vector2.INF
	var tt: float = game.state_t
	var x: float = world.position.x + stern.x * Geom.M
	if tt > 3.4:
		x += pow(tt - 3.4, 2.0) * 900.0
	return Vector2(x, stern.y * Geom.M)


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


# ---------------------------------------------------------------- the recovery mouths
# Three mouths, three looks, one way of reading them: the colour says what it
# takes (white: whole equipment, heat: scrap, green: hazards), the sign beside
# it says it in words with an icon, the lamp on the sign says whether it is
# ready, taking something in, or has just refused something, and while the
# drone carries something a mouth wants, that mouth's catch zone lights up.

static func zone_col(id: String, a: float = 1.0, k: float = 1.0) -> Color:
	match id:
		"metal": return Pal.heat(a, k)
		"hazard": return Pal.tint(Pal.FLUID, a, k)
	return Pal.ink(a, k)


# what the drone is carrying belongs in this mouth
func _wanted(id: String) -> bool:
	var b = game.tools.held_body
	if b == null or not is_instance_valid(b) or game.hud == null:
		return false
	return game.hud._zone_for(b) == id


func _mouth(id: String) -> void:
	var M := Geom.M
	var z: Dictionary = ZONES[id]
	var st: Dictionary = zone_state[id]
	var c: Vector2 = zpos(id)
	var f: Vector2 = z.face                 # from the mouth out into the berth
	var side := Vector2(-f.y, f.x)
	var hw: float = z.w * 0.5 * M
	var depth := 1.7 * M
	var col := zone_col(id, 0.85)
	if st.reject > 0.0:
		col = col.lerp(Pal.heat(1.0, 1.5), st.reject)
	var want := _wanted(id)
	# the catch zone, while the drone carries something for this mouth
	if want:
		var reach: float = (SCRAP_FIELD if id == "metal" else FIELD) * M
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		draw_circle(c, reach, zone_col(id, 0.035 + 0.025 * pulse))
		var n := 48
		for i in n:
			if i % 2 == 0:
				draw_arc(c, reach, TAU * i / n + t * 0.2, TAU * (i + 1) / n + t * 0.2, 4, zone_col(id, 0.55), 2.0, true)
	# the housing: a funnel from a wide lip down to a narrow throat
	var lip := hw + 26.0
	var throat_w := hw * 0.55
	var hous := PackedVector2Array([c + side * lip, c - side * lip, c - side * throat_w - f * depth, c + side * throat_w - f * depth])
	draw_colored_polygon(hous, Color(0.05, 0.053, 0.06))
	# depth: bands that get darker toward the throat
	for i in 5:
		var e := (i + 1) / 6.0
		var wl := lerpf(lip, throat_w, e)
		draw_line(c + side * wl - f * depth * e, c - side * wl - f * depth * e, zone_col(id, 0.05 + 0.1 * st.glow + 0.25 * st.eat * (1.0 - e)), 1.0)
	var outline := hous.duplicate()
	outline.append(hous[0])
	draw_polyline(outline, col, 2.0, true)
	# the lip: a heavy rim with lamps that chase inward while it takes something in
	draw_line(c + side * (lip + 8), c - side * (lip + 8), col, 4.0)
	var lamps := 7
	for i in lamps:
		var u := (i + 0.5) / lamps * 2.0 - 1.0
		var p := c + side * u * lip + f * 4.0
		var on := 0.25
		if st.eat > 0.0 or st.glow > 0.0:
			on = 0.35 + 0.65 * maxf(0.0, sin(t * 10.0 - absf(u) * 4.0))
		elif want:
			on = 0.4 + 0.4 * sin(t * 4.0)
		draw_circle(p, 2.6, zone_col(id, on, 1.3))
	match id:
		"equip":
			# padded cradle arms either side, guide rails down the throat
			for s in [-1.0, 1.0]:
				var a0: Vector2 = c + side * s * (lip + 4.0)
				var a1: Vector2 = a0 + f * 26.0 - side * s * 10.0
				draw_line(a0, a1, col, 3.0, true)
				draw_circle(a1, 5.0, Color(0.05, 0.053, 0.06))
				draw_arc(a1, 5.0, 0.0, TAU, 14, col, 1.6, true)
				draw_line(c + side * s * hw * 0.5, c + side * s * throat_w * 0.6 - f * depth * 0.9, Pal.ink(0.25), 1.2)
		"metal":
			# a grate across the throat, glowing with what melts below
			var gy := c - f * depth * 0.62
			var gw := lerpf(lip, throat_w, 0.62)
			for i in 7:
				var u2 := (i + 0.5) / 7.0 * 2.0 - 1.0
				draw_line(gy + side * u2 * gw - f * 6.0, gy + side * u2 * gw + f * 6.0, Pal.heat(0.6 + 0.3 * sin(t * 3.0 + i), 1.3), 2.0)
			draw_line(gy + side * gw, gy - side * gw, Pal.heat(0.5, 1.2), 1.4)
		"hazard":
			# hazard stripes along the lip, and two doors that slide apart when it opens
			var open: float = clampf(maxf(st.glow, st.eat) + (0.6 if want else 0.0), 0.0, 1.0)
			for i in 10:
				var u3 := float(i) / 10.0 * 2.0 - 1.0
				var p0 := c + side * u3 * lip - f * 6.0
				draw_line(p0, p0 + side * 10.0 - f * 8.0, Pal.tint(Pal.FLUID, 0.5, 1.0), 3.0)
			for s in [-1.0, 1.0]:
				var dw: float = lip * (1.0 - open) * 0.95
				var d0: Vector2 = c - f * 16.0 + side * s * lip
				draw_line(d0, d0 - side * s * dw, Pal.tint(Pal.FLUID, 0.75, 1.0), 4.0)
	_sign(id, c, f, side, lip, st)


# the sign beside a mouth: an icon, the name, what goes in, and a status lamp
func _sign(id: String, c: Vector2, f: Vector2, side: Vector2, lip: float, st: Dictionary) -> void:
	var sz := Vector2(262, 66)
	# beside the mouth, on the side with room (the hazard bay is at the berth's end)
	# the hazard bay sits at the berth's end: its sign goes straight above it
	var above := id == "hazard"
	var at: Vector2 = (c + Vector2(-sz.x * 0.5, -2.3 * Geom.M - sz.y)) if above else (c + Vector2(lip + 40.0, -sz.y * 0.5) + f * 1.2 * Geom.M)
	var r := Rect2(at, sz)
	draw_rect(r, Color(0.035, 0.037, 0.042, 0.94))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), zone_col(id, 0.95, 1.1))
	draw_rect(r, zone_col(id, 0.35), false, 1.0)
	if above:
		draw_line(Vector2(r.get_center().x, r.end.y), c - Vector2(0, 26), zone_col(id, 0.35), 1.0)
	else:
		draw_line(Vector2(r.position.x, r.get_center().y), c + Vector2(lip + 8.0, 0), zone_col(id, 0.35), 1.0)
	_icon(id, r.position + Vector2(30, 33))
	draw_string(font_b, r.position + Vector2(58, 28), game.txt("zone_" + id), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.95))
	draw_string(font, r.position + Vector2(58, 50), game.txt("zone_" + id + "_d"), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 66, 13, Pal.ink(0.6))
	# status
	var key := "dk_ready"
	var lc := Pal.tint(Pal.FLUID, 0.9, 1.3)
	if st.reject > 0.0:
		key = "dk_refused"
		lc = Pal.heat(0.6 + 0.4 * sin(t * 18.0), 1.5)
	elif st.eat > 0.0 or st.busy > 0.0:
		key = "dk_taking"
		lc = Pal.ink(0.6 + 0.4 * sin(t * 12.0), 1.4)
	var sw := font.get_string_size(game.txt(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_circle(Vector2(r.end.x - 14, r.position.y + 14), 4.0, lc)
	draw_string(font, Vector2(r.end.x - 24 - sw, r.position.y + 18), game.txt(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.6))


func _icon(id: String, p: Vector2) -> void:
	var col := zone_col(id, 0.95, 1.2)
	match id:
		"equip":
			# a crate with a check
			draw_rect(Rect2(p - Vector2(13, 11), Vector2(26, 22)), col, false, 1.8)
			draw_polyline(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(-1, 5), p + Vector2(7, -5)]), col, 2.0, true)
		"metal":
			# a flame over a hopper
			draw_polyline(PackedVector2Array([p + Vector2(-12, 4), p + Vector2(-6, 13), p + Vector2(6, 13), p + Vector2(12, 4)]), col, 1.8, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(7, -2), p + Vector2(3, 4), p + Vector2(-3, 4), p + Vector2(-7, -2)]), col)
		"hazard":
			# a warning diamond
			draw_polyline(PackedVector2Array([p + Vector2(0, -14), p + Vector2(14, 0), p + Vector2(0, 14), p + Vector2(-14, 0), p + Vector2(0, -14)]), col, 1.8, true)
			draw_line(p + Vector2(0, -6), p + Vector2(0, 3), col, 2.4)
			draw_circle(p + Vector2(0, 8), 1.8, col)


# the scrap trough: a recessed channel along the floor, a belt of slats running
# toward the furnace, arrows on the rail; lit along its length while scrap is carried
func _trough_live() -> void:
	var M := Geom.M
	var mx: float = zpos("metal").x
	var y0 := TROUGH_Y * M
	var y1 := FLOOR_Y * M
	var x0 := TROUGH_X0 * M
	var x1 := TROUGH_X1 * M
	var want := _wanted("metal")
	if want:
		draw_rect(Rect2(x0, y0 - 6, x1 - x0, 6), Pal.heat(0.12 + 0.08 * sin(t * 4.0), 1.2))
	var ph := fposmod(t * CONVEY * M, 24.0)
	var x := x0 + 6.0
	while x < x1 - 6.0:
		var px := x + (ph if x < mx else -ph)
		if px > x0 + 2.0 and px < x1 - 2.0 and absf(px - mx) > 1.4 * M:
			draw_line(Vector2(px, y0 + 8), Vector2(px, y1 - 6), Pal.ink(0.16), 2.0)
		x += 24.0
	# arrows on the rail, every few metres, pointing to the furnace
	var ax := x0 + 1.5 * M
	while ax < x1 - 1.0 * M:
		if absf(ax - mx) > 2.6 * M:
			var d := 1.0 if ax < mx else -1.0
			var ay := y0 + 4.0
			draw_polyline(PackedVector2Array([Vector2(ax - 5.0 * d, ay - 5), Vector2(ax + 3.0 * d, ay), Vector2(ax - 5.0 * d, ay + 5)]), Pal.heat(0.55 if want else 0.3, 1.2), 1.6, true)
		ax += 3.0 * M


# a plated girder: a lit top edge, a shadowed bottom, posts and diagonals, rivets at the nodes
func _truss(r: Rect2) -> void:
	var ci := static_node
	ci.draw_rect(r, Color(0.052, 0.055, 0.062))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.22)), Color(0.075, 0.079, 0.088))
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - r.size.y * 0.18), Vector2(r.size.x, r.size.y * 0.18)), Color(0.04, 0.042, 0.048))
	var x := r.position.x
	var k := 0
	while x < r.end.x:
		var nx := minf(x + r.size.y, r.end.x)
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Pal.ink(0.12), 1.0)
		if k % 2 == 0:
			ci.draw_line(Vector2(x, r.position.y), Vector2(nx, r.end.y), Pal.ink(0.16), 1.2)
		else:
			ci.draw_line(Vector2(x, r.end.y), Vector2(nx, r.position.y), Pal.ink(0.16), 1.2)
		ci.draw_circle(Vector2(x, r.position.y + 3), 1.4, Pal.ink(0.35))
		ci.draw_circle(Vector2(x, r.end.y - 3), 1.4, Pal.ink(0.25))
		x = nx
		k += 1
	ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Pal.ink(0.6), 1.6)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Pal.ink(0.28), 1.2)


func _truss_v(r: Rect2) -> void:
	var ci := static_node
	ci.draw_rect(r, Color(0.052, 0.055, 0.062))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.22, r.size.y)), Color(0.075, 0.079, 0.088))
	var y := r.position.y
	var k := 0
	while y < r.end.y:
		var ny := minf(y + r.size.x, r.end.y)
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Pal.ink(0.12), 1.0)
		if k % 2 == 0:
			ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, ny), Pal.ink(0.16), 1.2)
		else:
			ci.draw_line(Vector2(r.end.x, y), Vector2(r.position.x, ny), Pal.ink(0.16), 1.2)
		ci.draw_circle(Vector2(r.position.x + 3, y), 1.4, Pal.ink(0.35))
		y = ny
		k += 1
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Pal.ink(0.6), 1.6)
	ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Pal.ink(0.28), 1.2)


# diagonal warning stripes over a band (heat on dark)
func _stripes(r: Rect2, a: float = 0.55) -> void:
	var ci := static_node
	ci.draw_rect(r, Color(0.03, 0.03, 0.03))
	var x := r.position.x - r.size.y
	var i := 0
	while x < r.end.x:
		if i % 2 == 0:
			var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), Vector2(x + r.size.y + 10, r.position.y), Vector2(x + 10, r.end.y)])
			for j in pts.size():
				pts[j] = Vector2(clampf(pts[j].x, r.position.x, r.end.x), pts[j].y)
			ci.draw_colored_polygon(pts, Pal.heat(a, 1.0))
		x += 10
		i += 1


func _draw_trough(ci: CanvasItem) -> void:
	var M := Geom.M
	var mx: float = zpos("metal").x
	var y := (TROUGH_Y + 0.4) * M
	var x := TROUGH_X0 * M + 20.0
	var ph := fposmod(t * CONVEY * M * 0.25, 40.0)
	while x < TROUGH_X1 * M - 10.0:
		var px := x + (ph if x < mx else -ph)
		var dirx := 1.0 if px < mx else -1.0
		if absf(px - mx) > 30.0:
			ci.draw_line(Vector2(px - 5.0 * dirx, y - 6), Vector2(px + 3.0 * dirx, y), Pal.heat(0.25, 1.2), 1.4)
			ci.draw_line(Vector2(px + 3.0 * dirx, y), Vector2(px - 5.0 * dirx, y + 6), Pal.heat(0.25, 1.2), 1.4)
		x += 40.0


const FLOODS := [9.5, 19.0]      # m along the boom: lamps that light the ship from above


func _draw_lights() -> void:
	var M := Geom.M
	var tex: Texture2D = game.fx.glow_tex
	# floodlights: a soft cone down onto the ship, a bright head on the boom
	for fx_ in FLOODS:
		var hp := Vector2(fx_, -9.9) * M
		# the cone fades out downwards (bright at the lamp, nothing by the hull's far side)
		var cone := PackedVector2Array([hp + Vector2(-10, 0), hp + Vector2(10, 0), hp + Vector2(3.2 * M, 8.0 * M), hp + Vector2(-3.2 * M, 8.0 * M)])
		var cc := PackedColorArray([Pal.ink(0.045, 1.2), Pal.ink(0.045, 1.2), Pal.ink(0.0), Pal.ink(0.0)])
		add_node.draw_polygon(cone, cc)
		add_node.draw_texture_rect(tex, Rect2(hp - Vector2(26, 14), Vector2(52, 28)), false, Pal.ink(0.5, 1.6))
		add_node.draw_circle(hp, 3.0, Pal.ink(0.95, 2.0))
	# marker lights along the deck edge and under the boom, chasing slowly toward the furnace
	var mx: float = zpos("metal").x / M
	var x := TOWER_X + 1.0
	while x < FLOOR_X1 - 0.5:
		var ph := fposmod(t * 0.8 - absf(x - mx) * 0.08, 1.0)
		var a := 0.15 + 0.55 * pow(1.0 - ph, 6.0)
		add_node.draw_circle(Vector2(x, FLOOR_Y) * M + Vector2(0, -2), 2.2, Pal.heat(a, 1.6))
		x += 2.0
	x = TOWER_X + 1.0
	while x < ARM_X1 - 0.5:
		var a2 := 0.12 + 0.12 * sin(t * 1.5 + x)
		add_node.draw_circle(Vector2(x, -10.0) * M + Vector2(0, 2), 1.8, Pal.ink(a2, 1.6))
		x += 3.0


func _draw_add() -> void:
	_draw_lights()
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
