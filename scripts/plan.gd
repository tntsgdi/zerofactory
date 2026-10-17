class_name WorkPlan
extends Node
# Basic work plans (roadmap 3.5). While the operator makes a ship safe, each
# control worked and each hose put on or taken off is written down together
# with the readings that stood at that moment (which port read what, which
# test point read what). A contract finished without an incident turns that
# order into the work plan for its ship type, kept with the career.
#
# On the next ship of the type the plan can be run (the plan key): the berth
# does the steps one by one, as a machine, but before each step every reading
# the operator had then must be there now, taken on this ship and not gone
# stale since, and be no worse than it was then (a room that read empty must
# read empty, a circuit that read dead must read dead). Missing, stale or
# worse: it stops and says
# which, and goes on by itself once the operator has put it right. A control
# the plan names that is not on this ship stops it for good: the ship is not
# the one the plan was made on. The automation key (or the plan key) stops it
# at any time.

const STEP_TIME := 1.6           # s of sim time a step takes the machine

var game
var rec: Array = []              # this contract's order, as the operator did it
var steps: Array = []            # the plan being run
var i := 0
var running := false
var wait := ""                   # why it is not going on: a Txt key
var wait_arg := ""
var step_t := 0.0


func setup(g) -> void:
	game = g
	if g.career() and Career.usable():
		Career.load_or_new()
		steps = Career.data.get("plans", {}).get(g.ship_id, []).duplicate(true)


# the operator worked a control or a hose (never called for the plan's own steps)
func on_player(kind: String, c) -> void:
	if running or c == null:
		return
	var pre: Array = []
	for k in game.sys.readings:
		var r: Dictionary = game.sys.readings[k]
		if str(k).begins_with("L:") or str(k).begins_with("P:") or str(k).find("/") >= 0:
			continue
		if game.sys.stale(r):
			continue
		pre.append({"key": str(k), "kind": r.kind, "val": snappedf(float(r.val), 0.1)})
	# a door is never opened on the plan's word alone: the rooms behind it must
	# have been read, whether the operator read them that time or not
	if c.kind in ["door", "hatch"]:
		for room in _rooms_by(c):
			var port := _gas_port(room)
			if port == "" or pre.any(func(q): return q.key == port):
				continue
			pre.append({"key": port, "kind": "pressure", "val": snappedf(game.sys.P(room), 0.1)})
	rec.append({"do": kind, "ctrl": c.id, "pre": pre})


# the rooms on either side of a door's piece
func _rooms_by(c) -> Array:
	var out: Array = []
	var p = game.world.pieces.get(c.piece)
	if p == null:
		return out
	var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	for n in 12:
		var room: String = game.world.room_at(at + Vector2.from_angle(TAU * n / 12.0) * 0.8 * Geom.M)
		if room != "" and not room in out:
			out.append(room)
	return out


func _gas_port(room: String) -> String:
	for id in game.world.ctrls:
		var k = game.world.ctrls[id]
		if k.kind == "port" and k.medium == "gas" and k.target == room:
			return id
	return ""


# the contract ended clean: its order becomes the type's plan
func commit() -> void:
	if rec.is_empty() or not game.incidents.is_empty() or Career.data.is_empty():
		return
	var plans: Dictionary = Career.data.get("plans", {})
	plans[game.ship_id] = rec.duplicate(true)
	Career.data.plans = plans


func save_state() -> Dictionary:
	return {"rec": rec.duplicate(true), "i": i}


func load_state(d: Dictionary) -> void:
	rec = d.get("rec", []).duplicate(true)
	i = int(d.get("i", 0))


func has_plan() -> bool:
	return not steps.is_empty()


func toggle() -> String:
	if steps.is_empty():
		return "plan_none"
	if running:
		running = false
		return "plan_stopped"
	if i >= steps.size():
		return "plan_done"
	running = true
	wait = ""
	return "plan_running"


func cancel() -> void:
	running = false


# what a reading says: something there (gas, voltage, fluid, heat, field) or not
static func present(kind: String, v: float) -> bool:
	match kind:
		"pressure":
			return v > 5.0
		"volts":
			return v > 1.0
		"fluid":
			return v > 0.02
		"temp":
			return v > 60.0
		"field":
			return v > 2.0
	return false


# no worse than when the plan was made: what was dead or empty then is now too
static func no_worse(kind: String, now: float, then: float) -> bool:
	return present(kind, then) or not present(kind, now)


func _pause(key: String, arg: String) -> void:
	wait = key
	wait_arg = arg
	step_t = 0.0


func _physics_process(dt: float) -> void:
	if not running or game == null or game.state != "play" or game.paused_sim:
		return
	if game.auto_paused:
		return
	if i >= steps.size():
		running = false
		wait = ""
		game.say("plan_done", game.drone.global_position + Vector2(0, -44))
		return
	var st: Dictionary = steps[i]
	var c = game.world.ctrls.get(st.ctrl)
	if c == null or not game.world.ctrl_alive(c):
		# not the ship the plan was made on: the operator takes over from here
		_pause("plan_changed", st.ctrl)
		running = false
		game.say("plan_changed", game.drone.global_position + Vector2(0, -44), st.ctrl)
		return
	if game.world.room_hidden(c.hidden_room):
		_pause("plan_hidden", st.ctrl)
		return
	for pr in st.pre:
		if game.world.ctrls.get(pr.key) == null:
			_pause("plan_changed", pr.key)
			running = false
			return
		var r = game.sys.readings.get(pr.key)
		if r == null or game.sys.stale(r):
			_pause("plan_measure", pr.key)
			return
		if not no_worse(pr.kind, float(r.val), float(pr.val)):
			_pause("plan_differs", pr.key)
			return
	wait = ""
	step_t += dt
	if step_t < STEP_TIME:
		return
	step_t = 0.0
	game.plan_do(st.do, c)
	i += 1


func status() -> Array:
	# [title, line] for the HUD; empty when there is nothing to show
	if steps.is_empty():
		return []
	var head := Txt.t("plan_title") % [mini(i + (0 if i >= steps.size() else 1), steps.size()), steps.size()]
	if i >= steps.size():
		return [head, Txt.t("plan_done")]
	if not running:
		if wait == "plan_changed":
			return [head, Txt.t("plan_changed") % wait_arg]
		return [head, Txt.t("plan_ready")]
	if wait != "":
		return [head, Txt.t(wait) % wait_arg]
	return [head, Txt.t("plan_step") % steps[i].ctrl]
