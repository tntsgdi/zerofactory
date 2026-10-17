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
# State that has to survive a save: which magnets are degaussed, which preloads went off.

var game
var world
var mags := {}                # piece tag -> {r, mT, k (1 = full field, 0 = degaussed)}
var loads := []               # [{tag, cfg, alive, fired}]
var pending := []             # [{tag, push, t}] impulses waiting for the part to come loose
var hit_cd := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	var mg: Dictionary = ship.get("magnets", {})
	for t in mg:
		mags[t] = {"r": float(mg[t].get("r", 4.0)), "mT": float(mg[t].get("mT", 60.0)), "k": 1.0}
	var pl: Dictionary = ship.get("preloads", {})
	for t in pl:
		loads.append({"tag": t, "cfg": pl[t], "alive": _joint(t) != null, "fired": false})


func save_state() -> Dictionary:
	var k := {}
	for t in mags:
		k[t] = mags[t].k
	var f: Array = []
	for l in loads:
		if l.fired:
			f.append(l.tag)
	return {"mags": k, "fired": f}


func load_state(d: Dictionary) -> void:
	for t in d.get("mags", {}):
		if mags.has(t):
			mags[t].k = float(d.mags[t])
	for l in loads:
		l.fired = l.tag in d.get("fired", [])
		l.alive = _joint(l.tag) != null


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
	_impulses(dt)


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
