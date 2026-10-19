class_name Mech
extends Node
# Mechanisms a few ship types bring with them (first on H-22, design/ships/H-22_双钩_设计稿.md):
# Both are named in the ship file: "magnets" {piece tag: {r, mT}}, "preloads" {joint tag: {...}}.
#   magnets  a piece with a magnet entry {"r": m, "mT": field} keeps a residual field until
#            it is degaussed (a "degauss" control, only with its coil supply dead).
#            Within r it pulls the drone and loose pieces of steel towards it; a drone
#            dragged onto it is knocked about.
#   preload  a joint with a preload entry {"pins": [joint tags], "vessel": gas vessel,
#            "kpa": pressure that still drives it, "piece": the loaded part, "push": [x, y]}
#            is the pivot of an arm held under load. Take it out while a locking pin is
#            still in, or while the hydraulics still hold pressure, and the arm springs:
#            the pins shear, the arm is thrown, it and what it hits are damaged.
#   actuator  a line with an actuator entry {"lock": control id, "piece": the
#            actuator's tag, "hits": what it slams into, "push": [x, y]} is the control
#            line of a powered actuator (PT-34's thrust-vector rams, reached through
#            the upper maintenance tunnel). Cut it while it is live and the lock is
#            off, and the actuator jerks: it and what it hits are damaged. Lock it
#            first, or kill its supply, and the cut is harmless.
#   balance  "balance": {"pairs": [[tag, tag, [the pieces each one hangs from]...]],
#            "support": control id} (TW-64's two outboard engine pods, the weight all
#            aft): take one of a pair off while the other still hangs there and the
#            hull's support isn't set, and the hull twists under the one left: its
#            mounts and it are damaged. Set the support first, or take both together.
# State that has to survive a save: which magnets are degaussed, which preloads went off.

var game
var world
var mags := {}                # piece tag -> {r, mT, k (1 = full field, 0 = degaussed)}
var loads := []               # [{tag, cfg, alive, fired}]
var pending := []             # [{tag, push, t}] impulses waiting for the part to come loose
var hit_cd := 0.0
var acts := {}                # line id -> {cfg, live (as last seen), fired}
var balance := {}             # the ship file's "balance" section
var twisted := {}             # pair index -> true once it went


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	var mg: Dictionary = ship.get("magnets", {})
	for t in mg:
		mags[t] = {"r": float(mg[t].get("r", 4.0)), "mT": float(mg[t].get("mT", 60.0)), "k": 1.0}
	var pl: Dictionary = ship.get("preloads", {})
	for t in pl:
		loads.append({"tag": t, "cfg": pl[t], "alive": _joint(t) != null, "fired": false})
	balance = ship.get("balance", {})
	var ac: Dictionary = ship.get("actuators", {})
	for lid in ac:
		acts[lid] = {"cfg": ac[lid], "live": false, "fired": false}


func save_state() -> Dictionary:
	var k := {}
	for t in mags:
		k[t] = mags[t].k
	var f: Array = []
	for l in loads:
		if l.fired:
			f.append(l.tag)
	var af: Array = []
	for lid in acts:
		if acts[lid].fired:
			af.append(lid)
	return {"mags": k, "fired": f, "acts": af, "twisted": twisted.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("mags", {}):
		if mags.has(t):
			mags[t].k = float(d.mags[t])
	for l in loads:
		l.fired = l.tag in d.get("fired", [])
		l.alive = _joint(l.tag) != null
	for lid in d.get("acts", []):
		if acts.has(lid):
			acts[lid].fired = true
	for i in d.get("twisted", []):
		twisted[int(i)] = true


func _joint(tag: String):
	for j in world.joints:
		if j.alive and j.get_meta("tag", "") == tag:
			return j
	return null


# the tension a preloaded joint holds (kN): what a tension gauge on it reads
func tension(tag: String) -> float:
	for l in loads:
		if l.tag == tag:
			if l.fired or not l.alive:
				return 0.0
			var cfg: Dictionary = l.cfg
			for pt in cfg.get("pins", []):
				if _joint(pt) != null:
					return float(cfg.get("kn", 40.0))
			return 0.0
	return 0.0


# the field a magnet piece shows now (mT): what a field probe reads
func field(tag: String) -> float:
	var m = mags.get(tag)
	if m == null:
		return 0.0
	var p = world.tag(tag)
	if p == null or p.gone:
		return 0.0
	return m.mT * m.k


# degauss: only once nothing feeds the coils (its supply piece reads no volts)
func degauss(tags: Array, supply: String) -> bool:
	var sp = world.tag(supply)
	if sp != null and not sp.gone and game.sys.piece_volts(sp) > 1.0:
		return false
	for t in tags:
		if mags.has(t):
			mags[t].k = 0.0
	return true


func _physics_process(dt: float) -> void:
	if game == null or game.state != "play" or game.paused_sim:
		return
	hit_cd = maxf(0.0, hit_cd - dt)
	_magnets(dt)
	_preloads()
	_actuators()
	_balance()
	_impulses(dt)


# a powered actuator's control line, cut while live and unlocked: the ram jerks
func _actuators() -> void:
	for lid in acts:
		var a: Dictionary = acts[lid]
		if a.fired:
			continue
		var l = world.lines.get(lid)
		if l != null and l.alive:
			a.live = game.sys.line_live(l)
			continue
		var cfg: Dictionary = a.cfg
		var locked: bool = game.sys.on(str(cfg.get("lock", "")))
		var was_live: bool = a.live
		a.fired = true
		if not was_live or locked:
			continue
		var p = world.tag(cfg.get("piece", ""))
		var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else game.drone.global_position
		game.incident("actuator", lid)
		game.say("actuator_jerk", at, cfg.get("piece", ""))
		game.fx.sparks(at, Vector2.UP, 20, Pal.heat(1.0, 2.0), 300.0, 0.4, PI)
		game.shake(0.5)
		game.sfx.play("snap")
		if p != null:
			game._dent(p, minf(p.cond, 0.5), "dv_actuator")
			var push: Array = cfg.get("push", [0.0, 0.0])
			if push[0] != 0.0 or push[1] != 0.0:
				pending.append({"tag": cfg.get("piece", ""), "push": Vector2(push[0], push[1]), "t": 0.0})
		var hit = world.tag(cfg.get("hits", ""))
		if hit != null and not hit.gone:
			game._dent(hit, minf(hit.cond, 0.35), "dv_actuator")
		game.lose("loss_actuator", 4000.0, at + Vector2(0, -40))


func _magnets(_dt: float) -> void:
	for t in mags:
		var m: Dictionary = mags[t]
		if m.k <= 0.01:
			continue
		var p = world.tag(t)
		if p == null or p.gone:
			continue
		var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
		var r: float = m.r * Geom.M
		var drone = game.drone
		# a drone just launched from the bay is still on its own thrust
		if drone != null and drone.alive and drone.spawn_t > 2.5:
			var d: Vector2 = c - drone.global_position
			var dist := d.length()
			if dist < r and dist > 1.0:
				drone.apply_central_force(d / dist * 2600.0 * m.k * (1.0 - dist / r))
				# within reach of the head itself (its centre is over a metre inside)
				if dist < 1.7 * Geom.M and hit_cd <= 0.0:
					hit_cd = 3.0
					game.incident("magnet", t)
					game.hurt_drone(8.0, c, "hurt_magnet", "magnet", 2.0)
					game.say("magnet_pull", c, t)
		for b in world.bodies:
			if not is_instance_valid(b) or b.pieces.has(p):
				continue
			var d2: Vector2 = c - b.global_position
			var dist2 := d2.length()
			if dist2 < r and dist2 > 1.0 and b.mass < 600.0:
				b.apply_central_force(d2 / dist2 * 900.0 * m.k * (1.0 - dist2 / r))


func _preloads() -> void:
	for l in loads:
		if not l.alive or l.fired:
			continue
		if _joint(l.tag) != null:
			continue
		l.alive = false
		var cfg: Dictionary = l.cfg
		var pinned := false
		for pt in cfg.get("pins", []):
			var pj = _joint(pt)
			if pj != null:
				pinned = true
				world.kill_joint(pj)
		var kpa := 0.0
		var vk: String = cfg.get("vessel", "")
		if vk != "" and game.sys.vols.has(vk):
			kpa = game.sys.P(vk)
		var held: bool = pinned or kpa > float(cfg.get("kpa", 300.0))
		if not held:
			continue
		l.fired = true
		var push := Vector2(cfg.get("push", [0.0, -1.0])[0], cfg.get("push", [0.0, -1.0])[1])
		pending.append({"tag": cfg.get("piece", ""), "push": push * (1.6 if pinned else 1.0), "t": 0.0})
		var p = world.tag(cfg.get("piece", ""))
		var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else game.drone.global_position
		game.incident("preload", l.tag)
		game.say("preload_snap", at, cfg.get("piece", ""))
		game.fx.sparks(at, Vector2.UP, 24, Pal.heat(1.0, 2.0), 320.0, 0.4, PI)
		game.shake(0.6)
		game.sfx.play("snap")
		if p != null:
			game._dent(p, minf(p.cond, 0.45), "dv_preload")
		# and what it is thrown into
		var hit = world.tag(cfg.get("hits", ""))
		if hit != null and not hit.gone:
			game._dent(hit, minf(hit.cond, 0.4), "dv_preload")
		game.lose("loss_preload", 3000.0, at + Vector2(0, -40))


# a pair of heavy parts that must come off together (or with the hull supported)
func _off(tag: String) -> bool:
	var p = world.tag(tag)
	return p == null or p.gone or p.body != null


func _balance() -> void:
	if balance.is_empty():
		return
	var sup: String = balance.get("support", "")
	if sup != "" and game.sys.on(sup):
		return
	var pairs: Array = balance.get("pairs", [])
	for i in pairs.size():
		if twisted.has(i):
			continue
		var pr: Array = pairs[i]
		var a_off := _off(pr[0])
		var b_off := _off(pr[1])
		if a_off == b_off:
			continue
		twisted[i] = true
		var left: String = pr[1] if a_off else pr[0]
		var mounts: Array = (pr[3] if a_off else pr[2]) if pr.size() > 3 else []
		var p = world.tag(left)
		var at: Vector2 = world.frame(p) * Geom.centroid(p.poly) if p != null else game.drone.global_position
		game.incident("imbalance", left)
		game.say("hull_twist", at, left)
		game.shake(0.7)
		game.sfx.play("snap")
		if p != null and not p.gone:
			game._dent(p, minf(p.cond, 0.6), "dv_twist")
		for t in mounts:
			var m = world.tag(str(t))
			if m != null and not m.gone:
				game._dent(m, minf(m.cond, 0.5), "dv_twist")
		game.lose("loss_twist", 3500.0, at + Vector2(0, -40))


func _impulses(dt: float) -> void:
	for e in pending:
		e.t += dt
		var p = world.tag(e.tag)
		if p == null or p.gone:
			e.t = 99.0
			continue
		if p.body != null and is_instance_valid(p.body):
			p.body.apply_central_impulse(e.push * p.body.mass * 3.0 * Geom.M)
			e.t = 99.0
	pending = pending.filter(func(e): return e.t < 2.0)
