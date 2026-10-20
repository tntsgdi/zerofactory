extends Node
# Drones parked live in their bays (R2 fleet, CV-138 "Wayfarer": "the main battery,
# the gantry and every drone each carry their own charge; a drone kept whole is
# worth more than its weight in scrap"). A ship file's "drones" section:
#   {drone tag: {"pack": the tag of its battery pack (an isolated supply, with its
#    own isolator on the drone), "kick": [x, y] m/s}}
#   A drone freed from its cradle (its body come loose) with its pack still on it
#   and live wakes: its rotors spin up and throw it off along "kick" into whatever
#   is near, a knock that badly damages it (and the pack). Its pack's isolator open
#   (or the pack taken off it first), it comes away quietly.
# Saved: which drones woke.

const DENT := 0.5             # what a waking drone is left at
const KICK_T := 0.6           # s the rotors run before the drone's safety cuts them

var game
var world
var cfg := {}
var woke := {}                # drone tag -> true
var _kick: Array = []         # [drone tag, velocity px/s, seconds left]


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("drones", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"woke": woke.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("woke", []):
		woke[str(t)] = true


# the drone's own pack still on it (in the same loose body) and live
func live_pack(tag: String, b = null) -> bool:
	var e: Dictionary = cfg.get(tag, {})
	var pk = world.tag(str(e.get("pack", "")))
	if pk == null or pk.gone or not pk.intact or not game.sys.iso_live(pk.tag):
		return false
	if b == null:
		var dr = world.tag(tag)
		return dr != null and not dr.gone and pk.body == dr.body
	return b.pieces.has(pk)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if not cfg.has(q.tag) or woke.has(q.tag) or not q.intact or not live_pack(q.tag, b):
			continue
		woke[q.tag] = true
		var lost := 0.0
		for p in b.pieces:
			if p.cls == "equip" and p.intact and (p.tag == q.tag or p.tag == cfg[q.tag].pack):
				var before: float = p.cond
				game._dent(p, minf(p.cond, DENT), "dv_drone_woke")
				lost += (before - p.cond) * p.value
		var k: Array = cfg[q.tag].get("kick", [0.0, -2.0])
		_kick.append([q.tag, Vector2(float(k[0]), float(k[1])) * Geom.M, KICK_T])
		var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		game.incident("drone_woke", q.tag)
		game.say("drone_woke", at, q.tag)
		game.note_loss("loss_drone_woke", q.tag, lost)
		game.fx.sparks(at, Vector2.UP, 14, Pal.tint(Pal.VOLT, 1.0, 2.0), 220.0, 0.35, PI)
		game.shake(0.35)
		game.sfx.play("zap_small")


func _physics_process(dt: float) -> void:
	if _kick.is_empty():
		return
	var left: Array = []
	for e in _kick:
		var dr = world.tag(e[0])
		if dr == null or dr.body == null or not is_instance_valid(dr.body) or dr.body.capture != null:
			continue
		dr.body.linear_velocity = e[1]
		dr.body.angular_velocity = 0.8
		e[2] = float(e[2]) - dt
		if float(e[2]) > 0.0:
			left.append(e)
	_kick = left
