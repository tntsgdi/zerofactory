extends Node
# A cargo module clamped between two hulls (exotic batch, CH-110 "Bookend": "two 98 m
# hulls with a 40 m prefab habitat clamped between them by eight hydraulic clamps,
# four beams in tension holding the hulls apart; beam 2 is cracked"). A ship file's
# "sandwich":
#   {"rooms": the cargo's rooms, "spring_kpa": over this the cargo springs when a clamp lets go,
#    "upper": [hold switches over the cargo], "lower": [hold switches under it],
#    "clamps": {clamp piece: its hold switch},
#    "spring_hits", "twist_hits": [what the cargo springing / twisting knocks],
#    "cracked": {"pieces": [the cracked beam's pieces], "guards": [the hold switches
#     beside it], "hits": [what the torn hull carries]},
#    "loads": {load cell: {"base": kN, "k": extra on a cracked beam, "clamps": [hold
#     switches it carries the load of]}}}
#   A clamp lets go when its hold switch goes off. If the cargo still holds over
#   "spring_kpa" it springs. If the clamps over it and under it are let go unevenly
#   (two more off on one side than the other) the cargo twists and the cracked beam
#   breaks. The cracked beam taken out while a clamp beside it still holds tears the
#   upper hull. A clamp freed while its hold is still on springs its jaws.
# Saved: which of these happened.

const KEEP := 0.6

var game
var world
var cfg := {}
var sprung := false
var twisted := false
var torn := false
var _was := {}


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("sandwich", {})
	for t in _holds():
		_was[t] = true


func active() -> bool:
	return not cfg.is_empty()


func _holds() -> Array:
	var out: Array = []
	out.append_array(cfg.get("upper", []))
	out.append_array(cfg.get("lower", []))
	return out


func save_state() -> Dictionary:
	return {"sprung": sprung, "twisted": twisted, "torn": torn}


func load_state(d: Dictionary) -> void:
	sprung = bool(d.get("sprung", false))
	twisted = bool(d.get("twisted", false))
	torn = bool(d.get("torn", false))
	for t in _holds():
		_was[t] = game.sys.on(str(t))


func cargo_kpa() -> float:
	var p := 0.0
	for r in cfg.get("rooms", []):
		p = maxf(p, game.sys.P(str(r)))
	return p


func _off(side: String) -> int:
	var n := 0
	for t in cfg.get(side, []):
		if not game.sys.on(str(t)):
			n += 1
	return n


# what a load cell reads, kN
func load(lc: String) -> float:
	var e: Dictionary = cfg.get("loads", {}).get(lc, {})
	var cl: Array = e.get("clamps", [])
	var v: float = float(e.get("base", 120.0))
	if not cl.is_empty():
		var held := 0
		for t in cl:
			if game.sys.on(str(t)):
				held += 1
		v *= float(held) / cl.size()
	if e.has("k"):
		v = 0.0 if twisted else v * float(e.k)
	return v


func unsafe() -> Array:
	var out: Array = []
	for t in _holds():
		if game.sys.on(str(t)):
			out.append("clamp %s holding" % t)
	return out


func _physics_process(_dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var let_go := false
	for t in _holds():
		var now: bool = game.sys.on(str(t))
		if _was.get(t, true) and not now:
			let_go = true
		_was[t] = now
	if not let_go:
		return
	if not sprung and cargo_kpa() > float(cfg.get("spring_kpa", 20.0)):
		sprung = true
		_hit(cfg.get("spring_hits", []), KEEP, "cargo_spring")
	if not twisted and absi(_off("upper") - _off("lower")) >= 2:
		twisted = true
		_hit(cfg.get("twist_hits", []), KEEP, "cargo_twist")


func _hit(tags: Array, keep: float, why: String) -> void:
	var lost := 0.0
	var at: Vector2 = game.drone.global_position
	for t in tags:
		var q = world.tag(str(t))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, keep), "dv_" + why)
		lost += (before - q.cond) * q.value
		at = world.frame(q) * Geom.centroid(q.poly)
	game.incident(why, "")
	game.say(why, at, "")
	game.note_loss("loss_" + why, "", lost)
	game.shake(0.7)
	game.sfx.play("snap")


func _check(p) -> void:
	var cr: Dictionary = cfg.get("cracked", {})
	if not torn and (cr.get("pieces", []) as Array).has(p.tag):
		for t in cr.get("guards", []):
			if game.sys.on(str(t)):
				torn = true
				_hit(cr.get("hits", []), 0.5, "hull_torn")
				break
	var hold: String = str(cfg.get("clamps", {}).get(p.tag, ""))
	if hold != "" and game.sys.on(hold) and p.cls == "equip" and p.intact:
		var before: float = p.cond
		game._dent(p, minf(p.cond, 0.4), "dv_clamp_spring")
		game.incident("clamp_spring", p.tag)
		game.say("clamp_spring", world.frame(p) * Geom.centroid(p.poly), p.tag)
		game.note_loss("loss_clamp_spring", p.tag, (before - p.cond) * p.value)


func on_cut(p) -> void:
	if active():
		_check(p)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		_check(q)
