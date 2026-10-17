class_name Cryo
extends Node
# Cryogenic cargo (first on FR-26, design/ships/FR-26_霜线_设计稿.md). The
# ship file's "cryo" section: {"tanks": {tag: {...}}, "chillers": [tags],
# "heater": {...}}. Each tank:
#   liquid  fluid volume       the cargo (drawn off through its own port)
#   vessel  gas vessel         its vapour space: the pressure a port on it reads
#   jacket  room               the vacuum jacket round it (it insulates while it holds vacuum)
#   T0, kpa0                   the temperature it is kept at, and the vapour pressure there
#   psv, psv_kpa, stuck        its relief valve (a piece), where it lifts, whether it is frozen shut
#   burst_kpa                  where a tank that cannot relieve itself ruptures
# While there is liquid in it, a tank's vapour pressure follows its temperature
# (it doubles every 20 °C). Heat leaks in slowly through a sound vacuum jacket
# (the user's call: warming, but slow: under 10 °C in a contract's time), ten
# times faster through a lost one; a running chiller (powered) pulls the cargo
# back towards T0; the heater, if something feeds it and it is switched on,
# warms its tank. Above psv_kpa the relief valve lifts and boils the cargo off
# to space (cargo lost); frozen shut, the pressure climbs to burst_kpa and the
# tank ruptures. A temperature probe reads a tank's cargo.

const LEAK := 0.0035             # °C/s through a sound jacket
const LEAK_LOST := 0.05          # °C/s through a jacket that has lost its vacuum
const CHILL := 0.02              # °C/s a running chiller pulls each tank back
const HEAT := 0.09               # °C/s the heater adds to its tank
const DOUBLE := 20.0             # °C for the vapour pressure to double

var game
var tanks := {}                  # tag -> cfg merged with live {"T", "ruptured"}
var chillers: Array = []
var heater := {}
var t := 0.0


func setup(g, ship: Dictionary) -> void:
	game = g
	var c: Dictionary = ship.get("cryo", {})
	for tg in c.get("tanks", {}):
		var e: Dictionary = c.tanks[tg].duplicate()
		e.T = float(e.get("T", e.get("T0", -163.0)))
		e.ruptured = false
		tanks[tg] = e
	chillers = c.get("chillers", [])
	heater = c.get("heater", {})


func active() -> bool:
	return not tanks.is_empty()


func save_state() -> Dictionary:
	var out := {}
	for tg in tanks:
		out[tg] = {"T": tanks[tg].T, "r": tanks[tg].ruptured}
	return out


func load_state(d: Dictionary) -> void:
	for tg in d:
		if tanks.has(tg):
			tanks[tg].T = float(d[tg].get("T", tanks[tg].T))
			tanks[tg].ruptured = d[tg].get("r", false)


# what a temperature probe on a tank reads
func temp(tg: String) -> float:
	return float(tanks[tg].T) if tanks.has(tg) else 20.0


func vapour_kpa(e: Dictionary) -> float:
	return float(e.kpa0) * pow(2.0, (float(e.T) - float(e.T0)) / DOUBLE)


func _powered(tag: String) -> bool:
	var p = game.world.tag(tag)
	return p != null and not p.gone and p.intact and game.sys.piece_volts(p) > 30.0


func _physics_process(dt: float) -> void:
	if game == null or game.state != "play" or game.paused_sim or not active():
		return
	var s = game.sys
	var chill := 0
	for c in chillers:
		if _powered(c):
			chill += 1
	# the heater runs while something feeds it (and its own switch, if it has one, is on)
	var heat_on: bool = not heater.is_empty() and _powered(heater.get("piece", "")) and (not heater.has("switch") or s.on(heater.switch))
	for tg in tanks:
		var e: Dictionary = tanks[tg]
		var p = game.world.tag(tg)
		if e.ruptured or p == null or p.gone:
			continue
		var liquid: float = s.fluid(e.liquid)
		if liquid <= 0.001:
			continue
		# heat in through the jacket, out through the chillers, in from the heater
		# gas in the jacket conducts heat; opened to space it is still a vacuum
		var lost: bool = s.P(e.get("jacket", "")) > 5.0
		var dT := (LEAK_LOST if lost else LEAK) * dt
		if chill > 0 and float(e.T) > float(e.T0):
			dT -= CHILL * chill * dt
		if heat_on and heater.get("tank", "") == tg:
			dT += HEAT * dt
		e.T = maxf(float(e.T0), float(e.T) + dT)
		# the vapour space follows the temperature while there is liquid to boil
		var v: String = e.vessel
		if s.vols.has(v):
			var want := vapour_kpa(e)
			var have: float = s.P(v)
			# the boil-off makes up what a hose draws away, a little at a time
			if have < want:
				var dn: float = minf((want - have) * s.vols[v].V, 40.0 * s.vols[v].V * dt)
				s.vols[v].n += dn
				s.set_fluid(e.liquid, maxf(0.0, liquid - dn * 0.00002))
			var now: float = s.P(v)
			var psv = game.world.tag(e.get("psv", ""))
			var can_lift: bool = psv != null and not psv.gone and not e.get("stuck", false)
			if now > float(e.psv_kpa) and can_lift:
				# the relief valve lifts: the vapour and the cargo it came from go to space
				var over: float = (now - float(e.psv_kpa)) * s.vols[v].V
				s.vols[v].n -= over
				s.gas_lost += over
				s.set_fluid(e.liquid, maxf(0.0, s.fluid(e.liquid) - over * 0.0004))
				if not e.get("lifting", false):
					e.lifting = true
					game.say("psv_lift", game.world.frame(p) * Geom.centroid(p.poly) + Vector2(0, -80), tg)
			elif now > float(e.burst_kpa):
				_rupture(tg, e, p)
			elif now < float(e.psv_kpa) * 0.95:
				e.lifting = false


func _rupture(tg: String, e: Dictionary, p) -> void:
	e.ruptured = true
	var s = game.sys
	var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	s.gas_lost += s.vols[e.vessel].n
	s.vols[e.vessel].n = 0.0
	s.fluid_lost += s.fluid(e.liquid)
	s.set_fluid(e.liquid, 0.0)
	game.incident("tank_rupture", tg)
	game.say("tank_rupture", at + Vector2(0, -90), tg)
	game.lose("loss_rupture", 25000.0, at + Vector2(0, -110))
	game._dent(p, 0.0, "dv_rupture")
	p.intact = false
	game.fx.flash(at, 320.0, 0.5, Pal.tint(Pal.AIR, 1.0, 2.2))
	game.shake(0.8)
	game.sfx.play("blast")
	if game.drone.alive and game.drone.global_position.distance_to(at) < 8.0 * Geom.M:
		game.hurt_drone(45.0, at, "hit_hard", "rupture", 0.8)
