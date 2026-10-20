extends Node2D
# Cryogenic tanks boiling off (HG-170 "Gas Sea", design/ships/02_新设计十艘_设计稿.md:
# "the tanks boil off and their pressure climbs (faster where the insulation is torn);
# with the refrigeration running (it needs power) it holds; stopped, it climbs to the
# relief valve and vents (cargo lost); one tank's relief valve is frozen shut (a
# temperature probe shows it) and that tank bursts. Draw the liquid off at the hose
# (the more drawn, the lower the pressure): refrigerate while you draw, cut the power
# last").
# A ship file's "boiloff":
#   {"tanks": {shell piece: {"vol": its cargo volume, "valve": its relief valve piece,
#    "line": its refrigeration line, "rate": kPa/s it climbs uncooled, "frozen": its
#    valve iced shut, "heater": the switch that thaws it}}, "plant": [the cryocoolers,
#    any one running cools them all], "P0": kPa at the start, "floor": kPa the cooling
#    holds it at, "relief": kPa the valve lifts at, "reseat": kPa it shuts again at,
#    "burst": kPa a tank fails at (its shell, "shell": [pieces], blown apart), "cool": kPa/s the cooling takes off, "draw": kPa/s a
#    hose on it takes off, "vent": m3 of cargo lost a kPa vented, "thaw": s to thaw a
#    valve, "reach": m a burst wrecks around it}
#   A tank over "relief" with its valve working vents (cargo lost) down to "reseat".
#   A tank over "burst": it fails, its cargo and what is near it lost.
# Saved: each tank's pressure, which valves are thawed, which tanks vented or burst.

var game
var world
var cfg := {}
var kpa := {}
var thaw := {}              # tank -> seconds of heating its valve has had
var vented := {}
var burst := {}
var _venting := {}
var _c0 := {}               # tank -> its cargo at the start (for the level drawn)
var _t := 0.0
var _kick: Array = []        # [piece tag, outward from] for the frame after a burst


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("boiloff", {})
	z_index = 20
	for t in cfg.get("tanks", {}):
		kpa[t] = float(cfg.get("P0", 420.0))
		thaw[t] = 0.0


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"kpa": kpa, "thaw": thaw, "vented": vented.keys(), "burst": burst.keys()}


func load_state(d: Dictionary) -> void:
	for t in d.get("kpa", {}):
		kpa[str(t)] = float(d.kpa[t])
	for t in d.get("thaw", {}):
		thaw[str(t)] = float(d.thaw[t])
	for t in d.get("vented", []):
		vented[str(t)] = true
	for t in d.get("burst", []):
		burst[str(t)] = true


func _e(t: String) -> Dictionary:
	return cfg.get("tanks", {}).get(t, {})


func cargo(t: String) -> float:
	return game.sys.fluid(str(_e(t).get("vol", "")))


func frozen(t: String) -> bool:
	var e := _e(t)
	return bool(e.get("frozen", false)) and float(thaw.get(t, 0.0)) < float(cfg.get("thaw", 20.0))


# what a probe on the valve reads, °C: iced, or thawing, or as it should be
func valve_temp(t: String) -> float:
	if not bool(_e(t).get("frozen", false)):
		return -40.0
	var k: float = clampf(float(thaw.get(t, 0.0)) / float(cfg.get("thaw", 20.0)), 0.0, 1.0)
	return lerpf(-196.0, -40.0, k)


# the look of a tank's cargo for scripts/liquids.gd
func look(t: String) -> String:
	return str(_e(t).get("look", "lh2"))


func tank_kpa(t: String) -> float:
	return float(kpa.get(t, 0.0))


func refrigerating() -> bool:
	for c in cfg.get("plant", []):
		var p = world.tag(str(c))
		if p != null and not p.gone and p.body == null and p.intact and game.sys.piece_volts(p) > 1.0:
			return true
	return false


func _cooled(t: String) -> bool:
	if not refrigerating():
		return false
	var ln: String = str(_e(t).get("line", ""))
	return ln == "" or not world.lines.has(ln) or world.lines[ln].alive


func _drawn(t: String) -> bool:
	var e := _e(t)
	for id in game.sys.hoses:
		if game.sys.fluid_at_port(id) == str(e.get("vol", "")):
			return true
	return false


func _shell_whole(t: String) -> bool:
	var p = world.tag(t)
	return p != null and not p.gone


func unsafe() -> Array:
	var out: Array = []
	for t in cfg.get("tanks", {}):
		if burst.has(t):
			continue
		if cargo(t) > 0.02:
			out.append("tank %s holds %.1f m³ at %.0f kPa" % [t, cargo(t), tank_kpa(t)])
		if frozen(t):
			out.append("tank %s relief valve frozen" % t)
	return out


func bot_prep() -> Array:
	for t in cfg.get("tanks", {}):
		var h: String = str(_e(t).get("heater", ""))
		if frozen(t) and h != "" and not game.sys.on(h) and not burst.has(t):
			return [[h, "relief valve heater on (tank %s)" % t, 2.0]]
	return []


# for tests/salvage_bot.gd: the refrigeration keeps its power while there is cargo aboard
func hold_power() -> bool:
	for t in cfg.get("tanks", {}):
		if not burst.has(t) and cargo(t) > 0.02:
			return true
	for t in cfg.get("tanks", {}):
		if frozen(t) and not burst.has(t):
			return true
	return false


func _physics_process(dt: float) -> void:
	if not active():
		return
	var fl: float = float(cfg.get("floor", 300.0))
	_t += dt
	# the shell plates of a tank that burst last frame: thrown outward
	for kk in _kick:
		var sp = world.tag(str(kk[0]))
		if sp != null and not sp.gone and sp.body != null:
			var away: Vector2 = (world.frame(sp) * Geom.centroid(sp.poly) - kk[1]).normalized()
			sp.body.linear_velocity = away * 5.0 * Geom.M
			sp.body.angular_velocity = randf_range(-1.5, 1.5)
	_kick.clear()
	for t in cfg.get("tanks", {}):
		if not _c0.has(t):
			_c0[t] = maxf(0.001, cargo(t))
	queue_redraw()
	for t in cfg.get("tanks", {}):
		if burst.has(t):
			continue
		var e := _e(t)
		var h: String = str(e.get("heater", ""))
		if bool(e.get("frozen", false)) and h != "" and game.sys.on(h):
			if game.sys.bus_live:
				thaw[t] = float(thaw.get(t, 0.0)) + dt
		var p: float = float(kpa[t])
		var c := cargo(t)
		if c <= 0.02:
			# nothing left to boil: the ullage gas goes with the last of it
			p = move_toward(p, 0.0, 40.0 * dt)
		elif _cooled(t):
			p = maxf(fl, p - float(cfg.get("cool", 0.6)) * dt)
		else:
			p += float(e.get("rate", 0.8)) * dt
		if _drawn(t) and c > 0.02:
			p = maxf(0.0, p - float(cfg.get("draw", 1.5)) * dt)
		# the relief valve: it lifts, vents the cargo as gas, reseats
		var rv = world.tag(str(e.get("valve", "")))
		var valve_ok: bool = rv != null and not rv.gone and not frozen(t)
		if valve_ok and (p > float(cfg.get("relief", 600.0)) or (_venting.has(t) and p > float(cfg.get("reseat", 540.0)))):
			if not _venting.has(t):
				_venting[t] = true
				_vent_start(t)
			if game.liquids != null and randf() < dt * 1.5:
				var rvv = world.tag(str(e.get("valve", "")))
				if rvv != null:
					game.liquids.spill(world.frame(rvv) * Geom.centroid(rvv.poly), Vector2(1.0 if randf() < 0.5 else -1.0, -0.2), 0.006, look(t), 2, 0.9, 2.2, true)
			var dp: float = minf(p - float(cfg.get("reseat", 540.0)), 30.0 * dt)
			p -= dp
			var vk: String = str(e.get("vol", ""))
			if game.sys.fvol.has(vk):
				var lose: float = minf(float(game.sys.fvol[vk].amount), dp * float(cfg.get("vent", 0.004)))
				game.sys.fvol[vk].amount -= lose
				game.sys.fluid_lost += lose
		else:
			_venting.erase(t)
		kpa[t] = p
		if p > float(cfg.get("burst", 820.0)):
			_burst(t)


func _vent_start(t: String) -> void:
	vented[t] = true
	var rv = world.tag(str(_e(t).get("valve", "")))
	var at: Vector2 = world.frame(rv) * Geom.centroid(rv.poly) if rv != null else Vector2.ZERO
	for i in 6:
		game.fx.puff(at, Vector2(randf_range(-40, 40), -160.0), 2.0, 12.0, 90.0, Pal.ink(0.1))
	if game.liquids != null:
		# the valve's discharge is sideways out of its body (the truss sits right over it)
		game.liquids.spill(at, Vector2(1.0 if randf() < 0.5 else -1.0, -0.2), 0.04, look(t), 6, 0.9, 2.5, true)
	game.sfx.play("hiss", at, 0.8)
	game.incident("tank_vent", t)
	game.say("tank_vent", at, t)
	game.note_loss("loss_tank_vent", t, 0.0)


func _burst(t: String) -> void:
	burst[t] = true
	var e := _e(t)
	var vk: String = str(e.get("vol", ""))
	var s = game.sys
	if s.fvol.has(vk):
		s.fluid_lost += float(s.fvol[vk].amount)
		s.fvol[vk].amount = 0.0
	var shell = world.tag(t)
	var at: Vector2 = world.frame(shell) * Geom.centroid(shell.poly) if shell != null else Vector2.ZERO
	var c: Array = e.get("centre", [])
	if c.size() == 2:
		at = Vector2(float(c[0]), float(c[1])) * Geom.M
	var lost := 0.0
	var reach: float = float(cfg.get("reach", 14.0)) * Geom.M
	for p in game._equip_near(at, reach):
		if p.body != null:
			continue
		var before: float = p.cond
		var k: float = 1.0 - clampf(at.distance_to(world.frame(p) * Geom.centroid(p.poly)) / reach, 0.0, 1.0)
		game._dent(p, maxf(0.0, p.cond - p.fragile * k * 1.2), "dv_tank_burst")
		lost += (before - p.cond) * p.value
	kpa[t] = 0.0
	if game.liquids != null:
		game.liquids.spill(at, Vector2.ZERO, 0.8, look(t), 36, TAU, 3.0, true)
	# the shell comes apart at its welds
	for st in e.get("shell", []):
		var sp = world.tag(str(st))
		if sp == null or sp.gone or sp.body != null:
			continue
		for j in world.joints_of(sp):
			world.kill_joint(j)
		_kick.append([str(st), at])
	game.fx.flash(at, 9.0 * Geom.M, 0.6, Pal.ink(0.9, 1.8))
	for i in 12:
		game.fx.puff(at, Vector2.from_angle(i * TAU / 12.0) * 260.0, 2.2, 20.0, 160.0, Pal.ink(0.12))
	game.shake(0.6)
	game.sfx.play("blowout", at, 1.0)
	game.incident("tank_burst", t)
	game.say("tank_burst", at, t)
	game.note_loss("loss_tank_burst", t, lost)


func on_cut(_p) -> void:
	pass


func on_freed(_b) -> void:
	pass


# ---------------------------------------------------------------- drawing

# each tank's liquid seen through its shell: the level, hatched below, a shimmer on it;
# the gas lifting off it while it vents
func _draw() -> void:
	if not active():
		return
	var r: float = float(cfg.get("radius", 5.0)) * Geom.M
	for t in cfg.get("tanks", {}):
		if burst.has(t):
			continue
		var c: Array = _e(t).get("centre", [])
		if c.size() != 2:
			continue
		var ctr := Vector2(float(c[0]), float(c[1])) * Geom.M
		var k: float = clampf(cargo(t) / float(_c0.get(t, 1.0)), 0.0, 1.0)
		if k <= 0.005:
			continue
		var y: float = ctr.y + r - 2.0 * r * k
		var half: float = sqrt(maxf(0.0, r * r - (y - ctr.y) * (y - ctr.y)))
		var wob: float = sin(_t * 1.7 + ctr.x) * 1.5
		draw_line(Vector2(ctr.x - half, y + wob), Vector2(ctr.x + half, y - wob), Pal.ink(0.45), 1.4, true)
		var step := 0.9 * Geom.M
		var yy: float = y + step
		while yy < ctr.y + r:
			var hh: float = sqrt(maxf(0.0, r * r - (yy - ctr.y) * (yy - ctr.y)))
			draw_line(Vector2(ctr.x - hh, yy), Vector2(ctr.x + hh, yy), Pal.ink(0.08), 1.0, true)
			yy += step
		if _venting.has(t):
			for i in 4:
				var bx: float = ctr.x + (fposmod(i * 0.37 + _t * 0.3, 1.0) - 0.5) * half * 1.6
				var by: float = y - fposmod(_t * 40.0 + i * 25.0, maxf(10.0, y - (ctr.y - r)))
				draw_arc(Vector2(bx, by), 3.0, 0.0, TAU, 8, Pal.ink(0.3), 1.0, true)
