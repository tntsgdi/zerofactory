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
			acc -= tow_u * away * tow_k
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
	var fx = game.fx
	if alive:
		for i in 4:
			if flame[i] > 0.3 and randf() < flame[i] * 0.6:
				var d: Vector2 = dirs[i]
				var o: Vector2 = global_position + d * (R + 3.0)
				fx.puff(o, d * randf_range(90, 160) * flame[i] + linear_velocity * 0.5, randf_range(0.18, 0.32), 3.0, 9.0 * flame[i], Pal.heat(0.12, 1.0))
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
	# afterimages while burning hard
	for i in range(trail.size() - 1, 0, -1):
		var p: Vector2 = trail[i] - global_position
		var k := 1.0 - float(i) / trail.size()
		draw_circle(p, R * (0.55 + 0.4 * k), Pal.ink(0.05 * k))
	# body: a rounded hexagon
	var hexp := PackedVector2Array()
	for i in 8:
		hexp.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * R)
	draw_colored_polygon(hexp, Color(0.07, 0.074, 0.084))
	var flash := hurt_t / 0.35
	var ring_c := Pal.ink(0.95).lerp(Pal.heat(1.0, 1.8), flash)
	var closed := hexp.duplicate()
	closed.append(hexp[0])
	draw_polyline(closed, ring_c, 1.8, true)
	# four nozzle pods
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d in dirs:
		var c: Vector2 = d * (R - 1.0)
		var t := Vector2(-d.y, d.x)
		draw_line(c + t * 5.0, c - t * 5.0, Pal.ink(0.8), 3.0)
	# fitted upgrades show on the airframe
	if game != null and game.has_upgrade("grapple5"):
		# the bigger tractor emitter: a heavy ring round the lens and two coil blocks
		draw_arc(Vector2.ZERO, 12.5, 0.0, TAU, 28, Pal.ink(0.7), 2.4, true)
		for s in [-1.0, 1.0]:
			var a: float = heading + s * 0.9
			draw_rect(Rect2(Vector2.from_angle(a) * 13.0 - Vector2(3, 3), Vector2(6, 6)), Pal.ink(0.75))
	if game != null and game.has_upgrade("scan_kit"):
		# the precision inspection head: a small dish on a mast
		var up := Vector2(0, -R - 2.0)
		draw_line(Vector2(0, -R + 2.0), up + Vector2(0, -6), Pal.ink(0.7), 1.4)
		draw_arc(up + Vector2(0, -6), 5.0, PI * 1.1, PI * 1.9, 10, Pal.ink(0.85), 1.6, true)
		draw_circle(up + Vector2(0, -9), 1.4, Pal.tint(Pal.AIR, 0.9, 1.4))
	# lens looks where you aim
	var lens := Vector2.from_angle(heading) * 7.0
	draw_circle(Vector2.ZERO, 8.5, Color(0.03, 0.03, 0.035))
	draw_arc(Vector2.ZERO, 8.5, 0.0, TAU, 20, Pal.ink(0.6), 1.0, true)
	draw_circle(lens * 0.5, 3.4, Pal.ink(0.95))
	if game != null:
		var armor := Growth.level(game.job.get("kit", {}), "armor")
		for i in armor:
			draw_rect(Rect2(Vector2(-23 - i * 3, -23 - i * 3), Vector2(46 + i * 6, 46 + i * 6)), Pal.ink(0.55), false, 1.0)
		var shield := Growth.level(game.job.get("kit", {}), "shield")
		for i in shield:
			draw_arc(Vector2.ZERO, 33.0 + i * 4, heading - 0.6, heading + 0.6, 20, Pal.ink(0.6), 1.0, true)
		var drive := Growth.level(game.job.get("kit", {}), "drive")
		for i in drive:
			draw_line(Vector2(-14 + i * 12, -27), Vector2(-14 + i * 12, -34), Pal.ink(0.8), 2.0)
	# integrity tick ring
	if integrity < 100.0:
		draw_arc(Vector2.ZERO, R + 7.0, -PI / 2.0, -PI / 2.0 + TAU * integrity / 100.0, 40, Pal.ink(0.35) if integrity > 35.0 else Pal.heat(0.8, 1.2), 1.6, true)


func _draw_add() -> void:
	if not alive:
		return
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var tex: Texture2D = game.fx.glow_tex
	var t := Time.get_ticks_msec() / 1000.0
	for i in 4:
		var f: float = flame[i]
		if f < 0.04:
			continue
		var d: Vector2 = dirs[i]
		var nrm := Vector2(-d.y, d.x)
		var base: Vector2 = d * (R + 1.0)
		var flick := 0.85 + 0.15 * sin(t * 61.0 + i * 1.7) + randf() * 0.1
		var ln := (14.0 + 22.0 * f) * flick * (1.6 if dashing else 1.0)
		var tip := base + d * ln
		var cone := PackedVector2Array([base + nrm * 5.0, tip, base - nrm * 5.0])
		add_node.draw_colored_polygon(cone, Pal.heat(0.55 * f, 1.6))
		var core := PackedVector2Array([base + nrm * 2.4, base + d * ln * 0.55, base - nrm * 2.4])
		add_node.draw_colored_polygon(core, Color(1.6, 1.3, 1.0, 0.8 * f))
		add_node.draw_texture_rect(tex, Rect2(base + d * 6.0 - Vector2(16, 16), Vector2(32, 32)), false, Pal.heat(0.35 * f, 1.4))
	# the lens glows faintly
	add_node.draw_texture_rect(tex, Rect2(Vector2.from_angle(heading) * 3.5 - Vector2(9, 9), Vector2(18, 18)), false, Pal.ink(0.35, 1.2))
