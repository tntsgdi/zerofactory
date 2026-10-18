class_name FreeBody
extends RigidBody2D
# A group of pieces that has lost every connection to the dock and now drifts
# in vacuum. Collision comes from one polygon per piece; drawing happens in
# body-local space, so the canvas item is only rebuilt when the pieces change.

var world: World
var pieces: Array = []
var view: Node2D
var heat_view: Node2D
var hit_imp := 0.0
var hit_pos := Vector2.ZERO
var prev_v := Vector2.ZERO
var tethered := false
var capture = null          # recovery zone that is swallowing this body
var capture_t := 0.0
const INSET := 1.0            # px: collision sits this far inside the outline
const MAX_SPEED := 900.0      # px/s for anything loose
const MAX_SPIN := 6.0         # rad/s
const TELEPORT := 72.0        # px in one step: more than this was placed, not moved
var _safe_transform := Transform2D.IDENTITY
var _has_safe_transform := false
var _last := Vector2.INF     # where the body was last physics step
static var guard_hits := 0   # how often the tunnel check put a body back (tests read it)
# A piece that comes loose overlapping its neighbours (shapes that touch or
# cross in the ship data) was flung off at full speed by the solver pushing the
# overlap apart. Born overlapping, it eases out instead for a moment.
const CALM_T := 0.5           # s
const CALM_SPEED := 60.0      # px/s
var calm := 0.0
# what a loose body collides with: other loose bodies (1), the drone (2), the
# berth's edges (4) and the attached ship (8)
const MASK := 1 | 2 | 4 | 8
# Born overlapping the attached ship, a body slides out without colliding with
# it (the solver used to shove it out in one jump) and touches it again once it
# is clear, or after GHOST_T at the latest.
const GHOST_T := 1.5
const GHOST_SPEED := 40.0     # px/s, out of the overlap
var ghost := 0.0
var ghost_dir := Vector2.ZERO
var _ghost_check := 0.0

var cols := {}              # piece id -> Array of CollisionPolygon2D
var age := 0.0
var rejected_t := 0.0


func _init() -> void:
	process_physics_priority = -1
	gravity_scale = 0.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.02
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = 1
	collision_mask = MASK
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	z_index = 3
	z_as_relative = false
	view = Node2D.new()
	view.draw.connect(_draw_view)
	add_child(view)
	heat_view = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	heat_view.material = m
	heat_view.z_index = 1
	heat_view.draw.connect(_draw_heat)
	add_child(heat_view)


func total_mass() -> float:
	var s := 0.0
	for p in pieces:
		s += p.mass + world.content_mass(p)
	return s


func refresh() -> void:
	var m := 0.0
	var com := Vector2.ZERO
	for p in pieces:
		var pm: float = maxf(0.01, p.mass + world.content_mass(p))
		m += pm
		com += Geom.centroid(p.poly) * pm
	if m <= 0.0:
		return
	mass = maxf(0.02, m)
	center_of_mass = com / m
	inertia = 0.0
	view.queue_redraw()


func rebuild_cols(p) -> void:
	if cols.has(p.id):
		for c in cols[p.id]:
			World.free_shape(c)
	cols.erase(p.id)
	if p.gone or p.body != self:
		return
	var arr: Array = []
	var poly := Geom.simplify(p.poly, 1.4)
	if Geom.area(poly) < 20.0 or not Geom.valid(poly):
		poly = p.poly
	# a hair inside the drawn outline: a piece that comes loose was touching its
	# neighbours, and shapes that start in contact slip past continuous
	# collision (a light box could be knocked straight through a bulkhead)
	var inset := Geometry2D.offset_polygon(poly, -INSET)
	if inset.size() == 1 and Geom.area(inset[0]) >= 20.0 and Geom.valid(inset[0]):
		poly = inset[0]
	if Geom.area(poly) >= 20.0 and Geom.valid(poly):
		var c := CollisionPolygon2D.new()
		c.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		c.polygon = poly
		add_child(c)
		arr.append(c)
	cols[p.id] = arr


func drop_piece(p) -> void:
	pieces.erase(p)
	if cols.has(p.id):
		for c in cols[p.id]:
			World.free_shape(c)
		cols.erase(p.id)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# The overlap solver can produce a non-finite state for a newly freed shard.
	# Restore its last valid pose before it propagates into tractor forces, FX,
	# or the camera. Finite states retain the original integration unchanged.
	var pose := state.transform
	if not pose.origin.is_finite() or not pose.x.is_finite() or not pose.y.is_finite() or not state.linear_velocity.is_finite() or not is_finite(state.angular_velocity):
		state.transform = _safe_transform if _has_safe_transform else Transform2D(0.0, _last if _last.is_finite() else Vector2.ZERO)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		hit_imp = 0.0
		return
	_safe_transform = pose
	_has_safe_transform = true
	# a light piece squeezed between something heavy and the hull can be pushed
	# right through it: if the body's centre crossed the attached ship since
	# the last step, put it back and bounce it off
	var here: Vector2 = state.transform.origin
	# only motion the physics made (speed, or the solver pushing overlaps
	# apart): a teleport (a load, a test placing it) jumps metres at once
	var moved := _last.distance_to(here) if _last != Vector2.INF else 0.0
	var could := maxf(state.linear_velocity.length() * state.step * 2.0, TELEPORT)
	# A body born overlapping (calm) is meant to ease out of what it overlaps:
	# putting it back would only make it judder in place.
	if capture == null and calm <= 0.0 and moved > 2.0 and moved < could:
		var q := PhysicsRayQueryParameters2D.create(_last, here, World.STATIC_LAYER)
		var hit: Dictionary = state.get_space_state().intersect_ray(q)
		if not hit.is_empty():
			var xf := state.transform
			xf.origin = _last
			state.transform = xf
			guard_hits += 1
			state.linear_velocity = state.linear_velocity.bounce(hit.normal) * 0.4
			state.angular_velocity *= 0.5
			return
	_last = here
	if calm > 0.0:
		calm -= state.step
		if not tethered:
			state.linear_velocity = state.linear_velocity.limit_length(CALM_SPEED)
			state.angular_velocity = clampf(state.angular_velocity, -1.0, 1.0)
	# nothing loose outruns the collision: a hard knock still sends it flying,
	# just not through a wall
	if state.linear_velocity.length() > MAX_SPEED:
		state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
	if absf(state.angular_velocity) > MAX_SPIN:
		state.angular_velocity = clampf(state.angular_velocity, -MAX_SPIN, MAX_SPIN)
	for i in state.get_contact_count():
		var imp := state.get_contact_impulse(i).length()
		if imp > hit_imp:
			hit_imp = imp
			hit_pos = state.get_contact_local_position(i)


func _physics_process(dt: float) -> void:
	_ghost_step(dt)
	# The solver publishes its result before scene physics callbacks. Repair an
	# invalid result before the dock, tools and FX read the body this step.
	var pose := global_transform
	if pose.origin.is_finite() and pose.x.is_finite() and pose.y.is_finite() and linear_velocity.is_finite() and is_finite(angular_velocity):
		return
	global_transform = _safe_transform if _has_safe_transform else Transform2D(0.0, _last if _last.is_finite() else Vector2.ZERO)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	hit_imp = 0.0
	reset_physics_interpolation()


func start_ghost(dir: Vector2) -> void:
	ghost = GHOST_T
	ghost_dir = dir
	collision_mask = MASK & ~World.STATIC_LAYER
	linear_velocity = dir * GHOST_SPEED


func _ghost_step(dt: float) -> void:
	if ghost <= 0.0:
		return
	ghost -= dt
	calm = maxf(calm, 0.1)
	if not tethered and capture == null:
		linear_velocity = ghost_dir * GHOST_SPEED
		angular_velocity = 0.0
	_ghost_check -= dt
	if _ghost_check <= 0.0 or ghost <= 0.0:
		_ghost_check = 0.1
		if ghost <= 0.0 or world.overlap_dir(pieces).is_empty():
			ghost = 0.0
			collision_mask = MASK


func _process(_dt: float) -> void:
	var hot := false
	for p in pieces:
		if not p.heat.is_empty():
			hot = true
			break
	if hot:
		heat_view.queue_redraw()


func _draw_view() -> void:
	world.draw_pieces(view, pieces)
	world.draw_joints_of(view, pieces)


func _draw_heat() -> void:
	for p in pieces:
		world.draw_heat(heat_view, p)
