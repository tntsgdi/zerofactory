extends Node
# A dilution refrigerator still at a few millikelvin (QC-30 "Quantum",
# design/ships/02_新设计十艘_设计稿.md: "the qubit chip sits in the mixing chamber;
# warm it up in order - circulation stopped, the 3He/4He mixture recovered, then the
# stages - or it cracks; and the isolation table locked before anything near is cut").
# A ship file's "dilution":
#   {"stages": {stage piece: its base temperature K}, "order": [stages, top to bottom
#    (the mixing chamber last)], "chip": the processor (a piece), "pt": the pulse
#    tube's switch, "compressor": the piece it runs on (needs power), "circ": the
#    circulation pump's switch, "heater": the warm-up heaters' switch, "mix": the
#    mixture's gas vessel, "mix_safe": kPa it must be under before the pulse tube
#    stops, "warm": K/s the mixing chamber warms with the pulse tube off, "heat_k":
#    how much faster with the heaters on, "shock_T": K under which the heaters crack
#    the chip, "brittle_T": K under which the stack (or the chip) can't be touched,
#    "isolation": {"lock": the isolation table's lock switch, "radius": m, "knock": what
#    a cut or a knock near takes off the chip}}
#   With the pulse tube running (its switch on and its compressor powered) the stages
#   hold their base temperatures; stopped, they warm towards room temperature, the
#   coldest slowest. Stopped with the mixture still in the fridge (the circulation
#   still on, or the mixture not yet recovered) the mixture boils off through the
#   still: lost, and the still and cold plate are damaged. The heaters on while the
#   mixing chamber is still under "shock_T": the chip cracks. Anything of the stack
#   cut or freed while the mixing chamber is still under "brittle_T": the chip cracks.
#   With the isolation table unlocked, a cut into anything within "radius" of the
#   chip shakes it.
# Saved: the stages' temperatures, whether the mixture boiled off, what cracked.

const CRACK_KEEP := 0.15
const BOIL_KEEP := 0.6
const ROOM := 295.0

var game
var world
var cfg := {}
var temp := {}
var boiled := false
var cracked := ""
var _shake_t := -99.0


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("dilution", {})
	for s in cfg.get("stages", {}):
		temp[s] = float(cfg.stages[s])


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"temp": temp, "boiled": boiled, "cracked": cracked}


func load_state(d: Dictionary) -> void:
	for s in d.get("temp", {}):
		temp[str(s)] = float(d.temp[s])
	boiled = bool(d.get("boiled", false))
	cracked = str(d.get("cracked", ""))


func mxc() -> String:
	var o: Array = cfg.get("order", [])
	return str(o[o.size() - 1]) if not o.is_empty() else ""


func mxc_temp() -> float:
	return float(temp.get(mxc(), ROOM))


func stage_temp(s: String) -> float:
	return float(temp.get(s, ROOM))


func running() -> bool:
	var c = world.tag(str(cfg.get("compressor", "")))
	return game.sys.on(str(cfg.get("pt", ""))) and c != null and not c.gone and c.intact and game.sys.piece_volts(c) > 1.0


func mix_in() -> bool:
	return game.sys.vols.has(str(cfg.get("mix", ""))) and game.sys.P(str(cfg.get("mix", ""))) > float(cfg.get("mix_safe", 20.0))


func locked() -> bool:
	return game.sys.on(str(cfg.get("isolation", {}).get("lock", "")))


# what still has to be made safe
func unsafe() -> Array:
	var out: Array = []
	if mix_in():
		out.append("mixture %.0f kPa" % game.sys.P(str(cfg.mix)))
	if running():
		out.append("pulse tube running")
	if mxc_temp() < float(cfg.get("brittle_T", 250.0)):
		out.append("mixing chamber %.1f K" % mxc_temp())
	if not locked():
		out.append("isolation table floating")
	return out


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	var s = game.sys
	var run := running()
	var heat: bool = s.on(str(cfg.get("heater", "")))
	if not run:
		# the mixture still in the fridge: it boils off through the still
		if not boiled and (mix_in() or s.on(str(cfg.get("circ", "")))) and mxc_temp() < 4.0:
			_boil()
		var k: float = float(cfg.get("warm", 1.0)) * (float(cfg.get("heat_k", 4.0)) if heat else 1.0)
		var o: Array = cfg.get("order", [])
		for i in o.size():
			var st: String = o[i]
			# the upper stages warm first: each a little faster than the one below it
			var f := 1.0 + 0.35 * (o.size() - 1 - i)
			temp[st] = minf(ROOM, float(temp[st]) + k * f * dt * (1.0 + float(temp[st]) / 60.0))
	else:
		for st in temp:
			temp[st] = maxf(float(cfg.stages[st]), float(temp[st]) - 2.0 * dt)
	if heat and mxc_temp() < float(cfg.get("shock_T", 30.0)) and cracked == "":
		_crack("qpu_shock")


func _boil() -> void:
	boiled = true
	var s = game.sys
	var mv: String = str(cfg.get("mix", ""))
	var lost := 0.0
	if s.vols.has(mv):
		s.vols[mv].n = 0.0
	for t in ["STG-STILL", "STG-CP"]:
		var q = world.tag(t)
		if q != null and not q.gone and q.intact:
			var before: float = q.cond
			game._dent(q, minf(q.cond, BOIL_KEEP), "dv_mix_boil")
			lost += (before - q.cond) * q.value
	var at: Vector2 = _chip_pos()
	game.incident("mix_boil", "")
	game.say("mix_boil", at, "")
	game.note_loss("loss_mix_boil", str(cfg.get("mix", "")), lost)
	game.sfx.play("hiss")


func _chip_pos() -> Vector2:
	var c = world.tag(str(cfg.get("chip", "")))
	if c == null or c.gone:
		return game.drone.global_position
	return world.frame(c) * Geom.centroid(c.poly)


func _crack(why: String) -> void:
	var c = world.tag(str(cfg.get("chip", "")))
	if c == null or c.gone or not c.intact or cracked != "":
		return
	cracked = why
	var before: float = c.cond
	game._dent(c, minf(c.cond, CRACK_KEEP), "dv_" + why)
	game.incident(why, c.tag)
	game.say(why, _chip_pos(), c.tag)
	game.note_loss("loss_qpu_crack", c.tag, (before - c.cond) * c.value)
	game.sfx.play("crack")
	world.redraw_near([c])


# a cut or a knock near the chip, the isolation table floating
func _shake(at: Vector2) -> void:
	if locked() or cracked != "":
		return
	var iso: Dictionary = cfg.get("isolation", {})
	if at.distance_to(_chip_pos()) > float(iso.get("radius", 8.0)) * Geom.M:
		return
	if game.playtime - _shake_t < 2.0:
		return
	_shake_t = game.playtime
	var c = world.tag(str(cfg.get("chip", "")))
	if c == null or c.gone or not c.intact:
		return
	var before: float = c.cond
	game._dent(c, maxf(0.0, c.cond - float(iso.get("knock", 0.25))), "dv_qpu_vibration")
	game.incident("qpu_vibration", c.tag)
	game.say("qpu_vibration", _chip_pos(), c.tag)
	game.note_loss("loss_qpu_vibration", c.tag, (before - c.cond) * c.value)


func on_cut(p) -> void:
	if not active():
		return
	var at: Vector2 = world.frame(p) * Geom.centroid(p.poly)
	if (cfg.get("stages", {}) as Dictionary).has(p.tag) or p.tag == str(cfg.get("chip", "")):
		if mxc_temp() < float(cfg.get("brittle_T", 250.0)):
			_crack("qpu_brittle")
	_shake(at)


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if (cfg.get("stages", {}) as Dictionary).has(q.tag) or q.tag == str(cfg.get("chip", "")):
			if mxc_temp() < float(cfg.get("brittle_T", 250.0)):
				_crack("qpu_brittle")
				break
