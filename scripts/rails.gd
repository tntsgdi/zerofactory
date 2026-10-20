class_name Rails
extends Node
# Cargo held on lock rails (R2 fleet, JD-38 "Turtledove": "the cargo rails run
# through two door locks; release the rail locks before it can be drawn out
# undamaged"; RO-128 "Long Bridge": four independent lock rails). A ship file's
# "rails" section: {set id: {"lock": control id, "boxes": [tags], "rails": [tags],
# "out": [x, y] m/s, "doors": [the door controls on the way out]}}.
#   The fixings between a box and its rails are the rail's locks, not bolts: the
#   wrench can't undo them. Turning the set's lock control off releases every box
#   on it at once and sends them off along the rails ("out"): through the open
#   doors, or into a shut one, which dents them as any knock does.
#   Cutting a rail that still carries a box: the box is wrenched with it (dented).
#   "hangs": [tags] (SV-122's instrument cradle, hung from the main beam): one of
#   those cut into or freed while the set's boxes are still locked on, and the
#   whole set drops and bangs (badly dented). "say": a prefix for what is said
#   ("rail" unless given: <say>_locked / _released / _cut / _drop).
# Saved: which sets have been released.

const CUT_DENT := 0.45
const LIFT := 0.03            # m a released box rises off its rail
const DROP_DENT := 0.55

var game
var world
var cfg := {}
var released := {}            # set id -> true
var _push: Array = []         # [box tag, velocity px/s, frames left, lifted]


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("rails", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"released": released.keys()}


func load_state(d: Dictionary) -> void:
	for s in d.get("released", []):
		released[str(s)] = true


# the set a box or a rail belongs to ("" none)
func _set_of(tag: String, key: String) -> String:
	for s in cfg:
		if (cfg[s].get(key, []) as Array).has(tag):
			return s
	return ""


# what is said when the wrench meets a locked fixing
func locked_msg(j) -> String:
	var s := _set_holding(j)
	return str(cfg[s].get("say", "rail")) + "_locked" if s != "" else "rail_locked"


func _set_holding(j) -> String:
	var a = world.pieces.get(j.a)
	var b = world.pieces.get(j.b)
	if a == null or b == null:
		return ""
	for pr in [[a, b], [b, a]]:
		var s := _set_of(pr[0].tag, "boxes")
		if s != "" and not released.has(s) and (cfg[s].get("rails", []) as Array).has(pr[1].tag):
			return s
	return ""


# a fixing between a box and its rail, while the rail is locked
func holds(j) -> bool:
	if not active():
		return false
	var a = world.pieces.get(j.a)
	var b = world.pieces.get(j.b)
	if a == null or b == null:
		return false
	for pr in [[a, b], [b, a]]:
		var s := _set_of(pr[0].tag, "boxes")
		if s != "" and not released.has(s) and (cfg[s].get("rails", []) as Array).has(pr[1].tag):
			return true
	return false


# a lock control turned: off releases its set
func on_switch(c) -> bool:
	for s in cfg:
		if cfg[s].get("lock", "") == c.id and not c.state and not released.has(s):
			_release(s)
			return true
	return false


func _release(s: String) -> void:
	released[s] = true
	var e: Dictionary = cfg[s]
	var out: Array = e.get("out", [0.0, 0.0])
	for t in e.get("boxes", []):
		var bx = world.tag(str(t))
		if bx == null or bx.gone:
			continue
		for j in world.joints_of(bx):
			var o = world.pieces.get(j.b if j.a == bx.id else j.a)
			if o != null and (e.get("rails", []) as Array).has(o.tag):
				world.kill_joint(j)
		_push.append([str(t), Vector2(float(out[0]), float(out[1])) * Geom.M, 60 * 30, false])
	game.say(str(e.get("say", "rail")) + "_released", world.ctrl_world(world.ctrls[e.lock]), e.lock)
	game.log_op("rail")


# the beam into a rail: whatever box still rides it is wrenched with it
func on_cut(p) -> void:
	if not active() or p.cls == "equip":
		return
	_hung(p)
	var s := _set_of(p.tag, "rails")
	if s == "":
		return
	var hit := 0.0
	for t in cfg[s].get("boxes", []):
		var bx = world.tag(str(t))
		if bx == null or bx.gone or bx.body != null or not bx.intact:
			continue
		var on := false
		for j in world.joints_of(bx):
			if j.a == p.id or j.b == p.id:
				on = true
		if on:
			var before: float = bx.cond
			game._dent(bx, maxf(0.0, bx.cond - CUT_DENT * maxf(0.4, bx.fragile * 2.0)), "dv_rail")
			hit += (before - bx.cond) * bx.value
	if hit > 0.0:
		game.incident("rail_cut", p.tag)
		game.say(str(cfg[s].get("say", "rail")) + "_cut", world.frame(p) * Geom.centroid(p.poly), p.tag)


# a piece some set hangs from, cut into or come loose: the locked set drops with it
func _hung(p) -> void:
	for s in cfg:
		if released.has(s) or not (cfg[s].get("hangs", []) as Array).has(p.tag):
			continue
		released[s] = true
		var lost := 0.0
		for t in cfg[s].get("boxes", []):
			var bx = world.tag(str(t))
			if bx == null or bx.gone or not bx.intact:
				continue
			var before: float = bx.cond
			game._dent(bx, maxf(0.0, bx.cond - DROP_DENT), "dv_drop")
			lost += (before - bx.cond) * bx.value
		game.incident("cradle_drop", s)
		game.say(str(cfg[s].get("say", "rail")) + "_drop", world.frame(p) * Geom.centroid(p.poly), p.tag)
		game.shake(0.5)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		_hung(q)


# how far along "out" the set's rails reach (px): a box rides them until it is past that
func _rail_end(st: String, dir: Vector2) -> float:
	var far := -INF
	for t in cfg[st].get("rails", []):
		var r = world.tag(str(t))
		if r == null or r.gone:
			continue
		for q in world.frame(r) * r.poly:
			far = maxf(far, q.dot(dir))
	return far


func _physics_process(_dt: float) -> void:
	if _push.is_empty():
		return
	var left: Array = []
	for e in _push:
		var bx = world.tag(e[0])
		if bx != null and bx.body != null and is_instance_valid(bx.body):
			# clear of the rail it rode on (it slides out, it doesn't grind along it)
			if not e[3]:
				bx.body.global_position += Vector2(0, -LIFT * Geom.M)
				bx.body.reset_physics_interpolation()
				e[3] = true
			# the rails guide it: along them, no turning, until it is past their end
			var dir: Vector2 = (e[1] as Vector2).normalized()
			var back := INF
			for q in bx.body.global_transform * bx.poly:
				back = minf(back, q.dot(dir))
			# stopped by something (a shut door): it no longer slides
			var blocked: bool = e.size() > 4 and bx.body.linear_velocity.dot(dir) < (e[1] as Vector2).length() * 0.4
			if back < _rail_end(_set_of(e[0], "boxes"), dir) and int(e[2]) > 0 and not blocked:
				if e.size() == 4:
					e.append(true)
				bx.body.linear_velocity = e[1]
				bx.body.angular_velocity = 0.0
				e[2] = int(e[2]) - 1
				left.append(e)
			continue
		e[2] = int(e[2]) - 1
		if int(e[2]) > 0:
			left.append(e)
	_push = left
