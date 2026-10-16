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
var _last := Vector2.INF     # where the body was last physics step
var cols := {}              # piece id -> Array of CollisionPolygon2D
var age := 0.0
var rejected_t := 0.0


func _init() -> void:
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
	collision_mask = 1 | 2 | 4
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
			c.queue_free()
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
			c.queue_free()
		cols.erase(p.id)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# a light piece squeezed between something heavy and the hull can be pushed
	# right through it: if the body's centre crossed the attached ship since
	# the last step, put it back and bounce it off
	var here: Vector2 = state.transform.origin
	# only motion the physics made (speed, or the solver pushing overlaps
	# apart): a teleport (a load, a test placing it) jumps metres at once
	var moved := _last.distance_to(here) if _last != Vector2.INF else 0.0
	var could := maxf(state.linear_velocity.length() * state.step * 2.0, TELEPORT)
	if capture == null and moved > 0.5 and moved < could:
		var q := PhysicsRayQueryParameters2D.create(_last, here, World.STATIC_LAYER)
		var hit: Dictionary = state.get_space_state().intersect_ray(q)
		if not hit.is_empty():
			var xf := state.transform
			xf.origin = _last
			state.transform = xf
			state.linear_velocity = state.linear_velocity.bounce(hit.normal) * 0.4
			state.angular_velocity *= 0.5
			return
	_last = here
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
