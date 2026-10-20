extends Node
# A long spine that carries the tail (ARK-01 "Voyager", design/ships/ARK-01_远航者_设计稿.md
# 4-5: "the tail - reactor, engines, propellant - hangs on the 440 m spine; its
# chord trusses are the load path, and a chord cut puts the whole tail on what is
# left"). A ship file's "spine":
#   {"segments": {seg: {"chords": [pieces], "x1": m its aft end}}, "order": [segs, bow
#    to stern], "hung_x": m (what lies aft of it hangs on the spine), "cap": t one
#    chord carries, "gauges": {probe: seg}, "hits": {seg: [what its tear damages]}}
#   Each segment carries the weight of everything still on the ship aft of both its
#   end and "hung_x", shared by its chords that are still whole (one cut into is
#   no longer whole). Past what they take, the segment tears: the tail sags and
#   twists on it, and what "hits" names (and the hung equipment) is damaged.
#   So the weight comes off the tail first, or the chords are cut last.
# Saved: which chords were cut, which segments tore.

const TEAR_KEEP := 0.5
const TUBE := 0.15            # what the pressure tube alone carries, in chords
const SAG_KEEP := 0.7

var game
var world
var cfg := {}
var cut := {}
var torn := {}
var hung: Array = []        # [x m, piece], aft first
var _w := {}
var _t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("spine", {})
	if cfg.is_empty():
		return
	var hx: float = float(cfg.get("hung_x", 0.0))
	for id in world.order:
		var p = world.pieces[id]
		var x: float = Geom.centroid(p.poly).x / Geom.M
		if x > hx:
			hung.append([x, p])
	hung.sort_custom(func(a, b): return a[0] > b[0])
	_weigh()


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"cut": cut.keys(), "torn": torn.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("cut", []):
		cut[str(t)] = true
	for s in d.get("torn", []):
		torn[str(s)] = true
	_weigh()


# t of what still hangs aft of x (m)
func weight_aft(x: float) -> float:
	var m := 0.0
	for h in hung:
		if float(h[0]) <= x:
			break
		var p = h[1]
		if not p.gone and p.body == null:
			m += p.mass
	return m


func chords_whole(seg: String) -> int:
	var n := 0
	for t in cfg.segments[seg].get("chords", []):
		var p = world.tag(str(t))
		if p != null and not p.gone and p.body == null and not cut.has(t):
			n += 1
	return n


# what the segment's chords carry, as a share of what they take (1 = at the limit)
func stress(seg: String) -> float:
	var n := chords_whole(seg)
	var w: float = float(_w.get(seg, 0.0))
	if torn.has(seg):
		return 0.0
	# with no chord left the tube itself still takes a little (a few loose pieces aft)
	return w / (maxf(float(n), TUBE) * float(cfg.get("cap", 60.0)))


func gauge(probe: String) -> float:
	var seg: String = cfg.get("gauges", {}).get(probe, "")
	return 0.0 if seg == "" or torn.has(seg) else stress(seg) * 100.0


# what still has to be made safe: a segment that one more chord cut would tear
func unsafe() -> Array:
	var out: Array = []
	for seg in cfg.get("order", []):
		if torn.has(seg):
			continue
		var n := chords_whole(seg)
		if n >= 1 and float(_w.get(seg, 0.0)) > maxf(n - 1.0, TUBE) * float(cfg.get("cap", 60.0)):
			out.append("spine %s %.0f t on %d" % [seg, _w.get(seg, 0.0), n])
	return out


# a chord one more cut would overload (the bot keeps off these)
func carrying(tag: String) -> bool:
	if not active() or cut.has(tag):
		return false
	for seg in cfg.segments:
		if (cfg.segments[seg].get("chords", []) as Array).has(tag) and not torn.has(seg):
			var n := chords_whole(seg)
			return float(_w.get(seg, 0.0)) > maxf(n - 1.0, TUBE) * float(cfg.get("cap", 60.0))
	return false


func _weigh() -> void:
	for seg in cfg.get("segments", {}):
		_w[seg] = weight_aft(maxf(float(cfg.segments[seg].get("x1", 0.0)), float(cfg.get("hung_x", 0.0))))


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	_weigh()
	_check()


func _check() -> void:
	for seg in cfg.get("order", []):
		if not torn.has(seg) and stress(seg) > 1.0:
			_tear(seg)


func _tear(seg: String) -> void:
	torn[seg] = true
	var lost := 0.0
	var at: Vector2 = game.drone.global_position
	var tags: Array = cfg.get("hits", {}).get(seg, []).duplicate()
	for t in tags:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		at = world.frame(q) * Geom.centroid(q.poly)
		var before: float = q.cond
		game._dent(q, minf(q.cond, TEAR_KEEP), "dv_spine_tear")
		lost += (before - q.cond) * q.value
	# the tail sags on it: everything hung aft of the tear is knocked
	var x1: float = float(cfg.segments[seg].get("x1", 0.0))
	for h in hung:
		if float(h[0]) <= x1:
			break
		var q = h[1]
		if q.gone or q.body != null or q.cls != "equip" or not q.intact:
			continue
		var b0: float = q.cond
		game._dent(q, minf(q.cond, SAG_KEEP), "dv_spine_sag")
		lost += (b0 - q.cond) * q.value
	game.incident("spine_tear", seg)
	game.say("spine_tear", at, seg)
	game.note_loss("loss_spine_tear", seg, lost)
	game.shake(1.4)
	game.sfx.play("crack")


func on_cut(p) -> void:
	if not active() or cut.has(p.tag):
		return
	for seg in cfg.segments:
		if (cfg.segments[seg].get("chords", []) as Array).has(p.tag):
			cut[p.tag] = true
			_weigh()
			if not torn.has(seg) and stress(seg) > 1.0:
				_tear(seg)
			elif stress(seg) > 0.8:
				game.say("spine_strain", world.frame(p) * Geom.centroid(p.poly), seg)
			return


func on_freed(b) -> void:
	if not active():
		return
	_weigh()
	_check()
