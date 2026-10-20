extends Node
# A shut-down reactor still hot with radiation (exotic batch, NR-95 "Hearth": "the
# work is not taking the reactor apart but lifting the 5.6 t shield in front of the
# core first, and working in its shadow"). A ship file's "reactor":
#   {"core": piece, "rate": mSv/h at 1 m, "shields": [pieces that stop it],
#    "limit": the drone's dose (mSv) that faults its electronics,
#    "drums": {control drum: its mechanical lock}, "petals": [radiator petals],
#    "safe": °C the core must be under before the petals fold}
#   The core's dose rate falls with the square of the distance, and anything on a
#   shield's far side is in its shadow (a hundredth of it) — wherever the shield is,
#   on its mounts or hanging from the crane. The drone soaks it up: past the limit
#   its electronics fault (it is hurt) and the count starts again. A dose probe
#   reads the rate where it sits.
#   The core cut into breaks its cladding: the whole ship is contaminated (the rate
#   four times over), a fine. The core lifted with a control drum still unlocked:
#   the drum slips, a burst of dose over everything near. A radiator petal taken
#   off while the core (scripts/furnace.gd, its decay heat) is still over "safe"
#   deforms.
# Saved: the drone's dose, whether the core was breached, which drums slipped.

const SHADOW := 0.01
const TIME_K := 1.0 / 30.0     # a game second soaks up two minutes' dose
const BREACH_K := 4.0
const BREACH_FINE := 40000.0
const SLIP_DOSE := 120.0

var game
var world
var cfg := {}
var dose := 0.0
var breached := false
var slipped := false
var _warned := false
var _petals_hot := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("reactor", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"dose": dose, "breached": breached, "slipped": slipped}


func load_state(d: Dictionary) -> void:
	dose = float(d.get("dose", 0.0))
	breached = bool(d.get("breached", false))
	slipped = bool(d.get("slipped", false))


func _core():
	var p = world.tag(cfg.get("core", ""))
	return p if p != null and not p.gone else null


# the dose rate (mSv/h) at a point (px)
func rate_at(pos: Vector2) -> float:
	var c = _core()
	if c == null:
		return 0.0
	var src: Vector2 = world.frame(c) * Geom.centroid(c.poly)
	var r := maxf(1.0, src.distance_to(pos) / Geom.M)
	var k: float = float(cfg.get("rate", 3200.0)) / (r * r)
	if breached:
		k *= BREACH_K
	elif _shadowed(src, pos):
		k *= SHADOW
	return k


func _shadowed(a: Vector2, b: Vector2) -> bool:
	var polys: Array = []
	for t in cfg.get("shields", []):
		var p = world.tag(str(t))
		if p != null and not p.gone:
			polys.append(world.frame(p) * p.poly)
	if polys.is_empty():
		return false
	var n := int(a.distance_to(b) / (0.4 * Geom.M)) + 1
	for i in range(1, n):
		var q := a.lerp(b, float(i) / n)
		for pl in polys:
			if Geometry2D.is_point_in_polygon(q, pl):
				return true
	return false


# what a dose probe reads (mSv/h)
func probe(c) -> float:
	return rate_at(world.ctrl_world(c))


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	if game.drone == null or not game.drone.alive:
		return
	dose += rate_at(game.drone.global_position) * dt * TIME_K
	var lim: float = float(cfg.get("limit", 250.0))
	if dose > lim * 0.5 and not _warned:
		_warned = true
		game.say("dose_warn", game.drone.global_position, "%d" % int(dose))
	if dose > lim:
		dose = 0.0
		_warned = false
		game.hurt_drone(20.0, game.drone.global_position, "dose", "dose", 1.0)
		game.incident("dose_fault", "%d" % int(lim))
		game.say("dose_fault", game.drone.global_position, "")
	# the decay heat, as the petals feel it
	var hot: bool = game.furnace != null and game.furnace.active() and game.furnace.T > float(cfg.get("safe", 60.0))
	for t in cfg.get("petals", []):
		_petals_hot[t] = hot


func on_cut(p) -> void:
	if not active() or breached:
		return
	if p.tag == cfg.get("core", ""):
		breached = true
		var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
		game.incident("core_breach", p.tag)
		game.say("core_breach", at, p.tag)
		game.lose("loss_breach", BREACH_FINE, at + Vector2(0, -60))
		game.shake(0.5)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if q.tag == cfg.get("core", "") and not slipped:
			var loose: Array = []
			for d in cfg.get("drums", {}):
				if not game.sys.on(str(cfg.drums[d])):
					loose.append(d)
			if not loose.is_empty():
				slipped = true
				var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
				for d in loose:
					var dp = world.tag(str(d))
					if dp != null and not dp.gone and dp.intact:
						game._dent(dp, minf(dp.cond, 0.5), "dv_drum_slip")
				if game.drone.global_position.distance_to(at) < 25.0 * Geom.M:
					dose += SLIP_DOSE
				game.incident("drum_slip", ",".join(loose))
				game.say("drum_slip", at, q.tag)
		if (cfg.get("petals", []) as Array).has(q.tag) and _petals_hot.get(q.tag, false) and q.intact:
			var before: float = q.cond
			game._dent(q, minf(q.cond, 0.5), "dv_petal_hot")
			game.incident("petal_hot", q.tag)
			game.say("petal_hot", world.frame(q) * Geom.centroid(q.poly), q.tag)
			game.note_loss("loss_petal_hot", q.tag, (before - q.cond) * q.value)
