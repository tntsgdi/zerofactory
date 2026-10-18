class_name Crane
extends Node2D
# The heavy crane (roadmap 4.4, a berth facility): a gantry over the berth
# with a hook on a cable. It lifts what the grapple and the haulers cannot —
# up to 12 t — whole: an empty cryogenic tank, a crusher drum, an engine block.
# Marked with the mark key (anything over the hauler's 1.5 t goes on its list),
# it lifts it to its carrying height (over the ships, under the equipment bay),
# runs along, and brings it to the lip of the mouth it belongs in.
# It takes nothing unasked, waits its turn over a mouth, holds back for the
# operator's drone, keeps out of keep-out zones, and the automation key stops
# it (what it holds is let go where it is). Slow: it is a crane.

const MAX_T := 12.0
const SPEED := 2.5 * 48.0        # px/s with a load
const EMPTY := 6.0 * 48.0        # px/s empty
const CLEAR := 3.0 * 48.0        # px it keeps from the operator's drone
const LIFT_Y := -7.4             # m: the height it carries a load at (over the ships, under the equipment bay's lip)

var game: Game
var queue: Array = []            # marked bodies, in order
var body = null
var path: Array = []
var pos := Vector2.ZERO          # the hook
var state := "idle"              # idle reach carry release
var zone := "equip"              # the mouth it is making for (an id: "equip2" is a mouth of its own)
var off := Vector2.ZERO
var hold_t := 0.0
var t := 0.0
var carried := 0
var wait_t := 0.0


func _init() -> void:
	z_index = 6
	z_as_relative = false


# the rail along the top of the berth (px)
static func rail_y() -> float:
	return (Dock.BOUNDS.position.y + 1.4) * Geom.M


func home() -> Vector2:
	return Vector2(2.0 * Geom.M, LIFT_Y * Geom.M)


func can_take(b) -> bool:
	return is_instance_valid(b) and b.capture == null and not b.pieces.is_empty() and b.total_mass() <= MAX_T and game.tools.held_body != b and not b.get_meta("arm", false)


# the mark key on a load too heavy for the haulers
func toggle(b) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	if queue.has(b):
		queue.erase(b)
		return "crane_unmarked"
	if b.total_mass() > MAX_T:
		return "crane_heavy"
	queue.append(b)
	return "crane_marked"


func _zone_for(b) -> String:
	var k := "equip"
	for p in b.pieces:
		if game.sys.dest_of(p) == "hazard":
			k = "hazard"
	if k != "hazard" and game.dock.is_scrap(b):
		k = "metal"
	return Dock.nearest(k, b.global_transform * b.center_of_mass)


# just off the mouth's lip, inside its catch: the mouth takes it from the hook
func _drop_point(z: String) -> Vector2:
	return Dock.zpos(z) + Dock.ZONES[z].face * 0.4 * Geom.M


func _physics_process(dt: float) -> void:
	if game == null or game.paused_sim or game.state != "play":
		return
	t += dt
	if pos == Vector2.ZERO:
		pos = home()
	for b in queue.duplicate():
		if not is_instance_valid(b) or b.capture != null:
			queue.erase(b)
	if game.auto_paused:
		if body != null:
			halt()
		pos = pos.move_toward(home(), EMPTY * dt)
		return
	if state in ["reach", "carry"] and game.keepout_blocks(pos, _heading()):
		return
	var k := 1.0
	if state in ["reach", "carry"] and game.drone_near(pos, CLEAR, _heading()):
		wait_t += dt
		if wait_t < 1.0:
			return
		k = 0.4
	else:
		wait_t = 0.0
	dt *= k
	match state:
		"idle":
			for b in queue:
				if can_take(b):
					body = b
					queue.erase(b)
					body.set_meta("arm", true)
					path = _overhead(pos, body.global_transform * body.center_of_mass)
					state = "reach"
					break
			if state == "idle":
				pos = pos.move_toward(home(), EMPTY * dt)
		"reach":
			if not is_instance_valid(body) or body.capture != null or game.tools.held_body == body:
				_done()
				return
			# the load may have drifted: the last leg follows it
			var target: Vector2 = body.global_transform * body.center_of_mass
			if path.size() <= 1:
				path = [target]
			pos = pos.move_toward(path[0], EMPTY * dt)
			if pos.distance_to(path[0]) < 3.0:
				path.pop_front()
			if path.is_empty() and pos.distance_to(target) < 6.0:
				body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				body.set_deferred("freeze", true)
				body.collision_layer = 0
				body.collision_mask = 0
				off = body.global_position - pos
				zone = _zone_for(body)
				path = _overhead(pos, _drop_point(zone))
				state = "carry"
				game.sfx.play("grab", pos, 0.7)
		"carry":
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_done()
				return
			if path.is_empty():
				state = "release"
				hold_t = 0.0
				return
			if path.size() == 1 and not game.mouth_take(zone, "crane"):
				return
			pos = pos.move_toward(path[0], SPEED * dt)
			if pos.distance_to(path[0]) < 2.0:
				path.pop_front()
			body.global_position = pos + off
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
		"release":
			hold_t += dt
			if not is_instance_valid(body) or body.capture != null:
				carried += 1
				_done()
			elif hold_t > 0.4:
				body.collision_layer = 1
				body.collision_mask = FreeBody.MASK
				body.set_deferred("freeze", false)
				body.linear_velocity = Dock.ZONES[zone].face * -50.0
				body.set_meta("arm", false)
				body.set_meta("arm_drop", t)
				carried += 1
				game.on_arm_drop(body)
				_done()


# to the carrying height, along, and straight to the point
func _overhead(from: Vector2, to: Vector2) -> Array:
	var y := LIFT_Y * Geom.M
	return [Vector2(from.x, y), Vector2(to.x, y), to]


func _heading() -> Vector2:
	return path[0] if not path.is_empty() else pos


func halt() -> void:
	if body != null and is_instance_valid(body):
		if state in ["carry", "release"]:
			body.collision_layer = 1
			body.collision_mask = FreeBody.MASK
			body.set_deferred("freeze", false)
			body.linear_velocity = Vector2.ZERO
		body.set_meta("arm", false)
	_done()


func _done() -> void:
	game.mouth_release(zone, "crane")
	if body != null and is_instance_valid(body) and state == "reach":
		body.set_meta("arm", false)
	body = null
	path = []
	state = "idle"


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ry := rail_y()
	var x0 := (Dock.BOUNDS.position.x + 0.6) * Geom.M
	var x1 := (Dock.FLOOR_X1 - 0.6) * Geom.M
	# the rail
	draw_line(Vector2(x0, ry), Vector2(x1, ry), Pal.ink(0.5), 3.0)
	draw_line(Vector2(x0, ry + 6.0), Vector2(x1, ry + 6.0), Pal.ink(0.22), 1.0)
	var x := x0
	while x < x1:
		draw_line(Vector2(x, ry), Vector2(x + 10.0, ry + 6.0), Pal.ink(0.18), 1.0)
		x += 26.0
	# marks on the queued loads
	for i in queue.size():
		var b = queue[i]
		if not is_instance_valid(b):
			continue
		var c: Vector2 = b.global_transform * b.center_of_mass
		var s := 12.0 + 2.0 * sin(t * 4.0 + i)
		draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), Pal.tint(Pal.AIR, 0.85, 1.3), false, 1.6)
		draw_string(Fonts.get_font("Medium"), c + Vector2(s + 4, 4), "C%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Pal.tint(Pal.AIR, 0.9, 1.2))
	# the trolley, the cable, the hook
	var tr := Vector2(pos.x, ry)
	draw_rect(Rect2(tr - Vector2(26, 4), Vector2(52, 16)), Color(0.07, 0.074, 0.084))
	draw_rect(Rect2(tr - Vector2(26, 4), Vector2(52, 16)), Pal.ink(0.75), false, 1.4)
	for s2 in [-16.0, 16.0]:
		draw_circle(tr + Vector2(s2, -2), 4.0, Pal.ink(0.5))
	draw_line(tr + Vector2(-4, 12), pos + Vector2(-4, -8), Pal.ink(0.55), 1.2)
	draw_line(tr + Vector2(4, 12), pos + Vector2(4, -8), Pal.ink(0.55), 1.2)
	draw_rect(Rect2(pos - Vector2(12, 10), Vector2(24, 8)), Pal.heat(0.85, 1.2) if state != "idle" else Pal.ink(0.6))
	draw_arc(pos + Vector2(0, 6), 8.0, -0.4, PI + 0.4, 12, Pal.ink(0.85), 2.0, true)
	if body != null and is_instance_valid(body) and state in ["carry", "release"]:
		draw_line(pos, body.global_transform * body.center_of_mass, Pal.tint(Pal.AIR, 0.45, 1.2), 1.2, true)
