class_name Ore
extends Node2D
# Loose cargo (first on M-14, design/ships/M-14_鼹鼠_设计稿.md): a hopper of ore.
# The ship file's "ore" section:
#   box      [x0, y0, x1, y1] m   the hopper's inside (where the heap is drawn)
#   fines    t                    the heap: ore too fine to see piece by piece
#   price    $ per t              what the furnace pays for it
#   gates    [door tags]          the discharge gates in the hopper's floor
#   flow     t/s                  what one open gate lets through
#   tear     [joint tags]         the hopper's welds a lopsided dump tears
#   pins     joint type           how the visible chunks are packed ("pack")
# The visible chunks are ordinary pieces held by "pack" joints. As the heap runs
# out through a gate, the chunks over it come loose (lowest first) and drop
# through after it. Fines leave as a stream into the trough and are paid as they
# go. A gate that comes open by force (its welds cut, pried off) while the hopper
# is still more than half full dumps it all to one side: the hopper's welds tear.

const SURGE := 0.5               # of the fines still in: a forced gate tears the hopper

var game
var world
var cfg := {}
var fines := 0.0
var fines0 := 0.0
var paid := 0.0
var torn := false
var forced := {}                 # gate tag -> true once it came open by force
var t := 0.0
var stream: Array = []           # [pos, vel, life] particles of the falling fines
var flowing := {}                # ore piece -> the gate point (px) the flow carries it to
# Instance the same 64-segment circles as Godot draw_circle, with no texture
# rasterization or reduction in detail. Only transforms change as ore drains.
var heap := MultiMesh.new()
var heap_fines := -1.0
var stream_layer: Node2D
const HEAP_COLOR := Color(0.55, 0.45, 0.35, 0.5)
const CIRCLE_SEGMENTS := 64
const FLOW_V := 90.0             # px/s the flow carries a loose chunk at


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("ore", {})
	fines = float(cfg.get("fines", 0.0))
	fines0 = fines
	z_index = 3
	z_as_relative = false
	if active():
		_setup_heap()
		stream_layer = Node2D.new()
		stream_layer.draw.connect(_draw_stream)
		add_child(stream_layer)


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"fines": fines, "paid": paid, "torn": torn, "forced": forced.keys()}


func load_state(d: Dictionary) -> void:
	fines = float(d.get("fines", fines))
	paid = float(d.get("paid", 0.0))
	torn = d.get("torn", false)
	forced = {}
	for k in d.get("forced", []):
		forced[k] = true


# a gate is open when its door is, or when it is gone or loose
func _gate_open(tag: String) -> bool:
	var p = world.tag(tag)
	return p == null or p.gone or p.body != null or p.door_open


func _forced(tag: String) -> bool:
	var p = world.tag(tag)
	return p == null or p.gone or p.body != null


func value_left() -> float:
	return fines * float(cfg.get("price", 0.0))


func _physics_process(dt: float) -> void:
	if game == null or game.state != "play" or game.paused_sim or not active():
		return
	t += dt
	var open: Array = []
	for g in cfg.get("gates", []):
		if _gate_open(g):
			open.append(g)
			if _forced(g) and not forced.has(g):
				forced[g] = true
				_check_surge(g)
	_carry()
	if open.is_empty():
		return
	if fines > 0.0:
		var take := minf(fines, float(cfg.get("flow", 1.0)) * open.size() * dt)
		fines -= take
		var v := take * float(cfg.get("price", 0.0))
		paid += v
		game.on_ore_in(v)
		# the stream under each open gate
		for g in open:
			var at := _gate_point(g)
			if randf() < 0.6:
				stream.append([at + Vector2(randf_range(-30, 30), 0), Vector2(randf_range(-20, 20), randf_range(160, 260)), 0.0])
	# (and once the fines are all out, what is still packed over a gate opened late comes loose too)
	_release(open)


func _gate_point(tag: String) -> Vector2:
	var p = world.tag(tag)
	if p != null and not p.gone:
		return world.frame(p) * Geom.centroid(p.poly)
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	return Vector2((b[0] + b[2]) * 0.5, b[3]) * Geom.M


# the chunks over an open gate come loose and go out with the heap; once the
# fines are all gone, whatever is still packed anywhere slumps to the nearest
# open gate and goes the same way
func _release(open: Array) -> void:
	if t < 0.4:
		return
	t = 0.0
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var level: float = lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0)) * Geom.M
	var pin: String = cfg.get("pins", "pack")
	for j in world.joints:
		if not j.alive or j.type != pin:
			continue
		var p = world.pieces.get(j.a)
		if p == null:
			continue
		var at: Vector2 = world.joint_world(j)
		var best := ""
		var bd := INF
		for g in open:
			var d := absf(at.x - _gate_point(g).x)
			if d < bd:
				bd = d
				best = g
		# in the heap near an open gate, or anywhere once the heap is gone
		if fines > 0.0 and (at.y < level or bd >= 5.0 * Geom.M):
			continue
		world.kill_joint(j)
		for q in [p, world.pieces.get(j.b)]:
			if q != null and q.kind == "ore" and not flowing.has(q):
				flowing[q] = _gate_point(best)


# a loose chunk rides the flow down through its gate and out of the hopper
func _carry() -> void:
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var out_y := (float(b[3]) + 1.2) * Geom.M
	for q in flowing.keys():
		if q.gone or (q.body != null and q.body.capture != null):
			flowing.erase(q)
			continue
		if q.body == null or q.body.get_meta("arm", false) or game.tools.held_body == q.body:
			continue
		var com: Vector2 = q.body.global_transform * q.body.center_of_mass
		if com.y > out_y:
			flowing.erase(q)
			continue
		var to: Vector2 = flowing[q] + Vector2(0, 2.0 * Geom.M)
		q.body.linear_velocity = (to - com).normalized() * FLOW_V


# a gate that came open by force with the hopper still full: it all goes one way
func _check_surge(tag: String) -> void:
	if torn or fines < SURGE * fines0:
		return
	torn = true
	var at := _gate_point(tag)
	for jt in cfg.get("tear", []):
		for j in world.joints:
			if j.alive and j.get_meta("tag", "") == jt:
				world.kill_joint(j)
	game.incident("hopper_tear", tag)
	game.say("hopper_tear", at + Vector2(0, -60), tag)
	game.lose("loss_hopper", 8000.0, at + Vector2(0, -80))
	game.shake(0.7)
	game.sfx.play("snap")
	game.fx.sparks(at, Vector2.UP, 30, Pal.heat(1.0, 2.0), 360.0, 0.5, PI)


func _setup_heap() -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in CIRCLE_SEGMENTS + 1:
		# Match the float angle/radius used by RendererCanvasCull::canvas_item_add_ellipse.
		var angle: float = float(PackedFloat32Array([i * TAU / CIRCLE_SEGMENTS])[0])
		var offset := Vector2(cos(angle), sin(angle)) * 1.6
		verts.append(Vector3(offset.x, offset.y, 0.0))
		colors.append(HEAP_COLOR)
	verts.append(Vector3.ZERO)
	colors.append(HEAP_COLOR)
	for i in CIRCLE_SEGMENTS:
		indices.append(CIRCLE_SEGMENTS + 1)
		indices.append(i)
		indices.append(i + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	heap.transform_format = MultiMesh.TRANSFORM_2D
	heap.mesh = mesh
	# Reserve enough slots once, including room for alternate saved fill levels.
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	heap.instance_count = (ceili((b[2] - b[0]) * Geom.M / 12.0) + 1) * (ceili((b[3] - b[1]) * Geom.M / 14.0) + 1)
	heap.visible_instance_count = 0
	_update_heap()


func _heap_rect() -> Rect2:
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	var top: float = lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0))
	return Rect2(Vector2(b[0], top) * Geom.M, Vector2(b[2] - b[0], b[3] - top) * Geom.M)


func _update_heap() -> void:
	if fines == heap_fines:
		return
	heap_fines = fines
	var k := 0
	if fines > 0.0:
		var r := _heap_rect()
		var x: float = r.position.x + 6.0
		while x < r.end.x - 6.0:
			var y: float = r.position.y + 4.0 + float((k * 37) % 23)
			while y < r.end.y - 4.0:
				heap.set_instance_transform_2d(k, Transform2D(0.0, Vector2(x + float((k * 13) % 9), y)))
				y += 14.0
				k += 1
			x += 12.0
	heap.visible_instance_count = k
	queue_redraw()


func _process(dt: float) -> void:
	if not active():
		return
	_update_heap()
	# Keep the animated falling fines independent of the retained heap commands.
	var had_stream := not stream.is_empty()
	for s in stream:
		s[2] += dt
		s[0] += s[1] * dt
	if had_stream:
		stream = stream.filter(func(s): return s[2] < 0.9)
		stream_layer.queue_redraw()


func _draw() -> void:
	if not active() or fines <= 0.0:
		return
	draw_rect(_heap_rect(), Color(0.32, 0.26, 0.2, 0.35))
	if heap.visible_instance_count > 0:
		draw_multimesh(heap, null)


func _draw_stream() -> void:
	for s in stream:
		stream_layer.draw_circle(s[0], 2.0, Color(0.6, 0.5, 0.38, 0.8 * (1.0 - s[2] / 0.9)))
