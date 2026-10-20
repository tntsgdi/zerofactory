extends Node
# A container wall that is the ship's beam (exotic batch, CF-90 "Hive": "there is
# no hold: the containers in their slots are the hull; unload a column in the
# wrong order and the whole wall bends, then falls"). A ship file's "boxbeam":
#   {"bays": [[the bay's containers, top tier first], ...], "support": the bay the
#    berth holds it by, "stiff": what a container adds to a bay's stiffness (the
#    chords alone 1), "limit": the bending a bay takes, "gauges": {probe: bay},
#    "rods": {rod tag: {"turnbuckle": its switch, "bays": [the bays it holds],
#    "hits": [what it whips into], "kn": its pull}}}
#   Each bay bends under the containers outboard of it (towards the ship's ends,
#   from the bay the berth holds it by), each the further out the more; it is as
#   stiff as the chords and the containers still in it. Empty a bay while the
#   bays beyond it are still full and it bends past what it takes: the wall
#   kinks there, and everything still on beyond it is damaged. So the wall comes
#   down from the ends inwards. A strain gauge reads its bay's bending (% of what
#   it takes).
#   Within a bay the containers come off from the top: one taken from under
#   others still on lets the stack above sag onto it (damaged).
#   A pretension rod cut or freed with its turnbuckle still tight whips loose,
#   into what it hits, and knocks the containers in its bays.
# Saved: which sides kinked, which rods snapped.

const KINK_KEEP := 0.5
const SAG_KEEP := 0.6
const SNAP_KEEP := 0.6

var game
var world
var cfg := {}
var kinked := {}              # "fwd"/"aft" -> true
var snapped := {}             # rod tag -> true
var _t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("boxbeam", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"kinked": kinked.keys(), "snapped": snapped.keys()}


func load_state(d: Dictionary) -> void:
	for k in d.get("kinked", []):
		kinked[str(k)] = true
	for k in d.get("snapped", []):
		snapped[str(k)] = true


func _on(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and p.body == null


func fill(b: int) -> int:
	var n := 0
	for t in cfg.bays[b]:
		if _on(str(t)):
			n += 1
	return n


# a bay's bending as a share of what it takes (1 = at the limit)
func bend(b: int) -> float:
	var sup := int(cfg.get("support", 0))
	if b == sup:
		return 0.0
	var m := 0.0
	var nb: int = cfg.bays.size()
	if b < sup:
		for i in range(0, b):
			m += fill(i) * float(b - i)
	else:
		for i in range(b + 1, nb):
			m += fill(i) * float(i - b)
	var k: float = 1.0 + float(cfg.get("stiff", 0.75)) * fill(b)
	return m / k / float(cfg.get("limit", 6.0))


# what a strain gauge reads (%)
func strain(probe: String) -> float:
	var b := int(cfg.get("gauges", {}).get(probe, -1))
	if b < 0:
		return 0.0
	return 100.0 * bend(b)


func rod_tight(rod: String) -> bool:
	var e: Dictionary = cfg.get("rods", {}).get(rod, {})
	return not snapped.has(rod) and _on(rod) and game.sys.on(str(e.get("turnbuckle", "")))


func rod_pull(rod: String) -> float:
	return float(cfg.rods[rod].get("kn", 80.0)) if rod_tight(rod) else 0.0


# what still has to be made safe (the rods' turnbuckles)
func unsafe() -> Array:
	var out: Array = []
	for r in cfg.get("rods", {}):
		if rod_tight(r):
			out.append("rod %s tight" % r)
	return out


# the order a careful hand takes the containers off: the bays from the ends
# inwards to the one the berth holds, each from the top
func unload_order() -> Array:
	var sup := int(cfg.get("support", 0))
	var nb: int = cfg.bays.size()
	var bays: Array = range(nb)
	bays.sort_custom(func(a, c): return absi(a - sup) > absi(c - sup) if absi(a - sup) != absi(c - sup) else a < c)
	var seq: Array = []
	for b in bays:
		for t in cfg.bays[b]:
			seq.append(str(t))
	return seq


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	_t += dt
	if _t < 0.2:
		return
	_t = 0.0
	var sup := int(cfg.get("support", 0))
	for b in cfg.bays.size():
		var side := "fwd" if b < sup else "aft"
		if b == sup or kinked.has(side):
			continue
		if bend(b) > 1.0:
			_kink(b, side)


func _kink(b: int, side: String) -> void:
	kinked[side] = true
	var lost := 0.0
	var at := Vector2.ZERO
	var n := 0
	for i in cfg.bays.size():
		if (side == "fwd" and i >= b) or (side == "aft" and i <= b):
			continue
		for t in cfg.bays[i]:
			var p = world.tag(str(t))
			if p == null or p.gone or p.body != null or not p.intact:
				continue
			var before: float = p.cond
			game._dent(p, minf(p.cond, KINK_KEEP), "dv_kink")
			lost += (before - p.cond) * p.value
			at += world.frame(p) * Geom.centroid(p.poly)
			n += 1
	if n > 0:
		at /= float(n)
	game.incident("beam_kink", "%s %d" % [side, b])
	game.say("beam_kink", at, "")
	game.note_loss("loss_kink", "", lost)
	game.shake(0.8)
	game.sfx.play("snap")


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		# a container taken from under others still on
		for bay in cfg.bays:
			var i: int = bay.find(q.tag)
			if i <= 0:
				continue
			var lost := 0.0
			for k in range(0, i):
				var p = world.tag(str(bay[k]))
				if p == null or p.gone or p.body != null or not p.intact:
					continue
				var before: float = p.cond
				game._dent(p, minf(p.cond, SAG_KEEP), "dv_sag")
				lost += (before - p.cond) * p.value
			if lost > 0.0:
				game.incident("stack_sag", q.tag)
				game.say("stack_sag", world.frame(q) * Geom.centroid(q.poly), q.tag)
				game.note_loss("loss_sag", q.tag, lost)
		_rod(q)


func on_cut(p) -> void:
	if active():
		_rod(p)


func _rod(p) -> void:
	var rods: Dictionary = cfg.get("rods", {})
	if not rods.has(p.tag) or snapped.has(p.tag):
		return
	var e: Dictionary = rods[p.tag]
	if not game.sys.on(str(e.get("turnbuckle", ""))):
		return
	snapped[p.tag] = true
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var lost := 0.0
	var hit: Array = e.get("hits", []).duplicate()
	for bi in e.get("bays", []):
		hit.append_array(cfg.bays[int(bi)])
	for t in hit:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, SNAP_KEEP), "dv_rod_snap")
		lost += (before - q.cond) * q.value
	game.incident("rod_snap", p.tag)
	game.say("rod_snap", at, p.tag)
	game.note_loss("loss_rod_snap", p.tag, lost)
	game.shake(0.6)
	game.sfx.play("snap")
