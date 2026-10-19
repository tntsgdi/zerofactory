class_name Munitions
extends Node
# Munitions that really go off (PT-34 "Falcon", design/ships/PT-34_隼鹰_设计稿.md,
# player 2026-10-17: "ammunition explodes"). A ship file's "munitions" section:
#   {"cook": {"r": m, "rate": °C/s, "at": °C}, "chain": m, "knock": px/s,
#    "flood": {valve control id: room}}
# What it adds to the explosives every ship already has (a hazard "explosive"
# piece blasts when the beam cuts into it or it goes into the furnace):
#   cook-off  the beam working within r of a shell heats it; at "at" it goes
#             off. Its temperature reads on inspection, and a "heat" test
#             point reads the hottest round in a room (the magazine).
#   knock     a round hitting something faster than "knock" goes off.
#   chain     a round that goes off sets off the live rounds within "chain"
#             a moment later, one after another (the magazine all at once).
#   flood     opening a flood valve wets every round in its room: no longer
#             afraid of heat or knocks, and worth nothing (they are scrap).
# Saved: which rooms are flooded, which rounds went off or are wet.

const COOK_R := 1.6
const COOK_RATE := 28.0
const COOK_AT := 120.0
const COOL_RATE := 6.0
const CHAIN_R := 3.0
const KNOCK := 340.0

var game
var world
var cfg := {}
var flooded := {}            # room -> true
var wet := {}                # piece id -> true
var pending: Array = []      # [piece id, seconds left] rounds about to go off
var _vel := {}               # body instance id -> last speed


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("munitions", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	var w: Array = []
	for id in wet:
		var p = world.pieces.get(id)
		if p != null and p.tag != "":
			w.append(p.tag)
	return {"flooded": flooded.keys(), "wet": w}


func load_state(d: Dictionary) -> void:
	for r in d.get("flooded", []):
		flooded[str(r)] = true
	for t in d.get("wet", []):
		var p = world.tag(str(t))
		if p != null:
			_wet(p)


func live(p) -> bool:
	return p != null and not p.gone and p.hazard == "explosive" and p.intact and not wet.has(p.id)


# a flood valve opened: every round in its room is wet from now on
func flood(ctrl_id: String) -> bool:
	var room: String = str(cfg.get("flood", {}).get(ctrl_id, ""))
	if room == "":
		return false
	flooded[room] = true
	for id in world.order:
		var p = world.pieces[id]
		if not p.gone and p.hazard == "explosive" and p.room == room:
			_wet(p)
	return true


func _wet(p) -> void:
	wet[p.id] = true
	p.temp = minf(p.temp, 20.0)
	p.value = 0.0
	p.set_meta("wet", true)


# the hottest round in a room (what a heat test point there reads)
func room_temp(room: String) -> float:
	var t := 20.0
	for id in world.order:
		var p = world.pieces[id]
		if live(p) and p.room == room:
			t = maxf(t, p.temp)
	return t


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var tl = game.tools
	var heated := {}
	if tl != null and tl.cutting and tl.in_material:
		heated = heat(tl.front, dt)
	var knock: float = float(cfg.get("knock", KNOCK))
	for id in world.order:
		var p = world.pieces[id]
		if not live(p):
			continue
		if not heated.has(p.id) and p.temp > 20.0:
			p.temp = maxf(20.0, p.temp - COOL_RATE * dt)
		# a loose round knocked hard (not one a recovery mouth is swallowing: its catch brakes it on purpose)
		if p.body != null and is_instance_valid(p.body) and p.body.capture == null:
			var k: int = p.body.get_instance_id()
			var v: float = p.body.linear_velocity.length()
			var was: float = float(_vel.get(k, v))
			if was - v > knock and not _pending(p.id):
				pending.append([p.id, 0.0])
			_vel[k] = v
		elif p.body != null and is_instance_valid(p.body):
			_vel.erase(p.body.get_instance_id())
	_tick(dt)


# the beam working at bp for dt: the live rounds within reach heat, the nearer the
# faster, and one hot enough is about to go off. Returns the rounds it heated.
func heat(bp: Vector2, dt: float) -> Dictionary:
	var r: float = float(cfg.get("cook", {}).get("r", COOK_R)) * Geom.M
	var rate: float = float(cfg.get("cook", {}).get("rate", COOK_RATE))
	var at: float = float(cfg.get("cook", {}).get("at", COOK_AT))
	var out := {}
	for id in world.order:
		var p = world.pieces[id]
		if not live(p):
			continue
		var d: float = (world.frame(p) * Geom.centroid(p.poly)).distance_to(bp)
		if d < r:
			p.temp += rate * dt * (1.0 - d / r * 0.6)
			out[p.id] = true
			if p.temp >= at and not _pending(p.id):
				pending.append([p.id, 0.0])
	return out


func _tick(dt: float) -> void:
	# rounds going off, one after another
	var left: Array = []
	for e in pending:
		e[1] = float(e[1]) - dt
		if e[1] > 0.0:
			left.append(e)
			continue
		var q = world.pieces.get(e[0])
		if live(q):
			_go_off(q)
	pending = left


func _pending(id: int) -> bool:
	for e in pending:
		if e[0] == id:
			return true
	return false


# it goes off: the ship's own blast (which sets the live rounds round it going, on_blast)
func _go_off(p) -> void:
	var c: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	game.say("cook_off", c)
	game._blast(p, c)
	p.intact = false


# a blast from anything else (a cut-into round, the furnace) sets the rest off too
func on_blast(p, at: Vector2) -> void:
	if not active():
		return
	var cr: float = float(cfg.get("chain", CHAIN_R)) * Geom.M
	var n := 0
	for id in world.order:
		var q = world.pieces[id]
		if q == p or not live(q) or _pending(q.id):
			continue
		var qc: Vector2 = world.frame(q) * Geom.centroid(q.poly)
		if qc.distance_to(at) < cr:
			n += 1
			pending.append([q.id, 0.12 + 0.06 * n])
