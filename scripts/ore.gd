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


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("ore", {})
	fines = float(cfg.get("fines", 0.0))
	fines0 = fines
	z_index = 3
	z_as_relative = false


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
	if open.is_empty() or fines <= 0.0:
		return
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
	_release(open)


func _gate_point(tag: String) -> Vector2:
	var p = world.tag(tag)
	if p != null and not p.gone:
		return world.frame(p) * Geom.centroid(p.poly)
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	return Vector2((b[0] + b[2]) * 0.5, b[3]) * Geom.M


# the chunks over an open gate come loose as the heap under them runs out
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
		# above the heap's top: nothing under it any more
		if at.y < level:
			continue
		var near := false
		for g in open:
			if absf(at.x - _gate_point(g).x) < 5.0 * Geom.M:
				near = true
		if near:
			world.kill_joint(j)


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


func _process(dt: float) -> void:
	if not active():
		return
	for s in stream:
		s[2] += dt
		s[0] += s[1] * dt
	stream = stream.filter(func(s): return s[2] < 0.9)
	queue_redraw()


func _draw() -> void:
	if not active():
		return
	# the heap: shaded to its level inside the hopper, once anyone can see in
	var b: Array = cfg.get("box", [0, 0, 0, 0])
	if fines > 0.0:
		var top: float = lerpf(float(b[3]), float(b[1]), clampf(fines / maxf(fines0, 0.001), 0.0, 1.0))
		var r := Rect2(Vector2(b[0], top) * Geom.M, Vector2(b[2] - b[0], b[3] - top) * Geom.M)
		draw_rect(r, Color(0.32, 0.26, 0.2, 0.35))
		var k := 0
		var x: float = r.position.x + 6.0
		while x < r.end.x - 6.0:
			var y: float = r.position.y + 4.0 + float((k * 37) % 23)
			while y < r.end.y - 4.0:
				draw_circle(Vector2(x + float((k * 13) % 9), y), 1.6, Color(0.55, 0.45, 0.35, 0.5))
				y += 14.0
				k += 1
			x += 12.0
	for s in stream:
		draw_circle(s[0], 2.0, Color(0.6, 0.5, 0.38, 0.8 * (1.0 - s[2] / 0.9)))
