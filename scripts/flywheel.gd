extends Node
# A mass driver still spinning (exotic batch, MD-160 "Slingshot": "three 1.5 t
# flywheels at 20,000 rpm on magnetic bearings, still turning six hours after the
# power went; two rails held at 180 kN"). A ship file's "flywheel":
#   {"wheels": {wheel: {"rpm": at the start, "brake": its caliper's switch,
#     "cool": its brake cooling's switch, "caliper": the caliper piece,
#     "near": [what it tears into]}},
#    "safe": rpm under which it may be lifted, "decel": rpm/s a cooled brake takes
#    off, "burn": s a brake takes dry before it burns out,
#    "rails": {rail: {"sections": [pieces], "tensioners": [switches, tail first],
#     "hits": [what it whips into], "kn": its pull}}}
#   A wheel keeps turning on its own; its brake slows it only while the brake's
#   cooling runs — braked dry it slows at half the rate and, after "burn" s, the
#   caliper burns out (damaged, no more use). A wheel freed or cut while still over
#   "safe" tears loose: it is thrown off spinning, into what is near.
#   A rail's tensioners come off from its tail to its head: one let off while one
#   further aft still holds, and the rail lurches (what it carries is knocked); a
#   rail section cut or freed while any of its tensioners holds whips loose.
# Saved: each wheel's rpm, which brakes burnt, which wheels tore loose, which rails went.

const LOOSE_KEEP := 0.5
const WHIP_KEEP := 0.6

var game
var world
var cfg := {}
var rpm := {}
var burnt := {}
var loose := {}
var rails_gone := {}
var _dry := {}
var _was_on := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("flywheel", {})
	for w in cfg.get("wheels", {}):
		rpm[w] = float(cfg.wheels[w].get("rpm", 20000.0))
	for r in cfg.get("rails", {}):
		for t in cfg.rails[r].get("tensioners", []):
			_was_on[t] = true


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"rpm": rpm, "burnt": burnt.keys(), "loose": loose.keys(), "rails": rails_gone.keys()}


func load_state(d: Dictionary) -> void:
	for w in d.get("rpm", {}):
		rpm[str(w)] = float(d.rpm[w])
	for t in d.get("burnt", []):
		burnt[str(t)] = true
	for t in d.get("loose", []):
		loose[str(t)] = true
	for t in d.get("rails", []):
		rails_gone[str(t)] = true


func spinning(w: String) -> bool:
	return float(rpm.get(w, 0.0)) > float(cfg.get("safe", 300.0))


func rail_pull(r: String) -> float:
	var e: Dictionary = cfg.get("rails", {}).get(r, {})
	var n := 0
	for t in e.get("tensioners", []):
		if game.sys.on(str(t)):
			n += 1
	return float(e.get("kn", 180.0)) * n / maxf(1.0, e.get("tensioners", []).size())


# what still has to be made safe
func unsafe() -> Array:
	var out: Array = []
	for w in cfg.get("wheels", {}):
		if spinning(w) and not loose.has(w):
			out.append("wheel %s %d rpm" % [w, int(rpm[w])])
	for r in cfg.get("rails", {}):
		if rail_pull(r) > 0.0:
			out.append("rail %s %d kN" % [r, int(rail_pull(r))])
	return out


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var s = game.sys
	for w in cfg.wheels:
		var e: Dictionary = cfg.wheels[w]
		if loose.has(w):
			continue
		var r: float = rpm[w]
		var braked: bool = s.on(str(e.get("brake", ""))) and not burnt.has(w)
		if braked and r > 0.0:
			if s.on(str(e.get("cool", ""))):
				r -= float(cfg.get("decel", 250.0)) * dt
			else:
				r -= float(cfg.get("decel", 250.0)) * 0.5 * dt
				_dry[w] = float(_dry.get(w, 0.0)) + dt
				if _dry[w] > float(cfg.get("burn", 8.0)):
					_burn(w)
		else:
			r -= 0.5 * dt
		rpm[w] = maxf(0.0, r)
	# the tensioners, tail first
	for rl in cfg.get("rails", {}):
		var ts: Array = cfg.rails[rl].get("tensioners", [])
		for i in ts.size():
			var t: String = ts[i]
			var now: bool = s.on(t)
			if _was_on.get(t, true) and not now:
				for k in range(0, i):
					if s.on(str(ts[k])) and not rails_gone.has(rl):
						_lurch(rl, t)
						break
			_was_on[t] = now


func _burn(w: String) -> void:
	burnt[w] = true
	var e: Dictionary = cfg.wheels[w]
	var c = world.tag(str(e.get("caliper", "")))
	if c != null and not c.gone and c.intact:
		game._dent(c, minf(c.cond, 0.3), "dv_brake_burn")
	var at: Vector2 = world.frame(c) * Geom.centroid(c.poly) if c != null else game.drone.global_position
	game.incident("brake_burn", w)
	game.say("brake_burn", at, w)


func _tear(w: String, why: String) -> void:
	if loose.has(w):
		return
	loose[w] = true
	var p = world.tag(w)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var lost := 0.0
	for t in cfg.wheels[w].get("near", []):
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, LOOSE_KEEP), "dv_wheel_loose")
		lost += (before - q.cond) * q.value
	if p != null and p.intact:
		var b0: float = p.cond
		game._dent(p, minf(p.cond, LOOSE_KEEP), "dv_wheel_loose")
		lost += (b0 - p.cond) * p.value
		if p.body != null:
			p.body.linear_velocity = Vector2(6.0, -3.0) * Geom.M
			p.body.angular_velocity = 12.0
	game.incident("wheel_loose", why)
	game.say("wheel_loose", at, w)
	game.note_loss("loss_wheel_loose", w, lost)
	game.shake(0.9)
	game.sfx.play("snap")


func _lurch(rl: String, t: String) -> void:
	var lost := 0.0
	for h in cfg.rails[rl].get("hits", []):
		var q = world.tag(str(h))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, WHIP_KEEP + 0.2), "dv_rail_lurch")
		lost += (before - q.cond) * q.value
	game.incident("rail_lurch", t)
	game.say("rail_lurch", world.ctrl_world(world.ctrls[t]) if world.ctrls.has(t) else game.drone.global_position, t)
	game.note_loss("loss_rail_lurch", t, lost)
	game.shake(0.5)


func _rail_cut(p) -> void:
	for rl in cfg.get("rails", {}):
		if not (cfg.rails[rl].get("sections", []) as Array).has(p.tag) or rails_gone.has(rl):
			continue
		if rail_pull(rl) <= 0.0:
			return
		rails_gone[rl] = true
		var lost := 0.0
		for h in cfg.rails[rl].get("hits", []):
			var q = world.tag(str(h))
			if q == null or q.gone or q.cls != "equip" or not q.intact:
				continue
			var before: float = q.cond
			game._dent(q, minf(q.cond, WHIP_KEEP), "dv_rail_whip")
			lost += (before - q.cond) * q.value
		game.incident("rail_whip", p.tag)
		game.say("rail_whip", world.frame(p) * Geom.centroid(p.poly), p.tag)
		game.note_loss("loss_rail_whip", p.tag, lost)
		game.shake(0.8)
		game.sfx.play("snap")


func on_cut(p) -> void:
	if not active():
		return
	if cfg.wheels.has(p.tag) and spinning(p.tag):
		_tear(p.tag, "cut")
	_rail_cut(p)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if cfg.wheels.has(q.tag) and spinning(q.tag):
			_tear(q.tag, "freed")
		_rail_cut(q)
