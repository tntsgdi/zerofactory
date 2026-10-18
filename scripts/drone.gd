class_name Drone
extends RigidBody2D
# R-02, the dock's remote salvage drone. Thrusters on four sides, real vacuum
# inertia: let go of the keys and it keeps drifting until you burn the other
# way (Space burns every nozzle against the drift). Shift is a hard burn.

const R := 20.0
const ACCEL := 360.0
const VMAX := 430.0
const DASH_K := 2.3
const DASH_VMAX := 780.0
const BRAKE_K := 2.6          # braking beats letting go (the assist stops at ~2.3 x ACCEL)

var game: Game
var heading := 0.0
var aim := Vector2.ZERO
var thrust := Vector2.ZERO        # current commanded acceleration direction (world, 0..1+)
var flame := [0.0, 0.0, 0.0, 0.0] # +x -x +y -y nozzle intensity (smoothed)
var integrity := 100.0
var alive := true
var dashing := false
var braking := false
var trail: Array = []
# the airframe (UI animation, 2026-10-17: H1 arrow-ring, scripts/drone_art.gd)
const Art = preload("res://scripts/drone_art.gd")
const DESIGN := "arrowring"
const BOOT_T := 1.1           # s: the launch draw-on
const OPEN_T := 0.25          # s: a tool's transform
var tool_shown := 0
var tool_open := 1.0
var art_t := 0.0
var _booted := false
var hit_imp := 0.0
var hit_pos := Vector2.ZERO
var hurt_t := 0.0
var spawn_t := 0.0
var add_node: Node2D
var smoke_t := 0.0
var input := {"move": Vector2.ZERO, "dash": false, "brake": false, "hold": false}
var hold_at := Vector2.INF   # where the drone is held while the hold key is down
var external := Vector2.ZERO
# a heavy load on a taut tether holds the drone back (set by the grapple each
# step): it can't fly away from the load much faster than the load follows
var tow_k := 0.0
var tow_u := Vector2.ZERO
var tow_v := 0.0
var assist := true             # flight assist: holds position, kills side drift
var assist_k := 1.0            # 0..1 for the HUD switch animation


func _init() -> void:
	mass = 0.6
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = 2
	collision_mask = 1 | 4 | World.STATIC_LAYER
	z_index = 6
	z_as_relative = false
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.2
	physics_material_override = pm
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = R
	cs.shape = sh
	add_child(cs)
	add_node = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_node.material = m
	add_node.z_index = 1
	add_node.draw.connect(_draw_add)
	add_child(add_node)


func muzzle() -> Vector2:
	return global_position + Vector2.from_angle(heading) * (R + 2.0)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	for i in state.get_contact_count():
		var imp := state.get_contact_impulse(i).length()
		if imp > hit_imp:
			hit_imp = imp
			hit_pos = state.get_contact_local_position(i)


func _physics_process(dt: float) -> void:
	if not alive:
		return
	var mv: Vector2 = input.move
	dashing = input.dash and mv.length() > 0.1
	braking = input.brake
	# out of the launch tube it bleeds its speed off by itself, unless you take over
	if spawn_t > 0.3 and spawn_t < 1.6 and mv.length() < 0.05:
		braking = true
	var acc := Vector2.ZERO
	var drive := game.skill_value("drive") if game != null else 1.0
	var accel := ACCEL * drive
	var vmax := (DASH_VMAX if dashing else VMAX) * drive
	if mv.length() > 0.05:
		var dir := mv.normalized()
		acc = dir * accel * (DASH_K if dashing else 1.0)
		# no more push along the drift once at top speed
		var along := linear_velocity.dot(dir)
		if along > vmax:
			acc = Vector2.ZERO
	if assist and not braking:
		# fly-by-wire: steer the velocity toward what the keys ask for
		var v_des := mv.normalized() * vmax if mv.length() > 0.05 else Vector2.ZERO
		var cap := accel * (DASH_K + 0.4 if dashing else 2.3)
		acc = ((v_des - linear_velocity) * 9.0).limit_length(cap)
		if mv.length() < 0.05 and linear_velocity.length() < 6.0 and external.length() < 1.0:
			linear_velocity = Vector2.ZERO
			acc = Vector2.ZERO
	if braking:
		var v := linear_velocity
		if v.length() > 4.0:
			acc = -v.normalized() * accel * BRAKE_K
			if v.length() < accel * BRAKE_K * dt:
				acc = -v / dt
		else:
			linear_velocity = Vector2.ZERO
			acc = Vector2.ZERO
	# hold: stay put where the key went down, whatever pulls (the tether included)
	if input.get("hold", false):
		if hold_at == Vector2.INF:
			hold_at = global_position
		acc = ((hold_at - global_position) * 40.0 - linear_velocity * 12.0 - external / mass).limit_length(accel * BRAKE_K * 2.0)
	else:
		hold_at = Vector2.INF
	if tow_k > 0.0:
		var away := acc.dot(tow_u)
		if away > 0.0:
			acc -= tow_u * away * tow_k * 0.6
		var lead := linear_velocity.dot(tow_u) - tow_v
		if lead > 0.0:
			acc -= tow_u * minf(lead * 12.0, accel * 3.0) * tow_k
	thrust = acc / ACCEL
	apply_central_force(acc * mass)
	if external != Vector2.ZERO:
		apply_central_force(external)
		external = Vector2.ZERO
	# impacts
	var dv := hit_imp / mass
	if dv > 175.0 and spawn_t > 1.0:
		game.on_drone_impact(hit_pos, dv)
	hit_imp = 0.0


func _process(dt: float) -> void:
	spawn_t += dt
	hurt_t = maxf(0.0, hurt_t - dt)
	var want := (aim - global_position).angle() if aim.distance_to(global_position) > 4.0 else heading
	heading = lerp_angle(heading, want, 1.0 - exp(-14.0 * dt))
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for i in 4:
		var target := maxf(0.0, -thrust.dot(dirs[i]))
		flame[i] = Pal.damp(flame[i], target, 22.0, dt)
	art_t += dt
	var fx = game.fx
	var lvl := Txt.anim_level()
	# a new tool: the airframe changes over to it
	var tl: int = game.tools.tool if game.tools != null else 0
	if tl != tool_shown:
		tool_shown = tl
		tool_open = 0.0
		if alive and lvl >= 2 and spawn_t > BOOT_T:
			fx.ring(global_position + Vector2(28, 0).rotated(heading), 3.0, 30.0, 0.28, Art.tool_col(tl, 0.7, 1.8), 1.4)
	tool_open = 1.0 if lvl == 0 else move_toward(tool_open, 1.0, dt / OPEN_T)
	# out of the launch: one pulse as it comes fully alive
	if alive and not _booted and spawn_t >= BOOT_T:
		_booted = true
		if lvl >= 1:
			fx.ring(global_position, 8.0, 70.0, 0.45, Pal.ink(0.6, 1.6), 1.6)
	if spawn_t < 0.05:
		_booted = false
	if alive and lvl >= 1:
		for jet in Art.arrowring_jets(art_state()):
			var f: float = jet[2]
			if f > 0.3 and randf() < f * (0.6 if lvl >= 2 else 0.25):
				var d: Vector2 = jet[1]
				fx.puff(global_position + jet[0] + d * 3.0, d * randf_range(90, 160) * f + linear_velocity * 0.5, randf_range(0.18, 0.32), 2.5, 8.0 * f, Pal.heat(0.12, 1.0))
		if dashing:
			trail.push_front(global_position)
		else:
			trail.push_front(global_position)
			if trail.size() > 1:
				trail.pop_back()
		while trail.size() > 9:
			trail.pop_back()
		if integrity < 45.0:
			smoke_t -= dt
			if smoke_t <= 0.0:
				smoke_t = 0.05 + integrity / 400.0
				fx.puff(global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2(randf_range(-20, 20), randf_range(-30, -10)) + linear_velocity * 0.3, 0.9, 4.0, 14.0, Pal.ink(0.07))
				if randf() < 0.3:
					fx.sparks(global_position, Vector2.from_angle(randf() * TAU), 2, Pal.heat(0.8, 1.6), 120.0, 0.25)
	queue_redraw()
	add_node.queue_redraw()


func hurt(amount: float, from: Vector2) -> void:
	if not alive:
		return
	integrity -= amount
	hurt_t = 0.35
	var d := (global_position - from).normalized() if from.distance_to(global_position) > 1.0 else Vector2.UP
	apply_central_impulse(d * 160.0 * mass * minf(1.0, amount / 25.0))
	game.fx.sparks(global_position, d, 10, Pal.heat(0.9, 2.0), 260.0, 0.35, 1.4)
	if integrity <= 0.0:
		integrity = 0.0
		alive = false
		game.on_drone_destroyed()


func _draw() -> void:
	if not alive:
		return
	var lvl := Txt.anim_level()
	# afterimages while burning hard: the hull's ghost along the trail
	if lvl >= 2:
		for i in range(trail.size() - 1, 0, -1):
			var p: Vector2 = trail[i] - global_position
			var k := 1.0 - float(i) / trail.size()
			draw_set_transform(p, heading, Vector2.ONE * (0.8 + 0.2 * k))
			draw_colored_polygon(PackedVector2Array(Art.ARROW), Pal.ink(0.035 * k))
		draw_set_transform(Vector2.ZERO)
	Art.draw(self, DESIGN, art_state())
	# hit: the hull flashes in heat
	if hurt_t > 0.0:
		var flash := hurt_t / 0.35
		var hull := Art.rot(Art.ARROW, heading)
		Art.outline(self, hull, Pal.heat(flash, 1.8), 2.4)
	if game != null:
		# fitted upgrades show on the airframe: armour as plates round the hull,
		# shield arcs ahead, drive ticks at the tail
		var kit: Dictionary = game.job.get("kit", {})
		var armor := Growth.level(kit, "armor")
		for i in armor:
			var hull := Art.rot(Art.ARROW, heading, 1.18 + i * 0.12)
			Art.outline(self, hull, Pal.ink(0.22), 1.0)
		var shield := Growth.level(kit, "shield")
		for i in shield:
			draw_arc(Vector2.ZERO, 33.0 + i * 4, heading - 0.6, heading + 0.6, 20, Pal.ink(0.6), 1.0, true)
		var drive := Growth.level(kit, "drive")
		for i in drive:
			var tail := Vector2(-19 - i * 3, 0).rotated(heading)
			var n := Vector2(0, 5).rotated(heading)
			draw_line(tail - n, tail + n, Pal.ink(0.8), 1.6)
		if game.has_upgrade("grapple5"):
			draw_arc(Vector2(-2, 0).rotated(heading), 11.5, 0.0, TAU, 28, Pal.ink(0.5), 1.2, true)
	# integrity tick ring
	if integrity < 100.0:
		draw_arc(Vector2.ZERO, R + 9.0, -PI / 2.0, -PI / 2.0 + TAU * integrity / 100.0, 40, Pal.ink(0.35) if integrity > 35.0 else Pal.heat(0.8, 1.2), 1.6, true)


# what the airframe drawing needs this frame
func art_state() -> Dictionary:
	return {"heading": heading, "tool": tool_shown, "open": tool_open, "t": art_t, "thrust": thrust, "dash": dashing,
		"boot": boot(), "design": DESIGN, "base_xf": Transform2D.IDENTITY}


# the launch: the airframe draws itself on over its first second out
func boot() -> float:
	if Txt.anim_level() == 0:
		return 1.0
	return clampf(spawn_t / BOOT_T, 0.0, 1.0)


func _draw_add() -> void:
	if not alive or Txt.anim_level() == 0:
		return
	var tex: Texture2D = game.fx.glow_tex
	# the core glows in the tool's colour
	var core := Vector2(-2, 0).rotated(heading)
	var col := Art.tool_col(tool_shown, 0.3 + 0.25 * tool_open, 1.2)
	add_node.draw_texture_rect(tex, Rect2(core - Vector2(12, 12), Vector2(24, 24)), false, col)
