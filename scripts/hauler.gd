class_name Hauler
extends Node2D
# The basic hauling drone (berth upgrade, design/体验打磨定案.md §6): mark a
# floating piece (the "mark" key with the pointer on it) and it fetches it —
# up to 1.5 t, whatever it is — and lets it go at the mouth it belongs in:
# hazards to the hazard bay, whole equipment to the equipment bay, the rest
# to the furnace. One load at a time, round the ship, slower than you; what
# it delivers is the machine's work, not yours. The 200,000 second drone is
# the advanced version of this.
# With nothing marked it fetches loose plain scrap by itself (whatever the arm
# is not taking). Like the arm it waits its turn over a mouth, holds back for
# the operator's drone, and the automation key stops it (what it holds is let
# go there). A second hauler (roadmap 4.4) is another of these: it works the
# same list of marks and never goes for what the first already has. Neither
# goes into a keep-out zone the operator has set (game.keepout).

const MAX_T := 1.5
# It flies like the operator's drone (player 2026-10-18: "the same rhythm,
# the same inertia"): its top speed and acceleration, slowing for what it
# carries, braking into where it is going; it keeps off the ship's walls on the
# berth's navigation grid (scripts/nav.gd) and eases round loose pieces, the
# other hauler and the operator.
const VMAX := Drone.VMAX * 0.92   # px/s empty
const ACCEL := Drone.ACCEL * 2.0  # px/s² empty (the operator's assisted drone: ~2.3x)
const LOAD_V := 0.62              # top speed with a full 1.5 t load, as a share
const ARRIVE := 10.0              # px: there
const REPLAN := 1.2               # s between fresh paths
const AVOID_R := 1.6 * 48.0       # px: loose pieces and drones nearer than this are eased round
const R := 12.0
const CLEAR := 2.5 * 48.0        # px it keeps from the operator's drone

var game: Game
var who := "hauler"              # its name over a mouth ("hauler", "hauler2")
var home_off := Vector2(0.6, -1.6)
var queue: Array = []            # marked bodies, in order (shared by both haulers)
var body = null
var path: Array = []
var pos := Vector2.ZERO
var state := "idle"              # idle reach carry release
var zone := "metal"
var off := Vector2.ZERO
var hold_t := 0.0
var t := 0.0
var carried := 0
var wait_t := 0.0               # s spent holding back for the drone
# its airframe (2026-10-17): every drone in the berth looks different; drawn
# smaller and in air-blue, turned the way it travels
const Art = preload("res://scripts/drone_art.gd")
var heading := -PI / 2.0
var vel := Vector2.ZERO
var route := PackedVector2Array()
var _goal := Vector2.INF
var _replan_t := 0.0
var _clear := 0.0
var _avoid_skip: Array = []      # bodies it does not ease round (what it goes for, what it carries)
var _last_pos := Vector2.ZERO
var _move := Vector2.ZERO


func _init() -> void:
	z_index = 6
	z_as_relative = false


func home() -> Vector2:
	return (Dock.BAY + home_off) * Geom.M


func can_take(b) -> bool:
	if not is_instance_valid(b) or b.capture != null or b.pieces.is_empty() or b.total_mass() > MAX_T or game.tools.held_body == b:
		return false
	# another machine (the other hauler, the arm, the crane) is already after it
	return not b.get_meta("arm", false) or b.get_meta("arm_by", "") == who


# set off for it: from now on the other machines leave it alone
func _claim(b) -> void:
	b.set_meta("arm", true)
	b.set_meta("arm_by", who)


func _unclaim(b) -> void:
	if b != null and is_instance_valid(b) and b.get_meta("arm_by", "") == who:
		b.set_meta("arm", false)
		b.remove_meta("arm_by")


# what it fetches unasked: a loose body of plain scrap (no whole equipment, no
# hazard) that nobody holds and no other machine is after. Anything of value,
# or anything it cannot be sure of, waits for the operator (or a mark).
func auto_takes(b) -> bool:
	if not can_take(b) or b.get_meta("arm", false) or b == body:
		return false
	if t < float(b.get_meta("no_way_till", -1.0)):
		return false
	if t - float(b.get_meta("arm_drop", -99.0)) < 5.0:
		return false
	if game.arm != null and (game.arm.body == b or game.arm.takes(b)):
		return false
	if _other_has(b) or game.dock.in_buffer(b):
		return false
	return game.dock.is_scrap(b)


# the other hauler is already after it
func _other_has(b) -> bool:
	for h in game.haulers():
		if h != self and h.body == b:
			return true
	return false


# the mark key: on a floating piece it goes on the list (or comes off it)
func toggle(b) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	if queue.has(b):
		queue.erase(b)
		return "hauler_unmarked"
	if b.total_mass() > MAX_T:
		return "hauler_heavy"
	queue.append(b)
	return "hauler_marked"


func _zone_for(b) -> String:
	for p in b.pieces:
		if game.sys.dest_of(p) == "hazard":
			return "hazard"
	if game.dock.is_scrap(b):
		return "metal"
	return "equip"


func _drop_point(z: String) -> Vector2:
	return Dock.zpos(z) - Dock.ZONES[z].face * 1.4 * Geom.M


func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim or game.state != "play":
		return
	t += dt
	if pos == Vector2.ZERO:
		pos = home()
	game.nav_grid().step(dt)
	for b in queue.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			queue.erase(b)
	if game.auto_paused:
		if body != null:
			halt()
		_fly(home(), dt)
		return
	# the operator took hold of what it carries: theirs now
	if body != null and is_instance_valid(body) and game.tools.held_body == body:
		halt()
		return
	var hold := false
	if state in ["reach", "carry"] and game.keepout_blocks(pos, _heading()):
		hold = true
	if state in ["reach", "carry"] and game.drone_near(pos, CLEAR, _heading()):
		wait_t += dt
		if wait_t < 1.0:
			hold = true
	else:
		wait_t = 0.0
	# and out of the arm's way while that carries (unless it already has the mouth: then the arm waits)
	if state == "carry" and game.mouths.get(zone, "") != who and game.arm != null and game.arm.state == "carry" and game.arm.claw.distance_to(pos) < 2.0 * Geom.M:
		hold = true
	if hold:
		_brake(dt)
		return
	match state:
		"idle":
			for b in queue:
				if can_take(b) and _reachable(b):
					_set_off(b)
					queue.erase(b)
					break
			# nothing marked: loose scrap that is plainly scrap, the arm's or not
			if state == "idle":
				for b in game.world.bodies:
					if auto_takes(b) and _reachable(b):
						_set_off(b)
						break
			if state == "idle":
				_fly(home(), dt)
		"reach":
			if not can_take(body):
				_done()
				return
			var target: Vector2 = body.global_transform * body.center_of_mass
			if _fly(target, dt, 6.0) or pos.distance_to(target) < 6.0:
				body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				body.set_deferred("freeze", true)
				body.collision_layer = 0
				body.collision_mask = 0
				off = body.global_position - pos
				zone = Dock.nearest(_zone_for(body), pos)
				route = PackedVector2Array()
				state = "carry"
				game.sfx.play("grab", pos, 0.5)
		"carry":
			if not is_instance_valid(body) or body.capture != null:
				# the mouth took it out of the claw on the way down: delivered all the same
				carried += 1
				_done()
				return
			var drop := _drop_point(zone)
			# the last stretch waits its turn at the mouth
			if pos.distance_to(drop) < 3.0 * Geom.M and not game.mouth_take(zone, who):
				_brake(dt)
			elif _fly(drop, dt):
				state = "release"
				hold_t = 0.0
			body.global_position = pos + off
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
		"release":
			hold_t += dt
			_brake(dt)
			if is_instance_valid(body) and body.capture == null:
				body.global_position = pos + off
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_done()
			elif hold_t > 0.25:
				body.collision_layer = 1
				body.collision_mask = FreeBody.MASK
				body.set_deferred("freeze", false)
				body.linear_velocity = Dock.ZONES[zone].face * -60.0 + vel * 0.4
				body.set_meta("arm", false)
				body.remove_meta("arm_by")
				body.set_meta("arm_drop", t)
				carried += 1
				game.on_arm_drop(body)
				_done()


# off after b: claimed for this hauler, a fresh way planned
func _set_off(b) -> void:
	body = b
	_claim(b)
	state = "reach"
	route = PackedVector2Array()


# can it get there at all (a piece shut in a room nobody has opened is not for it);
# one it can't reach is left alone for a while
func _reachable(b) -> bool:
	if t < float(b.get_meta("no_way_till", -1.0)):
		return false
	var p: Vector2 = b.global_transform * b.center_of_mass
	var way: PackedVector2Array = game.nav_grid().path(pos, p, preload("res://scripts/nav.gd").EMPTY_CLEAR)
	if way.is_empty():
		b.set_meta("no_way_till", t + 6.0)
		return false
	return true


# how much it carries now (0 empty, 1 a full 1.5 t load)
func _load() -> float:
	if state in ["carry", "release"] and is_instance_valid(body):
		return clampf(body.total_mass() / MAX_T, 0.0, 1.0)
	return 0.0


# fly toward `to` along the navigation grid like the operator's drone: speed
# up, keep to the path, brake in to arrive. true once there and slow.
func _fly(to: Vector2, dt: float, arrive: float = ARRIVE) -> bool:
	var Nav = preload("res://scripts/nav.gd")
	var ld := _load()
	var clear: float = Nav.LOAD_CLEAR if ld > 0.0 else Nav.EMPTY_CLEAR
	_replan_t -= dt
	if route.is_empty() or _replan_t <= 0.0 or _goal.distance_to(to) > 24.0 or clear != _clear:
		route = game.nav_grid().path(pos, to, clear)
		if route.is_empty():
			route = PackedVector2Array([to])
		_goal = to
		_clear = clear
		_replan_t = REPLAN
	# the next point, skipping ahead when the one after is in clear sight
	while route.size() > 1 and (pos.distance_to(route[0]) < 28.0 or game.nav_grid().sight(pos, route[1], clear * 0.8)):
		route.remove_at(0)
	var nxt: Vector2 = route[0]
	var left := pos.distance_to(nxt)
	for i in range(1, route.size()):
		left += route[i - 1].distance_to(route[i])
	var vmax := VMAX * lerpf(1.0, LOAD_V, ld)
	var acc := ACCEL / (1.0 + 1.4 * ld)
	# brake in: the speed it can still stop from over what is left
	var speed := minf(vmax, sqrt(2.0 * acc * 0.75 * maxf(0.0, left - arrive * 0.5)))
	var dir := (nxt - pos).normalized() if left > 0.5 else Vector2.ZERO
	var want := dir * speed + _avoid() * vmax * 0.5
	if left < arrive and vel.length() < 50.0:
		vel = vel.move_toward(Vector2.ZERO, acc * dt)
		return true
	vel += (want - vel).limit_length(acc * dt)
	pos += vel * dt
	return false


func _brake(dt: float) -> void:
	vel = vel.move_toward(Vector2.ZERO, ACCEL / (1.0 + 1.4 * _load()) * dt)
	pos += vel * dt
	if state == "carry" and is_instance_valid(body):
		body.global_position = pos + off


# a push away from what is near: loose pieces (not its own), the other hauler, the operator
func _avoid() -> Vector2:
	var push := Vector2.ZERO
	for b in game.world.bodies:
		if not is_instance_valid(b) or b == body or b.capture != null:
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		var d := pos - c
		var r := AVOID_R + 0.5 * sqrt(b.total_mass()) * Geom.M
		if d.length() < r and d.length() > 0.1:
			push += d.normalized() * (1.0 - d.length() / r)
	for h in game.haulers():
		if h != self:
			var d2: Vector2 = pos - h.pos
			if d2.length() < AVOID_R and d2.length() > 0.1:
				push += d2.normalized() * 1.5 * (1.0 - d2.length() / AVOID_R)
	if game.drone != null and game.drone.alive:
		var d3: Vector2 = pos - game.drone.global_position
		if d3.length() < AVOID_R and d3.length() > 0.1:
			push += d3.normalized() * 1.2 * (1.0 - d3.length() / AVOID_R)
	return push.limit_length(1.0)


# where it is making for now
func _heading() -> Vector2:
	if not route.is_empty():
		return route[0]
	if state == "reach" and is_instance_valid(body):
		return body.global_transform * body.center_of_mass
	return pos


func halt() -> void:
	if body != null and is_instance_valid(body):
		if state in ["carry", "release"]:
			body.collision_layer = 1
			body.collision_mask = FreeBody.MASK
			body.set_deferred("freeze", false)
			body.linear_velocity = vel * 0.4
		_unclaim(body)
	_done()


func _done() -> void:
	game.mouth_release(zone, who)
	_unclaim(body)
	body = null
	route = PackedVector2Array()
	state = "idle"


func _process(dt: float) -> void:
	var v := (pos - _last_pos) / maxf(dt, 0.001)
	_last_pos = pos
	_move = _move.lerp(v, 1.0 - exp(-8.0 * dt))
	var want := heading
	if _move.length() > 20.0:
		want = _move.angle()
	elif body != null and is_instance_valid(body):
		want = (body.global_transform * body.center_of_mass - pos).angle()
	heading = lerp_angle(heading, want, 1.0 - exp(-6.0 * dt))
	queue_redraw()


func _draw() -> void:
	# marks on the queued pieces
	for i in queue.size():
		var b = queue[i]
		if not is_instance_valid(b):
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		var s := 9.0 + 2.0 * sin(t * 5.0 + i)
		draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s)]), Pal.tint(Pal.AIR, 0.9, 1.3), 1.6, true)
		draw_string(Fonts.get_font("Medium"), c + Vector2(s + 4, 4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.AIR, 0.9, 1.2))
	# the drone itself, and its line to the load
	if body != null and is_instance_valid(body) and state in ["carry", "release"]:
		draw_line(pos, body.global_transform * body.center_of_mass, Pal.tint(Pal.AIR, 0.5, 1.2), 1.2, true)
	var sc := R / 20.0
	var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, pos)
	draw_set_transform_matrix(xf)
	var busy := state != "idle"
	var push := _move.normalized() * clampf(_move.length() / 120.0, 0.0, 1.0) if Txt.anim_level() > 0 else Vector2.ZERO
	Art.tint = Color(Pal.AIR.r * 1.05, Pal.AIR.g * 1.05, Pal.AIR.b * 1.05)
	Art.draw(self, "tripod" if who == "hauler2" else "coreclaw", {"heading": heading, "tool": 3 if busy else 0, "open": 1.0 if state in ["carry", "release"] else (0.4 if busy else 0.0),
		"t": t, "thrust": push, "dash": false, "design": "", "base_xf": xf})
	Art.tint = Color(1, 1, 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)
