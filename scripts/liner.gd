extends Node
# A liner's escape pods and its observation glass (PS-12 "Dawn": "the pods' launch
# clamps carry explosive bolts; the observation glass holds the hall's pressure").
# A ship file's "liner" section:
#   {"pods": {pod tag: {"clamps": [joint tags], "charge": the pyrotechnic charge,
#     "bolt": the joint that holds the charge, "circuit": its firing capacitor (an
#     isolated supply, cabled to the charge by "lead"), "kick": [x, y] m/s}},
#    "glazing": {"room": the hall, "panes": [piece tags], "kpa": over this it blows out}}
#   A pod's launch clamp undone or cut (or its charge unbolted) while its charge is
#   still on its lead and its firing circuit live: the bolts fire and the pod is
#   thrown off (badly damaged). The circuit dead (its arming switch open, or never
#   charged) or the lead pulled, it comes away quietly; the charge itself is a
#   hazard for the hazard bay.
#   A pane freed while its hall still holds pressure is blown out and shatters.
# Saved: which pods fired, which panes blew out.

const FIRE_KEEP := 0.5

var game
var world
var cfg := {}
var fired := {}               # pod tag -> true
var blown := {}               # pane tag -> true
var _kick: Array = []         # [pod tag, velocity px/s, seconds left]


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("liner", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"fired": fired.keys(), "blown": blown.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("fired", []):
		fired[str(t)] = true
	for t in d.get("blown", []):
		blown[str(t)] = true


# the pod's charge still on its lead and its firing circuit live
func armed(pod: String) -> bool:
	var e: Dictionary = cfg.get("pods", {}).get(pod, {})
	var ch = world.tag(str(e.get("charge", "")))
	if ch == null or ch.gone or not ch.intact or not game.sys.iso_live(str(e.get("circuit", ""))):
		return false
	var l = world.lines.get(str(e.get("lead", "")))
	return l != null and l.alive


func _joint(tag: String):
	return game.mech._joint(tag) if game.mech != null else null


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	for pod in cfg.get("pods", {}):
		if fired.has(pod):
			continue
		var e: Dictionary = cfg.pods[pod]
		if not armed(pod):
			continue
		# a clamp's latch gone, or the charge's own bolt, with the circuit live
		var gone := false
		for jt in e.get("clamps", []) + [e.get("bolt", "")]:
			if str(jt) != "" and _joint(str(jt)) == null:
				gone = true
		if gone:
			_fire(pod)
	if _kick.is_empty():
		return
	var left: Array = []
	for k in _kick:
		var p = world.tag(k[0])
		if p == null or p.body == null or not is_instance_valid(p.body) or p.body.capture != null:
			continue
		p.body.linear_velocity = k[1]
		k[2] = float(k[2]) - dt
		if float(k[2]) > 0.0:
			left.append(k)
	_kick = left


func _fire(pod: String) -> void:
	fired[pod] = true
	var e: Dictionary = cfg.pods[pod]
	var p = world.tag(pod)
	var ch = world.tag(str(e.get("charge", "")))
	var at: Vector2 = world.frame(ch) * Geom.centroid(ch.poly) if ch != null else world.frame(p) * Geom.centroid(p.poly)
	# the charge is spent, every clamp latch blown
	if ch != null and not ch.gone:
		ch.intact = false
		ch.value = 0.0
	game.sys.drain_source(str(e.get("circuit", "")))
	for jt in e.get("clamps", []):
		var j = _joint(str(jt))
		if j != null:
			world.kill_joint(j)
	var lost := 0.0
	if p != null and not p.gone and p.intact:
		var before: float = p.cond
		game._dent(p, minf(p.cond, FIRE_KEEP), "dv_pod_fired")
		lost = (before - p.cond) * p.value
		var kk: Array = e.get("kick", [0.0, 3.0])
		_kick.append([pod, Vector2(float(kk[0]), float(kk[1])) * Geom.M, 0.5])
	game.incident("pod_fired", pod)
	game.say("pod_fired", at, pod)
	game.note_loss("loss_pod_fired", pod, lost)
	game.fx.flash(at, 140.0, 0.3, Pal.heat(1.0, 2.4))
	game.fx.sparks(at, Vector2.DOWN, 26, Pal.heat(1.0, 2.0), 340.0, 0.4, PI)
	game.shake(0.6)
	game.sfx.play("snap")
	world.redraw_all()


func on_freed(b) -> void:
	if not active():
		return
	var gz: Dictionary = cfg.get("glazing", {})
	if gz.is_empty():
		return
	var room: String = gz.get("room", "")
	if not game.sys.vols.has(room) or game.sys.P(room) <= float(gz.get("kpa", 20.0)):
		return
	for q in b.pieces:
		if not (gz.get("panes", []) as Array).has(q.tag) or blown.has(q.tag) or not q.intact:
			continue
		blown[q.tag] = true
		var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		var was: float = q.value * clampf(q.cond, 0.0, 1.0)
		q.intact = false
		q.value = 0.0
		game.incident("glass_blown", q.tag)
		game.say("glass_blown", at, q.tag)
		game.note_loss("loss_glass", q.tag, was)
		game.fx.burst_shards(at, 14, 220.0, Pal.ink(0.8), 6.0)
		game.sfx.play("snap")
		world.redraw_all()
