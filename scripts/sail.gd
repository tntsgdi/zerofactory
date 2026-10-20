extends Node
# A light sail held flat by its stays (exotic batch, SA-200 "Kite": "the whole ship
# is a sail; the only thing of value is the gondola, the sail an obstacle to take
# down"). A ship file's "sail":
#   {"quads": {quadrant: its winch's brake control (on: holding the corner taut)},
#    "panels": {film panel: {"quad": quadrant, "next": [the panels either side]}},
#    "stays": {stay or brace: {"quad": quadrant, "panels": [the panels on it],
#      "hits": [what its spar whips into]}},
#    "torn": [panels already torn], "ground": the earthing clamp's control}
#   The film can't be cut clean: cut, a panel tears (worthless), and while its
#   quadrant is still taut the tear runs into the panels either side; a panel next
#   to one already torn tears through too. Freed while its quadrant is taut, a
#   panel is pulled apart; slack, it comes away whole (a roll).
#   A stay or brace cut or freed with its quadrant taut snaps: the panels on it
#   tear and the corner spar whips into the gondola.
#   The film holds a static charge until the earthing clamp is on: a panel freed or
#   cut before then discharges into the drone.
# Saved: which panels tore, which stays snapped.

var game
var world
var cfg := {}
var torn := {}                # panel tag -> true
var snapped := {}             # stay tag -> true


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("sail", {})
	for t in cfg.get("torn", []):
		torn[str(t)] = true


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"torn": torn.keys(), "snapped": snapped.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("torn", []):
		torn[str(t)] = true
	for t in d.get("snapped", []):
		snapped[str(t)] = true


func taut(q: String) -> bool:
	return game.sys.on(str(cfg.get("quads", {}).get(q, "")))


func grounded() -> bool:
	return game.sys.on(str(cfg.get("ground", "")))


# a stay's pull (kN): what a tension gauge on it reads
func pull(stay: String) -> float:
	var e: Dictionary = cfg.get("stays", {}).get(stay, {})
	if e.is_empty() or snapped.has(stay):
		return 0.0
	var p = world.tag(stay)
	if p == null or p.gone or p.body != null:
		return 0.0
	return float(e.get("kn", 12.0)) if taut(str(e.quad)) else 0.0


# what still has to be made safe
func unsafe() -> Array:
	var out: Array = []
	for q in cfg.get("quads", {}):
		if taut(q):
			out.append("sail %s taut" % q)
	if not grounded():
		out.append("sail not earthed")
	return out


func _tear(tags: Array, why: String) -> void:
	var lost := 0.0
	var at := Vector2.ZERO
	var n := 0
	for t in tags:
		if torn.has(t):
			continue
		var p = world.tag(t)
		if p == null or p.gone:
			continue
		torn[t] = true
		lost += p.value * clampf(p.cond, 0.0, 1.0)
		p.value = 0.0
		p.intact = false
		p.cond = 0.0
		at += world.frame(p) * Geom.centroid(p.poly)
		n += 1
	if n == 0:
		return
	at /= float(n)
	game.incident("film_tear", why)
	game.say("film_tear", at, why)
	game.note_loss("loss_film", why, lost)
	game.sfx.play("snap")
	world.redraw_all()


# a panel torn: the tear runs on while its quadrant is taut, and through any
# panel beside one already torn
func _spread(t: String) -> void:
	var e: Dictionary = cfg.panels[t]
	var run: Array = [t]
	if taut(str(e.quad)):
		run.append_array(e.get("next", []))
	for nb in e.get("next", []):
		if torn.has(nb):
			for nn in cfg.panels.get(nb, {}).get("next", []):
				if not run.has(nn):
					run.append(nn)
	_tear(run, t)


func _zap(p) -> void:
	if grounded():
		return
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	game.fx.arc(at, game.drone.global_position, 0.3, 0.8)
	game.hurt_drone(12.0, at, "static", "static", 1.0)
	game.incident("static_zap", p.tag)
	game.say("static_zap", at, p.tag)


func on_cut(p) -> void:
	if not active():
		return
	if cfg.panels.has(p.tag):
		_zap(p)
		if not torn.has(p.tag):
			_spread(p.tag)
	elif cfg.stays.has(p.tag):
		_snap(p.tag)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if cfg.panels.has(q.tag):
			_zap(q)
			if not torn.has(q.tag) and taut(str(cfg.panels[q.tag].quad)):
				_spread(q.tag)
		elif cfg.stays.has(q.tag):
			_snap(q.tag)


func _snap(t: String) -> void:
	var e: Dictionary = cfg.stays[t]
	if snapped.has(t) or not taut(str(e.quad)):
		return
	snapped[t] = true
	var p = world.tag(t)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	game.incident("stay_snap", t)
	game.say("stay_snap", at, t)
	var lost := 0.0
	for h in e.get("hits", []):
		var q = world.tag(str(h))
		if q == null or q.gone or q.cls != "equip" or not q.intact:
			continue
		var before: float = q.cond
		game._dent(q, minf(q.cond, 0.5), "dv_spar_whip")
		lost += (before - q.cond) * q.value
	if lost > 0.0:
		game.note_loss("loss_spar_whip", t, lost)
	game.shake(0.7)
	_tear(e.get("panels", []), t)
