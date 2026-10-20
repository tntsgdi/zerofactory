extends Node2D
# A telescope's primary mirror (OB-90 "Sky-Eye", design/ships/02_新设计十艘_设计稿.md:
# "the primary mirror's segments are very dear and fragile; cutting near the mirror
# throws metal dust on it unless the dust cover is on; a segment taken off with its
# actuators unlocked drops and cracks; the segments come off from the outer ring in").
# A ship file's "optics":
#   {"segments": {piece: {"ring": 1 inner .. n outer, "half": "U" or "L", "act": its actuator}},
#    "locks": {"1": the switch that locks ring 1's actuators, ...}, "mcc": the mirror
#    control cabinet (a lock only latches while it has power), "radius": metres around
#    a cut that its dust reaches, "dust": what a segment loses to one cut, "dust_min":
#    how far dust alone takes it down,
#    "cover": {"roller": the roller piece, "switch": the cover's switch, "len": metres
#    of cover below the roller, "time": seconds to run it all the way down}}
#   A cut within the radius of an uncovered segment still on the mirror: dust on it.
#   A segment freed with its ring unlocked: it drops out of its seat and cracks.
#   A segment freed while a segment further out on its half is still on the mirror:
#   that outer segment's edge was carried by this one, and chips.
#   The cover is a roll-down blind on a motor (it needs power to run); taken away
#   with its roller, it is gone.
# Saved: the locks, which segments dropped or chipped, how far down the cover is.

const DROP_KEEP := 0.15
const EDGE_KEEP := 0.4
const DUST_GAP := 0.4            # s: one stroke touching several pieces is one cut's dust

var game
var world
var cfg := {}
var locked := {}                 # ring (String) -> true once its actuators are latched
var dropped := {}
var chipped := {}
var cover := 0.0                 # 0 rolled up .. 1 all the way down
var dusted := 0                  # cuts that dusted the mirror
var _warned := {}
var _dust_t := -99.0
var _t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("optics", {})
	z_index = 40


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"locked": locked.keys(), "dropped": dropped.keys(), "chipped": chipped.keys(), "cover": cover, "dusted": dusted}


func load_state(d: Dictionary) -> void:
	for k in d.get("locked", []):
		locked[str(k)] = true
	for k in d.get("dropped", []):
		dropped[str(k)] = true
	for k in d.get("chipped", []):
		chipped[str(k)] = true
	cover = float(d.get("cover", 0.0))
	dusted = int(d.get("dusted", 0))
	queue_redraw()


func on_mirror(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and p.body == null


func ring_locked(r) -> bool:
	# a ship file's numbers come back as floats: ring 1.0 is the "1" of "locks"
	return locked.has(str(int(r)) if (r is float or r is int) else str(r))


func _powered(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and game.sys.piece_volts(p) > 1.0


# what is left of the mirror's reflectance, % (the segments still on it)
func reflect() -> float:
	var s := 0.0
	var n := 0
	for t in cfg.get("segments", {}):
		if on_mirror(str(t)):
			s += world.tag(str(t)).cond
			n += 1
	return s / n * 100.0 if n > 0 else 0.0


func unsafe() -> Array:
	var out: Array = []
	for r in cfg.get("locks", {}):
		if not ring_locked(r) and _ring_left(int(r)):
			out.append("mirror ring %s unlocked" % r)
	return out


# for tests/salvage_bot.gd: the switches to throw before anything comes off, while the
# cabinet still has power
func bot_prep() -> Array:
	var out: Array = []
	for r in cfg.get("locks", {}):
		var sw: String = str(cfg.locks[r])
		if not ring_locked(r) and not game.sys.on(sw) and _ring_left(int(r)):
			out.append([sw, "mirror ring %s actuators locked" % r, 2.0])
	# a lock thrown with the cabinet dead: the berth's supply on, and it latches
	if hold_power() and not _powered(str(cfg.get("mcc", ""))):
		for id in world.ctrls:
			var c = world.ctrls[id]
			if c.kind == "socket" and c.target == "aux" and not c.state:
				out.append([id, "berth supply on %s for the mirror cabinet" % id, 2.5])
				break
	return out


# for tests/salvage_bot.gd: the bus stays up until every ring is locked (the locks
# need the cabinet's power)
func hold_power() -> bool:
	for r in cfg.get("locks", {}):
		if not ring_locked(r) and _ring_left(int(r)):
			return true
	return false


# for tests/salvage_bot.gd: the segments first, from the outer ring in (a contract for
# part of the ship that wants an inner segment gets the ones outside it taken too)
func bot_order(order: Array) -> Array:
	var segs: Dictionary = cfg.get("segments", {})
	var seg_ids: Array = []
	var acts := {}
	for t in segs:
		acts[str(segs[t].get("act", ""))] = str(t)
	for id in order:
		var tg: String = world.pieces[id].tag
		if segs.has(tg):
			seg_ids.append(id)
		elif acts.has(tg):
			# an actuator comes away with its segment on it: the segment first
			var sp = world.tag(acts[tg])
			if sp != null and on_mirror(sp.tag) and not seg_ids.has(sp.id):
				seg_ids.append(sp.id)
	for id in seg_ids.duplicate():
		var e: Dictionary = segs[world.pieces[id].tag]
		for t in segs:
			var o = world.tag(str(t))
			if o != null and not seg_ids.has(o.id) and on_mirror(str(t)) and str(segs[t].half) == str(e.half) and int(segs[t].ring) > int(e.ring):
				seg_ids.append(o.id)
	seg_ids.sort_custom(func(a, b): return int(segs[world.pieces[a].tag].ring) > int(segs[world.pieces[b].tag].ring))
	return seg_ids + order.filter(func(id): return not seg_ids.has(id))


func _ring_left(r: int) -> bool:
	var segs: Dictionary = cfg.get("segments", {})
	for t in segs:
		if int(segs[t].ring) == r and on_mirror(str(t)):
			return true
	return false


func _physics_process(dt: float) -> void:
	if not active():
		return
	_t += dt
	var mcc: String = str(cfg.get("mcc", ""))
	for r in cfg.get("locks", {}):
		var sw: String = str(cfg.locks[r])
		if ring_locked(r) or not game.sys.on(sw):
			continue
		var c = world.ctrls.get(sw)
		var at: Vector2 = world.ctrl_world(c) if c != null else Vector2.ZERO
		if _powered(mcc):
			locked[str(r)] = true
			game.say("mirror_locked", at, str(r))
			game.sfx.play("clank", at, 0.4)
		elif not _warned.has(sw):
			_warned[sw] = true
			game.say("mirror_lock_dead", at, str(r))
	# the cover's motor runs while its switch is on and it has power
	var cv: Dictionary = cfg.get("cover", {})
	if cv.is_empty():
		return
	var roller = world.tag(str(cv.get("roller", "")))
	if roller == null or roller.gone or roller.body != null:
		if cover > 0.0:
			cover = 0.0
			queue_redraw()
		return
	var want := 1.0 if game.sys.on(str(cv.get("switch", ""))) else 0.0
	if want != cover and _powered(roller.tag):
		cover = move_toward(cover, want, dt / maxf(1.0, float(cv.get("time", 12.0))))
		queue_redraw()


# the cover's lower edge, world y (the roller where it is rolled up)
func _cover_edge() -> Vector2:
	var cv: Dictionary = cfg.get("cover", {})
	var roller = world.tag(str(cv.get("roller", "")))
	if roller == null or roller.gone:
		return Vector2(INF, -INF)
	var top: Vector2 = world.frame(roller) * Geom.centroid(roller.poly)
	return top + Vector2(0, cover * float(cv.get("len", 16.0)) * Geom.M)


func covered(p) -> bool:
	if cover <= 0.0:
		return false
	var bb := Geom.bbox(world.world_poly(p))
	return bb.end.y <= _cover_edge().y + 0.05 * Geom.M


func on_cut(p) -> void:
	if not active() or p == null:
		return
	var segs: Dictionary = cfg.get("segments", {})
	if segs.has(p.tag):
		return
	if _t - _dust_t < DUST_GAP:
		return
	var c: Vector2 = Geom.bbox(world.world_poly(p)).get_center()
	var rad: float = float(cfg.get("radius", 12.0)) * Geom.M
	var dust: float = float(cfg.get("dust", 0.05))
	var floor_k: float = float(cfg.get("dust_min", 0.35))
	var lost := 0.0
	var hit: Array = []
	for t in segs:
		var s = world.tag(str(t))
		if s == null or s.gone or s.body != null or not s.intact or s.cond <= floor_k:
			continue
		var sc: Vector2 = world.frame(s) * Geom.centroid(s.poly)
		if sc.distance_to(c) > rad or covered(s):
			continue
		var before: float = s.cond
		game._dent(s, maxf(floor_k, s.cond - dust), "dv_mirror_dust")
		lost += (before - s.cond) * s.value
		hit.append(sc)
	if hit.is_empty():
		return
	_dust_t = _t
	dusted += 1
	for sc in hit:
		game.fx.puff(sc, Vector2(-30.0, 0.0), 0.8, 10.0, 60.0, Pal.ink(0.12))
	game.incident("mirror_dust", p.tag)
	game.say("mirror_dust", c, str(hit.size()))
	game.note_loss("loss_mirror_dust", p.tag, lost)


func on_freed(b) -> void:
	if not active():
		return
	var segs: Dictionary = cfg.get("segments", {})
	for q in b.pieces:
		if not segs.has(q.tag) or dropped.has(q.tag) or chipped.has(q.tag + "#off"):
			continue
		chipped[q.tag + "#off"] = true
		var e: Dictionary = segs[q.tag]
		var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		if not ring_locked(e.ring) and q.intact:
			dropped[q.tag] = true
			var before: float = q.cond
			game._dent(q, minf(q.cond, DROP_KEEP), "dv_mirror_drop")
			game.incident("mirror_drop", q.tag)
			game.say("mirror_drop", at, q.tag)
			game.note_loss("loss_mirror_drop", q.tag, (before - q.cond) * q.value)
			game.sfx.play("crack", at, 0.8)
			game.fx.burst_shards(at, 8, 120.0, Pal.ink(0.7), 4.0)
		# the segments further out on this half lean on this one's edge
		var lost := 0.0
		for t in segs:
			var o: Dictionary = segs[t]
			if str(o.half) != str(e.half) or int(o.ring) <= int(e.ring) or chipped.has(str(t)) or not on_mirror(str(t)):
				continue
			var s = world.tag(str(t))
			if not s.intact:
				continue
			chipped[str(t)] = true
			var b0: float = s.cond
			game._dent(s, minf(s.cond, EDGE_KEEP), "dv_mirror_edge")
			lost += (b0 - s.cond) * s.value
		if lost > 0.0:
			game.incident("mirror_unsupported", q.tag)
			game.say("mirror_unsupported", at, q.tag)
			game.note_loss("loss_mirror_edge", q.tag, lost)


# ---------------------------------------------------------------- drawing

# the blind seen edge-on: a band hanging off the roller, folds across it
func _draw() -> void:
	if not active() or cover <= 0.0:
		return
	var cv: Dictionary = cfg.get("cover", {})
	var roller = world.tag(str(cv.get("roller", "")))
	if roller == null or roller.gone:
		return
	var top: Vector2 = world.frame(roller) * Geom.centroid(roller.poly)
	var bot := _cover_edge()
	var hw := 0.12 * Geom.M
	draw_line(top + Vector2(-hw, 0), bot + Vector2(-hw, 0), Pal.ink(0.45), 1.2, true)
	draw_line(top + Vector2(hw, 0), bot + Vector2(hw, 0), Pal.ink(0.3), 1.0, true)
	var n := int((bot.y - top.y) / (0.6 * Geom.M))
	for i in n:
		var y: float = top.y + (i + 1) * 0.6 * Geom.M
		draw_line(Vector2(top.x - hw, y), Vector2(top.x + hw, y - 0.1 * Geom.M), Pal.ink(0.2), 1.0, true)
	draw_line(bot + Vector2(-hw * 1.6, 0), bot + Vector2(hw * 1.6, 0), Pal.ink(0.6), 2.0, true)
