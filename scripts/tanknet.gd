extends Node
# A propellant network (VT-80 "Long Whale": "the tanks are cross-connected; the
# wrong isolation or draining order puts another tank in trouble"). A ship file's
# "tanknet" section:
#   {"tanks": {tank tag: {"vol": its fluid volume, "valve": its cross valve,
#     "cap": its full amount, "ullage": its ullage gas vessel, "pv": its
#     pressurisation valve}},
#    "manifold": the cross-connect manifold's fluid volume, "mcap": its full amount,
#    "pump": the main pump (on the bus), "port": the recovery port it draws at,
#    "flow": how fast levels even out (/s)}
#   The tanks whose cross valve is open share the manifold: it fills from them,
#   and their levels even out through it. A valve that leaks ("leak" on its tank,
#   a contract's trap) passes a little even shut.
#   The main pump draws the manifold at the recovery port, only with power; kept
#   drawing with the manifold dry and nothing left to feed it, it runs dry and is
#   damaged.
#   A tank's ullage follows its level: as the liquid goes, the gas over it
#   expands. With its pressurisation shut and the ullage vented, drawing liquid
#   pulls a vacuum and the tank buckles (badly damaged).
# Saved: which tanks buckled, whether the pump ran dry.

const BUCKLE_KPA := 20.0
const BUCKLE_KEEP := 0.45
const DRY_S := 5.0
const DRY_KEEP := 0.5

var game
var world
var cfg := {}
var buckled := {}             # tank tag -> true
var ran_dry := false
var _dry_t := 0.0
var _pump0: Array = []        # the manifold's pump rate as the ship file gives it
var _ull := {}                # tank tag -> the ullage volume the vessel stood for last step


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("tanknet", {})
	if cfg.is_empty():
		return
	var v: Dictionary = ship.get("fluids", {}).get("volumes", {}).get(cfg.get("manifold", ""), {})
	_pump0 = v.get("pump", [0.1, 0.005])


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"buckled": buckled.keys(), "dry": ran_dry}


func load_state(d: Dictionary) -> void:
	for t in d.get("buckled", []):
		buckled[str(t)] = true
	ran_dry = bool(d.get("dry", false))


# propellant still aboard: in the tanks, the manifold, the branch lines
func fuel_left() -> float:
	var s = game.sys
	var tot: float = s.fluid(cfg.get("manifold", ""))
	for t in cfg.get("tanks", {}):
		tot += s.fluid(cfg.tanks[t].vol)
		tot += s.fluid(cfg.tanks[t].get("branch", ""))
	return tot


# a tank's vent or the nitrogen bank's ports: kept shut while the propellant is
# still being drawn (a vented ullage would pull a vacuum)
func hold_port(id: String) -> bool:
	if not active():
		return false
	if not (cfg.get("hold", []) as Array).has(id):
		return false
	return fuel_left() > 0.02


# a valve the bot must not reopen once shut (pressurisation, the nitrogen bank)
func pv_valve(id: String) -> bool:
	if not active():
		return false
	if id == cfg.get("bank", ""):
		return true
	for t in cfg.tanks:
		if cfg.tanks[t].get("pv", "") == id:
			return true
	return false


func pumped() -> bool:
	var p = world.tag(cfg.get("pump", ""))
	return p != null and not p.gone and p.intact and p.body == null and game.sys.piece_volts(p) > 1.0


func _tank_ok(tag: String) -> bool:
	var p = world.tag(tag)
	return p != null and not p.gone and p.body == null


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var s = game.sys
	var mk: String = cfg.get("manifold", "")
	if not s.fvol.has(mk):
		return
	var m: Dictionary = s.fvol[mk]
	var mcap := float(cfg.get("mcap", 0.4))
	var before := {}
	var open: Array = []
	for t in cfg.tanks:
		var e: Dictionary = cfg.tanks[t]
		before[t] = s.fluid(e.vol)
		var k := 0.0
		if s.on(e.valve):
			k = 1.0
		elif float(e.get("leak", 0.0)) > 0.0:
			k = float(e.leak)
		if k > 0.0 and _tank_ok(t):
			open.append([t, k])
	# the manifold fills from the open tanks
	var space := mcap - float(m.amount)
	if space > 0.0 and not open.is_empty():
		var want := 0.0
		for o in open:
			want += s.fluid(cfg.tanks[o[0]].vol) * float(o[1])
		if want > 0.0:
			var take := minf(space, want * dt * float(cfg.get("flow", 0.2)) * 4.0)
			for o in open:
				var v: Dictionary = s.fvol[cfg.tanks[o[0]].vol]
				var part: float = take * v.amount * float(o[1]) / want
				v.amount -= part
				m.amount += part
	# and their levels even out through it
	if open.size() > 1:
		var amt := 0.0
		var cap := 0.0
		for o in open:
			amt += s.fluid(cfg.tanks[o[0]].vol)
			cap += float(cfg.tanks[o[0]].cap)
		var lv := amt / maxf(cap, 0.001)
		for o in open:
			var e2: Dictionary = cfg.tanks[o[0]]
			var v2: Dictionary = s.fvol[e2.vol]
			var target: float = lv * float(e2.cap)
			v2.amount += (target - v2.amount) * minf(1.0, float(cfg.get("flow", 0.2)) * float(o[1]) * dt)
	# the main pump draws only with power
	m.pump = _pump0 if pumped() else [0.0, 0.0]
	var port: String = cfg.get("port", "")
	var feeding := 0.0
	for o in open:
		feeding += s.fluid(cfg.tanks[o[0]].vol)
	if s.hoses.has(port) and pumped() and float(m.amount) < 0.004 and feeding < 0.01:
		_dry_t += dt
		if _dry_t > DRY_S and not ran_dry:
			_run_dry()
	else:
		_dry_t = 0.0
	# the ullage follows the level
	for t in cfg.tanks:
		var e3: Dictionary = cfg.tanks[t]
		var uk: String = e3.get("ullage", "")
		if not s.vols.has(uk):
			continue
		var now: float = maxf(0.15, float(e3.cap) - s.fluid(e3.vol))
		var was: float = _ull.get(t, now)
		_ull[t] = now
		if absf(now - was) > 1e-6:
			s.vols[uk].n *= was / now
		var lost: float = float(before[t]) - s.fluid(e3.vol)
		if lost > 1e-5 and s.P(uk) < BUCKLE_KPA and not buckled.has(t) and _tank_ok(t):
			_buckle(t)


func _buckle(t: String) -> void:
	buckled[t] = true
	var p = world.tag(t)
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var before: float = p.cond
	game._dent(p, minf(p.cond, BUCKLE_KEEP), "dv_buckle")
	game.incident("tank_buckled", t)
	game.say("tank_buckled", at, t)
	game.note_loss("loss_buckle", t, (before - p.cond) * p.value)
	game.shake(0.5)
	game.sfx.play("snap")


func _run_dry() -> void:
	ran_dry = true
	var p = world.tag(cfg.get("pump", ""))
	if p == null:
		return
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	var before: float = p.cond
	game._dent(p, minf(p.cond, DRY_KEEP), "dv_pump_dry")
	game.incident("pump_dry", p.tag)
	game.say("pump_dry", at, p.tag)
	game.note_loss("loss_pump_dry", p.tag, (before - p.cond) * p.value)
	game.sfx.play("clank")
