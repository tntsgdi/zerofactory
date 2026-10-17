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
# go there).

const MAX_T := 1.5
const SPEED := 5.0 * 48.0        # px/s with a load
const EMPTY := 9.0 * 48.0        # px/s empty
const R := 12.0
const CLEAR := 2.5 * 48.0        # px it keeps from the operator's drone

var game: Game
var queue: Array = []            # marked bodies, in order
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


func _init() -> void:
	z_index = 6
	z_as_relative = false


func home() -> Vector2:
	return (Dock.BAY + Vector2(0.6, -1.6)) * Geom.M


func can_take(b) -> bool:
	return is_instance_valid(b) and b.capture == null and not b.pieces.is_empty() and b.total_mass() <= MAX_T and game.tools.held_body != b


# what it fetches unasked: a loose body of plain scrap (no whole equipment, no
# hazard) that nobody holds and no other machine is after. Anything of value,
# or anything it cannot be sure of, waits for the operator (or a mark).
func auto_takes(b) -> bool:
	if not can_take(b) or b.get_meta("arm", false) or b == body:
		return false
	if t - float(b.get_meta("arm_drop", -99.0)) < 5.0:
		return false
	if game.arm != null and (game.arm.body == b or game.arm.takes(b)):
		return false
	return game.dock.is_scrap(b)


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
	queue = queue.filter(func(b): return is_instance_valid(b) and b.capture == null)
	if game.auto_paused:
		if body != null:
			halt()
		pos = pos.move_toward(home(), EMPTY * dt)
		return
	var k := 1.0
	if state in ["reach", "carry"] and game.drone_near(pos, CLEAR):
		wait_t += dt
		if wait_t < 2.0:
			return
		k = 0.3
	else:
		wait_t = 0.0
	# and out of the arm's way while that carries (unless it already has the mouth: then the arm waits)
	if state == "carry" and game.mouths.get(zone, "") != "hauler" and game.arm != null and game.arm.state == "carry" and game.arm.claw.distance_to(pos) < 2.0 * Geom.M:
		return
	dt *= k
	match state:
		"idle":
			for b in queue:
				if can_take(b):
					body = b
					queue.erase(b)
					state = "reach"
					break
			# nothing marked: loose scrap that is plainly scrap, the arm's or not
			if state == "idle":
				for b in game.world.bodies:
					if auto_takes(b):
						body = b
						state = "reach"
						break
			if state == "idle":
				pos = pos.move_toward(home(), EMPTY * dt)
		"reach":
			if not can_take(body):
				_done()
				return
			var target: Vector2 = body.global_transform * body.center_of_mass
			pos = pos.move_toward(target, EMPTY * dt)
			if pos.distance_to(target) < 6.0:
				body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				body.set_deferred("freeze", true)
				body.collision_layer = 0
				body.collision_mask = 0
				body.set_meta("arm", true)
				off = body.global_position - pos
				zone = _zone_for(body)
				path = _route(pos, _drop_point(zone))
				state = "carry"
				game.sfx.play("grab", pos, 0.5)
		"carry":
			if not is_instance_valid(body) or body.capture != null:
				# the mouth took it out of the claw on the way down: delivered all the same
				carried += 1
				_done()
				return
			if path.is_empty():
				state = "release"
				hold_t = 0.0
				return
			if path.size() == 1 and not game.mouth_take(zone, "hauler"):
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
			elif hold_t > 0.25:
				body.collision_layer = 1
				body.collision_mask = 1 | 2 | 4
				body.set_deferred("freeze", false)
				body.linear_velocity = Dock.ZONES[zone].face * -60.0
				body.set_meta("arm", false)
				body.set_meta("arm_drop", t)
				carried += 1
				game.on_arm_drop(body)
				_done()


func halt() -> void:
	if body != null and is_instance_valid(body):
		if state in ["carry", "release"]:
			body.collision_layer = 1
			body.collision_mask = 1 | 2 | 4
			body.set_deferred("freeze", false)
			body.linear_velocity = Vector2.ZERO
		body.set_meta("arm", false)
	_done()


func _done() -> void:
	game.mouth_release(zone, "hauler")
	body = null
	path = []
	state = "idle"


# round the ship's nearer end while it stands between here and there
func _route(from: Vector2, to: Vector2) -> Array:
	var bb := Rect2()
	var first := true
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.gone or p.body != null or not p.barrier:
			continue
		var pb := Geom.bbox(p.poly)
		bb = pb if first else bb.merge(pb)
		first = false
	if first:
		return [to]
	bb = bb.grow(50.0)
	if not _crosses(from, to, bb):
		return [to]
	# over the top or under the bottom, whichever is nearer
	var y: float = bb.position.y - 30.0 if absf(from.y - bb.position.y) < absf(from.y - bb.end.y) else bb.end.y + 30.0
	var x0: float = clampf(from.x, bb.position.x - 30.0, bb.end.x + 30.0)
	return [Vector2(x0, y), Vector2(to.x, y), to]


func _crosses(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


func _process(_dt: float) -> void:
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
	var hexp := PackedVector2Array()
	for i in 9:
		hexp.append(pos + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * R)
	draw_colored_polygon(hexp.slice(0, 8), Color(0.07, 0.074, 0.084))
	draw_polyline(hexp, Pal.tint(Pal.AIR, 0.9, 1.1), 1.4, true)
	draw_circle(pos, 3.0, Pal.tint(Pal.AIR, 0.9, 1.4) if state != "idle" else Pal.ink(0.5))
